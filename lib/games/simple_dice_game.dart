import 'package:flutter/material.dart';
import 'dart:math';
import '../widgets/dice_display.dart'; // Jetzt DiceAssetDisplay

class SimpleDiceGameWidget extends StatefulWidget {
  final List<String> players;
  final VoidCallback onGameExit;

  const SimpleDiceGameWidget({super.key, required this.players, required this.onGameExit});

  @override
  State<SimpleDiceGameWidget> createState() => _SimpleDiceGameWidgetState();
}

class _SimpleDiceGameWidgetState extends State<SimpleDiceGameWidget> {
  final Random _random = Random();
  Map<String, int> _playerScores = {};
  int _currentPlayerIndex = 0;
  List<int> _currentDiceValues = [1, 1, 1];
  String _gameStatusMessage = 'Start!';
  final int _targetScore = 30;

  @override
  void initState() {
    super.initState();
    _playerScores = Map.fromIterable(widget.players, key: (player) => player, value: (_) => 0);
  }

  void _rollDice() {
    if (_playerScores.values.any((score) => score >= _targetScore)) return;

    setState(() {
      _currentDiceValues = List.generate(3, (_) => _random.nextInt(6) + 1);
      final sum = _currentDiceValues.fold(0, (prev, element) => prev + element);
      final currentPlayer = widget.players[_currentPlayerIndex];

      _playerScores[currentPlayer] = (_playerScores[currentPlayer] ?? 0) + sum;

      _gameStatusMessage = '$currentPlayer würfelt: $sum Punkte!';

      if (_playerScores[currentPlayer]! >= _targetScore) {
        _gameStatusMessage = '$currentPlayer hat gewonnen!';
        _showWinnerDialog(currentPlayer);
      } else {
        _currentPlayerIndex = (_currentPlayerIndex + 1) % widget.players.length;
      }
    });
  }

  void _showWinnerDialog(String winner) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.black,
          title: const Text('SPIEL VORBEI', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          content: Text('$winner hat ${_playerScores[winner]} Punkte erreicht und gewonnen!', style: const TextStyle(color: Colors.white)),
          actions: <Widget>[
            TextButton(
              child: const Text('NEU STARTEN', style: TextStyle(color: Colors.white)),
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _playerScores = Map.fromIterable(widget.players, key: (player) => player, value: (_) => 0);
                  _currentPlayerIndex = 0;
                  _gameStatusMessage = 'Neues Spiel gestartet.';
                });
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildDiceArea(double size) {
    return Column(
      children: [
        // Oben: Gewürfelte Würfel
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _currentDiceValues.map((value) => Padding(
            padding: const EdgeInsets.all(4.0),
            child: SizedBox(
              width: size,
              height: size,
              child: DiceAssetDisplay(value: value),
            ),
          )).toList(),
        ),
        const SizedBox(height: 50),
        // Unten: Würfelbecher (Visual)
        Container(
          width: size * 2,
          height: size * 3,
          child: Center(
            child: DiceAssetPaths.diceCupUrl.isNotEmpty && DiceAssetPaths.useAssets
                ? Image.network(
              DiceAssetPaths.diceCupUrl,
              width: size * 2,
              height: size * 3,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => _buildDrawnDiceCup(size),
            )
                : _buildDrawnDiceCup(size),
          ),
        ),
      ],
    );
  }

  Widget _buildScoreboard() {
    return Card(
      elevation: 5,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
      color: Colors.black,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'PUNKTE',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 2,
              ),
              textAlign: TextAlign.center,
            ),
            const Divider(color: Colors.redAccent, thickness: 1.5, height: 15),

            ..._playerScores.entries.map((entry) {
              final isCurrentPlayer = entry.key == widget.players[_currentPlayerIndex] && _playerScores.values.every((score) => score < _targetScore);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        if (isCurrentPlayer)
                          const Icon(Icons.play_arrow, size: 20, color: Colors.redAccent),
                        if (isCurrentPlayer) const SizedBox(width: 5),
                        Text(
                          entry.key,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isCurrentPlayer ? FontWeight.bold : FontWeight.normal,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${entry.value} / $_targetScore',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isCurrentPlayer ? FontWeight.bold : FontWeight.normal,
                        color: (entry.value >= _targetScore) ? Colors.red : Colors.white,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const double diceSize = 50;

    final bool isGameOver = _playerScores.values.any((score) => score >= _targetScore);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          // Titel
          const Text(
            'WÜRFELN',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 20),

          // Würfelbereich (Frame 3)
          _buildDiceArea(diceSize),

          const SizedBox(height: 40),

          // Würfeln Button
          Container(
            width: 300,
            height: 60,
            margin: const EdgeInsets.only(bottom: 20),
            child: ElevatedButton.icon(
              onPressed: isGameOver ? null : _rollDice,
              icon: const Icon(Icons.casino, size: 28),
              label: Text(
                isGameOver ? 'SPIEL VORBEI' : 'WÜRFELN',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)), // Eckig
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 8,
              ),
            ),
          ),

          // Scoreboard
          _buildScoreboard(),

          // Spiel wechseln
          TextButton(
            onPressed: widget.onGameExit,
            child: const Text('SPIEL WECHSELN', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }
}

// Zeichnet den Becher als Fallback
Widget _buildDrawnDiceCup(double mainDiceSize) {
  return Container(
    width: mainDiceSize * 2,
    height: mainDiceSize * 3,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30), bottom: Radius.circular(5)),
      border: Border.all(color: Colors.black, width: 3),
    ),
    child: const Center(
      child: Text(
        'BECHER\n(Fallback)',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    ),
  );
}
