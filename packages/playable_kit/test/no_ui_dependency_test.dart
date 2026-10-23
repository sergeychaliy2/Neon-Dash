import 'dart:io';

import 'package:test/test.dart';

final RegExp _relativeDirective =
    RegExp(r"""(?:import|export)\s+'([^':]+)'""");

void main() {
  test('the kit imports neither package:flutter nor dart:ui', () {
    final forbiddenImport =
        RegExp('''import\\s+['"](package:flutter/|dart:ui)''');

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
      reason: 'playable_kit must stay pure Dart so it runs in plain unit '
          'tests and in a dart2js web build. Move the offending code into '
          'apps/<game>/lib instead.',
    );
  });

  test('the main barrel stays free of dart:io', () {
    final reachable = <String>{};
    final pending = <String>['lib/playable_kit.dart'];

    while (pending.isNotEmpty) {
      final path = pending.removeLast();
      if (!reachable.add(path)) continue;

      final source = File(path).readAsStringSync();
      expect(
        source.contains("import 'dart:io'"),
        isFalse,
        reason: '$path is reachable from the main barrel and imports '
            "dart:io. Move it behind 'package:playable_kit/storage.dart'.",
      );

      for (final match in _relativeDirective.allMatches(source)) {
        pending.add(_resolve(path, match.group(1)!));
      }
    }

    expect(reachable.length, greaterThan(8));
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

/// Resolves a relative directive target against the file that wrote it.
String _resolve(String from, String relative) {
  final parts = from.split('/')..removeLast();
  for (final step in relative.split('/')) {
    if (step == '..') {
      parts.removeLast();
    } else if (step != '.') {
      parts.add(step);
    }
  }
  return parts.join('/');
}
