import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:camera/camera.dart';

import 'screens/login_screen.dart';
import 'screens/reset_password_screen.dart';
import 'home/home_screen.dart';

import 'supabase_client.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
late final StreamSubscription<AuthState> authSub;
late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  cameras = await availableCameras();
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

  // 🔥 FUNGSI UTAMA: Mengecek status session di memori HP
  Widget _getInitialScreen() {
    final session = Supabase.instance.client.auth.currentSession;

    if (session != null) {
      // Jika session ada/user sudah login, langsung buka halaman utama
      return const HomeScreen();
    } else {
      // Jika session kosong, lempar ke halaman login
      return const LoginScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Absensi Wajah',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      // 🔥 KODE DIUBAH: Sekarang menggunakan pengecekan otomatis
      home: _getInitialScreen(),
    );
  }
}
