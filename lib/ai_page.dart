import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import 'ai_client.dart';
import 'main.dart'; // Assuming StarryBackground is in main.dart

class AiPage extends StatefulWidget {
  const AiPage({super.key});

  @override
  State<AiPage> createState() => _AiPageState();
}

class _AiPageState extends State<AiPage> {
  bool showVideo = false;
  CameraController? _cameraController;
  late AiClient _aiClient;
  String _inputHint = "Hold mic to speak...";
  bool _isListening = false;
  bool _isAiResponding = false;
  final TextEditingController _controller = TextEditingController();
  String _lastUserTranscript = "";
  final List<Map<String, String>> messages = [
    {"role": "bot", "text": "Hello 🌙, how are you feeling today?"},
  ];
  final ScrollController _scrollController = ScrollController();

  // Frame capture
  Timer? _frameCaptureTimer;
  int _videoFramesSent = 0;
  static const int MAX_FRAMES = 6;
  static const int FRAME_INTERVAL_MS = 500;

  // Keep reference to current playing audio for cleanup
  html.AudioElement? _currentAudio;

  @override
  void initState() {
    super.initState();
    initCamera();
    _initMicPermission();

    _aiClient = AiClient(
      userId: "demo_user",
      onStatusUpdate: _handleStatusUpdate,
      onFinalResponse: _handleFinalResponse,
      onError: _handleError,
      onInterimTranscript: (text) {
        if (!mounted || text.isEmpty) return;
        _lastUserTranscript = text;
        setState(() {
          messages.add({"role": "user", "text": text});
          _scrollToBottom();
        });
      },
    );
  }

  Future<void> _initMicPermission() async {
    try {
      final stream = await html.window.navigator.getUserMedia(audio: true);
      stream.getTracks().forEach((track) => track.stop());
      print("Microphone permission granted");
    } catch (e) {
      debugPrint("Microphone permission denied by user: $e");
      setState(() {
        _inputHint = "Microphone access is needed to speak.";
      });
    }
  }

  Future<void> initCamera() async {
    try {
      print("Initializing camera...");
      final cameras = await availableCameras();
      print("Found ${cameras.length} cameras");

      if (cameras.isEmpty) {
        print("No cameras available on this device");
        return;
      }

      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      print("Camera initialized successfully!");

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print("Camera init error: $e");

      if (e.toString().contains('cameraNotReadable')) {
        print("Camera hardware error - continuing without video");
        setState(() {
          _inputHint = "Audio-only mode (camera unavailable)";
        });
      } else if (e.toString().contains('NotAllowedError')) {
        print("Camera permission denied");
        setState(() {
          _inputHint = "Camera permission denied - audio only";
        });
      }

      _cameraController?.dispose();
      _cameraController = null;
    }
  }

  // Clean up all resources when leaving the page
  Future<void> _cleanupResources() async {
    print("Cleaning up resources...");

    // Stop any ongoing recording
    if (_isListening) {
      await _onMicRelease();
    }

    // Stop frame capture
    _frameCaptureTimer?.cancel();
    _frameCaptureTimer = null;

    // Stop any playing audio
    if (_currentAudio != null) {
      _currentAudio!.pause();
      _currentAudio!.currentTime = 0;
      _currentAudio = null;
      print("Stopped playing audio");
    }

    // Dispose camera
    _cameraController?.dispose();
    _cameraController = null;

    // Dispose AI client (this should close WebSocket)
    _aiClient.dispose();

    // Reset states
    setState(() {
      _isListening = false;
      _isAiResponding = false;
      _inputHint = "Hold mic to speak...";
    });

    print("Resource cleanup complete");
  }

  @override
  void dispose() {
    _frameCaptureTimer?.cancel();
    _cameraController?.dispose();
    _aiClient.dispose();
    _scrollController.dispose();
    _controller.dispose();

    // Stop any playing audio
    if (_currentAudio != null) {
      _currentAudio!.pause();
      _currentAudio = null;
    }

    super.dispose();
  }

  void toggleVideo() async {
    setState(() => showVideo = !showVideo);
    print("Video display toggled to: $showVideo");
    if (showVideo &&
        (_cameraController == null ||
            !_cameraController!.value.isInitialized)) {
      await initCamera();
    }
  }

  void _handleStatusUpdate(String status) {
    if (!mounted) return;
    print("Status update: $status");
    setState(() {
      if (status == "transcribing") {
        _inputHint = "Transcribing...";
        _isAiResponding = true;
      } else if (status == "thinking") {
        _inputHint = "Polaris is thinking...";
        _isAiResponding = true;
      } else if (status == "listening") {
        _inputHint = "Listening...";
        _isAiResponding = false;
      } else if (status == "responding") {
        _inputHint = "Responding...";
        _isAiResponding = true;
      } else if (status == "disconnected") {
        _inputHint = "Hold mic to speak...";
        _isAiResponding = false;
      }
    });
  }

  void _handleFinalResponse(String text, Uint8List audioData) {
    if (!mounted) return;
    print("Final response received");

    // Stop any currently playing audio
    if (_currentAudio != null) {
      _currentAudio!.pause();
      _currentAudio = null;
    }

    setState(() {
      _inputHint = "Responding...";
      _isAiResponding = true;
      messages.add({"role": "bot", "text": text});
      _lastUserTranscript = "";
      _scrollToBottom();
    });

    final blob = html.Blob([audioData]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    _currentAudio = html.AudioElement(url)
      ..autoplay = true
      ..onEnded.listen((_) {
        html.Url.revokeObjectUrl(url);
        _currentAudio = null;
        if (mounted) {
          setState(() {
            _inputHint = "Hold mic to speak...";
            _isAiResponding = false;
          });
        }
        print("Audio finished, ready for next input");
      });
  }

  void _handleError(String error) {
    if (!mounted) return;
    print("AI error: $error");
    setState(() {
      _inputHint = "Error: Please try again";
      _isListening = false;
      _isAiResponding = false;
      _controller.clear();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _onMicPress() async {
    if (_isAiResponding) {
      print("Mic press blocked - AI is responding");
      return;
    }

    print("Mic pressed - starting new turn");

    await _aiClient.startNewTurn();

    setState(() {
      _isListening = true;
      _inputHint = "Listening...";
      _lastUserTranscript = "";
      _videoFramesSent = 0;
    });

    await _aiClient.startRecording();

    if (_cameraController != null && _cameraController!.value.isInitialized) {
      _startOptimizedFrameCapture();
    } else {
      print("Camera not available, audio-only mode");
    }
  }

  void _startOptimizedFrameCapture() {
    print(
      "Starting optimized frame capture (max $MAX_FRAMES frames, ${FRAME_INTERVAL_MS}ms interval)",
    );

    _frameCaptureTimer = Timer.periodic(Duration(milliseconds: FRAME_INTERVAL_MS), (
      timer,
    ) async {
      if (!_isListening || _videoFramesSent >= MAX_FRAMES) {
        print(
          "Stopping frame capture - listening: $_isListening, frames sent: $_videoFramesSent",
        );
        timer.cancel();
        return;
      }

      try {
        final XFile imageFile = await _cameraController!.takePicture();
        final Uint8List imageBytes = await imageFile.readAsBytes();

        _aiClient.sendVideoFrame(imageBytes);
        _videoFramesSent++;

        print(
          "Sent frame #$_videoFramesSent/$MAX_FRAMES (${imageBytes.length} bytes)",
        );
      } catch (e) {
        print("Error capturing frame: $e");
      }
    });
  }

  Future<void> _onMicRelease() async {
    if (!_isListening || _isAiResponding) return;

    print("Mic released - stopping recording");
    print("Total video frames sent: $_videoFramesSent");

    _frameCaptureTimer?.cancel();
    _frameCaptureTimer = null;

    final audioData = await _aiClient.stopRecording();
    print(
      "Audio recording stopped, data size: ${audioData?.length ?? 0} bytes",
    );

    if (audioData != null) {
      await _aiClient.sendAudio(audioData);
    }

    setState(() {
      _isListening = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) async {
        if (didPop) {
          await _cleanupResources();
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(
            "POLARIS AI",
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () async {
              await _cleanupResources();
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
          actions: [
            IconButton(
              onPressed: toggleVideo,
              icon: Text(
                showVideo ? "💬" : "🪞",
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            Positioned.fill(child: const StarryBackground()),
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  Expanded(
                    child: showVideo ? _buildVideoView() : _buildChatView(),
                  ),
                  _buildInputBar(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatView() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        final isUser = msg["role"] == "user";
        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.all(14),
            constraints: const BoxConstraints(maxWidth: 280),
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
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              msg["text"]!,
              style: GoogleFonts.poppins(fontSize: 15, color: Colors.white),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideoView() {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      return Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 15,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: CameraPreview(_cameraController!),
        ),
      );
    } else {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            "Camera not available",
            style: GoogleFonts.poppins(fontSize: 16, color: Colors.white70),
          ),
        ),
      );
    }
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                hintText: _inputHint,
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                border: InputBorder.none,
              ),
              readOnly: _isListening || _isAiResponding,
            ),
          ),
          GestureDetector(
            onTapDown: _isAiResponding ? null : (_) => _onMicPress(),
            onTapUp: _isAiResponding ? null : (_) => _onMicRelease(),
            onTapCancel: _isAiResponding ? null : () => _onMicRelease(),
            child: Icon(
              _isListening ? Icons.mic : Icons.mic_none,
              color: _isAiResponding
                  ? Colors.grey
                  : (_isListening ? Colors.redAccent : Colors.pinkAccent),
            ),
          ),
        ],
      ),
    );
  }
}
