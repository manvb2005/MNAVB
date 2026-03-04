import 'package:flutter/services.dart';
import 'package:workmanager/workmanager.dart';
import 'app_monitoring_service.dart';
import '../utils/system_notifications.dart';

const _channel = MethodChannel('voucher_share');
const taskProcessVoucher = "processVoucher";

/// Servicio para encolar trabajos de procesamiento de vouchers
/// Recibe llamadas desde el lado nativo (Android) y encola tareas en WorkManager
class ShareEnqueueService {
  /// Inicializa el servicio y configura el handler del MethodChannel
  static Future<void> init() async {
    await AppMonitoringService.instance.init();

    _channel.setMethodCallHandler((call) async {
      if (call.method == "enqueueVoucher") {
        try {
          final uri = (call.arguments as Map)['uri'] as String;
          AppMonitoringService.instance.logInfo(
            'Recibido URI de voucher: $uri',
            tag: 'SHARE',
          );

          // Generar ID único para la notificación
          final notifId = DateTime.now().millisecondsSinceEpoch.remainder(
            100000,
          );

          // Mostrar feedback inmediato al usuario (sin bloquear encolado)
          try {
            await SystemNotifications.showProcessing(notifId);
          } catch (e) {
            AppMonitoringService.instance.logWarning(
              'No se pudo mostrar notificacion de procesamiento: $e',
              tag: 'SHARE',
            );
          }

          // Encolar la tarea en WorkManager
          await Workmanager().registerOneOffTask(
            "voucher_$notifId", // ID único de la tarea
            taskProcessVoucher, // Nombre de la tarea
            inputData: {"uri": uri, "notifId": notifId},
          );

          AppMonitoringService.instance.logInfo(
            'Tarea encolada correctamente en WorkManager',
            tag: 'SHARE',
          );
        } catch (e) {
          await AppMonitoringService.instance.logError(
            'Error encolando tarea',
            tag: 'SHARE',
            error: e,
          );
        }
      }
    });

    AppMonitoringService.instance.logInfo(
      'ShareEnqueueService inicializado',
      tag: 'SHARE',
    );
  }
}
