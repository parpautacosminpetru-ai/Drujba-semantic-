import 'package:flutter_test/flutter_test.dart';
import 'package:semantic_drujba/core/ocr_frame_accumulator.dart';

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
      expect(second.isStable, isTrue);
      expect(second.newWords, <String>['Ana', 'are']);
      expect(second.stableText, 'Ana are');
    });

    test('does not duplicate an already committed OCR flow', () {
      final accumulator = OcrFrameAccumulator();

      accumulator
        ..ingestFrame('Ana are mere')
        ..ingestFrame('Ana are mere');
      final duplicate = accumulator.ingestFrame('Ana are mere');

      expect(duplicate.isStable, isTrue);
      expect(duplicate.newWords, isEmpty);
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
      expect(extension.cuvinteStabile, <String>['Ana', 'are', 'mere']);
    });

    test('preserves a repeated word at a new position', () {
      final accumulator = OcrFrameAccumulator(requiredMatchingFrames: 1);

      expect(accumulator.ingestFrame('da').newWords, <String>['da']);
      expect(accumulator.ingestFrame('da da').newWords, <String>['da']);
      expect(accumulator.stableWords, <String>['da', 'da']);
    });

    test('emits an inserted occurrence without duplicating known words', () {
      final accumulator = OcrFrameAccumulator(requiredMatchingFrames: 1);

      accumulator.ingestFrame('Ana mere');
      final insertion = accumulator.ingestFrame('Ana are mere');

      expect(insertion.newWords, <String>['are']);
      expect(accumulator.stableWords, <String>['Ana', 'mere', 'are']);
    });

    test('case and configured punctuation do not duplicate an occurrence', () {
      final accumulator = OcrFrameAccumulator(requiredMatchingFrames: 1);

      accumulator.ingestFrame('CONCEPT');
      final sameOccurrence = accumulator.ingestFrame('(concept),');

      expect(sameOccurrence.newWords, isEmpty);
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
