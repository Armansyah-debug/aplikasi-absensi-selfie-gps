import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import 'theme/admin_theme.dart';
import 'widgets/admin_widgets.dart';
import 'package:intl/intl.dart';

class PelanggaranScreen extends StatefulWidget {
  const PelanggaranScreen({super.key});

  @override
  State<PelanggaranScreen> createState() => _PelanggaranScreenState();
}

class _PelanggaranScreenState extends State<PelanggaranScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _allAbsensi = [];
  List<Map<String, dynamic>> _sesiList = [];
  List<Map<String, dynamic>> _mkList = [];
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

  List<Map<String, dynamic>> get _violations {
    return _allAbsensi.where((a) => a['is_mocked'] == true).toList();
  }

  int get _todayViolations {
    final now = DateTime.now().toLocal();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return _violations.where((v) {
      if (v['waktu'] == null) return false;
      try {
        final dt = DateTime.parse(v['waktu']).toLocal();
        return dt.isAfter(startOfDay);
      } catch (_) {
        return false;
      }
    }).length;
  }

  // Unique students who violated
  int get _uniqueViolators {
    return _violations.map((v) => v['npm']).toSet().length;
  }

  String _getMKName(int? sesiId) {
    if (sesiId == null) return '-';
    final sesi = _sesiList.firstWhere((s) => s['id'] == sesiId, orElse: () => {});
    if (sesi.isEmpty) return '-';
    final mk = _mkList.firstWhere((m) => m['id'] == sesi['mata_kuliah_id'], orElse: () => {});
    return mk['nama_mk'] ?? '-';
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

    final violations = _violations;
    final totalPages = (violations.length / _perPage).ceil().clamp(1, 9999);
    final startIdx = (_currentPage - 1) * _perPage;
    final pageData = violations.skip(startIdx).take(_perPage).toList();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // ─── Header ───
        const AdminPageHeader(
          title: 'Pelanggaran & Fake GPS',
          subtitle: 'Monitoring pelanggaran integritas lokasi absensi mahasiswa.',
        ),
        const SizedBox(height: 24),

        // ─── Alert Card ───
        if (_todayViolations > 0) ...[
          AdminAlertCard(
            title: 'Perhatian',
            message: '$_todayViolations pelanggaran terdeteksi hari ini. Segera investigasi kasus-kasus ini.',
            actionLabel: 'Lihat Detail',
            onAction: () {},
            color: AdminTheme.danger,
            icon: Icons.gpp_bad_rounded,
          ),
          const SizedBox(height: 20),
        ],

        // ─── Stat Cards ───
        Row(
          children: [
            Expanded(child: AdminStatCard(
              icon: Icons.gpp_bad_rounded,
              iconColor: AdminTheme.danger,
              label: 'Total Pelanggaran',
              value: '${violations.length}',
              valueColor: AdminTheme.danger,
            )),
            const SizedBox(width: 14),
            Expanded(child: AdminStatCard(
              icon: Icons.today_rounded,
              iconColor: AdminTheme.danger,
              label: 'Fake GPS Hari Ini',
              value: '$_todayViolations',
              valueColor: _todayViolations > 0 ? AdminTheme.danger : null,
            )),
            const SizedBox(width: 14),
            Expanded(child: AdminStatCard(
              icon: Icons.person_off_outlined,
              iconColor: AdminTheme.warning,
              label: 'Pelaku Unik',
              value: '$_uniqueViolators',
              subtitle: 'Mahasiswa berbeda',
            )),
            const SizedBox(width: 14),
            Expanded(child: AdminStatCard(
              icon: Icons.pending_actions_outlined,
              iconColor: AdminTheme.warning,
              label: 'Unresolved',
              value: '${violations.length}',
              subtitle: 'Belum ditindaklanjuti',
            )),
          ],
        ),
        const SizedBox(height: 20),

        // ─── Data Table ───
        Container(
          decoration: AdminTheme.cardDecoration,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
                      child: Row(
                        children: [
                          AdminTableHeader('Mahasiswa', flex: 3),
                          AdminTableHeader('NIM', flex: 2),
                          AdminTableHeader('Waktu', flex: 2),
                          AdminTableHeader('Lokasi', flex: 3),
                          AdminTableHeader('Mata Kuliah', flex: 2),
                          AdminTableHeader('Status', flex: 1),
                        ],
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),

              if (pageData.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(48),
                  child: Column(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, size: 48, color: AdminTheme.success),
                      const SizedBox(height: 12),
                      Text('Tidak ada pelanggaran terdeteksi', style: AdminTheme.h3),
                      const SizedBox(height: 4),
                      const Text('Semua absensi terverifikasi valid.', style: AdminTheme.body),
                    ],
                  ),
                )
              else
                ...pageData.asMap().entries.map((entry) {
                  final i = entry.key;
                  final v = entry.value;
                  final nama = v['nama'] ?? '-';
                  final npm = v['npm'] ?? '-';
                  final mkName = _getMKName(v['sesi_id']);
                  final alamat = (v['alamat'] ?? v['lokasi'] ?? '-').toString();
                  final alamatShort = alamat.length > 22 ? '${alamat.substring(0, 22)}…' : alamat;

                  String waktu = '-';
                  if (v['waktu'] != null) {
                    try {
                      final dt = DateTime.parse(v['waktu']).toLocal();
                      waktu = DateFormat('dd/MM/yy HH:mm').format(dt);
                    } catch (_) {}
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: i.isEven ? Colors.white : AdminTheme.dangerLight.withOpacity(0.3),
                      border: const Border(
                        bottom: BorderSide(color: AdminTheme.border, width: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              Stack(
                                children: [
                                  AdminTheme.avatarInitials(nama, radius: 16),
                                  Positioned(
                                    right: 0, bottom: 0,
                                    child: Container(
                                      width: 12, height: 12,
                                      decoration: BoxDecoration(
                                        color: AdminTheme.danger,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                      child: const Icon(Icons.close_rounded, size: 6, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Text(nama, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AdminTheme.danger))),
                            ],
                          ),
                        ),
                        Expanded(flex: 2, child: Text(npm, style: AdminTheme.tableCell)),
                        Expanded(flex: 2, child: Text(waktu, style: AdminTheme.tableCell)),
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, size: 12, color: AdminTheme.danger),
                              const SizedBox(width: 4),
                              Expanded(child: Text(alamatShort, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, color: AdminTheme.textSecondary))),
                            ],
                          ),
                        ),
                        Expanded(flex: 2, child: Text(mkName, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: AdminTheme.tableCell)),
                        Expanded(flex: 1, child: AdminTheme.statusBadge('Fake GPS')),
                        SizedBox(
                          width: 40,
                          child: IconButton(
                            icon: const Icon(Icons.visibility_outlined, size: 16, color: AdminTheme.textSecondary),
                            onPressed: () {
                              // Show detail dialog
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: Text('Detail Pelanggaran - $nama'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('NIM: $npm'),
                                      Text('Waktu: $waktu'),
                                      Text('Lokasi: $alamat'),
                                      Text('Mata Kuliah: $mkName'),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AdminTheme.dangerLight,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Row(
                                          children: [
                                            Icon(Icons.gpp_bad_rounded, size: 16, color: AdminTheme.danger),
                                            SizedBox(width: 8),
                                            Text('TERDETEKSI FAKE GPS', style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: AdminTheme.danger,
                                            )),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Tutup'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                }),

              AdminPagination(
                currentPage: _currentPage,
                totalPages: totalPages,
                totalItems: violations.length,
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