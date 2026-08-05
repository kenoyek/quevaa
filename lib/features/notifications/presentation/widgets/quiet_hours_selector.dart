import 'package:flutter/material.dart';

class QuietHoursSelector extends StatelessWidget {
  final int startMinutes;
  final int endMinutes;
  final ValueChanged<int> onStartChanged;
  final ValueChanged<int> onEndChanged;

  const QuietHoursSelector({
    super.key,
    required this.startMinutes,
    required this.endMinutes,
    required this.onStartChanged,
    required this.onEndChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TimeTile(
          label: 'Quiet hours start',
          minutes: startMinutes,
          onChanged: onStartChanged,
        ),
        _TimeTile(
          label: 'Quiet hours end',
          minutes: endMinutes,
          onChanged: onEndChanged,
        ),
      ],
    );
  }
}

class _TimeTile extends StatelessWidget {
  final String label;
  final int minutes;
  final ValueChanged<int> onChanged;

  const _TimeTile({
    required this.label,
    required this.minutes,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Text(time.format(context)),
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time,
        );
        if (picked != null) {
          onChanged(picked.hour * 60 + picked.minute);
        }
      },
    );
  }
}
