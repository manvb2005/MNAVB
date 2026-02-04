import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

/// Helper para solicitar permisos de notificaciones
class NotificationPermissionHelper {
  /// Solicita permiso de notificaciones (necesario para Android 13+)
  static Future<bool> requestNotificationPermission(BuildContext context) async {
    // Verificar si ya tenemos permiso
    final status = await Permission.notification.status;
    
    if (status.isGranted) {
      print('✅ Permiso de notificaciones ya concedido');
      return true;
    }
    
    if (status.isDenied) {
      // Mostrar diálogo explicativo antes de solicitar
      if (context.mounted) {
        final shouldRequest = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('📱 Activar Notificaciones'),
            content: const Text(
              'Para recibir notificaciones cuando proceses vouchers en segundo plano, '
              'necesitamos tu permiso.\n\n'
              '✅ Recibirás notificaciones de:\n'
              '• Vouchers procesados con éxito\n'
              '• Errores al procesar\n'
              '• Estado del procesamiento',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Ahora no'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Activar'),
              ),
            ],
          ),
        );
        
        if (shouldRequest != true) {
          return false;
        }
      }
      
      // Solicitar permiso
      final result = await Permission.notification.request();
      
      if (result.isGranted) {
        print('✅ Permiso de notificaciones concedido');
        return true;
      } else if (result.isPermanentlyDenied) {
        // Mostrar diálogo para ir a configuración
        if (context.mounted) {
          _showOpenSettingsDialog(context);
        }
        return false;
      } else {
        print('❌ Permiso de notificaciones denegado');
        return false;
      }
    }
    
    if (status.isPermanentlyDenied) {
      // Mostrar diálogo para ir a configuración
      if (context.mounted) {
        _showOpenSettingsDialog(context);
      }
      return false;
    }
    
    return false;
  }
  
  /// Muestra un diálogo para abrir la configuración de la app
  static Future<void> _showOpenSettingsDialog(BuildContext context) async {
    if (!context.mounted) return;
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚙️ Permiso Requerido'),
        content: const Text(
          'Las notificaciones están desactivadas. '
          'Para poder recibir notificaciones cuando se procesen vouchers, '
          'necesitas activarlas manualmente en la configuración de la app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Abrir Configuración'),
          ),
        ],
      ),
    );
  }
  
  /// Verifica si el permiso de notificaciones está concedido
  static Future<bool> isNotificationPermissionGranted() async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }
}
