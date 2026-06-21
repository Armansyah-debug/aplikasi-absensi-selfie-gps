import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../absensi/riwayat_screen.dart';
import '../absensi/absenScreen.dart';
import '../absensi/izin_screen.dart';
import '../../services/supabase_service.dart';
import '../admin/admin_screen.dart';
import '../screens/login_screen.dart';
import '../admin/kelola_sesi_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String role = 'user';
  String nama = 'User';
  String npm = '-';
  String? jurusan;
  int? semester;
  bool loading = true;

  Map<String, dynamic>? _activeSesi;
  bool _fetchingSesi = false;

  @override
  void initState() {
    super.initState();
    _fetchProfileAndSesi();
  }

  Future<void> _fetchProfileAndSesi() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const LoginScreen(),
          ),
          (route) => false,
        );
      }
      return;
    }

    setState(() => loading = true);
    final profile = await SupabaseService.getUserProfile(user.id);

    if (mounted) {
      setState(() {
        role = profile?['role'] ?? 'user';
        nama = profile?['nama'] ?? 'User';
        npm = profile?['npm'] ?? '-';
        jurusan = profile?['jurusan'];
        semester = profile?['semester'];
      });
    }

    if (role == 'user' || role == 'mahasiswa') {
      await _checkActiveSesi();
    } else {
      setState(() => loading = false);
    }
  }

  Future<void> _checkActiveSesi() async {
    if (jurusan == null || semester == null) {
      setState(() => loading = false);
      return;
    }

    setState(() => _fetchingSesi = true);
    try {
      final sesi = await Supabase.instance.client
          .from('sesi_absensi')
          .select('*, mata_kuliah!inner(*)')
          .eq('is_open', true)
          .eq('mata_kuliah.jurusan', jurusan as Object)
          .eq('mata_kuliah.semester', semester as Object)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _activeSesi = sesi;
        });
      }
    } catch (e) {
      debugPrint('Check Sesi Error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _fetchingSesi = false;
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == 'admin';
    final isDosen = role == 'dosen';
    final isMahasiswa = role == 'mahasiswa' || role == 'user';

    if (isAdmin) {
      return const AdminScreen();
    }

    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchProfileAndSesi,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              if (isMahasiswa) ...[
                _buildAttendanceStatsCard(),
                const SizedBox(height: 24),
                _buildSectionTitle("Aksi Presensi"),
                const SizedBox(height: 12),
                _buildStudentActions(),
                const SizedBox(height: 24),
                _buildSectionTitle("Kelas Kuliah Aktif"),
                const SizedBox(height: 12),
                _buildActiveSesiCard(),
              ],
              if (isDosen) ...[
                _buildDosenQuickActions(),
                const SizedBox(height: 24),
                _buildSectionTitle("Sesi Perkuliahan"),
                const SizedBox(height: 12),
                _buildDosenSesiCard(),
              ],
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
        color: Color(0xFF1A1D20),
      ),
    );
  }

  // ================= DYNAMIC HEADER =================
  Widget _buildHeader() {
    final primaryColor = const Color(0xFF005F73);
    final String welcomeMessage = role == 'dosen' ? 'Halo Bapak/Ibu Dosen' : 'Selamat Datang,';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              welcomeMessage,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              nama,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.6,
                color: Color(0xFF1A1D20),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                role.toUpperCase(),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ),
          ],
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.black87),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Belum ada notifikasi baru.')),
              );
            },
          ),
        ),
      ],
    );
  }

  // ================= STATISTICS CARD (MAHASISWA) =================
  Widget _buildAttendanceStatsCard() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const SizedBox();

    final primaryColor = const Color(0xFF005F73);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseService.streamMyData(user.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            height: 150,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data!;
        final hadir = data.where((e) => e['jenis'] == 'Hadir').length;
        final izin = data.where((e) => e['jenis'] == 'Izin').length;
        final sakit = data.where((e) => e['jenis'] == 'Sakit').length;

        final total = hadir + izin + sakit;
        final persen = total == 0 ? 0.0 : (hadir / total) * 100;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.grey.shade100),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                // Circular percentage progress
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: total == 0 ? 0.0 : hadir / total,
                        strokeWidth: 8,
                        backgroundColor: Colors.grey.shade100,
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      ),
                    ),
                    Text(
                      '${persen.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                // Detailed text stats
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Kehadiran Bulan Ini",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Total Presensi Kuliah: $total Sesi",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildMiniStat('Hadir', hadir, const Color(0xFF0A9396)),
                          _buildMiniStat('Izin', izin, const Color(0xFF007AFF)),
                          _buildMiniStat('Sakit', sakit, const Color(0xFFEE9B00)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMiniStat(String label, int value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: Text(
            "$value",
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  // ================= MAHASISWA ACTIONS =================
  Widget _buildStudentActions() {
    final primaryColor = const Color(0xFF005F73);

    return Row(
      children: [
        Expanded(
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.grey.shade100),
            ),
            color: Colors.white,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AbsenScreen()),
                ).then((_) => _fetchProfileAndSesi());
              },
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.camera_front_rounded, color: primaryColor, size: 24),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Absen Selfie",
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Selfie & Lokasi GPS",
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.grey.shade100),
            ),
            color: Colors.white,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const IzinScreen()),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEE9B00).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.edit_calendar_rounded, color: Color(0xFFEE9B00), size: 24),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Izin / Sakit",
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Ajukan Cuti/Sakit",
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ================= DYNAMIC SCHEDULE / SESI AKTIF (MAHASISWA) =================
  Widget _buildActiveSesiCard() {
    if (_fetchingSesi) {
      return Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.grey.shade100),
        ),
        child: const Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_activeSesi == null) {
      return Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.grey.shade100),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.event_busy_rounded, color: Colors.grey.shade400, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Tidak Ada Sesi Aktif",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Saat ini tidak ada sesi absen yang dibuka untuk semester Anda.",
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final mk = _activeSesi!['mata_kuliah'];
    final namaMK = mk['nama_mk'] ?? 'Mata Kuliah';
    final pertemuanKe = _activeSesi!['pertemuan_ke']?.toString() ?? '-';
    final materi = _activeSesi!['materi'] ?? '-';
    final primaryColor = const Color(0xFF005F73);

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: primaryColor.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.08),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(22), topRight: Radius.circular(22)),
            ),
            child: Row(
              children: [
                const Icon(Icons.radio_button_checked_rounded, color: Color(0xFF0A9396), size: 16),
                const SizedBox(width: 8),
                const Text(
                  "SESI ABSENSI DIBUKA",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0A9396)),
                ),
                const Spacer(),
                Text(
                  "Pertemuan $pertemuanKe",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryColor),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  namaMK,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  "Materi: $materi",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AbsenScreen()),
                      ).then((_) => _fetchProfileAndSesi());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text("Absen Sekarang", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= DOSEN ACTIONS =================
  Widget _buildDosenQuickActions() {
    final primaryColor = const Color(0xFF005F73);

    return Row(
      children: [
        Expanded(
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.grey.shade100),
            ),
            color: Colors.white,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const KelolaSesiScreen()),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.add_task_rounded, color: primaryColor, size: 24),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Kelola Sesi",
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Buka/Tutup Sesi",
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.grey.shade100),
            ),
            color: Colors.white,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RiwayatScreen()),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEE9B00).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.history_rounded, color: Color(0xFFEE9B00), size: 24),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Riwayat Kelas",
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Daftar Hadir Mahasiswa",
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ================= DOSEN ACTIVE SESI CARD =================
  Widget _buildDosenSesiCard() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const SizedBox();

    return FutureBuilder<List<dynamic>>(
      future: Supabase.instance.client
          .from('sesi_absensi')
          .select('*, mata_kuliah!inner(*)')
          .eq('is_open', true)
          .eq('mata_kuliah.dosen_id', user.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            elevation: 0,
            color: Colors.white,
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.grey.shade100),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.event_available_rounded, color: Colors.grey.shade400, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Belum Ada Sesi Dibuka",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Silakan buka sesi absensi baru agar mahasiswa dapat mulai absen.",
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final sesi = list.first;
        final mkName = sesi['mata_kuliah']['nama_mk'] ?? 'Mata Kuliah';
        final pertemuan = sesi['pertemuan_ke']?.toString() ?? '-';
        final materi = sesi['materi'] ?? '-';
        final radius = sesi['radius_meter']?.toString() ?? '50';

        return Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: Colors.green.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.08),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(22), topRight: Radius.circular(22)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Color(0xFF0A9396), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      "SESI ABSENSI AKTIF",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0A9396)),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mkName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Materi: $materi",
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Pertemuan Ke: $pertemuan  |  Radius: ${radius}m",
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const KelolaSesiScreen()),
                          ).then((_) => _fetchProfileAndSesi());
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF3B30),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text("Tutup Sesi Absensi", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
