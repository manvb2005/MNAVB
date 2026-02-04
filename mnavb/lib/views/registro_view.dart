import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';

class RegistroView extends StatefulWidget {
  const RegistroView({super.key});

  @override
  State<RegistroView> createState() => _RegistroViewState();
}

class _RegistroViewState extends State<RegistroView> {
  final _firebaseService = FirebaseService();
  int _tabIndex = 0; // 0 = Ingreso, 1 = Gasto

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Registro',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),

              _SegmentPills(
                value: _tabIndex,
                onChanged: (v) => setState(() => _tabIndex = v),
              ),

              const SizedBox(height: 14),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 16),
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: _tabIndex == 0
                          ? _IngresoFormCard(
                              key: const ValueKey('ingresoForm'),
                              firebaseService: _firebaseService,
                            )
                          : _GastoFormCard(
                              key: const ValueKey('gastoForm'),
                              firebaseService: _firebaseService,
                            ),
                    ),

                    const SizedBox(height: 16),

                    _SectionHeader(
                      title: _tabIndex == 0 ? 'Historial de Ingresos' : 'Historial de Gastos',
                      subtitle: 'Últimos registros del mes',
                    ),

                    const SizedBox(height: 10),

                    // Historial real desde Firebase
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _tabIndex == 0
                          ? _firebaseService.getIngresosStream()
                          : _firebaseService.getGastosStream(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        if (snapshot.hasError) {
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Error: ${snapshot.error}',
                              style: TextStyle(color: Colors.red.shade600),
                            ),
                          );
                        }

                        final registros = snapshot.data ?? [];

                        if (registros.isEmpty) {
                          return _EmptyState(
                            isIngreso: _tabIndex == 0,
                          );
                        }

                        return Column(
                          children: registros.map((registro) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _RegistroTile(
                                registro: registro,
                                isIngreso: _tabIndex == 0,
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ----------------------------- FORMULARIO INGRESO ----------------------------- */

class _IngresoFormCard extends StatefulWidget {
  final FirebaseService firebaseService;

  const _IngresoFormCard({
    super.key,
    required this.firebaseService,
  });

  @override
  State<_IngresoFormCard> createState() => _IngresoFormCardState();
}

class _IngresoFormCardState extends State<_IngresoFormCard> {
  Map<String, dynamic>? _bancoSeleccionado;
  String? _tipoCuentaSeleccionada;
  final _categoriaController = TextEditingController();
  final _montoController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _guardando = false;
  DateTime _fechaSeleccionada = DateTime.now();

  @override
  void dispose() {
    _categoriaController.dispose();
    _montoController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarBanco() async {
    // Verificar que se haya seleccionado tipo de cuenta primero
    if (_tipoCuentaSeleccionada == null) {
      _mostrarError('Selecciona primero un tipo de cuenta');
      return;
    }

    final bancos = await widget.firebaseService.getBancosStream().first;

    if (!mounted) return;

    if (bancos.isEmpty) {
      _mostrarError('No tienes bancos registrados. Agrega uno primero desde la sección Bancos.');
      return;
    }

    // Filtrar bancos por tipo de cuenta seleccionado
    final bancosFiltrados = bancos.where((banco) {
      return banco['tipoCuenta'] == _tipoCuentaSeleccionada;
    }).toList();

    if (bancosFiltrados.isEmpty) {
      _mostrarError('No tienes bancos del tipo $_tipoCuentaSeleccionada. Agrega uno desde la sección Bancos.');
      return;
    }

    final resultado = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SelectorBancos(bancos: bancosFiltrados),
    );

    if (resultado != null) {
      setState(() => _bancoSeleccionado = resultado);
    }
  }

  Future<void> _seleccionarFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (fecha != null) {
      final hora = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_fechaSeleccionada),
      );

      if (hora != null) {
        setState(() {
          _fechaSeleccionada = DateTime(
            fecha.year,
            fecha.month,
            fecha.day,
            hora.hour,
            hora.minute,
          );
        });
      }
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    if (_tipoCuentaSeleccionada == null) {
      _mostrarError('Selecciona el tipo de cuenta');
      return;
    }

    if (_bancoSeleccionado == null) {
      _mostrarError('Selecciona un banco');
      return;
    }

    final monto = double.tryParse(_montoController.text);
    if (monto == null || monto <= 0) {
      _mostrarError('Ingresa un monto válido mayor a cero');
      return;
    }

    setState(() => _guardando = true);

    try {
      await widget.firebaseService.registrarIngreso(
        bancoId: _bancoSeleccionado!['id'],
        bancoNombre: _bancoSeleccionado!['nombre'],
        bancoLogo: _bancoSeleccionado!['logo'],
        tipoCuenta: _tipoCuentaSeleccionada!,
        categoria: _categoriaController.text.trim(),
        monto: monto,
        fecha: _fechaSeleccionada,
      );

      if (mounted) {
        _mostrarExito('Ingreso registrado exitosamente');
        _limpiarFormulario();
      }
    } catch (e) {
      if (mounted) {
        _mostrarError('Error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  void _cambiarTipoCuenta(String tipo) {
    setState(() {
      _tipoCuentaSeleccionada = tipo;
      // Limpiar banco seleccionado al cambiar tipo de cuenta
      _bancoSeleccionado = null;
    });
  }

  void _limpiarFormulario() {
    setState(() {
      _bancoSeleccionado = null;
      _tipoCuentaSeleccionada = null;
      _categoriaController.clear();
      _montoController.clear();
      _fechaSeleccionada = DateTime.now();
    });
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _mostrarExito(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return _FormCard(
      title: 'Registrar ingreso',
      subtitle: 'Completa todos los campos requeridos',
      isDark: isDark,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tipo de cuenta (AHORA ARRIBA)
            _CampoLabel(texto: 'Tipo de cuenta *', isDark: isDark),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _ChipOpcion(
                    texto: 'Corriente',
                    seleccionado: _tipoCuentaSeleccionada == 'Corriente',
                    onTap: () => _cambiarTipoCuenta('Corriente'),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ChipOpcion(
                    texto: 'Ahorro',
                    seleccionado: _tipoCuentaSeleccionada == 'Ahorro',
                    onTap: () => _cambiarTipoCuenta('Ahorro'),
                    isDark: isDark,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Selector de banco (AHORA ABAJO)
            _CampoLabel(texto: 'Banco *', isDark: isDark),
            const SizedBox(height: 8),
            _CampoSelector(
              texto: _bancoSeleccionado == null
                  ? 'Selecciona un banco'
                  : _bancoSeleccionado!['nombre'],
              icono: Icons.account_balance_rounded,
              onTap: _seleccionarBanco,
              tieneValor: _bancoSeleccionado != null,
              isDark: isDark,
              logo: _bancoSeleccionado?['logo'],
            ),

            const SizedBox(height: 14),

            // Categoría
            _CampoLabel(texto: 'Categoría / Descripción *', isDark: isDark),
            const SizedBox(height: 8),
            _CampoTexto(
              controller: _categoriaController,
              hint: 'Ej: Sueldo, Freelance, Venta',
              isDark: isDark,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Campo requerido';
                if (v.length > 50) return 'Máximo 50 caracteres';
                return null;
              },
            ),

            const SizedBox(height: 14),

            // Monto
            _CampoLabel(texto: 'Monto *', isDark: isDark),
            const SizedBox(height: 8),
            _CampoTexto(
              controller: _montoController,
              hint: '0.00',
              prefijo: 'S/ ',
              teclado: const TextInputType.numberWithOptions(decimal: true),
              formatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
              isDark: isDark,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Campo requerido';
                final monto = double.tryParse(v);
                if (monto == null) return 'Monto inválido';
                if (monto <= 0) return 'Debe ser mayor a cero';
                return null;
              },
            ),

            const SizedBox(height: 14),

            // Fecha y hora
            _CampoLabel(texto: 'Fecha y hora', isDark: isDark),
            const SizedBox(height: 8),
            _CampoSelector(
              texto: DateFormat('dd/MM/yyyy HH:mm').format(_fechaSeleccionada),
              icono: Icons.calendar_today_rounded,
              onTap: _seleccionarFecha,
              tieneValor: true,
              isDark: isDark,
            ),

            const SizedBox(height: 18),

            // Botón guardar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _guardando ? null : _guardar,
                icon: _guardando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_rounded),
                label: Text(_guardando ? 'Guardando...' : 'Registrar ingreso'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ----------------------------- FORMULARIO GASTO ----------------------------- */

class _GastoFormCard extends StatefulWidget {
  final FirebaseService firebaseService;

  const _GastoFormCard({
    super.key,
    required this.firebaseService,
  });

  @override
  State<_GastoFormCard> createState() => _GastoFormCardState();
}

class _GastoFormCardState extends State<_GastoFormCard> {
  Map<String, dynamic>? _bancoSeleccionado;
  String? _tipoCuentaSeleccionada;
  final _categoriaController = TextEditingController();
  final _montoController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _guardando = false;
  DateTime _fechaSeleccionada = DateTime.now();

  @override
  void dispose() {
    _categoriaController.dispose();
    _montoController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarBanco() async {
    // Verificar que se haya seleccionado tipo de cuenta primero
    if (_tipoCuentaSeleccionada == null) {
      _mostrarError('Selecciona primero un tipo de cuenta');
      return;
    }

    final bancos = await widget.firebaseService.getBancosStream().first;

    if (!mounted) return;

    if (bancos.isEmpty) {
      _mostrarError('No tienes bancos registrados. Agrega uno primero desde la sección Bancos.');
      return;
    }

    // Filtrar bancos por tipo de cuenta seleccionado
    final bancosFiltrados = bancos.where((banco) {
      return banco['tipoCuenta'] == _tipoCuentaSeleccionada;
    }).toList();

    if (bancosFiltrados.isEmpty) {
      _mostrarError('No tienes bancos del tipo $_tipoCuentaSeleccionada. Agrega uno desde la sección Bancos.');
      return;
    }

    final resultado = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SelectorBancos(bancos: bancosFiltrados),
    );

    if (resultado != null) {
      setState(() => _bancoSeleccionado = resultado);
    }
  }

  Future<void> _seleccionarFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (fecha != null) {
      final hora = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_fechaSeleccionada),
      );

      if (hora != null) {
        setState(() {
          _fechaSeleccionada = DateTime(
            fecha.year,
            fecha.month,
            fecha.day,
            hora.hour,
            hora.minute,
          );
        });
      }
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    if (_tipoCuentaSeleccionada == null) {
      _mostrarError('Selecciona el tipo de cuenta');
      return;
    }

    if (_bancoSeleccionado == null) {
      _mostrarError('Selecciona un banco');
      return;
    }

    final monto = double.tryParse(_montoController.text);
    if (monto == null || monto <= 0) {
      _mostrarError('Ingresa un monto válido mayor a cero');
      return;
    }

    // Confirmar antes de registrar gasto
    final confirmar = await _mostrarConfirmacion(
      'Registrar gasto de S/ ${monto.toStringAsFixed(2)}',
      'Se descontará del saldo de ${_bancoSeleccionado!['nombre']}.',
    );

    if (!confirmar || !mounted) return;

    setState(() => _guardando = true);

    try {
      await widget.firebaseService.registrarGasto(
        bancoId: _bancoSeleccionado!['id'],
        bancoNombre: _bancoSeleccionado!['nombre'],
        bancoLogo: _bancoSeleccionado!['logo'],
        tipoCuenta: _tipoCuentaSeleccionada!,
        categoria: _categoriaController.text.trim(),
        monto: monto,
        fecha: _fechaSeleccionada,
      );

      if (mounted) {
        _mostrarExito('Gasto registrado exitosamente');
        _limpiarFormulario();
      }
    } catch (e) {
      if (mounted) {
        _mostrarError(e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  void _cambiarTipoCuenta(String tipo) {
    setState(() {
      _tipoCuentaSeleccionada = tipo;
      // Limpiar banco seleccionado al cambiar tipo de cuenta
      _bancoSeleccionado = null;
    });
  }

  void _limpiarFormulario() {
    setState(() {
      _bancoSeleccionado = null;
      _tipoCuentaSeleccionada = null;
      _categoriaController.clear();
      _montoController.clear();
      _fechaSeleccionada = DateTime.now();
    });
  }

  Future<bool> _mostrarConfirmacion(String titulo, String mensaje) async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) => _DialogoConfirmacion(
        titulo: titulo,
        mensaje: mensaje,
      ),
    );
    return resultado ?? false;
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _mostrarExito(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return _FormCard(
      title: 'Registrar gasto',
      subtitle: 'Completa todos los campos requeridos',
      isDark: isDark,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tipo de cuenta (AHORA ARRIBA)
            _CampoLabel(texto: 'Tipo de cuenta *', isDark: isDark),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _ChipOpcion(
                    texto: 'Corriente',
                    seleccionado: _tipoCuentaSeleccionada == 'Corriente',
                    onTap: () => _cambiarTipoCuenta('Corriente'),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ChipOpcion(
                    texto: 'Ahorro',
                    seleccionado: _tipoCuentaSeleccionada == 'Ahorro',
                    onTap: () => _cambiarTipoCuenta('Ahorro'),
                    isDark: isDark,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Selector de banco (AHORA ABAJO)
            _CampoLabel(texto: 'Banco *', isDark: isDark),
            const SizedBox(height: 8),
            _CampoSelector(
              texto: _bancoSeleccionado == null
                  ? 'Selecciona un banco'
                  : _bancoSeleccionado!['nombre'],
              icono: Icons.account_balance_rounded,
              onTap: _seleccionarBanco,
              tieneValor: _bancoSeleccionado != null,
              isDark: isDark,
              logo: _bancoSeleccionado?['logo'],
            ),

            const SizedBox(height: 14),

            // Categoría
            _CampoLabel(texto: 'Categoría / Descripción *', isDark: isDark),
            const SizedBox(height: 8),
            _CampoTexto(
              controller: _categoriaController,
              hint: 'Ej: Comida, Transporte, Servicios',
              isDark: isDark,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Campo requerido';
                if (v.length > 50) return 'Máximo 50 caracteres';
                return null;
              },
            ),

            const SizedBox(height: 14),

            // Monto
            _CampoLabel(texto: 'Monto *', isDark: isDark),
            const SizedBox(height: 8),
            _CampoTexto(
              controller: _montoController,
              hint: '0.00',
              prefijo: 'S/ ',
              teclado: const TextInputType.numberWithOptions(decimal: true),
              formatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
              isDark: isDark,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Campo requerido';
                final monto = double.tryParse(v);
                if (monto == null) return 'Monto inválido';
                if (monto <= 0) return 'Debe ser mayor a cero';
                return null;
              },
            ),

            const SizedBox(height: 14),

            // Fecha y hora
            _CampoLabel(texto: 'Fecha y hora', isDark: isDark),
            const SizedBox(height: 8),
            _CampoSelector(
              texto: DateFormat('dd/MM/yyyy HH:mm').format(_fechaSeleccionada),
              icono: Icons.calendar_today_rounded,
              onTap: _seleccionarFecha,
              tieneValor: true,
              isDark: isDark,
            ),

            const SizedBox(height: 18),

            // Botón guardar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _guardando ? null : _guardar,
                icon: _guardando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_rounded),
                label: Text(_guardando ? 'Guardando...' : 'Registrar gasto'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ----------------------------- COMPONENTES UI ----------------------------- */

class _SegmentPills extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _SegmentPills({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.05);
    final border = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.06);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          Expanded(
            child: _PillButton(
              selected: value == 0,
              label: 'Ingreso',
              icon: Icons.arrow_downward_rounded,
              onTap: () => onChanged(0),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _PillButton(
              selected: value == 1,
              label: 'Gasto',
              icon: Icons.arrow_upward_rounded,
              onTap: () => onChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final bool selected;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _PillButton({
    required this.selected,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;

    final bg = selected
        ? active.withValues(alpha: isDark ? 0.22 : 0.14)
        : Colors.transparent;

    final fg = selected
        ? active
        : (isDark
            ? Colors.white.withValues(alpha: 0.70)
            : Colors.black.withValues(alpha: 0.60));

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                color: fg,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isDark;
  final Widget child;

  const _FormCard({
    required this.title,
    required this.subtitle,
    required this.isDark,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final cardBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.03);
    final border = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.06);
    final muted = isDark
        ? Colors.white.withValues(alpha: 0.65)
        : Colors.black.withValues(alpha: 0.55);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_note_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _CampoLabel extends StatelessWidget {
  final String texto;
  final bool isDark;

  const _CampoLabel({
    required this.texto,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      texto,
      style: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _CampoSelector extends StatelessWidget {
  final String texto;
  final IconData icono;
  final VoidCallback onTap;
  final bool tieneValor;
  final bool isDark;
  final String? logo;

  const _CampoSelector({
    required this.texto,
    required this.icono,
    required this.onTap,
    required this.tieneValor,
    required this.isDark,
    this.logo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.white;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.06);
    final fg = tieneValor
        ? (isDark
            ? Colors.white.withValues(alpha: 0.88)
            : Colors.black.withValues(alpha: 0.78))
        : (isDark
            ? Colors.white.withValues(alpha: 0.55)
            : Colors.black.withValues(alpha: 0.45));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            if (logo != null)
              Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: border),
                ),
                child: ClipOval(
                  child: Image.network(
                    logo!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(icono, size: 16),
                  ),
                ),
              )
            else
              Icon(icono, size: 20, color: fg),
            if (logo == null) const SizedBox(width: 10),
            Expanded(
              child: Text(
                texto,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: fg,
                  fontWeight: tieneValor ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, color: fg),
          ],
        ),
      ),
    );
  }
}

class _ChipOpcion extends StatelessWidget {
  final String texto;
  final bool seleccionado;
  final VoidCallback onTap;
  final bool isDark;

  const _ChipOpcion({
    required this.texto,
    required this.seleccionado,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    final bg = seleccionado
        ? accent.withValues(alpha: isDark ? 0.18 : 0.12)
        : (isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.04));

    final border = seleccionado
        ? accent.withValues(alpha: 0.40)
        : (isDark
            ? Colors.white.withValues(alpha: 0.10)
            : Colors.black.withValues(alpha: 0.06));

    final fg = seleccionado
        ? accent
        : (isDark
            ? Colors.white.withValues(alpha: 0.75)
            : Colors.black.withValues(alpha: 0.70));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: border,
            width: seleccionado ? 2 : 1,
          ),
        ),
        child: Text(
          texto,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: fg,
          ),
        ),
      ),
    );
  }
}

class _CampoTexto extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String? prefijo;
  final TextInputType? teclado;
  final List<TextInputFormatter>? formatters;
  final String? Function(String?)? validator;
  final bool isDark;

  const _CampoTexto({
    required this.controller,
    required this.hint,
    required this.isDark,
    this.prefijo,
    this.teclado,
    this.formatters,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.white;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.06);
    final fg = isDark
        ? Colors.white.withValues(alpha: 0.88)
        : Colors.black.withValues(alpha: 0.78);
    final muted = isDark
        ? Colors.white.withValues(alpha: 0.55)
        : Colors.black.withValues(alpha: 0.45);

    return TextFormField(
      controller: controller,
      style: TextStyle(color: fg, fontWeight: FontWeight.w700),
      keyboardType: teclado,
      inputFormatters: formatters,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: muted, fontWeight: FontWeight.w500),
        prefixText: prefijo,
        prefixStyle: TextStyle(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w900,
        ),
        filled: true,
        fillColor: bg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.red.withValues(alpha: 0.65)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.red.withValues(alpha: 0.85), width: 2),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
          style: theme.textTheme.bodySmall?.copyWith(
            color: isDark
                ? Colors.white.withValues(alpha: 0.60)
                : Colors.black.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }
}

class _RegistroTile extends StatelessWidget {
  final Map<String, dynamic> registro;
  final bool isIngreso;

  const _RegistroTile({
    required this.registro,
    required this.isIngreso,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;

    final border = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.06);
    final bg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.03);
    final muted = isDark
        ? Colors.white.withValues(alpha: 0.65)
        : Colors.black.withValues(alpha: 0.55);

    final fecha = (registro['fecha'] as dynamic);
    final fechaStr = fecha != null
        ? DateFormat('dd/MM/yyyy HH:mm').format((fecha as dynamic).toDate())
        : '—';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          // Logo del banco
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: isDark ? 0.20 : 0.12),
              border: Border.all(color: accent.withValues(alpha: 0.18), width: 2),
            ),
            child: ClipOval(
              child: Image.network(
                registro['bancoLogo'] ?? '',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.account_balance,
                  color: accent,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Información
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isIngreso ? 'Ingreso' : 'Gasto',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: isIngreso ? Colors.green.shade600 : Colors.red.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${registro['bancoNombre']} • ${registro['tipoCuenta']}',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
                const SizedBox(height: 4),
                Text(
                  registro['categoria'] ?? 'Sin categoría',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  fechaStr,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // Monto
          Text(
            'S/ ${(registro['monto'] as num).toStringAsFixed(2)}',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isIngreso;

  const _EmptyState({required this.isIngreso});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              isIngreso ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              size: 64,
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.20),
            ),
            const SizedBox(height: 16),
            Text(
              isIngreso ? 'No hay ingresos registrados' : 'No hay gastos registrados',
              style: theme.textTheme.titleMedium?.copyWith(
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.50),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Registra tu primer ${isIngreso ? 'ingreso' : 'gasto'} usando el formulario',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.40),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ----------------------------- SELECTOR DE BANCOS ----------------------------- */

class _SelectorBancos extends StatelessWidget {
  final List<Map<String, dynamic>> bancos;

  const _SelectorBancos({required this.bancos});

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
            // Handle
            Center(
              child: Container(
                width: 52,
                height: 5,
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black)
                      .withValues(alpha: 0.16),
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
                    'Selecciona un banco',
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
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Icon(Icons.close_rounded, color: muted),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                shrinkWrap: true,
                itemCount: bancos.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final banco = bancos[i];
                  return _BancoOption(banco: banco, isDark: isDark);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BancoOption extends StatelessWidget {
  final Map<String, dynamic> banco;
  final bool isDark;

  const _BancoOption({
    required this.banco,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    final bg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white;
    final stroke = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.06);
    final fg = isDark
        ? Colors.white.withValues(alpha: 0.88)
        : Colors.black.withValues(alpha: 0.78);
    final muted = isDark
        ? Colors.white.withValues(alpha: 0.65)
        : Colors.black.withValues(alpha: 0.55);

    final saldo = (banco['saldo'] as num?)?.toDouble() ?? 0.0;

    return InkWell(
      onTap: () => Navigator.pop(context, banco),
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
            // Logo
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: accent.withValues(alpha: 0.35), width: 2),
              ),
              child: ClipOval(
                child: Image.network(
                  banco['logo'] ?? '',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.account_balance,
                    color: accent,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    banco['nombre'] ?? 'Sin nombre',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: fg,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          banco['tipoCuenta'] ?? 'Cuenta',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: muted,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      if (banco['alias'] != null && (banco['alias'] as String).isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: isDark ? 0.16 : 0.10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            banco['alias'],
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Saldo: S/ ${saldo.toStringAsFixed(2)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),

            Icon(Icons.chevron_right_rounded, color: muted),
          ],
        ),
      ),
    );
  }
}

/* ----------------------------- DIÁLOGO DE CONFIRMACIÓN ----------------------------- */

class _DialogoConfirmacion extends StatelessWidget {
  final String titulo;
  final String mensaje;

  const _DialogoConfirmacion({
    required this.titulo,
    required this.mensaje,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final card = isDark ? const Color(0xFF1C1D22) : Colors.white;
    final stroke = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);
    final fg = isDark
        ? Colors.white.withValues(alpha: 0.88)
        : Colors.black.withValues(alpha: 0.78);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: stroke),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.warning_rounded,
                size: 28,
                color: Colors.orange.shade600,
              ),
              const SizedBox(height: 10),
              Text(
                titulo,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: fg,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                mensaje,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.65)
                      : Colors.black.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: stroke),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Cancelar',
                        style: TextStyle(
                          color: fg,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Confirmar',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
