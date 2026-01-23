import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'izin_cuti_screen.dart';
import 'riwayat_screen.dart';
import 'statistik_screen.dart';
import '../../services/supabase_service.dart';
import 'absenScreen.dart';


// Halaman utama dengan menu berdasarkan role user
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// Halaman utama dengan menu berdasarkan role user
class _HomeScreenState extends State<HomeScreen> {
  String role = 'user';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _fetchRole();
  }

// Ambil role user dari Supabase
  Future<void> _fetchRole() async {
  final user = Supabase.instance.client.auth.currentUser;

  if (user != null) {
    final r = await SupabaseService.getUserRole(user.id);

    setState(() {
      role = r ?? 'user';
      loading = false;
    });
  } else {
    setState(() => loading = false);
  }
}


  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

// Cek apakah user adalah admin
    final isAdmin = role == 'admin';

    // List menu berdasarkan role
    List<Widget> menuCards = [];
    if (isAdmin) {
      menuCards.addAll([
        _buildMenuCard(
          context,
          icon: Icons.list_alt,
          color: Colors.blue.shade600,
          title: 'Data Absensi',
          subtitle: 'Lihat semua absensi, izin, sakit, cuti mahasiswa',
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const RiwayatScreen())),
        ),
        _buildMenuCard(
          context,
          icon: Icons.bar_chart,
          color: Colors.green.shade600,
          title: 'Statistik',
          subtitle: 'Jumlah hadir, telat, izin',
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const StatistikScreen())),
        ),
      ]);
    } else {
      menuCards.addAll([
        _buildMenuCard(
          context,
          icon: Icons.camera_alt,
          color: Colors.blue.shade600,
          title: 'Absen Hadir',
          subtitle: 'Selfie + Deteksi Wajah + Lokasi GPS',
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const AbsenScreen())),
        ),
        _buildMenuCard(
          context,
          icon: Icons.edit_calendar,
          color: Colors.orange.shade600,
          title: 'Ajukan Izin/Cuti/Sakit',
          subtitle: 'Lengkapi form dan lampirkan foto bukti',
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const IzinCutiScreen())),
        ),
        _buildMenuCard(
          context,
          icon: Icons.history,
          color: Colors.green.shade600,
          title: 'Lihat Riwayat',
          subtitle: 'Realtime + thumbnail foto',
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const RiwayatScreen())),
        ),
      ]);
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade700, Colors.blue.shade300],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                child: Text(
                  isAdmin ? 'Dashboard Admin' : 'Absensi Wajah',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ListView(
                    children: [
                      const SizedBox(height: 20),
                      ...menuCards,
                      const SizedBox(height: 50),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 15,
      shadowColor: color.withOpacity(0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              colors: [Colors.white, color.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 100, color: color),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
