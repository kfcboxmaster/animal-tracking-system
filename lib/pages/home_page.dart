import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  CameraController? _cameraController;
  bool _isInitialized = false;
  bool _isRecording = false;
  XFile? _recordedVideo;
  VideoPlayerController? _processedVideoController;
  String? _processedVideoUrl;

  // Change this to your backend URL
  final String backendUploadUrl = "http://192.168.1.67:8000/upload/";

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _fetchGallery();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isNotEmpty) {
      _cameraController = CameraController(cameras[0], ResolutionPreset.medium);
      await _cameraController!.initialize();
      setState(() {
        _isInitialized = true;
      });
    }
  }

  Future<void> _startRecording() async {
    if (_cameraController != null && !_isRecording) {
      try {
        await _cameraController!.startVideoRecording();
        setState(() {
          _isRecording = true;
        });
      } catch (e) {
        print("Error starting recording: $e");
      }
    }
  }

  Future<void> _stopRecording() async {
    if (_cameraController != null && _isRecording) {
      try {
        final XFile videoFile = await _cameraController!.stopVideoRecording();
        setState(() {
          _isRecording = false;
          _recordedVideo = videoFile;
        });
        // Optionally, you can now automatically trigger upload
        _uploadVideo();
      } catch (e) {
        print("Error stopping recording: $e");
      }
    }
  }

  Future<void> _uploadVideo() async {
    if (_recordedVideo == null) return;

    // Create a multipart request
    try {
      var uri = Uri.parse(backendUploadUrl);
      var request = http.MultipartRequest('POST', uri);

      // force filename to .mp4
      String originalBasename =
          path.basenameWithoutExtension(_recordedVideo!.path);
      String mp4Name = '$originalBasename.mp4';

      // set Form fields
      request.fields['roi_x'] = "100";

      // attach video, but override filename & contentType
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          _recordedVideo!.path,
          filename: mp4Name,
          contentType: MediaType('video', 'mp4'),
        ),
      );

      // Send the request
      var response = await request.send();
      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        // Assume JSON: {"message": "Processing complete", "counts": {...}, "processed_video_url": "http://..."}
        final Map<String, dynamic> data = jsonDecode(respStr);
        setState(() {
          _processedVideoUrl = data["processed_video_url"];
        });
        // Initialize video player with the processed video URL
        _initializeProcessedVideoPlayer(_processedVideoUrl!);
      } else {
        print("Upload failed with status: ${response.statusCode}");
      }
    } catch (e) {
      print("Error uploading video: $e");
    }
  }

  Future<void> _initializeProcessedVideoPlayer(String url) async {
    if (_processedVideoController != null) {
      await _processedVideoController!.dispose();
    }
    _processedVideoController = VideoPlayerController.network(url)
      ..initialize().then((_) {
        setState(() {});
        _processedVideoController!.play();
      });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _processedVideoController?.dispose();
    super.dispose();
  }

  Widget _buildCameraPreview() {
    if (_isInitialized && _cameraController != null) {
      return AspectRatio(
        aspectRatio: _cameraController!.value.aspectRatio,
        child: CameraPreview(_cameraController!),
      );
    } else {
      return const Center(child: CircularProgressIndicator());
    }
  }

  Widget _buildProcessedVideoPlayer() {
    if (_processedVideoController != null &&
        _processedVideoController!.value.isInitialized) {
      return AspectRatio(
        aspectRatio: _processedVideoController!.value.aspectRatio,
        child: VideoPlayer(_processedVideoController!),
      );
    } else if (_processedVideoUrl != null) {
      return const Center(child: CircularProgressIndicator());
    } else {
      return const Text("Processed video will appear here");
    }
  }

  List<String> _gallery = [];

  Future<void> _fetchGallery() async {
    final uri = Uri.parse('http://192.168.1.67:8000/processed_videos/');
    try {
      final resp = await http.get(uri);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        setState(() => _gallery = List<String>.from(data['videos']));
      } else {
        print('Failed to load gallery: ${resp.statusCode}');
      }
    } catch (e) {
      print('Error fetching gallery: $e');
    }
  }

  Widget _buildGallery() {
    if (_gallery.isEmpty) {
      return const Center(child: Text('No processed videos yet'));
    }
    return ListView.builder(
      itemCount: _gallery.length,
      itemBuilder: (_, i) {
        final url = _gallery[i];
        final name = path.basename(url);
        return ListTile(
          title: Text(name),
          trailing: const Icon(Icons.play_arrow),
          onTap: () => _initializeProcessedVideoPlayer(url),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Video Recording & Processing")),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(flex: 2, child: _buildCameraPreview()),
            Expanded(
              flex: 2,
              child: _processedVideoController != null &&
                      _processedVideoController!.value.isInitialized
                  ? AspectRatio(
                      aspectRatio: _processedVideoController!.value.aspectRatio,
                      child: VideoPlayer(_processedVideoController!),
                    )
                  : _buildGallery(),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: _isRecording ? null : _startRecording,
                    child: const Text("Start Recording"),
                  ),
                  ElevatedButton(
                    onPressed: _isRecording ? _stopRecording : null,
                    child: const Text("Stop Recording"),
                  ),
                  ElevatedButton(
                    onPressed: _recordedVideo != null ? _uploadVideo : null,
                    child: const Text("Process Video"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
