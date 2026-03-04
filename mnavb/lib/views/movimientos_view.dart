import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';
import '../utils/currency_formatter.dart';

const double _minimalFaIconSize = 14;

class MovimientosView extends StatefulWidget {
  const MovimientosView({super.key});

  @override
  State<MovimientosView> createState() => _MovimientosViewState();
}

class _MovimientosViewState extends State<MovimientosView> {
  int _tabIndex = 0; // 0 = Transferencia, 1 = Préstamo
  final _firebaseService = FirebaseService();

  Future<void> _eliminarTransferencia(
    Map<String, dynamic> transferencia,
  ) async {
    final transferenciaId = transferencia['id'] as String?;
    if (transferenciaId == null || transferenciaId.isEmpty) {
      _mostrarError('No se pudo identificar la transferencia a eliminar');
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => const _DialogoConfirmacion(
        titulo: 'Eliminar transferencia',
        mensaje: '¿Estás seguro que quieres eliminar esta transferencia?',
      ),
    );

    if (confirmar != true) return;

    try {
      await _firebaseService.eliminarTransferencia(
        transferenciaId: transferenciaId,
      );

      if (!mounted) return;
      _mostrarExito('Transferencia eliminada');
    } catch (e) {
      if (!mounted) return;
      _mostrarError(e.toString().replaceAll('Exception: ', ''));
    }
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

    return SafeArea(
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Movimientos',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),

              _SegmentPills(
                value: _tabIndex,
                labels: const ['Transferencia', 'Préstamo'],
                icons: const [
                  FontAwesomeIcons.rightLeft,
                  FontAwesomeIcons.handshake,
                ],
                onChanged: (v) => setState(() => _tabIndex = v),
              ),

              const SizedBox(height: 14),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 16),
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: _tabIndex == 0
                          ? _TransferenciaFormCard(
                              key: const ValueKey('transferForm'),
                              firebaseService: _firebaseService,
                            )
                          : _PrestamoFormCard(
                              key: const ValueKey('loanForm'),
                              firebaseService: _firebaseService,
                            ),
                    ),

                    const SizedBox(height: 16),

                    _SectionHeader(
                      title: _tabIndex == 0
                          ? 'Historial de transferencias'
                          : 'Historial de préstamos',
                      subtitle: _tabIndex == 0
                          ? 'Últimas 5 transferencias'
                          : 'Últimos 5 préstamos',
                      icon: _tabIndex == 0
                          ? FontAwesomeIcons.clockRotateLeft
                          : FontAwesomeIcons.fileInvoiceDollar,
                    ),

                    const SizedBox(height: 10),

                    if (_tabIndex == 0)
                      _HistorialTransferencias(
                        firebaseService: _firebaseService,
                        onDelete: _eliminarTransferencia,
                      )
                    else
                      _HistorialPrestamos(firebaseService: _firebaseService),
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

/* ----------------------------- FORMULARIO TRANSFERENCIA ----------------------------- */

class _TransferenciaFormCard extends StatefulWidget {
  final FirebaseService firebaseService;

  const _TransferenciaFormCard({super.key, required this.firebaseService});

  @override
  State<_TransferenciaFormCard> createState() => _TransferenciaFormCardState();
}

class _TransferenciaFormCardState extends State<_TransferenciaFormCard> {
  Map<String, dynamic>? _bancoOrigen;
  Map<String, dynamic>? _bancoDestino;
  final _descripcionController = TextEditingController();
  final _montoController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _guardando = false;
  DateTime _fechaSeleccionada = DateTime.now();

  @override
  void dispose() {
    _descripcionController.dispose();
    _montoController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarBancoOrigen() async {
    final bancos = await widget.firebaseService.getBancosStream().first;

    if (!mounted) return;

    if (bancos.isEmpty) {
      _mostrarError(
        'No tienes bancos registrados. Agrega uno primero desde la sección Bancos.',
      );
      return;
    }

    final resultado = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SelectorBancos(bancos: bancos),
    );

    if (resultado != null) {
      setState(() {
        _bancoOrigen = resultado;
        // Si el banco destino es el mismo que el origen, limpiarlo
        if (_bancoDestino != null && _bancoDestino!['id'] == resultado['id']) {
          _bancoDestino = null;
        }
      });
    }
  }

  Future<void> _seleccionarBancoDestino() async {
    if (_bancoOrigen == null) {
      _mostrarError('Selecciona primero el banco de origen');
      return;
    }

    final bancos = await widget.firebaseService.getBancosStream().first;

    if (!mounted) return;

    if (bancos.isEmpty) {
      _mostrarError('No tienes bancos registrados.');
      return;
    }

    // Filtrar para excluir el banco de origen (por ID, ya que alias puede ser diferente)
    final bancosFiltrados = bancos.where((banco) {
      return banco['id'] != _bancoOrigen!['id'];
    }).toList();

    if (bancosFiltrados.isEmpty) {
      _mostrarError(
        'No tienes otros bancos disponibles. El banco de origen no puede ser el mismo que el destino.',
      );
      return;
    }

    final resultado = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SelectorBancos(bancos: bancosFiltrados),
    );

    if (resultado != null) {
      setState(() => _bancoDestino = resultado);
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

    if (_bancoOrigen == null) {
      _mostrarError('Selecciona el banco de origen');
      return;
    }

    if (_bancoDestino == null) {
      _mostrarError('Selecciona el banco de destino');
      return;
    }

    final monto = double.tryParse(_montoController.text);
    if (monto == null || monto <= 0) {
      _mostrarError('Ingresa un monto válido mayor a cero');
      return;
    }

    // Confirmación con modal mejorado
    final confirmar = await _mostrarConfirmacionTransferencia(
      monto: monto,
      bancoOrigen: _bancoOrigen!,
      bancoDestino: _bancoDestino!,
    );

    if (!confirmar || !mounted) return;

    setState(() => _guardando = true);

    try {
      await widget.firebaseService.registrarTransferencia(
        bancoOrigenId: _bancoOrigen!['id'],
        bancoOrigenNombre: _bancoOrigen!['nombre'],
        bancoOrigenLogo: _bancoOrigen!['logo'],
        bancoOrigenAlias: _bancoOrigen!['alias'] as String?,
        bancoDestinoId: _bancoDestino!['id'],
        bancoDestinoNombre: _bancoDestino!['nombre'],
        bancoDestinoLogo: _bancoDestino!['logo'],
        bancoDestinoAlias: _bancoDestino!['alias'] as String?,
        descripcion: _descripcionController.text.trim(),
        monto: monto,
        fecha: _fechaSeleccionada,
      );

      if (mounted) {
        _mostrarExito('Transferencia registrada exitosamente');
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

  void _limpiarFormulario() {
    setState(() {
      _bancoOrigen = null;
      _bancoDestino = null;
      _descripcionController.clear();
      _montoController.clear();
      _fechaSeleccionada = DateTime.now();
    });
  }

  Future<bool> _mostrarConfirmacionTransferencia({
    required double monto,
    required Map<String, dynamic> bancoOrigen,
    required Map<String, dynamic> bancoDestino,
  }) async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) => _DialogoConfirmacionTransferencia(
        monto: monto,
        bancoOrigen: bancoOrigen,
        bancoDestino: bancoDestino,
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
      title: 'Registrar transferencia',
      subtitle: 'Completa todos los campos requeridos',
      isDark: isDark,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banco de origen
            _CampoLabel(texto: 'Banco de origen *', isDark: isDark),
            const SizedBox(height: 8),
            _CampoSelector(
              texto: _bancoOrigen == null
                  ? 'Selecciona banco de origen'
                  : (_bancoOrigen!['alias'] != null &&
                        (_bancoOrigen!['alias'] as String).isNotEmpty)
                  ? '${_bancoOrigen!['nombre']} - ${_bancoOrigen!['alias']}'
                  : _bancoOrigen!['nombre'],
              icono: Icons.account_balance_rounded,
              onTap: _seleccionarBancoOrigen,
              tieneValor: _bancoOrigen != null,
              isDark: isDark,
              logo: _bancoOrigen?['logo'],
            ),

            const SizedBox(height: 14),

            // Banco de destino
            _CampoLabel(texto: 'Banco de destino *', isDark: isDark),
            const SizedBox(height: 8),
            _CampoSelector(
              texto: _bancoDestino == null
                  ? 'Selecciona banco de destino'
                  : (_bancoDestino!['alias'] != null &&
                        (_bancoDestino!['alias'] as String).isNotEmpty)
                  ? '${_bancoDestino!['nombre']} - ${_bancoDestino!['alias']}'
                  : _bancoDestino!['nombre'],
              icono: Icons.account_balance_wallet_rounded,
              onTap: _seleccionarBancoDestino,
              tieneValor: _bancoDestino != null,
              isDark: isDark,
              logo: _bancoDestino?['logo'],
            ),

            const SizedBox(height: 14),

            // Descripción
            _CampoLabel(texto: 'Descripción *', isDark: isDark),
            const SizedBox(height: 8),
            _CampoTexto(
              controller: _descripcionController,
              hint: 'Ej: Emergencia, Gas, Pago amigo',
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
              isDark: isDark,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              validator: (v) {
                if (v == null || v.isEmpty) return 'Campo requerido';
                final monto = double.tryParse(v);
                if (monto == null || monto <= 0) return 'Monto inválido';
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

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _guardando ? null : _guardar,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _guardando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Registrar transferencia'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ----------------------------- FORMULARIO PRÉSTAMO ----------------------------- */

class _PrestamoFormCard extends StatefulWidget {
  final FirebaseService firebaseService;

  const _PrestamoFormCard({super.key, required this.firebaseService});

  @override
  State<_PrestamoFormCard> createState() => _PrestamoFormCardState();
}

class _PrestamoFormCardState extends State<_PrestamoFormCard> {
  Map<String, dynamic>? _bancoSeleccionado;
  String? _tipoCuentaSeleccionada;
  String _tiempoPrestamo = 'Reciente';
  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _montoController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _guardando = false;
  DateTime _fechaSeleccionada = DateTime.now();

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
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
      _mostrarError(
        'No tienes bancos registrados. Agrega uno primero desde la sección Bancos.',
      );
      return;
    }

    // Filtrar bancos por tipo de cuenta seleccionado
    final bancosFiltrados = bancos.where((banco) {
      return banco['tipoCuenta'] == _tipoCuentaSeleccionada;
    }).toList();

    if (bancosFiltrados.isEmpty) {
      _mostrarError(
        'No tienes bancos del tipo $_tipoCuentaSeleccionada. Agrega uno desde la sección Bancos.',
      );
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

    final esPrestamoReciente = _tiempoPrestamo == 'Reciente';

    if (esPrestamoReciente) {
      if (_tipoCuentaSeleccionada == null) {
        _mostrarError('Selecciona el tipo de cuenta');
        return;
      }

      if (_bancoSeleccionado == null) {
        _mostrarError('Selecciona un banco');
        return;
      }
    }

    final monto = double.tryParse(_montoController.text);
    if (monto == null || monto <= 0) {
      _mostrarError('Ingresa un monto válido mayor a cero');
      return;
    }

    final confirmar = esPrestamoReciente
        ? await _mostrarConfirmacionPrestamo(
            monto: monto,
            nombrePrestatario: _nombreController.text.trim(),
            banco: _bancoSeleccionado,
          )
        : await _mostrarConfirmacion(
            'Registrar préstamo antiguo',
            '¿Deseas registrar este préstamo antiguo por ${formatMoney(monto)}?',
          );

    if (!confirmar || !mounted) return;

    setState(() => _guardando = true);

    try {
      await widget.firebaseService.registrarPrestamo(
        bancoId: esPrestamoReciente ? _bancoSeleccionado!['id'] : null,
        bancoNombre: esPrestamoReciente ? _bancoSeleccionado!['nombre'] : null,
        bancoLogo: esPrestamoReciente ? _bancoSeleccionado!['logo'] : null,
        tipoCuenta: esPrestamoReciente ? _tipoCuentaSeleccionada! : null,
        nombrePrestatario: _nombreController.text.trim(),
        descripcion: _descripcionController.text.trim(),
        monto: monto,
        fecha: _fechaSeleccionada,
        descontarSaldo: esPrestamoReciente,
        tipoRegistro: esPrestamoReciente ? 'reciente' : 'antiguo',
      );

      if (mounted) {
        _mostrarExito('Préstamo registrado exitosamente');
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

  void _cambiarTiempoPrestamo(String tiempo) {
    setState(() {
      _tiempoPrestamo = tiempo;
      if (tiempo == 'Antiguo') {
        _tipoCuentaSeleccionada = null;
        _bancoSeleccionado = null;
      }
    });
  }

  void _limpiarFormulario() {
    setState(() {
      _tiempoPrestamo = 'Reciente';
      _bancoSeleccionado = null;
      _tipoCuentaSeleccionada = null;
      _nombreController.clear();
      _descripcionController.clear();
      _montoController.clear();
      _fechaSeleccionada = DateTime.now();
    });
  }

  Future<bool> _mostrarConfirmacion(String titulo, String mensaje) async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) =>
          _DialogoConfirmacion(titulo: titulo, mensaje: mensaje),
    );
    return resultado ?? false;
  }

  Future<bool> _mostrarConfirmacionPrestamo({
    required double monto,
    required String nombrePrestatario,
    Map<String, dynamic>? banco,
  }) async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) => _DialogoConfirmacionPrestamo(
        monto: monto,
        nombrePrestatario: nombrePrestatario,
        banco: banco,
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
      title: 'Registrar préstamo',
      subtitle: 'Elige entre préstamo reciente o antiguo',
      isDark: isDark,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CampoLabel(texto: 'Tiempo del préstamo *', isDark: isDark),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _ChipOpcion(
                    texto: 'Antiguo',
                    seleccionado: _tiempoPrestamo == 'Antiguo',
                    onTap: () => _cambiarTiempoPrestamo('Antiguo'),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ChipOpcion(
                    texto: 'Reciente',
                    seleccionado: _tiempoPrestamo == 'Reciente',
                    onTap: () => _cambiarTiempoPrestamo('Reciente'),
                    isDark: isDark,
                  ),
                ),
              ],
            ),

            if (_tiempoPrestamo == 'Reciente') ...[
              const SizedBox(height: 14),

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
            ],

            const SizedBox(height: 14),

            // Nombre del prestatario
            _CampoLabel(texto: 'Nombre de la persona *', isDark: isDark),
            const SizedBox(height: 8),
            _CampoTexto(
              controller: _nombreController,
              hint: 'Ej: Juan Pérez',
              isDark: isDark,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Campo requerido';
                if (v.length > 50) return 'Máximo 50 caracteres';
                return null;
              },
            ),

            const SizedBox(height: 14),

            // Descripción
            _CampoLabel(texto: 'Descripción del préstamo *', isDark: isDark),
            const SizedBox(height: 8),
            _CampoTexto(
              controller: _descripcionController,
              hint: 'Ej: Agua, Comida, Emergencia',
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
              isDark: isDark,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              validator: (v) {
                if (v == null || v.isEmpty) return 'Campo requerido';
                final monto = double.tryParse(v);
                if (monto == null || monto <= 0) return 'Monto inválido';
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

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _guardando ? null : _guardar,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _guardando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Registrar préstamo'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ----------------------------- HISTORIAL TRANSFERENCIAS ----------------------------- */

class _HistorialTransferencias extends StatelessWidget {
  final FirebaseService firebaseService;
  final ValueChanged<Map<String, dynamic>> onDelete;

  const _HistorialTransferencias({
    required this.firebaseService,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: firebaseService.getTransferenciasStream(),
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
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error: ${snapshot.error}'),
            ),
          );
        }

        final transferencias = snapshot.data ?? [];
        final ultimasTransferencias = transferencias.take(5).toList();

        if (ultimasTransferencias.isEmpty) {
          return const _EmptyState(
            mensaje: 'No hay transferencias registradas',
          );
        }

        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Column(
          children: ultimasTransferencias.map((tx) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TransferenciaTile(
                transferencia: tx,
                isDark: isDark,
                onDelete: () => onDelete(tx),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _TransferenciaTile extends StatelessWidget {
  final Map<String, dynamic> transferencia;
  final bool isDark;
  final VoidCallback onDelete;

  const _TransferenciaTile({
    required this.transferencia,
    required this.isDark,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = theme.colorScheme.primary;
    final border = isDark
        ? Colors.white.withAlpha((0.10 * 255).toInt())
        : Colors.black.withAlpha((0.06 * 255).toInt());
    final bg = isDark
        ? Colors.white.withAlpha((0.06 * 255).toInt())
        : Colors.black.withAlpha((0.03 * 255).toInt());

    final monto = (transferencia['monto'] as num).toDouble();
    final descripcion = transferencia['descripcion'] as String;
    final bancoOrigen = transferencia['bancoOrigenNombre'] as String;
    final aliasOrigen = transferencia['bancoOrigenAlias'] as String?;
    final logoOrigen = transferencia['bancoOrigenLogo'] as String;
    final bancoDestino = transferencia['bancoDestinoNombre'] as String;
    final aliasDestino = transferencia['bancoDestinoAlias'] as String?;
    final logoDestino = transferencia['bancoDestinoLogo'] as String;

    final fecha = (transferencia['fecha'] as dynamic);
    final fechaStr = fecha != null
        ? DateFormat('dd/MM/yyyy HH:mm').format((fecha as dynamic).toDate())
        : '—';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.swap_horiz_rounded,
                size: 18,
                color: active.withAlpha((0.80 * 255).toInt()),
              ),
              const SizedBox(width: 6),
              Text(
                'Transferencia',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                formatMoney(monto),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: active,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: onDelete,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.red : Colors.red).withValues(
                      alpha: 0.12,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    size: 17,
                    color: isDark ? Colors.red.shade300 : Colors.red.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _BankPill(
                  logo: logoOrigen,
                  nombre: bancoOrigen,
                  alias: aliasOrigen,
                  active: active,
                  isDark: isDark,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: active.withAlpha((0.80 * 255).toInt()),
                ),
              ),
              Expanded(
                child: _BankPill(
                  logo: logoDestino,
                  nombre: bancoDestino,
                  alias: aliasDestino,
                  active: active,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            descripcion,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            fechaStr,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark
                  ? Colors.white.withAlpha((0.60 * 255).toInt())
                  : Colors.black.withAlpha((0.50 * 255).toInt()),
            ),
          ),
        ],
      ),
    );
  }
}

class _BankPill extends StatelessWidget {
  final String logo;
  final String nombre;
  final String? alias;
  final Color active;
  final bool isDark;

  const _BankPill({
    required this.logo,
    required this.nombre,
    required this.alias,
    required this.active,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = isDark
        ? Colors.white.withAlpha((0.10 * 255).toInt())
        : Colors.black.withAlpha((0.06 * 255).toInt());
    final bg = isDark
        ? Colors.white.withAlpha((0.05 * 255).toInt())
        : Colors.black.withAlpha((0.03 * 255).toInt());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          _LogoBanco(logo: logo, active: active, isDark: isDark, size: 30),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (alias != null && alias!.isNotEmpty)
                  Text(
                    alias!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: isDark
                          ? Colors.white.withAlpha((0.60 * 255).toInt())
                          : Colors.black.withAlpha((0.50 * 255).toInt()),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ----------------------------- HISTORIAL PRÉSTAMOS ----------------------------- */

class _HistorialPrestamos extends StatelessWidget {
  final FirebaseService firebaseService;

  const _HistorialPrestamos({required this.firebaseService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: firebaseService.getPrestamosStream(),
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
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error: ${snapshot.error}'),
            ),
          );
        }

        final prestamos = snapshot.data ?? [];
        final ultimosPrestamos = prestamos.take(5).toList();

        if (ultimosPrestamos.isEmpty) {
          return const _EmptyState(mensaje: 'No hay préstamos registrados');
        }

        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Column(
          children: ultimosPrestamos.map((prestamo) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PrestamoTile(prestamo: prestamo, isDark: isDark),
            );
          }).toList(),
        );
      },
    );
  }
}

class _PrestamoTile extends StatelessWidget {
  final Map<String, dynamic> prestamo;
  final bool isDark;

  const _PrestamoTile({required this.prestamo, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = theme.colorScheme.primary;
    final border = isDark
        ? Colors.white.withAlpha((0.10 * 255).toInt())
        : Colors.black.withAlpha((0.06 * 255).toInt());
    final bg = isDark
        ? Colors.white.withAlpha((0.06 * 255).toInt())
        : Colors.black.withAlpha((0.03 * 255).toInt());

    final monto = (prestamo['monto'] as num).toDouble();
    final bancoNombre =
        (prestamo['bancoNombre'] as String?) ?? 'Sin banco asignado';
    final bancoLogo = (prestamo['bancoLogo'] as String?) ?? '';
    final nombrePrestatario = prestamo['nombrePrestatario'] as String;
    final descripcion = prestamo['descripcion'] as String;
    final tipoRegistro = (prestamo['tipoRegistro'] as String?) ?? 'reciente';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          _LogoBanco(logo: bancoLogo, active: active, isDark: isDark, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Préstamo',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tipoRegistro == 'antiguo' ? 'Antiguo' : 'Reciente',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: tipoRegistro == 'antiguo'
                        ? Colors.orange.shade600
                        : Colors.green.shade600,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  bancoNombre,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? Colors.white.withAlpha((0.65 * 255).toInt())
                        : Colors.black.withAlpha((0.55 * 255).toInt()),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Préstamo a: $nombrePrestatario',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  descripcion,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? Colors.white.withAlpha((0.60 * 255).toInt())
                        : Colors.black.withAlpha((0.50 * 255).toInt()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            formatMoney(monto),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: active,
            ),
          ),
        ],
      ),
    );
  }
}

/* ----------------------------- COMPONENTES COMPARTIDOS ----------------------------- */

class _SegmentPills extends StatelessWidget {
  final int value;
  final List<String> labels;
  final List<IconData> icons;
  final ValueChanged<int> onChanged;

  const _SegmentPills({
    required this.value,
    required this.labels,
    required this.icons,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark
        ? Colors.white.withAlpha((0.06 * 255).toInt())
        : Colors.black.withAlpha((0.05 * 255).toInt());
    final border = isDark
        ? Colors.white.withAlpha((0.10 * 255).toInt())
        : Colors.black.withAlpha((0.06 * 255).toInt());

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.all(6),
      child: Row(
        children: List.generate(
          labels.length,
          (i) => Expanded(
            child: _PillButton(
              selected: value == i,
              label: labels[i],
              icon: icons[i],
              onTap: () => onChanged(i),
            ),
          ),
        ),
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
        ? active.withAlpha(((isDark ? 0.22 : 0.14) * 255).toInt())
        : Colors.transparent;
    final fg = selected
        ? active
        : (isDark
              ? Colors.white.withAlpha((0.70 * 255).toInt())
              : Colors.black.withAlpha((0.60 * 255).toInt()));

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(icon, size: _minimalFaIconSize, color: fg),
            const SizedBox(width: 7),
            Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                color: fg,
                fontWeight: FontWeight.w800,
                fontSize: 13,
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
        ? Colors.white.withAlpha((0.06 * 255).toInt())
        : Colors.black.withAlpha((0.03 * 255).toInt());
    final border = isDark
        ? Colors.white.withAlpha((0.10 * 255).toInt())
        : Colors.black.withAlpha((0.06 * 255).toInt());

    return Container(
      padding: const EdgeInsets.all(16),
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
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark
                  ? Colors.white.withAlpha((0.65 * 255).toInt())
                  : Colors.black.withAlpha((0.55 * 255).toInt()),
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _CampoLabel extends StatelessWidget {
  final String texto;
  final bool isDark;

  const _CampoLabel({required this.texto, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      texto,
      style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
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
        ? Colors.white.withAlpha((0.05 * 255).toInt())
        : Colors.white;
    final border = isDark
        ? Colors.white.withAlpha((0.10 * 255).toInt())
        : Colors.black.withAlpha((0.06 * 255).toInt());
    final textColor = tieneValor
        ? (isDark ? Colors.white : Colors.black87)
        : (isDark
              ? Colors.white.withAlpha((0.55 * 255).toInt())
              : Colors.black.withAlpha((0.45 * 255).toInt()));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            if (logo != null && tieneValor)
              Container(
                width: 28,
                height: 28,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.primary.withAlpha(
                      (0.35 * 255).toInt(),
                    ),
                    width: 1.5,
                  ),
                ),
                child: ClipOval(
                  child: Image.network(
                    logo!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.account_balance,
                      color: theme.colorScheme.primary,
                      size: 14,
                    ),
                  ),
                ),
              )
            else
              Icon(icono, size: 20, color: textColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                texto,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: textColor,
                  fontWeight: tieneValor ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, color: textColor),
          ],
        ),
      ),
    );
  }
}

class _CampoTexto extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool isDark;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const _CampoTexto({
    required this.controller,
    required this.hint,
    required this.isDark,
    this.validator,
    this.keyboardType,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = isDark
        ? Colors.white.withAlpha((0.05 * 255).toInt())
        : Colors.white;
    final border = isDark
        ? Colors.white.withAlpha((0.10 * 255).toInt())
        : Colors.black.withAlpha((0.06 * 255).toInt());

    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: theme.textTheme.bodyMedium,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: bg,
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
          borderSide: BorderSide(color: Colors.red.shade600),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
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
    final active = theme.colorScheme.primary;
    final bg = seleccionado
        ? active.withAlpha(((isDark ? 0.22 : 0.14) * 255).toInt())
        : (isDark
              ? Colors.white.withAlpha((0.05 * 255).toInt())
              : Colors.white);
    final border = seleccionado
        ? active
        : (isDark
              ? Colors.white.withAlpha((0.10 * 255).toInt())
              : Colors.black.withAlpha((0.06 * 255).toInt()));
    final textColor = seleccionado
        ? active
        : (isDark ? Colors.white70 : Colors.black87);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: seleccionado ? 2 : 1),
        ),
        child: Center(
          child: Text(
            texto,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: textColor,
              fontWeight: seleccionado ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectorBancos extends StatelessWidget {
  final List<Map<String, dynamic>> bancos;

  const _SelectorBancos({required this.bancos});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withAlpha((0.20 * 255).toInt())
                  : Colors.black.withAlpha((0.10 * 255).toInt()),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Selecciona un banco',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: bancos.length,
              itemBuilder: (context, index) {
                final banco = bancos[index];
                return _BancoItem(
                  banco: banco,
                  onTap: () => Navigator.pop(context, banco),
                  isDark: isDark,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BancoItem extends StatelessWidget {
  final Map<String, dynamic> banco;
  final VoidCallback onTap;
  final bool isDark;

  const _BancoItem({
    required this.banco,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = theme.colorScheme.primary;
    final border = isDark
        ? Colors.white.withAlpha((0.10 * 255).toInt())
        : Colors.black.withAlpha((0.06 * 255).toInt());
    final bg = isDark
        ? Colors.white.withAlpha((0.05 * 255).toInt())
        : Colors.black.withAlpha((0.02 * 255).toInt());

    final saldo = (banco['saldo'] as num).toDouble();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: active.withAlpha((0.35 * 255).toInt()),
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: Image.network(
                    banco['logo'],
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Icon(Icons.account_balance, color: active, size: 22),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      banco['nombre'],
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      (banco['alias'] != null &&
                              (banco['alias'] as String).isNotEmpty)
                          ? '${banco['alias']} • ${banco['tipoCuenta']}'
                          : banco['tipoCuenta'],
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? Colors.white.withAlpha((0.60 * 255).toInt())
                            : Colors.black.withAlpha((0.50 * 255).toInt()),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatMoney(saldo),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: active,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Saldo',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? Colors.white.withAlpha((0.50 * 255).toInt())
                          : Colors.black.withAlpha((0.45 * 255).toInt()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final iconBg = isDark
        ? Colors.white.withAlpha((0.10 * 255).toInt())
        : theme.colorScheme.primary.withAlpha((0.12 * 255).toInt());
    final iconFg = isDark
        ? Colors.white.withAlpha((0.92 * 255).toInt())
        : theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(9),
              ),
              child: FaIcon(icon, size: _minimalFaIconSize, color: iconFg),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isDark
                ? Colors.white.withAlpha((0.60 * 255).toInt())
                : Colors.black.withAlpha((0.55 * 255).toInt()),
          ),
        ),
      ],
    );
  }
}

class _LogoBanco extends StatelessWidget {
  final String logo;
  final Color active;
  final bool isDark;
  final double size;

  const _LogoBanco({
    required this.logo,
    required this.active,
    required this.isDark,
    this.size = 38,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: active.withAlpha((0.35 * 255).toInt()),
          width: 2,
        ),
      ),
      child: ClipOval(
        child: Image.network(
          logo,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          errorBuilder: (_, __, ___) => Center(
            child: Icon(
              Icons.account_balance,
              color: active,
              size: size * 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String mensaje;

  const _EmptyState({required this.mensaje});

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
              Icons.info_outline_rounded,
              size: 64,
              color: isDark
                  ? Colors.white.withAlpha((0.30 * 255).toInt())
                  : Colors.black.withAlpha((0.20 * 255).toInt()),
            ),
            const SizedBox(height: 16),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: isDark
                    ? Colors.white.withAlpha((0.60 * 255).toInt())
                    : Colors.black.withAlpha((0.50 * 255).toInt()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogoConfirmacion extends StatelessWidget {
  final String titulo;
  final String mensaje;

  const _DialogoConfirmacion({required this.titulo, required this.mensaje});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        titulo,
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w900,
        ),
      ),
      content: Text(mensaje, style: theme.textTheme.bodyLarge),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            'Cancelar',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Confirmar',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _DialogoConfirmacionTransferencia extends StatelessWidget {
  final double monto;
  final Map<String, dynamic> bancoOrigen;
  final Map<String, dynamic> bancoDestino;

  const _DialogoConfirmacionTransferencia({
    required this.monto,
    required this.bancoOrigen,
    required this.bancoDestino,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final active = theme.colorScheme.primary;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.all(24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Título
          Text(
            'Transferencia',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            formatMoney(monto),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: active,
            ),
          ),
          const SizedBox(height: 24),

          // Bancos con flecha
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Banco origen
              _LogoConNombre(
                logo: bancoOrigen['logo'],
                nombre: bancoOrigen['nombre'],
                active: active,
                isDark: isDark,
              ),
              const SizedBox(width: 16),
              // Ícono de transferencia
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: active.withAlpha((0.15 * 255).toInt()),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: active,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              // Banco destino
              _LogoConNombre(
                logo: bancoDestino['logo'],
                nombre: bancoDestino['nombre'],
                active: active,
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            'Cancelar',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Text(
            'Confirmar',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ),
      ],
    );
  }
}

class _DialogoConfirmacionPrestamo extends StatelessWidget {
  final double monto;
  final String nombrePrestatario;
  final Map<String, dynamic>? banco;

  const _DialogoConfirmacionPrestamo({
    required this.monto,
    required this.nombrePrestatario,
    required this.banco,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final active = theme.colorScheme.primary;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.all(24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Título
          Text(
            'Préstamo',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            formatMoney(monto),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: active,
            ),
          ),
          const SizedBox(height: 24),

          if (banco != null) ...[
            _LogoConNombre(
              logo: banco!['logo'],
              nombre: banco!['nombre'],
              active: active,
              isDark: isDark,
            ),
            const SizedBox(height: 16),
          ],

          // Nombre de la persona
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withAlpha((0.08 * 255).toInt())
                  : Colors.black.withAlpha((0.04 * 255).toInt()),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.person_outline_rounded,
                  size: 20,
                  color: isDark
                      ? Colors.white.withAlpha((0.70 * 255).toInt())
                      : Colors.black.withAlpha((0.60 * 255).toInt()),
                ),
                const SizedBox(width: 8),
                Text(
                  nombrePrestatario,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            'Cancelar',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Text(
            'Confirmar',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ),
      ],
    );
  }
}

class _LogoConNombre extends StatelessWidget {
  final String logo;
  final String nombre;
  final Color active;
  final bool isDark;

  const _LogoConNombre({
    required this.logo,
    required this.nombre,
    required this.active,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: active.withAlpha((0.35 * 255).toInt()),
              width: 2,
            ),
          ),
          child: ClipOval(
            child: Image.network(
              logo,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Icon(Icons.account_balance, color: active, size: 30),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          nombre,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: isDark
                ? Colors.white.withAlpha((0.85 * 255).toInt())
                : Colors.black.withAlpha((0.75 * 255).toInt()),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
