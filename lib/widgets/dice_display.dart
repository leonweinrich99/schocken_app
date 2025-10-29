import 'package:flutter/material.dart';

// HILFSKLASSE: Würfel-Definition für Asset-Pfade
class DiceAssetPaths {
  static const String ASSET_BASE_URL = 'assets/images/dices/';
  static const String LID_BASE_URL = 'assets/images/lids/';

  static String diceCupUrl = 'assets/images/cup.png';
  // NEU: Pfad für den Fragezeichen-Würfel
  static String diceQuestionUrl = '${ASSET_BASE_URL}dice_question.png';

  static List<String> diceUrls = [
    '${ASSET_BASE_URL}dice_01.png', // Index 0 (Wert 1)
    '${ASSET_BASE_URL}dice_02.png', // Index 1 (Wert 2)
    '${ASSET_BASE_URL}dice_03.png', // Index 2 (Wert 3)
    '${ASSET_BASE_URL}dice_04.png', // Index 3 (Wert 4)
    '${ASSET_BASE_URL}dice_05.png', // Index 4 (Wert 5)
    '${ASSET_BASE_URL}dice_06.png', // Index 5 (Wert 6)
  ];

  static List<String> lidUrls = [
    '${LID_BASE_URL}lid_01.png', // Index 0 (Wert 1)
    '${LID_BASE_URL}lid_02.png', // Index 1 (Wert 2)
    '${LID_BASE_URL}lid_03.png', // Index 2 (Wert 3)
    '${LID_BASE_URL}lid_04.png', // Index 3 (Wert 4)
    '${LID_BASE_URL}lid_05.png', // Index 4 (Wert 5)
    '${LID_BASE_URL}lid_06.png', // Index 5 (Wert 6)
    '${LID_BASE_URL}lid_07.png', // Index 6 (Wert 7)
    '${LID_BASE_URL}lid_08.png', // Index 7 (Wert 8)
    '${LID_BASE_URL}lid_09.png', // Index 8 (Wert 9)
    '${LID_BASE_URL}lid_10.png', // Index 9 (Wert 10)
    '${LID_BASE_URL}lid_11.png', // Index 10 (Wert 11)
    '${LID_BASE_URL}lid_12.png', // Index 11 (Wert 12)
    '${LID_BASE_URL}lid_13.png', // Index 12 (Wert 13)
  ];

  static bool useAssets = true;
}

// -----------------------------------------------------------------------------
// WÜRFEL DARSTELLUNG
// -----------------------------------------------------------------------------

class DiceAssetDisplay extends StatelessWidget {
  final int value;
  final bool isHeld;
  final VoidCallback? onTap;
  static const double diceAspectRatio = 164 / 111;

  const DiceAssetDisplay({
    super.key,
    required this.value, // Wert 0 wird jetzt für '?' verwendet
    this.isHeld = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Standard-Asset-Pfad
    String assetPath;

    // Logik zur Auswahl des richtigen Bildes
    if (value == 0) {
      assetPath = DiceAssetPaths.diceQuestionUrl;
    } else if (value >= 1 && value <= 6) {
      assetPath = DiceAssetPaths.diceUrls[value - 1];
    } else {
      // Fallback, wenn der Wert ungültig ist
      return _buildDrawnDice();
    }

    if (DiceAssetPaths.useAssets) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isHeld ? Colors.white : Colors.transparent,
              width: isHeld ? 4 : 0,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.asset(
              assetPath, // Verwende den ausgewählten Pfad
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildDrawnDice();
              },
            ),
          ),
        ),
      );
    } else {
      return GestureDetector(
        onTap: onTap,
        child: _buildDrawnDice(),
      );
    }
  }

  Widget _buildDrawnDice() {
    // Zeigt '?' an, wenn der Wert 0 ist
    String displayText = value == 0 ? '?' : value.toString();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isHeld ? const Color(0xFFE53935) : Colors.black,
          width: isHeld ? 4.0 : 2.0,
        ),
      ),
      child: Center(
        child: Text(
          displayText,
          style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.black),
        ),
      ),
    );
  }
}