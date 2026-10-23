import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neon_dash/src/render/backdrop.dart';
import 'package:neon_dash/src/render/craft_shape.dart';
import 'package:neon_dash/src/render/neon_painter.dart';
import 'package:neon_dash/src/render/palette.dart';
import 'package:neon_dash/src/render/screen_effects.dart';
import 'package:neon_dash/src/render/viewport_layout.dart';
import 'package:playable_core/playable_core.dart';
import 'package:playable_core/src/application/world.dart';

const List<Size> _surfaces = <Size>[
  Size(360.0, 800.0),
  Size(360.0, 900.0),
  Size(1600.0, 900.0),
  Size(700.0, 700.0),
];

const double _step = 1.0 / 120.0;

void main() {
  group('Every screen shape', () {
    const shapes = <String, Size>{
      'foldable 1:1': Size(1768.0, 1768.0),
      'tablet 3:4': Size(1536.0, 2048.0),
      'phone 9:16': Size(1080.0, 1920.0),
      'phone 9:19.5': Size(1170.0, 2532.0),
      'phone 9:20': Size(1080.0, 2400.0),
      'phone 9:21': Size(1080.0, 2520.0),
      'desktop 16:9': Size(1920.0, 1080.0),
      'ultrawide 21:9': Size(2560.0, 1080.0),
    };

    test('the field and everything on it fits any of them', () {
      for (final entry in shapes.entries) {
        final size = entry.value;
        final game = Game(level: LevelCatalogue.byIndex(0))
          ..resizeToScreenAspect(size.width / size.height);

        final layout = ViewportLayout.fit(
          size,
          game.world.fieldWidth,
          game.world.fieldHeight,
          slotCount: game.world.slotCount,
        );

        final screen = Offset.zero & size;
        expect(screen.contains(layout.fieldRect.topLeft), isTrue,
            reason: entry.key);
        expect(
          screen.contains(
            layout.fieldRect.bottomRight - const Offset(1.0, 1.0),
          ),
          isTrue,
          reason: entry.key,
        );

        for (final piece in <Rect>[
          layout.leftZone,
          layout.rightZone,
          layout.slotRow,
        ]) {
          expect(layout.fieldRect.contains(piece.topLeft), isTrue,
              reason: entry.key);
          expect(
            layout.fieldRect.contains(piece.bottomRight - const Offset(1, 1)),
            isTrue,
            reason: entry.key,
          );
        }
      }
    });

    test('the two steering panels never meet', () {
      for (final entry in shapes.entries) {
        final size = entry.value;
        final game = Game(level: LevelCatalogue.byIndex(0))
          ..resizeToScreenAspect(size.width / size.height);
        final layout = ViewportLayout.fit(
          size,
          game.world.fieldWidth,
          game.world.fieldHeight,
        );

        expect(layout.leftZone.right, lessThan(layout.rightZone.left),
            reason: entry.key);
      }
    });

    test('reaction time is the same on all of them', () {
      final heights = <double>{
        for (final size in shapes.values)
          (Game(level: LevelCatalogue.byIndex(0))
                ..resizeToScreenAspect(size.width / size.height))
              .world
              .fieldHeight,
      };

      expect(heights, hasLength(1));
    });
  });

  group('Backdrops', () {
    test('every style paints without reaching past its scatter tables', () {
      for (final style in BackdropStyle.values) {
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);
        final backdrop = Backdrop(_themeWith(style));

        for (final distance in <double>[0.0, 137.0, 9999.0]) {
          backdrop.paint(
            canvas,
            const Rect.fromLTWH(0.0, 0.0, 420.0, 900.0),
            9.0,
            distance,
            0.37,
            Paint(),
            Paint(),
          );
        }

        recorder.endRecording().dispose();
      }
    });

    test('every level names a style that exists', () {
      for (final level in LevelCatalogue.levels) {
        expect(BackdropStyle.values, contains(level.theme.backdrop),
            reason: level.name);
      }
    });
  });

  group('Gates', () {
    test('every kind paints, in flight and in force', () {
      for (final kind in PortalKind.values) {
        final level = LevelCatalogue.levels.firstWhere(
          (candidate) => candidate.portals.contains(kind),
          orElse: () => LevelCatalogue.levels.last,
        );
        final game = Game(level: level)
          ..resizeToScreenAspect(0.45)
          ..startRun();
        final effects = ScreenEffects()..onEvent(GameEvent.portalEntered);

        final world = game.world as World;
        world
          ..addPortal(y: -20.0, kind: kind)
          ..beginPortal(kind);

        final painter = NeonPainter(
          world: world,
          effects: effects,
          theme: level.theme,
          repaint: _NeverRepaints(),
        );

        final recorder = PictureRecorder();
        painter.paint(Canvas(recorder), const Size(420.0, 900.0));
        recorder.endRecording().dispose();

        expect(world.portal, kind, reason: kind.name);
      }
    });

    test('a stretch fades out over its last second', () {
      final level = LevelCatalogue.byIndex(13);
      final game = Game(level: level)..resizeToScreenAspect(0.45);
      final world = game.world as World..beginPortal(PortalKind.rush);

      expect(world.portalRemaining, greaterThan(1.0));
      world.portalRemaining = 0.4;

      final painter = NeonPainter(
        world: world,
        effects: ScreenEffects(),
        theme: level.theme,
        repaint: _NeverRepaints(),
      );

      final recorder = PictureRecorder();
      painter.paint(Canvas(recorder), const Size(420.0, 900.0));
      recorder.endRecording().dispose();
    });
  });

  group('Craft shapes', () {
    test('every hull builds one path per speed tier', () {
      for (final skin in CraftSkin.values) {
        final paths = buildHullPaths(skin);

        expect(paths, hasLength(kHullTiers), reason: skin.name);
        for (final path in paths) {
          final bounds = path.getBounds();
          expect(bounds.isEmpty, isFalse, reason: skin.name);
          expect(bounds.width, lessThan(4.0), reason: skin.name);
          expect(bounds.height, lessThan(4.0), reason: skin.name);
        }
      }
    });

    test('the nose leads and the tail follows', () {
      for (final skin in CraftSkin.values) {
        final bounds = buildHullPath(skin, 0.0).getBounds();
        expect(bounds.top, lessThan(0.0), reason: skin.name);
        expect(bounds.bottom, greaterThan(0.0), reason: skin.name);
      }
    });

    test('a hull tightens as the run speeds up', () {
      for (final skin in CraftSkin.values) {
        final slow = buildHullPath(skin, 0.0).getBounds().width;
        final fast = buildHullPath(skin, 1.0).getBounds().width;
        expect(fast, lessThan(slow), reason: skin.name);
      }
    });

    test('thruster positions match the count the skin declares', () {
      for (final skin in CraftSkin.values) {
        final offsets = exhaustOffsets(skin);

        expect(offsets, hasLength(skin.exhausts), reason: skin.name);
        expect(exhaustWidthScale(skin), greaterThan(0.0), reason: skin.name);
        if (skin.exhausts.isOdd) {
          expect(offsets, contains(0.0), reason: skin.name);
        }
      }
    });
  });

  group('NeonPainter', () {
    testWidgets('paints every phase at every surface without throwing',
        (tester) async {
      for (final size in _surfaces) {
        final game = Game(seed: 11)
          ..resizeToScreenAspect(size.width / size.height);
        final effects = ScreenEffects();
        final painter = _painterFor(game, effects);

        _paintOnce(painter, size);

        game.startRun();
        for (var i = 0; i < 360; i++) {
          game
            ..moveTargetTo((i % 60) * 0.6)
            ..advance(_step);
          _feedEffects(game, effects);
          effects.advance(_step);
        }
        _paintOnce(painter, size);

        _runUntilOver(game, effects);
        _paintOnce(painter, size);

        expect(
          game.world.particleCount,
          greaterThan(0),
          reason: 'the crash burst should still be alive at $size',
        );
      }
    });

    testWidgets('paints every level in the catalogue', (tester) async {
      for (final level in LevelCatalogue.levels) {
        final game = Game(level: level)
          ..resizeToScreenAspect(0.45)
          ..startRun();
        final effects = ScreenEffects();
        final painter = NeonPainter(
          world: game.world,
          effects: effects,
          theme: level.theme,
          repaint: _NeverRepaints(),
        );

        for (var i = 0; i < 360; i++) {
          game
            ..advance(_step)
            ..consumeEvents();
          effects.advance(_step);
        }

        expect(
          () => _paintOnce(painter, const Size(400.0, 900.0)),
          returnsNormally,
          reason: level.name,
        );
      }
    });

    testWidgets('paints an empty world at a degenerate size', (tester) async {
      final game = Game();
      final painter = _painterFor(game, ScreenEffects());

      expect(() => _paintOnce(painter, const Size(1.0, 1.0)), returnsNormally);
    });

    testWidgets('survives a resize between paints', (tester) async {
      final game = Game(seed: 3)..startRun();
      final effects = ScreenEffects();
      final painter = _painterFor(game, effects);

      for (final size in _surfaces) {
        game.resizeToScreenAspect(size.width / size.height);
        for (var i = 0; i < 120; i++) {
          game.advance(_step);
          _feedEffects(game, effects);
        }
        expect(() => _paintOnce(painter, size), returnsNormally);
      }
    });
  });

  group('Palette', () {
    test('packs hue into a fully opaque colour at alpha one', () {
      final red = packHsl(0.0, 1.0, 0.5, 1.0);

      expect(red >> 24 & 0xFF, 255, reason: 'alpha');
      expect(red >> 16 & 0xFF, 255, reason: 'red');
      expect(red >> 8 & 0xFF, 0, reason: 'green');
      expect(red & 0xFF, 0, reason: 'blue');
    });

    test('wraps hue around the colour wheel', () {
      expect(packHsl(370.0, 0.8, 0.5, 1.0), packHsl(10.0, 0.8, 0.5, 1.0));
      expect(packHsl(-20.0, 0.8, 0.5, 1.0), packHsl(340.0, 0.8, 0.5, 1.0));
    });

    test('clamps channels instead of overflowing into other bytes', () {
      final packed = packHsl(200.0, 2.0, 5.0, 3.0);

      for (var shift = 0; shift <= 24; shift += 8) {
        final channel = packed >> shift & 0xFF;
        expect(channel, inInclusiveRange(0, 255));
      }
    });

    test('lightness zero is black and one is white', () {
      expect(packHsl(120.0, 1.0, 0.0, 1.0) & 0xFFFFFF, 0x000000);
      expect(packHsl(120.0, 1.0, 1.0, 1.0) & 0xFFFFFF, 0xFFFFFF);
    });
  });

  group('ScreenEffects', () {
    test('a crash shakes the camera and flashes the screen', () {
      final effects = ScreenEffects()..onEvent(GameEvent.crashed);

      expect(effects.flashAlpha, greaterThan(0.0));
      expect(effects.shakeX.abs() + effects.shakeY.abs(), greaterThan(0.0));
    });

    test('everything decays back to rest', () {
      final effects = ScreenEffects()
        ..onEvent(GameEvent.crashed)
        ..onEvent(GameEvent.orbCollected);

      for (var i = 0; i < 600; i++) {
        effects.advance(_step);
      }

      expect(effects.flashAlpha, lessThan(0.01));
      expect(effects.pulse, lessThan(0.01));
      expect(effects.shakeX.abs(), lessThan(0.01));
      expect(effects.shakeY.abs(), lessThan(0.01));
    });

    test('stacked impacts stay bounded', () {
      final effects = ScreenEffects();
      for (var i = 0; i < 200; i++) {
        effects.onEvent(GameEvent.crashed);
      }

      expect(effects.shakeX.abs(), lessThan(3.0));
      expect(effects.flashAlpha, lessThanOrEqualTo(1.0));
      expect(effects.pulse, lessThanOrEqualTo(1.0));
    });

    test('reset clears a run', () {
      final effects = ScreenEffects()..onEvent(GameEvent.crashed);
      effects.reset();

      expect(effects.flashAlpha, 0.0);
      expect(effects.shakeX, 0.0);
      expect(effects.pulse, 0.0);
    });

    test('the steering panels start visible', () {
      expect(ScreenEffects().zoneProminence, 1.0);
    });

    test('the panels settle at exactly zero once the run starts', () {
      final effects = ScreenEffects()..setZonesVisible(visible: false);

      for (var i = 0; i < 120; i++) {
        effects.advance(_step);
      }

      expect(effects.zoneProminence, 0.0);
    });

    test('the panels come back when the game waits again', () {
      final effects = ScreenEffects()..setZonesVisible(visible: false);
      for (var i = 0; i < 120; i++) {
        effects.advance(_step);
      }

      effects.setZonesVisible(visible: true);
      for (var i = 0; i < 120; i++) {
        effects.advance(_step);
      }

      expect(effects.zoneProminence, 1.0);
    });

    test('the fade is gradual rather than a single-frame cut', () {
      final effects = ScreenEffects()..setZonesVisible(visible: false);

      effects.advance(_step);

      expect(effects.zoneProminence, lessThan(1.0));
      expect(effects.zoneProminence, greaterThan(0.9));
    });
  });

  group('ViewportLayout', () {
    const worldWidth = 45.0;
    const worldHeight = 100.0;

    test('centres a field that cannot fill the surface', () {
      const size = Size(1600.0, 900.0);
      final layout = ViewportLayout.fit(size, worldWidth, worldHeight);

      expect(layout.fieldRect.height, closeTo(size.height, 1e-9));
      expect(layout.fieldRect.center.dx, closeTo(size.width / 2, 1e-9));
      expect(layout.fieldRect.left, greaterThan(0.0));
      expect(layout.fieldRect.right, lessThan(size.width));
    });

    test('the field never overflows the surface', () {
      for (final size in _surfaces) {
        final layout = ViewportLayout.fit(size, worldWidth, worldHeight);

        expect(layout.fieldRect.left, greaterThanOrEqualTo(-1e-9));
        expect(layout.fieldRect.top, greaterThanOrEqualTo(-1e-9));
        expect(layout.fieldRect.right, lessThanOrEqualTo(size.width + 1e-9));
        expect(layout.fieldRect.bottom, lessThanOrEqualTo(size.height + 1e-9));
      }
    });

    test('zones stay inside the field and apart from each other', () {
      for (final size in _surfaces) {
        final layout = ViewportLayout.fit(size, worldWidth, worldHeight);
        final field = layout.fieldRect;

        for (final zone in <Rect>[layout.leftZone, layout.rightZone]) {
          expect(zone.width, greaterThan(0.0), reason: '$size');
          expect(zone.height, greaterThan(0.0), reason: '$size');
          expect(field.contains(zone.topLeft), isTrue, reason: '$size');
          expect(field.contains(zone.bottomRight), isTrue, reason: '$size');
        }
        expect(
          layout.leftZone.right,
          lessThan(layout.rightZone.left),
          reason: 'the zones must leave a gap to drag in, at $size',
        );
      }
    });

    test('hit testing matches the zones that are drawn', () {
      final layout = ViewportLayout.fit(
        const Size(400.0, 900.0),
        worldWidth,
        worldHeight,
      );

      expect(layout.steerDirectionAt(layout.leftZone.center), -1);
      expect(layout.steerDirectionAt(layout.rightZone.center), 1);
      expect(layout.steerDirectionAt(layout.fieldRect.center), 0);
      expect(layout.steerDirectionAt(layout.fieldRect.topLeft), 0);
    });

    test('the power-up row sits inside the field, below both zones', () {
      final layout = ViewportLayout.fit(const Size(420.0, 900.0), 45.0, 100.0);

      final row = layout.slotRow;
      expect(layout.fieldRect.contains(row.topLeft), isTrue);
      expect(layout.fieldRect.contains(row.bottomRight - const Offset(1, 1)),
          isTrue);
      expect(row.top, greaterThan(layout.leftZone.bottom));
      expect(row.top, greaterThan(layout.rightZone.bottom));
    });

    test('the power-up buttons are square, equal and in order', () {
      final layout = ViewportLayout.fit(const Size(420.0, 900.0), 45.0, 100.0);

      Rect? previous;
      for (var i = 0; i < layout.slotCount; i++) {
        final rect = layout.slotRect(i);
        expect(rect.width, closeTo(rect.height, 1e-9));
        if (previous != null) {
          expect(rect.left, greaterThan(previous.right));
          expect(rect.width, closeTo(previous.width, 1e-9));
        }
        previous = rect;
      }
    });

    test('the row stays inside a field far narrower than it asks for', () {
      final layout = ViewportLayout.fit(const Size(200.0, 900.0), 20.0, 100.0);

      final row = layout.slotRow;
      expect(row.left, greaterThanOrEqualTo(layout.fieldRect.left));
      expect(row.right, lessThanOrEqualTo(layout.fieldRect.right));
    });

    test('hit testing matches the buttons that are drawn', () {
      final layout = ViewportLayout.fit(const Size(420.0, 900.0), 45.0, 100.0);

      for (var i = 0; i < layout.slotCount; i++) {
        expect(layout.slotIndexAt(layout.slotRect(i).center), i);
      }
      expect(layout.slotIndexAt(layout.fieldRect.center), -1);
      expect(layout.slotIndexAt(layout.leftZone.center), -1);
    });

    test('a button swallows the steer it sits on', () {
      final layout = ViewportLayout.fit(const Size(420.0, 900.0), 45.0, 100.0);

      for (var i = 0; i < layout.slotCount; i++) {
        expect(layout.steerDirectionAt(layout.slotRect(i).center), 0);
      }
    });

    test('an index outside the row draws and hits nothing', () {
      final layout = ViewportLayout.fit(const Size(420.0, 900.0), 45.0, 100.0);

      expect(layout.slotRect(-1), Rect.zero);
      expect(layout.slotRect(layout.slotCount), Rect.zero);
    });

    test('pixels convert back to world units', () {
      final layout = ViewportLayout.fit(
        const Size(450.0, 1000.0),
        worldWidth,
        worldHeight,
      );

      expect(layout.scale, closeTo(10.0, 1e-9));
      expect(layout.toWorldUnits(25.0), closeTo(2.5, 1e-9));
    });

    test('a degenerate surface does not divide by zero', () {
      final layout = ViewportLayout.fit(Size.zero, worldWidth, worldHeight);

      expect(layout.toWorldUnits(5.0), 5.0);
      expect(() => layout.leftZone, returnsNormally);
    });
  });
}

NeonPainter _painterFor(Game game, ScreenEffects effects) => NeonPainter(
      world: game.world,
      effects: effects,
      theme: LevelCatalogue.levels.first.theme,
      repaint: _NeverRepaints(),
    );

void _paintOnce(NeonPainter painter, Size size) {
  final recorder = PictureRecorder();
  painter.paint(Canvas(recorder), size);
  recorder.endRecording().dispose();
}

void _feedEffects(Game game, ScreenEffects effects) {
  final world = game.world;
  for (var i = 0; i < world.eventCount; i++) {
    effects.onEvent(world.eventAt(i));
  }
  game.consumeEvents();
}

void _runUntilOver(Game game, ScreenEffects effects) {
  for (var i = 0; i < 20000 && game.world.phase != GamePhase.over; i++) {
    game.advance(_step);
    _feedEffects(game, effects);
    effects.advance(_step);
  }
}

class _NeverRepaints extends ChangeNotifier {}

LevelTheme _themeWith(BackdropStyle style) {
  final base = LevelCatalogue.byIndex(0).theme;
  return LevelTheme(
    backdrop: style,
    craft: base.craft,
    orb: base.orb,
    hazard: base.hazard,
    skyFar: base.skyFar,
    skyNear: base.skyNear,
    surroundFar: base.surroundFar,
    surroundNear: base.surroundNear,
    grid: base.grid,
    horizon: base.horizon,
    rail: base.rail,
  );
}
