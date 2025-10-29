import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../widgets/dice_display.dart';
import '../logic/four_two_eighteen_game_logic.dart'; // Import der neuen Logik-Klasse

class FourTwoEighteenGameWidget extends StatefulWidget {
  final List<String> players;
  final VoidCallback onGameExit;

  // Removed const from constructor
  const FourTwoEighteenGameWidget({super.key, required this.players, required this.onGameExit});

  @override
  State<FourTwoEighteenGameWidget> createState() => _FourTwoEighteenGameWidgetState();
}

class _FourTwoEighteenGameWidgetState extends State<FourTwoEighteenGameWidget> {
  late FourTwoEighteenGame _game;
  bool _isInfoOverlayVisible = false;

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
    setState(() {
      // Show round resolution dialog
      if (_game.isRoundOver && !_game.isGameOver && !_isInfoOverlayVisible && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _game.isRoundOver && !_game.isGameOver) {
            _showRoundResolutionDialog();
          }
        });
      }
      // Show game over dialog
      else if (_game.isGameOver && !_isInfoOverlayVisible && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _game.isGameOver) {
            _showGameOverDialog();
          }
        });
      }
    });
  }


  // --- UI Build Methoden (Design von Schocken übernommen) ---

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
                          onPressed: widget.onGameExit, // Keep exit functionality
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
                // 2. HAUPTBEREICH (flexible to allow Scoreboard visibility)
                Expanded( // Use Expanded instead of Flexible
                  child: SingleChildScrollView( // Make content scrollable if needed
                    padding: const EdgeInsets.only(top: 50.0, left: 16.0, right: 16.0, bottom: 10.0), // Reduced padding
                    child: _buildMainContentArea(),
                  ),
                ),
                // 3. BUTTON-BEREICH
                // Only show buttons if game is not over
                if (!_game.isGameOver) _buildButtonArea(),
                // Show restart button if game is over
                if (_game.isGameOver) _buildRestartButtonArea(),
                // 4. SCOREBOARD (Always visible at the bottom)
                _buildScoreboardContainer(), // Moved outside Expanded/Flexible
              ],
            ),

            // Removed floating status indicators

            // INFO-OVERLAY
            if (_isInfoOverlayVisible) _buildInfoOverlay(),
          ],
        ),
      ),
    );
  }

  // Removed _buildGameStatusIndicators()


  Widget _buildMainContentArea() {
    // Zeige Würfelbecher beim ersten Wurf
    if (_game.rollsLeft == 3 && !_game.isRoundOver && !_game.isGameOver) {
      final screenWidth = MediaQuery.of(context).size.width;
      final screenHeight = MediaQuery.of(context).size.height;
      final orientation = MediaQuery.of(context).orientation;
      final referenceSize = orientation == Orientation.portrait ? screenWidth : screenHeight;
      // Make cup slightly smaller to give more space for the board below
      final maxSize = (referenceSize * 0.6).clamp(180.0, 250.0);

      return Column(
        mainAxisAlignment: MainAxisAlignment.center, // Center the cup vertically
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.05), // Add some top spacing
          Image.asset(
            DiceAssetPaths.diceCupUrl,
            width: maxSize,
            height: maxSize,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(Icons.casino, size: maxSize, color: Colors.white),
          ),
          // Adjust spacing below cup dynamically or remove if not needed
          SizedBox(height: MediaQuery.of(context).size.height * 0.05),
        ],
      );
    } else if (_game.isGameOver) {
      // Display winner message in the main area when game is over
      return Center(
        child: Padding( // Add padding around the game over text
          padding: const EdgeInsets.symmetric(vertical: 50.0),
          child: Text(
            _game.gameStatusMessage, // Shows the winner message from logic
            style: const TextStyle(
                color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Zeige Drag-and-Drop-Bereich
    return _buildDiceArea(); // Removed size argument, will calculate inside
  }

  Widget _buildButtonArea() {
    final buttonPadding = EdgeInsets.only(bottom: 15.0, top: 5.0); // Reduced padding
    final resultStyle = TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold); // Slightly smaller

    // Wenn Runde vorbei ist (Dialog wird angezeigt), keinen Button zeigen
    if (_game.isRoundOver) {
      return SizedBox(height: 70); // Placeholder height approx button + text
    }


    // Wenn Runde läuft
    Widget buttonWidget;

    if (_game.rollsLeft == 3) {
      buttonWidget = _buildActionButton('WÜRFELN', _game.roll, isPrimary: true);
    } else {
      buttonWidget = Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton('LASSEN', _game.endTurn),
          _buildActionButton(
              'NOCHMAL (${_game.rollsLeft})',
              _game.rollsLeft > 0 ? _game.roll : null // Deaktiviert, wenn keine Würfe mehr
          ),
        ],
      );
    }

    // Determine current score text
    String currentScoreText = _game.gameStatusMessage; // Default to status message
    if (_game.rollsLeft < 3 && _game.basisFound && _game.allScoreDiceHeld) {
      currentScoreText = 'Aktuell: ${_game.scoreDice} / 18';
    } else if (_game.rollsLeft < 3 && _game.basisFound && !_game.allScoreDiceHeld) {
      currentScoreText = 'Punkte würfeln...';
    } else if (_game.rollsLeft < 3 && !_game.basisFound) {
      currentScoreText = 'Basis 4 & 2 suchen...';
    }


    return Padding(
      padding: buttonPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Show current score or status message during the turn
          // Only show specific score/status text if not the first roll
          if (_game.rollsLeft < 3)
            Padding(
              padding: const EdgeInsets.only(bottom: 10.0), // Reduced bottom padding
              child: Text(
                  currentScoreText,
                  style: resultStyle,
                  textAlign: TextAlign.center
              ),
            )
          // If it's the first roll, show the current player status instead
          else if (_game.rollsLeft == 3)
            Padding(
              padding: const EdgeInsets.only(bottom: 10.0), // Reduced bottom padding
              child: Text(
                  _game.gameStatusMessage, // Shows "Player X ist dran."
                  style: resultStyle,
                  textAlign: TextAlign.center
              ),
            ),
          buttonWidget,
        ],
      ),
    );
  }

  // New button area specifically for the restart button
  Widget _buildRestartButtonArea() {
    final buttonPadding = EdgeInsets.only(bottom: 15.0, top: 5.0); // Consistent padding
    return Padding(
      padding: buttonPadding,
      child: _buildActionButton('NEU STARTEN', _game.restartGame, isPrimary: true),
    );
  }


  /// Baut einen Button im Schocken-Stil
  Widget _buildActionButton(String text, VoidCallback? onPressed, {bool isPrimary = false}) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Adjust button widths slightly
    final double primaryWidth = (screenWidth * 0.65).clamp(220.0, 280.0);
    final double secondaryWidth = (screenWidth * 0.4).clamp(140.0, 180.0);

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
          minimumSize: Size(isPrimary ? primaryWidth : secondaryWidth, 55), // Slightly smaller height
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          elevation: 0,
        ),
        child: FittedBox( // Stellt sicher, dass Text in den Button passt
          fit: BoxFit.scaleDown,
          child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)), // Slightly smaller font
        ),
      ),
    );
  }

  // --- Drag & Drop UI ---

  Widget _buildDiceArea() {
    // Styling for the slots (like Schocken Scoreboard items)
    final slotDecoration = BoxDecoration(
      color: Colors.white, // White background for empty slots
      borderRadius: BorderRadius.circular(8.0),
      boxShadow: const [
        BoxShadow( color: Colors.black, spreadRadius: 0, blurRadius: 0, offset: Offset(3, 4)),
      ],
      border: Border.all(color: Colors.black54, width: 1), // Subtle border like scoreboard
    );
    final slotDecorationOccupied = BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        boxShadow: const [ // Keep shadow when occupied
          BoxShadow( color: Colors.black, spreadRadius: 0, blurRadius: 0, offset: Offset(3, 4)),
        ],
        border: Border.all(color: Colors.black, width: 2) // Keep border when occupied
    );

    // Style for the number inside the empty slot
    final highlightLabelStyle = TextStyle(
        color: Colors.black.withOpacity(0.6), // Darker, less prominent
        fontSize: 36, // Larger font size for the number
        fontWeight: FontWeight.w900 // Bold
    );
    // Style for the "..." placeholder
    final slotLabelStyle = TextStyle(
        color: Colors.black.withOpacity(0.4), // Even less prominent
        fontSize: 24,
        fontWeight: FontWeight.bold
    );


    // Responsive size for active dice
    final activeDiceSize = (MediaQuery.of(context).size.width / 5.5).clamp(55.0, 75.0); // Make dice slightly larger

    return Column(
      children: [
        // 1. Ablageflächen (Basis 42 und Score 18) - Reordered like Schocken
        // Score 18 Sektion (Top Row)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5.0),
              child: _buildDragTargetSlot(
                targetType: HoldPosition.score,
                requiredValue: null, // No specific value required
                heldIndices: _game.scoreDice,
                indexInArray: index,
                decoration: slotDecoration,
                occupiedDecoration: slotDecorationOccupied,
                labelStyle: slotLabelStyle,
                highlightLabelStyle: highlightLabelStyle, // Not used here, but pass anyway
              ),
            );
          }),
        ),
        const SizedBox(height: 30), // Space between rows

        // Basis 42 Sektion (Bottom Row)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildDragTargetSlot(
              targetType: HoldPosition.basis4,
              requiredValue: 4, // Indicate required value
              heldIndices: _game.basisDice,
              indexInArray: 0,
              decoration: slotDecoration,
              occupiedDecoration: slotDecorationOccupied,
              labelStyle: slotLabelStyle, // Not used here
              highlightLabelStyle: highlightLabelStyle,
            ),
            const SizedBox(width: 15), // Space between basis slots
            _buildDragTargetSlot(
              targetType: HoldPosition.basis2,
              requiredValue: 2, // Indicate required value
              heldIndices: _game.basisDice,
              indexInArray: 1,
              decoration: slotDecoration,
              occupiedDecoration: slotDecorationOccupied,
              labelStyle: slotLabelStyle, // Not used here
              highlightLabelStyle: highlightLabelStyle,
            ),
          ],
        ),

        const SizedBox(height: 50), // Increased space before active dice

        // 2. Aktive Würfel (Draggable) - Horizontal Layout
        // Label removed, implied by position
        // const Text('Aktive Würfel:', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        // const SizedBox(height: 15),

        // Wrap ensures dice flow to next line if needed, centered
        Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.9), // Limit width
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 10.0, // Horizontal space
            runSpacing: 10.0, // Vertical space if wrapping occurs
            children: List.generate(_game.currentDiceValues.length, (index) {
              final value = _game.currentDiceValues[index];
              final isHeld = _game.diceHeld[index];

              if (isHeld) {
                return const SizedBox.shrink(); // Hide held dice
              }

              // Make Draggable items have consistent size
              return SizedBox(
                width: activeDiceSize,
                height: activeDiceSize / DiceAssetDisplay.diceAspectRatio,
                child: Draggable<int>(
                  data: index,
                  feedback: Opacity( // Make feedback semi-transparent
                    opacity: 0.7,
                    child: SizedBox(
                      width: activeDiceSize,
                      height: activeDiceSize / DiceAssetDisplay.diceAspectRatio,
                      child: DiceAssetDisplay(value: value, isHeld: true),
                    ),
                  ),
                  childWhenDragging: SizedBox( // Keep space, but make it less visible
                    width: activeDiceSize,
                    height: activeDiceSize / DiceAssetDisplay.diceAspectRatio,
                    // child: Opacity(opacity: 0.3, child: DiceAssetDisplay(value: value)),
                  ),
                  child: DiceAssetDisplay( // The actual draggable dice
                    value: value,
                    isHeld: isHeld, // Should be false here
                    onTap: null, // Drag only
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }


  // Einzelner DragTarget Slot (Angepasst für neues Design)
  Widget _buildDragTargetSlot({
    required HoldPosition targetType,
    int? requiredValue,
    required List<int?> heldIndices,
    required int indexInArray,
    required BoxDecoration decoration,        // Style for empty slot
    required BoxDecoration occupiedDecoration, // Style for occupied slot
    required TextStyle labelStyle,           // Style for "..."
    required TextStyle highlightLabelStyle,  // Style for "4" or "2"
  }) {
    final diceIndex = heldIndices[indexInArray];
    final isOccupied = diceIndex != null;
    final value = isOccupied ? _game.currentDiceValues[diceIndex] : null;

    final double slotSize = (MediaQuery.of(context).size.width * 0.22).clamp(70.0, 90.0); // Slightly larger slots

    return DragTarget<int>(
      onWillAcceptWithDetails: (data) {
        final diceValue = _game.currentDiceValues[data.data];
        if (requiredValue != null && diceValue != requiredValue) return false;
        if (targetType == HoldPosition.score && !_game.basisFound) return false;
        return !isOccupied;
      },
      onAccept: (diceIndex) {
        _game.setHeldDice(diceIndex, targetType);
      },
      builder: (context, candidateData, rejectedData) {
        bool canAccept = candidateData.isNotEmpty;

        return GestureDetector(
          onTap: isOccupied ? () => _game.releaseHeldDice(diceIndex!) : null,
          child: Container(
            width: slotSize,
            height: slotSize / DiceAssetDisplay.diceAspectRatio, // Use dice aspect ratio for slot height
            decoration: isOccupied ? occupiedDecoration : decoration.copyWith(
              // Highlight background slightly when draggable hovers
              color: canAccept ? Colors.white.withOpacity(0.9) : Colors.white,
              border: Border.all(
                  color: canAccept ? Colors.black : Colors.black54, // Darker border on hover
                  width: canAccept ? 2 : 1),
            ),
            // Clip content to rounded corners
            clipBehavior: Clip.antiAlias,
            child: isOccupied
                ? Center(
              child: SizedBox(
                // Make dice fit exactly into the slot dimensions
                width: slotSize,
                height: slotSize / DiceAssetDisplay.diceAspectRatio,
                child: DiceAssetDisplay(value: value!),
              ),
            )
                : Center( // Display required value or "..."
              child: requiredValue != null
                  ? Text(requiredValue.toString(), style: highlightLabelStyle)
                  : Text('...'),
            ),
          ),
        );
      },
    );
  }


  // --- Scoreboard (Design von Schocken, angepasst für "Leben") ---

  Widget _buildScoreboardContainer() {
    // Scoreboard remains visible even when game is over to show final state

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0), // Added vertical margin
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
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0), // Adjusted padding
      child: _buildScoreboardContent(),
    );
  }

  Widget _buildScoreboardContent() {
    final headerStyle = TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16); // Smaller header
    final cellStyle = TextStyle(color: Colors.black, fontSize: 14); // Smaller cell text
    Color currentHighlightColor = !_game.isGameOver ? Colors.grey.shade300 : Colors.transparent;
    final double heartSize = 20.0; // Smaller hearts

    // Find the minimum number of lives any active player has
    int minLives = _game.initialLives;
    _game.playerLives.forEach((player, lives) {
      if(lives > 0 && lives < minLives) {
        minLives = lives;
      }
    });


    return Column(
      mainAxisSize: MainAxisSize.min, // Take only needed height
      children: [
        Row(
          children: [
            Expanded(flex: 5, child: Text('SPIELER', style: headerStyle)),
            Expanded(flex: 3, child: Center(child: Text('LEBEN', style: headerStyle))), // Changed header
          ],
        ),
        const Divider(color: Colors.black54, thickness: 1.5), // Thinner divider

        // Use LayoutBuilder to constrain height if necessary, or keep flexible
        // Flexible( // Removed Flexible, Column uses MainAxisSize.min now
        //   child: ListView.builder(
        //      shrinkWrap: true, // Allow ListView to size itself
        //      itemCount: widget.players.length,
        //      itemBuilder: (context, index) {

        // Use Column + map for non-scrolling list if player number is small
        ...List.generate(widget.players.length, (index) {
          final playerName = widget.players[index];
          final isCurrent = index == _game.currentPlayerIndex && !_game.isRoundOver && !_game.isGameOver;
          final livesCount = _game.playerLives[playerName] ?? 0;
          final bool isEliminated = livesCount <= 0;
          // Highlight player if they have the minimum number of lives (and are not eliminated)
          final bool isLowestLife = !isEliminated && livesCount == minLives && !_game.isGameOver;


          return Container(
            color: isCurrent ? currentHighlightColor : Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 6.0), // Reduced vertical padding
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text(
                    playerName,
                    style: cellStyle.copyWith(
                      fontWeight: isCurrent || isLowestLife ? FontWeight.bold : FontWeight.normal, // Bold if current or lowest life
                      color: isEliminated ? Colors.grey : (isLowestLife ? Colors.red.shade700 : Colors.black), // Red if lowest life
                      decoration: isEliminated ? TextDecoration.lineThrough : TextDecoration.none,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Center(
                    child: Wrap(
                      spacing: 1.0, // Tighter spacing
                      runSpacing: 1.0,
                      alignment: WrapAlignment.center,
                      children: List.generate(
                        _game.initialLives,
                            (i) => Icon(
                          i < livesCount ? Icons.favorite : Icons.favorite_border,
                          color: i < livesCount ? Colors.red : Colors.grey.shade400,
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
        // }), // End ListView.builder
        // ), // End Flexible
      ],
    );
  }


  // --- Dialog & Info Overlay ---

  void _showRoundResolutionDialog() {
    // Ensure dialog is shown only once per round end and only if game is not over
    if (!mounted || _game.isGameOver) return;

    // Determine loser AFTER sorting for correct highlighting in dialog
    List<MapEntry<String, FourTwoEighteenScore>> sortedResults = _game.roundResults.entries.toList()
      ..sort((a, b) => b.value.isBetterThan(a.value) ? 1 : -1); // Best score first

    // Find the actual loser based on tie-breaking rules if needed
    String loser = "Niemand"; // Default
    if (sortedResults.isNotEmpty) {
      final worstScore = sortedResults.last.value;
      final potentialLosers = sortedResults
          .where((entry) =>
      entry.value.hasBasis == worstScore.hasBasis &&
          entry.value.score == worstScore.score &&
          entry.value.usedRolls == worstScore.usedRolls)
          .toList();

      if (potentialLosers.length > 1) {
        potentialLosers.sort((a, b) => widget.players.indexOf(a.key).compareTo(widget.players.indexOf(b.key))); // Sort by original player order
        loser = potentialLosers.first.key;
      } else {
        loser = potentialLosers.first.key;
      }
    }


    String winner = sortedResults.isNotEmpty ? sortedResults.first.key : "Niemand";
    int winnerScore = sortedResults.isNotEmpty ? sortedResults.first.value.score : 0;

    showDialog(
      context: context,
      barrierDismissible: false, // User must press OK
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFA4848),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.white, width: 5)
          ),
          title: Text(
            // Check if there was a valid winner
            sortedResults.isNotEmpty && sortedResults.first.value.hasBasis
                ? '$winner gewinnt die Runde mit ${winnerScore}!'
                : 'Kein gültiger Wurf!',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Display status message (who lost a life)
                Text(
                    _game.gameStatusMessage, // Shows "... verliert 1 Leben."
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    textAlign: TextAlign.center
                ),
                const SizedBox(height: 15),
                const Divider(color: Colors.white, thickness: 2),
                const SizedBox(height: 10),

                // Display sorted results
                ...sortedResults.map((entry) {
                  final player = entry.key;
                  final score = entry.value;
                  final isWorst = player == loser; // Highlight the actual loser
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
                                  color: isWorst ? Colors.black : Colors.white, // Highlight loser in black
                                  fontWeight: isWorst ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              Text(
                                score.hasBasis ? 'Punkte: ${score.score} (${score.usedRolls} Würfe)' : 'Ungültig', // Simplified text
                                style: TextStyle(
                                  fontSize: 14,
                                  color: score.hasBasis ? Colors.white70 : Colors.black, // Highlight invalid in black
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row( // Würfel anzeigen
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
                // Use _game.currentPlayerName for who starts next, as logic sets it
                  'OK (Start: ${_game.currentPlayerName})',
                      () {
                    Navigator.of(context).pop();
                    // Check game over state *after* dialog is closed
                    if (mounted && !_game.isGameOver) {
                      _game.startNextRound();
                    } else if (mounted && _game.isGameOver) {
                      // Game over state change will trigger the game over dialog
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

  // New Dialog for Game Over
  void _showGameOverDialog() {
    if (!mounted) return; // Ensure widget is still mounted

    String winnerName = "Unentschieden"; // Default
    final remainingPlayers = _game.playerLives.entries.where((entry) => entry.value > 0).toList();
    if (remainingPlayers.length == 1) {
      winnerName = remainingPlayers.first.key;
    }

    showDialog(
      context: context,
      barrierDismissible: false, // Must press button
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
            _game.gameStatusMessage, // Shows winner message
            style: const TextStyle(color: Colors.white, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          actions: <Widget>[
            Center(
              child: Column( // Buttons below each other
                children: [
                  _buildActionButton(
                      'NEU STARTEN',
                          () {
                        Navigator.of(context).pop();
                        _game.restartGame(); // Call restart method in logic
                      },
                      isPrimary: true
                  ),
                  const SizedBox(height: 10),
                  _buildActionButton(
                      'ZURÜCK ZUR AUSWAHL',
                          () {
                        Navigator.of(context).pop();
                        widget.onGameExit(); // Call exit callback
                      },
                      isPrimary: false // Secondary style
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
    final titleStyle = TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold);
    final itemStyle = TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600);
    final diceSize = (MediaQuery.of(context).size.width * 0.1).clamp(35.0, 45.0);

    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _isInfoOverlayVisible = false),
        child: Container(
          color: Colors.black.withOpacity(0.85),
          child: Center(
            child: GestureDetector(
              onTap: () {}, // Klicks innerhalb der Box abfangen
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                // Make height slightly more flexible
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                    color: const Color(0xFFFA4848),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white, width: 5)
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Adjust height to content
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
                    // Make the rules scrollable if they overflow
                    Flexible(
                      child: ListView(
                        shrinkWrap: true, // Important within Flexible
                        children: [
                          Text("Ziel:", style: itemStyle.copyWith(decoration: TextDecoration.underline)),
                          Text("Erreiche mit 3 Würfeln die höchste Punktzahl (max. 18), NACHDEM du die Basis '4' und '2' gesichert hast. Verliere nicht alle deine ${_game.initialLives} Leben!", style: itemStyle.copyWith(fontWeight: FontWeight.normal)), // Show initial lives
                          const SizedBox(height: 20),

                          Text("Ablauf (pro Spieler):", style: itemStyle.copyWith(decoration: TextDecoration.underline)),
                          Text("Du hast 3 Würfe pro Runde.", style: itemStyle.copyWith(fontWeight: FontWeight.normal)), // Clarified 'per round'
                          const SizedBox(height: 10),

                          Text("1. Basis (4 & 2) finden:", style: itemStyle),
                          Row(children: [
                            Text("Sichere zuerst ", style: itemStyle.copyWith(fontWeight: FontWeight.normal)),
                            SizedBox(width: diceSize, height: diceSize / DiceAssetDisplay.diceAspectRatio, child: DiceAssetDisplay(value: 4)),
                            Text(" und ", style: itemStyle.copyWith(fontWeight: FontWeight.normal)),
                            SizedBox(width: diceSize, height: diceSize / DiceAssetDisplay.diceAspectRatio, child: DiceAssetDisplay(value: 2)),
                          ]),
                          Text("Lege sie in die Basis-Slots (ziehen & fallen lassen).", style: itemStyle.copyWith(fontWeight: FontWeight.normal)), // Drag&Drop hint
                          const SizedBox(height: 15),

                          Text("2. Punkte (max. 18) würfeln:", style: itemStyle),
                          Text("Sobald die Basis liegt, sichere 3 weitere Würfel in den Punkte-Slots.", style: itemStyle.copyWith(fontWeight: FontWeight.normal)),
                          const SizedBox(height: 15),

                          Text("Wichtig:", style: itemStyle),
                          Text("- Du musst nach dem 1. Wurf min. 1 Würfel sichern.", style: itemStyle.copyWith(fontWeight: FontWeight.normal)),
                          Text("- Hast du nach 3 Würfen keine Basis (4 & 2), ist dein Wurf ungültig.", style: itemStyle.copyWith(fontWeight: FontWeight.normal)),
                          Text("- Du kannst gesicherte Würfel durch Antippen wieder freigeben.", style: itemStyle.copyWith(fontWeight: FontWeight.normal)), // Release hint
                          const SizedBox(height: 20),

                          Text("Wertung & Leben:", style: itemStyle.copyWith(decoration: TextDecoration.underline)),
                          Text("Der Spieler mit dem schlechtesten Wurf verliert 1 Leben.", style: itemStyle.copyWith(fontWeight: FontWeight.normal)),
                          Text("Vergleich (von schlecht nach gut):", style: itemStyle), // Changed order
                          Text("1. Ungültig (keine Basis).", style: itemStyle.copyWith(fontWeight: FontWeight.normal)),
                          Text("2. Gültig: Niedrigste Punktzahl (3-18).", style: itemStyle.copyWith(fontWeight: FontWeight.normal)),
                          Text("3. Bei gleicher Punktzahl: Mehr Würfe gebraucht.", style: itemStyle.copyWith(fontWeight: FontWeight.normal)),
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

