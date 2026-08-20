import 'dart:collection';

import 'romanian_rule_tagger.dart';

/// One explicit contribution C_n entering the unique evolving semantic state.
final class SemanticContribution {
  const SemanticContribution({
    required this.index,
    required this.surface,
    required this.category,
    required this.explicitMeaning,
  });

  final int index;
  final String surface;
  final String category;
  final String explicitMeaning;
}

/// Immutable view of the single semantic object S_n.
final class SemanticSnapshot {
  SemanticSnapshot({
    required List<SemanticContribution> contributions,
    required this.rawMeaning,
    required this.formalState,
  }) : contributions = List<SemanticContribution>.unmodifiable(contributions);

  final List<SemanticContribution> contributions;

  /// The explicit, integrated meaning. It is not a summary.
  final String rawMeaning;

  /// Mathematical state label for the current linear transition.
  final String formalState;

  int get tokenCount => contributions.length;
  bool get isEmpty => contributions.isEmpty;

  // Compatibility alias used by the previous UI.
  String get monolith => rawMeaning;
}

/// Linear no-loss semantic synthesizer.
///
/// Invariant:
///   S_0 = ∅
///   S_n = F(S_(n-1), C_n)
///
/// Every token occurrence, including function words and punctuation, produces
/// exactly one [SemanticContribution]. The engine never removes stop words,
/// deduplicates concepts, predicts missing text, or imports external context.
/// Ambiguous closed-class forms retain slash-separated alternatives.
final class PureSemanticFuzer {
  final List<String> _tokens = <String>[];
  final List<SemanticContribution> _contributions = <SemanticContribution>[];
  final List<_MeaningNode?> _states = <_MeaningNode?>[];

  _MeaningNode? _current;

  int get tokenCount => _tokens.length;
  UnmodifiableListView<String> get tokens => UnmodifiableListView(_tokens);

  /// Integrates one already-analyzed token into the same evolving object.
  void absorbAnalysis(RomanianTokenAnalysis analysis) {
    if (analysis.surface.isEmpty) {
      return;
    }

    final contribution = SemanticContribution(
      index: _tokens.length + 1,
      surface: analysis.surface,
      category: analysis.category,
      explicitMeaning: analysis.explicitMeaning,
    );

    _tokens.add(analysis.surface);
    _contributions.add(contribution);
    _current = _integrate(_current, analysis);
    _states.add(_current);
  }

  void absorbToken(String token, RomanianRuleTagger tagger) {
    absorbAnalysis(tagger.analyzeToken(token));
  }

  void absorbTokens(Iterable<String> tokens, RomanianRuleTagger tagger) {
    for (final token in tokens) {
      absorbToken(token, tagger);
    }
  }

  /// Compatibility API from v1.0. The supplied tag is intentionally ignored:
  /// the conservative token analyzer owns grammatical/operator decisions.
  void absorbWord(String word, String grammaticalTag) {
    absorbToken(word, const RomanianRuleTagger());
  }

  void absoarbeCuvantLiniar(String cuvant, String tagGramatical) {
    absorbWord(cuvant, tagGramatical);
  }

  /// Reconciles an OCR segment against the exact token positions already
  /// integrated from [baseIndex] onward. If OCR corrects an earlier token, the
  /// state rolls back to S_(k-1), then replays linearly from the correction.
  void reconcileTail({
    required int baseIndex,
    required List<String> tokens,
    required RomanianRuleTagger tagger,
  }) {
    if (baseIndex < 0 || baseIndex > _tokens.length) {
      throw RangeError.range(baseIndex, 0, _tokens.length, 'baseIndex');
    }

    final oldTail = _tokens.sublist(baseIndex);
    var common = 0;
    final limit = oldTail.length < tokens.length ? oldTail.length : tokens.length;
    while (common < limit &&
        _tokenKey(oldTail[common]) == _tokenKey(tokens[common])) {
      common += 1;
    }

    final rollbackIndex = baseIndex + common;
    rollbackTo(rollbackIndex);
    absorbTokens(tokens.skip(common), tagger);
  }

  /// Rolls the unique semantic state back to exactly S_[tokenCount].
  void rollbackTo(int tokenCount) {
    if (tokenCount < 0 || tokenCount > _tokens.length) {
      throw RangeError.range(tokenCount, 0, _tokens.length, 'tokenCount');
    }
    if (tokenCount == _tokens.length) {
      return;
    }

    _tokens.removeRange(tokenCount, _tokens.length);
    _contributions.removeRange(tokenCount, _contributions.length);
    _states.removeRange(tokenCount, _states.length);
    _current = tokenCount == 0 ? null : _states[tokenCount - 1];
  }

  String generateMonolith() => snapshot.rawMeaning;
  String genereazaMonolit() => generateMonolith();

  SemanticSnapshot get snapshot {
    final n = _tokens.length;
    final raw = _current?.render() ?? '∅';
    final formal = n == 0
        ? 'S₀ = ∅'
        : 'S$n = F(S${n - 1}, C$n)  •  Sₙ = F(...F(S₀,C₁)...,Cₙ)';
    return SemanticSnapshot(
      contributions: _contributions,
      rawMeaning: raw,
      formalState: formal,
    );
  }

  SemanticSnapshot get stareCurenta => snapshot;

  void reset() {
    _tokens.clear();
    _contributions.clear();
    _states.clear();
    _current = null;
  }

  _MeaningNode _integrate(
    _MeaningNode? state,
    RomanianTokenAnalysis analysis,
  ) {
    if (analysis.isPunctuation) {
      final punctuation = _PunctuationNode(
        symbol: analysis.surface,
        meaning: analysis.explicitMeaning,
      );
      return state == null ? punctuation : _FusionNode(state, punctuation);
    }

    if (analysis.modifiesPrevious && state != null && !_hasOpenRightEdge(state)) {
      return _modifyRightEdge(
        state,
        _ModifierNode(
          surface: analysis.surface,
          meaning: analysis.explicitMeaning,
        ),
      );
    }

    final unit = _nodeFor(analysis);
    if (state == null) {
      return unit;
    }

    // A connector arriving after a complete state uses that whole state as
    // its explicit left argument. If an earlier operator is still open, the
    // connector first becomes that operator's current operand.
    if (analysis.category == RomanianRuleTagger.conjunctionTag) {
      final nested = _fillOpenRightEdge(state, unit);
      if (nested.didFill) {
        return nested.node;
      }
      return _OpenConnectorNode(analysis.explicitMeaning, state);
    }

    final fill = _fillOpenRightEdge(state, unit);
    if (fill.didFill) {
      return fill.node;
    }
    return _FusionNode(state, unit);
  }

  static _MeaningNode _nodeFor(RomanianTokenAnalysis analysis) {
    switch (analysis.category) {
      case RomanianRuleTagger.prepositionTag:
        return _OpenRelationNode(analysis.explicitMeaning);
      case RomanianRuleTagger.conjunctionTag:
        return _OpenConnectorNode(analysis.explicitMeaning);
      case RomanianRuleTagger.negationTag:
        return _OpenUnaryNode(analysis.explicitMeaning);
      case RomanianRuleTagger.determinerTag:
        return _OpenUnaryNode(analysis.explicitMeaning);
      case RomanianRuleTagger.quantifierTag:
        return _OpenUnaryNode(analysis.explicitMeaning);
      case RomanianRuleTagger.auxiliaryTag:
        return _SemanticAtom(
          surface: analysis.surface,
          meaning: analysis.explicitMeaning,
        );
      case RomanianRuleTagger.copulaTag:
        return _SemanticAtom(
          surface: analysis.surface,
          meaning: analysis.explicitMeaning,
        );
      case RomanianRuleTagger.pronounTag:
      case RomanianRuleTagger.ambiguousTag:
      case RomanianRuleTagger.possessiveTag:
      case RomanianRuleTagger.numeralTag:
      case RomanianRuleTagger.lexemeTag:
      default:
        return _SemanticAtom(
          surface: analysis.surface,
          meaning: analysis.explicitMeaning,
        );
    }
  }

  static bool _hasOpenRightEdge(_MeaningNode node) {
    if (node is _OpenRelationNode ||
        node is _OpenUnaryNode ||
        node is _OpenConnectorNode) {
      return true;
    }
    if (node is _FusionNode) {
      return _hasOpenRightEdge(node.right);
    }
    if (node is _RelationNode) {
      return _hasOpenRightEdge(node.object);
    }
    if (node is _UnaryNode) {
      return _hasOpenRightEdge(node.operand);
    }
    if (node is _ConnectorNode) {
      return _hasOpenRightEdge(node.right);
    }
    if (node is _ModifiedNode) {
      return _hasOpenRightEdge(node.base);
    }
    return false;
  }

  static _FillResult _fillOpenRightEdge(_MeaningNode node, _MeaningNode unit) {
    if (node is _OpenRelationNode) {
      return _FillResult(_RelationNode(node.operator, unit), true);
    }
    if (node is _OpenUnaryNode) {
      return _FillResult(_UnaryNode(node.operator, unit), true);
    }
    if (node is _OpenConnectorNode) {
      return _FillResult(_ConnectorNode(node.operator, node.left, unit), true);
    }
    if (node is _FusionNode) {
      final result = _fillOpenRightEdge(node.right, unit);
      return result.didFill
          ? _FillResult(_FusionNode(node.left, result.node), true)
          : _FillResult(node, false);
    }
    if (node is _RelationNode) {
      final result = _fillOpenRightEdge(node.object, unit);
      return result.didFill
          ? _FillResult(_RelationNode(node.operator, result.node), true)
          : _FillResult(node, false);
    }
    if (node is _UnaryNode) {
      final result = _fillOpenRightEdge(node.operand, unit);
      return result.didFill
          ? _FillResult(_UnaryNode(node.operator, result.node), true)
          : _FillResult(node, false);
    }
    if (node is _ConnectorNode) {
      final result = _fillOpenRightEdge(node.right, unit);
      return result.didFill
          ? _FillResult(
              _ConnectorNode(node.operator, node.left, result.node),
              true,
            )
          : _FillResult(node, false);
    }
    if (node is _ModifiedNode) {
      final result = _fillOpenRightEdge(node.base, unit);
      return result.didFill
          ? _FillResult(_ModifiedNode(result.node, node.modifiers), true)
          : _FillResult(node, false);
    }
    return _FillResult(node, false);
  }

  static _MeaningNode _modifyRightEdge(
    _MeaningNode node,
    _ModifierNode modifier,
  ) {
    if (node is _FusionNode) {
      if (node.right is _PunctuationNode) {
        return _FusionNode(node, modifier);
      }
      return _FusionNode(node.left, _modifyRightEdge(node.right, modifier));
    }
    if (node is _RelationNode) {
      return _RelationNode(
        node.operator,
        _modifyRightEdge(node.object, modifier),
      );
    }
    if (node is _UnaryNode) {
      return _UnaryNode(node.operator, _modifyRightEdge(node.operand, modifier));
    }
    if (node is _ConnectorNode) {
      return _ConnectorNode(
        node.operator,
        node.left,
        _modifyRightEdge(node.right, modifier),
      );
    }
    if (node is _ModifiedNode) {
      return _ModifiedNode(node.base, <_ModifierNode>[...node.modifiers, modifier]);
    }
    if (node is _PunctuationNode) {
      return _FusionNode(node, modifier);
    }
    return _ModifiedNode(node, <_ModifierNode>[modifier]);
  }

  static String _tokenKey(String token) => token.trim().toLowerCase();
}

sealed class _MeaningNode {
  const _MeaningNode();
  String render();
}

final class _SemanticAtom extends _MeaningNode {
  const _SemanticAtom({required this.surface, required this.meaning});
  final String surface;
  final String meaning;

  @override
  String render() {
    if (surface.toLowerCase() == meaning.toLowerCase()) {
      return surface;
    }
    return '$meaning⟨$surface⟩';
  }
}

final class _ModifierNode extends _MeaningNode {
  const _ModifierNode({required this.surface, required this.meaning});
  final String surface;
  final String meaning;

  @override
  String render() => '$meaning⟨$surface⟩';
}

final class _ModifiedNode extends _MeaningNode {
  const _ModifiedNode(this.base, this.modifiers);
  final _MeaningNode base;
  final List<_ModifierNode> modifiers;

  @override
  String render() {
    final tail = modifiers.map((modifier) => modifier.render()).join(' ⊕ ');
    return '${base.render()} ⊕ $tail';
  }
}

final class _FusionNode extends _MeaningNode {
  const _FusionNode(this.left, this.right);
  final _MeaningNode left;
  final _MeaningNode right;

  @override
  String render() => '${left.render()} ⊗ ${right.render()}';
}

final class _OpenRelationNode extends _MeaningNode {
  const _OpenRelationNode(this.operator);
  final String operator;

  @override
  String render() => operator;
}

final class _RelationNode extends _MeaningNode {
  const _RelationNode(this.operator, this.object);
  final String operator;
  final _MeaningNode object;

  @override
  String render() => '$operator(${object.render()})';
}

final class _OpenUnaryNode extends _MeaningNode {
  const _OpenUnaryNode(this.operator);
  final String operator;

  @override
  String render() => operator;
}

final class _UnaryNode extends _MeaningNode {
  const _UnaryNode(this.operator, this.operand);
  final String operator;
  final _MeaningNode operand;

  @override
  String render() => '$operator(${operand.render()})';
}

final class _OpenConnectorNode extends _MeaningNode {
  const _OpenConnectorNode(this.operator, [this.left]);
  final String operator;
  final _MeaningNode? left;

  @override
  String render() => left == null ? operator : '$operator(${left!.render()})';
}

final class _ConnectorNode extends _MeaningNode {
  const _ConnectorNode(this.operator, this.left, this.right);
  final String operator;
  final _MeaningNode? left;
  final _MeaningNode right;

  @override
  String render() {
    if (left == null) {
      return '$operator(${right.render()})';
    }
    return '$operator(${left!.render()}, ${right.render()})';
  }
}

final class _PunctuationNode extends _MeaningNode {
  const _PunctuationNode({required this.symbol, required this.meaning});
  final String symbol;
  final String meaning;

  @override
  String render() => '$meaning⟨$symbol⟩';
}

final class _FillResult {
  const _FillResult(this.node, this.didFill);
  final _MeaningNode node;
  final bool didFill;
}
