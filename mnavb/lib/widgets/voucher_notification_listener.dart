import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/voucher_provider.dart';

/// Widget que muestra notificaciones cuando se procesan vouchers
class VoucherNotificationListener extends StatefulWidget {
  final Widget child;

  const VoucherNotificationListener({
    super.key,
    required this.child,
  });

  @override
  State<VoucherNotificationListener> createState() => _VoucherNotificationListenerState();
}

class _VoucherNotificationListenerState extends State<VoucherNotificationListener> {
  @override
  void initState() {
    super.initState();
    
    // Escuchar cambios en el VoucherProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final voucherProvider = context.read<VoucherProvider>();
      voucherProvider.addListener(_onVoucherUpdate);
    });
  }

  void _onVoucherUpdate() {
    final voucherProvider = context.read<VoucherProvider>();
    
    // Mostrar mensaje de éxito
    if (voucherProvider.mensajeExito != null) {
      _mostrarSnackBar(
        voucherProvider.mensajeExito!,
        Colors.green,
        Icons.check_circle,
      );
      voucherProvider.limpiarMensajes();
    }
    
    // Mostrar mensaje de error
    if (voucherProvider.mensajeError != null) {
      _mostrarSnackBar(
        voucherProvider.mensajeError!,
        Colors.red,
        Icons.error,
      );
      voucherProvider.limpiarMensajes();
    }
  }

  void _mostrarSnackBar(String mensaje, Color color, IconData icon) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                mensaje,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void dispose() {
    final voucherProvider = context.read<VoucherProvider>();
    voucherProvider.removeListener(_onVoucherUpdate);
    super.dispose();
  }
}
