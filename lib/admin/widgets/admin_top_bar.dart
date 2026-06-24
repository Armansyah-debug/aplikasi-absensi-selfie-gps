import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
import '../theme/admin_theme.dart';

class AdminTopBar extends StatefulWidget {
  final String searchHint;
  final ValueChanged<String>? onSearch;
  final bool showMenuButton;
  final VoidCallback? onMenuTap;

  const AdminTopBar({
    super.key,
    this.searchHint = 'Cari data, mahasiswa, atau sesi...',
    this.onSearch,
    this.showMenuButton = false,
    this.onMenuTap,
  });

  @override
  State<AdminTopBar> createState() => _AdminTopBarState();
}

class _AdminTopBarState extends State<AdminTopBar> {
  String _adminName = 'Admin';
  String _adminRole = 'SUPER ADMINISTRATOR';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final profile = await SupabaseService.getUserProfile(user.id);
    if (mounted && profile != null) {
      setState(() {
        _adminName = profile['nama'] ?? 'Admin';
        _adminRole = (profile['role'] ?? 'admin').toString().toUpperCase();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 600;
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AdminTheme.surface,
        border: Border(bottom: BorderSide(color: AdminTheme.border)),
      ),
      child: Row(
        children: [
          if (widget.showMenuButton) ...[
            IconButton(
              icon: const Icon(Icons.menu_rounded,
                  color: AdminTheme.textSecondary, size: 20),
              onPressed: widget.onMenuTap,
            ),
            const SizedBox(width: 4),
          ],

          const Spacer(),

          // ─── Admin Profile Chip ───
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AdminTheme.bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AdminTheme.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isWide) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _adminName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AdminTheme.textPrimary,
                        ),
                      ),
                      Text(
                        _adminRole,
                        style: const TextStyle(
                          fontSize: 8,
                          color: AdminTheme.textMuted,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                ],
                AdminTheme.avatarInitials(_adminName, radius: 15),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

