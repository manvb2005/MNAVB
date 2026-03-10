import 'package:flutter/material.dart';

import '../app/app_routes.dart';
import '../services/external_api_voucher_service.dart';
import '../services/pending_external_voucher_service.dart';
import '../utils/currency_formatter.dart';
import '../utils/system_notifications.dart';

class ExternalApiVoucherConfirmView extends StatefulWidget {
  final bool isOverlay;

  const ExternalApiVoucherConfirmView({super.key, this.isOverlay = false});

  @override
  State<ExternalApiVoucherConfirmView> createState() =>
      _ExternalApiVoucherConfirmViewState();
}

class _ExternalApiVoucherConfirmViewState
    extends State<ExternalApiVoucherConfirmView> {
  final _apiService = ExternalApiVoucherService();
  final _pendingService = PendingExternalVoucherService();

  PendingExternalVoucher? _pending;
  List<ExternalApiCategoria> _categorias = const [];
  ExternalApiCategoria? _categoria;
  ExternalApiSubcategoria? _subcategoria;
  bool _loading = true;
  bool _sending = false;
  String? _error;
  bool _animateIn = false;

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _animateIn = true);
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      PendingExternalVoucher? pending;
      for (var i = 0; i < 10; i++) {
        pending = await _pendingService.get();
        if (pending != null) break;
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }

      if (pending == null) {
        setState(() {
          _loading = false;
          _error = 'No hay voucher pendiente por confirmar.';
        });
        return;
      }

      final categorias = await _apiService.getCategorias();
      if (categorias.isEmpty) {
        throw Exception('La API no devolvio categorias');
      }

      final categoria = categorias.first;
      final sub = categoria.subcategorias.isNotEmpty
          ? categoria.subcategorias.first
          : null;

      setState(() {
        _pending = pending;
        _categorias = categorias;
        _categoria = categoria;
        _subcategoria = sub;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _confirm() async {
    if (_pending == null || _categoria == null || _subcategoria == null) return;

    setState(() => _sending = true);
    try {
      await SystemNotifications.showProcessing(_pending!.notificationId);
      await _apiService.sendVoucherGasto(
        monto: _pending!.monto,
        categoriaPrincipalId: _categoria!.id,
        subcategoriaId: _subcategoria!.id,
        descripcion: _pending!.descripcion,
        fecha: _pending!.fecha,
        moneda: _pending!.moneda,
      );

      await _pendingService.clear();
      await SystemNotifications.showSuccess(
        _pending!.notificationId,
        'Gasto enviado a API externa: ${_pending!.moneda} ${formatAmount(_pending!.monto)}',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voucher enviado correctamente a la API.'),
        ),
      );
      if (widget.isOverlay && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      } else {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.externalApiHome,
          (_) => false,
        );
      }
    } catch (e) {
      await SystemNotifications.showError(
        _pending?.notificationId ?? 9999,
        e.toString().replaceAll('Exception: ', ''),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final content = _loading
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                const SizedBox(height: 14),
                Text(
                  'Cargando datos del voucher...',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          )
        : _error != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cs.errorContainer.withAlpha((0.55 * 255).toInt()),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: cs.error.withAlpha((0.35 * 255).toInt()),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded, color: cs.error, size: 26),
                    const SizedBox(height: 10),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),
          )
        : Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withAlpha((0.55 * 255).toInt()),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: cs.outlineVariant.withAlpha((0.5 * 255).toInt()),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: cs.primary.withAlpha((0.12 * 255).toInt()),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.receipt_long_rounded,
                          color: cs.primary,
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Completa categoria y subcategoria para enviar el voucher.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: cs.outlineVariant.withAlpha((0.5 * 255).toInt()),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha((0.04 * 255).toInt()),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _InfoTile(
                        icon: Icons.payments_rounded,
                        label: 'Monto',
                        value:
                            '${_pending!.moneda} ${formatAmount(_pending!.monto)}',
                      ),
                      _InfoTile(
                        icon: Icons.notes_rounded,
                        label: 'Descripcion',
                        value: _pending!.descripcion,
                      ),
                      _InfoTile(
                        icon: Icons.calendar_month_rounded,
                        label: 'Fecha',
                        value: _formatDate(_pending!.fecha),
                      ),
                      _InfoTile(
                        icon: Icons.account_balance_rounded,
                        label: 'Origen',
                        value: _pending!.bancoNombre,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<ExternalApiCategoria>(
                  initialValue: _categoria,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  decoration: _inputDecoration(theme, 'Categoria principal'),
                  items: _categorias
                      .map(
                        (c) =>
                            DropdownMenuItem(value: c, child: Text(c.nombre)),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _categoria = value;
                      _subcategoria = value.subcategorias.isNotEmpty
                          ? value.subcategorias.first
                          : null;
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ExternalApiSubcategoria>(
                  initialValue: _subcategoria,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  decoration: _inputDecoration(theme, 'Subcategoria'),
                  items:
                      (_categoria?.subcategorias ??
                              const <ExternalApiSubcategoria>[])
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(s.nombre),
                            ),
                          )
                          .toList(),
                  onChanged: (value) => setState(() => _subcategoria = value),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _sending || _subcategoria == null
                        ? null
                        : _confirm,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(
                      _sending
                          ? 'Enviando...'
                          : 'Confirmar y enviar a API',
                    ),
                  ),
                ),
              ],
            ),
          );

    if (!widget.isOverlay) {
      return Scaffold(
        appBar: AppBar(title: const Text('Confirmar voucher API')),
        body: AnimatedSlide(
          offset: _animateIn ? Offset.zero : const Offset(0, 0.03),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: _animateIn ? 1 : 0,
            duration: const Duration(milliseconds: 220),
            child: content,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black.withAlpha((0.46 * 255).toInt()),
      body: SafeArea(
        child: Center(
          child: AnimatedScale(
            scale: _animateIn ? 1 : 0.98,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: _animateIn ? 1 : 0,
              duration: const Duration(milliseconds: 220),
              child: Container(
                margin: const EdgeInsets.all(16),
                constraints: const BoxConstraints(maxWidth: 480),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withAlpha(
                      (0.55 * 255).toInt(),
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha((0.20 * 255).toInt()),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.surfaceContainerHighest,
                              theme.colorScheme.surfaceContainer,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.shield_moon_rounded, size: 18),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Confirmar voucher API',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(context).maybePop(),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      ),
                      Flexible(child: content),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$d/$m/$y';
  }

  InputDecoration _inputDecoration(ThemeData theme, String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: theme.colorScheme.surfaceContainerHighest.withAlpha(
        (0.35 * 255).toInt(),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: theme.colorScheme.outlineVariant.withAlpha((0.6 * 255).toInt()),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: theme.colorScheme.outlineVariant.withAlpha((0.6 * 255).toInt()),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withAlpha((0.12 * 255).toInt()),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 95,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
