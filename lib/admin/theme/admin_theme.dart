import 'package:flutter/material.dart';

/// AdminTheme — centralized design tokens for Admin Dashboard.
/// All colors, typography, and decoration helpers live here.
class AdminTheme {
  AdminTheme._();

  // ─────────────────────────────────────────────
  // Brand Colors
  // ─────────────────────────────────────────────
  static const Color primary = Color(0xFF1A56DB);
  static const Color primaryDark = Color(0xFF1E3A8A);
  static const Color primaryLight = Color(0xFFEFF6FF);
  static const Color primaryMid = Color(0xFF3B82F6);

  // ─────────────────────────────────────────────
  // Status Colors
  // ─────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color successDark = Color(0xFF065F46);
  static const Color danger = Color(0xFFEF4444);
  static const Color dangerLight = Color(0xFFFEE2E2);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color warningDark = Color(0xFF92400E);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDEEBFF);

  // ─────────────────────────────────────────────
  // Neutral Colors
  // ─────────────────────────────────────────────
  static const Color bg = Color(0xFFF1F5F9);
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFF8FAFC);
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  // ─────────────────────────────────────────────
  // Sidebar
  // ─────────────────────────────────────────────
  static const Color sidebarBg = Colors.white;
  static const Color sidebarActive = Color(0xFF1A56DB);
  static const Color sidebarActiveText = Colors.white;
  static const Color sidebarInactiveText = Color(0xFF64748B);
  static const double sidebarWidth = 220;

  // ─────────────────────────────────────────────
  // Typography
  // ─────────────────────────────────────────────
  static const TextStyle h1 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -0.3,
  );

  static const TextStyle h3 = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 13,
    color: textSecondary,
    height: 1.5,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    color: textMuted,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle label = TextStyle(
    fontSize: 11,
    color: textSecondary,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  // ─────────────────────────────────────────────
  // Card Decorations
  // ─────────────────────────────────────────────
  static BoxDecoration get cardDecoration => BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      );

  static BoxDecoration get primaryGradientDecoration => BoxDecoration(
        gradient: const LinearGradient(
          colors: [primary, primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      );

  // ─────────────────────────────────────────────
  // Input Decoration Helper
  // ─────────────────────────────────────────────
  static InputDecoration inputDecoration({
    required String label,
    IconData? prefixIcon,
    String? hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, size: 18, color: textSecondary)
          : null,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: surface,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
      labelStyle: const TextStyle(color: textSecondary, fontSize: 13),
      hintStyle: const TextStyle(color: textMuted, fontSize: 13),
    );
  }

  // ─────────────────────────────────────────────
  // Shared Helpers
  // ─────────────────────────────────────────────

  /// Avatar with initials
  static Widget avatarInitials(String name, {double radius = 18}) {
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join();
    final colors = [
      primary, success, warning, danger, const Color(0xFF8B5CF6), const Color(0xFFEC4899)
    ];
    final colorIdx = name.isEmpty ? 0 : name.codeUnitAt(0) % colors.length;
    return CircleAvatar(
      radius: radius,
      backgroundColor: colors[colorIdx].withOpacity(0.15),
      child: Text(
        initials,
        style: TextStyle(
          fontSize: radius * 0.7,
          fontWeight: FontWeight.bold,
          color: colors[colorIdx],
        ),
      ),
    );
  }

  /// Status badge for kehadiran
  static Widget statusBadge(String status) {
    Color bg;
    Color fg;
    switch (status.toLowerCase()) {
      case 'hadir':
        bg = successLight;
        fg = successDark;
        break;
      case 'izin':
        bg = infoLight;
        fg = primaryDark;
        break;
      case 'sakit':
        bg = warningLight;
        fg = warningDark;
        break;
      case 'fake gps':
        bg = dangerLight;
        fg = danger;
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        fg = textSecondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}
