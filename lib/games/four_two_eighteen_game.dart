import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../widgets/dice_display.dart';
import '../logic/four_two_eighteen_game_logic.dart'; // Import der neuen Logik-Klasse

class FourTwoEighteenGameWidget extends StatefulWidget {
  final List<String> players;
  final VoidCallback onGameExit;

  const FourTwoEighteenGameWidget({super.key, required this.players, required this.onGameExit});

  @override
  State<FourTwoEighteenGameWidget> createState() => _FourTwoEighteenGameWidgetState();
}

class _FourTwoEighteenGameWidgetState extends State<FourTwoEighteenGameWidget> {
  late FourTwoEighteenGame _game;
  bool _isInfoOverlayVisible = false;
  // NEU: Cache für die Ergebnisse der letzten Runde
  Map<String, FourTwoEighteenScore> _lastRoundResults = {};

  @override
  void initState() {
    super.initState();
    _game = FourTwoEighteenGame(widget.players);
    _game.addListener(_onGameStateChanged);
  }

  @override
  void dispose() {
    _game.removeListener(_onGameStateChanged);
    _game.dispose();
    super.dispose();
  }

  void _onGameStateChanged() {
    // UI-Aktualisierung erzwingen
    setState(() {
      // Dialog-Logik
      if (_game.isRoundOver && !_game.isGameOver && !_isInfoOverlayVisible && mounted) {
        // KORREKTUR: Ergebnisse hier cachen, BEVOR der Dialog angezeigt wird
        // (da sie nach dem Dialog durch startNextRound() gelöscht werden)
        _lastRoundResults = Map.from(_game.roundResults);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _game.isRoundOver && !_game.isGameOver) {
            _showRoundResolutionDialog();
          }
        });
      }
      else if (_game.isGameOver && !_isInfoOverlayVisible && mounted) {
        // KORREKTUR: Ergebnisse auch hier cachen
        _lastRoundResults = Map.from(_game.roundResults);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _game.isGameOver) {
            _showGameOverDialog();
          }
        });
      }
    });
  }

  // --- UI Build Methoden ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFA4848), // Roter Hintergrund
      body: SafeArea(
        child: Stack( // Stack für Overlays
          children: [
            Column(
              children: [
                // 1. HEADER
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40.0),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: const Text('42 / 18', style: TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900)),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
                          onPressed: widget.onGameExit,
                        ),
                      ),
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
                const SizedBox(height: 40),
                // 2. HAUPTBEREICH (Brett) + BUTTONS (Jetzt in Expanded, wie bei Schocken)
                Expanded(
                    child: Column(
                      children: [
                        // Brett (nimmt den meisten Platz ein)
                        Flexible(
                          fit: FlexFit.loose,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
                            child: _buildMainContentArea(),
                          ),
                        ),

                        // Button-Bereich (unter dem Brett)
                        if (!_game.isGameOver) _buildButtonArea(),
                        if (_game.isGameOver) _buildRestartButtonArea(),
                      ],
                    )
                ),

                // 3. SCOREBOARD (Außerhalb Expanded, unten, scrollbar)
                SingleChildScrollView( // Ermöglicht das Scrollen des Scoreboards bei vielen Spielern
                  child: _buildScoreboardContainer(),
                ),
              ],
            ),

            // 5. STATUS-INDIKATOREN (ENTFERNT)

            // 6. INFO-OVERLAY
            if (_isInfoOverlayVisible) _buildInfoOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContentArea() {
// ... (Rest der Datei bleibt gleich) ...
    // Zeige Würfelbecher beim ersten Wurf
    if (_game.rollCount == 0 && !_game.isRoundOver && !_game.isGameOver) {
      final screenWidth = MediaQuery.of(context).size.width;
      final screenHeight = MediaQuery.of(context).size.height;
      final orientation = MediaQuery.of(context).orientation;
      final referenceSize = orientation == Orientation.portrait ? screenWidth : screenHeight;
      // Brett verkleinert, daher Becher auch etwas kleiner
      final maxSize = (referenceSize * 0.6).clamp(180.0, 250.0);

      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.02), // Abstand oben reduziert
          Image.asset(
            DiceAssetPaths.diceCupUrl,
            width: maxSize,
            height: maxSize,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(Icons.casino, size: maxSize, color: Colors.white),
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.05), // Abstand unten reduziert
        ],
      );
    } else if (_game.isGameOver) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 50.0),
          child: Text(
            _game.gameStatusMessage, // Zeigt Gewinner
            style: const TextStyle(
                color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Zeige Drag-and-Drop-Bereich
    return _buildDiceArea(); // Verwendet das "Brett"-Design
  }

  Widget _buildButtonArea() {
    final buttonPadding = const EdgeInsets.only(bottom: 15.0, top: 5.0);
    // final resultStyle = const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold); // Entfernt

    // Button-Logik basierend auf den neuen Regeln
    final int currentHeldCount = _game.heldDiceCount;
    // Kann würfeln, wenn: noch nicht 5 liegen UND (es der 1. Wurf ist ODER man seit dem letzten Wurf einen abgelegt hat)
    final bool canRoll = currentHeldCount < 5 &&
        (_game.rollCount == 0 || currentHeldCount > _game.diceHeldBeforeRoll);

    String buttonText;
    VoidCallback? onPressed;

    // KORREKTUR: Logik für den "ZUG BEENDEN" Button, wenn 4 & 2 fehlen
    if (currentHeldCount < 5 && !canRoll && !_game.canStillGetBasis()) {
      // Spieler kann nicht mehr würfeln (hat nichts abgelegt)
      // UND kann die Basis nicht mehr bekommen (z.B. 4 & 2 sind nicht bei den unheld dice)
      // UND die Basis ist noch nicht voll.
      buttonText = 'ZUG BEENDEN';
      onPressed = _game.endTurn; // Erlaube das Beenden des Zugs
    }
    else if (currentHeldCount == 5) {
      buttonText = 'ZUG BEENDET';
      onPressed = null; // Zug endet automatisch
    } else if (canRoll) {
      buttonText = 'NOCHMAL'; // Zähler entfernt
      onPressed = _game.roll;
    } else {
      buttonText = 'ABLEGEN!'; // Aufforderung, 1 Würfel abzulegen
      onPressed = null; // Deaktiviert, bis abgelegt wurde
    }

    return Padding(
      padding: buttonPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status-Text über dem Button entfernt
          // Padding(
          //   padding: const EdgeInsets.only(bottom: 10.0),
          //   child: Text(
          //     _game.gameStatusMessage,
          //     style: resultStyle,
          //     textAlign: TextAlign.center
          //   ),
          // ),
          const SizedBox(height: 20), // Platzhalter für entfernten Text
          // Nur noch ein zentrierter Button
          Center(
            child: _buildActionButton(
                buttonText,
                onPressed,
                isPrimary: true // Immer Primär-Button-Stil
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestartButtonArea() {
    final buttonPadding = const EdgeInsets.only(bottom: 15.0, top: 5.0);
    return Padding(
      padding: buttonPadding,
      // Platzhalter hinzugefügt, damit Button auf gleicher Höhe wie Spiel-Button ist
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 20),
          _buildActionButton('NEU STARTEN', _game.restartGame, isPrimary: true),
        ],
      ),
    );
  }


  /// Baut einen Button im Schocken-Stil
  Widget _buildActionButton(String text, VoidCallback? onPressed, {bool isPrimary = false}) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Breite angepasst für einen einzelnen Button
    final double primaryWidth = (screenWidth * 0.65).clamp(220.0, 280.0);
    final double secondaryWidth = (screenWidth * 0.4).clamp(140.0, 180.0); // Beibehalten, falls benötigt

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.0),
        boxShadow: const [
          BoxShadow(
            color: Colors.black,
            spreadRadius: 0,
            blurRadius: 0,
            offset: Offset(4, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.black,
          backgroundColor: const Color(0xFFD9D9D9),
          disabledBackgroundColor: Colors.grey.shade400,
          minimumSize: Size(isPrimary ? primaryWidth : secondaryWidth, 55),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          elevation: 0,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        ),
      ),
    );
  }

  // --- Drag & Drop UI (Brett-Design aus User-Snippet) ---

  Widget _buildDiceArea() {
    // Styling für die Slots (angepasst an User-Snippet + Hellgrau)
    final slotDecoration = BoxDecoration(
      color: const Color(0xFFEEEEEE), // HELLGRAU (wie gewünscht)
      borderRadius: BorderRadius.circular(8.0),
      border: Border.all(color: Colors.black26, width: 1), // Dezenter Rand
    );
    final slotDecorationOccupied = BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.black, width: 2)
    );

    // Style für die "4" und "2" (ENTFERNT)
    // final highlightLabelStyle = ...
    // Style for "..." (ENTFERNT)
    // final slotLabelStyle = ...


    return Column(
      children: [
        // 1. Ablageflächen (Weißer Kasten)
        Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10), // Padding reduziert
          decoration: BoxDecoration(
            color: Colors.white, // Weißer Kasten
            borderRadius: BorderRadius.circular(12.0),
            boxShadow: const [
              BoxShadow(color: Colors.black, spreadRadius: 0, blurRadius: 0, offset: Offset(5, 7)),
            ],
          ),
          child: Column(
            children: [
              // Basis 42 Sektion (Oben) - TEXT ENTFERNT
              // const Text("BASIS", ...),
              // const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildDragTargetSlot(
                    targetType: HoldPosition.basis4,
                    requiredValue: 4, // Zeigt '4'
                    heldIndices: _game.basisDice,
                    indexInArray: 0,
                    decoration: slotDecoration,
                    occupiedDecoration: slotDecorationOccupied,
                    labelStyle: const TextStyle(), // Ignoriert
                    highlightLabelStyle: const TextStyle(), // Ignoriert
                  ),
                  const SizedBox(width: 10), // Abstand reduziert
                  _buildDragTargetSlot(
                    targetType: HoldPosition.basis2,
                    requiredValue: 2, // Zeigt '2'
                    heldIndices: _game.basisDice,
                    indexInArray: 1,
                    decoration: slotDecoration,
                    occupiedDecoration: slotDecorationOccupied,
                    labelStyle: const TextStyle(), // Ignoriert
                    highlightLabelStyle: const TextStyle(), // Ignoriert
                  ),
                ],
              ),
              const SizedBox(height: 10), // Abstand reduziert
              // Score 18 Sektion (Unten) - TEXT ENTFERNT
              // Text(...),
              // const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0), // Abstand reduziert
                    child: _buildDragTargetSlot(
                      targetType: HoldPosition.score,
                      requiredValue: null, // Zeigt nichts
                      heldIndices: _game.scoreDice,
                      indexInArray: index,
                      decoration: slotDecoration,
                      occupiedDecoration: slotDecorationOccupied,
                      labelStyle: const TextStyle(), // Ignoriert
                      highlightLabelStyle: const TextStyle(), // Ignoriert
                    ),
                  );
                }),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20), // Abstand reduziert

        // 2. Aktive Würfel (Draggable)
        Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.9),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8.0, // Abstand reduziert
            runSpacing: 8.0, // Abstand reduziert
            children: List.generate(_game.currentDiceValues.length, (index) {
              final value = _game.currentDiceValues[index];
              final isHeld = _game.diceHeld[index];
              // Größe der Würfel angepasst an kleinere Slots
              final diceSize = (MediaQuery.of(context).size.width * 0.18).clamp(55.0, 70.0);

              if (isHeld) {
                return const SizedBox.shrink(); // Gehaltene Würfel nicht hier anzeigen
              }

              return SizedBox(
                width: diceSize,
                height: diceSize / DiceAssetDisplay.diceAspectRatio, // Seitenverhältnis beibehalten
                child: Draggable<int>(
                  data: index,
                  feedback: Opacity(
                    opacity: 0.7,
                    child: SizedBox(
                      width: diceSize,
                      height: diceSize / DiceAssetDisplay.diceAspectRatio,
                      child: DiceAssetDisplay(value: value, isHeld: true), // Feedback hervorheben
                    ),
                  ),
                  childWhenDragging: SizedBox( // Leerer Platz
                    width: diceSize,
                    height: diceSize / DiceAssetDisplay.diceAspectRatio,
                  ),
                  child: DiceAssetDisplay(
                    value: value,
                    isHeld: isHeld,
                    onTap: null, // Drag statt Tap
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }


  // Einzelner DragTarget Slot (Logik angepasst)
  Widget _buildDragTargetSlot({
    required HoldPosition targetType,
    int? requiredValue,
    required List<int?> heldIndices,
    required int indexInArray,
    required BoxDecoration decoration,
    required BoxDecoration occupiedDecoration,
    required TextStyle labelStyle,
    required TextStyle highlightLabelStyle,
  }) {
    final diceIndex = heldIndices[indexInArray];
    final isOccupied = diceIndex != null;
    final value = isOccupied ? _game.currentDiceValues[diceIndex] : null;

    // Responsive Größe (VERKLEINERT)
    final double slotSize = (MediaQuery.of(context).size.width * 0.18).clamp(55.0, 70.0); // Angepasst an Würfelgröße

    return DragTarget<int>(
      // KORRIGIERTE onWillAccept Logik
      onWillAcceptWithDetails: (data) {
        final diceValue = _game.currentDiceValues[data.data];
        if (isOccupied) return false; // Slot muss frei sein

        // Basis-Slots sind exklusiv
        if (targetType == HoldPosition.basis4) return diceValue == 4;
        if (targetType == HoldPosition.basis2) return diceValue == 2;

        // Score-Slots (unten)
        if (targetType == HoldPosition.score) {
          // Wenn es eine 4 ist, prüfe ob der Basis-4-Slot (oben) frei ist
          if (diceValue == 4 && _game.basisDice[0] == null) {
            return false; // Du musst die 4 erst oben reinlegen
          }
          // Wenn es eine 2 ist, prüfe ob der Basis-2-Slot (oben) frei ist
          if (diceValue == 2 && _game.basisDice[1] == null) {
            return false; // Du musst die 2 erst oben reinlegen
          }
          // Alle anderen (1,3,5,6) sind OK,
          // und 4/2 sind auch OK, wenn ihre Basis-Slots schon voll sind.
          return true;
        }

        return false;
      },
      onAccept: (diceIndex) {
        _game.setHeldDice(diceIndex, targetType);
      },
      builder: (context, candidateData, rejectedData) {
        bool canAccept = candidateData.isNotEmpty; // Nur für Highlight

        return GestureDetector(
          onTap: isOccupied ? () => _game.releaseHeldDice(diceIndex!) : null, // Freigeben durch Antippen
          child: Container(
            width: slotSize,
            height: slotSize, // Quadratische Slots
            decoration: isOccupied
                ? occupiedDecoration
                : decoration.copyWith( // Leerer Slot (Hellgrau)
              color: canAccept ? Colors.grey.shade300 : const Color(0xFFEEEEEE), // Dunkler bei Hover
              border: Border.all(
                  color: canAccept ? Colors.black : Colors.black26,
                  width: canAccept ? 2 : 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: isOccupied
                ? Center(
              child: SizedBox(
                width: slotSize * 0.9,
                height: (slotSize * 0.9) / DiceAssetDisplay.diceAspectRatio,
                child: DiceAssetDisplay(value: value!),
              ),
            )
                : Center( // Zeigt "4", "2" (ausgegraut) oder "..."
              child: requiredValue != null
                  ? Opacity( // JA: Zeige ausgegrauten Würfel
                opacity: 0.2, // Stark ausgegraut
                child: SizedBox(
                  width: slotSize * 0.9,
                  height: (slotSize * 0.9) / DiceAssetDisplay.diceAspectRatio,
                  child: DiceAssetDisplay(value: requiredValue),
                ),
              )
                  : Container(), // NEIN: Zeige nichts (nur hellgrauen Hintergrund)
            ),
          ),
        );
      },
    );
  }

  // --- Scoreboard (Angepasst für "Leben") ---

  Widget _buildScoreboardContainer() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: const [
          BoxShadow(
            color: Colors.black,
            spreadRadius: 0,
            blurRadius: 0,
            offset: Offset(5, 7),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      child: _buildScoreboardContent(),
    );
  }

  Widget _buildScoreboardContent() {
    // --- ÄNDERUNGEN HIER ---
    final headerStyle = TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16);
    final cellStyle = TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold); // Namen jetzt fett und schwarz
    final scoreStyle = TextStyle(color: Colors.black54, fontSize: 14, fontWeight: FontWeight.normal); // Score normal und grau
    Color currentHighlightColor = !_game.isGameOver ? Colors.grey.shade300 : Colors.transparent;
    final double heartSize = 20.0;

    int minLives = _game.initialLives;
    _game.playerLives.forEach((player, lives) {
      if(lives > 0 && lives < minLives) {
        minLives = lives;
      }
    });

    // KORREKTUR: Logik zur Anzeige der Ergebnisse
    // WÄHREND die Runde läuft, werden die Scores in _game.roundResults gesammelt.
    // WENN die Runde endet, werden sie in _lastRoundResults gecacht.
    // WENN die nächste Runde startet, ist _game.roundResults leer.
    // Wir müssen also _game.roundResults priorisieren (für Spieler, die schon dran waren)
    // und auf _lastRoundResults zurückfallen (für Spieler, die noch nicht dran waren).

    return Column(
      mainAxisSize: MainAxisSize.min, // Nimmt nur die Höhe ein, die es braucht
      children: [
        Row(
          children: [
            Expanded(flex: 4, child: Text('SPIELER', style: headerStyle)), // Mehr Platz für Spieler
            Expanded(flex: 3, child: Center(child: Text('WURF', style: headerStyle))), // Neuer Header: WURF
            Expanded(flex: 3, child: Center(child: Text('LEBEN', style: headerStyle))), // Weniger Platz für Leben
          ],
        ),
        const Divider(color: Colors.black54, thickness: 1.5),

        ...List.generate(widget.players.length, (index) {
          final playerName = widget.players[index];
          final isCurrent = index == _game.currentPlayerIndex && !_game.isRoundOver && !_game.isGameOver;
          final livesCount = _game.playerLives[playerName] ?? 0;
          final bool isEliminated = livesCount <= 0;
          final bool isLowestLife = !isEliminated && livesCount == minLives && !_game.isGameOver;

          // KORREKTUR: Logik zur Anzeige des Scores
          final scoreDataThisRound = _game.roundResults[playerName];
          final scoreDataLastRound = _lastRoundResults[playerName];

          String scoreDisplay = "---"; // Standard
          String scoreColorHex = "Colors.black54"; // Standardfarbe
          Color scoreColor = Colors.black54;


          if (isCurrent) {
            scoreDisplay = (_game.rollCount > 0) ? "..." : "---";
          } else if (scoreDataThisRound != null) {
            // Spieler war in DIESER Runde schon dran (Runde ist vielleicht noch nicht vorbei)
            scoreDisplay = scoreDataThisRound.hasBasis ? "42 - ${scoreDataThisRound.score}" : "Ungültig";
          } else if (scoreDataLastRound != null) {
            // Spieler war noch nicht dran, zeige VORIGE Runde
            scoreDisplay = scoreDataLastRound.hasBasis ? "42 - ${scoreDataLastRound.score}" : "Ungültig";
          }
          // (else: scoreDisplay bleibt "---" für erste Runde)

          // Farbe basierend auf dem endgültigen scoreDisplay setzen
          scoreColor = (scoreDisplay == "Ungültig") ? Colors.red : Colors.black54;


          return Container(
            color: isCurrent ? currentHighlightColor : Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Row(
              children: [
                // Spielername
                Expanded(
                  flex: 4, // Mehr Platz
                  child: Text(
                    playerName,
                    style: cellStyle.copyWith( // cellStyle ist jetzt schwarz und fett
                      color: isEliminated ? Colors.grey : (isLowestLife ? Colors.red.shade700 : Colors.black),
                      decoration: isEliminated ? TextDecoration.lineThrough : TextDecoration.none,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                // Score (NEU)
                Expanded(
                  flex: 3,
                  child: Center(
                    child: Text(
                      scoreDisplay,
                      style: scoreStyle.copyWith(
                        color: scoreColor, // Dynamische Farbe
                      ),
                    ),
                  ),
                ),
                // Leben (Herzen)
                Expanded(
                  flex: 3, // Weniger Platz
                  child: Center(
                    child: Wrap(
                      spacing: 1.0,
                      runSpacing: 1.0,
                      alignment: WrapAlignment.center,
                      children: List.generate(
                        _game.initialLives,
                            (i) => Icon(
                          i < livesCount ? Icons.favorite : Icons.favorite_border,
                          color: Colors.black, // HERZEN JETZT SCHWARZ
                          size: heartSize,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
    // --- ENDE ÄNDERUNGEN ---
  }

  // --- Dialog & Info Overlay ---

  void _showRoundResolutionDialog() {
    if (!mounted || _game.isGameOver) return;

    List<MapEntry<String, FourTwoEighteenScore>> sortedResults = _game.roundResults.entries.toList()
      ..sort((a, b) => b.value.isBetterThan(a.value) ? 1 : -1);

    String loser = "Niemand";
    if (sortedResults.isNotEmpty) {
      final worstScore = sortedResults.last.value;
      final potentialLosers = sortedResults
          .where((entry) =>
      entry.value.hasBasis == worstScore.hasBasis &&
          entry.value.score == worstScore.score &&
          entry.value.usedRolls == worstScore.usedRolls)
          .toList();

      if (potentialLosers.length > 1) {
        potentialLosers.sort((a, b) => widget.players.indexOf(a.key).compareTo(widget.players.indexOf(b.key)));
        loser = potentialLosers.first.key;
      } else if (potentialLosers.isNotEmpty) { // Sicherstellen, dass die Liste nicht leer ist
        loser = potentialLosers.first.key;
      }
    }

    String winner = sortedResults.isNotEmpty ? sortedResults.first.key : "Niemand";
    int winnerScore = sortedResults.isNotEmpty ? sortedResults.first.value.score : 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFA4848),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.white, width: 5)
          ),
          title: Text(
            sortedResults.isNotEmpty && sortedResults.first.value.hasBasis
                ? '$winner gewinnt mit $winnerScore!'
                : 'Kein gültiger Wurf!',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                    _game.gameStatusMessage,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    textAlign: TextAlign.center
                ),
                const SizedBox(height: 15),
                const Divider(color: Colors.white, thickness: 2),
                const SizedBox(height: 10),

                ...sortedResults.map((entry) {
                  final player = entry.key;
                  final score = entry.value;
                  final isWorst = player == loser;
                  final diceSize = (MediaQuery.of(context).size.width * 0.08).clamp(25.0, 35.0);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                player,
                                style: TextStyle(
                                  fontSize: 18,
                                  color: isWorst ? Colors.black : Colors.white,
                                  fontWeight: isWorst ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              Text(
                                score.hasBasis ? 'Punkte: ${score.score} (${score.usedRolls} Würfe)' : 'Ungültig',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: score.hasBasis ? Colors.white70 : Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: score.diceValues.map((value) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 1.0),
                            child: SizedBox(
                              width: diceSize,
                              height: diceSize / DiceAssetDisplay.diceAspectRatio,
                              child: DiceAssetDisplay(value: value),
                            ),
                          )).toList(),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          actions: <Widget>[
            Center(
              child: _buildActionButton(
                  'OK (Start: ${_game.currentPlayerName})',
                      () {
                    Navigator.of(context).pop();
                    if (mounted && !_game.isGameOver) {
                      _game.startNextRound();
                    }
                  },
                  isPrimary: true
              ),
            ),
          ],
        );
      },
    );
  }

  void _showGameOverDialog() {
    if (!mounted) return;

    String winnerName = "Unentschieden";
    final remainingPlayers = _game.playerLives.entries.where((entry) => entry.value > 0).toList();
    if (remainingPlayers.length == 1) {
      winnerName = remainingPlayers.first.key;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFA4848),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.white, width: 5)
          ),
          title: const Text(
            'SPIEL VORBEI!',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24),
            textAlign: TextAlign.center,
          ),
          content: Text(
            _game.gameStatusMessage,
            style: const TextStyle(color: Colors.white, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          actions: <Widget>[
            Center(
              child: Column(
                children: [
                  _buildActionButton(
                      'NEU STARTEN',
                          () {
                        Navigator.of(context).pop();
                        _game.restartGame();
                      },
                      isPrimary: true
                  ),
                  const SizedBox(height: 10),
                  _buildActionButton(
                      'ZURÜCK ZUR AUSWAHL',
                          () {
                        Navigator.of(context).pop();
                        widget.onGameExit();
                      },
                      isPrimary: false
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }


  Widget _buildInfoOverlay() {
    final titleStyle = const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold);
    final itemStyle = const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600);
    final diceSize = (MediaQuery.of(context).size.width * 0.1).clamp(35.0, 45.0);

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
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                    color: const Color(0xFFFA4848),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white, width: 5)
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Text("Spielregeln", style: titleStyle, textAlign: TextAlign.left),
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
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          Text("Ziel:", style: itemStyle.copyWith(decoration: TextDecoration.underline)),
                          Text("Sichere die Basis '4' und '2' und erreiche mit den 3 anderen Würfeln die höchste Punktzahl (max. 18). Verliere nicht alle deine ${_game.initialLives} Leben!", style: itemStyle.copyWith(fontWeight: FontWeight.normal)),
                          const SizedBox(height: 20),

                          Text("Ablauf (pro Spieler):", style: itemStyle.copyWith(decoration: TextDecoration.underline)),
                          Text("Dein Zug geht so lange, bis alle 5 Würfel auf dem Brett liegen.", style: itemStyle.copyWith(fontWeight: FontWeight.normal)),
                          const SizedBox(height: 10),

                          Text("1. Würfeln & Ablegen:", style: itemStyle),
                          Text("Nach JEDEM Wurf (Klick auf 'NOCHMAL') MUSST du mindestens einen der gewürfelten Würfel auf einen passenden, freien Slot legen.", style: itemStyle.copyWith(fontWeight: FontWeight.normal)),
                          Row(children: [
                            Text("Passende Slots: ", style: itemStyle.copyWith(fontWeight: FontWeight.normal)),
                            SizedBox(width: diceSize, height: diceSize / DiceAssetDisplay.diceAspectRatio, child: DiceAssetDisplay(value: 4)),
                            Text(" auf '4', ", style: itemStyle.copyWith(fontWeight: FontWeight.normal)),
                            SizedBox(width: diceSize, height: diceSize / DiceAssetDisplay.diceAspectRatio, child: DiceAssetDisplay(value: 2)),
                            Text(" auf '2'.", style: itemStyle.copyWith(fontWeight: FontWeight.normal)),
                          ]),
                          Text("Alle anderen Würfel (1, 3, 5, 6) kommen auf die '...'-Slots.", style: itemStyle.copyWith(fontWeight: FontWeight.normal)),
                          const SizedBox(height: 15),

                          Text("2. Zug beenden:", style: itemStyle),
                          Text("Sobald der 5. Würfel liegt, ist dein Zug beendet und dein Ergebnis wird gewertet.", style: itemStyle.copyWith(fontWeight: FontWeight.normal)),
                          const SizedBox(height: 15),

                          Text("Wichtig:", style: itemStyle),
                          Text("- Du kannst 'NOCHMAL' erst klicken, wenn du einen Würfel abgelegt hast.", style: itemStyle.copyWith(fontWeight: FontWeight.normal)),
                          Text("- Einmal abgelegte Würfel kannst du durch Antippen wieder freigeben.", style: itemStyle.copyWith(fontWeight: FontWeight.normal)),
                          Text("- Dein Wurf ist ungültig, wenn am Ende keine '4' und '2' in den Basis-Slots liegen.", style: itemStyle.copyWith(fontWeight: FontWeight.normal)),
                          const SizedBox(height: 20),

                          Text("Wertung & Leben:", style: itemStyle.copyWith(decoration: TextDecoration.underline)),
                          Text("Der Spieler mit dem schlechtesten Wurf verliert 1 Leben.", style: itemStyle.copyWith(fontWeight: FontWeight.normal)),
                          Text("Vergleich (von schlecht nach gut):", style: itemStyle),
                          Text("1. Ungültig (Basis fehlt).", style: itemStyle.copyWith(fontWeight: FontWeight.normal)),
                          Text("2. Gültig: Niedrigste Punktzahl (3-18).", style: itemStyle.copyWith(fontWeight: FontWeight.normal)),
                          Text("3. Bei gleicher Punktzahl: Mehr 'NOCHMAL'-Klicks.", style: itemStyle.copyWith(fontWeight: FontWeight.normal)),
                          Text("4. Bei weiterem Gleichstand: Wer zuerst gewürfelt hat.", style: itemStyle.copyWith(fontWeight: FontWeight.normal)),
                          Text("Wer keine Leben mehr hat, scheidet aus. Der letzte Spieler gewinnt!", style: itemStyle.copyWith(fontWeight: FontWeight.normal)),

                        ],
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

}

