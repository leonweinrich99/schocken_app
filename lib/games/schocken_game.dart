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
    // _game.dispose(); // Wichtig, falls SchockenGame Ressourcen verwendet (aktuell nicht)
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
    sortedScores.sort((a, b) {
      if (a == null && b == null) return 0;
      if (a == null) return 1;
      if (b == null) return -1;
      return a.isBetterThan(b) ? -1 : 1;
    });
    final bestScore = sortedScores.first;


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
            Column(
              children: [
                // 1. HEADER mit Info-Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 30.0),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Titel
                      const Center(
                        child: Text(
                            'SCHOCKEN',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              shadows: [
                                Shadow(
                                  color: Colors.black, // Farbe des Schattens mit Deckkraft
                                  offset: Offset(6, 0),                // Horizontale (dx) und vertikale (dy) Verschiebung
                                  blurRadius: 0,                       // Weichzeichner-Radius
                                ),
                              ],
                              )),
                      ),
                      // Zurück-Button
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
                          onPressed: widget.onGameQuit, // Callback an main.dart
                        ),
                      ),
                      // Info/Close-Button NEU
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
                // Alte Text-Anzeige (Wurf/Deckel Mitte) entfernt
                // 2. HAUPTBEREICH (JETZT MIT FLEXIBLE)
                Flexible( // Ersetzt Expanded
                  fit: FlexFit.tight, // Nimmt verfügbaren Platz, kann aber schrumpfen
                  child: Padding(
                    // Mehr Padding oben, um Platz für die schwebenden Indikatoren zu machen
                    padding: const EdgeInsets.only(top: 20.0, left: 16.0, right: 16.0), // Padding oben reduziert
                    child: _buildMainContentArea(),
                  ),
                ),
                // 3. BUTTON-BEREICH
                _buildButtonArea(),
                // 4. SCOREBOARD (Jetzt mit weißem Hintergrund und Schatten)
                Padding( // Padding hinzugefügt, um Abstand nach unten zu schaffen
                  padding: const EdgeInsets.only(bottom: 30.0), // Abstand nach unten
                  child: _buildScoreboardContainer(), // Wrapper-Container für Styling
                ),

              ],
            ),
            // NEU: Schwebende Statusanzeigen (Wurf & Deckel)
            if (!_isInfoOverlayVisible && !_isRevealSequenceRunning && !_game.isRoundFinished)
              _buildGameStatusIndicators(), // Wird im Stack positioniert
            // 5. ANIMATIONS-OVERLAY
            _buildAnimationOverlay(),
            // 6. INFO-OVERLAY NEU
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
    String lidAssetPath = validLidIndex ? DiceAssetPaths.lidUrls![lidIndex] : ''; // Fallback


    // Würfelbild für Wurfnummer
    bool validDiceIndex = currentRollNumber >= 1 && currentRollNumber <= 6;
    // Sicherstellen, dass der Index gültig ist und diceUrls existiert
    String diceAssetPath = validDiceIndex && DiceAssetPaths.diceUrls.length >= currentRollNumber
        ? DiceAssetPaths.diceUrls[currentRollNumber - 1]
        : ''; // Fallback


    // Stil für den Text unter den Bildern
    const indicatorTextStyle = TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w900); // Schriftgröße angepasst
    const double indicatorSize = 70.0; // Größe der Indikator-Boxen


    return Positioned(
        top: 100, // Abstand vom oberen Rand (unter dem Header) - Anpassen nach Bedarf
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
                      ? Image.network( // Image.network für lokale Dateien
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
                      ? Image.network( // Image.network für lokale Dateien
                    lidAssetPath,
                    height: indicatorSize * 0.5,
                    fit: BoxFit.contain,
                    errorBuilder: (_,__,___) => Icon(Icons.circle, size: indicatorSize * 0.5, color: Colors.black), // Fallback geändert
                  )
                      : Icon(Icons.circle_outlined, size: indicatorSize * 0.5, color: Colors.black), // Fallback für 0 Deckel
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
    // Greift auf _game.isRoundFinished etc. zu
    if (_game.isRoundFinished && !_game.areResultsCalculated && !_isRevealSequenceRunning) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.network( // Korrigiert zurück zu Image.network
            DiceAssetPaths.diceCupUrl,
            width: 300,
            height: 300,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(Icons.casino, size: 300, color: Colors.white),
          ),
        ],
      );
      // ANPASSUNG: Zeigt immer _buildResultDisplay während der Ergebnisphase, auch während der Animation
    } else if (_game.isRoundFinished && (_game.areResultsCalculated || _isRevealSequenceRunning)) {
      return _buildResultDisplay();
    } else { // Normaler Spielzug
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildDiceArea(),
        ],
      );
    }
  }

  Widget _buildButtonArea() {
    const buttonPadding = EdgeInsets.only(bottom: 24.0, top: 10.0); // Padding angepasst
    // Ergebnistext wird jetzt in _buildResultDisplay angezeigt

    Widget buttonWidget;

    // Greift auf _game.isRoundFinished etc. zu
    if (_game.isRoundFinished && !_game.areResultsCalculated && !_isRevealSequenceRunning) {
      buttonWidget = _buildActionButton('AUFDECKEN', _startRevealAnimationSequence, isPrimary: true);
    } else if (_game.isRoundFinished && _game.areResultsCalculated) {
      String buttonText = _game.wasGameLost ? 'SPIEL BEENDEN' : _game.wasHalfLost ? 'NÄCHSTE HALBZEIT' : 'NÄCHSTE RUNDE';
      // Ruft _game.startNextRoundOrHalf auf
      VoidCallback nextAction = () {
        if(_game.wasGameLost) {
          widget.onGameQuit(); // Callback an main.dart
        } else {
          _game.startNextRoundOrHalf();
        }
      };
      buttonWidget = _buildActionButton(buttonText, nextAction, isPrimary: true);
    } else if (!_game.isRoundFinished && !_isRevealSequenceRunning) {
      buttonWidget = _buildGameButtons(); // Ruft UI-interne Methode auf
    } else {
      buttonWidget = const SizedBox(height: 80); // Angepasste Platzhalter Höhe (größere Buttons)
    }

    // ANPASSUNG: Nur noch der Button wird hier gebaut
    return Padding(
      padding: buttonPadding,
      child: buttonWidget,
    );
  }

  Widget _buildAnimationOverlay() {
    return Center(
      child: IgnorePointer( // Macht das Overlay nicht klickbar
        child: SlideTransition(
          position: _slideAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12), // Padding angepasst
                decoration: BoxDecoration(
                  color: Color(0xFFFA4848), // Hintergrundfarbe angepasst
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white, width: 3), // Border angepasst
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
    final titleStyle = const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold);
    final playerNameStyle = const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold);
    final diceSize = MediaQuery.of(context).size.width * 0.18;
    final resultStyle = const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold); // Stil für Ergebnistext

    // Ergebnistext wird hier definiert
    String resultText = "";
    if (_game.roundLoserName != null && _game.areResultsCalculated) {
      resultText = _game.wasHalfLost
          ? '${_game.roundLoserName} hat eine Halbzeit verloren!'
          : '${_game.roundLidsTransferred} Deckel gehen an ${_game.roundLoserName}'; // Angepasster Text
    }


    return Column( // Column umschließt alles für linksbündigen Titel
      crossAxisAlignment: CrossAxisAlignment.start, // Titel linksbündig
      children: [
        const SizedBox(height: 20.0), // Abstand über dem Titel hinzugefügt
        Text("Ergebnisliste", style: titleStyle), // Titel geändert und linksbündig
        const SizedBox(height: 20),
        const Divider(color: Colors.white, thickness: 3), // Divider hinzugefügt
        const SizedBox(height: 20),
        Center( // Zentriert den Rest des Inhalts horizontal
          child: SingleChildScrollView( // Wichtig, falls viele Spieler
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center, // Zentriert vertikal
              children: [
                ...widget.playerNames.asMap().entries.map((entry) {
                  int playerIndex = entry.key;
                  String playerName = entry.value;
                  SchockenScore? score = _game.playerScores[playerIndex];
                  if (score == null) return const SizedBox.shrink();

                  Color borderColor = Colors.transparent;
                  if (playerName == _game.roundWinnerName) {
                    borderColor = Colors.white;
                  } else if (playerName == _game.roundLoserName) {
                    borderColor = Colors.black;
                  }

                  BoxDecoration decoration = BoxDecoration(
                    border: Border.all(color: borderColor, width: 3),
                    borderRadius: BorderRadius.circular(8),
                  );

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 6.0),
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                    decoration: decoration,
                    child: Row(
                      mainAxisSize: MainAxisSize.min, // Passt Breite an Inhalt an
                      children: [
                        Expanded(
                            child: Text(
                              playerName,
                              style: playerNameStyle,
                              overflow: TextOverflow.ellipsis, // Verhindert Überlauf bei langen Namen
                              maxLines: 1,
                            )
                        ),
                        const SizedBox(width: 10), // Abstand
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: score.diceValues.map((diceValue) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: SizedBox(
                                width: diceSize,
                                height: diceSize / DiceAssetDisplay.diceAspectRatio,
                                child: DiceAssetDisplay(value: diceValue),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  );
                }),
                // Ergebnistext wird jetzt im ButtonArea angezeigt
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDiceArea() {
    // Greift auf _game.rollsLeft zu
    if (_game.rollsLeft == 3) {
      return Image.network( // Korrigiert zurück zu Image.network
        DiceAssetPaths.diceCupUrl,
        width: 300,
        height: 300,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(Icons.casino, size: 300, color: Colors.white),
      );
    }

    final double diceSize = MediaQuery.of(context).size.width * 0.28;

    List<Widget> diceWidgets = List.generate(3, (index) {
      return SizedBox(
        width: diceSize,
        height: diceSize / DiceAssetDisplay.diceAspectRatio,
        child: DiceAssetDisplay(
          // Greift auf _game.currentDiceValues etc. zu
          value: _game.currentDiceValues[index],
          isHeld: _game.heldDiceIndices.contains(index),
          // Ruft _game.handleDiceTap auf
          onTap: () => _game.handleDiceTap(index),
        ),
      );
    });

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
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

  // Diese Funktion baut nur die Buttons, enthält keine Logik mehr
  Widget _buildGameButtons() {
    // Greift auf _game.rollsLeft etc. zu
    // KORRIGIERTER ZUGRIFF AUF GETTER
    final bool canRollAgain = (_game.currentPlayerIndex == _game.loserIndexAtStartOfRound || (3 - _game.rollsLeft) < _game.maxRollsInRound) && _game.rollsLeft > 0;


    if (_game.rollsLeft == 3) {
      // Ruft _game.rollDice auf
      return _buildActionButton('WÜRFELN', _game.rollDice, isPrimary: true);
    } else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Ruft _game.endTurn auf
          _buildActionButton('LASSEN', () => _game.endTurn(false)),
          // Ruft _game.rollDice auf
          _buildActionButton('NOCHMAL', canRollAgain ? _game.rollDice : null),
        ],
      );
    }
  }

  /// Baut einen Button mit neuem Styling (größer, kein Rand, Schatten)
  Widget _buildActionButton(String text, VoidCallback? onPressed, {bool isPrimary = false}) {
    return Container( // Container für den Schatten
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black, // Schattenfarbe angepasst
            spreadRadius: 0,
            blurRadius: 0,
            offset: const Offset(4, 6), // Schatten nach unten rechts
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.black,
          backgroundColor: const Color(0xFFD9D9D9),
          disabledBackgroundColor: Colors.grey.shade400,
          minimumSize: Size(isPrimary ? 280 : 170, 60), // GRÖSSERE BUTTONS
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
            // side: const BorderSide(color: Colors.black, width: 2), // RAND ENTFERNT
          ),
          elevation: 0, // Elevation wird durch BoxShadow ersetzt
          // shadowColor: Colors.transparent, // Kein Button-eigener Schatten
        ),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 28)), // Größere Schrift
      ),
    );
  }

  // --- SCOREBOARD STYLING ---
  /// Wrapper-Container für das Scoreboard-Styling (Hintergrund, Schatten)
  Widget _buildScoreboardContainer() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0), // Optionaler seitlicher Abstand
      decoration: BoxDecoration(
        color: Colors.white, // Weißer Hintergrund
        borderRadius: BorderRadius.circular(12.0), // Leicht abgerundete Ecken
        boxShadow: const [
          BoxShadow(
            color: Colors.black, // Harter Schatten
            spreadRadius: 0,
            blurRadius: 0,
            offset: Offset(5, 7), // Schatten nach unten rechts
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16), // Innerer Abstand
      child: _buildScoreboardContent(), // Der eigentliche Inhalt des Scoreboards
    );
  }


  /// Baut den Inhalt des Scoreboards (jetzt mit schwarzen Textfarben etc.)
  Widget _buildScoreboardContent() {
    const headerStyle = TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 24); // Angepasst
    const cellStyle = TextStyle(color: Colors.black, fontSize: 22); // Angepasst
    final double lidImageSize = 40.0; // Angepasste Größe
    Color currentHighlightColor = Color(0xFFFA4848); // Highlight für aktuellen Spieler

    Widget verticalDivider() => Container(height: 25, width: 1.5, color: Colors.black26); // Angepasste Farbe

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Expanded(flex: 3, child: Text('SPIELER', style: headerStyle)),
            const Expanded(flex: 3, child: Center(child: Text('WURF', style: headerStyle))),
            const Expanded(flex: 2, child: Center(child: Text('DECKEL', style: headerStyle))),
            const Expanded(flex: 1, child: Center(child: Text('HZ', style: headerStyle))),
          ],
        ),
        const Divider(color: Colors.black54, thickness: 2), // Angepasste Farbe & Dicke

        ...List.generate(widget.playerNames.length, (index) {
          final isCurrent = index == _game.currentPlayerIndex && !_game.isRoundFinished;
          final score = _game.playerScores[index];
          final lidCount = _game.playerLids[index];
          int lidIndex = lidCount - 1;
          bool validLidIndex = DiceAssetPaths.lidUrls != null && lidIndex >= 0 && lidIndex < DiceAssetPaths.lidUrls!.length;
          String lidAssetPath = validLidIndex ? DiceAssetPaths.lidUrls![lidIndex] : '';


          return Container( // Container für optionales Highlighting
            //color: isCurrent ? currentHighlightColor : Colors.transparent, // Hintergrund für aktuellen Spieler
            padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0), // Vertikaler Abstand für Zeilen
            decoration: isCurrent ? BoxDecoration(
                color: const Color(0xFFFA4848), // Angepasste Hintergrundfarbe
                borderRadius: BorderRadius.circular(12), // Angepasster Radius
                border: Border.all(color: Colors.white, width: 1) // Angepasste Border
            ) : BoxDecoration(
                color: Colors.transparent, // Angepasste Hintergrundfarbe
                borderRadius: BorderRadius.circular(1), // Angepasster Radius
                border: Border.all(color: Colors.white, width: 1) // Angepasste Border
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    widget.playerNames[index],
                    style: cellStyle.copyWith(
                      color: isCurrent ? Colors.white : Colors.black,
                      fontWeight: isCurrent ? FontWeight.normal : FontWeight.bold
                    ),
                  ),
                ),
                Expanded(
                    flex: 3,
                    child: Center(
                      child: score != null
                          ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (diceIndex) {
                          bool isVisible = score.diceCount < 3 || score.heldDiceIndices.contains(diceIndex);
                          final int displayValue = isVisible ? score.diceValues[diceIndex] : 0;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2.0), // Weniger Abstand
                            child: SizedBox(
                              width: 30, // Kleinere Würfel im Scoreboard
                              height: 30 / DiceAssetDisplay.diceAspectRatio,
                              child: DiceAssetDisplay(value: displayValue),
                            ),
                          );
                        }),
                      ) : Text('...', style: cellStyle.copyWith(color: Colors.black54)), // Angepasste Farbe
                    )
                ),
                Expanded(
                  flex: 2,
                  child: Center(
                    child: lidCount > 0 && validLidIndex
                        ? Image.network( // Image.network für lokale Dateien
                      lidAssetPath,
                      width: lidImageSize,
                      height: lidImageSize,
                      errorBuilder: (_,__,___) => Icon(Icons.circle, size: lidImageSize * 0.6, color: Colors.black54), // Angepasste Farbe
                    )
                        : Icon(Icons.circle_outlined, size: lidImageSize * 0.6, color: Colors.black54), // Angepasste Farbe
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Center(
                    child: Icon(
                      _game.playerHalfLosses[index] >= 1 ? Icons.pie_chart : Icons.circle_outlined,
                      color: Colors.black, // Angepasste Farbe
                      size: 26,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }


  // --- Widget für das Info-Overlay (ANGEPASST) ---
  Widget _buildInfoOverlay() {
    final titleStyle = const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold);
    final itemStyle = const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold);
    final diceSize = MediaQuery.of(context).size.width * 0.12;
    final double lidImageSize = 50.0; // Größe für Deckelbilder im Overlay

    // Erzeugt eine Liste von Beispiel-Scores für die Anzeige
    List<SchockenScore> rankedCombinations = _getRankedCombinations();

    return Positioned.fill(
      child: GestureDetector(
        // Schließt das Overlay, wenn man auf den Hintergrund klickt
        onTap: () => setState(() => _isInfoOverlayVisible = false),
        child: Container(
          color: Colors.black.withOpacity(0.85), // Halbtransparenter Hintergrund
          child: Center(
            child: GestureDetector( // Verhindert Schließen bei Klick IN die Box
              onTap: () {},
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9, // 90% der Breite
                height: MediaQuery.of(context).size.height * 0.75, // Etwas höher
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                    color: const Color(0xFFFA4848), // Angepasste Hintergrundfarbe
                    borderRadius: BorderRadius.circular(16), // Angepasster Radius
                    border: Border.all(color: Colors.white, width: 5) // Angepasste Border
                ),
                child: Column(
                  children: [
                    // Titel und Schließen-Button
                    Stack(
                      alignment: Alignment.centerLeft, // Titel linksbündig
                      children: [
                        Text("Wertigkeiten", style: titleStyle, textAlign: TextAlign.left), // Angepasste Ausrichtung
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
                    const Divider(thickness: 3, color: Colors.white), // Angepasste Dicke
                    // Liste der Kombinationen
                    Expanded(
                      child: ListView.builder(
                        itemCount: rankedCombinations.length,
                        itemBuilder: (context, index) {
                          final score = rankedCombinations[index];
                          // Index für das Deckelbild (0-basiert)
                          int lidIndex = score.lidValue -1;
                          // Sicherstellen, dass der Index gültig ist
                          // VERWENDET JETZT DiceAssetPaths.lidUrls KORREKT
                          bool validLidIndex = DiceAssetPaths.lidUrls != null && lidIndex >= 0 && lidIndex < DiceAssetPaths.lidUrls!.length;
                          String lidAssetPath = validLidIndex ? DiceAssetPaths.lidUrls![lidIndex] : ''; // Fallback


                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0), // Mehr vertikaler Abstand
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Name der Kombination
                                Expanded(
                                    flex: 3, // Mehr Platz für den Namen
                                    child: Text(score.typeString, style: itemStyle, overflow: TextOverflow.ellipsis)
                                ),
                                // Deckel-Bild (eigene Spalte)
                                SizedBox( // Feste Breite für die Deckelspalte
                                  width: lidImageSize + 30, // Bildgröße + Padding
                                  child: Align( // Zentriert das Bild
                                    alignment: Alignment.center,
                                    child: validLidIndex
                                        ? Image.network( // Korrigiert zurück zu Image.network
                                      lidAssetPath,
                                      width: lidImageSize,
                                      height: lidImageSize,
                                      errorBuilder: (_,__,___) => Icon(Icons.circle, size: lidImageSize * 0.1, color: Colors.grey[600]),
                                    )
                                        : Icon(Icons.circle, size: lidImageSize * 0.1, color: Colors.grey[600]), // Fallback
                                  ),
                                ),

                                // Würfelbilder
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: score.diceValues.map((diceValue) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 3.0),
                                      child: SizedBox(
                                        width: diceSize,
                                        height: diceSize / DiceAssetDisplay.diceAspectRatio,
                                        child: DiceAssetDisplay(value: diceValue),
                                      ),
                                    );
                                  }).toList(),
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

  // Hilfsfunktion zum Erzeugen der Beispiel-Scores für das Info-Overlay (ANGEPASST)
  List<SchockenScore> _getRankedCombinations() {
    // Verwendet die neue, von dir bereitgestellte Liste
    List<SchockenScore> combos = [
      SchockenScore(type: SchockenRollType.schockOut, value: 7, lidValue: 13, diceCount: 1, diceValues: [1, 1, 1], heldDiceIndices: []),
      SchockenScore(type: SchockenRollType.schockX, value: 6, lidValue: 6, diceCount: 1, diceValues: [6, 1, 1], heldDiceIndices: []),
      SchockenScore(type: SchockenRollType.schockX, value: 5, lidValue: 5, diceCount: 1, diceValues: [5, 1, 1], heldDiceIndices: []),
      SchockenScore(type: SchockenRollType.schockX, value: 4, lidValue: 4, diceCount: 1, diceValues: [4, 1, 1], heldDiceIndices: []), // Korrigierter Wert
      SchockenScore(type: SchockenRollType.schockX, value: 3, lidValue: 3, diceCount: 1, diceValues: [3, 1, 1], heldDiceIndices: []), // Korrigierter Wert
      SchockenScore(type: SchockenRollType.schockX, value: 2, lidValue: 2, diceCount: 1, diceValues: [2, 1, 1], heldDiceIndices: []),
      SchockenScore(type: SchockenRollType.pasch, value: 6, lidValue: 3, diceCount: 1, diceValues: [6, 6, 6], heldDiceIndices: []),
      SchockenScore(type: SchockenRollType.pasch, value: 5, lidValue: 3, diceCount: 1, diceValues: [5, 5, 5], heldDiceIndices: []),
      SchockenScore(type: SchockenRollType.pasch, value: 4, lidValue: 3, diceCount: 1, diceValues: [4, 4, 4], heldDiceIndices: []),
      SchockenScore(type: SchockenRollType.pasch, value: 3, lidValue: 3, diceCount: 1, diceValues: [3, 3, 3], heldDiceIndices: []),
      SchockenScore(type: SchockenRollType.pasch, value: 2, lidValue: 3, diceCount: 1, diceValues: [2, 2, 2], heldDiceIndices: []),
      SchockenScore(type: SchockenRollType.straight, value: 456, lidValue: 2, diceCount: 1, diceValues: [4, 5, 6], heldDiceIndices: []),
      SchockenScore(type: SchockenRollType.straight, value: 345, lidValue: 2, diceCount: 1, diceValues: [3, 4, 5], heldDiceIndices: []),
      SchockenScore(type: SchockenRollType.straight, value: 234, lidValue: 2, diceCount: 1, diceValues: [2, 3, 4], heldDiceIndices: []),
      SchockenScore(type: SchockenRollType.straight, value: 123, lidValue: 2, diceCount: 1, diceValues: [1, 2, 3], heldDiceIndices: []),
      SchockenScore(type: SchockenRollType.simple, value: 665, lidValue: 1, diceCount: 1, diceValues: [6, 6, 5], heldDiceIndices: []), // Beispiel höchste
      SchockenScore(type: SchockenRollType.simple, value: 221, lidValue: 1, diceCount: 1, diceValues: [2, 2, 1], heldDiceIndices: []), // Beispiel niedrigste
    ];


    // Sortiert die Liste absteigend nach Wertigkeit
    combos.sort((a, b) => b.isBetterThan(a) ? 1 : -1);
    return combos;
  }

}

