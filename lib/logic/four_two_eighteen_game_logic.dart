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
  final int usedRolls; // KORREKTUR: Zählt jetzt die "NOCHMAL"-Klicks
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

    // 3. Wurf-Anzahl (Tie-Breaker): MEHR Würfe (NOCHMAL-Klicks) sind BESSER
    // (Regel-Präzisierung: Wer öfter gewürfelt hat, hatte mehr Risiko/Mut)
    if (usedRolls != other.usedRolls) {
      return usedRolls > other.usedRolls;
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
  late Map<String, int> _playerLives;
  int _currentPlayerIndex = 0;
  List<int> _currentDiceValues = [1, 1, 1, 1, 1];
  List<bool> _diceHeld = [false, false, false, false, false];
  List<int?> _basisDice = [null, null]; // [0] = 4er-Index, [1] = 2er-Index
  List<int?> _scoreDice = [null, null, null]; // Die drei Indexe der Würfel für die 18

  int _rollCount = 0; // Zählt die "NOCHMAL"-Klicks
  int _diceHeldBeforeRoll = 0; // Wie viele Würfel waren vor dem Wurf gesperrt?

  String _gameStatusMessage = '';
  bool _isRoundOver = false;
  bool _isGameOver = false;

  Map<String, FourTwoEighteenScore> _roundResults = {};
  Map<String, List<int>> _allPlayerFinalDice = {};

  // --- Getters für die UI ---
  Map<String, int> get playerLives => _playerLives;
  int get currentPlayerIndex => _currentPlayerIndex;
  List<int> get currentDiceValues => _currentDiceValues;
  List<bool> get diceHeld => _diceHeld;
  List<int?> get basisDice => _basisDice;
  List<int?> get scoreDice => _scoreDice;

  int get rollCount => _rollCount; // Zählt Klicks auf "NOCHMAL"
  int get diceHeldBeforeRoll => _diceHeldBeforeRoll;
  int get heldDiceCount => _diceHeld.where((h) => h).length;
  int get unheldDiceCount => _diceHeld.where((h) => !h).length;

  String get gameStatusMessage => _gameStatusMessage;
  bool get isRoundOver => _isRoundOver;
  bool get isGameOver => _isGameOver;
  Map<String, FourTwoEighteenScore> get roundResults => _roundResults;
  Map<String, List<int>> get allPlayerFinalDice => _allPlayerFinalDice;

  String get currentPlayerName => playerNames[_currentPlayerIndex];
  bool get hasHeldFour => _basisDice[0] != null;
  bool get hasHeldTwo => _basisDice[1] != null;
  // KORREKTUR: basisFound prüft jetzt die *Werte*
  bool get basisFound {
    bool fourFound = hasHeldFour && _currentDiceValues[_basisDice[0]!] == 4;
    bool twoFound = hasHeldTwo && _currentDiceValues[_basisDice[1]!] == 2;
    return fourFound && twoFound;
  }
  bool get allScoreDiceHeld => _scoreDice.every((element) => element != null);

  /// NEU: Getter, der prüft, ob die Basis (4 & 2) überhaupt noch erreicht werden kann.
  bool canStillGetBasis() {
    if (basisFound) return true; // Basis ist schon da

    // Prüfe, ob 4 oder 2 noch unter den *nicht gehaltenen* Würfeln sind
    bool canGetFour = !hasHeldFour; // Brauchen wir die 4?
    bool canGetTwo = !hasHeldTwo; // Brauchen wir die 2?

    // Wenn wir beide nicht mehr brauchen (weil sie schon gehalten werden,
    // aber vielleicht am falschen Platz?), ist die Basis (logisch) noch erreichbar.
    // Der wichtige Check ist: Sind die Würfel, die wir brauchen, noch im Spiel?

    List<int> unheldValues = [];
    for(int i=0; i < _totalDice; i++) {
      if (!_diceHeld[i]) {
        unheldValues.add(_currentDiceValues[i]);
      }
    }

    // Wenn wir eine 4 brauchen, muss sie unter den freien Würfeln sein
    if (canGetFour && !unheldValues.contains(4)) {
      // Wir brauchen eine 4, aber keine 4 ist mehr frei -> Basis nicht erreichbar
      return false;
    }
    // Wenn wir eine 2 brauchen, muss sie unter den freien Würfeln sein
    if (canGetTwo && !unheldValues.contains(2)) {
      // Wir brauchen eine 2, aber keine 2 ist mehr frei -> Basis nicht erreichbar
      return false;
    }

    // Wenn wir 4 und 2 brauchen, aber nur noch 1 Würfel frei ist
    if (canGetFour && canGetTwo && unheldDiceCount < 2) {
      return false;
    }

    return true; // Basis ist noch erreichbar
  }


  // --- Konstruktor ---
  FourTwoEighteenGame(this.playerNames) {
    _playerLives = Map.fromIterable(playerNames, key: (player) => player, value: (_) => initialLives);
    _startPlayerTurn();
  }

  // --- Private Methoden (Logik) ---

  void _startPlayerTurn() {
    if (_isGameOver) return;
    _currentDiceValues = List.generate(_totalDice, (_) => 1);
    _diceHeld = List.generate(_totalDice, (_) => false);
    _rollCount = 0;
    _diceHeldBeforeRoll = 0;
    _basisDice = [null, null];
    _scoreDice = [null, null, null];
    _gameStatusMessage = '${playerNames[_currentPlayerIndex]} ist dran.';
    notifyListeners();
  }

  FourTwoEighteenScore _evaluateScore() {
    final finalDiceValues = List<int>.from(_currentDiceValues);

    // KORREKTUR: Prüft die *Werte* in den Basis-Slots
    bool finalBasisFound = (hasHeldFour && _currentDiceValues[_basisDice[0]!] == 4) &&
        (hasHeldTwo && _currentDiceValues[_basisDice[1]!] == 2);

    if (!finalBasisFound || !allScoreDiceHeld) {
      return FourTwoEighteenScore(score: 0, usedRolls: _rollCount, hasBasis: false, diceValues: finalDiceValues);
    }

    int score = 0;
    for (int? index in _scoreDice) {
      if (index != null) {
        score += _currentDiceValues[index];
      }
    }

    return FourTwoEighteenScore(score: score, usedRolls: _rollCount, hasBasis: true, diceValues: finalDiceValues);
  }

  // --- Öffentliche Aktionen (von der UI aufgerufen) ---

  void roll() {
    if (_isGameOver || heldDiceCount == 5) return;

    // Prüfen, ob der Spieler seit dem letzten Wurf min. 1 Würfel abgelegt hat
    if (_rollCount > 0 && heldDiceCount <= _diceHeldBeforeRoll) {
      _gameStatusMessage = 'Du musst erst 1 Würfel ablegen!';
      notifyListeners();
      return;
    }

    _rollCount++;
    _diceHeldBeforeRoll = heldDiceCount; // Speichern, wie viele *vor* dem Wurf gehalten wurden

    for (int i = 0; i < _totalDice; i++) {
      if (!_diceHeld[i]) {
        _currentDiceValues[i] = _random.nextInt(6) + 1;
      }
    }

    _gameStatusMessage = '$currentPlayerName hat gewürfelt (Wurf $_rollCount)';
    notifyListeners();
  }

  void endTurn() { // KORREKTUR: Gibt jetzt void zurück
    if (_isRoundOver || _isGameOver) return;

    final currentPlayer = playerNames[_currentPlayerIndex];

    // Erzwinge das Halten aller Würfel, falls der Spieler "Beenden (Ungültig)" drückt
    if (heldDiceCount < 5) {
      _diceHeld = List.generate(5, (index) => true);
      // Fülle die Slots automatisch auf (könnte zu ungültigem Ergebnis führen)
      _autoFillSlots();
    }

    final score = _evaluateScore();
    _roundResults[currentPlayer] = score;
    _allPlayerFinalDice[currentPlayer] = List<int>.from(_currentDiceValues);

    final nextPlayerIndex = (_currentPlayerIndex + 1) % playerNames.length;

    // Aktive Spieler finden (die noch Leben haben)
    final activePlayers = playerNames.where((name) => (_playerLives[name] ?? 0) > 0).toList();

    if (_roundResults.length == activePlayers.length) {
      // Alle aktiven Spieler haben gewürfelt -> Runde auflösen
      _isRoundOver = true;
      _resolveRound(); // Benachrichtigt UI
    } else {
      // Nächster Spieler ist dran (überspringe eliminierte)
      int nextIndex = _currentPlayerIndex;
      do {
        nextIndex = (nextIndex + 1) % playerNames.length;
      } while ((_playerLives[playerNames[nextIndex]] ?? 0) <= 0);

      _currentPlayerIndex = nextIndex;
      _startPlayerTurn();
    }
  }

  // NEU: Hilfsmethode, um Slots automatisch zu füllen, wenn der Zug beendet wird
  void _autoFillSlots() {
    List<int> unheldIndices = [];
    for(int i=0; i < _totalDice; i++) {
      if (!_diceHeld[i]) {
        unheldIndices.add(i);
      }
    }

    for (int diceIndex in unheldIndices) {
      int value = _currentDiceValues[diceIndex];
      bool placed = false;

      // 1. Versuche Basis-Slots zu füllen
      if (value == 4 && _basisDice[0] == null) {
        _basisDice[0] = diceIndex;
        placed = true;
      } else if (value == 2 && _basisDice[1] == null) {
        _basisDice[1] = diceIndex;
        placed = true;
      }

      // 2. Wenn nicht in Basis platziert, versuche Score-Slots
      if (!placed) {
        final emptyScoreIndex = _scoreDice.indexOf(null);
        if (emptyScoreIndex != -1) {
          _scoreDice[emptyScoreIndex] = diceIndex;
          placed = true;
        }
      }
      // (Wenn alle Slots voll sind, wird der Würfel ignoriert)
    }
    _diceHeld = List.generate(5, (index) => true);
  }


  void setHeldDice(int diceIndex, HoldPosition target) {
    if (_isGameOver || _diceHeld[diceIndex]) return; // Verhindert das Verschieben bereits gehaltener

    // 1. Würfel aus altem Platz entfernen (falls er schon woanders lag - sollte nicht passieren, aber sicher ist sicher)
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
      // KORREKTUR: Speichere den *Würfel-Index* (diceIndex), nicht den Slot-Index (indexInArray)
      final emptyIndex = _scoreDice.indexOf(null);
      if (emptyIndex != -1) {
        _scoreDice[emptyIndex] = diceIndex;
      }
    }

    // Fülle leere Plätze mit null (sollte nicht nötig sein, aber schadet nicht)
    while (_basisDice.length < 2) _basisDice.add(null);
    while (_scoreDice.length < 3) _scoreDice.add(null);

    // Wenn alle 5 Würfel gehalten wurden, Zug automatisch beenden
    if (heldDiceCount == 5) {
      endTurn();
    } else {
      // Status aktualisieren, dass abgelegt wurde
      _gameStatusMessage = 'Abgelegt. Du kannst nochmal würfeln.';
      notifyListeners();
    }
  }

  void releaseHeldDice(int diceIndex) {
    if (_isGameOver) return;
    // Verhindere das Freigeben, wenn der Spieler ablegen MUSS
    if (_rollCount > 0 && heldDiceCount <= _diceHeldBeforeRoll) {
      _gameStatusMessage = 'Du musst erst einen neuen Würfel ablegen!';
      notifyListeners();
      return;
    }

    _diceHeld[diceIndex] = false;
    _basisDice = _basisDice.map((index) => index == diceIndex ? null : index).toList();
    _scoreDice = _scoreDice.map((index) => index == diceIndex ? null : index).toList();

    // Aktualisiere _diceHeldBeforeRoll, wenn wir einen Würfel freigeben
    // (damit wir nicht würfeln können, ohne einen NEUEN abzulegen)
    _diceHeldBeforeRoll = heldDiceCount;

    _gameStatusMessage = 'Freigegeben. Wähle neu oder würfle.';
    notifyListeners();
  }

  // Rundenauflösung und Lebensabzug
  void _resolveRound() {
    // Nur Spieler werten, die noch Leben haben
    final activePlayers = playerNames.where((name) => (_playerLives[name] ?? 0) > 0).toList();
    List<MapEntry<String, FourTwoEighteenScore>> sortedResults = _roundResults.entries
        .where((entry) => activePlayers.contains(entry.key))
        .toList()
      ..sort((a, b) => a.value.isBetterThan(b.value) ? -1 : 1); // Bester zuerst

    String loserName = "Niemand";

    if (sortedResults.isNotEmpty) {
      final worstScore = sortedResults.last.value;
      final losers = sortedResults
          .where((entry) =>
      entry.value.hasBasis == worstScore.hasBasis &&
          entry.value.score == worstScore.score &&
          entry.value.usedRolls == worstScore.usedRolls
      )
          .toList();


      if (losers.length > 1) {
        // Bei Gleichstand verliert der Spieler, der zuerst gewürfelt hat (niedrigster Index im Original-Array)
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
        _handlePlayerElimination(loserName); // Prüft auch auf Spielende
      } else {
        _currentPlayerIndex = playerNames.indexOf(loserName); // Verlierer beginnt nächste Runde
      }
    } else {
      // Sollte nicht passieren, wenn activePlayers > 0
      _gameStatusMessage = "Fehler bei der Auswertung.";
    }


    notifyListeners(); // UI über Ergebnis informieren
  }

  // Handles player elimination and checks for game over
  void _handlePlayerElimination(String eliminatedPlayer) {
    _gameStatusMessage = '$eliminatedPlayer hat alle Leben verloren!';

    // Check if only one player remains
    final remainingPlayers = _playerLives.entries.where((entry) => entry.value > 0).toList();
    if (remainingPlayers.length == 1) {
      _isGameOver = true;
      _gameStatusMessage = '${remainingPlayers.first.key} hat gewonnen!';
      _currentPlayerIndex = playerNames.indexOf(remainingPlayers.first.key);
    } else if (remainingPlayers.isEmpty) {
      _isGameOver = true;
      _gameStatusMessage = 'Unentschieden! Alle Spieler haben verloren.';
      _currentPlayerIndex = 0; // Zurück zum ersten Spieler
    }
    else {
      // Es sind noch mehrere Spieler übrig.
      // Der Verlierer (eliminiert) beginnt *technisch* gesehen,
      // aber wir müssen den nächsten *aktiven* Spieler finden.
      _currentPlayerIndex = playerNames.indexOf(eliminatedPlayer);
      int nextStarterIndex = _currentPlayerIndex;
      do {
        nextStarterIndex = (nextStarterIndex + 1) % playerNames.length;
      } while ((_playerLives[playerNames[nextStarterIndex]] ?? 0) <= 0);
      _currentPlayerIndex = nextStarterIndex; // Dieser Spieler startet tatsächlich
    }
  }


  void startNextRound() {
    if (_isGameOver) return; // Don't start a new round if game is over
    _isRoundOver = false;
    _roundResults = {}; // Ergebnisse der aktiven Runde löschen
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
    // _lastRoundResults = {}; // Cache auch leeren // <--- DIESE ZEILE WURDE ENTFERNT
    _allPlayerFinalDice = {};
    _startPlayerTurn(); // Start the first turn of the new game
    notifyListeners();
  }
}

