import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../../domain/health_report_model.dart';

class HealthReportPreviewPage extends StatelessWidget {
  final GeneratedHealthReport report;

  const HealthReportPreviewPage({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/reports'),
        ),
        title: Text(report.filename),
      ),
      body: PdfPreview(
        build: (_) async => report.bytes,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        pdfFileName: report.filename,
      ),
    );
  }
}
