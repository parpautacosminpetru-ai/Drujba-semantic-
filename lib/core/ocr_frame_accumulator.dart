import 'dart:collection';

/// Result of one OCR frame observation.
final class OcrFrameUpdate {
  OcrFrameUpdate({
    required this.isStable,
    required List<String> appendedWords,
    required this.requiresReplay,
    required List<String> stableWords,
  })  : appendedWords = List<String>.unmodifiable(appendedWords),
        stableWords = List<String>.unmodifiable(stableWords);

  /// Whether the current non-empty frame reached the configured stability.
  final bool isStable;

  /// Stable suffix appended after the previously committed word positions.
  final List<String> appendedWords;

  /// Backwards-compatible alias for [appendedWords].
  List<String> get newWords => appendedWords;

  /// Whether the stable frame changed an already committed word position.
  ///
  /// Callers must rebuild their order-sensitive derived state from
  /// [stableWords] instead of appending [newWords] when this is `true`.
  final bool requiresReplay;

  /// All word occurrences already committed for the current stream.
  final List<String> stableWords;

  bool get hasNewWords => appendedWords.isNotEmpty;
  String get newText => appendedWords.join(' ');
  String get stableText => stableWords.join(' ');

  // Romanian aliases used by the application layer.
  List<String> get cuvinteNoi => appendedWords;
  List<String> get cuvinteStabile => stableWords;
}

/// Stabilizes overlapping OCR windows and emits every word occurrence once.
///
/// Camera OCR may return a cumulative prefix, a sliding window, or a corrected
/// view. This class waits for compatible consecutive observations, aligns the
/// stable window in one global ledger, and preserves already confirmed prefix
/// and suffix positions. A deliberately repeated word at a new position is
/// preserved. Mapped edits request a replay so order-sensitive consumers
/// cannot silently append a word in the wrong position.
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
  List<String> _lastStableFrameWords = const <String>[];
  int _lastStableFrameStart = 0;

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

    if (_similarEnough(words, _candidateWords)) {
      _candidateMatches += 1;
      // Keep the newest surface form so a stabilized OCR correction is not
      // hidden by normalized comparison.
      _candidateWords = words;
    } else {
      _candidateWords = words;
      _candidateMatches = 1;
    }

    if (_candidateMatches < requiredMatchingFrames) {
      return _update(isStable: false);
    }

    return _reconcileStableFrame(words);
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
    _lastStableFrameWords = const <String>[];
    _lastStableFrameStart = 0;
  }

  OcrFrameUpdate _update({
    required bool isStable,
    List<String> appendedWords = const <String>[],
    bool requiresReplay = false,
  }) {
    return OcrFrameUpdate(
      isStable: isStable,
      appendedWords: appendedWords,
      requiresReplay: requiresReplay,
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

  static bool _similarEnough(List<String> left, List<String> right) {
    if (left.isEmpty || right.isEmpty) {
      return false;
    }

    final lengthDifference = left.length - right.length;
    if (lengthDifference.abs() > 1) {
      return false;
    }

    if (lengthDifference == 0) {
      var fluctuations = 0;
      for (var index = 0; index < left.length; index++) {
        if (_wordKey(left[index]) != _wordKey(right[index])) {
          fluctuations += 1;
          if (fluctuations > 1) {
            return false;
          }
        }
      }
      return true;
    }

    final longer = left.length > right.length ? left : right;
    final shorter = left.length > right.length ? right : left;
    var longerIndex = 0;
    var shorterIndex = 0;
    var fluctuations = 0;
    while (longerIndex < longer.length && shorterIndex < shorter.length) {
      if (_wordKey(longer[longerIndex]) == _wordKey(shorter[shorterIndex])) {
        longerIndex += 1;
        shorterIndex += 1;
        continue;
      }
      fluctuations += 1;
      if (fluctuations > 1) {
        return false;
      }
      longerIndex += 1;
    }
    return true;
  }

  OcrFrameUpdate _reconcileStableFrame(List<String> words) {
    if (_lastStableFrameWords.isEmpty) {
      final frameStart = _committedWords.length;
      _committedWords.addAll(words);
      _rememberStableFrame(words, frameStart);
      return _update(isStable: true, appendedWords: words);
    }

    final existingFrameStart = _findNormalizedSubsequence(
      _committedWords,
      words,
      preferredStart: _lastStableFrameStart,
    );
    if (existingFrameStart >= 0) {
      final surfacesChanged = !_sameSurfaceSlices(
        _committedWords,
        existingFrameStart,
        words,
        0,
        words.length,
      );
      if (surfacesChanged) {
        _replaceMappedSegment(
          existingFrameStart,
          previousLength: words.length,
          replacement: words,
        );
        _rememberStableFrame(words, existingFrameStart);
        return _update(isStable: true, requiresReplay: true);
      }

      _rememberStableFrame(words, existingFrameStart);
      return _update(isStable: true);
    }

    if (_isNormalizedPrefix(_lastStableFrameWords, words)) {
      final surfacesChanged = !_sameSurfacePrefix(
        _lastStableFrameWords,
        words,
        _lastStableFrameWords.length,
      );
      if (surfacesChanged) {
        _replaceMappedSegment(
          _lastStableFrameStart,
          previousLength: _lastStableFrameWords.length,
          replacement: words,
        );
        _rememberStableFrame(words, _lastStableFrameStart);
        return _update(isStable: true, requiresReplay: true);
      }

      final appendedWords = words.sublist(_lastStableFrameWords.length);
      final mappedEnd =
          _lastStableFrameStart + _lastStableFrameWords.length;
      if (appendedWords.isNotEmpty && mappedEnd < _committedWords.length) {
        _replaceMappedSegment(
          _lastStableFrameStart,
          previousLength: _lastStableFrameWords.length,
          replacement: words,
        );
        _rememberStableFrame(words, _lastStableFrameStart);
        return _update(isStable: true, requiresReplay: true);
      }
      _committedWords.addAll(appendedWords);
      _rememberStableFrame(words, _lastStableFrameStart);
      return _update(isStable: true, appendedWords: appendedWords);
    }

    final overlap = _longestNormalizedSuffixPrefix(
      _lastStableFrameWords,
      words,
    );
    if (overlap > 0) {
      final frameStart = _lastStableFrameStart +
          _lastStableFrameWords.length -
          overlap;
      final overlapSurfaceChanged = !_sameSurfaceSlices(
        _lastStableFrameWords,
        _lastStableFrameWords.length - overlap,
        words,
        0,
        overlap,
      );
      if (overlapSurfaceChanged) {
        _replaceMappedSegment(
          frameStart,
          previousLength: overlap,
          replacement: words,
        );
        _rememberStableFrame(words, frameStart);
        return _update(isStable: true, requiresReplay: true);
      }

      final appendedWords = words.sublist(overlap);
      final overlapEnd = frameStart + overlap;
      if (appendedWords.isNotEmpty && overlapEnd < _committedWords.length) {
        _replaceMappedSegment(
          frameStart,
          previousLength: overlap,
          replacement: words,
        );
        _rememberStableFrame(words, frameStart);
        return _update(isStable: true, requiresReplay: true);
      }
      _committedWords.addAll(appendedWords);
      _rememberStableFrame(words, frameStart);
      return _update(isStable: true, appendedWords: appendedWords);
    }

    if (_looksLikeMappedSegmentEdit(_lastStableFrameWords, words)) {
      _replaceMappedSegment(
        _lastStableFrameStart,
        previousLength: _lastStableFrameWords.length,
        replacement: words,
      );
      _rememberStableFrame(words, _lastStableFrameStart);
      return _update(isStable: true, requiresReplay: true);
    }

    final frameStart = _committedWords.length;
    _committedWords.addAll(words);
    _rememberStableFrame(words, frameStart);
    return _update(isStable: true, appendedWords: words);
  }

  void _rememberStableFrame(List<String> words, int frameStart) {
    _lastStableFrameWords = List<String>.of(words);
    _lastStableFrameStart = frameStart;
    // Every accepted frame starts a fresh stabilization window. Therefore the
    // next observation alone can never be emitted with the default threshold.
    _candidateWords = List<String>.of(words);
    _candidateMatches = 0;
  }

  void _replaceMappedSegment(
    int start, {
    required int previousLength,
    required List<String> replacement,
  }) {
    final mappedLength = previousLength > replacement.length
        ? previousLength
        : replacement.length;
    final proposedEnd = start + mappedLength;
    final end = proposedEnd < _committedWords.length
        ? proposedEnd
        : _committedWords.length;
    _committedWords.replaceRange(start, end, replacement);
  }

  static bool _isNormalizedPrefix(
    List<String> prefix,
    List<String> words,
  ) {
    if (prefix.length > words.length) {
      return false;
    }
    for (var index = 0; index < prefix.length; index++) {
      if (_wordKey(prefix[index]) != _wordKey(words[index])) {
        return false;
      }
    }
    return true;
  }

  static int _longestNormalizedSuffixPrefix(
    List<String> previous,
    List<String> current,
  ) {
    final maximum = previous.length < current.length
        ? previous.length
        : current.length;
    for (var length = maximum; length > 0; length--) {
      final previousStart = previous.length - length;
      var matches = true;
      for (var offset = 0; offset < length; offset++) {
        if (_wordKey(previous[previousStart + offset]) !=
            _wordKey(current[offset])) {
          matches = false;
          break;
        }
      }
      if (matches) {
        return length;
      }
    }
    return 0;
  }

  static int _findNormalizedSubsequence(
    List<String> ledger,
    List<String> frame, {
    required int preferredStart,
  }) {
    if (frame.isEmpty || frame.length > ledger.length) {
      return -1;
    }

    var bestStart = -1;
    var bestDistance = ledger.length + 1;
    final lastStart = ledger.length - frame.length;
    for (var start = 0; start <= lastStart; start++) {
      var normalizedMatch = true;
      for (var offset = 0; offset < frame.length; offset++) {
        if (_wordKey(ledger[start + offset]) != _wordKey(frame[offset])) {
          normalizedMatch = false;
          break;
        }
      }
      if (!normalizedMatch) {
        continue;
      }

      final distance = (start - preferredStart).abs();
      if (distance < bestDistance) {
        bestStart = start;
        bestDistance = distance;
      }
    }

    return bestStart;
  }

  static bool _looksLikeMappedSegmentEdit(
    List<String> previous,
    List<String> current,
  ) {
    return _commonNormalizedPrefixLength(previous, current) > 0 ||
        _commonNormalizedSuffixLength(previous, current) > 0;
  }

  static int _commonNormalizedPrefixLength(
    List<String> left,
    List<String> right,
  ) {
    final maximum = left.length < right.length ? left.length : right.length;
    var length = 0;
    while (length < maximum &&
        _wordKey(left[length]) == _wordKey(right[length])) {
      length += 1;
    }
    return length;
  }

  static int _commonNormalizedSuffixLength(
    List<String> left,
    List<String> right,
  ) {
    final maximum = left.length < right.length ? left.length : right.length;
    var length = 0;
    while (length < maximum &&
        _wordKey(left[left.length - 1 - length]) ==
            _wordKey(right[right.length - 1 - length])) {
      length += 1;
    }
    return length;
  }

  static bool _sameSurfacePrefix(
    List<String> left,
    List<String> right,
    int length,
  ) {
    return _sameSurfaceSlices(left, 0, right, 0, length);
  }

  static bool _sameSurfaceSlices(
    List<String> left,
    int leftStart,
    List<String> right,
    int rightStart,
    int length,
  ) {
    for (var offset = 0; offset < length; offset++) {
      if (left[leftStart + offset] != right[rightStart + offset]) {
        return false;
      }
    }
    return true;
  }

  static String _wordKey(String word) {
    return word.replaceAll(_discardedPunctuation, '').toLowerCase();
  }
}
