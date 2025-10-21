import 'package:flutter/material.dart';
import 'screens/game_selection_screen.dart';
import 'games/simple_dice_game.dart';
import 'games/schocken_game.dart';
import 'games/four_two_eighteen_game.dart';

// Enum zur Verwaltung des Spielzustands
enum GameMode {
  selection,
  simpleDiceGame,
  schocken,
  fourTwoEighteen,
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
          secondary: Color(0xFF1E1E1E), // Weiß als Akzent
          surface: Color(0xFF1E1E1E),
          background: Color(0xFFEB3B2C), // Kräftiges Rot als Hintergrund
        ),
        scaffoldBackgroundColor: const Color(0xFFEB3B2C), // Rot als Hintergrund
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFEB3B2C), // App Bar auch Rot
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true, // Zentrierte Titel
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
  GameMode _currentGameMode = GameMode.selection;
  List<String> _players = ['Spieler 1', 'Spieler 2']; // Lokale Spieler

  void _selectGame(GameMode mode) {
    setState(() {
      _currentGameMode = mode;
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
    String title;

    switch (_currentGameMode) {
      case GameMode.simpleDiceGame:
        title = 'WÜRFELN';
        currentScreen = SimpleDiceGameWidget(
          players: _players,
          onGameExit: _exitGame,
        );
        break;
      case GameMode.schocken:
        title = 'SCHOCKEN';
        currentScreen = SchockenGameWidget(
          playerNames: _players,
          onGameQuit: _exitGame,
        );
        break;
      case GameMode.fourTwoEighteen:
        title = '42 / 18';
        currentScreen = FourTwoEighteenGameWidget(
          players: _players,
          onGameExit: _exitGame,
        );
        break;
      case GameMode.selection:
      default:
        title = 'WÜRFELN';
        currentScreen = GameSelectionScreen(onGameSelected: _selectGame);
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        automaticallyImplyLeading: _currentGameMode != GameMode.selection,
        leading: _currentGameMode != GameMode.selection
            ? IconButton(
          icon: const Icon(Icons.arrow_back, size: 30),
          onPressed: _exitGame
        )
            : null,
      ),
      body: Center(child: currentScreen),
    );
  }
}

void main() {
  runApp(const DiceGameApp());
}
