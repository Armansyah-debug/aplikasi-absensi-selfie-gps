import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../absensi/riwayat_screen.dart';
import '../absensi/statistik_screen.dart';
import '../absensi/absenScreen.dart';
import '../absensi/izin_screen.dart';
import '../../services/supabase_service.dart';
import '../screens/login_screen.dart';
import '../admin/kelola_sesi_screen.dart';
import '../admin/kelola_mk_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String role = 'user';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _fetchRole();
  }

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
    final isAdmin = role == 'admin';
    final isDosen = role == 'dosen';
    final isMahasiswa = role == 'mahasiswa' || role == 'user';

    String getTitle() {
      if (isAdmin) return "Dashboard Admin";
      if (isDosen) return "Dashboard Dosen";
      return "Absensi";
    }

    List<Widget> getMenus() {
      if (isAdmin) return _adminMenu(context);
      if (isDosen) return _dosenMenu(context);
      return _userMenu(context);
    }

    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();

              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LoginScreen(),
                  ),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                getTitle(),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (isMahasiswa) _attendanceCard(),
                  const SizedBox(height: 16),
                  ...getMenus(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= GLASS STAT CARD =================
  Widget _attendanceCard() {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) return const SizedBox();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseService.streamMyData(user.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!;

        final hadir = data.where((e) => e['jenis'] == 'Hadir').length;
        final izin = data.where((e) => e['jenis'] == 'Izin').length;
        final sakit = data.where((e) => e['jenis'] == 'Sakit').length;

        final total = hadir + izin + sakit;
        final persen = total == 0 ? 0 : (hadir / total) * 100;

        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    '${persen.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF007AFF),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Persentase Kehadiran",
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 14),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statItem("Hadir", hadir),
                      _statItem("Izin", izin),
                      _statItem("Sakit", sakit),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _statItem(String label, int value) {
    return Column(
      children: [
        Text(label),
        const SizedBox(height: 4),
        Text(
          "$value",
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ================= USER MENU =================
  List<Widget> _userMenu(BuildContext context) => [
        _menuCard(
          icon: Icons.camera_alt_rounded,
          title: "Absen Hadir",
          subtitle: "Selfie + GPS otomatis",
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AbsenScreen()),
          ),
        ),
        const SizedBox(height: 12),
        _menuCard(
          icon: Icons.edit_calendar_rounded,
          title: "Izin / Sakit",
          subtitle: "Ajukan permohonan",
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const IzinScreen()),
          ),
        ),
        const SizedBox(height: 12),
        _menuCard(
          icon: Icons.history_rounded,
          title: "Riwayat",
          subtitle: "Lihat data absensi",
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RiwayatScreen()),
          ),
        ),
      ];

  // ================= DOSEN MENU =================
  List<Widget> _dosenMenu(BuildContext context) => [
        _menuCard(
          icon: Icons.schedule_rounded,
          title: "Kelola Sesi",
          subtitle: "Buka / Tutup absensi",
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const KelolaSesiScreen(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _menuCard(
          icon: Icons.history_rounded,
          title: "Riwayat",
          subtitle: "Lihat data absensi",
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RiwayatScreen()),
          ),
        ),
      ];

  // ================= ADMIN MENU =================
  List<Widget> _adminMenu(BuildContext context) => [
        _menuCard(
          icon: Icons.list_alt_rounded,
          title: "Data Absensi",
          subtitle: "Semua data user",
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RiwayatScreen()),
          ),
        ),
        const SizedBox(height: 12),
        _menuCard(
          icon: Icons.bar_chart_rounded,
          title: "Statistik",
          subtitle: "Rekap kehadiran",
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StatistikScreen()),
          ),
        ),
        const SizedBox(height: 12),
        _menuCard(
          icon: Icons.book_outlined,
          title: "Kelola Mata Kuliah",
          subtitle: "Tambah, edit, hapus mata kuliah",
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const KelolaMKScreen()),
          ),
        ),
        const SizedBox(height: 12),
        _menuCard(
          icon: Icons.schedule_rounded,
          title: "Kelola Sesi",
          subtitle: "Buka / Tutup absensi",
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const KelolaSesiScreen(),
            ),
          ),
        ),
      ];

  // ================= iOS STYLE MENU CARD =================
  Widget _menuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF007AFF),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
