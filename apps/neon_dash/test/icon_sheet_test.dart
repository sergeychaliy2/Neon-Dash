library;

import 'dart:io';

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neon_dash/src/render/craft_shape.dart';
import 'package:neon_dash/src/render/palette.dart';
import 'package:playable_core/playable_core.dart';

const double _side = 512.0;

typedef _Candidate = (String name, void Function(Canvas canvas, double side));

void main() {
  final candidates = <_Candidate>[
    ('1-mark', _paintMark),
    ('2-grid', _paintGrid),
    ('3-gate', _paintGate),
    ('4-ring', _paintRing),
    ('5-finish', _paintFinish),
    ('6-trail', _paintTrail),
    ('7-grid-bold', _paintGridBold),
    ('8-grid-floor', _paintGridFloor),
  ];

  test('every icon candidate draws, and the files are written', () async {
    final out = Directory('build/icons')..createSync(recursive: true);

    for (final (name, paint) in candidates) {
      final bytes = await _render(_side, (canvas) => paint(canvas, _side));

      expect(bytes.lengthInBytes, greaterThan(2000), reason: '$name is empty');
      File('${out.path}/$name.png').writeAsBytesSync(bytes.buffer.asUint8List());
    }
  });

  test('the small-size strip is written', () async {
    const small = 64.0;
    const blow = 5.0;

    final shrunk = <ui.Image>[];
    for (final (_, paint) in candidates) {
      final recorder = ui.PictureRecorder();
      paint(Canvas(recorder, const Rect.fromLTWH(0.0, 0.0, small, small)),
          small);
      final picture = recorder.endRecording();
      shrunk.add(await picture.toImage(small.round(), small.round()));
      picture.dispose();
    }

    final bytes = await _render(
      small * blow * candidates.length,
      (canvas) {
        for (var i = 0; i < shrunk.length; i++) {
          canvas.drawImageRect(
            shrunk[i],
            const Rect.fromLTWH(0.0, 0.0, small, small),
            Rect.fromLTWH(i * small * blow, 0.0, small * blow, small * blow),
            Paint()..filterQuality = FilterQuality.none,
          );
        }
      },
      height: small * blow,
    );

    for (final image in shrunk) {
      image.dispose();
    }

    File('build/icons/small.png').writeAsBytesSync(bytes.buffer.asUint8List());
  });

  test('the launcher icon set is written', () async {
    const densities = <(String, int, int)>[
      ('mdpi', 48, 108),
      ('hdpi', 72, 162),
      ('xhdpi', 96, 216),
      ('xxhdpi', 144, 324),
      ('xxxhdpi', 192, 432),
    ];

    final root = Directory('build/icons/launcher')
      ..createSync(recursive: true);

    for (final (density, plain, adaptive) in densities) {
      final folder = Directory('${root.path}/mipmap-$density')
        ..createSync(recursive: true);

      final icon = await _render(
        plain.toDouble(),
        (canvas) => _paintGridBold(canvas, plain.toDouble()),
      );
      File('${folder.path}/ic_launcher.png')
          .writeAsBytesSync(icon.buffer.asUint8List());

      final background = await _render(
        adaptive.toDouble(),
        (canvas) => _plate(canvas, adaptive.toDouble()),
      );
      File('${folder.path}/ic_launcher_background.png')
          .writeAsBytesSync(background.buffer.asUint8List());

      final foreground = await _render(
        adaptive.toDouble(),
        (canvas) => _gridBoldSubject(canvas, adaptive.toDouble()),
      );
      File('${folder.path}/ic_launcher_foreground.png')
          .writeAsBytesSync(foreground.buffer.asUint8List());
    }

    final win = Directory('${root.path}/win')..createSync(recursive: true);
    for (final size in <int>[16, 32, 48, 64, 128, 256]) {
      final bytes = await _render(
        size.toDouble(),
        (canvas) => _paintGridBold(canvas, size.toDouble()),
      );
      File('${win.path}/$size.png').writeAsBytesSync(bytes.buffer.asUint8List());
    }

    expect(
      Directory('${root.path}/mipmap-xxxhdpi').listSync().length,
      3,
      reason: 'each density needs the plain icon and both adaptive layers',
    );
  });

  test('the contact sheet is written', () async {
    const cell = 256.0;
    const columns = 3;
    final rows = (candidates.length / columns).ceil();

    final bytes = await _render(
      cell * columns,
      (canvas) {
        canvas.drawRect(
          Rect.fromLTWH(0.0, 0.0, cell * columns, cell * rows),
          Paint()..color = Palette.skyFar,
        );
        for (var i = 0; i < candidates.length; i++) {
          canvas
            ..save()
            ..translate((i % columns) * cell, (i ~/ columns) * cell)
            ..clipRect(const Rect.fromLTWH(0.0, 0.0, cell, cell));
          candidates[i].$2(canvas, cell);
          canvas.restore();
        }
      },
      height: cell * rows,
    );

    File('build/icons/sheet.png').writeAsBytesSync(bytes.buffer.asUint8List());
  });
}

Future<ByteData> _render(
  double width,
  void Function(Canvas canvas) paint, {
  double? height,
}) async {
  final size = Size(width, height ?? width);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Offset.zero & size);

  paint(canvas);

  final picture = recorder.endRecording();
  final image = await picture.toImage(
    size.width.round(),
    size.height.round(),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  picture.dispose();
  image.dispose();

  return bytes!;
}

void _plate(Canvas canvas, double side) {
  final rect = Rect.fromLTWH(0.0, 0.0, side, side);

  canvas
    ..drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(side * 0.5, 0.0),
          Offset(side * 0.5, side),
          <Color>[Palette.skyNear, Palette.skyFar],
        ),
    )
    ..drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(side * 0.5, side * 0.46),
          side * 0.62,
          <Color>[
            const Color(0x26123A52),
            const Color(0x00000000),
          ],
        ),
    );
}

const double _safe = 0.70;

void _glow(Canvas canvas, Offset centre, double radius, Color colour) {
  canvas.drawCircle(
    centre,
    radius,
    Paint()
      ..shader = ui.Gradient.radial(
        centre,
        radius,
        <Color>[colour, colour.withValues(alpha: 0.0)],
      ),
  );
}

void _craft(
  Canvas canvas,
  Offset centre,
  double radius, {
  double hue = Palette.craftHue,
  bool plumes = true,
}) {
  const skin = CraftSkin.standard;
  final ink = NeonInk.fromHue(hue);
  final paint = Paint()..isAntiAlias = true;

  _glow(canvas, centre, radius * 2.1, ink.halo);

  canvas
    ..save()
    ..translate(centre.dx, centre.dy);

  if (plumes) {
    final plume = radius * 1.25;
    for (final offset in exhaustOffsets(skin)) {
      canvas
        ..save()
        ..translate(offset * radius, exhaustSeat(skin) * radius)
        ..scale(plume * exhaustWidthScale(skin), plume);
      paint.color = ink.aura;
      canvas
        ..drawPath(buildExhaustPath(), paint)
        ..restore();
    }
  }

  final hull = buildHullPath(skin, 0.35);
  for (final (factor, color) in <(double, Color)>[
    (1.22, ink.aura),
    (1.0, ink.body),
    (0.52, ink.edge),
  ]) {
    canvas
      ..save()
      ..scale(radius * factor, radius * factor);
    paint.color = color;
    canvas
      ..drawPath(hull, paint)
      ..restore();
  }

  canvas.restore();
}

void _paintMark(Canvas canvas, double side) {
  _plate(canvas, side);
  _craft(canvas, Offset(side * 0.5, side * 0.5), side * _safe * 0.34);
}

void _paintGrid(Canvas canvas, double side) {
  _plate(canvas, side);

  final horizon = side * 0.30;
  final paint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeWidth = side * 0.011
    ..color = const Color(0x5540E0FF);

  for (var i = -3; i <= 3; i++) {
    canvas.drawLine(
      Offset(side * 0.5 + i * side * 0.05, horizon),
      Offset(side * 0.5 + i * side * 0.34, side),
      paint,
    );
  }
  for (var i = 1; i <= 4; i++) {
    final t = i / 4.0;
    final y = horizon + (side - horizon) * t * t;
    canvas.drawLine(Offset(0.0, y), Offset(side, y), paint);
  }

  paint
    ..color = const Color(0x8870F4FF)
    ..strokeWidth = side * 0.016;
  canvas.drawLine(Offset(0.0, horizon), Offset(side, horizon), paint);

  _craft(canvas, Offset(side * 0.5, side * 0.56), side * _safe * 0.30);
}

void _paintGate(Canvas canvas, double side) {
  _plate(canvas, side);

  final ink = NeonInk.fromHue(Palette.craftHue + 16.0);
  final bar = Paint()..isAntiAlias = true;
  final top = side * 0.30;
  final thickness = side * 0.11;
  final gap = side * 0.26;
  final margin = side * 0.12;

  for (final (from, to) in <(double, double)>[
    (margin, (side - gap) * 0.5),
    ((side + gap) * 0.5, side - margin),
  ]) {
    bar.color = ink.halo;
    canvas.drawRRect(
      RRect.fromLTRBR(
        from - side * 0.02,
        top - side * 0.02,
        to + side * 0.02,
        top + thickness + side * 0.02,
        Radius.circular(side * 0.04),
      ),
      bar,
    );
    bar.color = ink.body;
    canvas.drawRRect(
      RRect.fromLTRBR(from, top, to, top + thickness,
          Radius.circular(side * 0.025)),
      bar,
    );
    bar.color = ink.edge;
    canvas.drawRect(
      Rect.fromLTRB(from, top + thickness * 0.38, to, top + thickness * 0.56),
      bar,
    );
  }

  _craft(canvas, Offset(side * 0.5, side * 0.66), side * _safe * 0.27);
}

void _paintRing(Canvas canvas, double side) {
  _plate(canvas, side);

  final ink = NeonInk.fromHue(Palette.craftHue);
  final centre = Offset(side * 0.5, side * 0.5);
  final radius = side * _safe * 0.46;
  final ring = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke;

  _glow(canvas, centre, radius * 1.5, ink.halo);

  for (final (width, color) in <(double, Color)>[
    (side * 0.075, ink.aura),
    (side * 0.034, ink.body),
    (side * 0.012, ink.edge),
  ]) {
    ring
      ..strokeWidth = width
      ..color = color;
    canvas.drawCircle(centre, radius, ring);
  }

  _craft(canvas, centre, side * _safe * 0.25);
}

void _paintFinish(Canvas canvas, double side) {
  _plate(canvas, side);

  final ink = NeonInk.fromHue(Palette.orbHue);
  final paint = Paint()..isAntiAlias = true;
  final top = side * 0.62;
  final band = side * 0.13;
  final margin = side * 0.10;

  _glow(canvas, Offset(side * 0.5, top + band * 0.5), side * 0.44, ink.halo);

  final tick = (side - margin * 2.0) / 6.0;
  for (var i = 0; i < 6; i++) {
    paint.color = i.isEven ? ink.edge : ink.body;
    canvas.drawRect(
      Rect.fromLTRB(
        margin + i * tick,
        top,
        margin + (i + 1) * tick,
        top + band,
      ),
      paint,
    );
  }

  _craft(canvas, Offset(side * 0.5, side * 0.38), side * _safe * 0.28);
}

void _paintTrail(Canvas canvas, double side) {
  _plate(canvas, side);

  final ink = NeonInk.fromHue(Palette.craftHue);
  final nose = Offset(side * 0.5, side * 0.44);

  final trail = Path()
    ..moveTo(nose.dx - side * 0.035, nose.dy)
    ..lineTo(nose.dx + side * 0.035, nose.dy)
    ..lineTo(nose.dx + side * 0.21, side * 0.94)
    ..lineTo(nose.dx - side * 0.21, side * 0.94)
    ..close();

  canvas.drawPath(
    trail,
    Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.linear(
        Offset(nose.dx, nose.dy),
        Offset(nose.dx, side * 0.94),
        <Color>[ink.aura, ink.halo.withValues(alpha: 0.0)],
      ),
  );

  _craft(canvas, nose, side * _safe * 0.30, plumes: false);
}

void _paintGridBold(Canvas canvas, double side) {
  _plate(canvas, side);
  _gridBoldSubject(canvas, side);
}

void _gridBoldSubject(Canvas canvas, double side) {
  final horizon = side * 0.24;
  final paint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = side * 0.022
    ..color = const Color(0x9947D9FF);

  for (var i = -2; i <= 2; i++) {
    canvas.drawLine(
      Offset(side * 0.5 + i * side * 0.05, horizon),
      Offset(side * 0.5 + i * side * 0.46, side),
      paint,
    );
  }

  paint
    ..color = const Color(0xCC8CF2FF)
    ..strokeWidth = side * 0.030;
  canvas.drawLine(Offset(0.0, horizon), Offset(side, horizon), paint);
  _glow(canvas, Offset(side * 0.5, horizon), side * 0.46,
      const Color(0x5547C8FF));

  _craft(canvas, Offset(side * 0.5, side * 0.52), side * _safe * 0.30);
}

void _paintGridFloor(Canvas canvas, double side) {
  _plate(canvas, side);

  final horizon = side * 0.56;
  final paint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = side * 0.020
    ..color = const Color(0x8F47D9FF);

  for (var i = -2; i <= 2; i++) {
    canvas.drawLine(
      Offset(side * 0.5 + i * side * 0.04, horizon),
      Offset(side * 0.5 + i * side * 0.40, side * 0.98),
      paint,
    );
  }
  for (var i = 1; i <= 2; i++) {
    final t = i / 2.0;
    final y = horizon + (side * 0.98 - horizon) * t * t;
    final spread = side * (0.10 + 0.34 * t * t);
    canvas.drawLine(
      Offset(side * 0.5 - spread * 2.0, y),
      Offset(side * 0.5 + spread * 2.0, y),
      paint,
    );
  }

  _glow(canvas, Offset(side * 0.5, horizon), side * 0.46,
      const Color(0x4447C8FF));

  _craft(canvas, Offset(side * 0.5, side * 0.40), side * _safe * 0.32);
}
