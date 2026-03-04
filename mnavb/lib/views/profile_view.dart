import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/app_routes.dart';
import '../models/backend_type.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final _firebaseService = FirebaseService();
  UserModel? _user;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final userId = _firebaseService.currentUserId;
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }

      final user = await _firebaseService.getUser(userId);
      if (!mounted) return;

      setState(() {
        _user = user;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesion'),
        content: const Text('Se cerrara tu sesion actual.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar sesion'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await _firebaseService.logout();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_uid');

    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
  }

  Future<void> _copyUserId() async {
    final id = _user?.id;
    if (id == null || id.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: id));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ID copiado al portapapeles')),
    );
  }

  String _initialsFromName(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Future<void> _openEditProfileSheet() async {
    final current = _user;
    if (current == null) return;

    final nameCtrl = TextEditingController(text: current.name);
    final userCtrl = TextEditingController(text: current.username);
    final phoneCtrl = TextEditingController(text: current.phone ?? '');
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final sheet = isDark ? const Color(0xFF14151A) : Colors.white;
        final stroke = isDark
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.black.withValues(alpha: 0.08);

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  decoration: BoxDecoration(
                    color: sheet,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    border: Border.all(color: stroke),
                  ),
                  child: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Editar perfil',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Nombre completo',
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Campo requerido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: userCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Nombre de usuario',
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Campo requerido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: phoneCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Telefono (opcional)',
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(9),
                            ],
                            validator: (v) {
                              final value = (v ?? '').trim();
                              if (value.isEmpty) return null;
                              if (!RegExp(r'^\d{9}$').hasMatch(value)) {
                                return 'Debe tener 9 digitos';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: saving
                                      ? null
                                      : () => Navigator.pop(context),
                                  child: const Text('Cancelar'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: saving
                                      ? null
                                      : () async {
                                          if (!formKey.currentState!
                                              .validate()) {
                                            return;
                                          }

                                          setSheetState(() => saving = true);
                                          try {
                                            await _firebaseService
                                                .updateUserProfile(
                                                  name: nameCtrl.text,
                                                  username: userCtrl.text,
                                                  phone: phoneCtrl.text,
                                                );

                                            if (!mounted) return;
                                            Navigator.pop(context);
                                            await _loadUser();
                                            if (!mounted) return;
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Perfil actualizado',
                                                    ),
                                                  ),
                                                );
                                          } catch (e) {
                                            if (!mounted) return;
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      e
                                                          .toString()
                                                          .replaceAll(
                                                            'Exception: ',
                                                            '',
                                                          ),
                                                    ),
                                                    backgroundColor:
                                                        Colors.red.shade600,
                                                  ),
                                                );
                                          } finally {
                                            if (mounted) {
                                              setSheetState(() => saving = false);
                                            }
                                          }
                                        },
                                  child: saving
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text('Guardar'),
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
            );
          },
        );
      },
    );

    nameCtrl.dispose();
    userCtrl.dispose();
    phoneCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.06);
    final card = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white;
    final muted = isDark
        ? Colors.white.withValues(alpha: 0.65)
        : Colors.black.withValues(alpha: 0.55);
    final soft = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.black.withValues(alpha: 0.03);
    final currentUser = _user;

    return SafeArea(
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loadUser,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Perfil',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Spacer(),
                          OutlinedButton.icon(
                            onPressed: _openEditProfileSheet,
                            icon: const Icon(Icons.edit_rounded, size: 18),
                            label: const Text('Editar'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: border),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isDark
                                ? [
                                    const Color(0xFF20232A),
                                    const Color(0xFF121317),
                                  ]
                                : [
                                    const Color(0xFFF7F7F9),
                                    Colors.white,
                                  ],
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 66,
                              height: 66,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.08),
                                border: Border.all(
                                  color: (isDark ? Colors.white : Colors.black)
                                      .withValues(alpha: 0.16),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  _initialsFromName(currentUser?.name ?? ''),
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    currentUser?.name ?? '-',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '@${currentUser?.username ?? '-'}',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: muted,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(999),
                                      color:
                                          (isDark ? Colors.white : Colors.black)
                                              .withValues(alpha: 0.08),
                                    ),
                                    child: Text(
                                      currentUser?.backendType.label ?? '-',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SectionCard(
                        title: 'Informacion personal',
                        color: card,
                        border: border,
                        child: Column(
                          children: [
                            _DataTile(
                              icon: Icons.person_rounded,
                              label: 'Nombre completo',
                              value: currentUser?.name ?? '-',
                              muted: muted,
                            ),
                            _DataTile(
                              icon: Icons.badge_rounded,
                              label: 'Usuario',
                              value: currentUser?.username ?? '-',
                              muted: muted,
                            ),
                            _DataTile(
                              icon: Icons.phone_rounded,
                              label: 'Telefono',
                              value: (currentUser?.phone == null ||
                                      currentUser!.phone!.trim().isEmpty)
                                  ? '-'
                                  : currentUser.phone!,
                              muted: muted,
                              isLast: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SectionCard(
                        title: 'Cuenta',
                        color: card,
                        border: border,
                        child: Column(
                          children: [
                            _DataTile(
                              icon: Icons.email_rounded,
                              label: 'Correo',
                              value: currentUser?.email ?? '-',
                              muted: muted,
                            ),
                            _DataTile(
                              icon: Icons.fingerprint_rounded,
                              label: 'ID de usuario',
                              value: currentUser?.id ?? '-',
                              muted: muted,
                              trailing: TextButton.icon(
                                onPressed: _copyUserId,
                                icon: const Icon(Icons.copy_rounded, size: 16),
                                label: const Text('Copiar'),
                              ),
                            ),
                            _DataTile(
                              icon: Icons.storage_rounded,
                              label: 'Backend',
                              value:
                                  currentUser?.backendType.storageValue ?? '-',
                              muted: muted,
                              isLast: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: soft,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: border),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded, color: muted),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Puedes actualizar nombre, usuario y telefono desde el boton Editar.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: muted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _logout,
                          icon: const Icon(Icons.logout_rounded),
                          label: const Text('Cerrar sesion'),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Color color;
  final Color border;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.color,
    required this.border,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _DataTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color muted;
  final bool isLast;
  final Widget? trailing;

  const _DataTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.muted,
    this.isLast = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tileBorder = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.06);

    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tileBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 18, color: muted),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}
