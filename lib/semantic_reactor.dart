/// One explicit axiom in the local, directional semantic algebra.
final class SemanticAxiom {
  const SemanticAxiom(this.id, this.left, this.right, this.result);

  /// Stable proof identifier. IDs must be unique inside one reactor.
  final String id;

  /// Ordered left operand.
  final String left;

  /// Ordered right operand.
  final String right;

  /// Exact raw sense produced when both operands match.
  final String result;
}

/// One exact, deterministic fusion performed by [SemanticReactor].
final class SemanticFusionStep {
  SemanticFusionStep({
    required this.axiomId,
    required this.left,
    required this.right,
    required this.result,
    required List<String> sourceForms,
  }) : sourceForms = List<String>.unmodifiable(sourceForms);

  /// Stable ID of the axiom that justifies this reduction.
  final String axiomId;

  /// Raw sense on the left side of the matched axiom.
  final String left;

  /// Raw sense on the right side of the matched axiom.
  final String right;

  /// Exact result asserted by the local axiom.
  final String result;

  /// Original forms that contributed to this result, in scan order.
  final List<String> sourceForms;
}

/// A semantic object protected from subsequent folds.
final class LockedSemanticResult {
  LockedSemanticResult({
    required this.display,
    required this.rawSense,
    required List<String> sourceForms,
    required List<SemanticFusionStep> fusionSteps,
  })  : sourceForms = List<String>.unmodifiable(sourceForms),
        fusionSteps = List<SemanticFusionStep>.unmodifiable(fusionSteps);

  final String display;
  final String rawSense;
  final List<String> sourceForms;
  final List<SemanticFusionStep> fusionSteps;
}

/// Immutable public view of the reactor's active and locked semantic objects.
final class SemanticSnapshot {
  SemanticSnapshot({
    required this.display,
    required this.rawSense,
    required List<String> sourceForms,
    required List<SemanticFusionStep> fusionSteps,
    required List<LockedSemanticResult> locked,
    required this.isAxiomaticallyResolved,
    required List<String> unresolvedForms,
  })  : sourceForms = List<String>.unmodifiable(sourceForms),
        fusionSteps = List<SemanticFusionStep>.unmodifiable(fusionSteps),
        locked = List<LockedSemanticResult>.unmodifiable(locked),
        unresolvedForms = List<String>.unmodifiable(unresolvedForms);

  /// Bracketed, upper-case projection intended for the monolith widget.
  final String display;

  /// Current named fusion or ordered, unresolved composition without brackets.
  final String rawSense;

  /// Every accepted surface form, unchanged and in its original order.
  final List<String> sourceForms;

  /// Axiomatic proof steps performed for the active object.
  final List<SemanticFusionStep> fusionSteps;

  /// Objects frozen with [SemanticReactor.lockCurrent].
  final List<LockedSemanticResult> locked;

  /// True only when the final active root is justified by an exact axiom.
  final bool isAxiomaticallyResolved;

  /// Surface forms not covered by a final axiomatic subtree.
  final List<String> unresolvedForms;

  bool get isEmpty => sourceForms.isEmpty;
}

/// Offline, deterministic, left-to-right semantic folding reactor.
///
/// The display value of a successful fold may be compact, but each internal
/// node retains its children and therefore the complete ordered provenance.
/// Unknown combinations remain an ordered link joined by a hyphen. No form is
/// treated as a stop word and repeated forms remain distinct.
final class SemanticReactor {
  SemanticReactor({
    Map<String, Map<String, String>>? fusionMatrix,
    Iterable<SemanticAxiom>? axioms,
  }) : _axiomMatrix = _prepareAxioms(
          _selectAxioms(fusionMatrix: fusionMatrix, axioms: axioms),
        ) {
    _publishSnapshot();
  }

  /// The six explicit axioms supplied by the v2 technical specification.
  static const List<SemanticAxiom> defaultAxioms = <SemanticAxiom>[
    SemanticAxiom('AX-001', 'sistem', 'eșuat', 'Colaps'),
    SemanticAxiom('AX-002', 'sistem', 'politic', 'Guvernanță'),
    SemanticAxiom('AX-003', 'guvernanță', 'eșuat', 'Anomie'),
    SemanticAxiom('AX-004', 'guvernanță', 'corupt', 'Cleptocrație'),
    SemanticAxiom('AX-005', 'tehnologie', 'rapid', 'Hiper-Evoluție'),
    SemanticAxiom('AX-006', 'tehnologie', 'control', 'Cibernetică'),
  ];

  /// Legacy map representation of [defaultAxioms].
  ///
  /// Kept for source compatibility. New code should prefer explicit axioms so
  /// every proof step has a caller-defined stable ID.
  static const Map<String, Map<String, String>> defaultFusionMatrix =
      <String, Map<String, String>>{
    'sistem': <String, String>{
      'eșuat': 'Colaps',
      'politic': 'Guvernanță',
    },
    'guvernanță': <String, String>{
      'eșuat': 'Anomie',
      'corupt': 'Cleptocrație',
    },
    'tehnologie': <String, String>{
      'rapid': 'Hiper-Evoluție',
      'control': 'Cibernetică',
    },
  };

  static const String _emptyDisplay = '[FLUX-VID]';

  /// Explicit OCR aliases for concepts that occur in the bundled matrix.
  ///
  /// This is intentionally not a global diacritic stripper: unrelated words
  /// such as `fată` and `față` must remain distinct semantic forms.
  static const Map<String, String> _matrixOcrAliases = <String, String>{
    'esuat': 'eșuat',
    'guvernanta': 'guvernanță',
    'cleptocratie': 'cleptocrație',
    'cibernetica': 'cibernetică',
    'hiper-evolutie': 'hiper-evoluție',
  };

  final Map<String, Map<String, _PreparedAxiom>> _axiomMatrix;
  final List<SemanticFusionStep> _activeFusionSteps =
      <SemanticFusionStep>[];
  final List<LockedSemanticResult> _locked = <LockedSemanticResult>[];

  _SemanticNode? _root;
  late SemanticSnapshot _snapshot;

  SemanticSnapshot get snapshot => _snapshot;

  /// Integrates one lexical form into the active semantic object.
  ///
  /// Empty and whitespace-only inputs do not represent lexical forms and are
  /// ignored. Every other surface string is preserved verbatim in provenance.
  SemanticSnapshot integrateForm(String form) {
    _appendForm(form);
    _publishSnapshot();
    return _snapshot;
  }

  /// Appends already ordered forms to the active semantic object.
  SemanticSnapshot integrateForms(Iterable<String> forms) {
    for (final form in forms) {
      _appendForm(form);
    }
    _publishSnapshot();
    return _snapshot;
  }

  /// Rebuilds only the active object while preserving every locked object.
  ///
  /// This is intended for a corrected or restabilized OCR token sequence.
  SemanticSnapshot replaceActiveForms(Iterable<String> forms) {
    _root = null;
    _activeFusionSteps.clear();
    for (final form in forms) {
      _appendForm(form);
    }
    _publishSnapshot();
    return _snapshot;
  }

  /// Freezes the active semantic object and starts a new empty active object.
  ///
  /// A lock is a semantic boundary. Later forms cannot collapse with the
  /// frozen tree. Locking an empty or still-atomic stream is a deterministic
  /// no-op because the UI's Zăvor applies only to composed semantic objects.
  SemanticSnapshot lockCurrent() {
    final root = _root;
    if (root != null && root.sourceForms.length > 1) {
      _locked.add(
        LockedSemanticResult(
          display: _displayFor(root.rawSense),
          rawSense: root.rawSense,
          sourceForms: root.sourceForms,
          fusionSteps: _activeFusionSteps,
        ),
      );
      _root = null;
      _activeFusionSteps.clear();
    }
    _publishSnapshot();
    return _snapshot;
  }

  /// Removes one locked object. Invalid indices throw [RangeError].
  SemanticSnapshot removeLockedAt(int index) {
    _locked.removeAt(index);
    _publishSnapshot();
    return _snapshot;
  }

  /// Clears the active tree, its trace, and every lock.
  SemanticSnapshot reset() {
    _root = null;
    _activeFusionSteps.clear();
    _locked.clear();
    _publishSnapshot();
    return _snapshot;
  }

  void _appendForm(String surface) {
    final rawSense = surface.trim();
    if (rawSense.isEmpty) {
      return;
    }

    final atom = _Atom(
      surface: surface,
      rawSense: rawSense,
      lookupKey: _normalizeLookup(rawSense),
    );
    final root = _root;
    if (root == null) {
      _root = atom;
      return;
    }

    _root = _reducePair(root, atom).node;
  }

  /// Reduces only exact rules on the newly formed right edge.
  ///
  /// A full current-state match wins first. If it is undefined, the reducer
  /// tries the rightmost unresolved link. This lets a third form collapse an
  /// earlier barrier without reordering or discarding the untouched prefix.
  _Reduction _reducePair(_SemanticNode left, _SemanticNode right) {
    final axiom = _lookupAxiom(left.lookupKey, right.lookupKey);
    if (axiom != null) {
      final fused = _Fused(
        left: left,
        right: right,
        axiomId: axiom.id,
        resultSense: axiom.result,
        lookupKey: _normalizeLookup(axiom.result),
      );
      _activeFusionSteps.add(
        SemanticFusionStep(
          axiomId: axiom.id,
          left: left.rawSense,
          right: right.rawSense,
          result: axiom.result,
          sourceForms: fused.sourceForms,
        ),
      );
      return _Reduction(node: fused, changed: true);
    }

    if (left is _Linked) {
      final suffix = _reducePair(left.right, right);
      if (suffix.changed) {
        final withPrefix = _reducePair(left.left, suffix.node);
        return _Reduction(node: withPrefix.node, changed: true);
      }
    }

    return _Reduction(
      node: _Linked(left: left, right: right),
      changed: false,
    );
  }

  _PreparedAxiom? _lookupAxiom(String left, String right) {
    return _axiomMatrix[left]?[right];
  }

  void _publishSnapshot() {
    final root = _root;
    _snapshot = SemanticSnapshot(
      display: root == null ? _emptyDisplay : _displayFor(root.rawSense),
      rawSense: root?.rawSense ?? '',
      sourceForms: root?.sourceForms ?? const <String>[],
      fusionSteps: _activeFusionSteps,
      locked: _locked,
      isAxiomaticallyResolved: root is _Fused && root.axiomId.isNotEmpty,
      unresolvedForms: root?.unresolvedForms ?? const <String>[],
    );
  }

  static String _displayFor(String rawSense) => '[${rawSense.toUpperCase()}]';

  /// Produces a lookup-only spelling while leaving the source surface intact.
  ///
  /// Romanian comma/cedilla variants and decomposed marks are canonicalized.
  /// Missing diacritics are accepted only through [_matrixOcrAliases], so this
  /// lookup never merges arbitrary Romanian words with different meanings.
  static String _normalizeLookup(String value) {
    var normalized = value.trim().toLowerCase();

    normalized = normalized
        .replaceAll('a\u0306', 'ă')
        .replaceAll('a\u0302', 'â')
        .replaceAll('i\u0302', 'î')
        .replaceAll('s\u0326', 'ș')
        .replaceAll('s\u0327', 'ș')
        .replaceAll('t\u0326', 'ț')
        .replaceAll('t\u0327', 'ț')
        .replaceAll('ş', 'ș')
        .replaceAll('ţ', 'ț');

    return _matrixOcrAliases[normalized] ?? normalized;
  }

  static Iterable<SemanticAxiom> _selectAxioms({
    required Map<String, Map<String, String>>? fusionMatrix,
    required Iterable<SemanticAxiom>? axioms,
  }) {
    if (fusionMatrix != null && axioms != null) {
      throw ArgumentError(
        'Provide either axioms or fusionMatrix, never both.',
      );
    }
    if (axioms != null) {
      return axioms;
    }
    if (fusionMatrix != null) {
      return _axiomsFromLegacyMatrix(fusionMatrix);
    }
    return defaultAxioms;
  }

  static Iterable<SemanticAxiom> _axiomsFromLegacyMatrix(
    Map<String, Map<String, String>> source,
  ) {
    final byPair = <String, SemanticAxiom>{};
    for (final leftEntry in source.entries) {
      for (final rightEntry in leftEntry.value.entries) {
        final left = _normalizeLookup(leftEntry.key);
        final right = _normalizeLookup(rightEntry.key);
        final id = 'matrix:$left+$right';
        final candidate = SemanticAxiom(
          id,
          leftEntry.key,
          rightEntry.key,
          rightEntry.value,
        );
        final existing = byPair[id];
        if (existing != null) {
          if (existing.result.trim() != candidate.result.trim()) {
            throw ArgumentError(
              'Conflicting fusion rules after lookup normalization: '
              '${leftEntry.key} + ${rightEntry.key}',
            );
          }
          continue;
        }
        byPair[id] = candidate;
      }
    }
    return List<SemanticAxiom>.unmodifiable(byPair.values);
  }

  static Map<String, Map<String, _PreparedAxiom>> _prepareAxioms(
    Iterable<SemanticAxiom> source,
  ) {
    final prepared = <String, Map<String, _PreparedAxiom>>{};
    final axiomIds = <String>{};

    for (final axiom in source) {
      final id = axiom.id.trim();
      final left = _normalizeLookup(axiom.left);
      final right = _normalizeLookup(axiom.right);
      final result = axiom.result.trim();
      if (id.isEmpty || left.isEmpty || right.isEmpty || result.isEmpty) {
        throw ArgumentError.value(
          axiom,
          'axioms',
          'Axiom IDs, operands, and results must not be empty',
        );
      }
      if (!axiomIds.add(id)) {
        throw ArgumentError.value(
          id,
          'axioms',
          'Axiom IDs must be unique',
        );
      }

      final preparedAxiom = _PreparedAxiom(
        id: id,
        result: result,
      );
      final rightMap = prepared.putIfAbsent(
        left,
        () => <String, _PreparedAxiom>{},
      );
      final existing = rightMap[right];
      if (existing != null) {
        throw ArgumentError(
          'Conflicting axioms for the normalized pair '
          '${axiom.left} + ${axiom.right}: ${existing.id} and $id',
        );
      }
      rightMap[right] = preparedAxiom;
    }

    return Map<String, Map<String, _PreparedAxiom>>.unmodifiable(
      prepared.map(
        (key, value) => MapEntry<String, Map<String, _PreparedAxiom>>(
          key,
          Map<String, _PreparedAxiom>.unmodifiable(value),
        ),
      ),
    );
  }
}

sealed class _SemanticNode {
  String get rawSense;
  String get lookupKey;
  List<String> get sourceForms;
  List<String> get unresolvedForms;
}

/// One input form. [surface] is never normalized or rewritten.
final class _Atom extends _SemanticNode {
  _Atom({
    required this.surface,
    required this.rawSense,
    required this.lookupKey,
  })  : sourceForms = List<String>.unmodifiable(<String>[surface]),
        unresolvedForms = List<String>.unmodifiable(<String>[surface]);

  final String surface;

  @override
  final String rawSense;

  @override
  final String lookupKey;

  @override
  final List<String> sourceForms;

  @override
  final List<String> unresolvedForms;
}

/// Ordered geometric connection retained when no exact rule is defined.
final class _Linked extends _SemanticNode {
  _Linked({required this.left, required this.right})
      : rawSense = '${left.rawSense}-${right.rawSense}',
        lookupKey = '${left.lookupKey}-${right.lookupKey}',
        sourceForms = List<String>.unmodifiable(
          <String>[...left.sourceForms, ...right.sourceForms],
        ),
        unresolvedForms = List<String>.unmodifiable(
          <String>[...left.unresolvedForms, ...right.unresolvedForms],
        );

  final _SemanticNode left;
  final _SemanticNode right;

  @override
  final String rawSense;

  @override
  final String lookupKey;

  @override
  final List<String> sourceForms;

  @override
  final List<String> unresolvedForms;
}

/// Named result of an exact matrix rule with both operands retained.
final class _Fused extends _SemanticNode {
  _Fused({
    required this.left,
    required this.right,
    required this.axiomId,
    required String resultSense,
    required this.lookupKey,
  })  : rawSense = resultSense,
        sourceForms = List<String>.unmodifiable(
          <String>[...left.sourceForms, ...right.sourceForms],
        );

  final _SemanticNode left;
  final _SemanticNode right;
  final String axiomId;

  @override
  final String rawSense;

  @override
  final String lookupKey;

  @override
  final List<String> sourceForms;

  @override
  List<String> get unresolvedForms => const <String>[];
}

final class _PreparedAxiom {
  const _PreparedAxiom({
    required this.id,
    required this.result,
  });

  final String id;
  final String result;
}

final class _Reduction {
  const _Reduction({required this.node, required this.changed});

  final _SemanticNode node;
  final bool changed;
}
