
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'app/app_routes.dart';
import 'app/app_theme.dart';
import 'viewmodels/theme_provider.dart';
import 'viewmodels/remember_session_provider.dart';
import 'viewmodels/voucher_provider.dart';
import 'views/login_view.dart';
import 'views/register_view.dart';
import 'viewmodels/register_viewmodel.dart';

import 'views/main_nav_view.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => RememberSessionProvider()),
        ChangeNotifierProvider(create: (_) => VoucherProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Control Finanzas',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: theme.themeMode,
      initialRoute: AppRoutes.login,
      routes: {
        AppRoutes.login: (_) => const LoginView(),
        AppRoutes.register: (_) => ChangeNotifierProvider(
          create: (_) => RegisterViewModel(),
          child: const RegisterView(),
        ),
        AppRoutes.home: (_) => const MainNavView(),
      },
    );
  }
}

// ...existing code...

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
// ...existing code...
