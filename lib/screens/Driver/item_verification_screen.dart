import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shiffters/services/theme_service.dart';
import 'package:shiffters/theme/app_colors.dart';
import '../../services/email_service.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ItemVerificationScreen extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> orderData;

  const ItemVerificationScreen({
    super.key,
    required this.orderId,
    required this.orderData,
  });

  @override
  State<ItemVerificationScreen> createState() => _ItemVerificationScreenState();
}

class _ItemVerificationScreenState extends State<ItemVerificationScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;

  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isDetecting = false;
  bool _isVerifying = false;
  bool _showObjectsList = true;
  bool _showExpectedItemsList = true;

  List<String> _expectedItems = [];
  List<String> _detectedObjectsList = []; // List of all detected objects
  List<String> _selectedObjects = []; // User selected objects
  List<String> _verifiedItems = [];
  List<String> _missingItems = [];

  Timer? _detectionTimer;

  // YOLO API Configuration
  static const String _yoloApiBaseUrl =
      'https://trickily-photoactinic-alita.ngrok-free.dev';
  static const String _yoloApiEndpoint = '/yolo/detect';

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
    _extractExpectedItems();
    _initializeCamera();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  void _startAnimations() {
    _animationController.forward();
    _pulseController.repeat(reverse: true);
  }

  void _extractExpectedItems() async {
    print('\n═══════════════════════════════════════════════════════');
    print('🔍 [Verification] STARTING ITEM EXTRACTION');
    print('═══════════════════════════════════════════════════════');

    // ALWAYS fetch fresh data from Firebase to ensure accuracy
    print('📦 [Verification] Order ID: ${widget.orderId}');
    print('📥 [Verification] Fetching FRESH data from Firebase...');

    var items;

    try {
      final orderDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .get();

      if (orderDoc.exists) {
        final freshOrderData = orderDoc.data() as Map<String, dynamic>;
        print('✅ [Verification] Fresh order data fetched from Firebase');
        print(
            '📦 [Verification] Firebase orderData keys: ${freshOrderData.keys.toList()}');
        items = freshOrderData['items'];
        print('📦 [Verification] Items from Firebase: $items');
        print(
            '📦 [Verification] Items type from Firebase: ${items.runtimeType}');
      } else {
        print('❌ [Verification] Order document not found in Firebase!');
        _showMessage('Order not found in database', isError: true);
        return;
      }
    } catch (e) {
      print('❌ [Verification] Error fetching from Firebase: $e');
      _showMessage('Failed to load order data: $e', isError: true);
      return;
    }

    // Validate we have items data
    if (items == null) {
      print('❌ [Verification] No items field in Firebase order!');
      _showMessage('No items found in order', isError: true);
      setState(() {
        _expectedItems = [];
      });
      return;
    }

    List<String> rawItems = [];

    if (items is Map) {
      // Handle Firebase Map structure like {"0": "Tv", "1": "Keyboard", "2": "Mouse"}
      print('\n🗂️ [Verification] Processing Map with ${items.length} entries');
      print('🗂️ [Verification] Map keys: ${items.keys.toList()}');
      print('🗂️ [Verification] Map values: ${items.values.toList()}');

      rawItems = items.values.map((item) {
        final trimmed = item.toString().trim();
        print('   - Processing map value: "$item" -> "$trimmed"');
        return trimmed;
      }).where((item) {
        final isNotEmpty = item.isNotEmpty;
        print('   - Checking if empty: "$item" -> keep: $isNotEmpty');
        return isNotEmpty;
      }).toList();
      print('✅ [Verification] Map values extracted: $rawItems');
    } else if (items is List) {
      print('\n📋 [Verification] Processing List with ${items.length} entries');
      rawItems = items.map((item) {
        final trimmed = item.toString().trim();
        print('   - Processing list item: "$item" -> "$trimmed"');
        return trimmed;
      }).where((item) {
        final isNotEmpty = item.isNotEmpty;
        print('   - Checking if empty: "$item" -> keep: $isNotEmpty');
        return isNotEmpty;
      }).toList();
      print('✅ [Verification] List items extracted: $rawItems');
    } else if (items is String) {
      print('\n📝 [Verification] Processing String: "$items"');
      // Parse items string (format: "• Item 1\n• Item 2")
      rawItems = items
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .map((line) => line.replaceAll('•', '').trim())
          .where((item) => item.isNotEmpty)
          .toList();
      print('✅ [Verification] String items parsed: $rawItems');
    } else {
      print('\n❓ [Verification] Unknown items type: ${items.runtimeType}');
      // Try to convert to string and process
      if (items != null) {
        rawItems =
            [items.toString().trim()].where((item) => item.isNotEmpty).toList();
        print('✅ [Verification] Converted to string: $rawItems');
      }
    }

    print('\n📊 [Verification] Raw items BEFORE normalization: $rawItems');
    print('📊 [Verification] Raw items count: ${rawItems.length}');

    // Normalize items to match detection classes
    _expectedItems = rawItems.where((item) => item.isNotEmpty).map((item) {
      final normalized = _normalizeItemName(item);
      print('   🔄 Normalizing: "$item" -> "$normalized"');
      return normalized;
    }).toList();

    print('\n✅ [Verification] FINAL Expected items: $_expectedItems');
    print(
        '✅ [Verification] FINAL Expected items count: ${_expectedItems.length}');
    print('═══════════════════════════════════════════════════════\n');

    // Force UI update
    if (mounted) {
      setState(() {});
    }
  }

  String _normalizeItemName(String item) {
    print('🔍 [_normalizeItemName] Input item: "$item"');

    // First, preserve the original if it's already properly formatted
    String trimmedItem = item.trim();

    // Clean up item name (same as live detection screen)
    String cleanedItem = trimmedItem.replaceAll('_', ' ');
    cleanedItem = cleanedItem
        .split(' ')
        .map((word) => word.isNotEmpty
            ? word[0].toUpperCase() + word.substring(1).toLowerCase()
            : word)
        .join(' ');

    print('🔍 [_normalizeItemName] After cleaning: "$cleanedItem"');

    // Map common variations to standard names (with proper capitalization)
    final normalized = cleanedItem.toLowerCase();

    String result;
    if (normalized.contains('sofa') || normalized.contains('couch'))
      result = 'Sofa';
    else if (normalized.contains('table'))
      result = 'Table';
    else if (normalized.contains('chair'))
      result = 'Chair';
    else if (normalized.contains('bed'))
      result = 'Bed';
    else if (normalized.contains('tv') || normalized.contains('television'))
      result = 'Tv';
    else if (normalized.contains('refrigerator') ||
        normalized.contains('fridge'))
      result = 'Refrigerator';
    else if (normalized.contains('washing machine') ||
        normalized.contains('washer'))
      result = 'Washing Machine';
    else if (normalized.contains('microwave'))
      result = 'Microwave';
    else if (normalized.contains('laptop') || normalized.contains('computer'))
      result = 'Laptop';
    else if (normalized.contains('phone') || normalized.contains('mobile'))
      result = 'Phone';
    else if (normalized.contains('book'))
      result = 'Book';
    else if (normalized.contains('bag') || normalized.contains('suitcase'))
      result = 'Suitcase';
    else if (normalized.contains('box') || normalized.contains('carton'))
      result = 'Box';
    else if (normalized.contains('keyboard'))
      result = 'Keyboard';
    else if (normalized.contains('mouse'))
      result = 'Mouse';
    else
      result = cleanedItem;

    print('🔍 [_normalizeItemName] Final result: "$result"');
    return result;
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
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
          // Start continuous detection like in live detection screen
          _startContinuousDetection();
        }
      }
    } catch (e) {
      debugPrint('Camera initialization error: $e');
      _showMessage('Camera initialization failed: $e', isError: true);
    }
  }

  void _startContinuousDetection() {
    _detectionTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
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
      final XFile image = await _cameraController!.takePicture();
      await _detectObjectsInImage(image);
    } catch (e) {
      print('Error in continuous detection: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isDetecting = false;
        });
      }
    }
  }

  void _addDetectedObjectToList(String objectName) {
    setState(() {
      if (_selectedObjects.contains(objectName)) {
        _selectedObjects.remove(objectName);
      } else {
        _selectedObjects.add(objectName);
      }
    });
    HapticFeedback.lightImpact();
  }

  void _toggleObjectsList() {
    setState(() {
      _showObjectsList = !_showObjectsList;
    });
  }

  void _toggleExpectedItemsList() {
    setState(() {
      _showExpectedItemsList = !_showExpectedItemsList;
    });
  }

  Future<void> _detectObjectsInImage(XFile imageFile) async {
    try {
      print('Starting YOLO object detection for verification...');

      // Read and process image
      final File file = File(imageFile.path);
      final List<int> imageBytes = await file.readAsBytes();

      // Encode to base64
      final String base64Image = base64Encode(imageBytes);

      print('Sending verification request to YOLO API...');

      // Call YOLO API
      final response = await http
          .post(
            Uri.parse('$_yoloApiBaseUrl$_yoloApiEndpoint'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'ngrok-skip-browser-warning': 'true',
              'User-Agent': 'Flutter-Driver-App/1.0',
            },
            body: jsonEncode({
              'image_base64': base64Image,
              'confidence': 0.4, // Higher confidence for verification
              'iou_threshold': 0.5,
            }),
          )
          .timeout(const Duration(seconds: 20));

      print('YOLO API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        print('Successful YOLO API response received');
        await _parseYOLODetections(responseData);
      } else {
        print('YOLO API Error ${response.statusCode}: ${response.body}');
        _showMessage('Detection API error: ${response.statusCode}',
            isError: true);
        setState(() => _isDetecting = false);
      }
    } catch (e) {
      print('Error detecting objects with YOLO: $e');
      if (e.toString().contains('TimeoutException')) {
        _showMessage('Detection timeout - check network', isError: true);
      } else if (e.toString().contains('SocketException')) {
        _showMessage('Cannot connect to YOLO server', isError: true);
      } else {
        _showMessage('YOLO detection failed: ${e.toString()}', isError: true);
      }
      setState(() => _isDetecting = false);
    }
  }

  Future<void> _parseYOLODetections(Map<String, dynamic> responseData) async {
    try {
      print('YOLO API Response for verification: ${responseData.toString()}');

      List<dynamic> detections = [];

      if (responseData.containsKey('detections') &&
          responseData['detections'] != null) {
        detections = List<dynamic>.from(responseData['detections']);
      } else if (responseData.containsKey('predictions') &&
          responseData['predictions'] != null) {
        detections = List<dynamic>.from(responseData['predictions']);
      }

      print('YOLO found ${detections.length} detections for verification');

      setState(() {
        // Parse YOLO detections and add to detected objects list
        for (var detection in detections) {
          try {
            String className = '';
            double confidence = 0.0;

            if (detection.containsKey('class') &&
                detection.containsKey('confidence')) {
              className = detection['class'].toString().toLowerCase();
              confidence = (detection['confidence'] as num).toDouble();
            } else if (detection.containsKey('name') &&
                detection.containsKey('confidence')) {
              className = detection['name'].toString().toLowerCase();
              confidence = (detection['confidence'] as num).toDouble();
            }

            // Only add objects with reasonable confidence
            if (className.isNotEmpty && confidence >= 0.4) {
              // Normalize common object names for verification
              final normalizedClass = _normalizeObjectName(className);
              if (!_detectedObjectsList.contains(normalizedClass)) {
                _detectedObjectsList.add(normalizedClass);
                print(
                    'YOLO detected for verification: $normalizedClass (confidence: ${(confidence * 100).toStringAsFixed(1)}%)');
              }
            }
          } catch (e) {
            print('Error parsing YOLO detection: $e');
          }
        }
        _isDetecting = false;
      });
    } catch (e) {
      print('Error parsing YOLO detections: $e');
      _showMessage('Failed to process detection results', isError: true);
      setState(() => _isDetecting = false);
    }
  }

  String _normalizeObjectName(String className) {
    print('🔍 [_normalizeObjectName] Input className: "$className"');

    // Clean up class name (same as live detection screen)
    String cleanedName = className.replaceAll('_', ' ');
    cleanedName = cleanedName
        .split(' ')
        .map((word) => word.isNotEmpty
            ? word[0].toUpperCase() + word.substring(1).toLowerCase()
            : word)
        .join(' ');

    print('🔍 [_normalizeObjectName] After cleaning: "$cleanedName"');

    // Map common variations to standard names (with proper capitalization)
    final normalized = cleanedName.toLowerCase();

    String result;
    if (normalized.contains('sofa') || normalized.contains('couch'))
      result = 'Sofa';
    else if (normalized.contains('table') || normalized == 'diningtable')
      result = 'Table';
    else if (normalized.contains('chair'))
      result = 'Chair';
    else if (normalized.contains('bed'))
      result = 'Bed';
    else if (normalized.contains('tv') ||
        normalized.contains('television') ||
        normalized == 'tvmonitor')
      result = 'Tv';
    else if (normalized.contains('refrigerator') ||
        normalized.contains('fridge'))
      result = 'Refrigerator';
    else if (normalized.contains('washing machine') ||
        normalized.contains('washer'))
      result = 'Washing Machine';
    else if (normalized.contains('microwave'))
      result = 'Microwave';
    else if (normalized.contains('laptop') || normalized.contains('computer'))
      result = 'Laptop';
    else if (normalized.contains('phone') ||
        normalized.contains('mobile') ||
        normalized == 'cell phone')
      result = 'Phone';
    else if (normalized.contains('book'))
      result = 'Book';
    else if (normalized.contains('bag') || normalized.contains('suitcase'))
      result = 'Suitcase';
    else if (normalized.contains('box') || normalized.contains('carton'))
      result = 'Box';
    else if (normalized.contains('bottle'))
      result = 'Bottle';
    else if (normalized.contains('cup'))
      result = 'Cup';
    else if (normalized.contains('bowl'))
      result = 'Bowl';
    else if (normalized.contains('keyboard'))
      result = 'Keyboard';
    else if (normalized.contains('mouse'))
      result = 'Mouse';
    else
      result = cleanedName;

    print('🔍 [_normalizeObjectName] Final result: "$result"');
    return result;
  }

  void _performVerification() {
    print('🔍 [Verification] Starting verification...');
    print('🔍 [Verification] Expected items: $_expectedItems');
    print('🔍 [Verification] Selected objects: $_selectedObjects');

    // Check if driver selected any items
    if (_selectedObjects.isEmpty) {
      _showMessage('Please select at least one item to verify', isError: true);
      return;
    }

    // Validate that selected items match expected items from Firebase
    List<String> verifiedItems = [];
    List<String> missingItems = [];
    List<String> extraItems = [];

    // Check each expected item against selected items (case-insensitive)
    for (String expectedItem in _expectedItems) {
      print('🔍 [Verification] Checking expected item: "$expectedItem"');
      bool found = _selectedObjects.any((selected) {
        bool matches = selected.toLowerCase() == expectedItem.toLowerCase();
        print(
            '🔍 [Verification] Comparing "$selected" (lower: "${selected.toLowerCase()}") with "$expectedItem" (lower: "${expectedItem.toLowerCase()}") = $matches');
        return matches;
      });
      if (found) {
        verifiedItems.add(expectedItem);
        print('✅ [Verification] Found match for: "$expectedItem"');
      } else {
        missingItems.add(expectedItem);
        print('❌ [Verification] No match found for: "$expectedItem"');
      }
    }

    // Check for extra items not in expected list (case-insensitive)
    for (String selectedItem in _selectedObjects) {
      bool isExpected = _expectedItems.any(
          (expected) => expected.toLowerCase() == selectedItem.toLowerCase());
      if (!isExpected) {
        extraItems.add(selectedItem);
        print(
            '➕ [Verification] Extra item not in expected list: "$selectedItem"');
      }
    }

    print('🔍 [Verification] Verified items: $verifiedItems');
    print('🔍 [Verification] Missing items: $missingItems');
    print('🔍 [Verification] Extra items: $extraItems');

    // Update state variables for completion
    setState(() {
      _verifiedItems = verifiedItems;
      _missingItems = missingItems;
    });

    // Show verification summary to driver
    _showVerificationSummary(verifiedItems, missingItems, extraItems);
  }

  void _showVerificationSummary(
      List<String> verified, List<String> missing, List<String> extra) {
    String message = '';
    bool canComplete = true;

    if (verified.isEmpty) {
      message =
          'No expected items were found in your selection. Please select the correct items.';
      canComplete = false;
    } else if (missing.isNotEmpty) {
      message = 'Missing items: ${missing.join(', ')}. ';
      if (verified.isNotEmpty) {
        message += 'Found: ${verified.join(', ')}. ';
      }
      message += 'Continue anyway?';
    } else {
      message = 'All expected items verified successfully! ';
      if (extra.isNotEmpty) {
        message += 'Additional items detected: ${extra.join(', ')}.';
      }
    }

    if (!canComplete) {
      _showMessage(message, isError: true);
      return;
    }

    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.black.withValues(alpha: 0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
          ),
          title: Text(
            'Verification Summary',
            style: GoogleFonts.albertSans(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: GoogleFonts.albertSans(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              if (verified.isNotEmpty) ...[
                Text(
                  '✅ Verified (${verified.length}):',
                  style: GoogleFonts.albertSans(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  verified.join(', '),
                  style: GoogleFonts.albertSans(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (missing.isNotEmpty) ...[
                Text(
                  '❌ Missing (${missing.length}):',
                  style: GoogleFonts.albertSans(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  missing.join(', '),
                  style: GoogleFonts.albertSans(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (extra.isNotEmpty) ...[
                Text(
                  '➕ Additional (${extra.length}):',
                  style: GoogleFonts.albertSans(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  extra.join(', '),
                  style: GoogleFonts.albertSans(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.albertSans(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _completeVerification();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.yellowAccent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Complete Verification',
                style: GoogleFonts.albertSans(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _completeVerification() async {
    setState(() {
      _isVerifying = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showMessage('User not authenticated', isError: true);
        return;
      }

      print('🔍 Completing verification...');
      print('📋 Expected items: $_expectedItems');
      print('📷 Selected items: $_selectedObjects');
      print('✅ Verified items: $_verifiedItems');
      print('❌ Missing items: $_missingItems');

      // Calculate verification metrics
      final verificationScore = _expectedItems.isEmpty
          ? 100.0
          : (_verifiedItems.length / _expectedItems.length) * 100;

      final isFullyVerified =
          _missingItems.isEmpty && _verifiedItems.isNotEmpty;

      // Determine correct verification status for email
      final verificationStatus = isFullyVerified
          ? 'all_items_verified' // All items delivered successfully
          : 'partially_verified'; // Some items missing

      // Prepare comprehensive verification data
      final verificationData = {
        'order_id': widget.orderId,
        'service_type': 'Item Verification',
        'verification_status': verificationStatus,
        'verification_score': verificationScore,
        'total_expected': _expectedItems.length,
        'total_verified': _verifiedItems.length,
        'total_missing': _missingItems.length,
        'selected_items': _selectedObjects.join(', '),
        'expected_items': _expectedItems.join(', '),
        'verified_items': _verifiedItems.join(', '),
        'missing_items': _missingItems.join(', '),
        'verification_date': DateTime.now().toIso8601String(),
        'verified_by_driver': true,
        'driver_id': user.uid,
        'is_fully_verified': isFullyVerified,
      };

      // Only complete order if ALL items are verified
      if (isFullyVerified) {
        // All items verified - complete the order
        await FirebaseFirestore.instance
            .collection('orders')
            .doc(widget.orderId)
            .update({
          'verification_completed': true,
          'verification_results': verificationData,
          'status': 'completed', // Update order status to completed
          'updatedAt': FieldValue.serverTimestamp(),
        });

        print('✅ Order completed - all items verified');

        // Try to send email (optional - don't fail if this doesn't work)
        try {
          await _attemptEmailNotification(verificationData);
        } catch (emailError) {
          print(
              '⚠️ Email notification failed (continuing anyway): $emailError');
          // Don't show error to user - email is optional
        }

        // Show success message and return with success
        _showMessage('All items verified! Order completed successfully.',
            isError: false);

        // Wait briefly to show message
        await Future.delayed(const Duration(seconds: 1));

        // Return success to navigate away
        Navigator.pop(context, true);
      } else {
        // Some items missing - save verification but don't complete order
        await FirebaseFirestore.instance
            .collection('orders')
            .doc(widget.orderId)
            .update({
          'verification_results': verificationData,
          'verification_attempts': FieldValue.arrayUnion([verificationData]),
          'status': 'delivered', // Keep status as delivered, not completed
          'updatedAt': FieldValue.serverTimestamp(),
        });

        print(
            '⚠️ Verification incomplete - ${_missingItems.length} items missing');

        // Send email notification about missing items
        try {
          await _attemptEmailNotification(verificationData);
          print('📧 Email sent to customer about missing items');
        } catch (emailError) {
          print(
              '⚠️ Email notification failed (continuing anyway): $emailError');
          // Don't show error to user - email is optional
        }

        // Show message about missing items
        _showMessage(
          'Missing items: ${_missingItems.join(', ')}. Please scan again to verify all items.',
          isError: true,
        );

        // Return false to stay on verification screen
        Navigator.pop(context, false);
      }
    } catch (e) {
      print('❌ Verification completion failed: $e');
      _showMessage('Failed to complete verification: $e', isError: true);
    } finally {
      setState(() {
        _isVerifying = false;
      });
    }
  }

  Future<void> _attemptEmailNotification(
      Map<String, dynamic> verificationData) async {
    try {
      // Get customer details for email
      String? customerUid = widget.orderData['uid']?.toString();

      if (customerUid == null || customerUid.isEmpty) {
        final orderDoc = await FirebaseFirestore.instance
            .collection('orders')
            .doc(widget.orderId)
            .get();

        if (orderDoc.exists) {
          final orderData = orderDoc.data() as Map<String, dynamic>;
          customerUid = orderData['uid']?.toString();
        }
      }

      if (customerUid == null || customerUid.isEmpty) {
        print('📧 No customer UID found - skipping email notification');
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(customerUid)
          .get();

      if (!userDoc.exists) {
        print('📧 Customer document not found - skipping email notification');
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final customerEmail = userData['email']?.toString() ?? '';
      final customerName = userData['displayName']?.toString() ??
          userData['name']?.toString() ??
          'Valued Customer';

      if (customerEmail.isEmpty) {
        print('📧 Customer email not available - skipping email notification');
        return;
      }

      print('📧 Attempting to send email notification...');

      final result = await EmailService.sendItemVerificationEmail(
        userEmail: customerEmail,
        userName: customerName,
        verificationData: verificationData,
      );

      if (result['success'] == true) {
        print('✅ Email notification sent successfully');
      } else {
        print(
            '⚠️ Email notification failed: ${result['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      print('⚠️ Email notification error: $e');
      // Don't rethrow - email failure shouldn't stop verification completion
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.albertSans(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    _cameraController?.dispose();
    _detectionTimer?.cancel();
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
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Verify Items',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 22 : 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: Icon(
                  _showExpectedItemsList
                      ? Icons.list_alt
                      : Icons.list_alt_outlined,
                  color: _showExpectedItemsList ? Colors.green : Colors.white,
                ),
                onPressed: _toggleExpectedItemsList,
                tooltip: 'Toggle Expected Items',
              ),
              IconButton(
                icon: Icon(
                  _showObjectsList ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white,
                ),
                onPressed: _toggleObjectsList,
                tooltip: 'Toggle Detected Objects',
              ),
            ],
          ),
          body: Stack(
            children: [
              // Camera Preview (Full Screen)
              if (_isCameraInitialized)
                Positioned.fill(
                  child: CameraPreview(_cameraController!),
                ),

              // Subtle gradient overlay for better UI visibility
              if (_isCameraInitialized)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.3),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.4),
                        ],
                        stops: const [0.0, 0.2, 0.8, 1.0],
                      ),
                    ),
                  ),
                ),

              // Loading overlay
              if (!_isCameraInitialized)
                Positioned.fill(
                  child: Container(
                    color: Colors.black,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(color: Colors.white),
                          const SizedBox(height: 16),
                          Text(
                            'Initializing Camera...',
                            style: GoogleFonts.albertSans(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Detection indicator
              if (_isDetecting)
                Positioned(
                  top: 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Scanning objects...',
                            style: GoogleFonts.albertSans(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Objects List Panel (like in live detection)
              if (_showObjectsList)
                _buildObjectsListPanel(isTablet, isDarkMode),

              // Expected Items Panel
              if (_showExpectedItemsList)
                _buildExpectedItemsPanel(isTablet, isDarkMode),

              // Selected Counter
              if (_selectedObjects.isNotEmpty)
                _buildSelectedCounter(isTablet, isDarkMode),

              // Bottom Controls
              _buildBottomControls(isTablet, isDarkMode),
            ],
          ),
        );
      },
    );
  }

  Widget _buildObjectsListPanel(bool isTablet, bool isDarkMode) {
    return Positioned(
      top: 80,
      right: 15,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          width: _showObjectsList ? 220 : 50,
          height: _showObjectsList ? 300 : 50,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _showObjectsList
              ? Column(
                  children: [
                    // Header with collapse button
                    GestureDetector(
                      onTap: _toggleObjectsList,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.yellowAccent.withValues(alpha: 0.2),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Detected Objects',
                                style: GoogleFonts.albertSans(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Icon(
                              Icons.keyboard_arrow_up,
                              color: Colors.white,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Objects List
                    Expanded(
                      child: _detectedObjectsList.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.search,
                                      color:
                                          Colors.white.withValues(alpha: 0.4),
                                      size: 24,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Scanning for objects...',
                                      style: GoogleFonts.albertSans(
                                        color:
                                            Colors.white.withValues(alpha: 0.6),
                                        fontSize: 11,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Column(
                              children: [
                                // Count indicator
                                Container(
                                  width: double.infinity,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    '${_detectedObjectsList.length} objects found',
                                    style: GoogleFonts.albertSans(
                                      color: AppColors.yellowAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                // List
                                Expanded(
                                  child: ListView.builder(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                    itemCount: _detectedObjectsList.length,
                                    itemBuilder: (context, index) {
                                      final objectName =
                                          _detectedObjectsList[index];
                                      final isSelected =
                                          _selectedObjects.contains(objectName);
                                      final isExpected = _expectedItems.any(
                                          (expected) =>
                                              expected.toLowerCase() ==
                                              objectName.toLowerCase());

                                      return Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 6),
                                        child: GestureDetector(
                                          onTap: () => _addDetectedObjectToList(
                                              objectName),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? AppColors.yellowAccent
                                                  : isExpected
                                                      ? Colors.green.withValues(
                                                          alpha: 0.2)
                                                      : Colors.white.withValues(
                                                          alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: isSelected
                                                    ? AppColors.yellowAccent
                                                    : isExpected
                                                        ? Colors.green
                                                        : Colors.white
                                                            .withValues(
                                                                alpha: 0.3),
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  isSelected
                                                      ? Icons.check_circle
                                                      : isExpected
                                                          ? Icons.star
                                                          : Icons
                                                              .radio_button_unchecked,
                                                  color: isSelected
                                                      ? Colors.black
                                                      : isExpected
                                                          ? Colors.green
                                                          : Colors.white
                                                              .withValues(
                                                                  alpha: 0.7),
                                                  size: 14,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          objectName,
                                                          style: GoogleFonts
                                                              .albertSans(
                                                            color: isSelected
                                                                ? Colors.black
                                                                : Colors.white,
                                                            fontSize: 10,
                                                            fontWeight:
                                                                isSelected
                                                                    ? FontWeight
                                                                        .bold
                                                                    : FontWeight
                                                                        .normal,
                                                          ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                      if (isExpected)
                                                        Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal: 4,
                                                                  vertical: 1),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Colors.green,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        6),
                                                          ),
                                                          child: Text(
                                                            'EXPECTED',
                                                            style: GoogleFonts
                                                                .albertSans(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 6,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                        ),
                                                    ],
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
                  ],
                )
              :
              // Collapsed state - just the expand button
              GestureDetector(
                  onTap: _toggleObjectsList,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.yellowAccent.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.yellowAccent.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.black,
                          size: 16,
                        ),
                        if (_detectedObjectsList.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${_detectedObjectsList.length}',
                              style: GoogleFonts.albertSans(
                                color: Colors.black,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildSelectedCounter(bool isTablet, bool isDarkMode) {
    return Positioned(
      top: 390,
      right: 15,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 12 : 10,
            vertical: isTablet ? 8 : 6,
          ),
          decoration: BoxDecoration(
            color: AppColors.yellowAccent,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: AppColors.yellowAccent.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
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

  Widget _buildExpectedItemsPanel(bool isTablet, bool isDarkMode) {
    return Positioned(
      top: 80,
      left: 15,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          width: _showExpectedItemsList ? 210 : 50,
          height: _showExpectedItemsList ? 280 : 50,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.green.withValues(alpha: 0.6),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _showExpectedItemsList
              ? Column(
                  children: [
                    // Header with collapse button
                    GestureDetector(
                      onTap: _toggleExpectedItemsList,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.2),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Expected Items',
                                style: GoogleFonts.albertSans(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Icon(
                              Icons.keyboard_arrow_up,
                              color: Colors.white,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Expected Items List
                    Expanded(
                      child: _expectedItems.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.list_alt,
                                      color:
                                          Colors.white.withValues(alpha: 0.4),
                                      size: 24,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'No expected items found',
                                      style: GoogleFonts.albertSans(
                                        color:
                                            Colors.white.withValues(alpha: 0.6),
                                        fontSize: 11,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Column(
                              children: [
                                // Count indicator
                                Container(
                                  width: double.infinity,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    '${_expectedItems.length} items expected',
                                    style: GoogleFonts.albertSans(
                                      color: Colors.green,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                // List
                                Expanded(
                                  child: ListView.builder(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                    itemCount: _expectedItems.length,
                                    itemBuilder: (context, index) {
                                      final expectedItem =
                                          _expectedItems[index];
                                      final isSelected = _selectedObjects.any(
                                          (selected) =>
                                              selected.toLowerCase() ==
                                              expectedItem.toLowerCase());

                                      return Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? Colors.green
                                                    .withValues(alpha: 0.8)
                                                : Colors.white
                                                    .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: isSelected
                                                  ? Colors.green
                                                  : Colors.green
                                                      .withValues(alpha: 0.3),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                isSelected
                                                    ? Icons.check_circle
                                                    : Icons
                                                        .radio_button_unchecked,
                                                color: isSelected
                                                    ? Colors.white
                                                    : Colors.green
                                                        .withValues(alpha: 0.7),
                                                size: 14,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  expectedItem,
                                                  style: GoogleFonts.albertSans(
                                                    color: isSelected
                                                        ? Colors.white
                                                        : Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: isSelected
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                )
              :
              // Collapsed state - just the expand button
              GestureDetector(
                  onTap: _toggleExpectedItemsList,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.white,
                          size: 16,
                        ),
                        if (_expectedItems.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${_expectedItems.length}',
                              style: GoogleFonts.albertSans(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildBottomControls(bool isTablet, bool isDarkMode) {
    return Positioned(
      bottom: 30,
      left: 15,
      right: 15,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Instructions
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isTablet ? 18 : 14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.4),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Select ONLY the items from detected objects that match the expected items for this order.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.albertSans(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: isTablet ? 14 : 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_expectedItems.isNotEmpty) ...[
                    Text(
                      'Expected items (${_expectedItems.length}): ${_expectedItems.join(', ')}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.albertSans(
                        color: Colors.green,
                        fontSize: isTablet ? 12 : 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (_detectedObjectsList.isNotEmpty) ...[
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

            // Complete Verification Button
            GestureDetector(
              onTap: (_selectedObjects.isNotEmpty && !_isVerifying)
                  ? _performVerification
                  : null,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  vertical: isTablet ? 16 : 14,
                ),
                decoration: BoxDecoration(
                  color: _selectedObjects.isNotEmpty && !_isVerifying
                      ? AppColors.yellowAccent
                      : Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: _selectedObjects.isNotEmpty && !_isVerifying
                      ? [
                          BoxShadow(
                            color:
                                AppColors.yellowAccent.withValues(alpha: 0.4),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isVerifying)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.black),
                        ),
                      )
                    else ...[
                      Text(
                        _selectedObjects.isEmpty
                            ? 'Select Items to Complete'
                            : 'Complete Verification (${_selectedObjects.length} items)',
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
                        Icons.check_circle,
                        color: _selectedObjects.isNotEmpty
                            ? Colors.black
                            : Colors.white.withValues(alpha: 0.5),
                        size: isTablet ? 20 : 18,
                      ),
                    ]
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
