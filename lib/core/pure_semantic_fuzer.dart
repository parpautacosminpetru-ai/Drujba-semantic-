import 'dart:collection';

/// A semantic item prepared for display by the user interface.
final class SemanticElement {
  const SemanticElement({
    required this.value,
    required this.frequency,
    required this.locked,
  });

  /// The exact display value used in the generated monolith.
  final String value;

  /// Number of non-stop-word observations, including observations while locked.
  final int frequency;

  /// Whether future observations of this concept are currently ignored.
  final bool locked;
}

/// An immutable, insertion-ordered view of the fuzer's current state.
final class SemanticSnapshot {
  SemanticSnapshot({
    required List<SemanticElement> substances,
    required List<SemanticElement> dynamics,
    required List<SemanticElement> attributes,
    required this.monolith,
  })  : substances = List<SemanticElement>.unmodifiable(substances),
        dynamics = List<SemanticElement>.unmodifiable(dynamics),
        attributes = List<SemanticElement>.unmodifiable(attributes);

  final List<SemanticElement> substances;
  final List<SemanticElement> dynamics;
  final List<SemanticElement> attributes;
  final String monolith;

  // Romanian aliases keep the public API traceable to the specification.
  List<SemanticElement> get substante => substances;
  List<SemanticElement> get dinamici => dynamics;
  List<SemanticElement> get atribute => attributes;
}

/// Deterministic, offline semantic fusion engine from the project specification.
///
/// Words are kept in insertion order and are never predictively completed or
/// paraphrased. Duplicate words increase their frequency without changing the
/// order of the generated monolith.
final class PureSemanticFuzer {
  final LinkedHashSet<String> _substances = LinkedHashSet<String>();
  final LinkedHashSet<String> _dynamics = LinkedHashSet<String>();
  final LinkedHashSet<String> _attributes = LinkedHashSet<String>();
  final LinkedHashSet<String> _lockedConcepts = LinkedHashSet<String>();
  final LinkedHashMap<String, int> _frequencies = LinkedHashMap<String, int>();

  static final RegExp _discardedPunctuation =
      RegExp(r'[.,\/#!$%\^&\*;:{}=\-_`~()]');

  /// Function words excluded verbatim by the supplied specification.
  static const Set<String> stopWords = <String>{
    'și',
    'sau',
    'dar',
    'iar',
    'încât',
    'ca',
    'să',
    'o',
    'un',
    'unui',
    'unei',
    'pe',
    'la',
    'în',
    'din',
    'cu',
    'de',
    'prin',
    'pentru',
    'este',
    'sunt',
    'a',
    'al',
    'ai',
    'ale',
    'ce',
    'care',
    'ci',
    'ba',
    'deci',
    'prin urmare',
    'asupra',
    'sub',
    'peste',
  };

  /// Absorbs one word into exactly one grammatical category.
  ///
  /// The frequency is updated before the lock is checked, matching the PDF
  /// algorithm. Unknown tags deliberately fall back to `SUBSTANTIV`.
  void absorbWord(String word, String grammaticalTag) {
    final cleaned = _clean(word);
    final normalized = cleaned.toLowerCase();
    if (normalized.isEmpty || stopWords.contains(normalized)) {
      return;
    }

    final concept = _conceptKey(cleaned);
    _frequencies[concept] = (_frequencies[concept] ?? 0) + 1;
    if (_lockedConcepts.contains(_lockKey(concept))) {
      return;
    }

    switch (grammaticalTag.toUpperCase()) {
      case 'SUBSTANTIV':
        _substances.add(concept);
      case 'VERB':
        _dynamics.add(concept);
      case 'ADJECTIV':
      case 'ADVERB':
        _attributes.add(normalized);
      default:
        _substances.add(concept);
    }
  }

  /// Romanian alias from the supplied implementation contract.
  void absoarbeCuvantLiniar(String cuvant, String tagGramatical) {
    absorbWord(cuvant, tagGramatical);
  }

  /// Locks a concept so later observations only update its frequency.
  void lock(String value) {
    final key = _lockKey(value);
    if (key.isNotEmpty) {
      _lockedConcepts.add(key);
    }
  }

  /// Romanian alias from the supplied implementation contract.
  void aplicaZavor(String element) => lock(element);

  /// Unlocks a concept and allows later observations to enter a category.
  void unlock(String value) {
    final key = _lockKey(value);
    if (key.isNotEmpty) {
      _lockedConcepts.remove(key);
    }
  }

  /// Romanian alias from the supplied implementation contract.
  void eliminaZavor(String element) => unlock(element);

  /// Toggles a concept lock and returns its new state.
  bool toggleLock(String value) {
    final key = _lockKey(value);
    if (key.isEmpty) {
      return false;
    }
    if (_lockedConcepts.remove(key)) {
      return false;
    }
    _lockedConcepts.add(key);
    return true;
  }

  /// Romanian alias for [toggleLock].
  bool comutaZavor(String element) => toggleLock(element);

  bool isLocked(String value) {
    final key = _lockKey(value);
    return key.isNotEmpty && _lockedConcepts.contains(key);
  }

  int frequencyOf(String value) {
    final key = _lockKey(value);
    if (key.isEmpty) {
      return 0;
    }
    return _frequencies.entries
        .where((entry) => _lockKey(entry.key) == key)
        .fold<int>(0, (total, entry) => total + entry.value);
  }

  /// Frequencies in the order in which concepts were first observed.
  Map<String, int> get frequencies =>
      UnmodifiableMapView<String, int>(_frequencies);

  /// Generates the monolith using the exact separators from the PDF.
  String generateMonolith() {
    if (_substances.isEmpty && _dynamics.isEmpty && _attributes.isEmpty) {
      return '[Flux-Vid]';
    }

    final substance = _substances.join('-');
    final dynamic = _dynamics.isEmpty ? '' : ' ➔ [${_dynamics.join('-')}]';
    final attributes = _attributes.isEmpty
        ? ''
        : ' ${_attributes.map((attribute) => '[$attribute]').join()}';
    return '[$substance]$dynamic$attributes';
  }

  /// Romanian alias from the supplied implementation contract.
  String genereazaMonolit() => generateMonolith();

  SemanticSnapshot get snapshot => SemanticSnapshot(
        substances: _elementsFor(_substances),
        dynamics: _elementsFor(_dynamics),
        attributes: _elementsFor(_attributes),
        monolith: generateMonolith(),
      );

  /// Romanian alias for [snapshot].
  SemanticSnapshot get stareCurenta => snapshot;

  /// Clears categories, frequencies, and locks for a completely new session.
  void reset() {
    _substances.clear();
    _dynamics.clear();
    _attributes.clear();
    _lockedConcepts.clear();
    _frequencies.clear();
  }

  List<SemanticElement> _elementsFor(Iterable<String> values) {
    return values
        .map(
          (value) => SemanticElement(
            value: value,
            frequency: frequencyOf(value),
            locked: isLocked(value),
          ),
        )
        .toList(growable: false);
  }

  static String _clean(String value) {
    return value.replaceAll(_discardedPunctuation, '').trim();
  }

  static String _conceptKey(String cleanedValue) {
    if (cleanedValue.isEmpty) {
      return '';
    }
    return '${cleanedValue.substring(0, 1).toUpperCase()}'
        '${cleanedValue.substring(1)}';
  }

  static String _lockKey(String value) => _clean(value).toLowerCase();
}
