import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'theme/admin_theme.dart';
import 'widgets/admin_widgets.dart';

class MahasiswaScreen extends StatefulWidget {
  const MahasiswaScreen({super.key});

  @override
  State<MahasiswaScreen> createState() => _MahasiswaScreenState();
}

class _MahasiswaScreenState extends State<MahasiswaScreen> {
  List<Map<String, dynamic>> _allMahasiswa = [];
  List<Map<String, dynamic>> _allAbsensi = [];
  bool _loading = true;
  String _search = '';
  final _searchCtrl = TextEditingController();
  String? _filterJurusan;
  int? _filterSemester;
  int _currentPage = 1;
  final int _perPage = 10;
  final List<int> _semesterList = List.generate(14, (i) => i + 1);

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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

  // Compute attendance percentage for a student
  double _getAttendance(String? npm) {
    if (npm == null || npm.isEmpty) return 0;
    final records = _allAbsensi.where((a) => a['npm'] == npm).toList();
    if (records.isEmpty) return 0;
    final hadir = records.where((a) => a['jenis'] == 'Hadir').length;
    return (hadir / records.length) * 100;
  }

  int _getAbsensiCount(String? npm) {
    if (npm == null) return 0;
    return _allAbsensi.where((a) => a['npm'] == npm).length;
  }

  String _getStatus(double attendance) {
    if (attendance == 0) return 'BARU';
    if (attendance >= 75) return 'AKTIF';
    if (attendance >= 50) return 'BERISIKO';
    return 'CUTI';
  }

  List<String> _getJurusanList() {
    final set = <String>{};
    for (final m in _allMahasiswa) {
      final j = m['jurusan'];
      if (j != null && j.toString().isNotEmpty) set.add(j.toString());
    }
    return set.toList()..sort();
  }

  List<int> _getSemesterList() {
    final set = <int>{};
    for (final m in _allMahasiswa) {
      final s = m['semester'];
      if (s != null && s is int) set.add(s);
    }
    return set.toList()..sort();
  }

  List<Map<String, dynamic>> _getFiltered() {
    var list = _allMahasiswa;
    if (_filterJurusan != null) {
      list = list.where((m) => m['jurusan'] == _filterJurusan).toList();
    }
    if (_filterSemester != null) {
      list = list.where((m) => m['semester'] == _filterSemester).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((m) {
        final nama = (m['nama'] ?? '').toString().toLowerCase();
        final npm = (m['npm'] ?? '').toString().toLowerCase();
        return nama.contains(q) || npm.contains(q);
      }).toList();
    }
    return list;
  }

  void _showForm({Map<String, dynamic>? mhs}) {
    final isEdit = mhs != null;
    final namaCtrl = TextEditingController(text: isEdit ? mhs['nama'] : '');
    final npmCtrl = TextEditingController(text: isEdit ? mhs['npm'] : '');
    String? selJurusan = isEdit ? mhs['jurusan'] : null;
    int? selSemester = isEdit ? mhs['semester'] : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                      child: const Icon(Icons.person_outline, color: AdminTheme.primary, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Text(isEdit ? 'Edit Mahasiswa' : 'Tambah Mahasiswa', style: AdminTheme.h2),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (!isEdit)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AdminTheme.warningLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AdminTheme.warning),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: AdminTheme.warningDark, size: 20),
                        SizedBox(width: 8),
                        Expanded(child: Text('Penambahan mahasiswa baru belum tersedia dari panel admin. Mahasiswa harus mendaftar via aplikasi.', style: TextStyle(color: AdminTheme.warningDark, fontSize: 12))),
                      ],
                    ),
                  ),
                TextField(
                  controller: namaCtrl,
                  enabled: isEdit,
                  decoration: AdminTheme.inputDecoration(label: 'Nama Lengkap', prefixIcon: Icons.person_outline),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: npmCtrl,
                  enabled: isEdit,
                  decoration: AdminTheme.inputDecoration(label: 'NIM', prefixIcon: Icons.badge_outlined),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: selJurusan,
                  hint: const Text('Pilih Jurusan'),
                  items: [
                    'Informatika',
                    'Sistem Informasi',
                    'Manajemen',
                    'Akuntansi',
                  ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: isEdit ? (v) => setDlg(() => selJurusan = v) : null,
                  decoration: AdminTheme.inputDecoration(label: 'Jurusan'),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  value: selSemester,
                  hint: const Text('Pilih Semester'),
                  items: _semesterList.map((e) => DropdownMenuItem(value: e, child: Text('Semester $e'))).toList(),
                  onChanged: isEdit ? (v) => setDlg(() => selSemester = v) : null,
                  decoration: AdminTheme.inputDecoration(label: 'Semester'),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: AdminTheme.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Batal', style: TextStyle(color: AdminTheme.textSecondary)),
                      ),
                    ),
                    if (isEdit) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AdminTheme.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () async {
                            if (namaCtrl.text.trim().isEmpty || npmCtrl.text.trim().isEmpty || selJurusan == null || selSemester == null) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lengkapi semua field')));
                              return;
                            }
                            await SupabaseService.updateMahasiswaAdmin(
                              userId: mhs['id'],
                              nama: namaCtrl.text.trim(),
                              npm: npmCtrl.text.trim(),
                              jurusan: selJurusan!,
                              semester: selSemester!,
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            _fetchData();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil mahasiswa berhasil diperbarui')));
                            }
                          },
                          child: const Text('Simpan Perubahan', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Stats
  int get _totalActive {
    int count = 0;
    for (final m in _allMahasiswa) {
      if (_getAttendance(m['npm']) >= 75) count++;
    }
    return count;
  }

  double get _avgAttendance {
    if (_allMahasiswa.isEmpty) return 0;
    double sum = 0;
    for (final m in _allMahasiswa) {
      sum += _getAttendance(m['npm']);
    }
    return sum / _allMahasiswa.length;
  }

  int get _risikoCount {
    int count = 0;
    for (final m in _allMahasiswa) {
      if (_getAttendance(m['npm']) < 75 && _getAbsensiCount(m['npm']) > 0) count++;
    }
    return count;
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

    final filtered = _getFiltered();
    final totalPages = (filtered.length / _perPage).ceil().clamp(1, 9999);
    final startIdx = (_currentPage - 1) * _perPage;
    final pageData = filtered.skip(startIdx).take(_perPage).toList();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // ─── Header ───
        AdminPageHeader(
          title: 'Manajemen Mahasiswa',
          subtitle: 'Kelola data akademik dan status kehadiran seluruh mahasiswa universitas.',
          action: AdminPrimaryButton(
            label: 'Tambah Mahasiswa',
            icon: Icons.person_add_outlined,
            onPressed: () => _showForm(),
          ),
        ),
        const SizedBox(height: 24),

        // ─── Stat Cards ───
        Row(
          children: [
            Expanded(child: AdminStatCard(
              icon: Icons.people_outline_rounded,
              iconColor: AdminTheme.primary,
              label: 'Total Mahasiswa',
              value: '${_allMahasiswa.length}',
            )),
            const SizedBox(width: 14),
            Expanded(child: AdminStatCard(
              icon: Icons.check_circle_outline_rounded,
              iconColor: AdminTheme.success,
              label: 'Aktif Semester Ini',
              value: '$_totalActive',
              subtitle: '${_allMahasiswa.isEmpty ? 0 : (_totalActive / _allMahasiswa.length * 100).toStringAsFixed(1)}%',
            )),
            const SizedBox(width: 14),
            Expanded(child: AdminStatCard(
              icon: Icons.bar_chart_rounded,
              iconColor: AdminTheme.primary,
              label: 'Rata-Rata Kehadiran',
              value: '${_avgAttendance.toStringAsFixed(1)}%',
            )),
            const SizedBox(width: 14),
            Expanded(child: AdminStatCard(
              icon: Icons.warning_amber_rounded,
              iconColor: AdminTheme.danger,
              label: 'Mahasiswa Berisiko',
              value: '$_risikoCount',
              subtitle: 'Bawah 75%',
              valueColor: AdminTheme.danger,
            )),
          ],
        ),
        const SizedBox(height: 20),

        // ─── Search & Filter ───
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AdminTheme.cardDecoration,
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() {
                    _search = v;
                    _currentPage = 1;
                  }),
                  decoration: AdminTheme.inputDecoration(
                    label: 'Cari nama atau NIM...',
                    prefixIcon: Icons.search_rounded,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  value: _filterJurusan,
                  hint: const Text('Semua Jurusan'),
                  items: [
                    const DropdownMenuItem(value: 'Semua', child: Text('Semua Jurusan')),
                    ..._getJurusanList().map((e) => DropdownMenuItem(value: e, child: Text(e))),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _filterJurusan = v == 'Semua' ? null : v;
                      _currentPage = 1;
                    });
                  },
                  decoration: AdminTheme.inputDecoration(label: 'Filter Jurusan'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<int>(
                  value: _filterSemester,
                  hint: const Text('Semua Semester'),
                  items: [
                    const DropdownMenuItem<int>(value: -1, child: Text('Semua Sem')),
                    ..._getSemesterList().map((e) => DropdownMenuItem<int>(value: e, child: Text('Semester $e'))),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _filterSemester = v == -1 ? null : v;
                      _currentPage = 1;
                    });
                  },
                  decoration: AdminTheme.inputDecoration(label: 'Filter Semester'),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() {
                    _filterJurusan = null;
                    _filterSemester = null;
                    _search = '';
                    _currentPage = 1;
                  });
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  side: const BorderSide(color: AdminTheme.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.clear_rounded, size: 16),
                label: const Text('Reset'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ─── Data Table ───
        Container(
          decoration: AdminTheme.cardDecoration,
          child: Column(
            children: [
              // Table Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: AdminTheme.bg,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: const Row(
                  children: [
                    SizedBox(width: 40), // checkbox space
                    AdminTableHeader('Nama Mahasiswa', flex: 3),
                    AdminTableHeader('NIM', flex: 2),
                    AdminTableHeader('Jurusan', flex: 2),
                    AdminTableHeader('Total Kehadiran', flex: 2),
                    AdminTableHeader('Status', flex: 1),
                    SizedBox(width: 80, child: Text('AKSI', style: AdminTheme.tableHeader, textAlign: TextAlign.center)),
                  ],
                ),
              ),

              // Table Rows
              if (pageData.isEmpty)
                const AdminEmptyState(
                  icon: Icons.people_outline_rounded,
                  title: 'Tidak ada data mahasiswa',
                  subtitle: 'Coba ubah filter atau pencarian.',
                )
              else
                ...pageData.asMap().entries.map((entry) {
                  final i = entry.key;
                  final m = entry.value;
                  final nama = m['nama'] ?? '-';
                  final npm = m['npm'] ?? '-';
                  final jurusan = m['jurusan'] ?? '-';
                  final semester = m['semester'];
                  final attendance = _getAttendance(npm);
                  final status = _getStatus(attendance);

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: AdminTheme.tableRowDecoration(isEven: i.isEven),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 40,
                          child: Checkbox(
                            value: false,
                            onChanged: (_) {},
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
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
                                    if (semester != null)
                                      Text('Angkatan ${semester > 2 ? 2020 + (semester ~/ 2) : 2024}',
                                        style: const TextStyle(fontSize: 10, color: AdminTheme.textMuted)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(npm, style: AdminTheme.tableCell),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(jurusan, style: AdminTheme.tableCell),
                        ),
                        Expanded(
                          flex: 2,
                          child: Row(
                            children: [
                              Text('${attendance.toStringAsFixed(0)}%',
                                style: AdminTheme.tableCellBold),
                              const SizedBox(width: 8),
                              AdminProgressBar(value: attendance / 100, width: 60),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: AdminTheme.statusBadge(status),
                        ),
                        SizedBox(
                          width: 80,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18, color: AdminTheme.primary),
                                tooltip: 'Edit',
                                onPressed: () => _showForm(mhs: m),
                                constraints: const BoxConstraints(minWidth: 32),
                                padding: EdgeInsets.zero,
                              ),

                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),

              // Pagination
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
      ],
    );
  }
}