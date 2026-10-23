library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const Map<String, (double, double, double)> _crops = <String, (double, double, double)>{
  'art-craft': (238.0, 886.0, 375.0),
  'art-reach': (199.0, 806.0, 450.0),
};

void main() {
  late ui.Image source;

  setUpAll(() async {
    final bytes = File('art/store_card.webp').readAsBytesSync();
    final codec = await ui.instantiateImageCodec(bytes);
    source = (await codec.getNextFrame()).image;
  });

  tearDownAll(() => source.dispose());

  test('the crops are written', () async {
    final out = Directory('build/icons/art')..createSync(recursive: true);

    for (final entry in _crops.entries) {
      final bytes = await _render(
        512.0,
        (canvas) => _drawCrop(canvas, source, entry.value, 512.0),
      );
      expect(bytes.lengthInBytes, greaterThan(5000), reason: entry.key);
      File('${out.path}/${entry.key}.png')
          .writeAsBytesSync(bytes.buffer.asUint8List());
    }
  });

  test('the launcher set is written from the chosen crop', () async {
    final chosen = _crops['art-craft']!;

    const densities = <(String, int, int)>[
      ('mdpi', 48, 108),
      ('hdpi', 72, 162),
      ('xhdpi', 96, 216),
      ('xxhdpi', 144, 324),
      ('xxxhdpi', 192, 432),
    ];

    final root = Directory('build/icons/art/launcher')
      ..createSync(recursive: true);

    for (final (density, plain, adaptive) in densities) {
      final folder = Directory('${root.path}/mipmap-$density')
        ..createSync(recursive: true);

      final icon = await _render(
        plain.toDouble(),
        (canvas) => _drawCrop(canvas, source, chosen, plain.toDouble()),
      );
      File('${folder.path}/ic_launcher.png')
          .writeAsBytesSync(icon.buffer.asUint8List());

      final foreground = await _render(
        adaptive.toDouble(),
        (canvas) {
          final inset = adaptive * 0.1667;
          canvas
            ..save()
            ..translate(inset, inset);
          _drawCrop(canvas, source, chosen, adaptive * 0.6667);
          canvas.restore();
        },
      );
      File('${folder.path}/ic_launcher_foreground.png')
          .writeAsBytesSync(foreground.buffer.asUint8List());
    }

    final win = Directory('${root.path}/win')..createSync(recursive: true);
    for (final size in <int>[16, 32, 48, 64, 128, 256]) {
      final bytes = await _render(
        size.toDouble(),
        (canvas) => _drawCrop(canvas, source, chosen, size.toDouble()),
      );
      File('${win.path}/$size.png').writeAsBytesSync(bytes.buffer.asUint8List());
    }

    expect(
      Directory('${root.path}/mipmap-xxxhdpi').listSync().length,
      2,
      reason: 'each density needs the plain icon and the adaptive foreground',
    );
  });

  test('the small-size strip is written', () async {
    const small = 64.0;
    const blow = 5.0;

    final shrunk = <ui.Image>[];
    for (final crop in _crops.values) {
      final recorder = ui.PictureRecorder();
      _drawCrop(
        Canvas(recorder, const Rect.fromLTWH(0.0, 0.0, small, small)),
        source,
        crop,
        small,
      );
      final picture = recorder.endRecording();
      shrunk.add(await picture.toImage(small.round(), small.round()));
      picture.dispose();
    }

    final bytes = await _render(
      small * blow * shrunk.length,
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

    File('build/icons/art/small.png')
        .writeAsBytesSync(bytes.buffer.asUint8List());
  });
}

void _drawCrop(
  Canvas canvas,
  ui.Image source,
  (double, double, double) crop,
  double side,
) {
  final (left, top, size) = crop;

  canvas.drawImageRect(
    source,
    Rect.fromLTWH(left, top, size, size),
    Rect.fromLTWH(0.0, 0.0, side, side),
    Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high,
  );
}

Future<ByteData> _render(
  double width,
  void Function(Canvas canvas) paint, {
  double? height,
}) async {
  final size = Size(width, height ?? width);
  final recorder = ui.PictureRecorder();

  paint(Canvas(recorder, Offset.zero & size));

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
