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

  @override
  void initState() {
    super.initState();
    _load();
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

    final content = _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _load,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          )
        : Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Completa categoria y subcategoria para enviar el voucher.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                _InfoTile(
                  label: 'Monto',
                  value:
                      '${_pending!.moneda} ${formatAmount(_pending!.monto)}',
                ),
                _InfoTile(label: 'Descripcion', value: _pending!.descripcion),
                _InfoTile(label: 'Fecha', value: _formatDate(_pending!.fecha)),
                _InfoTile(label: 'Origen', value: _pending!.bancoNombre),
                const SizedBox(height: 16),
                DropdownButtonFormField<ExternalApiCategoria>(
                  initialValue: _categoria,
                  decoration: const InputDecoration(
                    labelText: 'Categoria principal',
                  ),
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
                  decoration: const InputDecoration(labelText: 'Subcategoria'),
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
                  child: ElevatedButton(
                    onPressed: _sending || _subcategoria == null
                        ? null
                        : _confirm,
                    child: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Confirmar y enviar a API'),
                  ),
                ),
              ],
            ),
          );

    if (!widget.isOverlay) {
      return Scaffold(
        appBar: AppBar(title: const Text('Confirmar voucher API')),
        body: content,
      );
    }

    return Scaffold(
      backgroundColor: Colors.black54,
      body: SafeArea(
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(16),
            constraints: const BoxConstraints(maxWidth: 460),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Row(
                      children: [
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
    );
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$d/$m/$y';
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;

  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
