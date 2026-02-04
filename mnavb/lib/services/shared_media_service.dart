import 'dart:async';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../models/voucher_model.dart';
import 'voucher_processing_service.dart';

/// Servicio para manejar archivos compartidos con la app
class SharedMediaService {
  final VoucherProcessingService _voucherService = VoucherProcessingService();
  
  StreamSubscription? _intentDataStreamSubscription;
  
  // Stream controller para notificar cuando se procesa un voucher
  final _voucherStreamController = StreamController<VoucherModel?>.broadcast();
  Stream<VoucherModel?> get voucherStream => _voucherStreamController.stream;

  /// Inicializa el servicio y escucha por imágenes compartidas
  void initialize() {
    // Para imágenes compartidas mientras la app está cerrada
    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      if (value.isNotEmpty) {
        _procesarMediaCompartida(value);
      }
    });

    // Para imágenes compartidas mientras la app está abierta
    _intentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      (value) {
        if (value.isNotEmpty) {
          _procesarMediaCompartida(value);
        }
      },
      onError: (err) {
        print('Error recibiendo media compartida: $err');
      },
    );
  }

  /// Procesa archivos de medios compartidos
  Future<void> _procesarMediaCompartida(List<SharedMediaFile> archivos) async {
    print('=== ARCHIVOS COMPARTIDOS RECIBIDOS ===');
    print('Total: ${archivos.length}');
    
    for (var archivo in archivos) {
      print('Tipo: ${archivo.type}');
      print('Path: ${archivo.path}');
      
      // Verificar que sea una imagen
      if (archivo.type == SharedMediaType.image && archivo.path.isNotEmpty) {
        await _procesarImagenVoucher(archivo.path);
      }
    }
  }

  /// Procesa una imagen de voucher
  Future<void> _procesarImagenVoucher(String imagePath) async {
    print('Procesando imagen: $imagePath');
    
    try {
      // Procesar la imagen con OCR
      final voucher = await _voucherService.procesarVoucher(imagePath);
      
      if (voucher != null) {
        print('✅ Voucher procesado exitosamente:');
        print(voucher);
        
        // Notificar a los listeners
        _voucherStreamController.add(voucher);
      } else {
        print('❌ No se pudo procesar el voucher');
        _voucherStreamController.add(null);
      }
    } catch (e) {
      print('Error procesando voucher: $e');
      _voucherStreamController.add(null);
    }
  }

  /// Libera los recursos
  void dispose() {
    _intentDataStreamSubscription?.cancel();
    _voucherStreamController.close();
    _voucherService.dispose();
  }
}
