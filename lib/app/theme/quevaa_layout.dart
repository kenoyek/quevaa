import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'quevaa_spacing.dart';

class QuevaaBreakpoints {
  static const compact = 360.0;
  static const medium = 600.0;
  static const expanded = 840.0;
}

class QuevaaSectionTabs extends StatelessWidget {
  final List<({String value, String label, IconData icon})> segments;
  final String selected;
  final ValueChanged<String> onSelectionChanged;

  const QuevaaSectionTabs({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: QuevaaSpacing.m),
      child: Row(
        children: segments.map((s) {
          final isSelected = s.value == selected;
          return Padding(
            padding: const EdgeInsets.only(right: QuevaaSpacing.s),
            child: ChoiceChip(
              showCheckmark: false,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    s.icon,
                    size: 18,
                    color: isSelected
                        ? (isDark ? AppColors.terracottaLight : Colors.white)
                        : (isDark ? Colors.white70 : AppColors.textSecondaryLight),
                  ),
                  const SizedBox(width: QuevaaSpacing.xs),
                  Text(
                    s.label,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
              selected: isSelected,
              onSelected: (_) => onSelectionChanged(s.value),
              selectedColor: isDark ? AppColors.terracottaDark : AppColors.terracottaPrimary,
              backgroundColor: isDark ? AppColors.cardSurfaceDark : AppColors.cardSurfaceLight,
              labelStyle: TextStyle(
                color: isSelected
                    ? (isDark ? AppColors.terracottaLight : Colors.white)
                    : (isDark ? Colors.white70 : AppColors.textSecondaryLight),
              ),
              side: BorderSide(
                color: isSelected
                    ? (isDark ? AppColors.terracottaPrimary : Colors.transparent)
                    : (isDark ? AppColors.borderDark : AppColors.borderLight),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: QuevaaSpacing.s,
                vertical: QuevaaSpacing.xs,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(QuevaaSpacing.m),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
