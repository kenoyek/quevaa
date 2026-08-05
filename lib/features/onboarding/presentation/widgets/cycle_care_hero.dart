import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../app/theme/app_colors.dart';

class CycleCareHero extends StatelessWidget {
  final double height;

  const CycleCareHero({super.key, this.height = 300});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [
                    Color(0xFF3A2332),
                    Color(0xFF23141E),
                    Color(0xFF4A2A31),
                  ]
                : const [
                    Color(0xFFFFF7F3),
                    Color(0xFFFDF0EF),
                    Color(0xFFEAF2ED),
                  ],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.deepPlum.withValues(alpha: isDark ? 0.28 : 0.10),
              blurRadius: 28,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _CycleCarePainter(isDark: isDark)),
              ),
              const _CentralCareFigure().animate().scale(
                begin: const Offset(0.985, 0.985),
                end: const Offset(1, 1),
                duration: 900.ms,
                curve: Curves.easeOutCubic,
              ),
              const Positioned(
                top: 28,
                left: 34,
                child: _CareIcon(
                  icon: Icons.water_drop_rounded,
                  color: AppColors.mutedRose,
                  background: AppColors.mutedRoseContainer,
                ),
              ),
              const Positioned(
                top: 34,
                right: 42,
                child: _CareIcon(
                  icon: Icons.spa_rounded,
                  color: AppColors.sageDark,
                  background: AppColors.sageContainer,
                ),
              ),
              const Positioned(
                bottom: 36,
                left: 46,
                child: _CareIcon(
                  icon: Icons.nightlight_round,
                  color: AppColors.deepPlum,
                  background: AppColors.deepPlumContainer,
                ),
              ),
              const Positioned(
                bottom: 30,
                right: 34,
                child: _CareIcon(
                  icon: Icons.health_and_safety_rounded,
                  color: AppColors.terracottaDark,
                  background: AppColors.terracottaContainer,
                ),
              ),
              Positioned(
                bottom: 22,
                child: const _CyclePhasePills()
                    .animate()
                    .fadeIn(duration: 600.ms, delay: 350.ms)
                    .slideY(begin: 0.18, end: 0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CentralCareFigure extends StatelessWidget {
  const _CentralCareFigure();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 168,
      width: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 136,
            height: 136,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.78),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.14)
                    : Colors.white,
                width: 1.4,
              ),
            ),
          ),
          Positioned(
            top: 30,
            child: Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: Color(0xFF6B4D60),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 38,
            child: Container(
              width: 36,
              height: 34,
              decoration: const BoxDecoration(
                color: Color(0xFFD8A38E),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 78,
            child: Container(
              width: 82,
              height: 70,
              decoration: const BoxDecoration(
                color: AppColors.terracottaPrimary,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(42),
                  topRight: Radius.circular(42),
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
            ),
          ),
          Positioned(
            top: 90,
            child: Icon(
              Icons.favorite_rounded,
              color: Colors.white.withValues(alpha: 0.92),
              size: 28,
            ),
          ),
          Positioned(
            bottom: 18,
            child: Container(
              width: 104,
              height: 18,
              decoration: BoxDecoration(
                color: AppColors.warmGold.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CareIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color background;

  const _CareIcon({
    required this.icon,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
          height: 48,
          width: 48,
          decoration: BoxDecoration(
            color: background,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.74),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.16),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(icon, color: color, size: 24),
        )
        .animate()
        .fadeIn(duration: 450.ms)
        .moveY(begin: -8, end: 0, duration: 700.ms, curve: Curves.easeOutCubic);
  }
}

class _CyclePhasePills extends StatelessWidget {
  const _CyclePhasePills();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PhaseDot(color: AppColors.mutedRose),
          _PhaseDot(color: AppColors.terracottaLight),
          _PhaseDot(color: AppColors.sagePrimary),
          _PhaseDot(color: AppColors.deepPlumLight),
        ],
      ),
    );
  }
}

class _PhaseDot extends StatelessWidget {
  final Color color;

  const _PhaseDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _CycleCarePainter extends CustomPainter {
  final bool isDark;

  const _CycleCarePainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 4);
    final radius = math.min(size.width, size.height) * 0.36;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..color = (isDark ? Colors.white : AppColors.deepPlum).withValues(
        alpha: isDark ? 0.08 : 0.07,
      );

    canvas.drawCircle(center, radius, trackPaint);

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius);
    final segments = [
      (AppColors.mutedRose, -math.pi / 2, math.pi * 0.42),
      (AppColors.terracottaPrimary, math.pi * -0.04, math.pi * 0.34),
      (AppColors.sagePrimary, math.pi * 0.42, math.pi * 0.32),
      (AppColors.deepPlumLight, math.pi * 0.86, math.pi * 0.40),
    ];

    for (final segment in segments) {
      arcPaint.color = segment.$1.withValues(alpha: isDark ? 0.86 : 0.72);
      canvas.drawArc(rect, segment.$2, segment.$3, false, arcPaint);
    }

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = (isDark ? Colors.white : AppColors.deepPlum).withValues(
        alpha: isDark ? 0.08 : 0.06,
      );

    final path = Path()
      ..moveTo(-12, size.height * 0.78)
      ..cubicTo(
        size.width * 0.22,
        size.height * 0.60,
        size.width * 0.36,
        size.height * 0.96,
        size.width * 0.56,
        size.height * 0.76,
      )
      ..cubicTo(
        size.width * 0.72,
        size.height * 0.60,
        size.width * 0.86,
        size.height * 0.82,
        size.width + 16,
        size.height * 0.64,
      );
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _CycleCarePainter oldDelegate) {
    return oldDelegate.isDark != isDark;
  }
}
