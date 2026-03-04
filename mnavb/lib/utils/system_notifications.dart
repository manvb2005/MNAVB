import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../services/native_overlay_service.dart';
import '../services/pending_external_voucher_service.dart';

/// Servicio para manejar notificaciones del sistema
/// Estas aparecen en la barra de notificaciones de Android sin necesidad de abrir la app
class SystemNotifications {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static final _pendingService = PendingExternalVoucherService();
  static const _payloadExternalConfirm = 'open_external_confirm';
  static const _payloadNoop = 'noop';
  static const _channelId = 'voucher_channel';
  static const _channelName = 'Procesamiento de Vouchers';
  static const _channelDesc =
      'Notificaciones sobre el procesamiento de vouchers compartidos';

  /// Inicializa el sistema de notificaciones
  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: android);
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload == _payloadExternalConfirm) {
          Future<void>.microtask(_openExternalConfirmIfPending);
        }
      },
    );

    // Crear el canal de notificaciones
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
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
      payload: _payloadNoop,
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
      payload: _payloadNoop,
    );
  }

  static Future<void> showNeedsExternalConfirmation(int id, String msg) async {
    final shownNatively = await NativeOverlayService.showConfirmNotification(
      id: id,
      message: msg,
    );
    if (shownNatively) return;

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
      '🧾 Confirmar voucher API',
      msg,
      details,
      payload: _payloadExternalConfirm,
    );
  }

  static Future<void> _openExternalConfirmIfPending() async {
    await _pendingService.markOpenOverlayRequested();

    PendingExternalVoucher? pending;
    for (var i = 0; i < 10; i++) {
      pending = await _pendingService.get();
      if (pending != null) break;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    if (pending == null) return;

    if (await NativeOverlayService.openFromPending()) {
      return;
    }
  }

  /// Cancela todas las notificaciones
  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
