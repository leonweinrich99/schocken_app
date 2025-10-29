import 'package:flutter/foundation.dart';
import 'dart:math';

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

  FourTwoEighteenScore({
    required this.score,
    required this.usedRolls,
    required this.hasBasis,
    required this.diceValues,
  });

  /// Vergleicht diesen Score mit einem anderen.
  /// Gibt true zurück, wenn dieser Score BESSER ist als der andere.
  bool isBetterThan(FourTwoEighteenScore other) {
    // 1. Basis-Prüfung: Wer keine Basis hat, verliert gegen jeden, der eine hat.
    if (!hasBasis && other.hasBasis) return false;
    if (hasBasis && !other.hasBasis) return true;
    // Wenn beide keine Basis haben, ist es gleich schlecht (Wert 0)
    if (!hasBasis && !other.hasBasis) return false;

    // 2. Score-Prüfung: Höherer Score ist besser
    if (score != other.score) {
      return score > other.score;
    }

    // 3. Wurf-Anzahl (Tie-Breaker): Weniger Würfe sind besser
    if (usedRolls != other.usedRolls) {
      return usedRolls < other.usedRolls;
    }

    // Ansonsten gleichwertig
    return false;
  }
}

// -----------------------------------------------------------------------------
// SPIELLOGIK-KLASSE (ChangeNotifier)
// -----------------------------------------------------------------------------

class FourTwoEighteenGame extends ChangeNotifier {
  final List<String> playerNames;
  final Random _random = Random();
  final int _totalDice = 5;
  final int initialLives = 3; // Starting number of lives

  // --- Spielzustand ---
  late Map<String, int> _playerLives; // Changed from _playerLids
  int _currentPlayerIndex = 0;
  List<int> _currentDiceValues = [1, 1, 1, 1, 1];
  List<bool> _diceHeld = [false, false, false, false, false];
  List<int?> _basisDice = [null, null]; // [0] = 4er-Index, [1] = 2er-Index
  List<int?> _scoreDice = [null, null, null]; // Die drei Indexe der Würfel für die 18
  int _rollsLeft = 3;
  String _gameStatusMessage = '';
  bool _isRoundOver = false;
  bool _isGameOver = false; // Flag to indicate if the game has ended

  Map<String, FourTwoEighteenScore> _roundResults = {};
  Map<String, List<int>> _allPlayerFinalDice = {};

  // --- Getters für die UI ---
  Map<String, int> get playerLives => _playerLives; // Changed from playerLids
  int get currentPlayerIndex => _currentPlayerIndex;
  List<int> get currentDiceValues => _currentDiceValues;
  List<bool> get diceHeld => _diceHeld;
  List<int?> get basisDice => _basisDice;
  List<int?> get scoreDice => _scoreDice;
  int get rollsLeft => _rollsLeft;
  String get gameStatusMessage => _gameStatusMessage;
  bool get isRoundOver => _isRoundOver;
  bool get isGameOver => _isGameOver; // Getter for game over state
  Map<String, FourTwoEighteenScore> get roundResults => _roundResults;
  Map<String, List<int>> get allPlayerFinalDice => _allPlayerFinalDice;

  String get currentPlayerName => playerNames[_currentPlayerIndex];
  bool get hasHeldFour => _basisDice[0] != null;
  bool get hasHeldTwo => _basisDice[1] != null;
  bool get basisFound => hasHeldFour && hasHeldTwo;
  bool get allScoreDiceHeld => _scoreDice.every((element) => element != null);

  // --- Konstruktor ---
  FourTwoEighteenGame(this.playerNames) {
    // Initialize lives for each player
    _playerLives = Map.fromIterable(playerNames, key: (player) => player, value: (_) => initialLives);
    _startPlayerTurn(); // Startet den ersten Zug
  }

  // --- Private Methoden (Logik) ---

  void _startPlayerTurn() {
    if (_isGameOver) return; // Don't start a new turn if game is over
    _currentDiceValues = List.generate(_totalDice, (_) => 1);
    _diceHeld = List.generate(_totalDice, (_) => false);
    _rollsLeft = 3;
    _basisDice = [null, null];
    _scoreDice = [null, null, null];
    _gameStatusMessage = '${playerNames[_currentPlayerIndex]} ist dran.';
    notifyListeners();
  }

  FourTwoEighteenScore _evaluateScore() {
    final usedRolls = 3 - _rollsLeft;
    final finalDiceValues = List<int>.from(_currentDiceValues);

    if (!basisFound || !allScoreDiceHeld) {
      return FourTwoEighteenScore(score: 0, usedRolls: usedRolls, hasBasis: false, diceValues: finalDiceValues);
    }

    int score = 0;
    for (int? index in _scoreDice) {
      if (index != null) {
        score += _currentDiceValues[index];
      }
    }

    return FourTwoEighteenScore(score: score, usedRolls: usedRolls, hasBasis: true, diceValues: finalDiceValues);
  }

  // --- Öffentliche Aktionen (von der UI aufgerufen) ---

  void roll() {
    if (_isRoundOver || _rollsLeft <= 0 || _isGameOver) return;

    // Nur Würfel, die nicht gehalten werden, neu würfeln
    int rollCount = 0;
    for (int i = 0; i < _totalDice; i++) {
      if (!_diceHeld[i]) {
        _currentDiceValues[i] = _random.nextInt(6) + 1;
        rollCount++;
      }
    }

    // Regel: Nach dem ersten Wurf MUSS mindestens ein Würfel gehalten werden.
    if (rollCount == 0 && _rollsLeft > 0 && _rollsLeft < 3) {
      _gameStatusMessage = 'Du musst mindestens einen Würfel behalten oder den Zug beenden.';
      notifyListeners();
      return;
    }

    _rollsLeft--;
    _gameStatusMessage = '$currentPlayerName hat gewürfelt. Würfe übrig: $_rollsLeft';

    // Wenn keine Würfe mehr übrig oder alle Würfel gehalten sind -> Zug beenden
    if (_rollsLeft == 0 || _diceHeld.every((held) => held)) {
      endTurn();
    } else {
      notifyListeners();
    }
  }

  void endTurn() {
    if (_isRoundOver || _isGameOver) return;

    final currentPlayer = playerNames[_currentPlayerIndex];
    final score = _evaluateScore();
    _roundResults[currentPlayer] = score;
    _allPlayerFinalDice[currentPlayer] = List<int>.from(_currentDiceValues);

    final nextPlayerIndex = (_currentPlayerIndex + 1) % playerNames.length;

    if (_roundResults.length == playerNames.length) {
      // Alle Spieler haben gewürfelt -> Runde auflösen
      _isRoundOver = true;
      _resolveRound(); // Benachrichtigt UI
    } else {
      // Nächster Spieler ist dran
      _currentPlayerIndex = nextPlayerIndex;
      _startPlayerTurn();
      // Status message is updated in _startPlayerTurn
      // notifyListeners() is called in _startPlayerTurn
    }
  }

  void setHeldDice(int diceIndex, HoldPosition target) {
    if (_isGameOver) return;
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
      endTurn();
    } else {
      notifyListeners();
    }
  }

  void releaseHeldDice(int diceIndex) {
    if (_isGameOver) return;
    _diceHeld[diceIndex] = false;
    _basisDice = _basisDice.map((index) => index == diceIndex ? null : index).toList();
    _scoreDice = _scoreDice.map((index) => index == diceIndex ? null : index).toList();
    notifyListeners();
  }

  // Rundenauflösung und Lebensabzug
  void _resolveRound() {
    List<MapEntry<String, FourTwoEighteenScore>> sortedResults = _roundResults.entries.toList()
      ..sort((a, b) => a.value.isBetterThan(b.value) ? -1 : 1); // Bester zuerst

    // Finde den/die schlechtesten Spieler
    final worstScore = sortedResults.last.value;
    final losers = sortedResults
        .where((entry) =>
    entry.value.hasBasis == worstScore.hasBasis &&
        entry.value.score == worstScore.score &&
        entry.value.usedRolls == worstScore.usedRolls
    )
        .toList();

    String loserName;
    if (losers.length > 1) {
      // Bei Gleichstand verliert der Spieler, der zuerst gewürfelt hat (niedrigster Index)
      losers.sort((a, b) => playerNames.indexOf(a.key).compareTo(playerNames.indexOf(b.key)));
      loserName = losers.first.key;
      _gameStatusMessage = 'Gleichstand! ${loserName} verliert 1 Leben (zuerst gewürfelt).';
    } else {
      loserName = losers.first.key;
      _gameStatusMessage = '${loserName} verliert 1 Leben.';
    }

    // Decrement life for the loser
    _playerLives[loserName] = (_playerLives[loserName] ?? 0) - 1;

    // Check if the loser is out of lives
    if ((_playerLives[loserName] ?? 0) <= 0) {
      _handlePlayerElimination(loserName);
    } else {
      _currentPlayerIndex = playerNames.indexOf(loserName); // Verlierer beginnt nächste Runde
    }


    notifyListeners(); // UI über Ergebnis informieren
  }

  // Handles player elimination and checks for game over
  void _handlePlayerElimination(String eliminatedPlayer) {
    _gameStatusMessage = '$eliminatedPlayer hat alle Leben verloren!';
    // Optional: Mark player as eliminated if needed for UI

    // Check if only one player remains
    final remainingPlayers = _playerLives.entries.where((entry) => entry.value > 0).toList();
    if (remainingPlayers.length == 1) {
      _isGameOver = true;
      _gameStatusMessage = '${remainingPlayers.first.key} hat gewonnen!';
      _currentPlayerIndex = playerNames.indexOf(remainingPlayers.first.key); // Winner starts technically, but game ends
    } else if (remainingPlayers.isEmpty) {
      // Should not happen with >= 2 players, but handle edge case
      _isGameOver = true;
      _gameStatusMessage = 'Unentschieden! Alle Spieler haben verloren.';
      // Keep current player index or set to 0
    }
    else {
      // Determine the next player (the loser of the round who is *not* eliminated)
      _currentPlayerIndex = playerNames.indexOf(eliminatedPlayer); // Loser still "starts"
      // Find the *next* player in sequence who still has lives
      int nextStarterIndex = _currentPlayerIndex;
      do {
        nextStarterIndex = (nextStarterIndex + 1) % playerNames.length;
      } while ((_playerLives[playerNames[nextStarterIndex]] ?? 0) <= 0);
      _currentPlayerIndex = nextStarterIndex; // This player actually starts the next round
    }
  }


  void startNextRound() {
    if (_isGameOver) return; // Don't start a new round if game is over
    _isRoundOver = false;
    _roundResults = {};
    _allPlayerFinalDice = {};
    // _currentPlayerIndex was set in _resolveRound or _handlePlayerElimination
    _startPlayerTurn();
    // notifyListeners() is called in _startPlayerTurn
  }

  // Method to restart the game
  void restartGame() {
    _playerLives = Map.fromIterable(playerNames, key: (player) => player, value: (_) => initialLives);
    _currentPlayerIndex = 0; // Start with the first player
    _isRoundOver = false;
    _isGameOver = false;
    _roundResults = {};
    _allPlayerFinalDice = {};
    _startPlayerTurn(); // Start the first turn of the new game
    notifyListeners();
  }
}

