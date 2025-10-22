import 'package:flutter/foundation.dart'; // Für ChangeNotifier
import 'dart:math' as math;

// Enums und Score-Klasse bleiben hier oder können in eine eigene Datei (models.dart)
enum SchockenRollType { simple, straight, pasch, schockX, schockOut }

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
    // SchockOut schlägt alles
    if (type == SchockenRollType.schockOut && other.type != SchockenRollType.schockOut) return true;
    if (type != SchockenRollType.schockOut && other.type == SchockenRollType.schockOut) return false;
    // SchockX schlägt alles außer SchockOut
    if (type == SchockenRollType.schockX && other.type != SchockenRollType.schockX && other.type != SchockenRollType.schockOut) return true;
    if (type != SchockenRollType.schockX && type != SchockenRollType.schockOut && other.type == SchockenRollType.schockX) return false;

    // Vergleich innerhalb SchockX
    if (type == SchockenRollType.schockX && other.type == SchockenRollType.schockX) {
      return value > other.value; // Höherer Schock ist besser
    }

    // Standard-Enum-Vergleich (Pasch > Straight > Simple)
    // Beachte: Pasch/Straight/Simple werden nur nach Typ sortiert, der Wert ist sekundär,
    // außer bei Simple, wo niedriger besser ist, wenn der Typ gleich ist.
    if (type.index > other.type.index) return true;
    if (type.index < other.type.index) return false;


    // Bei gleichem Typ
    if (type == SchockenRollType.simple) {
      // Niedrigere Hausnummer ist besser
      // Sortiere absteigend für Wert (654 > 432), aber in der Logik ist kleiner besser
      int thisValue = int.parse((List.from(diceValues)..sort((a, b) => b.compareTo(a))).join());
      int otherValue = int.parse((List.from(other.diceValues)..sort((a, b) => b.compareTo(a))).join());
      return thisValue < otherValue;
    }
    if (type == SchockenRollType.pasch) {
      // Höherer Pasch ist besser
      return value > other.value;
    }
    if (type == SchockenRollType.straight) {
      // Höhere Straße ist besser (z.B. 456 > 123)
      List<int> thisSorted = List.from(diceValues)..sort();
      List<int> otherSorted = List.from(other.diceValues)..sort();
      int thisStraightValue = int.parse(thisSorted.join());
      int otherStraightValue = int.parse(otherSorted.join());
      return thisStraightValue > otherStraightValue;
    }

    // Fallback (sollte nicht erreicht werden)
    return false;
  }


  String get typeString {
    switch (type) {
      case SchockenRollType.schockOut:
        return 'Schock-Aus!';
      case SchockenRollType.schockX:
        return 'Schock $value';
      case SchockenRollType.pasch:
        return 'Pasch ${diceValues[0]}er'; // Angepasst
      case SchockenRollType.straight:
      // Zeigt die höchste Zahl der Straße an
        int highest = diceValues.reduce(math.max);
        return 'Straße bis $highest';
      case SchockenRollType.simple:
      // Sortiert für korrekte Hausnummernanzeige (höchste zuerst)
        List<int> sortedDice = List.from(diceValues)..sort((a, b) => b.compareTo(a));
        return 'Hausnr. ${sortedDice.join()}';
    }
  }
}


// Die Haupt-Logik-Klasse
class SchockenGame extends ChangeNotifier {
  final List<String> playerNames;

  SchockenGame(this.playerNames) {
    _playerLids = List.generate(playerNames.length, (index) => 0);
    _playerHalfLosses = List.generate(playerNames.length, (index) => 0);
    _playerScores = List.generate(playerNames.length, (index) => null);
    _initializeRound(); // Startet die erste Runde
  }

  // --- Spielzustand ---
  late List<int> _playerLids;
  late List<int> _playerHalfLosses;
  late List<SchockenScore?> _playerScores;
  int _lidsInMiddle = 13;
  int _rollsLeft = 3;
  int _currentPlayerIndex = 0;
  int _half = 1;
  int _loserIndexAtStartOfRound = 0; // Index des Spielers, der die Runde beginnt
  List<int> _currentDiceValues = [1, 1, 1];
  List<int> _heldDiceIndices = [];
  int _maxRollsInRound = 3;

  // Phasensteuerung
  bool _isRoundFinished = false;
  bool _areResultsCalculated = false; // Geändert von _areResultsRevealed

  // Ergebnisanzeige
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
  String get currentPlayerName => playerNames[_currentPlayerIndex];
  int get half => _half;
  List<int> get currentDiceValues => _currentDiceValues;
  List<int> get heldDiceIndices => _heldDiceIndices;
  int get maxRollsInRound => _maxRollsInRound;
  int get loserIndexAtStartOfRound => _loserIndexAtStartOfRound; // GETTER HINZUGEFÜGT
  bool get isRoundFinished => _isRoundFinished;
  bool get areResultsCalculated => _areResultsCalculated;
  String? get roundWinnerName => _roundWinnerName;
  String? get roundLoserName => _roundLoserName;
  int get roundLidsTransferred => _roundLidsTransferred;
  bool get wasHalfLost => _wasHalfLost;
  bool get wasGameLost => _wasGameLost;

  // --- Spielaktionen ---

  void _initializeRound() {
    _rollsLeft = 3;
    _currentDiceValues = [1, 1, 1];
    _heldDiceIndices = [];
    _isRoundFinished = false;
    _areResultsCalculated = false;
    _roundLoserName = null;
    _roundWinnerName = null;

    if (_currentPlayerIndex == _loserIndexAtStartOfRound) {
      _maxRollsInRound = 3;
      _playerScores = List.generate(playerNames.length, (index) => null);
    }
    if (_playerScores[_currentPlayerIndex] != null) {
      _playerScores[_currentPlayerIndex] = null;
    }
    notifyListeners();
  }

  void startNextRoundOrHalf() {
    if (_wasGameLost) {
      print("Spiel zu Ende!");
      return;
    } else if (_wasHalfLost) {
      startNextHalf();
    } else {
      // Der Verlierer der letzten Runde beginnt die nächste
      _currentPlayerIndex = _loserIndexAtStartOfRound;
      _initializeRound();
    }
  }


  void startNextHalf() {
    _half++;
    _lidsInMiddle = 13;
    _playerLids = List.generate(playerNames.length, (index) => 0);
    _currentPlayerIndex = _loserIndexAtStartOfRound; // Verlierer beginnt
    _initializeRound();
  }

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
      endTurn(true); // Automatisches Beenden
    }
    notifyListeners();
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

    SchockenScore score = _evaluateDice(_currentDiceValues, usedRolls, List.from(_heldDiceIndices));
    _playerScores[_currentPlayerIndex] = score;

    bool allPlayersDone = !_playerScores.contains(null);

    if (allPlayersDone) {
      _isRoundFinished = true;
    } else {
      _currentPlayerIndex = (_currentPlayerIndex + 1) % playerNames.length;
      // Hier _initializeRound rufen, um den nächsten Spieler vorzubereiten
      // Wichtig: _initializeRound prüft, ob es der Startspieler ist und setzt ggf. Scores zurück
      _initializeRound();
    }
    notifyListeners();
  }

  SchockenScore _evaluateDice(List<int> dice, int diceCount, List<int> heldIndices) {
    final sorted = List<int>.from(dice)..sort((a,b) => b.compareTo(a)); // Höchste zuerst

    // Schock-Aus (111)
    if (dice.every((d) => d == 1)) {
      return SchockenScore(type: SchockenRollType.schockOut, value: 111, lidValue: 13, diceCount: diceCount, diceValues: dice, heldDiceIndices: heldIndices);
    }
    // Schock (X11)
    if (dice.where((d) => d == 1).length == 2) {
      int val = dice.firstWhere((d) => d != 1);
      return SchockenScore(type: SchockenRollType.schockX, value: val, lidValue: val, diceCount: diceCount, diceValues: dice, heldDiceIndices: heldIndices);
    }
    // Pasch (XXX)
    if (dice[0] == dice[1] && dice[1] == dice[2]) {
      return SchockenScore(type: SchockenRollType.pasch, value: dice[0], lidValue: 3, diceCount: diceCount, diceValues: dice, heldDiceIndices: heldIndices);
    }
    // Straße (sortiert prüfen!)
    final uniqueSorted = (List<int>.from(dice)..sort()).toSet().toList();
    if (uniqueSorted.length == 3 && uniqueSorted[0] + 1 == uniqueSorted[1] && uniqueSorted[1] + 1 == uniqueSorted[2]) {
      return SchockenScore(type: SchockenRollType.straight, value: int.parse(uniqueSorted.join()), lidValue: 2, diceCount: diceCount, diceValues: dice, heldDiceIndices: heldIndices);
    }

    // Einfache Zahl / Hausnummer (höchste zuerst)
    int value = int.parse(sorted.join());
    return SchockenScore(type: SchockenRollType.simple, value: value, lidValue: 1, diceCount: diceCount, diceValues: dice, heldDiceIndices: heldIndices);
  }


  void calculateAndSetResults() {
    if (!_isRoundFinished) return;

    List<MapEntry<String, SchockenScore>> scoredPlayers = [];
    for (int i = 0; i < playerNames.length; i++) {
      if (_playerScores[i] != null) {
        scoredPlayers.add(MapEntry(playerNames[i], _playerScores[i]!));
      }
    }

    // Sortiere von Bester (Index 0) zu Schlechtester (letzter Index)
    scoredPlayers.sort((a, b) => a.value.isBetterThan(b.value) ? -1 : 1);


    _roundWinnerName = scoredPlayers.first.key;
    _roundLoserName = scoredPlayers.last.key;
    int loserIndex = playerNames.indexOf(_roundLoserName!);
    SchockenScore bestScoreOfRound = scoredPlayers.first.value;
    _roundLidsTransferred = bestScoreOfRound.lidValue;

    _wasHalfLost = false;
    _wasGameLost = false;

    // --- Deckel-Logik ---
    int lidsFromMiddle = math.min(_lidsInMiddle, _roundLidsTransferred);
    _playerLids[loserIndex] += lidsFromMiddle;
    _lidsInMiddle -= lidsFromMiddle;

    if (lidsFromMiddle < _roundLidsTransferred && playerNames.length > 1) {
      int winnerIndex = playerNames.indexOf(_roundWinnerName!);
      if (winnerIndex != loserIndex) {
        int lidsFromWinner = _roundLidsTransferred - lidsFromMiddle;
        int actualLidsFromWinner = math.min(_playerLids[winnerIndex], lidsFromWinner);
        _playerLids[winnerIndex] -= actualLidsFromWinner;
        _playerLids[loserIndex] += actualLidsFromWinner;
      }
    }
    // --- Ende Deckel-Logik ---


    if (_playerLids[loserIndex] >= 13) {
      _wasHalfLost = true;
      // Bei Halbzeitverlust werden alle Deckel zurückgesetzt und die Mitte aufgefüllt
      _playerLids = List.generate(playerNames.length, (index) => 0);
      _lidsInMiddle = 13;
      _playerHalfLosses[loserIndex]++;
      if (_playerHalfLosses[loserIndex] >= 2) {
        _wasGameLost = true;
      }
    }


    _loserIndexAtStartOfRound = loserIndex; // Setzt den Index für die nächste Runde
    // _currentPlayerIndex wird erst beim Start der nächsten Runde gesetzt

    _areResultsCalculated = true; // Markiert, dass die Berechnung abgeschlossen ist
    notifyListeners();
  }
}

