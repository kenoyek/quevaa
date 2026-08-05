import 'package:flutter_test/flutter_test.dart';
import 'package:quevaa/core/notifications/notification_service.dart';
import 'package:quevaa/features/journal/domain/journal_service.dart';
import 'package:quevaa/features/reports/domain/pdf_health_report_generator.dart';
import 'package:quevaa/features/subscription/domain/partner_sharing_service.dart';

void main() {
  group('Phases 10-13 Advanced Features Unit Tests', () {
    test(
      'Phase 10: Local journal search filters entries without cloud transmission',
      () {
        final entries = [
          {
            'title': 'Morning Thoughts',
            'content': 'Feeling energised after plantain porridge',
            'mood': 'Calm',
          },
          {
            'title': 'Evening Reflection',
            'content': 'Mild cramps during workday',
            'mood': 'Fatigued',
          },
        ];

        final results = JournalService.searchLocalJournal(
          entries: entries,
          query: 'cramps',
        );
        expect(results.length, 1);
        expect(results.first['title'], 'Evening Reflection');
      },
    );

    test(
      'Phase 11: NotificationPrivacyMode formats discreet notifications',
      () {
        final explicitContent = NotificationService.formatNotificationContent(
          explicitTitle: 'Period Due',
          explicitBody: 'Your period may begin in 3 days.',
          mode: NotificationPrivacyMode.explicit,
        );
        expect(explicitContent['body'], 'Your period may begin in 3 days.');

        final discreetContent = NotificationService.formatNotificationContent(
          explicitTitle: 'Period Due',
          explicitBody: 'Your period may begin in 3 days.',
          mode: NotificationPrivacyMode.discreet,
        );
        expect(discreetContent['body']!.contains('check-in is ready'), true);
        expect(discreetContent['body']!.contains('period'), false);
      },
    );

    test(
      'Phase 12: Doctor PDF Report Generator creates valid PDF document bytes',
      () async {
        final pdfBytes = await PdfHealthReportGenerator.generateDoctorReport(
          userName: 'Adaora',
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2026, 3, 31),
          periodLogs: [
            {'date': '2026-01-10', 'flow': 'Medium', 'pain': 2, 'duration': 5},
          ],
          symptomLogs: [],
          predictionConfidence: 'High',
          includeMedications: true,
          includeNotes: true,
        );

        expect(pdfBytes.isNotEmpty, true);
      },
    );

    test(
      'Phase 13: Granular Partner Sharing excludes intimate journal data',
      () {
        const payload = SharedSupportPayload(
          sharePeriodExpectedDate: true,
          supportPreference: 'I would appreciate extra support',
        );

        final output = PartnerSharingService.formatPartnerShareMessage(
          payload: payload,
          expectedPeriodRange: '17–20 August',
        );

        expect(output.contains('17–20 August'), true);
        expect(output.contains('I would appreciate extra support'), true);
        expect(output.contains('Journal'), false);
      },
    );
  });
}
