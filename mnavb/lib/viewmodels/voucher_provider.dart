import 'package:flutter/material.dart';
import '../models/voucher_model.dart';
import '../services/shared_media_service.dart';
import '../services/firebase_service.dart';
import '../utils/currency_formatter.dart';

/// Provider para manejar el procesamiento automático de vouchers
class VoucherProvider extends ChangeNotifier {
  final SharedMediaService _sharedMediaService = SharedMediaService();
  final FirebaseService _firebaseService = FirebaseService();
  
  VoucherModel? _ultimoVoucher;
  bool _procesando = false;
  String? _mensajeError;
  String? _mensajeExito;

  VoucherModel? get ultimoVoucher => _ultimoVoucher;
  bool get procesando => _procesando;
  String? get mensajeError => _mensajeError;
  String? get mensajeExito => _mensajeExito;

  VoucherProvider() {
    _inicializar();
  }

  void _inicializar() {
    _sharedMediaService.initialize();
    
    // Escuchar por vouchers procesados
    _sharedMediaService.voucherStream.listen((voucher) {
      if (voucher != null) {
        _procesarVoucherAutomaticamente(voucher);
      } else {
        _mensajeError = 'No se pudo procesar el voucher. Verifica que sea una imagen válida de Yape.';
        notifyListeners();
      }
    });
  }

  /// Procesa automáticamente un voucher y lo guarda como gasto/ingreso
  Future<void> _procesarVoucherAutomaticamente(VoucherModel voucher) async {
    _procesando = true;
    _ultimoVoucher = voucher;
    _mensajeError = null;
    _mensajeExito = null;
    notifyListeners();

    try {
      // Verificar que el usuario tenga el banco registrado
      final bancos = await _firebaseService.getBancosStream().first;
      
      final bancoEncontrado = bancos.where((b) {
        final nombre = (b['nombre'] as String?)?.toLowerCase() ?? '';
        return nombre == voucher.banco.toLowerCase();
      }).toList();

      if (bancoEncontrado.isEmpty) {
        _mensajeError = 'No tienes un banco "${voucher.banco}" registrado. Por favor, agrega uno desde la sección Bancos.';
        _procesando = false;
        notifyListeners();
        return;
      }

      final banco = bancoEncontrado.first;
      
      // Preparar datos para guardar
      final bancoId = banco['id'] as String;
      final bancoNombre = banco['nombre'] as String;
      final bancoLogo = banco['logo'] as String;
      final tipoCuenta = banco['tipoCuenta'] as String;
      
      // Determinar categoría (puedes mejorar esto con lógica más específica)
      final categoria = voucher.descripcion?.isNotEmpty == true 
          ? voucher.descripcion! 
          : (voucher.esGasto ? 'Otros' : 'Ingreso varios');
      
      final descripcion = voucher.descripcion ?? 
          '${voucher.tipoTransaccion} - ${voucher.numeroOperacion ?? "Sin número"}';
      
      final fecha = voucher.fecha ?? DateTime.now();

      // Guardar según el tipo de transacción
      if (voucher.esGasto) {
        await _firebaseService.registrarGasto(
          bancoId: bancoId,
          bancoNombre: bancoNombre,
          bancoLogo: bancoLogo,
          tipoCuenta: tipoCuenta,
          categoria: categoria,
          descripcion: descripcion,
          monto: voucher.monto,
          fecha: fecha,
        );
        
        _mensajeExito =
            '✅ Gasto de ${formatMoney(voucher.monto)} guardado automáticamente';
      } else {
        await _firebaseService.registrarIngreso(
          bancoId: bancoId,
          bancoNombre: bancoNombre,
          bancoLogo: bancoLogo,
          tipoCuenta: tipoCuenta,
          categoria: categoria,
          descripcion: descripcion,
          monto: voucher.monto,
          fecha: fecha,
        );
        
        _mensajeExito =
            '✅ Ingreso de ${formatMoney(voucher.monto)} guardado automáticamente';
      }

      print('✅ Transacción guardada exitosamente');
      
    } catch (e) {
      _mensajeError = 'Error al guardar: $e';
      print('Error guardando voucher: $e');
    } finally {
      _procesando = false;
      notifyListeners();
    }
  }

  /// Limpia mensajes
  void limpiarMensajes() {
    _mensajeError = null;
    _mensajeExito = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sharedMediaService.dispose();
    super.dispose();
  }
}
