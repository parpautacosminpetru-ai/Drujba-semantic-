import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../core/ocr_frame_accumulator.dart';
import '../ocr/local_ocr_scanner.dart';
import '../semantic_reactor.dart';

final class SemanticHomePage extends StatefulWidget {
  const SemanticHomePage({super.key});

  @override
  State<SemanticHomePage> createState() => _SemanticHomePageState();
}

final class _SemanticHomePageState extends State<SemanticHomePage>
    with WidgetsBindingObserver {
  final SemanticReactor _reactor = SemanticReactor();
  final OcrFrameAccumulator _frameAccumulator =
      OcrFrameAccumulator(requiredMatchingFrames: 2);
  final TextEditingController _manualTextController = TextEditingController();

  late final LocalOcrScanner _scanner;
  int _ocrBaseFormCount = 0;
  bool _lockingCurrentSense = false;
  String _semanticStatus = 'Așteptare flux semantic liniar';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scanner = LocalOcrScanner(onRecognizedFrame: _onRecognizedFrame)
      ..addListener(_onScannerChanged);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _scanner.isScanning) {
      unawaited(_scanner.stop());
      _beginOcrStream();
    }
  }

  void _onScannerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _beginOcrStream() {
    _frameAccumulator.startNewStream();
    _ocrBaseFormCount = _reactor.snapshot.sourceForms.length;
  }

  void _onRecognizedFrame(String text) {
    if (_lockingCurrentSense) {
      return;
    }
    final update = _frameAccumulator.ingestFrame(text);
    if (!mounted) {
      return;
    }

    if (update.requiresReplay) {
      final currentForms = _reactor.snapshot.sourceForms;
      final safeBaseCount =
          _ocrBaseFormCount.clamp(0, currentForms.length).toInt();
      final prefix = currentForms.take(safeBaseCount);
      _reactor.replaceActiveForms(<String>[
        ...prefix,
        ...update.stableWords,
      ]);
      setState(() {
        _semanticStatus = _describeSynthesis(
          'Flux OCR corectat și reintegrat în ordinea detectată',
        );
      });
      return;
    }

    if (update.appendedWords.isNotEmpty) {
      _reactor.integrateForms(update.appendedWords);
      setState(() {
        _semanticStatus = _describeSynthesis(
          '${update.appendedWords.length} forme integrate semantic',
        );
      });
      return;
    }

    setState(() {
      _semanticStatus = update.isStable
          ? 'Cadru stabil - sensul curent este neschimbat'
          : 'Stabilizez formele detectate...';
    });
  }

  Future<void> _toggleScanning() async {
    if (_scanner.isScanning) {
      await _scanner.stop();
      _beginOcrStream();
      if (mounted) {
        setState(() => _semanticStatus = 'Flux OCR oprit');
      }
      return;
    }

    _beginOcrStream();
    await _scanner.start();
  }

  void _processManualText() {
    final text = _manualTextController.text.trim();
    if (text.isEmpty) {
      return;
    }
    if (_scanner.isStarting || _scanner.isScanning) {
      setState(() {
        _semanticStatus =
            'Așteaptă sau oprește scanarea înainte de introducerea manuală';
      });
      return;
    }

    final forms = text.split(RegExp(r'\s+'));
    _reactor.integrateForms(forms);
    _manualTextController.clear();
    FocusScope.of(context).unfocus();
    setState(() {
      _semanticStatus = _describeSynthesis(
        '${forms.length} forme integrate semantic offline',
      );
    });
  }

  String _describeSynthesis(String prefix) {
    final snapshot = _reactor.snapshot;
    if (snapshot.isAxiomaticallyResolved) {
      final proof = snapshot.fusionSteps
          .map((step) => step.axiomId)
          .join(' → ');
      return '$prefix; dovadă $proof';
    }
    return '$prefix; compoziție încă nerezolvată axiomatic';
  }

  void _resetSession() {
    _reactor.reset();
    _frameAccumulator.reset();
    _scanner.clearError();
    _manualTextController.clear();
    _ocrBaseFormCount = 0;
    setState(() {
      _semanticStatus = 'Așteptare flux semantic liniar';
    });
  }

  Future<void> _lockCurrentSense() async {
    final current = _reactor.snapshot;
    if (current.sourceForms.length < 2 || _lockingCurrentSense) {
      return;
    }
    if (_scanner.isStarting) {
      setState(() {
        _semanticStatus =
            'Așteaptă pornirea camerei înainte de aplicarea Zăvorului';
      });
      return;
    }
    final lockedDisplay = current.display;
    final scanWasActive = _scanner.isScanning;
    _lockingCurrentSense = true;
    try {
      if (scanWasActive) {
        await _scanner.stop();
      }
      if (!mounted) {
        return;
      }
      _reactor.lockCurrent();
      _beginOcrStream();
      setState(() {
        _semanticStatus = scanWasActive
            ? '$lockedDisplay: Zăvor aplicat; scanarea a fost oprită'
            : '$lockedDisplay: Zăvor aplicat; segment nou deschis';
      });
    } finally {
      _lockingCurrentSense = false;
    }
  }

  void _removeLock(int index) {
    final locked = _reactor.snapshot.locked[index];
    _reactor.removeLockedAt(index);
    setState(() {
      _semanticStatus = '${locked.display}: Zăvor eliminat';
    });
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _reactor.snapshot;

    return Scaffold(
      appBar: AppBar(
        title: const Text('DRU - Drujba Semantică v2.0'),
        actions: <Widget>[
          IconButton(
            key: const Key('reset-session'),
            tooltip: 'Resetează fluxul',
            onPressed: _resetSession,
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            Expanded(
              flex: 4,
              child: _MonolithPanel(
                monolith: snapshot.display,
                canLock: snapshot.sourceForms.length > 1,
                onLock: _lockCurrentSense,
              ),
            ),
            const Divider(height: 1),
            Expanded(
              flex: 3,
              child: _ControlPanel(
                scanner: _scanner,
                semanticStatus: _semanticStatus,
                manualTextController: _manualTextController,
                lockedSenses: snapshot.locked,
                fusionSteps: snapshot.fusionSteps,
                unresolvedForms: snapshot.unresolvedForms,
                onToggleScanning: _toggleScanning,
                onProcessManualText: _processManualText,
                onRemoveLock: _removeLock,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanner
      ..removeListener(_onScannerChanged)
      ..dispose();
    _manualTextController.dispose();
    super.dispose();
  }
}

final class _MonolithPanel extends StatelessWidget {
  const _MonolithPanel({
    required this.monolith,
    required this.canLock,
    required this.onLock,
  });

  final String monolith;
  final bool canLock;
  final Future<void> Function() onLock;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
            child: Center(
              child: Semantics(
                label: 'Sens brut compozițional curent',
                hint: canLock
                    ? 'Atinge pentru a aplica Zăvorul și a deschide un segment nou'
                    : null,
                button: canLock,
                liveRegion: true,
                child: GestureDetector(
                  key: const Key('lock-current-sense'),
                  onTap: canLock ? () => unawaited(onLock()) : null,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 20,
                    ),
                    child: Text(
                      monolith,
                      key: const Key('semantic-monolith'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF69F0AE),
                        fontFamily: 'monospace',
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _ControlPanel extends StatelessWidget {
  const _ControlPanel({
    required this.scanner,
    required this.semanticStatus,
    required this.manualTextController,
    required this.lockedSenses,
    required this.fusionSteps,
    required this.unresolvedForms,
    required this.onToggleScanning,
    required this.onProcessManualText,
    required this.onRemoveLock,
  });

  final LocalOcrScanner scanner;
  final String semanticStatus;
  final TextEditingController manualTextController;
  final List<LockedSemanticResult> lockedSenses;
  final List<SemanticFusionStep> fusionSteps;
  final List<String> unresolvedForms;
  final Future<void> Function() onToggleScanning;
  final VoidCallback onProcessManualText;
  final ValueChanged<int> onRemoveLock;

  @override
  Widget build(BuildContext context) {
    final controller = scanner.cameraController;
    final showPreview = controller != null && controller.value.isInitialized;

    return ColoredBox(
      color: const Color(0xFF0D1210),
      child: ListView(
        scrollCacheExtent: const ScrollCacheExtent.pixels(1600),
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          if (showPreview) ...<Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 150,
                child: ColoredBox(
                  color: Colors.black,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: controller.value.aspectRatio,
                      child: CameraPreview(controller),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          FilledButton.icon(
            key: const Key('toggle-scanning'),
            onPressed: scanner.isStarting ? null : onToggleScanning,
            icon: scanner.isStarting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(scanner.isScanning ? Icons.stop : Icons.camera_alt),
            label: Text(
              scanner.isScanning
                  ? 'Oprește scanarea OCR locală'
                  : 'Scanează Pagina Liniar (OCR Continuous)',
            ),
          ),
          const SizedBox(height: 10),
          _StatusLine(
            active: scanner.isScanning,
            primary: scanner.status,
            secondary: semanticStatus,
          ),
          if (fusionSteps.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF13231B),
                border: Border.all(color: const Color(0xFF315E46)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.account_tree, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Dovadă axiomatică: '
                        '${fusionSteps.map((step) => step.axiomId).join(' → ')}',
                        key: const Key('axiomatic-proof'),
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (unresolvedForms.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              'Nerezolvat axiomatic: ${unresolvedForms.join(', ')}',
              key: const Key('axiomatic-unresolved'),
              style: const TextStyle(color: Colors.amber),
            ),
          ],
          if (scanner.lastRecognizedText.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF151D19),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  'OCR brut: ${scanner.lastRecognizedText}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ],
          if (scanner.error != null) ...<Widget>[
            const SizedBox(height: 10),
            Material(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
              child: ListTile(
                leading: const Icon(Icons.error_outline),
                title: Text(scanner.error!),
                trailing: IconButton(
                  tooltip: 'Închide eroarea',
                  onPressed: scanner.clearError,
                  icon: const Icon(Icons.close),
                ),
              ),
            ),
          ],
          if (lockedSenses.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            const Text(
              'Sinteze cu Zăvor',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (var index = 0; index < lockedSenses.length; index++)
                  ActionChip(
                    key: Key('locked-sense-$index'),
                    tooltip: 'Elimină Zăvorul pentru '
                        '${lockedSenses[index].display}',
                    avatar: const Icon(Icons.lock, size: 16),
                    label: Text(lockedSenses[index].display),
                    onPressed: () => onRemoveLock(index),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Material(
            color: Colors.transparent,
            child: ExpansionTile(
              key: const Key('manual-input-section'),
              tilePadding: EdgeInsets.zero,
              title: const Text('Introducere manuală offline'),
              subtitle: const Text('Folosește același reactor, fără cameră'),
              children: <Widget>[
                TextField(
                  key: const Key('manual-input'),
                  controller: manualTextController,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => onProcessManualText(),
                  decoration: const InputDecoration(
                    hintText: 'Scrie sau lipește formele aici',
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const Key('process-manual-input'),
                    onPressed: onProcessManualText,
                    icon: const Icon(Icons.account_tree_outlined),
                    label: const Text('Integrează sensul brut'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Atinge un monolit compus pentru Zăvor [LOCK]. Scanarea se '
            'oprește, sensul rămâne separat, iar următoarea pornire deschide '
            'o sinteză nouă.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

final class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.active,
    required this.primary,
    required this.secondary,
  });

  final bool active;
  final String primary;
  final String secondary;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Icon(
            Icons.circle,
            size: 10,
            color: active ? const Color(0xFF69F0AE) : Colors.grey,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(primary),
              Text(
                secondary,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
