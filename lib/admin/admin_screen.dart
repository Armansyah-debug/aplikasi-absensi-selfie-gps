import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import 'theme/admin_theme.dart';
import 'widgets/admin_widgets.dart';
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
      final todayTotalValid = todayData.where((e) => e['jenis'] != 'Pelanggaran').length;
      final hadirPct = todayTotalValid == 0 ? 0.0 : (todayHadir / todayTotalValid) * 100;
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
        padding: const EdgeInsets.all(24),
        children: [
          _buildPageHeader(context),
          const SizedBox(height: 24),
          _buildSummaryCards(context),
          const SizedBox(height: 24),
          _buildChartAndActivity(context),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // PAGE HEADER
  // ─────────────────────────────────────────────
  Widget _buildPageHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Executive Dashboard', style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AdminTheme.textPrimary,
                letterSpacing: -0.5,
              )),
              SizedBox(height: 4),
              Text(
                'Real-time smart attendance system and monitoring.',
                style: AdminTheme.body,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // SUMMARY CARDS — 3 stats + alert card
  // ─────────────────────────────────────────────
  Widget _buildSummaryCards(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;

    final stat1 = AdminStatCard(
      icon: Icons.people_outline_rounded,
      iconColor: AdminTheme.primary,
      label: 'Total Mahasiswa',
      value: _fmt(mahasiswaCount),
      badge: dosenCount > 0 ? '+${_fmt(dosenCount)} dosen' : null,
      badgeColor: AdminTheme.success,
    );
    final stat2 = AdminStatCard(
      icon: Icons.radio_button_checked_rounded,
      iconColor: AdminTheme.success,
      label: 'Active Sessions',
      value: _fmt(sesiAktifCount),
      trailing: AdminTheme.liveDot(),
    );
    final stat3 = AdminStatCard(
      icon: Icons.verified_user_outlined,
      iconColor: AdminTheme.primary,
      label: 'Attendance Rate',
      value: '${hadirHariIniPercent.toStringAsFixed(1)}%',
      badge: izinMenunggu > 0 ? '-${izinMenunggu} izin' : null,
      badgeColor: izinMenunggu > 0 ? AdminTheme.danger : null,
    );

    final alert = AdminAlertCard(
      title: 'High Risk Alert',
      message: fakeGpsCount > 0
          ? 'Monitoring Fake GPS — $fakeGpsCount suspicious activities detected today.'
          : 'No suspicious activities detected today.',
      color: fakeGpsCount > 0 ? AdminTheme.danger : AdminTheme.success,
      icon: fakeGpsCount > 0 ? Icons.gpp_bad_rounded : Icons.check_circle_outline_rounded,
    );

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: stat1),
          const SizedBox(width: 14),
          Expanded(child: stat2),
          const SizedBox(width: 14),
          Expanded(child: stat3),
          const SizedBox(width: 14),
          SizedBox(width: 260, child: alert),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        stat1,
        const SizedBox(height: 14),
        stat2,
        const SizedBox(height: 14),
        stat3,
        const SizedBox(height: 14),
        alert,
      ],
    );
  }

  // ─────────────────────────────────────────────
  // CHART + ACTIVITY FEED
  // ─────────────────────────────────────────────
  Widget _buildChartAndActivity(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;
    final chart = _buildTrendChart();
    final activity = _buildActivityFeed();

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 6, child: chart),
          const SizedBox(width: 16),
          SizedBox(width: 320, child: activity),
        ],
      );
    }
    return Column(
      children: [chart, const SizedBox(height: 16), activity],
    );
  }

  Widget _buildTrendChart() {
    final days =
        List.generate(7, (i) => DateTime.now().subtract(Duration(days: 6 - i)));
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    int maxVal = 1;
    for (final d in days) {
      final k = _dayKey(d);
      final v = weekTrend[k] ?? 0;
      if (v > maxVal) maxVal = v;
    }
    final today = DateTime.now();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AdminTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Weekly Attendance Trend', style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AdminTheme.textPrimary,
                )),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AdminTheme.bg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AdminTheme.border),
                ),
                child: const Row(
                  children: [
                    Text('Last 7 Days',
                        style: TextStyle(
                            fontSize: 11,
                            color: AdminTheme.textSecondary,
                            fontWeight: FontWeight.w600)),
                    SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down_rounded,
                        size: 14, color: AdminTheme.textSecondary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 200,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: days.map((day) {
                final k = _dayKey(day);
                final count = weekTrend[k] ?? 0;
                final isToday = day.day == today.day &&
                    day.month == today.month &&
                    day.year == today.year;
                final barH = (maxVal == 0 ? 4.0 : (count / maxVal) * 150.0)
                    .clamp(4.0, 150.0);

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (count > 0) ...[
                          Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isToday ? AdminTheme.primary : AdminTheme.textMuted,
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
                                : AdminTheme.primary.withOpacity(0.25),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(6),
                              topRight: Radius.circular(6),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          dayNames[day.weekday - 1],
                          style: TextStyle(
                            fontSize: 11,
                            color: isToday
                                ? AdminTheme.textPrimary
                                : AdminTheme.textMuted,
                            fontWeight:
                                isToday ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AdminTheme.primary,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              const Text('Overall Attendance', style: TextStyle(fontSize: 11, color: AdminTheme.textMuted)),
              const SizedBox(width: 20),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AdminTheme.primary.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              const Text('Weekly Average', style: TextStyle(fontSize: 11, color: AdminTheme.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityFeed() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AdminTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Aktivitas Terbaru', style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AdminTheme.textPrimary,
                )),
              ),
              Text(
                'View All',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AdminTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (recentActivity.isEmpty)
            const AdminEmptyState(
              icon: Icons.inbox_rounded,
              title: 'Belum ada aktivitas',
            )
          else
            ...recentActivity.take(5).map((item) {
              final nama = item['nama'] ?? '-';
              final jenis = item['jenis'] ?? 'Hadir';
              final isMocked = item['is_mocked'] == true;
              final mkName = _getMKName(item['sesi_id']);
              String timeAgo = '';
              if (item['waktu'] != null) {
                try {
                  final dt = DateTime.parse(item['waktu']).toLocal();
                  final diff = DateTime.now().difference(dt);
                  if (diff.inMinutes < 1) {
                    timeAgo = 'Just now';
                  } else if (diff.inMinutes < 60) {
                    timeAgo = '${diff.inMinutes} mins ago';
                  } else if (diff.inHours < 24) {
                    timeAgo = '${diff.inHours} hrs ago';
                  } else {
                    timeAgo = DateFormat('dd MMM').format(dt);
                  }
                } catch (_) {}
              }
              final alamat = (item['alamat'] ?? item['lokasi'] ?? '').toString();
              final alamatShort = alamat.length > 20 ? '${alamat.substring(0, 20)}…' : alamat;

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        AdminTheme.avatarInitials(nama, radius: 20),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: isMocked
                                  ? AdminTheme.danger
                                  : jenis == 'Hadir'
                                      ? AdminTheme.success
                                      : AdminTheme.warning,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Icon(
                              isMocked
                                  ? Icons.close_rounded
                                  : Icons.check_rounded,
                              size: 8,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nama,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isMocked ? AdminTheme.danger : AdminTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isMocked ? 'Suspicious GPS coordinates detected' : 'Checked-in: $mkName',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: AdminTheme.textSecondary),
                          ),
                          Text(
                            '$timeAgo • $alamatShort',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: isMocked ? AdminTheme.danger.withOpacity(0.7) : AdminTheme.textMuted,
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
          const SizedBox(height: 8),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh_rounded, size: 12, color: AdminTheme.textMuted),
                const SizedBox(width: 4),
                const Text(
                  'Auto-refreshing every 30s',
                  style: TextStyle(fontSize: 10, color: AdminTheme.textMuted),
                ),
              ],
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
      padding: const EdgeInsets.all(24),
      children: [
        const AdminSkeletonBox(height: 60, borderRadius: 12),
        const SizedBox(height: 20),
        Row(
          children: List.generate(
              3,
              (i) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < 2 ? 14 : 0),
                  child: const AdminSkeletonBox(height: 130),
                ),
              )),
        ),
        const SizedBox(height: 20),
        const AdminSkeletonBox(height: 300, borderRadius: 12),
        const SizedBox(height: 20),
        const AdminSkeletonBox(height: 60, borderRadius: 12),
      ],
    );
  }

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmt(int n) => NumberFormat('#,###', 'id_ID').format(n);
}
