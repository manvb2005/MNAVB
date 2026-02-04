import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/firebase_service.dart';

/* ----------------------------- DATA (MOCK) ----------------------------- */

class _BancoPredefinido {
  final String nombre;
  final String logo;
  const _BancoPredefinido({required this.nombre, required this.logo});
}

const _bancosPredefinidos = [
  _BancoPredefinido(
    nombre: 'BBVA',
    logo:
        'https://pps.services.adobe.com/api/profile/F1913DDA5A3BC47C0A495C08@AdobeID/image/b6c20c0d-0e3c-4e8e-9b60-c02ccf1cb54d/276',
  ),
  _BancoPredefinido(
    nombre: 'BCP',
    logo: 'https://www.epsgrau.pe/webpage/oficinavirtual/oficinas-pago/img/bcp.png',
  ),
  _BancoPredefinido(
    nombre: 'SCOTIABANK',
    logo: 'https://images.icon-icons.com/2699/PNG/512/scotiabank_logo_icon_170755.png',
  ),
  _BancoPredefinido(
    nombre: 'INTERBANK',
    logo: 'https://www.fabritec.pe/assets/media/logo-banco/logo-inter.png',
  ),
  _BancoPredefinido(
    nombre: 'YAPE',
    logo:
        'https://d1yjjnpx0p53s8.cloudfront.net/styles/logo-thumbnail/s3/032021/yape.png?nfeyt9DPqyQFYu7MebAfT.qYz11ytffk&itok=vkI2T5X4',
  ),
  _BancoPredefinido(
    nombre: 'PLIN',
    logo: 'https://images.seeklogo.com/logo-png/38/2/plin-logo-png_seeklogo-386806.png',
  ),
];

enum TipoCuenta { corriente, ahorro }

String _tipoCuentaLabel(TipoCuenta t) => t == TipoCuenta.corriente ? 'Corriente' : 'Ahorro';

/* ----------------------------- VIEW ----------------------------- */

class BancosView extends StatefulWidget {
  const BancosView({super.key});

  @override
  State<BancosView> createState() => _BancosViewState();
}

class _BancosViewState extends State<BancosView> {
  final _firebaseService = FirebaseService();

  Future<void> _openBancoSheet({Map<String, dynamic>? editBanco}) async {
    final res = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => _BancoFormSheet(initial: editBanco),
    );

    if (res == null || !mounted) return;

    try {
      if (editBanco == null) {
        await _firebaseService.agregarBanco(
          nombre: res['nombre'],
          logo: res['logo'],
          tipoCuenta: res['tipoCuenta'],
          alias: res['alias'],
          saldo: res['saldo'],
        );
        if (mounted) _showSuccess('Banco agregado exitosamente');
      } else {
        await _firebaseService.actualizarBanco(
          bancoId: editBanco['id'],
          nombre: res['nombre'],
          logo: res['logo'],
          tipoCuenta: res['tipoCuenta'],
          alias: res['alias'],
          saldo: res['saldo'],
        );
        if (mounted) _showSuccess('Banco actualizado exitosamente');
      }
    } catch (e) {
      if (mounted) _showError('Error: ${e.toString()}');
    }
  }

  void _confirmDelete(Map<String, dynamic> banco) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final card = isDark ? const Color(0xFF1C1D22) : Colors.white;
        final stroke =
            isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08);
        final fg = isDark ? Colors.white.withValues(alpha: 0.88) : Colors.black.withValues(alpha: 0.78);

        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: stroke),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.20),
                  blurRadius: 26,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.delete_rounded,
                      size: 28, color: isDark ? Colors.red.shade300 : Colors.red.shade700),
                  const SizedBox(height: 10),
                  Text(
                    'Eliminar banco',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: fg),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '¿Seguro que deseas eliminar ${banco['nombre']}${banco['alias'] != null ? ' (${banco['alias']})' : ''}?',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.white.withValues(alpha: 0.65) : Colors.black.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: stroke),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text('Cancelar', style: TextStyle(color: fg, fontWeight: FontWeight.w800)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            try {
                              await _firebaseService.eliminarBanco(banco['id']);
                              if (mounted) _showSuccess('Banco eliminado');
                            } catch (e) {
                              if (mounted) _showError('Error al eliminar');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? Colors.red.shade400 : Colors.red.shade700,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Eliminar', style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
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

    // Soft UI tokens (mismo estilo que tu Home)
    final surface = isDark ? const Color(0xFF0E0F12) : const Color(0xFFF7F7F9);
    final card = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white;
    final stroke =
        isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.06);
    final muted =
        isDark ? Colors.white.withValues(alpha: 0.65) : Colors.black.withValues(alpha: 0.55);
    final fg =
        isDark ? Colors.white.withValues(alpha: 0.88) : Colors.black.withValues(alpha: 0.78);
    final accent = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text('Bancos', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: fg)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: fg),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),

      // ✅ FAB pro (círculo +)
      floatingActionButton: _GlassFab(
        accent: accent,
        isDark: isDark,
        onTap: () => _openBancoSheet(),
      ),

      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _firebaseService.getBancosStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: muted),
                  const SizedBox(height: 16),
                  Text(
                    'Error al cargar bancos',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: fg),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final bancos = snapshot.data ?? [];

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header de ayuda
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: stroke),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: accent.withValues(alpha: 0.95), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Agrega bancos para ver su saldo y luego conectar tus movimientos.',
                            style: theme.textTheme.bodySmall?.copyWith(color: muted, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Lista
                  Expanded(
                    child: bancos.isEmpty
                        ? Center(
                            child: Text(
                              'No hay bancos agregados\nToca el + para agregar',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(color: muted, height: 1.25),
                            ),
                          )
                        : ListView.separated(
                            itemCount: bancos.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (_, i) {
                              return _BancoCardPro(
                                banco: bancos[i],
                                card: card,
                                stroke: stroke,
                                accent: accent,
                                fg: fg,
                                muted: muted,
                                isDark: isDark,
                                onEdit: () => _openBancoSheet(editBanco: bancos[i]),
                                onDelete: () => _confirmDelete(bancos[i]),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/* ----------------------------- PRO UI: FAB ----------------------------- */

class _GlassFab extends StatelessWidget {
  final Color accent;
  final bool isDark;
  final VoidCallback onTap;

  const _GlassFab({
    required this.accent,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: accent.withValues(alpha: isDark ? 0.18 : 0.12),
          border: Border.all(color: accent.withValues(alpha: 0.40), width: 2),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: isDark ? 0.25 : 0.18),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
              blurRadius: 22,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Icon(Icons.add_rounded, color: accent.withValues(alpha: 0.98), size: 30),
      ),
    );
  }
}

/* ----------------------------- PRO UI: CARD ----------------------------- */

class _BancoCardPro extends StatelessWidget {
  final Map<String, dynamic> banco;
  final Color card;
  final Color stroke;
  final Color accent;
  final Color fg;
  final Color muted;
  final bool isDark;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BancoCardPro({
    required this.banco,
    required this.card,
    required this.stroke,
    required this.accent,
    required this.fg,
    required this.muted,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tipoCuenta = banco['tipoCuenta'] ?? 'Corriente';
    final saldo = (banco['saldo'] as num?)?.toDouble() ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: stroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          // Logo con aro/accent
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
              border: Border.all(color: accent.withValues(alpha: 0.35), width: 2),
            ),
            child: ClipOval(
              child: Image.network(
                banco['logo'] ?? '',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(Icons.account_balance, color: accent),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        banco['nombre'] ?? 'Sin nombre',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: fg,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _Pill(
                      text: tipoCuenta,
                      bg: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                      fg: muted,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if ((banco['alias'] ?? '').toString().trim().isNotEmpty)
                  _Pill(
                    text: banco['alias'].toString().trim(),
                    bg: accent.withValues(alpha: isDark ? 0.16 : 0.10),
                    fg: accent.withValues(alpha: 0.95),
                  ),

                const SizedBox(height: 10),

                Row(
                  children: [
                    Text(
                      'S/ ${saldo.toStringAsFixed(2)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: accent.withValues(alpha: 0.95),
                      ),
                    ),
                    const Spacer(),
                    _IconPillButton(
                      icon: Icons.edit_rounded,
                      onTap: onEdit,
                      bg: accent.withValues(alpha: isDark ? 0.16 : 0.10),
                      fg: accent.withValues(alpha: 0.95),
                    ),
                    const SizedBox(width: 8),
                    _IconPillButton(
                      icon: Icons.delete_rounded,
                      onTap: onDelete,
                      bg: (isDark ? Colors.red : Colors.red).withValues(alpha: 0.14),
                      fg: isDark ? Colors.red.shade300 : Colors.red.shade700,
                    ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;

  const _Pill({required this.text, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900, color: fg, fontSize: 11),
      ),
    );
  }
}

class _IconPillButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color bg;
  final Color fg;

  const _IconPillButton({
    required this.icon,
    required this.onTap,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, size: 18, color: fg),
      ),
    );
  }
}

/* ----------------------------- PRO UI: FORM (BOTTOM SHEET) ----------------------------- */

class _BancoFormSheet extends StatefulWidget {
  final Map<String, dynamic>? initial;
  const _BancoFormSheet({this.initial});

  @override
  State<_BancoFormSheet> createState() => _BancoFormSheetState();
}

class _BancoFormSheetState extends State<_BancoFormSheet> {
  _BancoPredefinido? _bancoSel;
  TipoCuenta? _tipoSel;
  final _alias = TextEditingController();
  final _saldo = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final ini = widget.initial;
    if (ini != null) {
      _bancoSel = _bancosPredefinidos.firstWhere(
        (b) => b.nombre == ini['nombre'],
        orElse: () => _bancosPredefinidos.first,
      );
      final tipoCuentaStr = ini['tipoCuenta'] ?? 'Corriente';
      _tipoSel = tipoCuentaStr == 'Corriente' ? TipoCuenta.corriente : TipoCuenta.ahorro;
      _alias.text = ini['alias'] ?? '';
      final saldoNum = (ini['saldo'] as num?)?.toDouble() ?? 0.0;
      _saldo.text = saldoNum.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _alias.dispose();
    _saldo.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    if (_bancoSel == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona un banco')));
      return;
    }
    if (_tipoSel == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona el tipo de cuenta')));
      return;
    }

    final saldo = double.tryParse(_saldo.text.replaceAll(',', '.')) ?? 0.0;

    Navigator.pop(
      context,
      {
        'nombre': _bancoSel!.nombre,
        'logo': _bancoSel!.logo,
        'tipoCuenta': _tipoCuentaLabel(_tipoSel!),
        'alias': _alias.text.trim().isEmpty ? null : _alias.text.trim(),
        'saldo': saldo,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final sheet = isDark ? const Color(0xFF14151A) : Colors.white;
    final stroke =
        isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08);
    final fg =
        isDark ? Colors.white.withValues(alpha: 0.88) : Colors.black.withValues(alpha: 0.78);
    final muted =
        isDark ? Colors.white.withValues(alpha: 0.65) : Colors.black.withValues(alpha: 0.55);
    final accent = theme.colorScheme.primary;

    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Container(
          decoration: BoxDecoration(
            color: sheet,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            border: Border.all(color: stroke),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.22),
                blurRadius: 30,
                offset: const Offset(0, -10),
              )
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // handle
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

                    Row(
                      children: [
                        Text(
                          widget.initial == null ? 'Agregar banco' : 'Editar banco',
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
                    const SizedBox(height: 6),
                    Text(
                      'Selecciona banco, tipo, alias y saldo inicial.',
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                    const SizedBox(height: 16),

                    Text('Banco', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900, color: fg)),
                    const SizedBox(height: 10),

                    // ✅ Selector horizontal pro
                    SizedBox(
                      height: 92,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _bancosPredefinidos.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (_, i) {
                          final b = _bancosPredefinidos[i];
                          final selected = _bancoSel?.nombre == b.nombre;

                          return InkWell(
                            onTap: () => setState(() => _bancoSel = b),
                            borderRadius: BorderRadius.circular(20),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 110,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: selected
                                    ? accent.withValues(alpha: isDark ? 0.18 : 0.12)
                                    : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: selected ? accent.withValues(alpha: 0.45) : stroke,
                                  width: selected ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                      border: Border.all(color: stroke),
                                    ),
                                    child: ClipOval(
                                      child: Image.network(
                                        b.logo,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) =>
                                            Icon(Icons.account_balance, color: accent, size: 18),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    b.nombre,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11,
                                      color: selected ? accent.withValues(alpha: 0.95) : fg,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 18),
                    Text('Tipo de cuenta',
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900, color: fg)),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: _ToggleChip(
                            label: 'Corriente',
                            selected: _tipoSel == TipoCuenta.corriente,
                            onTap: () => setState(() => _tipoSel = TipoCuenta.corriente),
                            accent: accent,
                            stroke: stroke,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ToggleChip(
                            label: 'Ahorro',
                            selected: _tipoSel == TipoCuenta.ahorro,
                            onTap: () => setState(() => _tipoSel = TipoCuenta.ahorro),
                            accent: accent,
                            stroke: stroke,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    Text('Alias (opcional)',
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900, color: fg)),
                    const SizedBox(height: 10),
                    _SoftField(
                      controller: _alias,
                      hint: 'Ej: Personal, Negocio',
                      isDark: isDark,
                      stroke: stroke,
                      accent: accent,
                      fg: fg,
                      muted: muted,
                      validator: (_) => null,
                    ),

                    const SizedBox(height: 18),

                    Text('Saldo actual',
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900, color: fg)),
                    const SizedBox(height: 10),
                    _SoftField(
                      controller: _saldo,
                      hint: '0.00',
                      prefix: 'S/ ',
                      isDark: isDark,
                      stroke: stroke,
                      accent: accent,
                      fg: fg,
                      muted: muted,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+([.,]\d{0,2})?$'))],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Ingresa el saldo';
                        final value = double.tryParse(v.replaceAll(',', '.'));
                        if (value == null) return 'Saldo inválido';
                        if (value < 0) return 'No puede ser negativo';
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: stroke),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text('Cancelar', style: TextStyle(color: fg, fontWeight: FontWeight.w900)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(widget.initial == null ? 'Agregar' : 'Guardar',
                                style: const TextStyle(fontWeight: FontWeight.w900)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color accent;
  final Color stroke;
  final bool isDark;

  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.accent,
    required this.stroke,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final fg = isDark ? Colors.white.withValues(alpha: 0.88) : Colors.black.withValues(alpha: 0.78);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: isDark ? 0.18 : 0.12)
              : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? accent.withValues(alpha: 0.45) : stroke,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: selected ? accent.withValues(alpha: 0.95) : fg,
          ),
        ),
      ),
    );
  }
}

class _SoftField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String? prefix;
  final bool isDark;
  final Color stroke;
  final Color accent;
  final Color fg;
  final Color muted;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?) validator;

  const _SoftField({
    required this.controller,
    required this.hint,
    required this.isDark,
    required this.stroke,
    required this.accent,
    required this.fg,
    required this.muted,
    required this.validator,
    this.prefix,
    this.keyboardType,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: fg, fontWeight: FontWeight.w800),
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: muted, fontWeight: FontWeight.w700),
        prefixText: prefix,
        prefixStyle: TextStyle(color: fg, fontWeight: FontWeight.w900),
        filled: true,
        fillColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: stroke),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: stroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.withValues(alpha: 0.65)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.withValues(alpha: 0.85), width: 2),
        ),
      ),
    );
  }
}
