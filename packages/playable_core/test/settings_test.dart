import 'package:playable_core/playable_core.dart';
import 'package:test/test.dart';

void main() {
  group('Defaults', () {
    test('a fresh profile has sound on and the music under the effects', () {
      final settings = Settings();

      expect(settings.musicVolume, greaterThan(0.0));
      expect(settings.effectsVolume, greaterThan(0.0));
      expect(settings.effectsVolume, greaterThan(settings.musicVolume));
      expect(settings.vibration, isTrue);
      expect(settings.isSilent, isFalse);
    });

    test('silence is reported only when both are down', () {
      final settings = Settings()..musicVolume = 0.0;
      expect(settings.isSilent, isFalse);

      settings.effectsVolume = 0.0;
      expect(settings.isSilent, isTrue);
    });
  });

  group('Clamping', () {
    test('a volume cannot leave the range', () {
      final settings = Settings()
        ..musicVolume = 4.0
        ..effectsVolume = -2.0;

      expect(settings.musicVolume, 1.0);
      expect(settings.effectsVolume, 0.0);
    });

    test('a volume that is not a number falls back rather than spreading', () {
      final settings = Settings()..musicVolume = double.nan;

      expect(settings.musicVolume.isFinite, isTrue);
      expect(settings.musicVolume, greaterThan(0.0));

      settings.effectsVolume = double.infinity;
      expect(settings.effectsVolume.isFinite, isTrue);
    });

    test('the constructor clamps too, not only the setters', () {
      final settings = Settings(musicVolume: 9.0, effectsVolume: -1.0);

      expect(settings.musicVolume, 1.0);
      expect(settings.effectsVolume, 0.0);
    });
  });

  group('Saving', () {
    test('everything survives a round trip', () {
      final settings = Settings(
        musicVolume: 0.35,
        effectsVolume: 0.65,
        vibration: false,
      );

      final restored = Settings.fromJson(settings.toJson());

      expect(restored.musicVolume, closeTo(0.35, 1e-9));
      expect(restored.effectsVolume, closeTo(0.65, 1e-9));
      expect(restored.vibration, isFalse);
    });

    test('an empty or broken file gives the defaults', () {
      for (final source in <String>['', '{', 'null', '[]', '{"music":"loud"}']) {
        final restored = Settings.fromJson(source);

        expect(restored.musicVolume, Settings().musicVolume, reason: source);
        expect(restored.vibration, isTrue, reason: source);
      }
    });

    test('a forged file cannot push a volume out of range', () {
      final restored = Settings.fromJson('{"music":40,"effects":-5}');

      expect(restored.musicVolume, 1.0);
      expect(restored.effectsVolume, 0.0);
    });

    test('a missing field keeps its default rather than zeroing', () {
      final restored = Settings.fromJson('{"vibration":false}');

      expect(restored.musicVolume, Settings().musicVolume);
      expect(restored.effectsVolume, Settings().effectsVolume);
      expect(restored.vibration, isFalse);
    });

    test('settings and progress are separate things', () {
      final settings = Settings.fromJson(Progression(shards: 40).toJson());

      expect(settings.musicVolume, Settings().musicVolume,
          reason: 'a profile is not a settings file and reads as defaults');
    });
  });
}
