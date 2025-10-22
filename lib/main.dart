import 'package:flutter/material.dart';
import 'screens/game_selection_screen.dart';
import 'screens/video_splash_screen.dart';
import 'screens/initial_splash_screen.dart'; // NEUER IMPORT
import 'games/simple_dice_game.dart';
import 'games/schocken_game.dart';
import 'games/four_two_eighteen_game.dart';

// Enum zur Verwaltung des Spielzustands (ERWEITERT)
enum GameMode {
  initialSplash, // NEUER STARTZUSTAND
  selection,
  videoSplash,
  simpleDiceGame,
  schocken,
  fourTwoEighteen,
  maexchen
}

class DiceGameApp extends StatelessWidget {
  const DiceGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Würfelspiel-Sammlung',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          secondary: Color(0xFF1E1E1E),
          surface: Color(0xFF1E1E1E),
          background: Color(0xFFEB3B2C),
        ),
        scaffoldBackgroundColor: const Color(0xFFEB3B2C),
        appBarTheme: const AppBarTheme( // AppBar wird hier nicht mehr genutzt, könnte entfernt werden
          backgroundColor: Color(0xFFEB3B2C),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        useMaterial3: true,
      ),
      home: const GameWrapperScreen(),
    );
  }
}

class GameWrapperScreen extends StatefulWidget {
  const GameWrapperScreen({super.key});

  @override
  State<GameWrapperScreen> createState() => _GameWrapperScreenState();
}

class _GameWrapperScreenState extends State<GameWrapperScreen> {
  // Startet jetzt mit dem InitialSplashScreen
  GameMode _currentGameMode = GameMode.initialSplash;
  GameMode? _selectedGameAfterSplash;
  List<String> _players = ['Spieler 1', 'Spieler 2']; // Lokale Spieler

  void _selectGame(GameMode mode) {
    setState(() {
      _selectedGameAfterSplash = mode;
      _currentGameMode = GameMode.videoSplash;
    });
  }

  void _goToSelection() {
    setState(() {
      _currentGameMode = GameMode.selection;
    });
  }


  void _exitGame() {
    setState(() {
      _currentGameMode = GameMode.selection;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget currentScreen;

    switch (_currentGameMode) {
    // --- NEUER CASE FÜR DEN ERSTEN SPLASH ---
      case GameMode.initialSplash:
        currentScreen = InitialSplashScreen(
          onFinished: _goToSelection, // Geht danach zur Auswahl
        );
        break;
    // --- Bestehende Cases ---
      case GameMode.videoSplash:
        currentScreen = VideoSplashScreen(
          onVideoFinished: () {
            setState(() {
              _currentGameMode = _selectedGameAfterSplash ?? GameMode.selection;
              _selectedGameAfterSplash = null;
            });
          },
        );
        break;
      case GameMode.simpleDiceGame:
        currentScreen = SimpleDiceGameWidget(
          players: _players,
          onGameExit: _exitGame,
        );
        break;
      case GameMode.schocken:
        currentScreen = SchockenGameWidget(
          playerNames: _players,
          onGameQuit: _exitGame,
        );
        break;
      case GameMode.fourTwoEighteen:
        currentScreen = FourTwoEighteenGameWidget(
          players: _players,
          onGameExit: _exitGame,
        );
        break;
      case GameMode.maexchen:
      // Hier dein Mäxchen-Widget einfügen
        currentScreen = GameSelectionScreen(onGameSelected: _selectGame);
        break;
      case GameMode.selection:
      default:
        currentScreen = GameSelectionScreen(onGameSelected: _selectGame);
        break;
    }

    return Scaffold(
      body: Center(child: currentScreen),
    );
  }
}

void main() {
  runApp(const DiceGameApp());
}

