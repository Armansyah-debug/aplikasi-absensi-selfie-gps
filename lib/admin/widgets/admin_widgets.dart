import 'package:flutter/material.dart';
import '../theme/admin_theme.dart';

// ═══════════════════════════════════════════════════════════
// AdminPageHeader — Title + subtitle + optional action button
// ═══════════════════════════════════════════════════════════
class AdminPageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? action;
  final List<Widget>? breadcrumbs;

  const AdminPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.action,
    this.breadcrumbs,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (breadcrumbs != null) ...[
                Row(children: breadcrumbs!),
                const SizedBox(height: 8),
              ],
              Text(title, style: AdminTheme.h1),
              const SizedBox(height: 4),
              Text(subtitle, style: AdminTheme.body),
            ],
          ),
        ),
        if (action != null) ...[
          const SizedBox(width: 16),
          action!,
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// AdminStatCard — Summary metric card (icon + label + value)
// ═══════════════════════════════════════════════════════════
class AdminStatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String? badge;
  final Color? badgeColor;
  final String? subtitle;
  final Color? valueColor;
  final Widget? trailing;
  final double? width;

  const AdminStatCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.badge,
    this.badgeColor,
    this.subtitle,
    this.valueColor,
    this.trailing,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: AdminTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const Spacer(),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (badgeColor ?? AdminTheme.success).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        badgeColor == AdminTheme.danger
                            ? Icons.trending_down_rounded
                            : Icons.trending_up_rounded,
                        size: 12,
                        color: badgeColor ?? AdminTheme.success,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        badge!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: badgeColor ?? AdminTheme.success,
                        ),
                      ),
                    ],
                  ),
                ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AdminTheme.textMuted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: valueColor ?? AdminTheme.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 11,
                color: AdminTheme.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// AdminFilterBar — Filter area with chips/dropdowns
// ═══════════════════════════════════════════════════════════
class AdminFilterBar extends StatelessWidget {
  final List<Widget> filters;
  final VoidCallback? onReset;
  final List<Widget>? actions;

  const AdminFilterBar({
    super.key,
    required this.filters,
    this.onReset,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AdminTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AdminTheme.bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AdminTheme.border),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tune_rounded, size: 14, color: AdminTheme.textSecondary),
                SizedBox(width: 6),
                Text('Filter', style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AdminTheme.textSecondary,
                )),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ...filters.map((f) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: f,
          )),
          if (onReset != null)
            TextButton(
              onPressed: onReset,
              style: TextButton.styleFrom(
                foregroundColor: AdminTheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: const Text('Reset', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          const Spacer(),
          if (actions != null) ...actions!,
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// AdminDropdownFilter — Styled dropdown for filter bar
// ═══════════════════════════════════════════════════════════
class AdminDropdownFilter extends StatelessWidget {
  final String hint;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const AdminDropdownFilter({
    super.key,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AdminTheme.bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AdminTheme.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: const TextStyle(fontSize: 12, color: AdminTheme.textSecondary)),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AdminTheme.textSecondary),
          style: const TextStyle(fontSize: 12, color: AdminTheme.textPrimary, fontWeight: FontWeight.w500),
          isDense: true,
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// AdminPagination — Page numbers with prev/next arrows
// ═══════════════════════════════════════════════════════════
class AdminPagination extends StatelessWidget {
  final int currentPage; // 1-indexed
  final int totalPages;
  final int totalItems;
  final ValueChanged<int> onPageChanged;
  final String itemLabel;
  final int? itemsPerPage;

  const AdminPagination({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.onPageChanged,
    this.itemLabel = 'data',
    this.itemsPerPage,
  });

  @override
  Widget build(BuildContext context) {
    final perPage = itemsPerPage ?? 10;
    final start = ((currentPage - 1) * perPage + 1).clamp(1, totalItems == 0 ? 1 : totalItems);
    final end = (currentPage * perPage).clamp(0, totalItems);

    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AdminTheme.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Text(
              totalItems == 0
                  ? 'Tidak ada $itemLabel'
                  : 'Menampilkan $start–$end dari $totalItems $itemLabel',
              style: const TextStyle(fontSize: 12, color: AdminTheme.textMuted, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            _navBtn('Sebelumnya', currentPage > 1, () => onPageChanged(currentPage - 1)),
            const SizedBox(width: 4),
            ...List.generate(
              totalPages.clamp(0, 5),
              (i) {
                final page = i + 1; // 1-indexed
                final isActive = page == currentPage;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => onPageChanged(page),
                    child: Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isActive ? AdminTheme.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: isActive ? null : Border.all(color: AdminTheme.border),
                      ),
                      child: Text(
                        '$page',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isActive ? Colors.white : AdminTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            if (totalPages > 5) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('...', style: TextStyle(color: AdminTheme.textMuted)),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => onPageChanged(totalPages),
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AdminTheme.border),
                  ),
                  child: Text(
                    '$totalPages',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AdminTheme.textSecondary),
                  ),
                ),
              ),
            ],
            const SizedBox(width: 4),
            _navBtn('Berikutnya', currentPage < totalPages, () => onPageChanged(currentPage + 1)),
          ],
        ),
      ),
    );
  }

  Widget _navBtn(String label, bool enabled, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: enabled ? AdminTheme.border : AdminTheme.border.withOpacity(0.5)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: enabled ? AdminTheme.textSecondary : AdminTheme.textMuted,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// AdminTableHeader — Column header text for data tables
// ═══════════════════════════════════════════════════════════
class AdminTableHeader extends StatelessWidget {
  final String text;
  final int flex;

  const AdminTableHeader(this.text, {super.key, this.flex = 1});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AdminTheme.textMuted,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// AdminEmptyState — Empty state placeholder
// ═══════════════════════════════════════════════════════════
class AdminEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const AdminEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AdminTheme.bg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: AdminTheme.textMuted),
            ),
            const SizedBox(height: 16),
            Text(title, style: AdminTheme.h3),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!, style: AdminTheme.body, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// AdminPrimaryButton — Prominent action button
// ═══════════════════════════════════════════════════════════
class AdminPrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  final Color? color;

  const AdminPrimaryButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? AdminTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: icon != null ? Icon(icon, size: 18) : const SizedBox.shrink(),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// AdminProgressBar — Horizontal progress indicator
// ═══════════════════════════════════════════════════════════
class AdminProgressBar extends StatelessWidget {
  final double value; // 0.0 to 1.0
  final Color? color;
  final double height;
  final double width;

  const AdminProgressBar({
    super.key,
    required this.value,
    this.color,
    this.height = 6,
    this.width = 80,
  });

  @override
  Widget build(BuildContext context) {
    final barColor = color ?? _getColorForValue(value);
    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: LinearProgressIndicator(
          value: value.clamp(0.0, 1.0),
          backgroundColor: AdminTheme.bg,
          valueColor: AlwaysStoppedAnimation<Color>(barColor),
          minHeight: height,
        ),
      ),
    );
  }

  Color _getColorForValue(double v) {
    if (v >= 0.85) return AdminTheme.success;
    if (v >= 0.70) return AdminTheme.primary;
    if (v >= 0.50) return AdminTheme.warning;
    return AdminTheme.danger;
  }
}

// ═══════════════════════════════════════════════════════════
// AdminSkeletonBox — Loading skeleton placeholder
// ═══════════════════════════════════════════════════════════
class AdminSkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const AdminSkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AdminTheme.border,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// AdminAlertCard — Highlighted alert / notification card
// ═══════════════════════════════════════════════════════════
class AdminAlertCard extends StatelessWidget {
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color color;
  final IconData icon;

  const AdminAlertCard({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.color = AdminTheme.danger,
    this.icon = Icons.warning_amber_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(fontSize: 13, color: AdminTheme.textPrimary, fontWeight: FontWeight.w600, height: 1.4),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: onAction,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    actionLabel!,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 14, color: color),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
