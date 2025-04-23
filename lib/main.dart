import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Raspberry Pi 5 Camera',
      debugShowCheckedModeBanner: false,
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
  Process? _streamProcess;
  WebViewController? _webViewController;
  bool _isStreamRunning = false;
  
  // Assuming your Raspberry Pi's IP address
  // Use local IP if running on Raspberry Pi itself
  final String _streamUrl = 'http://127.0.0.1:8080/';
  
  @override
  void initState() {
    super.initState();
    _createOutputDirectory();
    _initWebView();
    _startCameraStream();
  }

  @override
  void dispose() {
    _stopRecording();
    _stopCameraStream();
    _scrollController.dispose();
    super.dispose();
  }
  
  void _initWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(_streamUrl));
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
  
  Future<void> _startCameraStream() async {
    if (_isStreamRunning) return;
    
    try {
      _addLog('Starting camera stream...');
      
      // Start a streaming server using libcamera-vid
      // Port 8080 for HTTP stream
      _streamProcess = await Process.start(
        'libcamera-vid',
        [
          '--width', '640',
          '--height', '480',
          '--framerate', '30',
          '--inline', // Use inline headers for lower latency
          '--listen', // Enable HTTP server
          '--output', 'tcp://0.0.0.0:8080' // Stream over TCP
        ],
        runInShell: true,
      );
      
      _addLog('Camera stream started on port 8080');
      
      _streamProcess?.stdout.listen((data) {
        _addLog('Stream output: ${String.fromCharCodes(data).trim()}');
      });
      
      _streamProcess?.stderr.listen((data) {
        _addLog('Stream error: ${String.fromCharCodes(data).trim()}');
      });
      
      setState(() {
        _isStreamRunning = true;
      });
      
      // Alternative method using raspivid if libcamera-vid streaming doesn't work
      // Comment out the above code and uncomment this if needed
      /*
      _streamProcess = await Process.start(
        'raspivid',
        [
          '-t', '0',
          '-w', '640',
          '-h', '480',
          '-fps', '30',
          '-o', '-', // Output to stdout
          '|',
          'cvlc', 
          '-', // Read from stdin
          '--sout', '#standard{access=http,mux=ts,dst=0.0.0.0:8080}',
          '--no-audio'
        ],
        runInShell: true,
      );
      */
      
    } catch (e) {
      _addLog('Error starting camera stream: $e');
      setState(() {
        _isStreamRunning = false;
      });
    }
  }
  
  Future<void> _stopCameraStream() async {
    if (_streamProcess != null) {
      _addLog('Stopping camera stream...');
      _streamProcess!.kill(ProcessSignal.sigterm);
      await _streamProcess!.exitCode;
      setState(() {
        _isStreamRunning = false;
      });
      _addLog('Camera stream stopped');
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
      
      // Run libcamera-vid command to record video without displaying preview
      // (since we're already showing the stream in the WebView)
      _cameraProcess = await Process.start(
        'libcamera-vid', 
        [
          '--output', _currentVideoPath,
          '--width', '1920',
          '--height', '1080',
          '--nopreview'
        ],
        runInShell: true,
      );
      
      _addLog('Recording started with PID: ${_cameraProcess?.pid}');
      
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
  
  Widget _buildCameraPreview() {
    if (Platform.isLinux) {
      // Use WebView to display the camera stream
      if (_webViewController != null) {
        return WebViewWidget(controller: _webViewController!);
      } else {
        return const Center(
          child: Text('Initializing camera preview...'),
        );
      }
    } else {
      // On non-Linux platforms, show a placeholder
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.videocam,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'Camera preview only available on Raspberry Pi',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Raspberry Pi 5 Camera'),
        backgroundColor: Colors.red,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _stopCameraStream();
              _startCameraStream();
              _webViewController?.reload();
            },
            tooltip: 'Restart Camera Stream',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _isRecording ? Colors.red : Colors.blue,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Stack(
                  children: [
                    _buildCameraPreview(),
                    if (_isRecording)
                      Positioned(
                        top: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'REC',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
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
            height: 150,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade400),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'LOG:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.clear_all, size: 16),
                      onPressed: () {
                        setState(() {
                          _logMessages.clear();
                        });
                      },
                      tooltip: 'Clear logs',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
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
