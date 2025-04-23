import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

List<CameraDescription> cameras = [];

void main() async {
  // Ensure that plugin services are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Get available cameras
  try {
    cameras = await availableCameras();
    print('Found ${cameras.length} cameras');
    for (var camera in cameras) {
      print('Camera: ${camera.name}, direction: ${camera.lensDirection}');
    }
  } on CameraException catch (e) {
    print('Error getting cameras: ${e.code}: ${e.description}');
  }

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: cameras.isEmpty 
          ? const NoCameraScreen() 
          : CameraScreen(camera: cameras.first),
    ),
  );
}

class NoCameraScreen extends StatelessWidget {
  const NoCameraScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera Error'),
        backgroundColor: Colors.red,
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, size: 80, color: Colors.red),
              SizedBox(height: 16),
              Text(
                'No camera found or camera access denied',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Text(
                'Please check your camera connection and app permissions in your device settings.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CameraScreen extends StatefulWidget {
  final CameraDescription camera;

  const CameraScreen({Key? key, required this.camera}) : super(key: key);

  @override
  CameraScreenState createState() => CameraScreenState();
}

class CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  bool _isRecording = false;
  String _videoPath = '';
  String _savedVideoPath = '';
  String _videoDirectory = '';
  bool _isCameraInitialized = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Set up the video directory
    _setupVideoDirectory().then((_) {
      // Initialize camera after setting up directory
      _initializeCamera();
    });
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;

    // App state changed before controller was initialized
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      // Free up memory when camera not active
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      // Reinitialize the camera with same properties
      _initializeCamera();
    }
  }

  Future<void> _setupVideoDirectory() async {
    try {
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
      
      // Create directory if it doesn't exist
      Directory videoDir = Directory(_videoDirectory);
      if (!await videoDir.exists()) {
        await videoDir.create(recursive: true);
      }
      print('Video directory set to: $_videoDirectory');
    } catch (e) {
      print('Error setting up video directory: $e');
      _errorMessage = 'Error setting up storage: $e';
    }
  }
  
  Future<void> _initializeCamera() async {
    final CameraController cameraController = CameraController(
      widget.camera,
      ResolutionPreset.high,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    
    _controller = cameraController;

    // Initialize the controller future
    _initializeControllerFuture = cameraController.initialize().then((_) {
      if (!mounted) return;
      setState(() {
        _isCameraInitialized = true;
        _errorMessage = '';
      });
      print('Camera initialized successfully');
    }).catchError((Object e) {
      if (e is CameraException) {
        switch (e.code) {
          case 'CameraAccessDenied':
            _errorMessage = 'Camera access was denied';
            break;
          case 'CameraAccessDeniedWithoutPrompt':
            _errorMessage = 'Camera access was denied without prompt';
            break;
          case 'CameraAccessRestricted':
            _errorMessage = 'Camera access is restricted';
            break;
          case 'AudioAccessDenied':
            _errorMessage = 'Audio recording permission was denied';
            break;
          default:
            _errorMessage = 'Error: ${e.code}\n${e.description}';
            break;
        }
      } else {
        _errorMessage = 'Error: $e';
      }
      
      print('Camera initialization error: $_errorMessage');
      setState(() {});
      return;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _startVideoRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      showInSnackBar('Error: Camera is not initialized');
      return;
    }
    
    if (_controller!.value.isRecordingVideo) {
      showInSnackBar('A recording is already in progress');
      return;
    }

    try {
      await _initializeControllerFuture;

      // Create a unique file name
      final String videoFileName = 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final String videoFilePath = path.join(_videoDirectory, videoFileName);

      await _controller!.startVideoRecording();
      
      setState(() {
        _isRecording = true;
        _videoPath = videoFilePath;
      });
      
      showInSnackBar('Recording started');
    } on CameraException catch (e) {
      showInSnackBar('Error starting recording: ${e.description}');
      return;
    } catch (e) {
      showInSnackBar('Error starting recording: $e');
    }
  }

  Future<void> _stopVideoRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      showInSnackBar('Error: Camera is not initialized');
      return;
    }

    if (!_controller!.value.isRecordingVideo) {
      showInSnackBar('No recording in progress');
      return;
    }

    try {
      final XFile videoFile = await _controller!.stopVideoRecording();
      showInSnackBar('Recording stopped');
      
      // Copy the file to our predefined directory
      final File originalVideoFile = File(videoFile.path);
      print('Original video path: ${videoFile.path}');
      
      final File savedVideoFile = await originalVideoFile.copy(_videoPath);
      print('Saved video to: ${savedVideoFile.path}');
      
      setState(() {
        _isRecording = false;
        _savedVideoPath = savedVideoFile.path;
      });

      showInSnackBar('Video saved to: $_savedVideoPath');
    } on CameraException catch (e) {
      showInSnackBar('Error stopping recording: ${e.description}');
      setState(() {
        _isRecording = false;
      });
      return;
    } catch (e) {
      showInSnackBar('Error stopping recording: $e');
      setState(() {
        _isRecording = false;
      });
    }
  }
  
  void showInSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Camera Error'),
          backgroundColor: Colors.red,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 80, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Camera Error',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _initializeCamera,
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Raspberry Pi 5 Camera'),
        backgroundColor: Colors.red,
      ),
      body: _controller == null || !_isCameraInitialized
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Initializing camera...'),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      border: Border.all(
                        color: _isRecording ? Colors.red : Colors.blue,
                        width: 3,
                      ),
                    ),
                    child: CameraPreview(_controller!),
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isRecording ? Icons.stop : Icons.videocam,
                        size: 36,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _isRecording ? 'STOP RECORDING' : 'START RECORDING',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
    );
  }
}
