import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/clock/clock_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: TourneyApp()));
}

class TourneyApp extends StatelessWidget {
  const TourneyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tourney Clock',
      theme: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(primary: Color(0xFF19C37D)),
        scaffoldBackgroundColor: const Color(0xFF0B0E13),
      ),
      home: const ClockScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}