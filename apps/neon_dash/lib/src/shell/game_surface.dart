import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:playable_core/playable_core.dart';

import '../audio/cue_player.dart';
import '../input/keyboard_steering.dart';
import 'haptics.dart';
import '../render/neon_painter.dart';
import '../render/screen_effects.dart';
import '../render/viewport_layout.dart';
import 'frame_stats.dart';
import 'result_overlay.dart';

class GameSurface extends StatefulWidget {
  const GameSurface({
    required this.level,
    required this.mode,
    required this.layoutSeed,
    required this.audio,
    required this.haptics,
    required this.progression,
    required this.onProfileChanged,
    required this.onRunSettled,
    required this.onExitToMenu,
    required this.onPlayLevel,
    super.key,
  });

  final LevelDefinition level;

  final RunMode mode;

  final int? layoutSeed;

  final CuePlayer audio;

  final Haptics haptics;

  final Progression progression;

  final VoidCallback onProfileChanged;

  final ValueChanged<RunSummary> onRunSettled;

  final VoidCallback onExitToMenu;

  final void Function(LevelDefinition level, RunMode mode) onPlayLevel;

  @override
  State<GameSurface> createState() => _GameSurfaceState();
}

class _GameSurfaceState extends State<GameSurface>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const KeyboardSteering _steering = KeyboardSteering();

  static bool get _hasKeyboard =>
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS;

  late final Game _game;
  late final ScreenEffects _effects;
  late final NeonPainter _painter;
  late final Ticker _ticker;

  final _FrameSignal _frameSignal = _FrameSignal();
  final FrameStatsReporter _frameStats = FrameStatsReporter();
  final _AutoPilot _autoPilot = _AutoPilot();

  int _musicIntensity = -1;

  Duration _lastTick = Duration.zero;
  Size _surfaceSize = Size.zero;
  bool _confirmHeld = false;

  RunSummary? _summary;

  bool _settled = false;

  late int _starsBefore = widget.progression.starsFor(widget.level.index);

  RunMode _modeFor(LevelDefinition level) =>
      widget.mode.isRandomised &&
              widget.progression.isShiftingUnlocked(level.index)
          ? RunMode.shifting
          : RunMode.fixed;

  GamePhase _lastPhase = GamePhase.ready;

  final List<bool> _slotKeyWasDown =
      List<bool>.filled(KeyboardSteering.slotKeyCount, false);

  int _pointerSlot = -1;
  int _keySlot = -1;

  ViewportLayout? _layout;

  final Map<int, int> _pointerDirections = <int, int>{};

  int _heldSteer = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _game = Game(
      level: widget.level,
      loadout: widget.progression.loadout,
      skin: widget.progression.selectedSkin,
      mode: widget.mode,
      seed: widget.layoutSeed,
    );
    _effects = ScreenEffects();
    _painter = NeonPainter(
      world: _game.world,
      effects: _effects,
      theme: widget.level.theme,
      repaint: _frameSignal,
      skin: widget.progression.selectedSkin,
      showKeyHints: _hasKeyboard,
    );

    _ticker = createTicker(_onTick)..start();
    _frameStats.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _frameStats.stop();
    _ticker.dispose();
    _frameSignal.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resumeLoop();
    } else {
      _suspendLoop();
    }
  }

  void _resumeLoop() {
    widget.audio.setMusicPaused(false);
    if (_ticker.isActive) return;
    _lastTick = Duration.zero;
    _ticker.start();
  }

  void _suspendLoop() {
    if (_ticker.isActive) _ticker.stop();
    widget.audio.setMusicPaused(true);
  }

  void _onTick(Duration elapsed) {
    final dt = _lastTick == Duration.zero
        ? 0.0
        : (elapsed - _lastTick).inMicroseconds /
            Duration.microsecondsPerSecond;
    _lastTick = elapsed;

    if (_AutoPilot.enabled) {
      _autoPilot.drive(_game, dt);
    } else {
      _readInput(dt);
    }
    _game.advance(dt);
    _drainEvents();
    _syncMusic();
    _watchPhase();
    _effects.setZonesVisible(visible: _game.world.phase == GamePhase.ready);
    _effects.advance(dt);

    _frameSignal.requestFrame();
  }

  void _watchPhase() {
    final phase = _game.world.phase;
    if (phase == _lastPhase) return;
    _lastPhase = phase;

    if (phase == GamePhase.running || phase == GamePhase.ready) {
      if (_summary != null) setState(() => _summary = null);
      return;
    }

    final summary = RunSummary.of(
      _game.world,
      widget.level,
      mode: widget.mode,
      skin: widget.progression.selectedSkin,
      loadout: widget.progression.loadout,
    );
    if (phase == GamePhase.finished) _settle(summary);
    setState(() => _summary = summary);
  }

  void _settle(RunSummary summary) {
    if (_settled) return;
    _settled = true;
    widget.onRunSettled(summary);
  }

  void _readInput(double dt) {
    var axis = _steering.axis() + _heldSteer;
    if (axis > 1.0) {
      axis = 1.0;
    } else if (axis < -1.0) {
      axis = -1.0;
    }

    if (axis != 0.0) {
      _startIfWaiting();
      final span = _game.config.player.speedInWidths * _game.world.fieldWidth;
      _game.dragTargetBy(axis * span * dt * _steerSign);
    }

    final pressed = _steering.confirmPressed;
    if (pressed && !_confirmHeld) _confirm();
    _confirmHeld = pressed;

    _readSlotKeys();
    _effects.pressedSlot = _pointerSlot >= 0 ? _pointerSlot : _keySlot;
  }

  double get _steerSign => _game.world.controlsMirrored ? -1.0 : 1.0;

  void _readSlotKeys() {
    _keySlot = -1;
    for (var i = 0; i < _slotKeyWasDown.length; i++) {
      final down = _steering.slotPressed(i);
      if (down) {
        _keySlot = i;
        if (!_slotKeyWasDown[i]) _game.activateSlot(i);
      }
      _slotKeyWasDown[i] = down;
    }
  }

  void _drainEvents() {
    final world = _game.world;
    final count = world.eventCount;
    if (count == 0) return;

    for (var i = 0; i < count; i++) {
      final event = world.eventAt(i);
      _effects.onEvent(event);
      widget.haptics.onEvent(event);
      widget.audio.play(cueForEvent(event));
    }
    _game.consumeEvents();
  }

  static const List<double> _layerJoinSeconds = <double>[8.0, 20.0];

  void _syncMusic() {
    final intensity = _musicIntensityFor(_game.world);
    if (intensity == _musicIntensity) return;
    _musicIntensity = intensity;
    widget.audio.setMusicIntensity(intensity);
  }

  int _musicIntensityFor(WorldView world) {
    if (world.phase != GamePhase.running) return 0;

    var intensity = 1;
    for (final threshold in _layerJoinSeconds) {
      if (world.elapsed >= threshold) intensity++;
    }
    return intensity;
  }

  void _applySurfaceSize(Size size) {
    if (size.isEmpty) return;

    if (size != _surfaceSize) {
      _surfaceSize = size;
      _game.resizeToScreenAspect(size.width / size.height);
    }

    _layout = ViewportLayout.fit(
      size,
      _game.world.fieldWidth,
      _game.world.fieldHeight,
      slotCount: _game.world.slotCount,
    );
  }

  void _startIfWaiting() {
    if (_game.world.phase == GamePhase.ready) _game.startRun();
  }

  void _confirm() {
    switch (_game.world.phase) {
      case GamePhase.ready:
        _game.startRun();
      case GamePhase.over:
        _retry();
      case GamePhase.finished:
        final next = _nextLevel();
        next == null ? _retry() : _advanceTo(next);
      case GamePhase.running:
        break;
    }
  }

  LevelDefinition? _nextLevel() {
    for (var i = widget.level.index + 1; i < LevelCatalogue.count; i++) {
      final candidate = LevelCatalogue.byIndex(i);
      if (widget.progression.isUnlocked(candidate)) return candidate;
    }
    return null;
  }

  void _retry() {
    final summary = _summary;
    if (summary != null) _settle(summary);

    _game
      ..restart()
      ..startRun();
    _effects.reset();
    _settled = false;
    _starsBefore = widget.progression.starsFor(widget.level.index);
    setState(() => _summary = null);
  }

  void _advanceTo(LevelDefinition level) {
    final summary = _summary;
    if (summary != null) _settle(summary);
    widget.onPlayLevel(level, _modeFor(level));
  }

  void _exit() {
    final summary = _summary;
    if (summary != null) _settle(summary);
    widget.onExitToMenu();
  }

  void _continue() {
    final summary = _summary;
    if (summary == null || !_game.canContinue) return;
    if (!widget.progression.spendShards(summary.continuePrice)) return;
    if (!_game.continueRun()) return;

    _effects.reset();
    widget.onProfileChanged();
    setState(() => _summary = null);
  }

  void _onPointerDown(PointerDownEvent event) {
    final slot = _layout?.slotIndexAt(event.localPosition) ?? -1;
    if (slot >= 0 && _game.activateSlot(slot)) {
      _pointerSlot = slot;
      _effects.pressedSlot = slot;
      return;
    }

    _confirm();
    _pointerDirections[event.pointer] = _directionAt(event.localPosition);
    _recomputeHeldSteer();
  }

  void _onPointerMove(PointerMoveEvent event) {
    _startIfWaiting();

    final direction = _directionAt(event.localPosition);
    if (_pointerDirections[event.pointer] != direction) {
      _pointerDirections[event.pointer] = direction;
      _recomputeHeldSteer();
    }

    if (direction == 0) {
      _game.dragTargetBy(
        (_layout?.toWorldUnits(event.delta.dx) ?? event.delta.dx) * _steerSign,
      );
    }
  }

  void _onPointerUp(PointerUpEvent event) => _releasePointer(event.pointer);

  void _onPointerCancel(PointerCancelEvent event) =>
      _releasePointer(event.pointer);

  void _releasePointer(int pointer) {
    if (_pointerSlot >= 0) {
      _pointerSlot = -1;
      _effects.pressedSlot = _keySlot;
    }
    if (_pointerDirections.remove(pointer) == null) return;
    _recomputeHeldSteer();
  }

  int _directionAt(Offset localPosition) =>
      _layout?.steerDirectionAt(localPosition) ?? 0;

  void _recomputeHeldSteer() {
    var sum = 0;
    for (final direction in _pointerDirections.values) {
      sum += direction;
    }
    _heldSteer = sum > 0 ? 1 : (sum < 0 ? -1 : 0);
  }

  @override
  Widget build(BuildContext context) {
    final summary = _AutoPilot.enabled ? null : _summary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        _applySurfaceSize(size);

        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              onPointerCancel: _onPointerCancel,
              child: CustomPaint(
                size: size,
                isComplex: false,
                willChange: true,
                painter: _painter,
              ),
            ),
            if (summary != null)
              Listener(
                behavior: HitTestBehavior.opaque,
                child: ResultOverlay(
                  summary: summary,
                  level: widget.level,
                  starsAlreadyHeld: _starsBefore,
                  shardsHeld: widget.progression.shards,
                  canContinue: _game.canContinue,
                  onContinue: _continue,
                  onRetry: _retry,
                  onMenu: _exit,
                  onNext: _nextLevel() == null
                      ? null
                      : () => _advanceTo(_nextLevel()!),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FrameSignal extends ChangeNotifier {
  void requestFrame() => notifyListeners();
}

class _AutoPilot {
  static const bool enabled = bool.fromEnvironment('neon_dash.autopilot');

  static const double _sweepsPerSecond = 0.37;
  static const double _sweepReach = 0.45;
  static const double _tau = 6.283185307179586;

  double _phase = 0.0;

  void drive(Game game, double dt) {
    final world = game.world;

    _phase = (_phase + dt * _sweepsPerSecond) % 1.0;
    final centre = world.fieldWidth * 0.5;
    game.moveTargetTo(
      centre + world.fieldWidth * _sweepReach * math.sin(_phase * _tau),
    );

    switch (world.phase) {
      case GamePhase.ready:
        game.startRun();
      case GamePhase.over:
        game
          ..restart()
          ..startRun();
      case GamePhase.finished:
        game
          ..restart()
          ..startRun();
      case GamePhase.running:
        break;
    }
  }
}
