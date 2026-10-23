import 'dart:async';
import 'dart:io';

import 'package:playable_kit/storage.dart';
import 'package:test/test.dart';

void main() {
  group('AtomicJsonStore', () {
    late Directory directory;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('playable_kit_store');
    });

    tearDown(() {
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });

    test('a document that was never written reads as null', () async {
      final store = AtomicJsonStore.at(directory);

      expect(await store.read('progress.json'), isNull);
    });

    test('what was written is what is read back', () async {
      final store = AtomicJsonStore.at(directory);

      await store.write('progress.json', '{"shards":77}');
      await store.flush();

      expect(
        await AtomicJsonStore.at(directory).read('progress.json'),
        '{"shards":77}',
      );
    });

    test('two documents do not share a file', () async {
      final store = AtomicJsonStore.at(directory);

      await store.write('progress.json', 'A');
      await store.write('settings.json', 'B');
      await store.flush();

      expect(await store.read('progress.json'), 'A');
      expect(await store.read('settings.json'), 'B');
    });

    test('overlapping writes do not interleave', () async {
      final store = AtomicJsonStore.at(directory);

      for (var i = 1; i <= 5; i++) {
        unawaited(store.write('progress.json', 'payload-$i'));
      }
      await store.flush();

      expect(
        await store.read('progress.json'),
        'payload-5',
        reason: 'the last write wins, whole',
      );
    });

    test('overlapping writes to different documents also serialise', () async {
      final store = AtomicJsonStore.at(directory);

      unawaited(store.write('a.json', 'first'));
      unawaited(store.write('b.json', 'second'));
      unawaited(store.write('a.json', 'third'));
      await store.flush();

      expect(await store.read('a.json'), 'third');
      expect(await store.read('b.json'), 'second');
    });

    test('no scratch file is left behind', () async {
      final store = AtomicJsonStore.at(directory);

      await store.write('progress.json', 'payload');
      await store.flush();

      final left = directory
          .listSync()
          .map((entity) => entity.path.split(Platform.pathSeparator).last)
          .toList();
      expect(left, <String>['progress.json']);
    });

    test('a replaced document is never half-written', () async {
      final store = AtomicJsonStore.at(directory);
      final long = 'x' * 200000;

      await store.write('progress.json', long);
      await store.flush();

      unawaited(store.write('progress.json', 'short'));
      final seen = await AtomicJsonStore.at(directory).read('progress.json');
      await store.flush();

      expect(seen, anyOf(long, 'short'));
    });

    test('a directory that does not exist yet is created', () async {
      final nested = Directory(
        '${directory.path}${Platform.pathSeparator}deeper',
      );
      final store = AtomicJsonStore.at(nested);

      await store.write('progress.json', 'payload');
      await store.flush();

      expect(await store.read('progress.json'), 'payload');
    });

    test('a store with nowhere to write neither throws nor pretends',
        () async {
      final reported = <String>[];
      final store = AtomicJsonStore(
        resolveDirectory: () async => null,
        onError: reported.add,
      );

      await store.write('progress.json', 'payload');
      await store.flush();

      expect(await store.read('progress.json'), isNull);
      expect(reported, isEmpty, reason: 'declining is not an error');
    });

    test('a resolver that throws is reported, once, and then swallowed',
        () async {
      final reported = <String>[];
      var calls = 0;
      final store = AtomicJsonStore(
        resolveDirectory: () async {
          calls++;
          throw const FileSystemException('no support directory');
        },
        onError: reported.add,
      );

      await store.write('progress.json', 'payload');
      await store.flush();
      expect(await store.read('progress.json'), isNull);

      expect(calls, 1, reason: 'the platform call is a round trip; cache it');
      expect(reported, hasLength(1));
      expect(reported.single, contains('nothing will persist'));
    });

    test('a write that cannot land is reported rather than thrown', () async {
      final reported = <String>[];
      final blocked = File(
        '${directory.path}${Platform.pathSeparator}blocked',
      )..writeAsStringSync('not a directory');
      final store = AtomicJsonStore.at(
        Directory(blocked.path),
        onError: reported.add,
      );

      await store.write('progress.json', 'payload');
      await store.flush();

      expect(reported, isNotEmpty);
      expect(reported.first, contains('could not save progress.json'));
    });

    test('a document that is not a file reads as null, quietly', () async {
      final reported = <String>[];
      final store = AtomicJsonStore.at(directory, onError: reported.add);

      Directory('${directory.path}${Platform.pathSeparator}progress.json')
          .createSync();

      expect(await store.read('progress.json'), isNull);
      expect(reported, isEmpty);
    });

    test('errors are swallowed entirely when nobody is listening', () async {
      final store = AtomicJsonStore(resolveDirectory: () async {
        throw const FileSystemException('nowhere');
      });

      await store.write('progress.json', 'payload');
      await store.flush();

      expect(await store.read('progress.json'), isNull);
    });
  });
}
