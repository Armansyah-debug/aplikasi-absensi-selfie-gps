import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'theme/admin_theme.dart';
import 'widgets/admin_widgets.dart';

class MahasiswaRisikoScreen extends StatefulWidget {
  const MahasiswaRisikoScreen({super.key});

  @override
  State<MahasiswaRisikoScreen> createState() => _MahasiswaRisikoScreenState();
}

class _MahasiswaRisikoScreenState extends State<MahasiswaRisikoScreen> {
  List<Map<String, dynamic>> _allMahasiswa = [];
  List<Map<String, dynamic>> _allAbsensi = [];
  bool _loading = true;
  String? _filterJurusan;
  int _currentPage = 1;
  final int _perPage = 10;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    final mhs = await SupabaseService.getMahasiswaList();
    final absensi = await SupabaseService.getAllHistoryRaw();
    if (mounted) {
      setState(() {
        _allMahasiswa = mhs;
        _allAbsensi = absensi;
        _loading = false;
      });
    }
  }

  double _getAttendance(String? npm) {
    if (npm == null || npm.isEmpty) return 0;
    final records = _allAbsensi.where((a) => a['npm'] == npm && a['jenis'] != 'Pelanggaran').toList();
    if (records.isEmpty) return 0;
    
    final hadir = records.where((a) => a['jenis'] == 'Hadir').length;
    return (hadir / records.length) * 100;
  }

  int _getAbsensiCount(String? npm) {
    if (npm == null) return 0;
    return _allAbsensi.where((a) => a['npm'] == npm).length;
  }

  String _getRiskLevel(double attendance) {
    if (attendance < 50) return 'Tinggi';
    if (attendance < 75) return 'Sedang';
    return 'Rendah';
  }

  Color _getRiskColor(String level) {
    switch (level) {
      case 'Tinggi': return AdminTheme.danger;
      case 'Sedang': return AdminTheme.warning;
      default: return AdminTheme.info;
    }
  }

  List<Map<String, dynamic>> _getRiskyStudents() {
    return _allMahasiswa.where((m) {
      final npm = m['npm']?.toString();
      final count = _getAbsensiCount(npm);
      if (count == 0) return false;
      final attendance = _getAttendance(npm);
      return attendance < 75;
    }).toList();
  }

  List<String> _getJurusanList() {
    final set = <String>{};
    for (final m in _allMahasiswa) {
      final j = m['jurusan'];
      if (j != null && j.toString().isNotEmpty) set.add(j.toString());
    }
    return set.toList()..sort();
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

    final riskyStudents = _getRiskyStudents();
    var filtered = riskyStudents;
    if (_filterJurusan != null) {
      filtered = filtered.where((m) => m['jurusan'] == _filterJurusan).toList();
    }
    // Sort by attendance ascending (most at-risk first)
    filtered.sort((a, b) {
      final aVal = _getAttendance(a['npm']?.toString());
      final bVal = _getAttendance(b['npm']?.toString());
      return aVal.compareTo(bVal);
    });

    final totalPages = (filtered.length / _perPage).ceil().clamp(1, 9999);
    final startIdx = (_currentPage - 1) * _perPage;
    final pageData = filtered.skip(startIdx).take(_perPage).toList();

    final tinggiCount = riskyStudents.where((m) => _getRiskLevel(_getAttendance(m['npm']?.toString())) == 'Tinggi').length;
    final sedangCount = riskyStudents.where((m) => _getRiskLevel(_getAttendance(m['npm']?.toString())) == 'Sedang').length;

    final healthScore = _allMahasiswa.isEmpty
        ? 100.0
        : ((_allMahasiswa.length - riskyStudents.length) / _allMahasiswa.length * 100);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // ─── Header ───
        const AdminPageHeader(
          title: 'Analitik Mahasiswa Risiko',
          subtitle: 'Identifikasi dan monitoring mahasiswa dengan tingkat kehadiran rendah.',
        ),
        const SizedBox(height: 24),

        // ─── Stat Cards ───
        Row(
          children: [
            Expanded(child: AdminStatCard(
              icon: Icons.warning_amber_rounded,
              iconColor: AdminTheme.danger,
              label: 'Total Berisiko',
              value: '${riskyStudents.length}',
              subtitle: 'Dari ${_allMahasiswa.length} mahasiswa',
              valueColor: AdminTheme.danger,
            )),
            const SizedBox(width: 14),
            Expanded(child: AdminStatCard(
              icon: Icons.error_outline_rounded,
              iconColor: AdminTheme.danger,
              label: 'Risiko Tinggi',
              value: '$tinggiCount',
              subtitle: '< 50% kehadiran',
              valueColor: AdminTheme.danger,
            )),
            const SizedBox(width: 14),
            Expanded(child: AdminStatCard(
              icon: Icons.notification_important_outlined,
              iconColor: AdminTheme.warning,
              label: 'Risiko Sedang',
              value: '$sedangCount',
              subtitle: '50-74% kehadiran',
              valueColor: AdminTheme.warning,
            )),
            const SizedBox(width: 14),
            Expanded(child: AdminStatCard(
              icon: Icons.monitor_heart_outlined,
              iconColor: AdminTheme.success,
              label: 'Health Score',
              value: '${healthScore.toStringAsFixed(0)}%',
            )),
          ],
        ),
        const SizedBox(height: 20),

        // ─── Filter ───
        AdminFilterBar(
          filters: [
            AdminDropdownFilter(
              hint: 'Semua Jurusan',
              value: _filterJurusan,
              items: _getJurusanList(),
              onChanged: (v) => setState(() {
                _filterJurusan = v;
                _currentPage = 1;
              }),
            ),
          ],
          onReset: () => setState(() {
            _filterJurusan = null;
            _currentPage = 1;
          }),
        ),
        const SizedBox(height: 16),

        // ─── Main content ───
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Table
            Expanded(
              flex: 6,
              child: Container(
                decoration: AdminTheme.cardDecoration,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: const BoxDecoration(
                        color: AdminTheme.bg,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: const Row(
                        children: [
                          AdminTableHeader('Mahasiswa', flex: 3),
                          AdminTableHeader('Prodi / Angkatan', flex: 2),
                          AdminTableHeader('Tingkat Kehadiran', flex: 3),
                          AdminTableHeader('Status Risiko', flex: 2),
                          AdminTableHeader('Trend', flex: 1),
                          SizedBox(width: 80, child: Text('AKSI', style: AdminTheme.tableHeader)),
                        ],
                      ),
                    ),
                    if (pageData.isEmpty)
                      const AdminEmptyState(
                        icon: Icons.check_circle_outline_rounded,
                        title: 'Tidak ada mahasiswa berisiko',
                        subtitle: 'Semua mahasiswa memiliki kehadiran di atas 75%.',
                      )
                    else
                      ...pageData.asMap().entries.map((entry) {
                        final i = entry.key;
                        final m = entry.value;
                        final nama = m['nama'] ?? '-';
                        final npm = m['npm']?.toString() ?? '-';
                        final jurusan = m['jurusan'] ?? '-';
                        final semester = m['semester'];
                        final attendance = _getAttendance(npm);
                        final riskLevel = _getRiskLevel(attendance);
                        final riskColor = _getRiskColor(riskLevel);

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          decoration: AdminTheme.tableRowDecoration(isEven: i.isEven),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Row(
                                  children: [
                                    AdminTheme.avatarInitials(nama, radius: 18),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(nama, maxLines: 1, overflow: TextOverflow.ellipsis,
                                            style: AdminTheme.tableCellBold),
                                          Text(npm, style: const TextStyle(fontSize: 10, color: AdminTheme.textMuted)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(jurusan, style: AdminTheme.tableCell),
                                    if (semester != null)
                                      Text('Semester $semester', style: const TextStyle(fontSize: 10, color: AdminTheme.textMuted)),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 45,
                                      child: Text(
                                        '${attendance.toStringAsFixed(0)}%',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: riskColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(child: AdminProgressBar(value: attendance / 100)),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: AdminTheme.statusBadge(riskLevel),
                              ),
                              Expanded(
                                flex: 1,
                                child: Icon(
                                  attendance < 50 ? Icons.trending_down_rounded : Icons.trending_flat_rounded,
                                  color: riskColor,
                                  size: 18,
                                ),
                              ),
                              SizedBox(
                                width: 80,
                                child: TextButton.icon(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Peringatan terkirim ke $nama')),
                                    );
                                  },
                                  icon: const Icon(Icons.send_rounded, size: 12),
                                  label: const Text('Kirim', style: TextStyle(fontSize: 10)),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AdminTheme.primary,
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                    AdminPagination(
                      currentPage: _currentPage,
                      totalPages: totalPages,
                      totalItems: filtered.length,
                      itemsPerPage: _perPage,
                      onPageChanged: (p) => setState(() => _currentPage = p),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 16),

            // ─── Right Panel ───
            SizedBox(
              width: 260,
              child: Column(
                children: [
                  // Risk Factors
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: AdminTheme.cardDecoration,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Faktor Risiko Teratas', style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AdminTheme.textPrimary,
                        )),
                        const SizedBox(height: 16),
                        _riskFactor('Kehadiran Rendah', tinggiCount, AdminTheme.danger),
                        const SizedBox(height: 10),
                        _riskFactor('Izin Berulang', sedangCount, AdminTheme.warning),
                        const SizedBox(height: 10),
                        _riskFactor('Sering Telat', 0, AdminTheme.info),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Quick Recommendations
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: AdminTheme.cardDecoration,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Rekomendasi Cepat', style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AdminTheme.textPrimary,
                        )),
                        const SizedBox(height: 12),
                        _recCard(Icons.email_outlined, 'Kirim Notifikasi',
                          'Kirim peringatan massal ke $tinggiCount mahasiswa risiko tinggi.'),
                        const SizedBox(height: 10),
                        _recCard(Icons.people_outline, 'Jadwalkan Konseling',
                          'Atur jadwal konseling akademik untuk mahasiswa berisiko.'),
                        const SizedBox(height: 10),
                        _recCard(Icons.analytics_outlined, 'Export Report',
                          'Unduh laporan risiko untuk bagian akademik.'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _riskFactor(String label, int count, Color color) {
    return Row(
      children: [
        Container(width: 4, height: 20, decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AdminTheme.textPrimary))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        ),
      ],
    );
  }

  Widget _recCard(IconData icon, String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AdminTheme.bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: AdminTheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AdminTheme.textPrimary)),
                  const SizedBox(height: 2),
                  Text(desc, style: const TextStyle(fontSize: 10, color: AdminTheme.textMuted, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      );
  }
}