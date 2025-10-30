import 'package:flutter/material.dart';
import 'screens/game_selection_screen.dart';
import 'screens/video_splash_screen.dart';
import 'screens/initial_splash_screen.dart';
import 'screens/player_entry_screen.dart'; // NEUER IMPORT
import 'games/simple_dice_game.dart';
import 'games/schocken_game.dart';
import 'games/four_two_eighteen_game.dart';

// Enum zur Verwaltung des Spielzustands (ERWEITERT)
enum GameMode {
  initialSplash,
  selection,
  playerEntry, // NEUER ZUSTAND für Spielereingabe
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
      title: 'Würfeln',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          secondary: Color(0xFF1E1E1E),
          surface: Color(0xFF1E1E1E),
          background: Color(0xFFFA4848),
        ),
        scaffoldBackgroundColor: const Color(0xFFFA4848),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFA4848),
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
  GameMode _currentGameMode = GameMode.initialSplash;
  GameMode? _selectedGameAfterSplash;
  List<String> _players = ['Spieler 1']; // Startet jetzt mit leerer Liste oder Standard

  /// Diese Funktion startet jetzt den PlayerEntryScreen für Schocken UND 42/18
  void _selectGame(GameMode mode) {
    setState(() {
      // Spiele, die eine Spielereingabe benötigen
      if (mode == GameMode.schocken || mode == GameMode.fourTwoEighteen) { // HIER HINZUGEFÜGT
        _currentGameMode = GameMode.playerEntry;
        _selectedGameAfterSplash = mode; // Merken, welches Spiel gestartet werden soll
      } else { // Für andere Spiele direkt zum Video
        _selectedGameAfterSplash = mode;
        _currentGameMode = GameMode.videoSplash;
      }
    });
  }

  /// Wird vom PlayerEntryScreen aufgerufen, um das Spiel zu starten
  void _startGameWithPlayers(List<String> playerNames) {
    setState(() {
      _players = playerNames; // Spielerliste aktualisieren
      _currentGameMode = GameMode.videoSplash; // Video starten
      // _selectedGameAfterSplash sollte hier bereits gesetzt sein (z.B. auf schocken oder fourTwoEighteen)
    });
  }

  void _goToSelection() {
    setState(() {
      _currentGameMode = GameMode.selection;
    });
  }


  void _exitGame() {
    setState(() {
      _currentGameMode = GameMode.selection; // Zurück zur Auswahl
      _selectedGameAfterSplash = null; // Auswahl zurücksetzen
      _players = ['Spieler 1']; // Spieler zurücksetzen (optional)
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget currentScreen;

    switch (_currentGameMode) {
      case GameMode.initialSplash:
        currentScreen = InitialSplashScreen(
          onFinished: _goToSelection,
        );
        break;
    // --- NEUER CASE FÜR SPIELEREINGABE ---
      case GameMode.playerEntry:
        currentScreen = PlayerEntryScreen(
          onStartGame: _startGameWithPlayers, // Callback zum Starten
          onBack: _exitGame, // Geht zurück zur Auswahl
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
      // Stellt sicher, dass Spieler vorhanden sind, sonst Fallback
        currentScreen = SchockenGameWidget(
          playerNames: _players.isNotEmpty ? _players : ['Spieler 1'],
          onGameQuit: _exitGame,
        );
        break;
      case GameMode.fourTwoEighteen:
        currentScreen = FourTwoEighteenGameWidget(
          players: _players.isNotEmpty ? _players : ['Spieler 1'],
          onGameExit: _exitGame,
        );
        break;
      case GameMode.maexchen:
      //TODO: Mäxchen implementieren
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

