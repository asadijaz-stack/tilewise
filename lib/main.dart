/// TileWise — offline Scrabble-like word game.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game/ai_engine.dart';
import 'game/dictionary.dart';
import 'ui/how_to_play_screen.dart';
import 'ui/menu_screen.dart';
import 'ui/widgets.dart';
import 'util/sound.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TileWiseApp());
}

class TileWiseApp extends StatelessWidget {
  const TileWiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TileWise',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const LoadingScreen(),
    );
  }
}

/// Boot screen: loads the dictionary, warms up the AI isolate, then menu.
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  String _status = 'Loading dictionary…';

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      final text = await rootBundle.loadString('assets/words.txt');
      final words = text.split('\n').where((w) => w.trim().isNotEmpty).toList();
      final dict = Dictionary.fromWords(words);
      final commonText = await rootBundle.loadString('assets/common_words.txt');
      // Everyday vocabulary for the weaker AI levels (must all be legal).
      final commonWords = commonText
          .split('\n')
          .map((w) => w.trim())
          .where((w) => w.isNotEmpty && dict.contains(w))
          .toList();
      if (!mounted) return;
      setState(() => _status = 'Warming up the computer…');
      final engine = await AiEngine.create();
      await engine.init(words, commonWords);
      await SoundManager().init();
      // First launch ever: open the visual guide over the menu, so a
      // brand-new player learns the game before their first move.
      final prefs = await SharedPreferences.getInstance();
      final firstLaunch = !(prefs.getBool('seenGuide') ?? false);
      if (firstLaunch) await prefs.setBool('seenGuide', true);
      if (!mounted) return;
      final nav = Navigator.of(context);
      nav.pushReplacement(
        MaterialPageRoute(
          builder: (_) => MenuScreen(dict: dict, aiEngine: engine),
        ),
      );
      if (firstLaunch) {
        nav.push(slideRoute(const HowToPlayScreen()));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Something went wrong: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F3D1F),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(
                  color: Colors.amber, strokeWidth: 5),
            ),
            const SizedBox(height: 20),
            Text(
              _status,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
