library;

class MusicVoice {
  const MusicVoice({
    required this.beatsPerMinute,
    required this.rootSemitone,
    required this.progression,
    required this.minorChords,
    required this.leadOctave,
    required this.groove,
    required this.style,
  });

  final int beatsPerMinute;

  final double rootSemitone;

  final List<int> progression;

  final List<bool> minorChords;

  final double leadOctave;

  final MusicStyle style;

  final MusicGroove groove;

  double get beatSeconds => 60.0 / beatsPerMinute;
}

enum BassFigure {
  drive(<int>[0, -1, -1, 0, -1, -1, 12, -1, 0, -1, -1, 7, -1, 0, -1, 12]),

  pump(<int>[0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1]),

  sparse(<int>[0, -1, -1, -1, -1, -1, -1, -1, 7, -1, -1, -1, -1, -1, -1, -1]),

  walk(<int>[0, -1, 3, -1, 5, -1, 7, -1, 12, -1, 7, -1, 5, -1, 3, -1]),

  stab(<int>[-1, -1, 0, -1, -1, 0, -1, -1, 0, -1, -1, -1, 0, -1, 0, -1]),

  rumble(<int>[0, 0, -1, -1, 0, -1, 0, -1, -1, 0, -1, -1, 0, -1, -1, 7]);

  const BassFigure(this.steps);

  final List<int> steps;
}

enum ArpShape {
  climb,

  fall,

  pendulum,

  octaves,

  stab,

  walk,
}

enum LeadPhrasing {
  flowing(<String>['x..x..x.', 'x.x...x.', 'x..x.x..', 'x.....x.']),
  urgent(<String>['x.xx..x.', 'x.x.x.x.', 'xx..x.x.', 'x.x...x.']),
  spare(<String>['x.......', 'x...x...', '....x...', 'x.......']),
  syncopated(<String>['..x..x..', '.x..x..x', '..x.x...', '.x.....x']),
  broken(<String>['x..x.x.x', '..x.x..x', 'x.x..x..', '..x...x.']);

  const LeadPhrasing(this.bars);

  final List<String> bars;
}

enum LeadVoice {
  sustained,

  bell,

  pluck,
}

enum MusicStyle {
  pulse(
    bass: BassFigure.drive,
    arp: ArpShape.climb,
    phrasing: LeadPhrasing.flowing,
    voice: LeadVoice.sustained,
    barsPerChord: 2,
  ),
  glide(
    bass: BassFigure.sparse,
    arp: ArpShape.pendulum,
    phrasing: LeadPhrasing.spare,
    voice: LeadVoice.bell,
    barsPerChord: 4,
  ),
  chop(
    bass: BassFigure.stab,
    arp: ArpShape.stab,
    phrasing: LeadPhrasing.syncopated,
    voice: LeadVoice.pluck,
    barsPerChord: 1,
  ),
  surge(
    bass: BassFigure.pump,
    arp: ArpShape.octaves,
    phrasing: LeadPhrasing.urgent,
    voice: LeadVoice.sustained,
    barsPerChord: 2,
  ),
  drift(
    bass: BassFigure.walk,
    arp: ArpShape.fall,
    phrasing: LeadPhrasing.flowing,
    voice: LeadVoice.bell,
    barsPerChord: 4,
  ),
  fracture(
    bass: BassFigure.rumble,
    arp: ArpShape.walk,
    phrasing: LeadPhrasing.broken,
    voice: LeadVoice.pluck,
    barsPerChord: 1,
  );

  const MusicStyle({
    required this.bass,
    required this.arp,
    required this.phrasing,
    required this.voice,
    required this.barsPerChord,
  });

  final BassFigure bass;
  final ArpShape arp;
  final LeadPhrasing phrasing;
  final LeadVoice voice;

  final int barsPerChord;
}

enum MusicGroove {
  pulse(
    kick: 'x...x...x...x..x',
    clap: '....x.......x...',
    hat: 'x.xox.x.x.xox.xo',
    swing: 0.0,
  ),

  drive(
    kick: 'x..x..x.x..x..x.',
    clap: '....x.......x..x',
    hat: 'x.x.x.x.x.x.x.x.',
    swing: 0.0,
  ),

  halftime(
    kick: 'x.......x.......',
    clap: '........x.......',
    hat: 'x...o...x...o...',
    swing: 0.10,
  ),

  breaks(
    kick: 'x..x....x.x.....',
    clap: '....x......x.x..',
    hat: 'xoxox.oxx.x.oxx.',
    swing: 0.18,
  ),

  stomp(
    kick: 'x...x..x..x.x...',
    clap: '..x.....x...x..x',
    hat: 'x..ox..ox..ox..o',
    swing: 0.12,
  );

  const MusicGroove({
    required this.kick,
    required this.clap,
    required this.hat,
    required this.swing,
  });

  final String kick;
  final String clap;
  final String hat;

  final double swing;
}
