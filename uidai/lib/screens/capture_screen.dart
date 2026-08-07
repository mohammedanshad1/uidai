import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../pipeline/pipeline_controller.dart';
import '../services/capture_pipeline_service.dart';
import 'auth_success_screen.dart';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class CaptureScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CaptureScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  _CaptureScreenState createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  late CameraController _cameraController;
  final PipelineController _pipelineController = PipelineController();
  final CapturePipelineService _capturePipelineService = CapturePipelineService();
  
  String _guidanceText = "Initializing...";
  PipelineState _state = PipelineState.initializing;
  img.Image? _capturedImage;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _initPipeline();
  }

  Future<void> _initCamera() async {
    _cameraController = CameraController(
      widget.cameras[0],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _cameraController.initialize();
    if (!mounted) return;

    _cameraController.startImageStream((CameraImage image) {
      _pipelineController.processCameraFrame(image);
    });

    setState(() {});
  }

  Future<void> _initPipeline() async {
    _pipelineController.onGuidanceUpdate = (text) {
      if (mounted) setState(() => _guidanceText = text);
    };

    _pipelineController.onStateUpdate = (state) {
      if (mounted) setState(() => _state = state);
      if (state == PipelineState.processing || state == PipelineState.completed) {
        _cameraController.stopImageStream();
      }
    };

    _pipelineController.onCaptureSuccess = (image) {
      if (mounted) setState(() => _capturedImage = image);
      _uploadToCloud(image);
    };

    await _pipelineController.initialize();
  }
  
  Future<void> _uploadToCloud(img.Image image) async {
    setState(() => _guidanceText = "Evaluating capture quality...");

    final quality = _capturePipelineService.evaluateQuality(image);
    if (!quality.shouldContinue) {
      setState(() => _guidanceText = quality.reason);
      return;
    }

    setState(() => _guidanceText = "Compressing for secure upload...");
    final payload = await _capturePipelineService.compressForCloud(image);

    setState(() => _guidanceText = "Uploading to secure cloud...");
    final response = await _capturePipelineService.submitToCloud(payload);

    if (response['status'] == 'accepted') {
      if (!mounted) return;
      setState(() => _guidanceText = 'Authentication successful. Template ready.');
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const AuthSuccessScreen(),
        ),
      );
    } else {
      setState(() => _guidanceText = 'Cloud matching failed. Retrying later.');
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _pipelineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_cameraController.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.blueAccent),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera Preview
          CameraPreview(_cameraController),
          
          // Overlay Gradient (Premium feel)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.4),
                  Colors.transparent,
                  Colors.black.withOpacity(0.8),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // ROI Animated Bounding Box
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 250,
              height: 350,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _state == PipelineState.completed 
                      ? Colors.greenAccent 
                      : _state == PipelineState.processing 
                          ? Colors.orangeAccent 
                          : Colors.cyanAccent.withOpacity(0.8),
                  width: _state == PipelineState.processing ? 4 : 2,
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  if (_state == PipelineState.processing)
                    BoxShadow(
                      color: Colors.orangeAccent.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  if (_state == PipelineState.completed)
                    BoxShadow(
                      color: Colors.greenAccent.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                ],
              ),
              child: Stack(
                children: [
                  // Corner markers
                  Positioned(top: 0, left: 0, child: _buildCorner(true, true)),
                  Positioned(top: 0, right: 0, child: _buildCorner(true, false)),
                  Positioned(bottom: 0, left: 0, child: _buildCorner(false, true)),
                  Positioned(bottom: 0, right: 0, child: _buildCorner(false, false)),
                ],
              ),
            ),
          ),
          
          // Guidance Text with Glassmorphism
          Positioned(
            bottom: 60,
            left: 30,
            right: 30,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 500),
              key: ValueKey(_guidanceText),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 10 * (1 - value)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: -5,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_state == PipelineState.processing)
                            const Padding(
                              padding: EdgeInsets.only(right: 12.0),
                              child: SizedBox(
                                width: 20, 
                                height: 20, 
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                              ),
                            ),
                          if (_state == PipelineState.completed)
                            const Padding(
                              padding: EdgeInsets.only(right: 12.0),
                              child: Icon(Icons.check_circle, color: Colors.greenAccent, size: 24),
                            ),
                          Expanded(
                            child: Text(
                              _guidanceText,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white, 
                                fontSize: 18, 
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
            ),
          ),
          
          // Result Image (Mock Thumbnail)
          if (_capturedImage != null)
            Positioned(
              top: 60,
              right: 20,
              child: AnimatedOpacity(
                opacity: _capturedImage != null ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 600),
                child: Container(
                  width: 90,
                  height: 130,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.greenAccent, width: 2),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 5))
                    ],
                    image: DecorationImage(
                      image: MemoryImage(Uint8List.fromList(img.encodePng(_capturedImage!))),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCorner(bool isTop, bool isLeft) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        border: Border(
          top: isTop ? const BorderSide(color: Colors.cyanAccent, width: 4) : BorderSide.none,
          bottom: !isTop ? const BorderSide(color: Colors.cyanAccent, width: 4) : BorderSide.none,
          left: isLeft ? const BorderSide(color: Colors.cyanAccent, width: 4) : BorderSide.none,
          right: !isLeft ? const BorderSide(color: Colors.cyanAccent, width: 4) : BorderSide.none,
        ),
      ),
    );
  }
}
