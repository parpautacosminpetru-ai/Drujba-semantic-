import 'package:flutter_test/flutter_test.dart';
import 'package:semantic_drujba/core/romanian_rule_tagger.dart';

void main() {
  const tagger = RomanianRuleTagger();

  test('closed-class function words receive explicit semantic operators', () {
    final inWord = tagger.analyzeToken('în');
    expect(inWord.category, RomanianRuleTagger.prepositionTag);
    expect(inWord.explicitMeaning, contains('interioritate'));

    final negation = tagger.analyzeToken('nu');
    expect(negation.category, RomanianRuleTagger.negationTag);
    expect(negation.explicitMeaning, 'negație');
  });

  test('open-class words are not guessed by suffix', () {
    final analysis = tagger.analyzeToken('istoria');
    expect(analysis.category, RomanianRuleTagger.lexemeTag);
    expect(analysis.explicitMeaning, 'istoria');
  });

  test('genuinely ambiguous forms stay ambiguous', () {
    final analysis = tagger.analyzeToken('o');
    expect(analysis.category, RomanianRuleTagger.ambiguousTag);
    expect(analysis.explicitMeaning, contains('articol'));
    expect(analysis.explicitMeaning, contains('pronume'));
    expect(analysis.explicitMeaning, contains('auxiliar'));
  });

  test('punctuation is analyzed, not discarded', () {
    final analysis = tagger.analyzeToken('?');
    expect(analysis.category, RomanianRuleTagger.punctuationTag);
    expect(analysis.explicitMeaning, 'interogație');
  });
}
