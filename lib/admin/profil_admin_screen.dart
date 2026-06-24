import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import 'theme/admin_theme.dart';
import 'widgets/admin_widgets.dart';

class ProfilAdminScreen extends StatefulWidget {
  const ProfilAdminScreen({super.key});

  @override
  State<ProfilAdminScreen> createState() => _ProfilAdminScreenState();
}

class _ProfilAdminScreenState extends State<ProfilAdminScreen> {
  final supabase = Supabase.instance.client;
  bool _loading = true;

  // Profile data
  String _adminName = 'Admin';
  String _adminEmail = '';
  String _adminRole = 'ADMIN';
  String _adminNpm = '-';

  // Stats
  int _totalMahasiswa = 0;
  int _totalDosen = 0;
  int _totalSesi = 0;

  // Activity Log Layout Data
  List<Map<String, dynamic>> _recentLogs = [];

  // Toggle Preferences (UI State Only) - Removed as per user request

  @override
  void initState() {
    super.initState();
    _loadProfileAndStats();
  }

  Future<void> _loadProfileAndStats() async {
    setState(() => _loading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        _adminEmail = user.email ?? '';
        final profile = await SupabaseService.getUserProfile(user.id);
        if (profile != null) {
          _adminName = profile['nama'] ?? 'Admin';
          _adminRole = (profile['role'] ?? 'admin').toString().toUpperCase();
          _adminNpm = profile['npm'] ?? '-';
        }
      }

      // Fetch dynamic stats from existing tables
      final profilesRes = await supabase.from('profiles').select('role');
      final sesiRes = await supabase.from('sesi_absensi').select('id');
      final logsRes = await supabase
          .from('data_absensi')
          .select('nama, jenis, waktu')
          .order('waktu', ascending: false)
          .limit(5);

      final profiles = profilesRes as List;
      _totalMahasiswa = profiles
          .where((e) => e['role'] == 'user' || e['role'] == 'mahasiswa')
          .length;
      _totalDosen = profiles.where((e) => e['role'] == 'dosen').length;
      _totalSesi = (sesiRes as List).length;

      _recentLogs = List<Map<String, dynamic>>.from(logsRes as List);

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      debugPrint('Error loading profile screen: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          AdminSkeletonBox(height: 60),
          SizedBox(height: 16),
          AdminSkeletonBox(height: 150),
          SizedBox(height: 16),
          AdminSkeletonBox(height: 350),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // ─── Header ───
        const AdminPageHeader(
          title: 'Profil Administrator',
          subtitle: 'Lihat data personal, aktivitas sistem terakhir, dan preferensi akun Anda.',
        ),
        const SizedBox(height: 24),

        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 800;
            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _buildLeftColumn()),
                  const SizedBox(width: 20),
                  Expanded(flex: 5, child: _buildRightColumn()),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildLeftColumn(),
                const SizedBox(height: 20),
                _buildRightColumn(),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildLeftColumn() {
    return Column(
      children: [
        // Profile Summary Card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: AdminTheme.cardDecoration,
          child: Column(
            children: [
              AdminTheme.avatarInitials(_adminName, radius: 45),
              const SizedBox(height: 16),
              Text(
                _adminName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AdminTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AdminTheme.primaryLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _adminRole,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AdminTheme.primary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Divider(color: AdminTheme.border, height: 1),
              const SizedBox(height: 20),
              _profileMetaRow(Icons.email_outlined, 'Email', _adminEmail),
              const SizedBox(height: 12),
              _profileMetaRow(Icons.badge_outlined, 'NPM / ID', _adminNpm),
              const SizedBox(height: 12),
              _profileMetaRow(Icons.security_rounded, 'Hak Akses', 'Super Admin'),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Quick Stats Indicator Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: AdminTheme.cardDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Statistik Terpantau',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AdminTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              _indicatorRow('Total Mahasiswa', _totalMahasiswa, AdminTheme.primary),
              const SizedBox(height: 12),
              _indicatorRow('Total Dosen', _totalDosen, AdminTheme.success),
              const SizedBox(height: 12),
              _indicatorRow('Total Sesi Absensi', _totalSesi, AdminTheme.warning),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRightColumn() {
    return Column(
      children: [
        // Personal Information Form Layout (Read-Only)
        Container(
          padding: const EdgeInsets.all(24),
          decoration: AdminTheme.cardDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Detail Informasi Akun',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AdminTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: TextEditingController(text: _adminName),
                readOnly: true,
                decoration: AdminTheme.inputDecoration(
                  label: 'Nama Lengkap',
                  prefixIcon: Icons.person_outline_rounded,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: TextEditingController(text: _adminEmail),
                readOnly: true,
                decoration: AdminTheme.inputDecoration(
                  label: 'Alamat Email',
                  prefixIcon: Icons.mail_outline_rounded,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: TextEditingController(text: _adminNpm),
                readOnly: true,
                decoration: AdminTheme.inputDecoration(
                  label: 'Nomor Pokok Mahasiswa / ID Staf',
                  prefixIcon: Icons.badge_outlined,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 14, color: AdminTheme.textMuted),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Data profil dikelola secara terpusat oleh Direktorat Teknologi Informasi.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AdminTheme.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),



        // Recent Activities Feed (Connected to Absensi logs)
        Container(
          padding: const EdgeInsets.all(24),
          decoration: AdminTheme.cardDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Aktivitas Sistem Terkini',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AdminTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              if (_recentLogs.isEmpty)
                const Text('Belum ada log aktivitas absensi.',
                    style: TextStyle(fontSize: 12, color: AdminTheme.textMuted))
              else
                ..._recentLogs.map((log) {
                  final nama = log['nama'] ?? 'Mahasiswa';
                  final jenis = log['jenis'] ?? 'Hadir';
                  final waktu = log['waktu'] != null
                      ? DateTime.parse(log['waktu']).toLocal()
                      : DateTime.now();
                  final timeStr =
                      '${waktu.hour.toString().padLeft(2, '0')}:${waktu.minute.toString().padLeft(2, '0')}';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AdminTheme.primaryLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 14,
                            color: AdminTheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$nama mencatat absensi ($jenis)',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AdminTheme.textPrimary,
                                ),
                              ),
                              Text(
                                'Waktu: $timeStr WIB',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AdminTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _profileMetaRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AdminTheme.textSecondary),
        const SizedBox(width: 10),
        Text(
          '$label:',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AdminTheme.textSecondary,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AdminTheme.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _indicatorRow(String label, int value, Color color) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AdminTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          '$value',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AdminTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}