import 'package:flutter/material.dart';

/// AdminTheme — centralized design tokens for Admin Dashboard.
/// All colors, typography, and decoration helpers live here.
class AdminTheme {
  AdminTheme._();

  // ─────────────────────────────────────────────
  // Brand Colors
  // ─────────────────────────────────────────────
  static const Color primary = Color(0xFF4343D9);
  static const Color primaryDark = Color(0xFF2E2E99);
  static const Color primaryLight = Color(0xFFE8E8FF);
  static const Color primaryMid = Color(0xFF5B5BF0);

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
  static const Color bg = Color(0xFFF8FAFC);
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
  static const Color sidebarActive = Color(0xFF4343D9);
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

  static const TextStyle tableHeader = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: textMuted,
    letterSpacing: 0.5,
  );

  static const TextStyle tableCell = TextStyle(
    fontSize: 12,
    color: textPrimary,
  );

  static const TextStyle tableCellBold = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: textPrimary,
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

  // Table row decoration (alternating)
  static BoxDecoration tableRowDecoration({bool isEven = true, bool isHovered = false}) => BoxDecoration(
        color: isHovered
            ? primaryLight
            : isEven
                ? Colors.white
                : bg.withOpacity(0.5),
        border: const Border(
          bottom: BorderSide(color: border, width: 0.5),
        ),
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
  static Widget statusBadge(String status, {double fontSize = 10}) {
    Color bg;
    Color fg;
    switch (status.toLowerCase()) {
      case 'hadir':
        bg = successLight;
        fg = successDark;
        break;
      case 'aktif':
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
      case 'pelanggaran':
      case 'ditolak (fake gps)':
        bg = dangerLight;
        fg = danger;
        break;
      case 'berisiko':
        bg = dangerLight;
        fg = danger;
        break;
      case 'tinggi':
        bg = dangerLight;
        fg = danger;
        break;
      case 'sedang':
        bg = warningLight;
        fg = warningDark;
        break;
      case 'rendah':
        bg = const Color(0xFFDEEBFF);
        fg = primaryDark;
        break;
      case 'cuti':
        bg = const Color(0xFFF1F5F9);
        fg = textSecondary;
        break;
      case 'on leave':
        bg = warningLight;
        fg = warningDark;
        break;
      case 'aman':
        bg = successLight;
        fg = successDark;
        break;
      case 'sempurna':
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF065F46);
        break;
      case 'peringatan':
        bg = warningLight;
        fg = warningDark;
        break;
      case 'risiko':
        bg = dangerLight;
        fg = danger;
        break;
      case 'selesai':
        bg = const Color(0xFFF1F5F9);
        fg = textSecondary;
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
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  /// Live dot indicator
  static Widget liveDot({Color color = success, String label = 'Live'}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.4), blurRadius: 6),
            ],
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }

  /// Section divider with title
  static Widget sectionDivider(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, top: 16, bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
          color: textMuted,
        ),
      ),
    );
  }
}
