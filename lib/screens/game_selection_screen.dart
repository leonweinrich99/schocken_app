import 'package:flutter/material.dart';
import '../main.dart'; // Stellt sicher, dass die GameMode-Enum hier definiert ist.
import '../widgets/dice_display.dart'; // Importieren, um Asset-Pfade zu nutzen

class GameSelectionScreen extends StatelessWidget {
  final Function(GameMode) onGameSelected;

  const GameSelectionScreen({super.key, required this.onGameSelected});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(5),
        constraints: const BoxConstraints(maxWidth: 375),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 60),
            // --- Titel (jetzt responsiv) ---
            FittedBox( // NEU: Skaliert den Text, damit er in die Breite passt
              fit: BoxFit.contain, // Stellt sicher, dass der Text hineinpasst
              child: const Text(
                'WÜRFELN',
                style: TextStyle(
                  fontSize: 60, // Basis-Schriftgröße, wird von FittedBox skaliert
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(
                      color: Colors.black, // Farbe des Schattens mit Deckkraft
                      offset: Offset(10, 0), // Offset skaliert mit der Schriftgröße
                      blurRadius: 0, // Weichzeichner-Radius
                    ),
                  ],
                  color: Colors.white,
                  letterSpacing: 1,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 30),

            // --- Spiel-Buttons (jetzt scrollbar) ---
            Expanded( // NEU: Nimmt den restlichen Platz ein
              child: SingleChildScrollView( // NEU: Macht die Liste scrollbar
                child: Column( // NEU: Innere Spalte für die Buttons
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                      mode: GameMode.maexchen, // Angenommen, es gibt diesen Modus
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
        color: isDisabled ? Color(0xFF1E1E1E) : Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Colors.black, width: 0),
          borderRadius: BorderRadius.circular(10),
        ),
        child: InkWell(
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
          onTap: isDisabled || mode == null ? null : () => onGameSelected(mode),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
            child: Row(
              children: [
                // Würfel-Icon (jetzt mit Bild)
                _buildDiceImage(diceValue), // Geändert zu _buildDiceImage
                // Spiel-Titel
                if (title != null)
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 36,
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

  /// Baut ein Würfel-Bild-Widget (ähnlich wie im InitialSplashScreen)
  Widget _buildDiceImage(int value) {
    const double diceSize = 125.0; // Feste Größe für diesen Screen

    // Stellt sicher, dass der Wert gültig ist
    if (value < 1 || value > 6) {
      return Container(width: diceSize, height: diceSize, color: Colors.grey); // Fallback
    }

    // Direkte Verwendung von Image.asset
    return SizedBox(
      width: diceSize,
      // Höhe basierend auf dem Aspektverhältnis der Würfelbilder anpassen
      // Annahme: Das Verhältnis ist 111/164 (Höhe/Breite)
      height: diceSize * (111 / 164),
      child: Image.asset(
        DiceAssetPaths.diceUrls[value - 1], // Greift auf die Pfade in dice_display.dart zu
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          // Fallback, wenn das Asset nicht geladen werden kann
          return Container(width: diceSize, height: diceSize * (111 / 164), color: Colors.black, child: Center(child: Text(value.toString(), style: TextStyle(color: Colors.white))));
        },
      ),
    );
  }
}
