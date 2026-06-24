import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import 'theme/admin_theme.dart';
import 'widgets/admin_widgets.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({super.key});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  bool _loading = true;

  // Raw data
  List<Map<String, dynamic>> _allData = [];
  List<Map<String, dynamic>> _allSesi = [];
  List<Map<String, dynamic>> _allMK = [];

  // Filter state
  String? _filterJurusan;
  String? _filterMKId;

  // Pagination
  static const _perPage = 10;
  int _currentPage = 1;

  // Jurusan options (from MK)
  List<String> get _jurusanOptions {
    final set = _allMK.map((e) => e['jurusan']?.toString() ?? '').toSet().toList();
    set.sort();
    return set;
  }

  // Filtered MK (based on jurusan filter)
  List<Map<String, dynamic>> get _filteredMKOptions {
    if (_filterJurusan == null || _filterJurusan == 'Semua') return _allMK;
    return _allMK.where((m) => m['jurusan'] == _filterJurusan).toList();
  }

  // Apply filter
  List<Map<String, dynamic>> get _filteredData {
    return _allData.where((item) {
      // Filter by MK via sesi
      if (_filterMKId != null) {
        final sesi = _allSesi.firstWhere(
          (s) => s['id'] == item['sesi_id'],
          orElse: () => {},
        );
        if (sesi.isEmpty || sesi['mata_kuliah_id'].toString() != _filterMKId) {
          return false;
        }
      }
      // Filter by jurusan via sesi → MK
      if (_filterJurusan != null && _filterJurusan != 'Semua') {
        final sesi = _allSesi.firstWhere(
          (s) => s['id'] == item['sesi_id'],
          orElse: () => {},
        );
        if (sesi.isEmpty) return false;
        final mk = _allMK.firstWhere(
          (m) => m['id'] == sesi['mata_kuliah_id'],
          orElse: () => {},
        );
        if (mk.isEmpty || mk['jurusan'] != _filterJurusan) return false;
      }
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> get _paginated {
    final list = _filteredData;
    final start = (_currentPage - 1) * _perPage;
    final end = (start + _perPage).clamp(0, list.length);
    if (start >= list.length) return [];
    return list.sublist(start, end);
  }

  int get _totalPages => (_filteredData.length / _perPage).ceil().clamp(1, 9999);

  // Stats from today's data
  late final String _startOfDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now().toLocal();
    _startOfDay = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final supabase = Supabase.instance.client;

    try {
      final results = await Future.wait([
        supabase
            .from('data_absensi')
            .select('*')
            .order('waktu', ascending: false),
        supabase
            .from('sesi_absensi')
            .select('id, mata_kuliah_id, is_open, pertemuan_ke'),
        SupabaseService.getAllMK(),
      ]);

      if (mounted) {
        setState(() {
          _allData = List<Map<String, dynamic>>.from(results[0] as List);
          _allSesi = List<Map<String, dynamic>>.from(results[1] as List);
          _allMK = List<Map<String, dynamic>>.from(results[2] as List);
          _loading = false;
          _currentPage = 1;
        });
      }
    } catch (e) {
      debugPrint('Monitoring error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  // Derived stats
  List<Map<String, dynamic>> get _todayData =>
      _allData.where((e) => (e['waktu'] ?? '').compareTo(_startOfDay) >= 0).toList();

  int get _activeSessions =>
      _allSesi.where((e) => e['is_open'] == true).length;
  int get _hadirTepat =>
      _todayData.where((e) => e['jenis'] == 'Hadir' && e['is_mocked'] != true).length;
  int get _fakeGpsToday =>
      _todayData.where((e) => e['is_mocked'] == true).length;
  int get _absenLuarKampus => _fakeGpsToday;

  String _getMKName(dynamic sesiId) {
    if (sesiId == null) return '-';
    final sesi = _allSesi.firstWhere((s) => s['id'] == sesiId, orElse: () => {});
    if (sesi.isEmpty) return '-';
    final mk = _allMK.firstWhere((m) => m['id'] == sesi['mata_kuliah_id'], orElse: () => {});
    return mk['nama_mk'] ?? '-';
  }

  void _showDetail(Map<String, dynamic> item) {
    final nama = item['nama'] ?? '-';
    final npm = item['npm'] ?? '-';
    final jenis = item['jenis'] ?? 'Hadir';
    final isMocked = item['is_mocked'] == true;
    final lokasi = item['lokasi'] ?? '-';
    final alamat = item['alamat'] ?? '-';
    final mkName = _getMKName(item['sesi_id']);
    final fotoPath = item['foto_path'];

    String jam = '-';
    if (item['waktu'] != null) {
      try {
        jam = DateFormat('HH:mm:ss, dd MMM yyyy')
            .format(DateTime.parse(item['waktu']).toLocal());
      } catch (_) {}
    }

    final String? fotoUrl = () {
      if (fotoPath != null && fotoPath.toString().isNotEmpty) {
        if (fotoPath.startsWith('http')) {
          return fotoPath;
        } else {
          return Supabase.instance.client.storage.from('selfies').getPublicUrl(fotoPath);
        }
      }
      return null;
    }();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 460,
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Detail Verifikasi Absensi', style: AdminTheme.h2),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 1. FOTO SELFIE UTAMA
              if (fotoUrl != null)
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: ctx,
                      builder: (_) => Dialog(
                        backgroundColor: Colors.transparent,
                        insetPadding: const EdgeInsets.all(20),
                        child: Stack(
                          alignment: Alignment.topRight,
                          children: [
                            InteractiveViewer(
                              clipBehavior: Clip.none,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  fotoUrl,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 32),
                              onPressed: () => Navigator.pop(_),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    height: 280,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: AdminTheme.bg,
                      border: Border.all(color: AdminTheme.border),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        fotoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.broken_image_rounded, color: AdminTheme.textMuted, size: 48),
                        ),
                      ),
                    ),
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  height: 180,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: AdminTheme.bg,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AdminTheme.avatarInitials(nama, radius: 40),
                        const SizedBox(height: 10),
                        const Text('Foto tidak tersedia', style: AdminTheme.caption),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 20),

              // 2. STATUS BADGES
              Row(
                children: [
                  AdminTheme.statusBadge(jenis),
                  const SizedBox(width: 10),
                  AdminTheme.statusBadge(isMocked ? 'Fake GPS' : 'Verified GPS'),
                ],
              ),
              const Divider(height: 32, color: AdminTheme.border),

              // 3. INFORMASI MAHASISWA & ABSENSI
              _dRow('Nama Lengkap', nama),
              _dRow('NPM / ID', npm),
              _dRow('Waktu Absensi', jam),
              _dRow('Mata Kuliah', mkName),
              _dRow('Koordinat GPS', lokasi),
              _dRow('Alamat', alamat),
              
              const SizedBox(height: 24),

              // TOMBOL GOOGLE MAPS
              if (lokasi != null && lokasi != '-' && lokasi.toString().contains(','))
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final coords = lokasi.toString().split(',');
                      if (coords.length >= 2) {
                        final lat = coords[0].trim();
                        final lng = coords[1].trim();
                        final url = Uri.parse('https://maps.google.com/?q=$lat,$lng');
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url);
                        } else {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Gagal membuka maps')));
                          }
                        }
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AdminTheme.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.map_rounded, size: 18, color: AdminTheme.primary),
                    label: const Text('Buka di Google Maps', style: TextStyle(color: AdminTheme.primary, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _dRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    color: AdminTheme.textMuted,
                    fontWeight: FontWeight.w600)),
          ),
          const Text(': ', style: TextStyle(color: AdminTheme.textMuted)),
          Expanded(
            child: Text(val,
                style: const TextStyle(
                    fontSize: 13,
                    color: AdminTheme.textPrimary,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
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
          AdminSkeletonBox(height: 400),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
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
                    Text('Monitoring Absensi Real-time', style: AdminTheme.h1),
                    SizedBox(height: 4),
                    Text(
                      'Status kehadiran mahasiswa hari ini secara langsung melalui sinkronisasi GPS.',
                      style: AdminTheme.body,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _loadData,
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  side: const BorderSide(color: AdminTheme.border),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.refresh_rounded,
                    size: 16, color: AdminTheme.textSecondary),
                label: const Text('Refresh',
                    style: TextStyle(
                        color: AdminTheme.textSecondary, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ─── Filter Bar ───
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AdminTheme.cardDecoration,
            child: Row(
              children: [
                // Filter Jurusan
                Expanded(
                  flex: 3,
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
                      _filterMKId = null;
                      _currentPage = 1;
                    }),
                    decoration: AdminTheme.inputDecoration(label: 'Jurusan'),
                  ),
                ),
                const SizedBox(width: 12),
                // Filter MK
                Expanded(
                  flex: 4,
                  child: DropdownButtonFormField<String>(
                    value: _filterMKId,
                    hint: const Text('Semua Mata Kuliah'),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('Semua Mata Kuliah')),
                      ..._filteredMKOptions.map((m) => DropdownMenuItem(
                            value: m['id'].toString(),
                            child: Text(m['nama_mk'] ?? '-'),
                          )),
                    ],
                    onChanged: (v) => setState(() {
                      _filterMKId = v;
                      _currentPage = 1;
                    }),
                    decoration:
                        AdminTheme.inputDecoration(label: 'Mata Kuliah'),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => setState(() {
                    _filterJurusan = null;
                    _filterMKId = null;
                    _currentPage = 1;
                  }),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminTheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.filter_list_rounded, size: 16),
                  label: const Text('Terapkan Filter'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ─── Stat Cards ───
          Builder(
            builder: (context) {
              final allClean = _allData.where((e) => e['is_mocked'] != true).length;
              final double integrityScore = _allData.isEmpty ? 100.0 : (allClean / _allData.length * 100);
              return Row(
                children: [
                  Expanded(
                    child: AdminStatCard(
                      icon: Icons.radio_button_checked_rounded,
                      iconColor: AdminTheme.success,
                      label: 'Sedang Berlangsung',
                      value: '$_activeSessions',
                      trailing: _activeSessions > 0 ? AdminTheme.liveDot() : null,
                      subtitle: 'sesi aktif',
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: AdminStatCard(
                      icon: Icons.verified_user_outlined,
                      iconColor: AdminTheme.primary,
                      label: 'Hadir Tepat Waktu',
                      value: '$_hadirTepat',
                      subtitle: _todayData.isEmpty
                          ? '0% dari total'
                          : '${(_hadirTepat / _todayData.length * 100).toStringAsFixed(0)}% dari total',
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: AdminStatCard(
                      icon: Icons.shield_outlined,
                      iconColor: AdminTheme.info,
                      label: 'Integrity Score',
                      value: '${integrityScore.toStringAsFixed(0)}%',
                      subtitle: 'GPS Valid rata-rata',
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: AdminStatCard(
                      icon: Icons.gpp_bad_rounded,
                      iconColor: AdminTheme.danger,
                      label: 'Pelanggaran Aktif',
                      value: '$_fakeGpsToday',
                      subtitle: 'Kasus Fake GPS hari ini',
                      valueColor: _fakeGpsToday > 0 ? AdminTheme.danger : null,
                    ),
                  ),
                ],
              );
            }
          ),
          const SizedBox(height: 20),

          // ─── Main Contents Row (2-Column Layout) ───
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Column 1: Log Absensi Table (Flex: 5)
              Expanded(
                flex: 5,
                child: Container(
                  decoration: AdminTheme.cardDecoration,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Log Absensi Terbaru', style: AdminTheme.h3),
                                  SizedBox(height: 2),
                                  Text(
                                    'Arus data real-time check-in dan lokasi GPS mahasiswa.',
                                    style: AdminTheme.caption,
                                  ),
                                ],
                              ),
                            ),
                            AdminTheme.liveDot(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Table header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        color: AdminTheme.bg,
                        child: const Row(
                          children: [
                            AdminTableHeader('MAHASISWA', flex: 3),
                            AdminTableHeader('MATA KULIAH', flex: 3),
                            AdminTableHeader('CHECK-IN', flex: 2),
                            AdminTableHeader('KOORDINAT GPS', flex: 3),
                            AdminTableHeader('STATUS', flex: 2),
                            SizedBox(width: 60, child: Text('', style: TextStyle())),
                          ],
                        ),
                      ),
                      // Rows
                      if (_filteredData.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: Text('Belum ada data absensi', style: AdminTheme.body),
                          ),
                        )
                      else
                        ..._paginated.asMap().entries.map((entry) {
                          final i = entry.key;
                          final item = entry.value;
                          final nama = item['nama'] ?? '-';
                          final npm = item['npm'] ?? '-';
                          final isMocked = item['is_mocked'] == true;
                          final jenis = item['jenis'] ?? 'Hadir';
                          final lokasi = (item['lokasi'] ?? '-').toString();
                          final mkName = _getMKName(item['sesi_id']);
                          final lokShort = lokasi.length > 20
                              ? '${lokasi.substring(0, 20)}…'
                              : lokasi;
                          String jam = '-';
                          if (item['waktu'] != null) {
                            try {
                              jam = DateFormat('HH:mm:ss').format(
                                  DateTime.parse(item['waktu']).toLocal());
                            } catch (_) {}
                          }

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: AdminTheme.tableRowDecoration(isEven: i.isEven),
                            child: Row(
                              children: [
                                // Mahasiswa
                                Expanded(
                                  flex: 3,
                                  child: Row(
                                    children: [
                                      AdminTheme.avatarInitials(nama, radius: 16),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(nama,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: AdminTheme.tableCellBold),
                                            Text(npm,
                                                style: const TextStyle(
                                                    fontSize: 10,
                                                    color: AdminTheme.textMuted)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // MK
                                Expanded(
                                  flex: 3,
                                  child: Text(mkName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AdminTheme.textSecondary)),
                                ),
                                // Jam
                                Expanded(
                                  flex: 2,
                                  child: Text(jam, style: AdminTheme.tableCellBold),
                                ),
                                // GPS
                                Expanded(
                                  flex: 3,
                                  child: Row(
                                    children: [
                                      Icon(
                                        isMocked
                                            ? Icons.gpp_bad_rounded
                                            : Icons.location_on_rounded,
                                        size: 12,
                                        color: isMocked
                                            ? AdminTheme.danger
                                            : AdminTheme.success,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          lokShort,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isMocked
                                                ? AdminTheme.danger
                                                : AdminTheme.textSecondary,
                                            fontWeight: isMocked
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Status
                                Expanded(
                                  flex: 2,
                                  child: AdminTheme.statusBadge(
                                      isMocked ? 'Fake GPS' : jenis),
                                ),
                                // Detail button
                                SizedBox(
                                  width: 60,
                                  child: TextButton(
                                    onPressed: () => _showDetail(item),
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      foregroundColor: AdminTheme.primary,
                                    ),
                                    child: const Text('Detail',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),

                      // Pagination
                      AdminPagination(
                        currentPage: _currentPage,
                        totalPages: _totalPages,
                        totalItems: _filteredData.length,
                        itemLabel: 'data',
                        onPageChanged: (p) => setState(() => _currentPage = p),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),

              // Column 2: Pelanggaran Aktif & Map Placeholder (Width: 320)
              SizedBox(
                width: 320,
                child: Column(
                  children: [
                    // Active Violations Panel
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: AdminTheme.cardDecoration,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Deteksi Fake GPS',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AdminTheme.textPrimary,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _fakeGpsToday > 0
                                      ? AdminTheme.dangerLight
                                      : AdminTheme.bg,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '$_fakeGpsToday Aktif',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _fakeGpsToday > 0
                                        ? AdminTheme.danger
                                        : AdminTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_todayData.where((e) => e['is_mocked'] == true).isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: Column(
                                  children: [
                                    Icon(Icons.verified_user_rounded,
                                        color: AdminTheme.success, size: 36),
                                    SizedBox(height: 10),
                                    Text(
                                      'Aman. Tidak ada manipulasi GPS terdeteksi hari ini.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 11, color: AdminTheme.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            ..._todayData
                                .where((e) => e['is_mocked'] == true)
                                .take(3)
                                .map((v) {
                              final name = v['nama'] ?? '-';
                              final address = v['alamat'] ?? v['lokasi'] ?? '-';
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AdminTheme.dangerLight.withOpacity(0.4),
                                  border: Border.all(color: AdminTheme.danger.withOpacity(0.3)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.gpp_bad_rounded,
                                            color: AdminTheme.danger, size: 14),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: AdminTheme.danger,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$address',
                                      style: const TextStyle(fontSize: 10, color: AdminTheme.textSecondary),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ─── Live Feed ticker ───
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AdminTheme.textPrimary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AdminTheme.success,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('LIVE FEED',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _allData.isEmpty
                        ? 'Belum ada aktivitas absensi hari ini'
                        : '${_allData.first['nama'] ?? '-'} baru saja melakukan absensi — ${_getMKName(_allData.first['sesi_id'])}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}