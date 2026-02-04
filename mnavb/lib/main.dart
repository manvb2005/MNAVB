
import 'package:flutter/material.dart';
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
import 'viewmodels/register_viewmodel.dart';
import 'views/main_nav_view.dart';
import 'utils/system_notifications.dart';
import 'services/voucher_processing_service_background.dart';
import 'services/firebase_service.dart';
import 'services/share_enqueue_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Nombre de la tarea del WorkManager
const taskProcessVoucher = "processVoucher";

/// Callback dispatcher para WorkManager
/// Este se ejecuta en un isolate separado (background)
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      print('📱 WorkManager: Iniciando tarea de procesamiento de voucher');
      
      // IMPORTANTE: Inicializar Firebase en background
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      
      // Inicializar notificaciones
      await SystemNotifications.init();
      
      // Obtener ID de notificación único
      final notifId = (inputData?['notifId'] as int?) ?? 
          DateTime.now().millisecondsSinceEpoch.remainder(100000);
      
      // Mostrar notificación de "Procesando..."
      await SystemNotifications.showProcessing(notifId);
      
      // Obtener URI del voucher
      final uri = inputData?['uri'] as String?;
      if (uri == null) {
        throw Exception('URI del voucher no proporcionado');
      }
      
      print('📄 Procesando voucher desde URI: $uri');
      
      // Procesar el voucher con OCR
      final voucherService = VoucherProcessingService();
      final result = await voucherService.processSharedUri(uri);
      
      print('✅ Voucher procesado: ${result.tipo} - S/ ${result.monto}');
      
      // Obtener UID del usuario desde SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('saved_uid');
      
      if (userId == null) {
        throw Exception('Usuario no autenticado. Inicia sesión en la app.');
      }
      
      // Guardar en Firestore
      final firebaseService = FirebaseService();
      
      // Buscar o crear el banco
      String? bancoId = await _buscarOCrearBanco(
        firebaseService,
        userId,
        result.bancoNombre,
        result.bancoLogo,
        result.tipoCuenta,
      );
      
      if (bancoId == null) {
        throw Exception('No se pudo obtener o crear el banco');
      }
      
      // Registrar la transacción
      if (result.tipo == 'gasto') {
        await firebaseService.registrarGastoConUserId(
          userId: userId,
          bancoId: bancoId,
          bancoNombre: result.bancoNombre,
          bancoLogo: result.bancoLogo,
          tipoCuenta: result.tipoCuenta,
          categoria: result.descripcion,
          monto: result.monto,
          fecha: result.fecha,
        );
        
        await SystemNotifications.showSuccess(
          notifId,
          'Gasto registrado: S/ ${result.monto.toStringAsFixed(2)}${result.descripcion != 'Sin descripción' ? ' - ${result.descripcion}' : ''}',
        );
      } else {
        await firebaseService.registrarIngresoConUserId(
          userId: userId,
          bancoId: bancoId,
          bancoNombre: result.bancoNombre,
          bancoLogo: result.bancoLogo,
          tipoCuenta: result.tipoCuenta,
          categoria: result.descripcion,
          monto: result.monto,
          fecha: result.fecha,
        );
        
        await SystemNotifications.showSuccess(
          notifId,
          'Ingreso registrado: S/ ${result.monto.toStringAsFixed(2)}${result.descripcion != 'Sin descripción' ? ' - ${result.descripcion}' : ''}',
        );
      }
      
      print('💾 Transacción guardada en Firestore');
      
      return Future.value(true);
    } catch (e) {
      print('❌ Error en background: $e');
      
      final notifId = (inputData?['notifId'] as int?) ?? 9999;
      await SystemNotifications.showError(
        notifId,
        e.toString().replaceAll('Exception: ', ''),
      );
      
      // IMPORTANTE: Retornar false marca la tarea como FAILURE (no se reintentará)
      // Si retornamos true, WorkManager intentaría ejecutar de nuevo
      return Future.value(false);
    }
  });
}

/// Busca un banco existente o lo crea si no existe
Future<String?> _buscarOCrearBanco(
  FirebaseService firebaseService,
  String userId,
  String nombreBanco,
  String logoBanco,
  String tipoCuenta,
) async {
  try {
    // Intentar buscar el banco existente
    final bancos = await firebaseService.getBancosListConUserId(userId);
    
    for (var banco in bancos) {
      if (banco['nombre'].toString().toLowerCase() == nombreBanco.toLowerCase()) {
        return banco['id'] as String;
      }
    }
    
    // Si no existe, crear uno nuevo
    return await firebaseService.agregarBancoConUserId(
      userId: userId,
      nombre: nombreBanco,
      logo: logoBanco,
      tipoCuenta: tipoCuenta,
      saldo: 0.0,
    );
  } catch (e) {
    print('Error buscando/creando banco: $e');
    return null;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Inicializar notificaciones del sistema
  await SystemNotifications.init();
  
  // Inicializar WorkManager
  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: false, // Cambiar a true para ver logs detallados
  );
  
  // IMPORTANTE: Cancelar trabajos antiguos/pendientes para evitar ejecuciones fantasma
  await Workmanager().cancelAll();
  print('🧹 Trabajos antiguos de WorkManager cancelados');
  
  // Inicializar servicio para encolar vouchers compartidos
  await ShareEnqueueService.init();
  
  print('🚀 WorkManager inicializado correctamente');
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => RememberSessionProvider()),
        ChangeNotifierProvider(create: (_) => VoucherProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Control Finanzas',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: theme.themeMode,
      initialRoute: AppRoutes.login,
      routes: {
        AppRoutes.login: (_) => const LoginView(),
        AppRoutes.register: (_) => ChangeNotifierProvider(
          create: (_) => RegisterViewModel(),
          child: const RegisterView(),
        ),
        AppRoutes.home: (_) => const MainNavView(),
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
