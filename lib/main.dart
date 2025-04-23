import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:process_run/process_run.dart';

void main() {
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
      home: const RaspberryPiCamera(),
    );
  }
}

class RaspberryPiCamera extends StatefulWidget {
  const RaspberryPiCamera({Key? key}) : super(key: key);

  @override
  State<RaspberryPiCamera> createState() => _RaspberryPiCameraState();
}

class _RaspberryPiCameraState extends State<RaspberryPiCamera> {
  bool _isRecording = false;
  String _videoDirectory = '/home/pi/videos';
  String _currentVideoPath = '';
  Process? _recordingProcess;
  final StreamController<String> _logStreamController = StreamController<String>.broadcast();
  
  @override
  void initState() {
    super.initState();
    _setupVideoDirectory();
  }

  @override
  void dispose() {
    _stopRecording();
    _logStreamController.close();
    super.dispose();
  }

  Future<void> _setupVideoDirectory() async {
    try {
      // Create the video directory if it doesn't exist
      final directory = Directory(_videoDirectory);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      _log('Video directory set to: $_videoDirectory');
    } catch (e) {
      _log('Error setting up video directory: $e');
    }
  }

  void _log(String message) {
    debugPrint(message);
    _logStreamController.add(message);
  }

  Future<void> _startRecording() async {
    if (_isRecording) {
      _log('Already recording');
      return;
    }

    try {
      // Create a timestamp-based filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentVideoPath = path.join(_videoDirectory, 'video_$timestamp.h264');
      
      _log('Starting recording to: $_currentVideoPath');
      
      // Start the libcamera-vid command
      // Using standard parameters, adjust as needed for your specific camera
      final shell = Shell();
      
      _log('Running libcamera-vid command...');
      
      // Launch the process
      _recordingProcess = await shell.startDetached(
        'libcamera-vid',
        [
          '--output', _currentVideoPath,
          '--width', '1920',
          '--height', '1080',
          '--timeout', '0', // No timeout, we'll stop it manually
          '--nopreview' // No preview since we're using Flutter UI
        ],
      );
      
      setState(() {
        _isRecording = true;
      });
      
      _log('Recording started with PID: ${_recordingProcess?.pid}');
    } catch (e) {
      _log('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording || _recordingProcess == null) {
      _log('Not recording');
      return;
    }

    try {
      _log('Stopping recording...');
      
      // Kill the recording process
      final process = _recordingProcess;
      if (process != null) {
        if (Platform.isLinux || Platform.isMacOS) {
          // On Linux (Raspberry Pi) we terminate the process
          Process.killPid(process.pid);
        } else {
          // This would be used on other platforms, but Raspberry Pi is Linux
          process.kill();
        }
      }
      
      // Convert the H264 to MP4 if needed
      await _convertVideoToMP4();
      
      setState(() {
        _isRecording = false;
        _recordingProcess = null;
      });
      
      _log('Recording stopped. Video saved to: $_currentVideoPath');
    } catch (e) {
      _log('Error stopping recording: $e');
      setState(() {
        _isRecording = false;
        _recordingProcess = null;
      });
    }
  }

  Future<void> _convertVideoToMP4() async {
    try {
      if (!_currentVideoPath.endsWith('.h264')) {
        return; // No conversion needed
      }
      
      final mp4Path = _currentVideoPath.replaceAll('.h264', '.mp4');
      _log('Converting H264 to MP4: $mp4Path');
      
      final shell = Shell();
      await shell.run('MP4Box -add $_currentVideoPath $mp4Path');
      
      _log('Conversion complete: $mp4Path');
      
      // Update the current path to the MP4 file
      _currentVideoPath = mp4Path;
    } catch (e) {
      _log('Error converting video: $e');
      _log('Note: You may need to install MP4Box using: sudo apt-get install gpac');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Raspberry Pi 5 AI Camera'),
        backgroundColor: Colors.red,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              color: Colors.black,
              child: Center(
                child: _isRecording
                    ? Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.videocam,
                          color: Colors.white,
                          size: 60,
                        ),
                      )
                    : const Text(
                        'Camera Preview Not Available',
                        style: TextStyle(color: Colors.white),
                      ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isRecording ? Colors.red : Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      minimumSize: const Size(300, 100),
                    ),
                    onPressed: _isRecording ? _stopRecording : _startRecording,
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
                  const SizedBox(height: 16),
                  Expanded(
                    child: StreamBuilder<String>(
                      stream: _logStreamController.stream,
                      builder: (context, snapshot) {
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: SingleChildScrollView(
                            child: Text(
                              snapshot.data ?? 'Waiting for logs...',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
