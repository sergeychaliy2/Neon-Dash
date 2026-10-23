class DeterministicRandom {
  DeterministicRandom(int seed)
      : _state = _initialStateFor(seed),
        _weyl = _initialWeylFor(seed);

  static const int _mask = 0xFFFFFFFF;
  static const int _goldenRatioSeed = 0x9E3779B9;
  static const double _uint32Scale = 1.0 / 4294967296.0;

  static const int _weylStep = 0x9E3779B9;

  static const int _seedWarmupRounds = 16;

  int _state;

  int _weyl;

  ({int state, int weyl}) get position => (state: _state, weyl: _weyl);

  void restore(({int state, int weyl}) value) {
    final raw = value.state & _mask;
    _state = raw == 0 ? _goldenRatioSeed : raw;
    _weyl = value.weyl & _mask;
  }

  void reseed(int seed) {
    _state = _initialStateFor(seed);
    _weyl = _initialWeylFor(seed);
  }

  int nextUint32() {
    _state = _advance(_state);
    _weyl = (_weyl + _weylStep) & _mask;
    return (_state + _weyl) & _mask;
  }

  double nextDouble() => nextUint32() * _uint32Scale;

  double nextRange(double min, double max) {
    if (max <= min) return min;
    return min + nextDouble() * (max - min);
  }

  bool chance(double probability) => nextDouble() < probability;

  int nextInt(int bound) {
    if (bound <= 0) return 0;
    return nextUint32() % bound;
  }

  static int _advance(int state) {
    var x = state;
    x ^= (x << 13) & _mask;
    x ^= x >>> 17;
    x ^= (x << 5) & _mask;
    return x & _mask;
  }

  static int _initialStateFor(int seed) {
    var state = (seed & _mask) == 0 ? _goldenRatioSeed : seed & _mask;
    for (var round = 0; round < _seedWarmupRounds; round++) {
      state = _advance(state);
    }
    return state;
  }

  static int _initialWeylFor(int seed) {
    final raw = seed & _mask;
    return (raw ^ (raw << 11) ^ (raw >>> 7) ^ _goldenRatioSeed) & _mask;
  }
}
