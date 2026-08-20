import 'dart:async';

import 'package:flutter/material.dart';

import '../cinema/cinematic_scene.dart';

/// Full-bleed, offline projection of the current semantic concept.
///
/// The image is a deterministic view selected by the terminal axiom. It never
/// changes the semantic state and no fallback image is invented for an
/// unresolved concept.
final class CinematicStage extends StatefulWidget {
  const CinematicStage({
    required this.projection,
    required this.display,
    required this.canLock,
    required this.isPaused,
    required this.onLock,
    required this.onTogglePlayback,
    super.key,
  });

  final CinematicSceneProjection projection;
  final String display;
  final bool canLock;
  final bool isPaused;
  final Future<void> Function() onLock;
  final VoidCallback onTogglePlayback;

  @override
  State<CinematicStage> createState() => _CinematicStageState();
}

final class _CinematicStageState extends State<CinematicStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final CurvedAnimation _pulseCurve;
  late final Animation<double> _pulseScale;
  late final Animation<double> _pulseOpacity;
  late final Animation<double> _backgroundScale;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: widget.projection.scene?.pulse ??
          const Duration(milliseconds: 1400),
    );
    _pulseCurve = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
    _pulseScale =
        Tween<double>(begin: 0.97, end: 1.04).animate(_pulseCurve);
    _pulseOpacity =
        Tween<double>(begin: 0.72, end: 1).animate(_pulseCurve);
    _backgroundScale =
        Tween<double>(begin: 1.01, end: 1.07).animate(_pulseCurve);
    _syncPlayback();
  }

  @override
  void didUpdateWidget(CinematicStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldScene = oldWidget.projection.scene;
    final newScene = widget.projection.scene;
    if (oldScene?.sceneId != newScene?.sceneId ||
        oldScene?.pulse != newScene?.pulse) {
      _pulseController
        ..duration = newScene?.pulse ?? const Duration(milliseconds: 1400)
        ..value = 0;
    }
    if (oldWidget.isPaused != widget.isPaused ||
        oldWidget.projection.status != widget.projection.status ||
        oldScene?.sceneId != newScene?.sceneId ||
        oldScene?.pulse != newScene?.pulse) {
      _syncPlayback();
    }
  }

  void _syncPlayback() {
    if (widget.isPaused ||
        widget.projection.status == CinematicSceneStatus.empty) {
      _pulseController.stop();
      return;
    }
    _pulseController.repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    final scene = widget.projection.scene;
    final transition =
        scene?.transition ?? const Duration(milliseconds: 320);
    final foreground = widget.projection.status ==
            CinematicSceneStatus.unresolved
        ? const Color(0xFFFFC107)
        : const Color(0xFF69F0AE);

    return RepaintBoundary(
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            AnimatedSwitcher(
              duration: transition,
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: scene == null
                  ? const ColoredBox(
                      key: ValueKey<String>('cinema-black'),
                      color: Colors.black,
                    )
                  : ScaleTransition(
                      key: ValueKey<String>(scene.sceneId),
                      scale: _backgroundScale,
                      child: Image.asset(
                        scene.assetPath,
                        key: const Key('cinematic-scene-image'),
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (context, error, stackTrace) =>
                            const ColoredBox(color: Colors.black),
                      ),
                    ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: <Color>[
                    Color(0x55000000),
                    Color(0xDD000000),
                  ],
                  radius: 1.05,
                ),
              ),
            ),
            Center(
              child: Semantics(
                label: 'Sens brut compozițional curent',
                hint: widget.canLock
                    ? 'Atinge pentru a îngheța cadrul și a aplica Zăvorul'
                    : null,
                button: widget.canLock,
                liveRegion: true,
                child: GestureDetector(
                  key: const Key('lock-current-sense'),
                  onTap: widget.canLock
                      ? () => unawaited(widget.onLock())
                      : null,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: ScaleTransition(
                      scale: _pulseScale,
                      child: FadeTransition(
                        opacity: _pulseOpacity,
                        child: AnimatedSwitcher(
                          duration: transition,
                          child: KeyedSubtree(
                            key: ValueKey<String>(widget.display),
                            child: Text(
                              widget.display,
                              key: const Key('semantic-monolith'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: foreground,
                                fontFamily: 'monospace',
                                fontSize: 31,
                                fontWeight: FontWeight.w800,
                                height: 1.25,
                                shadows: const <Shadow>[
                                  Shadow(
                                    color: Colors.black,
                                    blurRadius: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filledTonal(
                key: const Key('toggle-cinematic-playback'),
                tooltip: widget.isPaused
                    ? 'Continuă proiecția'
                    : 'Pauză proiecție',
                onPressed: widget.onTogglePlayback,
                icon: Icon(
                  widget.isPaused ? Icons.play_arrow : Icons.pause,
                ),
              ),
            ),
            Positioned(
              left: 12,
              bottom: 10,
              child: Text(
                widget.projection.isLocked
                    ? 'CADRU BLOCAT · ZĂVOR SEMANTIC'
                    : scene == null
                        ? 'PROIECȚIE LOCALĂ · FĂRĂ SCENĂ AXIOMATICĂ'
                        : 'FILM SEMANTIC LOCAL · '
                            '${scene.sceneId.toUpperCase()}',
                key: const Key('cinematic-scene-status'),
                style: const TextStyle(
                  color: Colors.white54,
                  fontFamily: 'monospace',
                  fontSize: 10,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pulseCurve.dispose();
    _pulseController.dispose();
    super.dispose();
  }
}
