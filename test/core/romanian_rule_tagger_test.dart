import 'package:flutter_test/flutter_test.dart';
import 'package:semantic_drujba/core/romanian_rule_tagger.dart';

void main() {
  const tagger = RomanianRuleTagger();

  group('RomanianRuleTagger', () {
    test('re and a endings are verbs', () {
      expect(tagger.tagWord('determinare'), 'VERB');
      expect(tagger.eticheteazaCuvant('EVOLUA'), 'VERB');
      expect(tagger.tagWord('analiza.'), 'VERB');
    });

    test('ic and al endings are adjectives', () {
      expect(tagger.tagWord('științific'), 'ADJECTIV');
      expect(tagger.tagWord('CULTURAL!'), 'ADJECTIV');
    });

    test('every other ending defaults to noun', () {
      expect(tagger.tagWord('epistemologie'), 'SUBSTANTIV');
      expect(tagger.tagWord(''), 'SUBSTANTIV');
    });
  });
}
