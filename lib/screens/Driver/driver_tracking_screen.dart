import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:shiffters/theme/app_colors.dart';
import 'package:shiffters/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shiffters/services/theme_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:math' as math;

// Google Maps support
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/gestures.dart';
import 'package:geolocator/geolocator.dart';

class DriverTrackingScreen extends StatefulWidget {
  final String? orderId;

  const DriverTrackingScreen({super.key, this.orderId});

  @override
  State<DriverTrackingScreen> createState() => _DriverTrackingScreenState();
}

class _DriverTrackingScreenState extends State<DriverTrackingScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // Google Maps API key for Directions API
  static const String _googleApiKey = 'AIzaSyDCWgFbqwajbUfBQY_greoV0Lvjny75Ue8';

  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;

  // Google Maps related variables
  Completer<GoogleMapController> _googleMapController = Completer();
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  LatLng? _currentDriverLocation;
  LatLng? _previousDriverLocation;
  LatLng? _pickupLocation;
  LatLng? _dropoffLocation;
  LatLng _defaultLocation = LatLng(31.5204, 74.3587); // Lahore, Pakistan
  bool _isLoadingRoute = false;
  bool _isTrackingLocation = false;
  bool _isFullScreenMap = false;
  bool _isFollowingDriver = true;
  double _currentBearing = 0.0;
  double _currentSpeed = 0.0;
  StreamSubscription<Position>? _positionSubscription;
  Timer? _locationUpdateTimer;

  // Store route points for road-following navigation
  List<LatLng> _navigationRoute = [];

  // Firebase data
  String _orderId = '';
  String _currentStatus = 'Loading...';
  String _currentLocation = 'Fetching location...';
  String _destination = 'Loading destination...';
  double _progressPercentage = 0.0;
  String _estimatedTime = '...';
  String _distanceRemaining = '...';
  String _currentJobId = 'Loading...';
  String _customerName = 'Loading...';

  // Loading states
  bool _isLoadingOrderData = true;
  StreamSubscription<DocumentSnapshot>? _orderSubscription;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
    _initializeOrderData();
    _startLocationTracking();
    _startLocationUpdateTimer();

    // Set system UI overlay style
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
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
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      _animationController.forward();
      _pulseController.repeat(reverse: true);
    }
  }

  void _initializeOrderData() {
    // Set the order ID from widget parameter or get from current active order
    _orderId = widget.orderId ?? '';

    if (_orderId.isNotEmpty) {
      _setupOrderListener();
    } else {
      _fetchActiveOrder();
    }
  }

  void _setupOrderListener() {
    print("🔄 [Driver Tracking] Setting up order listener for: $_orderId");

    _orderSubscription = FirebaseFirestore.instance
        .collection('orders')
        .doc(_orderId)
        .snapshots()
        .listen((DocumentSnapshot snapshot) {
      if (snapshot.exists && mounted) {
        _processOrderData(snapshot.data() as Map<String, dynamic>);
      } else {
        print("❌ [Driver Tracking] Order not found: $_orderId");
        if (mounted) {
          setState(() {
            _isLoadingOrderData = false;
            _currentStatus = 'Order Not Found';
          });
        }
      }
    }, onError: (error) {
      print("❌ [Driver Tracking] Error listening to order: $error");
      if (mounted) {
        setState(() {
          _isLoadingOrderData = false;
          _currentStatus = 'Error Loading Data';
        });
      }
    });
  }

  void _fetchActiveOrder() async {
    print("🔄 [Driver Tracking] Fetching active order for current driver");

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print("❌ [Driver Tracking] No user logged in");
        setState(() {
          _isLoadingOrderData = false;
          _currentStatus = 'Not Logged In';
        });
        return;
      }

      // Find active order for current driver
      final QuerySnapshot activeOrders = await FirebaseFirestore.instance
          .collection('orders')
          .where('driverId', isEqualTo: user.uid)
          .where('status',
              whereIn: ['started', 'in_progress', 'picked_up', 'in_transit'])
          .limit(1)
          .get();

      if (activeOrders.docs.isNotEmpty) {
        final orderDoc = activeOrders.docs.first;
        _orderId = orderDoc.id;
        _setupOrderListener();
        print("✅ [Driver Tracking] Found active order: $_orderId");
      } else {
        print("⚠️ [Driver Tracking] No active order found");
        setState(() {
          _isLoadingOrderData = false;
          _currentStatus = 'No Active Order';
        });
      }
    } catch (e) {
      print("❌ [Driver Tracking] Error fetching active order: $e");
      setState(() {
        _isLoadingOrderData = false;
        _currentStatus = 'Error Fetching Order';
      });
    }
  }

  void _processOrderData(Map<String, dynamic> orderData) async {
    print("📊 [Driver Tracking] Processing order data: ${orderData.keys}");

    if (!mounted) return;

    // Extract basic order details first
    final String rawStatus =
        orderData['status']?.toString().toLowerCase() ?? 'unknown';
    final String customerUid = orderData['uid'] ?? '';

    setState(() {
      _isLoadingOrderData = false;

      // Extract order details
      _currentJobId = _orderId;

      // Map status to display format
      _currentStatus = _mapStatusToDisplay(rawStatus);

      // Extract addresses
      final Map<String, dynamic>? pickupLocation = orderData['pickupLocation'];
      final Map<String, dynamic>? dropoffLocation =
          orderData['dropoffLocation'];

      _currentLocation = pickupLocation?['address'] ?? 'Pickup location';
      _destination = dropoffLocation?['address'] ?? 'Dropoff location';

      // Calculate progress based on status
      _progressPercentage = _calculateProgress(rawStatus);

      // Extract or calculate estimated time and distance
      _estimatedTime = orderData['estimatedTime']?.toString() ??
          _calculateEstimatedTime(rawStatus);

      // Get actual distance from Firebase distance field
      final dynamic distanceValue = orderData['distance'];
      print(
          "🔍 [Driver Tracking] Distance field from Firebase: $distanceValue (type: ${distanceValue.runtimeType})");

      if (distanceValue != null) {
        if (distanceValue is String) {
          _distanceRemaining = distanceValue;
        } else if (distanceValue is num) {
          // Format the number to show as km
          _distanceRemaining = '${distanceValue.toStringAsFixed(1)} km';
        } else {
          _distanceRemaining = distanceValue.toString();
        }
      } else {
        // Fallback to calculated distance if no distance field
        _distanceRemaining = _calculateDistance(rawStatus);
      }
    });

    // Extract and setup locations for navigation
    _extractLocationsFromOrder(orderData);

    // Fetch customer details from users collection using UID
    if (customerUid.isNotEmpty) {
      try {
        print(
            "🔍 [Driver Tracking] Fetching customer details for UID: $customerUid");

        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(customerUid)
            .get();

        if (userDoc.exists && mounted) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final customerName =
              userData['name'] ?? userData['fullName'] ?? 'Unknown Customer';

          setState(() {
            _customerName = customerName;
          });

          print(
              "✅ [Driver Tracking] Customer details fetched - Name: $customerName");
        } else {
          print(
              "⚠️ [Driver Tracking] User document not found for UID: $customerUid");
          // Fallback to order data if available
          setState(() {
            _customerName = orderData['customerName'] ?? 'Unknown Customer';
          });
        }
      } catch (e) {
        print("❌ [Driver Tracking] Error fetching customer details: $e");
        // Fallback to order data if available
        if (mounted) {
          setState(() {
            _customerName = orderData['customerName'] ?? 'Unknown Customer';
          });
        }
      }
    } else {
      print(
          "⚠️ [Driver Tracking] No UID found in order data, using fallback customer info");
      // Fallback to order data if no UID
      setState(() {
        _customerName = orderData['customerName'] ?? 'Unknown Customer';
      });
    }

    print(
        "✅ [Driver Tracking] Order data processed - Status: $_currentStatus, Progress: ${(_progressPercentage * 100).toInt()}%, Distance: $_distanceRemaining");
  }

  String _mapStatusToDisplay(String status) {
    switch (status) {
      case 'started':
      case 'accepted':
        return 'Started';
      case 'picked_up':
        return 'Picked Up';
      case 'in_progress':
      case 'in_transit':
        return 'In Transit';
      case 'delivered':
      case 'completed':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  double _calculateProgress(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'pending':
        return 0.0; // 0%
      case 'started':
      case 'accepted':
        return 0.25; // 25%
      case 'picked_up':
      case 'pickedup':
        return 0.50; // 50%
      case 'in_progress':
      case 'in_transit':
      case 'in transit':
        return 0.75; // 75%
      case 'delivered':
      case 'completed':
        return 1.0; // 100%
      case 'cancelled':
        return 0.0; // 0% for cancelled orders
      default:
        return 0.0; // Default to 0%
    }
  }

  String _calculateEstimatedTime(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'pending':
        return '30-45 mins';
      case 'started':
      case 'accepted':
        return '20-30 mins';
      case 'picked_up':
      case 'pickedup':
        return '15-20 mins';
      case 'in_progress':
      case 'in_transit':
      case 'in transit':
        return '5-10 mins';
      case 'delivered':
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return '20-30 mins';
    }
  }

  String _calculateDistance(String status) {
    switch (status) {
      case 'started':
      case 'accepted':
        return '5-8 km';
      case 'picked_up':
        return '3-5 km';
      case 'in_progress':
      case 'in_transit':
        return '1-3 km';
      case 'delivered':
      case 'completed':
        return '0 km';
      default:
        return 'Unknown';
    }
  }

  // Start real-time location tracking
  void _startLocationTracking() async {
    setState(() {
      _isTrackingLocation = true;
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('⚠️ [Driver Tracking] Location services are disabled');
        return;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('⚠️ [Driver Tracking] Location permissions denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('⚠️ [Driver Tracking] Location permissions permanently denied');
        return;
      }

      // Get initial position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );

      setState(() {
        _currentDriverLocation = LatLng(position.latitude, position.longitude);
        _currentSpeed = position.speed * 3.6; // Convert m/s to km/h
        _currentBearing = position.heading;
      });

      print(
          '✅ [Driver Tracking] Initial location: ${position.latitude}, ${position.longitude}, Speed: ${_currentSpeed.toStringAsFixed(1)} km/h, Bearing: ${_currentBearing.toStringAsFixed(1)}°');

      // Start listening to position updates with high accuracy for navigation
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 5, // Update every 5 meters for smoother tracking
          timeLimit: Duration(seconds: 10), // Timeout after 10 seconds
        ),
      ).listen((Position position) {
        if (mounted) {
          _updateDriverLocationAndCamera(position);
        }
      });
    } catch (e) {
      print('❌ [Driver Tracking] Error setting up location tracking: $e');
    }
  }

  // Update driver location and smoothly animate camera
  void _updateDriverLocationAndCamera(Position position) async {
    // Store previous location for bearing calculation
    _previousDriverLocation = _currentDriverLocation;

    final newLocation = LatLng(position.latitude, position.longitude);

    // Calculate bearing if we have previous location
    double newBearing = _currentBearing;
    if (_previousDriverLocation != null) {
      newBearing = Geolocator.bearingBetween(
        _previousDriverLocation!.latitude,
        _previousDriverLocation!.longitude,
        position.latitude,
        position.longitude,
      );
    } else if (position.heading >= 0) {
      newBearing = position.heading;
    }

    setState(() {
      _currentDriverLocation = newLocation;
      _currentSpeed = position.speed * 3.6; // Convert m/s to km/h
      _currentBearing = newBearing;
    });

    // Update markers
    _updateMarkersAndRoute();

    // Smooth camera animation following the driver (like Google Maps)
    if (_isFollowingDriver && _googleMapController.isCompleted) {
      try {
        final GoogleMapController controller =
            await _googleMapController.future;

        // Smooth camera animation to follow driver with bearing
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: newLocation,
              zoom: 18.0, // Higher zoom for navigation
              bearing: newBearing, // Rotate map based on driver direction
              tilt: 45.0, // Slight tilt for 3D effect
            ),
          ),
        );
      } catch (e) {
        print('⚠️ [Driver Tracking] Error animating camera: $e');
      }
    }

    // Draw updated route
    _drawRoute();

    print(
        '📍 [Driver Tracking] Location updated: ${position.latitude}, ${position.longitude}, Speed: ${_currentSpeed.toStringAsFixed(1)} km/h, Bearing: ${newBearing.toStringAsFixed(1)}°');
  }

  // Start location update timer (every 5 minutes)
  void _startLocationUpdateTimer() {
    _locationUpdateTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _updateDriverLocationInFirebase();
    });
  }

  // Update driver location in Firebase
  Future<void> _updateDriverLocationInFirebase() async {
    if (_currentDriverLocation == null || _orderId.isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(_orderId)
          .update({
        'driverLocation': {
          'latitude': _currentDriverLocation!.latitude,
          'longitude': _currentDriverLocation!.longitude,
          'timestamp': FieldValue.serverTimestamp(),
        },
      });
      print('✅ [Driver Tracking] Location updated in Firebase');
    } catch (e) {
      print('❌ [Driver Tracking] Error updating location in Firebase: $e');
    }
  }

  // Extract locations from order data and update map
  void _extractLocationsFromOrder(Map<String, dynamic> orderData) {
    try {
      // Extract pickup location
      final pickupLocationData =
          orderData['pickupLocation'] as Map<String, dynamic>?;
      if (pickupLocationData != null) {
        final pickupLat = pickupLocationData['latitude'] as double?;
        final pickupLng = pickupLocationData['longitude'] as double?;
        if (pickupLat != null && pickupLng != null) {
          _pickupLocation = LatLng(pickupLat, pickupLng);
          print('✅ [Driver Tracking] Pickup location: $pickupLat, $pickupLng');
        }
      }

      // Extract dropoff location
      final dropoffLocationData =
          orderData['dropoffLocation'] as Map<String, dynamic>?;
      if (dropoffLocationData != null) {
        final dropoffLat = dropoffLocationData['latitude'] as double?;
        final dropoffLng = dropoffLocationData['longitude'] as double?;
        if (dropoffLat != null && dropoffLng != null) {
          _dropoffLocation = LatLng(dropoffLat, dropoffLng);
          print(
              '✅ [Driver Tracking] Dropoff location: $dropoffLat, $dropoffLng');
        }
      }

      // Update markers and route
      _updateMarkersAndRoute();
      _drawRoute();
    } catch (e) {
      print('❌ [Driver Tracking] Error extracting locations: $e');
    }
  }

  // Update markers based on current order status
  void _updateMarkersAndRoute() {
    _markers.clear();

    // Add driver location marker with rotation
    if (_currentDriverLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: _currentDriverLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(
            title: 'Driver Location',
            snippet: 'Speed: ${_currentSpeed.toStringAsFixed(1)} km/h',
          ),
          rotation: _currentBearing, // Rotate marker based on bearing
          anchor: const Offset(0.5, 0.5), // Center the marker
          onTap: () async {
            if (_googleMapController.isCompleted) {
              final GoogleMapController controller =
                  await _googleMapController.future;
              await controller.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(
                    target: _currentDriverLocation!,
                    zoom: 18.0,
                    bearing: _currentBearing,
                    tilt: 45.0,
                  ),
                ),
              );
            }
          },
        ),
      );
    }

    // Add pickup location marker (if not picked up yet)
    if (_pickupLocation != null &&
        (_currentStatus == 'Started' || _currentStatus == 'Loading...')) {
      _markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: _pickupLocation!,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Pickup Location'),
        ),
      );
    }

    // Add dropoff location marker
    if (_dropoffLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('dropoff'),
          position: _dropoffLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Drop-off Location'),
        ),
      );
    }
  }

  // Draw route between locations using Google Directions API
  Future<void> _drawRoute() async {
    if (_currentDriverLocation == null) return;

    LatLng? destination;

    // Determine destination based on order status
    if (_currentStatus == 'Started' && _pickupLocation != null) {
      destination = _pickupLocation; // Navigate to pickup
    } else if ((_currentStatus == 'Picked Up' ||
            _currentStatus == 'In Transit') &&
        _dropoffLocation != null) {
      destination = _dropoffLocation; // Navigate to dropoff
    }

    if (destination == null) return;

    setState(() {
      _isLoadingRoute = true;
    });

    try {
      // Fetch route using Google Directions API
      await _fetchNavigationRoute(_currentDriverLocation!, destination);

      // Create polyline using the fetched route points
      _polylines.clear();
      if (_navigationRoute.isNotEmpty) {
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('navigation_route'),
            points: _navigationRoute,
            color: Colors.blue,
            width: 5,
            patterns: [],
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
        );
        print(
            '✅ [Driver Tracking] Road-following route drawn with ${_navigationRoute.length} points');
      } else {
        // Fallback to straight line if no route points
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('direct_route'),
            points: [_currentDriverLocation!, destination],
            color: Colors.blue,
            width: 5,
            patterns: [],
          ),
        );
        print('⚠️ [Driver Tracking] Using direct route as fallback');
      }
    } catch (e) {
      print('⚠️ [Driver Tracking] Error drawing route: $e');
    }

    setState(() {
      _isLoadingRoute = false;
    });

    // Fit map to show the route
    _fitMapToRoute();
  }

  // Fetch navigation route using Google Directions API
  Future<void> _fetchNavigationRoute(LatLng origin, LatLng destination) async {
    try {
      final String url = 'https://maps.googleapis.com/maps/api/directions/json?'
          'origin=${origin.latitude},${origin.longitude}&'
          'destination=${destination.latitude},${destination.longitude}&'
          'key=$_googleApiKey&'
          'mode=driving&'
          'alternatives=false';

      debugPrint(
          '🚗 [Driver Tracking] Fetching navigation route from ${origin.latitude},${origin.longitude} to ${destination.latitude},${destination.longitude}');

      final response = await http.get(Uri.parse(url));
      debugPrint(
          '🌐 [Driver Tracking] API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint(
            '📊 [Driver Tracking] API Response Status: ${data['status']}');

        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final polylinePoints = route['overview_polyline']['points'];
          final List<LatLng> routePoints = _decodePolyline(polylinePoints);

          _navigationRoute = routePoints;
          debugPrint(
              '✅ [Driver Tracking] Navigation route fetched: ${routePoints.length} points');
          debugPrint('First few points: ${routePoints.take(3).toList()}');
        } else {
          debugPrint('❌ [Driver Tracking] No routes found: ${data['status']}');
          if (data['error_message'] != null) {
            debugPrint(
                '❌ [Driver Tracking] API Error: ${data['error_message']}');
          }
          _navigationRoute = [origin, destination]; // Fallback to straight line
        }
      } else {
        debugPrint(
            '❌ [Driver Tracking] API request failed: ${response.statusCode}');
        debugPrint('❌ [Driver Tracking] Response body: ${response.body}');
        _navigationRoute = [origin, destination]; // Fallback to straight line
      }
    } catch (e) {
      debugPrint('❌ [Driver Tracking] Error fetching navigation route: $e');
      _navigationRoute = [origin, destination]; // Fallback to straight line
    }
  }

  // Decode Google polyline format
  List<LatLng> _decodePolyline(String polyline) {
    List<LatLng> points = [];
    int index = 0;
    int len = polyline.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;
      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }

  // Fit map to show the route
  Future<void> _fitMapToRoute() async {
    if (_currentDriverLocation == null) return;

    try {
      final GoogleMapController controller = await _googleMapController.future;

      LatLngBounds bounds;
      if (_pickupLocation != null || _dropoffLocation != null) {
        List<LatLng> points = [_currentDriverLocation!];
        if (_pickupLocation != null) points.add(_pickupLocation!);
        if (_dropoffLocation != null) points.add(_dropoffLocation!);

        double minLat = points.first.latitude;
        double maxLat = points.first.latitude;
        double minLng = points.first.longitude;
        double maxLng = points.first.longitude;

        for (LatLng point in points) {
          minLat = math.min(minLat, point.latitude);
          maxLat = math.max(maxLat, point.latitude);
          minLng = math.min(minLng, point.longitude);
          maxLng = math.max(maxLng, point.longitude);
        }

        bounds = LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        );

        await controller.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 100.0),
        );
      }
    } catch (e) {
      print('⚠️ [Driver Tracking] Error fitting map to route: $e');
    }
  }

  // Center map on driver's current location
  Future<void> _centerOnLocation() async {
    if (_currentDriverLocation != null) {
      try {
        final GoogleMapController controller =
            await _googleMapController.future;
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(_currentDriverLocation!, 15.0),
        );
        print('✅ [Driver Tracking] Map centered on driver location');
      } catch (e) {
        print('⚠️ [Driver Tracking] Error centering map: $e');
      }
    }
  }

  // Center map on driver's current location with bearing and navigation view
  Future<void> _centerOnDriverWithBearing() async {
    if (_currentDriverLocation != null) {
      try {
        final GoogleMapController controller =
            await _googleMapController.future;
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: _currentDriverLocation!,
              zoom: 18.0,
              bearing: _currentBearing,
              tilt: 45.0,
            ),
          ),
        );
        print(
            '✅ [Driver Tracking] Map centered on driver with bearing: ${_currentBearing.toStringAsFixed(1)}°');
      } catch (e) {
        print('⚠️ [Driver Tracking] Error centering map with bearing: $e');
      }
    }
  }

  // Open external navigation app
  void _openNavigation() async {
    LatLng? destination;
    String destinationName = '';

    // Determine destination based on order status
    if (_currentStatus == 'Started' && _pickupLocation != null) {
      destination = _pickupLocation;
      destinationName = 'Pickup Location';
    } else if ((_currentStatus == 'Picked Up' ||
            _currentStatus == 'In Transit') &&
        _dropoffLocation != null) {
      destination = _dropoffLocation;
      destinationName = 'Delivery Location';
    }

    if (destination == null) {
      // Show snackbar if no destination available
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No navigation destination available'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      // Show navigation coordinates and open Google Maps in browser
      final String googleMapsUrl =
          'https://www.google.com/maps/dir/?api=1&destination=${destination.latitude},${destination.longitude}&travelmode=driving';

      // Show coordinates to driver
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Navigate to $destinationName:'),
                Text('${destination.latitude}, ${destination.longitude}'),
                Text('Google Maps URL: $googleMapsUrl'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Copy URL',
              textColor: Colors.white,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: googleMapsUrl));
              },
            ),
          ),
        );
      }

      print(
          '🧭 [Driver Tracking] Navigation URL for $destinationName: $googleMapsUrl');
    } catch (e) {
      print('❌ [Driver Tracking] Error opening navigation: $e');
    }
  }

  @override
  void dispose() {
    _orderSubscription?.cancel();
    _positionSubscription?.cancel();
    _locationUpdateTimer?.cancel();
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        final isDarkMode = themeService.isDarkMode;

        return Scaffold(
          backgroundColor: isDarkMode
              ? const Color(0xFF1E1E2C)
              : AppTheme.lightBackgroundColor,
          body: Column(
            children: [
              // Header
              _buildHeader(isTablet, isDarkMode),

              // Content
              Expanded(
                child: SafeArea(
                  top: false,
                  child: _isLoadingOrderData
                      ? _buildLoadingState(isTablet, isDarkMode)
                      : SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 32 : 20,
                            ),
                            child: Column(
                              children: [
                                const SizedBox(height: 24),

                                // Map view
                                _buildMapView(isTablet, isDarkMode),

                                const SizedBox(height: 24),

                                // Bottom info panel
                                _buildBottomPanel(isTablet, isDarkMode),

                                const SizedBox(height: 100),
                              ],
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

  Widget _buildLoadingState(bool isTablet, bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: isTablet ? 60 : 50,
            height: isTablet ? 60 : 50,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                isDarkMode
                    ? AppColors.yellowAccent
                    : AppTheme.lightPrimaryColor,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading order details...',
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 18 : 16,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please wait while we fetch your order information',
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 14 : 12,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.7)
                  : AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isTablet, bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 20 : 16,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: isDarkMode
            ? const Color(0xFF2D2D3C)
            : Colors.white.withValues(alpha: 0.9),
        boxShadow: isDarkMode
            ? null
            : [
                BoxShadow(
                  color: AppColors.lightPrimary.withValues(alpha: 0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Back button
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.arrow_back_ios,
                  color: isDarkMode
                      ? Colors.white
                      : AppTheme.lightTextPrimaryColor,
                  size: isTablet ? 20 : 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Job info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Live Tracking',
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 28 : 24,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode
                          ? Colors.white
                          : AppTheme.lightTextPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Job #$_currentJobId',
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 14 : 12,
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.7)
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '• $_customerName',
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 14 : 12,
                          fontWeight: FontWeight.w500,
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.8)
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Status badge with pulse animation
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(_currentStatus)
                          .withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: _getStatusColor(_currentStatus), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: _getStatusColor(_currentStatus)
                              .withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      _currentStatus,
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 12 : 10,
                        fontWeight: FontWeight.w700,
                        color: _getStatusColor(_currentStatus),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapView(bool isTablet, bool isDarkMode) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        height: _isFullScreenMap
            ? MediaQuery.of(context).size.height
            : (isTablet ? 400 : 300),
        decoration: BoxDecoration(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : AppTheme.lightCardColor,
          borderRadius:
              _isFullScreenMap ? BorderRadius.zero : BorderRadius.circular(16),
          border: isDarkMode || _isFullScreenMap
              ? null
              : Border.all(
                  color: AppTheme.lightPrimaryColor,
                  width: 1.5,
                ),
          boxShadow: isDarkMode || _isFullScreenMap
              ? null
              : [
                  BoxShadow(
                    color: AppTheme.lightShadowMedium,
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius:
              _isFullScreenMap ? BorderRadius.zero : BorderRadius.circular(16),
          child: Stack(
            children: [
              // Google Map Widget
              GoogleMap(
                onMapCreated: (GoogleMapController controller) {
                  if (!_googleMapController.isCompleted) {
                    _googleMapController.complete(controller);
                  }
                  print('✅ [Driver Tracking] Google Maps created');
                },
                initialCameraPosition: CameraPosition(
                  target: _currentDriverLocation ?? _defaultLocation,
                  zoom: 18.0,
                  bearing: _currentBearing,
                  tilt: 45.0,
                ),
                markers: _markers,
                polylines: _polylines,
                mapType: MapType.normal,
                myLocationEnabled: false, // We'll show our own driver marker
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                compassEnabled: true,
                rotateGesturesEnabled: true,
                scrollGesturesEnabled: true,
                zoomGesturesEnabled: true,
                tiltGesturesEnabled: true,
                mapToolbarEnabled: false,
                trafficEnabled: true, // Show traffic for navigation
                buildingsEnabled: true,
                gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                  Factory<PanGestureRecognizer>(() => PanGestureRecognizer()),
                  Factory<ScaleGestureRecognizer>(
                      () => ScaleGestureRecognizer()),
                  Factory<TapGestureRecognizer>(() => TapGestureRecognizer()),
                  Factory<VerticalDragGestureRecognizer>(
                      () => VerticalDragGestureRecognizer()),
                  Factory<HorizontalDragGestureRecognizer>(
                      () => HorizontalDragGestureRecognizer()),
                },
                onCameraMove: (CameraPosition position) {
                  // Disable auto-follow if user manually moves the camera
                  if (_isFollowingDriver) {
                    final distance = Geolocator.distanceBetween(
                      position.target.latitude,
                      position.target.longitude,
                      _currentDriverLocation?.latitude ?? 0,
                      _currentDriverLocation?.longitude ?? 0,
                    );

                    // If user moves camera more than 100 meters away, stop auto-follow
                    if (distance > 100) {
                      setState(() {
                        _isFollowingDriver = false;
                      });
                    }
                  }
                },
              ),

              // Loading overlay
              if (_isLoadingRoute)
                Container(
                  color: Colors.black.withValues(alpha: 0.3),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),

              // Floating action buttons
              Positioned(
                top: _isFullScreenMap ? 50 : 16,
                right: 16,
                child: Column(
                  children: [
                    // Full screen toggle
                    _buildFloatingButton(
                      _isFullScreenMap
                          ? Icons.fullscreen_exit
                          : Icons.fullscreen,
                      isDarkMode
                          ? AppColors.yellowAccent
                          : AppTheme.lightPrimaryColor,
                      () {
                        setState(() {
                          _isFullScreenMap = !_isFullScreenMap;
                        });
                        HapticFeedback.lightImpact();
                      },
                      isTablet,
                      isDarkMode,
                    ),

                    const SizedBox(height: 12),

                    // Center on location
                    _buildFloatingButton(
                      Icons.my_location,
                      isDarkMode
                          ? AppColors.yellowAccent
                          : AppTheme.lightPrimaryColor,
                      () => _centerOnLocation(),
                      isTablet,
                      isDarkMode,
                    ),

                    const SizedBox(height: 12),

                    // Show full route
                    _buildFloatingButton(
                      Icons.zoom_out_map,
                      Colors.green,
                      () => _fitMapToRoute(),
                      isTablet,
                      isDarkMode,
                    ),

                    const SizedBox(height: 12),

                    // Toggle follow driver
                    _buildFloatingButton(
                      _isFollowingDriver
                          ? Icons.gps_fixed
                          : Icons.gps_not_fixed,
                      _isFollowingDriver ? Colors.green : Colors.grey,
                      () {
                        setState(() {
                          _isFollowingDriver = !_isFollowingDriver;
                        });
                        HapticFeedback.lightImpact();
                        if (_isFollowingDriver) {
                          _centerOnDriverWithBearing();
                        }
                      },
                      isTablet,
                      isDarkMode,
                    ),

                    const SizedBox(height: 12),

                    // Navigation
                    _buildFloatingButton(
                      Icons.navigation,
                      Colors.blue,
                      () => _openNavigation(),
                      isTablet,
                      isDarkMode,
                    ),
                  ],
                ),
              ),

              // Location tracking indicator
              if (_isTrackingLocation)
                Positioned(
                  top: _isFullScreenMap ? 100 : 16,
                  left: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // GPS Status
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.gps_fixed,
                                color: Colors.white, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              _isFollowingDriver
                                  ? 'Navigation Mode'
                                  : 'GPS Active',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Speed indicator
                      if (_currentSpeed > 0) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.speed,
                                  color: Colors.white, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                '${_currentSpeed.toStringAsFixed(1)} km/h',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingButton(IconData icon, Color color, VoidCallback onTap,
      bool isTablet, bool isDarkMode) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: isTablet ? 24 : 20,
        ),
      ),
    );
  }

  Widget _buildBottomPanel(bool isTablet, bool isDarkMode) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        padding: EdgeInsets.all(isTablet ? 24 : 20),
        decoration: BoxDecoration(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : AppTheme.lightCardColor,
          borderRadius: BorderRadius.circular(16),
          border: isDarkMode
              ? null
              : Border.all(
                  color: AppTheme.lightPrimaryColor,
                  width: 1.5,
                ),
          boxShadow: isDarkMode
              ? null
              : [
                  BoxShadow(
                    color: AppTheme.lightShadowMedium,
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress bar
            _buildProgressBar(isTablet, isDarkMode),

            const SizedBox(height: 20),

            // Current location
            _buildLocationInfo(isTablet, isDarkMode),

            const SizedBox(height: 20),

            // Destination info
            _buildDestinationInfo(isTablet, isDarkMode),

            const SizedBox(height: 20),

            // Stats row
            _buildStatsRow(isTablet, isDarkMode),

            const SizedBox(height: 20),

            // Action buttons
            _buildActionButtons(isTablet, isDarkMode),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(bool isTablet, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Delivery Progress',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 16 : 14,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : AppColors.textPrimary,
              ),
            ),
            Text(
              '${(_progressPercentage * 100).toInt()}%',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 14 : 12,
                fontWeight: FontWeight.w700,
                color: isDarkMode
                    ? AppColors.yellowAccent
                    : AppTheme.lightPrimaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: _progressPercentage,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    isDarkMode
                        ? AppColors.yellowAccent
                        : AppTheme.lightPrimaryColor,
                    isDarkMode
                        ? AppColors.yellowAccent.withValues(alpha: 0.7)
                        : AppTheme.lightPrimaryColor.withValues(alpha: 0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: isDarkMode
                        ? AppColors.yellowAccent.withValues(alpha: 0.3)
                        : AppTheme.lightPrimaryColor.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationInfo(bool isTablet, bool isDarkMode) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: isDarkMode
            ? null
            : Border.all(
                color: AppTheme.lightPrimaryColor,
                width: 1.5,
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pickup Location',
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 14 : 12,
              fontWeight: FontWeight.w600,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.8)
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Icon(
                      Icons.my_location,
                      color: Colors.green,
                      size: isTablet ? 20 : 18,
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _currentLocation,
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 14 : 12,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDestinationInfo(bool isTablet, bool isDarkMode) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: isDarkMode
            ? null
            : Border.all(
                color: AppTheme.lightPrimaryColor,
                width: 1.5,
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Destination',
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 14 : 12,
              fontWeight: FontWeight.w600,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.8)
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.location_on,
                color: Colors.red,
                size: isTablet ? 20 : 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _destination,
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 14 : 12,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(bool isTablet, bool isDarkMode) {
    return Row(
      children: [
        Expanded(
          child: _buildStatItem(
            'ETA',
            _estimatedTime,
            Icons.access_time,
            isDarkMode ? AppColors.yellowAccent : AppTheme.lightPrimaryColor,
            isTablet,
            isDarkMode,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatItem(
            'Distance',
            _distanceRemaining,
            Icons.straighten,
            Colors.blue,
            isTablet,
            isDarkMode,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatItem(
            'Speed',
            '${_currentSpeed.toStringAsFixed(1)} km/h',
            Icons.speed,
            _currentSpeed > 0 ? Colors.green : Colors.grey,
            isTablet,
            isDarkMode,
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String title, String value, IconData icon, Color color,
      bool isTablet, bool isDarkMode) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: isDarkMode
            ? null
            : Border.all(
                color: AppTheme.lightPrimaryColor,
                width: 1.5,
              ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: isTablet ? 24 : 20),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 12 : 10,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.7)
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 14 : 12,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isTablet, bool isDarkMode) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _updateStatus();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color:
              isDarkMode ? AppColors.yellowAccent : AppTheme.lightPrimaryColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: isDarkMode
                  ? AppColors.yellowAccent.withValues(alpha: 0.3)
                  : AppTheme.lightPrimaryColor.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          'Update Status',
          style: GoogleFonts.albertSans(
            fontSize: isTablet ? 14 : 12,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.black : Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Started':
        return isDarkMode ? AppColors.yellowAccent : Colors.blue;
      case 'In Transit':
        return isDarkMode ? AppColors.yellowAccent : AppTheme.lightPrimaryColor;
      case 'Delivered':
        return Colors.green;
      case 'Delayed':
        return Colors.orange;
      case 'Emergency':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _updateStatus() async {
    if (_orderId.isEmpty) {
      _showGlowingSnackBar(
        'No active order to update',
        Colors.red,
      );
      return;
    }

    try {
      // Show loading
      _showGlowingSnackBar(
        'Updating status...',
        isDarkMode ? AppColors.yellowAccent : AppTheme.lightPrimaryColor,
      );

      // Get current status and determine next status
      String nextStatus = _getNextStatus(_currentStatus);

      // Update Firebase
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(_orderId)
          .update({
        'status': nextStatus.toLowerCase().replaceAll(' ', '_'),
        'lastUpdated': FieldValue.serverTimestamp(),
        'statusUpdatedAt': FieldValue.serverTimestamp(),
      });

      _showGlowingSnackBar(
        'Status updated to $nextStatus',
        Colors.green,
      );

      // Trigger haptic feedback
      HapticFeedback.mediumImpact();
    } catch (e) {
      print("❌ [Driver Tracking] Error updating status: $e");
      _showGlowingSnackBar(
        'Failed to update status: $e',
        Colors.red,
      );
    }
  }

  String _getNextStatus(String currentStatus) {
    switch (currentStatus) {
      case 'Started':
        return 'Picked Up';
      case 'Picked Up':
        return 'In Transit';
      case 'In Transit':
        return 'Delivered';
      case 'Delivered':
        return 'Completed';
      default:
        return 'In Transit';
    }
  }

  void _showGlowingSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.albertSans(
            fontWeight: FontWeight.w500,
            color: Colors.white,
            shadows: [
              Shadow(
                offset: const Offset(0, 0),
                blurRadius: 10,
                color: Colors.white.withValues(alpha: 0.8),
              ),
              Shadow(
                offset: const Offset(0, 0),
                blurRadius: 20,
                color: Colors.white.withValues(alpha: 0.6),
              ),
              Shadow(
                offset: const Offset(0, 0),
                blurRadius: 30,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  bool get isDarkMode =>
      Provider.of<ThemeService>(context, listen: false).isDarkMode;
}
