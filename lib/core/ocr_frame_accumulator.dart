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
/// view. This class waits for consecutive observations with identical token
/// surfaces, aligns the stable window in one global ledger, and preserves
/// already confirmed prefix and suffix positions. A deliberately repeated
/// word at a new position is preserved. Mapped edits request a replay so
/// order-sensitive consumers cannot silently append a word in the wrong
/// position.
///
/// Without OCR coordinates, an isolated word identical to an already
/// confirmed occurrence cannot be distinguished from the camera revisiting
/// that occurrence. The accumulator deliberately deduplicates that ambiguous
/// one-word frame. Repetition remains observable when the frame itself carries
/// positional evidence, for example `da da`.
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

    if (_sameSurfaceWords(words, _candidateWords)) {
      _candidateMatches += 1;
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

  static bool _sameSurfaceWords(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }

  OcrFrameUpdate _reconcileStableFrame(List<String> words) {
    final previousLedger = List<String>.of(_committedWords);
    if (previousLedger.isEmpty) {
      _committedWords.addAll(words);
      _rememberStableFrame(words, 0);
      return _update(isStable: true, appendedWords: words);
    }

    final preferredStart = _lastStableFrameWords.isEmpty
        ? 0
        : _lastStableFrameStart;
    final alignment = _bestGreedyAlignment(
      previousLedger,
      words,
      preferredStart: preferredStart,
    );
    final hasAnchor = alignment.any((position) => position >= 0);

    if (!hasAnchor) {
      final frameStart = _committedWords.length;
      _committedWords.addAll(words);
      _rememberStableFrame(words, frameStart);
      return _update(isStable: true, appendedWords: words);
    }

    final mergedLedger = <String>[];
    final mergedFramePositions = List<int>.filled(words.length, -1);
    final insertedWords = <String>[];
    var insertedInsideLedger = false;
    var ledgerCursor = 0;
    var frameCursor = 0;

    for (var frameIndex = 0; frameIndex < words.length; frameIndex++) {
      final ledgerIndex = alignment[frameIndex];
      if (ledgerIndex < 0) {
        continue;
      }

      mergedLedger.addAll(
        previousLedger.getRange(ledgerCursor, ledgerIndex),
      );
      while (frameCursor < frameIndex) {
        mergedFramePositions[frameCursor] = mergedLedger.length;
        mergedLedger.add(words[frameCursor]);
        insertedWords.add(words[frameCursor]);
        insertedInsideLedger = true;
        frameCursor += 1;
      }

      mergedFramePositions[frameIndex] = mergedLedger.length;
      // A normalized OCR match retains its first confirmed surface spelling.
      mergedLedger.add(previousLedger[ledgerIndex]);
      ledgerCursor = ledgerIndex + 1;
      frameCursor = frameIndex + 1;
    }

    final hasConfirmedSuffix = ledgerCursor < previousLedger.length;
    while (frameCursor < words.length) {
      mergedFramePositions[frameCursor] = mergedLedger.length;
      mergedLedger.add(words[frameCursor]);
      insertedWords.add(words[frameCursor]);
      insertedInsideLedger = insertedInsideLedger || hasConfirmedSuffix;
      frameCursor += 1;
    }
    mergedLedger.addAll(
      previousLedger.getRange(ledgerCursor, previousLedger.length),
    );

    _insertOnlyMergedWords(previousLedger, mergedLedger);
    final frameStart = mergedFramePositions.firstWhere(
      (position) => position >= 0,
      orElse: () => previousLedger.length,
    );
    _rememberStableFrame(words, frameStart);

    if (insertedInsideLedger) {
      return _update(isStable: true, requiresReplay: true);
    }
    return _update(isStable: true, appendedWords: insertedWords);
  }

  void _insertOnlyMergedWords(
    List<String> previousLedger,
    List<String> mergedLedger,
  ) {
    var previousIndex = 0;
    var mergedIndex = 0;
    while (mergedIndex < mergedLedger.length) {
      if (previousIndex < previousLedger.length &&
          mergedLedger[mergedIndex] == previousLedger[previousIndex]) {
        previousIndex += 1;
        mergedIndex += 1;
        continue;
      }

      _committedWords.insert(mergedIndex, mergedLedger[mergedIndex]);
      mergedIndex += 1;
    }
    assert(previousIndex == previousLedger.length);
  }

  void _rememberStableFrame(List<String> words, int frameStart) {
    _lastStableFrameWords = List<String>.of(words);
    _lastStableFrameStart = frameStart;
    // Every accepted frame starts a fresh stabilization window. Therefore the
    // next observation alone can never be emitted with the default threshold.
    _candidateWords = List<String>.of(words);
    _candidateMatches = 0;
  }

  static List<int> _bestGreedyAlignment(
    List<String> ledger,
    List<String> frame, {
    required int preferredStart,
  }) {
    final clampedStart = preferredStart.clamp(0, ledger.length).toInt();
    final preferred = _greedyAlignmentFrom(ledger, frame, clampedStart);
    final global = _greedyAlignmentFrom(ledger, frame, 0);
    final preferredMatches =
        preferred.where((position) => position >= 0).length;
    final globalMatches = global.where((position) => position >= 0).length;
    return preferredMatches >= globalMatches ? preferred : global;
  }

  static List<int> _greedyAlignmentFrom(
    List<String> ledger,
    List<String> frame,
    int start,
  ) {
    final positions = List<int>.filled(frame.length, -1);
    var ledgerCursor = start;
    for (var frameIndex = 0; frameIndex < frame.length; frameIndex++) {
      for (var ledgerIndex = ledgerCursor;
          ledgerIndex < ledger.length;
          ledgerIndex++) {
        if (_wordKey(ledger[ledgerIndex]) == _wordKey(frame[frameIndex])) {
          positions[frameIndex] = ledgerIndex;
          ledgerCursor = ledgerIndex + 1;
          break;
        }
      }
    }
    return positions;
  }

  static String _wordKey(String word) {
    return word.replaceAll(_discardedPunctuation, '').toLowerCase();
  }
}
