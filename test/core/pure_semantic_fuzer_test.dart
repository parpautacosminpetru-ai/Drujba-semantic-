import 'package:flutter_test/flutter_test.dart';
import 'package:semantic_drujba/core/pure_semantic_fuzer.dart';

void main() {
  group('PureSemanticFuzer', () {
    test('starts with the exact empty-flow monolith', () {
      final fuzer = PureSemanticFuzer();

      expect(fuzer.generateMonolith(), '[Flux-Vid]');
      expect(fuzer.genereazaMonolit(), '[Flux-Vid]');
    });

    test('preserves category insertion order and exact separators', () {
      final fuzer = PureSemanticFuzer()
        ..absorbWord('Epistemologia', 'SUBSTANTIV')
        ..absorbWord('determina', 'VERB')
        ..absorbWord('evolutia', 'SUBSTANTIV')
        ..absorbWord('ȘTIINȚIFIC', 'ADJECTIV')
        ..absorbWord('rapid', 'ADVERB');

      expect(
        fuzer.generateMonolith(),
        '[Epistemologia-Evolutia] ➔ [Determina] [științific][rapid]',
      );
      expect(
        fuzer.snapshot.substances.map((element) => element.value),
        <String>['Epistemologia', 'Evolutia'],
      );
      expect(
        fuzer.snapshot.dynamics.map((element) => element.value),
        <String>['Determina'],
      );
      expect(
        fuzer.snapshot.attributes.map((element) => element.value),
        <String>['științific', 'rapid'],
      );
    });

    test('removes specified punctuation and ignores stop words', () {
      final fuzer = PureSemanticFuzer()
        ..absorbWord('ȘI,', 'SUBSTANTIV')
        ..absorbWord('(în)', 'SUBSTANTIV')
        ..absorbWord('eco-socială!', 'SUBSTANTIV');

      expect(fuzer.generateMonolith(), '[Ecosocială]');
      expect(fuzer.frequencies, <String, int>{'Ecosocială': 1});
    });

    test('duplicates update frequency without changing insertion order', () {
      final fuzer = PureSemanticFuzer()
        ..absorbWord('Casa', 'SUBSTANTIV')
        ..absorbWord('Casa', 'SUBSTANTIV')
        ..absorbWord('Om', 'SUBSTANTIV');

      expect(fuzer.generateMonolith(), '[Casa-Om]');
      expect(fuzer.frequencyOf('casa'), 2);
      expect(fuzer.snapshot.substances.first.frequency, 2);
    });

    test('lock counts observations but prevents category insertion', () {
      final fuzer = PureSemanticFuzer()..lock('idee');

      fuzer.absorbWord('idee', 'SUBSTANTIV');
      expect(fuzer.generateMonolith(), '[Flux-Vid]');
      expect(fuzer.frequencyOf('Idee'), 1);

      fuzer.unlock('IDEE');
      expect(fuzer.isLocked('Idee'), isFalse);
      fuzer.absoarbeCuvantLiniar('idee', 'SUBSTANTIV');

      expect(fuzer.generateMonolith(), '[Idee]');
      expect(fuzer.frequencyOf('Idee'), 2);
    });

    test('attribute locks work with their lowercase display values', () {
      final fuzer = PureSemanticFuzer()
        ..absorbWord('CULTURAL', 'ADJECTIV');

      expect(fuzer.toggleLock('cultural'), isTrue);
      expect(fuzer.snapshot.attributes.single.locked, isTrue);
      fuzer.absorbWord('cultural', 'ADJECTIV');
      expect(fuzer.snapshot.attributes.single.frequency, 2);

      expect(fuzer.comutaZavor('cultural'), isFalse);
      expect(fuzer.snapshot.attributes.single.locked, isFalse);
    });

    test('unknown tags default to nouns and adverbs are attributes', () {
      final fuzer = PureSemanticFuzer()
        ..absorbWord('necunoscut', 'ALTCEVA')
        ..absorbWord('repede', 'ADVERB');

      expect(fuzer.generateMonolith(), '[Necunoscut] [repede]');
    });

    test('reset clears categories, frequencies, and locks', () {
      final fuzer = PureSemanticFuzer()
        ..absorbWord('Concept', 'SUBSTANTIV')
        ..aplicaZavor('Concept')
        ..reset();

      expect(fuzer.generateMonolith(), '[Flux-Vid]');
      expect(fuzer.frequencies, isEmpty);
      expect(fuzer.isLocked('Concept'), isFalse);
      expect(fuzer.stareCurenta.substante, isEmpty);
    });
  });
}
