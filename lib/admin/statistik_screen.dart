import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'theme/admin_theme.dart';
import 'widgets/admin_widgets.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// StatistikScreen — Laporan Rekapitulasi Absensi per Mahasiswa
class StatistikScreen extends StatefulWidget {
  const StatistikScreen({super.key});

  @override
  State<StatistikScreen> createState() => _StatistikScreenState();
}

class _StatistikScreenState extends State<StatistikScreen> {
  bool _loading = true;

  // Raw data
  List<Map<String, dynamic>> _allAbsensi = [];
  List<Map<String, dynamic>> _allProfiles = [];
  List<Map<String, dynamic>> _allSesi = [];
  List<Map<String, dynamic>> _allMK = [];
  List<Map<String, dynamic>> _dosenList = [];

  // Filter state
  DateTime? _filterTanggalMulai;
  DateTime? _filterTanggalSelesai;
  String? _filterJurusan;
  String? _filterDosenId;

  // Pagination
  static const _perPage = 10;
  int _currentPage = 1;

  // Jurusan options
  final List<String> _jurusanOptions = [
    'Informatika',
    'Sistem Informasi',
    'Manajemen',
    'Akuntansi',
  ];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    final supabase = Supabase.instance.client;

    try {
      final results = await Future.wait([
        SupabaseService.getAllHistoryRaw(),
        supabase.from('profiles').select('id, nama, npm, jurusan, semester, role'),
        SupabaseService.getSesiList(),
        SupabaseService.getAllMK(),
        SupabaseService.getDosenList(),
      ]);

      if (mounted) {
        setState(() {
          _allAbsensi = List<Map<String, dynamic>>.from(results[0] as List);
          _allProfiles = (results[1] as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          _allSesi = List<Map<String, dynamic>>.from(results[2] as List);
          _allMK = List<Map<String, dynamic>>.from(results[3] as List);
          _dosenList = List<Map<String, dynamic>>.from(results[4] as List);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Laporan error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── Rekap per Mahasiswa ───
  List<Map<String, dynamic>> get _rekap {
    // Filter absensi by date range
    List<Map<String, dynamic>> filtered = _allAbsensi.where((a) {
      if (_filterTanggalMulai != null && a['waktu'] != null) {
        final dt = DateTime.tryParse(a['waktu']);
        if (dt != null && dt.toLocal().isBefore(_filterTanggalMulai!)) return false;
      }
      if (_filterTanggalSelesai != null && a['waktu'] != null) {
        final dt = DateTime.tryParse(a['waktu']);
        if (dt != null && dt.toLocal().isAfter(_filterTanggalSelesai!.add(const Duration(days: 1)))) return false;
      }
      return true;
    }).toList();

    // Group by user_id
    final Map<String, List<Map<String, dynamic>>> byUser = {};
    for (final a in filtered) {
      final uid = a['user_id']?.toString() ?? '';
      byUser.putIfAbsent(uid, () => []).add(a);
    }

    // Build rekap list
    final List<Map<String, dynamic>> result = [];
    for (final entry in byUser.entries) {
      final uid = entry.key;
      final records = entry.value.where((r) => r['jenis'] != 'Pelanggaran').toList();

      // Find profile
      final profile = _allProfiles.firstWhere(
        (p) => p['id']?.toString() == uid,
        orElse: () => {},
      );

      if (profile.isEmpty) continue;

      final jurusan = profile['jurusan']?.toString() ?? '-';
      final semester = profile['semester'];

      // Filter by jurusan
      if (_filterJurusan != null &&
          _filterJurusan != 'Semua' &&
          jurusan != _filterJurusan) continue;

      // Filter by dosen (check if mahasiswa has absensi in MK milik dosen)
      if (_filterDosenId != null) {
        final mkMilikDosen = _allMK
            .where((m) => m['dosen_id']?.toString() == _filterDosenId)
            .map((m) => m['id'])
            .toSet();
        final sesiMilikDosen = _allSesi
            .where((s) => mkMilikDosen.contains(s['mata_kuliah_id']))
            .map((s) => s['id'])
            .toSet();
        final hasAbsensiDosen = records
            .any((r) => sesiMilikDosen.contains(r['sesi_id']));
        if (!hasAbsensiDosen) continue;
      }

      final hadir = records.where((r) => r['jenis'] == 'Hadir').length;
      final sakit = records.where((r) => r['jenis'] == 'Sakit').length;
      final izin = records.where((r) => r['jenis'] == 'Izin').length;
      final alpa = records
          .where((r) => r['jenis'] != 'Hadir' && r['jenis'] != 'Sakit' && r['jenis'] != 'Izin')
          .length;
      final total = records.length;
      final pct = total == 0 ? 0.0 : (hadir / total) * 100;

      result.add({
        'nama': profile['nama'] ?? '-',
        'npm': profile['npm'] ?? '-',
        'jurusan': jurusan,
        'semester': semester,
        'hadir': hadir,
        'sakit': sakit,
        'izin': izin,
        'alpa': alpa,
        'total': total,
        'pct': pct,
      });
    }

    result.sort((a, b) =>
        (b['pct'] as double).compareTo(a['pct'] as double));
    return result;
  }

  List<Map<String, dynamic>> get _paginated {
    final list = _rekap;
    final start = (_currentPage - 1) * _perPage;
    final end = (start + _perPage).clamp(0, list.length);
    if (start >= list.length) return [];
    return list.sublist(start, end);
  }

  int get _totalPages => (_rekap.length / _perPage).ceil().clamp(1, 9999);

  // ─── Summary stats ───
  double get _avgAttendance {
    final all = _rekap;
    if (all.isEmpty) return 0;
    return all.map((e) => e['pct'] as double).reduce((a, b) => a + b) / all.length;
  }

  double get _avgAbsen {
    final all = _rekap;
    if (all.isEmpty) return 0;
    final totalAlpa = all.map((e) => (e['alpa'] as int) + (e['sakit'] as int)).reduce((a, b) => a + b);
    final totalAll = all.map((e) => e['total'] as int).reduce((a, b) => a + b);
    return totalAll == 0 ? 0 : totalAlpa / totalAll * 100;
  }

  String _statusLabel(double pct) {
    if (pct >= 90) return 'Sempurna';
    if (pct >= 75) return 'Aman';
    if (pct >= 60) return 'Peringatan';
    return 'Risiko';
  }

  String _getMKName(dynamic sesiId) {
    if (sesiId == null) return '-';
    final sesi = _allSesi.firstWhere((s) => s['id'] == sesiId, orElse: () => {});
    if (sesi.isEmpty) return '-';
    final mk = _allMK.firstWhere((m) => m['id'] == sesi['mata_kuliah_id'], orElse: () => {});
    return mk['nama_mk'] ?? '-';
  }

  // ─── Date Picker ───
  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_filterTanggalMulai ?? DateTime.now().subtract(const Duration(days: 30)))
          : (_filterTanggalSelesai ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: AdminTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _filterTanggalMulai = picked;
        } else {
          _filterTanggalSelesai = picked;
        }
        _currentPage = 1;
      });
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Pilih tanggal';
    return DateFormat('dd MMM yyyy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          AdminSkeletonBox(height: 60),
          SizedBox(height: 16),
          AdminSkeletonBox(height: 120),
          SizedBox(height: 16),
          AdminSkeletonBox(height: 500),
        ],
      );
    }

    final rekap = _rekap;

    return RefreshIndicator(
      onRefresh: _fetchData,
      color: AdminTheme.primary,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // ─── Header ───
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Laporan Rekapitulasi Absensi', style: AdminTheme.h1),
                    SizedBox(height: 4),
                    Text(
                      'Kelola dan rekap data kehadiran mahasiswa secara berkala.',
                      style: AdminTheme.body,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ─── Summary + Status Card ───
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Total Kehadiran card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AdminTheme.cardDecoration,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AdminTheme.successLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.people_outline_rounded,
                                color: AdminTheme.success, size: 18),
                          ),
                          const Spacer(),
                          Text(
                            '+${rekap.where((e) => (e['pct'] as double) >= 75).length} aman',
                            style: const TextStyle(
                                fontSize: 11,
                                color: AdminTheme.success,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${_avgAttendance.toStringAsFixed(1)}%',
                        style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AdminTheme.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      const Text('Rata-rata Kehadiran',
                          style: AdminTheme.caption),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Absen tanpa ket card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AdminTheme.cardDecoration,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AdminTheme.dangerLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.person_off_outlined,
                                color: AdminTheme.danger, size: 18),
                          ),
                          const Spacer(),
                          Text(
                            '-${rekap.where((e) => (e['pct'] as double) < 75).length} risiko',
                            style: const TextStyle(
                                fontSize: 11,
                                color: AdminTheme.danger,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${_avgAbsen.toStringAsFixed(1)}%',
                        style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AdminTheme.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      const Text('Absen Tanpa Keterangan',
                          style: AdminTheme.caption),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Status Laporan
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AdminTheme.primaryGradientDecoration,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Status Laporan',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Rekap data kehadiran ${rekap.length} mahasiswa tersedia.',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12, height: 1.5),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _statChip('AMAN',
                              '${rekap.where((e) => (e['pct'] as double) >= 75).length}',
                              AdminTheme.success),
                          const SizedBox(width: 10),
                          _statChip('RISIKO',
                              '${rekap.where((e) => (e['pct'] as double) < 75).length}',
                              AdminTheme.danger),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ─── Filter Laporan ───
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AdminTheme.cardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.filter_list_rounded,
                        size: 18, color: AdminTheme.primary),
                    SizedBox(width: 8),
                    Text('Filter Laporan', style: AdminTheme.h3),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    // Tanggal Mulai
                    SizedBox(
                      width: 180,
                      child: InkWell(
                        onTap: () => _pickDate(isStart: true),
                        child: InputDecorator(
                          decoration: AdminTheme.inputDecoration(
                              label: 'Tanggal Mulai',
                              prefixIcon: Icons.date_range_outlined),
                          child: Text(
                            _formatDate(_filterTanggalMulai),
                            style: TextStyle(
                              fontSize: 13,
                              color: _filterTanggalMulai == null
                                  ? AdminTheme.textMuted
                                  : AdminTheme.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Tanggal Akhir
                    SizedBox(
                      width: 180,
                      child: InkWell(
                        onTap: () => _pickDate(isStart: false),
                        child: InputDecorator(
                          decoration: AdminTheme.inputDecoration(
                              label: 'Tanggal Akhir',
                              prefixIcon: Icons.date_range_outlined),
                          child: Text(
                            _formatDate(_filterTanggalSelesai),
                            style: TextStyle(
                              fontSize: 13,
                              color: _filterTanggalSelesai == null
                                  ? AdminTheme.textMuted
                                  : AdminTheme.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Jurusan
                    SizedBox(
                      width: 200,
                      child: DropdownButtonFormField<String>(
                        value: _filterJurusan,
                        hint: const Text('Semua Jurusan'),
                        items: [
                          const DropdownMenuItem(
                              value: 'Semua', child: Text('Semua Jurusan')),
                          ..._jurusanOptions.map(
                              (e) => DropdownMenuItem(value: e, child: Text(e))),
                        ],
                        onChanged: (v) => setState(() {
                          _filterJurusan = v;
                          _currentPage = 1;
                        }),
                        decoration: AdminTheme.inputDecoration(label: 'Jurusan'),
                      ),
                    ),
                    // Dosen
                    SizedBox(
                      width: 200,
                      child: DropdownButtonFormField<String>(
                        value: _filterDosenId,
                        hint: const Text('Semua Dosen'),
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text('Semua Dosen')),
                          ..._dosenList.map((d) => DropdownMenuItem(
                                value: d['id'].toString(),
                                child: Text(d['nama'] ?? '-',
                                    overflow: TextOverflow.ellipsis),
                              )),
                        ],
                        onChanged: (v) => setState(() {
                          _filterDosenId = v;
                          _currentPage = 1;
                        }),
                        decoration:
                            AdminTheme.inputDecoration(label: 'Dosen Pengampu'),
                      ),
                    ),
                    // Terapkan / Reset
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => setState(() => _currentPage = 1),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AdminTheme.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.search_rounded, size: 16),
                          label: const Text('Terapkan Filter'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () => setState(() {
                            _filterTanggalMulai = null;
                            _filterTanggalSelesai = null;
                            _filterJurusan = null;
                            _filterDosenId = null;
                            _currentPage = 1;
                          }),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 14),
                            side: const BorderSide(color: AdminTheme.border),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Reset',
                              style: TextStyle(color: AdminTheme.textSecondary)),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ─── Rekapitulasi Table ───
          Container(
            decoration: AdminTheme.cardDecoration,
            child: Column(
              children: [
                // Table title
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('Data Rekapitulasi Kehadiran',
                            style: AdminTheme.h3),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AdminTheme.bg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AdminTheme.border),
                        ),
                        child: Text(
                          'Menampilkan ${(_currentPage - 1) * _perPage + 1}-${((_currentPage - 1) * _perPage + _paginated.length).clamp(0, rekap.length)} dari ${rekap.length} baris',
                          style: const TextStyle(
                              fontSize: 11, color: AdminTheme.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Table header
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  color: AdminTheme.bg,
                  child: const Row(
                    children: [
                      AdminTableHeader('MAHASISWA', flex: 3),
                      AdminTableHeader('NIM', flex: 2),
                      AdminTableHeader('JURUSAN', flex: 3),
                      AdminTableHeader('HADIR', flex: 1),
                      AdminTableHeader('SAKIT/IZIN', flex: 2),
                      AdminTableHeader('ALPA', flex: 1),
                      AdminTableHeader('PERSENTASE', flex: 3),
                      AdminTableHeader('STATUS', flex: 2),
                    ],
                  ),
                ),

                // Rows
                if (rekap.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: Text('Tidak ada data dengan filter ini',
                          style: AdminTheme.body),
                    ),
                  )
                else
                  ..._paginated.asMap().entries.map((entry) {
                    final i = entry.key;
                    final mhs = entry.value;
                    final pct = mhs['pct'] as double;
                    final status = _statusLabel(pct);

                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      decoration:
                          AdminTheme.tableRowDecoration(isEven: i.isEven),
                      child: Row(
                        children: [
                          // Nama
                          Expanded(
                            flex: 3,
                            child: Row(
                              children: [
                                AdminTheme.avatarInitials(
                                    mhs['nama'] ?? '', radius: 16),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    mhs['nama'] ?? '-',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AdminTheme.tableCellBold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // NIM
                          Expanded(
                            flex: 2,
                            child: Text(mhs['npm'] ?? '-',
                                style: AdminTheme.tableCell),
                          ),
                          // Jurusan
                          Expanded(
                            flex: 3,
                            child: Text(mhs['jurusan'] ?? '-',
                                style: AdminTheme.tableCell),
                          ),
                          // Hadir
                          Expanded(
                            flex: 1,
                            child: Text('${mhs['hadir']}',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AdminTheme.success)),
                          ),
                          // Sakit/Izin
                          Expanded(
                            flex: 2,
                            child: Text(
                                '${(mhs['sakit'] as int) + (mhs['izin'] as int)}',
                                style: AdminTheme.tableCell),
                          ),
                          // Alpa
                          Expanded(
                            flex: 1,
                            child: Text('${mhs['alpa']}',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: (mhs['alpa'] as int) > 0
                                        ? AdminTheme.danger
                                        : AdminTheme.textPrimary)),
                          ),
                          // Persentase
                          Expanded(
                            flex: 3,
                            child: Row(
                              children: [
                                Text(
                                  '${pct.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: pct >= 75
                                        ? AdminTheme.success
                                        : AdminTheme.danger,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                AdminProgressBar(
                                  value: pct / 100,
                                  width: 60,
                                  color: pct >= 90
                                      ? AdminTheme.success
                                      : pct >= 75
                                          ? AdminTheme.warning
                                          : AdminTheme.danger,
                                ),
                              ],
                            ),
                          ),
                          // Status
                          Expanded(
                            flex: 2,
                            child: AdminTheme.statusBadge(status),
                          ),
                        ],
                      ),
                    );
                  }),

                // Pagination
                AdminPagination(
                  currentPage: _currentPage,
                  totalPages: _totalPages,
                  totalItems: rekap.length,
                  itemLabel: 'mahasiswa',
                  onPageChanged: (p) => setState(() => _currentPage = p),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ─── Visual Reports & Performance Panel (2-Column Layout) ───
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Column 1: Monthly Attendance Trends (Custom Paint) & Department Performance (Flex: 5)
              Expanded(
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: AdminTheme.cardDecoration,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tren Kehadiran Bulanan & Departemen',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AdminTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Representasi grafik tren kehadiran bulanan dan performa masing-masing jurusan.',
                        style: AdminTheme.caption,
                      ),
                      const SizedBox(height: 20),
                      // Custom Paint Line Chart representing monthly trends
                      SizedBox(
                        height: 140,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: _AttendanceTrendPainter(absensiData: _allAbsensi),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Divider(color: AdminTheme.border, height: 1),
                      const SizedBox(height: 20),
                      const Text(
                        'Tingkat Kehadiran Per Jurusan',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AdminTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Department progress bars calculated dynamically
                      Builder(
                        builder: (context) {
                          final Map<String, List<double>> jurAverages = {};
                          for (final m in rekap) {
                            final jur = m['jurusan'] as String;
                            final pct = m['pct'] as double;
                            jurAverages.putIfAbsent(jur, () => []).add(pct);
                          }
                          if (jurAverages.isEmpty) {
                            return const Text('Belum ada data jurusan.', style: TextStyle(fontSize: 11, color: AdminTheme.textMuted));
                          }
                          return Column(
                            children: jurAverages.entries.map((entry) {
                              final name = entry.key;
                              final pcts = entry.value;
                              final avg = pcts.reduce((a, b) => a + b) / pcts.length;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10.0),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 120,
                                      child: Text(
                                        name,
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AdminTheme.textSecondary),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: avg / 100,
                                          backgroundColor: AdminTheme.bg,
                                          color: avg >= 75 ? AdminTheme.success : AdminTheme.danger,
                                          minHeight: 6,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    SizedBox(
                                      width: 40,
                                      child: Text(
                                        '${avg.toStringAsFixed(1)}%',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: avg >= 75 ? AdminTheme.success : AdminTheme.danger,
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        }
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),

              // Column 2: Engagement Score & Course Performance Mini Table (Flex: 4)
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: AdminTheme.cardDecoration,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Engagement Score
                      const Text(
                        'Skor Keterlibatan (Engagement)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AdminTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AdminTheme.primaryLight,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.insights_rounded,
                              color: AdminTheme.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_avgAttendance.toStringAsFixed(0)} / 100',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AdminTheme.textPrimary,
                                  ),
                                ),
                                const Text(
                                  'Tingkat Keaktifan Mahasiswa',
                                  style: AdminTheme.caption,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Divider(color: AdminTheme.border, height: 1),
                      const SizedBox(height: 20),

                      // Course Performance Table
                      const Text(
                        'Performa Kehadiran Kelas (Mata Kuliah)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AdminTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Mini Table headers
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        color: AdminTheme.bg,
                        child: const Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text('MATA KULIAH', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AdminTheme.textMuted)),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text('HADIR', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AdminTheme.textMuted), textAlign: TextAlign.right),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text('RATE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AdminTheme.textMuted), textAlign: TextAlign.right),
                            ),
                          ],
                        ),
                      ),
                      // Dynamic Course List from absensi data
                      Builder(
                        builder: (context) {
                          // Map containing course name -> [Total check-ins, Clean check-ins]
                          final Map<String, List<int>> courseStats = {};
                          for (final a in _allAbsensi) {
                            final String mkName = _getMKName(a['sesi_id']);
                            if (mkName == '-') continue;
                            courseStats.putIfAbsent(mkName, () => [0, 0]);
                            courseStats[mkName]![0]++; // Increment total check-ins
                            if (a['jenis'] == 'Hadir') {
                              courseStats[mkName]![1]++; // Increment present count
                            }
                          }
                          if (courseStats.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(child: Text('Belum ada log mata kuliah.', style: TextStyle(fontSize: 11, color: AdminTheme.textMuted))),
                            );
                          }
                          final sortedCourses = courseStats.entries.toList()
                            ..sort((a, b) {
                              final rateA = a.value[1] / a.value[0];
                              final rateB = b.value[1] / b.value[0];
                              return rateB.compareTo(rateA);
                            });

                          return Column(
                            children: sortedCourses.take(3).map<Widget>((entry) {
                              final name = entry.key;
                              final total = entry.value[0];
                              final present = entry.value[1];
                              final rate = (present / total) * 100;

                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                decoration: const BoxDecoration(
                                  border: Border(bottom: BorderSide(color: AdminTheme.border, width: 0.5)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        name,
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AdminTheme.textPrimary),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Text('$present', style: const TextStyle(fontSize: 11, color: AdminTheme.textSecondary), textAlign: TextAlign.right),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        '${rate.toStringAsFixed(0)}%',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: rate >= 75 ? AdminTheme.success : AdminTheme.danger,
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        }
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white60,
                fontSize: 10,
                fontWeight: FontWeight.bold)),
        const SizedBox(width: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _AttendanceTrendPainter extends CustomPainter {
  final List<Map<String, dynamic>> absensiData;
  _AttendanceTrendPainter({required this.absensiData});

  @override
  void paint(Canvas canvas, Size size) {
    final List<int> values = [];
    final List<String> labels = [];
    final now = DateTime.now();

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final labelStr = DateFormat('dd/MM').format(date);
      labels.add(labelStr);

      final count = absensiData.where((e) {
        if (e['waktu'] == null) return false;
        try {
          final dt = DateTime.parse(e['waktu']).toLocal();
          return DateFormat('yyyy-MM-dd').format(dt) == dateStr;
        } catch (_) {
          return false;
        }
      }).length;
      values.add(count);
    }

    final paintLine = Paint()
      ..color = AdminTheme.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final paintDot = Paint()
      ..color = AdminTheme.primary
      ..style = PaintingStyle.fill;

    final paintDotBorder = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final textPainter = TextPainter(
      textDirection: ui.TextDirection.ltr,
    );

    final paintGrid = Paint()
      ..color = AdminTheme.border
      ..strokeWidth = 0.5;

    final double gridHeight = size.height - 20;
    for (int i = 0; i <= 3; i++) {
      final y = gridHeight * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paintGrid);
    }

    if (values.isEmpty) return;
    final maxVal = values.reduce((a, b) => a > b ? a : b).clamp(5, 99999).toDouble();

    final points = <Offset>[];
    final double stepX = size.width / (values.length - 1);

    for (int i = 0; i < values.length; i++) {
      final x = i * stepX;
      final y = gridHeight - (values[i] / maxVal * (gridHeight - 10));
      points.add(Offset(x, y));

      textPainter.text = TextSpan(
        text: labels[i],
        style: const TextStyle(fontSize: 8, color: AdminTheme.textMuted, fontWeight: FontWeight.bold),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, size.height - 14));
    }

    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paintLine);

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [AdminTheme.primary.withOpacity(0.15), AdminTheme.primary.withOpacity(0.0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTRB(0, 0, size.width, gridHeight))
      ..style = PaintingStyle.fill;

    final fillPath = Path()
      ..moveTo(points[0].dx, gridHeight)
      ..lineTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      fillPath.lineTo(points[i].dx, points[i].dy);
    }
    fillPath.lineTo(points.last.dx, gridHeight);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);

    for (final pt in points) {
      canvas.drawCircle(pt, 5, paintDotBorder);
      canvas.drawCircle(pt, 3.5, paintDot);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}