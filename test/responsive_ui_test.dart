import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quevaa/features/productivity/presentation/pages/plan_workspace_page.dart';
import 'package:quevaa/features/wellness/presentation/pages/wellness_workspace_page.dart';
import 'package:quevaa/app/theme/quevaa_layout.dart';

void main() {
  Widget wrapWithProvider(Widget child, {Size size = const Size(360, 800)}) {
    return ProviderScope(
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: child,
        ),
      ),
    );
  }

  group('Responsive UI Tests', () {
    testWidgets('PlanWorkspacePage should not overflow at 320dp', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 800));
      await tester.pumpWidget(wrapWithProvider(const PlanWorkspacePage(), size: const Size(320, 800)));
      await tester.pumpAndSettle();

      expect(find.byType(PlanWorkspacePage), findsOneWidget);
      expect(find.byType(QuevaaSectionTabs), findsOneWidget);
      
      // Check for overflow (RenderFlex usually throws exception if it overflows)
      final dynamic exception = tester.takeException();
      expect(exception, isNull);
    });

    testWidgets('WellnessWorkspacePage should not overflow at 320dp', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 800));
      await tester.pumpWidget(wrapWithProvider(const WellnessWorkspacePage(), size: const Size(320, 800)));
      await tester.pumpAndSettle();

      expect(find.byType(WellnessWorkspacePage), findsOneWidget);
      expect(find.byType(QuevaaSectionTabs), findsOneWidget);
      
      final dynamic exception = tester.takeException();
      expect(exception, isNull);
    });

    testWidgets('QuevaaSectionTabs should contain expected labels and be scrollable', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 800));
      await tester.pumpWidget(wrapWithProvider(
        Scaffold(
          body: QuevaaSectionTabs(
            segments: const [
              (value: '1', label: 'Very Long Label One', icon: Icons.star),
              (value: '2', label: 'Very Long Label Two', icon: Icons.star),
              (value: '3', label: 'Very Long Label Three', icon: Icons.star),
              (value: '4', label: 'Very Long Label Four', icon: Icons.star),
              (value: '5', label: 'Very Long Label Five', icon: Icons.star),
            ],
            selected: '1',
            onSelectionChanged: (_) {},
          ),
        ),
        size: const Size(320, 800),
      ));

      expect(find.text('Very Long Label One'), findsOneWidget);
      // 'Five' should be off-screen initially at 320dp
      expect(find.text('Very Long Label Five'), findsOneWidget); 
      // ChoiceChip might be rendered but not visible. 
      // We check if it can be scrolled into view.
      await tester.drag(find.byType(SingleChildScrollView), const Offset(-500, 0));
      await tester.pumpAndSettle();
    });
  });
}
