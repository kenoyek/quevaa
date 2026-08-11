import 'package:flutter/material.dart';

class QuietHoursSelector extends StatelessWidget {
  final int startMinutes;
  final int endMinutes;
  final ValueChanged<int>? onStartChanged;
  final ValueChanged<int>? onEndChanged;
  final ValueChanged<int>? onStartChangeEnd;
  final ValueChanged<int>? onEndChangeEnd;

  const QuietHoursSelector({
    super.key,
    required this.startMinutes,
    required this.endMinutes,
    required this.onStartChanged,
    required this.onEndChanged,
    this.onStartChangeEnd,
    this.onEndChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onStartChanged != null && onEndChanged != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        _TimeSlider(
          label: 'Start',
          minutes: startMinutes,
          enabled: enabled,
          onChanged: onStartChanged,
          onChangeEnd: onStartChangeEnd ?? onStartChanged,
        ),
        _TimeSlider(
          label: 'End',
          minutes: endMinutes,
          enabled: enabled,
          onChanged: onEndChanged,
          onChangeEnd: onEndChangeEnd ?? onEndChanged,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            _summary(context),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  String _summary(BuildContext context) {
    final start = _formatMinutes(context, startMinutes);
    final end = _formatMinutes(context, endMinutes);
    final crossesMidnight = startMinutes > endMinutes;
    return crossesMidnight
        ? 'Quiet from $start to $end overnight'
        : 'Quiet from $start to $end';
  }
}

class _TimeSlider extends StatelessWidget {
  final String label;
  final int minutes;
  final bool enabled;
  final ValueChanged<int>? onChanged;
  final ValueChanged<int>? onChangeEnd;

  const _TimeSlider({
    required this.label,
    required this.minutes,
    required this.enabled,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = _roundToQuarterHour(minutes).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(_formatMinutes(context, minutes)),
          ],
        ),
        Slider(
          value: normalized,
          min: 0,
          max: 24 * 60 - 15,
          divisions: 95,
          label: _formatMinutes(context, normalized.round()),
          onChanged: !enabled || onChanged == null
              ? null
              : (value) => onChanged!(_roundToQuarterHour(value.round())),
          onChangeEnd: !enabled || onChangeEnd == null
              ? null
              : (value) => onChangeEnd!(_roundToQuarterHour(value.round())),
        ),
      ],
    );
  }
}

int _roundToQuarterHour(int minutes) {
  return ((minutes / 15).round() * 15).clamp(0, 24 * 60 - 15);
}

String _formatMinutes(BuildContext context, int minutes) {
  final clamped = minutes.clamp(0, 24 * 60 - 15);
  final time = TimeOfDay(hour: clamped ~/ 60, minute: clamped % 60);
  return time.format(context);
}
