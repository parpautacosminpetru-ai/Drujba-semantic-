import 'package:flutter_test/flutter_test.dart';
import 'package:drujba_semantic_core/semantic_reactor.dart';

void main() {
  group('SemanticReactor v2', () {
    test('starts with one exact empty-flow snapshot', () {
      final reactor = SemanticReactor();

      expect(reactor.snapshot.display, '[FLUX-VID]');
      expect(reactor.snapshot.rawSense, isEmpty);
      expect(reactor.snapshot.sourceForms, isEmpty);
      expect(reactor.snapshot.fusionSteps, isEmpty);
      expect(reactor.snapshot.locked, isEmpty);
      expect(reactor.snapshot.isEmpty, isTrue);
      expect(reactor.snapshot.isAxiomaticallyResolved, isFalse);
      expect(reactor.snapshot.unresolvedForms, isEmpty);
    });

    test('performs the complete three-form collapse from the PDF', () {
      final reactor = SemanticReactor();

      reactor.integrateForms(<String>['Sistem', 'Politic', 'Eșuat']);

      expect(reactor.snapshot.display, '[ANOMIE]');
      expect(reactor.snapshot.rawSense, 'Anomie');
      expect(
        reactor.snapshot.sourceForms,
        <String>['Sistem', 'Politic', 'Eșuat'],
      );
      expect(reactor.snapshot.fusionSteps, hasLength(2));
      expect(reactor.snapshot.isAxiomaticallyResolved, isTrue);
      expect(reactor.snapshot.unresolvedForms, isEmpty);
      expect(reactor.snapshot.fusionSteps[0].axiomId, 'AX-002');
      expect(reactor.snapshot.fusionSteps[0].left, 'Sistem');
      expect(reactor.snapshot.fusionSteps[0].right, 'Politic');
      expect(reactor.snapshot.fusionSteps[0].result, 'Guvernanță');
      expect(
        reactor.snapshot.fusionSteps[0].sourceForms,
        <String>['Sistem', 'Politic'],
      );
      expect(reactor.snapshot.fusionSteps[1].left, 'Guvernanță');
      expect(reactor.snapshot.fusionSteps[1].axiomId, 'AX-003');
      expect(reactor.snapshot.fusionSteps[1].right, 'Eșuat');
      expect(reactor.snapshot.fusionSteps[1].result, 'Anomie');
      expect(
        reactor.snapshot.fusionSteps[1].sourceForms,
        <String>['Sistem', 'Politic', 'Eșuat'],
      );
    });

    test('contains every exact directional rule from the PDF', () {
      final cases =
          <({String id, String left, String right, String result})>[
        (id: 'AX-001', left: 'sistem', right: 'eșuat', result: 'Colaps'),
        (id: 'AX-002', left: 'sistem', right: 'politic', result: 'Guvernanță'),
        (id: 'AX-003', left: 'guvernanță', right: 'eșuat', result: 'Anomie'),
        (id: 'AX-004', left: 'guvernanță', right: 'corupt', result: 'Cleptocrație'),
        (id: 'AX-005', left: 'tehnologie', right: 'rapid', result: 'Hiper-Evoluție'),
        (id: 'AX-006', left: 'tehnologie', right: 'control', result: 'Cibernetică'),
      ];

      for (final rule in cases) {
        final reactor = SemanticReactor()
          ..integrateForms(<String>[rule.left, rule.right]);

        expect(
          reactor.snapshot.rawSense,
          rule.result,
          reason: '${rule.left} + ${rule.right}',
        );
        expect(reactor.snapshot.fusionSteps, hasLength(1));
        expect(reactor.snapshot.fusionSteps.single.axiomId, rule.id);
        expect(reactor.snapshot.isAxiomaticallyResolved, isTrue);
        expect(reactor.snapshot.unresolvedForms, isEmpty);
      }
    });

    test('matrix is directional and never reverses an undeclared rule', () {
      final reactor = SemanticReactor()
        ..integrateForms(<String>['Politic', 'Sistem']);

      expect(reactor.snapshot.rawSense, 'Politic-Sistem');
      expect(reactor.snapshot.display, '[POLITIC-SISTEM]');
      expect(reactor.snapshot.fusionSteps, isEmpty);
      expect(reactor.snapshot.isAxiomaticallyResolved, isFalse);
      expect(
        reactor.snapshot.unresolvedForms,
        <String>['Politic', 'Sistem'],
      );
    });

    test('fallback keeps order, stop words, and repeated forms', () {
      final reactor = SemanticReactor()
        ..integrateForms(<String>['Casa', 'și', 'Casa', 'în', 'Casa']);

      expect(reactor.snapshot.rawSense, 'Casa-și-Casa-în-Casa');
      expect(
        reactor.snapshot.sourceForms,
        <String>['Casa', 'și', 'Casa', 'în', 'Casa'],
      );
      expect(reactor.snapshot.fusionSteps, isEmpty);
      expect(reactor.snapshot.isAxiomaticallyResolved, isFalse);
      expect(
        reactor.snapshot.unresolvedForms,
        <String>['Casa', 'și', 'Casa', 'în', 'Casa'],
      );
    });

    test('canonicalizes Unicode and explicit matrix OCR aliases for lookup', () {
      const decomposedGovernance = 'GUVERNANT\u0326A\u0306';
      final reactor = SemanticReactor()
        ..integrateForms(<String>[decomposedGovernance, 'ESUAT']);

      expect(reactor.snapshot.rawSense, 'Anomie');
      expect(
        reactor.snapshot.sourceForms,
        <String>[decomposedGovernance, 'ESUAT'],
      );

      final legacyCedilla = SemanticReactor()
        ..integrateForms(<String>['SISTEM', 'POLITIC', 'EŞUAT']);
      expect(legacyCedilla.snapshot.rawSense, 'Anomie');
      expect(
        legacyCedilla.snapshot.sourceForms,
        <String>['SISTEM', 'POLITIC', 'EŞUAT'],
      );
    });

    test('ignores only empty inputs and preserves non-empty surface exactly', () {
      final reactor = SemanticReactor()
        ..integrateForm('')
        ..integrateForm('   ')
        ..integrateForm('  Sistem  ')
        ..integrateForm('POLITIC');

      expect(reactor.snapshot.rawSense, 'Guvernanță');
      expect(
        reactor.snapshot.sourceForms,
        <String>['  Sistem  ', 'POLITIC'],
      );
    });

    test('accepts a custom matrix and folds through its named result', () {
      final reactor = SemanticReactor(
        fusionMatrix: const <String, Map<String, String>>{
          'apă': <String, String>{'rece': 'Răcoare'},
          'răcoare': <String, String>{'intensă': 'Frig'},
        },
      )..integrateForms(<String>['APĂ', 'Rece', 'INTENSĂ']);

      expect(reactor.snapshot.rawSense, 'Frig');
      expect(reactor.snapshot.display, '[FRIG]');
      expect(reactor.snapshot.fusionSteps, hasLength(2));
      expect(
        reactor.snapshot.fusionSteps.map((step) => step.axiomId),
        <String>['matrix:apă+rece', 'matrix:răcoare+intensă'],
      );
      expect(reactor.snapshot.isAxiomaticallyResolved, isTrue);
      expect(
        reactor.snapshot.sourceForms,
        <String>['APĂ', 'Rece', 'INTENSĂ'],
      );
    });

    test('accepts explicit custom axioms and exposes their proof IDs', () {
      const axioms = <SemanticAxiom>[
        SemanticAxiom('CUSTOM-COOL', 'apă', 'rece', 'Răcoare'),
        SemanticAxiom('CUSTOM-COLD', 'Răcoare', 'intensă', 'Frig'),
      ];
      final reactor = SemanticReactor(axioms: axioms)
        ..integrateForms(<String>['Apă', 'Rece', 'Intensă']);

      expect(reactor.snapshot.rawSense, 'Frig');
      expect(reactor.snapshot.isAxiomaticallyResolved, isTrue);
      expect(reactor.snapshot.unresolvedForms, isEmpty);
      expect(
        reactor.snapshot.fusionSteps.map((step) => step.axiomId),
        <String>['CUSTOM-COOL', 'CUSTOM-COLD'],
      );
      expect(
        reactor.snapshot.fusionSteps.last.sourceForms,
        <String>['Apă', 'Rece', 'Intensă'],
      );
    });

    test('axiom IDs and reduction order are deterministic', () {
      final first = SemanticReactor()
        ..integrateForms(<String>['Sistem', 'Politic', 'Eșuat']);
      final second = SemanticReactor()
        ..integrateForms(<String>['SISTEM', 'POLITIC', 'ESUAT']);

      expect(
        SemanticReactor.defaultAxioms.map((axiom) => axiom.id),
        <String>['AX-001', 'AX-002', 'AX-003', 'AX-004', 'AX-005', 'AX-006'],
      );
      expect(
        first.snapshot.fusionSteps.map((step) => step.axiomId),
        second.snapshot.fusionSteps.map((step) => step.axiomId),
      );
      expect(
        first.snapshot.fusionSteps.map((step) => step.axiomId),
        <String>['AX-002', 'AX-003'],
      );
    });

    test('forbids supplying axioms and a legacy matrix together', () {
      expect(
        () => SemanticReactor(
          axioms: const <SemanticAxiom>[
            SemanticAxiom('ONE', 'a', 'b', 'c'),
          ],
          fusionMatrix: const <String, Map<String, String>>{
            'a': <String, String>{'b': 'c'},
          },
        ),
        throwsArgumentError,
      );
    });

    test('rejects duplicate IDs and conflicting axiom pairs', () {
      expect(
        () => SemanticReactor(
          axioms: const <SemanticAxiom>[
            SemanticAxiom('SAME', 'a', 'b', 'x'),
            SemanticAxiom('SAME', 'c', 'd', 'y'),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => SemanticReactor(
          axioms: const <SemanticAxiom>[
            SemanticAxiom('FIRST', 'a', 'b', 'x'),
            SemanticAxiom('SECOND', 'A', 'B', 'y'),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('unknown forms remain explicit and axiomatically unresolved', () {
      final reactor = SemanticReactor()
        ..integrateForms(<String>['Sistem', 'Politic', 'Necunoscut']);

      expect(reactor.snapshot.rawSense, 'Guvernanță-Necunoscut');
      expect(reactor.snapshot.isAxiomaticallyResolved, isFalse);
      expect(reactor.snapshot.unresolvedForms, <String>['Necunoscut']);
      expect(
        reactor.snapshot.sourceForms,
        <String>['Sistem', 'Politic', 'Necunoscut'],
      );
      expect(reactor.snapshot.fusionSteps.single.axiomId, 'AX-002');
    });

    test('a third form can collapse an exact unresolved chain key', () {
      final reactor = SemanticReactor(
        fusionMatrix: const <String, Map<String, String>>{
          'alpha-beta': <String, String>{'gamma': 'Triadă'},
        },
      );

      reactor.integrateForms(<String>['Alpha', 'Beta']);
      expect(reactor.snapshot.rawSense, 'Alpha-Beta');
      expect(reactor.snapshot.fusionSteps, isEmpty);

      reactor.integrateForm('Gamma');
      expect(reactor.snapshot.rawSense, 'Triadă');
      expect(
        reactor.snapshot.sourceForms,
        <String>['Alpha', 'Beta', 'Gamma'],
      );
      expect(reactor.snapshot.fusionSteps, hasLength(1));
      expect(reactor.snapshot.fusionSteps.single.left, 'Alpha-Beta');
      expect(
        reactor.snapshot.fusionSteps.single.axiomId,
        'matrix:alpha-beta+gamma',
      );
    });

    test('right-edge collapse preserves prefix then permits cascade', () {
      final reactor = SemanticReactor(
        fusionMatrix: const <String, Map<String, String>>{
          'beta': <String, String>{'gamma': 'BetaGamma'},
          'alpha': <String, String>{'betagamma': 'Tot'},
        },
      )..integrateForms(<String>['Alpha', 'Beta', 'Gamma']);

      expect(reactor.snapshot.rawSense, 'Tot');
      expect(reactor.snapshot.fusionSteps, hasLength(2));
      expect(reactor.snapshot.fusionSteps[0].result, 'BetaGamma');
      expect(reactor.snapshot.fusionSteps[1].result, 'Tot');
      expect(reactor.snapshot.fusionSteps[0].axiomId, 'matrix:beta+gamma');
      expect(
        reactor.snapshot.fusionSteps[1].axiomId,
        'matrix:alpha+betagamma',
      );
      expect(
        reactor.snapshot.sourceForms,
        <String>['Alpha', 'Beta', 'Gamma'],
      );
    });

    test('keeps unrelated diacritic forms semantically distinct', () {
      final girl = SemanticReactor(
        fusionMatrix: const <String, Map<String, String>>{
          'fată': <String, String>{'mare': 'Adolescentă'},
          'față': <String, String>{'mare': 'Chip'},
        },
      )..integrateForms(<String>['Fată', 'mare']);
      final face = SemanticReactor(
        fusionMatrix: const <String, Map<String, String>>{
          'fată': <String, String>{'mare': 'Adolescentă'},
          'față': <String, String>{'mare': 'Chip'},
        },
      )..integrateForms(<String>['Față', 'mare']);

      expect(girl.snapshot.rawSense, 'Adolescentă');
      expect(face.snapshot.rawSense, 'Chip');
    });

    test('deduplicates equivalent legacy matrix aliases compatibly', () {
      final reactor = SemanticReactor(
        fusionMatrix: const <String, Map<String, String>>{
          'eșuat': <String, String>{'grav': 'Colaps'},
          'esuat': <String, String>{'grav': 'Colaps'},
        },
      )..integrateForms(<String>['ESUAT', 'grav']);

      expect(reactor.snapshot.rawSense, 'Colaps');
      expect(
        reactor.snapshot.fusionSteps.single.axiomId,
        'matrix:eșuat+grav',
      );
    });

    test('rejects nondeterministic collisions between explicit OCR aliases', () {
      expect(
        () => SemanticReactor(
          fusionMatrix: const <String, Map<String, String>>{
            'eșuat': <String, String>{'grav': 'Colaps'},
            'esuat': <String, String>{'grav': 'Avarie'},
          },
        ),
        throwsArgumentError,
      );
    });

    test('lock freezes provenance and starts an independent active root', () {
      final reactor = SemanticReactor()
        ..integrateForms(<String>['Sistem', 'Politic'])
        ..lockCurrent()
        ..integrateForm('Eșuat');

      expect(reactor.snapshot.rawSense, 'Eșuat');
      expect(reactor.snapshot.sourceForms, <String>['Eșuat']);
      expect(reactor.snapshot.fusionSteps, isEmpty);
      expect(reactor.snapshot.locked, hasLength(1));

      final locked = reactor.snapshot.locked.single;
      expect(locked.display, '[GUVERNANȚĂ]');
      expect(locked.rawSense, 'Guvernanță');
      expect(locked.sourceForms, <String>['Sistem', 'Politic']);
      expect(locked.fusionSteps, hasLength(1));
    });

    test('locking requires a composition and a lock can be removed', () {
      final reactor = SemanticReactor()..lockCurrent();
      expect(reactor.snapshot.locked, isEmpty);

      reactor
        ..integrateForm('Concept')
        ..lockCurrent();
      expect(reactor.snapshot.locked, isEmpty);
      expect(reactor.snapshot.rawSense, 'Concept');

      reactor
        ..integrateForm('compus')
        ..lockCurrent();
      expect(reactor.snapshot.locked, hasLength(1));

      reactor.removeLockedAt(0);
      expect(reactor.snapshot.locked, isEmpty);
      expect(() => reactor.removeLockedAt(0), throwsRangeError);
    });

    test('replaceActiveForms replays only active OCR forms', () {
      final reactor = SemanticReactor()
        ..integrateForms(<String>['Sistem', 'Politic'])
        ..lockCurrent()
        ..integrateForms(<String>['Tehnologie', 'Control']);

      expect(reactor.snapshot.rawSense, 'Cibernetică');
      expect(reactor.snapshot.locked, hasLength(1));

      reactor.replaceActiveForms(<String>['Sistem', 'Eșuat']);

      expect(reactor.snapshot.rawSense, 'Colaps');
      expect(
        reactor.snapshot.sourceForms,
        <String>['Sistem', 'Eșuat'],
      );
      expect(reactor.snapshot.fusionSteps, hasLength(1));
      expect(reactor.snapshot.locked, hasLength(1));
      expect(reactor.snapshot.locked.single.rawSense, 'Guvernanță');
      expect(reactor.snapshot.isAxiomaticallyResolved, isTrue);
      expect(reactor.snapshot.unresolvedForms, isEmpty);
    });

    test('reset clears the active AST, trace, and locks', () {
      final reactor = SemanticReactor()
        ..integrateForms(<String>['Sistem', 'Politic'])
        ..lockCurrent()
        ..integrateForm('Tehnologie')
        ..reset();

      expect(reactor.snapshot.display, '[FLUX-VID]');
      expect(reactor.snapshot.rawSense, isEmpty);
      expect(reactor.snapshot.sourceForms, isEmpty);
      expect(reactor.snapshot.fusionSteps, isEmpty);
      expect(reactor.snapshot.locked, isEmpty);
      expect(reactor.snapshot.isAxiomaticallyResolved, isFalse);
      expect(reactor.snapshot.unresolvedForms, isEmpty);
    });

    test('all snapshot collections are externally immutable', () {
      final reactor = SemanticReactor()
        ..integrateForms(<String>['Sistem', 'Politic'])
        ..lockCurrent();

      expect(
        () => reactor.snapshot.locked.add(
          LockedSemanticResult(
            display: '[X]',
            rawSense: 'X',
            sourceForms: const <String>['X'],
            fusionSteps: const <SemanticFusionStep>[],
          ),
        ),
        throwsUnsupportedError,
      );
      expect(
        () => reactor.snapshot.locked.single.sourceForms.add('X'),
        throwsUnsupportedError,
      );
      expect(
        () => reactor.snapshot.locked.single.fusionSteps.clear(),
        throwsUnsupportedError,
      );
      expect(
        () => reactor.snapshot.unresolvedForms.add('X'),
        throwsUnsupportedError,
      );
    });
  });
}
