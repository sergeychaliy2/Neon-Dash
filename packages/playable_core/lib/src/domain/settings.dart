import 'dart:convert';

class Settings {
  Settings({
    double musicVolume = _defaultMusic,
    double effectsVolume = _defaultEffects,
    this.vibration = true,
  })  : _musicVolume = _clamp(musicVolume, _defaultMusic),
        _effectsVolume = _clamp(effectsVolume, _defaultEffects);

  factory Settings.fromJson(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map<String, dynamic>) return Settings();

      return Settings(
        musicVolume: _readDouble(decoded['music'], _defaultMusic),
        effectsVolume: _readDouble(decoded['effects'], _defaultEffects),
        vibration: decoded['vibration'] is bool
            ? decoded['vibration'] as bool
            : true,
      );
    } on Object {
      return Settings();
    }
  }

  static const double _defaultMusic = 0.8;
  static const double _defaultEffects = 0.9;

  double _musicVolume;
  double _effectsVolume;

  bool vibration;

  double get musicVolume => _musicVolume;
  set musicVolume(double value) =>
      _musicVolume = _clamp(value, _defaultMusic);

  double get effectsVolume => _effectsVolume;
  set effectsVolume(double value) =>
      _effectsVolume = _clamp(value, _defaultEffects);

  bool get isSilent => _musicVolume <= 0.0 && _effectsVolume <= 0.0;

  String toJson() => jsonEncode(<String, dynamic>{
        'music': _musicVolume,
        'effects': _effectsVolume,
        'vibration': vibration,
      });

  static double _clamp(double value, double fallback) {
    if (!value.isFinite) return fallback;
    if (value < 0.0) return 0.0;
    return value > 1.0 ? 1.0 : value;
  }

  static double _readDouble(Object? raw, double fallback) {
    if (raw is num) return _clamp(raw.toDouble(), fallback);
    return fallback;
  }
}
