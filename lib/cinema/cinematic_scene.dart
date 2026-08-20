import '../semantic_reactor.dart';

/// Projection state produced without changing the semantic reactor.
enum CinematicSceneStatus {
  empty,
  atomic,
  unresolved,
  mapped,
  unmapped,
  locked,
}

/// One compile-time local scene associated with one exact semantic axiom.
final class CinematicSceneSpec {
  const CinematicSceneSpec({
    required this.sceneId,
    required this.axiomId,
    required this.semanticResult,
    required this.assetPath,
    this.pulse = const Duration(milliseconds: 1400),
    this.transition = const Duration(milliseconds: 320),
  });

  final String sceneId;
  final String axiomId;
  final String semanticResult;
  final String assetPath;
  final Duration pulse;
  final Duration transition;
}

/// Deterministic lookup from terminal axiom IDs to bundled WebP scenes.
final class CinematicSceneCatalog {
  factory CinematicSceneCatalog(Iterable<CinematicSceneSpec> scenes) {
    final prepared = _prepareScenes(scenes);
    return CinematicSceneCatalog._(
      prepared,
      _prepareAxiomIndex(prepared),
    );
  }

  const CinematicSceneCatalog._(this._scenes, this._byAxiomId);

  static const List<CinematicSceneSpec> defaultScenes =
      <CinematicSceneSpec>[
    CinematicSceneSpec(
      sceneId: 'scene-stat',
      axiomId: 'CIN-001',
      semanticResult: 'stat',
      assetPath: 'assets/cinema/scenes/stat.webp',
    ),
    CinematicSceneSpec(
      sceneId: 'scene-societate',
      axiomId: 'CIN-002',
      semanticResult: 'societate',
      assetPath: 'assets/cinema/scenes/societate.webp',
    ),
    CinematicSceneSpec(
      sceneId: 'scene-prabusire',
      axiomId: 'CIN-003',
      semanticResult: 'prabusire',
      assetPath: 'assets/cinema/scenes/prabusire.webp',
    ),
    CinematicSceneSpec(
      sceneId: 'scene-degradare',
      axiomId: 'CIN-004',
      semanticResult: 'degradare',
      assetPath: 'assets/cinema/scenes/degradare.webp',
    ),
  ];

  factory CinematicSceneCatalog.defaults() {
    return CinematicSceneCatalog(defaultScenes);
  }

  final List<CinematicSceneSpec> _scenes;
  final Map<String, CinematicSceneSpec> _byAxiomId;

  List<CinematicSceneSpec> get scenes => _scenes;

  CinematicSceneSpec? operator [](String axiomId) => _byAxiomId[axiomId];

  static List<CinematicSceneSpec> _prepareScenes(
    Iterable<CinematicSceneSpec> source,
  ) {
    final prepared = <CinematicSceneSpec>[];
    final sceneIds = <String>{};
    final axiomIds = <String>{};

    for (final scene in source) {
      if (scene.sceneId.trim().isEmpty ||
          scene.axiomId.trim().isEmpty ||
          scene.semanticResult.trim().isEmpty ||
          scene.assetPath.trim().isEmpty) {
        throw ArgumentError.value(
          scene,
          'scenes',
          'Scene IDs, axiom IDs, results, and paths must not be empty',
        );
      }
      if (!sceneIds.add(scene.sceneId)) {
        throw ArgumentError.value(
          scene.sceneId,
          'scenes',
          'Scene IDs must be unique',
        );
      }
      if (!axiomIds.add(scene.axiomId)) {
        throw ArgumentError.value(
          scene.axiomId,
          'scenes',
          'Axiom IDs must map to at most one scene',
        );
      }
      if (scene.pulse <= Duration.zero || scene.transition < Duration.zero) {
        throw ArgumentError.value(
          scene,
          'scenes',
          'Animation durations must be non-negative and pulse must be positive',
        );
      }
      prepared.add(scene);
    }

    return List<CinematicSceneSpec>.unmodifiable(prepared);
  }

  static Map<String, CinematicSceneSpec> _prepareAxiomIndex(
    Iterable<CinematicSceneSpec> source,
  ) {
    final index = <String, CinematicSceneSpec>{};
    for (final scene in source) {
      index[scene.axiomId] = scene;
    }
    return Map<String, CinematicSceneSpec>.unmodifiable(index);
  }
}

/// Immutable cinematic view of one active or locked semantic object.
final class CinematicSceneProjection {
  CinematicSceneProjection({
    required this.status,
    required this.conceptLabel,
    required this.scene,
    required List<String> sourceForms,
    required List<SemanticFusionStep> proof,
    required List<String> unresolvedForms,
  })  : sourceForms = List<String>.unmodifiable(sourceForms),
        proof = List<SemanticFusionStep>.unmodifiable(proof),
        unresolvedForms = List<String>.unmodifiable(unresolvedForms);

  final CinematicSceneStatus status;
  final String conceptLabel;
  final CinematicSceneSpec? scene;
  final List<String> sourceForms;
  final List<SemanticFusionStep> proof;
  final List<String> unresolvedForms;

  bool get isPlayable => scene != null;
  bool get isLocked => status == CinematicSceneStatus.locked;
}

/// Pure semantic-to-scene adapter using exact terminal axiom IDs only.
final class SemanticSceneProjector {
  SemanticSceneProjector({CinematicSceneCatalog? catalog})
      : catalog = catalog ?? CinematicSceneCatalog.defaults();

  final CinematicSceneCatalog catalog;

  CinematicSceneProjection project(SemanticSnapshot snapshot) {
    if (snapshot.isEmpty) {
      return _projection(
        status: CinematicSceneStatus.empty,
        conceptLabel: '',
        sourceForms: snapshot.sourceForms,
        proof: snapshot.fusionSteps,
        unresolvedForms: snapshot.unresolvedForms,
      );
    }

    if (!snapshot.isAxiomaticallyResolved) {
      return _projection(
        status: snapshot.sourceForms.length == 1
            ? CinematicSceneStatus.atomic
            : CinematicSceneStatus.unresolved,
        conceptLabel: snapshot.rawSense,
        sourceForms: snapshot.sourceForms,
        proof: snapshot.fusionSteps,
        unresolvedForms: snapshot.unresolvedForms,
      );
    }

    final scene = _exactScene(
      rawSense: snapshot.rawSense,
      proof: snapshot.fusionSteps,
    );
    return _projection(
      status: scene == null
          ? CinematicSceneStatus.unmapped
          : CinematicSceneStatus.mapped,
      conceptLabel: snapshot.rawSense,
      scene: scene,
      sourceForms: snapshot.sourceForms,
      proof: snapshot.fusionSteps,
      unresolvedForms: snapshot.unresolvedForms,
    );
  }

  CinematicSceneProjection projectLocked(LockedSemanticResult locked) {
    final proofEndsAtRoot = locked.fusionSteps.isNotEmpty &&
        locked.fusionSteps.last.result == locked.rawSense;
    final scene = proofEndsAtRoot
        ? _exactScene(rawSense: locked.rawSense, proof: locked.fusionSteps)
        : null;

    return _projection(
      status: CinematicSceneStatus.locked,
      conceptLabel: locked.rawSense,
      scene: scene,
      sourceForms: locked.sourceForms,
      proof: locked.fusionSteps,
      unresolvedForms:
          proofEndsAtRoot ? const <String>[] : locked.sourceForms,
    );
  }

  CinematicSceneSpec? _exactScene({
    required String rawSense,
    required List<SemanticFusionStep> proof,
  }) {
    if (proof.isEmpty) {
      return null;
    }
    final scene = catalog[proof.last.axiomId];
    if (scene == null || scene.semanticResult != rawSense) {
      return null;
    }
    return scene;
  }

  static CinematicSceneProjection _projection({
    required CinematicSceneStatus status,
    required String conceptLabel,
    CinematicSceneSpec? scene,
    required List<String> sourceForms,
    required List<SemanticFusionStep> proof,
    required List<String> unresolvedForms,
  }) {
    return CinematicSceneProjection(
      status: status,
      conceptLabel: conceptLabel,
      scene: scene,
      sourceForms: sourceForms,
      proof: proof,
      unresolvedForms: unresolvedForms,
    );
  }
}
