import 'package:drujba_semantic_core/cinema/cinematic_profile.dart';
import 'package:drujba_semantic_core/cinema/cinematic_scene.dart';
import 'package:drujba_semantic_core/fuzer_atomic.dart';
import 'package:drujba_semantic_core/semantic_reactor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CinematicSemanticProfile', () {
    test('exposes the requested atomic Romanian API without losing forms', () {
      final reactor = AtomicSemanticReactor()
        ..absoarbeCuvinte(<String>['Sistem', 'Politic', 'Esuat']);

      expect(reactor.obtineFinal(), 'PRABUSIRE');
      expect(
        reactor.snapshot.sourceForms,
        <String>['Sistem', 'Politic', 'Esuat'],
      );
    });

    test('defines the four directional axioms from the PDF', () {
      expect(
        CinematicSemanticProfile.axioms
            .map((axiom) => (axiom.id, axiom.left, axiom.right, axiom.result)),
        <(String, String, String, String)>[
          ('CIN-001', 'sistem', 'politic', 'stat'),
          ('CIN-002', 'sistem', 'social', 'societate'),
          ('CIN-003', 'stat', 'esuat', 'prabusire'),
          ('CIN-004', 'stat', 'corupt', 'degradare'),
        ],
      );
    });

    test('folds three forms while retaining the complete proof', () {
      final reactor = CinematicSemanticProfile.createReactor()
        ..integrateForms(<String>['Sistem', 'Politic', 'Esuat']);

      expect(reactor.snapshot.rawSense, 'prabusire');
      expect(reactor.snapshot.isAxiomaticallyResolved, isTrue);
      expect(
        reactor.snapshot.sourceForms,
        <String>['Sistem', 'Politic', 'Esuat'],
      );
      expect(
        reactor.snapshot.fusionSteps.map((step) => step.axiomId),
        <String>['CIN-001', 'CIN-003'],
      );
      expect(
        reactor.snapshot.fusionSteps.last.sourceForms,
        <String>['Sistem', 'Politic', 'Esuat'],
      );
    });

    test('does not reverse an undeclared cinematic axiom', () {
      final reactor = CinematicSemanticProfile.createReactor()
        ..integrateForms(<String>['Politic', 'Sistem']);

      expect(reactor.snapshot.rawSense, 'Politic-Sistem');
      expect(reactor.snapshot.isAxiomaticallyResolved, isFalse);
    });
  });

  group('CinematicSceneCatalog', () {
    test('contains one exact local WebP path for every cinematic axiom', () {
      final catalog = CinematicSceneCatalog.defaults();

      expect(catalog.scenes, hasLength(4));
      expect(catalog['CIN-001']?.assetPath, 'assets/cinema/scenes/stat.webp');
      expect(
        catalog['CIN-002']?.assetPath,
        'assets/cinema/scenes/societate.webp',
      );
      expect(
        catalog['CIN-003']?.assetPath,
        'assets/cinema/scenes/prabusire.webp',
      );
      expect(
        catalog['CIN-004']?.assetPath,
        'assets/cinema/scenes/degradare.webp',
      );
      expect(() => catalog.scenes.clear(), throwsUnsupportedError);
    });

    test('rejects duplicate IDs and invalid animation durations', () {
      expect(
        () => CinematicSceneCatalog(
          const <CinematicSceneSpec>[
            CinematicSceneSpec(
              sceneId: 'same',
              axiomId: 'A',
              semanticResult: 'x',
              assetPath: 'x.webp',
            ),
            CinematicSceneSpec(
              sceneId: 'same',
              axiomId: 'B',
              semanticResult: 'y',
              assetPath: 'y.webp',
            ),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => CinematicSceneCatalog(
          const <CinematicSceneSpec>[
            CinematicSceneSpec(
              sceneId: 'scene',
              axiomId: 'A',
              semanticResult: 'x',
              assetPath: 'x.webp',
              pulse: Duration.zero,
            ),
          ],
        ),
        throwsArgumentError,
      );
    });
  });

  group('SemanticSceneProjector', () {
    test('maps only the exact terminal axiom and preserves all evidence', () {
      final reactor = CinematicSemanticProfile.createReactor()
        ..integrateForms(<String>['Sistem', 'Politic', 'Esuat']);
      final before = reactor.snapshot;

      final projection = SemanticSceneProjector().project(before);

      expect(projection.status, CinematicSceneStatus.mapped);
      expect(projection.conceptLabel, 'prabusire');
      expect(projection.scene?.axiomId, 'CIN-003');
      expect(
        projection.scene?.assetPath,
        'assets/cinema/scenes/prabusire.webp',
      );
      expect(
        projection.sourceForms,
        <String>['Sistem', 'Politic', 'Esuat'],
      );
      expect(
        projection.proof.map((step) => step.axiomId),
        <String>['CIN-001', 'CIN-003'],
      );
      expect(projection.unresolvedForms, isEmpty);
      expect(projection.isPlayable, isTrue);
      expect(reactor.snapshot.sourceForms, before.sourceForms);
      expect(() => projection.sourceForms.clear(), throwsUnsupportedError);
    });

    test('keeps empty, atomic, and unresolved states image-free', () {
      final projector = SemanticSceneProjector();
      final reactor = CinematicSemanticProfile.createReactor();

      final empty = projector.project(reactor.snapshot);
      expect(empty.status, CinematicSceneStatus.empty);
      expect(empty.scene, isNull);

      reactor.integrateForm('Sistem');
      final atomic = projector.project(reactor.snapshot);
      expect(atomic.status, CinematicSceneStatus.atomic);
      expect(atomic.scene, isNull);
      expect(atomic.unresolvedForms, <String>['Sistem']);

      reactor.integrateForm('Necunoscut');
      final unresolved = projector.project(reactor.snapshot);
      expect(unresolved.status, CinematicSceneStatus.unresolved);
      expect(unresolved.scene, isNull);
      expect(
        unresolved.sourceForms,
        <String>['Sistem', 'Necunoscut'],
      );
    });

    test('does not invent a fallback for a resolved but unmapped result', () {
      final reactor = SemanticReactor(
        axioms: const <SemanticAxiom>[
          SemanticAxiom('OTHER-001', 'a', 'b', 'c'),
        ],
      )..integrateForms(<String>['a', 'b']);
      final projector = SemanticSceneProjector();

      final projection = projector.project(reactor.snapshot);

      expect(projection.status, CinematicSceneStatus.unmapped);
      expect(projection.conceptLabel, 'c');
      expect(projection.scene, isNull);
      expect(projection.sourceForms, <String>['a', 'b']);
    });

    test('rejects a catalog scene whose declared result does not match', () {
      final catalog = CinematicSceneCatalog(
        const <CinematicSceneSpec>[
          CinematicSceneSpec(
            sceneId: 'wrong',
            axiomId: 'CIN-001',
            semanticResult: 'alt-rezultat',
            assetPath: 'assets/cinema/scenes/wrong.webp',
          ),
        ],
      );
      final reactor = CinematicSemanticProfile.createReactor()
        ..integrateForms(<String>['Sistem', 'Politic']);

      final projection =
          SemanticSceneProjector(catalog: catalog).project(reactor.snapshot);

      expect(projection.status, CinematicSceneStatus.unmapped);
      expect(projection.scene, isNull);
    });

    test('projects a resolved lock without crossing its boundary', () {
      final reactor = CinematicSemanticProfile.createReactor()
        ..integrateForms(<String>['Sistem', 'Politic'])
        ..lockCurrent()
        ..integrateForms(<String>['Stat', 'Corupt']);
      final locked = reactor.snapshot.locked.single;

      final projection = SemanticSceneProjector().projectLocked(locked);

      expect(projection.status, CinematicSceneStatus.locked);
      expect(projection.isLocked, isTrue);
      expect(projection.scene?.axiomId, 'CIN-001');
      expect(projection.sourceForms, <String>['Sistem', 'Politic']);
      expect(
        reactor.snapshot.sourceForms,
        <String>['Stat', 'Corupt'],
      );
      expect(reactor.snapshot.rawSense, 'degradare');
    });

    test('does not map an unresolved locked composition', () {
      final reactor = CinematicSemanticProfile.createReactor()
        ..integrateForms(<String>['Sistem', 'Necunoscut'])
        ..lockCurrent();
      final locked = reactor.snapshot.locked.single;

      final projection = SemanticSceneProjector().projectLocked(locked);

      expect(projection.status, CinematicSceneStatus.locked);
      expect(projection.scene, isNull);
      expect(
        projection.unresolvedForms,
        <String>['Sistem', 'Necunoscut'],
      );
    });
  });
}
