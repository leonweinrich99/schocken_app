import 'package:flutter/material.dart';
import '../main.dart'; // Stellt sicher, dass die GameMode-Enum hier definiert ist.

class GameSelectionScreen extends StatelessWidget {
  final Function(GameMode) onGameSelected;

  const GameSelectionScreen({super.key, required this.onGameSelected});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // --- Titel ---
            const Text(
              'WÜRFELN',
              style: TextStyle(
                fontSize: 64, // Größer, um dem Design zu entsprechen
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),

            // --- Spiel-Buttons ---
            _buildGameButton(
              context,
              title: 'SCHOCKEN',
              mode: GameMode.schocken,
              diceValue: 1, // Zeigt die '1' auf dem Würfel
            ),
            _buildGameButton(
              context,
              title: '42 / 18',
              mode: GameMode.fourTwoEighteen,
              diceValue: 2,
            ),
            _buildGameButton(
              context,
              title: 'MÄXCHEN',
              mode: GameMode.simpleDiceGame, // Angenommen, es gibt diesen Modus
              diceValue: 3,
            ),
            // --- Platzhalter-Buttons ---
            _buildGameButton(
              context,
              diceValue: 4,
              isDisabled: true,
            ),
            _buildGameButton(
              context,
              diceValue: 5,
              isDisabled: true,
            ),
            _buildGameButton(
              context,
              diceValue: 6,
              isDisabled: true,
            ),
          ],
        ),
      ),
    );
  }

  /// Baut einen einzelnen Button im neuen Design
  Widget _buildGameButton(
      BuildContext context, {
        String? title,
        GameMode? mode,
        required int diceValue,
        bool isDisabled = false,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Material(
        color: isDisabled ? Colors.black.withOpacity(0.5) : Colors.black,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Colors.white, width: 3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: InkWell(
          onTap: isDisabled || mode == null ? null : () => onGameSelected(mode),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                // Würfel-Icon
                _buildDiceIcon(diceValue),
                const SizedBox(width: 20),
                // Spiel-Titel
                if (title != null)
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: isDisabled ? Colors.white54 : Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Baut ein einfaches, gezeichnetes Würfel-Icon, das zum Design passt
  Widget _buildDiceIcon(int value) {
    // Die Position der Punkte in einem 3x3 Gitter
    final positions = [
      [4], // 1
      [0, 8], // 2
      [0, 4, 8], // 3
      [0, 2, 6, 8], // 4
      [0, 2, 4, 6, 8], // 5
      [0, 2, 3, 5, 6, 8], // 6
    ];

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(6),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemCount: 9,
        itemBuilder: (context, index) {
          bool isDotVisible = (value >= 1 && value <= 6) ? positions[value - 1].contains(index) : false;
          return Container(
            decoration: BoxDecoration(
              color: isDotVisible ? Colors.black : Colors.transparent,
              shape: BoxShape.circle,
            ),
          );
        },
      ),
    );
  }
}
