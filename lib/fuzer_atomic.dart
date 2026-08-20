import 'cinema/cinematic_profile.dart';
import 'semantic_reactor.dart';

/// Romanian API requested by the cinematic specification.
///
/// Internally it delegates to the same no-loss binary reactor used by the UI,
/// so an absent axiom never makes an input form disappear.
final class AtomicSemanticReactor {
  AtomicSemanticReactor() : _reactor = CinematicSemanticProfile.createReactor();

  final SemanticReactor _reactor;

  SemanticSnapshot get snapshot => _reactor.snapshot;

  void absoarbeCuvant(String cuvant) {
    _reactor.integrateForm(cuvant);
  }

  void absoarbeCuvinte(Iterable<String> cuvinte) {
    _reactor.integrateForms(cuvinte);
  }

  String obtineFinal() => snapshot.rawSense.toUpperCase();

  void reset() {
    _reactor.reset();
  }
}
