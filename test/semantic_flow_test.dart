import 'package:flutter_test/flutter_test.dart';
import 'package:drujba_semantic_core/core/ocr_frame_accumulator.dart';
import 'package:drujba_semantic_core/features/semantic_home_page.dart';
import 'package:drujba_semantic_core/semantic_reactor.dart';

void main() {
  test('sliding OCR updates append to one no-loss semantic ledger', () {
    final accumulator = OcrFrameAccumulator(requiredMatchingFrames: 1);
    final reactor = SemanticReactor();
    final ledger = <String>[];
    final preservedPrefixes = <List<String>>[];
    final frames = <String>[
      'Sistem politic',
      'politic eșuat',
      'eșuat și',
      'și tehnologie',
      'tehnologie control',
    ];

    for (final frame in frames) {
      final update = accumulator.ingestFrame(frame);

      expect(update.requiresReplay, isFalse, reason: frame);
      expect(update.appendedWords, isNotEmpty, reason: frame);
      ledger.addAll(update.appendedWords);
      reactor.integrateForms(update.appendedWords);

      expect(
        reactor.snapshot.sourceForms,
        ledger,
        reason: 'The semantic state must equal the append-only OCR ledger',
      );
      for (final prefix in preservedPrefixes) {
        expect(
          reactor.snapshot.sourceForms.take(prefix.length),
          prefix,
          reason: 'A previously committed semantic prefix was lost',
        );
      }
      preservedPrefixes.add(List<String>.unmodifiable(ledger));
    }

    expect(
      reactor.snapshot.sourceForms,
      <String>[
        'Sistem',
        'politic',
        'eșuat',
        'și',
        'tehnologie',
        'control',
      ],
    );
  });

  test('insert-only replay preserves the base and every previous OCR form', () {
    final accumulator = OcrFrameAccumulator(requiredMatchingFrames: 1);
    final reactor = SemanticReactor()..integrateForm('Sistem');
    const baseForms = <String>['Sistem'];

    final first = accumulator.ingestFrame('politic eșuat');
    reactor.integrateForms(first.appendedWords);
    var integratedLedger = List<String>.of(first.stableWords);

    expect(reactor.snapshot.display, '[ANOMIE]');
    expect(
      reactor.snapshot.sourceForms,
      <String>['Sistem', 'politic', 'eșuat'],
    );

    final insertion = accumulator.ingestFrame('politic acum eșuat');
    expect(insertion.requiresReplay, isTrue);

    final formsBeforeInsertion = List<String>.of(
      reactor.snapshot.sourceForms,
    );
    final safeReplay = buildInsertOnlyReplayForms(
      baseForms: baseForms,
      integratedLedger: integratedLedger,
      candidateLedger: insertion.stableWords,
    );
    expect(safeReplay, isNotNull);

    reactor.replaceActiveForms(safeReplay!);
    integratedLedger = List<String>.of(insertion.stableWords);
    expect(
      reactor.snapshot.sourceForms,
      <String>['Sistem', 'politic', 'acum', 'eșuat'],
    );
    expect(
      buildInsertOnlyReplayForms(
        baseForms: const <String>[],
        integratedLedger: formsBeforeInsertion,
        candidateLedger: reactor.snapshot.sourceForms,
      ),
      isNotNull,
      reason: 'Every previously integrated form must remain in exact order',
    );

    final laterInsertion = accumulator.ingestFrame('politic acum schimbat');
    expect(laterInsertion.requiresReplay, isTrue);
    final secondSafeReplay = buildInsertOnlyReplayForms(
      baseForms: baseForms,
      integratedLedger: integratedLedger,
      candidateLedger: laterInsertion.stableWords,
    );
    expect(secondSafeReplay, isNotNull);
    reactor.replaceActiveForms(secondSafeReplay!);
    integratedLedger = List<String>.of(laterInsertion.stableWords);
    expect(
      reactor.snapshot.sourceForms,
      <String>['Sistem', 'politic', 'acum', 'schimbat', 'eșuat'],
    );

    final rejectedReplay = buildInsertOnlyReplayForms(
      baseForms: baseForms,
      integratedLedger: integratedLedger,
      candidateLedger: const <String>['politic', 'acum', 'schimbat'],
    );
    expect(rejectedReplay, isNull);

    final stateBeforeRejection = List<String>.of(
      reactor.snapshot.sourceForms,
    );
    if (rejectedReplay != null) {
      reactor.replaceActiveForms(rejectedReplay);
    }
    expect(reactor.snapshot.sourceForms, stateBeforeRejection);
  });
}
