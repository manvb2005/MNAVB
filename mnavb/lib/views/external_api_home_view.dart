import 'package:flutter/material.dart';

import '../app/app_routes.dart';
import '../services/external_api_voucher_service.dart';
import '../services/firebase_service.dart';
import '../services/pending_external_voucher_service.dart';
import '../utils/auth_background.dart';
import '../utils/currency_formatter.dart';

class ExternalApiHomeView extends StatefulWidget {
  const ExternalApiHomeView({super.key});

  @override
  State<ExternalApiHomeView> createState() => _ExternalApiHomeViewState();
}

class _ExternalApiHomeViewState extends State<ExternalApiHomeView> {
  final _apiService = ExternalApiVoucherService();
  final _pendingService = PendingExternalVoucherService();

  ExternalApiBalance? _balance;
  PendingExternalVoucher? _pending;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pending = await _pendingService.get();

    try {
      final balance = await _apiService.getBalance();
      if (!mounted) return;
      setState(() {
        _balance = balance;
        _pending = pending;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pending = pending;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: AuthBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withAlpha((0.14 * 255).toInt())
                      : Colors.black.withAlpha((0.10 * 255).toInt()),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Conexion externa activa',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Tu cuenta esta configurada para usar API externa. Por ahora se soporta Yapeaste (gasto). Comparte el voucher y luego confirma categoria/subcategoria para enviarlo a tu API.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 14),
                  if (_loading)
                    const Center(child: CircularProgressIndicator())
                  else if (_balance != null)
                    Text(
                      'Balance API: ${_balance!.moneda} ${formatAmount(_balance!.saldoTotal)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  if (_pending != null)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Text(
                        'Hay un voucher pendiente. Usa la notificacion "Confirmar voucher API" para abrir el overlay.',
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await FirebaseService().logout();
                        if (!context.mounted) return;
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          AppRoutes.login,
                          (_) => false,
                        );
                      },
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Cerrar sesion'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
