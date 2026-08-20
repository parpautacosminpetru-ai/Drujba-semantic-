import 'package:flutter_test/flutter_test.dart';
import 'package:semantic_drujba/core/ocr_frame_accumulator.dart';
import 'package:semantic_drujba/core/pure_semantic_fuzer.dart';
import 'package:semantic_drujba/core/romanian_rule_tagger.dart';

void main() {
  const tagger = RomanianRuleTagger();

  test('function words are semantic operators, never stop words', () {
    final fuzer = PureSemanticFuzer();
    fuzer.absorbTokens(
      OcrFrameAccumulator.tokenizeText('în istoria sa multiseculară'),
      tagger,
    );

    final snapshot = fuzer.snapshot;
    expect(snapshot.tokenCount, 4);
    expect(snapshot.contributions.map((e) => e.surface),
        <String>['în', 'istoria', 'sa', 'multiseculară']);
    expect(snapshot.rawMeaning, contains('interioritate/localizare'));
    expect(snapshot.rawMeaning, contains('istoria'));
    expect(snapshot.rawMeaning, contains('posesie-p3-singular'));
    expect(snapshot.rawMeaning, contains('multiseculară'));
  });

  test('negation and punctuation participate in the same state', () {
    final fuzer = PureSemanticFuzer();
    fuzer.absorbTokens(
      OcrFrameAccumulator.tokenizeText('nu pleacă.'),
      tagger,
    );

    expect(fuzer.snapshot.tokenCount, 3);
    expect(fuzer.snapshot.rawMeaning, contains('negație'));
    expect(fuzer.snapshot.rawMeaning, contains('pleacă'));
    expect(fuzer.snapshot.rawMeaning, contains('închidere-enunț'));
  });

  test('rollback and replay replace OCR correction without semantic residue', () {
    final fuzer = PureSemanticFuzer();
    fuzer.reconcileTail(
      baseIndex: 0,
      tokens: OcrFrameAccumulator.tokenizeText('în istoria lui'),
      tagger: tagger,
    );
    expect(fuzer.snapshot.rawMeaning, contains('lui'));

    fuzer.reconcileTail(
      baseIndex: 0,
      tokens: OcrFrameAccumulator.tokenizeText('în istoria sa'),
      tagger: tagger,
    );

    expect(fuzer.tokens, <String>['în', 'istoria', 'sa']);
    expect(fuzer.snapshot.rawMeaning, isNot(contains('lui')));
    expect(fuzer.snapshot.rawMeaning, contains('posesie-p3-singular'));
  });

  test('ambiguous function form stays explicitly ambiguous', () {
    final fuzer = PureSemanticFuzer();
    fuzer.absorbToken('o', tagger);
    expect(
      fuzer.snapshot.rawMeaning,
      contains('articol/pronume/auxiliar'),
    );
  });
}
