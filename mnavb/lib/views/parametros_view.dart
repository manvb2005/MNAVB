import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/parametros_service.dart';

class ParametrosView extends StatefulWidget {
  const ParametrosView({super.key});

  @override
  State<ParametrosView> createState() => _ParametrosViewState();
}

class _ParametrosViewState extends State<ParametrosView> {
  final _parametrosService = ParametrosService();

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
                'Parámetros',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: StreamBuilder<Map<String, dynamic>>(
                  stream: _parametrosService.getParametrosStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final config = snapshot.data ?? {};
                    final parametroActivo = config['parametroActivo'] ?? false;

                    return ListView(
                      padding: const EdgeInsets.only(bottom: 16),
                      children: [
                        _CardLimiteMensual(
                          config: config,
                          parametrosService: _parametrosService,
                          onEditarLimite: () => _editarLimite(config),
                        ),
                        const SizedBox(height: 12),
                        _CardIntentos(
                          config: config,
                          parametroActivo: parametroActivo,
                          onGenerarCodigo: (tipo) =>
                              _generarCodigo(config, tipo),
                        ),
                        const SizedBox(height: 12),
                        _CardConfiguracion(
                          config: config,
                          parametroActivo: parametroActivo,
                          onCambiarHoras: () => _cambiarHoras(config),
                        ),
                        const SizedBox(height: 12),
                        _CardAppsBancarias(config: config),
                        const SizedBox(height: 12),
                        _BotonActivacion(
                          parametroActivo: parametroActivo,
                          onToggle: () => _toggleParametro(parametroActivo),
                        ),
                        const SizedBox(height: 12),
                        const _InfoSistema(),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editarLimite(Map<String, dynamic> config) async {
    final resultado = await showDialog<double>(
      context: context,
      builder: (context) => _DialogoEditarLimite(
        limiteActual: (config['limiteGastoMensual'] ?? 1000.0).toDouble(),
      ),
    );

    if (resultado != null) {
      await _parametrosService.actualizarLimite(resultado);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Límite actualizado a S/ ${resultado.toStringAsFixed(2)}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _cambiarHoras(Map<String, dynamic> config) async {
    final resultado = await showDialog<int>(
      context: context,
      builder: (context) =>
          _DialogoCambiarHoras(horasActuales: config['horasDesbloqueo'] ?? 24),
    );

    if (resultado != null) {
      await _parametrosService.actualizarHorasDesbloqueo(resultado);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Horas de desbloqueo actualizadas a ${resultado}h'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _generarCodigo(Map<String, dynamic> config, String tipo) async {
    final parametroActivo = config['parametroActivo'] ?? false;
    if (!parametroActivo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes activar el sistema primero'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      String? codigo;
      if (tipo == 'normal') {
        codigo = await _parametrosService.generarCodigoDesbloqueo(false);
      } else if (tipo == 'emergencia') {
        codigo = await _parametrosService.generarCodigoDesbloqueo(true);
      }

      if (codigo != null && mounted) {
        await showDialog(
          context: context,
          builder: (context) => _DialogoCodigoGenerado(codigo: codigo!),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _toggleParametro(bool estaActivo) async {
    if (estaActivo) {
      // Confirmar desactivación
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (context) => const _DialogoConfirmacion(),
      );

      if (confirmar == true) {
        try {
          await _parametrosService.desactivarParametro();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Sistema desactivado'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Error: ${e.toString().replaceAll("[cloud_firestore/permission-denied] ", "")}',
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      }
    } else {
      // Activar directamente
      try {
        await _parametrosService.activarParametro();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sistema activado. Periodo iniciado.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error: ${e.toString().replaceAll("[cloud_firestore/permission-denied] ", "")}',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }
}

/* ----------------------------- CARD LÍMITE MENSUAL ----------------------------- */

class _CardLimiteMensual extends StatelessWidget {
  final Map<String, dynamic> config;
  final ParametrosService parametrosService;
  final VoidCallback onEditarLimite;

  const _CardLimiteMensual({
    required this.config,
    required this.parametrosService,
    required this.onEditarLimite,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final limite = (config['limiteGastoMensual'] ?? 1000.0).toDouble();
    final parametroActivo = config['parametroActivo'] ?? false;
    final fechaActivacion = config['fechaActivacion'] as Timestamp?;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet_rounded,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Límite Mensual',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.edit_rounded, size: 20),
                onPressed: onEditarLimite,
                tooltip: 'Editar límite',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Límite: ',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              Text(
                'S/ ${limite.toStringAsFixed(2)}',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (parametroActivo) ...[
            StreamBuilder<double>(
              key: ValueKey('gasto_$parametroActivo'),
              stream: parametrosService.getGastoMensualStream(),
              builder: (context, snapshot) {
                final gastoActual = snapshot.data ?? 0.0;
                final porcentaje = limite > 0
                    ? (gastoActual / limite) * 100
                    : 0.0;
                final porcentajeClamped = porcentaje.clamp(0.0, 100.0);

                Color colorBarra = Colors.green;
                if (porcentaje >= 100) {
                  colorBarra = Colors.red;
                } else if (porcentaje >= 90) {
                  colorBarra = Colors.orange;
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Gastado: ',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          'S/ ${gastoActual.toStringAsFixed(2)}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorBarra,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${porcentaje.toStringAsFixed(1)}%)',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: porcentajeClamped / 100,
                        backgroundColor: Colors.grey[300],
                        color: colorBarra,
                        minHeight: 8,
                      ),
                    ),
                    if (porcentaje >= 90) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: colorBarra.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: colorBarra.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_rounded,
                              color: colorBarra,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                porcentaje >= 100
                                    ? '¡Límite superado!'
                                    : '¡Cerca del límite!',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorBarra,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Divider(color: Colors.grey[300], height: 1),
            const SizedBox(height: 12),
            _InfoPeriodo(fechaActivacion: fechaActivacion?.toDate()),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Colors.orange,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Activa el sistema para empezar a monitorear',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.orange[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoPeriodo extends StatelessWidget {
  final DateTime? fechaActivacion;

  const _InfoPeriodo({required this.fechaActivacion});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (fechaActivacion == null) {
      return const SizedBox.shrink();
    }

    final fechaInicio = fechaActivacion!;
    final fechaRenovacion = DateTime(
      fechaInicio.year,
      fechaInicio.month + 1,
      fechaInicio.day,
      fechaInicio.hour,
      fechaInicio.minute,
    );

    final formatoFecha = DateFormat('dd/MM/yyyy HH:mm');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Periodo activo:',
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              color: Colors.grey[600],
              size: 14,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Desde: ${formatoFecha.format(fechaInicio)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[700],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.event_repeat_rounded, color: Colors.grey[600], size: 14),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Próxima renovación: ${formatoFecha.format(fechaRenovacion)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[700],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/* ----------------------------- CARD INTENTOS ----------------------------- */

class _CardIntentos extends StatelessWidget {
  final Map<String, dynamic> config;
  final bool parametroActivo;
  final Function(String) onGenerarCodigo;

  const _CardIntentos({
    required this.config,
    required this.parametroActivo,
    required this.onGenerarCodigo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final intentosNormales = config['intentosNormalesRestantes'] ?? 3;
    final intentosEmergencia = config['intentosEmergenciaRestantes'] ?? 2;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lock_clock_rounded,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Códigos de Desbloqueo',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _IntentoCard(
                  titulo: 'Normal',
                  intentos: intentosNormales,
                  icono: Icons.vpn_key_rounded,
                  color: Colors.blue,
                  onPresionar: parametroActivo
                      ? () => onGenerarCodigo('normal')
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _IntentoCard(
                  titulo: 'Emergencia',
                  intentos: intentosEmergencia,
                  icono: Icons.emergency_rounded,
                  color: Colors.red,
                  onPresionar: parametroActivo
                      ? () => onGenerarCodigo('emergencia')
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IntentoCard extends StatelessWidget {
  final String titulo;
  final int intentos;
  final IconData icono;
  final Color color;
  final VoidCallback? onPresionar;

  const _IntentoCard({
    required this.titulo,
    required this.intentos,
    required this.icono,
    required this.color,
    this.onPresionar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final habilitado = onPresionar != null && intentos > 0;

    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Icon(icono, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            titulo,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$intentos disponibles',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: habilitado ? onPresionar : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                disabledBackgroundColor: Colors.grey[300],
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Generar',
                style: TextStyle(
                  color: habilitado ? Colors.white : Colors.grey[500],
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ----------------------------- CARD CONFIGURACIÓN ----------------------------- */

class _CardConfiguracion extends StatelessWidget {
  final Map<String, dynamic> config;
  final bool parametroActivo;
  final VoidCallback onCambiarHoras;

  const _CardConfiguracion({
    required this.config,
    required this.parametroActivo,
    required this.onCambiarHoras,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final horas = config['horasDesbloqueo'] ?? 24;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.settings_rounded,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Configuración',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.3),
              ),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  color: theme.colorScheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Horas de desbloqueo',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$horas horas',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_rounded, size: 20),
                  onPressed: parametroActivo ? onCambiarHoras : null,
                  tooltip: parametroActivo
                      ? 'Cambiar horas'
                      : 'Activa el sistema primero',
                  color: theme.colorScheme.primary,
                  disabledColor: Colors.grey[400],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ----------------------------- CARD APPS BANCARIAS ----------------------------- */

class _CardAppsBancarias extends StatefulWidget {
  final Map<String, dynamic> config;

  const _CardAppsBancarias({required this.config});

  @override
  State<_CardAppsBancarias> createState() => _CardAppsBancariasState();
}

class _CardAppsBancariasState extends State<_CardAppsBancarias> {
  final _parametrosService = ParametrosService();
  List<Map<String, String>>? _appsInstaladas;

  @override
  void initState() {
    super.initState();
    _cargarAppsInstaladas();
  }

  Future<void> _cargarAppsInstaladas() async {
    final apps = await _parametrosService.getAppsBancariasConocidas();
    if (mounted) {
      setState(() {
        _appsInstaladas = apps;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bloqueado = widget.config['bloqueado'] ?? false;
    final parametroActivo = widget.config['parametroActivo'] ?? false;

    // Iconos y colores predefinidos para apps conocidas
    final iconosApps = {
      'yape': {'icono': Icons.payment_rounded, 'color': Colors.purple},
      'bcp': {'icono': Icons.account_balance_rounded, 'color': Colors.blue},
      'bbva': {'icono': Icons.account_balance_rounded, 'color': Colors.lightBlue},
      'interbank': {'icono': Icons.account_balance_rounded, 'color': Colors.teal},
      'scotiabank': {'icono': Icons.account_balance_rounded, 'color': Colors.red},
      'plin': {'icono': Icons.payment_rounded, 'color': Colors.green},
      'tunki': {'icono': Icons.payment_rounded, 'color': Colors.orange},
      'banbif': {'icono': Icons.account_balance_rounded, 'color': Colors.indigo},
      'pichincha': {'icono': Icons.account_balance_rounded, 'color': Colors.yellow},
    };

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.apps_rounded,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Apps Bancarias',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: parametroActivo && bloqueado
                      ? Colors.red.withOpacity(0.1)
                      : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: parametroActivo && bloqueado
                        ? Colors.red.withOpacity(0.3)
                        : Colors.green.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  parametroActivo && bloqueado ? 'BLOQUEADAS' : 'DESBLOQUEADAS',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: parametroActivo && bloqueado
                        ? Colors.red[700]
                        : Colors.green[700],
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_appsInstaladas == null)
            const Center(child: CircularProgressIndicator())
          else if (_appsInstaladas!.isEmpty)
            Text(
              'No se detectaron apps bancarias instaladas',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _appsInstaladas!.map((app) {
                final nombre = app['nombre']!;
                final key = nombre.toLowerCase();
                final iconData = iconosApps[key];
                
                return _AppChip(
                  nombre: nombre,
                  icono: iconData?['icono'] as IconData? ?? Icons.account_balance_rounded,
                  color: iconData?['color'] as Color? ?? Colors.blue,
                  bloqueado: parametroActivo && bloqueado,
                );
              }).toList(),
          ),
        ],
      ),
    );
  }
}

class _AppChip extends StatelessWidget {
  final String nombre;
  final IconData icono;
  final Color color;
  final bool bloqueado;

  const _AppChip({
    required this.nombre,
    required this.icono,
    required this.color,
    required this.bloqueado,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, color: color, size: 18),
          const SizedBox(width: 6),
          Text(
            nombre,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            bloqueado ? Icons.lock_rounded : Icons.lock_open_rounded,
            color: bloqueado ? Colors.red : Colors.green,
            size: 16,
          ),
        ],
      ),
    );
  }
}

/* ----------------------------- BOTÓN ACTIVACIÓN ----------------------------- */

class _BotonActivacion extends StatelessWidget {
  final bool parametroActivo;
  final VoidCallback onToggle;

  const _BotonActivacion({
    required this.parametroActivo,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onToggle,
        icon: Icon(
          parametroActivo
              ? Icons.power_settings_new_rounded
              : Icons.play_arrow_rounded,
          size: 28,
        ),
        label: Text(
          parametroActivo ? 'Desactivar Sistema' : 'Activar Sistema',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: parametroActivo ? Colors.red : Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
        ),
      ),
    );
  }
}

/* ----------------------------- INFO SISTEMA ----------------------------- */

class _InfoSistema extends StatelessWidget {
  const _InfoSistema();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_rounded, color: Colors.blue, size: 24),
              const SizedBox(width: 8),
              Text(
                '¿Cómo funciona?',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoItem(
            icono: Icons.check_circle_outline_rounded,
            texto: 'Activa el sistema para empezar a controlar tus gastos',
          ),
          const SizedBox(height: 8),
          _InfoItem(
            icono: Icons.check_circle_outline_rounded,
            texto:
                'El periodo mensual se calcula desde el momento de activación',
          ),
          const SizedBox(height: 8),
          _InfoItem(
            icono: Icons.check_circle_outline_rounded,
            texto: 'Genera códigos de desbloqueo cuando necesites acceder',
          ),
          const SizedBox(height: 8),
          _InfoItem(
            icono: Icons.check_circle_outline_rounded,
            texto: 'Cada código desbloquea apps por el tiempo configurado',
          ),
          const SizedBox(height: 8),
          _InfoItem(
            icono: Icons.check_circle_outline_rounded,
            texto: 'Los intentos se renuevan cada mes automáticamente',
          ),
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icono;
  final String texto;

  const _InfoItem({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, color: Colors.green, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            texto,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey[700],
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

/* ----------------------------- DIÁLOGOS ----------------------------- */

class _DialogoEditarLimite extends StatefulWidget {
  final double limiteActual;

  const _DialogoEditarLimite({required this.limiteActual});

  @override
  State<_DialogoEditarLimite> createState() => _DialogoEditarLimiteState();
}

class _DialogoEditarLimiteState extends State<_DialogoEditarLimite> {
  late TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.limiteActual.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.edit_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          const Text('Editar Límite Mensual'),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Nuevo límite (S/)',
                prefixIcon: Icon(Icons.monetization_on_rounded),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Ingresa un valor';
                }
                final numero = double.tryParse(value);
                if (numero == null || numero <= 0) {
                  return 'Debe ser mayor a 0';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final valor = double.parse(_controller.text);
              Navigator.of(context).pop(valor);
            }
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _DialogoCambiarHoras extends StatefulWidget {
  final int horasActuales;

  const _DialogoCambiarHoras({required this.horasActuales});

  @override
  State<_DialogoCambiarHoras> createState() => _DialogoCambiarHorasState();
}

class _DialogoCambiarHorasState extends State<_DialogoCambiarHoras> {
  late int _horas;

  @override
  void initState() {
    super.initState();
    _horas = widget.horasActuales;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.access_time_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          const Text('Horas de Desbloqueo'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Selecciona cuántas horas permanecerán desbloqueadas las apps bancarias',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline_rounded),
                onPressed: _horas > 1 ? () => setState(() => _horas--) : null,
                iconSize: 36,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  '$_horas h',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded),
                onPressed: _horas < 72 ? () => setState(() => _horas++) : null,
                iconSize: 36,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Rango: 1 - 72 horas',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_horas),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _DialogoCodigoGenerado extends StatelessWidget {
  final String codigo;

  const _DialogoCodigoGenerado({required this.codigo});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.vpn_key_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          const Text('Código Generado'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Tu código de desbloqueo es:',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.3),
              ),
            ),
            child: SelectableText(
              codigo,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
                letterSpacing: 4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: codigo));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Código copiado al portapapeles'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copiar Código'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

class _DialogoConfirmacion extends StatelessWidget {
  const _DialogoConfirmacion();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.warning_rounded, color: Colors.orange),
          const SizedBox(width: 8),
          const Text('Confirmar Desactivación'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¿Estás seguro de que deseas desactivar el sistema?',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Esto hará que:',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[800],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '• Se desbloqueen todas las apps bancarias\n'
                  '• Se reinicie el contador de intentos\n'
                  '• Se pierda el seguimiento del periodo actual',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.orange[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Desactivar'),
        ),
      ],
    );
  }
}
