import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'websocket_service.dart';

class VideoStreamPage extends StatefulWidget {
  const VideoStreamPage({super.key});

  @override
  _VideoStreamPageState createState() => _VideoStreamPageState();
}

class _VideoStreamPageState extends State<VideoStreamPage> {
  CameraController? _cameraController;
  final WebSocketService _webSocketService = WebSocketService();
  Uint8List? processedFrame;

  @override
  void initState() {
    super.initState();
    initializeCamera();
    _webSocketService.connect("ws://192.168.73.163:5000/ws");
    _webSocketService.processedStream.listen((base64Image) {
      setState(() {
        processedFrame = base64Decode(base64Image);
      });
    });
  }

  Future<void> initializeCamera() async {
    final cameras = await availableCameras();
    _cameraController = CameraController(cameras[0], ResolutionPreset.medium);
    await _cameraController!.initialize();
    startStreaming();
  }

  void startStreaming() {
    Timer.periodic(Duration(milliseconds: 100), (timer) async {
      if (!_cameraController!.value.isInitialized) return;
      final XFile image = await _cameraController!.takePicture();
      final bytes = await image.readAsBytes();
      _webSocketService.sendFrame("cow", bytes); // Change to "sheep" or "horse"
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _webSocketService.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Animal Detection Stream")),
      body: Column(
        children: [
          if (_cameraController?.value.isInitialized ?? false)
            SizedBox(
              height: 300,
              child: CameraPreview(_cameraController!),
            ),
          SizedBox(height: 20),
          processedFrame != null
              ? Image.memory(processedFrame!)
              : Text("Waiting for processed video..."),
        ],
      ),
    );
  }
}
