import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'bancos_view.dart';
import 'kpi_history_view.dart';
import '../services/firebase_service.dart';

enum SummaryRange { today, week, month, year }

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final _firebaseService = FirebaseService();
  int _selectedBankIndex = 0;
  String? _selectedBankId;

  // Resumen: hoy/semana/mes/año
  SummaryRange _summaryRange = SummaryRange.today;

  // Fechas del calendario para estadística
  DateTime? _fromDate;
  DateTime? _toDate;

  // Método para calcular el rango de fechas según el filtro seleccionado
  (DateTime, DateTime) _getDateRangeForSummary() {
    final now = DateTime.now();
    switch (_summaryRange) {
      case SummaryRange.today:
        final start = DateTime(now.year, now.month, now.day, 0, 0, 0);
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        return (start, end);

      case SummaryRange.week:
        // Última semana (7 días incluyendo hoy)
        final start = DateTime(now.year, now.month, now.day - 6, 0, 0, 0);
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        return (start, end);

      case SummaryRange.month:
        // Mes actual
        final start = DateTime(now.year, now.month, 1, 0, 0, 0);
        final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        return (start, end);

      case SummaryRange.year:
        // Año actual
        final start = DateTime(now.year, 1, 1, 0, 0, 0);
        final end = DateTime(now.year, 12, 31, 23, 59, 59);
        return (start, end);
    }
  }

  String get _summaryRangeLabel {
    switch (_summaryRange) {
      case SummaryRange.today:
        return 'Hoy';
      case SummaryRange.week:
        return 'Semana';
      case SummaryRange.month:
        return 'Mes';
      case SummaryRange.year:
        return 'Año';
    }
  }

  String _fmtDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yy = d.year.toString();
    return '$dd/$mm/$yy';
  }

  String get _statsRangeLabel {
    if (_fromDate == null && _toDate == null) return 'Rango: —';
    if (_fromDate != null && _toDate == null)
      return 'Desde: ${_fmtDate(_fromDate!)}';
    if (_fromDate == null && _toDate != null)
      return 'Hasta: ${_fmtDate(_toDate!)}';
    return '${_fmtDate(_fromDate!)}  →  ${_fmtDate(_toDate!)}';
  }

  Future<(DateTime?, DateTime?)?> _openStatsCalendarPopup(
    BuildContext context,
  ) async {
    DateTime? tempFrom = _fromDate;
    DateTime? tempTo = _toDate;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Fondos sólidos para el popup
    final card = isDark ? const Color(0xFF1C1D22) : Colors.white;
    final stroke = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);

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
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.40 : 0.18,
                          ),
                          blurRadius: 22,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: _InlineRangePicker(
                        border: stroke,
                        muted: isDark
                            ? Colors.white.withValues(alpha: 0.65)
                            : Colors.black.withValues(alpha: 0.55),
                        isDark: isDark,
                        from: tempFrom,
                        to: tempTo,
                        onFromChanged: (d) =>
                            setDialogState(() => tempFrom = d),
                        onToChanged: (d) => setDialogState(() => tempTo = d),
                        onClear: () => setDialogState(() {
                          tempFrom = null;
                          tempTo = null;
                        }),
                        onClose: () =>
                            Navigator.pop(context, (tempFrom, tempTo)),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final active = theme.colorScheme.primary;

    // Tokens estilo "soft UI" (blanco/negro + grises)
    final surface = isDark ? const Color(0xFF0E0F12) : const Color(0xFFF7F7F9);
    final card = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white;
    final stroke = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.06);
    final soft = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.black.withValues(alpha: 0.03);
    final muted = isDark
        ? Colors.white.withValues(alpha: 0.65)
        : Colors.black.withValues(alpha: 0.55);

    // Obtener el rango de fechas según el filtro seleccionado
    final dateRange = _getDateRangeForSummary();

    return SafeArea(
      child: Scaffold(
        backgroundColor: surface,
        body: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _firebaseService.getBancosStream(),
          builder: (context, bancosSnapshot) {
            if (bancosSnapshot.hasError) {
              return Center(child: Text('Error: ${bancosSnapshot.error}'));
            }

            final bancos = bancosSnapshot.data ?? [];

            // Si cambiamos de banco y el índice ya no es válido, resetear
            if (_selectedBankIndex >= bancos.length && bancos.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _selectedBankIndex = 0;
                    _selectedBankId = bancos.isNotEmpty
                        ? bancos[0]['id']
                        : null;
                  });
                }
              });
            }

            // Actualizar el ID del banco seleccionado
            if (bancos.isNotEmpty &&
                (_selectedBankId == null ||
                    _selectedBankIndex < bancos.length)) {
              _selectedBankId = bancos[_selectedBankIndex]['id'];
            }

            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: _firebaseService.getIngresosStream(),
              builder: (context, ingresosSnapshot) {
                return StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _firebaseService.getGastosStream(),
                  builder: (context, gastosSnapshot) {
                    return StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _firebaseService.getTransferenciasStream(),
                      builder: (context, transferenciasSnapshot) {
                        return StreamBuilder<List<Map<String, dynamic>>>(
                          stream: _firebaseService.getPrestamosStream(),
                          builder: (context, prestamosSnapshot) {
                            // Si hay errores en alguno de los streams, mostrar indicador
                            if (ingresosSnapshot.hasError ||
                                gastosSnapshot.hasError ||
                                transferenciasSnapshot.hasError ||
                                prestamosSnapshot.hasError) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    'Error al cargar los datos',
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: muted,
                                    ),
                                  ),
                                ),
                              );
                            }

                            // Calcular KPIs
                            final ingresos = ingresosSnapshot.data ?? [];
                            final gastos = gastosSnapshot.data ?? [];
                            final transferencias =
                                transferenciasSnapshot.data ?? [];
                            final prestamos = prestamosSnapshot.data ?? [];

                            // Saldo total: suma de todos los bancos (NO cambia con el filtro)
                            final saldoTotal = bancos.fold<double>(
                              0.0,
                              (sum, banco) =>
                                  sum + (banco['saldo'] as num).toDouble(),
                            );

                            // Filtrar por rango de fechas
                            final ingresosEnRango = ingresos.where((i) {
                              final fecha = (i['fecha'] as Timestamp).toDate();
                              return fecha.isAfter(
                                    dateRange.$1.subtract(
                                      const Duration(seconds: 1),
                                    ),
                                  ) &&
                                  fecha.isBefore(
                                    dateRange.$2.add(
                                      const Duration(seconds: 1),
                                    ),
                                  );
                            }).toList();

                            final gastosEnRango = gastos.where((g) {
                              final fecha = (g['fecha'] as Timestamp).toDate();
                              return fecha.isAfter(
                                    dateRange.$1.subtract(
                                      const Duration(seconds: 1),
                                    ),
                                  ) &&
                                  fecha.isBefore(
                                    dateRange.$2.add(
                                      const Duration(seconds: 1),
                                    ),
                                  );
                            }).toList();

                            final transferenciasEnRango = transferencias.where((
                              t,
                            ) {
                              final fecha = (t['fecha'] as Timestamp).toDate();
                              return fecha.isAfter(
                                    dateRange.$1.subtract(
                                      const Duration(seconds: 1),
                                    ),
                                  ) &&
                                  fecha.isBefore(
                                    dateRange.$2.add(
                                      const Duration(seconds: 1),
                                    ),
                                  );
                            }).toList();

                            final prestamosEnRango = prestamos.where((p) {
                              final fecha = (p['fecha'] as Timestamp).toDate();
                              return fecha.isAfter(
                                    dateRange.$1.subtract(
                                      const Duration(seconds: 1),
                                    ),
                                  ) &&
                                  fecha.isBefore(
                                    dateRange.$2.add(
                                      const Duration(seconds: 1),
                                    ),
                                  );
                            }).toList();

                            // Sumar totales
                            final totalIngresos = ingresosEnRango.fold<double>(
                              0.0,
                              (sum, i) => sum + (i['monto'] as num).toDouble(),
                            );

                            final totalGastos = gastosEnRango.fold<double>(
                              0.0,
                              (sum, g) => sum + (g['monto'] as num).toDouble(),
                            );

                            final totalTransferencias = transferenciasEnRango
                                .fold<double>(
                                  0.0,
                                  (sum, t) =>
                                      sum + (t['monto'] as num).toDouble(),
                                );

                            final totalPrestamos = prestamosEnRango
                                .fold<double>(
                                  0.0,
                                  (sum, p) =>
                                      sum + (p['monto'] as num).toDouble(),
                                );

                            // Estadísticas del banco seleccionado (con filtro de fecha para estadísticas)
                            final DateTime? statsStart = _fromDate;
                            final DateTime? statsEnd = _toDate;

                            // Validar que las fechas sean correctas
                            bool rangoValido = true;
                            if (statsStart != null && statsEnd != null) {
                              rangoValido =
                                  statsStart.isBefore(statsEnd) ||
                                  statsStart.isAtSameMomentAs(statsEnd);
                            }

                            // Filtrar datos del banco seleccionado
                            final ingresosDelBanco = rangoValido
                                ? ingresos.where((i) {
                                    final bancoId = i['bancoId'] as String?;
                                    if (bancoId == null ||
                                        bancoId != _selectedBankId)
                                      return false;

                                    if (statsStart == null && statsEnd == null)
                                      return true;

                                    final fecha = (i['fecha'] as Timestamp)
                                        .toDate();
                                    if (statsStart != null &&
                                        statsEnd != null) {
                                      return fecha.isAfter(
                                            statsStart.subtract(
                                              const Duration(seconds: 1),
                                            ),
                                          ) &&
                                          fecha.isBefore(
                                            statsEnd.add(
                                              const Duration(days: 1),
                                            ),
                                          );
                                    }
                                    if (statsStart != null) {
                                      return fecha.isAfter(
                                        statsStart.subtract(
                                          const Duration(seconds: 1),
                                        ),
                                      );
                                    }
                                    if (statsEnd != null) {
                                      return fecha.isBefore(
                                        statsEnd.add(const Duration(days: 1)),
                                      );
                                    }
                                    return true;
                                  }).toList()
                                : <Map<String, dynamic>>[];

                            final gastosDelBanco = rangoValido
                                ? gastos.where((g) {
                                    final bancoId = g['bancoId'] as String?;
                                    if (bancoId == null ||
                                        bancoId != _selectedBankId)
                                      return false;

                                    if (statsStart == null && statsEnd == null)
                                      return true;

                                    final fecha = (g['fecha'] as Timestamp)
                                        .toDate();
                                    if (statsStart != null &&
                                        statsEnd != null) {
                                      return fecha.isAfter(
                                            statsStart.subtract(
                                              const Duration(seconds: 1),
                                            ),
                                          ) &&
                                          fecha.isBefore(
                                            statsEnd.add(
                                              const Duration(days: 1),
                                            ),
                                          );
                                    }
                                    if (statsStart != null) {
                                      return fecha.isAfter(
                                        statsStart.subtract(
                                          const Duration(seconds: 1),
                                        ),
                                      );
                                    }
                                    if (statsEnd != null) {
                                      return fecha.isBefore(
                                        statsEnd.add(const Duration(days: 1)),
                                      );
                                    }
                                    return true;
                                  }).toList()
                                : <Map<String, dynamic>>[];

                            final transferenciasDelBanco = rangoValido
                                ? transferencias.where((t) {
                                    final origenId =
                                        t['bancoOrigenId'] as String?;
                                    final destinoId =
                                        t['bancoDestinoId'] as String?;
                                    final perteneceAlBanco =
                                        origenId == _selectedBankId ||
                                        destinoId == _selectedBankId;
                                    if (!perteneceAlBanco) return false;

                                    if (statsStart == null && statsEnd == null)
                                      return true;

                                    final fecha = (t['fecha'] as Timestamp)
                                        .toDate();
                                    if (statsStart != null &&
                                        statsEnd != null) {
                                      return fecha.isAfter(
                                            statsStart.subtract(
                                              const Duration(seconds: 1),
                                            ),
                                          ) &&
                                          fecha.isBefore(
                                            statsEnd.add(
                                              const Duration(days: 1),
                                            ),
                                          );
                                    }
                                    if (statsStart != null) {
                                      return fecha.isAfter(
                                        statsStart.subtract(
                                          const Duration(seconds: 1),
                                        ),
                                      );
                                    }
                                    if (statsEnd != null) {
                                      return fecha.isBefore(
                                        statsEnd.add(const Duration(days: 1)),
                                      );
                                    }
                                    return true;
                                  }).toList()
                                : <Map<String, dynamic>>[];

                            final prestamosDelBanco = rangoValido
                                ? prestamos.where((p) {
                                    final bancoId = p['bancoId'] as String?;
                                    if (bancoId == null ||
                                        bancoId != _selectedBankId)
                                      return false;

                                    if (statsStart == null && statsEnd == null)
                                      return true;

                                    final fecha = (p['fecha'] as Timestamp)
                                        .toDate();
                                    if (statsStart != null &&
                                        statsEnd != null) {
                                      return fecha.isAfter(
                                            statsStart.subtract(
                                              const Duration(seconds: 1),
                                            ),
                                          ) &&
                                          fecha.isBefore(
                                            statsEnd.add(
                                              const Duration(days: 1),
                                            ),
                                          );
                                    }
                                    if (statsStart != null) {
                                      return fecha.isAfter(
                                        statsStart.subtract(
                                          const Duration(seconds: 1),
                                        ),
                                      );
                                    }
                                    if (statsEnd != null) {
                                      return fecha.isBefore(
                                        statsEnd.add(const Duration(days: 1)),
                                      );
                                    }
                                    return true;
                                  }).toList()
                                : <Map<String, dynamic>>[];

                            final bancoIngresos = ingresosDelBanco.fold<double>(
                              0.0,
                              (sum, i) => sum + (i['monto'] as num).toDouble(),
                            );

                            final bancoGastos = gastosDelBanco.fold<double>(
                              0.0,
                              (sum, g) => sum + (g['monto'] as num).toDouble(),
                            );

                            final bancoTransfer = transferenciasDelBanco
                                .fold<double>(
                                  0.0,
                                  (sum, t) =>
                                      sum + (t['monto'] as num).toDouble(),
                                );

                            final bancoPrestamos = prestamosDelBanco
                                .fold<double>(
                                  0.0,
                                  (sum, p) =>
                                      sum + (p['monto'] as num).toDouble(),
                                );

                            return Column(
                              children: [
                                // Espacio para el ThemeSwitch (componente externo)
                                const SizedBox(height: 48),

                                // Contenido scrolleable
                                Expanded(
                                  child: ListView(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      0,
                                      16,
                                      16,
                                    ),
                                    children: [
                                      // =========================
                                      // RESUMEN
                                      // =========================
                                      Row(
                                        children: [
                                          Text(
                                            'Resumen',
                                            style: theme.textTheme.titleLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w900,
                                                ),
                                          ),
                                          const Spacer(),

                                          // Chip presionable: Hoy/Semana/Mes/Año
                                          _RangeChip(
                                            label: _summaryRangeLabel,
                                            border: stroke,
                                            color: card,
                                            textColor: isDark
                                                ? Colors.white.withValues(
                                                    alpha: 0.85,
                                                  )
                                                : Colors.black.withValues(
                                                    alpha: 0.75,
                                                  ),
                                            muted: muted,
                                            onSelected: (v) => setState(
                                              () => _summaryRange = v,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),

                                      // =========================
                                      // KPI CARDS
                                      // =========================
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _TileCard(
                                              border: stroke,
                                              color: card,
                                              child: _KpiTile(
                                                tag: 'Saldo total',
                                                value:
                                                    'S/ ${saldoTotal.toStringAsFixed(2)}',
                                                icon: FontAwesomeIcons.wallet,
                                                accent: active,
                                                muted: muted,
                                                isDark: isDark,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _TileCard(
                                              border: stroke,
                                              color: card,
                                              onTap: () {
                                                Navigator.of(context).push(
                                                  MaterialPageRoute(
                                                    builder: (_) => KpiHistoryView(
                                                      type: KpiHistoryType
                                                          .ingresos,
                                                      title:
                                                          'Historial de Ingresos',
                                                    ),
                                                  ),
                                                );
                                              },
                                              child: _KpiTile(
                                                tag: 'Ingresos',
                                                value:
                                                    'S/ ${totalIngresos.toStringAsFixed(2)}',
                                                icon:
                                                    FontAwesomeIcons.arrowDown,
                                                accent: active,
                                                muted: muted,
                                                isDark: isDark,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),

                                      Row(
                                        children: [
                                          Expanded(
                                            child: _TileCard(
                                              border: stroke,
                                              color: card,
                                              onTap: () {
                                                Navigator.of(context).push(
                                                  MaterialPageRoute(
                                                    builder: (_) => KpiHistoryView(
                                                      type:
                                                          KpiHistoryType.gastos,
                                                      title:
                                                          'Historial de Gastos',
                                                    ),
                                                  ),
                                                );
                                              },
                                              child: _KpiTile(
                                                tag: 'Gastos',
                                                value:
                                                    'S/ ${totalGastos.toStringAsFixed(2)}',
                                                icon: FontAwesomeIcons
                                                    .cartShopping,
                                                accent: active,
                                                muted: muted,
                                                isDark: isDark,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _TileCard(
                                              border: stroke,
                                              color: card,
                                              onTap: () {
                                                Navigator.of(context).push(
                                                  MaterialPageRoute(
                                                    builder: (_) => KpiHistoryView(
                                                      type: KpiHistoryType
                                                          .prestamos,
                                                      title:
                                                          'Historial de Préstamos',
                                                    ),
                                                  ),
                                                );
                                              },
                                              child: _KpiTile(
                                                tag: 'Préstamos',
                                                value:
                                                    'S/ ${totalPrestamos.toStringAsFixed(2)}',
                                                icon: FontAwesomeIcons
                                                    .handHoldingDollar,
                                                accent: active,
                                                muted: muted,
                                                isDark: isDark,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),

                                      _TileCard(
                                        border: stroke,
                                        color: card,
                                        onTap: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => KpiHistoryView(
                                                type: KpiHistoryType
                                                    .transferencias,
                                                title:
                                                    'Historial de Transferencias',
                                              ),
                                            ),
                                          );
                                        },
                                        child: _KpiTile(
                                          tag: 'Transferencias',
                                          value:
                                              'S/ ${totalTransferencias.toStringAsFixed(2)}',
                                          icon: FontAwesomeIcons.rightLeft,
                                          accent: active,
                                          muted: muted,
                                          isDark: isDark,
                                          fullWidth: true,
                                        ),
                                      ),

                                      const SizedBox(height: 18),

                                      // =========================
                                      // BANCOS
                                      // =========================
                                      Row(
                                        children: [
                                          Text(
                                            'Bancos',
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w900,
                                                ),
                                          ),
                                          const Spacer(),
                                          _IconNavButton(
                                            onTap: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      const BancosView(),
                                                ),
                                              );
                                            },
                                            border: stroke,
                                            color: card,
                                            icon: Icons.chevron_right_rounded,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),

                                      if (bancos.isEmpty)
                                        _TileCard(
                                          border: stroke,
                                          color: card,
                                          child: Padding(
                                            padding: const EdgeInsets.all(20),
                                            child: Center(
                                              child: Text(
                                                'No tienes bancos registrados',
                                                style: theme
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(color: muted),
                                              ),
                                            ),
                                          ),
                                        )
                                      else
                                        _TileCard(
                                          border: stroke,
                                          color: card,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 10,
                                          ),
                                          child: SizedBox(
                                            height: 96,
                                            child: ListView.separated(
                                              scrollDirection: Axis.horizontal,
                                              itemCount: bancos.length,
                                              separatorBuilder: (_, __) =>
                                                  const SizedBox(width: 10),
                                              itemBuilder: (context, i) {
                                                final banco = bancos[i];
                                                final selected =
                                                    i == _selectedBankIndex;
                                                return _BankMemberChip(
                                                  logo: banco['logo'],
                                                  nombre: banco['nombre'],
                                                  balance:
                                                      (banco['saldo'] as num)
                                                          .toDouble(),
                                                  selected: selected,
                                                  accent: active,
                                                  stroke: stroke,
                                                  soft: soft,
                                                  isDark: isDark,
                                                  onTap: () => setState(() {
                                                    _selectedBankIndex = i;
                                                    _selectedBankId =
                                                        banco['id'];
                                                  }),
                                                );
                                              },
                                            ),
                                          ),
                                        ),

                                      const SizedBox(height: 18),

                                      // =========================
                                      // ESTADÍSTICA + CALENDARIO
                                      // =========================
                                      Row(
                                        children: [
                                          Text(
                                            'Estadística',
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w900,
                                                ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            _statsRangeLabel,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(color: muted),
                                          ),
                                          const SizedBox(width: 10),
                                          _IconNavButton(
                                            onTap: () async {
                                              final res =
                                                  await _openStatsCalendarPopup(
                                                    context,
                                                  );
                                              if (res == null) return;

                                              // Validar que la fecha de inicio no sea posterior a la fecha de fin
                                              if (res.$1 != null &&
                                                  res.$2 != null) {
                                                if (res.$1!.isAfter(res.$2!)) {
                                                  if (mounted) {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        content: const Row(
                                                          children: [
                                                            Icon(
                                                              Icons.error,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                            SizedBox(width: 12),
                                                            Expanded(
                                                              child: Text(
                                                                'La fecha de inicio no puede ser posterior a la fecha de fin',
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        backgroundColor:
                                                            Colors.red.shade600,
                                                        behavior:
                                                            SnackBarBehavior
                                                                .floating,
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                12,
                                                              ),
                                                        ),
                                                        margin:
                                                            const EdgeInsets.all(
                                                              16,
                                                            ),
                                                      ),
                                                    );
                                                  }
                                                  return;
                                                }
                                              }

                                              setState(() {
                                                _fromDate = res.$1;
                                                _toDate = res.$2;
                                              });
                                            },
                                            border: stroke,
                                            color: card,
                                            icon: Icons.calendar_month_rounded,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),

                                      // Advertencia si el rango no es válido
                                      if (!rangoValido)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 10,
                                          ),
                                          child: _TileCard(
                                            border: Colors.red.shade600
                                                .withValues(alpha: 0.40),
                                            color: Colors.red.shade600
                                                .withValues(alpha: 0.10),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.warning_rounded,
                                                  color: Colors.red.shade600,
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    'La fecha de inicio debe ser anterior o igual a la fecha de fin',
                                                    style: theme
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: Colors
                                                              .red
                                                              .shade700,
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),

                                      // =========================
                                      // GRÁFICOS
                                      // =========================
                                      if (bancos.isEmpty)
                                        _TileCard(
                                          border: stroke,
                                          color: card,
                                          child: Padding(
                                            padding: const EdgeInsets.all(20),
                                            child: Center(
                                              child: Text(
                                                'Selecciona un banco para ver estadísticas',
                                                style: theme
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(color: muted),
                                              ),
                                            ),
                                          ),
                                        )
                                      else
                                        AnimatedSwitcher(
                                          duration: const Duration(
                                            milliseconds: 220,
                                          ),
                                          switchInCurve: Curves.easeOut,
                                          switchOutCurve: Curves.easeIn,
                                          child: Column(
                                            key: ValueKey(
                                              'bank_$_selectedBankId',
                                            ),
                                            children: [
                                              _TileCard(
                                                border: stroke,
                                                color: card,
                                                child: _PowerSection(
                                                  title: 'Flujo de efectivo',
                                                  subtitle: bancos.isNotEmpty
                                                      ? '${bancos[_selectedBankIndex]['nombre']}${rangoValido ? (statsStart != null || statsEnd != null ? ' - Rango personalizado' : ' - Sin filtro') : ''}'
                                                      : 'Sin banco seleccionado',
                                                  muted: muted,
                                                  child: _CompareBarsModern(
                                                    ingresos: bancoIngresos,
                                                    gastos: bancoGastos,
                                                    accent: active,
                                                    isDark: isDark,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              _TileCard(
                                                border: stroke,
                                                color: card,
                                                child: _PowerSection(
                                                  title: 'Distribución',
                                                  subtitle:
                                                      'Transferencias y Préstamos',
                                                  muted: muted,
                                                  child: _RingBreakdownModern(
                                                    transfer: bancoTransfer,
                                                    prestamos: bancoPrestamos,
                                                    accent: active,
                                                    isDark: isDark,
                                                    muted: muted,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/* ----------------------------- RESUMEN RANGE CHIP ----------------------------- */

class _RangeChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color border;
  final Color textColor;
  final Color muted;
  final ValueChanged<SummaryRange> onSelected;

  const _RangeChip({
    required this.label,
    required this.color,
    required this.border,
    required this.textColor,
    required this.muted,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Fondo sólido para el menú
    final menuBg = isDark ? const Color(0xFF1C1D22) : Colors.white;

    return PopupMenuButton<SummaryRange>(
      onSelected: onSelected,
      offset: const Offset(0, 46),
      elevation: 10,
      color: menuBg,
      surfaceTintColor: Colors.transparent,
      constraints: const BoxConstraints(minWidth: 160),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: border),
      ),
      itemBuilder: (context) => const [
        PopupMenuItem(value: SummaryRange.today, child: Text('Hoy')),
        PopupMenuItem(value: SummaryRange.week, child: Text('Semana')),
        PopupMenuItem(value: SummaryRange.month, child: Text('Mes')),
        PopupMenuItem(value: SummaryRange.year, child: Text('Año')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.expand_more_rounded, size: 18, color: muted),
          ],
        ),
      ),
    );
  }
}

/* ----------------------------- INLINE RANGE PICKER ----------------------------- */

class _InlineRangePicker extends StatelessWidget {
  final Color border;
  final Color muted;
  final bool isDark;
  final DateTime? from;
  final DateTime? to;
  final ValueChanged<DateTime> onFromChanged;
  final ValueChanged<DateTime> onToChanged;
  final VoidCallback onClear;
  final VoidCallback onClose;

  const _InlineRangePicker({
    required this.border,
    required this.muted,
    required this.isDark,
    required this.from,
    required this.to,
    required this.onFromChanged,
    required this.onToChanged,
    required this.onClear,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = isDark
        ? Colors.white.withValues(alpha: 0.85)
        : Colors.black.withValues(alpha: 0.75);

    final now = DateTime.now();
    final first = DateTime(now.year - 5, 1, 1);
    final last = DateTime(now.year + 1, 12, 31);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Selecciona rango',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Toca las fechas para definir inicio y fin del período.',
          style: theme.textTheme.bodySmall?.copyWith(color: muted),
        ),
        const SizedBox(height: 12),

        // Calendario unificado con mejor diseño
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border, width: 1.5),
            color: (isDark ? Colors.white : Colors.black).withValues(
              alpha: 0.02,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header del calendario
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(
                    alpha: 0.04,
                  ),
                  border: Border(bottom: BorderSide(color: border)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _DateChip(
                      label: 'Inicio',
                      date: from,
                      muted: muted,
                      isDark: isDark,
                    ),
                    Icon(Icons.arrow_forward_rounded, color: muted, size: 16),
                    _DateChip(
                      label: 'Fin',
                      date: to,
                      muted: muted,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              // Calendario
              Padding(
                padding: const EdgeInsets.all(8),
                child: _CompactRangeCalendar(
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
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: onClose,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Aplicar'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
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

class _DateChip extends StatelessWidget {
  final String label;
  final DateTime? date;
  final Color muted;
  final bool isDark;

  const _DateChip({
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
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _CompactRangeCalendar extends StatefulWidget {
  final DateTime? from;
  final DateTime? to;
  final ValueChanged<DateTime> onFromChanged;
  final ValueChanged<DateTime> onToChanged;
  final DateTime firstDate;
  final DateTime lastDate;
  final bool isDark;

  const _CompactRangeCalendar({
    required this.from,
    required this.to,
    required this.onFromChanged,
    required this.onToChanged,
    required this.firstDate,
    required this.lastDate,
    required this.isDark,
  });

  @override
  State<_CompactRangeCalendar> createState() => _CompactRangeCalendarState();
}

class _CompactRangeCalendarState extends State<_CompactRangeCalendar> {
  late DateTime _currentMonth;
  bool _selectingFrom = true;

  @override
  void initState() {
    super.initState();
    _currentMonth = widget.from ?? widget.to ?? DateTime.now();
  }

  void _onDateTapped(DateTime date) {
    // Normalizar la fecha al inicio del día
    final normalizedDate = DateTime(date.year, date.month, date.day);

    if (_selectingFrom || widget.from == null) {
      widget.onFromChanged(normalizedDate);
      setState(() => _selectingFrom = false);
    } else {
      if (normalizedDate.isBefore(widget.from!)) {
        // Si la nueva fecha es anterior al inicio, actualizar el inicio
        widget.onFromChanged(normalizedDate);
      } else {
        // Sino, establecer como fecha de fin
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

/* ----------------------------- UI BUILDING BLOCKS ----------------------------- */

class _TileCard extends StatelessWidget {
  final Color color;
  final Color border;
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  const _TileCard({
    required this.color,
    required this.border,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return card;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: card,
    );
  }
}

class _IconNavButton extends StatelessWidget {
  final VoidCallback onTap;
  final Color color;
  final Color border;
  final IconData icon;

  const _IconNavButton({
    required this.onTap,
    required this.color,
    required this.border,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = isDark
        ? Colors.white.withValues(alpha: 0.80)
        : Colors.black.withValues(alpha: 0.70);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Icon(icon, color: fg),
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  final String tag;
  final String value;
  final IconData icon;
  final Color accent;
  final Color muted;
  final bool isDark;
  final bool fullWidth;

  const _KpiTile({
    required this.tag,
    required this.value,
    required this.icon,
    required this.accent,
    required this.muted,
    required this.isDark,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bubble = accent.withValues(alpha: isDark ? 0.18 : 0.12);

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bubble,
            border: Border.all(color: accent.withValues(alpha: 0.14)),
          ),
          child: Center(child: FaIcon(icon, color: accent, size: 17)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // tag tipo pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(
                    alpha: 0.04,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  tag,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Evita overflows en cualquier tamaño
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: fullWidth ? 19 : 17,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BankMemberChip extends StatelessWidget {
  final String logo;
  final String nombre;
  final double balance;
  final bool selected;
  final Color accent;
  final Color stroke;
  final Color soft;
  final bool isDark;
  final VoidCallback onTap;

  const _BankMemberChip({
    required this.logo,
    required this.nombre,
    required this.balance,
    required this.selected,
    required this.accent,
    required this.stroke,
    required this.soft,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final fg = isDark
        ? Colors.white.withValues(alpha: 0.85)
        : Colors.black.withValues(alpha: 0.75);
    final bg = selected ? accent.withValues(alpha: isDark ? 0.18 : 0.10) : soft;
    final brd = selected ? accent.withValues(alpha: 0.35) : stroke;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        width: 86,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: brd),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: isDark ? 0.18 : 0.12),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo con puntito de selección
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? accent.withValues(alpha: isDark ? 0.18 : 0.12)
                        : (isDark ? Colors.white : Colors.black).withValues(
                            alpha: 0.06,
                          ),
                    border: Border.all(
                      color: selected ? accent.withValues(alpha: 0.35) : stroke,
                      width: 1.5,
                    ),
                  ),
                  child: ClipOval(
                    child: Image.network(
                      logo,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.account_balance,
                        color: selected ? accent : fg,
                        size: 22,
                      ),
                    ),
                  ),
                ),
                if (selected)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.95),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: (isDark ? Colors.black : Colors.white)
                              .withValues(alpha: 0.40),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Balance siempre entra
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'S/ ${balance.toStringAsFixed(2)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: selected ? accent : fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PowerSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color muted;
  final Widget child;

  const _PowerSection({
    required this.title,
    required this.subtitle,
    required this.muted,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(color: muted),
        ),
        const SizedBox(height: 14),
        child,
      ],
    );
  }
}

/* ----------------------------- GRÁFICOS ----------------------------- */

class _CompareBarsModern extends StatelessWidget {
  final double ingresos;
  final double gastos;
  final Color accent;
  final bool isDark;

  const _CompareBarsModern({
    required this.ingresos,
    required this.gastos,
    required this.accent,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final fg = isDark
        ? Colors.white.withValues(alpha: 0.85)
        : Colors.black.withValues(alpha: 0.75);
    final sub = isDark
        ? Colors.white.withValues(alpha: 0.65)
        : Colors.black.withValues(alpha: 0.55);

    final maxV = (ingresos > gastos ? ingresos : gastos).clamp(
      1,
      double.infinity,
    );
    final pIngresos = (ingresos / maxV).clamp(0.0, 1.0);
    final pGastos = (gastos / maxV).clamp(0.0, 1.0);

    return Column(
      children: [
        _MetricRow(
          label: 'Ingresos',
          value: 'S/ ${ingresos.toStringAsFixed(2)}',
          color: accent.withValues(alpha: 0.90),
          track: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
          progress: pIngresos,
          fg: fg,
          sub: sub,
        ),
        const SizedBox(height: 12),
        _MetricRow(
          label: 'Gastos',
          value: 'S/ ${gastos.toStringAsFixed(2)}',
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.35),
          track: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
          progress: pGastos,
          fg: fg,
          sub: sub,
        ),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color track;
  final double progress;
  final Color fg;
  final Color sub;

  const _MetricRow({
    required this.label,
    required this.value,
    required this.color,
    required this.track,
    required this.progress,
    required this.fg,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: fg,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: fg,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 12,
            color: track,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: progress,
                alignment: Alignment.centerLeft,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOut,
                  color: color,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Comparación relativa',
          style: theme.textTheme.bodySmall?.copyWith(color: sub),
        ),
      ],
    );
  }
}

class _RingBreakdownModern extends StatelessWidget {
  final double transfer;
  final double prestamos;
  final Color accent;
  final bool isDark;
  final Color muted;

  const _RingBreakdownModern({
    required this.transfer,
    required this.prestamos,
    required this.accent,
    required this.isDark,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final total = (transfer + prestamos).clamp(1, double.infinity);
    final p = (transfer / total).clamp(0.0, 1.0);

    final ringBg = (isDark ? Colors.white : Colors.black).withValues(
      alpha: 0.10,
    );
    final ringFg = accent.withValues(alpha: 0.90);

    return Row(
      children: [
        // Gráfico de anillo ajustado
        CustomPaint(
          size: const Size(100, 100),
          painter: _RingPainter(
            percent: p,
            foreground: ringFg,
            background: ringBg,
          ),
          child: SizedBox(
            width: 100,
            height: 100,
            child: Center(
              child: Text(
                '${(p * 100).toStringAsFixed(0)}%',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LegendLine(
                label: 'Transferencias',
                value: 'S/ ${transfer.toStringAsFixed(2)}',
                dot: accent.withValues(alpha: 0.90),
              ),
              const SizedBox(height: 10),
              _LegendLine(
                label: 'Préstamos',
                value: 'S/ ${prestamos.toStringAsFixed(2)}',
                dot: (isDark ? Colors.white : Colors.black).withValues(
                  alpha: 0.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendLine extends StatelessWidget {
  final String label;
  final String value;
  final Color dot;

  const _LegendLine({
    required this.label,
    required this.value,
    required this.dot,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  final double percent;
  final Color foreground;
  final Color background;

  _RingPainter({
    required this.percent,
    required this.foreground,
    required this.background,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    // Anillo de fondo
    final bgPaint = Paint()
      ..color = background
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Anillo de progreso
    final fgPaint = Paint()
      ..color = foreground
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    const startAngle = -math.pi / 2; // -90 grados (arriba)
    final sweepAngle = 2 * math.pi * percent;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) {
    return oldDelegate.percent != percent ||
        oldDelegate.foreground != foreground ||
        oldDelegate.background != background;
  }
}
