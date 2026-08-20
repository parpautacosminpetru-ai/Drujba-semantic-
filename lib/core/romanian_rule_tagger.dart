/// The deliberately small, deterministic Romanian tagger from the PDF.
///
/// It is a suffix heuristic, not a predictive language model: `re` and `a`
/// identify verbs, `ic` and `al` identify adjectives, and every other ending
/// falls back to a noun.
final class RomanianRuleTagger {
  const RomanianRuleTagger();

  static final RegExp _discardedPunctuation =
      RegExp(r'[.,\/#!$%\^&\*;:{}=\-_`~()]');

  static const String nounTag = 'SUBSTANTIV';
  static const String verbTag = 'VERB';
  static const String adjectiveTag = 'ADJECTIV';

  String tagWord(String word) => inferTag(word);

  /// Romanian alias for [tagWord].
  String eticheteazaCuvant(String cuvant) => inferTag(cuvant);

  static String inferTag(String word) {
    final normalized = word
        .replaceAll(_discardedPunctuation, '')
        .trim()
        .toLowerCase();

    var tag = nounTag;
    if (normalized.endsWith('re') || normalized.endsWith('a')) {
      tag = verbTag;
    }
    if (normalized.endsWith('ic') || normalized.endsWith('al')) {
      tag = adjectiveTag;
    }
    return tag;
  }
}
