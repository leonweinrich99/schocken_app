import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/dice_display.dart'; // Importieren, um Asset-Pfade zu nutzen

class InitialSplashScreen extends StatefulWidget {
  final VoidCallback onFinished;

  const InitialSplashScreen({super.key, required this.onFinished});

  @override
  State<InitialSplashScreen> createState() => _InitialSplashScreenState();
}

class _InitialSplashScreenState extends State<InitialSplashScreen> {
  @override
  void initState() {
    super.initState();
    // Nach einer Sekunde zur nächsten Ansicht wechseln
    Timer(const Duration(seconds: 1), widget.onFinished);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE53935), // Roter Hintergrund
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Titel "WÜRFELN"
            const Text(
              'WÜRFELN',
              style: TextStyle(
                fontSize: 100, // Sehr groß, wie im Bild
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),

            // Würfel-Anordnung mit Assets
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildDiceImage(4), // Oben links
                const SizedBox(width: 15),
                _buildDiceImage(2), // Oben rechts
              ],
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildDiceImage(6), // Unten links
                const SizedBox(width: 15),
                _buildDiceImage(6), // Unten mitte
                const SizedBox(width: 15),
                _buildDiceImage(6), // Unten rechts
              ],
            ),
            const SizedBox(height: 40),

            // Würfelbecher-Asset
            _buildDiceCupImage(),
          ],
        ),
      ),
    );
  }

  /// Baut ein Würfel-Bild-Widget
  Widget _buildDiceImage(int value) {
    const double diceSize = 100.0; // Feste Größe für diesen Screen

    // Stellt sicher, dass der Wert gültig ist
    if (value < 1 || value > 6) {
      return Container(width: diceSize, height: diceSize, color: Colors.grey); // Fallback
    }

    // Verwendet DiceAssetDisplay, falls vorhanden und konfiguriert
    // return SizedBox(
    //   width: diceSize,
    //   height: diceSize / DiceAssetDisplay.diceAspectRatio, // Nutzt das korrekte Verhältnis
    //   child: DiceAssetDisplay(value: value),
    // );

    // Alternative: Direkte Verwendung von Image.asset
    return SizedBox(
      width: diceSize,
      height: diceSize * (111 / 164), // Höhe basierend auf dem Aspektverhältnis anpassen
      child: Image.asset(
        DiceAssetPaths.diceUrls[value - 1],
        fit: BoxFit.contain, // Passt das Bild an, ohne es zu verzerren
        errorBuilder: (context, error, stackTrace) {
          // Fallback, wenn das Asset nicht geladen werden kann
          return Container(width: diceSize, height: diceSize * (111 / 164), color: Colors.black, child: Center(child: Text(value.toString(), style: TextStyle(color: Colors.white))));
        },
      ),
    );
  }

  /// Baut das Würfelbecher-Bild-Widget
  Widget _buildDiceCupImage() {
    return SizedBox(
      width: 300,
      height: 301, // Passen Sie die Höhe ggf. an Ihr Asset an
      child: Image.asset(
        DiceAssetPaths.diceCupUrl,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          // Fallback, wenn das Asset nicht geladen werden kann
          return Container(width: 150, height: 200, decoration: BoxDecoration(border: Border.all(color: Colors.white)));
        },
      ),
    );
  }
}

