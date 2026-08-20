import 'package:flutter_test/flutter_test.dart';
import 'package:semantic_drujba/core/ocr_frame_accumulator.dart';

void main() {
  test('tokenizer keeps punctuation as an explicit contribution', () {
    expect(
      OcrFrameAccumulator.tokenizeText('Nu, acum.'),
      <String>['Nu', ',', 'acum', '.'],
    );
  });

  test('stable correction reports exact divergence position', () {
    final accumulator = OcrFrameAccumulator(requiredMatchingFrames: 2);

    accumulator.ingestFrame('în istoria lui');
    final firstStable = accumulator.ingestFrame('în istoria lui');
    expect(firstStable.isStable, isTrue);
    expect(firstStable.changedFromIndex, 0);

    accumulator.ingestFrame('în istoria sa');
    final correction = accumulator.ingestFrame('în istoria sa');
    expect(correction.isStable, isTrue);
    expect(correction.changedFromIndex, 2);
    expect(correction.changedTokens, <String>['sa']);
  });
}
