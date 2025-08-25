import 'models.dart';

/// Build full schedule from base blinds, inserting breaks by ACCRUED level minutes (breaks don't count).
List<Level> buildSchedule({
  required List<Map<String, int>> baseLevels, // e.g., [{'sb':25,'bb':50}, ...]
  required int levelLenMin,
  required int breakEveryMin,
  required int breakDurMin,
}) {
  final out = <Level>[];
  var acc = 0;
  for (final l in baseLevels) {
    out.add(Level.play(sb: l['sb']!, bb: l['bb']!, lengthMin: levelLenMin));
    acc += levelLenMin;
    if (acc >= breakEveryMin) {
      out.add(Level.brk(lengthMin: breakDurMin));
      acc = 0;
    }
  }
  return out;
}

/// A sample blind list to get us going.
final sampleBaseLevels = <Map<String,int>>[
  {'sb':25,'bb':50},
  {'sb':50,'bb':100},
  {'sb':100,'bb':200},
  {'sb':200,'bb':400},
  {'sb':300,'bb':600},
  {'sb':400,'bb':800},
  {'sb':500,'bb':1000},
  {'sb':600,'bb':1200},
  {'sb':800,'bb':1600},
  {'sb':1000,'bb':2000},
];