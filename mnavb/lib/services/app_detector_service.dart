import 'package:flutter/services.dart';

class AppDetectorService {
  static const platform = MethodChannel('app_detector');

  /// Obtiene la lista de aplicaciones bancarias instaladas en el dispositivo
  Future<List<Map<String, String>>> getInstalledBankApps() async {
    try {
      final List<dynamic> result = await platform.invokeMethod('getInstalledBankApps');
      return result.map((app) => Map<String, String>.from(app)).toList();
    } on PlatformException catch (e) {
      print("Error al obtener apps bancarias: ${e.message}");
      return [];
    }
  }
}
