import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'utils/theme.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/forecast/forecast_screen.dart';
import 'screens/price_pilot/price_pilot_screen.dart';
import 'screens/sales/sales_history_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/staff/staff_login_screen.dart';
import 'services/auth_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const SaleCentraApp());
}

class SaleCentraApp extends StatefulWidget {
  const SaleCentraApp({super.key});

  @override
  State<SaleCentraApp> createState() => _SaleCentraAppState();
}

class _SaleCentraAppState extends State<SaleCentraApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkSessionTimeout();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _authService.updateLastActivity();
    }
  }

  Future<void> _checkSessionTimeout() async {
    final isExpired = await _authService.isSessionExpired();
    if (isExpired && mounted) {
      await _authService.logout();
      _navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SaleCentra',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      navigatorKey: _navigatorKey,
      home: const SplashScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/forecast': (context) => const ForecastScreen(),
        '/price-pilot': (context) => const PricePilotScreen(),
        '/sales-history': (context) => const SalesHistoryScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/staff-login': (context) => const StaffLoginScreen(),
      },
    );
  }
}
