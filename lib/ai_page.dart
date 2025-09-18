import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import 'main.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class AiPage extends StatefulWidget {
  const AiPage({super.key});

  @override
  State<AiPage> createState() => _AiPageState();
}

class _AiPageState extends State<AiPage> {
  bool showVideo = false;
  CameraController? _cameraController;

  // --- Speech to Text ---
  late stt.SpeechToText _speech;
  bool _isListening = false;
  final TextEditingController _controller = TextEditingController();

  final List<Map<String, String>> messages = [
    {"role": "bot", "text": "Hello 🌙, how are you feeling today?"},
    {"role": "user", "text": "A little tired, but better now."},
  ];

  @override
  void initState() {
    super.initState();
    initCamera();
    _speech = stt.SpeechToText();
  }

  Future<void> initCamera() async {
    try {
      final cameras = await availableCameras();
      _cameraController ??= CameraController(cameras.first, ResolutionPreset.medium);
      if (!_cameraController!.value.isInitialized) {
        await _cameraController!.initialize();
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Camera init error: $e");
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _speech.stop();
    super.dispose();
  }

  void toggleVideo() async {
    setState(() => showVideo = !showVideo);

    if (showVideo) {
      if (_cameraController == null || !_cameraController!.value.isInitialized) {
        await initCamera();
      }
    }
  }

  void _toggleListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(onResult: (val) {
          setState(() {
            _controller.text = val.recognizedWords;
            _controller.selection = TextSelection.fromPosition(
              TextPosition(offset: _controller.text.length),
            );
          });
        });
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("POLARIS AI",
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              letterSpacing: 1,
            )),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: toggleVideo,
            icon: Text(
              showVideo ? "💬" : "🪞", // 🪞 for video mode, 🏠 to go back
              style: const TextStyle(fontSize: 24),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background: stars or video
          Positioned.fill(
            child: (showVideo &&
                    _cameraController != null &&
                    _cameraController!.value.isInitialized)
                ? CameraPreview(_cameraController!)
                : const StarryBackground(),
          ),

          // Chat bubbles + input bar (hidden when video is on)
          if (!showVideo)
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final isUser = msg["role"] == "user";
                        return Align(
                          alignment: isUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.all(14),
                            constraints:
                                const BoxConstraints(maxWidth: 280),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isUser
                                    ? [
                                        const Color.fromARGB(255, 135, 187, 222),
                                        const Color.fromARGB(255, 164, 115, 201),
                                      ]
                                    : [
                                        const Color.fromARGB(255, 62, 34, 97),
                                        const Color.fromARGB(255, 97, 50, 150),
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: Text(
                              msg["text"]!,
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Input bar
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    margin: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: "Type your thoughts...",
                              hintStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.6)),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _isListening ? Icons.mic : Icons.mic_none,
                            color:
                                _isListening ? Colors.redAccent : Colors.pinkAccent,
                          ),
                          onPressed: _toggleListening,
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
        ],
      ),
    );
  }
}
