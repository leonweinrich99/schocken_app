import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoSplashScreen extends StatefulWidget {
  final VoidCallback onVideoFinished;

  const VideoSplashScreen({
    super.key,
    required this.onVideoFinished,
  });

  @override
  State<VideoSplashScreen> createState() => _VideoSplashScreenState();
}

class _VideoSplashScreenState extends State<VideoSplashScreen> {
  late VideoPlayerController _controller;
  bool _isVideoFinished = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/videos/dice_in_cup.mp4')
      ..initialize().then((_) {
        // Stellt sicher, dass der erste Frame angezeigt wird
        setState(() {});
        // Spielt das Video ab
        _controller.play();
        // Fügt einen Listener hinzu, um das Ende zu erkennen
        _controller.addListener(_videoListener);
        // Video in Schleife abspielen, falls gewünscht (auskommentieren, wenn nicht)
        // _controller.setLooping(true);
      });
  }

  void _videoListener() {
    // Prüft, ob das Video initialisiert ist, nicht mehr spielt,
    // die Position am Ende (oder darüber) ist UND der Callback noch nicht ausgelöst wurde.
    // Bei Looping wird diese Bedingung ggf. nicht erreicht, anpassen falls Looping aktiv ist.
    if (_controller.value.isInitialized &&
        !_controller.value.isPlaying &&
        !_controller.value.isLooping && // Nur prüfen, wenn nicht geloopt wird
        _controller.value.position >= _controller.value.duration &&
        !_isVideoFinished) {

      setState(() {
        _isVideoFinished = true;
      });

      // Entfernt den Listener, um mehrfache Aufrufe zu verhindern
      _controller.removeListener(_videoListener);

      // Benachrichtigt das Haupt-Widget, dass das Video fertig ist
      widget.onVideoFinished();
    }
  }

  @override
  void dispose() {
    // Stellt sicher, dass der Listener entfernt wird, wenn das Widget zerstört wird
    _controller.removeListener(_videoListener);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Hintergrundfarbe Rot, wie im Rest der App
      backgroundColor: const Color(0xFFE53935),
      body: Center(
        child: _controller.value.isInitialized
            ?
        // NEU: SizedBox.expand zwingt das Kind, den gesamten Platz einzunehmen
        SizedBox.expand(
          child: FittedBox(
            // NEU: BoxFit.cover skaliert das Video, um den Bereich zu füllen (kann croppen)
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller.value.size.width,
              height: _controller.value.size.height,
              child: VideoPlayer(_controller),
            ),
          ),
        )
        // Zeigt nur den roten Hintergrund, während das Video lädt
            : Container(
          color: const Color(0xFFE53935),
          child: const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              )), // Optional: Ladeindikator
        ),
      ),
    );
  }
}

