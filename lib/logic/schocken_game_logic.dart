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
  // int _half = 1; // Ersetzt durch _gamePhase
  int _loserIndexAtStartOfRound = 0; // Index des Spielers, der die Runde beginnt
  List<int> _currentDiceValues = [1, 1, 1];
  List<int> _heldDiceIndices = [];
  int _maxRollsInRound = 3; // Max. erlaubte Würfe in dieser Runde

  // NEU: Spielphasen-Management
  late List<bool> _activePlayers; // Welche Spieler nehmen teil
  int _gamePhase = 1; // 1 = Stock leeren (für H1 & H2), 2 = Halbzeit (Stock leer), 3 = Finale
  int? _firstHalfLoserIndex; // NEU: Merkt sich, wer H1 verloren hat

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
  List<bool> get activePlayers => _activePlayers; // NEU
  int get lidsInMiddle => _lidsInMiddle;
  int get rollsLeft => _rollsLeft;
  int get currentPlayerIndex => _currentPlayerIndex;
  // int get half => _half; // Ersetzt durch _gamePhase
  int get gamePhase => _gamePhase; // Neuer Getter
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
  int? get firstHalfLoserIndex => _firstHalfLoserIndex; // NEU

  // --- Konstruktor ---
  SchockenGame(this.playerNames) {
    _playerLids = List.generate(playerNames.length, (index) => 0);
    _playerHalfLosses = List.generate(playerNames.length, (index) => 0);
    _playerScores = List.generate(playerNames.length, (index) => null);
    _activePlayers = List.generate(playerNames.length, (index) => true); // Phase 1: Alle aktiv
    _gamePhase = 1;
    _firstHalfLoserIndex = null; // NEU
    _startRound(); // Starte die erste Runde
  }

  // --- Spielaktionen ---
  void rollDice() {
    // Prüft, ob der aktuelle Spieler würfeln darf (basierend auf maxRolls)
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

    // Beende den Zug automatisch, wenn das Wurflimit erreicht ist
    if ((_currentPlayerIndex != _loserIndexAtStartOfRound && currentRolls >= _maxRollsInRound) || _rollsLeft == 0) {
      endTurn(true);
    } else {
      notifyListeners();
    }
  }

  void handleDiceTap(int index) {
    if (_rollsLeft == 0) return; // Nicht nach dem letzten Wurf ändern

    // Sonderregel: Zwei Sechsen -> Dritte Zahl wird zur Eins (wenn nicht schon 1)
    final sixes = _currentDiceValues.where((v) => v == 6).toList();
    if (sixes.length == 2) {
      int thirdDieIndex = _currentDiceValues.indexWhere((v) => v != 6);
      if (index == thirdDieIndex && _currentDiceValues[index] != 1) {
        _currentDiceValues[index] = 1;
        if (!_heldDiceIndices.contains(index)) {
          _heldDiceIndices.add(index); // Die 1 sofort halten
        }
        notifyListeners();
        return; // Aktion beendet
      }
    }

    // Normales Halten/Lösen (nur bei Einsern)
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
    // Ersten Wurf nicht "lassen"
    if (!isForced && _rollsLeft == 3) return;
    final usedRolls = 3 - _rollsLeft;

    // Setzt maxRolls nur, wenn der Startspieler den Wurf beendet
    if (_currentPlayerIndex == _loserIndexAtStartOfRound) {
      _maxRollsInRound = usedRolls == 0 ? 1 : usedRolls;
    }

    SchockenScore score = _evaluateDice(_currentDiceValues, usedRolls, List.from(_heldDiceIndices), _currentPlayerIndex);
    _playerScores[_currentPlayerIndex] = score;

    // Prüfen, ob alle AKTIVEN Spieler fertig sind
    bool allActivePlayersDone = true;
    for (int i = 0; i < playerNames.length; i++) {
      if (_activePlayers[i] && _playerScores[i] == null) {
        allActivePlayersDone = false;
        break;
      }
    }

    if (allActivePlayersDone) {
      _isRoundFinished = true;
    } else {
      // Finde den nächsten AKTIVEN Spieler
      _currentPlayerIndex = _findNextActivePlayer(_currentPlayerIndex);
      _prepareNextTurn(); // Bereitet Würfel etc. vor
    }
    notifyListeners();
  }

  // --- Runden-/Spiel-Management ---

  // NEU: Methode, um die aktiven Spieler basierend auf der Phase zu bestimmen
  void _updateActivePlayers() {

    if (_gamePhase == 3) {
      // Phase 3: Finale - Nur Spieler mit Halbzeitverlust (mind. 1) spielen
      _activePlayers = List.generate(playerNames.length, (i) => _playerHalfLosses[i] > 0);
    } else if ((_gamePhase == 1 || _gamePhase == 2) && _lidsInMiddle == 0) {
      // Phase 2: Halbzeit ausspielen - Nur Spieler mit Deckeln spielen
      _gamePhase = 2; // Setze/Bleibe in Phase 2
      _activePlayers = List.generate(playerNames.length, (i) => _playerLids[i] > 0);
    } else {
      // Phase 1: Stock leeren - Alle spielen
      _gamePhase = 1;
      _activePlayers = List.generate(playerNames.length, (i) => true);
    }

    // NEU: Auto-Halbzeit-Verlust, wenn nur 1 Spieler in Phase 2 aktiv ist
    if (_gamePhase == 2) {
      int activeCount = _activePlayers.where((a) => a).length;
      if (activeCount == 1) {
        // Dieser einzelne aktive Spieler hat die Halbzeit verloren
        int loserIndex = _activePlayers.indexOf(true);
        // Manually trigger the half loss calculation
        _playerLids[loserIndex] = 13; // Force half loss

        // Runde sofort beenden und Ergebnisse berechnen
        _isRoundFinished = true; // Runde ist vorbei
        calculateAndSetResults(); // Dies wird die Logik für H1/H2/Finale auslösen
        return; // Stop further processing for this round
      }
    }

    // Sicherstellen, dass der Startspieler der Runde aktiv ist
    if (!_activePlayers[_loserIndexAtStartOfRound]) {
      // Wenn der eigentliche Startspieler (Verlierer) nicht mehr aktiv ist
      // (z.B. weil er in Phase 2 keine Deckel mehr hat), finde den nächsten aktiven Spieler.
      _loserIndexAtStartOfRound = _findNextActivePlayer(_loserIndexAtStartOfRound);
    }
    _currentPlayerIndex = _loserIndexAtStartOfRound;
  }

  // NEU: Hilfsmethode, um den nächsten aktiven Spieler zu finden
  int _findNextActivePlayer(int currentIndex) {
    int nextIndex = currentIndex;
    for (int i = 0; i < playerNames.length; i++) {
      nextIndex = (nextIndex + 1) % playerNames.length;
      if (_activePlayers[nextIndex]) {
        return nextIndex;
      }
    }

    // Fallback: Finde den ersten aktiven Spieler (sollte nur bei 1 Spieler passieren)
    int firstActive = _activePlayers.indexOf(true);
    return firstActive != -1 ? firstActive : 0; // Fallback auf 0, wenn niemand aktiv (Fehler)
  }

  void _startRound() {
    // VOR dem Zurücksetzen der Scores die aktiven Spieler bestimmen
    _updateActivePlayers(); // Setzt _gamePhase und _activePlayers

    // Wenn _updateActivePlayers das Spiel beendet hat (z.B. Auto-Verlust),
    // wurden die Flags (_isRoundFinished etc.) in calculateAndSetResults gesetzt.
    // Wir müssen den Start der Runde abbrechen, sonst überschreiben wir sie.
    // Prüfe _areResultsCalculated statt _isRoundFinished
    if (_areResultsCalculated) return;

    _rollsLeft = 3;
    _currentDiceValues = [1, 1, 1];
    _heldDiceIndices = [];
    // _isRoundFinished = false; // Bereits in startNextRoundOrHalf gesetzt
    // _areResultsCalculated = false; // Bereits in startNextRoundOrHalf gesetzt
    _roundWinnerName = null;
    _roundLoserName = null;
    // _wasHalfLost = false; // Bereits in startNextRoundOrHalf gesetzt

    // Setzt den Startspieler (wurde in _updateActivePlayers ggf. korrigiert)
    _currentPlayerIndex = _loserIndexAtStartOfRound;

    // Nur Scores von aktiven Spielern zurücksetzen
    _playerScores = List.generate(playerNames.length, (index) {
      return _activePlayers[index] ? null : _playerScores[index];
    });

    // Max Rolls für den Startspieler setzen
    if (_currentPlayerIndex == _loserIndexAtStartOfRound) {
      _maxRollsInRound = 3;
    }
    // notifyListeners() wird in startNextRoundOrHalf aufgerufen
  }


  void _prepareNextTurn() {
    _rollsLeft = 3;
    _currentDiceValues = [1, 1, 1];
    _heldDiceIndices = [];
  }


  void startNextRoundOrHalf() {
    // KORREKTUR: Flags HIER zurücksetzen, BEVOR _startRound gerufen wird
    _isRoundFinished = false;
    _areResultsCalculated = false;
    _wasHalfLost = false;

    _startRound(); // _startRound wird nun _updateActivePlayers korrekt ausführen
    notifyListeners();
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

    // Hole sortierte Liste, ABER nur von aktiven Spielern
    List<MapEntry<String, SchockenScore>> scoredPlayers = getSortedPlayerScores();

    // Wenn aus irgendeinem Grund keine Scores vorhanden sind (z.B. Auto-Verlust in H2)
    // müssen wir den Verlierer anders bestimmen.
    String finalLoserName;
    int loserIndex;
    int lidsToTake;

    if (scoredPlayers.isEmpty) {
      // Dies passiert beim Auto-Verlust in Phase 2
      // Der Verlierer-Index wurde bereits in _updateActivePlayers bestimmt
      loserIndex = _activePlayers.indexOf(true); // Finde den einzig verbliebenen
      if (loserIndex == -1) loserIndex = 0; // Fallback
      finalLoserName = playerNames[loserIndex];
      _roundWinnerName = finalLoserName; // Es gibt keinen "Gewinner"
      _roundLidsTransferred = 0; // Es werden keine Deckel verschoben
      lidsToTake = 0;
    } else {
      // --- KORRIGIERTE Tie-Breaking Logik ---
      finalLoserName = scoredPlayers.last.key; // Annahme: Letzter ist Verlierer
      SchockenScore loserScore = scoredPlayers.last.value;

      // Finde alle Spieler mit dem gleichen schlechtesten Score (aus der Liste der aktiven Spieler)
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
      loserIndex = playerNames.indexOf(_roundLoserName!);
      SchockenScore bestScoreOfRound = scoredPlayers.first.value; // Bester Score bestimmt Deckel

      // ANPASSUNG WUNSCH 1: _roundLidsTransferred darf nicht größer sein als _lidsInMiddle, WENN _lidsInMiddle > 0 (Phase 1)
      if (_gamePhase == 1) { // Phase 1 (Stock leeren)
        _roundLidsTransferred = math.min(bestScoreOfRound.lidValue, _lidsInMiddle);
      } else { // Phase 2 oder 3
        _roundLidsTransferred = bestScoreOfRound.lidValue;
      }
      lidsToTake = _roundLidsTransferred; // Dieser Wert ist in Phase 1 bereits limitiert
    }


    _wasHalfLost = false;
    _wasGameLost = false;

    // --- Deckel-Logik (ANGEPASST für Wunsch 1) ---

    // In Phase 1 (Stock leeren): Nimm *nur* aus der Mitte
    if (_gamePhase == 1) {
      // lidsToTake ist bereits math.min(bestScore.lidValue, _lidsInMiddle)
      _playerLids[loserIndex] += lidsToTake;
      _lidsInMiddle -= lidsToTake;
    }
    // In Phase 2 oder 3 (Stock ist leer): Nimm vom Gewinner
    else if (_gamePhase == 2 || _gamePhase == 3) {
      // Stock ist leer (_lidsInMiddle == 0)
      // lidsToTake ist der volle Wert des Wurfs (z.B. 6 für Schock 6).

      if (lidsToTake > 0 && playerNames.length > 1 && _roundWinnerName != null) {
        int winnerIndex = playerNames.indexOf(_roundWinnerName!);
        if (winnerIndex != loserIndex) {
          // In Phase 2/3 kann der Gewinner auch Deckel verlieren.
          int actualLidsFromWinner = math.min(_playerLids[winnerIndex], lidsToTake);
          _playerLids[winnerIndex] -= actualLidsFromWinner;
          _playerLids[loserIndex] += actualLidsFromWinner;
        }
      }
    }
    // --- Ende Deckel-Logik ---

    // --- NEUE HALBZEIT/FINALE LOGIK ---
    if (_playerLids[loserIndex] >= 13) {
      _wasHalfLost = true; // Diese Runde resultierte in einem Halbzeit- oder Finalverlust
      _playerHalfLosses[loserIndex]++; // Zähle den Verlust
      _roundLidsTransferred = 0; // Zeige keine Deckel-Anzahl an

      if ((_gamePhase == 1 || _gamePhase == 2) && _firstHalfLoserIndex == null) {
        // --- ENDE VON HALBZEIT 1 ---
        _firstHalfLoserIndex = loserIndex;
        _gamePhase = 1; // Setze zurück auf Phase 1 (für H2)
        // Deckel zurücksetzen für H2
        _playerLids = List.generate(playerNames.length, (index) => 0);
        _lidsInMiddle = 13;

      } else if ((_gamePhase == 1 || _gamePhase == 2) && _firstHalfLoserIndex != null) {
        // --- ENDE VON HALBZEIT 2 ---
        if (_firstHalfLoserIndex == loserIndex) {
          // ** SZENARIO A: Gleicher Spieler hat H1 und H2 verloren **
          _wasGameLost = true;
          _gamePhase = 4; // Spiel vorbei
        } else {
          // ** SZENARIO B: Verschiedene Spieler haben H1 und H2 verloren **
          _gamePhase = 3; // Setze auf Finale
          // Deckel zurücksetzen für Finale
          _playerLids = List.generate(playerNames.length, (index) => 0);
          _lidsInMiddle = 13;
        }
      } else if (_gamePhase == 3) {
        // --- ENDE VOM FINALE ---
        _wasGameLost = true;
        _gamePhase = 4; // Spiel vorbei
      }
    }
    // --- ENDE NEUE HALBZEIT/FINALE LOGIK ---


    _loserIndexAtStartOfRound = loserIndex; // Verlierer beginnt nächste Runde
    _currentPlayerIndex = loserIndex;      // Setzt den Index für _startRound()

    _areResultsCalculated = true; // Markiert, dass Ergebnisse berechnet wurden
    notifyListeners(); // UI über Ergebnisse informieren
  }

  /// Gibt eine sortierte Liste der Spieler und ihrer Scores zurück (Bester zuerst).
  /// Berücksichtigt NUR Spieler, die in dieser Runde aktiv waren (_activePlayers).
  List<MapEntry<String, SchockenScore>> getSortedPlayerScores() {
    List<MapEntry<String, SchockenScore>> scoredPlayers = [];
    for (int i = 0; i < playerNames.length; i++) {
      // NEU: Prüfe, ob Spieler aktiv war UND einen Score hat
      if (_activePlayers[i] && _playerScores[i] != null) {
        scoredPlayers.add(MapEntry(playerNames[i], _playerScores[i]!));
      }
    }
    // Sortiert von Bester (links/Index 0) zu Schlechtester (rechts/letzter Index)
    scoredPlayers.sort((a, b) => a.value.isBetterThan(b.value) ? -1 : 1);
    return scoredPlayers;
  }

}

