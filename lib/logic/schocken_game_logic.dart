import 'package:flutter/foundation.dart'; // Für ChangeNotifier
import 'dart:math' as math; // Wird für Sortierung und Deckel-Logik benötigt

// --- ENUMS UND DATENSTRUKTUREN ---

enum SchockenRollType {
  simple,     // Niedrigster Rang
  straight,
  pasch,
  schockX,
  schockOut   // Höchster Rang
}

class SchockenScore {
  final SchockenRollType type;
  final int value; // Numerischer Wert zur Sortierung innerhalb des Typs
  // Höher ist besser, AUSSER bei Simple (niedriger ist schlechter/weniger gut)
  final int lidValue; // Anzahl Deckel für diesen Wurf
  final int diceCount; // Anzahl der Würfe (1-3)
  final List<int> diceValues; // Die tatsächlichen Würfel [6, 1, 1]
  final List<int> heldDiceIndices;
  final int playerIndex; // Index des Spielers, der geworfen hat (für Tie-Breaking)

  SchockenScore({
    required this.type,
    required this.value,
    required this.lidValue,
    required this.diceCount,
    required this.diceValues,
    required this.heldDiceIndices,
    required this.playerIndex,
  });

  /// Vergleicht diesen Score mit einem anderen.
  /// Gibt true zurück, wenn dieser Score BESSER ist als der andere.
  bool isBetterThan(SchockenScore other) {
    // 1. Nach Typ vergleichen (höherer Index ist besser)
    if (type.index > other.type.index) return true;
    if (type.index < other.type.index) return false;

    // 2. Bei gleichem Typ:
    // Für Simple ist ein NIEDRIGERER Wert schlechter (also ein HÖHERER Wert besser im Vergleich)
    if (type == SchockenRollType.simple) {
      // Höhere Hausnummer ist "besser" (weniger schlecht)
      return value > other.value;
    }

    // Für alle anderen Typen ist ein HÖHERER Wert besser
    return value > other.value;
  }

  String get typeString {
    switch (type) {
      case SchockenRollType.schockOut:
        return 'Schock-Aus!';
      case SchockenRollType.schockX:
      // Finde den Wert des Schocks (die Zahl, die keine 1 ist)
        int schockValue = diceValues.firstWhere((d) => d != 1, orElse: () => 0);
        return 'Schock $schockValue';
      case SchockenRollType.pasch:
      // Zeigt den Wert des Pasches an, z.B. "Pasch 6er"
        return 'Pasch ${diceValues[0]}er'; // Alle Würfel sind gleich
      case SchockenRollType.straight:
      // Zeigt die Straße an, z.B. "Straße 456"
        List<int> sorted = List.from(diceValues)..sort();
        return 'Straße ${sorted.join()}';
      case SchockenRollType.simple:
      // Zeigt die Hausnummer an (höchste zuerst)
        List<int> sorted = List.from(diceValues)..sort((a, b) => b.compareTo(a));
        return '${sorted.join()}'; // Nur die Zahl anzeigen
    }
  }
}


// --- SPIELLOGIK ---

class SchockenGame extends ChangeNotifier {
  // --- Spielzustand ---
  final List<String> playerNames;
  late List<int> _playerLids;
  late List<int> _playerHalfLosses;
  late List<SchockenScore?> _playerScores; // Index entspricht Spielerindex
  int _lidsInMiddle = 13;
  int _rollsLeft = 3;
  int _currentPlayerIndex = 0;
  int _half = 1;
  int _loserIndexAtStartOfRound = 0; // Index des Spielers, der die Runde beginnt
  List<int> _currentDiceValues = [1, 1, 1];
  List<int> _heldDiceIndices = [];
  int _maxRollsInRound = 3; // Max. erlaubte Würfe in dieser Runde

  // --- Phasensteuerung ---
  bool _isRoundFinished = false;
  bool _areResultsCalculated = false;

  // --- Ergebnisanzeige ---
  String? _roundWinnerName;
  String? _roundLoserName;
  int _roundLidsTransferred = 0;
  bool _wasHalfLost = false;
  bool _wasGameLost = false;

  // --- Getters für die UI ---
  List<int> get playerLids => _playerLids;
  List<int> get playerHalfLosses => _playerHalfLosses;
  List<SchockenScore?> get playerScores => _playerScores;
  int get lidsInMiddle => _lidsInMiddle;
  int get rollsLeft => _rollsLeft;
  int get currentPlayerIndex => _currentPlayerIndex;
  int get half => _half;
  int get loserIndexAtStartOfRound => _loserIndexAtStartOfRound;
  List<int> get currentDiceValues => _currentDiceValues;
  List<int> get heldDiceIndices => _heldDiceIndices;
  int get maxRollsInRound => _maxRollsInRound;
  bool get isRoundFinished => _isRoundFinished;
  bool get areResultsCalculated => _areResultsCalculated;
  String? get roundWinnerName => _roundWinnerName;
  String? get roundLoserName => _roundLoserName;
  int get roundLidsTransferred => _roundLidsTransferred;
  bool get wasHalfLost => _wasHalfLost;
  bool get wasGameLost => _wasGameLost;

  // --- Konstruktor ---
  SchockenGame(this.playerNames) {
    _playerLids = List.generate(playerNames.length, (index) => 0);
    _playerHalfLosses = List.generate(playerNames.length, (index) => 0);
    _playerScores = List.generate(playerNames.length, (index) => null);
    _startRound(); // Starte die erste Runde
  }

  // --- Spielaktionen ---
  void rollDice() {
    if (_currentPlayerIndex != _loserIndexAtStartOfRound && (3 - _rollsLeft) >= _maxRollsInRound) return;
    if (_rollsLeft == 0) return;

    _rollsLeft--;
    final random = math.Random();
    for (int i = 0; i < 3; i++) {
      if (!_heldDiceIndices.contains(i)) {
        _currentDiceValues[i] = 1 + random.nextInt(6);
      }
    }

    final currentRolls = 3 - _rollsLeft;

    if ((_currentPlayerIndex != _loserIndexAtStartOfRound && currentRolls >= _maxRollsInRound) || _rollsLeft == 0) {
      endTurn(true);
    } else {
      notifyListeners();
    }
  }

  void handleDiceTap(int index) {
    if (_rollsLeft == 0) return;

    final sixes = _currentDiceValues.where((v) => v == 6).toList();
    if (sixes.length == 2) {
      int thirdDieIndex = _currentDiceValues.indexWhere((v) => v != 6);
      if (index == thirdDieIndex && _currentDiceValues[index] != 1) {
        _currentDiceValues[index] = 1;
        if (!_heldDiceIndices.contains(index)) {
          _heldDiceIndices.add(index);
        }
        notifyListeners();
        return;
      }
    }

    if (_currentDiceValues[index] == 1) {
      if (_heldDiceIndices.contains(index)) {
        _heldDiceIndices.remove(index);
      } else {
        _heldDiceIndices.add(index);
      }
      notifyListeners();
    }
  }


  void endTurn(bool isForced) {
    if (!isForced && _rollsLeft == 3) return;
    final usedRolls = 3 - _rollsLeft;

    if (_currentPlayerIndex == _loserIndexAtStartOfRound) {
      _maxRollsInRound = usedRolls == 0 ? 1 : usedRolls;
    }

    SchockenScore score = _evaluateDice(_currentDiceValues, usedRolls, List.from(_heldDiceIndices), _currentPlayerIndex);
    _playerScores[_currentPlayerIndex] = score;

    bool allPlayersDone = true;
    for (var score in _playerScores) {
      if (score == null) {
        allPlayersDone = false;
        break;
      }
    }
    // Kompaktere Prüfung: bool allPlayersDone = !_playerScores.contains(null);


    if (allPlayersDone) {
      _isRoundFinished = true;
    } else {
      _currentPlayerIndex = (_currentPlayerIndex + 1) % playerNames.length;
      _prepareNextTurn();
    }
    notifyListeners();
  }

  // --- Runden-/Spiel-Management ---
  void _startRound() {
    _rollsLeft = 3;
    _currentDiceValues = [1, 1, 1];
    _heldDiceIndices = [];
    _isRoundFinished = false;
    _areResultsCalculated = false;
    _roundWinnerName = null;
    _roundLoserName = null;
    _wasHalfLost = false;
    _wasGameLost = false;

    if (_currentPlayerIndex == _loserIndexAtStartOfRound) {
      _maxRollsInRound = 3;
      // Scores nur zurücksetzen, wenn eine *komplett neue* Runde beginnt (also vom Verlierer gestartet)
      _playerScores = List.generate(playerNames.length, (index) => null);
    } else {
      // Wenn ein anderer Spieler dran ist, nur dessen Score zurücksetzen
      if(_playerScores[_currentPlayerIndex] != null) {
        _playerScores[_currentPlayerIndex] = null;
      }
    }

    // Kein notifyListeners() hier, da es von außen kommt
  }

  void _prepareNextTurn() {
    _rollsLeft = 3;
    _currentDiceValues = [1, 1, 1];
    _heldDiceIndices = [];
    // Wichtig: _isRoundFinished etc. hier *nicht* zurücksetzen
    // Score des nächsten Spielers wird in _startRound() zurückgesetzt, wenn er dran ist
    // Hier nichts tun bzgl. Scores
  }


  void startNextRoundOrHalf() {
    if (_wasHalfLost) {
      _startHalf();
    } else {
      // Wichtig: _currentPlayerIndex wurde bereits in calculateAndSetResults gesetzt
      _startRound();
    }
    notifyListeners();
  }

  void _startHalf() {
    _half++;
    _lidsInMiddle = 13;
    _playerLids = List.generate(playerNames.length, (index) => 0);
    // _currentPlayerIndex bleibt der Verlierer der letzten Runde
    _startRound();
    // notifyListeners() in startNextRoundOrHalf
  }


  // --- Ergebnisberechnung (Logik stark überarbeitet) ---
  SchockenScore _evaluateDice(List<int> dice, int diceCount, List<int> heldIndices, int playerIndex) {
    // Sortiere absteigend für die Hausnummern-Bildung
    final sortedHighToLow = List<int>.from(dice)..sort((a,b) => b.compareTo(a));
    // Sortiere aufsteigend für Straßen-Prüfung und Wert
    final sortedLowToHigh = List<int>.from(dice)..sort();
    final unique = dice.toSet();

    // 1. Schock Out (111)
    if (dice.every((d) => d == 1)) {
      // Value für Vergleichszwecke, Deckelwert ist 13
      return SchockenScore(type: SchockenRollType.schockOut, value: 7, lidValue: 13, diceCount: diceCount, diceValues: dice, heldDiceIndices: heldIndices, playerIndex: playerIndex);
    }

    // 2. Schock X (X11)
    if (dice.where((e) => e == 1).length == 2) {
      int schockValue = dice.firstWhere((e) => e != 1);
      // Value ist der Wert des Schocks (6 > 5 > ...) für Vergleich, Deckelwert ist schockValue
      return SchockenScore(type: SchockenRollType.schockX, value: schockValue, lidValue: schockValue, diceCount: diceCount, diceValues: dice, heldDiceIndices: heldIndices, playerIndex: playerIndex);
    }

    // 3. Pasch (XXX)
    if (unique.length == 1) {
      // Value ist der Wert des Pasches (6 > 5 > ...) für Vergleich, Deckelwert ist 3
      return SchockenScore(type: SchockenRollType.pasch, value: dice[0], lidValue: 3, diceCount: diceCount, diceValues: dice, heldDiceIndices: heldIndices, playerIndex: playerIndex);
    }

    // 4. Straße (123, 234, 345, 456)
    if (unique.length == 3 && (sortedLowToHigh[0] + 1 == sortedLowToHigh[1] && sortedLowToHigh[1] + 1 == sortedLowToHigh[2])) {
      // Value ist die numerische Darstellung (456 > 345 > ...) für Vergleich, Deckelwert ist 2
      return SchockenScore(type: SchockenRollType.straight, value: int.parse(sortedLowToHigh.join()), lidValue: 2, diceCount: diceCount, diceValues: dice, heldDiceIndices: heldIndices, playerIndex: playerIndex);
    }

    // 5. Simple (Hausnummer)
    // Value ist die Hausnummer (höchste zuerst), z.B. 643.
    // ACHTUNG: Niedrigere Hausnummer ist SCHLECHTER (verliert eher). In isBetterThan wird < verwendet.
    int hausnummerValue = int.parse(sortedHighToLow.join());
    return SchockenScore(type: SchockenRollType.simple, value: hausnummerValue, lidValue: 1, diceCount: diceCount, diceValues: dice, heldDiceIndices: heldIndices, playerIndex: playerIndex);
  }

  /// Berechnet Endergebnis mit korrigiertem Tie-Breaking
  void calculateAndSetResults() {
    if (!_isRoundFinished) return;

    List<MapEntry<String, SchockenScore>> scoredPlayers = getSortedPlayerScores(); // Sortiert von Best nach Schlechtest

    // --- KORRIGIERTE Tie-Breaking Logik ---
    String finalLoserName = scoredPlayers.last.key; // Annahme: Letzter ist Verlierer
    SchockenScore loserScore = scoredPlayers.last.value;

    // Finde alle Spieler mit dem gleichen schlechtesten Score
    List<MapEntry<String, SchockenScore>> potentialLosers = scoredPlayers
        .where((entry) =>
    entry.value.type == loserScore.type && entry.value.value == loserScore.value)
        .toList();

    if (potentialLosers.length > 1) {
      // Schock Out: Der LETZTE Spieler verliert (höchster Index)
      if (loserScore.type == SchockenRollType.schockOut) {
        potentialLosers.sort((a, b) => b.value.playerIndex.compareTo(a.value.playerIndex)); // Sortiert absteigend nach Index
        finalLoserName = potentialLosers.first.key;
      }
      // Andere Typen: Der ERSTE Spieler verliert (niedrigster Index)
      else {
        potentialLosers.sort((a, b) => a.value.playerIndex.compareTo(b.value.playerIndex)); // Sortiert aufsteigend nach Index
        finalLoserName = potentialLosers.first.key;
      }
    }
    // --- Ende Tie-Breaking ---

    _roundWinnerName = scoredPlayers.first.key; // Gewinner ist immer der Erste nach normaler Sortierung
    _roundLoserName = finalLoserName; // Der Verlierer nach Tie-Breaking
    int loserIndex = playerNames.indexOf(_roundLoserName!);
    SchockenScore bestScoreOfRound = scoredPlayers.first.value; // Bester Score bestimmt Deckel
    _roundLidsTransferred = bestScoreOfRound.lidValue;

    _wasHalfLost = false;
    _wasGameLost = false;

    // --- Deckel-Logik ---
    int lidsToTake = _roundLidsTransferred;
    int lidsFromMiddle = math.min(_lidsInMiddle, lidsToTake);
    _playerLids[loserIndex] += lidsFromMiddle;
    _lidsInMiddle -= lidsFromMiddle;
    lidsToTake -= lidsFromMiddle;

    if (lidsToTake > 0 && playerNames.length > 1) {
      int winnerIndex = playerNames.indexOf(_roundWinnerName!);
      if (winnerIndex != loserIndex) {
        int actualLidsFromWinner = math.min(_playerLids[winnerIndex], lidsToTake);
        _playerLids[winnerIndex] -= actualLidsFromWinner;
        _playerLids[loserIndex] += actualLidsFromWinner;
      }
    }
    // --- Ende Deckel-Logik ---


    if (_playerLids[loserIndex] >= 13) {
      _wasHalfLost = true;
      // Bei Halbzeitverlust werden ALLE Deckel zurückgesetzt und die Mitte aufgefüllt
      _playerLids = List.generate(playerNames.length, (index) => 0);
      _lidsInMiddle = 13;
      _playerHalfLosses[loserIndex]++;
      if (_playerHalfLosses[loserIndex] >= 2) {
        _wasGameLost = true;
      }
    }

    _loserIndexAtStartOfRound = loserIndex; // Verlierer beginnt nächste Runde
    _currentPlayerIndex = loserIndex;      // Setzt den Index für _startRound()

    _areResultsCalculated = true; // Markiert, dass Ergebnisse berechnet wurden
    notifyListeners(); // UI über Ergebnisse informieren
  }

  /// Gibt eine sortierte Liste der Spieler und ihrer Scores zurück (Bester zuerst).
  List<MapEntry<String, SchockenScore>> getSortedPlayerScores() {
    List<MapEntry<String, SchockenScore>> scoredPlayers = [];
    for (int i = 0; i < playerNames.length; i++) {
      if (_playerScores[i] != null) {
        scoredPlayers.add(MapEntry(playerNames[i], _playerScores[i]!));
      }
    }
    // Sortiert von Bester (links/Index 0) zu Schlechtester (rechts/letzter Index)
    scoredPlayers.sort((a, b) => a.value.isBetterThan(b.value) ? -1 : 1);
    return scoredPlayers;
  }

}

