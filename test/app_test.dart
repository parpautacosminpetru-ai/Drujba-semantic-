import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drujba_semantic_core/app.dart';

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> openManualInput(WidgetTester tester) async {
  if (find.byKey(const Key('manual-input')).evaluate().isNotEmpty) {
    return;
  }
  await tapVisible(tester, find.text('Introducere manuală offline'));
  expect(find.byKey(const Key('manual-input')), findsOneWidget);
}

Future<void> integrateManually(WidgetTester tester, String text) async {
  await openManualInput(tester);
  final input = find.byKey(const Key('manual-input'));
  await tester.ensureVisible(input);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.enterText(input, text);
  await tester.pump();
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
    expect(find.byKey(const Key('toggle-cinematic-playback')), findsOneWidget);
    expect(find.byKey(const Key('cinematic-scene-image')), findsNothing);
    expect(find.text('Ce:'), findsNothing);
    expect(find.text('Dinamică:'), findsNothing);
    expect(find.text('Cum:'), findsNothing);
  });

  testWidgets('manual forms collapse through the directional matrix',
      (tester) async {
    await tester.pumpWidget(const DrujbaSemanticaApp());
    await openManualInput(tester);

    await integrateManually(tester, 'Sistem politic eșuat');

    expect(find.text('[PRABUSIRE]'), findsOneWidget);
    expect(
      find.text('Dovadă axiomatică: CIN-001 → CIN-003'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('cinematic-scene-image')), findsOneWidget);
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
    expect(find.byKey(const Key('cinematic-scene-image')), findsNothing);
  });

  testWidgets('locking freezes the monolith and opens a separate segment',
      (tester) async {
    await tester.pumpWidget(const DrujbaSemanticaApp());
    await openManualInput(tester);
    await integrateManually(tester, 'Sistem politic');
    expect(find.text('[STAT]'), findsOneWidget);

    await tapVisible(tester, find.byKey(const Key('lock-current-sense')));

    expect(
      tester.widget<Text>(find.byKey(const Key('semantic-monolith'))).data,
      '[STAT]',
    );
    expect(find.text('Sinteze cu Zăvor'), findsOneWidget);
    expect(find.byKey(const Key('locked-sense-0')), findsOneWidget);

    await integrateManually(tester, 'rapid');
    expect(
      tester.widget<Text>(find.byKey(const Key('semantic-monolith'))).data,
      '[STAT]',
      reason: 'Zăvorul trebuie să înghețe cadrul cinematografic',
    );

    await tapVisible(
      tester,
      find.byKey(const Key('toggle-cinematic-playback')),
    );
    expect(find.text('[RAPID]'), findsOneWidget);
    expect(find.byKey(const Key('locked-sense-0')), findsOneWidget);

    await tapVisible(tester, find.byKey(const Key('reset-session')));
    expect(find.text('[FLUX-VID]'), findsOneWidget);
    expect(find.byKey(const Key('locked-sense-0')), findsNothing);
  });

  testWidgets('an atomic concept can freeze on the black projection',
      (tester) async {
    await tester.pumpWidget(const DrujbaSemanticaApp());
    await integrateManually(tester, 'Sistem');

    await tapVisible(tester, find.byKey(const Key('lock-current-sense')));

    expect(
      tester.widget<Text>(find.byKey(const Key('semantic-monolith'))).data,
      '[SISTEM]',
    );
    expect(find.byKey(const Key('cinematic-scene-image')), findsNothing);
    expect(find.byKey(const Key('locked-sense-0')), findsOneWidget);
  });

  testWidgets('removing an older lock keeps the latest frame frozen',
      (tester) async {
    await tester.pumpWidget(const DrujbaSemanticaApp());
    await integrateManually(tester, 'Sistem politic');
    await tapVisible(tester, find.byKey(const Key('lock-current-sense')));
    await tapVisible(
      tester,
      find.byKey(const Key('toggle-cinematic-playback')),
    );

    await integrateManually(tester, 'Stat corupt');
    await tapVisible(tester, find.byKey(const Key('lock-current-sense')));
    expect(find.byKey(const Key('locked-sense-0')), findsOneWidget);
    expect(find.byKey(const Key('locked-sense-1')), findsOneWidget);

    await tapVisible(tester, find.byKey(const Key('locked-sense-0')));

    expect(
      tester.widget<Text>(find.byKey(const Key('semantic-monolith'))).data,
      '[DEGRADARE]',
    );
    expect(find.byKey(const Key('locked-sense-0')), findsOneWidget);
    expect(find.byKey(const Key('locked-sense-1')), findsNothing);
  });
}
