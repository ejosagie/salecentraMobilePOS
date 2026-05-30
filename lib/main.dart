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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const SaleCentraApp());
}

class SaleCentraApp extends StatelessWidget {
  const SaleCentraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SaleCentra',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
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
