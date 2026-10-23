library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neon_dash/src/render/craft_shape.dart';
import 'package:neon_dash/src/render/palette.dart';
import 'package:playable_core/playable_core.dart';

void main() {
  test('every hull draws, and the contact sheet is written', () async {
    const columns = 4;
    const cell = Size(220.0, 190.0);
    final rows = (CraftSkin.values.length / columns).ceil();
    final sheet = Size(cell.width * columns, cell.height * rows);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Offset.zero & sheet);

    canvas.drawRect(
      Offset.zero & sheet,
      Paint()..color = Palette.skyFar,
    );

    for (var i = 0; i < CraftSkin.values.length; i++) {
      final skin = CraftSkin.values[i];
      final origin = Offset(
        (i % columns) * cell.width,
        (i ~/ columns) * cell.height,
      );
      _paintCell(canvas, origin & cell, skin);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      sheet.width.round(),
      sheet.height.round(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();
    image.dispose();

    expect(bytes, isNotNull);
    expect(bytes!.lengthInBytes, greaterThan(1000));

    final out = Directory('build')..createSync(recursive: true);
    File('${out.path}/hull_sheet.png').writeAsBytesSync(
      bytes.buffer.asUint8List(),
    );
  });
}

void _paintCell(Canvas canvas, Rect cell, CraftSkin skin) {
  final hue = skin.hueOverride ?? Palette.craftHue;
  final ink = NeonInk.fromHue(hue);
  final paint = Paint()..isAntiAlias = true;

  final centre = cell.center.translate(0.0, -12.0);
  final radius = cell.shortestSide * 0.24;

  canvas
    ..save()
    ..translate(centre.dx, centre.dy);

  final plume = radius * 1.4;
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

  final hull = buildHullPath(skin, 0.35);
  for (final (scale, color) in <(double, Color)>[
    (1.75, ink.halo),
    (1.0, ink.body),
    (0.6, ink.edge),
  ]) {
    canvas
      ..save()
      ..scale(radius * scale, radius * scale);
    paint.color = color;
    canvas
      ..drawPath(hull, paint)
      ..restore();
  }

  canvas.restore();

}
