import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shiffters/theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:shiffters/services/theme_service.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:camera/camera.dart';

class DetectedObject {
  final String className;
  final double confidence;
  final Rect boundingBox;
  final String id;

  DetectedObject({
    required this.className,
    required this.confidence,
    required this.boundingBox,
    required this.id,
  });
}

class LiveObjectDetectionScreen extends StatefulWidget {
  final Function(List<String>) onObjectsSelected;

  const LiveObjectDetectionScreen({
    super.key,
    required this.onObjectsSelected,
  });

  @override
  State<LiveObjectDetectionScreen> createState() =>
      _LiveObjectDetectionScreenState();
}

class _LiveObjectDetectionScreenState extends State<LiveObjectDetectionScreen>
    with TickerProviderStateMixin {
  // Camera and detection state
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isDetecting = false;
  Timer? _detectionTimer;
  List<DetectedObject> _detectedObjects = [];
  List<String> _selectedObjects = [];
  List<String> _detectedObjectsList = []; // List of all detected objects
  bool _showObjectsList = false;

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  // API Configuration
  static const String _yoloApiBaseUrl =
      'https://trickily-photoactinic-alita.ngrok-free.dev';
  static const String _yoloApiEndpoint = '/yolo/detect';

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeCamera();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_fadeController);

    _pulseController.repeat(reverse: true);
    _fadeController.forward();
  }

  void _initializeCamera() async {
    try {
      // Get available cameras
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('No cameras available');
      }

      // Initialize camera controller
      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });

        // Start continuous detection
        _startContinuousDetection();
      }
    } catch (e) {
      print('Error initializing camera: $e');
      if (mounted) {
        _showMessage('Failed to initialize camera: $e', isError: true);
      }
    }
  }

  void _startContinuousDetection() {
    _detectionTimer =
        Timer.periodic(const Duration(milliseconds: 5000), (timer) {
      if (!_isDetecting && mounted && _isCameraInitialized) {
        _captureAndDetect();
      }
    });
  }

  void _captureAndDetect() async {
    if (_isDetecting ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return;
    }

    setState(() {
      _isDetecting = true;
    });

    try {
      // Capture image from camera
      final XFile image = await _cameraController!.takePicture();
      await _detectObjectsInImage(image);
    } catch (e) {
      print('Error in capture and detect: $e');
      if (mounted) {
        _showMessage('Detection failed: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDetecting = false;
        });
      }
    }
  }

  Future<void> _detectObjectsInImage(XFile imageFile) async {
    try {
      print('Starting object detection for image: ${imageFile.path}');

      // Read and process image
      final File file = File(imageFile.path);
      final List<int> imageBytes = await file.readAsBytes();

      print('Image size: ${imageBytes.length} bytes');

      // Encode to base64
      final String base64Image = base64Encode(imageBytes);

      print('Sending request to YOLO API...');

      // Call YOLO API with improved request format
      final response = await http
          .post(
            Uri.parse('$_yoloApiBaseUrl$_yoloApiEndpoint'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'ngrok-skip-browser-warning': 'true',
              'User-Agent': 'Flutter-App/1.0',
            },
            body: jsonEncode({
              'image_base64': base64Image, // Use correct field name
              'confidence': 0.3,
              'iou_threshold': 0.45,
            }),
          )
          .timeout(const Duration(seconds: 15));

      print('API Response Status: ${response.statusCode}');
      print('API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        print('Successful API response received');
        await _parseDetections(responseData);
      } else {
        print('API Error ${response.statusCode}: ${response.body}');
        if (mounted) {
          _showMessage('Detection API error: ${response.statusCode}',
              isError: true);
        }
      }
    } catch (e) {
      print('Error detecting objects: $e');
      print('Stack trace: ${StackTrace.current}');
      if (mounted) {
        if (e.toString().contains('TimeoutException')) {
          _showMessage('Detection timeout - check network', isError: true);
        } else if (e.toString().contains('SocketException')) {
          _showMessage('Cannot connect to detection server', isError: true);
        } else {
          _showMessage('Detection failed: ${e.toString().split(':').last}',
              isError: true);
        }
      }
    }
  }

  Future<void> _parseDetections(Map<String, dynamic> responseData) async {
    try {
      // Debug logging
      print('YOLO API Response: ${responseData.toString()}');

      List<dynamic> detections = [];

      if (responseData.containsKey('detections') &&
          responseData['detections'] != null) {
        detections = List<dynamic>.from(responseData['detections']);
      } else if (responseData.containsKey('predictions') &&
          responseData['predictions'] != null) {
        detections = List<dynamic>.from(responseData['predictions']);
      }

      print('Found ${detections.length} detections');

      List<DetectedObject> newObjects = [];

      for (var detection in detections) {
        String? className;
        double confidence = 0.0;
        Map<String, dynamic>? bbox;

        // Extract class name
        if (detection['class'] != null) {
          className = detection['class'].toString();
        } else if (detection['name'] != null) {
          className = detection['name'].toString();
        }

        // Extract confidence
        if (detection['confidence'] != null) {
          confidence =
              double.tryParse(detection['confidence'].toString()) ?? 0.0;
        }

        // Extract bounding box
        if (detection['bbox'] != null) {
          bbox = Map<String, dynamic>.from(detection['bbox']);
        } else if (detection['box'] != null) {
          bbox = Map<String, dynamic>.from(detection['box']);
        }

        if (className != null && bbox != null && confidence > 0.3) {
          // Clean up class name
          className = className.replaceAll('_', ' ');
          className = className
              .split(' ')
              .map((word) => word.isNotEmpty
                  ? word[0].toUpperCase() + word.substring(1).toLowerCase()
                  : word)
              .join(' ');

          // Parse bounding box coordinates - server.py uses x1,y1,x2,y2 format
          double x1 = double.tryParse(bbox['x1'].toString()) ?? 0.0;
          double y1 = double.tryParse(bbox['y1'].toString()) ?? 0.0;
          double x2 = double.tryParse(bbox['x2'].toString()) ?? 0.0;
          double y2 = double.tryParse(bbox['y2'].toString()) ?? 0.0;

          // Debug logging for bounding box
          print(
              'Object: $className, Confidence: $confidence, BBox: x1=$x1, y1=$y1, x2=$x2, y2=$y2');

          // Convert to x,y,width,height format
          double x = x1;
          double y = y1;
          double width = x2 - x1;
          double height = y2 - y1;

          // Get image dimensions for normalization
          // Since we're capturing at medium resolution, estimate dimensions
          double imageWidth = 640.0; // Typical camera width
          double imageHeight = 480.0; // Typical camera height

          // Normalize coordinates to 0-1 range
          x = x / imageWidth;
          y = y / imageHeight;
          width = width / imageWidth;
          height = height / imageHeight;

          // Ensure coordinates are within bounds
          x = x.clamp(0.0, 1.0);
          y = y.clamp(0.0, 1.0);
          width = width.clamp(0.01, 1.0 - x); // Minimum width of 1%
          height = height.clamp(0.01, 1.0 - y); // Minimum height of 1%

          print('Normalized: x=$x, y=$y, w=$width, h=$height');

          final rect = Rect.fromLTWH(x, y, width, height);
          print('Normalized rect: $rect');

          newObjects.add(DetectedObject(
            className: className,
            confidence: confidence,
            boundingBox: rect,
            id: '${className}_${DateTime.now().millisecondsSinceEpoch}',
          ));
        }
      }

      if (mounted) {
        setState(() {
          _detectedObjects = newObjects;
          // Add new objects to detected objects list
          for (var obj in newObjects) {
            if (!_detectedObjectsList.contains(obj.className)) {
              _detectedObjectsList.add(obj.className);
            }
          }
        });
      }
    } catch (e) {
      print('Error parsing detections: $e');
    }
  }

  void _onObjectTapped(DetectedObject object) {
    HapticFeedback.lightImpact();

    if (!_selectedObjects.contains(object.className)) {
      setState(() {
        _selectedObjects.add(object.className);
        if (!_detectedObjectsList.contains(object.className)) {
          _detectedObjectsList.add(object.className);
        }
      });

      _showMessage('${object.className} added to list!', isError: false);
    } else {
      _showMessage('${object.className} already in list', isError: true);
    }
  }

  void _addDetectedObjectToList(String objectName) {
    HapticFeedback.lightImpact();

    if (!_selectedObjects.contains(objectName)) {
      setState(() {
        _selectedObjects.add(objectName);
      });
      _showMessage('$objectName added to list!', isError: false);
    } else {
      _showMessage('$objectName already in list', isError: true);
    }
  }

  void _showMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError
            ? Colors.red.withValues(alpha: 0.9)
            : Colors.green.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.albertSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _finishSelection() {
    widget.onObjectsSelected(_selectedObjects);
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _detectionTimer?.cancel();
    _cameraController?.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        final isDarkMode = themeService.isDarkMode;

        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              children: [
                // Camera Preview Area
                _buildCameraPreview(screenSize, isDarkMode),

                // Detection Overlay
                if (_detectedObjects.isNotEmpty)
                  _buildDetectionOverlay(screenSize),

                // Top Controls
                _buildTopControls(isTablet, isDarkMode),

                // Bottom Controls
                _buildBottomControls(isTablet, isDarkMode),

                // Selected Items Counter
                if (_selectedObjects.isNotEmpty)
                  _buildSelectedCounter(isTablet, isDarkMode),

                // Detected Objects List Panel
                if (_showObjectsList)
                  _buildObjectsListPanel(isTablet, isDarkMode),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCameraPreview(Size screenSize, bool isDarkMode) {
    return Container(
      width: screenSize.width,
      height: screenSize.height,
      color: Colors.black,
      child: _isCameraInitialized && _cameraController != null
          ? CameraPreview(_cameraController!)
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Icon(
                          Icons.camera_alt,
                          size: 80,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Initializing Camera...',
                    style: GoogleFonts.albertSans(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDetectionOverlay(Size screenSize) {
    print(
        'Building overlay with ${_detectedObjects.length} objects, screen size: ${screenSize.width}x${screenSize.height}');

    return Stack(
      children: _detectedObjects.map((object) {
        // Convert normalized coordinates to screen coordinates
        final left = object.boundingBox.left * screenSize.width;
        final top = object.boundingBox.top * screenSize.height;
        final width = object.boundingBox.width * screenSize.width;
        final height = object.boundingBox.height * screenSize.height;

        print(
            'Drawing box: left=$left, top=$top, width=$width, height=$height for ${object.className}');

        return Positioned(
          left: left,
          top: top,
          child: GestureDetector(
            onTap: () => _onObjectTapped(object),
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.yellowAccent,
                  width: 3,
                ),
                color: AppColors.yellowAccent.withValues(alpha: 0.2),
              ),
              child: Stack(
                children: [
                  // Label
                  Positioned(
                    top: -30,
                    left: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.yellowAccent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${object.className} (${(object.confidence * 100).toInt()}%)',
                        style: GoogleFonts.albertSans(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  // Tap indicator
                  Center(
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.yellowAccent.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.touch_app,
                        color: Colors.black,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTopControls(bool isTablet, bool isDarkMode) {
    return Positioned(
      top: 20,
      left: 20,
      right: 20,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: isTablet ? 24 : 20,
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 16 : 12,
                    vertical: isTablet ? 12 : 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isDetecting)
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.yellowAccent,
                            ),
                          ),
                        )
                      else
                        Icon(
                          Icons.visibility,
                          color: AppColors.yellowAccent,
                          size: 16,
                        ),
                      const SizedBox(width: 8),
                      Text(
                        _isDetecting ? 'Detecting...' : 'Live Detection',
                        style: GoogleFonts.albertSans(
                          color: Colors.white,
                          fontSize: isTablet ? 14 : 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showObjectsList = !_showObjectsList;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _showObjectsList
                          ? AppColors.yellowAccent
                          : Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.list_alt,
                      color: _showObjectsList ? Colors.black : Colors.white,
                      size: isTablet ? 20 : 18,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls(bool isTablet, bool isDarkMode) {
    return Positioned(
      bottom: 40,
      left: 20,
      right: 20,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Instructions
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isTablet ? 16 : 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Point camera at objects. Tap on detected items or use the list to add them.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.albertSans(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: isTablet ? 14 : 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_detectedObjectsList.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Detected: ${_detectedObjectsList.length} unique objects',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.albertSans(
                        color: AppColors.yellowAccent,
                        fontSize: isTablet ? 12 : 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Finish Button
            GestureDetector(
              onTap: _selectedObjects.isNotEmpty ? _finishSelection : null,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  vertical: isTablet ? 16 : 14,
                ),
                decoration: BoxDecoration(
                  color: _selectedObjects.isNotEmpty
                      ? AppColors.yellowAccent
                      : Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Add ${_selectedObjects.length} Items to List',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 16 : 14,
                        fontWeight: FontWeight.bold,
                        color: _selectedObjects.isNotEmpty
                            ? Colors.black
                            : Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.check,
                      color: _selectedObjects.isNotEmpty
                          ? Colors.black
                          : Colors.white.withValues(alpha: 0.5),
                      size: isTablet ? 20 : 18,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedCounter(bool isTablet, bool isDarkMode) {
    return Positioned(
      top: 100,
      right: 20,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 12 : 10,
            vertical: isTablet ? 8 : 6,
          ),
          decoration: BoxDecoration(
            color: AppColors.yellowAccent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.yellowAccent.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle,
                color: Colors.black,
                size: isTablet ? 16 : 14,
              ),
              const SizedBox(width: 6),
              Text(
                '${_selectedObjects.length} selected',
                style: GoogleFonts.albertSans(
                  color: Colors.black,
                  fontSize: isTablet ? 12 : 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildObjectsListPanel(bool isTablet, bool isDarkMode) {
    return Positioned(
      top: 80,
      left: 20,
      bottom: 200,
      width: 200,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.yellowAccent.withValues(alpha: 0.2),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Text(
                  'Detected Objects',
                  style: GoogleFonts.albertSans(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              // Objects List
              Expanded(
                child: _detectedObjectsList.isEmpty
                    ? Center(
                        child: Text(
                          'No objects detected yet',
                          style: GoogleFonts.albertSans(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _detectedObjectsList.length,
                        itemBuilder: (context, index) {
                          final objectName = _detectedObjectsList[index];
                          final isSelected =
                              _selectedObjects.contains(objectName);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: GestureDetector(
                              onTap: () => _addDetectedObjectToList(objectName),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.yellowAccent
                                          .withValues(alpha: 0.3)
                                      : Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.yellowAccent
                                        : Colors.white.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isSelected
                                          ? Icons.check_circle
                                          : Icons.add_circle_outline,
                                      color: isSelected
                                          ? AppColors.yellowAccent
                                          : Colors.white.withValues(alpha: 0.7),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        objectName,
                                        style: GoogleFonts.albertSans(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
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
    );
  }
}
