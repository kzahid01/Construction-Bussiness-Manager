import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/splash_screen.dart';
import 'navigation/app_router.dart';
import 'utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Status bar style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: const ConstructionApp(),
    ),
  );
}

class ConstructionApp extends StatelessWidget {
  const ConstructionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Construction Manager',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      onGenerateRoute: generateRoute,
      home: const _AppGate(),
    );
  }
}

/// Watches [AuthProvider] and routes between Splash → Login → Home reactively.
class _AppGate extends StatefulWidget {
  const _AppGate();

  @override
  State<_AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<_AppGate> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _bootSplash();
  }

  Future<void> _bootSplash() async {
    // Trigger auto-login attempt while the splash shows
    await context.read<AuthProvider>().tryAutoLogin();
    if (mounted) setState(() => _showSplash = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) return const SplashScreen();

    final auth = context.watch<AuthProvider>();
    if (!auth.isLoggedIn) return const LoginScreen();
    return const MainNavShell();
  }
}
