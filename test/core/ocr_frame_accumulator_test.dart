import 'package:flutter_test/flutter_test.dart';
import 'package:drujba_semantic_core/core/ocr_frame_accumulator.dart';

void main() {
  group('OcrFrameAccumulator', () {
    test('requires a positive stability threshold', () {
      expect(
        () => OcrFrameAccumulator(requiredMatchingFrames: 0),
        throwsArgumentError,
      );
    });

    test('emits a frame only after consecutive stabilization', () {
      final accumulator = OcrFrameAccumulator();

      final first = accumulator.ingestFrame('Ana are');
      final second = accumulator.ingestFrame('Ana   are');

      expect(first.isStable, isFalse);
      expect(first.newWords, isEmpty);
      expect(first.appendedWords, isEmpty);
      expect(first.requiresReplay, isFalse);
      expect(second.isStable, isTrue);
      expect(second.newWords, <String>['Ana', 'are']);
      expect(second.appendedWords, <String>['Ana', 'are']);
      expect(second.requiresReplay, isFalse);
      expect(second.stableText, 'Ana are');
    });

    test('does not duplicate an already committed OCR flow', () {
      final accumulator = OcrFrameAccumulator();

      accumulator
        ..ingestFrame('Ana are mere')
        ..ingestFrame('Ana are mere');
      final firstDuplicateObservation = accumulator.ingestFrame('Ana are mere');
      final duplicate = accumulator.ingestFrame('Ana are mere');

      expect(firstDuplicateObservation.isStable, isFalse);
      expect(duplicate.isStable, isTrue);
      expect(duplicate.newWords, isEmpty);
      expect(duplicate.appendedWords, isEmpty);
      expect(duplicate.requiresReplay, isFalse);
      expect(accumulator.stableText, 'Ana are mere');
    });

    test('emits only the new suffix of a stabilized extension', () {
      final accumulator = OcrFrameAccumulator();

      accumulator
        ..ingestFrame('Ana are')
        ..ingestFrame('Ana are');
      expect(accumulator.ingestFrame('Ana are mere').newWords, isEmpty);

      final extension = accumulator.absoarbeCadru('Ana are mere');
      expect(extension.cuvinteNoi, <String>['mere']);
      expect(extension.appendedWords, <String>['mere']);
      expect(extension.requiresReplay, isFalse);
      expect(extension.cuvinteStabile, <String>['Ana', 'are', 'mere']);
    });

    test('keeps a global ledger across overlapping sliding frames', () {
      final accumulator = OcrFrameAccumulator();

      accumulator
        ..ingestFrame('A B C')
        ..ingestFrame('A B C');
      final firstSlideObservation = accumulator.ingestFrame('C D E');
      final slide = accumulator.ingestFrame('C D E');

      expect(firstSlideObservation.isStable, isFalse);
      expect(slide.isStable, isTrue);
      expect(slide.requiresReplay, isFalse);
      expect(slide.appendedWords, <String>['D', 'E']);
      expect(slide.stableWords, <String>['A', 'B', 'C', 'D', 'E']);
      expect(accumulator.stableText, 'A B C D E');
    });

    test('appends a disjoint stable frame to the global ledger', () {
      final accumulator = OcrFrameAccumulator();

      accumulator
        ..ingestFrame('A B')
        ..ingestFrame('A B')
        ..ingestFrame('X Y');
      final disjoint = accumulator.ingestFrame('X Y');

      expect(disjoint.isStable, isTrue);
      expect(disjoint.requiresReplay, isFalse);
      expect(disjoint.appendedWords, <String>['X', 'Y']);
      expect(disjoint.stableWords, <String>['A', 'B', 'X', 'Y']);
    });

    test('remaps revisited ledger segments without duplicates or loss', () {
      final accumulator = OcrFrameAccumulator(requiredMatchingFrames: 1);

      accumulator.ingestFrame('A B C D E');
      final revisit = accumulator.ingestFrame('B C');
      final extensionInsideLedger = accumulator.ingestFrame('B C D');

      expect(revisit.requiresReplay, isFalse);
      expect(revisit.appendedWords, isEmpty);
      expect(revisit.stableWords, <String>['A', 'B', 'C', 'D', 'E']);
      expect(extensionInsideLedger.requiresReplay, isFalse);
      expect(extensionInsideLedger.appendedWords, isEmpty);
      expect(
        extensionInsideLedger.stableWords,
        <String>['A', 'B', 'C', 'D', 'E'],
      );
    });

    test('needs positional evidence for an identical repeated word', () {
      final accumulator = OcrFrameAccumulator(requiredMatchingFrames: 1);

      expect(accumulator.ingestFrame('da').newWords, <String>['da']);
      final ambiguousIsolatedWord = accumulator.ingestFrame('da');
      expect(ambiguousIsolatedWord.newWords, isEmpty);
      expect(ambiguousIsolatedWord.stableWords, <String>['da']);

      final repeatedPosition = accumulator.ingestFrame('da da');
      expect(repeatedPosition.newWords, <String>['da']);
      expect(accumulator.stableWords, <String>['da', 'da']);
    });

    test('requests replay when an occurrence is inserted before the cursor', () {
      final accumulator = OcrFrameAccumulator(requiredMatchingFrames: 1);

      accumulator.ingestFrame('Ana mere');
      final insertion = accumulator.ingestFrame('Ana are mere');

      expect(insertion.isStable, isTrue);
      expect(insertion.requiresReplay, isTrue);
      expect(insertion.appendedWords, isEmpty);
      expect(insertion.newWords, isEmpty);
      expect(insertion.stableWords, <String>['Ana', 'are', 'mere']);
      expect(accumulator.stableWords, <String>['Ana', 'are', 'mere']);
    });

    test('corrections and shorter frames never remove confirmed forms', () {
      final accumulator = OcrFrameAccumulator(requiredMatchingFrames: 1);

      accumulator.ingestFrame('Ana are mere');

      final correction = accumulator.ingestFrame('Ana vede mere');
      expect(correction.requiresReplay, isTrue);
      expect(correction.appendedWords, isEmpty);
      expect(
        correction.stableWords,
        <String>['Ana', 'are', 'vede', 'mere'],
      );

      final removal = accumulator.ingestFrame('Ana mere');
      expect(removal.requiresReplay, isFalse);
      expect(removal.appendedWords, isEmpty);
      expect(
        removal.stableWords,
        <String>['Ana', 'are', 'vede', 'mere'],
      );
    });

    test('mapped correction preserves ledger words before a sliding window', () {
      final accumulator = OcrFrameAccumulator(requiredMatchingFrames: 1);

      accumulator
        ..ingestFrame('A B C')
        ..ingestFrame('C D E');
      final correction = accumulator.ingestFrame('C X E');

      expect(correction.requiresReplay, isTrue);
      expect(correction.appendedWords, isEmpty);
      expect(
        correction.stableWords,
        <String>['A', 'B', 'C', 'D', 'X', 'E'],
      );
    });

    test('mapped edit preserves the confirmed ledger suffix', () {
      final accumulator = OcrFrameAccumulator(requiredMatchingFrames: 1);

      accumulator
        ..ingestFrame('A B C D E')
        ..ingestFrame('B C');
      final correction = accumulator.ingestFrame('B X');

      expect(correction.requiresReplay, isTrue);
      expect(correction.appendedWords, isEmpty);
      expect(
        correction.stableWords,
        <String>['A', 'B', 'X', 'C', 'D', 'E'],
      );
    });

    test('an interior extension inserts without replacing confirmed suffix', () {
      final accumulator = OcrFrameAccumulator(requiredMatchingFrames: 1);

      accumulator.ingestFrame('A B C D E');
      final correction = accumulator.ingestFrame('B C X');

      expect(correction.requiresReplay, isTrue);
      expect(correction.appendedWords, isEmpty);
      expect(
        correction.stableWords,
        <String>['A', 'B', 'C', 'X', 'D', 'E'],
      );
    });

    test('surface noise keeps the first confirmed normalized occurrence', () {
      final accumulator = OcrFrameAccumulator(requiredMatchingFrames: 1);

      accumulator.ingestFrame('CONCEPT');
      final sameOccurrence = accumulator.ingestFrame('(concept),');

      expect(sameOccurrence.newWords, isEmpty);
      expect(sameOccurrence.requiresReplay, isFalse);
      expect(sameOccurrence.stableWords, <String>['CONCEPT']);
    });

    test('requires an exact repeat after a lexical OCR fluctuation', () {
      final accumulator = OcrFrameAccumulator();

      final first = accumulator.ingestFrame('Ana are mere');
      final fluctuation = accumulator.ingestFrame('Ana are pere');
      final stabilized = accumulator.ingestFrame('Ana are pere');

      expect(first.isStable, isFalse);
      expect(first.appendedWords, isEmpty);
      expect(fluctuation.isStable, isFalse);
      expect(fluctuation.appendedWords, isEmpty);
      expect(stabilized.isStable, isTrue);
      expect(stabilized.requiresReplay, isFalse);
      expect(stabilized.appendedWords, <String>['Ana', 'are', 'pere']);
      expect(stabilized.stableWords, <String>['Ana', 'are', 'pere']);
    });

    test('blank frames interrupt matching but do not erase committed words', () {
      final accumulator = OcrFrameAccumulator();

      accumulator
        ..ingestFrame('flux stabil')
        ..ingestFrame('flux stabil');
      final blank = accumulator.ingestFrame('  \n ');

      expect(blank.isStable, isFalse);
      expect(blank.newWords, isEmpty);
      expect(blank.stableText, 'flux stabil');
      expect(accumulator.ingestFrame('flux stabil nou').isStable, isFalse);
    });

    test('a new stream may emit the same words again only after reset', () {
      final accumulator = OcrFrameAccumulator(requiredMatchingFrames: 1);

      expect(accumulator.ingestFrame('același flux').hasNewWords, isTrue);
      expect(accumulator.ingestFrame('același flux').hasNewWords, isFalse);

      accumulator.incepeFluxNou();
      expect(accumulator.ingestFrame('același flux').newText, 'același flux');
    });
  });
}
