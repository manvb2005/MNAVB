import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Servicio para manejar notificaciones del sistema
/// Estas aparecen en la barra de notificaciones de Android sin necesidad de abrir la app
class SystemNotifications {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _channelId = 'voucher_channel';
  static const _channelName = 'Procesamiento de Vouchers';
  static const _channelDesc = 'Notificaciones sobre el procesamiento de vouchers compartidos';

  /// Inicializa el sistema de notificaciones
  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: android);
    await _plugin.initialize(initSettings);

    // Crear el canal de notificaciones
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Muestra notificación de "Procesando..."
  /// Esta notificación es persistente (ongoing) hasta que se complete el proceso
  static Future<void> showProcessing(int id) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
        ongoing: true, // No se puede descartar hasta que termine
        showWhen: true,
        icon: '@mipmap/ic_launcher',
      ),
    );
    await _plugin.show(
      id,
      '⏳ Procesando voucher',
      'Leyendo información del voucher...',
      details,
    );
  }

  /// Muestra notificación de éxito
  static Future<void> showSuccess(int id, String msg) async {
    // Cancelar la notificación de "procesando"
    await _plugin.cancel(id);
    
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    );
    await _plugin.show(
      id,
      '✅ Voucher procesado',
      msg,
      details,
    );
  }

  /// Muestra notificación de error
  static Future<void> showError(int id, String msg) async {
    // Cancelar la notificación de "procesando"
    await _plugin.cancel(id);
    
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    );
    await _plugin.show(
      id,
      '❌ Error procesando voucher',
      msg,
      details,
    );
  }

  /// Cancela todas las notificaciones
  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
