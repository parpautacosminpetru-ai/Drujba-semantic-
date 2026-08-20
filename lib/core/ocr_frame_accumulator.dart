import 'dart:collection';

/// One stabilized OCR observation.
final class OcrFrameUpdate {
  OcrFrameUpdate({
    required this.isStable,
    required List<String> stableTokens,
    required List<String> changedTokens,
    required this.changedFromIndex,
  })  : stableTokens = List<String>.unmodifiable(stableTokens),
        changedTokens = List<String>.unmodifiable(changedTokens);

  final bool isStable;
  final List<String> stableTokens;

  /// Suffix beginning at [changedFromIndex] after positional reconciliation.
  final List<String> changedTokens;

  /// Zero-based position at which the stable OCR stream diverged. -1 means
  /// that no committed semantic position changed in this update.
  final int changedFromIndex;

  bool get hasChanges => changedFromIndex >= 0;

  // Compatibility aliases.
  List<String> get newWords => changedTokens;
  List<String> get stableWords => stableTokens;
  String get newText => changedTokens.join(' ');
  String get stableText => stableTokens.join(' ');
  List<String> get cuvinteNoi => changedTokens;
  List<String> get cuvinteStabile => stableTokens;
}

/// Stabilizes full OCR frames while preserving exact token order and
/// punctuation. Corrections are reported positionally so the semantic engine
/// can roll back to S_(k-1) and replay the corrected suffix.
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

  List<String> _candidateTokens = const <String>[];
  int _candidateMatches = 0;
  final List<String> _stableTokens = <String>[];

  UnmodifiableListView<String> get stableTokens =>
      UnmodifiableListView<String>(_stableTokens);
  UnmodifiableListView<String> get stableWords => stableTokens;
  String get stableText => _stableTokens.join(' ');

  OcrFrameUpdate ingestFrame(String recognizedText) {
    final tokens = tokenizeText(recognizedText);
    if (tokens.isEmpty) {
      _candidateTokens = const <String>[];
      _candidateMatches = 0;
      return _update(isStable: false);
    }

    if (_sameTokens(tokens, _candidateTokens)) {
      _candidateMatches += 1;
      _candidateTokens = tokens;
    } else {
      _candidateTokens = tokens;
      _candidateMatches = 1;
    }

    if (_candidateMatches < requiredMatchingFrames) {
      return _update(isStable: false);
    }

    final common = _commonPrefixLength(_stableTokens, tokens);
    if (common == _stableTokens.length && common == tokens.length) {
      return _update(isStable: true);
    }

    _stableTokens
      ..clear()
      ..addAll(tokens);

    return _update(
      isStable: true,
      changedFromIndex: common,
      changedTokens: tokens.sublist(common),
    );
  }

  OcrFrameUpdate absoarbeCadru(String textRecunoscut) =>
      ingestFrame(textRecunoscut);

  void startNewStream() => reset();
  void incepeFluxNou() => startNewStream();

  void reset() {
    _candidateTokens = const <String>[];
    _candidateMatches = 0;
    _stableTokens.clear();
  }

  OcrFrameUpdate _update({
    required bool isStable,
    int changedFromIndex = -1,
    List<String> changedTokens = const <String>[],
  }) {
    return OcrFrameUpdate(
      isStable: isStable,
      stableTokens: _stableTokens,
      changedTokens: changedTokens,
      changedFromIndex: changedFromIndex,
    );
  }

  /// Tokenization is lossless at word/punctuation level. Punctuation is kept as
  /// its own C_n contribution instead of being stripped from a neighboring word.
  static List<String> tokenizeText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return const <String>[];
    }

    final matcher = RegExp(
      r'''[A-Za-zĂÂÎȘȚŢŢăâîșțşţ0-9]+(?:['’][A-Za-zĂÂÎȘȚŞŢăâîșțşţ0-9]+)*|[.,;:!?…()\[\]{}„”"«»—–-]''',
      unicode: true,
    );
    return matcher
        .allMatches(trimmed)
        .map((match) => match.group(0)!)
        .toList(growable: false);
  }

  static bool _sameTokens(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index++) {
      if (_tokenKey(left[index]) != _tokenKey(right[index])) {
        return false;
      }
    }
    return true;
  }

  static int _commonPrefixLength(List<String> left, List<String> right) {
    final limit = left.length < right.length ? left.length : right.length;
    var index = 0;
    while (index < limit && _tokenKey(left[index]) == _tokenKey(right[index])) {
      index += 1;
    }
    return index;
  }

  static String _tokenKey(String token) => token.trim().toLowerCase();
}
