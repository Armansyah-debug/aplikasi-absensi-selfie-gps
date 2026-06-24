import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/notifikasi_screen.dart';
import 'package:intl/intl.dart';

import '../absensi/riwayat_screen.dart';
import '../absensi/absenScreen.dart';
import '../absensi/izin_screen.dart';
import '../../services/supabase_service.dart';
import '../admin/admin_screen.dart';
import '../screens/login_screen.dart';
import '../admin/dosen_buka_sesi_screen.dart';


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

  // Dosen Redesign Stats Variables
  List<Map<String, dynamic>> _dosenHistory = [];
  bool _loadingDosenStats = false;
  double _avgAttendance = 0.0;
  int _totalEnrolledStudents = 0;
  List<int> _weeklyActivity = List.filled(5, 0);
  List<Map<String, dynamic>> _dosenMKList = [];

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
    } else if (role == 'dosen') {
      await _fetchDosenStats();
      if (mounted) setState(() => loading = false);
    } else {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _fetchDosenStats() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    if (mounted) setState(() => _loadingDosenStats = true);
    try {
      final history = await SupabaseService.getDosenHistoryRaw(user.id);
      final listMK = await SupabaseService.getMataKuliah(dosenId: user.id);
      
      // Calculate Total Mahasiswa (unique NPM count)
      final uniqueNPMs = history.map((e) => e['npm'].toString()).toSet();
      final totalMahasiswa = uniqueNPMs.length;

      // Calculate Average Attendance
      final totalCheckIns = history.length;
      final hadirCount = history.where((e) => e['jenis'] == 'Hadir').length;
      final avgAttendance = totalCheckIns == 0 ? 0.0 : (hadirCount / totalCheckIns) * 100;

      // Calculate Weekly Activity (Senin - Jumat)
      final weeklyActivity = List.filled(5, 0);
      final now = DateTime.now();
      for (var item in history) {
        if (item['waktu'] != null) {
          try {
            final dt = DateTime.parse(item['waktu']).toLocal();
            // Check if it's within the last 7 days
            if (now.difference(dt).inDays < 7) {
              final wd = dt.weekday; // 1 = Monday, 5 = Friday
              if (wd >= 1 && wd <= 5) {
                weeklyActivity[wd - 1]++;
              }
            }
          } catch (_) {}
        }
      }

      if (mounted) {
        setState(() {
          _dosenHistory = history;
          _avgAttendance = avgAttendance;
          _totalEnrolledStudents = totalMahasiswa;
          _weeklyActivity = weeklyActivity;
          _dosenMKList = listMK;
          _loadingDosenStats = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching dosen stats: $e');
      if (mounted) setState(() => _loadingDosenStats = false);
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
    final user = Supabase.instance.client.auth.currentUser;
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
                _buildActiveSesiCard(),
                if (user != null) ...[
                  const SizedBox(height: 24),
                  _buildRecentHistorySection(user.id),
                ],
                const SizedBox(height: 24),
                _buildIllustrationCard(),
              ],
              if (isDosen) ...[
                _buildDosenQuickActions(),
                const SizedBox(height: 24),
                _buildSectionTitle("Sesi Berjalan"),
                const SizedBox(height: 12),
                _buildDosenSesiCard(),
                const SizedBox(height: 24),
                    _buildSectionTitle("Jadwal Hari Ini"),
                const SizedBox(height: 12),
                _buildDosenScheduleList(),
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
    if (role == 'mahasiswa' || role == 'user') {
      final hour = DateTime.now().hour;
      String greeting = 'Selamat pagi,';
      if (hour >= 11 && hour < 15) {
        greeting = 'Selamat siang,';
      } else if (hour >= 15 && hour < 18) {
        greeting = 'Selamat sore,';
      } else if (hour >= 18 || hour < 5) {
        greeting = 'Selamat malam,';
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'UniCheck',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: Color(0xFF1A1D20),
                ),
              ),
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, color: Color(0xFF1A1D20), size: 24),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const NotifikasiScreen()),
                      );
                    },
                  ),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            greeting,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            nama,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.6,
              color: Color(0xFF1A1D20),
            ),
          ),
        ],
      );
    }

    if (role == 'dosen') {
      final hour = DateTime.now().hour;
      String greeting = 'Selamat Pagi,';
      if (hour >= 11 && hour < 15) {
        greeting = 'Selamat Siang,';
      } else if (hour >= 15 && hour < 18) {
        greeting = 'Selamat Sore,';
      } else if (hour >= 18 || hour < 5) {
        greeting = 'Selamat Malam,';
      }

      final initials = nama.isNotEmpty ? nama.substring(0, (nama.length > 2 ? 2 : nama.length)).toUpperCase() : 'DR';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8E8FF),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4343D9),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Attendance Pro',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1D20),
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Color(0xFF1A1D20), size: 24),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const NotifikasiScreen()),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'DASHBOARD DOSEN',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4343D9),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$greeting $nama',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.6,
              color: Color(0xFF1A1D20),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Anda memiliki ${_dosenMKList.length} mata kuliah semester ini.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    final String welcomeMessage = 'Selamat Datang,';
    final primaryColor = const Color(0xFF005F73);

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
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotifikasiScreen()),
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

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseService.streamMyData(user.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
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
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "RASIO KEHADIRAN",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Icon(
                      Icons.insert_chart_outlined_rounded,
                      color: Color(0xFF4343D9),
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${persen.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1D20),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '+2% bln ini',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4343D9),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1A1D20)),
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
    
    // Fallback values for layout consistency
    final jamMulai = _activeSesi!['jam_mulai'] ?? '08:00';
    final jamSelesai = _activeSesi!['jam_selesai'] ?? '10:00';
    final ruangan = _activeSesi!['ruangan'] ?? 'Lab Komputer 02 (Lantai 3)';

    return Column(
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF090909),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Stack(
            children: [
              Positioned(
                right: 20,
                bottom: 20,
                child: Icon(
                  Icons.school_rounded,
                  size: 80,
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4343D9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        "SESI AKTIF",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      namaMK,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.access_time_outlined, color: Colors.white.withOpacity(0.5), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "$jamMulai - $jamSelesai",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, color: Colors.white.withOpacity(0.5), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ruangan,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AbsenScreen()),
              ).then((_) => _fetchProfileAndSesi());
            },
            icon: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 20),
            label: const Text(
              "Absen Sekarang",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4343D9),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Verifikasi wajah & lokasi diperlukan",
          style: TextStyle(
            fontSize: 12,
            fontStyle: FontStyle.italic,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  // ================= RECENT HISTORY SECTION =================
  Widget _buildRecentHistorySection(String userId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle("Riwayat Terbaru"),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RiwayatScreen()),
                );
              },
              child: const Text(
                "Lihat Semua",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4343D9),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<dynamic>>(
          future: Future.wait([
            SupabaseService.getHistoryRaw(userId),
            SupabaseService.getSesiList(),
            SupabaseService.getAllMK(),
          ]),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return const SizedBox();
            }

            final List<Map<String, dynamic>> rawAbsensi =
                List<Map<String, dynamic>>.from(snapshot.data![0]);
            final List<Map<String, dynamic>> listSesi =
                List<Map<String, dynamic>>.from(snapshot.data![1]);
            final List<Map<String, dynamic>> listMK =
                List<Map<String, dynamic>>.from(snapshot.data![2]);

            final filteredAbsensi = rawAbsensi.where((item) {
              final sesiId = item['sesi_id'];
              if (sesiId == null) return false;
              final sesi = listSesi.firstWhere((s) => s['id'] == sesiId, orElse: () => {});
              return sesi.isNotEmpty && sesi['mata_kuliah_id'] != null;
            }).toList();

            if (filteredAbsensi.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Center(
                  child: Text(
                    "Belum ada riwayat presensi",
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  ),
                ),
              );
            }

            final recentItems = filteredAbsensi.take(3).toList();

            return Column(
              children: recentItems.map((item) {
                final sesiId = item['sesi_id'];
                final sesi = listSesi.firstWhere((s) => s['id'] == sesiId, orElse: () => {});
                final mkId = sesi['mata_kuliah_id'];
                final mk = listMK.firstWhere((m) => m['id'] == mkId, orElse: () => {});
                final namaMK = mk['nama_mk'] ?? 'Mata Kuliah';
                final jenis = item['jenis'] ?? 'Hadir';

                String jamStr = '-';
                if (item['waktu'] != null) {
                  try {
                    final dt = DateTime.parse(item['waktu']).toLocal();
                    final weekday = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'][dt.weekday - 1];
                    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'];
                    final monthStr = months[dt.month - 1];
                    final hourStr = dt.hour.toString().padLeft(2, '0');
                    final minStr = dt.minute.toString().padLeft(2, '0');
                    jamStr = "$weekday, ${dt.day} $monthStr • $hourStr:$minStr";
                  } catch (_) {}
                }

                Color badgeBg = const Color(0xFFE8F5E9);
                Color badgeText = const Color(0xFF2E7D32);
                String badgeLabel = 'Hadir';

                if (jenis == 'Izin') {
                  badgeBg = const Color(0xFFFFF8E1);
                  badgeText = const Color(0xFFF57F17);
                  badgeLabel = 'Izin';
                } else if (jenis == 'Sakit') {
                  badgeBg = const Color(0xFFFFEBEE);
                  badgeText = const Color(0xFFC62828);
                  badgeLabel = 'Sakit';
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.menu_book_rounded,
                          color: Colors.grey.shade600,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              namaMK,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1D20),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              jamStr,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badgeLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: badgeText,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  // ================= ILLUSTRATION PLACEHOLDER CARD =================
  Widget _buildIllustrationCard() {
    return Container(
      width: double.infinity,
      height: 160,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.shade300,
          style: BorderStyle.solid,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.05,
                child: GridPaper(
                  color: Colors.blue.shade900,
                  divisions: 1,
                  subdivisions: 1,
                  interval: 40,
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.dashboard_customize_outlined,
                    size: 40,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Selamat Belajar & Beraktivitas!",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade500,
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

  // ================= DOSEN ACTIONS & STATISTICS =================
  Widget _buildDosenQuickActions() {
    final List<String> weekdays = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum'];
    int maxActivity = _weeklyActivity.reduce((curr, next) => curr > next ? curr : next);
    if (maxActivity == 0) maxActivity = 1; // Prevent division by zero

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Buka Sesi Baru Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DosenBukaSesiScreen()),
              ).then((_) => _fetchProfileAndSesi());
            },
            icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 20),
            label: const Text(
              "Buka Sesi Baru",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0051D5),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Rata-Rata Kehadiran Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "RATA-RATA KEHADIRAN",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade500,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(
                    Icons.trending_up_rounded,
                    color: Color(0xFF4343D9),
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '${_avgAttendance.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1D20),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Total Mahasiswa Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "TOTAL MAHASISWA",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade500,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(
                    Icons.people_alt_outlined,
                    color: Color(0xFF4343D9),
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '$_totalEnrolledStudents',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1D20),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Terdaftar di ${_dosenMKList.length} mata kuliah',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Aktivitas Minggu Ini Card (Bar Chart)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "AKTIVITAS MINGGU INI",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade500,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 120,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(5, (index) {
                    final dayVal = _weeklyActivity[index];
                    final pct = dayVal / maxActivity;
                    final height = (pct * 80).clamp(6.0, 80.0);

                    // Highlight Kamis or current day dynamically, or highlight index 3 (Kamis) as reference
                    final isHighlighted = index == 3;

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          width: 32,
                          height: height,
                          decoration: BoxDecoration(
                            color: isHighlighted ? const Color(0xFF0051D5) : const Color(0xFFE8E8FF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          weekdays[index],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isHighlighted ? const Color(0xFF0051D5) : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ],
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
          return Container(
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
            ),
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
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1A1D20)),
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
          );
        }

        final sesi = list.first;
        final sesiId = sesi['id'];
        final mkName = sesi['mata_kuliah']['nama_mk'] ?? 'Mata Kuliah';
        final ruangan = sesi['ruangan'] ?? 'Ruang Kelas';

        // Load dynamic attendees count for this session
        return FutureBuilder<List<dynamic>>(
          future: Future.wait([
            Supabase.instance.client
                .from('data_absensi')
                .select('npm, nama')
                .eq('sesi_id', sesiId)
                .neq('jenis', 'Pelanggaran'),
            Supabase.instance.client
                .from('profiles')
                .select('id')
                .eq('role', 'user')
                .eq('jurusan', sesi['mata_kuliah']['jurusan'])
                .eq('semester', sesi['mata_kuliah']['semester']),
          ]),
          builder: (context, statsSnap) {
            int checkedInCount = 0;
            int enrolledCount = 0;
            List<String> studentInitials = [];

            if (statsSnap.hasData) {
              final checkIns = List<Map<String, dynamic>>.from(statsSnap.data![0]);
              final enrolled = List<Map<String, dynamic>>.from(statsSnap.data![1]);
              checkedInCount = checkIns.length;
              enrolledCount = enrolled.length;

              studentInitials = checkIns.take(3).map<String>((c) {
                final name = c['nama'] ?? '';
                return name.isNotEmpty ? name.substring(0, (name.length > 2 ? 2 : name.length)).toUpperCase() : 'M';
              }).toList();
            }

            return Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF0051D5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: 20,
                    bottom: 20,
                    child: Icon(
                      Icons.school_rounded,
                      size: 80,
                      color: Colors.white.withOpacity(0.06),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "SESI BERJALAN",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white.withOpacity(0.9),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          mkName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Ruang $ruangan • Berjalan",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Student check in avatars & counter
                        Row(
                          children: [
                            if (studentInitials.isNotEmpty)
                              Row(
                                children: studentInitials.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final text = entry.value;
                                  return Container(
                                    margin: EdgeInsets.only(left: index == 0 ? 0.0 : -10.0),
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFF0051D5), width: 1.5),
                                    ),
                                    child: Center(
                                      child: Text(
                                        text,
                                        style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0051D5),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            if (studentInitials.isNotEmpty) const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "$checkedInCount/$enrolledCount Mahasiswa Hadir",
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Actions row
                        SizedBox(
                          width: double.infinity,
                          height: 40,
                          child: ElevatedButton(
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  title: const Text('Tutup Sesi Absensi?', style: TextStyle(fontWeight: FontWeight.bold)),
                                  content: const Text('Yakin ingin mengakhiri sesi kuliah aktif ini?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Tutup Sesi'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await Supabase.instance.client
                                    .from('sesi_absensi')
                                    .update({'is_open': false})
                                    .eq('id', sesiId);
                                _fetchProfileAndSesi();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFC62828),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text(
                              "Tutup Sesi",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
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
      },
    );
  }

  // ================= DOSEN SCHEDULES =================
  Widget _buildDosenScheduleList() {
    if (_dosenMKList.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Center(
          child: Text(
            "Belum ada jadwal mengajar",
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          ),
        ),
      );
    }

    final List<String> times = ['08:00\nWIB', '13:30\nWIB', '15:30\nWIB'];
    final List<String> fallbacks = ['Lab Komputer 1', 'Ruang 205', 'Daring via Zoom'];

    return Column(
      children: List.generate(_dosenMKList.length, (index) {
        final mk = _dosenMKList[index];
        final name = mk['nama_mk'] ?? 'Mata Kuliah';
        final room = fallbacks[index % fallbacks.length];
        final timeStr = times[index % times.length];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  timeStr,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1D20),
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1D20),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$room • Mendatang',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
