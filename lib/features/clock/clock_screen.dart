import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/engine/clock.dart';
import '../../core/engine/models.dart';
import '../../core/engine/schedule.dart';

/// ----- simple payout model -----
class Payout {
  final int place;
  final double pct;
  final int amount;
  const Payout(this.place, this.pct, this.amount);
}

/// ----- State -----
class ClockState {
  final int secondsLeft;
  final bool running;

  // structure
  final int levelIndex;
  final List<Level> schedule;

  // accounting / config
  final int entries;
  final int reentries;
  final int rebuys;
  final int addons;
  final int playersRemaining;
  final int startingStack; // chips
  final int buyin;         // currency units
  final String currency;

  // NEW — runtime‑configurable structure knobs
  final int levelLenMin;   // minutes per level
  final int lateRegLevel;  // close after this level (1‑based for UI, internal uses index+1)

  const ClockState({
    required this.secondsLeft,
    required this.running,
    required this.levelIndex,
    required this.schedule,
    required this.entries,
    required this.reentries,
    required this.rebuys,
    required this.addons,
    required this.playersRemaining,
    required this.startingStack,
    required this.buyin,
    required this.currency,
    required this.levelLenMin,
    required this.lateRegLevel,
  });

  ClockState copy({
    int? secondsLeft,
    bool? running,
    int? levelIndex,
    List<Level>? schedule,
    int? entries,
    int? reentries,
    int? rebuys,
    int? addons,
    int? playersRemaining,
    int? startingStack,
    int? buyin,
    String? currency,
    int? levelLenMin,
    int? lateRegLevel,
  }) =>
      ClockState(
        secondsLeft: secondsLeft ?? this.secondsLeft,
        running: running ?? this.running,
        levelIndex: levelIndex ?? this.levelIndex,
        schedule: schedule ?? this.schedule,
        entries: entries ?? this.entries,
        reentries: reentries ?? this.reentries,
        rebuys: rebuys ?? this.rebuys,
        addons: addons ?? this.addons,
        playersRemaining: playersRemaining ?? this.playersRemaining,
        startingStack: startingStack ?? this.startingStack,
        buyin: buyin ?? this.buyin,
        currency: currency ?? this.currency,
        levelLenMin: levelLenMin ?? this.levelLenMin,
        lateRegLevel: lateRegLevel ?? this.lateRegLevel,
      );
}

/// ----- Controller -----
final clockProvider =
    StateNotifierProvider<ClockController, ClockState>((ref) {
  final controller = ClockController(ref);
  ref.onDispose(controller.dispose);
  return controller;
});

class ClockController extends StateNotifier<ClockState> {
  final Ref ref;
  late ClockEngine _engine;
  Timer? _t;
  final _player = AudioPlayer();

static const int kDefaultLevelLenMin = 15;
static const int kDefaultBreakEveryMin = 135; // 2h15m (kept constant for now)
static const int kDefaultBreakDurMin = 10;
static const int kDefaultLateRegLevel = 8;
static const int kDefaultStartStack = 20000;
static const int kDefaultBuyin = 100;
static const String kDefaultCurrency = 'CAD';

ClockController(this.ref)
    : super(ClockState(
        secondsLeft: kDefaultLevelLenMin * 60,
        running: false,
        levelIndex: 0,
        schedule: const [],
        entries: 0,
        reentries: 0,
        rebuys: 0,
        addons: 0,
        playersRemaining: 0,
        startingStack: kDefaultStartStack,
        buyin: kDefaultBuyin,
        currency: kDefaultCurrency,
        levelLenMin: kDefaultLevelLenMin,
        lateRegLevel: kDefaultLateRegLevel,
      )) {
  final sched = buildSchedule(
    baseLevels: sampleBaseLevels,
    levelLenMin: state.levelLenMin,
    breakEveryMin: kDefaultBreakEveryMin,
    breakDurMin: kDefaultBreakDurMin,
  );
  _engine = ClockEngine(secondsLeft: sched.first.lengthMin * 60);
  state = state.copy(
    secondsLeft: _engine.secondsLeft,
    schedule: sched,
    levelIndex: 0,
  );
}

  // ----- derived stats -----
  int get totalEntriesForPlaces => state.entries + state.reentries;
  int get totalBuyinsForPool =>
      state.entries + state.reentries + state.rebuys + state.addons;
  int get prizePool => totalBuyinsForPool * state.buyin;
  int get chipsInPlay =>
      state.startingStack *
      (state.entries + state.reentries + state.rebuys + state.addons);
  int get avgStack =>
      state.playersRemaining > 0 ? (chipsInPlay ~/ state.playersRemaining) : 0;

  bool get lateRegOpen => (state.levelIndex + 1) <= state.lateRegLevel;
  // ----- settings -----
  void applySettings({
    required int buyin,
    required String currency,
    required int startingStack,
    required int levelLenMin,
    required int lateRegLevel,
  }) {
    // Rebuild schedule with new structure settings
    final sched = buildSchedule(
      baseLevels: sampleBaseLevels,
      levelLenMin: levelLenMin,
      breakEveryMin: kDefaultBreakEveryMin,
      breakDurMin: kDefaultBreakDurMin,
    );
    // Reset to Level 1, paused, with new settings
    _engine.reset(sched.first.lengthMin * 60);
    state = state.copy(
      buyin: buyin,
      currency: currency,
      startingStack: startingStack,
      levelLenMin: levelLenMin,
      lateRegLevel: lateRegLevel,
      schedule: sched,
      levelIndex: 0,
      secondsLeft: sched.first.lengthMin * 60,
      running: false,
    );
  }

  String currentBlindsText() {
    final L = state.schedule[state.levelIndex];
    return L.isBreak ? 'BREAK' : '${L.sb} / ${L.bb} / ${L.ante}';
  }

  String nextBlindsText() {
    if (state.levelIndex + 1 >= state.schedule.length) return '—';
    final L = state.schedule[state.levelIndex + 1];
    return L.isBreak ? 'BREAK' : '${L.sb} / ${L.bb} / ${L.ante}';
  }

  // ----- payouts -----
  List<Payout> get payouts {
    final totalPlaces = (totalEntriesForPlaces * 0.10).ceil().clamp(1, 9999);
    final pool = prizePool;
    if (totalPlaces <= 0 || pool <= 0) return const [];

    const r = 1.25; // geometric ratio for top-heavy distribution
    final weights = List<double>.generate(
      totalPlaces,
      (i) => math.pow(r, i).toDouble(),
    ).reversed.toList();
    final sum = weights.fold<double>(0, (a, b) => a + b);

    final out = <Payout>[];
    var allocated = 0;
    for (var i = 0; i < totalPlaces; i++) {
      final pct = 100.0 * (weights[i] / sum);
      int amt;
      if (i == totalPlaces - 1) {
        amt = pool - allocated; // ensure exact sum
      } else {
        amt = ((pool * pct) / 100).round();
        allocated += amt;
      }
      out.add(Payout(i + 1, pct, amt));
    }
    return out;
  }

  // ----- timer controls -----
  Future<void> _ensureWakelock() async => WakelockPlus.enable();

  Future<void> start() async {
    if (state.running) return;
    await _ensureWakelock();
    _t?.cancel();
    _t = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    _engine.running = true;
    state = state.copy(running: true);
  }

  void pause() {
    _engine.running = false;
    _t?.cancel();
    state = state.copy(running: false);
  }

  void resetCurrent() {
    final L = state.schedule[state.levelIndex];
    _engine.reset(L.lengthMin * 60);
    _t?.cancel();
    state = state.copy(secondsLeft: _engine.secondsLeft, running: false);
  }

  void addMinute() {
    _engine.secondsLeft += 60;
    state = state.copy(secondsLeft: _engine.secondsLeft);
  }

  void subMinute() {
    _engine.secondsLeft = (_engine.secondsLeft - 60).clamp(0, 24 * 3600);
    state = state.copy(secondsLeft: _engine.secondsLeft);
  }

  Future<void> nextLevel() async {
    if (state.levelIndex + 1 >= state.schedule.length) return;
    pause();
    final idx = state.levelIndex + 1;
    final L = state.schedule[idx];
    _engine.reset(L.lengthMin * 60);
    state = state.copy(levelIndex: idx, secondsLeft: _engine.secondsLeft);
  }

  Future<void> prevLevel() async {
    if (state.levelIndex == 0) return;
    pause();
    final idx = state.levelIndex - 1;
    final L = state.schedule[idx];
    _engine.reset(L.lengthMin * 60);
    state = state.copy(levelIndex: idx, secondsLeft: _engine.secondsLeft);
  }

  Future<void> _beep() async {
    try {
      await _player.setAsset('assets/sounds/level_end.mp3'); // optional asset
      await _player.play();
    } catch (_) {}
  }

  Future<void> _onTick() async {
    final finished = _engine.tick();
    final s = _engine.secondsLeft;
    if (s == 60) await _beep(); // 1‑minute warning
    if (finished) {
      await _beep();
      if (state.levelIndex + 1 < state.schedule.length) {
        final idx = state.levelIndex + 1;
        final L = state.schedule[idx];
        _engine.reset(L.lengthMin * 60);
        state = state.copy(
          levelIndex: idx,
          secondsLeft: _engine.secondsLeft,
          running: true,
        );
      } else {
        pause();
      }
    } else {
      state = state.copy(secondsLeft: s, running: _engine.running);
    }
  }

  // ----- accounting -----
  void addEntry() {
    state = state.copy(
      entries: state.entries + 1,
      playersRemaining: state.playersRemaining + 1,
    );
  }

  void addReentry() {
    state = state.copy(
      reentries: state.reentries + 1,
      playersRemaining: state.playersRemaining + 1,
    );
  }

  void addRebuy() {
    state = state.copy(rebuys: state.rebuys + 1);
  }

  void addAddon() {
    state = state.copy(addons: state.addons + 1);
  }

  void bustPlayer() {
    if (state.playersRemaining > 0) {
      state = state.copy(playersRemaining: state.playersRemaining - 1);
    }
  }

  void playersPlus() {
    state = state.copy(playersRemaining: state.playersRemaining + 1);
  }

  void playersMinus() {
    if (state.playersRemaining > 0) {
      state = state.copy(playersRemaining: state.playersRemaining - 1);
    }
  }

  void dispose() {
    _t?.cancel();
    _player.dispose();
    super.dispose();
  }
}

/// ----- helpers -----
String fmt(int seconds) {
  final m = (seconds ~/ 60).toString().padLeft(2, '0');
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

String comma(int n) {
  final s = n.toString();
  final rgx = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
  return s.replaceAllMapped(rgx, (m) => '${m[1]},');
}

String money(int amount, String ccy) => '$ccy ${comma(amount)}';

/// ----- UI -----
class ClockScreen extends ConsumerWidget {
  const ClockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(clockProvider);
    final ctl = ref.read(clockProvider.notifier);

    final curIsBreak = st.schedule[st.levelIndex].isBreak;

    Widget stat(String label, String value) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        );

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E13),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16, 16, 16, 16 + MediaQuery.of(context).padding.bottom,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      children: [
                        const Text('Tourney Clock (MVP)',
                            style: TextStyle(color: Color(0xFFB7C6FF), fontSize: 16)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: st.running ? const Color(0xFF082A1B) : const Color(0xFF27151A),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            st.running ? 'RUNNING' : 'PAUSED',
                            style: TextStyle(
                              color: st.running ? Colors.greenAccent : Colors.redAccent,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.settings, color: Colors.white70),
                          tooltip: 'Settings',
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                              ),
                              builder: (ctx) => Padding(
                                padding: EdgeInsets.only(
                                  bottom: MediaQuery.of(context).viewInsets.bottom,
                                ),
                                child: _SettingsSheet(
                                  buyin: st.buyin,
                                  currency: st.currency,
                                  startingStack: st.startingStack,
                                  levelLenMin: st.levelLenMin,
                                  lateRegLevel: st.lateRegLevel,
                                  onSave: (buyin, currency, startingStack, levelLenMin, lateRegLevel) {
                                    ctl.applySettings(
                                      buyin: buyin,
                                      currency: currency,
                                      startingStack: startingStack,
                                      levelLenMin: levelLenMin,
                                      lateRegLevel: lateRegLevel,
                                    );
                                    Navigator.of(ctx).pop();
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Level & blinds
                    Row(
                      children: [
                        Text(
                          curIsBreak ? 'Break' : 'Level ${st.levelIndex + 1}',
                          style: const TextStyle(fontSize: 20, color: Color(0xFFD0DCFF)),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          ctl.currentBlindsText(),
                          style: const TextStyle(fontSize: 16, color: Colors.white70),
                        ),
                        const Spacer(),
                        Text(
                          ctl.lateRegOpen ? 'Late Reg: OPEN' : 'Late Reg: CLOSED',
                          style: const TextStyle(fontSize: 12, color: Colors.white54),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Timer
                    Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          fmt(st.secondsLeft),
                          style: const TextStyle(
                            fontSize: 96,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text('Next: ${ctl.nextBlindsText()}',
                          style: const TextStyle(color: Colors.white54)),
                    ),

                    const SizedBox(height: 24),

                    // Stats row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        stat('Entries', '${st.entries + st.reentries}'),
                        stat('Players', '${st.playersRemaining}'),
                        stat('Prize Pool', money(ctl.prizePool, st.currency)),
                        stat('Avg Stack', comma(ctl.avgStack)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Payouts
                    _PayoutsPanel(
                      payouts: ctl.payouts,
                      currency: st.currency,
                      totalEntries: st.entries + st.reentries,
                      prizePool: ctl.prizePool,
                    ),
                    const SizedBox(height: 16),

                    // Level controls
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(onPressed: ctl.prevLevel, child: const Text('◀︎ Level')),
                        ElevatedButton(
                          onPressed: st.running ? ctl.pause : ctl.start,
                          child: Text(st.running ? 'Pause' : 'Start'),
                        ),
                        OutlinedButton(onPressed: ctl.nextLevel, child: const Text('Level ▶︎')),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Time adjust & reset
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(onPressed: ctl.subMinute, child: const Text('− 1 min')),
                        OutlinedButton(onPressed: ctl.addMinute, child: const Text('+ 1 min')),
                        OutlinedButton(
                          onPressed: ctl.resetCurrent,
                          child: const Text('Reset Current Level Time'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Quick accounting
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(onPressed: ctl.addEntry, child: const Text('+ Entry')),
                        OutlinedButton(onPressed: ctl.addReentry, child: const Text('+ Re-entry')),
                        OutlinedButton(onPressed: ctl.addRebuy, child: const Text('+ Rebuy')),
                        OutlinedButton(onPressed: ctl.addAddon, child: const Text('+ Add-on')),
                        OutlinedButton(onPressed: ctl.bustPlayer, child: const Text('− Bust')),
                        OutlinedButton(onPressed: ctl.playersPlus, child: const Text('+ Player')),
                        OutlinedButton(onPressed: ctl.playersMinus, child: const Text('− Player')),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PayoutsPanel extends StatelessWidget {
  final List<Payout> payouts;
  final String currency;
  final int totalEntries;
  final int prizePool;

  const _PayoutsPanel({
    required this.payouts,
    required this.currency,
    required this.totalEntries,
    required this.prizePool,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF12161D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x223366FF)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('Payouts (Top 10%)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('Entries: $totalEntries · Pool: ${money(prizePool, currency)}',
                style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ]),
          const SizedBox(height: 8),
          if (payouts.isEmpty)
            const Text(
              'Add entries/re-entries/rebuys/add-ons to build the prize pool.',
              style: TextStyle(color: Colors.white54),
            )
          else
            Column(
              children: payouts.map((p) {
                final pctStr = p.pct.toStringAsFixed(1);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 40,
                        child: Text('${p.place}.',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: (p.pct / 100).clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: const Color(0x2222FFAA),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 110,
                        child: Text(
                          money(p.amount, currency),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 50,
                        child: Text(
                          '$pctStr%',
                          textAlign: TextAlign.right,
                          style: const TextStyle(color: Colors.white60),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 6),
          const Text(
            'Rebuys/Add-ons count toward the prize pool. No rake. BBA structure.',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
// --- Settings Sheet ---
class _SettingsSheet extends StatefulWidget {
  final int buyin;
  final String currency;
  final int startingStack;
  final int levelLenMin;
  final int lateRegLevel;
  final void Function(int buyin, String currency, int startingStack, int levelLenMin, int lateRegLevel) onSave;

  const _SettingsSheet({
    required this.buyin,
    required this.currency,
    required this.startingStack,
    required this.levelLenMin,
    required this.lateRegLevel,
    required this.onSave,
  });

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late TextEditingController _buyinCtl;
  late TextEditingController _currencyCtl;
  late TextEditingController _startingStackCtl;
  late TextEditingController _levelLenCtl;
  late TextEditingController _lateRegLevelCtl;

  @override
  void initState() {
    super.initState();
    _buyinCtl = TextEditingController(text: widget.buyin.toString());
    _currencyCtl = TextEditingController(text: widget.currency);
    _startingStackCtl = TextEditingController(text: widget.startingStack.toString());
    _levelLenCtl = TextEditingController(text: widget.levelLenMin.toString());
    _lateRegLevelCtl = TextEditingController(text: widget.lateRegLevel.toString());
  }

  @override
  void dispose() {
    _buyinCtl.dispose();
    _currencyCtl.dispose();
    _startingStackCtl.dispose();
    _levelLenCtl.dispose();
    _lateRegLevelCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _buyinCtl,
            decoration: const InputDecoration(labelText: 'Buy-in'),
            keyboardType: TextInputType.number,
          ),
          TextField(
            controller: _currencyCtl,
            decoration: const InputDecoration(labelText: 'Currency'),
          ),
          TextField(
            controller: _startingStackCtl,
            decoration: const InputDecoration(labelText: 'Starting Stack'),
            keyboardType: TextInputType.number,
          ),
          TextField(
            controller: _levelLenCtl,
            decoration: const InputDecoration(labelText: 'Level Length (min)'),
            keyboardType: TextInputType.number,
          ),
          TextField(
            controller: _lateRegLevelCtl,
            decoration: const InputDecoration(labelText: 'Late Reg Level (1-based)'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              final buyin = int.tryParse(_buyinCtl.text) ?? widget.buyin;
              final currency = _currencyCtl.text.trim().isEmpty ? widget.currency : _currencyCtl.text.trim();
              final startingStack = int.tryParse(_startingStackCtl.text) ?? widget.startingStack;
              final levelLenMin = int.tryParse(_levelLenCtl.text) ?? widget.levelLenMin;
              final lateRegLevel = int.tryParse(_lateRegLevelCtl.text) ?? widget.lateRegLevel;
              widget.onSave(buyin, currency, startingStack, levelLenMin, lateRegLevel);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}