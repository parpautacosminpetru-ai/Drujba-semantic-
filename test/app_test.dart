import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:semantic_drujba/app.dart';

void main() {
  testWidgets('shows one raw semantic state and offline input', (tester) async {
    await tester.pumpWidget(const DrujbaSemanticaApp());

    expect(find.text('DRU — Sinteză Semantică NO-LOSS'), findsOneWidget);
    expect(find.byKey(const Key('semantic-monolith')), findsOneWidget);
    expect(find.textContaining('SENS BRUT INTEGRAT'), findsOneWidget);
    expect(find.byKey(const Key('manual-input-section')), findsOneWidget);
  });
}
