import 'dart:async';
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shiffters/theme/app_colors.dart';
import 'package:shiffters/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shiffters/services/theme_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class TrackScreen extends StatefulWidget {
  final Map<String, dynamic> orderData;

  const TrackScreen({super.key, required this.orderData});

  @override
  State<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends State<TrackScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // Google Maps API key for Directions API
  static const String _googleApiKey = 'AIzaSyDCWgFbqwajbUfBQY_greoV0Lvjny75Ue8';

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final TextEditingController _trackingController = TextEditingController();
  StreamSubscription<DocumentSnapshot>? _orderSubscription;
  StreamSubscription<DocumentSnapshot>? _driverSubscription;
  Map<String, dynamic>? _currentOrderData;
  Map<String, dynamic>? _driverData;
  Completer<GoogleMapController> _mapController = Completer();
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  LatLng? _driverLocation;
  LatLng? _pickupLocation;
  LatLng? _dropoffLocation;

  // Store route points for proper road following
  List<LatLng> _driverToPickupRoute = [];
  List<LatLng> _pickupToDestinationRoute = [];

  @override
  void initState() {
    super.initState();
    _currentOrderData = widget.orderData;
    _mapController = Completer<GoogleMapController>();
    _initializeAnimations();
    _startAnimations();
    _listenToOrderUpdates();
    _extractLocationsFromOrderData();
    _preloadMarkerIcons(); // Pre-load custom marker icons
  }

  // Pre-load marker icons for better performance
  void _preloadMarkerIcons() {
    _createPickupMarker();
    _createDestinationMarker();
    _createTruckMarker();
  }

  void _extractLocationsFromOrderData() {
    final orderData = _currentOrderData ?? widget.orderData;
    print("🔍 [Track Screen] Extracting locations from order data");

    // Extract pickup location
    if (orderData['pickupLocation'] != null) {
      final pickup = orderData['pickupLocation'];
      if (pickup['latitude'] != null && pickup['longitude'] != null) {
        _pickupLocation = LatLng(
          pickup['latitude'].toDouble(),
          pickup['longitude'].toDouble(),
        );
        print(
            "✅ [Track Screen] Pickup location: ${_pickupLocation!.latitude}, ${_pickupLocation!.longitude}");
      }
    }

    // Extract dropoff location
    if (orderData['dropoffLocation'] != null) {
      final dropoff = orderData['dropoffLocation'];
      if (dropoff['latitude'] != null && dropoff['longitude'] != null) {
        _dropoffLocation = LatLng(
          dropoff['latitude'].toDouble(),
          dropoff['longitude'].toDouble(),
        );
        print(
            "✅ [Track Screen] Dropoff location: ${_dropoffLocation!.latitude}, ${_dropoffLocation!.longitude}");
      }
    }

    _updateMarkers();
  }

  // Custom marker creation methods
  Future<BitmapDescriptor> _createPickupMarker() async {
    try {
      // Try to load the pickup icon from assets
      return await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(36, 36)), // Slightly smaller
        'assets/icons/pickup.png',
      );
    } catch (error) {
      debugPrint(
          'Could not load pickup marker asset, using green marker: $error');
      // Fallback to green marker for pickup location
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    }
  }

  Future<BitmapDescriptor> _createDestinationMarker() async {
    try {
      // Use red marker for destination instead of asset icon
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    } catch (error) {
      debugPrint(
          'Error creating destination marker, using default red: $error');
      // Fallback to default red marker
      return BitmapDescriptor.defaultMarker;
    }
  }

  Future<BitmapDescriptor> _createTruckMarker() async {
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

      return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
    } catch (error) {
      debugPrint(
          'Error creating custom truck marker, using orange marker: $error');
      // Fallback to orange marker if custom icon creation fails
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    }
  }

  void _updateMarkers() async {
    _markers.clear();
    _polylines.clear();
    print(
        "🎯 [Track Screen] Updating markers - Pickup: ${_pickupLocation != null}, Dropoff: ${_dropoffLocation != null}, Driver: ${_driverLocation != null}");

    // Add pickup location marker with custom icon
    if (_pickupLocation != null) {
      final pickupIcon = await _createPickupMarker();
      _markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: _pickupLocation!,
          icon: pickupIcon,
          infoWindow: const InfoWindow(
            title: '📦 Pickup Location',
            snippet: 'Items will be collected from here',
          ),
          anchor: const Offset(0.5, 1.0), // Position anchor at bottom center
        ),
      );
      print("✅ [Track Screen] Pickup marker added with custom icon");
    }

    // Add dropoff location marker with custom icon
    if (_dropoffLocation != null) {
      final destinationIcon = await _createDestinationMarker();
      _markers.add(
        Marker(
          markerId: const MarkerId('dropoff'),
          position: _dropoffLocation!,
          icon: destinationIcon,
          infoWindow: const InfoWindow(
            title: '🏠 Destination',
            snippet: 'Items will be delivered here',
          ),
          anchor: const Offset(0.5, 1.0), // Position anchor at bottom center
        ),
      );
      print("✅ [Track Screen] Destination marker added with custom icon");
    }

    // Add driver location marker with truck icon (most important)
    if (_driverLocation != null) {
      final truckIcon = await _createTruckMarker();
      _markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: _driverLocation!,
          icon: truckIcon,
          infoWindow: const InfoWindow(
            title: '🚚 Driver Location',
            snippet: 'Current driver position',
          ),
          anchor: const Offset(0.5, 0.5), // Center the truck icon
          rotation: 0.0, // You can add rotation based on driver direction
        ),
      );
      print(
          "✅ [Track Screen] Driver marker added with truck icon at: ${_driverLocation!.latitude}, ${_driverLocation!.longitude}");
    }

    // Add polylines using Google Directions API for road-following routes
    debugPrint('🗺️ Starting route fetching...');
    if (_driverLocation != null && _pickupLocation != null) {
      debugPrint('📍 Fetching driver to pickup route');
      await _fetchRoute(_driverLocation!, _pickupLocation!, true);
    }

    if (_pickupLocation != null && _dropoffLocation != null) {
      debugPrint('📍 Fetching pickup to destination route');
      await _fetchRoute(_pickupLocation!, _dropoffLocation!, false);
    }
    debugPrint('🗺️ Route fetching completed');

    // Add road-following polylines
    debugPrint(
        '📏 Driver to pickup route points: ${_driverToPickupRoute.length}');
    debugPrint(
        '📏 Pickup to destination route points: ${_pickupToDestinationRoute.length}');
    if (_driverToPickupRoute.isNotEmpty) {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('driverToPickup'),
          points: _driverToPickupRoute,
          color: Colors.blue,
          width: 4,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      );
      print(
          "✅ [Track Screen] Road-following polyline added from driver to pickup");
    }

    if (_pickupToDestinationRoute.isNotEmpty) {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('pickupToDestination'),
          points: _pickupToDestinationRoute,
          color: Colors.green,
          width: 4,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      );
      print(
          "✅ [Track Screen] Road-following polyline added from pickup to destination");
    }

    if (mounted) {
      setState(() {});
      print(
          "🔄 [Track Screen] Markers and polylines updated - Total markers: ${_markers.length}, Total polylines: ${_polylines.length}");
    }
  }

  // Fetch route using Google Directions API
  Future<void> _fetchRoute(
      LatLng origin, LatLng destination, bool isDriverToPickup) async {
    debugPrint(
        '🚗 Fetching route from ${origin.latitude},${origin.longitude} to ${destination.latitude},${destination.longitude}');
    debugPrint(
        '🚗 Route type: ${isDriverToPickup ? "Driver to Pickup" : "Pickup to Destination"}');

    try {
      final String url = 'https://maps.googleapis.com/maps/api/directions/json?'
          'origin=${origin.latitude},${origin.longitude}&'
          'destination=${destination.latitude},${destination.longitude}&'
          'key=$_googleApiKey&'
          'mode=driving&'
          'alternatives=false';

      final response = await http.get(Uri.parse(url));
      debugPrint('🌐 API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('📊 API Response Status: ${data['status']}');

        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final polylinePoints = route['overview_polyline']['points'];
          final List<LatLng> routePoints = _decodePolyline(polylinePoints);

          if (isDriverToPickup) {
            _driverToPickupRoute = routePoints;
            debugPrint(
                '✅ Driver to pickup route fetched: ${routePoints.length} points');
            debugPrint('First few points: ${routePoints.take(3).toList()}');
          } else {
            _pickupToDestinationRoute = routePoints;
            debugPrint(
                '✅ Pickup to destination route fetched: ${routePoints.length} points');
            debugPrint('First few points: ${routePoints.take(3).toList()}');
          }
        } else {
          debugPrint('❌ No routes found: ${data['status']}');
          if (data['error_message'] != null) {
            debugPrint('❌ API Error: ${data['error_message']}');
          }
          debugPrint('📊 Full API Response: $data');
          _fallbackToStraightLine(origin, destination, isDriverToPickup);
        }
      } else {
        debugPrint('❌ API request failed: ${response.statusCode}');
        debugPrint('❌ Response body: ${response.body}');
        _fallbackToStraightLine(origin, destination, isDriverToPickup);
      }
    } catch (e) {
      debugPrint('❌ Error fetching route: $e');
      _fallbackToStraightLine(origin, destination, isDriverToPickup);
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

  // Fallback to straight line if API fails
  void _fallbackToStraightLine(
      LatLng origin, LatLng destination, bool isDriverToPickup) {
    final straightLine = [origin, destination];

    if (isDriverToPickup) {
      _driverToPickupRoute = straightLine;
      debugPrint('⚠️ Using straight line for driver to pickup');
    } else {
      _pickupToDestinationRoute = straightLine;
      debugPrint('⚠️ Using straight line for pickup to destination');
    }
  }

  void _listenToOrderUpdates() {
    if (widget.orderData['id'] != null) {
      print(
          "🔄 [Track Screen] Setting up order listener for: ${widget.orderData['id']}");

      _orderSubscription = FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderData['id'])
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists && mounted) {
          final orderData = snapshot.data() as Map<String, dynamic>;
          setState(() {
            _currentOrderData = orderData;
            _currentOrderData!['id'] = snapshot.id;
          });

          print("📊 [Track Screen] Order data updated: ${orderData.keys}");

          // Extract all locations including driver location from order
          _extractLocationsFromOrderData();
          _extractDriverLocationFromOrder(orderData);

          // Still listen to driver updates for driver info (but not location)
          _listenToDriverUpdates();
        }
      }, onError: (error) {
        print("❌ [Track Screen] Error listening to order: $error");
      });
    }
  }

  // Extract driver location from order data (not driver collection)
  void _extractDriverLocationFromOrder(Map<String, dynamic> orderData) {
    print("🔍 [Track Screen] Checking for driverLocation in order data");

    // Check for driverLocation field in order document
    if (orderData['driverLocation'] != null) {
      final driverLocationData = orderData['driverLocation'];
      print("📍 [Track Screen] Found driverLocation: $driverLocationData");

      if (driverLocationData['latitude'] != null &&
          driverLocationData['longitude'] != null) {
        final newDriverLocation = LatLng(
          driverLocationData['latitude'].toDouble(),
          driverLocationData['longitude'].toDouble(),
        );

        setState(() {
          _driverLocation = newDriverLocation;
        });

        print(
            "✅ [Track Screen] Driver location updated: ${newDriverLocation.latitude}, ${newDriverLocation.longitude}");

        // Update markers with new driver location
        _updateMarkers();

        // Center map on driver location if available
        _animateMapToLocation(_driverLocation!, 15.0);
      } else {
        print(
            "⚠️ [Track Screen] driverLocation exists but missing coordinates");
      }
    } else {
      print("⚠️ [Track Screen] No driverLocation field found in order");
    }
  }

  void _listenToDriverUpdates() {
    final orderData = _currentOrderData ?? widget.orderData;
    final driverId = orderData['driverId'];

    if (driverId != null) {
      _driverSubscription?.cancel();
      _driverSubscription = FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists && mounted) {
          final driverData = snapshot.data() as Map<String, dynamic>;
          setState(() {
            _driverData = driverData;
          });

          print(
              "👤 [Track Screen] Driver data updated: ${driverData['name'] ?? 'Unknown driver'}");
        }
      }, onError: (error) {
        print("❌ [Track Screen] Error listening to driver: $error");
      });
    }
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
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
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _trackingController.dispose();
    _orderSubscription?.cancel();
    _driverSubscription?.cancel();
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
        final accent =
            isDarkMode ? AppColors.yellowAccent : AppTheme.lightPrimaryColor;

        return Scaffold(
          backgroundColor:
              isDarkMode ? const Color(0xFF1E1E2C) : Colors.grey[50],
          body: Column(
            children: [
              // Header
              _buildHeader(isTablet, isDarkMode, accent),

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 32 : 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),

                        // Search Bar
                        _buildSearchBar(isTablet, isDarkMode, accent),

                        const SizedBox(height: 24),

                        // Live Tracking Map
                        _buildDriverLocationMap(isTablet, isDarkMode, accent),

                        const SizedBox(height: 24),

                        // Current Package Tracking
                        _buildCurrentTracking(isTablet, isDarkMode, accent),

                        const SizedBox(height: 24),
                      ],
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

  Widget _buildHeader(bool isTablet, bool isDarkMode, Color accent) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDarkMode
                ? [
                    const Color(0xFF2D2D3C),
                    const Color(0xFF1E1E2C),
                  ]
                : [
                    const Color(0xFF1E88E5),
                    const Color(0xFF42A5F5),
                  ],
          ),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: isTablet ? 20 : 16),
            child: Row(
              children: [
                // Back button on the left side
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: isTablet ? 24 : 20,
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Title - Single text "Tracking Order"
                Text(
                  'Tracking Order',
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 28 : 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isTablet, bool isDarkMode, Color accent) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDarkMode
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
        ),
        child: TextFormField(
          controller: _trackingController,
          style: GoogleFonts.albertSans(
            fontSize: isTablet ? 16 : 14,
            color: isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: 'Enter tracking number',
            hintStyle: GoogleFonts.albertSans(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.6)
                  : Colors.black.withValues(alpha: 0.6),
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.7)
                  : Colors.black.withValues(alpha: 0.7),
              size: isTablet ? 24 : 20,
            ),
            suffixIcon: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                // Handle search
              },
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.arrow_forward,
                  color: isDarkMode ? Colors.black : Colors.white,
                  size: isTablet ? 20 : 18,
                ),
              ),
            ),
            filled: true,
            fillColor: isDarkMode
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.9),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: isDarkMode
                  ? BorderSide.none
                  : BorderSide(
                      color: accent.withValues(alpha: 0.3),
                      width: 1,
                    ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: isDarkMode
                  ? BorderSide.none
                  : BorderSide(
                      color: accent.withValues(alpha: 0.3),
                      width: 1,
                    ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: accent,
                width: 2,
              ),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: isTablet ? 20 : 16,
              vertical: isTablet ? 18 : 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTracking(bool isTablet, bool isDarkMode, Color accent) {
    final orderData = _currentOrderData ?? widget.orderData;
    final orderId = orderData['id'] ?? 'Unknown';
    final status = orderData['status'] ?? 'Unknown';

    // Extract real location data from Firebase
    String fromLocation = 'Unknown Location';
    String toLocation = 'Unknown Location';

    if (orderData['pickupLocation'] != null &&
        orderData['pickupLocation']['address'] != null) {
      fromLocation = orderData['pickupLocation']['address'];
    }

    if (orderData['dropoffLocation'] != null &&
        orderData['dropoffLocation']['address'] != null) {
      toLocation = orderData['dropoffLocation']['address'];
    }

    // Determine progress based on status
    final statusSteps = _getStatusSteps(status);

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(isTablet ? 24 : 20),
        decoration: BoxDecoration(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.2)
                : accent.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: isDarkMode
              ? null
              : [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Order #${orderId.length > 8 ? orderId.substring(0, 8).toUpperCase() : orderId.toUpperCase()}',
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 18 : 16,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _getStatusColor(status)),
                  ),
                  child: Text(
                    _getStatusText(status),
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 12 : 10,
                      fontWeight: FontWeight.w600,
                      color: _getStatusColor(status),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Order details from Firebase
            if (orderData['orderType'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Icon(
                      orderData['orderType'] == 'shifting'
                          ? Icons.home
                          : Icons.local_shipping,
                      size: 16,
                      color: accent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Service: ${orderData['orderType']?.toString().toUpperCase() ?? 'Unknown'}',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 12 : 10,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.8)
                            : Colors.black.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),

            if (orderData['totalAmount'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.attach_money,
                      size: 16,
                      color: accent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Total: PKR ${orderData['totalAmount']}',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 12 : 10,
                        fontWeight: FontWeight.w600,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),

            // From and To locations
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'From',
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 12 : 10,
                          fontWeight: FontWeight.w500,
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.7)
                              : Colors.black.withValues(alpha: 0.7),
                        ),
                      ),
                      Text(
                        fromLocation,
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 14 : 12,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward,
                  color: accent,
                  size: isTablet ? 20 : 18,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'To',
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 12 : 10,
                          fontWeight: FontWeight.w500,
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.7)
                              : Colors.black.withValues(alpha: 0.7),
                        ),
                      ),
                      Text(
                        toLocation,
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 14 : 12,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                        textAlign: TextAlign.right,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Tracking Steps
            ...statusSteps
                .map((step) => _buildTrackingStep(
                      title: step['title'],
                      subtitle: step['subtitle'],
                      time: step['time'],
                      isCompleted: step['isCompleted'],
                      isTablet: isTablet,
                      isDarkMode: isDarkMode,
                      accent: accent,
                      isLast: step == statusSteps.last,
                    ))
                .toList(),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getStatusSteps(String status) {
    final orderData = _currentOrderData ?? widget.orderData;
    final createdAt = orderData['createdAt'] as Timestamp?;
    final startedAt = orderData['startedAt'] as Timestamp?;
    final updatedAt = orderData['updatedAt'] as Timestamp?;

    final createdDate =
        createdAt != null ? _formatTimestamp(createdAt) : 'Unknown date';
    final startedDate =
        startedAt != null ? _formatTimestamp(startedAt) : 'Pending';
    final updatedDate =
        updatedAt != null ? _formatTimestamp(updatedAt) : 'Pending';

    switch (status.toLowerCase()) {
      case 'active':
        return [
          {
            'title': 'Order Placed',
            'subtitle': 'Order confirmed and active',
            'time': createdDate,
            'isCompleted': true,
          },
          {
            'title': 'Driver Assignment',
            'subtitle': 'Looking for available driver',
            'time': 'In Progress',
            'isCompleted': false,
          },
          {
            'title': 'Pickup',
            'subtitle': 'Driver will collect your items',
            'time': 'Pending',
            'isCompleted': false,
          },
          {
            'title': 'In Transit',
            'subtitle': 'Items on the way to destination',
            'time': 'Pending',
            'isCompleted': false,
          },
          {
            'title': 'Delivered',
            'subtitle': 'Items delivered successfully',
            'time': 'Pending',
            'isCompleted': false,
          },
          {
            'title': 'Completed',
            'subtitle': 'Order completed successfully',
            'time': 'Pending',
            'isCompleted': false,
          },
        ];
      case 'pending':
        return [
          {
            'title': 'Order Placed',
            'subtitle': 'Order confirmed and awaiting driver assignment',
            'time': createdDate,
            'isCompleted': true,
          },
          {
            'title': 'Driver Assigned',
            'subtitle': 'Looking for available driver',
            'time': 'Pending',
            'isCompleted': false,
          },
          {
            'title': 'Pickup',
            'subtitle': 'Driver will collect your items',
            'time': 'Pending',
            'isCompleted': false,
          },
          {
            'title': 'In Transit',
            'subtitle': 'Items on the way to destination',
            'time': 'Pending',
            'isCompleted': false,
          },
          {
            'title': 'Delivered',
            'subtitle': 'Items delivered successfully',
            'time': 'Pending',
            'isCompleted': false,
          },
          {
            'title': 'Completed',
            'subtitle': 'Order completed successfully',
            'time': 'Pending',
            'isCompleted': false,
          },
        ];
      case 'started':
        return [
          {
            'title': 'Order Placed',
            'subtitle': 'Order confirmed',
            'time': createdDate,
            'isCompleted': true,
          },
          {
            'title': 'Driver Assigned',
            'subtitle': 'Driver has been assigned to your order',
            'time': startedDate,
            'isCompleted': true,
          },
          {
            'title': 'En Route to Pickup',
            'subtitle': 'Driver is heading to pickup location',
            'time': 'Current',
            'isCompleted': true,
          },
          {
            'title': 'In Transit',
            'subtitle': 'Items will be collected and transported',
            'time': 'Pending',
            'isCompleted': false,
          },
          {
            'title': 'Delivered',
            'subtitle': 'Items delivered successfully',
            'time': 'Pending',
            'isCompleted': false,
          },
          {
            'title': 'Completed',
            'subtitle': 'Order completed successfully',
            'time': 'Pending',
            'isCompleted': false,
          },
        ];
      case 'picked_up':
      case 'in_transit':
        return [
          {
            'title': 'Order Placed',
            'subtitle': 'Order confirmed',
            'time': createdDate,
            'isCompleted': true,
          },
          {
            'title': 'Driver Assigned',
            'subtitle': 'Driver assigned to your order',
            'time': startedDate,
            'isCompleted': true,
          },
          {
            'title': 'Items Collected',
            'subtitle': 'Items picked up from location',
            'time': updatedDate,
            'isCompleted': true,
          },
          {
            'title': 'In Transit',
            'subtitle': 'Items on the way to destination',
            'time':
                status.toLowerCase() == 'in_transit' ? 'Current' : 'Current',
            'isCompleted': true,
          },
          {
            'title': 'Delivered',
            'subtitle': 'Items delivered successfully',
            'time': 'Pending',
            'isCompleted': false,
          },
          {
            'title': 'Completed',
            'subtitle': 'Order completed successfully',
            'time': 'Pending',
            'isCompleted': false,
          },
        ];
      case 'delivered':
        return [
          {
            'title': 'Order Placed',
            'subtitle': 'Order confirmed',
            'time': createdDate,
            'isCompleted': true,
          },
          {
            'title': 'Driver Assigned',
            'subtitle': 'Driver assigned to your order',
            'time': startedDate,
            'isCompleted': true,
          },
          {
            'title': 'Items Collected',
            'subtitle': 'Items picked up from location',
            'time': updatedDate,
            'isCompleted': true,
          },
          {
            'title': 'In Transit',
            'subtitle': 'Items were transported',
            'time': updatedDate,
            'isCompleted': true,
          },
          {
            'title': 'Delivered',
            'subtitle': 'Items delivered successfully',
            'time': updatedDate,
            'isCompleted': true,
          },
          {
            'title': 'Completed',
            'subtitle': 'Order completed successfully',
            'time': updatedDate,
            'isCompleted': true,
          },
        ];
      case 'completed':
        return [
          {
            'title': 'Order Placed',
            'subtitle': 'Order confirmed',
            'time': createdDate,
            'isCompleted': true,
          },
          {
            'title': 'Driver Assigned',
            'subtitle': 'Driver assigned to your order',
            'time': startedDate,
            'isCompleted': true,
          },
          {
            'title': 'Items Collected',
            'subtitle': 'Items picked up from location',
            'time': updatedDate,
            'isCompleted': true,
          },
          {
            'title': 'In Transit',
            'subtitle': 'Items were transported',
            'time': updatedDate,
            'isCompleted': true,
          },
          {
            'title': 'Delivered',
            'subtitle': 'Items delivered successfully',
            'time': updatedDate,
            'isCompleted': true,
          },
          {
            'title': 'Completed',
            'subtitle': 'Order completed successfully',
            'time': updatedDate,
            'isCompleted': true,
          },
        ];
      case 'cancelled':
        return [
          {
            'title': 'Order Placed',
            'subtitle': 'Order was placed',
            'time': createdDate,
            'isCompleted': true,
          },
          {
            'title': 'Order Cancelled',
            'subtitle': 'Order has been cancelled',
            'time': updatedDate,
            'isCompleted': true,
          },
        ];
      default:
        return [
          {
            'title': 'Order Status Unknown',
            'subtitle': 'Please contact support for assistance',
            'time': createdDate,
            'isCompleted': false,
          },
        ];
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'started':
        return Colors.blue;
      case 'picked_up':
      case 'in_transit':
        return Colors.indigo;
      case 'delivered':
        return Colors.green;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return 'Active';
      case 'pending':
        return 'Pending';
      case 'started':
        return 'Started';
      case 'picked_up':
        return 'Picked Up';
      case 'in_transit':
        return 'In Transit';
      case 'delivered':
        return 'Delivered';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  // Google Maps helper methods
  void _onMapCreated(GoogleMapController controller) {
    debugPrint('🗺️ Google Map created successfully in TrackScreen');
    _mapController.complete(controller);
  }

  Future<void> _animateMapToLocation(LatLng location, double zoom) async {
    try {
      final GoogleMapController controller = await _mapController.future;
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: location, zoom: zoom),
        ),
      );
    } catch (e) {
      debugPrint('Error animating map camera: $e');
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return 'Today ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  Widget _buildTrackingStep({
    required String title,
    required String subtitle,
    required String time,
    required bool isCompleted,
    required bool isTablet,
    required bool isDarkMode,
    required Color accent,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isCompleted
                    ? accent
                    : (isDarkMode
                        ? Colors.white.withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.3)),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCompleted
                      ? accent
                      : (isDarkMode
                          ? Colors.white.withValues(alpha: 0.5)
                          : Colors.black.withValues(alpha: 0.5)),
                  width: 2,
                ),
              ),
              child: isCompleted
                  ? Icon(
                      Icons.check,
                      size: 12,
                      color: isDarkMode ? Colors.black : Colors.white,
                    )
                  : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: isCompleted
                    ? accent
                    : (isDarkMode
                        ? Colors.white.withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.3)),
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 16 : 14,
                  fontWeight: FontWeight.w600,
                  color: isCompleted
                      ? (isDarkMode ? Colors.white : Colors.black)
                      : (isDarkMode
                          ? Colors.white.withValues(alpha: 0.7)
                          : Colors.black.withValues(alpha: 0.7)),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 14 : 12,
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.6)
                      : Colors.black.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                time,
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 12 : 11,
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.5)
                      : Colors.black.withValues(alpha: 0.5),
                ),
              ),
              if (!isLast) const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDriverLocationMap(bool isTablet, bool isDarkMode, Color accent) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        width: double.infinity,
        height: isTablet ? 500 : 400,
        decoration: BoxDecoration(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.2)
                : accent.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: isDarkMode
              ? null
              : [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.all(isTablet ? 24 : 20),
              child: Row(
                children: [
                  Icon(
                    Icons.map,
                    color: accent,
                    size: isTablet ? 24 : 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Live Tracking',
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 18 : 16,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  const Spacer(),
                  if (_driverLocation != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Live',
                            style: GoogleFonts.albertSans(
                              fontSize: isTablet ? 10 : 9,
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Driver Info Section
            if (_driverData != null)
              Container(
                margin: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 20),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: accent.withValues(alpha: 0.2),
                      child: Icon(
                        Icons.person,
                        color: accent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _driverData!['driverName'] ?? 'Driver',
                            style: GoogleFonts.albertSans(
                              fontSize: isTablet ? 14 : 12,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                          if (_driverData!['contactPhone'] != null)
                            Text(
                              _driverData!['contactPhone'],
                              style: GoogleFonts.albertSans(
                                fontSize: isTablet ? 12 : 10,
                                color: isDarkMode
                                    ? Colors.white.withValues(alpha: 0.7)
                                    : Colors.black.withValues(alpha: 0.7),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_driverData!['contactPhone'] != null)
                      GestureDetector(
                        onTap: () {
                          // Here you could implement calling functionality
                          HapticFeedback.lightImpact();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.phone,
                            color: Colors.green,
                            size: 20,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

            if (_driverData != null) const SizedBox(height: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                child: Stack(
                  children: [
                    _markers.isNotEmpty
                        ? GoogleMap(
                            onMapCreated: _onMapCreated,
                            initialCameraPosition: CameraPosition(
                              target: _getMapCenter(),
                              zoom: _getMapZoom(),
                            ),
                            markers: _markers,
                            polylines:
                                _polylines, // Use the road-following polylines
                            mapType: MapType.normal,
                            myLocationEnabled: false,
                            myLocationButtonEnabled: false,
                            zoomControlsEnabled: true, // Enable zoom controls
                            zoomGesturesEnabled: true, // Enable zoom gestures
                            scrollGesturesEnabled: true, // Enable pan gestures
                            rotateGesturesEnabled: true, // Enable rotation
                            tiltGesturesEnabled: true, // Enable tilt
                            compassEnabled: true,
                            mapToolbarEnabled: false,
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? Colors.grey[800]
                                  : Colors.grey[200],
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.location_off,
                                    size: isTablet ? 48 : 40,
                                    color: isDarkMode
                                        ? Colors.white.withValues(alpha: 0.5)
                                        : Colors.black.withValues(alpha: 0.5),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Location data not available',
                                    style: GoogleFonts.albertSans(
                                      fontSize: isTablet ? 16 : 14,
                                      color: isDarkMode
                                          ? Colors.white.withValues(alpha: 0.7)
                                          : Colors.black.withValues(alpha: 0.7),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Driver location will appear here once available',
                                    style: GoogleFonts.albertSans(
                                      fontSize: isTablet ? 12 : 10,
                                      color: isDarkMode
                                          ? Colors.white.withValues(alpha: 0.5)
                                          : Colors.black.withValues(alpha: 0.5),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                    // Full-screen button
                    if (_markers.isNotEmpty)
                      Positioned(
                        top: 16,
                        right: 16,
                        child: FloatingActionButton.small(
                          onPressed: () {
                            _showFullScreenMap(
                                context, isTablet, isDarkMode, accent);
                          },
                          backgroundColor:
                              isDarkMode ? Colors.grey[800] : Colors.white,
                          foregroundColor: accent,
                          elevation: 3,
                          child: const Icon(Icons.fullscreen),
                        ),
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

  LatLng _getMapCenter() {
    if (_driverLocation != null) {
      return _driverLocation!;
    } else if (_pickupLocation != null) {
      return _pickupLocation!;
    } else if (_dropoffLocation != null) {
      return _dropoffLocation!;
    }
    // Default to Islamabad, Pakistan
    return const LatLng(33.6844, 73.0479);
  }

  double _getMapZoom() {
    if (_markers.length <= 1) {
      return 15.0;
    }
    // If we have multiple markers, use a lower zoom to show all
    return 12.0;
  }

  void _showFullScreenMap(
      BuildContext context, bool isTablet, bool isDarkMode, Color accent) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            _FullScreenMapPage(
          markers: _markers,
          polylines: _polylines,
          pickupLocation: _pickupLocation,
          dropoffLocation: _dropoffLocation,
          accent: accent,
          isDarkMode: isDarkMode,
          onMapCreated: _onMapCreated,
          getMapCenter: _getMapCenter,
          getMapZoom: _getMapZoom,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: animation.drive(
              Tween(begin: const Offset(0.0, 1.0), end: Offset.zero)
                  .chain(CurveTween(curve: Curves.easeInOut)),
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }
}

class _FullScreenMapPage extends StatelessWidget {
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final LatLng? pickupLocation;
  final LatLng? dropoffLocation;
  final Color accent;
  final bool isDarkMode;
  final Function(GoogleMapController) onMapCreated;
  final LatLng Function() getMapCenter;
  final double Function() getMapZoom;

  const _FullScreenMapPage({
    required this.markers,
    required this.polylines,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.accent,
    required this.isDarkMode,
    required this.onMapCreated,
    required this.getMapCenter,
    required this.getMapZoom,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Live Tracking',
          style: GoogleFonts.albertSans(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: GoogleMap(
        onMapCreated: onMapCreated,
        initialCameraPosition: CameraPosition(
          target: getMapCenter(),
          zoom: getMapZoom(),
        ),
        markers: markers,
        polylines: polylines, // Use the road-following polylines
        mapType: MapType.normal,
        myLocationEnabled: false,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: true,
        zoomGesturesEnabled: true,
        scrollGesturesEnabled: true,
        rotateGesturesEnabled: true,
        tiltGesturesEnabled: true,
        compassEnabled: true,
        mapToolbarEnabled: false,
      ),
    );
  }
}
