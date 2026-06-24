import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'theme/admin_theme.dart';
import 'widgets/admin_widgets.dart';

class DosenScreen extends StatefulWidget {
  const DosenScreen({super.key});

  @override
  State<DosenScreen> createState() => _DosenScreenState();
}

class _DosenScreenState extends State<DosenScreen> {
  List<Map<String, dynamic>> _allDosen = [];
  List<Map<String, dynamic>> _allMK = [];
  bool _loading = true;
  String _search = '';
  final _searchCtrl = TextEditingController();
  String? _filterJurusan;
  int _currentPage = 1;
  final int _perPage = 10;

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
    final dosen = await SupabaseService.getDosenList();
    final mk = await SupabaseService.getAllMK();
    if (mounted) {
      setState(() {
        _allDosen = dosen;
        _allMK = mk;
        _loading = false;
      });
    }
  }

  List<String> _getCourses(String dosenId) {
    return _allMK
        .where((m) => m['dosen_id']?.toString() == dosenId)
        .map((m) => m['nama_mk']?.toString() ?? '-')
        .toList();
  }

  String? _getJurusan(String dosenId) {
    final mk = _allMK.firstWhere(
      (m) => m['dosen_id']?.toString() == dosenId,
      orElse: () => <String, dynamic>{},
    );
    return mk['jurusan']?.toString();
  }

  List<String> _getJurusanList() {
    final set = <String>{};
    for (final m in _allMK) {
      final j = m['jurusan'];
      if (j != null && j.toString().isNotEmpty) set.add(j.toString());
    }
    return set.toList()..sort();
  }

  int get _activeTeaching {
    int count = 0;
    for (final d in _allDosen) {
      if (_getCourses(d['id'].toString()).isNotEmpty) count++;
    }
    return count;
  }

  List<Map<String, dynamic>> _getFiltered() {
    var list = _allDosen;
    if (_filterJurusan != null) {
      list = list.where((d) {
        final jur = _getJurusan(d['id'].toString());
        return jur == _filterJurusan;
      }).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((d) {
        final nama = (d['nama'] ?? '').toString().toLowerCase();
        return nama.contains(q);
      }).toList();
    }
    return list;
  }

  void _showForm({Map<String, dynamic>? dosen}) {
    final isEdit = dosen != null;
    final namaCtrl = TextEditingController(text: isEdit ? dosen['nama'] : '');
    final nidnCtrl = TextEditingController(text: isEdit ? dosen['npm'] : '');

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
                      child: const Icon(Icons.school_outlined, color: AdminTheme.primary, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Text(isEdit ? 'Edit Dosen' : 'Tambah Dosen', style: AdminTheme.h2),
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
                        Expanded(child: Text('Penambahan dosen baru belum tersedia dari panel admin. Dosen harus mendaftar via aplikasi.', style: TextStyle(color: AdminTheme.warningDark, fontSize: 12))),
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
                  controller: nidnCtrl,
                  enabled: isEdit,
                  decoration: AdminTheme.inputDecoration(label: 'NIDN', prefixIcon: Icons.badge_outlined),
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
                            if (namaCtrl.text.trim().isEmpty || nidnCtrl.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lengkapi semua field')));
                              return;
                            }
                            await SupabaseService.updateDosenAdmin(
                              userId: dosen['id'],
                              nama: namaCtrl.text.trim(),
                              nidn: nidnCtrl.text.trim(),
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            _fetchData();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil dosen berhasil diperbarui')));
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
    final activePercent = _allDosen.isEmpty ? 0.0 : (_activeTeaching / _allDosen.length * 100);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // ─── Header Card ───
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: AdminTheme.cardDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Data Master: Dosen', style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AdminTheme.textPrimary,
                    )),
                    const SizedBox(height: 6),
                    const Text(
                      'Comprehensive management of university academic staff and teaching schedules.',
                      style: AdminTheme.body,
                    ),
                    const SizedBox(height: 16),
                    AdminPrimaryButton(
                      label: 'New Lecturer',
                      icon: Icons.person_add_outlined,
                      onPressed: () => _showForm(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 2,
              child: AdminStatCard(
                icon: Icons.groups_outlined,
                iconColor: AdminTheme.primary,
                label: 'Total Lecturers',
                value: '${_allDosen.length}',
                subtitle: '+${_activeTeaching} mengajar',
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 2,
              child: AdminStatCard(
                icon: Icons.cast_for_education_outlined,
                iconColor: AdminTheme.success,
                label: 'Active Teaching',
                value: '${activePercent.toStringAsFixed(0)}%',
              ),
            ),
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
                    label: 'Cari nama dosen...',
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
              OutlinedButton.icon(
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() {
                    _filterJurusan = null;
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
                    AdminTableHeader('Name', flex: 3),
                    AdminTableHeader('NIDN', flex: 2),
                    AdminTableHeader('Department', flex: 2),
                    AdminTableHeader('Courses Taught', flex: 3),
                    AdminTableHeader('Status', flex: 1),
                    SizedBox(width: 80, child: Text('ACTIONS', style: AdminTheme.tableHeader, textAlign: TextAlign.center)),
                  ],
                ),
              ),
              if (pageData.isEmpty)
                const AdminEmptyState(
                  icon: Icons.school_outlined,
                  title: 'Tidak ada data dosen',
                  subtitle: 'Coba ubah filter atau pencarian.',
                )
              else
                ...pageData.asMap().entries.map((entry) {
                  final i = entry.key;
                  final d = entry.value;
                  final nama = d['nama'] ?? '-';
                  final dosenId = d['id'].toString();
                  final courses = _getCourses(dosenId);
                  final jurusan = _getJurusan(dosenId) ?? '-';
                  final isActive = courses.isNotEmpty;

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
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(d['npm']?.toString() ?? '-',
                            style: AdminTheme.tableCell),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(jurusan, style: AdminTheme.tableCell),
                        ),
                        Expanded(
                          flex: 3,
                          child: courses.isEmpty
                              ? const Text('-', style: AdminTheme.tableCell)
                              : Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: courses.take(2).map((c) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AdminTheme.primaryLight,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: AdminTheme.primary.withOpacity(0.2)),
                                    ),
                                    child: Text(c, style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AdminTheme.primary,
                                    )),
                                  )).toList(),
                                ),
                        ),
                        Expanded(
                          flex: 1,
                          child: AdminTheme.statusBadge(isActive ? 'Aktif' : 'On Leave'),
                        ),
                        SizedBox(
                          width: 80,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18, color: AdminTheme.primary),
                                tooltip: 'Edit',
                                onPressed: () => _showForm(dosen: d),
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