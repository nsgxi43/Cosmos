// ai_client.dart

import 'dart:async';
import 'dart:convert';
import 'dart:html';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

const SERVER_URL = "wss://cosmos-wellness.duckdns.org/process";

class AiClient {
  final String userId;
  WebSocketChannel? _channel;
  MediaStream? _stream;
  MediaRecorder? _recorder;
  final List<Blob> _chunks = [];
  bool _isRecording = false;

  final void Function(String status)? onStatusUpdate;
  final void Function(String text, Uint8List audioData)? onFinalResponse;
  final void Function(String error)? onError;
  final void Function(String transcript)? onInterimTranscript;

  AiClient({
    required this.userId,
    this.onStatusUpdate,
    this.onFinalResponse,
    this.onError,
    this.onInterimTranscript,
  });

  // ✅ NEW: This method now explicitly creates a new connection for each turn.
  Future<void> startNewTurn() async {
    // Gracefully close any existing (and now defunct) channel before creating a new one.
    await _channel?.sink.close();
    print("🔌 Starting new turn, creating fresh WebSocket connection...");

    try {
      _channel = WebSocketChannel.connect(Uri.parse(SERVER_URL));

      // The new channel needs its own listener.
      _channel!.stream.listen(
        _handleServerMessage,
        onError: (e) => onError?.call("WebSocket error: $e"),
        onDone: () => onStatusUpdate?.call("disconnected"),
      );

      // Send the mandatory init message for the new connection.
      _channel!.sink.add(jsonEncode({"type": "init", "user_id": userId}));
    } catch (e) {
      onError?.call("Cannot connect to server: $e");
    }
  }

  void _handleServerMessage(dynamic message) {
    final data = jsonDecode(message);
    final type = data['type'];
    if (type == 'status') {
      onStatusUpdate?.call(data['message']);
    } else if (type == 'interim_transcript') {
      onInterimTranscript?.call(data['text']);
    } else if (type == 'final_response') {
      final text = data['text'];
      final audioData = base64Decode(data['data']);
      onFinalResponse?.call(text, audioData);
    }
  }

  void sendVideoFrame(Uint8List frameBytes) {
    if (_channel == null) return;
    final message = {"type": "video", "data": base64Encode(frameBytes)};
    _channel!.sink.add(jsonEncode(message));
  }

  Future<void> startRecording() async {
    _chunks.clear();
    _isRecording = true;
    onStatusUpdate?.call("listening");
    try {
      _stream = await window.navigator.getUserMedia(audio: true);
      _recorder = MediaRecorder(_stream!);
      _recorder!.addEventListener('dataavailable', (event) {
        final e = event as dynamic;
        _chunks.add(e.data as Blob);
      });
      _recorder!.start();
    } catch (e) {
      onError?.call("Microphone access denied or failed: $e");
    }
  }

  Future<Uint8List?> stopRecording() async {
    if (!_isRecording) return null;
    _isRecording = false;
    final completer = Completer<Uint8List?>();
    _recorder!.addEventListener('stop', (event) async {
      try {
        final blob = Blob(_chunks, 'audio/webm');
        final reader = FileReader();
        reader.readAsArrayBuffer(blob);
        reader.onLoad.listen(
          (_) => completer.complete(reader.result as Uint8List),
        );
        reader.onError.listen(
          (_) => completer.completeError("Failed to read audio"),
        );
      } catch (e) {
        completer.completeError(e);
      }
    });
    _recorder!.stop();
    _stream?.getTracks().forEach((track) => track.stop());
    return completer.future;
  }

  Future<void> sendAudio(Uint8List audioData) async {
    if (_channel == null) return;
    final message = {"type": "audio_file", "data": base64Encode(audioData)};
    _channel!.sink.add(jsonEncode(message));
  }

  Future<void> dispose() async {
    await _channel?.sink.close();
    _stream?.getTracks().forEach((track) => track.stop());
  }
}
