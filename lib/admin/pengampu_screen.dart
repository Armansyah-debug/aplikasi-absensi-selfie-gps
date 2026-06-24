import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'theme/admin_theme.dart';
import 'widgets/admin_widgets.dart';

/// PengampuScreen — Manajemen penugasan dosen ke mata kuliah.
/// Menggunakan tabel mata_kuliah.dosen_id (existing schema).
class PengampuScreen extends StatefulWidget {
  const PengampuScreen({super.key});

  @override
  State<PengampuScreen> createState() => _PengampuScreenState();
}

class _PengampuScreenState extends State<PengampuScreen> {
  List<Map<String, dynamic>> _listMK = [];
  List<Map<String, dynamic>> _listMKFiltered = [];
  List<Map<String, dynamic>> _listDosen = [];
  bool _loading = true;

  final _searchCtrl = TextEditingController();
  String? _filterJurusan;

  // Pagination
  static const _perPage = 10;
  int _currentPage = 1;

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

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      SupabaseService.getAllMK(),
      SupabaseService.getDosenList(),
    ]);
    if (mounted) {
      setState(() {
        _listMK = List<Map<String, dynamic>>.from(results[0] as List);
        _listDosen = List<Map<String, dynamic>>.from(results[1] as List);
        _loading = false;
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
        final matchSearch = q.isEmpty ||
            nama.contains(q) ||
            _getDosenName(mk['dosen_id']).toLowerCase().contains(q);
        final matchJurusan = _filterJurusan == null ||
            _filterJurusan == 'Semua' ||
            jur == _filterJurusan;
        return matchSearch && matchJurusan;
      }).toList();
      _currentPage = 1;
    });
  }

  String _getDosenName(dynamic dosenId) {
    if (dosenId == null) return 'Belum ada dosen';
    final d = _listDosen.firstWhere(
      (e) => e['id'].toString() == dosenId.toString(),
      orElse: () => {},
    );
    return d['nama'] ?? 'Belum ada dosen';
  }

  List<Map<String, dynamic>> get _paginated {
    final start = (_currentPage - 1) * _perPage;
    final end = (start + _perPage).clamp(0, _listMKFiltered.length);
    if (start >= _listMKFiltered.length) return [];
    return _listMKFiltered.sublist(start, end);
  }

  int get _totalPages => (_listMKFiltered.length / _perPage).ceil().clamp(1, 9999);

  /// Tampilkan dialog penugasan/ganti dosen
  void _showAssignDialog(Map<String, dynamic> mk) {
    String? selDosen = mk['dosen_id']?.toString();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 460,
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
                      child: const Icon(Icons.person_search_outlined,
                          color: AdminTheme.primary, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Tugaskan Dosen', style: AdminTheme.h2),
                          Text(
                            mk['nama_mk'] ?? '-',
                            style: AdminTheme.body,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Info MK
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AdminTheme.bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AdminTheme.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 16, color: AdminTheme.textMuted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${mk['jurusan'] ?? '-'} • Semester ${mk['semester'] ?? '-'}',
                          style: AdminTheme.body,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Dropdown Dosen
                DropdownButtonFormField<String?>(
                  value: selDosen,
                  hint: const Text('Pilih Dosen Pengampu'),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('-- Tidak ada dosen --')),
                    ..._listDosen.map((d) => DropdownMenuItem<String?>(
                          value: d['id'].toString(),
                          child: Row(
                            children: [
                              AdminTheme.avatarInitials(d['nama'] ?? '?',
                                  radius: 12),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(d['nama'] ?? '-',
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        )),
                  ],
                  onChanged: (v) => setDlg(() => selDosen = v),
                  decoration: AdminTheme.inputDecoration(
                    label: 'Dosen Pengampu',
                    prefixIcon: Icons.school_outlined,
                  ),
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
                          await SupabaseService.updateMK(
                            id: mk['id'],
                            namaMk: mk['nama_mk'],
                            jurusan: mk['jurusan'],
                            semester: mk['semester'],
                            dosenId: selDosen,
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          _fetchData();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(selDosen != null
                                    ? 'Dosen berhasil ditugaskan'
                                    : 'Penugasan dosen dihapus'),
                              ),
                            );
                          }
                        },
                        child: const Text('Simpan',
                            style: TextStyle(fontWeight: FontWeight.bold)),
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

  /// Hapus penugasan dosen (set dosen_id = null)
  Future<void> _hapusPenugasan(Map<String, dynamic> mk) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Penugasan?', style: AdminTheme.h2),
        content: Text(
          'Yakin ingin menghapus penugasan dosen dari "${mk['nama_mk']}"?',
          style: AdminTheme.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.danger, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await SupabaseService.updateMK(
        id: mk['id'],
        namaMk: mk['nama_mk'],
        jurusan: mk['jurusan'],
        semester: mk['semester'],
        dosenId: null,
      );
      _fetchData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Penugasan dosen dihapus')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Summary stats
    final totalMK = _listMK.length;
    final sudahPunya = _listMK.where((e) => e['dosen_id'] != null).length;
    final belumPunya = totalMK - sudahPunya;
    final totalDosen = _listDosen.length;

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
                    Text('Pengampu Mata Kuliah', style: AdminTheme.h1),
                    SizedBox(height: 4),
                    Text(
                      'Kelola penugasan dosen pengampu untuk setiap mata kuliah.',
                      style: AdminTheme.body,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ─── Stat Cards ───
          if (!_loading)
            Row(
              children: [
                Expanded(
                  child: AdminStatCard(
                    icon: Icons.school_outlined,
                    iconColor: AdminTheme.primary,
                    label: 'Total Dosen',
                    value: '$totalDosen',
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: AdminStatCard(
                    icon: Icons.menu_book_outlined,
                    iconColor: AdminTheme.info,
                    label: 'Total Mata Kuliah',
                    value: '$totalMK',
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: AdminStatCard(
                    icon: Icons.assignment_turned_in_outlined,
                    iconColor: AdminTheme.success,
                    label: 'Sudah Ditugaskan',
                    value: '$sudahPunya',
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: AdminStatCard(
                    icon: Icons.assignment_late_outlined,
                    iconColor: AdminTheme.danger,
                    label: 'Belum Ada Dosen',
                    value: '$belumPunya',
                    valueColor: belumPunya > 0 ? AdminTheme.danger : null,
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
                    onChanged: (_) => _applyFilter(),
                    decoration: AdminTheme.inputDecoration(
                      label: 'Cari mata kuliah atau dosen...',
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
                      const DropdownMenuItem(
                          value: 'Semua', child: Text('Semua Jurusan')),
                      ..._jurusanOptions.map(
                          (e) => DropdownMenuItem(value: e, child: Text(e))),
                    ],
                    onChanged: (v) {
                      setState(() => _filterJurusan = v);
                      _applyFilter();
                    },
                    decoration: AdminTheme.inputDecoration(label: 'Jurusan'),
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
            child: _loading
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
                              const Icon(Icons.person_search_outlined,
                                  size: 48, color: AdminTheme.textMuted),
                              const SizedBox(height: 12),
                              Text(
                                _searchCtrl.text.isNotEmpty
                                    ? 'Tidak ada hasil pencarian'
                                    : 'Belum ada data',
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
                                    child: AdminTableHeader('NAMA DOSEN')),
                                const Expanded(
                                    flex: 4,
                                    child: AdminTableHeader('MATA KULIAH')),
                                const Expanded(
                                    flex: 2,
                                    child: AdminTableHeader('JURUSAN')),
                                const Expanded(
                                    flex: 2,
                                    child: AdminTableHeader('SEMESTER')),
                                SizedBox(
                                  width: 90,
                                  child: Text('AKSI',
                                      style: AdminTheme.tableHeader,
                                      textAlign: TextAlign.center),
                                ),
                              ],
                            ),
                          ),
                          // Table rows
                          ..._paginated.asMap().entries.map((entry) {
                            final i = entry.key;
                            final mk = entry.value;
                            final dosenName = _getDosenName(mk['dosen_id']);
                            final hasDosen = mk['dosen_id'] != null;

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 14),
                              decoration:
                                  AdminTheme.tableRowDecoration(isEven: i.isEven),
                              child: Row(
                                children: [
                                  // Dosen
                                  Expanded(
                                    flex: 4,
                                    child: Row(
                                      children: [
                                        AdminTheme.avatarInitials(
                                            hasDosen ? dosenName : '?',
                                            radius: 16),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                dosenName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: hasDosen
                                                      ? AdminTheme.textPrimary
                                                      : AdminTheme.textMuted,
                                                ),
                                              ),
                                              if (!hasDosen)
                                                const Text(
                                                  'Belum ditugaskan',
                                                  style: TextStyle(
                                                      fontSize: 10,
                                                      color: AdminTheme.danger),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // MK
                                  Expanded(
                                    flex: 4,
                                    child: Text(mk['nama_mk'] ?? '-',
                                        style: AdminTheme.tableCellBold),
                                  ),
                                  // Jurusan
                                  Expanded(
                                    flex: 2,
                                    child: Text(mk['jurusan'] ?? '-',
                                        style: AdminTheme.tableCell),
                                  ),
                                  // Semester
                                  Expanded(
                                    flex: 2,
                                    child: Text('Sem ${mk['semester'] ?? '-'}',
                                        style: AdminTheme.tableCell),
                                  ),
                                  // Aksi
                                  SizedBox(
                                    width: 90,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                              Icons.edit_outlined,
                                              size: 18,
                                              color: AdminTheme.primary),
                                          tooltip: 'Tugaskan/Ganti Dosen',
                                          onPressed: () =>
                                              _showAssignDialog(mk),
                                        ),
                                        if (hasDosen)
                                          IconButton(
                                            icon: Icon(
                                                Icons.link_off_rounded,
                                                size: 18,
                                                color: AdminTheme.danger),
                                            tooltip: 'Hapus Penugasan',
                                            onPressed: () =>
                                                _hapusPenugasan(mk),
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
                            totalPages: _totalPages,
                            totalItems: _listMKFiltered.length,
                            itemLabel: 'penugasan',
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