import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shiffters/theme/app_colors.dart';
import 'package:shiffters/services/theme_service.dart';
import 'dart:async';
import 'dart:math' as math;

// Firebase imports
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Google Maps imports
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart';

// Add geolocator for real location
import 'package:geolocator/geolocator.dart';

// Using Google Maps LatLng from google_maps_flutter package

// Mock order model - now will be populated from Firebase
class OrderModel {
  final String id;
  String customerName; // Changed from final to allow updates
  final String pickupAddress;
  final String dropoffAddress;
  final LatLng pickupLocation;
  final LatLng dropoffLocation;
  final double distance;
  final double estimatedEarnings;
  final String packageType;
  final DateTime createdAt;
  final String status;
  final String serviceType; // 'pickup-drop' or 'shifting'
  final Map<String, dynamic> rawData; // Store original Firebase data

  OrderModel({
    required this.id,
    required this.customerName,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.distance,
    required this.estimatedEarnings,
    required this.packageType,
    required this.createdAt,
    this.status = 'pending',
    this.serviceType = 'pickup-drop',
    this.rawData = const {},
  });

  // Method to update customer name after fetching from users collection
  void updateCustomerName(String newName) {
    customerName = newName;
  }

  // Factory constructor to create OrderModel from Firebase document
  // Static helper method for distance calculation
  static double _calculateDistanceBetweenPoints(
      double lat1, double lng1, double lat2, double lng2) {
    // Haversine formula for calculating distance between two points
    const double earthRadius = 6371; // Earth's radius in kilometers

    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLng = _degreesToRadians(lng2 - lng1);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Extract pickup location - try different field names
    LatLng pickupLocation = const LatLng(31.5204, 74.3587); // Default Lahore
    if (data['pickupLocation'] != null) {
      final pickup = data['pickupLocation'] as Map<String, dynamic>;
      if (pickup['latitude'] != null && pickup['longitude'] != null) {
        pickupLocation = LatLng(
          (pickup['latitude'] as num).toDouble(),
          (pickup['longitude'] as num).toDouble(),
        );
      }
    } else if (data['pickup'] != null) {
      final pickup = data['pickup'] as Map<String, dynamic>;
      if (pickup['latitude'] != null && pickup['longitude'] != null) {
        pickupLocation = LatLng(
          (pickup['latitude'] as num).toDouble(),
          (pickup['longitude'] as num).toDouble(),
        );
      }
    }

    // Extract dropoff location - try different field names
    LatLng dropoffLocation = const LatLng(31.5497, 74.3436); // Default Lahore
    if (data['dropoffLocation'] != null) {
      final dropoff = data['dropoffLocation'] as Map<String, dynamic>;
      if (dropoff['latitude'] != null && dropoff['longitude'] != null) {
        dropoffLocation = LatLng(
          (dropoff['latitude'] as num).toDouble(),
          (dropoff['longitude'] as num).toDouble(),
        );
      }
    } else if (data['dropoff'] != null) {
      final dropoff = data['dropoff'] as Map<String, dynamic>;
      if (dropoff['latitude'] != null && dropoff['longitude'] != null) {
        dropoffLocation = LatLng(
          (dropoff['latitude'] as num).toDouble(),
          (dropoff['longitude'] as num).toDouble(),
        );
      }
    }

    // Extract customer name - prioritize actual name from various sources
    String customerName = 'Loading...'; // Temporary placeholder
    String? customerUid;

    // Get the customer UID first
    if (data['uid'] != null) {
      customerUid = data['uid'] as String;
    } else if (data['userId'] != null) {
      customerUid = data['userId'] as String;
    }

    // Try to get name from contact information first (immediate data)
    if (data['contactInformation'] != null) {
      final contactInfo = data['contactInformation'] as Map<String, dynamic>;
      if (contactInfo['senderName'] != null &&
          contactInfo['senderName'].toString().isNotEmpty) {
        customerName = contactInfo['senderName'] as String;
      }
    }
    // Try contactDetails structure
    else if (data['contactDetails'] != null) {
      final contactDetails = data['contactDetails'] as Map<String, dynamic>;
      if (contactDetails['sender'] != null) {
        final sender = contactDetails['sender'] as Map<String, dynamic>;
        if (sender['name'] != null && sender['name'].toString().isNotEmpty) {
          customerName = sender['name'] as String;
        }
      }
    }
    // Try other possible name fields in the order document
    else if (data['customerName'] != null &&
        data['customerName'].toString().isNotEmpty) {
      customerName = data['customerName'] as String;
    } else if (data['senderName'] != null &&
        data['senderName'].toString().isNotEmpty) {
      customerName = data['senderName'] as String;
    }
    // Try to get from sender phone (like "0336-5017866")
    else if (data['senderPhone'] != null) {
      customerName = 'Customer ${data['senderPhone']}';
    }
    // If no name found in order data, we'll fetch from users collection
    else if (customerUid != null) {
      customerName = 'Customer ${customerUid.substring(0, 8)}...'; // Temporary
      // Note: We'll fetch the actual name asynchronously after creation
    }

    // Extract package type - try different sources
    String packageType = 'Unknown Package';
    if (data['packageInformation'] != null) {
      final packageInfo = data['packageInformation'] as Map<String, dynamic>;
      packageType = packageInfo['packageType'] as String? ??
          packageInfo['packageName'] as String? ??
          'Package';
    } else if (data['packageDetails'] != null) {
      final packageDetails = data['packageDetails'] as Map<String, dynamic>;
      packageType = packageDetails['type'] as String? ?? 'Package';
    } else if (data['orderType'] != null) {
      String orderType = data['orderType'] as String;
      if (orderType == 'shifting') {
        packageType = 'Shifting Service';
      } else if (orderType == 'pickupdrop') {
        packageType = 'Pickup & Drop';
      }
    }

    // Calculate estimated earnings based on price or distance
    double estimatedEarnings = 300.0; // Default base price
    if (data['totalAmount'] != null) {
      estimatedEarnings = (data['totalAmount'] as num).toDouble();
    } else if (data['price'] != null) {
      estimatedEarnings = (data['price'] as num).toDouble();
    } else if (data['totalPrice'] != null) {
      estimatedEarnings = (data['totalPrice'] as num).toDouble();
    }

    // Extract distance - use existing or calculate from coordinates
    double distance = 0.0;
    if (data['distance'] != null) {
      if (data['distance'] is String) {
        // Parse distance string like "10.3561237795324"
        distance = double.tryParse(data['distance']) ?? 5.0;
      } else {
        distance = (data['distance'] as num).toDouble();
      }
    } else {
      // Calculate distance from coordinates
      distance = _calculateDistanceBetweenPoints(
        pickupLocation.latitude,
        pickupLocation.longitude,
        dropoffLocation.latitude,
        dropoffLocation.longitude,
      );
    }

    // Extract addresses - try different field names
    String pickupAddress = 'Unknown Pickup Location';
    String dropoffAddress = 'Unknown Dropoff Location';

    if (data['pickupLocation'] != null &&
        data['pickupLocation']['address'] != null) {
      pickupAddress = data['pickupLocation']['address'] as String;
    } else if (data['pickup'] != null && data['pickup']['address'] != null) {
      pickupAddress = data['pickup']['address'] as String;
    }

    if (data['dropoffLocation'] != null &&
        data['dropoffLocation']['address'] != null) {
      dropoffAddress = data['dropoffLocation']['address'] as String;
    } else if (data['dropoff'] != null && data['dropoff']['address'] != null) {
      dropoffAddress = data['dropoff']['address'] as String;
    }

    // Determine service type from orderType or other fields
    String serviceType = 'pickup-drop';
    if (data['orderType'] != null) {
      String orderType = data['orderType'] as String;
      if (orderType == 'shifting') {
        serviceType = 'shifting';
      } else if (orderType == 'pickupdrop') {
        serviceType = 'pickup-drop';
      }
    } else if (data['serviceType'] != null) {
      serviceType = data['serviceType'] as String;
    } else if (data['vehicle'] != null || data['additionalDetails'] != null) {
      serviceType = 'shifting';
    }

    // Extract creation date
    DateTime createdAt = DateTime.now();
    if (data['createdAt'] != null) {
      if (data['createdAt'] is Timestamp) {
        createdAt = (data['createdAt'] as Timestamp).toDate();
      } else if (data['createdAt'] is String) {
        createdAt =
            DateTime.tryParse(data['createdAt'] as String) ?? DateTime.now();
      }
    }

    final orderModel = OrderModel(
      id: doc.id,
      customerName: customerName,
      pickupAddress: pickupAddress,
      dropoffAddress: dropoffAddress,
      pickupLocation: pickupLocation,
      dropoffLocation: dropoffLocation,
      distance: distance,
      estimatedEarnings: estimatedEarnings,
      packageType: packageType,
      createdAt: createdAt,
      status: data['status'] as String? ?? 'pending',
      serviceType: serviceType,
      rawData: data,
    );

    // If we need to fetch customer name from users collection, do it asynchronously
    if (customerUid != null &&
        customerName.startsWith('Customer ') &&
        customerName.contains('...')) {
      // We'll store the UID in rawData for later reference
      orderModel.rawData['customerUid'] = customerUid;
    }

    return orderModel;
  }

  // Method to fetch customer name from users collection and update the order
  static Future<String?> fetchCustomerNameFromUsers(String uid) async {
    try {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        String? fetchedName;

        // Try different possible name fields
        if (userData['name'] != null &&
            userData['name'].toString().isNotEmpty) {
          fetchedName = userData['name'] as String;
        } else if (userData['displayName'] != null &&
            userData['displayName'].toString().isNotEmpty) {
          fetchedName = userData['displayName'] as String;
        } else if (userData['firstName'] != null) {
          final firstName = userData['firstName'] as String;
          final lastName = userData['lastName'] as String? ?? '';
          fetchedName = '$firstName $lastName'.trim();
        }

        return fetchedName;
      }
    } catch (e) {
      print('Error fetching customer name for $uid: $e');
    }
    return null;
  }
}

class DriverAcceptOrderScreen extends StatefulWidget {
  const DriverAcceptOrderScreen({super.key});

  @override
  State<DriverAcceptOrderScreen> createState() =>
      _DriverAcceptOrderScreenState();
}

class _DriverAcceptOrderScreenState extends State<DriverAcceptOrderScreen>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _mapAnimationController;
  late AnimationController _orderSheetController;
  late AnimationController _radiusAnimationController;
  late AnimationController _popupController;
  late AnimationController _pulseController;

  // Animations
  late Animation<double> _mapFadeAnimation;
  late Animation<Offset> _popupSlideAnimation;
  late Animation<double> _popupOpacityAnimation;
  // late Animation<double> _pulseAnimation; // Not needed for Google Maps

  // Controllers and state
  final DraggableScrollableController _scrollController =
      DraggableScrollableController();
  GoogleMapController? _mapController;
  Timer? _orderPopupTimer;
  Timer? _searchRadiusTimer;
  Timer? _noOrdersTimer;
  Timer? _orderGenerationTimer;

  // Current location (will be updated with real location)
  LatLng _currentLocation =
      const LatLng(31.5204, 74.3587); // Default: Lahore, Pakistan
  bool _locationPermissionGranted = false;

  // Custom truck icon for driver marker
  BitmapDescriptor? _truckIcon;

  // Orders data
  List<OrderModel> _availableOrders = [];
  OrderModel? _currentPopupOrder;
  OrderModel? _activeOrder; // Track currently active order
  bool _showOrderPopup = false;
  int _popupTimeRemaining = 15;
  Set<String> _seenOrderIds = {}; // Track seen orders to detect new ones

  // Firebase related
  StreamSubscription<QuerySnapshot>? _ordersStreamSubscription;
  bool _isLoadingOrders = false;
  String? _lastError;

  // Map state
  bool _isSearchingOrders = true;
  double _searchRadius = 4.0; // km - default radius
  bool _isOrderSheetExpanded = false;
  DateTime _lastOrderFoundTime = DateTime.now();

  // Available radius options
  final List<double> _radiusOptions = [4.0, 6.0, 9.0, 999.0];

  @override
  void initState() {
    super.initState();
    print("==== DriverAcceptOrderScreen initState ====");

    // Initialize with searching enabled
    _isSearchingOrders = true;
    print("Initial searching state: $_isSearchingOrders");
    // GoogleMapController will be initialized in onMapCreated callback
    print("Map controller will be initialized on map creation");

    _initializeAnimations();
    print("Animations initialized");

    _startAnimations();
    print("Animations started");

    _createTruckIcon();
    print("Truck icon creation initiated");

    _fetchOrdersFromFirebase();
    print("Firebase orders fetch initiated");

    _startOrderSearch();
    print("Order search started");

    _startPeriodicOrderGeneration();
    print("Periodic order generation started");

    _initializeLocation();
    print("Location initialization started");

    _startNoOrdersTimer();
    print("No orders timer started");

    print("==== DriverAcceptOrderScreen initState complete ====");

    // Make sure the app is in the right state after initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        // Ensure animations are running if searching
        if (_isSearchingOrders) {
          _radiusAnimationController.repeat(reverse: true);
        }
      });
      // Check for existing active orders
      _checkForExistingActiveOrder();
      // Setup scroll listener after the widget is built
      _setupScrollListener();

      // Automatically get and center on current location when screen loads
      _getUserLocationAndCenter();
    });
  }

  void _setupScrollListener() {
    // Check if the controller is attached to avoid the error
    if (_scrollController.isAttached) {
      _scrollController.addListener(() {
        final isExpanded = _scrollController.size > 0.5; // Increased threshold
        if (isExpanded != _isOrderSheetExpanded) {
          setState(() {
            _isOrderSheetExpanded = isExpanded;
          });
        }
      });
    } else {
      // If not attached, try again after a brief delay
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && _scrollController.isAttached) {
          _setupScrollListener();
        }
      });
    }
  }

  void _initializeLocation() async {
    await _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      // Check if location services are enabled
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled.');
        _startLocationSimulation();
        return;
      }

      // Request permission
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permissions are denied');
          _startLocationSimulation();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint(
            'Location permissions are permanently denied, we cannot request permissions.');
        _startLocationSimulation();
        return;
      }

      // Get current location
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _locationPermissionGranted = true;
        });

        // Move map to current location
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _moveMapToCurrentLocation();
        });

        _startLocationUpdates();
      }
    } catch (e) {
      debugPrint('Error getting current location: $e');
      _startLocationSimulation();
    }
  }

  // Move map to current location using Google Maps controller
  void _moveMapToCurrentLocation() {
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target:
                LatLng(_currentLocation.latitude, _currentLocation.longitude),
            zoom: 15.0,
          ),
        ),
      );
      debugPrint(
          'Google Map moved to current location: ${_currentLocation.latitude}, ${_currentLocation.longitude}');
    }
  }

  // Enhanced method to center map on current location with smooth animation
  void _centerMapOnCurrentLocation({double zoom = 15.0}) async {
    if (_mapController != null) {
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target:
                LatLng(_currentLocation.latitude, _currentLocation.longitude),
            zoom: zoom,
          ),
        ),
      );
      debugPrint('Map centered on current location with zoom $zoom');
    }
  }

  void _startLocationUpdates() {
    Timer.periodic(const Duration(seconds: 15), (timer) async {
      if (mounted && _locationPermissionGranted) {
        try {
          // Check if location services are still enabled
          bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
          if (!serviceEnabled) {
            debugPrint('Location services disabled during update');
            return;
          }

          Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 10),
          );

          if (mounted) {
            setState(() {
              _currentLocation = LatLng(position.latitude, position.longitude);
            });

            debugPrint(
                'Driver location updated: ${position.latitude}, ${position.longitude}');

            // Update Firebase with driver location if they have an active order
            if (_activeOrder != null) {
              _updateDriverLocationInFirebase(position);
            }
          }
        } catch (e) {
          debugPrint('Error updating location: $e');
        }
      } else {
        timer.cancel();
      }
    });
  }

  // Update driver location in Firebase for order tracking
  void _updateDriverLocationInFirebase(Position position) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null || _activeOrder == null) return;

      await FirebaseFirestore.instance
          .collection('orders')
          .doc(_activeOrder!.id)
          .update({
        'driverLocation': {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'timestamp': FieldValue.serverTimestamp(),
        },
      });

      debugPrint(
          'Driver location updated in Firebase for order ${_activeOrder!.id}');
    } catch (e) {
      debugPrint('Error updating driver location in Firebase: $e');
    }
  }

  void _startLocationSimulation() {
    Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(
            _currentLocation.latitude +
                (math.Random().nextDouble() - 0.5) * 0.001,
            _currentLocation.longitude +
                (math.Random().nextDouble() - 0.5) * 0.001,
          );
        });
      }
    });
  }

  // Create custom truck icon for driver marker
  void _createTruckIcon() async {
    try {
      // Create a custom truck icon using Flutter's Icons.local_shipping
      final icon = Icons.local_shipping; // This is a truck icon
      
      // Create a custom marker using Flutter's truck icon
      final pictureRecorder = ui.PictureRecorder();
      final canvas = Canvas(pictureRecorder);
      const size = 48.0;
      
      // Draw a circle background
      final paint = Paint()
        ..color = const Color(0xFFFF6B35) // Orange color for truck
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(
        const Offset(size / 2, size / 2), 
        size / 2, 
        paint,
      );
      
      // Draw the truck icon
      final textPainter = TextPainter(
        textDirection: TextDirection.ltr,
      );
      
      textPainter.text = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size * 0.6, // 60% of container size
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: Colors.white,
        ),
      );
      
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          (size - textPainter.width) / 2,
          (size - textPainter.height) / 2,
        ),
      );
      
      final picture = pictureRecorder.endRecording();
      final image = await picture.toImage(size.toInt(), size.toInt());
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      
      _truckIcon = BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
      print('Successfully created custom truck icon for driver marker');
    } catch (e) {
      print('Error creating custom truck marker, using orange marker: $e');
      // Fallback to orange marker if custom icon creation fails
      _truckIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    }
  }

  // Get user location and automatically center map when screen loads
  void _getUserLocationAndCenter() async {
    try {
      // Get fresh location when screen loads
      await _getUserLocation();

      // Small delay to ensure map is ready, then center with smooth animation
      await Future.delayed(const Duration(milliseconds: 500));
      _centerMapOnCurrentLocation(zoom: 15.0);

      print(
          'Map automatically centered on current location: ${_currentLocation.latitude}, ${_currentLocation.longitude}');
    } catch (e) {
      print('Error getting location and centering map: $e');
    }
  }

  void _startNoOrdersTimer() {
    _noOrdersTimer = Timer.periodic(const Duration(minutes: 4), (timer) {
      if (mounted && _isSearchingOrders && _availableOrders.isEmpty) {
        final timeSinceLastOrder =
            DateTime.now().difference(_lastOrderFoundTime);
        if (timeSinceLastOrder.inMinutes >= 4) {
          _showIncreaseSearchAreaDialog();
        }
      }
    });
  }

  void _showIncreaseSearchAreaDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF2D2D3C)
              : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.search_off,
                color: Colors.orange,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'No Orders Found',
                style: GoogleFonts.albertSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No orders found in your current search area (${_searchRadius.toStringAsFixed(1)} km) for the last 4 minutes.',
                style: GoogleFonts.albertSans(
                  fontSize: 14,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withOpacity(0.8)
                      : Colors.grey[700],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Would you like to increase your search area to find more orders?',
                style: GoogleFonts.albertSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _lastOrderFoundTime = DateTime.now();
              },
              child: Text(
                'Not Now',
                style: GoogleFonts.albertSans(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _increaseSearchArea();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.yellowAccent
                    : Colors.blue,
                foregroundColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black
                    : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              ),
              child: Text(
                'Yes, Increase Area',
                style: GoogleFonts.albertSans(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _increaseSearchArea() {
    final oldRadius = _searchRadius;
    setState(() {
      _searchRadius = math.min(_searchRadius + 2.0, 15.0);
      _lastOrderFoundTime = DateTime.now();
    });

    print("SEARCH AREA INCREASED: $oldRadius km -> $_searchRadius km");

    // Re-filter existing Firebase orders with new radius
    _filterOrdersByRadius();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Search area increased to ${_searchRadius.toStringAsFixed(1)} km',
          style: GoogleFonts.albertSans(
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Show radius selection dialog
  void _showRadiusSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Consumer<ThemeService>(
          builder: (context, themeService, child) {
            final isDarkMode = themeService.isDarkMode;

            return AlertDialog(
              backgroundColor:
                  isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.radar,
                    color: AppColors.yellowAccent,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Search Radius',
                    style: GoogleFonts.albertSans(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select your preferred search radius for finding orders:',
                    style: GoogleFonts.albertSans(
                      fontSize: 14,
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.8)
                          : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ..._radiusOptions.map((radius) {
                    final isSelected = _searchRadius == radius;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () {
                          print("RADIUS OPTION TAPPED: $radius km");
                          print("Previous radius: $_searchRadius km");
                          print("New radius: $radius km");
                          HapticFeedback.mediumImpact();
                          setState(() {
                            _searchRadius = radius;
                            _lastOrderFoundTime = DateTime.now();
                          });
                          Navigator.of(context).pop();

                          // Re-filter existing orders with new radius
                          print(
                              "Re-filtering orders with new radius: $radius km");
                          _filterOrdersByRadius();

                          // Show confirmation
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                radius == 999.0
                                    ? 'Search radius updated to No Boundary Limit'
                                    : 'Search radius updated to ${radius.toStringAsFixed(1)} km',
                                style: GoogleFonts.albertSans(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                              backgroundColor: Colors.blue,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.yellowAccent.withOpacity(0.1)
                                : (isDarkMode
                                    ? Colors.white.withOpacity(0.05)
                                    : Colors.grey.withOpacity(0.05)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.yellowAccent
                                  : (isDarkMode
                                      ? Colors.white.withOpacity(0.1)
                                      : Colors.grey.withOpacity(0.2)),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? AppColors.yellowAccent
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.yellowAccent
                                        : (isDarkMode
                                            ? Colors.white.withOpacity(0.3)
                                            : Colors.grey.withOpacity(0.5)),
                                    width: 2,
                                  ),
                                ),
                                child: isSelected
                                    ? Icon(
                                        Icons.check,
                                        size: 14,
                                        color: Colors.black,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      radius == 999.0
                                          ? 'No Boundary Limit'
                                          : '${radius.toStringAsFixed(1)} km radius',
                                      style: GoogleFonts.albertSans(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: isDarkMode
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _getRadiusDescription(radius),
                                      style: GoogleFonts.albertSans(
                                        fontSize: 12,
                                        color: isDarkMode
                                            ? Colors.white.withOpacity(0.6)
                                            : Colors.grey.withOpacity(0.8),
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
                  }).toList(),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.albertSans(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _getRadiusDescription(double radius) {
    switch (radius) {
      case 4.0:
        return 'Close range - More frequent orders';
      case 6.0:
        return 'Medium range - Balanced distance';
      case 9.0:
        return 'Wide range - More order options';
      case 999.0:
        return 'No boundary limit - All available orders';
      default:
        return 'Custom radius';
    }
  }

  void _toggleOrderSheetDirect() {
    print('_toggleOrderSheetDirect called');
    print('Current expanded state: $_isOrderSheetExpanded');

    // Add haptic feedback
    HapticFeedback.mediumImpact();

    // Simple state-based toggle without relying on DraggableScrollableController
    if (mounted) {
      setState(() {
        _isOrderSheetExpanded = !_isOrderSheetExpanded;
      });
      print('Sheet state toggled to: $_isOrderSheetExpanded');
    }
  }

  void _initializeAnimations() {
    _mapAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _mapFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _mapAnimationController,
      curve: Curves.easeInOut,
    ));

    _orderSheetController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _radiusAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _popupController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    final slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _popupController,
      curve: Curves.easeOutBack,
    ));
    _popupSlideAnimation = slideAnimation;

    _popupOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _popupController,
      curve: Curves.easeOut,
    ));

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // _pulseAnimation not needed for Google Maps
    // _pulseAnimation = Tween<double>(
    //   begin: 0.0,
    //   end: 1.0,
    // ).animate(CurvedAnimation(
    //   parent: _pulseController,
    //   curve: Curves.easeInOut,
    // ));
  }

  void _startAnimations() {
    _mapAnimationController.forward();
    if (_isSearchingOrders) {
      _radiusAnimationController.repeat(reverse: true);
    }
    _pulseController.repeat();
  }

  // Firebase order fetching methods
  void _fetchOrdersFromFirebase() async {
    setState(() {
      _isLoadingOrders = true;
      _lastError = null;
    });

    try {
      print("Starting to fetch orders from Firebase...");

      // Cancel any existing subscription
      _ordersStreamSubscription?.cancel();

      // Listen to orders collection with real-time updates
      // Only show orders with status 'active' as per requirements
      _ordersStreamSubscription = FirebaseFirestore.instance
          .collection('orders')
          .where('status', isEqualTo: 'active')
          .orderBy('createdAt', descending: true)
          .limit(50) // Increased limit to ensure we get recent orders
          .snapshots()
          .listen(
        (QuerySnapshot snapshot) {
          print(
              "🔥 REAL-TIME UPDATE: Received ${snapshot.docs.length} orders from Firebase");
          print("🔥 Timestamp: ${DateTime.now()}");
          // Log first few orders for debugging
          for (int i = 0; i < math.min(3, snapshot.docs.length); i++) {
            final doc = snapshot.docs[i];
            final data = doc.data() as Map<String, dynamic>;
            print(
                "📋 Order ${i + 1}: ${doc.id} - Status: ${data['status']} - Created: ${data['createdAt']}");
          }
          _handleOrdersUpdate(snapshot);
        },
        onError: (error) {
          print("❌ Error listening to orders: $error");
          setState(() {
            _lastError = error.toString();
            _isLoadingOrders = false;
          });

          // No fallback - only show Firebase orders
          print("Firebase error, clearing orders list");
        },
      );

      // Also listen to driver's active orders to detect completion/cancellation
      _setupActiveOrderListener();
    } catch (e) {
      print("Error setting up Firebase listener: $e");
      setState(() {
        _lastError = e.toString();
        _isLoadingOrders = false;
      });

      // No fallback - only show Firebase orders
      print("Firebase setup error, clearing orders list");
    }
  }

  void _handleOrdersUpdate(QuerySnapshot snapshot) {
    try {
      List<OrderModel> newOrders = [];

      print("=== Processing ${snapshot.docs.length} orders from Firebase ===");
      print("Current search radius: $_searchRadius km");
      print(
          "Current location: ${_currentLocation.latitude}, ${_currentLocation.longitude}");

      for (var doc in snapshot.docs) {
        try {
          print("Processing order: ${doc.id}");
          final data = doc.data() as Map<String, dynamic>;
          print("Order data keys: ${data.keys.toList()}");
          print("Order status: ${data['status']}");
          print("Order type: ${data['orderType']}");

          // Only process orders with status 'active'
          if (data['status'] != 'active') {
            print(
                "❌ Order ${doc.id} skipped - status is '${data['status']}', not 'active'");
            continue;
          }

          final order = OrderModel.fromFirestore(doc);
          print(
              "Parsed order: ${order.customerName} - ${order.packageType} - Rs ${order.estimatedEarnings}");
          print("Pickup: ${order.pickupAddress}");
          print("Dropoff: ${order.dropoffAddress}");
          print("Distance from driver: ${order.distance} km");
          print(
              "Pickup location: ${order.pickupLocation.latitude}, ${order.pickupLocation.longitude}");

          // Filter orders based on current location and search radius
          if (_isOrderWithinRadius(order)) {
            newOrders.add(order);
            print(
                "✅ Order ${doc.id} added (within ${_searchRadius} km radius)");
          } else {
            print(
                "❌ Order ${doc.id} filtered out (outside ${_searchRadius} km radius)");
          }
        } catch (e) {
          print("Error parsing order ${doc.id}: $e");
          // Continue processing other orders
        }
      }

      setState(() {
        _availableOrders = newOrders;
        _isLoadingOrders = false;
        _lastError = null;
        _lastOrderFoundTime = DateTime.now();
      });

      print(
          "✅ Successfully updated UI: ${_availableOrders.length} orders within ${_searchRadius} km radius");
      print(
          "🔄 UI State - isSearchingOrders: $_isSearchingOrders, hasActiveOrder: ${_activeOrder != null}");

      // Fetch customer names for orders that need them
      _fetchCustomerNamesForOrders(newOrders);

      // Detect and show popup for new orders
      _handleNewOrderDetection(newOrders);
    } catch (e) {
      print("Error handling orders update: $e");
      setState(() {
        _lastError = e.toString();
        _isLoadingOrders = false;
      });
    }
  }

  // Method to detect new orders and show popups
  void _handleNewOrderDetection(List<OrderModel> currentOrders) {
    // Always update the seen orders, but only show popups if searching and no active order
    bool shouldShowPopups =
        _isSearchingOrders && !_showOrderPopup && _activeOrder == null;

    // Find orders that haven't been seen before
    List<OrderModel> newOrders = currentOrders.where((order) {
      return !_seenOrderIds.contains(order.id);
    }).toList();

    if (newOrders.isNotEmpty) {
      print("=== DETECTED ${newOrders.length} NEW ORDERS ===");

      // Add all current order IDs to seen set
      for (var order in currentOrders) {
        _seenOrderIds.add(order.id);
      }

      // Only show popup if driver can accept orders (no active order)
      if (shouldShowPopups) {
        // Show popup for the first new order
        final firstNewOrder = newOrders.first;
        print(
            "Showing popup for new order: ${firstNewOrder.id} - ${firstNewOrder.customerName}");
        _showNewOrderPopupForOrder(firstNewOrder);

        // Queue other new orders if there are multiple
        if (newOrders.length > 1) {
          _queueRemainingNewOrders(newOrders.skip(1).toList());
        }
      } else {
        print(
            "New orders detected but not showing popups (active order present or not searching)");
      }
    } else {
      // Still update seen orders in case of order updates
      for (var order in currentOrders) {
        _seenOrderIds.add(order.id);
      }
    }
  }

  // Queue system for multiple new orders
  List<OrderModel> _queuedNewOrders = [];

  void _queueRemainingNewOrders(List<OrderModel> orders) {
    _queuedNewOrders.addAll(orders);
    print("Queued ${orders.length} additional new orders");
  }

  void _showNextQueuedOrder() {
    if (_queuedNewOrders.isNotEmpty && !_showOrderPopup) {
      final nextOrder = _queuedNewOrders.removeAt(0);
      print(
          "Showing next queued order: ${nextOrder.id} - ${nextOrder.customerName}");
      _showNewOrderPopupForOrder(nextOrder);
    }
  }

  bool _isOrderWithinRadius(OrderModel order) {
    // If no boundary limit is set, accept all orders
    if (_searchRadius >= 999.0) {
      print("📍 Order ${order.id}: No boundary limit - order accepted");
      return true;
    }

    // Calculate distance between current location and pickup location
    final distance = _calculateDistance(
      _currentLocation.latitude,
      _currentLocation.longitude,
      order.pickupLocation.latitude,
      order.pickupLocation.longitude,
    );

    final withinRadius = distance <= _searchRadius;
    print(
        "📍 Order ${order.id}: Distance = ${distance.toStringAsFixed(2)} km, Radius = $_searchRadius km, Within: $withinRadius");
    print(
        "   Current location: ${_currentLocation.latitude}, ${_currentLocation.longitude}");
    print(
        "   Order pickup: ${order.pickupLocation.latitude}, ${order.pickupLocation.longitude}");

    return withinRadius;
  }

  // Helper function for distance calculation
  double _calculateDistanceBetweenPoints(
      double lat1, double lng1, double lat2, double lng2) {
    // Haversine formula for calculating distance between two points
    const double earthRadius = 6371; // Earth's radius in kilometers

    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLng = _degreesToRadians(lng2 - lng1);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  // Method to fetch customer names for orders that need them
  void _fetchCustomerNamesForOrders(List<OrderModel> orders) async {
    for (OrderModel order in orders) {
      // Check if order needs customer name fetching
      if (order.customerName.startsWith('Customer ') &&
          order.customerName.contains('...') &&
          order.rawData['customerUid'] != null) {
        final customerUid = order.rawData['customerUid'] as String;
        print('Fetching customer name for UID: $customerUid');

        // Fetch the customer name
        final customerName =
            await OrderModel.fetchCustomerNameFromUsers(customerUid);

        if (customerName != null && customerName.isNotEmpty) {
          print('Found customer name: $customerName for UID: $customerUid');

          // Update the order model
          order.updateCustomerName(customerName);

          // Trigger UI update
          if (mounted) {
            setState(() {
              // The order is already in _availableOrders, so just trigger rebuild
            });
          }
        } else {
          print('No name found for UID: $customerUid, keeping default name');
        }
      }
    }
  }

  double _calculateDistance(
      double lat1, double lng1, double lat2, double lng2) {
    return _calculateDistanceBetweenPoints(lat1, lng1, lat2, lng2);
  }

  void _showNewOrderPopupForOrder(OrderModel order) {
    if (_showOrderPopup || !_isSearchingOrders) return;

    // Add haptic feedback and sound for new order
    HapticFeedback.heavyImpact();

    print(
        "🚨 NEW ORDER POPUP: ${order.customerName} - Rs ${order.estimatedEarnings}");

    setState(() {
      _currentPopupOrder = order;
      _showOrderPopup = true;
      _popupTimeRemaining = 15; // 15 seconds to respond
    });

    _popupController.forward();

    // Start countdown timer
    _orderPopupTimer?.cancel();
    _orderPopupTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _popupTimeRemaining--;
        });

        // Auto-reject if time runs out
        if (_popupTimeRemaining <= 0) {
          print("⏰ Order popup timed out - auto-rejecting order ${order.id}");
          _autoRejectOrder(order);
          timer.cancel();
        }
      } else {
        timer.cancel();
      }
    });
  }

  void _autoRejectOrder(OrderModel order) {
    _hideOrderPopup();

    // Record auto-rejection in Firebase
    FirebaseFirestore.instance.collection('orders').doc(order.id).update({
      'autoRejectedBy': FieldValue.arrayUnion([
        {
          'driverId':
              FirebaseAuth.instance.currentUser?.uid ?? 'anonymous_driver',
          'reason': 'timeout',
          'autoRejectedAt': FieldValue.serverTimestamp(),
        }
      ]),
    }).catchError((error) {
      print("Error recording auto-rejection: $error");
    });

    // Show feedback to driver
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '⏰ Order expired - ${order.customerName}',
          style: GoogleFonts.albertSans(
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.orange.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );

    // Show next queued order if any
    _showNextQueuedOrder();
  }

  void _filterOrdersByRadius() {
    print("=== Filtering orders by radius ===");
    print("Current radius: $_searchRadius km");
    print("Available orders before filtering: ${_availableOrders.length}");

    // Get fresh data from Firebase when radius changes to catch any orders that might have been missed
    _fetchOrdersFromFirebase();

    print("Re-fetched orders from Firebase due to radius change");
  }

  void _startOrderSearch() {
    _searchRadiusTimer?.cancel();
  }

  void _startPeriodicOrderGeneration() {
    print("Starting periodic order monitoring");

    // First cancel any existing timer
    if (_orderGenerationTimer != null) {
      _orderGenerationTimer!.cancel();
      _orderGenerationTimer = null;
      print("Existing order generation timer canceled");
    }

    // Only monitor if searching is active
    if (_isSearchingOrders) {
      print(
          "Firebase order monitoring is active - orders will come through real-time listener");
      // Note: We don't need a periodic timer anymore since Firebase provides real-time updates
      // The _fetchOrdersFromFirebase() method handles all order updates via Firestore listeners
    } else {
      print("Not starting order monitoring because searching is paused");
    }
  }

  void _hideOrderPopup() {
    _popupController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _showOrderPopup = false;
          _currentPopupOrder = null;
        });

        // Show next queued order after a short delay
        Future.delayed(const Duration(milliseconds: 500), () {
          _showNextQueuedOrder();
        });
      }
    });
    _orderPopupTimer?.cancel();
  }

  // Check if driver has an active order
  Future<bool> _hasActiveOrder() async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return false;

      final querySnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('driverId', isEqualTo: currentUserId)
          .where('status', whereIn: ['started', 'accepted'])
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        // Update local active order reference
        final doc = querySnapshot.docs.first;
        _activeOrder = OrderModel.fromFirestore(doc);
        return true;
      } else {
        _activeOrder = null;
        return false;
      }
    } catch (e) {
      print("Error checking for active orders: $e");
      return false;
    }
  }

  // Check for existing active order on app start
  void _checkForExistingActiveOrder() async {
    await _hasActiveOrder();
    if (_activeOrder != null) {
      print(
          "Found existing active order: ${_activeOrder!.id} - ${_activeOrder!.customerName}");
      // Optionally show a notification or update UI to indicate active order
      setState(() {
        // Update UI to reflect active order status
      });
    }
  }

  // Setup listener for driver's active orders
  void _setupActiveOrderListener() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    FirebaseFirestore.instance
        .collection('orders')
        .where('driverId', isEqualTo: currentUserId)
        .where('status', whereIn: ['started', 'accepted'])
        .snapshots()
        .listen(
          (QuerySnapshot snapshot) {
            if (snapshot.docs.isEmpty) {
              // No active orders - driver can accept new orders
              if (_activeOrder != null) {
                print(
                    "Active order completed/cancelled - driver can accept new orders");
                setState(() {
                  _activeOrder = null;
                  // Resume searching if was paused due to active order
                  if (!_isSearchingOrders) {
                    _isSearchingOrders = true;
                    _fetchOrdersFromFirebase();
                    _radiusAnimationController.repeat(reverse: true);
                  }
                });
              }
            } else {
              // Update active order but keep listening for orders
              final doc = snapshot.docs.first;
              final updatedOrder = OrderModel.fromFirestore(doc);
              if (_activeOrder?.id != updatedOrder.id) {
                setState(() {
                  _activeOrder = updatedOrder;
                  // Just update the UI state, but keep the orders listener active
                  _isSearchingOrders = false;
                  _radiusAnimationController.stop();
                  // Don't cancel _ordersStreamSubscription - keep it active for real-time updates
                });
                print(
                    "Active order updated: ${updatedOrder.id} - ${updatedOrder.customerName}");
              }
            }
          },
          onError: (error) {
            print("Error listening to active orders: $error");
          },
        );
  }

  // Show snackbar for active order warning
  void _showActiveOrderWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Complete Current Active Order',
                    style: GoogleFonts.albertSans(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'You cannot accept new orders until you complete your current active order',
                    style: GoogleFonts.albertSans(
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 5),
        action: _activeOrder != null
            ? SnackBarAction(
                label: 'View',
                textColor: Colors.white,
                onPressed: () {
                  // Navigate to active order details
                  _showOrderDetails(_activeOrder!);
                },
              )
            : null,
      ),
    );
  }

  void _acceptOrder(OrderModel order, {bool isPopup = false}) async {
    HapticFeedback.mediumImpact();

    // Check if driver already has an active order
    if (await _hasActiveOrder()) {
      _showActiveOrderWarning();
      return;
    }

    if (isPopup) {
      _hideOrderPopup();
    } else {
      setState(() {
        _availableOrders.removeWhere((o) => o.id == order.id);
      });
    }

    // Update order status in Firebase to "started"
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(order.id)
          .update({
        'status': 'started', // Changed from 'accepted' to 'started'
        'acceptedAt': FieldValue.serverTimestamp(),
        'startedAt': FieldValue.serverTimestamp(), // Add started timestamp
        'driverId':
            FirebaseAuth.instance.currentUser?.uid ?? 'anonymous_driver',
        'driverLocation': {
          'latitude': _currentLocation.latitude,
          'longitude': _currentLocation.longitude,
        },
      });

      print(
          "Order ${order.id} accepted and status changed to 'started' in Firebase");

      // Set this as the active order
      setState(() {
        _activeOrder = order;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Order Started!',
                      style: GoogleFonts.albertSans(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${order.customerName} • Rs ${order.estimatedEarnings.toInt()}',
                      style: GoogleFonts.albertSans(
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'View',
            textColor: Colors.white,
            onPressed: () {
              // Navigate to order details or tracking screen
              _showOrderDetails(order);
            },
          ),
        ),
      );
    } catch (e) {
      print("Error updating order in Firebase: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Order accepted but failed to update status: $e',
            style: GoogleFonts.albertSans(
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          backgroundColor: Colors.orange.shade600,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _rejectOrder(OrderModel order, {bool isPopup = false}) async {
    HapticFeedback.lightImpact();

    if (isPopup) {
      _hideOrderPopup();
    } else {
      setState(() {
        _availableOrders.removeWhere((o) => o.id == order.id);
      });
    }

    // Update order status in Firebase (optional - you might want to track rejections)
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(order.id)
          .update({
        'rejectedBy': FieldValue.arrayUnion([
          {
            'driverId':
                FirebaseAuth.instance.currentUser?.uid ?? 'anonymous_driver',
            'rejectedAt': FieldValue.serverTimestamp(),
            'driverLocation': {
              'latitude': _currentLocation.latitude,
              'longitude': _currentLocation.longitude,
            },
          }
        ]),
      });

      print("Order ${order.id} rejection recorded in Firebase");
    } catch (e) {
      print("Error recording rejection in Firebase: $e");
      // Don't show error to user for rejections
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Order rejected - ${order.customerName}',
          style: GoogleFonts.albertSans(
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.orange.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _toggleSearching() {
    try {
      print("==== _toggleSearching called ====");

      // Check if driver has an active order
      if (_activeOrder != null) {
        _showActiveOrderWarning();
        return;
      }

      print(
          "Current state before toggle: ${_isSearchingOrders ? 'SEARCHING' : 'PAUSED'}");

      // Toggle the state
      final newSearchingState = !_isSearchingOrders;
      print("New state will be: ${newSearchingState ? 'SEARCHING' : 'PAUSED'}");

      // Update the state
      setState(() {
        _isSearchingOrders = newSearchingState;
      });

      print(
          "State has been set to: ${_isSearchingOrders ? 'SEARCHING' : 'PAUSED'}");

      // Perform operations based on new state
      if (_isSearchingOrders) {
        print(
            "Resuming search operations - starting timers (Firebase listener already active)");
        try {
          // Only restart Firebase listener if not already active
          if (_ordersStreamSubscription == null) {
            _fetchOrdersFromFirebase();
          }
          _startPeriodicOrderGeneration();
          _startNoOrdersTimer();
          _radiusAnimationController.repeat(reverse: true);
        } catch (e) {
          print("Error in resume operations: $e");
        }
      } else {
        print(
            "Pausing search operations - cancelling timers but keeping Firebase listener active");
        try {
          // Don't cancel _ordersStreamSubscription - keep it active for real-time updates
          _orderGenerationTimer?.cancel();
          _noOrdersTimer?.cancel();
          _radiusAnimationController.stop();

          if (_showOrderPopup) {
            _hideOrderPopup();
          }
        } catch (e) {
          print("Error in pause operations: $e");
        }
      }

      // Show visual feedback with a snackbar
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isSearchingOrders
                  ? '✓ Order search resumed'
                  : '⏸ Order search paused',
              style: GoogleFonts.albertSans(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            backgroundColor: _isSearchingOrders
                ? Colors.green.shade700
                : Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(bottom: 80, left: 20, right: 20),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
        print("Snackbar shown successfully");
      } catch (e) {
        print("Error showing snackbar: $e");
      }

      print("==== _toggleSearching completed ====");
    } catch (e) {
      print("!!! CRITICAL ERROR in _toggleSearching: $e");
    }
  }

  @override
  void dispose() {
    _mapAnimationController.dispose();
    _orderSheetController.dispose();
    _radiusAnimationController.dispose();
    _popupController.dispose();
    _pulseController.dispose();
    _orderPopupTimer?.cancel();
    _searchRadiusTimer?.cancel();
    _noOrdersTimer?.cancel();
    _orderGenerationTimer?.cancel();
    _ordersStreamSubscription?.cancel(); // Cancel Firebase subscription
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
          backgroundColor: isDarkMode ? const Color(0xFF1E1E2C) : Colors.white,
          body: Stack(
            children: [
              // Full screen map
              _buildMapView(isDarkMode),

              // Top app bar
              _buildTopAppBar(isTablet, isDarkMode),

              // Zoom controls
              _buildZoomControls(isTablet, isDarkMode),

              // Draggable order sheet
              _buildDraggableOrderSheet(isTablet, isDarkMode),

              // New order popup - slides from bottom
              if (_showOrderPopup && _currentPopupOrder != null)
                _buildOrderPopup(isTablet, isDarkMode),

              // Floating Pause/Play button (separate from the top bar)
              Positioned(
                bottom: 120,
                right: 20,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      print("FLOATING PAUSE/PLAY BUTTON TAPPED");
                      HapticFeedback.heavyImpact();
                      _toggleSearching();
                    },
                    borderRadius: BorderRadius.circular(30),
                    splashColor: Colors.white.withOpacity(0.3),
                    child: Container(
                      width: 65,
                      height: 65,
                      decoration: BoxDecoration(
                        color: _isSearchingOrders
                            ? Colors.green.shade600
                            : Colors.orange.shade600,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            spreadRadius: 2,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          _isSearchingOrders ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMapView(bool isDarkMode) {
    return FadeTransition(
      opacity: _mapFadeAnimation,
      child: Column(
        children: [
          // Map
          Expanded(
            child: Container(
              width: double.infinity,
              color: isDarkMode ? const Color(0xFF1E1E2C) : Colors.grey[100],
              child: _buildFlutterMap(isDarkMode),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlutterMap(bool isDarkMode) {
    // Use Google Maps for all platforms
    return _buildGoogleMap(isDarkMode);
  }

  /// Google Maps implementation for both Web and Mobile
  Widget _buildGoogleMap(bool isDarkMode) {
    return GoogleMap(
      onMapCreated: (GoogleMapController controller) {
        _mapController = controller;
        print("Google Map controller initialized");

        // Set map style for dark mode if needed
        if (isDarkMode) {
          _setMapStyle(controller);
        }

        // Automatically move to current location when map is created
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _moveMapToCurrentLocation();
        });
      },
      initialCameraPosition: CameraPosition(
        target: LatLng(_currentLocation.latitude, _currentLocation.longitude),
        zoom: 15.0,
      ),
      markers: _buildGoogleMapMarkers(isDarkMode),
      circles: _buildSearchRadiusCircles(),
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      onTap: (LatLng position) {
        HapticFeedback.lightImpact();
      },
      onCameraMove: (CameraPosition position) {
        // Handle camera movement if needed
      },
    );
  }

  // Set dark map style for Google Maps
  void _setMapStyle(GoogleMapController controller) {
    const String darkMapStyle = '''
    [
      {
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#212121"
          }
        ]
      },
      {
        "elementType": "labels.icon",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#757575"
          }
        ]
      },
      {
        "elementType": "labels.text.stroke",
        "stylers": [
          {
            "color": "#212121"
          }
        ]
      },
      {
        "featureType": "administrative",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#757575"
          }
        ]
      },
      {
        "featureType": "road",
        "elementType": "geometry.fill",
        "stylers": [
          {
            "color": "#2c2c2c"
          }
        ]
      },
      {
        "featureType": "water",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#000000"
          }
        ]
      }
    ]
    ''';

    controller.setMapStyle(darkMapStyle);
  }

  /// Build overlays for mobile Mapbox map (current location and order markers)
  // List<Widget> _buildMobileMapOverlays(bool isDarkMode) {
  //   // Method commented out as it's not used in simplified Mapbox implementation
  //   return [];
  // }

  // Old FlutterMap marker method - DEPRECATED
  // This method is commented out as we now use Google Maps
  /*
  List<Marker> _buildMapMarkers(bool isDarkMode) {
    // This method is no longer used - replaced by _buildGoogleMapMarkers
    return [];
  }
  */

  // Build Google Maps markers
  Set<Marker> _buildGoogleMapMarkers(bool isDarkMode) {
    Set<Marker> markers = <Marker>{};

    // Add driver's current location marker
    markers.add(
      Marker(
        markerId: const MarkerId('driver_location'),
        position: LatLng(_currentLocation.latitude, _currentLocation.longitude),
        infoWindow: InfoWindow(
          title: 'Your Location (Driver)',
          snippet: _isSearchingOrders
              ? 'Searching for orders...'
              : _activeOrder != null
                  ? 'On active order'
                  : 'Offline',
        ),
        icon: _truckIcon ??
            BitmapDescriptor.defaultMarkerWithHue(
              _isSearchingOrders
                  ? BitmapDescriptor.hueOrange // Orange when searching
                  : _activeOrder != null
                      ? BitmapDescriptor
                          .hueYellow // Yellow when on active order
                      : BitmapDescriptor.hueRed, // Red when offline
            ),
        rotation:
            0.0, // You can add rotation based on movement direction if needed
      ),
    );

    // Add markers for available orders
    for (int i = 0; i < _availableOrders.length; i++) {
      final order = _availableOrders[i];

      // Use actual order pickup location instead of simulated positions
      final orderLat = order.pickupLocation.latitude;
      final orderLng = order.pickupLocation.longitude;

      print(
          "Adding marker for order ${order.id} at lat: $orderLat, lng: $orderLng");

      markers.add(
        Marker(
          markerId: MarkerId('order_${order.id}'),
          position: LatLng(orderLat, orderLng),
          infoWindow: InfoWindow(
            title: order.customerName,
            snippet:
                'Rs ${order.estimatedEarnings.toInt()} - ${order.packageType}',
            onTap: () {
              HapticFeedback.mediumImpact();
              _showOrderDetails(order);
            },
          ),
          icon: order.serviceType == 'shifting'
              ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)
              : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          onTap: () {
            print(
                "🎯 Order marker tapped: ${order.id} - ${order.customerName}");
            print("📋 Order details:");
            print("   - Service: ${order.serviceType}");
            print("   - Package: ${order.packageType}");
            print("   - Status: ${order.status}");
            print("   - Distance: ${order.distance.toStringAsFixed(1)} km");
            print(
                "   - Location: ${order.pickupLocation.latitude}, ${order.pickupLocation.longitude}");

            HapticFeedback.lightImpact();

            try {
              _showOrderDetails(order);
              print("✅ Order details modal called successfully");
            } catch (e) {
              print("❌ Error showing order details: $e");
              print("📱 Stack trace: ${StackTrace.current}");
            }
          },
        ),
      );
    }

    return markers;
  }

  // Build search radius circles for Google Maps
  Set<Circle> _buildSearchRadiusCircles() {
    Set<Circle> circles = <Circle>{};

    if (_isSearchingOrders) {
      circles.add(
        Circle(
          circleId: const CircleId('search_radius'),
          center: LatLng(_currentLocation.latitude, _currentLocation.longitude),
          radius: _searchRadius * 1000, // Convert km to meters
          fillColor: AppColors.yellowAccent.withOpacity(0.1),
          strokeColor: AppColors.yellowAccent.withOpacity(0.4),
          strokeWidth: 2,
        ),
      );
    }

    return circles;
  }

  Widget _buildZoomControls(bool isTablet, bool isDarkMode) {
    return Positioned(
      right: 16,
      top: 120,
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              if (_mapController != null) {
                try {
                  _mapController!.animateCamera(
                    CameraUpdate.zoomIn(),
                  );
                } catch (e) {
                  debugPrint('Error zooming in: $e');
                }
              }
            },
            child: Container(
              width: isTablet ? 48 : 44,
              height: isTablet ? 48 : 44,
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.black.withOpacity(0.7)
                    : Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
                border: isDarkMode
                    ? Border.all(color: Colors.white.withOpacity(0.2))
                    : Border.all(color: Colors.grey.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.zoom_in,
                color: isDarkMode ? Colors.white : Colors.black,
                size: isTablet ? 24 : 20,
              ),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              if (_mapController != null) {
                try {
                  _mapController!.animateCamera(
                    CameraUpdate.zoomOut(),
                  );
                } catch (e) {
                  debugPrint('Error zooming out: $e');
                }
              }
            },
            child: Container(
              width: isTablet ? 48 : 44,
              height: isTablet ? 48 : 44,
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.black.withOpacity(0.7)
                    : Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
                border: isDarkMode
                    ? Border.all(color: Colors.white.withOpacity(0.2))
                    : Border.all(color: Colors.grey.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.zoom_out,
                color: isDarkMode ? Colors.white : Colors.black,
                size: isTablet ? 24 : 20,
              ),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () async {
              HapticFeedback.mediumImpact();

              // Get fresh current location
              try {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Getting your current location...',
                          style: GoogleFonts.albertSans(
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: Colors.orange,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    duration: const Duration(seconds: 3),
                  ),
                );

                Position position = await Geolocator.getCurrentPosition(
                  desiredAccuracy: LocationAccuracy.high,
                  timeLimit: const Duration(seconds: 10),
                );

                if (mounted) {
                  setState(() {
                    _currentLocation =
                        LatLng(position.latitude, position.longitude);
                    _locationPermissionGranted = true;
                  });

                  if (_mapController != null) {
                    _mapController!.animateCamera(
                      CameraUpdate.newCameraPosition(
                        CameraPosition(
                          target: LatLng(position.latitude, position.longitude),
                          zoom: 15.0,
                        ),
                      ),
                    );

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.check_circle,
                                color: Colors.white, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Location Updated!',
                                    style: GoogleFonts.albertSans(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    'Driver position updated and map centered',
                                    style: GoogleFonts.albertSans(
                                      fontSize: 12,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                }
              } catch (e) {
                debugPrint('Error getting current location: $e');

                // Fallback to previously stored location
                if (_mapController != null) {
                  _mapController!.animateCamera(
                    CameraUpdate.newCameraPosition(
                      CameraPosition(
                        target: LatLng(_currentLocation.latitude,
                            _currentLocation.longitude),
                        zoom: 15.0,
                      ),
                    ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.warning, color: Colors.white, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Centered on last known location',
                              style: GoogleFonts.albertSans(
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.blue,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
            child: Container(
              width: isTablet ? 48 : 44,
              height: isTablet ? 48 : 44,
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.black.withOpacity(0.7)
                    : Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _locationPermissionGranted
                      ? (isDarkMode
                          ? AppColors.yellowAccent.withOpacity(0.5)
                          : Colors.blue.withOpacity(0.5))
                      : Colors.red.withOpacity(0.5),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                  if (_locationPermissionGranted)
                    BoxShadow(
                      color: (isDarkMode ? AppColors.yellowAccent : Colors.blue)
                          .withOpacity(0.3),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    _locationPermissionGranted
                        ? Icons.my_location
                        : Icons.location_disabled,
                    color: _locationPermissionGranted
                        ? (isDarkMode ? AppColors.yellowAccent : Colors.blue)
                        : Colors.red,
                    size: isTablet ? 24 : 20,
                  ),
                  if (_locationPermissionGranted)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
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

  Widget _buildTopAppBar(bool isTablet, bool isDarkMode) {
    return SafeArea(
      child: Container(
        margin: EdgeInsets.all(isTablet ? 20 : 16),
        child: Column(
          children: [
            Row(
              children: [
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),
            // Centered search status
            Center(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    print("RADIUS SELECTION BUTTON TAPPED");
                    HapticFeedback.mediumImpact();
                    if (_isSearchingOrders) {
                      print("Opening radius selection dialog");
                      _showRadiusSelectionDialog();
                    } else {
                      print("Not showing radius dialog - searching is paused");
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Resume order search first to change radius',
                            style: GoogleFonts.albertSans(
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                          backgroundColor: Colors.orange,
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(20),
                  splashColor: Colors.white.withOpacity(0.2),
                  highlightColor: Colors.white.withOpacity(0.1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.black.withOpacity(0.7)
                          : Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      border: isDarkMode
                          ? Border.all(
                              color: AppColors.yellowAccent.withOpacity(0.3))
                          : Border.all(color: Colors.grey.withOpacity(0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _activeOrder != null
                                ? Colors.blue // Blue for active order
                                : _isSearchingOrders
                                    ? Colors.green // Green for searching
                                    : Colors.orange, // Orange for offline
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          _locationPermissionGranted
                              ? Icons.gps_fixed
                              : Icons.gps_off,
                          size: 16,
                          color: _locationPermissionGranted
                              ? Colors.green
                              : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _activeOrder != null
                              ? 'Active Order: ${_activeOrder!.customerName}'
                              : _isSearchingOrders
                                  ? _searchRadius >= 999.0
                                      ? 'Searching Orders (No Limit)'
                                      : 'Searching Orders (${_searchRadius.toStringAsFixed(1)} km)'
                                  : 'Offline',
                          style: GoogleFonts.albertSans(
                            color: _activeOrder != null
                                ? Colors.green.shade600
                                : isDarkMode
                                    ? Colors.white
                                    : Colors.black,
                            fontSize: isTablet ? 14 : 13,
                            fontWeight: _activeOrder != null
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                        if (_activeOrder != null || _isSearchingOrders) ...[
                          const SizedBox(width: 4),
                          Icon(
                            _activeOrder != null
                                ? Icons.work
                                : Icons.keyboard_arrow_down,
                            color: _activeOrder != null
                                ? Colors.blue.shade600
                                : isDarkMode
                                    ? Colors.white.withOpacity(0.8)
                                    : Colors.grey.withOpacity(0.8),
                            size: 18,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDraggableOrderSheet(bool isTablet, bool isDarkMode) {
    return DraggableScrollableSheet(
      controller: _scrollController,
      initialChildSize: _isOrderSheetExpanded ? 0.8 : 0.15,
      minChildSize: 0.15,
      maxChildSize: 0.8,
      snap: true,
      snapSizes: const [0.15, 0.8],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle - always tappable
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    print('Tapping drag handle');
                    _toggleOrderSheetDirect();
                  },
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: _isOrderSheetExpanded
                              ? AppColors.yellowAccent.withOpacity(0.8)
                              : (isDarkMode
                                  ? Colors.white.withOpacity(0.3)
                                  : Colors.grey.withOpacity(0.5)),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Header - always visible and tappable
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    print('Tapping Available Orders header');
                    _toggleOrderSheetDirect();
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 24 : 16,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Available Orders',
                              style: GoogleFonts.albertSans(
                                fontSize: isTablet ? 18 : 16,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              _isOrderSheetExpanded
                                  ? Icons.keyboard_arrow_down
                                  : Icons.keyboard_arrow_up,
                              color: isDarkMode
                                  ? Colors.white.withOpacity(0.6)
                                  : Colors.grey.withOpacity(0.6),
                              size: 20,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _isOrderSheetExpanded
                                  ? 'Tap to collapse'
                                  : 'Tap to expand',
                              style: GoogleFonts.albertSans(
                                fontSize: isTablet ? 12 : 10,
                                color: isDarkMode
                                    ? Colors.white.withOpacity(0.5)
                                    : Colors.grey.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.yellowAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_availableOrders.length}',
                            style: GoogleFonts.albertSans(
                              fontSize: isTablet ? 14 : 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.yellowAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Content - only shown when expanded
              if (_isOrderSheetExpanded) ...[
                const SizedBox(height: 8),
                Flexible(
                  child: _availableOrders.isEmpty
                      ? _buildEmptyOrdersState(isTablet, isDarkMode)
                      : ListView.builder(
                          controller: scrollController,
                          padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 24 : 16),
                          itemCount: _availableOrders.length,
                          itemBuilder: (context, index) {
                            return _buildOrderCard(
                                _availableOrders[index], isTablet, isDarkMode);
                          },
                        ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyOrdersState(bool isTablet, bool isDarkMode) {
    if (_isLoadingOrders) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: isTablet ? 50 : 40,
              height: isTablet ? 50 : 40,
              child: CircularProgressIndicator(
                color: isDarkMode ? AppColors.yellowAccent : Colors.blue,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading orders from Firebase...',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 16 : 14,
                fontWeight: FontWeight.w500,
                color: isDarkMode
                    ? Colors.white.withOpacity(0.7)
                    : Colors.grey.withOpacity(0.8),
              ),
            ),
          ],
        ),
      );
    }

    if (_lastError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: isTablet ? 60 : 48,
              color: Colors.red.withOpacity(0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading orders',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 16 : 14,
                fontWeight: FontWeight.w500,
                color: isDarkMode
                    ? Colors.white.withOpacity(0.7)
                    : Colors.grey.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _lastError!,
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 12 : 10,
                  color: Colors.red.withOpacity(0.8),
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                _fetchOrdersFromFirebase();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isDarkMode ? AppColors.yellowAccent : Colors.blue,
                foregroundColor: isDarkMode ? Colors.black : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              ),
              child: Text(
                'Retry',
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 14 : 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _isSearchingOrders ? Icons.search : Icons.search_off,
            size: isTablet ? 80 : 64,
            color: isDarkMode
                ? Colors.white.withOpacity(0.3)
                : Colors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            _isSearchingOrders ? 'No orders in your area' : 'Search paused',
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 18 : 16,
              fontWeight: FontWeight.w500,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.7)
                  : Colors.grey.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isSearchingOrders
                ? 'Orders within ${_searchRadius.toStringAsFixed(1)} km will appear here'
                : 'Turn on search to find orders',
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 14 : 12,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.5)
                  : Colors.grey.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
          if (_isSearchingOrders) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                _showRadiusSelectionDialog();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isDarkMode
                    ? AppColors.yellowAccent.withOpacity(0.2)
                    : Colors.blue.withOpacity(0.1),
                foregroundColor:
                    isDarkMode ? AppColors.yellowAccent : Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
                side: BorderSide(
                  color: isDarkMode ? AppColors.yellowAccent : Colors.blue,
                  width: 1,
                ),
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              ),
              child: Text(
                'Increase Search Area',
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 14 : 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order, bool isTablet, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withOpacity(0.05)
            : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withOpacity(0.1)
              : Colors.blue.withOpacity(0.3),
          width: isDarkMode ? 1 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.customerName,
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 16 : 14,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          order.packageType,
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 12 : 10,
                            color: isDarkMode
                                ? Colors.white.withOpacity(0.7)
                                : Colors.grey.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: order.serviceType == 'shifting'
                                ? Colors.purple.withOpacity(0.2)
                                : Colors.blue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            order.serviceType == 'shifting' ? 'SHIFT' : 'P&D',
                            style: GoogleFonts.albertSans(
                              fontSize: isTablet ? 10 : 8,
                              fontWeight: FontWeight.bold,
                              color: order.serviceType == 'shifting'
                                  ? Colors.purple
                                  : Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Rs ${order.estimatedEarnings.toInt()}',
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 14 : 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildLocationRow(
            Icons.my_location,
            'Pickup',
            order.pickupAddress,
            Colors.blue,
            isTablet,
            isDarkMode,
          ),
          const SizedBox(height: 8),
          _buildLocationRow(
            Icons.location_on,
            'Drop-off',
            order.dropoffAddress,
            Colors.red,
            isTablet,
            isDarkMode,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.route,
                size: 16,
                color: isDarkMode
                    ? Colors.white.withOpacity(0.6)
                    : Colors.grey.withOpacity(0.8),
              ),
              const SizedBox(width: 8),
              Text(
                '${order.distance.toStringAsFixed(1)} km',
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 12 : 11,
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.7)
                      : Colors.grey.withOpacity(0.8),
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                Icons.access_time,
                size: 16,
                color: isDarkMode
                    ? Colors.white.withOpacity(0.6)
                    : Colors.grey.withOpacity(0.8),
              ),
              const SizedBox(width: 8),
              Text(
                '${DateTime.now().difference(order.createdAt).inMinutes} min ago',
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 12 : 11,
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.7)
                      : Colors.grey.withOpacity(0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _rejectOrder(order),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.1),
                    foregroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                    side: BorderSide(color: Colors.red.withOpacity(0.3)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'Reject',
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 14 : 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed:
                      _activeOrder != null ? null : () => _acceptOrder(order),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _activeOrder != null
                        ? Colors.grey.withOpacity(0.3)
                        : isDarkMode
                            ? AppColors.yellowAccent
                            : Colors.blue,
                    foregroundColor: _activeOrder != null
                        ? Colors.grey
                        : isDarkMode
                            ? Colors.black
                            : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    _activeOrder != null ? 'Busy' : 'Accept',
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 14 : 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow(
    IconData icon,
    String label,
    String address,
    Color iconColor,
    bool isTablet,
    bool isDarkMode,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: iconColor,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 12 : 10,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.8)
                      : Colors.grey.withOpacity(0.8),
                ),
              ),
              Text(
                address,
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 13 : 12,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrderPopup(bool isTablet, bool isDarkMode) {
    return Positioned(
      bottom: 250,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _popupSlideAnimation,
        child: FadeTransition(
          opacity: _popupOpacityAnimation,
          child: Container(
            padding: EdgeInsets.all(isTablet ? 20 : 16),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDarkMode ? AppColors.yellowAccent : Colors.blue,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${_currentPopupOrder!.distance.toStringAsFixed(1)} km',
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 16 : 14,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Text(
                          'Rs ${_currentPopupOrder!.estimatedEarnings.toInt()}',
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 18 : 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _popupTimeRemaining <= 5
                            ? Colors.red.withOpacity(0.1)
                            : isDarkMode
                                ? AppColors.yellowAccent.withOpacity(0.1)
                                : Colors.blue.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _popupTimeRemaining <= 5
                              ? Colors.red
                              : isDarkMode
                                  ? AppColors.yellowAccent
                                  : Colors.blue,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$_popupTimeRemaining',
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 16 : 14,
                            fontWeight: FontWeight.bold,
                            color: _popupTimeRemaining <= 5
                                ? Colors.red
                                : isDarkMode
                                    ? AppColors.yellowAccent
                                    : Colors.blue,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _currentPopupOrder!.customerName,
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                Text(
                  _currentPopupOrder!.packageType,
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 12 : 11,
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.7)
                        : Colors.grey.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () =>
                            _rejectOrder(_currentPopupOrder!, isPopup: true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDarkMode
                              ? const Color(0xFF4A2C2A)
                              : Colors.red.withOpacity(0.1),
                          foregroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                          side: BorderSide(color: Colors.red.withOpacity(0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          'Reject',
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 14 : 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () =>
                            _acceptOrder(_currentPopupOrder!, isPopup: true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isDarkMode ? AppColors.yellowAccent : Colors.blue,
                          foregroundColor:
                              isDarkMode ? Colors.black : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          'Accept',
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 14 : 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showOrderDetails(OrderModel order) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Consumer<ThemeService>(
        builder: (context, themeService, child) {
          final isDarkMode = themeService.isDarkMode;

          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.3)
                            : Colors.grey.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order Details',
                              style: GoogleFonts.albertSans(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildDetailRow(
                                'Customer', order.customerName, isDarkMode),
                            _buildDetailRow(
                                'Service Type',
                                order.serviceType == 'shifting'
                                    ? 'Shifting Service'
                                    : order.serviceType == 'pickup-drop'
                                        ? 'Pickup & Drop'
                                        : order.serviceType.toUpperCase(),
                                isDarkMode),
                            _buildDetailRow(
                                'Package Type', order.packageType, isDarkMode),
                            _buildDetailRow(
                                'Distance',
                                '${order.distance.toStringAsFixed(1)} km',
                                isDarkMode),
                            _buildDetailRow(
                                'Estimated Earnings',
                                'Rs ${order.estimatedEarnings.toInt()}',
                                isDarkMode),
                            _buildDetailRow('Order ID', order.id, isDarkMode),
                            _buildDetailRow('Status',
                                order.status.toUpperCase(), isDarkMode),
                            _buildDetailRow('Created',
                                _formatDateTime(order.createdAt), isDarkMode),
                            const SizedBox(height: 20),
                            Text(
                              'Locations',
                              style: GoogleFonts.albertSans(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildLocationRow(
                              Icons.my_location,
                              'Pickup',
                              order.pickupAddress,
                              Colors.blue,
                              false,
                              isDarkMode,
                            ),
                            const SizedBox(height: 12),
                            _buildLocationRow(
                              Icons.location_on,
                              'Drop-off',
                              order.dropoffAddress,
                              Colors.red,
                              false,
                              isDarkMode,
                            ),
                            const SizedBox(height: 30),
                            // Action buttons
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.pop(context);
                                      _rejectOrder(order);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: Colors.red.withOpacity(0.3)),
                                      ),
                                      child: Text(
                                        'Reject Order',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.albertSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.pop(context);
                                      _acceptOrder(order);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      decoration: BoxDecoration(
                                        color: isDarkMode
                                            ? AppColors.yellowAccent
                                            : Colors.blue,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: (isDarkMode
                                                    ? AppColors.yellowAccent
                                                    : Colors.blue)
                                                .withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        'Accept Order',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.albertSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: isDarkMode
                                              ? Colors.black
                                              : Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20), // Bottom padding
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.albertSans(
                fontSize: 14,
                color: isDarkMode
                    ? Colors.white.withOpacity(0.7)
                    : Colors.grey.withOpacity(0.8),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.albertSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} min ago';
    } else {
      return 'Just now';
    }
  }
}
