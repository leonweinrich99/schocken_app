import 'package:flutter/material.dart';
import 'dart:math';
import '../widgets/dice_display.dart'; // Jetzt DiceAssetDisplay

// Enum zur Unterscheidung der Halteposition
enum HoldPosition {
  none, // Würfel ist frei oder wird neu gewürfelt
  basis4, // Muss der 4er Würfel sein
  basis2, // Muss der 2er Würfel sein
  score, // Die restlichen 3 Würfel für die Punktzahl (18)
}

// HILFSKLASSE: WERTUNG
class FourTwoEighteenScore {
  final int score; // Punktzahl 0 (ungültig), 3-18 (gültig)
  final int usedRolls;
  final bool hasBasis;
  final List<int> diceValues;

  FourTwoEighteenScore(this.score, this.usedRolls, this.hasBasis, this.diceValues);

  bool isBetterThan(FourTwoEighteenScore other) {
    if (!hasBasis && other.hasBasis) return false;
    if (hasBasis && !other.hasBasis) return true;
    if (!hasBasis && !other.hasBasis) return false;

    if (score != other.score) {
      return score > other.score;
    }
    return false;
  }
}

// -----------------------------------------------------------------------------
// WIDGET FÜR DAS 42/18 SPIEL
// -----------------------------------------------------------------------------

class FourTwoEighteenGameWidget extends StatefulWidget {
  final List<String> players;
  final VoidCallback onGameExit;

  const FourTwoEighteenGameWidget({super.key, required this.players, required this.onGameExit});

  @override
  State<FourTwoEighteenGameWidget> createState() => _FourTwoEighteenGameWidgetState();
}

class _FourTwoEighteenGameWidgetState extends State<FourTwoEighteenGameWidget> {
  final Random _random = Random();
  final int _totalDice = 5;

  Map<String, int> _playerLids = {};
  int _currentPlayerIndex = 0;
  List<int> _currentDiceValues = [1, 1, 1, 1, 1]; // Die fünf Würfel
  List<bool> _diceHeld = [false, false, false, false, false]; // Markiert Würfel, die gehalten werden (nicht neu gewürfelt)
  List<int?> _basisDice = [null, null]; // [0] = 4er-Index, [1] = 2er-Index
  List<int?> _scoreDice = [null, null, null]; // Die drei Indexe der Würfel für die 18

  int _rollsLeft = 3;
  String _gameStatusMessage = '';
  bool _isRoundOver = false;

  Map<String, FourTwoEighteenScore> _roundResults = {};
  Map<String, List<int>> _allPlayerFinalDice = {};

  // Status zur Basis 42
  bool get _hasHeldFour => _basisDice[0] != null;
  bool get _hasHeldTwo => _basisDice[1] != null;
  bool get _basisFound => _hasHeldFour && _hasHeldTwo;
  bool get _allScoreDiceHeld => _scoreDice.every((element) => element != null);

  @override
  void initState() {
    super.initState();
    _playerLids = Map.fromIterable(widget.players, key: (player) => player, value: (_) => 0);
    _startRound();
  }

  void _startRound() {
    setState(() {
      _currentDiceValues = List.generate(_totalDice, (_) => 1);
      _diceHeld = List.generate(_totalDice, (_) => false);
      _rollsLeft = 3;
      _isRoundOver = false;
      _roundResults = {};
      _allPlayerFinalDice = {};
      _basisDice = [null, null];
      _scoreDice = [null, null, null];
      _gameStatusMessage = 'Runde gestartet. ${widget.players[_currentPlayerIndex]} beginnt.';
    });
  }

  void _roll() {
    if (_isRoundOver || _rollsLeft <= 0) return;

    // Nur Würfel, die nicht gehalten werden, neu würfeln
    int rollCount = 0;
    for (int i = 0; i < _totalDice; i++) {
      if (!_diceHeld[i]) {
        _currentDiceValues[i] = _random.nextInt(6) + 1;
        rollCount++;
      }
    }

    // Regel: Nach dem ersten Wurf MUSS mindestens ein Würfel gehalten werden.
    if (rollCount == 0 && _rollsLeft > 0) {
      _gameStatusMessage = 'Du musst mindestens einen Würfel behalten oder den Zug beenden.';
      return;
    }

    setState(() {
      _rollsLeft--;
      _gameStatusMessage = '${widget.players[_currentPlayerIndex]} hat gewürfelt. Würfe übrig: $_rollsLeft';

      // Wenn keine Würfe mehr übrig und nicht alle Würfel gehalten sind, Zug beenden
      if (_rollsLeft == 0 && !_diceHeld.every((held) => held)) {
        _endTurn();
      } else if (_diceHeld.every((held) => held)) {
        _endTurn();
      }
    });
  }

  void _endTurn() {
    // Wenn die Basis nicht gehalten wurde, aber 3 Würfe weg sind, ist die Runde ungültig.
    if (!_basisFound && _rollsLeft == 0) {
      // Wenn die Basis fehlt, wird die Runde automatisch beendet und gewertet (Score = 0)
    }

    final currentPlayer = widget.players[_currentPlayerIndex];

    // Ergebnis werten und speichern
    final score = _evaluateScore();
    _roundResults[currentPlayer] = score;

    // Speichern des Endergebnisses des Spielers (alle 5 Würfel)
    _allPlayerFinalDice[currentPlayer] = List<int>.from(_currentDiceValues);

    final nextPlayerIndex = (_currentPlayerIndex + 1) % widget.players.length;

    if (_roundResults.length == widget.players.length) {
      _resolveRound();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showRoundResolutionDialog();
      });
    } else {
      setState(() {
        _currentPlayerIndex = nextPlayerIndex;
        _startRound(); // _startPlayerTurn wurde in _startRound umbenannt
        _gameStatusMessage = 'Der Zug von $currentPlayer ist beendet. ${widget.players[_currentPlayerIndex]} ist dran.';
      });
    }
  }

  // Setzt den Index des Würfels auf die Halteposition
  void _setHeldDice(int diceIndex, HoldPosition target) {
    setState(() {
      // 1. Würfel aus allen Halte-Arrays entfernen
      _basisDice = _basisDice.map((index) => index == diceIndex ? null : index).toList();
      _scoreDice = _scoreDice.map((index) => index == diceIndex ? null : index).toList();

      // 2. Halten Status des Würfels setzen
      _diceHeld[diceIndex] = true;

      // 3. Neue Position setzen
      if (target == HoldPosition.basis4) {
        _basisDice[0] = diceIndex;
      } else if (target == HoldPosition.basis2) {
        _basisDice[1] = diceIndex;
      } else if (target == HoldPosition.score) {
        // Fügt den Würfel zur ersten freien Stelle im Score-Array hinzu
        final emptyIndex = _scoreDice.indexOf(null);
        if (emptyIndex != -1) {
          _scoreDice[emptyIndex] = diceIndex;
        }
      }

      // Fülle leere Plätze mit null, falls remove oben welche erzeugt hat
      while (_basisDice.length < 2) _basisDice.add(null);
      while (_scoreDice.length < 3) _scoreDice.add(null);

      // Wenn alle 5 Würfel gehalten wurden, Zug beenden
      if (_diceHeld.every((held) => held)) {
        _endTurn();
      }
    });
  }

  // Gibt einen Würfel frei (wird wieder gewürfelt)
  void _releaseHeldDice(int diceIndex) {
    setState(() {
      _diceHeld[diceIndex] = false;
      _basisDice = _basisDice.map((index) => index == diceIndex ? null : index).toList();
      _scoreDice = _scoreDice.map((index) => index == diceIndex ? null : index).toList();
    });
  }

  // Wertet den finalen Wurf aus
  FourTwoEighteenScore _evaluateScore() {
    final usedRolls = 3 - _rollsLeft;
    final finalDiceValues = List<int>.from(_currentDiceValues);

    if (!_basisFound || !_allScoreDiceHeld) {
      return FourTwoEighteenScore(0, usedRolls, false, finalDiceValues);
    }

    // Die Punktzahl ist die Summe der drei Würfel in _scoreDice
    int score = 0;
    for (int? index in _scoreDice) {
      if (index != null) {
        score += _currentDiceValues[index];
      }
    }

    return FourTwoEighteenScore(score, usedRolls, true, finalDiceValues);
  }


  // Rundenauflösung und Deckelverteilung
  void _resolveRound() {
    setState(() {
      _isRoundOver = true;

      List<MapEntry<String, FourTwoEighteenScore>> sortedResults = _roundResults.entries.toList()
        ..sort((a, b) => b.value.isBetterThan(a.value) ? 1 : -1);

      final worstPlayerEntry = sortedResults.last;
      final worstPlayer = worstPlayerEntry.key;
      final worstScore = worstPlayerEntry.value;

      if (worstScore.score > 0 || !worstScore.hasBasis) {
        _playerLids[worstPlayer] = (_playerLids[worstPlayer] ?? 0) + 1;
        _gameStatusMessage = '$worstPlayer verliert und erhält 1 Strafpunkt.';
      } else {
        _gameStatusMessage = 'Unentschieden. Keine Strafpunkte verteilt.';
      }

      _currentPlayerIndex = widget.players.indexOf(worstPlayer);
    });
  }

  void _showRoundResolutionDialog() {
    String loser = widget.players[_currentPlayerIndex];

    List<MapEntry<String, FourTwoEighteenScore>> sortedResults = _roundResults.entries.toList()
      ..sort((a, b) => b.value.isBetterThan(a.value) ? 1 : -1);

    String winner = sortedResults.first.key;
    int winnerScore = sortedResults.first.value.score;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.black,
          title: Text(
            'Rundenergebnis - $winner gewinnt mit $winnerScore',
            style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_gameStatusMessage, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                const Text(
                    'Rangliste (Bester Wurf oben):',
                    style: TextStyle(color: Colors.white70, decoration: TextDecoration.underline)
                ),
                const SizedBox(height: 10),

                ...sortedResults.map((entry) {
                  final player = entry.key;
                  final score = entry.value;
                  final isWorst = player == loser;

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
                                  fontSize: 16,
                                  color: isWorst ? Colors.red : Colors.white,
                                  fontWeight: isWorst ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              Text(
                                score.hasBasis ? 'Punkte: ${score.score}' : 'Ungültig (Basis fehlt)',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: score.hasBasis ? Colors.grey : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: score.diceValues.map((value) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 1.0),
                            child: SizedBox(
                              width: 20,
                              height: 20,
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
            TextButton(
              child: Text(
                'Nächste Runde (Start: $loser)',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _startRound();
              },
            ),
          ],
        );
      },
    );
  }

  // Einzelner DragTarget Slot
  Widget _buildDragTargetSlot({
    required HoldPosition targetType,
    required String label,
    required List<int?> heldIndices,
    required int indexInArray,
    required int expectedValue,
  }) {
    final diceIndex = heldIndices[indexInArray];
    final isOccupied = diceIndex != null;
    final value = isOccupied ? _currentDiceValues[diceIndex] : null;

    return DragTarget<int>(
      // Akzeptiere nur den Index des Würfels
      onWillAcceptWithDetails: (data) {
        // Prüfe, ob der Würfel die erwartete Zahl hat
        final diceValue = _currentDiceValues[data.data];

        // Regel: Basis 4/2
        if (targetType == HoldPosition.basis4 && diceValue != 4) return false;
        if (targetType == HoldPosition.basis2 && diceValue != 2) return false;

        // Regel: Punkte (Score) dürfen nur gesetzt werden, wenn Basis 4/2 bereits gehalten wird
        if (targetType == HoldPosition.score && !_basisFound) return false;

        // Regel: Slot muss leer sein
        return !isOccupied;
      },
      onAccept: (diceIndex) {
        _setHeldDice(diceIndex, targetType);
      },
      builder: (context, candidateData, rejectedData) {
        return GestureDetector(
          onTap: isOccupied ? () => _releaseHeldDice(diceIndex!) : null,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: isOccupied ? Colors.black : Colors.redAccent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(0), // Eckig
              border: Border.all(
                color: isOccupied ? Colors.white : Colors.redAccent,
                width: 2,
              ),
            ),
            child: isOccupied
                ? Center(
              child: SizedBox(
                width: 45,
                height: 45,
                child: DiceAssetDisplay(value: value!),
              ),
            )
                : Center(
              child: Text(
                label,
                style: const TextStyle(color: Colors.white54, fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
    );
  }

  // Widget zum Anzeigen der aktuellen Würfel (mit Drag-Funktionalität)
  Widget _buildDiceArea(double size) {
    return Column(
      children: [
        // 1. Ablageflächen (Basis 42 und Score 18)

        // Basis 42 Sektion
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildDragTargetSlot(
              targetType: HoldPosition.basis4,
              label: 'BASIS (4)',
              heldIndices: _basisDice,
              indexInArray: 0,
              expectedValue: 4,
            ),
            const SizedBox(width: 20),
            _buildDragTargetSlot(
              targetType: HoldPosition.basis2,
              label: 'BASIS (2)',
              heldIndices: _basisDice,
              indexInArray: 1,
              expectedValue: 2,
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Score 18 Sektion
        Text(
          _basisFound ? 'PUNKTE (max. 18):' : 'PUNKTE (Basis 4/2 fehlt)',
          style: TextStyle(
            color: _basisFound ? Colors.white : Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5.0),
              child: _buildDragTargetSlot(
                targetType: HoldPosition.score,
                label: 'PUNKT-WÜRFEL',
                heldIndices: _scoreDice,
                indexInArray: index,
                expectedValue: 0, // Beliebige Zahl
              ),
            );
          }),
        ),
        const SizedBox(height: 30),


        // 2. Aktive Würfel (Draggable)
        const Text('Aktive Würfel:', style: TextStyle(color: Colors.white70)),
        const SizedBox(width: 164, height: 111),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_totalDice, (index) {
            final value = _currentDiceValues[index];
            final isHeld = _diceHeld[index];

            // Wenn der Würfel gehalten wird, zeigen wir ihn nicht im Draggable-Bereich
            if (isHeld) {
              return const SizedBox(width: 164, height: 111); // Platzhalter
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Draggable<int>(
                data: index, // Der Index des Würfels ist die übertragene Information
                feedback: SizedBox(
                  width: size + 50,
                  height: size + 10,
                  child: DiceAssetDisplay(value: value, isHeld: true),
                ),
                childWhenDragging: SizedBox(width: size, height: size), // Leerer Platz
                child: SizedBox(
                  width: size,
                  height: size,
                  child: DiceAssetDisplay(
                    value: value,
                    isHeld: isHeld,
                    // Deaktivieren des onTap, da wir Drag verwenden
                    onTap: null,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildScoreboard() {
    return Card(
      elevation: 5,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)), // Eckig
      color: Colors.black,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'STRAFPUNKTE',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.redAccent,
                letterSpacing: 2,
              ),
              textAlign: TextAlign.center,
            ),
            const Divider(color: Colors.white, thickness: 1.5, height: 15),

            ..._playerLids.entries.map((entry) {
              final isCurrentPlayer = entry.key == widget.players[_currentPlayerIndex] && !_isRoundOver;

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
                      '${entry.value} Strafpunkte',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isCurrentPlayer ? FontWeight.bold : FontWeight.normal,
                        color: (entry.value >= 3) ? Colors.red : Colors.redAccent,
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
    const double mainDiceSize = 50;

    // Würfelbecher als Platzhalter
    Widget diceArea;
    if (_rollsLeft == 3 && !_isRoundOver) {
      diceArea = Container(
        padding: const EdgeInsets.only(top: 50, bottom: 50),
        child: Column(
          children: [
            DiceAssetPaths.diceCupUrl.isNotEmpty && DiceAssetPaths.useAssets
                ? Image.network(
              DiceAssetPaths.diceCupUrl,
              width: mainDiceSize * 2.5,
              height: mainDiceSize * 3.5,
              errorBuilder: (context, error, stackTrace) => _buildDrawnDiceCup(mainDiceSize),
            )
                : _buildDrawnDiceCup(mainDiceSize),
          ],
        ),
      );
    } else {
      diceArea = _buildDiceArea(mainDiceSize);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          // 1. Statusmeldung
          Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: Text(
              _gameStatusMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: _gameStatusMessage.contains('Strafpunkt') ? Colors.white : Colors.redAccent,
              ),
            ),
          ),

          // 2. Würfel- / Becher-Anzeige mit Drag & Drop
          diceArea,
          const SizedBox(height: 30),

          // 3. Ergebnis-Anzeige der aktuellen Runde (wenn Basis + Score gehalten)
          if (_basisFound && _allScoreDiceHeld)
            Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Text(
                'Aktuelles Ergebnis: ${_evaluateScore().score} / 18',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),

          // 4. Würfeln-Button
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Lassen (Zug beenden) Button
              Container(
                width: 150,
                height: 50,
                margin: const EdgeInsets.only(right: 10),
                child: ElevatedButton(
                  onPressed: _isRoundOver || _rollsLeft == 3 ? null : _endTurn,
                  child: const Text('LASSEN', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)), // Eckig
                    elevation: 5,
                  ),
                ),
              ),

              // Noch mal (Würfeln) Button
              Container(
                width: 150,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isRoundOver || _rollsLeft == 0 ? null : _roll,
                  child: Text(
                    _rollsLeft == 0 ? 'Zug beendet' : 'NOCHMAL (${_rollsLeft})',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)), // Eckig
                    elevation: 5,
                  ),
                ),
              ),
            ],
          ),

          // 5. Spielstand-Anzeige (Strafpunkte)
          const SizedBox(height: 10),
          _buildScoreboard(),

          // 6. Spiel-Navigation
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
    width: mainDiceSize * 2.5,
    height: mainDiceSize * 3.5,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(50), bottom: Radius.circular(10)),
      border: Border.all(color: Colors.black, width: 3),
    ),
    child: const Center(
      child: Text(
        'BECHER\n(Fallback)',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
      ),
    ),
  );
}
