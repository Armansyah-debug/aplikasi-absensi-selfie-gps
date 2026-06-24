import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'theme/admin_theme.dart';
import 'widgets/admin_widgets.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RiwayatAdminScreen extends StatefulWidget {
  const RiwayatAdminScreen({super.key});

  @override
  State<RiwayatAdminScreen> createState() => _RiwayatAdminScreenState();
}

class _RiwayatAdminScreenState extends State<RiwayatAdminScreen> {
  List<Map<String, dynamic>> _allAbsensi = [];
  List<Map<String, dynamic>> _sesiList = [];
  List<Map<String, dynamic>> _mkList = [];
  bool _loading = true;
  String? _filterJenis;
  String? _filterMK;
  int _currentPage = 1;
  final int _perPage = 15;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      SupabaseService.getAllHistoryRaw(),
      SupabaseService.getSesiList(),
      SupabaseService.getAllMK(),
    ]);
    if (mounted) {
      setState(() {
        _allAbsensi = List<Map<String, dynamic>>.from(results[0] as List);
        _sesiList = List<Map<String, dynamic>>.from(results[1] as List);
        _mkList = List<Map<String, dynamic>>.from(results[2] as List);
        _loading = false;
      });
    }
  }

  String _getMKName(int? sesiId) {
    if (sesiId == null) return '-';
    final sesi = _sesiList.firstWhere((s) => s['id'] == sesiId, orElse: () => {});
    if (sesi.isEmpty) return '-';
    final mk = _mkList.firstWhere((m) => m['id'] == sesi['mata_kuliah_id'], orElse: () => {});
    return mk['nama_mk'] ?? '-';
  }

  List<String> _getJenisList() => ['Hadir', 'Izin', 'Sakit'];

  List<String> _getMKNames() {
    return _mkList.map((m) => m['nama_mk']?.toString() ?? '-').toSet().toList()..sort();
  }

  List<Map<String, dynamic>> _getFiltered() {
    var list = _allAbsensi;
    if (_filterJenis != null) {
      list = list.where((a) => a['jenis'] == _filterJenis).toList();
    }
    if (_filterMK != null) {
      list = list.where((a) {
        final mkName = _getMKName(a['sesi_id']);
        return mkName == _filterMK;
      }).toList();
    }
    return list;
  }

  int get _totalHadir => _allAbsensi.where((a) => a['jenis'] == 'Hadir').length;
  int get _totalIzin => _allAbsensi.where((a) => a['jenis'] == 'Izin').length;
  int get _totalSakit => _allAbsensi.where((a) => a['jenis'] == 'Sakit').length;

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

    final filtered = _getFiltered();
    final totalPages = (filtered.length / _perPage).ceil().clamp(1, 9999);
    final startIdx = (_currentPage - 1) * _perPage;
    final pageData = filtered.skip(startIdx).take(_perPage).toList();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // ─── Header ───
        const AdminPageHeader(
          title: 'Riwayat Absensi',
          subtitle: 'Riwayat lengkap seluruh absensi mahasiswa di universitas.',
        ),
        const SizedBox(height: 24),

        // ─── Stat Cards ───
        Row(
          children: [
            Expanded(child: AdminStatCard(
              icon: Icons.history_rounded,
              iconColor: AdminTheme.primary,
              label: 'Total Records',
              value: '${_allAbsensi.length}',
            )),
            const SizedBox(width: 14),
            Expanded(child: AdminStatCard(
              icon: Icons.check_circle_outline_rounded,
              iconColor: AdminTheme.success,
              label: 'Hadir',
              value: '$_totalHadir',
            )),
            const SizedBox(width: 14),
            Expanded(child: AdminStatCard(
              icon: Icons.event_note_outlined,
              iconColor: AdminTheme.info,
              label: 'Izin',
              value: '$_totalIzin',
            )),
            const SizedBox(width: 14),
            Expanded(child: AdminStatCard(
              icon: Icons.local_hospital_outlined,
              iconColor: AdminTheme.warning,
              label: 'Sakit',
              value: '$_totalSakit',
            )),
          ],
        ),
        const SizedBox(height: 20),

        // ─── Filter Bar ───
        AdminFilterBar(
          filters: [
            AdminDropdownFilter(
              hint: 'Semua Status',
              value: _filterJenis,
              items: _getJenisList(),
              onChanged: (v) => setState(() {
                _filterJenis = v;
                _currentPage = 1;
              }),
            ),
            AdminDropdownFilter(
              hint: 'Semua MK',
              value: _filterMK,
              items: _getMKNames(),
              onChanged: (v) => setState(() {
                _filterMK = v;
                _currentPage = 1;
              }),
            ),
            // Mock Date Range Filter Layout
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AdminTheme.bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AdminTheme.border),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_month_outlined, size: 12, color: AdminTheme.textSecondary),
                  SizedBox(width: 6),
                  Text('Rentang Tanggal (Semua)', style: TextStyle(fontSize: 12, color: AdminTheme.textSecondary)),
                ],
              ),
            ),
          ],
          onReset: () => setState(() {
            _filterJenis = null;
            _filterMK = null;
            _currentPage = 1;
          }),
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
                    AdminTableHeader('Mahasiswa & ID', flex: 3),
                    AdminTableHeader('Mata Kuliah', flex: 2),
                    AdminTableHeader('Waktu', flex: 2),
                    AdminTableHeader('Lokasi', flex: 3),
                    AdminTableHeader('Integritas Lokasi', flex: 2),
                    AdminTableHeader('Status', flex: 1),
                    SizedBox(width: 80, child: Text('', style: AdminTheme.tableHeader)),
                  ],
                ),
              ),

              if (pageData.isEmpty)
                const AdminEmptyState(
                  icon: Icons.history_toggle_off_rounded,
                  title: 'Tidak ada data riwayat',
                  subtitle: 'Coba ubah filter atau pencarian.',
                )
              else
                ...pageData.asMap().entries.map((entry) {
                  final i = entry.key;
                  final a = entry.value;
                  final nama = a['nama'] ?? '-';
                  final npm = a['npm'] ?? '-';
                  final jenis = a['jenis'] ?? 'Hadir';
                  final isMocked = a['is_mocked'] == true;
                  final mkName = _getMKName(a['sesi_id']);
                  final alamat = (a['alamat'] ?? a['lokasi'] ?? '-').toString();
                  final alamatShort = alamat.length > 20 ? '${alamat.substring(0, 20)}…' : alamat;

                  String waktu = '-';
                  if (a['waktu'] != null) {
                    try {
                      final dt = DateTime.parse(a['waktu']).toLocal();
                      waktu = DateFormat('dd/MM/yy HH:mm').format(dt);
                    } catch (_) {}
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: AdminTheme.tableRowDecoration(isEven: i.isEven),
                    child: Row(
                      children: [
                        // Mahasiswa & ID Layout
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
                                    Text(nama, maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: AdminTheme.tableCellBold),
                                    Text(npm, style: const TextStyle(fontSize: 10, color: AdminTheme.textMuted)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(flex: 2, child: Text(mkName, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: AdminTheme.tableCell)),
                        Expanded(flex: 2, child: Text(waktu, style: AdminTheme.tableCell)),
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              const Icon(
                                Icons.location_on_rounded,
                                size: 12,
                                color: AdminTheme.textMuted,
                              ),
                              const SizedBox(width: 4),
                              Expanded(child: Text(alamatShort, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, color: AdminTheme.textSecondary))),
                            ],
                          ),
                        ),
                        // Location Integrity Column Layout
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isMocked ? AdminTheme.dangerLight : AdminTheme.successLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isMocked ? Icons.gpp_bad_rounded : Icons.verified_user_rounded,
                                    size: 11,
                                    color: isMocked ? AdminTheme.danger : AdminTheme.successDark,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isMocked ? 'Fake GPS' : 'Verified GPS',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isMocked ? AdminTheme.danger : AdminTheme.successDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: AdminTheme.statusBadge(jenis),
                        ),
                        SizedBox(
                          width: 80,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.visibility_outlined, size: 16, color: AdminTheme.primary),
                                tooltip: 'Lihat Detail',
                                onPressed: () => _showDetail(a),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red.shade400),
                                onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Hapus Data?'),
                                  content: const Text('Data absensi ini akan dihapus secara permanen.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Batal'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('Hapus', style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await SupabaseService.deleteAbsen(a['id'], fotoPath: a['foto_path']);
                                _fetchData();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                      ],
                    ),
                  );
                }),

              // Metrik penunjang bottom row inside the card
              Builder(
                builder: (context) {
                  final fakeCount = _allAbsensi.where((e) => e['is_mocked'] == true).length;
                  final double integrityPct = _totalHadir == 0 ? 100.0 : ((_totalHadir - fakeCount) / _totalHadir * 100);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: const BoxDecoration(
                      color: AdminTheme.borderLight,
                      border: Border(
                        top: BorderSide(color: AdminTheme.border, width: 0.5),
                        bottom: BorderSide(color: AdminTheme.border, width: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 14, color: AdminTheme.textSecondary),
                        const SizedBox(width: 8),
                        Text(
                          'Ringkasan Kehadiran: Hadir ($_totalHadir) | Izin/Sakit (${_totalIzin + _totalSakit}) | Integritas Lokasi: ${integrityPct.toStringAsFixed(1)}% GPS Valid',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AdminTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }
              ),

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
