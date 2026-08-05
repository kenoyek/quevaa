import '../../../../core/analytics/app_logger.dart';

class JournalPrompt {
  final String text;
  final String category;

  const JournalPrompt({required this.text, required this.category});
}

class JournalService {
  static const List<JournalPrompt> prompts = [
    JournalPrompt(
      text: 'What does your body seem to need today?',
      category: 'Daily Reflection',
    ),
    JournalPrompt(text: 'What felt easier today?', category: 'Gratitude'),
    JournalPrompt(
      text: 'What drained your energy?',
      category: 'Productivity Review',
    ),
    JournalPrompt(
      text: 'What are you proud of completing?',
      category: 'Accomplishment',
    ),
    JournalPrompt(
      text: 'What would make tomorrow gentler?',
      category: 'Self-Care',
    ),
    JournalPrompt(
      text: 'Did anything feel different from your usual pattern?',
      category: 'Pattern Reflection',
    ),
  ];

  /// Filters journal entries locally by search query without external cloud or remote AI transmission.
  static List<Map<String, dynamic>> searchLocalJournal({
    required List<Map<String, dynamic>> entries,
    required String query,
  }) {
    if (query.trim().isEmpty) return entries;
    final lowerQuery = query.toLowerCase();
    AppLogger.info('Searching local journal index');
    return entries.where((e) {
      final title = (e['title'] ?? '').toString().toLowerCase();
      final content = (e['content'] ?? '').toString().toLowerCase();
      final mood = (e['mood'] ?? '').toString().toLowerCase();
      return title.contains(lowerQuery) ||
          content.contains(lowerQuery) ||
          mood.contains(lowerQuery);
    }).toList();
  }
}
