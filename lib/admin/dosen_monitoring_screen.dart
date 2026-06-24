import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../screens/notifikasi_screen.dart';
import '../services/supabase_service.dart';
import 'dosen_buka_sesi_screen.dart';

class DosenMonitoringScreen extends StatefulWidget {
  const DosenMonitoringScreen({super.key});

  @override
  State<DosenMonitoringScreen> createState() => _DosenMonitoringScreenState();
}

class _DosenMonitoringScreenState extends State<DosenMonitoringScreen>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  bool _loading = true;

  Map<String, dynamic>? _activeSesi;
  List<Map<String, dynamic>> _checkIns = [];
  List<Map<String, dynamic>> _enrolledStudents = [];
  bool _isClosing = false;

  late TabController _tabController;
  Timer? _countdownTimer;
  Duration _timeLeft = const Duration(minutes: 45, seconds: 10);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadActiveSessionData();
    _startTimer();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_timeLeft.inSeconds > 0) {
        setState(() {
          _timeLeft = _timeLeft - const Duration(seconds: 1);
        });
      }
    });
  }

  Future<void> _loadActiveSessionData() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      // 1. Fetch active session of this lecturer
      final sesiList = await supabase
          .from('sesi_absensi')
          .select('*, mata_kuliah!inner(*)')
          .eq('is_open', true)
          .eq('mata_kuliah.dosen_id', user.id)
          .maybeSingle();

      if (sesiList != null) {
        _activeSesi = sesiList;
        final sesiId = _activeSesi!['id'];

        // Calculate sisa waktu based on jam_selesai or fallback duration
        final jamSelesaiStr = _activeSesi!['jam_selesai'] ?? '10:30';
        try {
          final now = DateTime.now();
          final parts = jamSelesaiStr.split(':');
          if (parts.length >= 2) {
            final targetTime = DateTime(
              now.year,
              now.month,
              now.day,
              int.parse(parts[0]),
              int.parse(parts[1]),
            );
            final diff = targetTime.difference(now);
            if (diff.inSeconds > 0) {
              _timeLeft = diff;
            } else {
              _timeLeft = const Duration(minutes: 0, seconds: 0);
            }
          }
        } catch (_) {
          _timeLeft = const Duration(minutes: 45, seconds: 10);
        }

        // 2. Fetch check-ins for this session
        final checkInsData = await supabase
            .from('data_absensi')
            .select('*')
            .eq('sesi_id', sesiId)
            .neq('jenis', 'Pelanggaran');

        _checkIns = List<Map<String, dynamic>>.from(checkInsData);

        // 3. Fetch enrolled students based on Major & Semester
        final studentsData = await supabase
            .from('profiles')
            .select('*')
            .eq('role', 'user')
            .eq('jurusan', _activeSesi!['mata_kuliah']['jurusan'])
            .eq('semester', _activeSesi!['mata_kuliah']['semester']);

        _enrolledStudents = List<Map<String, dynamic>>.from(studentsData);
      } else {
        _activeSesi = null;
        _checkIns = [];
        _enrolledStudents = [];
      }
    } catch (e) {
      debugPrint('Error loading active session monitoring: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _tutupSesi(int id) async {
    setState(() => _isClosing = true);
    try {
      await supabase.from('sesi_absensi').update({'is_open': false}).eq('id', id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sesi absensi berhasil ditutup')),
        );
        _loadActiveSessionData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menutup sesi: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isClosing = false);
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return "${twoDigits(minutes)}:${twoDigits(seconds)}";
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8F9FA),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_activeSesi == null) {
      return _buildEmptyState();
    }

    final mk = _activeSesi!['mata_kuliah'];
    final namaMK = mk['nama_mk'] ?? 'Mata Kuliah';
    final ruangan = _activeSesi!['ruangan'] ?? 'Ruang Kelas';
    final jamMulai = _activeSesi!['jam_mulai'] ?? '08:00';
    final jamSelesai = _activeSesi!['jam_selesai'] ?? '10:30';

    // Separate students into Hadir and Belum Hadir
    final checkedInNPMs = _checkIns.map((e) => e['npm'].toString()).toSet();
    final List<Map<String, dynamic>> hadirStudents = [];
    final List<Map<String, dynamic>> belumHadirStudents = [];

    for (var student in _enrolledStudents) {
      final npm = student['npm'].toString();
      if (checkedInNPMs.contains(npm)) {
        // find checked in time
        final checkInItem = _checkIns.firstWhere((element) => element['npm'].toString() == npm, orElse: () => {});
        hadirStudents.add({
          ...student,
          'waktu': checkInItem['waktu'],
          'status': checkInItem['status'] ?? 'Hadir',
          'alasan': checkInItem['alasan'] ?? '-',
          'foto_path': checkInItem['foto_path'],
        });
      } else {
        belumHadirStudents.add(student);
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Monitoring Sesi',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -0.6,
            color: Color(0xFF1A1D20),
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF1A1D20),
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Color(0xFF1A1D20), size: 24),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotifikasiScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // ─── Header Sesi Aktif ───
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Container(
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
                          namaMK,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1D20),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8E8FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF4343D9),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'LIVE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4343D9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ruang $ruangan • $jamMulai - $jamSelesai',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Statistik row
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade100),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'HADIR',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${hadirStudents.length}/${_enrolledStudents.length}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4343D9),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade100),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'BELUM HADIR',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${belumHadirStudents.length}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade100),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'WAKTU TERSISA',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatDuration(_timeLeft),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1D20),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Tab Bar Kehadiran
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1)),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF4343D9),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: const Color(0xFF4343D9),
              unselectedLabelColor: Colors.grey.shade500,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              tabs: [
                Tab(text: 'Hadir (${hadirStudents.length})'),
                Tab(text: 'Belum Hadir (${belumHadirStudents.length})'),
              ],
            ),
          ),

          // Tab Contents
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildStudentList(hadirStudents, true),
                _buildStudentList(belumHadirStudents, false),
              ],
            ),
          ),

          // Bottom Action Tutup Sesi
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isClosing
                        ? null
                        : () => _tutupSesi(_activeSesi!['id']),
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                    label: const Text(
                      'Tutup Sesi',
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
                const SizedBox(height: 8),
                Text(
                  'Data akan disinkronisasi ke server setelah sesi ditutup.',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentList(List<Map<String, dynamic>> students, bool isHadir) {
    if (students.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            isHadir ? 'Belum ada mahasiswa yang hadir' : 'Semua mahasiswa telah hadir',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: students.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final student = students[index];
        final name = student['nama'] ?? 'Mahasiswa';
        final npm = student['npm'] ?? '-';
        final initials = name.isNotEmpty ? name.substring(0, (name.length > 2 ? 2 : name.length)).toUpperCase() : 'M';

        String jamStr = '';
        if (isHadir && student['waktu'] != null) {
          try {
            final dt = DateTime.parse(student['waktu']).toLocal();
            jamStr = DateFormat('HH:mm').format(dt);
          } catch (_) {}
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isHadir ? const Color(0xFFE8E8FF) : Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isHadir ? const Color(0xFF4343D9) : Colors.grey.shade500,
                    ),
                  ),
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
                      'NIM: $npm',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isHadir)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      jamStr,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4343D9),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      student['status']?.toString() ?? 'Hadir',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: (student['status'] == 'Izin')
                            ? const Color(0xFFF57C00)
                            : (student['status'] == 'Sakit')
                                ? const Color(0xFFD32F2F)
                                : const Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                )
              else
                Text(
                  'Belum Hadir',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade400,
                  ),
                ),
            ],
          ),
          if (isHadir && (student['status'] == 'Izin' || student['status'] == 'Sakit')) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Alasan: ${student['alasan']}', 
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                  ),
                  if (student['foto_path'] != null && student['foto_path'].toString().isNotEmpty && student['foto_path'] != '-') ...[
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => _showBuktiDialog(context, student),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.attachment_rounded, size: 14, color: Color(0xFF4343D9)),
                          SizedBox(width: 4),
                          Text('Lihat Bukti', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4343D9))),
                        ],
                      ),
                    )
                  ]
                ],
              ),
            ),
          ]
        ],
      ),
    );
      },
    );
  }

  void _showBuktiDialog(BuildContext context, Map<String, dynamic> student) {
    final fotoPath = student['foto_path'];
    final fotoUrl = SupabaseService.getFotoUrl(fotoPath ?? '');

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Bukti Pengajuan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: fotoUrl.isNotEmpty
                    ? Image.network(fotoUrl, fit: BoxFit.cover)
                    : Container(
                        width: double.infinity,
                        height: 200,
                        color: Colors.grey.shade100,
                        child: const Center(child: Icon(Icons.broken_image, size: 40, color: Colors.grey)),
                      ),
              ),
              const SizedBox(height: 16),
              Text('Status: ${student['status']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Alasan: ${student['alasan']}'),
              const SizedBox(height: 4),
              if (student['waktu'] != null)
                Text('Waktu: ${DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(student['waktu']).toLocal())}', 
                     style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Monitoring Sesi',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -0.6,
            color: Color(0xFF1A1D20),
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF1A1D20),
        elevation: 0,
        centerTitle: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8E8FF),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Icon(
                  Icons.calendar_today_rounded,
                  size: 40,
                  color: Color(0xFF4343D9),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Belum ada sesi aktif',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1D20),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Silakan buka sesi absensi baru agar mahasiswa dapat mulai melakukan presensi kelas.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DosenBukaSesiScreen()),
                    ).then((_) => _loadActiveSessionData());
                  },
                  icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                  label: const Text(
                    'Buka Sesi Baru',
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
            ],
          ),
        ),
      ),
    );
  }
}
