import 'package:discovery_app/pages/staff_directory_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pages/discovery_screen.dart';
import 'pages/dashboard_screen.dart';
import 'pages/sign_in_screen.dart';
import 'pages/sign_up_screen.dart';
import 'pages/services_screen.dart';
import 'package:discovery_app/pages/booking_screen.dart';
import 'pages/bookings_screen.dart';
import 'pages/profile_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();

  const fromDefineUrl = String.fromEnvironment('SUPABASE_URL');
  const fromDefineKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  final supabaseUrl = fromDefineUrl.isNotEmpty
      ? fromDefineUrl
      : dotenv.env['SUPABASE_URL'] ?? '';

  final supabaseAnonKey = fromDefineKey.isNotEmpty
      ? fromDefineKey
      : dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    throw Exception('Missing Supabase config');
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  bool isLoggedIn() {
    final user = Supabase.instance.client.auth.currentUser;
    return user != null;
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
      ),
    );

    return MaterialApp(
      title: 'M Speed On The Go',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF2A86DE),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2A86DE),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Poppins',
      ),
      initialRoute: '/discovery',
      onGenerateRoute: (settings) {
        final protectedRoutes = ['/bookings', '/services', '/profile', '/booking'];

        if (protectedRoutes.contains(settings.name) && !isLoggedIn()) {
          return MaterialPageRoute(builder: (_) => const DashboardScreen());
        }

        // Route map
        switch (settings.name) {
          case '/':
          case '/dashboard':
            return MaterialPageRoute(builder: (_) => const DashboardScreen());
          case '/discovery':
            return MaterialPageRoute(builder: (_) => const DiscoveryScreen());
          case '/sign-in':
            return MaterialPageRoute(builder: (_) => const SignInScreen());
          case '/sign-up':
            return MaterialPageRoute(builder: (_) => const SignUpScreen());
          case '/services':
            return MaterialPageRoute(builder: (_) => const ServicesScreen());
          case '/booking':
            return MaterialPageRoute(builder: (_) => const BookingScreen());
          case '/bookings':
            return MaterialPageRoute(builder: (_) => const BookingsScreen());
          case '/profile':
            return MaterialPageRoute(builder: (_) => const ProfileScreen());
          case '/staff-directory':
            return MaterialPageRoute(builder: (_) => const StaffDirectoryScreen());
          default:
            return MaterialPageRoute(
              builder: (_) => const Scaffold(
                body: Center(child: Text('Page not found')),
              ),
            );
        }
      },
    );
  }
}