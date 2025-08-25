class Level {
  final bool isBreak;
  final int lengthMin;
  final int? sb, bb, ante; // ante = bb (BBA) for play levels

  const Level._({required this.isBreak, required this.lengthMin, this.sb, this.bb, this.ante});

  factory Level.play({required int sb, required int bb, required int lengthMin}) =>
      Level._(isBreak: false, lengthMin: lengthMin, sb: sb, bb: bb, ante: bb);

  factory Level.brk({required int lengthMin}) =>
      Level._(isBreak: true, lengthMin: lengthMin);
}