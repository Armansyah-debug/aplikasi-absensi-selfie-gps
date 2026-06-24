import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/admin_theme.dart';
import 'widgets/admin_widgets.dart';

/// ToolsAkademikScreen — Alat bantu manajemen akademik
/// Fitur: Naik Semester Massal
class ToolsAkademikScreen extends StatefulWidget {
  const ToolsAkademikScreen({super.key});

  @override
  State<ToolsAkademikScreen> createState() => _ToolsAkademikScreenState();
}

class _ToolsAkademikScreenState extends State<ToolsAkademikScreen> {
  final supabase = Supabase.instance.client;

  // Filter state
  String? _selectedJurusan;
  int? _semesterLama;
  int? _semesterBaru;

  bool _loading = false;
  bool _loadingPreview = false;
  int _jumlahTerdampak = 0;
  List<Map<String, dynamic>> _previewList = [];
  bool _previewDone = false;

  final List<String> _jurusanList = [
    'Informatika',
    'Sistem Informasi',
    'Manajemen',
    'Akuntansi',
  ];

  final List<int> _semesterList = List.generate(14, (i) => i + 1);

  // ─── Preview — hitung mahasiswa terdampak ───
  Future<void> _preview() async {
    if (_selectedJurusan == null || _semesterLama == null || _semesterBaru == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lengkapi semua pilihan terlebih dahulu')));
      return;
    }
    if (_semesterBaru! <= _semesterLama!) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Semester baru harus lebih besar dari semester lama')));
      return;
    }

    setState(() => _loadingPreview = true);

    try {
      var query = supabase.from('profiles').select('id, nama, npm, jurusan, semester');
      if (_selectedJurusan != 'Semua') {
        query = query.eq('jurusan', _selectedJurusan!);
      }
      query = query.eq('role', 'user');

      final result = await query.eq('semester', _semesterLama!);
      final list = List<Map<String, dynamic>>.from(result);

      if (mounted) {
        setState(() {
          _jumlahTerdampak = list.length;
          _previewList = list;
          _previewDone = true;
          _loadingPreview = false;
        });
      }
    } catch (e) {
      debugPrint('Preview error: $e');
      if (mounted) {
        setState(() => _loadingPreview = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal memuat preview: $e')));
      }
    }
  }

  // ─── Konfirmasi dan proses ───
  Future<void> _konfirmasiDanProses() async {
    if (_jumlahTerdampak == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak ada mahasiswa yang sesuai kriteria')));
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Warning icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AdminTheme.warningLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: AdminTheme.warning, size: 32),
              ),
              const SizedBox(height: 20),
              const Text('Konfirmasi Naik Semester Massal',
                  style: AdminTheme.h2, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                      fontSize: 13,
                      color: AdminTheme.textSecondary,
                      height: 1.6),
                  children: [
                    const TextSpan(text: 'Anda akan menaikkan semester '),
                    TextSpan(
                      text: '$_jumlahTerdampak mahasiswa',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AdminTheme.textPrimary),
                    ),
                    TextSpan(
                      text: _selectedJurusan == 'Semua'
                          ? '\ndari semua jurusan'
                          : '\ndari jurusan $_selectedJurusan',
                    ),
                    TextSpan(
                      text: '\ndari Semester $_semesterLama → Semester $_semesterBaru.',
                    ),
                    const TextSpan(
                        text: '\n\nTindakan ini ',
                        style: TextStyle(color: AdminTheme.textPrimary)),
                    const TextSpan(
                        text: 'tidak dapat dibatalkan.',
                        style: TextStyle(
                            color: AdminTheme.danger,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AdminTheme.border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Batal',
                          style:
                              TextStyle(color: AdminTheme.textSecondary)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminTheme.warning,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Ya, Naikkan Semester',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);

    try {
      // Update massal mahasiswa sesuai kriteria
      final ids = _previewList.map((e) => e['id']).toList();
      for (final id in ids) {
        await supabase
            .from('profiles')
            .update({'semester': _semesterBaru!}).eq('id', id);
      }

      if (mounted) {
        setState(() {
          _loading = false;
          _previewDone = false;
          _jumlahTerdampak = 0;
          _previewList = [];
        });

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '$_jumlahTerdampak mahasiswa berhasil dinaikkan ke Semester $_semesterBaru'),
          backgroundColor: AdminTheme.success,
        ));
      }
    } catch (e) {
      debugPrint('Naik semester error: $e');
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal memproses: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // ─── Header ───
        const AdminPageHeader(
          title: 'Tools Akademik',
          subtitle:
              'Alat bantu manajemen akademik untuk operasi massal data mahasiswa.',
        ),
        const SizedBox(height: 24),

        // ─── Naik Semester Massal Card ───
        Container(
          decoration: AdminTheme.cardDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AdminTheme.border)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AdminTheme.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.upgrade_rounded,
                          color: AdminTheme.primary, size: 22),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Naik Semester Massal', style: AdminTheme.h2),
                          SizedBox(height: 4),
                          Text(
                            'Naikkan semester seluruh mahasiswa berdasarkan jurusan dan semester sekarang secara serentak.',
                            style: AdminTheme.body,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AdminTheme.warningLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              size: 14, color: AdminTheme.warning),
                          SizedBox(width: 4),
                          Text('Operasi Massal',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AdminTheme.warning,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Step 1: Pilih Kriteria
                    _sectionTitle('1', 'Pilih Kriteria Mahasiswa'),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isMobile = constraints.maxWidth < 600;
                        
                        final jurusanDropdown = DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _selectedJurusan,
                          hint: const Text('Pilih Jurusan / Prodi', overflow: TextOverflow.ellipsis),
                          items: [
                            const DropdownMenuItem(
                                value: 'Semua', child: Text('Semua Jurusan', overflow: TextOverflow.ellipsis)),
                            ..._jurusanList.map((e) =>
                                DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))),
                          ],
                          onChanged: (v) => setState(() {
                            _selectedJurusan = v;
                            _previewDone = false;
                          }),
                          decoration: AdminTheme.inputDecoration(
                            label: 'Jurusan / Prodi',
                            prefixIcon: Icons.account_balance_outlined,
                          ),
                        );

                        final semesterLamaDropdown = DropdownButtonFormField<int>(
                          isExpanded: true,
                          value: _semesterLama,
                          hint: const Text('Semester Sekarang', overflow: TextOverflow.ellipsis),
                          items: _semesterList
                              .map((e) => DropdownMenuItem(
                                    value: e,
                                    child: Text('Semester $e (Sekarang)', overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() {
                            _semesterLama = v;
                            _previewDone = false;
                            if (_semesterBaru != null && _semesterBaru! <= (v ?? 0)) {
                              _semesterBaru = null;
                            }
                          }),
                          decoration: AdminTheme.inputDecoration(
                            label: 'Semester Lama',
                            prefixIcon: Icons.calendar_today_outlined,
                          ),
                        );

                        final semesterBaruDropdown = DropdownButtonFormField<int>(
                          isExpanded: true,
                          value: _semesterBaru,
                          hint: const Text('Semester Tujuan', overflow: TextOverflow.ellipsis),
                          items: _semesterList
                              .where((e) => e > (_semesterLama ?? 0))
                              .map((e) => DropdownMenuItem(
                                    value: e,
                                    child: Text('Semester $e (Baru)', overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() {
                            _semesterBaru = v;
                            _previewDone = false;
                          }),
                          decoration: AdminTheme.inputDecoration(
                            label: 'Semester Baru',
                            prefixIcon: Icons.upgrade_rounded,
                          ),
                        );

                        final cekBtn = ElevatedButton.icon(
                          onPressed: _loadingPreview ? null : _preview,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AdminTheme.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: _loadingPreview
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.search_rounded, size: 18),
                          label: const Text('Cek Mahasiswa',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        );

                        if (isMobile) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              jurusanDropdown,
                              const SizedBox(height: 16),
                              semesterLamaDropdown,
                              const SizedBox(height: 16),
                              semesterBaruDropdown,
                              const SizedBox(height: 16),
                              cekBtn,
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(child: jurusanDropdown),
                            const SizedBox(width: 16),
                            Expanded(child: semesterLamaDropdown),
                            const SizedBox(width: 16),
                            Expanded(child: semesterBaruDropdown),
                            const SizedBox(width: 16),
                            cekBtn,
                          ],
                        );
                      },
                    ),

                    // Step 2: Preview hasil
                    if (_previewDone) ...[
                      const SizedBox(height: 24),
                      _sectionTitle('2', 'Mahasiswa Terdampak'),
                      const SizedBox(height: 12),

                      // Summary alert
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _jumlahTerdampak > 0
                              ? AdminTheme.warningLight
                              : AdminTheme.bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _jumlahTerdampak > 0
                                ? AdminTheme.warning.withOpacity(0.3)
                                : AdminTheme.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _jumlahTerdampak > 0
                                  ? Icons.people_outline_rounded
                                  : Icons.check_circle_outline_rounded,
                              color: _jumlahTerdampak > 0
                                  ? AdminTheme.warning
                                  : AdminTheme.success,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AdminTheme.textPrimary),
                                  children: [
                                    TextSpan(
                                      text: _jumlahTerdampak > 0
                                          ? 'Ditemukan '
                                          : 'Tidak ada mahasiswa yang memenuhi kriteria',
                                    ),
                                    if (_jumlahTerdampak > 0) ...[
                                      TextSpan(
                                        text: '$_jumlahTerdampak mahasiswa',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AdminTheme.warning),
                                      ),
                                      TextSpan(
                                        text:
                                            ' dari ${_selectedJurusan == 'Semua' ? 'semua jurusan' : 'jurusan $_selectedJurusan'} '
                                            'di Semester $_semesterLama yang akan dinaikkan ke Semester $_semesterBaru.',
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Preview table
                      if (_previewList.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: AdminTheme.border),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              // Header
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                decoration: const BoxDecoration(
                                  color: AdminTheme.bg,
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(10),
                                    topRight: Radius.circular(10),
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    AdminTableHeader('NAMA MAHASISWA', flex: 3),
                                    AdminTableHeader('NIM', flex: 2),
                                    AdminTableHeader('JURUSAN', flex: 3),
                                    AdminTableHeader('SEMESTER', flex: 2),
                                  ],
                                ),
                              ),
                              // Rows (max 5 preview)
                              ..._previewList.take(5).toList().asMap().entries.map(
                                (entry) {
                                  final i = entry.key;
                                  final mhs = entry.value;
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    decoration: AdminTheme.tableRowDecoration(
                                        isEven: i.isEven),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: Row(
                                            children: [
                                              AdminTheme.avatarInitials(
                                                  mhs['nama'] ?? '',
                                                  radius: 14),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(mhs['nama'] ?? '-',
                                                    style: AdminTheme
                                                        .tableCellBold),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(mhs['npm'] ?? '-',
                                              style: AdminTheme.tableCell),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: Text(mhs['jurusan'] ?? '-',
                                              style: AdminTheme.tableCell),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Row(
                                            children: [
                                              Text('${mhs['semester']}',
                                                  style: AdminTheme.tableCell),
                                              const Icon(
                                                  Icons.arrow_right_rounded,
                                                  size: 16,
                                                  color: AdminTheme.success),
                                              Text('$_semesterBaru',
                                                  style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.bold,
                                                      color: AdminTheme.success)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              if (_previewList.length > 5)
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  child: Center(
                                    child: Text(
                                      '... dan ${_previewList.length - 5} mahasiswa lainnya',
                                      style: AdminTheme.caption,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],

                      // Step 3: Proses
                      const SizedBox(height: 24),
                      _sectionTitle('3', 'Proses Kenaikan Semester'),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: (_loading || _jumlahTerdampak == 0)
                              ? null
                              : _konfirmasiDanProses,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _jumlahTerdampak > 0
                                ? AdminTheme.warning
                                : AdminTheme.textMuted,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: _loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.upgrade_rounded, size: 22),
                          label: Text(
                            _loading
                                ? 'Memproses...'
                                : _jumlahTerdampak > 0
                                    ? 'Naikkan Semester $_jumlahTerdampak Mahasiswa'
                                    : 'Tidak Ada Mahasiswa Terdampak',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ─── Keterangan ───
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AdminTheme.bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AdminTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 16, color: AdminTheme.textMuted),
                  SizedBox(width: 8),
                  Text('Panduan Penggunaan',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AdminTheme.textPrimary)),
                ],
              ),
              const SizedBox(height: 12),
              ...[
                '1. Pilih jurusan/prodi, semester saat ini, dan semester tujuan.',
                '2. Klik "Cek Mahasiswa" untuk melihat daftar mahasiswa yang terdampak.',
                '3. Periksa preview daftar mahasiswa yang akan dinaikkan semesternya.',
                '4. Klik "Naikkan Semester" dan konfirmasi untuk memproses perubahan.',
                '5. Operasi ini akan mengubah field semester pada tabel profiles untuk seluruh mahasiswa yang sesuai kriteria.',
              ].map(
                (s) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(s,
                      style: const TextStyle(
                          fontSize: 12, color: AdminTheme.textSecondary, height: 1.5)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String step, String title) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: AdminTheme.primary,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Center(
            child: Text(step,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AdminTheme.textPrimary)),
      ],
    );
  }
}
