import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/admin_theme.dart';
import '../../screens/login_screen.dart';

class _SidebarMenuItem {
  final String label;
  final IconData icon;
  const _SidebarMenuItem(this.label, this.icon);
}

const _menuItems = [
  _SidebarMenuItem('Dashboard', Icons.dashboard_rounded),
  _SidebarMenuItem('Mahasiswa', Icons.people_outline_rounded),
  _SidebarMenuItem('Dosen', Icons.school_outlined),
  _SidebarMenuItem('Jurusan', Icons.account_balance_outlined),
  _SidebarMenuItem('Mata Kuliah', Icons.menu_book_outlined),
  _SidebarMenuItem('Pengampu', Icons.person_search_outlined),
  _SidebarMenuItem('Monitoring', Icons.my_location_outlined),
  _SidebarMenuItem('Kelola Sesi', Icons.calendar_today_outlined),
  _SidebarMenuItem('Riwayat', Icons.history_rounded),
  _SidebarMenuItem('Statistik', Icons.bar_chart_rounded),
  _SidebarMenuItem(
    'Mahasiswa Risiko',
    Icons.warning_amber_rounded,
  ),
  _SidebarMenuItem('Pelanggaran', Icons.gpp_bad_rounded),
  _SidebarMenuItem('Export Data', Icons.download_rounded),
  _SidebarMenuItem('Profil', Icons.person_rounded),
];

class _MenuSection {
  final String title;
  final int start;
  final int end;

  const _MenuSection(
    this.title,
    this.start,
    this.end,
  );
}

const _sections = [
  _MenuSection('DATA MASTER', 1, 5),
  _MenuSection('ABSENSI', 6, 8),
  _MenuSection('ANALITIK', 9, 11),
  _MenuSection('LAPORAN', 12, 12),
  _MenuSection('AKUN', 13, 13),
];

class AdminSidebar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AdminSidebar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AdminTheme.sidebarWidth,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: AdminTheme.sidebarBg,
        border: Border(right: BorderSide(color: AdminTheme.border)),
      ),
      child: Column(
        children: [
          // ─── Logo Area ───
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AdminTheme.primary, AdminTheme.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'UniAttendance',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'ADMIN SYSTEM',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ─── Menu Items ───
          Expanded(
  child: ListView(
    padding: const EdgeInsets.symmetric(
      horizontal: 10,
      vertical: 10,
    ),
    children: [
      _MenuTile(
        icon: _menuItems[0].icon,
        label: _menuItems[0].label,
        isActive: currentIndex == 0,
        onTap: () => onTap(0),
      ),

      const SizedBox(height: 12),

      ..._sections.map((section) {
        return Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: 12,
                top: 10,
                bottom: 6,
              ),
              child: Text(
                section.title,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: AdminTheme.textMuted,
                ),
              ),
            ),

            ...List.generate(
              section.end - section.start + 1,
              (i) {
                final index =
                    section.start + i;

                return _MenuTile(
                  icon: _menuItems[index].icon,
                  label: _menuItems[index].label,
                  isActive:
                      currentIndex == index,
                  onTap: () => onTap(index),
                );
              },
            ),

            const SizedBox(height: 6),
          ],
        );
      }),
    ],
  ),
),

          // ─── Bottom Actions ───
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AdminTheme.border)),
            ),
            child: Column(
              children: [
                _BottomTile(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  onTap: () {},
                ),
                const SizedBox(height: 2),
                _BottomTile(
                  icon: Icons.logout_rounded,
                  label: 'Logout',
                  color: AdminTheme.danger,
                  onTap: () async {
                    await Supabase.instance.client.auth.signOut();
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isActive ? AdminTheme.sidebarActive : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 17,
                  color:
                      isActive ? Colors.white : AdminTheme.sidebarInactiveText,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      color: isActive
                          ? Colors.white
                          : AdminTheme.sidebarInactiveText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _BottomTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AdminTheme.sidebarInactiveText;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 17, color: c),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: c,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
