import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

Future<void> main() async {
  // Ensure all widgets are initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(const RaspberryPiCameraApp());
}

class RaspberryPiCameraApp extends StatelessWidget {
  const RaspberryPiCameraApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const CameraScreen(),
    );
  }
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  CameraScreenState createState() => CameraScreenState();
}

class CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  List<CameraDescription>? cameras;
  CameraController? controller;
  int selectedCameraIndex = 0;
  bool _isRecording = false;
  String _videoPath = '';
  String _savedVideoPath = '';
  String _videoDirectory = '';
  String _errorMessage = '';
  bool _camerasLoaded = false;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize everything
    _initializeAll();
  }
  
  Future<void> _initializeAll() async {
    await _setupVideoDirectory();
    await _loadCameras();
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
      debugPrint('Video directory set to: $_videoDirectory');
    } catch (e) {
      debugPrint('Error setting up video directory: $e');
      setState(() {
        _errorMessage = 'Error setting up storage: $e';
      });
    }
  }
  
  Future<void> _loadCameras() async {
    try {
      cameras = await availableCameras();
      
      if (cameras != null && cameras!.isNotEmpty) {
        debugPrint('Found ${cameras!.length} cameras');
        for (var i = 0; i < cameras!.length; i++) {
          debugPrint('Camera $i: ${cameras![i].name}, ${cameras![i].lensDirection}');
        }
        
        // Start with the first camera
        await _initCamera(0);
      } else {
        setState(() {
          _errorMessage = 'No cameras found';
        });
      }
    } on CameraException catch (e) {
      debugPrint('Camera error: ${e.code}: ${e.description}');
      setState(() {
        _errorMessage = 'Camera error: ${e.description}';
      });
    } catch (e) {
      debugPrint('Error loading cameras: $e');
      setState(() {
        _errorMessage = 'Error loading cameras: $e';
      });
    } finally {
      setState(() {
        _camerasLoaded = true;
      });
    }
  }
  
  Future<void> _initCamera(int index) async {
    if (cameras == null || cameras!.isEmpty) {
      setState(() {
        _errorMessage = 'No cameras available';
      });
      return;
    }
    
    // If the controller is already initialized, dispose it first
    if (controller != null) {
      await controller!.dispose();
    }
    
    if (index >= cameras!.length) {
      index = 0;
    }
    
    setState(() {
      _errorMessage = '';
    });
    
    try {
      // Use low preset to ensure compatibility
      controller = CameraController(
        cameras![index],
        ResolutionPreset.low,
        enableAudio: true,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      
      await controller!.initialize();
      selectedCameraIndex = index;
      
      if (mounted) {
        setState(() {});
      }
      
      debugPrint('Camera $index initialized successfully');
    } on CameraException catch (e) {
      debugPrint('Failed to initialize camera $index: ${e.code}, ${e.description}');
      setState(() {
        _errorMessage = 'Failed to initialize camera: ${e.description}';
      });
    } catch (e) {
      debugPrint('Error initializing camera $index: $e');
      setState(() {
        _errorMessage = 'Error initializing camera: $e';
      });
    }
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (controller == null || !controller!.value.isInitialized) {
      return;
    }
    
    if (state == AppLifecycleState.inactive) {
      controller!.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera(selectedCameraIndex);
    }
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller?.dispose();
    super.dispose();
  }
  
  void _toggleCamera() async {
    if (cameras == null || cameras!.isEmpty) return;
    
    final newIndex = (selectedCameraIndex + 1) % cameras!.length;
    await _initCamera(newIndex);
  }
  
  Future<void> _startVideoRecording() async {
    if (controller == null || !controller!.value.isInitialized) {
      _showMessage('Error: Camera is not initialized');
      return;
    }
    
    if (controller!.value.isRecordingVideo) {
      _showMessage('A recording is already in progress');
      return;
    }
    
    try {
      // Create a unique file name
      final String videoFileName = 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final String videoFilePath = path.join(_videoDirectory, videoFileName);
      
      await controller!.startVideoRecording();
      
      setState(() {
        _isRecording = true;
        _videoPath = videoFilePath;
      });
      
      _showMessage('Recording started');
    } on CameraException catch (e) {
      _showMessage('Error starting recording: ${e.description}');
    } catch (e) {
      _showMessage('Error starting recording: $e');
    }
  }
  
  Future<void> _stopVideoRecording() async {
    if (controller == null || !controller!.value.isInitialized) {
      _showMessage('Error: Camera is not initialized');
      return;
    }
    
    if (!controller!.value.isRecordingVideo) {
      _showMessage('No recording in progress');
      return;
    }
    
    try {
      final XFile videoFile = await controller!.stopVideoRecording();
      debugPrint('Original video path: ${videoFile.path}');
      
      // Copy the file to our predefined directory
      final File originalVideoFile = File(videoFile.path);
      final File savedVideoFile = await originalVideoFile.copy(_videoPath);
      
      setState(() {
        _isRecording = false;
        _savedVideoPath = savedVideoFile.path;
      });
      
      _showMessage('Video saved to: $_savedVideoPath');
    } on CameraException catch (e) {
      _showMessage('Error stopping recording: ${e.description}');
      setState(() {
        _isRecording = false;
      });
    } catch (e) {
      _showMessage('Error stopping recording: $e');
      setState(() {
        _isRecording = false;
      });
    }
  }
  
  void _showMessage(String message) {
    debugPrint(message);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }
  
  Widget _buildCameraView() {
    if (controller == null || !controller!.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    return AspectRatio(
      aspectRatio: controller!.value.aspectRatio,
      child: CameraPreview(controller!),
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
                const Text(
                  'Camera Error',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _initializeAll,
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    if (!_camerasLoaded) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading cameras...'),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Raspberry Pi 5 Camera'),
        backgroundColor: Colors.red,
        actions: [
          if (cameras != null && cameras!.length > 1)
            IconButton(
              icon: const Icon(Icons.flip_camera_ios),
              onPressed: _toggleCamera,
              tooltip: 'Switch Camera',
            ),
        ],
      ),
      body: Column(
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
              child: _buildCameraView(),
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
