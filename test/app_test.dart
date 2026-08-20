import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drujba_semantic_core/app.dart';

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> openManualInput(WidgetTester tester) async {
  await tapVisible(tester, find.text('Introducere manuală offline'));
}

Future<void> integrateManually(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const Key('manual-input')), text);
  await tapVisible(tester, find.byKey(const Key('process-manual-input')));
}

void main() {
  testWidgets('shows the v2 raw semantic interface', (tester) async {
    await tester.pumpWidget(const DrujbaSemanticaApp());

    expect(find.text('DRU - Drujba Semantică v2.0'), findsOneWidget);
    expect(find.text('[FLUX-VID]'), findsOneWidget);
    expect(
      find.text('Scanează Pagina Liniar (OCR Continuous)'),
      findsOneWidget,
    );
    expect(find.text('Introducere manuală offline'), findsOneWidget);
    expect(find.text('Ce:'), findsNothing);
    expect(find.text('Dinamică:'), findsNothing);
    expect(find.text('Cum:'), findsNothing);
  });

  testWidgets('manual forms collapse through the directional matrix',
      (tester) async {
    await tester.pumpWidget(const DrujbaSemanticaApp());
    await openManualInput(tester);

    await integrateManually(tester, 'Sistem politic eșuat');

    expect(find.text('[ANOMIE]'), findsOneWidget);
    expect(
      find.text('Dovadă axiomatică: AX-002 → AX-003'),
      findsOneWidget,
    );
    final input = tester.widget<TextField>(
      find.byKey(const Key('manual-input')),
    );
    expect(input.controller?.text, isEmpty);
  });

  testWidgets('unknown forms remain an ordered raw composition',
      (tester) async {
    await tester.pumpWidget(const DrujbaSemanticaApp());
    await openManualInput(tester);

    await integrateManually(tester, 'idee în idee');

    expect(find.text('[IDEE-ÎN-IDEE]'), findsOneWidget);
    expect(find.byKey(const Key('axiomatic-unresolved')), findsOneWidget);
  });

  testWidgets('locking freezes the monolith and opens a separate segment',
      (tester) async {
    await tester.pumpWidget(const DrujbaSemanticaApp());
    await openManualInput(tester);
    await integrateManually(tester, 'Tehnologie control');
    expect(find.text('[CIBERNETICĂ]'), findsOneWidget);

    await tapVisible(tester, find.byKey(const Key('lock-current-sense')));

    expect(find.text('[FLUX-VID]'), findsOneWidget);
    expect(find.text('Sinteze cu Zăvor'), findsOneWidget);
    expect(find.byKey(const Key('locked-sense-0')), findsOneWidget);
    expect(find.text('[CIBERNETICĂ]'), findsOneWidget);

    await integrateManually(tester, 'rapid');
    expect(find.text('[RAPID]'), findsOneWidget);
    expect(find.byKey(const Key('locked-sense-0')), findsOneWidget);

    await tapVisible(tester, find.byKey(const Key('reset-session')));
    expect(find.text('[FLUX-VID]'), findsOneWidget);
    expect(find.byKey(const Key('locked-sense-0')), findsNothing);
  });
}
