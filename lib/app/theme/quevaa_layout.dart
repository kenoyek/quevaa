import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'quevaa_spacing.dart';

class QuevaaBreakpoints {
  static const compact = 360.0;
  static const medium = 600.0;
  static const expanded = 840.0;
}

class QuevaaSectionTabs extends StatefulWidget {
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
  State<QuevaaSectionTabs> createState() => _QuevaaSectionTabsState();
}

class _QuevaaSectionTabsState extends State<QuevaaSectionTabs> {
  final _scroll = ScrollController();
  final _selectedTab = GlobalKey();

  @override
  void initState() {
    super.initState();
    _revealSelection();
  }

  @override
  void didUpdateWidget(covariant QuevaaSectionTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) _revealSelection();
  }

  void _revealSelection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final tab = _selectedTab.currentContext?.findRenderObject();
      if (tab == null) return;
      _scroll.position.ensureVisible(tab, alignment: 0.5);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: QuevaaSpacing.m),
      child: Row(
        children: widget.segments.map((s) {
          final isSelected = s.value == widget.selected;
          return Padding(
            key: isSelected ? _selectedTab : null,
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
                        : (isDark
                              ? Colors.white70
                              : AppColors.textSecondaryLight),
                  ),
                  const SizedBox(width: QuevaaSpacing.xs),
                  Text(
                    s.label,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
              selected: isSelected,
              onSelected: (_) => widget.onSelectionChanged(s.value),
              selectedColor: isDark
                  ? AppColors.terracottaDark
                  : AppColors.terracottaPrimary,
              backgroundColor: isDark
                  ? AppColors.cardSurfaceDark
                  : AppColors.cardSurfaceLight,
              labelStyle: TextStyle(
                color: isSelected
                    ? (isDark ? AppColors.terracottaLight : Colors.white)
                    : (isDark ? Colors.white70 : AppColors.textSecondaryLight),
              ),
              side: BorderSide(
                color: isSelected
                    ? (isDark
                          ? AppColors.terracottaPrimary
                          : Colors.transparent)
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
