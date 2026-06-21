import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'navigation/main_nav.dart';
import 'screens/login_screen.dart';
import 'screens/reset_password_screen.dart';
import 'supabase_client.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

late final StreamSubscription<AuthState> authSub;
late List<CameraDescription> cameras;

Future<void> _setupCameras() async {
  try {
    cameras = await availableCameras();
  } catch (e) {
    cameras = [];
    debugPrint('No cameras found: $e');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fix locale Indonesia untuk DateFormat
  await initializeDateFormatting('id_ID', null);

  await _setupCameras();
  await SupabaseClientConfig.initialize();

  authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    final event = data.event;

    if (event == AuthChangeEvent.passwordRecovery) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => const ResetPasswordScreen(),
        ),
      );
    }
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Widget _getInitialScreen() {
    final session = Supabase.instance.client.auth.currentSession;

    if (session != null) {
      return const MainNav();
    }

    return const LoginScreen();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Absensi Wajah',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF005F73),
          primary: const Color(0xFF005F73),
          secondary: const Color(0xFF0A9396),
          surface: const Color(0xFFF8F9FA),
        ),
      ),
      home: _getInitialScreen(),
    );
  }
}