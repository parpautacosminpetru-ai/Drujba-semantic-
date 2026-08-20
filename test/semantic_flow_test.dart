import 'package:flutter_test/flutter_test.dart';
import 'package:drujba_semantic_core/core/ocr_frame_accumulator.dart';
import 'package:drujba_semantic_core/semantic_reactor.dart';

void main() {
  test('OCR extension and correction keep the semantic fold in exact order', () {
    final accumulator = OcrFrameAccumulator(requiredMatchingFrames: 1);
    final reactor = SemanticReactor();

    final first = accumulator.ingestFrame('Sistem politic');
    reactor.integrateForms(first.appendedWords);
    expect(reactor.snapshot.display, '[GUVERNANȚĂ]');

    final extension = accumulator.ingestFrame('Sistem politic eșuat');
    expect(extension.requiresReplay, isFalse);
    reactor.integrateForms(extension.appendedWords);
    expect(reactor.snapshot.display, '[ANOMIE]');
    expect(
      reactor.snapshot.sourceForms,
      <String>['Sistem', 'politic', 'eșuat'],
    );

    final correction = accumulator.ingestFrame('Sistem eșuat');
    expect(correction.requiresReplay, isTrue);
    reactor.replaceActiveForms(correction.stableWords);
    expect(reactor.snapshot.display, '[COLAPS]');
    expect(
      reactor.snapshot.sourceForms,
      <String>['Sistem', 'eșuat'],
    );
  });
}
