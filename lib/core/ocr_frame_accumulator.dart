import 'dart:collection';

/// Result of one OCR frame observation.
final class OcrFrameUpdate {
  OcrFrameUpdate({
    required this.isStable,
    required List<String> newWords,
    required List<String> stableWords,
  })  : newWords = List<String>.unmodifiable(newWords),
        stableWords = List<String>.unmodifiable(stableWords);

  /// Whether the current non-empty frame reached the configured stability.
  final bool isStable;

  /// Stable word occurrences not returned by an earlier frame in this stream.
  final List<String> newWords;

  /// All word occurrences already committed for the current stream.
  final List<String> stableWords;

  bool get hasNewWords => newWords.isNotEmpty;
  String get newText => newWords.join(' ');
  String get stableText => stableWords.join(' ');

  // Romanian aliases used by the application layer.
  List<String> get cuvinteNoi => newWords;
  List<String> get cuvinteStabile => stableWords;
}

/// Stabilizes cumulative OCR frames and emits every word occurrence only once.
///
/// Camera OCR commonly returns the whole recognized prefix on every frame.
/// This class waits for matching consecutive frames, then reconciles the
/// stable frame with occurrences already emitted. A deliberately repeated word
/// at a new position is preserved, insertions are not lost, and reordered or
/// repeated frames do not duplicate the semantic stream.
final class OcrFrameAccumulator {
  OcrFrameAccumulator({this.requiredMatchingFrames = 2}) {
    if (requiredMatchingFrames < 1) {
      throw ArgumentError.value(
        requiredMatchingFrames,
        'requiredMatchingFrames',
        'must be at least 1',
      );
    }
  }

  final int requiredMatchingFrames;

  List<String> _candidateWords = const <String>[];
  int _candidateMatches = 0;
  final List<String> _committedWords = <String>[];

  static final RegExp _discardedPunctuation =
      RegExp(r'[.,\/#!$%\^&\*;:{}=\-_`~()]');

  UnmodifiableListView<String> get stableWords =>
      UnmodifiableListView<String>(_committedWords);
  String get stableText => _committedWords.join(' ');

  /// Observes one full OCR frame and returns only newly stable words.
  OcrFrameUpdate ingestFrame(String recognizedText) {
    final words = _tokenize(recognizedText);
    if (words.isEmpty) {
      _candidateWords = const <String>[];
      _candidateMatches = 0;
      return _update(isStable: false);
    }

    if (_sameWords(words, _candidateWords)) {
      _candidateMatches += 1;
      // Keep the newest spelling/casing even when comparison rules evolve.
      _candidateWords = words;
    } else {
      _candidateWords = words;
      _candidateMatches = 1;
    }

    if (_candidateMatches < requiredMatchingFrames) {
      return _update(isStable: false);
    }

    final newWords = _uncommittedOccurrences(words);
    _committedWords.addAll(newWords);
    return _update(isStable: true, newWords: newWords);
  }

  /// Romanian alias for [ingestFrame].
  OcrFrameUpdate absoarbeCadru(String textRecunoscut) {
    return ingestFrame(textRecunoscut);
  }

  /// Starts a distinct OCR stream. Previously emitted positions may be emitted
  /// again only after this explicit boundary.
  void startNewStream() => reset();

  /// Romanian alias for [startNewStream].
  void incepeFluxNou() => startNewStream();

  void reset() {
    _candidateWords = const <String>[];
    _candidateMatches = 0;
    _committedWords.clear();
  }

  OcrFrameUpdate _update({
    required bool isStable,
    List<String> newWords = const <String>[],
  }) {
    return OcrFrameUpdate(
      isStable: isStable,
      newWords: newWords,
      stableWords: _committedWords,
    );
  }

  static List<String> _tokenize(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return const <String>[];
    }
    return trimmed.split(RegExp(r'\s+'));
  }

  static bool _sameWords(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index++) {
      if (_wordKey(left[index]) != _wordKey(right[index])) {
        return false;
      }
    }
    return true;
  }

  List<String> _uncommittedOccurrences(List<String> words) {
    final availableOccurrences = <String, int>{};
    for (final word in _committedWords) {
      final key = _wordKey(word);
      availableOccurrences[key] = (availableOccurrences[key] ?? 0) + 1;
    }

    final uncommitted = <String>[];
    for (final word in words) {
      final key = _wordKey(word);
      final available = availableOccurrences[key] ?? 0;
      if (available > 0) {
        availableOccurrences[key] = available - 1;
      } else {
        uncommitted.add(word);
      }
    }
    return uncommitted;
  }

  static String _wordKey(String word) {
    return word.replaceAll(_discardedPunctuation, '').toLowerCase();
  }
}
