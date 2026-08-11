import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../../core/analytics/app_logger.dart';
import '../../insights/domain/cycle_insights_analyzer.dart';
import 'health_report_model.dart';

class PdfHealthReportGenerator {
  static Future<Uint8List> generateHealthReport(HealthReportModel model) async {
    AppLogger.info('Generating local Quevaa health report PDF');
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Quevaa health report',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          ],
        ),
        build: (context) {
          final insights = model.insights;
          return [
            _header(model),
            pw.SizedBox(height: 16),
            _notice(
              'Generated from information recorded by the user in Quevaa. User-reported data and Quevaa-calculated patterns are labelled separately.',
            ),
            pw.SizedBox(height: 18),
            _sectionTitle('User reported'),
            _keyValueTable([
              ['Report type', model.options.type.label],
              ['Report period', _range(model.periodStart, model.periodEnd)],
              ['Confirmed period records', '${insights.completedPeriodCount}'],
              ['Included sections', model.includedSections.join(', ')],
              [
                'Excluded sensitive sections',
                model.excludedSensitiveSections.isEmpty
                    ? 'None'
                    : model.excludedSensitiveSections.join(', '),
              ],
            ]),
            pw.SizedBox(height: 16),
            _sectionTitle('Calculated by Quevaa'),
            _keyValueTable([
              ['Tracked cycles', '${insights.trackedCycleCount}'],
              ['Average cycle', insights.averageCycleLabel],
              ['Cycle range', insights.cycleRangeLabel],
              ['Typical period', insights.averagePeriodLabel],
              ['Regularity label', insights.regularityLabel],
              [
                'Cycle variability',
                insights.cycleVariability == null
                    ? 'Learning'
                    : '${insights.cycleVariability!.toStringAsFixed(1)} days',
              ],
            ]),
            if (insights.cycleLengths.isNotEmpty) ...[
              pw.SizedBox(height: 16),
              _sectionTitle('Cycle history'),
              pw.TableHelper.fromTextArray(
                headers: const ['Cycle', 'Start', 'Length'],
                data: insights.cycleLengths.map((point) {
                  return [
                    'Cycle ${point.cycleNumber}',
                    _date(point.startDate),
                    '${point.lengthDays} days',
                  ];
                }).toList(),
              ),
            ],
            if (insights.periodDurations.isNotEmpty) ...[
              pw.SizedBox(height: 16),
              _sectionTitle('Period duration'),
              pw.Text(
                'Recent confirmed durations: ${insights.periodDurations.map((d) => '$d days').join(', ')}',
              ),
            ],
            if (insights.symptomPatterns.isNotEmpty) ...[
              pw.SizedBox(height: 16),
              _sectionTitle('Symptoms'),
              ...insights.symptomPatterns.map((pattern) {
                return pw.Bullet(
                  text:
                      '${pattern.symptom}: ${pattern.loggedDays} logged day(s), ${pattern.timingSummary}. ${pattern.explanation}',
                );
              }),
            ],
            if (model.options.type == HealthReportType.detailedHealth) ...[
              pw.SizedBox(height: 16),
              _sectionTitle('Wellbeing patterns'),
              _metricBullet(insights.energyPattern),
              _metricBullet(insights.painPattern),
              _metricBullet(insights.sleepPattern),
              pw.Bullet(
                text:
                    '${insights.moodPattern.name}: ${insights.moodPattern.summary} ${insights.moodPattern.explanation}',
              ),
              pw.Bullet(
                text:
                    '${insights.stressPattern.name}: ${insights.stressPattern.summary} ${insights.stressPattern.explanation}',
              ),
            ],
            if (model.options.includeTtc && insights.ttcPattern != null) ...[
              pw.SizedBox(height: 16),
              _sectionTitle('Optional TTC observations'),
              pw.Text(insights.ttcPattern!.summary),
              pw.Text(
                'Estimated fertile windows or ovulation dates, where shown in Quevaa, are calculated estimates and not confirmed ovulation.',
              ),
            ],
            if (model.options.includeJournal || model.options.includeIntimacy)
              _notice(
                'Sensitive optional sections were selected. Quevaa does not include journal or intimacy details by default.',
              ),
            pw.SizedBox(height: 24),
            _notice(
              'This report summarizes information recorded in Quevaa and calculated patterns. It is not a medical diagnosis or substitute for professional medical care.',
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Generates a doctor-friendly PDF health summary for gynecologist/medical consultation.
  static Future<Uint8List> generateDoctorReport({
    required String userName,
    required DateTime startDate,
    required DateTime endDate,
    required List<Map<String, dynamic>> periodLogs,
    required List<Map<String, dynamic>> symptomLogs,
    required String predictionConfidence,
    required bool includeMedications,
    required bool includeNotes,
  }) async {
    AppLogger.info('Generating PDF doctor health report');

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(32),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Quevaa Health Summary Report',
                      style: const pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Algorithm v1.0.0',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
                pw.Divider(thickness: 1),
                pw.SizedBox(height: 12),

                // Patient Info & Date Range
                pw.Text(
                  'Patient Name: $userName',
                  style: const pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Report Window: ${startDate.day}/${startDate.month}/${startDate.year} – ${endDate.day}/${endDate.month}/${endDate.year}',
                ),
                pw.Text('Cycle Prediction Confidence: $predictionConfidence'),
                pw.SizedBox(height: 20),

                // Period Summary Table
                pw.Text(
                  'Confirmed Period & Cycle Records',
                  style: const pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.TableHelper.fromTextArray(
                  headers: [
                    'Date',
                    'Flow Intensity',
                    'Pain Level (0-5)',
                    'Duration',
                  ],
                  data: periodLogs.map((log) {
                    return [
                      log['date'].toString(),
                      log['flow'].toString(),
                      log['pain'].toString(),
                      '${log['duration']} days',
                    ];
                  }).toList(),
                ),
                pw.SizedBox(height: 20),

                // Symptom Summary
                pw.Text(
                  'Logged Symptom Trends',
                  style: const pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                if (symptomLogs.isEmpty)
                  pw.Text(
                    'No symptom trends logged for this window.',
                    style: const pw.TextStyle(color: PdfColors.grey700),
                  )
                else
                  ...symptomLogs.map((log) {
                    final category =
                        log['category'] ??
                        log['symptom'] ??
                        log['name'] ??
                        'Logged Entry';
                    final details =
                        log['details'] ?? log['severity'] ?? log['value'] ?? '';
                    final textStr = details.toString().isNotEmpty
                        ? '$category: $details'
                        : '$category';
                    return pw.Bullet(text: textStr);
                  }),
                pw.SizedBox(height: 24),

                // Clinical Disclaimer Footer
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Text(
                    'CLINICAL DISCLAIMER: This document compiles self-reported user logs and range-based statistical cycle estimates. It is generated for medical consultation and does not constitute a diagnostic evaluation or medical advice.',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey800,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _header(HealthReportModel model) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'QUEVAA HEALTH SUMMARY',
          style: const pw.TextStyle(
            fontSize: 22,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text('Generated: ${_date(model.generatedAt)}'),
        pw.Text(
          'User: ${model.userName.trim().isEmpty ? 'Not specified' : model.userName.trim()}',
        ),
        pw.Text('Report period: ${_range(model.periodStart, model.periodEnd)}'),
        pw.Text('Tracked cycles: ${model.insights.trackedCycleCount}'),
        pw.Divider(thickness: 1),
      ],
    );
  }

  static pw.Widget _sectionTitle(String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(
        value.toUpperCase(),
        style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static pw.Widget _keyValueTable(List<List<String>> rows) {
    return pw.TableHelper.fromTextArray(
      cellAlignment: pw.Alignment.centerLeft,
      headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headers: const ['Field', 'Value'],
      data: rows,
    );
  }

  static pw.Widget _metricBullet(MetricPattern pattern) {
    return pw.Bullet(
      text:
          '${pattern.name}: ${pattern.summary} ${pattern.explanation}${pattern.average == null ? '' : ' Average: ${pattern.average!.toStringAsFixed(1)}.'}',
    );
  }

  static pw.Widget _notice(String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Text(
        value,
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
      ),
    );
  }

  static String _range(DateTime? start, DateTime? end) {
    if (start == null || end == null) return 'Not enough history';
    return '${_date(start)} - ${_date(end)}';
  }

  static String _date(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
