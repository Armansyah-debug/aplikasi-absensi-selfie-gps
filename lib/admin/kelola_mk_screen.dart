import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../constants/app_constants.dart';
import 'theme/admin_theme.dart';
import 'widgets/admin_widgets.dart';

class KelolaMKScreen extends StatefulWidget {
  const KelolaMKScreen({super.key});

  @override
  State<KelolaMKScreen> createState() => _KelolaMKScreenState();
}

class _KelolaMKScreenState extends State<KelolaMKScreen> {
  List<Map<String, dynamic>> _listMK = [];
  List<Map<String, dynamic>> _listMKFiltered = [];
  List<Map<String, dynamic>> _listDosen = [];
  bool _isLoading = true;

  // Filter & Search state
  final _searchCtrl = TextEditingController();
  String? _filterJurusan;

  // Pagination
  static const _perPage = 10;
  int _currentPage = 1;

  final List<String> _jurusanList = AppConstants.jurusanList;

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
    setState(() => _isLoading = true);
    final mk = await SupabaseService.getAllMK();
    final dosen = await SupabaseService.getDosenList();
    if (mounted) {
      setState(() {
        _listMK = mk;
        _listDosen = dosen;
        _isLoading = false;
      });
      _applyFilter();
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _listMKFiltered = _listMK.where((mk) {
        final nama = (mk['nama_mk'] ?? '').toLowerCase();
        final jur = (mk['jurusan'] ?? '').toString();
        final matchSearch = q.isEmpty || nama.contains(q);
        final matchJurusan =
            _filterJurusan == null || _filterJurusan == 'Semua' || jur == _filterJurusan;
        return matchSearch && matchJurusan;
      }).toList();
      _currentPage = 1;
    });
  }

  List<Map<String, dynamic>> get _paginated {
    final start = (_currentPage - 1) * _perPage;
    final end = (start + _perPage).clamp(0, _listMKFiltered.length);
    if (start >= _listMKFiltered.length) return [];
    return _listMKFiltered.sublist(start, end);
  }

  int get _totalPages => (_listMKFiltered.length / _perPage).ceil().clamp(1, 9999);

  String _getDosenName(dynamic dosenId) {
    if (dosenId == null) return 'Belum ada dosen';
    final d = _listDosen.firstWhere(
      (e) => e['id'].toString() == dosenId.toString(),
      orElse: () => {},
    );
    return d['nama'] ?? 'Belum ada dosen';
  }

  void _showForm({Map<String, dynamic>? mk}) {
    final isEdit = mk != null;
    final namaCtrl = TextEditingController(text: isEdit ? mk['nama_mk'] : '');
    String? selJurusan = isEdit ? mk['jurusan'] : null;
    int? selSemester = isEdit ? mk['semester'] : null;
    String? selDosen = isEdit ? mk['dosen_id']?.toString() : null;

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
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AdminTheme.primaryLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.menu_book_outlined,
                          color: AdminTheme.primary, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isEdit ? 'Edit Mata Kuliah' : 'Tambah Mata Kuliah',
                      style: AdminTheme.h2,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                TextField(
                  controller: namaCtrl,
                  decoration: AdminTheme.inputDecoration(
                    label: 'Nama Mata Kuliah',
                    prefixIcon: Icons.menu_book_outlined,
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: selJurusan,
                  hint: const Text('Pilih Jurusan'),
                  items: _jurusanList
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setDlg(() => selJurusan = v),
                  decoration: AdminTheme.inputDecoration(label: 'Jurusan'),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  value: selSemester,
                  hint: const Text('Pilih Semester'),
                  items: _semesterList
                      .map((e) => DropdownMenuItem(value: e, child: Text('Semester $e')))
                      .toList(),
                  onChanged: (v) => setDlg(() => selSemester = v),
                  decoration: AdminTheme.inputDecoration(label: 'Semester'),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String?>(
                  value: selDosen,
                  hint: const Text('Pilih Dosen Pengampu'),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('-- Belum ada dosen --')),
                    ..._listDosen.map((e) => DropdownMenuItem<String?>(
                          value: e['id'].toString(),
                          child: Text(e['nama'] ?? '-'),
                        )),
                  ],
                  onChanged: (v) => setDlg(() => selDosen = v),
                  decoration: AdminTheme.inputDecoration(label: 'Dosen Pengampu'),
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
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Batal',
                            style: TextStyle(color: AdminTheme.textSecondary)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AdminTheme.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          if (namaCtrl.text.trim().isEmpty ||
                              selJurusan == null ||
                              selSemester == null) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                content: Text(
                                    'Lengkapi field wajib: Nama, Jurusan, dan Semester')));
                            return;
                          }
                          if (isEdit) {
                            await SupabaseService.updateMK(
                              id: mk['id'],
                              namaMk: namaCtrl.text.trim(),
                              jurusan: selJurusan!,
                              semester: selSemester!,
                              dosenId: selDosen,
                            );
                          } else {
                            await SupabaseService.insertMK(
                              namaMk: namaCtrl.text.trim(),
                              jurusan: selJurusan!,
                              semester: selSemester!,
                              dosenId: selDosen,
                            );
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                          _fetchData();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(isEdit
                                    ? 'Mata kuliah berhasil diperbarui'
                                    : 'Mata kuliah berhasil ditambahkan')));
                          }
                        },
                        child: Text(
                          isEdit ? 'Simpan Perubahan' : 'Tambah Mata Kuliah',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmHapus(Map<String, dynamic> mk) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Mata Kuliah?', style: AdminTheme.h2),
        content: Text(
          'Yakin ingin menghapus "${mk['nama_mk']}"?\nSeluruh sesi absensi yang terkait juga akan dihapus.',
          style: AdminTheme.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.danger,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await SupabaseService.deleteMK(mk['id']);
      _fetchData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mata kuliah berhasil dihapus')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                child: AdminPageHeader(
                  title: 'Kelola Mata Kuliah',
                  subtitle: 'Tambah, edit, dan hapus data mata kuliah program studi.',
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showForm(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Tambah MK',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ─── Stat Cards ───
          if (!_isLoading)
            Row(
              children: [
                Expanded(
                  child: AdminStatCard(
                    icon: Icons.menu_book_outlined,
                    iconColor: AdminTheme.primary,
                    label: 'Total Mata Kuliah',
                    value: '${_listMK.length}',
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: AdminStatCard(
                    icon: Icons.account_balance_outlined,
                    iconColor: AdminTheme.success,
                    label: 'Total Jurusan',
                    value: '${_listMK.map((e) => e['jurusan']).toSet().length}',
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: AdminStatCard(
                    icon: Icons.person_outline_rounded,
                    iconColor: AdminTheme.warning,
                    label: 'Telah Punya Dosen',
                    value: '${_listMK.where((e) => e['dosen_id'] != null).length}',
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: AdminStatCard(
                    icon: Icons.pending_actions_outlined,
                    iconColor: AdminTheme.danger,
                    label: 'Belum Ada Dosen',
                    value: '${_listMK.where((e) => e['dosen_id'] == null).length}',
                    valueColor: AdminTheme.danger,
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
                // Search
                Expanded(
                  flex: 4,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => _applyFilter(),
                    decoration: AdminTheme.inputDecoration(
                      label: 'Cari mata kuliah...',
                      prefixIcon: Icons.search_rounded,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Filter Jurusan
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    value: _filterJurusan,
                    hint: const Text('Semua Jurusan'),
                    items: [
                      const DropdownMenuItem(value: 'Semua', child: Text('Semua Jurusan')),
                      ..._jurusanList.map((e) => DropdownMenuItem(value: e, child: Text(e))),
                    ],
                    onChanged: (v) {
                      setState(() => _filterJurusan = v);
                      _applyFilter();
                    },
                    decoration: AdminTheme.inputDecoration(label: 'Filter Jurusan'),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _filterJurusan = null);
                    _applyFilter();
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

          // ─── Table ───
          Container(
            decoration: AdminTheme.cardDecoration,
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _listMKFiltered.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.menu_book_outlined,
                                  size: 48, color: AdminTheme.textMuted),
                              const SizedBox(height: 12),
                              Text(
                                _searchCtrl.text.isNotEmpty || _filterJurusan != null
                                    ? 'Tidak ada hasil untuk filter ini'
                                    : 'Belum ada data mata kuliah',
                                style: AdminTheme.body,
                              ),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          // Table header
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            decoration: const BoxDecoration(
                              color: AdminTheme.bg,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Expanded(
                                    flex: 4,
                                    child: AdminTableHeader('NAMA MATA KULIAH')),
                                const Expanded(
                                    flex: 3,
                                    child: AdminTableHeader('JURUSAN')),
                                const Expanded(
                                    flex: 2,
                                    child: AdminTableHeader('SEMESTER')),
                                const Expanded(
                                    flex: 3,
                                    child: AdminTableHeader('DOSEN PENGAMPU')),
                                SizedBox(
                                  width: 80,
                                  child: Text(
                                    'AKSI',
                                    style: AdminTheme.tableHeader,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Table rows
                          ..._paginated.asMap().entries.map((entry) {
                            final i = entry.key;
                            final mk = entry.value;
                            final dosenName =
                                _getDosenName(mk['dosen_id']);
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 14),
                              decoration:
                                  AdminTheme.tableRowDecoration(isEven: i.isEven),
                              child: Row(
                                children: [
                                  // Nama MK
                                  Expanded(
                                    flex: 4,
                                    child: Text(mk['nama_mk'] ?? '-',
                                        style: AdminTheme.tableCellBold),
                                  ),
                                  // Jurusan badge
                                  Expanded(
                                    flex: 3,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AdminTheme.infoLight,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        mk['jurusan'] ?? '-',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AdminTheme.primaryDark,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Semester
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Semester ${mk['semester'] ?? '-'}',
                                      style: AdminTheme.tableCell,
                                    ),
                                  ),
                                  // Dosen
                                  Expanded(
                                    flex: 3,
                                    child: Row(
                                      children: [
                                        if (mk['dosen_id'] != null) ...[
                                          AdminTheme.avatarInitials(
                                              dosenName, radius: 14),
                                          const SizedBox(width: 8),
                                        ],
                                        Expanded(
                                          child: Text(
                                            dosenName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: mk['dosen_id'] != null
                                                  ? AdminTheme.textPrimary
                                                  : AdminTheme.textMuted,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Actions
                                  SizedBox(
                                    width: 80,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined,
                                              size: 18,
                                              color: AdminTheme.primary),
                                          tooltip: 'Edit',
                                          onPressed: () => _showForm(mk: mk),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.delete_outline_rounded,
                                              size: 18,
                                              color: AdminTheme.danger),
                                          tooltip: 'Hapus',
                                          onPressed: () => _confirmHapus(mk),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),

                          // ─── Pagination ───
                          AdminPagination(
                            currentPage: _currentPage,
                            totalPages: _totalPages,
                            totalItems: _listMKFiltered.length,
                            itemLabel: 'mata kuliah',
                            onPageChanged: (p) => setState(() => _currentPage = p),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}
