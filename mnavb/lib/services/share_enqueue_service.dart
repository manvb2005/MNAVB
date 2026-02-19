import 'package:flutter/services.dart';
import 'package:workmanager/workmanager.dart';
import '../utils/system_notifications.dart';

const _channel = MethodChannel('voucher_share');
const taskProcessVoucher = "processVoucher";

/// Servicio para encolar trabajos de procesamiento de vouchers
/// Recibe llamadas desde el lado nativo (Android) y encola tareas en WorkManager
class ShareEnqueueService {
  /// Inicializa el servicio y configura el handler del MethodChannel
  static Future<void> init() async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == "enqueueVoucher") {
        try {
          final uri = (call.arguments as Map)['uri'] as String;
          print('📥 Recibido URI de voucher: $uri');

          // Generar ID único para la notificación
          final notifId = DateTime.now().millisecondsSinceEpoch.remainder(
            100000,
          );

          // Mostrar feedback inmediato al usuario
          await SystemNotifications.showProcessing(notifId);

          // Encolar la tarea en WorkManager
          await Workmanager().registerOneOffTask(
            "voucher_$notifId", // ID único de la tarea
            taskProcessVoucher, // Nombre de la tarea
            inputData: {"uri": uri, "notifId": notifId},
          );

          print('✅ Tarea encolada correctamente en WorkManager');
        } catch (e) {
          print('❌ Error encolando tarea: $e');
        }
      }
    });

    print('🔗 ShareEnqueueService inicializado');
  }
}
