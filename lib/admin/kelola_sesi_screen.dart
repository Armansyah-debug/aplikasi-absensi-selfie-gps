import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import 'theme/admin_theme.dart';
import 'widgets/admin_widgets.dart';

class KelolaSesiScreen extends StatefulWidget {
  const KelolaSesiScreen({super.key});

  @override
  State<KelolaSesiScreen> createState() => _KelolaSesiScreenState();
}

class _KelolaSesiScreenState extends State<KelolaSesiScreen>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  // Tab controller: Semua / Aktif / Riwayat
  late TabController _tabCtrl;

  // MK dropdown for new session form
  List<dynamic> listMK = [];
  String? selectedMK;
  final _materiCtrl = TextEditingController();
  int? _selectedPertemuanKe;
  bool loadingMK = false;
  bool loadingSubmit = false;

  // Sessions data
  List<Map<String, dynamic>> _allSesi = [];
  bool _loadingSesi = true;

  // Pagination
  static const _perPage = 10;
  int _currentPage = 1;

  // Stats
  int get _activeSesi =>
      _allSesi.where((e) => e['is_open'] == true).length;
  int get _closedSesi =>
      _allSesi.where((e) => e['is_open'] != true).length;
  int get _totalSesi => _allSesi.length;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() => setState(() => _currentPage = 1));
    _fetchMK();
    _fetchSesi();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _materiCtrl.dispose();
    super.dispose();
  }

  // ─── Fetch MK ───
  Future<void> _fetchMK() async {
    setState(() => loadingMK = true);
    final user = supabase.auth.currentUser;
    if (user != null) {
      final role = await SupabaseService.getUserRole(user.id);
      List<Map<String, dynamic>> data;
      if (role == 'dosen') {
        data = await SupabaseService.getMataKuliah(dosenId: user.id);
      } else {
        data = await SupabaseService.getMataKuliah();
      }
      if (mounted) setState(() { listMK = data; loadingMK = false; });
    } else {
      if (mounted) setState(() => loadingMK = false);
    }
  }

  // ─── Fetch Sesi ───
  Future<void> _fetchSesi() async {
    setState(() => _loadingSesi = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) { setState(() => _loadingSesi = false); return; }

      final role = await SupabaseService.getUserRole(user.id);
      var query = supabase.from('sesi_absensi').select('*, mata_kuliah(*)');

      if (role == 'dosen') {
        final mkData = await SupabaseService.getMataKuliah(dosenId: user.id);
        final mkIds = mkData.map((e) => e['id']).toList();
        if (mkIds.isNotEmpty) {
          query = query.filter('mata_kuliah_id', 'in', mkIds);
        } else {
          setState(() { _allSesi = []; _loadingSesi = false; });
          return;
        }
      }

      final data = await query.order('tanggal', ascending: false);
      if (mounted) {
        setState(() {
          _allSesi = List<Map<String, dynamic>>.from(data);
          _loadingSesi = false;
        });
      }
    } catch (e) {
      debugPrint('Fetch sesi error: $e');
      if (mounted) setState(() => _loadingSesi = false);
    }
  }

  // ─── Buka Sesi Baru ───
  Future<void> _handleBukaSesiBaru() async {
    if (selectedMK == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pilih Mata Kuliah terlebih dahulu')));
      return;
    }
    setState(() => loadingSubmit = true);
    try {
      final mk = listMK.firstWhere((e) => e['id'].toString() == selectedMK);
      final jurusan = mk['jurusan'];
      final semester = mk['semester'];

      final existingSesi = await supabase
          .from('sesi_absensi')
          .select('id, mata_kuliah!inner(jurusan, semester)')
          .eq('is_open', true)
          .eq('mata_kuliah.jurusan', jurusan)
          .eq('mata_kuliah.semester', semester)
          .maybeSingle();

      if (existingSesi != null) {
        throw 'Masih ada sesi aktif untuk $jurusan Semester $semester. Tutup sesi tersebut terlebih dahulu.';
      }

      await SupabaseService.createSesiAbsensi(
        mkId: selectedMK!,
        pertemuan_ke: _selectedPertemuanKe,
        materi: _materiCtrl.text.isNotEmpty ? _materiCtrl.text : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sesi absensi berhasil dibuka')));
        setState(() {
          selectedMK = null;
          _selectedPertemuanKe = null;
          _materiCtrl.clear();
        });
        _fetchSesi();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal buka sesi: $e')));
      }
    } finally {
      if (mounted) setState(() => loadingSubmit = false);
    }
  }

  // ─── Tutup Sesi ───
  Future<void> _tutupSesi(int id) async {
    await supabase.from('sesi_absensi').update({'is_open': false}).eq('id', id);
    _fetchSesi();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sesi berhasil ditutup')));
    }
  }

  // ─── Hapus Sesi ───
  Future<void> _hapusSesi(Map<String, dynamic> sesi) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Sesi?', style: AdminTheme.h2),
        content: const Text(
          'Data absensi mahasiswa dalam sesi ini akan tetap ada. Yakin ingin menghapus sesi ini?',
          style: AdminTheme.body,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
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
      await supabase.from('sesi_absensi').delete().eq('id', sesi['id']);
      _fetchSesi();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sesi berhasil dihapus')));
      }
    }
  }

  // ─── Detail Sesi ───
  void _showDetail(Map<String, dynamic> sesi) {
    final mk = sesi['mata_kuliah'] as Map? ?? {};
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 440,
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
                      color: sesi['is_open'] == true
                          ? AdminTheme.successLight
                          : AdminTheme.bg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      sesi['is_open'] == true
                          ? Icons.radio_button_checked_rounded
                          : Icons.event_available_rounded,
                      color: sesi['is_open'] == true
                          ? AdminTheme.success
                          : AdminTheme.textMuted,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                      child: Text('Detail Sesi', style: AdminTheme.h2)),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _detailRow('Mata Kuliah', mk['nama_mk'] ?? '-'),
              _detailRow('Jurusan', mk['jurusan'] ?? '-'),
              _detailRow('Semester', 'Semester ${mk['semester'] ?? '-'}'),
              _detailRow(
                  'Pertemuan', 'Ke-${sesi['pertemuan_ke'] ?? '-'}'),
              _detailRow('Materi', sesi['materi'] ?? '-'),
              _detailRow('Tanggal', _formatTanggal(sesi['tanggal'])),
              _detailRow('Radius', '${sesi['radius_meter'] ?? 50} meter'),
              _detailRow(
                'Status',
                sesi['is_open'] == true ? 'AKTIF' : 'SELESAI',
              ),
              const SizedBox(height: 20),
              if (sesi['is_open'] == true) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _tutupSesi(sesi['id']);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminTheme.danger,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Akhiri Sesi',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      side: const BorderSide(color: AdminTheme.border),
                    ),
                    child: const Text('Kembali',
                        style: TextStyle(
                            color: AdminTheme.textSecondary,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ] else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      side: const BorderSide(color: AdminTheme.border),
                    ),
                    child: const Text('Tutup Dialog',
                        style: TextStyle(
                            color: AdminTheme.textSecondary,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    color: AdminTheme.textMuted,
                    fontWeight: FontWeight.w600)),
          ),
          const Text(': ',
              style: TextStyle(color: AdminTheme.textMuted)),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    color: AdminTheme.textPrimary,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  String _formatTanggal(String? d) {
    if (d == null || d.isEmpty) return '-';
    try {
      final dt = DateTime.parse(d);
      const m = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'];
      return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
    } catch (_) { return d; }
  }

  // ─── GET FILTERED LIST ───
  List<Map<String, dynamic>> get _filteredSesi {
    switch (_tabCtrl.index) {
      case 1: return _allSesi.where((e) => e['is_open'] == true).toList();
      case 2: return _allSesi.where((e) => e['is_open'] != true).toList();
      default: return _allSesi;
    }
  }

  List<Map<String, dynamic>> get _paginatedSesi {
    final list = _filteredSesi;
    final start = (_currentPage - 1) * _perPage;
    final end = (start + _perPage).clamp(0, list.length);
    if (start >= list.length) return [];
    return list.sublist(start, end);
  }

  int get _totalPages =>
      (_filteredSesi.length / _perPage).ceil().clamp(1, 9999);

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    Widget content = ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // ─── Header ───
        Row(
          children: [
            const Expanded(
              child: AdminPageHeader(
                title: 'Kelola Sesi Absensi',
                subtitle:
                    'Buka, tutup, dan pantau sesi absensi di seluruh mata kuliah.',
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _scrollToForm(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Buat Sesi Baru',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ─── Stat Cards ───
        if (!_loadingSesi)
          Row(
            children: [
              Expanded(
                child: AdminStatCard(
                  icon: Icons.radio_button_checked_rounded,
                  iconColor: AdminTheme.success,
                  label: 'Sesi Aktif',
                  value: '$_activeSesi',
                  trailing: _activeSesi > 0 ? AdminTheme.liveDot() : null,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: AdminStatCard(
                  icon: Icons.calendar_today_outlined,
                  iconColor: AdminTheme.primary,
                  label: 'Total Sesi',
                  value: '$_totalSesi',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: AdminStatCard(
                  icon: Icons.event_available_rounded,
                  iconColor: AdminTheme.textMuted,
                  label: 'Sesi Selesai',
                  value: '$_closedSesi',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: AdminStatCard(
                  icon: Icons.menu_book_outlined,
                  iconColor: AdminTheme.info,
                  label: 'Mata Kuliah',
                  value: '${listMK.length}',
                ),
              ),
            ],
          ),
        const SizedBox(height: 20),

        // ─── Buat Sesi Form ───
        Container(
          padding: const EdgeInsets.all(24),
          decoration: AdminTheme.cardDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.add_circle_outline_rounded,
                      size: 20, color: AdminTheme.primary),
                  SizedBox(width: 8),
                  Text('Buka Sesi Absensi Baru',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AdminTheme.textPrimary)),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: DropdownButtonFormField<String>(
                      value: selectedMK,
                      hint: const Text('Pilih Mata Kuliah'),
                      isExpanded: true,
                      items: listMK.map((e) => DropdownMenuItem<String>(
                            value: e['id'].toString(),
                            child: Text(e['nama_mk'] ?? '-'),
                          )).toList(),
                      onChanged: (v) => setState(() => selectedMK = v),
                      decoration: AdminTheme.inputDecoration(
                          label: 'Mata Kuliah',
                          prefixIcon: Icons.menu_book_outlined),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<int>(
                      value: _selectedPertemuanKe,
                      hint: const Text('Ke-'),
                      items: List.generate(15, (i) => i + 1)
                          .map((e) => DropdownMenuItem<int>(
                                value: e, child: Text('Pertemuan $e')))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedPertemuanKe = v),
                      decoration: AdminTheme.inputDecoration(
                          label: 'Pertemuan',
                          prefixIcon: Icons.format_list_numbered_rounded),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 4,
                    child: TextFormField(
                      controller: _materiCtrl,
                      decoration: AdminTheme.inputDecoration(
                          label: 'Materi Perkuliahan',
                          prefixIcon: Icons.subject_rounded),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: loadingSubmit ? null : _handleBukaSesiBaru,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminTheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: loadingSubmit
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.play_arrow_rounded, size: 20),
                  label: Text(
                    loadingSubmit ? 'Memproses...' : 'Buka Sesi Absensi',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ─── Sessions Table with Tabs ───
        Container(
          decoration: AdminTheme.cardDecoration,
          child: Column(
            children: [
              // Tabs header
              Container(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AdminTheme.border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TabBar(
                        controller: _tabCtrl,
                        labelColor: AdminTheme.primary,
                        unselectedLabelColor: AdminTheme.textMuted,
                        indicatorColor: AdminTheme.primary,
                        indicatorWeight: 2,
                        labelStyle: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                        tabs: [
                          Tab(text: 'Semua Sesi (${_allSesi.length})'),
                          Tab(text: 'Aktif ($_activeSesi)'),
                          Tab(text: 'Riwayat ($_closedSesi)'),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 14, color: AdminTheme.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            'Sesi diperbarui secara otomatis',
                            style: const TextStyle(
                                fontSize: 11, color: AdminTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              if (_loadingSesi)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_filteredSesi.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.event_busy_rounded,
                            size: 48, color: AdminTheme.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          _tabCtrl.index == 1
                              ? 'Tidak ada sesi aktif'
                              : 'Tidak ada data sesi',
                          style: AdminTheme.body,
                        ),
                      ],
                    ),
                  ),
                )
              else
                Column(
                  children: [
                    // Table header row
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      color: AdminTheme.bg,
                      child: const Row(
                        children: [
                          AdminTableHeader('KODE SESI', flex: 2),
                          AdminTableHeader('MATA KULIAH', flex: 4),
                          AdminTableHeader('PERTEMUAN', flex: 2),
                          AdminTableHeader('TANGGAL', flex: 2),
                          AdminTableHeader('STATUS', flex: 2),
                          SizedBox(width: 120),
                        ],
                      ),
                    ),
                    // Rows
                    ..._paginatedSesi.asMap().entries.map((entry) {
                      final i = entry.key;
                      final sesi = entry.value;
                      final mk = sesi['mata_kuliah'] as Map? ?? {};
                      final isActive = sesi['is_open'] == true;

                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        decoration:
                            AdminTheme.tableRowDecoration(isEven: i.isEven),
                        child: Row(
                          children: [
                            // ID/Kode
                            Expanded(
                              flex: 2,
                              child: Text(
                                '#${sesi['id'] ?? '-'}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isActive
                                      ? AdminTheme.primary
                                      : AdminTheme.textMuted,
                                ),
                              ),
                            ),
                            // MK
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(mk['nama_mk'] ?? '-',
                                      style: AdminTheme.tableCellBold),
                                  Text(
                                    '${mk['jurusan'] ?? ''} • ${mk['semester'] != null ? 'Sem ${mk['semester']}' : ''}',
                                    style: AdminTheme.caption,
                                  ),
                                ],
                              ),
                            ),
                            // Pertemuan
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Ke-${sesi['pertemuan_ke'] ?? '-'}',
                                style: AdminTheme.tableCell,
                              ),
                            ),
                            // Tanggal
                            Expanded(
                              flex: 2,
                              child: Text(
                                _formatTanggal(sesi['tanggal']),
                                style: AdminTheme.tableCell,
                              ),
                            ),
                            // Status
                            Expanded(
                              flex: 2,
                              child: Row(
                                children: [
                                  if (isActive) ...[
                                    AdminTheme.liveDot(),
                                    const SizedBox(width: 6),
                                  ],
                                  AdminTheme.statusBadge(
                                      isActive ? 'Aktif' : 'Selesai'),
                                ],
                              ),
                            ),
                            // Actions
                            SizedBox(
                              width: 120,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // Detail button
                                  OutlinedButton(
                                    onPressed: () => _showDetail(sesi),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      side: const BorderSide(
                                          color: AdminTheme.border),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(6)),
                                    ),
                                    child: const Text('Detail',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: AdminTheme.textSecondary)),
                                  ),
                                  const SizedBox(width: 6),
                                  // Tutup or hapus
                                  if (isActive)
                                    IconButton(
                                      icon: const Icon(Icons.stop_rounded,
                                          size: 18, color: AdminTheme.danger),
                                      tooltip: 'Tutup Sesi',
                                      onPressed: () => _tutupSesi(sesi['id']),
                                    )
                                  else
                                    IconButton(
                                      icon: Icon(Icons.delete_outline_rounded,
                                          size: 18, color: AdminTheme.danger),
                                      tooltip: 'Hapus Sesi',
                                      onPressed: () => _hapusSesi(sesi),
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
                      totalItems: _filteredSesi.length,
                      itemLabel: 'sesi',
                      onPageChanged: (p) => setState(() => _currentPage = p),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );

    if (canPop) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: const Text(
            'Kelola Sesi',
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
        body: content,
      );
    } else {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: content,
      );
    }
  }

  void _scrollToForm() {
    // Scroll to top to show the form
    PrimaryScrollController.of(context).animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }
}