import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

void main() async {
  // Ensure that plugin services are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Get available cameras
  final cameras = await availableCameras();
  final firstCamera = cameras.first;

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: CameraScreen(camera: firstCamera),
    ),
  );
}

class CameraScreen extends StatefulWidget {
  final CameraDescription camera;

  const CameraScreen({Key? key, required this.camera}) : super(key: key);

  @override
  CameraScreenState createState() => CameraScreenState();
}

class CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  bool _isRecording = false;
  String _videoPath = '';
  String _savedVideoPath = '';
  String _videoDirectory = '';

  @override
  void initState() {
    super.initState();
    // Initialize the camera controller
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.high,
      enableAudio: true,
    );

    // Initialize the controller future
    _initializeControllerFuture = _controller.initialize();
    
    // Set up the video directory
    _setupVideoDirectory();
  }

  Future<void> _setupVideoDirectory() async {
    if (Platform.isWindows) {
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      _videoDirectory = '${appDocDir.path}\\RaspberryPiVideos';
    } else if (Platform.isLinux) {
      // For Raspberry Pi (Linux)
      _videoDirectory = '/home/pi/videos';
    } else {
      // For other platforms
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      _videoDirectory = '${appDocDir.path}/RaspberryPiVideos';
    }
  }

  @override
  void dispose() {
    // Dispose of the controller when the widget is disposed
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startVideoRecording() async {
    // Ensure the camera is initialized
    try {
      await _initializeControllerFuture;

      // Create a video recording directory
      Directory videoDir = Directory(_videoDirectory);
      if (!await videoDir.exists()) {
        await videoDir.create(recursive: true);
      }

      // Create a unique file name
      final String videoFileName = 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final String videoFilePath = path.join(_videoDirectory, videoFileName);

      await _controller.startVideoRecording();
      
      setState(() {
        _isRecording = true;
        _videoPath = videoFilePath;
      });
    } catch (e) {
      print('Error starting video recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting recording: $e')),
      );
    }
  }

  Future<void> _stopVideoRecording() async {
    if (!_controller.value.isRecordingVideo) {
      return;
    }

    try {
      final XFile videoFile = await _controller.stopVideoRecording();
      
      // Copy the file to our predefined directory
      final File originalVideoFile = File(videoFile.path);
      final File savedVideoFile = await originalVideoFile.copy(_videoPath);
      
      setState(() {
        _isRecording = false;
        _savedVideoPath = savedVideoFile.path;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Video saved to: $_savedVideoPath')),
      );
    } catch (e) {
      print('Error stopping video recording: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Raspberry Pi 5 Camera'),
        backgroundColor: Colors.red,
      ),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Column(
              children: [
                Expanded(
                  child: Center(
                    child: CameraPreview(_controller),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRecording ? Colors.red : Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    minimumSize: const Size(300, 100),
                  ),
                  onPressed: () {
                    if (_isRecording) {
                      _stopVideoRecording();
                    } else {
                      _startVideoRecording();
                    }
                  },
                  child: Text(
                    _isRecording ? 'STOP RECORDING' : 'START RECORDING',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
