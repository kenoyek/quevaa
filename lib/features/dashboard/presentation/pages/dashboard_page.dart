import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../app/theme/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/models/prediction_confidence.dart';
import '../../../../core/providers/user_profile_provider.dart';
import '../../../cycle/application/cycle_workspace_provider.dart';
import '../../../cycle/domain/models/current_cycle_snapshot.dart';
import '../../../cycle/domain/models/estimated_cycle_phase.dart';
import '../../../insights/domain/insight_generator.dart';
import '../../../notifications/presentation/widgets/notification_bell_button.dart';
import '../../../notifications/presentation/widgets/notification_permission_invitation.dart';
import '../../../recommendations/application/daily_quevaa_plan_provider.dart';
import '../../domain/readiness_calculator.dart';

const _rose = Color(0xFF843C59);
const _lightRose = Color(0xFFFFBDD3);

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  int _mealIndex = 0;

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(dailyQuevaaPlanProvider);
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final logState = ref.watch(todaysDailyLogProvider);
    final log = logState.valueOrNull;
    final logSaving = ref.watch(cycleWorkspaceControllerProvider);
    final insights = ref.watch(quickInsightsProvider);
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final recipe = plan.mealForOffset(_mealIndex);
    final accent = dark ? _lightRose : _rose;

    return Scaffold(
      backgroundColor: dark ? AppColors.bgWarmDark : const Color(0xFFFCF7F9),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              math.max(16, (constraints.maxWidth - 680) / 2),
              18,
              math.max(16, (constraints.maxWidth - 680) / 2),
              24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TodayHeader(date: plan.date, name: profile?.userName),
                const SizedBox(height: 18),
                _CycleHero(
                  snapshot: plan.cycleSnapshot,
                  onOpen: () => context.go('/cycle'),
                ),
                const SizedBox(height: 14),
                _CheckInCard(
                  log: log,
                  onOpen: logState.hasValue && !logSaving
                      ? () => _showCheckIn(context, ref, plan.date, log)
                      : null,
                ),
                if (logState.hasError)
                  TextButton.icon(
                    onPressed: () => ref.invalidate(todaysDailyLogProvider),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry loading check-in'),
                  ),
                const SizedBox(height: 16),
                const _SectionHeading('Your daily plan'),
                const SizedBox(height: 10),
                _DailyCard(
                  icon: _readinessIcon(plan.readiness.score),
                  accent: accent,
                  tint: dark
                      ? const Color(0xFF382631)
                      : const Color(0xFFF9E9F0),
                  label: 'Readiness',
                  title: plan.readiness.title,
                  detail: plan.readiness.primaryRecommendation,
                  action: 'See why',
                  onOpen: () => _showReadinessDetails(context, plan),
                ),
                const SizedBox(height: 10),
                _DailyCard(
                  icon: Icons.flag_outlined,
                  accent: accent,
                  label: 'Focus',
                  title: plan.topFocusTask?.title ?? 'Choose one priority',
                  detail: plan.topFocusTask == null
                      ? null
                      : plan.topFocusReason,
                  action: 'Open plan',
                  onOpen: () => context.go('/plan'),
                ),
                const SizedBox(height: 24),
                const NotificationPermissionInvitation(),
                const _SectionHeading('Wellness picks'),
                const SizedBox(height: 10),
                _DailyCard(
                  icon: Icons.restaurant_menu_rounded,
                  accent: dark
                      ? const Color(0xFFFBC1A7)
                      : AppColors.terracottaDark,
                  tint: dark
                      ? const Color(0xFF392A26)
                      : const Color(0xFFFAECE3),
                  label: '${recipe.mealType} · ${recipe.totalMinutes} min',
                  title: recipe.title,
                  detail: recipe.description,
                  action: 'Explore meals',
                  onOpen: () => context.go('/wellness?section=Meals'),
                  accessory: plan.meals.length > 1
                      ? IconButton(
                          tooltip: 'Next meal',
                          onPressed: () => setState(() => _mealIndex++),
                          icon: const Icon(Icons.swap_horiz_rounded),
                        )
                      : null,
                ),
                const SizedBox(height: 10),
                _DailyCard(
                  icon: Icons.directions_walk_rounded,
                  accent: dark ? AppColors.sageLight : AppColors.sageDark,
                  tint: dark
                      ? const Color(0xFF24322B)
                      : const Color(0xFFEAF2EC),
                  label: 'Movement · ${plan.workout.durationMinutes} min',
                  title: plan.workout.title,
                  detail: plan.workout.intensity,
                  action: 'Explore movement',
                  onOpen: () => context.go('/wellness?section=Movement'),
                ),
                const SizedBox(height: 10),
                _DailyCard(
                  icon: Icons.edit_note_rounded,
                  accent: accent,
                  label: 'Journal',
                  title: plan.journalPrompt,
                  action: 'Open journal',
                  onOpen: () => context.go('/wellness?section=Mind'),
                ),
                if (insights.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const _SectionHeading('Your patterns'),
                  const SizedBox(height: 10),
                  for (final insight in insights)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _InsightTile(insight: insight),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TodayHeader extends StatelessWidget {
  const _TodayHeader({required this.date, required this.name});

  final DateTime date;
  final String? name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final firstName = name?.trim().split(RegExp(r'\s+')).first;
    final format = DateFormat.MMMEd(Localizations.localeOf(context).toString());
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(format.format(date), style: theme.textTheme.labelLarge),
              const SizedBox(height: 2),
              Text(
                'Today',
                style: theme.textTheme.displayMedium?.copyWith(
                  fontSize: 36,
                  height: 1.05,
                ),
                semanticsLabel: 'Today',
              ),
              if (firstName != null && firstName.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text('Hi, $firstName', style: theme.textTheme.bodyMedium),
              ],
            ],
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF372632) : const Color(0xFFF5E4EC),
            shape: BoxShape.circle,
          ),
          child: NotificationBellButton(
            onPressed: () => context.push('/notifications'),
            iconColor: dark ? _lightRose : _rose,
          ),
        ),
      ],
    );
  }
}

class _CycleHero extends StatelessWidget {
  const _CycleHero({required this.snapshot, required this.onOpen});

  final CurrentCycleSnapshot snapshot;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final day = snapshot.cycleDay;
    final phase = snapshot.isPeriodActive
        ? EstimatedCyclePhase.menstrual
        : snapshot.hasEnoughData
        ? snapshot.phase
        : EstimatedCyclePhase.unknown;
    final activePhase = _ringPhases.indexOf(phase);
    final colors = dark
        ? const [
            Color(0xFFF39CB3),
            Color(0xFF9DD6B9),
            Color(0xFFF1C58B),
            Color(0xFFCAA4EF),
          ]
        : const [
            Color(0xFFC7577E),
            Color(0xFF559D81),
            Color(0xFFB67A32),
            Color(0xFF9862C6),
          ];
    final range = snapshot.nextPeriodRange;
    final format = DateFormat.MMMd(Localizations.localeOf(context).toString());
    final estimate = range == null
        ? null
        : range.start == range.end
        ? format.format(range.start)
        : '${format.format(range.start)} – ${format.format(range.end)}';
    final accent = dark ? _lightRose : _rose;
    final phaseTitle = activePhase < 0
        ? 'Phase unavailable'
        : '${phase.shortName} phase';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF38283F), Color(0xFF291D2A)]
              : const [Color(0xFFF1E9FA), Color(0xFFFFF5F8)],
        ),
        border: Border.all(
          color: dark ? AppColors.borderDark : const Color(0xFFEADDEE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 254),
              child: AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ExcludeSemantics(
                      child: CustomPaint(
                        painter: _PhaseRingPainter(
                          colors: colors,
                          activePhase: activePhase,
                          badgeFill: dark
                              ? const Color(0xFF35243B)
                              : Colors.white,
                        ),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: 0.65,
                      heightFactor: 0.62,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: SizedBox(
                          width: 150,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                snapshot.isPeriodActive
                                    ? 'Period in progress'
                                    : activePhase < 0
                                    ? 'Your cycle'
                                    : 'Estimated phase',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.labelMedium,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                phaseTitle,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  height: 1.1,
                                ),
                              ),
                              if (day != null) ...[
                                const SizedBox(height: 8),
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: dark
                                        ? const Color(0xFF603F69)
                                        : const Color(0xFFEBDDF3),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    child: Text(
                                      'Cycle Day $day',
                                      style: theme.textTheme.labelMedium,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 14,
            runSpacing: 7,
            children: [
              for (var index = 0; index < _ringPhases.length; index++)
                Semantics(
                  label:
                      '${_ringPhases[index].shortName} phase'
                      '${index == activePhase ? ', current phase' : ''}',
                  excludeSemantics: true,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        index == activePhase
                            ? Icons.check_circle_rounded
                            : Icons.circle,
                        size: index == activePhase ? 14 : 9,
                        color: colors[index],
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _ringPhases[index].shortName,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: index == activePhase
                              ? FontWeight.w800
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 13),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.water_drop_outlined, size: 21, color: accent),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (estimate != null) ...[
                        Text(
                          'Next period · estimated',
                          style: theme.textTheme.labelMedium,
                        ),
                        const SizedBox(height: 3),
                      ],
                      Text(
                        estimate ??
                            (day == null
                                ? 'Log your last period to see estimates.'
                                : 'Your next period estimate is unavailable.'),
                        style: theme.textTheme.titleMedium,
                      ),
                      if (estimate != null && day != null)
                        Text(
                          '${formatPredictionConfidence(snapshot.confidence)} confidence',
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: accent),
              onPressed: onOpen,
              icon: const Icon(Icons.calendar_month_outlined, size: 19),
              label: Text(
                day == null ? 'Open period tracker' : 'Open cycle calendar',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _ringPhases = [
  EstimatedCyclePhase.menstrual,
  EstimatedCyclePhase.follicular,
  EstimatedCyclePhase.ovulatoryWindow,
  EstimatedCyclePhase.luteal,
];

class _PhaseRingPainter extends CustomPainter {
  const _PhaseRingPainter({
    required this.colors,
    required this.activePhase,
    required this.badgeFill,
  });

  final List<Color> colors;
  final int activePhase;
  final Color badgeFill;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.404;
    final dial = Rect.fromCircle(center: center, radius: radius);
    final thickness = size.shortestSide * 0.083;
    const origin = -math.pi / 2;
    const span = math.pi / 2;
    const gap = 0.13;
    final brush = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var index = 0; index < colors.length; index++) {
      final start = origin + index * span + gap;
      final current = index == activePhase;
      if (current) {
        brush
          ..strokeWidth = thickness + 9
          ..color = colors[index].withValues(alpha: 0.14);
        canvas.drawArc(dial, start, span - 2 * gap, false, brush);
      }
      brush
        ..strokeWidth = thickness
        ..color = colors[index].withValues(alpha: current ? 0.89 : 0.50);
      canvas.drawArc(dial, start, span - 2 * gap, false, brush);
    }

    if (activePhase < 0) return;
    final angle = origin + (activePhase + 0.5) * span;
    final marker = center + Offset(math.cos(angle), math.sin(angle)) * radius;
    final badge = Path()
      ..addOval(Rect.fromCircle(center: marker, radius: thickness * 0.78));
    canvas.drawShadow(badge, const Color(0x6656284F), 4, false);
    canvas.drawPath(badge, Paint()..color = badgeFill);
    const flower = Icons.local_florist_rounded;
    final glyph = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(flower.codePoint),
        style: TextStyle(
          fontFamily: flower.fontFamily,
          package: flower.fontPackage,
          fontSize: thickness,
          color: colors[activePhase],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    glyph.paint(canvas, marker - Offset(glyph.width / 2, glyph.height / 2));
    glyph.dispose();
  }

  @override
  bool shouldRepaint(_PhaseRingPainter oldDelegate) =>
      oldDelegate.activePhase != activePhase ||
      oldDelegate.badgeFill != badgeFill ||
      oldDelegate.colors != colors;
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(label, style: Theme.of(context).textTheme.headlineMedium),
  );
}

class _CheckInCard extends StatelessWidget {
  const _CheckInCard({required this.log, required this.onOpen});

  final DailyLog? log;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final entry = log;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final accent = dark ? _lightRose : _rose;
    final values = [
      (Icons.bolt_outlined, 'Energy', '${entry?.energyLevel ?? 0}/5'),
      (Icons.favorite_border_rounded, 'Pain', '${entry?.painLevel ?? 0}/5'),
      (
        Icons.bedtime_outlined,
        'Sleep',
        entry?.sleepHours == null
            ? '—'
            : '${entry!.sleepHours!.toStringAsFixed(1)} h',
      ),
    ];
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Daily check-in', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 6),
          if (entry == null)
            Text(
              'Record your energy, pain and sleep.',
              style: theme.textTheme.bodyMedium,
            )
          else
            Wrap(
              spacing: 15,
              runSpacing: 6,
              children: [
                for (final (icon, name, value) in values)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 14, color: accent),
                      const SizedBox(width: 4),
                      Text('$name $value', style: theme.textTheme.bodySmall),
                    ],
                  ),
              ],
            ),
          const SizedBox(height: 10),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _rose,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 46),
            ),
            onPressed: onOpen,
            icon: Icon(
              entry == null ? Icons.add_rounded : Icons.edit_outlined,
              size: 18,
            ),
            label: Text(entry == null ? 'Log how you feel' : 'Edit check-in'),
          ),
        ],
      ),
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child, this.tint});

  final Widget child;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: tint ?? (dark ? AppColors.cardSurfaceDark : Colors.white),
        border: Border.all(
          color: dark ? AppColors.borderDark : const Color(0xFFEFE4E9),
        ),
      ),
      child: child,
    );
  }
}

class _DailyCard extends StatelessWidget {
  const _DailyCard({
    required this.icon,
    required this.accent,
    required this.label,
    required this.title,
    required this.action,
    required this.onOpen,
    this.detail,
    this.tint,
    this.accessory,
  });

  final IconData icon;
  final Color accent;
  final String label;
  final String title;
  final String action;
  final String? detail;
  final Color? tint;
  final Widget? accessory;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Surface(
      tint: tint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: accent.withValues(alpha: 0.15),
                foregroundColor: accent,
                child: Icon(icon, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(color: accent),
                ),
              ),
              if (accessory != null) accessory!,
            ],
          ),
          const SizedBox(height: 8),
          Text(title, style: theme.textTheme.headlineSmall),
          if (detail case final description?) ...[
            const SizedBox(height: 5),
            Text(description, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: 4),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: accent),
            onPressed: onOpen,
            label: Text(action),
            icon: const Icon(Icons.arrow_forward_rounded, size: 17),
            iconAlignment: IconAlignment.end,
          ),
        ],
      ),
    );
  }
}

void _showCheckIn(
  BuildContext context,
  WidgetRef ref,
  DateTime date,
  DailyLog? log,
) {
  var energy = (log?.energyLevel ?? 3).clamp(1, 5).toDouble();
  var pain = (log?.painLevel ?? 0).clamp(0, 5).toDouble();
  final originalSleep = log?.sleepHours;
  var sleepEnabled = originalSleep != null;
  final maxSleep = math.max(16.0, originalSleep ?? 0);
  var sleep = (originalSleep ?? 7.5).clamp(0.0, maxSleep);
  var saving = false;
  String? failure;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (context) => StatefulBuilder(
      builder: (context, update) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Daily check-in',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(MaterialLocalizations.of(context).formatFullDate(date)),
              const SizedBox(height: 14),
              _CheckInSlider(
                label: 'Energy',
                value: energy,
                minimum: 1,
                maximum: 5,
                onChanged: saving
                    ? null
                    : (value) => update(() => energy = value),
              ),
              _CheckInSlider(
                label: 'Pain',
                value: pain,
                minimum: 0,
                maximum: 5,
                onChanged: saving
                    ? null
                    : (value) => update(() => pain = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Include sleep'),
                value: sleepEnabled,
                onChanged: saving
                    ? null
                    : (value) => update(() => sleepEnabled = value),
              ),
              if (sleepEnabled)
                _CheckInSlider(
                  label: 'Sleep',
                  value: sleep,
                  minimum: 0,
                  maximum: maxSleep,
                  suffix: ' h',
                  onChanged: saving
                      ? null
                      : (value) => update(() => sleep = value),
                ),
              if (failure != null)
                Text(
                  failure!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: saving
                    ? null
                    : () async {
                        update(() {
                          saving = true;
                          failure = null;
                        });
                        try {
                          await ref
                              .read(cycleWorkspaceControllerProvider.notifier)
                              .saveDailyLog(
                                date: date,
                                flow: log?.flow ?? 'None',
                                pain: pain.round(),
                                mood: log?.mood ?? 'Neutral',
                                energy: energy.round(),
                                stress: log?.stressLevel ?? 3,
                                sleepQuality: log?.sleepQuality ?? 3,
                                sleepHours: sleepEnabled ? sleep : null,
                                water: log?.waterGlasses ?? 0,
                                symptoms: _savedSymptoms(log),
                                notes: log?.generalNotes,
                              );
                          if (context.mounted) Navigator.of(context).pop();
                        } catch (_) {
                          if (context.mounted) {
                            update(() {
                              saving = false;
                              failure =
                                  'Could not finish saving your check-in. Please try again.';
                            });
                          }
                        }
                      },
                icon: const Icon(Icons.check_rounded),
                label: Text(saving ? 'Saving…' : 'Save check-in'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

List<String> _savedSymptoms(DailyLog? log) {
  if (log == null) return const [];
  try {
    final decoded = jsonDecode(log.customSymptomsJson);
    return decoded is List ? decoded.whereType<String>().toList() : const [];
  } on FormatException {
    return const [];
  }
}

class _CheckInSlider extends StatelessWidget {
  const _CheckInSlider({
    required this.label,
    required this.value,
    required this.minimum,
    required this.maximum,
    required this.onChanged,
    this.suffix = '',
  });

  final String label;
  final double value;
  final double minimum;
  final double maximum;
  final String suffix;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    final total = suffix.isEmpty
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label · $total$suffix',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        Slider(
          value: value,
          min: minimum,
          max: maximum,
          divisions: ((maximum - minimum) * (suffix.isEmpty ? 1 : 2)).round(),
          label: '$label $total$suffix',
          semanticFormatterCallback: (value) =>
              '$label ${value.toStringAsFixed(suffix.isEmpty ? 0 : 1)}$suffix',
          onChanged: onChanged,
        ),
      ],
    );
  }
}

void _showReadinessDetails(BuildContext context, DailyQuevaaPlan plan) {
  final readiness = plan.readiness;
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final accent = _readinessAccent(readiness.score, isDark);
  final confidenceText = switch (readiness.confidence) {
    ReadinessConfidence.personal => 'Personal pattern',
    ReadinessConfidence.current => 'Current check-in',
    ReadinessConfidence.low => 'Learning mode',
  };

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: isDark ? AppColors.cardSurfaceDark : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) {
      return SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.borderDark
                        : AppColors.borderLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: isDark ? 0.18 : 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(_readinessIcon(readiness.score), color: accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Why ${readiness.label} today?',
                          style: theme.textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$confidenceText · score ${readiness.internalScore}/100',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(readiness.description, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 18),
              _FactorSection(
                title: 'Supporting your capacity',
                factors: readiness.supportingFactors,
                icon: Icons.check_circle_rounded,
                color: isDark ? AppColors.sageLight : AppColors.sagePrimary,
                emptyText: 'No strong supporting signals yet.',
              ),
              const SizedBox(height: 14),
              _FactorSection(
                title: 'Plan around this',
                factors: readiness.limitingFactors,
                icon: Icons.info_rounded,
                color: isDark
                    ? AppColors.terracottaLight
                    : AppColors.terracottaPrimary,
                emptyText: 'No major limiting signals in this check-in.',
              ),
              const SizedBox(height: 14),
              _DetailCallout(
                title: 'Pattern',
                body: readiness.historyInsight,
                icon: Icons.timeline_rounded,
                color: accent,
              ),
              const SizedBox(height: 12),
              _DetailCallout(
                title: 'Recommendation',
                body: readiness.primaryRecommendation,
                icon: Icons.route_rounded,
                color: accent,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.go('/plan');
                  },
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text("Adjust Today's Plan"),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _FactorSection extends StatelessWidget {
  final String title;
  final List<ReadinessFactor> factors;
  final IconData icon;
  final Color color;
  final String emptyText;

  const _FactorSection({
    required this.title,
    required this.factors,
    required this.icon,
    required this.color,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (factors.isEmpty)
          Text(emptyText, style: theme.textTheme.bodySmall)
        else
          ...factors.map(
            (factor) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: color, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: theme.textTheme.bodySmall,
                        children: [
                          TextSpan(
                            text: '${factor.label}: ',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          TextSpan(text: factor.detail),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _DetailCallout extends StatelessWidget {
  final String title;
  final String body;
  final IconData icon;
  final Color color;

  const _DetailCallout({
    required this.title,
    required this.body,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(body, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Color _readinessAccent(ReadinessScore score, bool isDark) {
  return switch (score) {
    ReadinessScore.restore =>
      isDark ? AppColors.terracottaLight : AppColors.terracottaPrimary,
    ReadinessScore.gentle => isDark ? AppColors.sageLight : AppColors.sageDark,
    ReadinessScore.steady => AppColors.warmGoldPrimary,
    ReadinessScore.focused => AppColors.waterBlue,
    ReadinessScore.strong =>
      isDark ? AppColors.purpleLight : AppColors.purplePrimary,
  };
}

IconData _readinessIcon(ReadinessScore score) {
  return switch (score) {
    ReadinessScore.restore => Icons.nights_stay_rounded,
    ReadinessScore.gentle => Icons.self_improvement_rounded,
    ReadinessScore.steady => Icons.spa_rounded,
    ReadinessScore.focused => Icons.psychology_rounded,
    ReadinessScore.strong => Icons.bolt_rounded,
  };
}

class _InsightTile extends StatelessWidget {
  final TransparentInsight insight;

  const _InsightTile({required this.insight});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      color: isDark ? AppColors.cycleLutealDark : AppColors.purpleContainer,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              insight.title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.purpleLight : AppColors.purplePrimary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              insight.observation,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              insight.context,
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
