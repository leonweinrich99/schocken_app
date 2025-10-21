import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../widgets/dice_display.dart'; // Stellt sicher, dass der Pfad zu deiner dice_display.dart korrekt ist

// -----------------------------------------------------------------------------
// ENUM UND DATENSTRUKTUREN
// -----------------------------------------------------------------------------

enum SchockenRollType {
  simple, // Einfacher Wurf (Hausnummer)
  straight, // Straße
  pasch, // Pasch (Drilling)
  schockX, // Schock 2-6
  schockOut // Schock-Aus (111)
}

class SchockenScore {
  final SchockenRollType type;
  final int value;
  final int lidValue;
  final int diceCount;
  final List<int> diceValues;
  final List<int> heldDiceIndices;

  SchockenScore({
    required this.type,
    required this.value,
    required this.lidValue,
    required this.diceCount,
    required this.diceValues,
    required this.heldDiceIndices,
  });

  bool isBetterThan(SchockenScore other) {
    if (type == SchockenRollType.schockOut && other.type != SchockenRollType.schockOut) return true;
    if (type != SchockenRollType.schockOut && other.type == SchockenRollType.schockOut) return false;
    if (type == SchockenRollType.schockX && other.type != SchockenRollType.schockX) return true;
    if (type != SchockenRollType.schockX && other.type == SchockenRollType.schockX) return false;

    if (type == SchockenRollType.schockX && other.type == SchockenRollType.schockX) {
      return value > other.value;
    }

    if (type.index > other.type.index) return true;
    if (type.index < other.type.index) return false;

    return value > other.value;
  }

  String get typeString {
    switch (type) {
      case SchockenRollType.schockOut:
        return 'Schock-Aus!';
      case SchockenRollType.schockX:
        return 'Schock $value';
      case SchockenRollType.pasch:
        return 'Pasch ${diceValues[0]}er General';
      case SchockenRollType.straight:
        return 'Straße';
      case SchockenRollType.simple:
        return 'Einfache Zahl'; // Wird kürzer für die Animation
    }
  }
}

// -----------------------------------------------------------------------------
// WIDGET
// -----------------------------------------------------------------------------

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
  // --- Spiellogik-Zustände ---
  late List<int> _playerLids;
  late List<int> _playerHalfLosses;
  late List<SchockenScore?> _playerScores;
  int _lidsInMiddle = 13;
  int _rollsLeft = 3;
  int _currentPlayerIndex = 0;
  int _half = 1;
  int _loserIndexAtStartOfRound = 0;
  List<int> _currentDiceValues = [1, 2, 3];
  List<int> _heldDiceIndices = [];
  int _maxRollsInRound = 3;

  // --- Phasensteuerung ---
  bool _isRoundFinished = false;
  bool _areResultsRevealed = false;

  // --- Ergebnisanzeige ---
  String? _roundLoserName;
  int _roundLidsTransferred = 0;
  bool _wasHalfLost = false;
  bool _wasGameLost = false;

  // --- Animation ---
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation; // NEU für Slide-Effekt
  String _animationText = '';
  bool _isRevealSequenceRunning = false;

  @override
  void initState() {
    super.initState();
    _playerLids = List.generate(widget.playerNames.length, (index) => 0);
    _playerHalfLosses = List.generate(widget.playerNames.length, (index) => 0);
    _playerScores = List.generate(widget.playerNames.length, (index) => null);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600), // Etwas länger für besseren Effekt
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.1).animate( // Skaliert etwas größer für einen "Pop"-Effekt
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    // NEU: Definiert eine Animation, die von oben (-1.5) ins Zentrum (0.0) gleitet
    _slideAnimation = Tween<Offset>(begin: const Offset(0, -1.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.fastOutSlowIn),
    );

    _startRound();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _startRound() {
    setState(() {
      _rollsLeft = 3;
      _currentDiceValues = [1, 1, 1];
      _heldDiceIndices = [];
      _isRoundFinished = false;
      _areResultsRevealed = false;
      _roundLoserName = null;

      if (_currentPlayerIndex == _loserIndexAtStartOfRound) {
        _maxRollsInRound = 3;
        _playerScores = List.generate(widget.playerNames.length, (index) => null);
      }

      if (_playerScores[_currentPlayerIndex] != null) {
        _playerScores[_currentPlayerIndex] = null;
      }
    });
  }

  void _startHalf() {
    setState(() {
      _half++;
      _lidsInMiddle = 13;
      _playerLids = List.generate(widget.playerNames.length, (index) => 0);
      _currentPlayerIndex = _loserIndexAtStartOfRound;
      _startRound();
    });
  }

  void _rollDice() {
    if (_currentPlayerIndex != _loserIndexAtStartOfRound && (3 - _rollsLeft) >= _maxRollsInRound) return;
    if (_rollsLeft == 0) return;

    setState(() {
      _rollsLeft--;
      final random = math.Random();
      for (int i = 0; i < 3; i++) {
        if (!_heldDiceIndices.contains(i)) {
          _currentDiceValues[i] = 1 + random.nextInt(6);
        }
      }

      final currentRolls = 3 - _rollsLeft;

      if ((_currentPlayerIndex != _loserIndexAtStartOfRound && currentRolls >= _maxRollsInRound) || _rollsLeft == 0) {
        _endTurn(true);
      }
    });
  }

  void _onDiceTap(int index) {
    if (_rollsLeft == 0) return;

    final sixes = _currentDiceValues.where((v) => v == 6).toList();
    if (sixes.length == 2) {
      int thirdDieIndex = _currentDiceValues.indexWhere((v) => v != 6);
      if (index == thirdDieIndex && _currentDiceValues[index] != 1) {
        setState(() {
          _currentDiceValues[index] = 1;
          if (!_heldDiceIndices.contains(index)) {
            _heldDiceIndices.add(index);
          }
        });
        return;
      }
    }

    if (_currentDiceValues[index] == 1) {
      setState(() {
        if (_heldDiceIndices.contains(index)) {
          _heldDiceIndices.remove(index);
        } else {
          _heldDiceIndices.add(index);
        }
      });
    }
  }

  void _endTurn(bool isForced) {
    if (!isForced && _rollsLeft == 3) return;
    final usedRolls = 3 - _rollsLeft;

    if (_currentPlayerIndex == _loserIndexAtStartOfRound) {
      _maxRollsInRound = usedRolls == 0 ? 1 : usedRolls;
    }

    SchockenScore score = _evaluateDice(_currentDiceValues, usedRolls, List.from(_heldDiceIndices));
    _playerScores[_currentPlayerIndex] = score;

    bool allPlayersDone = !_playerScores.contains(null);

    if (allPlayersDone) {
      setState(() {
        _isRoundFinished = true;
      });
    } else {
      setState(() {
        _currentPlayerIndex = (_currentPlayerIndex + 1) % widget.playerNames.length;
        _startRound();
      });
    }
  }

  SchockenScore _evaluateDice(List<int> dice, int diceCount, List<int> heldIndices) {
    final sorted = List<int>.from(dice)..sort((a,b) => b.compareTo(a));

    if (sorted.every((d) => d == 1)) {
      return SchockenScore(type: SchockenRollType.schockOut, value: 7, lidValue: 13, diceCount: diceCount, diceValues: dice, heldDiceIndices: heldIndices);
    }
    if (sorted.contains(1) && sorted.where((e) => e == 1).length == 2) {
      int val = sorted.firstWhere((e) => e != 1);
      return SchockenScore(type: SchockenRollType.schockX, value: val, lidValue: val, diceCount: diceCount, diceValues: dice, heldDiceIndices: heldIndices);
    }
    if (sorted[0] == sorted[1] && sorted[1] == sorted[2]) {
      return SchockenScore(type: SchockenRollType.pasch, value: sorted[0], lidValue: 3, diceCount: diceCount, diceValues: dice, heldDiceIndices: heldIndices);
    }
    final unique = sorted.toSet();
    if (unique.length == 3 && (sorted[0] == sorted[1] + 1 && sorted[1] == sorted[2] + 1)) {
      return SchockenScore(type: SchockenRollType.straight, value: int.parse(sorted.join()), lidValue: 2, diceCount: diceCount, diceValues: dice, heldDiceIndices: heldIndices);
    }

    int value = int.parse(sorted.join());
    return SchockenScore(type: SchockenRollType.simple, value: value, lidValue: 1, diceCount: diceCount, diceValues: dice, heldDiceIndices: heldIndices);
  }

  /// ## Startet die Aufdeck-Animation (ANGEPASST)
  /// Zeigt nur noch das beste Ergebnis an.
  Future<void> _startRevealAnimationSequence() async {
    setState(() {
      _isRevealSequenceRunning = true;
    });

    List<SchockenScore?> sortedScores = List.from(_playerScores);
    sortedScores.sort((a, b) => a!.isBetterThan(b!) ? -1 : 1);

    final bestScore = sortedScores.first;

    if (bestScore != null) {
      setState(() {
        _animationText = bestScore.typeString;
      });
      await _animationController.forward();
      await Future.delayed(const Duration(milliseconds: 1200)); // Längere Pause, damit man es lesen kann
      await _animationController.reverse();
      await Future.delayed(const Duration(milliseconds: 200));
    }

    _calculateAndShowFinalResult();
  }

  /// ## Berechnet das endgültige Ergebnis nach der Animation
  void _calculateAndShowFinalResult() {
    List<MapEntry<String, SchockenScore>> scoredPlayers = [];
    for (int i = 0; i < widget.playerNames.length; i++) {
      if (_playerScores[i] != null) {
        scoredPlayers.add(MapEntry(widget.playerNames[i], _playerScores[i]!));
      }
    }

    scoredPlayers.sort((a, b) => a.value.isBetterThan(b.value) ? -1 : 1);

    String loserName = scoredPlayers.last.key;
    int loserIndex = widget.playerNames.indexOf(loserName);
    SchockenScore bestScoreOfRound = scoredPlayers.first.value;
    int lidsToTransfer = bestScoreOfRound.lidValue;

    bool halfLost = false;
    bool gameLost = false;

    _loserIndexAtStartOfRound = loserIndex;
    _currentPlayerIndex = loserIndex;

    setState(() {
      _roundLoserName = loserName;
      _roundLidsTransferred = lidsToTransfer;
      _wasHalfLost = halfLost;
      _wasGameLost = gameLost;
      _areResultsRevealed = true;
      _isRevealSequenceRunning = false;
    });
  }

  // ---------------------------------------------------------------------------
  // UI BUILD Methoden
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
                          onPressed: widget.onGameQuit,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: _buildMainContentArea(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: _buildScoreboard(),
                ),
              ],
            ),
            _buildAnimationOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContentArea() {
    if (_isRoundFinished && !_areResultsRevealed && !_isRevealSequenceRunning) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.network(
            DiceAssetPaths.diceCupUrl,
            width: 180,
            height: 180,
            errorBuilder: (_, __, ___) => const Icon(Icons.casino, size: 180, color: Colors.white),
          ),
          const SizedBox(height: 40),
          _buildActionButton('AUFDECKEN', _startRevealAnimationSequence, isPrimary: true),
        ],
      );
    }
    else if (_isRoundFinished && _areResultsRevealed) {
      String buttonText = _wasGameLost ? 'SPIEL BEENDEN' : _wasHalfLost ? 'NÄCHSTE HALBZEIT' : 'NÄCHSTE RUNDE';

      VoidCallback nextAction = () {
        if (_wasGameLost) {
          widget.onGameQuit();
        } else if (_wasHalfLost) {
          _startHalf();
        } else {
          _startRound();
        }
      };

      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildAllPlayerRollsDisplay(),
          const SizedBox(height: 40),
          _buildActionButton(buttonText, nextAction, isPrimary: true),
        ],
      );
    }
    else {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _isRevealSequenceRunning ? _buildAllPlayerRollsDisplay() : _buildDiceArea(),
          const SizedBox(height: 40),
          if (!_isRoundFinished) _buildGameButtons(),
        ],
      );
    }
  }

  /// ## Animations-Overlay Widget (ANGEPASST)
  /// Nutzt jetzt zusätzlich eine SlideTransition.
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

  Widget _buildAllPlayerRollsDisplay() {
    final titleStyle = const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold);
    final diceSize = MediaQuery.of(context).size.width * 0.15;
    final resultStyle = const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold);

    String resultText = "";
    if (_roundLoserName != null) {
      resultText = _wasHalfLost
          ? '$_roundLoserName hat eine Halbzeit verloren!'
          : '$_roundLoserName erhält $_roundLidsTransferred Deckel.';
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ...widget.playerNames.asMap().entries.map((entry) {
          int playerIndex = entry.key;
          String playerName = entry.value;
          SchockenScore? score = _playerScores[playerIndex];
          if (score == null) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Column(
              children: [
                Text(playerName, style: titleStyle),
                const SizedBox(height: 8),
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
        if(resultText.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(resultText, style: resultStyle, textAlign: TextAlign.center),
        ]
      ],
    );
  }

  Widget _buildDiceArea() {
    if (_rollsLeft == 3) {
      return Image.network(
        DiceAssetPaths.diceCupUrl,
        width: 150,
        height: 150,
        errorBuilder: (_, __, ___) => const Icon(Icons.casino, size: 150, color: Colors.white),
      );
    }

    final double diceSize = MediaQuery.of(context).size.width * 0.28;

    List<Widget> diceWidgets = List.generate(3, (index) {
      return SizedBox(
        width: diceSize,
        height: diceSize / DiceAssetDisplay.diceAspectRatio,
        child: DiceAssetDisplay(
          value: _currentDiceValues[index],
          isHeld: _heldDiceIndices.contains(index),
          onTap: () => _onDiceTap(index),
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

  Widget _buildGameButtons() {
    final bool canRollAgain = (_currentPlayerIndex == _loserIndexAtStartOfRound || (3 - _rollsLeft) < _maxRollsInRound) && _rollsLeft > 0;

    if (_rollsLeft == 3) {
      return _buildActionButton('WÜRFELN', _rollDice, isPrimary: true);
    } else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton('LASSEN', () => _endTurn(false)),
          _buildActionButton('NOCHMAL', canRollAgain ? _rollDice : null),
        ],
      );
    }
  }

  Widget _buildActionButton(String text, VoidCallback? onPressed, {bool isPrimary = false}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.black,
        backgroundColor: const Color(0xFFD9D9D9),
        disabledBackgroundColor: Colors.grey.shade400,
        minimumSize: Size(isPrimary ? 250 : 150, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
          side: const BorderSide(color: Colors.black, width: 2),
        ),
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.5),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
    );
  }

  Widget _buildScoreboard() {
    const headerStyle = TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16);
    const cellStyle = TextStyle(color: Colors.white, fontSize: 18);

    Widget verticalDivider() => Container(height: 30, width: 1.5, color: Colors.white38);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Expanded(flex: 3, child: Text('SPIELER', style: headerStyle)),
            const Expanded(flex: 3, child: Center(child: Text('WURF', style: headerStyle))),
            verticalDivider(),
            const Expanded(flex: 2, child: Center(child: Text('DECKEL', style: headerStyle))),
            verticalDivider(),
            const Expanded(flex: 1, child: Center(child: Text('HZ', style: headerStyle))),
          ],
        ),
        const Divider(color: Colors.white38, thickness: 1.5),

        ...List.generate(widget.playerNames.length, (index) {
          final isCurrent = index == _currentPlayerIndex && !_isRoundFinished;
          final score = _playerScores[index];

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
                      )
                          : const Text('...', style: cellStyle),
                    )
                ),
                verticalDivider(),
                Expanded(
                  flex: 2,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.circle, color: Colors.grey.shade300, size: 24),
                      const SizedBox(width: 8),
                      Text(_playerLids[index].toString(), style: cellStyle),
                    ],
                  ),
                ),
                verticalDivider(),
                Expanded(
                  flex: 1,
                  child: Center(
                    child: Icon(
                      _playerHalfLosses[index] >= 1 ? Icons.pie_chart : Icons.circle_outlined,
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

