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
  String _semanticStatus = 'Așteptare flux liniar';

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

    if (update.newWords.isNotEmpty) {
      _absorbWords(update.newWords);
      setState(() {
        _sessionStarted = true;
        _semanticStatus =
            '${update.newWords.length} cuvinte noi absorbite liniar';
      });
      return;
    }

    setState(() {
      _semanticStatus = update.isStable
          ? 'Cadru stabil - fără cuvinte noi'
          : 'Stabilizez textul detectat...';
    });
  }

  void _absorbWords(Iterable<String> words) {
    for (final word in words) {
      _fuzer.absorbWord(word, _tagger.tagWord(word));
    }
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
    await _scanner.start();
  }

  void _processManualText() {
    final text = _manualTextController.text.trim();
    if (text.isEmpty) {
      return;
    }
    final words = text.split(RegExp(r'\s+'));
    _absorbWords(words);
    FocusScope.of(context).unfocus();
    setState(() {
      _sessionStarted = true;
      _semanticStatus = '${words.length} cuvinte procesate offline';
    });
  }

  void _resetSession() {
    _fuzer.reset();
    _frameAccumulator.reset();
    _scanner.clearError();
    _manualTextController.clear();
    setState(() {
      _sessionStarted = false;
      _semanticStatus = 'Așteptare flux liniar';
    });
  }

  void _toggleLock(SemanticElement element) {
    final locked = _fuzer.toggleLock(element.value);
    setState(() {
      _semanticStatus = locked
          ? '${element.value}: Zăvor aplicat'
          : '${element.value}: Zăvor eliminat';
    });
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _fuzer.snapshot;
    final displayMonolith = _sessionStarted
        ? snapshot.monolith
        : '[Așteptare Flux Liniar...]';

    return Scaffold(
      appBar: AppBar(
        title: const Text('DRU - Drujba Semantică v1.0'),
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
                monolith: displayMonolith,
                snapshot: snapshot,
                onElementPressed: _toggleLock,
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

final class _MonolithPanel extends StatelessWidget {
  const _MonolithPanel({
    required this.monolith,
    required this.snapshot,
    required this.onElementPressed,
  });

  final String monolith;
  final SemanticSnapshot snapshot;
  final ValueChanged<SemanticElement> onElementPressed;

  @override
  Widget build(BuildContext context) {
    final hasElements = snapshot.substances.isNotEmpty ||
        snapshot.dynamics.isNotEmpty ||
        snapshot.attributes.isNotEmpty;

    return ColoredBox(
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Semantics(
                  label: 'Monolit semantic curent',
                  liveRegion: true,
                  child: SelectableText(
                    monolith,
                    key: const Key('semantic-monolith'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF69F0AE),
                      fontFamily: 'monospace',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                  ),
                ),
                if (hasElements) ...<Widget>[
                  const SizedBox(height: 22),
                  _ElementGroup(
                    label: 'Ce',
                    color: const Color(0xFF69F0AE),
                    elements: snapshot.substances,
                    onPressed: onElementPressed,
                  ),
                  _ElementGroup(
                    label: 'Dinamică',
                    color: const Color(0xFF64B5F6),
                    elements: snapshot.dynamics,
                    onPressed: onElementPressed,
                  ),
                  _ElementGroup(
                    label: 'Cum',
                    color: const Color(0xFFFFD54F),
                    elements: snapshot.attributes,
                    onPressed: onElementPressed,
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

final class _ElementGroup extends StatelessWidget {
  const _ElementGroup({
    required this.label,
    required this.color,
    required this.elements,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final List<SemanticElement> elements;
  final ValueChanged<SemanticElement> onPressed;

  @override
  Widget build(BuildContext context) {
    if (elements.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 7,
        runSpacing: 7,
        children: <Widget>[
          Text(
            '$label:',
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
          for (final element in elements)
            ActionChip(
              tooltip: element.locked
                  ? 'Elimină Zăvorul pentru ${element.value}'
                  : 'Aplică Zăvorul pentru ${element.value}',
              avatar: Icon(
                element.locked ? Icons.lock : Icons.lock_open,
                size: 16,
                color: element.locked ? Colors.amber : color,
              ),
              label: Text(
                element.frequency > 1
                    ? '${element.value} ×${element.frequency}'
                    : element.value,
              ),
              side: BorderSide(
                color: element.locked ? Colors.amber : color.withAlpha(150),
              ),
              onPressed: () => onPressed(element),
            ),
        ],
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
                  : 'Scanează Pagina Liniar (OCR Continuous)',
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
              subtitle: const Text('Folosește același motor, fără cameră'),
              children: <Widget>[
                TextField(
                  key: const Key('manual-input'),
                  controller: manualTextController,
                  minLines: 1,
                  maxLines: 3,
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
                    onPressed: onProcessManualText,
                    icon: const Icon(Icons.account_tree_outlined),
                    label: const Text('Procesează liniar'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Apasă scurt pe un concept pentru a aplica sau elimina Zăvorul '
            '[LOCK 🔒].',
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
