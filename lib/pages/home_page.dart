import 'dart:ffi';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  List<CameraDescription> cameras = [];
  CameraController? cameraController;

  static const String url = "ws://<network_ipv4>:5000";
  WebSocketChannel? _channel;
  bool _isConnected = false;

  void connect() {
    _channel = IOWebSocketChannel.connect(Uri.parse(url));
    setState(() {
      _isConnected = true;
    });
  }

  void disconnect() {
    _channel!.sink.close();
    setState(() {
      _isConnected = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (cameraController == null ||
        cameraController?.value.isInitialized == false) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _setupCameraController();
    }
  }

  @override
  void initState() {
    super.initState();
    _setupCameraController();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildUI(),
    );
  }

  Widget _buildUI() {
    if (cameraController == null ||
        cameraController?.value.isInitialized == false) {
      return const Center(child: CircularProgressIndicator());
    }
    return SafeArea(
        child: SizedBox.expand(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.30,
              width: MediaQuery.sizeOf(context).width * 0.80,
              child: Transform.rotate(
                  angle: 3.1416 / 2, child: CameraPreview(cameraController!))),
          IconButton(
              onPressed: () async {
                XFile picture = await cameraController!.takePicture();
                Gal.putImage(
                  picture.path,
                );
              },
              iconSize: 100,
              icon: const Icon(
                Icons.camera,
                color: Colors.red,
              )),
          IconButton(
              onPressed: () async {
                if (cameraController!.value.isRecordingVideo) {
                  XFile video = await cameraController!.stopVideoRecording();
                  print("Video recorded at: ${video.path}");
                  Gal.putVideo(
                    video.path,
                  );
                } else {
                  await cameraController!.startVideoRecording();
                }
              },
              iconSize: 100,
              icon: const Icon(
                Icons.camera,
                color: Colors.blue,
              ))
        ],
      ),
    ));
  }

  Future<void> _setupCameraController() async {
    List<CameraDescription> _cameras = await availableCameras();
    if (_cameras.isNotEmpty) {
      setState(() {
        cameras = _cameras;
        cameraController =
            CameraController(_cameras.first, ResolutionPreset.high);
      });

      cameraController?.initialize().then((_) {
        if (!mounted) {
          return;
        }
        setState(() {});
      }).catchError((Object e) {
        print(e);
      });
    }
  }
}
