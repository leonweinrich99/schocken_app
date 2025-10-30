import 'package:flutter/material.dart';

class PlayerEntryScreen extends StatefulWidget {
  final Function(List<String>) onStartGame;
  final VoidCallback onBack;

  const PlayerEntryScreen({
    super.key,
    required this.onStartGame,
    required this.onBack,
  });

  @override
  State<PlayerEntryScreen> createState() => _PlayerEntryScreenState();
}

class _PlayerEntryScreenState extends State<PlayerEntryScreen> {
  final List<TextEditingController> _controllers = [];
  final List<FocusNode> _focusNodes = []; // Für Fokus-Management

  @override
  void initState() {
    super.initState();
    // Start mit einem Spieler
    _addPlayerField();
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _addPlayerField() {
    setState(() {
      // ÄNDERUNG: Controller startet jetzt leer
      final controller = TextEditingController();
      final focusNode = FocusNode();
      _controllers.add(controller);
      _focusNodes.add(focusNode);

      // Setzt den Fokus auf das neu hinzugefügte Feld
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FocusScope.of(context).requestFocus(focusNode);
      });
    });
  }

  void _removePlayerField(int index) {
    // Verhindert das Entfernen des letzten Spielers
    if (_controllers.length <= 1) return;
    setState(() {
      _controllers[index].dispose();
      _focusNodes[index].dispose();
      _controllers.removeAt(index);
      _focusNodes.removeAt(index);
    });
  }


  void _startGame() {
    // Sammelt die Namen (ignoriert leere Felder)
    final playerNames = _controllers
        .map((controller) => controller.text.trim())
        .where((name) => name.isNotEmpty)
    // Stellt sicher, dass Standard-Platzhalter nicht als Namen verwendet werden
        .where((name) => !RegExp(r'^Spieler \d+$').hasMatch(name))
        .toList();

    // Fügt Standardnamen hinzu, WENN das Feld leer gelassen wurde
    for (int i = 0; i < _controllers.length; i++) {
      String name = _controllers[i].text.trim();
      if (name.isEmpty) {
        playerNames.add('Spieler ${i + 1}');
      }
    }

    // Startet das Spiel nur, wenn mindestens ein Name vorhanden ist
    if (playerNames.isNotEmpty) {
      widget.onStartGame(playerNames);
    } else {
      // Fallback, falls alle Felder leer gelassen wurden (sollte durch obige Logik abgedeckt sein)
      widget.onStartGame(['Spieler 1']);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Stil für Textfelder
    final inputDecoration = InputDecoration(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: const BorderSide(color: Colors.black, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: const BorderSide(color: Colors.black, width: 3), // Dickerer Rand bei Fokus
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.normal), // Hint-Stil angepasst
      counterText: '', // Versteckt den Zeichenzähler
    );

    const titleStyle = TextStyle(
      color: Colors.white,
      fontSize: 48,
      fontWeight: FontWeight.w900,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFFA4848),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // Header mit Zurück-Button und Titel
              Stack(
                alignment: Alignment.center,
                children: [
                  const Center(
                    child: Text('SPIELER', style: titleStyle),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
                      onPressed: widget.onBack,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // Liste der Eingabefelder
              Expanded(
                child: ListView.builder(
                  itemCount: _controllers.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 15.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controllers[index],
                              focusNode: _focusNodes[index], // Fokus-Node zuweisen
                              decoration: inputDecoration.copyWith(
                                // ÄNDERUNG: hintText wird jetzt hier gesetzt
                                hintText: 'Spieler ${index + 1}',
                              ),
                              style: const TextStyle(
                                  color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
                              cursorColor: Colors.black, // Sorgt für einen sichtbaren Cursor
                              textCapitalization: TextCapitalization.words,
                              maxLength: 20, // Maximale Namenslänge
                              onSubmitted: (_) { // Bei Enter zum nächsten Feld springen
                                if (index < _controllers.length - 1) {
                                  FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
                                } else {
                                  // Optional: Beim letzten Feld Enter -> Spiel starten?
                                  // _startGame();
                                }
                              },
                            ),
                          ),
                          // Nur "Entfernen"-Button anzeigen, wenn mehr als 1 Spieler
                          if (_controllers.length > 1)
                            IconButton(
                              icon: const Icon(Icons.remove_circle, color: Colors.black, size: 30),
                              onPressed: () => _removePlayerField(index),
                            ),
                          // Platzhalter, wenn nur 1 Spieler, um Layout konsistent zu halten
                          if (_controllers.length <= 1) const SizedBox(width: 48), // Breite des IconButtons
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Buttons am unteren Rand
              const SizedBox(height: 20),
              _buildActionButton('SPIELER HINZUFÜGEN', _addPlayerField),
              const SizedBox(height: 15),
              _buildActionButton('SPIEL STARTEN', _startGame, isPrimary: true),
            ],
          ),
        ),
      ),
    );
  }

  /// Baut einen Button (kopiert aus schocken_game.dart, ggf. auslagern)
  Widget _buildActionButton(String text, VoidCallback? onPressed, {bool isPrimary = false}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black,
            spreadRadius: 0,
            blurRadius: 0,
            offset: const Offset(4, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.black,
          backgroundColor: const Color(0xFFD9D9D9),
          disabledBackgroundColor: Colors.grey.shade400,
          minimumSize: Size(isPrimary ? double.infinity : 250, 60), // Primärbutton volle Breite
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          elevation: 0,
        ),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24)), // Schriftgröße angepasst
      ),
    );
  }
}

