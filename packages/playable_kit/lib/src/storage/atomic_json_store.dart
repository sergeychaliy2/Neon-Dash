import 'dart:async';
import 'dart:io';

class AtomicJsonStore {
  AtomicJsonStore({required this.resolveDirectory, this.onError});

  AtomicJsonStore.at(Directory directory, {this.onError})
      : resolveDirectory = (() async => directory);

  final Future<Directory?> Function() resolveDirectory;

  final void Function(String message)? onError;

  Directory? _directory;
  bool _resolved = false;

  Future<void> _inFlight = Future<void>.value();

  Future<Directory?> _directoryOrNull() async {
    if (_resolved) return _directory;

    try {
      _directory = await resolveDirectory();
    } on Object catch (error) {
      _report('no writable directory, nothing will persist: $error');
      _directory = null;
    }
    _resolved = true;
    return _directory;
  }

  Future<String?> read(String name) async {
    final directory = await _directoryOrNull();
    if (directory == null) return null;

    try {
      final file = File(_pathOf(directory, name));
      if (!file.existsSync()) return null;
      return await file.readAsString();
    } on Object catch (error) {
      _report('could not read $name: $error');
      return null;
    }
  }

  Future<void> write(String name, String payload) =>
      _inFlight = _inFlight.then((_) => _write(name, payload));

  Future<void> _write(String name, String payload) async {
    final directory = await _directoryOrNull();
    if (directory == null) return;

    try {
      if (!directory.existsSync()) {
        await directory.create(recursive: true);
      }

      final target = File(_pathOf(directory, name));
      final scratch = File(_pathOf(directory, '$name.tmp'));

      await scratch.writeAsString(payload, flush: true);
      await scratch.rename(target.path);
    } on Object catch (error) {
      _report('could not save $name: $error');
    }
  }

  Future<void> flush() => _inFlight;

  static String _pathOf(Directory directory, String name) =>
      '${directory.path}${Platform.pathSeparator}$name';

  void _report(String message) => onError?.call(message);
}
