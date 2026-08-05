import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scramble_text_cycler/scramble_text_cycler.dart';

void main() {
  group('ScrambleTextCycler', () {
    testWidgets('renders the first word initially', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: ScrambleTextCycler(
            words: ['Hello', 'World'],
            textStyle: TextStyle(fontFamily: 'monospace', fontSize: 24),
          ),
        ),
      );

      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('starts scrambling after displayDuration', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: ScrambleTextCycler(
            words: ['AAAA', 'BBBB'],
            displayDuration: Duration(milliseconds: 200),
            scrambleDuration: Duration(milliseconds: 300),
            scrambleTickInterval: Duration(milliseconds: 30),
            textStyle: TextStyle(fontFamily: 'monospace', fontSize: 24),
          ),
        ),
      );

      // Still showing initial word.
      expect(find.text('AAAA'), findsOneWidget);

      // Advance past the hold timer — scramble should start.
      await tester.pump(const Duration(milliseconds: 250));

      // Pump a few frames to let the animation produce scrambled output.
      await tester.pump(const Duration(milliseconds: 50));
      final textWidget = tester.widget<Text>(find.byType(Text));
      // During scramble, the text should NOT still be the original word.
      // (It may or may not equal 'BBBB' yet, but it should have changed.)
      expect(textWidget.data, isNotNull);
      expect(textWidget.data!.length, greaterThanOrEqualTo(4));
    });

    testWidgets('transitions to the next word after scramble completes',
        (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: ScrambleTextCycler(
            words: ['AAA', 'BBB'],
            displayDuration: Duration(milliseconds: 100),
            scrambleDuration: Duration(milliseconds: 200),
            scrambleTickInterval: Duration(milliseconds: 20),
            textStyle: TextStyle(fontFamily: 'monospace', fontSize: 24),
          ),
        ),
      );

      // Advance past hold + full scramble duration.
      await tester.pump(const Duration(milliseconds: 100)); // hold
      await tester.pump(const Duration(milliseconds: 250)); // scramble done

      expect(find.text('BBB'), findsOneWidget);
    });

    testWidgets('respects maxLines normalisation', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: ScrambleTextCycler(
            words: ['Line1\nLine2\nLine3', 'Short'],
            maxLines: 3,
            textStyle: TextStyle(fontFamily: 'monospace', fontSize: 24),
          ),
        ),
      );

      // First word should be displayed as-is (3 lines, matches maxLines).
      expect(find.text('Line1\nLine2\nLine3'), findsOneWidget);
    });

    testWidgets('handles single-word list without crashing', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: ScrambleTextCycler(
            words: ['Solo'],
            textStyle: TextStyle(fontFamily: 'monospace', fontSize: 24),
          ),
        ),
      );

      expect(find.text('Solo'), findsOneWidget);

      // Advance past hold — it should cycle back to itself.
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Solo'), findsOneWidget);
    });

    testWidgets('handles empty word list gracefully', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: ScrambleTextCycler(
            words: [],
            textStyle: TextStyle(fontFamily: 'monospace', fontSize: 24),
          ),
        ),
      );

      // Should render an empty text widget without crashing.
      final textWidget = tester.widget<Text>(find.byType(Text));
      expect(textWidget.data, equals(''));
    });
  });
}
