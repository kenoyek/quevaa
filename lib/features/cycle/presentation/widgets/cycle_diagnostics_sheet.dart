import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/models/prediction_confidence.dart';
import '../../application/cycle_workspace_provider.dart';
import '../../domain/models/estimated_cycle_phase.dart';

void showCycleDiagnosticsSheet(BuildContext context) {
  if (!kDebugMode) return;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const CycleDiagnosticsSheet(),
  );
}

class CycleDiagnosticsSheet extends ConsumerWidget {
  const CycleDiagnosticsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(currentCycleSnapshotProvider);
    final history = ref.watch(periodHistoryProvider).valueOrNull ?? const [];
    final df = DateFormat('yyyy-MM-dd');

    final lastPeriodStartStr = snapshot.currentPeriodStart != null
        ? df.format(snapshot.currentPeriodStart!)
        : 'None recorded';

    final nextPeriodRangeStr = snapshot.nextPeriodRange != null
        ? '${df.format(snapshot.nextPeriodRange!.start)} – ${df.format(snapshot.nextPeriodRange!.end)}'
        : 'N/A';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.deepPlum,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Cycle Calculation Diagnostics',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DiagRow('Local As-Of Date', df.format(snapshot.asOfDate)),
              _DiagRow('Last Confirmed Period Start', lastPeriodStartStr),
              _DiagRow('Completed Cycles Count', '${history.length}'),
              _DiagRow(
                'Current Cycle Day',
                snapshot.cycleDay != null ? 'Day ${snapshot.cycleDay}' : 'N/A',
              ),
              _DiagRow('Current Phase', snapshot.phase.label),
              _DiagRow('Next Period Range', nextPeriodRangeStr),
              _DiagRow(
                'Prediction Confidence',
                formatPredictionConfidence(snapshot.confidence),
              ),
              _DiagRow(
                'Has Enough Data',
                snapshot.hasEnoughData ? 'Yes' : 'No',
              ),
              _DiagRow(
                'Is Period Active',
                snapshot.isPeriodActive ? 'Yes' : 'No',
              ),
              _DiagRow(
                'Is TTC Mode Enabled',
                snapshot.isTtcEnabled ? 'Yes' : 'No',
              ),
              _DiagRow(
                'Calculation Version',
                'v${snapshot.calculationVersion}',
              ),
              const _DiagRow('Source Provider', 'currentCycleSnapshotProvider'),
              _DiagRow(
                'Last Recalculation',
                DateFormat('HH:mm:ss').format(DateTime.now()),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiagRow extends StatelessWidget {
  final String label;
  final String value;

  const _DiagRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
