import 'package:flutter/material.dart';
import '../logic/schocken_game_logic.dart'; // Import der neuen Logik-Klasse
import '../widgets/dice_display.dart';

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
      backgroundColor: const Color(0xFFE53935),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // 1. HEADER
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Center(
                        child: Text('SCHOCKEN', style: TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900)),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
                          onPressed: widget.onGameQuit, // Callback an main.dart
                        ),
                      ),
                    ],
                  ),
                ),
                // 2. HAUPTBEREICH (JETZT MIT FLEXIBLE)
                // Flexible erlaubt dem Hauptbereich zu schrumpfen, wenn der untere Bereich mehr Platz braucht
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: _buildMainContentArea(),
                  ),
                ),
                // 3. BUTTON-BEREICH
                _buildButtonArea(),
                // 4. SCOREBOARD
                // Das Scoreboard ist jetzt in einem SingleChildScrollView, falls es zu groß wird
                SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: _buildScoreboard(),
                  ),
                ),
              ],
            ),
            // 5. ANIMATIONS-OVERLAY
            _buildAnimationOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContentArea() {
    // Greift auf _game.isRoundFinished etc. zu
    if (_game.isRoundFinished && !_game.areResultsCalculated && !_isRevealSequenceRunning) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
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
    const buttonPadding = EdgeInsets.only(bottom: 24.0, top: 16.0);
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
      buttonWidget = const SizedBox(height: 60); // Angepasste Platzhalter Höhe (größere Buttons)
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white, width: 2),
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
      return Image.asset(
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
            color: Color(0xFF1E1E1E), // Schattenfarbe
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
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 26)), // Größere Schrift
      ),
    );
  }

  Widget _buildScoreboard() {
    const headerStyle = TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 26);
    const cellStyle = TextStyle(color: Colors.white, fontSize: 24);

    Widget verticalDivider() => Container(height: 30, width: 1.5, color: Colors.white38);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Expanded(flex: 3, child: Text('SPIELER', style: headerStyle)),
            const Expanded(flex: 3, child: Center(child: Text('WURF', style: headerStyle))),
            verticalDivider(), // Trennlinie
            const Expanded(flex: 2, child: Center(child: Text('DECKEL', style: headerStyle))),
            verticalDivider(), // Trennlinie
            const Expanded(flex: 1, child: Center(child: Text('HZ', style: headerStyle))),
          ],
        ),
        const Divider(color: Colors.white38, thickness: 5),

        ...List.generate(widget.playerNames.length, (index) {
          // Greift auf _game.currentPlayerIndex etc. zu
          final isCurrent = index == _game.currentPlayerIndex && !_game.isRoundFinished;
          final score = _game.playerScores[index];

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    widget.playerNames[index],
                    style: cellStyle.copyWith(
                      color: isCurrent ? Colors.black : Colors.white,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
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
                          bool isVisible = false;
                          if (score.diceCount < 3) {
                            isVisible = true;
                          }
                          else if (score.heldDiceIndices.contains(diceIndex)) {
                            isVisible = true;
                          }
                          final int displayValue = isVisible ? score.diceValues[diceIndex] : 0;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3.0),
                            child: SizedBox(
                              width: 35,
                              height: 35 / DiceAssetDisplay.diceAspectRatio,
                              child: DiceAssetDisplay(value: displayValue),
                            ),
                          );
                        }),
                      ) : const Text('...', style: cellStyle),
                    )
                ),
                verticalDivider(), // Trennlinie
                Expanded(
                  flex: 2,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.circle, color: Colors.grey.shade300, size: 24),
                      const SizedBox(width: 8),
                      // Greift auf _game.playerLids zu
                      Text(_game.playerLids[index].toString(), style: cellStyle),
                    ],
                  ),
                ),
                verticalDivider(), // Trennlinie
                Expanded(
                  flex: 1,
                  child: Center(
                    // Greift auf _game.playerHalfLosses zu
                    child: Icon(
                      _game.playerHalfLosses[index] >= 1 ? Icons.pie_chart : Icons.circle_outlined,
                      color: Colors.white,
                      size: 28,
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
}

