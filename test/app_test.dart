import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:semantic_drujba/app.dart';

void main() {
  testWidgets('shows the specified initial interface', (tester) async {
    await tester.pumpWidget(const DrujbaSemanticaApp());

    expect(find.text('DRU - Drujba Semantică v1.0'), findsOneWidget);
    expect(find.text('[Așteptare Flux Liniar...]'), findsOneWidget);
    expect(
      find.text('Scanează Pagina Liniar (OCR Continuous)'),
      findsOneWidget,
    );
    expect(find.text('Introducere manuală offline'), findsOneWidget);
  });

  testWidgets('manual offline input updates the deterministic monolith',
      (tester) async {
    await tester.pumpWidget(const DrujbaSemanticaApp());
    await tester.tap(find.text('Introducere manuală offline'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('manual-input')),
      'Epistemologia determina evolutia cunoasterii stiintifice',
    );
    await tester.tap(find.byKey(const Key('process-manual-input')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        '[Cunoasterii-Stiintifice] ➔ '
        '[Epistemologia-Determina-Evolutia]',
      ),
      findsOneWidget,
    );
    expect(find.text('Cunoasterii'), findsOneWidget);
    expect(find.text('Dinamică:'), findsOneWidget);
  });

  testWidgets('concept chips toggle the lock and reset clears the session',
      (tester) async {
    await tester.pumpWidget(const DrujbaSemanticaApp());
    await tester.tap(find.text('Introducere manuală offline'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('manual-input')), 'concept');
    await tester.tap(find.byKey(const Key('process-manual-input')));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Aplică Zăvorul pentru Concept'));
    await tester.pump();
    expect(find.byTooltip('Elimină Zăvorul pentru Concept'), findsOneWidget);

    await tester.tap(find.byKey(const Key('reset-session')));
    await tester.pump();
    expect(find.text('[Așteptare Flux Liniar...]'), findsOneWidget);
    expect(find.text('Concept'), findsNothing);
  });
}
