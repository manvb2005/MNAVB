import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app/app_routes.dart';
import '../utils/theme_switch.dart';
import '../viewmodels/remember_session_provider.dart';
import '../viewmodels/login_viewmodel.dart';
import '../models/backend_type.dart';
import '../utils/auth_background.dart';
import '../widgets/loader_overlay.dart';
import '../services/firebase_service.dart';
import '../services/native_overlay_service.dart';
import '../utils/notification_permission_helper.dart';

// ...existing code...

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  late final TextEditingController emailCtrl;
  late final TextEditingController passCtrl;
  bool showPassword = false;
  bool hydrated = false;
  Future<void>? _loadSessionFuture;

  @override
  void initState() {
    super.initState();
    emailCtrl = TextEditingController();
    passCtrl = TextEditingController();
    // Lanzar la carga de sesión al iniciar
    final remember = Provider.of<RememberSessionProvider>(
      context,
      listen: false,
    );
    _loadSessionFuture = remember.loadSession();
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  void _hydrateOnce(RememberSessionProvider remember, LoginViewModel loginVM) {
    if (hydrated) return;
    // Mostrar solo la parte antes de @ en el campo visual
    if (remember.email.isNotEmpty) {
      final beforeAt = remember.email.split('@')[0];
      emailCtrl.text = beforeAt;
    }
    passCtrl.text = remember.password;
    hydrated = true;
    // Ya no se hace login automático, solo se rellenan los campos
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LoginViewModel(),
      child: Consumer2<LoginViewModel, RememberSessionProvider>(
        builder: (context, loginVM, remember, _) {
          return FutureBuilder<void>(
            future: _loadSessionFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              _hydrateOnce(remember, loginVM);
              return Scaffold(
                body: AuthBackground(
                  child: LoaderOverlay(
                    show: loginVM.isLoading,
                    child: Stack(
                      children: [
                        const Positioned(
                          top: 0,
                          left: 0,
                          child: SafeArea(
                            minimum: EdgeInsets.only(top: 8, left: 10),
                            child: ThemeSwitch(),
                          ),
                        ),
                        LayoutBuilder(
                          builder: (context, c) {
                            final w = c.maxWidth < 600
                                ? c.maxWidth * 0.9
                                : 420.0;
                            return Center(
                              child: SizedBox(
                                width: w,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _card(
                                      context,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text(
                                            '¡Bienvenido!',
                                            style: TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 18),
                                          TextField(
                                            controller: emailCtrl,
                                            keyboardType:
                                                TextInputType.emailAddress,
                                            decoration: const InputDecoration(
                                              labelText: 'Correo electrónico',
                                              suffixText: '@gmail.com',
                                            ),
                                            onChanged: (value) {
                                              if (value.contains('@')) {
                                                final beforeAt = value.split(
                                                  '@',
                                                )[0];
                                                emailCtrl.text = beforeAt;
                                                emailCtrl.selection =
                                                    TextSelection.fromPosition(
                                                      TextPosition(
                                                        offset: beforeAt.length,
                                                      ),
                                                    );
                                              }
                                            },
                                          ),
                                          const SizedBox(height: 14),
                                          TextField(
                                            controller: passCtrl,
                                            obscureText: !showPassword,
                                            decoration: InputDecoration(
                                              labelText: 'Contraseña',
                                              suffixIcon: IconButton(
                                                onPressed: () => setState(
                                                  () => showPassword =
                                                      !showPassword,
                                                ),
                                                icon: Icon(
                                                  showPassword
                                                      ? Icons.visibility_off
                                                      : Icons.visibility,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 14),
                                          Row(
                                            children: [
                                              Switch(
                                                value: remember.remember,
                                                onChanged: (v) =>
                                                    remember.setRemember(v),
                                              ),
                                              const SizedBox(width: 8),
                                              const Text('Recordar sesión'),
                                            ],
                                          ),
                                          const SizedBox(height: 24),
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 14,
                                                    ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                textStyle: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              onPressed: loginVM.isLoading
                                                  ? null
                                                  : () async {
                                                      final ok = await loginVM
                                                          .login(
                                                            email:
                                                                "${emailCtrl.text.trim()}@gmail.com",
                                                            password:
                                                                passCtrl.text,
                                                          );
                                                      if (!mounted) return;
                                                      if (ok) {
                                                        BackendType
                                                        backendType =
                                                            BackendType
                                                                .firebase;

                                                        // Guardar credenciales si está activado "Recordar sesión"
                                                        if (remember.remember) {
                                                          await remember
                                                              .saveCredentials(
                                                                "${emailCtrl.text.trim()}@gmail.com",
                                                                passCtrl.text,
                                                              );
                                                        } else {
                                                          remember.setRemember(
                                                            false,
                                                          );
                                                        }

                                                        // IMPORTANTE: Guardar UID para procesamiento en background
                                                        final firebaseService =
                                                            FirebaseService();
                                                        final userId =
                                                            firebaseService
                                                                .currentUserId;
                                                        if (userId != null) {
                                                          backendType =
                                                              await firebaseService
                                                                  .getBackendTypeForUser(
                                                                    userId,
                                                                  );
                                                          await remember
                                                              .saveUserId(
                                                                userId,
                                                              );
                                                          await remember
                                                              .saveBackendTypeForUser(
                                                                userId,
                                                                backendType
                                                                    .storageValue,
                                                              );
                                                        }

                                                        // Solicitar permiso de notificaciones (importante para background)
                                                        if (mounted) {
                                                          await NotificationPermissionHelper.requestNotificationPermission(
                                                            context,
                                                          );
                                                        }

                                                        if (backendType ==
                                                            BackendType
                                                                .externalApi) {
                                                          final canOverlay =
                                                              await NativeOverlayService.canDrawOverlays();
                                                          if (!canOverlay) {
                                                            await NativeOverlayService.requestPermission();
                                                          }
                                                        }

                                                        if (mounted) {
                                                          Navigator.pushReplacementNamed(
                                                            context,
                                                            backendType ==
                                                                    BackendType
                                                                        .externalApi
                                                                ? AppRoutes
                                                                      .externalApiHome
                                                                : AppRoutes
                                                                      .home,
                                                          );
                                                        }
                                                      } else if (loginVM
                                                              .errorMessage !=
                                                          null) {
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                              loginVM
                                                                  .errorMessage!,
                                                            ),
                                                            behavior:
                                                                SnackBarBehavior
                                                                    .floating,
                                                          ),
                                                        );
                                                      }
                                                    },
                                              child: loginVM.isLoading
                                                  ? const SizedBox(
                                                      width: 22,
                                                      height: 22,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            color: Colors.white,
                                                          ),
                                                    )
                                                  : const Text(
                                                      'Iniciar sesión',
                                                    ),
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Text('¿No tienes cuenta? '),
                                              GestureDetector(
                                                onTap: () {
                                                  Navigator.pushReplacementNamed(
                                                    context,
                                                    AppRoutes.register,
                                                  );
                                                },
                                                child: const Text(
                                                  'Regístrate',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.blue,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
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
