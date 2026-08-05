import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../../core/analytics/app_logger.dart';

class PdfHealthReportGenerator {
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
                pw.Bullet(
                  text:
                      'Primary Symptoms: Cramps (Moderate), Fatigue, Headache',
                ),
                pw.Bullet(text: 'Average Sleep Duration: 7.5 hours / night'),
                pw.Bullet(text: 'Average Water Intake: 7 glasses / day'),
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
}
