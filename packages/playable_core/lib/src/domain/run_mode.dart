library;

enum RunMode {
  fixed(
    title: 'FIXED',
    detail: 'The same run every time. Learn it, then beat it.',
    shardScale: 1.0,
  ),

  shifting(
    title: 'SHIFTING',
    detail: 'A new layout every attempt. Pays more, forgives nothing.',
    shardScale: 1.5,
  );

  const RunMode({
    required this.title,
    required this.detail,
    required this.shardScale,
  });

  final String title;

  final String detail;

  final double shardScale;

  bool get isRandomised => this == RunMode.shifting;
}
