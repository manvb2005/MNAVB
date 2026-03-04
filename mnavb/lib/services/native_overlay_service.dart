import 'package:flutter/services.dart';

class NativeOverlayService {
  static const _channel = MethodChannel('native_overlay');

  static Future<bool> canDrawOverlays() async {
    try {
      final result = await _channel.invokeMethod<bool>('canDrawOverlays');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> requestPermission() async {
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } catch (_) {}
  }

  static Future<bool> openFromPending() async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'openOverlayFromPending',
      );
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> showConfirmNotification({
    required int id,
    required String message,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'showNativeConfirmNotification',
        {'id': id, 'message': message},
      );
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}
