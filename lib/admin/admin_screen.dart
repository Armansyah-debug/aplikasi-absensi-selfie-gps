import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import 'riwayat_admin_screen.dart';
import 'theme/admin_theme.dart';
import 'package:intl/intl.dart';

/// AdminScreen — Dashboard content widget (no Scaffold, runs inside AdminShell).
/// All existing business logic preserved. Extended with additional metrics.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  // ─── Existing state (PRESERVED) ───
  int mahasiswaCount = 0;
  int dosenCount = 0;
  int mkCount = 0;
  int sesiAktifCount = 0;
  bool loading = true;

  // ─── Extended state (NEW metrics from existing data) ───
  double hadirHariIniPercent = 0;
  int izinMenunggu = 0;
  int fakeGpsCount = 0;
  Map<String, int> weekTrend = {};
  List<Map<String, dynamic>> recentActivity = [];
  List<Map<String, dynamic>> _sesiList = [];
  List<Map<String, dynamic>> _mkList = [];

  @override
  void initState() {
    super.initState();
    loadDashboard();
  }

  /// loadDashboard — EXTENDED version that fetches additional metrics
  /// using existing tables (no new schema).
  Future<void> loadDashboard() async {
    setState(() => loading = true);
    final supabase = Supabase.instance.client;

    try {
      final now = DateTime.now().toLocal();
      final startOfDay =
          DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
      final sevenDaysAgo =
          now.subtract(const Duration(days: 7)).toUtc().toIso8601String();

      // Parallel fetch using Future.wait for performance
      final results = await Future.wait([
        supabase.from('profiles').select('role'),
        supabase.from('mata_kuliah').select('id, nama_mk'),
        supabase
            .from('sesi_absensi')
            .select('id, mata_kuliah_id, pertemuan_ke, materi')
            .eq('is_open', true),
        supabase
            .from('data_absensi')
            .select('nama,npm,waktu,lokasi,alamat,jenis,is_mocked,sesi_id')
            .order('waktu', ascending: false)
            .limit(10),
        supabase
            .from('data_absensi')
            .select('jenis, is_mocked')
            .gte('waktu', startOfDay),
        supabase
            .from('data_absensi')
            .select('jenis, waktu')
            .gte('waktu', sevenDaysAgo),
      ]);

      final profiles = results[0] as List;
      final mk = results[1] as List;
      final sesi = results[2] as List;
      final recent = results[3] as List;
      final todayData = results[4] as List;
      final weekData = results[5] as List;

      // Today stats
      final todayHadir = todayData.where((e) => e['jenis'] == 'Hadir').length;
      final todayTotal = todayData.length;
      final hadirPct = todayTotal == 0 ? 0.0 : (todayHadir / todayTotal) * 100;
      final izin = todayData
          .where((e) => e['jenis'] == 'Izin' || e['jenis'] == 'Sakit')
          .length;
      final fakeGps = todayData.where((e) => e['is_mocked'] == true).length;

      // 7-day trend (hadir count per day)
      final Map<String, int> trend = {};
      for (final item in weekData) {
        if (item['jenis'] == 'Hadir') {
          final dt = DateTime.parse(item['waktu']).toLocal();
          final key =
              '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
          trend[key] = (trend[key] ?? 0) + 1;
        }
      }

      if (mounted) {
        setState(() {
          mahasiswaCount = profiles
              .where((e) => e['role'] == 'user' || e['role'] == 'mahasiswa')
              .length;
          dosenCount = profiles.where((e) => e['role'] == 'dosen').length;
          mkCount = mk.length;
          sesiAktifCount = sesi.length;
          hadirHariIniPercent = hadirPct;
          izinMenunggu = izin;
          fakeGpsCount = fakeGps;
          weekTrend = trend;
          recentActivity = List<Map<String, dynamic>>.from(recent);
          _sesiList = List<Map<String, dynamic>>.from(sesi);
          _mkList = List<Map<String, dynamic>>.from(mk);
          loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading admin dashboard: $e');
      if (mounted) setState(() => loading = false);
    }
  }

  String _getMKName(dynamic sesiId) {
    if (sesiId == null) return '-';
    final sesi = _sesiList.firstWhere(
      (s) => s['id'] == sesiId,
      orElse: () => {},
    );
    if (sesi.isEmpty) return '-';
    final mk = _mkList.firstWhere(
      (m) => m['id'] == sesi['mata_kuliah_id'],
      orElse: () => {},
    );
    return mk['nama_mk'] ?? '-';
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (loading) return _buildSkeleton();

    return RefreshIndicator(
      onRefresh: loadDashboard,
      color: AdminTheme.primary,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildPageHeader(context),
          const SizedBox(height: 20),
          _buildSummaryCards(),
          const SizedBox(height: 20),
          _buildChartAndGeofencing(context),
          const SizedBox(height: 20),
          _buildActiveSessionCard(),
          const SizedBox(height: 20),
          _buildRecentActivity(context),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildActiveSessionCard() {
  if (_sesiList.isEmpty) {
    return Container(
      height: 180,
      padding: const EdgeInsets.all(20),
      decoration: AdminTheme.cardDecoration,
      child: const Center(
        child: Text(
          'Tidak ada sesi aktif saat ini',
          style: AdminTheme.body,
        ),
      ),
    );
  }

  final sesi = _sesiList.first;

  return Container(
    height: 180,
    padding: const EdgeInsets.all(20),
    decoration: AdminTheme.cardDecoration,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sesi Aktif',
          style: AdminTheme.h3,
        ),

        const SizedBox(height: 16),

        Text(
          _getMKName(sesi['id']),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AdminTheme.textPrimary,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          'Pertemuan ${sesi['pertemuan_ke'] ?? '-'}',
          style: AdminTheme.body,
        ),

        const SizedBox(height: 4),

        Text(
          '${sesi['materi'] ?? '-'}',
          style: const TextStyle(
            color: AdminTheme.textSecondary,
            fontSize: 13,
          ),
        ),

        const Spacer(),

        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: AdminTheme.successLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'AKTIF',
            style: TextStyle(
              color: AdminTheme.successDark,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ),
      ],
    ),
  );
}

  // ─────────────────────────────────────────────
  // PAGE HEADER
  // ─────────────────────────────────────────────
  Widget _buildPageHeader(BuildContext context) {
    final today = DateFormat('dd MMM yyyy', 'id_ID').format(DateTime.now());
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Dashboard Utama', style: AdminTheme.h1),
              const SizedBox(height: 4),
              const Text(
                'Selamat datang kembali. Berikut ringkasan kehadiran hari ini.',
                style: AdminTheme.body,
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AdminTheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AdminTheme.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 14, color: AdminTheme.textSecondary),
                  const SizedBox(width: 6),
                  Text(today,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AdminTheme.textSecondary,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Fitur export laporan segera tersedia',
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.download_outlined, size: 16),
              label: const Text('Export Laporan',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // SUMMARY CARDS
  // ─────────────────────────────────────────────
  Widget _buildSummaryCards() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _StatCard(
          icon: Icons.people_outline_rounded,
          label: 'Total Mahasiswa',
          value: _fmt(mahasiswaCount),
          badge: null,
          badgeColor: AdminTheme.success,
          iconColor: AdminTheme.primary,
        ),
        const SizedBox(width: 12),
        _StatCard(
          icon: Icons.school_outlined,
          label: 'Total Dosen',
          value: _fmt(dosenCount),
          badge: null,
          badgeColor: AdminTheme.textMuted,
          iconColor: AdminTheme.primary,
        ),
        const SizedBox(width: 12),
        _StatCard(
          icon: Icons.menu_book_outlined,
          label: 'Total Mata Kuliah',
          value: _fmt(mkCount),
          iconColor: AdminTheme.primary,
        ),
        const SizedBox(width: 12),
        // Highlighted: Absensi Hari Ini
        _AbsensiCard(percent: hadirHariIniPercent, total: mahasiswaCount),
        const SizedBox(width: 12),
        _StatCard(
          icon: Icons.radio_button_checked_rounded,
          label: 'Sesi Aktif',
          value: _fmt(sesiAktifCount),
          subtitle: 'Sedang berlangsung',
          iconColor: AdminTheme.success,
          dotColor: AdminTheme.success,
        ),
        const SizedBox(width: 12),
        _StatCard(
          icon: Icons.assignment_late_outlined,
          label: 'Izin Menunggu',
          value: _fmt(izinMenunggu),
          valueColor: AdminTheme.danger,
          iconColor: AdminTheme.danger,
        ),
        const SizedBox(width: 12),

        _StatCard(
          icon: Icons.gpp_bad_rounded,
          label: 'Fake GPS',
          value: _fmt(fakeGpsCount),
          valueColor: AdminTheme.danger,
          iconColor: AdminTheme.danger,
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // CHART + GEOFENCING
  // ─────────────────────────────────────────────
  Widget _buildChartAndGeofencing(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 700;
    final chart = _buildTrendChart();
    final geo = _buildGeofencingCard(context);

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 6, child: chart),
          const SizedBox(width: 16),
          SizedBox(width: 280, child: geo),
        ],
      );
    }
    return Column(
      children: [chart, const SizedBox(height: 16), geo],
    );
  }

  Widget _buildTrendChart() {
    final days =
        List.generate(7, (i) => DateTime.now().subtract(Duration(days: 6 - i)));
    const dayNames = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

    int maxVal = 1;
    for (final d in days) {
      final k = _dayKey(d);
      final v = weekTrend[k] ?? 0;
      if (v > maxVal) maxVal = v;
    }
    final today = DateTime.now();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AdminTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Tren Kehadiran Mingguan', style: AdminTheme.h3),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AdminTheme.bg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AdminTheme.border),
                ),
                child: Row(
                  children: [
                    const Text('7 Hari Terakhir',
                        style: TextStyle(
                            fontSize: 11,
                            color: AdminTheme.textSecondary,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down_rounded,
                        size: 14, color: AdminTheme.textSecondary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 160,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: days.map((day) {
                final k = _dayKey(day);
                final count = weekTrend[k] ?? 0;
                final isToday = day.day == today.day &&
                    day.month == today.month &&
                    day.year == today.year;
                final barH = (maxVal == 0 ? 4.0 : (count / maxVal) * 120.0)
                    .clamp(4.0, 120.0);
                final pct = mahasiswaCount == 0
                    ? 0
                    : (count / mahasiswaCount * 100).round();

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (isToday && count > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: AdminTheme.textPrimary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '$pct%',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.easeOut,
                          height: barH,
                          decoration: BoxDecoration(
                            color: isToday
                                ? AdminTheme.primary
                                : AdminTheme.primary.withOpacity(0.22),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(5),
                              topRight: Radius.circular(5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          dayNames[day.weekday - 1],
                          style: TextStyle(
                            fontSize: 10,
                            color: isToday
                                ? AdminTheme.textPrimary
                                : AdminTheme.textMuted,
                            fontWeight:
                                isToday ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeofencingCard(BuildContext context) {
    final validPct = (izinMenunggu == 0 && fakeGpsCount == 0)
        ? 100.0
        : 100.0 -
            (fakeGpsCount /
                (izinMenunggu + fakeGpsCount + mahasiswaCount)
                    .clamp(1, 999999) *
                100);
    final accuracy = validPct.clamp(80.0, 100.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AdminTheme.primaryGradientDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Monitoring Geofencing',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Text(
            fakeGpsCount > 0
                ? 'Sistem mendeteksi $fakeGpsCount percobaan absensi di luar radius kampus hari ini.'
                : 'Tidak ada percobaan absensi di luar radius kampus hari ini.',
            style: const TextStyle(
                color: Colors.white70, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'AKURASI RATA-RATA',
                style: TextStyle(
                    color: Colors.white60,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5),
              ),
              Text(
                '${accuracy.toStringAsFixed(1)}%',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: accuracy / 100,
              minHeight: 6,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Buka menu Monitoring dari sidebar')),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AdminTheme.primary,
                backgroundColor: Colors.white,
                side: BorderSide.none,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text(
                'Buka Monitoring',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // RECENT ACTIVITY TABLE
  // ─────────────────────────────────────────────
  Widget _buildRecentActivity(BuildContext context) {
    return Container(
      decoration: AdminTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                const Expanded(
                  child:
                      Text('Aktivitas Absensi Terbaru', style: AdminTheme.h3),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AdminTheme.bg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AdminTheme.border),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.tune_rounded,
                          size: 13, color: AdminTheme.textSecondary),
                      SizedBox(width: 5),
                      Text('Filter',
                          style: TextStyle(
                              fontSize: 12,
                              color: AdminTheme.textSecondary,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            color: AdminTheme.bg,
            child: const Row(
              children: [
                Expanded(flex: 3, child: _TableHeader('NAMA MAHASISWA')),
                Expanded(flex: 3, child: _TableHeader('MATA KULIAH')),
                Expanded(flex: 2, child: _TableHeader('WAKTU')),
                Expanded(flex: 3, child: _TableHeader('LOKASI GPS')),
                Expanded(flex: 2, child: _TableHeader('STATUS')),
                SizedBox(width: 40),
              ],
            ),
          ),
          // Table rows
          if (recentActivity.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text('Belum ada aktivitas hari ini',
                    style: AdminTheme.body),
              ),
            )
          else
            ...recentActivity.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              return _ActivityRow(
                item: item,
                mkName: _getMKName(item['sesi_id']),
                isEven: i.isEven,
              );
            }),
          // Footer
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RiwayatAdminScreen(),
                ),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AdminTheme.border)),
              ),
              child: const Center(
                child: Text(
                  'Lihat Semua Aktivitas',
                  style: TextStyle(
                    color: AdminTheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // SKELETON LOADING
  // ─────────────────────────────────────────────
  Widget _buildSkeleton() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SkeletonBox(height: 60, borderRadius: 12),
        const SizedBox(height: 20),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(
                6,
                (i) => Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: _SkeletonBox(width: 200, height: 100),
                    )),
          ),
        ),
        const SizedBox(height: 20),
        _SkeletonBox(height: 260, borderRadius: 12),
        const SizedBox(height: 20),
        _SkeletonBox(height: 360, borderRadius: 12),
      ],
    );
  }

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmt(int n) => NumberFormat('#,###', 'id_ID').format(n);
}

// ─────────────────────────────────────────────
// SUB-WIDGETS
// ─────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? badge;
  final Color? badgeColor;
  final String? subtitle;
  final Color? valueColor;
  final Color iconColor;
  final Color? dotColor;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.badge,
    this.badgeColor,
    this.subtitle,
    this.valueColor,
    required this.iconColor,
    this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: AdminTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const Spacer(),
              if (badge != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color:
                        (badgeColor ?? AdminTheme.textMuted).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: badgeColor ?? AdminTheme.textMuted,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (dotColor != null) ...[
            Row(
              children: [
                Icon(Icons.circle, color: dotColor, size: 8),
                const SizedBox(width: 5),
                Text(
                  subtitle ?? '',
                  style: TextStyle(
                      fontSize: 10,
                      color: dotColor,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 2),
          ],
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: valueColor ?? AdminTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: AdminTheme.caption),
          if (subtitle != null && dotColor == null) ...[
            const SizedBox(height: 2),
            Text(subtitle!,
                style:
                    const TextStyle(fontSize: 10, color: AdminTheme.textMuted)),
          ],
        ],
      ),
    );
  }
}

class _AbsensiCard extends StatelessWidget {
  final double percent;
  final int total;

  const _AbsensiCard({required this.percent, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AdminTheme.primary.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AdminTheme.primary.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AdminTheme.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.verified_user_outlined,
                    color: AdminTheme.primary, size: 18),
              ),
              const Spacer(),
              Text(
                'Absensi Hari Ini',
                style: TextStyle(
                    fontSize: 10,
                    color: AdminTheme.primary.withOpacity(0.8),
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${percent.toStringAsFixed(0)}%',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AdminTheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 5,
              backgroundColor: AdminTheme.primaryLight,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AdminTheme.primary),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(percent / 100 * total).round().toStringAsFixed(0)} dari $total Mahasiswa',
            style: AdminTheme.caption,
          ),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  final String text;
  const _TableHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AdminTheme.textMuted,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final String mkName;
  final bool isEven;

  const _ActivityRow({
    required this.item,
    required this.mkName,
    required this.isEven,
  });

  @override
  Widget build(BuildContext context) {
    final nama = item['nama'] ?? '-';
    final npm = item['npm'] ?? '-';
    final jenis = item['jenis'] ?? 'Hadir';
    final isMocked = item['is_mocked'] == true;
    final lokasi = (item['alamat'] ?? item['lokasi'] ?? '-').toString();
    String jam = '-';
    if (item['waktu'] != null) {
      try {
        jam = DateFormat('HH:mm:ss')
            .format(DateTime.parse(item['waktu']).toLocal());
      } catch (_) {}
    }

    // Shorten coordinate string
    final lokShort =
        lokasi.length > 22 ? '${lokasi.substring(0, 22)}…' : lokasi;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: isEven ? Colors.white : AdminTheme.bg.withOpacity(0.5),
      child: Row(
        children: [
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
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AdminTheme.textPrimary)),
                      Text(npm,
                          style: const TextStyle(
                              fontSize: 10, color: AdminTheme.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(mkName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12, color: AdminTheme.textSecondary)),
          ),
          Expanded(
            flex: 2,
            child: Text(jam,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AdminTheme.textPrimary)),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Icon(
                  isMocked
                      ? Icons.warning_amber_rounded
                      : Icons.location_on_rounded,
                  size: 12,
                  color: isMocked ? AdminTheme.warning : AdminTheme.success,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(lokShort,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: AdminTheme.textSecondary)),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                AdminTheme.statusBadge(isMocked ? 'Fake GPS' : jenis),
              ],
            ),
          ),
          SizedBox(
            width: 40,
            child: Icon(Icons.more_vert_rounded,
                size: 18, color: AdminTheme.textMuted),
          ),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const _SkeletonBox({this.width, required this.height, this.borderRadius = 8});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AdminTheme.border,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}
