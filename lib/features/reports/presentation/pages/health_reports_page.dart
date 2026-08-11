import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../application/health_report_provider.dart';
import '../../domain/health_report_model.dart';

class HealthReportsPage extends ConsumerWidget {
  const HealthReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(healthReportOptionsProvider);
    final modelAsync = ref.watch(healthReportModelProvider);
    final generated = ref.watch(generatedHealthReportProvider);
    final controllerState = ref.watch(healthReportControllerProvider);
    final controller = ref.read(healthReportControllerProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ref.listen(healthReportControllerProvider, (previous, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.error.toString())));
      }
    });

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgWarmDark : AppColors.bgWarmCream,
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/me'),
        ),
        title: const Text('Health Reports'),
      ),
      body: modelAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: "We couldn't prepare health reports.",
          onRetry: () => ref.invalidate(healthReportModelProvider),
        ),
        data: (model) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              "Create a private summary of the health information you've logged in Quevaa.",
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            _ReportTypeCard(options: options),
            const SizedBox(height: 12),
            _RangeCard(options: options),
            const SizedBox(height: 12),
            _PrivacyCard(
              options: options,
              ttcAvailable: model.insights.ttcPattern != null,
            ),
            const SizedBox(height: 12),
            _PreviewCard(model: model),
            const SizedBox(height: 12),
            _GenerateCard(
              model: model,
              generated: generated,
              saving: controllerState.isLoading,
              onGenerate: controller.generatePdf,
              onPreview: generated == null
                  ? null
                  : () => context.push('/reports/preview', extra: generated),
              onShare: generated == null
                  ? null
                  : controller.shareGeneratedReport,
              onExport: generated == null
                  ? null
                  : controller.shareGeneratedReport,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportTypeCard extends ConsumerWidget {
  final HealthReportOptions options;

  const _ReportTypeCard({required this.options});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _ReportCard(
      title: 'Report type',
      child: SegmentedButton<HealthReportType>(
        segments: const [
          ButtonSegment(
            value: HealthReportType.cycleSummary,
            label: Text('Cycle'),
            icon: Icon(Icons.calendar_month_rounded),
          ),
          ButtonSegment(
            value: HealthReportType.detailedHealth,
            label: Text('Detailed'),
            icon: Icon(Icons.description_rounded),
          ),
        ],
        selected: {options.type},
        onSelectionChanged: (selection) {
          ref.read(healthReportOptionsProvider.notifier).state = options
              .copyWith(type: selection.first);
          ref.read(generatedHealthReportProvider.notifier).state = null;
        },
      ),
    );
  }
}

class _RangeCard extends ConsumerWidget {
  final HealthReportOptions options;

  const _RangeCard({required this.options});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _ReportCard(
      title: 'Report range',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButton<HealthReportRange>(
            value: options.range,
            isExpanded: true,
            items: [
              for (final range in HealthReportRange.values)
                DropdownMenuItem(value: range, child: Text(range.label)),
            ],
            onChanged: (value) {
              if (value == null) return;
              ref.read(healthReportOptionsProvider.notifier).state = options
                  .copyWith(range: value);
              ref.read(generatedHealthReportProvider.notifier).state = null;
            },
          ),
          if (options.range == HealthReportRange.custom) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _pickDate(context, ref, start: true),
                  icon: const Icon(Icons.event_rounded),
                  label: Text(_dateLabel(options.customStartDate, 'Start')),
                ),
                OutlinedButton.icon(
                  onPressed: () => _pickDate(context, ref, start: false),
                  icon: const Icon(Icons.event_available_rounded),
                  label: Text(_dateLabel(options.customEndDate, 'End')),
                ),
              ],
            ),
            if (!options.hasValidDateRange) ...[
              const SizedBox(height: 8),
              Text(
                'Select a start and end date for this report.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _pickDate(
    BuildContext context,
    WidgetRef ref, {
    required bool start,
  }) async {
    final current = start ? options.customStartDate : options.customEndDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    ref.read(healthReportOptionsProvider.notifier).state = start
        ? options.copyWith(customStartDate: picked)
        : options.copyWith(customEndDate: picked);
    ref.read(generatedHealthReportProvider.notifier).state = null;
  }

  String _dateLabel(DateTime? date, String fallback) {
    if (date == null) return fallback;
    return DateFormat('d MMM yyyy').format(date);
  }
}

class _PrivacyCard extends ConsumerWidget {
  final HealthReportOptions options;
  final bool ttcAvailable;

  const _PrivacyCard({required this.options, required this.ttcAvailable});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void update(HealthReportOptions next) {
      ref.read(healthReportOptionsProvider.notifier).state = next;
      ref.read(generatedHealthReportProvider.notifier).state = null;
    }

    return _ReportCard(
      title: 'Privacy controls',
      child: Column(
        children: [
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: options.includeNotes,
            onChanged: (value) =>
                update(options.copyWith(includeNotes: value ?? false)),
            title: const Text('Include daily notes'),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: options.includeJournal,
            onChanged: (value) =>
                update(options.copyWith(includeJournal: value ?? false)),
            title: const Text('Include journal excerpts'),
            subtitle: const Text('Off by default.'),
          ),
          if (ttcAvailable)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: options.includeTtc,
              onChanged: (value) =>
                  update(options.copyWith(includeTtc: value ?? false)),
              title: const Text('Include TTC observations'),
              subtitle: const Text(
                'BBT, LH, cervical mucus and pregnancy tests.',
              ),
            ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: options.includeIntimacy,
            onChanged: (value) =>
                update(options.copyWith(includeIntimacy: value ?? false)),
            title: const Text('Include intimacy'),
            subtitle: const Text('Sensitive and off by default.'),
          ),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final HealthReportModel model;

  const _PreviewCard({required this.model});

  @override
  Widget build(BuildContext context) {
    final format = DateFormat('d MMM yyyy');
    final period = model.periodStart == null || model.periodEnd == null
        ? 'Not enough history'
        : '${format.format(model.periodStart!)} - ${format.format(model.periodEnd!)}';
    return _ReportCard(
      title: 'Report preview',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Period: $period'),
          const SizedBox(height: 12),
          Text('Includes', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final section in model.includedSections)
            _LineIcon(icon: Icons.check_rounded, text: section),
          if (model.excludedSensitiveSections.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Excluded by default',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final section in model.excludedSensitiveSections)
              _LineIcon(icon: Icons.lock_outline_rounded, text: section),
          ],
          if (!model.options.hasValidDateRange) ...[
            const SizedBox(height: 12),
            const Text(
              'Choose a valid custom date range before creating this report.',
            ),
          ] else if (!model.canGenerate) ...[
            const SizedBox(height: 12),
            const Text(
              "There's not enough cycle history to create this report yet. Log at least one period to create a basic cycle summary.",
            ),
          ],
        ],
      ),
    );
  }
}

class _GenerateCard extends StatelessWidget {
  final HealthReportModel model;
  final GeneratedHealthReport? generated;
  final bool saving;
  final VoidCallback onGenerate;
  final VoidCallback? onPreview;
  final VoidCallback? onShare;
  final VoidCallback? onExport;

  const _GenerateCard({
    required this.model,
    required this.generated,
    required this.saving,
    required this.onGenerate,
    required this.onPreview,
    required this.onShare,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return _ReportCard(
      title: 'Generate',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilledButton.icon(
            onPressed: saving || !model.canGenerate ? null : onGenerate,
            icon: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_rounded),
            label: Text(saving ? 'Generating...' : 'Generate PDF'),
          ),
          if (generated != null) ...[
            const SizedBox(height: 12),
            Text(generated!.filename),
            Text('${generated!.fileSizeBytes} bytes'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: onPreview,
                  icon: const Icon(Icons.visibility_rounded),
                  label: const Text('Preview'),
                ),
                OutlinedButton.icon(
                  onPressed: onShare,
                  icon: const Icon(Icons.ios_share_rounded),
                  label: const Text('Share'),
                ),
                OutlinedButton.icon(
                  onPressed: onExport,
                  icon: const Icon(Icons.save_alt_rounded),
                  label: const Text('Save / Export'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _ReportCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _LineIcon extends StatelessWidget {
  final IconData icon;
  final String text;

  const _LineIcon({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.sagePrimary),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
