import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../core/ocr_frame_accumulator.dart';
import '../core/pure_semantic_fuzer.dart';
import '../core/romanian_rule_tagger.dart';
import '../ocr/local_ocr_scanner.dart';

final class SemanticHomePage extends StatefulWidget {
  const SemanticHomePage({super.key});

  @override
  State<SemanticHomePage> createState() => _SemanticHomePageState();
}

final class _SemanticHomePageState extends State<SemanticHomePage>
    with WidgetsBindingObserver {
  final PureSemanticFuzer _fuzer = PureSemanticFuzer();
  final RomanianRuleTagger _tagger = const RomanianRuleTagger();
  final OcrFrameAccumulator _frameAccumulator = OcrFrameAccumulator();
  final TextEditingController _manualTextController = TextEditingController();

  late final LocalOcrScanner _scanner;
  bool _sessionStarted = false;
  String _semanticStatus = 'Așteptare sinteză liniară';
  int _ocrBaseIndex = 0;

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
      _frameAccumulator.startNewStream();
    }
  }

  void _onScannerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onRecognizedFrame(String text) {
    final update = _frameAccumulator.ingestFrame(text);
    if (!mounted) {
      return;
    }

    if (update.isStable && update.hasChanges) {
      _fuzer.reconcileTail(
        baseIndex: _ocrBaseIndex,
        tokens: update.stableTokens,
        tagger: _tagger,
      );
      setState(() {
        _sessionStarted = true;
        _semanticStatus =
            'Sinteză reconciliată de la C${_ocrBaseIndex + update.changedFromIndex + 1}';
      });
      return;
    }

    setState(() {
      _semanticStatus = update.isStable
          ? 'Cadru stabil — sensul curent este neschimbat'
          : 'Stabilizez textul detectat...';
    });
  }

  Future<void> _toggleScanning() async {
    setState(() => _sessionStarted = true);
    if (_scanner.isScanning) {
      await _scanner.stop();
      _frameAccumulator.startNewStream();
      if (mounted) {
        setState(() => _semanticStatus = 'Flux OCR oprit');
      }
      return;
    }

    _frameAccumulator.startNewStream();
    _ocrBaseIndex = _fuzer.tokenCount;
    await _scanner.start();
  }

  void _processManualText() {
    final text = _manualTextController.text.trim();
    if (text.isEmpty) {
      return;
    }

    final tokens = OcrFrameAccumulator.tokenizeText(text);
    _fuzer.absorbTokens(tokens, _tagger);
    _manualTextController.clear();
    FocusScope.of(context).unfocus();
    setState(() {
      _sessionStarted = true;
      _semanticStatus = '${tokens.length} contribuții integrate fără pierdere';
    });
  }

  void _resetSession() {
    _fuzer.reset();
    _frameAccumulator.reset();
    _scanner.clearError();
    _manualTextController.clear();
    _ocrBaseIndex = 0;
    setState(() {
      _sessionStarted = false;
      _semanticStatus = 'Așteptare sinteză liniară';
    });
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _fuzer.snapshot;
    final rawMeaning = _sessionStarted
        ? snapshot.rawMeaning
        : '∅  —  așteptare C₁';

    return Scaffold(
      appBar: AppBar(
        title: const Text('DRU — Sinteză Semantică NO-LOSS'),
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
              flex: 5,
              child: _SemanticStatePanel(
                rawMeaning: rawMeaning,
                snapshot: snapshot,
              ),
            ),
            const Divider(height: 1),
            Expanded(
              flex: 3,
              child: _ControlPanel(
                scanner: _scanner,
                semanticStatus: _semanticStatus,
                manualTextController: _manualTextController,
                onToggleScanning: _toggleScanning,
                onProcessManualText: _processManualText,
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

final class _SemanticStatePanel extends StatelessWidget {
  const _SemanticStatePanel({
    required this.rawMeaning,
    required this.snapshot,
  });

  final String rawMeaning;
  final SemanticSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'SENS BRUT INTEGRAT',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: const Color(0xFF69F0AE),
                        letterSpacing: 1.5,
                      ),
                ),
                const SizedBox(height: 12),
                Semantics(
                  label: 'Sens semantic brut curent',
                  liveRegion: true,
                  child: SelectableText(
                    rawMeaning,
                    key: const Key('semantic-monolith'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF69F0AE),
                      fontFamily: 'monospace',
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  snapshot.formalState,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF90CAF9),
                    fontFamily: 'monospace',
                  ),
                ),
                if (snapshot.contributions.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 18),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    collapsedIconColor: Colors.grey,
                    iconColor: Colors.grey,
                    title: Text(
                      'Trasare NO-LOSS · ${snapshot.tokenCount} contribuții',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    children: <Widget>[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: <Widget>[
                            for (final item in snapshot.contributions)
                              Chip(
                                label: Text(
                                  'C${item.index} ${item.surface} → ${item.explicitMeaning}',
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
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
    required this.onToggleScanning,
    required this.onProcessManualText,
  });

  final LocalOcrScanner scanner;
  final String semanticStatus;
  final TextEditingController manualTextController;
  final Future<void> Function() onToggleScanning;
  final VoidCallback onProcessManualText;

  @override
  Widget build(BuildContext context) {
    final controller = scanner.cameraController;
    final showPreview = controller != null && controller.value.isInitialized;

    return ColoredBox(
      color: const Color(0xFF0D1210),
      child: ListView(
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
                  : 'Scanează și sintetizează liniar',
            ),
          ),
          const SizedBox(height: 10),
          _StatusLine(
            active: scanner.isScanning,
            primary: scanner.status,
            secondary: semanticStatus,
          ),
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
          const SizedBox(height: 8),
          Material(
            color: Colors.transparent,
            child: ExpansionTile(
              key: const Key('manual-input-section'),
              tilePadding: EdgeInsets.zero,
              title: const Text('Introducere manuală offline'),
              subtitle: const Text('Aceeași sinteză Sₙ = F(Sₙ₋₁, Cₙ)'),
              children: <Widget>[
                TextField(
                  key: const Key('manual-input'),
                  controller: manualTextController,
                  enabled: !scanner.isScanning,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => onProcessManualText(),
                  decoration: const InputDecoration(
                    hintText: 'Scrie sau lipește textul aici',
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const Key('process-manual-input'),
                    onPressed: scanner.isScanning ? null : onProcessManualText,
                    icon: const Icon(Icons.account_tree_outlined),
                    label: const Text('Integrează fără rezumare'),
                  ),
                ),
              ],
            ),
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
