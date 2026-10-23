import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:playable_core/playable_core.dart';
import 'package:playable_kit/storage.dart';

class ProfileStore {
  ProfileStore({@visibleForTesting Directory? directory})
      : _documents = AtomicJsonStore(
          resolveDirectory: directory == null
              ? getApplicationSupportDirectory
              : (() async => directory),
          onError: (message) => debugPrint('neon_dash: $message'),
        );

  static const String _fileName = 'progress.json';
  static const String _settingsFileName = 'settings.json';

  final AtomicJsonStore _documents;

  Future<Progression> load() async {
    final saved = await _documents.read(_fileName);
    return saved == null ? Progression() : Progression.fromJson(saved);
  }

  Future<Settings> loadSettings() async {
    final saved = await _documents.read(_settingsFileName);
    return saved == null ? Settings() : Settings.fromJson(saved);
  }

  Future<void> save(Progression progression) =>
      _documents.write(_fileName, progression.toJson());

  Future<void> saveSettings(Settings settings) =>
      _documents.write(_settingsFileName, settings.toJson());

  Future<void> flush() => _documents.flush();
}
