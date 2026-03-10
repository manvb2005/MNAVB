import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'package:workmanager/workmanager.dart';
import 'app/app_routes.dart';
import 'app/app_theme.dart';
import 'viewmodels/theme_provider.dart';
import 'viewmodels/remember_session_provider.dart';
import 'viewmodels/voucher_provider.dart';
import 'views/login_view.dart';
import 'views/register_view.dart';
import 'views/external_api_home_view.dart';
import 'views/external_api_voucher_confirm_view.dart';
import 'viewmodels/register_viewmodel.dart';
import 'views/main_nav_view.dart';
import 'utils/system_notifications.dart';
import 'services/backends/finance_backend.dart';
import 'services/backends/finance_backend_resolver.dart';
import 'models/backend_type.dart';
import 'services/firebase_service.dart';
import 'services/pending_external_voucher_service.dart';
import 'services/voucher_processing_service_background.dart';
import 'services/share_enqueue_service.dart';
import 'services/app_monitoring_service.dart';
import 'utils/currency_formatter.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Nombre de la tarea del WorkManager
const taskProcessVoucher = "processVoucher";
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> _enableImmersiveMode() async {
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
}

Future<void> _safeNotification(Future<void> Function() action) async {
  try {
    await action();
  } catch (e) {
    AppMonitoringService.instance.logWarning(
      'Notificacion no disponible en este contexto: $e',
      tag: 'NOTIFICATION',
    );
  }
}

/// Callback dispatcher para WorkManager
/// Este se ejecuta en un isolate separado (background)
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await AppMonitoringService.instance.init();

      if (task != taskProcessVoucher) {
        AppMonitoringService.instance.logInfo(
          'WorkManager: tarea ignorada: $task',
          tag: 'WORKER',
        );
        return Future.value(true);
      }

      AppMonitoringService.instance.logInfo(
        'WorkManager: iniciando tarea de procesamiento de voucher',
        tag: 'WORKER',
      );

      // IMPORTANTE: Inicializar Firebase en background
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Inicializar notificaciones (si están disponibles en este isolate)
      await _safeNotification(() => SystemNotifications.init());

      // Obtener ID de notificación único
      final notifId =
          (inputData?['notifId'] as int?) ??
          DateTime.now().millisecondsSinceEpoch.remainder(100000);

      // Obtener URI del voucher
      final uri = inputData?['uri'] as String?;
      if (uri == null || uri.isEmpty) {
        throw Exception('URI del voucher no proporcionado');
      }

      AppMonitoringService.instance.logInfo(
        'Procesando voucher desde URI: $uri',
        tag: 'WORKER',
      );

      // Obtener UID del usuario desde SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('saved_uid');

      if (userId == null) {
        throw Exception('Usuario no autenticado. Inicia sesión en la app.');
      }

      final backendType = await FinanceBackendResolver.resolveBackendType(
        userId,
      );

      final voucherService = VoucherProcessingService();

      if (backendType == BackendType.externalApi) {
        final result = await voucherService.processSharedUriForExternalApi(uri);

        AppMonitoringService.instance.logInfo(
          'Voucher API externa procesado: ${formatMoney(result.monto)}',
          tag: 'WORKER',
        );

        final pendingService = PendingExternalVoucherService();
        await pendingService.save(
          PendingExternalVoucher(
            notificationId: notifId,
            monto: result.monto,
            descripcion: result.descripcion,
            fecha: result.fecha,
            moneda: 'PEN',
            bancoNombre: 'Voucher',
          ),
        );

        await _safeNotification(
          () => SystemNotifications.showNeedsExternalConfirmation(
            notifId,
            'Toca aqui para confirmar categoria y subcategoria.',
          ),
        );

        return Future.value(true);
      }

      // Flujo completo (gasto/ingreso/banco) solo para usuarios Firebase
      final result = await voucherService.processSharedUri(uri);

      AppMonitoringService.instance.logInfo(
        'Voucher procesado: ${result.tipo} - ${formatMoney(result.monto)}',
        tag: 'WORKER',
      );

      final backend = await FinanceBackendResolver.resolveForUser(userId);
      final bancoId = await backend.findOrCreateBank(
        userId: userId,
        bank: BankIdentity(
          nombre: result.bancoNombre,
          logo: result.bancoLogo,
          tipoCuenta: result.tipoCuenta,
        ),
      );

      final movement = MovementRecordInput(
        userId: userId,
        bancoId: bancoId,
        bancoNombre: result.bancoNombre,
        bancoLogo: result.bancoLogo,
        tipoCuenta: result.tipoCuenta,
        categoria: result.descripcion,
        descripcion: result.descripcion,
        monto: result.monto,
        fecha: result.fecha,
      );

      // Registrar la transacción
      if (result.tipo == 'gasto') {
        await backend.registerGasto(movement: movement);

        await _safeNotification(
          () => SystemNotifications.showSuccess(
            notifId,
            'Gasto registrado: ${formatMoney(result.monto)}${result.descripcion != 'Sin descripción' ? ' - ${result.descripcion}' : ''}',
          ),
        );
      } else {
        await backend.registerIngreso(movement: movement);

        await _safeNotification(
          () => SystemNotifications.showSuccess(
            notifId,
            'Ingreso registrado: ${formatMoney(result.monto)}${result.descripcion != 'Sin descripción' ? ' - ${result.descripcion}' : ''}',
          ),
        );
      }

      AppMonitoringService.instance.logInfo(
        'Transaccion guardada correctamente',
        tag: 'WORKER',
      );

      return Future.value(true);
    } catch (e) {
      await AppMonitoringService.instance.logError(
        'Error en procesamiento en background',
        tag: 'WORKER',
        error: e,
      );

      final notifId = (inputData?['notifId'] as int?) ?? 9999;
      await _safeNotification(
        () => SystemNotifications.showError(
          notifId,
          e.toString().replaceAll('Exception: ', ''),
        ),
      );

      // IMPORTANTE: retornar true evita reintentos automáticos de WorkManager.
      // Ya notificamos el error al usuario y no queremos re-disparar la misma tarea.
      return Future.value(true);
    }
  });
}

Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await AppMonitoringService.instance.init();

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      unawaited(
        AppMonitoringService.instance.logError(
          'FlutterError no manejado',
          tag: 'FLUTTER',
          error: details.exception,
          stackTrace: details.stack,
        ),
      );
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(
        AppMonitoringService.instance.logError(
          'Error de plataforma no manejado',
          tag: 'PLATFORM',
          error: error,
          stackTrace: stack,
        ),
      );
      return true;
    };

    // Inicializar canal de share lo antes posible para evitar perder intents
    await ShareEnqueueService.init();

    // Inicializar WorkManager temprano (necesario para encolar desde share)
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false, // Cambiar a true para ver logs detallados
    );

    // Pantalla completa: oculta barras del sistema
    await _enableImmersiveMode();

    // Inicializar Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Inicializar notificaciones del sistema
    await SystemNotifications.init();

    // Limpiar tarea periódica antigua de parámetros si aún existe en el dispositivo
    await Workmanager().cancelByUniqueName('monitor_parametros_periodic');

    AppMonitoringService.instance.logInfo(
      'WorkManager inicializado correctamente',
      tag: 'BOOT',
      persist: true,
    );

    final startupRoute = await _resolveStartupRoute();

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => RememberSessionProvider()),
          ChangeNotifierProvider(create: (_) => VoucherProvider()),
        ],
        child: MyApp(initialRoute: startupRoute),
      ),
    );
  }, (error, stackTrace) {
    unawaited(
      AppMonitoringService.instance.logError(
        'Error no manejado en zona principal',
        tag: 'ZONE',
        error: error,
        stackTrace: stackTrace,
      ),
    );
  });
}

Future<String> _resolveStartupRoute() async {
  final userId = FirebaseService().currentUserId;
  if (userId == null) return AppRoutes.login;

  final backendType = await FinanceBackendResolver.resolveBackendType(userId);
  if (backendType == BackendType.externalApi) {
    return AppRoutes.externalApiHome;
  }

  return AppRoutes.home;
}

class MyApp extends StatefulWidget {
  final String initialRoute;

  const MyApp({super.key, required this.initialRoute});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enableImmersiveMode();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _enableImmersiveMode();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Control Finanzas',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: theme.themeMode,
      initialRoute: widget.initialRoute,
      routes: {
        AppRoutes.login: (_) => const LoginView(),
        AppRoutes.register: (_) => ChangeNotifierProvider(
          create: (_) => RegisterViewModel(),
          child: const RegisterView(),
        ),
        AppRoutes.home: (_) => const MainNavView(),
        AppRoutes.externalApiHome: (_) => const ExternalApiHomeView(),
        AppRoutes.externalApiVoucherConfirm: (_) =>
            const ExternalApiVoucherConfirmView(),
        AppRoutes.externalApiVoucherOverlay: (_) =>
            const ExternalApiVoucherConfirmView(isOverlay: true),
      },
    );
  }
}

// ...existing code...

// This widget is the home page of your application. It is stateful, meaning
// that it has a State object (defined below) that contains fields that affect
// how it looks.

// This class is the configuration for the state. It holds the values (in this
// case the title) provided by the parent (in this case the App widget) and
// ...existing code...
