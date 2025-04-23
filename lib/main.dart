import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Raspberry Pi 5 Camera',
      theme: ThemeData(
        primarySwatch: Colors.red,
        useMaterial3: true,
      ),
      home: const CameraScreen(),
    );
  }
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  bool _isRecording = false;
  String _outputDir = '/home/pi/videos';
  String _currentVideoPath = '';
  final List<String> _logMessages = [];
  final ScrollController _scrollController = ScrollController();
  Process? _cameraProcess;

  @override
  void initState() {
    super.initState();
    _createOutputDirectory();
  }

  @override
  void dispose() {
    _stopRecording();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _createOutputDirectory() async {
    try {
      // Create output directory if it doesn't exist
      final dir = Directory(_outputDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      _addLog('Output directory: $_outputDir');
    } catch (e) {
      _addLog('Error creating directory: $e');
    }
  }

  void _addLog(String message) {
    setState(() {
      _logMessages.add('${DateTime.now().toString().split('.').first}: $message');
    });
    
    // Scroll to bottom of log
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

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    if (_isRecording) return;

    _addLog('Starting recording...');
    
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentVideoPath = '$_outputDir/video_$timestamp.h264';
      
      _addLog('Recording to: $_currentVideoPath');
      
      // Run libcamera-vid command
      _cameraProcess = await Process.start(
        'libcamera-vid', 
        [
          '--output', _currentVideoPath,
          '--width', '1920',
          '--height', '1080',
          '--timeout', '0',    // No timeout, manual stop
          '--nopreview'        // No preview
        ],
        runInShell: true,
      );
      
      _addLog('Recording started with PID: ${_cameraProcess?.pid}');
      
      // Listen to process stdout and stderr
      _cameraProcess?.stdout.listen((data) {
        _addLog('Camera output: ${String.fromCharCodes(data).trim()}');
      });
      
      _cameraProcess?.stderr.listen((data) {
        _addLog('Camera error: ${String.fromCharCodes(data).trim()}');
      });
      
      setState(() {
        _isRecording = true;
      });
    } catch (e) {
      _addLog('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    _addLog('Stopping recording...');
    
    try {
      // Kill the process
      if (_cameraProcess != null) {
        _addLog('Terminating process ${_cameraProcess!.pid}');
        _cameraProcess!.kill(ProcessSignal.sigterm);
        await _cameraProcess!.exitCode;
      }
      
      _addLog('Recording stopped. Video saved to $_currentVideoPath');
      
      // Convert to MP4
      _convertToMP4();
      
      setState(() {
        _isRecording = false;
        _cameraProcess = null;
      });
    } catch (e) {
      _addLog('Error stopping recording: $e');
      setState(() {
        _isRecording = false;
        _cameraProcess = null;
      });
    }
  }

  Future<void> _convertToMP4() async {
    try {
      if (!_currentVideoPath.endsWith('.h264')) return;
      
      final mp4Path = _currentVideoPath.replaceAll('.h264', '.mp4');
      _addLog('Converting to MP4: $mp4Path');
      
      final result = await Process.run(
        'MP4Box',
        ['-add', _currentVideoPath, mp4Path],
        runInShell: true,
      );
      
      if (result.exitCode == 0) {
        _addLog('Conversion successful');
      } else {
        _addLog('Conversion error: ${result.stderr}');
      }
    } catch (e) {
      _addLog('Error converting video: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Raspberry Pi 5 Camera'),
        backgroundColor: Colors.red,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: Center(
              child: _isRecording
                  ? Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.videocam,
                              color: Colors.white,
                              size: 80,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'RECORDING',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(
                                    blurRadius: 10.0,
                                    color: Colors.red.shade800,
                                    offset: const Offset(0, 0),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const Text(
                      'Press the button below to start recording',
                      style: TextStyle(fontSize: 18),
                    ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            child: ElevatedButton(
              onPressed: _toggleRecording,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isRecording ? Colors.red : Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                minimumSize: const Size(double.infinity, 100),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isRecording ? Icons.stop : Icons.videocam,
                    size: 40,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    _isRecording ? 'STOP RECORDING' : 'START RECORDING',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            height: 200,
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade400),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'LOG:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _logMessages.length,
                    itemBuilder: (context, index) {
                      return Text(
                        _logMessages[index],
                        style: const TextStyle(fontSize: 12),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
