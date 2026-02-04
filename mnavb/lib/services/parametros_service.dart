import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'app_detector_service.dart';

class ParametrosService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final AppDetectorService _appDetector = AppDetectorService();

  String? get _userId => _auth.currentUser?.uid;

  // Variables de caché
  double? _cachedGastoMensual;
  DateTime? _cacheTimestamp;

  // Stream para monitorear gastos en tiempo real
  Stream<double> getGastoMensualStream() async* {
    if (_userId == null) {
      yield 0.0;
      return;
    }

    // Primero obtener configuración
    await for (var configSnapshot in _firestore
        .collection('Users')
        .doc(_userId)
        .collection('parametros')
        .doc('configuracion')
        .snapshots()) {
      
      if (!configSnapshot.exists) {
        yield 0.0;
        continue;
      }

      final config = configSnapshot.data()!;
      final parametroActivo = config['parametroActivo'] as bool? ?? false;

      if (!parametroActivo) {
        yield 0.0;
        continue;
      }

      final fechaActivacion = (config['fechaActivacion'] as Timestamp?)?.toDate();
      if (fechaActivacion == null) {
        yield 0.0;
        continue;
      }

      // Escuchar cambios en gastos desde la fecha de activación
      await for (var gastosSnapshot in _firestore
          .collection('Users')
          .doc(_userId)
          .collection('Gastos')
          .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(fechaActivacion))
          .snapshots()) {
        
        double totalGastos = 0.0;
        for (var doc in gastosSnapshot.docs) {
          totalGastos += (doc.data()['monto'] as num).toDouble();
        }

        // Actualizar caché
        _cachedGastoMensual = totalGastos;
        _cacheTimestamp = DateTime.now();

        // Monitorear si se alcanzó el límite
        final limite = (config['limiteGastoMensual'] as num).toDouble();
        final bloqueado = config['bloqueado'] as bool? ?? false;
        
        if (totalGastos >= limite && !bloqueado) {
          // Actualizar estado de bloqueo
          await _firestore
              .collection('Users')
              .doc(_userId)
              .collection('parametros')
              .doc('configuracion')
              .set({
                'bloqueado': true,
                'limiteNotificado': true,
              }, SetOptions(merge: true));
          
          await _bloquearAppsBancarias();
          await _enviarNotificacion(
            '🚫 Límite alcanzado',
            'Has alcanzado tu límite de S/ ${limite.toStringAsFixed(2)}. Las apps bancarias han sido bloqueadas.',
            2,
          );
        }

        yield totalGastos;
        break; // Salir del loop de gastos para volver al loop de config
      }
    }
  }

  // Inicializar notificaciones
  Future<void> inicializarNotificaciones() async {
    const androidSettings = AndroidInitializationSettings(
      'ic_notification',
    );
    const initSettings = InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(initSettings);

    // Solicitar permisos para Android 13+
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  // Obtener configuración de parámetros del usuario
  Stream<Map<String, dynamic>> getParametrosStream() {
    if (_userId == null) return Stream.value({});

    return _firestore
        .collection('Users')
        .doc(_userId)
        .collection('parametros')
        .doc('configuracion')
        .snapshots()
        .map((doc) {
          if (!doc.exists) {
            return _configuracionPorDefecto();
          }
          return doc.data()!;
        });
  }

  Map<String, dynamic> _configuracionPorDefecto() {
    return {
      'limiteGastoMensual': 1000.0,
      'horasDesbloqueo': 24,
      'intentosNormalesRestantes': 3,
      'intentosEmergenciaRestantes': 2,
      'bloqueado': false,
      'parametroActivo': false, // Si el usuario activó el sistema
      'fechaActivacion': null, // Fecha exacta de activación
      'proximaRenovacion': null, // Fecha de próxima renovación (1 mes después)
      'umbralNotificado': false, // Para notificar solo una vez al 90%
      'limiteNotificado': false, // Para notificar solo una vez al 100%
    };
  }

  // Actualizar límite mensual
  Future<void> actualizarLimite(double nuevoLimite) async {
    if (_userId == null) throw Exception('Usuario no autenticado');

    await _firestore
        .collection('Users')
        .doc(_userId)
        .collection('parametros')
        .doc('configuracion')
        .set({'limiteGastoMensual': nuevoLimite}, SetOptions(merge: true));
  }

  // Actualizar tiempo de desbloqueo
  Future<void> actualizarHorasDesbloqueo(int horas) async {
    if (_userId == null) throw Exception('Usuario no autenticado');

    await _firestore
        .collection('Users')
        .doc(_userId)
        .collection('parametros')
        .doc('configuracion')
        .set({'horasDesbloqueo': horas}, SetOptions(merge: true));
  }

  // Calcular gasto total desde la fecha de activación
  Future<double> calcularGastoMensual() async {
    if (_userId == null) return 0.0;

    // Usar caché si es reciente (menos de 30 segundos)
    if (_cachedGastoMensual != null && _cacheTimestamp != null) {
      final diff = DateTime.now().difference(_cacheTimestamp!);
      if (diff.inSeconds < 30) {
        return _cachedGastoMensual!;
      }
    }

    // Obtener configuración para saber desde cuándo contar
    final configDoc = await _firestore
        .collection('Users')
        .doc(_userId)
        .collection('parametros')
        .doc('configuracion')
        .get();

    if (!configDoc.exists) return 0.0;

    final config = configDoc.data()!;
    final parametroActivo = config['parametroActivo'] as bool? ?? false;

    if (!parametroActivo) return 0.0;

    final fechaActivacion = (config['fechaActivacion'] as Timestamp?)?.toDate();
    if (fechaActivacion == null) return 0.0;

    final now = DateTime.now();

    // Obtener SOLO GASTOS (no transferencias ni préstamos) desde la fecha de activación
    final gastosSnapshot = await _firestore
        .collection('Users')
        .doc(_userId)
        .collection('Gastos')
        .where(
          'fecha',
          isGreaterThanOrEqualTo: Timestamp.fromDate(fechaActivacion),
        )
        .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(now))
        .get();

    double totalGastos = 0.0;
    for (var doc in gastosSnapshot.docs) {
      totalGastos += (doc.data()['monto'] as num).toDouble();
    }

    // Actualizar caché
    _cachedGastoMensual = totalGastos;
    _cacheTimestamp = DateTime.now();

    return totalGastos;
  }

  // Verificar y renovar intentos según fecha de activación personalizada
  Future<void> verificarRenovacionMensual() async {
    if (_userId == null) return;

    final docRef = _firestore
        .collection('Users')
        .doc(_userId)
        .collection('parametros')
        .doc('configuracion');

    final doc = await docRef.get();

    if (!doc.exists) {
      await docRef.set(_configuracionPorDefecto());
      return;
    }

    final data = doc.data()!;
    final parametroActivo = data['parametroActivo'] as bool? ?? false;

    if (!parametroActivo) return; // No renovar si no está activo

    final fechaActivacion = (data['fechaActivacion'] as Timestamp?)?.toDate();
    final proximaRenovacion = (data['proximaRenovacion'] as Timestamp?)
        ?.toDate();

    if (fechaActivacion == null || proximaRenovacion == null) return;

    final now = DateTime.now();

    // Si ya pasó la fecha de renovación (1 mes desde activación)
    if (now.isAfter(proximaRenovacion)) {
      // Calcular siguiente renovación (1 mes más desde la próxima)
      final nuevaProximaRenovacion = DateTime(
        proximaRenovacion.year,
        proximaRenovacion.month + 1,
        proximaRenovacion.day,
        proximaRenovacion.hour,
        proximaRenovacion.minute,
      );

      await docRef.set({
        'intentosNormalesRestantes': 3,
        'intentosEmergenciaRestantes': 2,
        'bloqueado': false,
        'proximaRenovacion': Timestamp.fromDate(nuevaProximaRenovacion),
        'umbralNotificado': false,
        'limiteNotificado': false,
      }, SetOptions(merge: true));

      await _enviarNotificacion(
        '🔄 Período renovado',
        'Tus intentos han sido renovados. Nuevo período hasta ${DateFormat('dd/MM/yyyy').format(nuevaProximaRenovacion)}',
        1000,
      );
    }
  }

  // Monitorear gastos y enviar notificaciones
  Future<void> monitorearGastos() async {
    if (_userId == null) return;

    final gastoActual = await calcularGastoMensual();
    final configDoc = await _firestore
        .collection('Users')
        .doc(_userId)
        .collection('parametros')
        .doc('configuracion')
        .get();

    if (!configDoc.exists) return;

    final config = configDoc.data()!;
    final parametroActivo = config['parametroActivo'] as bool? ?? false;
    
    if (!parametroActivo) return; // No monitorear si no está activo

    final limite = (config['limiteGastoMensual'] as num).toDouble();
    final umbralNotificado = config['umbralNotificado'] as bool? ?? false;
    final limiteNotificado = config['limiteNotificado'] as bool? ?? false;
    final bloqueado = config['bloqueado'] as bool? ?? false;

    final porcentaje = (gastoActual / limite);

    // Notificación al 90% (umbral)
    if (porcentaje >= 0.90 && porcentaje < 1.0 && !umbralNotificado) {
      await _enviarNotificacion(
        '⚠️ Cerca del límite',
        'Has gastado S/ ${gastoActual.toStringAsFixed(2)} de S/ ${limite.toStringAsFixed(2)}. Estás cerca de tu límite mensual.',
        1,
      );

      await configDoc.reference.set({'umbralNotificado': true}, SetOptions(merge: true));
    }

    // Notificación al 100% (límite alcanzado) y BLOQUEAR
    if (gastoActual >= limite && !bloqueado) {
      await _enviarNotificacion(
        '🚫 Límite alcanzado',
        'Has alcanzado tu límite de S/ ${limite.toStringAsFixed(2)} para este mes. Las apps bancarias han sido bloqueadas.',
        2,
      );

      await configDoc.reference.set({
        'limiteNotificado': true,
        'bloqueado': true,
      }, SetOptions(merge: true));

      // Bloquear apps bancarias
      await _bloquearAppsBancarias();
    }

    // Notificaciones de recordatorio cada 100 soles adicionales después del límite
    if (gastoActual > limite && bloqueado) {
      final exceso = gastoActual - limite;
      // Notificar cada 100 soles de exceso
      if ((exceso / 100).floor() > ((exceso - 1) / 100).floor()) {
        await _enviarNotificacion(
          '📊 Sobregasto',
          'Has sobrepasado tu límite en S/ ${exceso.toStringAsFixed(2)}',
          100 + (exceso / 100).floor(),
        );
      }
    }
  }

  // Generar código de desbloqueo
  Future<String> generarCodigoDesbloqueo(bool esEmergencia) async {
    if (_userId == null) throw Exception('Usuario no autenticado');

    await verificarRenovacionMensual();

    final configDoc = await _firestore
        .collection('Users')
        .doc(_userId)
        .collection('parametros')
        .doc('configuracion')
        .get();

    if (!configDoc.exists) {
      throw Exception('Configuración no encontrada');
    }

    final config = configDoc.data()!;
    final intentosNormales = config['intentosNormalesRestantes'] as int? ?? 0;
    final intentosEmergencia =
        config['intentosEmergenciaRestantes'] as int? ?? 0;
    final horasDesbloqueo = config['horasDesbloqueo'] as int? ?? 24;

    if (esEmergencia) {
      if (intentosEmergencia <= 0) {
        throw Exception('No tienes intentos de emergencia disponibles');
      }
    } else {
      if (intentosNormales <= 0) {
        throw Exception('No tienes intentos normales disponibles');
      }
    }

    // Generar código aleatorio de 6 dígitos
    final codigo = (100000 + (DateTime.now().millisecondsSinceEpoch % 900000))
        .toString();

    // Descontar intento
    await configDoc.reference.set({
      if (esEmergencia)
        'intentosEmergenciaRestantes': intentosEmergencia - 1
      else
        'intentosNormalesRestantes': intentosNormales - 1,
      'bloqueado': false,
    }, SetOptions(merge: true));

    // Guardar código con fecha de expiración
    await _firestore
        .collection('Users')
        .doc(_userId)
        .collection('parametros')
        .doc('codigoActual')
        .set({
          'codigo': codigo,
          'fechaGeneracion': Timestamp.now(),
          'fechaExpiracion': Timestamp.fromDate(
            DateTime.now().add(Duration(hours: horasDesbloqueo)),
          ),
          'esEmergencia': esEmergencia,
          'activo': true,
        });

    // Desbloquear apps bancarias temporalmente
    await _desbloquearAppsBancarias();

    // Programar bloqueo automático después del tiempo configurado
    await _programarBloqueoAutomatico(horasDesbloqueo);

    await _enviarNotificacion(
      '🔓 Apps desbloqueadas',
      'Código generado: $codigo. Válido por $horasDesbloqueo horas.',
      3,
    );

    return codigo;
  }

  // Enviar notificación local
  Future<void> _enviarNotificacion(
    String titulo,
    String mensaje,
    int id,
  ) async {
    const androidDetails = AndroidNotificationDetails(
      'parametros_channel',
      'Control de Gastos',
      channelDescription: 'Notificaciones del sistema de parámetros',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: 'ic_notification',
    );

    const details = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(id, titulo, mensaje, details);
  }

  // Bloquear apps bancarias (placeholder - requiere implementación nativa)
  Future<void> _bloquearAppsBancarias() async {
    // Aquí iría la lógica nativa para bloquear apps
    // Por ahora solo actualiza el estado en Firebase
    if (_userId == null) return;

    await _firestore
        .collection('Users')
        .doc(_userId)
        .collection('parametros')
        .doc('estadoApps')
        .set({
          'bloqueado': true,
          'fechaBloqueo': Timestamp.now(),
        }, SetOptions(merge: true));

    // Apps bancarias bloqueadas
  }

  // Desbloquear apps bancarias (placeholder - requiere implementación nativa)
  Future<void> _desbloquearAppsBancarias() async {
    // Aquí iría la lógica nativa para desbloquear apps
    if (_userId == null) return;

    await _firestore
        .collection('Users')
        .doc(_userId)
        .collection('parametros')
        .doc('estadoApps')
        .set({
          'bloqueado': false,
          'fechaDesbloqueo': Timestamp.now(),
        }, SetOptions(merge: true));

    // Apps bancarias desbloqueadas
  }

  // Programar bloqueo automático
  Future<void> _programarBloqueoAutomatico(int horas) async {
    // Esta funcionalidad requeriría un trabajo en segundo plano
    // Por ahora, se registra en Firebase
    if (_userId == null) return;

    await _firestore
        .collection('Users')
        .doc(_userId)
        .collection('parametros')
        .doc('estadoApps')
        .set({
          'bloqueoAutomaticoProgramado': true,
          'fechaBloqueoAutomatico': Timestamp.fromDate(
            DateTime.now().add(Duration(hours: horas)),
          ),
        }, SetOptions(merge: true));
  }

  // Verificar si hay código activo y válido
  Future<bool> verificarCodigoActivo() async {
    if (_userId == null) return false;

    final codigoDoc = await _firestore
        .collection('Users')
        .doc(_userId)
        .collection('parametros')
        .doc('codigoActual')
        .get();

    if (!codigoDoc.exists) return false;

    final data = codigoDoc.data()!;
    final activo = data['activo'] as bool? ?? false;
    final fechaExpiracion = (data['fechaExpiracion'] as Timestamp?)?.toDate();

    if (!activo || fechaExpiracion == null) return false;

    // Verificar si expiró
    if (DateTime.now().isAfter(fechaExpiracion)) {
      await codigoDoc.reference.set({'activo': false}, SetOptions(merge: true));
      await _bloquearAppsBancarias();
      await _enviarNotificacion(
        '⏰ Código expirado',
        'Tu código de desbloqueo ha expirado. Las apps han sido bloqueadas nuevamente.',
        4,
      );
      return false;
    }

    return true;
  }

  // Detectar apps bancarias instaladas (ahora usa el servicio nativo)
  Future<List<Map<String, String>>> getAppsBancariasConocidas() async {
    // Primero intentar obtener las apps realmente instaladas
    final installedApps = await _appDetector.getInstalledBankApps();
    
    if (installedApps.isNotEmpty) {
      return installedApps;
    }
    
    // Si no se pudo obtener, devolver lista por defecto
    return [
      {'nombre': 'Yape', 'packageName': 'com.bcp.bank.bcp'},
      {'nombre': 'BCP', 'packageName': 'com.bcp.mobile.app'},
      {'nombre': 'BBVA', 'packageName': 'com.bbva.peru'},
      {'nombre': 'Interbank', 'packageName': 'com.interbank.mobilebanking'},
      {'nombre': 'Scotiabank', 'packageName': 'com.scotiabank.pe'},
      {'nombre': 'Plin', 'packageName': 'com.plin.app'},
      {'nombre': 'Tunki', 'packageName': 'com.tunki'},
      {'nombre': 'Banbif', 'packageName': 'com.banbif.mobile'},
      {'nombre': 'Banco Pichincha', 'packageName': 'com.pichincha.mobile'},
    ];
  }

  // Guardar lista de apps detectadas
  Future<void> guardarAppsDetectadas(List<Map<String, dynamic>> apps) async {
    if (_userId == null) return;

    await _firestore
        .collection('Users')
        .doc(_userId)
        .collection('parametros')
        .doc('appsDetectadas')
        .set({'apps': apps, 'ultimaActualizacion': Timestamp.now()});
  }

  // Obtener apps detectadas
  Future<List<Map<String, dynamic>>> getAppsDetectadas() async {
    if (_userId == null) return [];

    final doc = await _firestore
        .collection('Users')
        .doc(_userId)
        .collection('parametros')
        .doc('appsDetectadas')
        .get();

    if (!doc.exists) return [];

    final data = doc.data()!;
    return List<Map<String, dynamic>>.from(data['apps'] ?? []);
  }

  // Activar el sistema de parámetros
  Future<void> activarParametro() async {
    if (_userId == null) throw Exception('Usuario no autenticado');

    final now = DateTime.now();
    // Calcular próxima renovación (1 mes desde ahora)
    final proximaRenovacion = DateTime(
      now.year,
      now.month + 1,
      now.day,
      now.hour,
      now.minute,
    );

    await _firestore
        .collection('Users')
        .doc(_userId)
        .collection('parametros')
        .doc('configuracion')
        .set({
          'parametroActivo': true,
          'fechaActivacion': Timestamp.fromDate(now),
          'proximaRenovacion': Timestamp.fromDate(proximaRenovacion),
          'intentosNormalesRestantes': 3,
          'intentosEmergenciaRestantes': 2,
          'bloqueado': false,
          'umbralNotificado': false,
          'limiteNotificado': false,
          'limiteGastoMensual': 1000.0,
          'horasDesbloqueo': 24,
        }, SetOptions(merge: true));

    await _enviarNotificacion(
      '✅ Parámetros activados',
      'El control de gastos ha sido activado. Renovación: ${DateFormat('dd/MM/yyyy HH:mm').format(proximaRenovacion)}',
      2000,
    );
  }

  // Desactivar el sistema de parámetros
  Future<void> desactivarParametro() async {
    if (_userId == null) throw Exception('Usuario no autenticado');

    await _firestore
        .collection('Users')
        .doc(_userId)
        .collection('parametros')
        .doc('configuracion')
        .set({
          'parametroActivo': false,
          'bloqueado': false,
        }, SetOptions(merge: true));

    // Desbloquear apps si estaban bloqueadas
    await _desbloquearAppsBancarias();

    await _enviarNotificacion(
      '❌ Parámetros desactivados',
      'El control de gastos ha sido desactivado',
      2001,
    );
  }
}
