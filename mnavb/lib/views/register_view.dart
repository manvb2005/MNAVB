import 'package:flutter/material.dart';
import '../app/app_routes.dart';
import '../models/backend_type.dart';
import '../utils/auth_background.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../viewmodels/register_viewmodel.dart';
import '../widgets/loader_overlay.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final nameCtrl = TextEditingController();
  final userCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();
  bool showPass = false;
  bool showConfirm = false;
  BackendType _backendType = BackendType.firebase;

  @override
  void dispose() {
    nameCtrl.dispose();
    userCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();
    confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthBackground(
        child: LoaderOverlay(
          show: context.watch<RegisterViewModel>().isLoading,
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth < 600 ? c.maxWidth * 0.9 : 420.0;
              return Center(
                child: SizedBox(
                  width: w,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pushNamedAndRemoveUntil(
                              context,
                              AppRoutes.login,
                              (route) => false,
                            ),
                            icon: const Icon(Icons.arrow_back),
                          ),
                          const Spacer(),
                        ],
                      ),
                      _card(
                        context,
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                '¡Regístrate!',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 18),
                              TextField(
                                controller: nameCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Nombre completo',
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: userCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Nombre de usuario',
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: phoneCtrl,
                                keyboardType: TextInputType.number,
                                maxLength: 9,
                                decoration: const InputDecoration(
                                  labelText: 'Teléfono',
                                  counterText: '',
                                ),
                                inputFormatters: [
                                  // Solo números
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: emailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: 'Correo electrónico',
                                  suffixText: '@gmail.com',
                                ),
                                onChanged: (value) {
                                  // Evitar que el usuario escriba el @gmail.com
                                  if (value.contains('@')) {
                                    final beforeAt = value.split('@')[0];
                                    emailCtrl.text = beforeAt;
                                    emailCtrl.selection =
                                        TextSelection.fromPosition(
                                          TextPosition(offset: beforeAt.length),
                                        );
                                  }
                                },
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: passCtrl,
                                obscureText: !showPass,
                                decoration: InputDecoration(
                                  labelText: 'Contraseña',
                                  suffixIcon: IconButton(
                                    onPressed: () =>
                                        setState(() => showPass = !showPass),
                                    icon: Icon(
                                      showPass
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: confirmCtrl,
                                obscureText: !showConfirm,
                                decoration: InputDecoration(
                                  labelText: 'Confirmar contraseña',
                                  suffixIcon: IconButton(
                                    onPressed: () => setState(
                                      () => showConfirm = !showConfirm,
                                    ),
                                    icon: Icon(
                                      showConfirm
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              _BackendDataSourceSelector(
                                value: _backendType,
                                onChanged: (value) {
                                  setState(() => _backendType = value);
                                },
                              ),
                              const SizedBox(height: 40),
                              Consumer<RegisterViewModel>(
                                builder: (context, registerVM, _) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        ElevatedButton(
                                          onPressed: registerVM.isLoading
                                              ? null
                                              : () async {
                                                  final registerVM =
                                                      Provider.of<
                                                        RegisterViewModel
                                                      >(context, listen: false);
                                                  final ok = await registerVM
                                                      .register(
                                                        name: nameCtrl.text
                                                            .trim(),
                                                        username: userCtrl.text
                                                            .trim(),
                                                        email: emailCtrl.text
                                                            .trim(),
                                                        password: passCtrl.text,
                                                        confirmPassword:
                                                            confirmCtrl.text,
                                                        phone:
                                                            phoneCtrl.text
                                                                .trim()
                                                                .isEmpty
                                                            ? null
                                                            : phoneCtrl.text
                                                                  .trim(),
                                                        backendType:
                                                            _backendType,
                                                      );
                                                  if (!context.mounted) return;
                                                  if (ok) {
                                                    if (context.mounted) {
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        const SnackBar(
                                                          content: Text(
                                                            'Registro exitoso, inicia sesión.',
                                                          ),
                                                        ),
                                                      );
                                                      Navigator.pushNamedAndRemoveUntil(
                                                        context,
                                                        AppRoutes.login,
                                                        (r) => false,
                                                      );
                                                    }
                                                  } else if (registerVM
                                                          .errorMessage !=
                                                      null) {
                                                    if (context.mounted) {
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            registerVM
                                                                .errorMessage!,
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                  }
                                                },
                                          child: const Text('Crear cuenta'),
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Text('¿Ya tienes cuenta? '),
                                            GestureDetector(
                                              onTap: () =>
                                                  Navigator.pushNamedAndRemoveUntil(
                                                    context,
                                                    AppRoutes.login,
                                                    (r) => false,
                                                  ),
                                              child: const Text(
                                                'Inicia sesión',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, {required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : Colors.black).withAlpha(
              (isDark ? 0.35 : 0.10) * 255 ~/ 1,
            ),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _BackendDataSourceSelector extends StatelessWidget {
  final BackendType value;
  final ValueChanged<BackendType> onChanged;

  const _BackendDataSourceSelector({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? Colors.white12 : Colors.black12;
    final bg = isDark
        ? Colors.white.withAlpha((0.04 * 255).toInt())
        : Colors.black.withAlpha((0.03 * 255).toInt());

    Widget option(BackendType type) {
      final selected = value == type;
      return Expanded(
        child: InkWell(
          onTap: () => onChanged(type),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? theme.colorScheme.primary.withAlpha((0.12 * 255).toInt())
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? theme.colorScheme.primary.withAlpha((0.40 * 255).toInt())
                    : Colors.transparent,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type.label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  type.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? Colors.white.withAlpha((0.72 * 255).toInt())
                        : Colors.black.withAlpha((0.62 * 255).toInt()),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Origen de datos para tu cuenta',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              option(BackendType.firebase),
              const SizedBox(width: 8),
              option(BackendType.externalApi),
            ],
          ),
        ],
      ),
    );
  }
}
