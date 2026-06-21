import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../home/home_screen.dart';
import '../absensi/riwayat_screen.dart';
import '../absensi/izin_screen.dart';
import '../screens/profile_screen.dart';
import '../services/supabase_service.dart';
import '../screens/login_screen.dart';
import '../admin/admin_shell.dart';

class MainNav extends StatefulWidget {
  const MainNav({super.key});

  @override
  State<MainNav> createState() => _MainNavState();
}

class _MainNavState extends State<MainNav> {
  int _selectedIndex = 0;
  String _role = 'mahasiswa';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchRole();
  }

  Future<void> _fetchRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
      return;
    }

    final r = await SupabaseService.getUserRole(user.id);
    if (mounted) {
      setState(() {
        _role = r ?? 'mahasiswa';
        _loading = false;
      });
    }
  }

  List<Widget> _getScreens() {
    if (_role == 'admin') {
      return [
        const HomeScreen(), // Admin Dashboard (originally maps to AdminScreen inside HomeScreen build)
        const RiwayatScreen(), // All History
        const ProfileScreen(),
      ];
    } else if (_role == 'dosen') {
      return [
        const HomeScreen(), // Dosen Dashboard
        const RiwayatScreen(), // Lecturer History
        const ProfileScreen(),
      ];
    } else {
      // mahasiswa / user
      return [
        const HomeScreen(), // Mahasiswa Dashboard
        const RiwayatScreen(), // Personal History
        const IzinScreen(), // Form Cuti/Izin
        const ProfileScreen(),
      ];
    }
  }

  List<NavigationDestination> _getNavDestinations() {
    if (_role == 'admin') {
      return [
        const NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        const NavigationDestination(
          icon: Icon(Icons.history_outlined),
          selectedIcon: Icon(Icons.history),
          label: 'Riwayat',
        ),
        const NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'Profil',
        ),
      ];
    } else if (_role == 'dosen') {
      return [
        const NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_filled),
          label: 'Beranda',
        ),
        const NavigationDestination(
          icon: Icon(Icons.history_outlined),
          selectedIcon: Icon(Icons.history),
          label: 'Riwayat',
        ),
        const NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'Profil',
        ),
      ];
    } else {
      // mahasiswa
      return [
        const NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_filled),
          label: 'Beranda',
        ),
        const NavigationDestination(
          icon: Icon(Icons.history_outlined),
          selectedIcon: Icon(Icons.history),
          label: 'Riwayat',
        ),
        const NavigationDestination(
          icon: Icon(Icons.edit_calendar_outlined),
          selectedIcon: Icon(Icons.edit_calendar),
          label: 'Izin',
        ),
        const NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'Profil',
        ),
      ];
    }
  }

  @override
Widget build(BuildContext context) {
  if (_loading) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  // ADMIN langsung masuk AdminShell
  if (_role == 'admin') {
    return const AdminShell();
  }

  final screens = _getScreens();

  return Scaffold(
    body: IndexedStack(
      index: _selectedIndex,
      children: screens,
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) {
        setState(() {
          _selectedIndex = index;
        });
      },
      destinations: _getNavDestinations(),
      elevation: 8,
      backgroundColor: Colors.white,
      indicatorColor:
          Theme.of(context).colorScheme.primary.withOpacity(0.12),
    ),
  );
}
}
