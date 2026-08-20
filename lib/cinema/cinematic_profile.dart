import '../semantic_reactor.dart';

/// Exact semantic algebra defined by the cinematic APK specification.
///
/// This profile is intentionally separate from [SemanticReactor.defaultAxioms]
/// because both profiles define a different result for `sistem + politic`.
abstract final class CinematicSemanticProfile {
  static const List<SemanticAxiom> axioms = <SemanticAxiom>[
    SemanticAxiom('CIN-001', 'sistem', 'politic', 'stat'),
    SemanticAxiom('CIN-002', 'sistem', 'social', 'societate'),
    SemanticAxiom('CIN-003', 'stat', 'esuat', 'prabusire'),
    SemanticAxiom('CIN-004', 'stat', 'corupt', 'degradare'),
  ];

  /// Creates an isolated reactor using only the cinematic axioms.
  static SemanticReactor createReactor() => SemanticReactor(axioms: axioms);
}
