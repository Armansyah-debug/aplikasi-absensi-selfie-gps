import 'package:flutter/material.dart';
import '../theme/admin_theme.dart';

class AdminTopBar extends StatelessWidget {
  final String searchHint;
  final ValueChanged<String>? onSearch;
  final bool showMenuButton;
  final VoidCallback? onMenuTap;

  const AdminTopBar({
    super.key,
    this.searchHint = 'Cari aktivitas atau data...',
    this.onSearch,
    this.showMenuButton = false,
    this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AdminTheme.surface,
        border: Border(bottom: BorderSide(color: AdminTheme.border)),
      ),
      child: Row(
        children: [
          if (showMenuButton) ...[
            IconButton(
              icon: const Icon(Icons.menu_rounded,
                  color: AdminTheme.textSecondary, size: 20),
              onPressed: onMenuTap,
            ),
            const SizedBox(width: 4),
          ],

          // ─── Search Bar ───
          Expanded(
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: AdminTheme.bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AdminTheme.border),
              ),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(Icons.search_rounded,
                        size: 15, color: AdminTheme.textMuted),
                  ),
                  Expanded(
                    child: TextField(
                      onChanged: onSearch,
                      style: const TextStyle(
                          fontSize: 13, color: AdminTheme.textPrimary),
                      decoration: InputDecoration(
                        hintText: searchHint,
                        hintStyle: const TextStyle(
                            fontSize: 13, color: AdminTheme.textMuted),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 8),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

          // ─── Icon Buttons ───
          _IconBtn(icon: Icons.notifications_outlined, onTap: () {}),
          const SizedBox(width: 2),
          _IconBtn(icon: Icons.help_outline_rounded, onTap: () {}),

          const SizedBox(width: 12),

          // ─── Admin Profile Chip ───
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AdminTheme.bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AdminTheme.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Admin Profile',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AdminTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'SUPER ADMINISTRATOR',
                      style: TextStyle(
                        fontSize: 8,
                        color: AdminTheme.textMuted,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AdminTheme.primary,
                  child: const Text(
                    'A',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 19, color: AdminTheme.textSecondary),
        ),
      ),
    );
  }
}
