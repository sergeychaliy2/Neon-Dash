import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('core imports neither package:flutter nor dart:ui', () {
    final forbiddenImport = RegExp('''import\\s+['"](package:flutter/|dart:ui)''');

    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (forbiddenImport.hasMatch(entity.readAsStringSync())) {
        offenders.add(entity.path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'playable_core must stay pure Dart so it runs in plain unit '
          'tests and in a dart2js web build. Move the offending code into '
          'apps/<game>/lib instead.',
    );
  });

  test('no library under lib/src is orphaned', () {
    final libraries = <File>[
      for (final entity in Directory('lib').listSync(recursive: true))
        if (entity is File && entity.path.endsWith('.dart')) entity,
    ];

    final sourceByPath = {
      for (final library in libraries)
        library.path.replaceAll(r'\', '/'): library.readAsStringSync(),
    };

    final orphans = <String>[];
    for (final path in sourceByPath.keys) {
      if (!path.contains('/src/')) continue;

      final fileName = path.split('/').last;
      final referenced = sourceByPath.entries.any(
        (entry) => entry.key != path && entry.value.contains(fileName),
      );
      if (!referenced) orphans.add(path);
    }

    expect(
      orphans,
      isEmpty,
      reason: 'These libraries are imported by nothing and exported by '
          'nothing. Either wire them up or delete them.',
    );
  });
}
