import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/firebase_service.dart';

enum KpiHistoryType { ingresos, gastos, prestamos, transferencias }

class KpiHistoryView extends StatefulWidget {
  final KpiHistoryType type;
  final String title;
  final (DateTime, DateTime)? initialDateRange;

  const KpiHistoryView({
    super.key,
    required this.type,
    required this.title,
    this.initialDateRange,
  });

  @override
  State<KpiHistoryView> createState() => _KpiHistoryViewState();
}

class _KpiHistoryViewState extends State<KpiHistoryView> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _searchController = TextEditingController();
  late final Stream<List<Map<String, dynamic>>> _itemsStream;

  DateTime? _from;
  DateTime? _to;
  String _bankFilter = 'Todos';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _from = null;
    _to = null;
    _itemsStream = _streamForType();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<List<Map<String, dynamic>>> _streamForType() {
    switch (widget.type) {
      case KpiHistoryType.ingresos:
        return _firebaseService.getIngresosStream();
      case KpiHistoryType.gastos:
        return _firebaseService.getGastosStream();
      case KpiHistoryType.prestamos:
        return _firebaseService.getPrestamosStream();
      case KpiHistoryType.transferencias:
        return _firebaseService.getTransferenciasStream();
    }
  }

  bool _passesDate(DateTime fecha) {
    if (_from == null && _to == null) return true;
    if (_from != null && fecha.isBefore(DateTime(_from!.year, _from!.month, _from!.day))) return false;
    if (_to != null && fecha.isAfter(DateTime(_to!.year, _to!.month, _to!.day, 23, 59, 59))) return false;
    return true;
  }

  DateTime _fechaFromItem(Map<String, dynamic> item) {
    final raw = item['fecha'];
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return DateTime.now();
  }

  String _normalizeBank(String? v) => (v ?? '').trim().toLowerCase();

  bool _matchesBank(Map<String, dynamic> item) {
    if (_bankFilter == 'Todos') return true;
    if (widget.type == KpiHistoryType.transferencias) {
      final origen = (item['bancoOrigenNombre'] as String?) ?? '';
      final destino = (item['bancoDestinoNombre'] as String?) ?? '';
      final selected = _normalizeBank(_bankFilter);
      return _normalizeBank(origen) == selected || _normalizeBank(destino) == selected;
    }
    return _normalizeBank((item['bancoNombre'] as String?) ?? '') == _normalizeBank(_bankFilter);
  }

  bool _matchesSearch(Map<String, dynamic> item) {
    final q = _searchQuery;
    if (q.isEmpty) return true;

    final values = <String>[
      (item['categoria'] as String?) ?? '',
      (item['descripcion'] as String?) ?? '',
      (item['nombrePrestatario'] as String?) ?? '',
      (item['bancoNombre'] as String?) ?? '',
      (item['bancoOrigenNombre'] as String?) ?? '',
      (item['bancoDestinoNombre'] as String?) ?? '',
    ];

    return values.any((v) => v.toLowerCase().contains(q));
  }

  Future<void> _pickSingleDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _from ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
    );
    if (date == null) return;
    setState(() {
      _from = DateTime(date.year, date.month, date.day);
      _to = DateTime(date.year, date.month, date.day, 23, 59, 59);
    });
  }

  String _fmtDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yy = d.year.toString();
    return '$dd/$mm/$yy';
  }

  String get _rangeLabel {
    if (_from == null && _to == null) return 'Rango: —';
    if (_from != null && _to == null) return 'Desde: ${_fmtDate(_from!)}';
    if (_from == null && _to != null) return 'Hasta: ${_fmtDate(_to!)}';
    return '${_fmtDate(_from!)}  →  ${_fmtDate(_to!)}';
  }

  Future<(DateTime?, DateTime?)?> _openRangePopup() async {
    DateTime? tempFrom = _from;
    DateTime? tempTo = _to;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final card = isDark ? const Color(0xFF1C1D22) : Colors.white;
    final stroke = isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08);

    return showDialog<(DateTime?, DateTime?)>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: isDark ? 0.50 : 0.25),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 170, right: 16, left: 16),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: 360,
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: stroke),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.18),
                          blurRadius: 22,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: _KpiInlineRangePicker(
                        from: tempFrom,
                        to: tempTo,
                        isDark: isDark,
                        border: stroke,
                        onFromChanged: (d) => setDialogState(() => tempFrom = d),
                        onToChanged: (d) => setDialogState(() => tempTo = d),
                        onClear: () => setDialogState(() {
                          tempFrom = null;
                          tempTo = null;
                        }),
                        onClose: () => Navigator.pop(context, (tempFrom, tempTo)),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteRecord(Map<String, dynamic> item) async {
    final id = item['id'] as String?;
    if (id == null || id.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: const Text('¿Deseas eliminar este registro?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      switch (widget.type) {
        case KpiHistoryType.ingresos:
          await _firebaseService.eliminarIngreso(ingresoId: id);
          break;
        case KpiHistoryType.gastos:
          await _firebaseService.eliminarGasto(gastoId: id);
          break;
        case KpiHistoryType.prestamos:
          await _firebaseService.eliminarPrestamo(prestamoId: id);
          break;
        case KpiHistoryType.transferencias:
          await _firebaseService.eliminarTransferencia(transferenciaId: id);
          break;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Registro eliminado'),
          backgroundColor: Colors.green.shade600,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  Future<void> _openBankSelector() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _KpiBankSelectorSheet(selectedBank: _bankFilter),
    );

    if (selected == null) return;
    setState(() => _bankFilter = selected);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _itemsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final all = snapshot.data ?? [];
            final items = all.where((e) {
              final fecha = _fechaFromItem(e);
              return _passesDate(fecha) && _matchesBank(e) && _matchesSearch(e);
            }).toList()
              ..sort((a, b) => _fechaFromItem(b).compareTo(_fechaFromItem(a)));

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() => _searchQuery = value.trim().toLowerCase());
                    },
                    decoration: InputDecoration(
                      hintText: 'Buscar por banco, descripción o categoría',
                      prefixIcon: const Icon(Icons.search_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      isDense: true,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _rangeLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark ? Colors.white70 : Colors.black54,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _MiniActionButton(label: 'Fecha', onTap: _pickSingleDate),
                      const SizedBox(width: 8),
                      _MiniActionButton(
                        label: 'Rango',
                        onTap: () async {
                          final res = await _openRangePopup();
                          if (res == null) return;

                          if (res.$1 != null && res.$2 != null && res.$1!.isAfter(res.$2!)) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('La fecha de inicio no puede ser mayor a la fecha de fin'),
                                backgroundColor: Colors.red.shade600,
                              ),
                            );
                            return;
                          }

                          setState(() {
                            _from = res.$1 == null
                                ? null
                                : DateTime(res.$1!.year, res.$1!.month, res.$1!.day, 0, 0, 0);
                            _to = res.$2 == null
                                ? null
                                : DateTime(res.$2!.year, res.$2!.month, res.$2!.day, 23, 59, 59);
                          });
                        },
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _firebaseService.getBancosStream(),
                    builder: (context, bancosSnapshot) {
                      final bancos = bancosSnapshot.data ?? [];
                      final bankFilterActive = _bankFilter != 'Todos';
                      Map<String, dynamic>? selectedBanco;
                      for (final b in bancos) {
                        if (_normalizeBank((b['nombre'] as String?)) == _normalizeBank(_bankFilter)) {
                          selectedBanco = b;
                          break;
                        }
                      }

                      final activeBorder = bankFilterActive
                          ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.45 : 0.35)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.black.withValues(alpha: 0.08));
                      final activeBg = bankFilterActive
                          ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.14 : 0.08)
                          : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white);

                      return InkWell(
                        onTap: _openBankSelector,
                        borderRadius: BorderRadius.circular(14),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: activeBorder, width: bankFilterActive ? 1.4 : 1),
                            color: activeBg,
                          ),
                          child: Row(
                            children: [
                              if (selectedBanco != null)
                                _BankCircleLogo(logo: (selectedBanco['logo'] as String?) ?? '')
                              else
                                const Icon(Icons.account_balance_rounded),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Banco',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: isDark ? Colors.white70 : Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            _bankFilter,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                                          ),
                                        ),
                                        if (bankFilterActive) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.28 : 0.18),
                                              borderRadius: BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              'Activo',
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 10,
                                                color: theme.colorScheme.primary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (selectedBanco != null)
                                Text(
                                  'S/ ${((selectedBanco['saldo'] as num?) ?? 0).toDouble().toStringAsFixed(2)}',
                                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                                ),
                              if (bankFilterActive) ...[
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => setState(() => _bankFilter = 'Todos'),
                                  borderRadius: BorderRadius.circular(999),
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.10),
                                    ),
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 14,
                                      color: isDark ? Colors.white70 : Colors.black54,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(width: 6),
                              const Icon(Icons.keyboard_arrow_down_rounded),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: items.isEmpty
                      ? Center(
                          child: Text(
                            'No hay registros con esos filtros',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemBuilder: (context, index) => _HistoryCard(
                            item: items[index],
                            type: widget.type,
                            onDelete: () => _deleteRecord(items[index]),
                          ),
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemCount: items.length,
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MiniActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _MiniActionButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
        ),
        child: Text(label, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class _KpiInlineRangePicker extends StatelessWidget {
  final DateTime? from;
  final DateTime? to;
  final bool isDark;
  final Color border;
  final ValueChanged<DateTime> onFromChanged;
  final ValueChanged<DateTime> onToChanged;
  final VoidCallback onClear;
  final VoidCallback onClose;

  const _KpiInlineRangePicker({
    required this.from,
    required this.to,
    required this.isDark,
    required this.border,
    required this.onFromChanged,
    required this.onToChanged,
    required this.onClear,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = isDark ? Colors.white.withValues(alpha: 0.85) : Colors.black.withValues(alpha: 0.75);
    final muted = isDark ? Colors.white.withValues(alpha: 0.65) : Colors.black.withValues(alpha: 0.55);

    final now = DateTime.now();
    final first = DateTime(now.year - 5, 1, 1);
    final last = DateTime(now.year + 1, 12, 31);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Selecciona rango',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          'Toca las fechas para definir inicio y fin del periodo.',
          style: theme.textTheme.bodySmall?.copyWith(color: muted),
        ),
        const SizedBox(height: 12),

        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border, width: 1.5),
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.02),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                  border: Border(bottom: BorderSide(color: border)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _KpiDateChip(
                      label: 'Inicio',
                      date: from,
                      muted: muted,
                      isDark: isDark,
                    ),
                    Icon(Icons.arrow_forward_rounded, color: muted, size: 16),
                    _KpiDateChip(
                      label: 'Fin',
                      date: to,
                      muted: muted,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: _KpiCompactRangeCalendar(
                  from: from,
                  to: to,
                  onFromChanged: onFromChanged,
                  onToChanged: onToChanged,
                  firstDate: first,
                  lastDate: last,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: onClear,
              icon: Icon(Icons.refresh_rounded, color: fg, size: 18),
              label: Text(
                'Limpiar',
                style: theme.textTheme.bodyMedium?.copyWith(color: fg, fontWeight: FontWeight.w700),
              ),
            ),
            ElevatedButton.icon(
              onPressed: onClose,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Aplicar'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _KpiDateChip extends StatelessWidget {
  final String label;
  final DateTime? date;
  final Color muted;
  final bool isDark;

  const _KpiDateChip({
    required this.label,
    required this.date,
    required this.muted,
    required this.isDark,
  });

  String _fmt(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: muted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            date == null ? '—' : _fmt(date!),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiCompactRangeCalendar extends StatefulWidget {
  final DateTime? from;
  final DateTime? to;
  final ValueChanged<DateTime> onFromChanged;
  final ValueChanged<DateTime> onToChanged;
  final DateTime firstDate;
  final DateTime lastDate;
  final bool isDark;

  const _KpiCompactRangeCalendar({
    required this.from,
    required this.to,
    required this.onFromChanged,
    required this.onToChanged,
    required this.firstDate,
    required this.lastDate,
    required this.isDark,
  });

  @override
  State<_KpiCompactRangeCalendar> createState() => _KpiCompactRangeCalendarState();
}

class _KpiCompactRangeCalendarState extends State<_KpiCompactRangeCalendar> {
  late DateTime _currentMonth;
  bool _selectingFrom = true;

  @override
  void initState() {
    super.initState();
    _currentMonth = widget.from ?? widget.to ?? DateTime.now();
  }

  void _onDateTapped(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);

    if (_selectingFrom || widget.from == null) {
      widget.onFromChanged(normalizedDate);
      setState(() => _selectingFrom = false);
    } else {
      if (normalizedDate.isBefore(widget.from!)) {
        widget.onFromChanged(normalizedDate);
      } else {
        widget.onToChanged(normalizedDate);
      }
      setState(() => _selectingFrom = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CalendarDatePicker(
      initialDate: _currentMonth,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
      onDateChanged: _onDateTapped,
    );
  }
}

class _KpiBankSelectorSheet extends StatelessWidget {
  final String selectedBank;

  const _KpiBankSelectorSheet({required this.selectedBank});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sheet = isDark ? const Color(0xFF14151A) : Colors.white;
    final stroke = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);
    final fg = isDark
        ? Colors.white.withValues(alpha: 0.88)
        : Colors.black.withValues(alpha: 0.78);
    final muted = isDark
        ? Colors.white.withValues(alpha: 0.65)
        : Colors.black.withValues(alpha: 0.55);

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: sheet,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          border: Border.all(color: stroke),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 52,
                height: 5,
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  Text(
                    'Filtrar por banco',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: fg,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Icon(Icons.close_rounded, color: muted),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: FirebaseService().getBancosStream(),
                builder: (context, snapshot) {
                  final bancos = snapshot.data ?? [];
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    shrinkWrap: true,
                    itemCount: bancos.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      if (i == 0) {
                        return _KpiBankOption(
                          nombre: 'Todos',
                          logo: '',
                          saldo: null,
                          isDark: isDark,
                          selected: selectedBank == 'Todos',
                          onTap: () => Navigator.pop(context, 'Todos'),
                        );
                      }
                      final banco = bancos[i - 1];
                      return _KpiBankOption(
                        nombre: (banco['nombre'] as String?) ?? 'Sin nombre',
                        logo: (banco['logo'] as String?) ?? '',
                        saldo: (banco['saldo'] as num?)?.toDouble() ?? 0,
                        isDark: isDark,
                        selected: selectedBank == ((banco['nombre'] as String?) ?? ''),
                        onTap: () => Navigator.pop(context, (banco['nombre'] as String?) ?? 'Todos'),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiBankOption extends StatelessWidget {
  final String nombre;
  final String logo;
  final double? saldo;
  final bool isDark;
  final bool selected;
  final VoidCallback onTap;

  const _KpiBankOption({
    required this.nombre,
    required this.logo,
    required this.saldo,
    required this.isDark,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final bg = selected
        ? accent.withValues(alpha: isDark ? 0.14 : 0.10)
        : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white);
    final stroke = selected
        ? accent.withValues(alpha: 0.35)
        : (isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.06));
    final fg = isDark
        ? Colors.white.withValues(alpha: 0.88)
        : Colors.black.withValues(alpha: 0.78);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: stroke),
        ),
        child: Row(
          children: [
            _BankCircleLogo(logo: logo),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                nombre,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: fg,
                ),
              ),
            ),
            if (saldo != null)
              Text(
                'S/ ${saldo!.toStringAsFixed(2)}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: accent,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BankCircleLogo extends StatelessWidget {
  final String logo;

  const _BankCircleLogo({required this.logo});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: accent.withValues(alpha: 0.35), width: 1.8),
      ),
      child: ClipOval(
        child: logo.isEmpty
            ? Icon(Icons.account_balance, color: accent, size: 22)
            : Image.network(
                logo,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(Icons.account_balance, color: accent, size: 22),
              ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final KpiHistoryType type;
  final VoidCallback onDelete;

  const _HistoryCard({
    required this.item,
    required this.type,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.07);
    final bg = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03);
    final fecha = item['fecha'] is Timestamp
        ? (item['fecha'] as Timestamp).toDate()
        : DateTime.now();

    final monto = ((item['monto'] as num?) ?? 0).toDouble();
    final logo = _logoForType(item, type);
    final titulo = _titleForType(item, type);
    final subtitulo = _subtitleForType(item, type);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          _CircleLogo(logo: logo),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(subtitulo, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(DateFormat('dd/MM/yyyy HH:mm').format(fecha), style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'S/ ${monto.toStringAsFixed(2)}',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: onDelete,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.delete_outline_rounded, color: Colors.red.shade700, size: 17),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _logoForType(Map<String, dynamic> i, KpiHistoryType t) {
    if (t == KpiHistoryType.transferencias) {
      return (i['bancoOrigenLogo'] as String?) ?? '';
    }
    return (i['bancoLogo'] as String?) ?? '';
  }

  String _titleForType(Map<String, dynamic> i, KpiHistoryType t) {
    switch (t) {
      case KpiHistoryType.ingresos:
        return 'Ingreso';
      case KpiHistoryType.gastos:
        return 'Gasto';
      case KpiHistoryType.prestamos:
        return 'Préstamo';
      case KpiHistoryType.transferencias:
        return 'Transferencia';
    }
  }

  String _subtitleForType(Map<String, dynamic> i, KpiHistoryType t) {
    switch (t) {
      case KpiHistoryType.ingresos:
      case KpiHistoryType.gastos:
        return '${(i['bancoNombre'] as String?) ?? 'Sin banco'} • ${(i['categoria'] as String?) ?? 'Sin categoría'}';
      case KpiHistoryType.prestamos:
        return '${(i['nombrePrestatario'] as String?) ?? 'Sin nombre'} • ${(i['descripcion'] as String?) ?? 'Sin descripción'}';
      case KpiHistoryType.transferencias:
        return '${(i['bancoOrigenNombre'] as String?) ?? 'Origen'} → ${(i['bancoDestinoNombre'] as String?) ?? 'Destino'}';
    }
  }
}

class _CircleLogo extends StatelessWidget {
  final String logo;

  const _CircleLogo({required this.logo});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = theme.colorScheme.primary;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: active.withValues(alpha: 0.30), width: 1.5),
      ),
      child: ClipOval(
        child: Image.network(
          logo,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(Icons.account_balance, color: active, size: 19),
        ),
      ),
    );
  }
}
