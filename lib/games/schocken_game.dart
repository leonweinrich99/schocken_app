import 'package:flutter/material.dart';
import '../logic/schocken_game_logic.dart'; // Import der neuen Logik-Klasse
import '../widgets/dice_display.dart'; // Stellt sicher, dass diese Datei existiert und lidUrls enthält
import 'dart:math' as math; // Wird für Sortierung benötigt

class SchockenGameWidget extends StatefulWidget {
  final List<String> playerNames;
  final VoidCallback onGameQuit;

  const SchockenGameWidget({
    super.key,
    required this.playerNames,
    required this.onGameQuit,
  });

  @override
  State<SchockenGameWidget> createState() => _SchockenGameWidgetState();
}

class _SchockenGameWidgetState extends State<SchockenGameWidget> with SingleTickerProviderStateMixin {
  late SchockenGame _game; // Instanz der Spiellogik

  // Animation bleibt in der UI-Schicht
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  String _animationText = '';
  bool _isRevealSequenceRunning = false;

  // Zustand für Info-Overlay
  bool _isInfoOverlayVisible = false;

  @override
  void initState() {
    super.initState();
    _game = SchockenGame(widget.playerNames); // Logik-Instanz erstellen
    _game.addListener(_onGameStateChanged); // Auf Änderungen hören

    // Animation initialisieren
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, -1.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.fastOutSlowIn),
    );
  }

  @override
  void dispose() {
    _game.removeListener(_onGameStateChanged); // Listener entfernen
    _animationController.dispose();
    _game.dispose(); // ChangeNotifier sollte disposed werden
    super.dispose();
  }

  // Wird aufgerufen, wenn sich der Spielzustand in SchockenGame ändert
  void _onGameStateChanged() {
    setState(() {}); // Einfach die UI neu bauen
  }

  // Startet die Aufdeck-Animation (bleibt hier, da UI-spezifisch)
  Future<void> _startRevealAnimationSequence() async {
    setState(() {
      _isRevealSequenceRunning = true;
    });

    // Hole den besten Score aus der Logik-Klasse
    List<SchockenScore?> sortedScores = List.from(_game.playerScores);
    // Filtert inaktive Spieler heraus, bevor sortiert wird
    sortedScores.removeWhere((score) => score == null); // Scores von inaktiven Spielern sind null

    sortedScores.sort((a, b) {
      if (a == null && b == null) return 0;
      if (a == null) return 1;
      if (b == null) return -1;
      return a.isBetterThan(b) ? -1 : 1;
    });
    // Nimm den besten Score der aktiven Spieler
    final bestScore = sortedScores.isNotEmpty ? sortedScores.first : null;


    if (bestScore != null) {
      setState(() {
        _animationText = bestScore.typeString;
      });
      await _animationController.forward();
      await Future.delayed(const Duration(milliseconds: 1200));
      await _animationController.reverse();
      await Future.delayed(const Duration(milliseconds: 200));
    }

    // Ergebnisberechnung in der Logik-Klasse anstoßen
    _game.calculateAndSetResults();
    setState(() {
      _isRevealSequenceRunning = false;
    });
  }


  // ---------------------------------------------------------------------------
  // UI BUILD Methoden (verwenden jetzt _game für Zustand und Aktionen)
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFA4848), // Hintergrundfarbe angepasst
      body: SafeArea(
        child: Stack( // Stack für Overlays (Animation & Info & Status)
          children: [
            Column( // Main layout column
              children: [
                // 1. HEADER (Fixed Height)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Titel
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40.0),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: const Text(
                              'SCHOCKEN',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 42,
                                  fontWeight: FontWeight.w900,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black, // Farbe des Schattens mit Deckkraft
                                      offset: Offset(6, 0), // Offset skaliert mit der Schriftgröße
                                      blurRadius: 0, // Weichzeichner-Radius
                                    ),
                                  ]),
                            ),
                          ),
                        ),
                      ),
                      // Back Button
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
                          onPressed: widget.onGameQuit,
                        ),
                      ),
                      // Info/Close Button
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          icon: Icon(
                              _isInfoOverlayVisible ? Icons.close : Icons.info_outline,
                              color: Colors.white,
                              size: 30
                          ),
                          onPressed: () {
                            setState(() {
                              _isInfoOverlayVisible = !_isInfoOverlayVisible;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // --- EXPANDED AREA FOR MAIN CONTENT + BUTTONS ---
                // This Expanded area pushes the Scoreboard to the bottom
                Expanded(
                    child: Column(
                      children: [
                        // 2. MAIN CONTENT AREA (Flexible within Expanded)
                        // Allows main content to shrink/grow but takes priority
                        Flexible(
                          fit: FlexFit.tight, // Takes available space
                          child: Padding(
                            padding: const EdgeInsets.only(top: 20.0, left: 16.0, right: 16.0, bottom: 10.0), // Added bottom padding
                            child: _buildMainContentArea(),
                          ),
                        ),

                        // 3. BUTTON AREA (Fixed Height)
                        _buildButtonArea(), // Buttons are placed below main content
                      ],
                    )
                ),
                // --- END EXPANDED AREA ---

                // 4. SCOREBOARD (Fixed Height - conditional, outside Expanded)
                // This will now be fixed at the bottom
                if (!_game.areResultsCalculated && !_isRevealSequenceRunning)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20.0, left: 16.0, right: 16.0, top: 10.0), // Added top padding
                    child: _buildScoreboardContainer(),
                  ),
                // Add some bottom padding if scoreboard is hidden
                if (_game.areResultsCalculated || _isRevealSequenceRunning)
                  const SizedBox(height: 20),
              ],
            ),
            // Status Indicators, Animation Overlay, Info Overlay remain in the Stack
            if (!_isInfoOverlayVisible && !_isRevealSequenceRunning && !_game.isRoundFinished)
              _buildGameStatusIndicators(),
            _buildAnimationOverlay(),
            if (_isInfoOverlayVisible) _buildInfoOverlay(),
          ],
        ),
      ),
    );
  }


  /// NEUES WIDGET: Baut die schwebenden Statusanzeigen für Wurf und Deckel
  Widget _buildGameStatusIndicators() {
    // Ermittelt die aktuelle Wurfnummer für die Anzeige
    int currentRollNumber = _game.rollsLeft < 3 ? (3 - _game.rollsLeft) + 1 : 1;
    // Deckelzahl für die Anzeige
    int lidsInMiddleCount = _game.lidsInMiddle;
    // Index für das Deckelbild (1-basiert für Bildnamen, 0-basiert für Liste)
    int lidIndex = math.max(0, lidsInMiddleCount - 1); // Stellt sicher, dass Index nicht negativ ist
    // Sicherstellen, dass der Index gültig ist und lidUrls existiert
    bool validLidIndex = DiceAssetPaths.lidUrls != null && lidIndex < DiceAssetPaths.lidUrls!.length;
    String lidAssetPath = validLidIndex ? DiceAssetPaths.lidUrls[lidIndex] : ''; // Fallback


    // Würfelbild für Wurfnummer
    bool validDiceIndex = currentRollNumber >= 1 && currentRollNumber <= 6;
    // Sicherstellen, dass der Index gültig ist und diceUrls existiert
    String diceAssetPath = validDiceIndex && DiceAssetPaths.diceUrls.length >= currentRollNumber
        ? DiceAssetPaths.diceUrls[currentRollNumber - 1]
        : ''; // Fallback


    // Stil für den Text unter den Bildern
    const indicatorTextStyle = TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold); // Schriftgröße angepasst

    // --- RESPONSIVE ANPASSUNG ---
    // Größe der Indikator-Boxen basierend auf Bildschirmbreite, mit min/max
    final double indicatorSize = (MediaQuery.of(context).size.width * 0.18).clamp(60.0, 80.0);


    return Positioned(
        top: 80, // Abstand vom oberen Rand (unter dem Header) - Anpassen nach Bedarf
        right: 20,  // Abstand vom RECHTEN Rand
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Wurf-Anzeige
            Container(
              width: indicatorSize,
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14), // Abrundung wie im Bild
                  boxShadow: const [
                    BoxShadow(color: Colors.black, offset: Offset(4, 5), blurRadius: 0), // Harter Schatten
                  ]
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Würfelbild anzeigen
                  validDiceIndex && diceAssetPath.isNotEmpty
                      ? Image.asset( // Image.asset für lokale Dateien
                    diceAssetPath,
                    height: indicatorSize * 0.5,
                    fit: BoxFit.contain,
                    errorBuilder: (_,__,___) => Icon(Icons.help_outline, size: indicatorSize * 0.5, color: Colors.black), // Fallback Icon geändert
                  )
                      : Icon(Icons.help_outline, size: indicatorSize * 0.5, color: Colors.black), // Fallback Icon geändert
                  const SizedBox(height: 4),
                  const Text("WURF", style: indicatorTextStyle),
                ],
              ),
            ),
            const SizedBox(height: 15), // Abstand zwischen den Indikatoren
            // Deckel-Anzeige
            Container(
              width: indicatorSize,
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14), // Abrundung wie im Bild
                  boxShadow: const [
                    BoxShadow(color: Colors.black, offset: Offset(4, 5), blurRadius: 0), // Harter Schatten
                  ]
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Deckelbild anzeigen
                  (lidsInMiddleCount > 0 && validLidIndex && lidAssetPath.isNotEmpty)
                      ? Image.asset( // Image.asset für lokale Dateien
                    lidAssetPath,
                    height: indicatorSize * 0.5,
                    fit: BoxFit.contain,
                    errorBuilder: (_,__,___) => Icon(Icons.circle, size: indicatorSize * 0.5, color: Colors.red), // Fallback geändert
                  )
                      : Icon(Icons.circle_outlined, size: indicatorSize * 0.5, color: Colors.red), // Fallback für 0 Deckel
                  const SizedBox(height: 4),
                  const Text("DECKEL", style: indicatorTextStyle),
                ],
              ),
            ),
          ],
        )
    );
  }


  Widget _buildMainContentArea() {
    // Now within a Flexible parent, LayoutBuilder works as intended
    if (_game.isRoundFinished && !_game.areResultsCalculated && !_isRevealSequenceRunning) {
      return LayoutBuilder(
        builder: (context, constraints) {
          // Calculate size based on available height from Flexible parent
          final cupSize = (constraints.maxHeight * 0.8).clamp(150.0, 300.0); // Keep min size
          // Ensure cup doesn't get too small if constraints.maxHeight is tiny
          if (constraints.maxHeight < 100) return const SizedBox.shrink(); // Hide if not enough space

          return Center(
            child: Image.asset(
              DiceAssetPaths.diceCupUrl,
              width: cupSize,
              height: cupSize,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(Icons.casino, size: cupSize, color: Colors.white),
            ),
          );
        },
      );
    } else if (_game.isRoundFinished && (_game.areResultsCalculated || _isRevealSequenceRunning)) {
      // Result display needs to fit. If it's too tall, the outer Column won't scroll.
      // Consider making the result display itself scrollable if needed.
      return _buildResultDisplay();
    } else { // Normal dice rolling view
      // Dice area should fit naturally.
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDiceArea(),
        ],
      );
    }
  }

  Widget _buildButtonArea() {
    const buttonPadding = EdgeInsets.only(bottom: 10.0, top: 10.0); // Reduced bottom padding
    final resultStyle = const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold);

    String resultText = "";
    if (_game.roundLoserName != null && _game.areResultsCalculated) {
      // NEUE LOGIK FÜR RESULTAT-TEXT
      if (_game.wasGameLost) {
        resultText = '${_game.roundLoserName} hat das Spiel verloren!';
      } else if (_game.wasHalfLost) {
        // Unterscheiden, ob Finale beginnt oder 2. Halbzeit
        resultText = _game.gamePhase == 3
            ? '${_game.roundLoserName} hat die 2. Halbzeit verloren!'
            : '${_game.roundLoserName} hat die 1. Halbzeit verloren!';
      } else {
        resultText = '${_game.roundLidsTransferred} Deckel gehen an ${_game.roundLoserName}';
      }
    }

    Widget buttonWidget;
    if (_game.isRoundFinished && !_game.areResultsCalculated && !_isRevealSequenceRunning) {
      buttonWidget = _buildActionButton('AUFDECKEN', _startRevealAnimationSequence, isPrimary: true);
    } else if (_game.isRoundFinished && _game.areResultsCalculated) {
      // NEUE LOGIK FÜR BUTTON-TEXT
      String buttonText;
      if (_game.wasGameLost) {
        buttonText = 'SPIEL BEENDEN';
      } else if (_game.wasHalfLost) {
        buttonText = _game.gamePhase == 3 ? 'FINALE STARTEN' : 'NÄCHSTE HALBZEIT';
      } else {
        buttonText = 'NÄCHSTE RUNDE';
      }
      VoidCallback nextAction = () {
        if(_game.wasGameLost) {
          widget.onGameQuit();
        } else {
          _game.startNextRoundOrHalf();
        }
      };
      buttonWidget = _buildActionButton(buttonText, nextAction, isPrimary: true);
    } else if (!_game.isRoundFinished && !_isRevealSequenceRunning) {
      buttonWidget = _buildGameButtons();
    } else {
      buttonWidget = const SizedBox(height: 0);
    }

    return Padding(
      padding: buttonPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (resultText.isNotEmpty && _game.areResultsCalculated)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(resultText, style: resultStyle, textAlign: TextAlign.center),
            ),
          buttonWidget,
        ],
      ),
    );
  }

  Widget _buildAnimationOverlay() {
    return Center(
      child: IgnorePointer(
        child: SlideTransition(
          position: _slideAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                decoration: BoxDecoration(
                  color: Color(0xFFFA4848),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: Text(
                  _animationText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultDisplay() {
    final titleStyle = const TextStyle(color: Colors.black, fontSize: 28, fontWeight: FontWeight.bold);
    final itemStyle = const TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.bold);
    final diceSize = MediaQuery.of(context).size.width * 0.12;
    final double lidImageSize = (MediaQuery.of(context).size.width * 0.08).clamp(30.0, 40.0);
    List<MapEntry<String, SchockenScore>> sortedPlayerScores = _game.getSortedPlayerScores();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: const [
          BoxShadow(color: Colors.black, spreadRadius: 0, blurRadius: 0, offset: Offset(5, 7)),
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // Important!
        children: [
          Text("Ergebnisliste", style: titleStyle),
          const SizedBox(height: 10),
          const Divider(color: Colors.black54, thickness: 2),
          const SizedBox(height: 10),
          // Make the ListView scrollable within this Column
          LimitedBox( // Give the ListView a max height
            maxHeight: MediaQuery.of(context).size.height * 0.45, // Example: max 30% of screen height
            child: ListView.builder(
              shrinkWrap: true, // Still needed with LimitedBox/ConstrainedBox
              // physics: AlwaysScrollableScrollPhysics(), // Allow scrolling even if content fits
              itemCount: sortedPlayerScores.length,
              itemBuilder: (context, index) {
                final entry = sortedPlayerScores[index];
                String playerName = entry.key;
                SchockenScore score = entry.value;
                Color? highlightColor;
                if (playerName == _game.roundWinnerName) highlightColor = Colors.green.shade100;
                if (playerName == _game.roundLoserName) highlightColor = Colors.red.shade100;
                int lidIndex = score.lidValue - 1;
                bool validLidIndex = DiceAssetPaths.lidUrls != null && lidIndex >= 0 && lidIndex < DiceAssetPaths.lidUrls!.length;
                String lidAssetPath = validLidIndex ? DiceAssetPaths.lidUrls![lidIndex] : '';

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                  padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
                  decoration: BoxDecoration(color: highlightColor, borderRadius: BorderRadius.circular(6)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(flex: 3, child: Text(playerName, style: itemStyle, overflow: TextOverflow.ellipsis, maxLines: 1)),
                      SizedBox(
                        width: lidImageSize + 10,
                        child: Align(
                          alignment: Alignment.center,
                          // NEUE LOGIK: Zeige nur Deckel > 0
                          child: (validLidIndex && lidAssetPath.isNotEmpty && score.lidValue > 0)
                              ? Image.asset(lidAssetPath, width: lidImageSize, height: lidImageSize, errorBuilder: (_,__,___) => Icon(Icons.circle, size: lidImageSize * 0.6, color: Colors.grey[600]))
                              : Icon(Icons.circle_outlined, size: lidImageSize * 0.6, color: Colors.grey[600]), // NEU: Korrektes Fallback-Icon
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: score.diceValues.map((diceValue) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3.0),
                          child: SizedBox(
                            width: diceSize,
                            height: diceSize / DiceAssetDisplay.diceAspectRatio,
                            child: DiceAssetDisplay(value: diceValue),
                          ),
                        )).toList(),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

        ],
      ),
    );
  }


  Widget _buildDiceArea() {
    if (_game.rollsLeft == 3) {
      const double defaultCupSize = 250.0;
      return Center(
        child: Image.asset(
          DiceAssetPaths.diceCupUrl,
          width: defaultCupSize,
          height: defaultCupSize,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(Icons.casino, size: defaultCupSize, color: Colors.white),
        ),
      );
    }

    // Dice display area
    final double diceSize = MediaQuery.of(context).size.width * 0.28;
    List<Widget> diceWidgets = List.generate(3, (index) {
      return SizedBox(
        width: diceSize,
        height: diceSize / DiceAssetDisplay.diceAspectRatio,
        child: DiceAssetDisplay(
          value: _game.currentDiceValues[index],
          isHeld: _game.heldDiceIndices.contains(index),
          onTap: () => _game.handleDiceTap(index),
        ),
      );
    });

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        diceWidgets[0],
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            diceWidgets[1],
            const SizedBox(width: 12),
            diceWidgets[2],
          ],
        ),
      ],
    );
  }

  Widget _buildGameButtons() {
    final bool canRollAgain = (_game.currentPlayerIndex == _game.loserIndexAtStartOfRound || (3 - _game.rollsLeft) < _game.maxRollsInRound) && _game.rollsLeft > 0;
    if (_game.rollsLeft == 3) {
      return _buildActionButton('WÜRFELN', _game.rollDice, isPrimary: true);
    } else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton('LASSEN', () => _game.endTurn(false)),
          _buildActionButton('NOCHMAL', canRollAgain ? _game.rollDice : null),
        ],
      );
    }
  }

  Widget _buildActionButton(String text, VoidCallback? onPressed, {bool isPrimary = false}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final double primaryWidth = (screenWidth * 0.7).clamp(240.0, 300.0);
    final double secondaryWidth = (screenWidth * 0.4).clamp(150.0, 190.0);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.0),
        boxShadow: [BoxShadow(color: Colors.black, spreadRadius: 0, blurRadius: 0, offset: const Offset(4, 6))],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.black,
          backgroundColor: const Color(0xFFFFFFFF),
          disabledBackgroundColor: const Color(0xFFFFFFFF),
          minimumSize: Size(isPrimary ? primaryWidth : secondaryWidth, 60),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
          elevation: 0,
        ),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 28)),
      ),
    );
  }

  Widget _buildScoreboardContainer() {
    if (_game.isRoundFinished && (_game.areResultsCalculated || _isRevealSequenceRunning)) {
      return const SizedBox.shrink();
    }
    // Give the container a maximum height to allow internal scrolling
    // Adjust this value based on how much space you want the scoreboard to take at most
    final double maxScoreboardHeight = MediaQuery.of(context).size.height * 0.25;

    return Container(
      constraints: BoxConstraints(maxHeight: maxScoreboardHeight), // Apply max height constraint
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: const [BoxShadow(color: Colors.black, spreadRadius: 0, blurRadius: 0, offset: Offset(5, 7))],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: _buildScoreboardContent(), // Content needs to handle scrolling
    );
  }

  Widget _buildScoreboardContent() {
    const headerStyle = TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16);
    const cellStyle = TextStyle(color: Colors.black, fontSize: 14);
    final screenWidth = MediaQuery.of(context).size.width;
    final double lidImageSize = (screenWidth * 0.09).clamp(30.0, 45.0);
    final double diceSize = (screenWidth * 0.07).clamp(25.0, 35.0);
    Color currentHighlightColor = Colors.grey.shade300;

    // This Column determines the content structure INSIDE the scrollable area
    return Column(
      mainAxisSize: MainAxisSize.min, // Takes minimum required height initially
      children: [
        // Header Row (fixed)
        Row(
          children: [
            const Expanded(flex: 3, child: Text('SPIELER', style: headerStyle)),
            const Expanded(flex: 3, child: Center(child: Text('WURF', style: headerStyle))),

            const Expanded(flex: 2, child: Center(child: Text('DECKEL', style: headerStyle))),

            const Expanded(flex: 1, child: Center(child: Text('HZ', style: headerStyle))),
          ],
        ),
        const Divider(color: Colors.black54, thickness: 2),
        // Scrollable Player List
        Flexible( // Make the ListView flexible to fill the ConstrainedBox from parent
          child: ListView.builder(
            shrinkWrap: true, // Let ListView determine its height based on children
            // Remove physics: NeverScrollableScrollPhysics() to ALLOW scrolling
            itemCount: widget.playerNames.length,
            itemBuilder: (context, index) {
              // NEU: Prüfen, ob Spieler aktiv ist
              final bool isPlayerActive = _game.activePlayers[index];
              final isCurrent = index == _game.currentPlayerIndex && !_game.isRoundFinished;
              final score = _game.playerScores[index];
              final lidCount = _game.playerLids[index];
              int lidIndex = lidCount - 1;
              bool validLidIndex = DiceAssetPaths.lidUrls != null && lidIndex >= 0 && lidIndex < DiceAssetPaths.lidUrls!.length;
              String lidAssetPath = validLidIndex ? DiceAssetPaths.lidUrls![lidIndex] : '';

              return Container(
                // NEU: Hintergrund für inaktive Spieler
                color: !isPlayerActive ? Colors.grey.shade100 : (isCurrent ? currentHighlightColor : Colors.transparent),
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        widget.playerNames[index],
                        style: cellStyle.copyWith(
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          // NEU: Farbe für inaktive Spieler
                          color: !isPlayerActive ? Colors.grey.shade500 : Colors.black,
                        ),
                        overflow: TextOverflow.ellipsis, maxLines: 1,
                      ),
                    ),
                    Expanded(
                        flex: 3,
                        child: Center(
                          // NEU: Wurf nur anzeigen, wenn Spieler aktiv war
                          child: isPlayerActive && score != null
                              ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(3, (diceIndex) {
                              bool isVisible = score.diceCount < 3 || score.heldDiceIndices.contains(diceIndex);
                              final int displayValue = isVisible ? score.diceValues[diceIndex] : 0;
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                                child: SizedBox(
                                  width: diceSize, height: diceSize / DiceAssetDisplay.diceAspectRatio,
                                  child: DiceAssetDisplay(value: displayValue),
                                ),
                              );
                            }),
                          ) : Text('...', style: cellStyle.copyWith(color: !isPlayerActive ? Colors.grey.shade400 : Colors.black54)), // NEU: Farbe für inaktive
                        )
                    ),

                    Expanded(
                      flex: 2,
                      child: Center(
                        child: lidCount > 0 && validLidIndex
                        // NEU: Farbe für inaktive
                            ? Image.asset(lidAssetPath, width: lidImageSize, height: lidImageSize, errorBuilder: (_,__,___) => Icon(Icons.circle, size: lidImageSize * 0.6, color: !isPlayerActive ? Colors.grey.shade400 : Colors.black54))
                            : Icon(Icons.circle_outlined, size: lidImageSize * 0.6, color: !isPlayerActive ? Colors.grey.shade400 : Colors.black54), // NEU: Farbe für inaktive
                      ),
                    ),

                    Expanded(
                      flex: 1,
                      child: Center(
                        child: Icon(
                          _game.playerHalfLosses[index] >= 1 ? Icons.pie_chart : Icons.circle_outlined,
                          color: !isPlayerActive ? Colors.grey.shade400 : Colors.black, size: 26, // NEU: Farbe für inaktive
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInfoOverlay() {
    final titleStyle = const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold);
    final itemStyle = const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold);
    final diceSize = MediaQuery.of(context).size.width * 0.12;
    final double lidImageSize = (MediaQuery.of(context).size.width * 0.1).clamp(40.0, 55.0);
    List<SchockenScore> rankedCombinations = _getRankedCombinations();

    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _isInfoOverlayVisible = false),
        child: Container(
          color: Colors.black.withOpacity(0.85),
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.height * 0.75,
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                    color: const Color(0xFFFA4848),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white, width: 5)
                ),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Text("Wertigkeiten", style: titleStyle, textAlign: TextAlign.left),
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 30),
                            onPressed: () => setState(() => _isInfoOverlayVisible = false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    const Divider(thickness: 3, color: Colors.white),
                    Expanded(
                      child: ListView.builder(
                        itemCount: rankedCombinations.length,
                        itemBuilder: (context, index) {
                          final score = rankedCombinations[index];
                          int lidIndex = score.lidValue -1;
                          bool validLidIndex = DiceAssetPaths.lidUrls != null && lidIndex >= 0 && lidIndex < DiceAssetPaths.lidUrls!.length;
                          String lidAssetPath = validLidIndex ? DiceAssetPaths.lidUrls![lidIndex] : '';

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(flex: 50, child: Text(score.typeString, style: itemStyle, overflow: TextOverflow.ellipsis)),
                                SizedBox(
                                  width: lidImageSize,
                                  child: Align(
                                    alignment: Alignment.center,
                                    // NEUE LOGIK: Zeige nur Deckel > 0
                                    child: (validLidIndex && score.lidValue > 0)
                                        ? Image.asset(lidAssetPath, width: lidImageSize, height: lidImageSize, errorBuilder: (_,__,___) => Icon(Icons.circle, size: lidImageSize * 0.1, color: Colors.grey[600]))
                                        : Icon(Icons.circle_outlined, size: lidImageSize * 0.6, color: Colors.grey[600]), // NEU: Korrektes Fallback-Icon
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: score.diceValues.map((diceValue) => Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 1.0),
                                    child: SizedBox(
                                      width: diceSize,
                                      height: diceSize / DiceAssetDisplay.diceAspectRatio,
                                      child: DiceAssetDisplay(value: diceValue),
                                    ),
                                  )).toList(),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<SchockenScore> _getRankedCombinations() {
    List<SchockenScore> combos = [
      SchockenScore(type: SchockenRollType.schockOut, value: 7, lidValue: 13, diceCount: 1, diceValues: [1, 1, 1], heldDiceIndices: [], playerIndex: 1),
      SchockenScore(type: SchockenRollType.schockX, value: 6, lidValue: 6, diceCount: 1, diceValues: [6, 1, 1], heldDiceIndices: [], playerIndex: 1),
      SchockenScore(type: SchockenRollType.schockX, value: 5, lidValue: 5, diceCount: 1, diceValues: [5, 1, 1], heldDiceIndices: [], playerIndex: 1),
      SchockenScore(type: SchockenRollType.schockX, value: 4, lidValue: 4, diceCount: 1, diceValues: [4, 1, 1], heldDiceIndices: [], playerIndex: 1),
      SchockenScore(type: SchockenRollType.schockX, value: 3, lidValue: 3, diceCount: 1, diceValues: [3, 1, 1], heldDiceIndices: [], playerIndex: 1),
      SchockenScore(type: SchockenRollType.schockX, value: 2, lidValue: 2, diceCount: 1, diceValues: [2, 1, 1], heldDiceIndices: [], playerIndex: 1),
      SchockenScore(type: SchockenRollType.pasch, value: 6, lidValue: 3, diceCount: 1, diceValues: [6, 6, 6], heldDiceIndices: [], playerIndex: 1),
      SchockenScore(type: SchockenRollType.pasch, value: 5, lidValue: 3, diceCount: 1, diceValues: [5, 5, 5], heldDiceIndices: [], playerIndex: 1),
      SchockenScore(type: SchockenRollType.pasch, value: 4, lidValue: 3, diceCount: 1, diceValues: [4, 4, 4], heldDiceIndices: [], playerIndex: 1),
      SchockenScore(type: SchockenRollType.pasch, value: 3, lidValue: 3, diceCount: 1, diceValues: [3, 3, 3], heldDiceIndices: [], playerIndex: 1),
      SchockenScore(type: SchockenRollType.pasch, value: 2, lidValue: 3, diceCount: 1, diceValues: [2, 2, 2], heldDiceIndices: [], playerIndex: 1),
      SchockenScore(type: SchockenRollType.straight, value: 456, lidValue: 2, diceCount: 1, diceValues: [4, 5, 6], heldDiceIndices: [], playerIndex: 1),
      SchockenScore(type: SchockenRollType.straight, value: 345, lidValue: 2, diceCount: 1, diceValues: [3, 4, 5], heldDiceIndices: [], playerIndex: 1),
      SchockenScore(type: SchockenRollType.straight, value: 234, lidValue: 2, diceCount: 1, diceValues: [2, 3, 4], heldDiceIndices: [], playerIndex: 1),
      SchockenScore(type: SchockenRollType.straight, value: 123, lidValue: 2, diceCount: 1, diceValues: [1, 2, 3], heldDiceIndices: [], playerIndex: 1),
      SchockenScore(type: SchockenRollType.simple, value: 665, lidValue: 1, diceCount: 1, diceValues: [6, 6, 5], heldDiceIndices: [], playerIndex: 1),
      SchockenScore(type: SchockenRollType.simple, value: 221, lidValue: 1, diceCount: 1, diceValues: [2, 2, 1], heldDiceIndices: [], playerIndex: 1),
    ];
    combos.sort((a, b) => b.isBetterThan(a) ? 1 : -1);
    return combos;
  }
}

