import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:shiffters/theme/app_colors.dart';
import 'package:shiffters/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shiffters/services/theme_service.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
// Import latlong2 for conversion
import 'package:latlong2/latlong.dart' as latlong;

// Import your enter_route_screen
import 'enter_route_screen.dart';
// Import the new products_listing_screen
import 'product_listing.dart';

class AddLocationScreen extends StatefulWidget {
  const AddLocationScreen({super.key});

  @override
  State<AddLocationScreen> createState() => _AddLocationScreenState();
}

class _AddLocationScreenState extends State<AddLocationScreen>
    with TickerProviderStateMixin {
  Completer<GoogleMapController> _mapController = Completer();
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;

  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dropOffController = TextEditingController();
  final FocusNode _pickupFocusNode = FocusNode();
  final FocusNode _dropOffFocusNode = FocusNode();

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  LatLng? _pickupLocation;
  LatLng? _dropOffLocation;
  // Default to Pakistan (Lahore coordinates)
  LatLng _currentPosition = const LatLng(31.5204, 74.3587);

  bool _isLoadingRoute = false;
  bool _isGeocodingPickup = false;
  bool _isFetchingCurrentLocation = false;
  String _selectedField = '';
  double _currentZoom = 15.0;
  bool _shouldMoveMap = true;

  // Double tap detection variables
  int _tapCount = 0;
  DateTime? _lastTapTime;

  // Dark map style for Google Maps
  // Helper function to convert Google Maps LatLng to latlong2 LatLng
  latlong.LatLng? _convertToLatLong2(LatLng? googleLatLng) {
    if (googleLatLng == null) return null;
    return latlong.LatLng(googleLatLng.latitude, googleLatLng.longitude);
  }

  static const String _darkMapStyle = '''
    [
      {
        "elementType": "geometry",
        "stylers": [{"color": "#242f3e"}]
      },
      {
        "elementType": "labels.text.fill",
        "stylers": [{"color": "#746855"}]
      },
      {
        "elementType": "labels.text.stroke",
        "stylers": [{"color": "#242f3e"}]
      },
      {
        "featureType": "administrative.locality",
        "elementType": "labels.text.fill",
        "stylers": [{"color": "#d59563"}]
      },
      {
        "featureType": "poi",
        "elementType": "labels.text.fill",
        "stylers": [{"color": "#d59563"}]
      },
      {
        "featureType": "poi.park",
        "elementType": "geometry",
        "stylers": [{"color": "#263c3f"}]
      },
      {
        "featureType": "poi.park",
        "elementType": "labels.text.fill",
        "stylers": [{"color": "#6b9a76"}]
      },
      {
        "featureType": "road",
        "elementType": "geometry",
        "stylers": [{"color": "#38414e"}]
      },
      {
        "featureType": "road",
        "elementType": "geometry.stroke",
        "stylers": [{"color": "#212a37"}]
      },
      {
        "featureType": "road",
        "elementType": "labels.text.fill",
        "stylers": [{"color": "#9ca5b3"}]
      },
      {
        "featureType": "road.highway",
        "elementType": "geometry",
        "stylers": [{"color": "#746855"}]
      },
      {
        "featureType": "road.highway",
        "elementType": "geometry.stroke",
        "stylers": [{"color": "#1f2835"}]
      },
      {
        "featureType": "road.highway",
        "elementType": "labels.text.fill",
        "stylers": [{"color": "#f3d19c"}]
      },
      {
        "featureType": "transit",
        "elementType": "geometry",
        "stylers": [{"color": "#2f3948"}]
      },
      {
        "featureType": "transit.station",
        "elementType": "labels.text.fill",
        "stylers": [{"color": "#d59563"}]
      },
      {
        "featureType": "water",
        "elementType": "geometry",
        "stylers": [{"color": "#17263c"}]
      },
      {
        "featureType": "water",
        "elementType": "labels.text.fill",
        "stylers": [{"color": "#515c6d"}]
      },
      {
        "featureType": "water",
        "elementType": "labels.text.stroke",
        "stylers": [{"color": "#17263c"}]
      }
    ]
  ''';

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
    _getCurrentLocation();
    _setupTextFieldListeners();

    // Set system UI overlay style for proper theming
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            Brightness.dark, // Always dark for better visibility
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    // Using Google Maps for all platforms
    debugPrint(
        'Initialized AddLocationScreen with Google Maps for all platforms');
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 300),
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
      curve: Curves.elasticOut,
    ));
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) {
      _animationController.forward();
    }
  }

  void _setupTextFieldListeners() {
    // Remove the old listeners and replace with tap handlers
    _pickupFocusNode.addListener(() {
      if (_pickupFocusNode.hasFocus) {
        _pickupFocusNode.unfocus(); // Immediately unfocus
        _openEnterRouteScreen('pickup');
      }
    });

    _dropOffFocusNode.addListener(() {
      if (_dropOffFocusNode.hasFocus) {
        _dropOffFocusNode.unfocus(); // Immediately unfocus
        _openEnterRouteScreen('dropoff');
      }
    });
  }

  // Handle double tap on target icon
  void _handleTargetIconTap() {
    final now = DateTime.now();

    if (_lastTapTime != null &&
        now.difference(_lastTapTime!).inMilliseconds < 500) {
      _tapCount++;
    } else {
      _tapCount = 1;
    }

    _lastTapTime = now;

    // Trigger pulse animation
    _pulseController.forward().then((_) {
      _pulseController.reverse();
    });

    // Single tap: just show current location feedback
    if (_tapCount == 1) {
      HapticFeedback.lightImpact();
      // Set a timer to handle single tap if no second tap comes
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_tapCount == 1 &&
            _lastTapTime != null &&
            now.difference(_lastTapTime!).inMilliseconds >= 500) {
          _fetchCurrentLocationAndSetAsPickup();
          _tapCount = 0; // Reset tap count
        }
      });
    } else if (_tapCount >= 2) {
      // Double tap: immediately fetch location
      HapticFeedback.mediumImpact();
      _fetchCurrentLocationAndSetAsPickup();
      _tapCount = 0; // Reset tap count
    }
  }

  // Enhanced method to fetch actual current GPS location
  Future<void> _fetchCurrentLocationAndSetAsPickup() async {
    setState(() {
      _isFetchingCurrentLocation = true;
      _isGeocodingPickup = true;
    });

    try {
      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showLocationError(
              'Location permissions are denied. Please enable location access.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showLocationError(
            'Location permissions are permanently denied. Please enable them in settings.');
        return;
      }

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationError(
            'Location services are disabled. Please enable location services.');
        return;
      }

      // Get current position with high accuracy
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      // Check if location is within Pakistan bounds
      if (!_isLocationInPakistan(position.latitude, position.longitude)) {
        _showLocationError(
            'Current location is outside Pakistan. Please select a location within Pakistan.');
        return;
      }

      LatLng currentLocation = LatLng(position.latitude, position.longitude);

      // Get detailed address using enhanced reverse geocoding
      String detailedAddress =
          await _getDetailedCurrentLocationAddress(currentLocation);

      setState(() {
        _pickupLocation = currentLocation;
        _pickupController.text = detailedAddress;
        _currentPosition = currentLocation; // Update current position marker
      });

      // Add marker for pickup location
      _addMarker(_pickupLocation!, 'pickup', detailedAddress);

      // Move map to current location
      _moveMapToLocation(currentLocation, 16.0);

      // Show success feedback
      HapticFeedback.mediumImpact();
      _showSuccessMessage('Current location set as pickup successfully!');

      // Draw route if both locations are set
      if (_pickupLocation != null && _dropOffLocation != null) {
        _drawRoute();
      }
    } catch (e) {
      debugPrint('Error fetching current location: $e');
      String errorMessage = 'Failed to get current location';

      if (e is TimeoutException) {
        errorMessage = 'Location request timed out. Please try again.';
      } else if (e is LocationServiceDisabledException) {
        errorMessage = 'Location services are disabled. Please enable them.';
      } else if (e is PermissionDeniedException) {
        errorMessage =
            'Location permission denied. Please grant location access.';
      }

      _showLocationError(errorMessage);
    } finally {
      setState(() {
        _isFetchingCurrentLocation = false;
        _isGeocodingPickup = false;
      });
    }
  }

  // Enhanced reverse geocoding for detailed Pakistani addresses
  Future<String> _getDetailedCurrentLocationAddress(LatLng position) async {
    try {
      // Try multiple geocoding sources for best results
      List<String> addresses = [];

      // 1. Try Nominatim with detailed Pakistani formatting
      try {
        String nominatimAddress = await _getNominatimDetailedAddress(position);
        if (nominatimAddress.isNotEmpty &&
            nominatimAddress != 'Unknown Location') {
          addresses.add(nominatimAddress);
        }
      } catch (e) {
        debugPrint('Nominatim geocoding failed: $e');
      }

      // 2. Try Photon geocoding
      try {
        String photonAddress = await _getPhotonDetailedAddress(position);
        if (photonAddress.isNotEmpty && photonAddress != 'Unknown Location') {
          addresses.add(photonAddress);
        }
      } catch (e) {
        debugPrint('Photon geocoding failed: $e');
      }

      // 3. Fallback to local geocoding
      try {
        String localAddress = await _getLocalDetailedAddress(position);
        if (localAddress.isNotEmpty &&
            localAddress != 'Unknown Location, Pakistan') {
          addresses.add(localAddress);
        }
      } catch (e) {
        debugPrint('Local geocoding failed: $e');
      }

      // Return the most detailed address (usually the first successful one)
      if (addresses.isNotEmpty) {
        // Sort by length and detail level, prefer addresses with street numbers
        addresses.sort((a, b) {
          int aScore = _calculateAddressDetailScore(a);
          int bScore = _calculateAddressDetailScore(b);
          return bScore.compareTo(aScore); // Higher score first
        });

        return addresses.first;
      }

      return 'Current Location, Pakistan';
    } catch (e) {
      debugPrint('Error in detailed address lookup: $e');
      return 'Current Location, Pakistan';
    }
  }

  // Calculate address detail score for sorting
  int _calculateAddressDetailScore(String address) {
    int score = 0;
    String lowerAddress = address.toLowerCase();

    // Higher score for more detailed addresses
    if (RegExp(r'\d+').hasMatch(address))
      score += 3; // Has numbers (house/street numbers)
    if (lowerAddress.contains('street') || lowerAddress.contains('road'))
      score += 2;
    if (lowerAddress.contains('sector') ||
        RegExp(r'[a-z]-\d+').hasMatch(lowerAddress)) score += 2;
    if (lowerAddress.contains('block')) score += 1;
    if (lowerAddress.contains('phase')) score += 1;

    // Bonus for Pakistani sector patterns
    if (RegExp(r'[a-z]-\d+(/\d+)?', caseSensitive: false).hasMatch(address))
      score += 3;

    return score;
  }

  // Enhanced Nominatim reverse geocoding
  Future<String> _getNominatimDetailedAddress(LatLng position) async {
    final response = await http.get(
      Uri.parse('https://nominatim.openstreetmap.org/reverse?'
          'lat=${position.latitude}&'
          'lon=${position.longitude}&'
          'format=json&'
          'addressdetails=1&'
          'extratags=1&'
          'namedetails=1&'
          'zoom=18'),
      headers: {
        'User-Agent': 'ShifftersApp/1.0 (contact@shiffters.com)',
        'Accept-Language': 'en,ur',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['address'] != null) {
        return _formatEnhancedPakistaniAddress(data);
      }
    }

    throw Exception('Nominatim request failed');
  }

  // Photon reverse geocoding
  Future<String> _getPhotonDetailedAddress(LatLng position) async {
    final response = await http.get(
      Uri.parse('https://photon.komoot.io/reverse?'
          'lat=${position.latitude}&'
          'lon=${position.longitude}&'
          'limit=1&'
          'lang=en'),
      headers: {
        'User-Agent': 'ShifftersApp/1.0',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final features = data['features'] as List?;

      if (features != null && features.isNotEmpty) {
        final properties = features.first['properties'] ?? {};
        return _formatPhotonAddress(properties);
      }
    }

    throw Exception('Photon request failed');
  }

  // Local geocoding fallback
  Future<String> _getLocalDetailedAddress(LatLng position) async {
    List<Placemark> placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );

    if (placemarks.isNotEmpty) {
      Placemark place = placemarks.first;
      return _formatLocalPlacemark(place);
    }

    throw Exception('Local geocoding failed');
  }

  // Enhanced Pakistani address formatting
  String _formatEnhancedPakistaniAddress(Map<String, dynamic> data) {
    Map<String, dynamic> address = data['address'] ?? {};
    List<String> addressParts = [];

    // Add house number first if available
    if (address['house_number'] != null &&
        address['house_number'].toString().isNotEmpty) {
      addressParts.add(address['house_number'].toString());
    }

    // Add road/street name with various possible keys
    List<String> roadKeys = [
      'road',
      'pedestrian',
      'footway',
      'path',
      'cycleway',
      'street'
    ];
    for (String key in roadKeys) {
      if (address[key] != null && address[key].toString().isNotEmpty) {
        String roadName = address[key].toString();
        if (!addressParts
            .any((part) => part.toLowerCase() == roadName.toLowerCase())) {
          addressParts.add(roadName);
        }
        break;
      }
    }

    // Add area/locality details with priority
    List<String> areaKeys = [
      'suburb',
      'neighbourhood',
      'quarter',
      'residential',
      'commercial',
      'industrial'
    ];
    for (String key in areaKeys) {
      if (address[key] != null && address[key].toString().isNotEmpty) {
        String areaName = address[key].toString();
        if (!addressParts.any(
            (part) => part.toLowerCase().contains(areaName.toLowerCase()))) {
          addressParts.add(areaName);
        }
        break;
      }
    }

    // Add city/town with priority
    List<String> cityKeys = ['city', 'town', 'municipality', 'village'];
    for (String key in cityKeys) {
      if (address[key] != null && address[key].toString().isNotEmpty) {
        String cityName = address[key].toString();
        if (!addressParts.any(
            (part) => part.toLowerCase().contains(cityName.toLowerCase()))) {
          addressParts.add(cityName);
        }
        break;
      }
    }

    // Add district/county if different from city
    if (address['county'] != null && address['county'].toString().isNotEmpty) {
      String county = address['county'].toString();
      if (!addressParts
          .any((part) => part.toLowerCase().contains(county.toLowerCase()))) {
        addressParts.add(county);
      }
    }

    // Add province/state
    if (address['state'] != null && address['state'].toString().isNotEmpty) {
      addressParts.add(address['state'].toString());
    }

    // Always add Pakistan
    addressParts.add('Pakistan');

    // Remove duplicates while preserving order
    List<String> uniqueParts = [];
    for (String part in addressParts) {
      String cleaned = part.trim();
      if (cleaned.isNotEmpty &&
          !uniqueParts.any(
              (existing) => existing.toLowerCase() == cleaned.toLowerCase())) {
        uniqueParts.add(cleaned);
      }
    }

    return uniqueParts.join(', ');
  }

  // Format Photon address
  String _formatPhotonAddress(Map<String, dynamic> properties) {
    List<String> addressParts = [];

    // Add name if available
    if (properties['name'] != null &&
        properties['name'].toString().isNotEmpty) {
      addressParts.add(properties['name'].toString());
    }

    // Add street if available
    if (properties['street'] != null &&
        properties['street'].toString().isNotEmpty) {
      String street = properties['street'].toString();
      if (!addressParts
          .any((part) => part.toLowerCase() == street.toLowerCase())) {
        addressParts.add(street);
      }
    }

    // Add city
    if (properties['city'] != null &&
        properties['city'].toString().isNotEmpty) {
      addressParts.add(properties['city'].toString());
    }

    // Add state
    if (properties['state'] != null &&
        properties['state'].toString().isNotEmpty) {
      addressParts.add(properties['state'].toString());
    }

    // Add Pakistan
    addressParts.add('Pakistan');

    return addressParts.join(', ');
  }

  // Format local placemark
  String _formatLocalPlacemark(Placemark place) {
    List<String> addressParts = [];

    if (place.street != null && place.street!.isNotEmpty) {
      addressParts.add(place.street!);
    }
    if (place.subLocality != null && place.subLocality!.isNotEmpty) {
      addressParts.add(place.subLocality!);
    }
    if (place.locality != null && place.locality!.isNotEmpty) {
      addressParts.add(place.locality!);
    }
    if (place.administrativeArea != null &&
        place.administrativeArea!.isNotEmpty) {
      addressParts.add(place.administrativeArea!);
    }
    addressParts.add('Pakistan');

    return addressParts.join(', ');
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline,
                color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.albertSans(
                    color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showLocationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.albertSans(
                    color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // New method to open the enter route screen
  void _openEnterRouteScreen(String focusedField) async {
    HapticFeedback.lightImpact();

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EnterRouteScreen(
          initialPickupAddress:
              _pickupController.text.isNotEmpty ? _pickupController.text : null,
          initialDropOffAddress: _dropOffController.text.isNotEmpty
              ? _dropOffController.text
              : null,
          initialPickupLocation: _convertToLatLong2(_pickupLocation),
          initialDropOffLocation: _convertToLatLong2(_dropOffLocation),
        ),
      ),
    );

    if (result != null && mounted) {
      _handleRouteResult(result);
    }
  }

  // Handle the result from enter route screen
  void _handleRouteResult(Map<String, dynamic> result) {
    if (result['choose_on_map'] == true) {
      // User chose to select on map, update with any partial data
      if (result['pickup'] != null) {
        setState(() {
          _pickupController.text = result['pickup']['address'];
          _pickupLocation = result['pickup']['location'];
        });
        _addMarker(_pickupLocation!, 'pickup', result['pickup']['address']);
      }
      if (result['dropoff'] != null) {
        setState(() {
          _dropOffController.text = result['dropoff']['address'];
          _dropOffLocation = result['dropoff']['location'];
        });
        _addMarker(_dropOffLocation!, 'dropoff', result['dropoff']['address']);
      }
    } else {
      // User completed address entry
      if (result['pickup'] != null) {
        setState(() {
          _pickupController.text = result['pickup']['address'];
          _pickupLocation = result['pickup']['location'];
        });
        _addMarker(_pickupLocation!, 'pickup', result['pickup']['address']);
      }

      if (result['dropoff'] != null) {
        setState(() {
          _dropOffController.text = result['dropoff']['address'];
          _dropOffLocation = result['dropoff']['location'];
        });
        _addMarker(_dropOffLocation!, 'dropoff', result['dropoff']['address']);
      }

      // Draw route if both locations are set
      if (_pickupLocation != null && _dropOffLocation != null) {
        _drawRoute();
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    debugPrint('🌍 Getting current location...');
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      debugPrint('📍 Location permission status: $permission');
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        debugPrint('📍 Requested permission result: $permission');
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        debugPrint(
            '📍 Got position: ${position.latitude}, ${position.longitude}');

        // Check if current location is within Pakistan bounds
        if (_isLocationInPakistan(position.latitude, position.longitude)) {
          setState(() {
            _currentPosition = LatLng(position.latitude, position.longitude);
          });
        } else {
          // If outside Pakistan, use default Pakistan location (Lahore)
          setState(() {
            _currentPosition = LatLng(31.5204, 74.3587);
          });
        }

        if (_shouldMoveMap) {
          _moveMapToLocation(_currentPosition, 15.0);
        }
      }
    } catch (e) {
      // Handle location errors silently
      debugPrint('Location error: $e');
    }
  }

  // Check if coordinates are within Pakistan bounds
  bool _isLocationInPakistan(double lat, double lng) {
    // Pakistan approximate bounds
    const double northBound = 37.1;
    const double southBound = 23.6;
    const double eastBound = 77.8;
    const double westBound = 60.9;

    return lat >= southBound &&
        lat <= northBound &&
        lng >= westBound &&
        lng <= eastBound;
  }

  void _onMapCreated(GoogleMapController controller) {
    debugPrint('🗺️ Google Map created successfully in AddLocationScreen');
    _mapController.complete(controller);
  }

  Future<void> _moveMapToLocation(LatLng location, double zoom) async {
    final GoogleMapController controller = await _mapController.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: location, zoom: zoom),
      ),
    );
  }

  void _onMapTap(LatLng position) async {
    HapticFeedback.lightImpact();

    // Only allow tapping within Pakistan bounds
    if (!_isLocationInPakistan(position.latitude, position.longitude)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.orange.withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: [
              const Icon(Icons.warning_outlined, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Text(
                'Please select a location within Pakistan',
                style: GoogleFonts.albertSans(
                    color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    try {
      // Use reverse geocoding to get address
      String address = await _reverseGeocode(position);

      if (_selectedField == 'pickup') {
        setState(() {
          _pickupLocation = position;
          _pickupController.text = address;
          _shouldMoveMap = false; // Prevent map movement
        });
        _addMarker(position, 'pickup', address);
      } else if (_selectedField == 'dropoff') {
        setState(() {
          _dropOffLocation = position;
          _dropOffController.text = address;
          _shouldMoveMap = false; // Prevent map movement
        });
        _addMarker(position, 'dropoff', address);
      }

      // Draw route if both locations are set
      if (_pickupLocation != null && _dropOffLocation != null) {
        _drawRoute();
      }
    } catch (e) {
      debugPrint('Error getting address: $e');
    }
  }

  void _onMapLongPress(LatLng position) {
    HapticFeedback.mediumImpact();

    // Find and remove nearby marker
    Marker? markerToRemove;
    for (Marker marker in _markers) {
      double distance = Geolocator.distanceBetween(
        marker.position.latitude,
        marker.position.longitude,
        position.latitude,
        position.longitude,
      );

      if (distance < 100) {
        // Within 100 meters
        markerToRemove = marker;
        break;
      }
    }

    if (markerToRemove != null) {
      setState(() {
        _markers.remove(markerToRemove);
        _polylines.clear(); // Clear route when marker is removed

        if (markerToRemove!.markerId.value == 'pickup') {
          _pickupLocation = null;
          _pickupController.clear();
        } else if (markerToRemove.markerId.value == 'dropoff') {
          _dropOffLocation = null;
          _dropOffController.clear();
        }
      });

      // Redraw route if one location still exists
      if (_pickupLocation != null && _dropOffLocation != null) {
        _drawRoute();
      }

      // Show feedback
      final themeService = Provider.of<ThemeService>(context, listen: false);
      final isDarkMode = themeService.isDarkMode;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: isDarkMode
              ? const Color(0xFF2D2D3C)
              : AppTheme.lightTextPrimaryColor,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: [
              Icon(Icons.location_off,
                  color: isDarkMode
                      ? AppColors.yellowAccent
                      : AppTheme.lightPrimaryColor,
                  size: 20),
              const SizedBox(width: 12),
              Text(
                'Location marker removed',
                style: GoogleFonts.albertSans(
                    color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _drawRoute() async {
    if (_pickupLocation == null || _dropOffLocation == null) return;

    setState(() {
      _isLoadingRoute = true;
    });

    try {
      // Use OSRM (Open Source Routing Machine) for routing
      final response = await http.get(
        Uri.parse(
            'https://router.project-osrm.org/route/v1/driving/${_pickupLocation!.longitude},${_pickupLocation!.latitude};${_dropOffLocation!.longitude},${_dropOffLocation!.latitude}?overview=full&geometries=geojson'),
        headers: {
          'User-Agent': 'ShifftersApp/1.0',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry'];

          if (geometry != null && geometry['coordinates'] != null) {
            List<LatLng> routePoints = [];

            for (var coord in geometry['coordinates']) {
              routePoints.add(
                  LatLng(coord[1], coord[0])); // Note: OSRM returns [lng, lat]
            }

            setState(() {
              _polylines.clear();
              _polylines.add(
                Polyline(
                  polylineId: const PolylineId('route'),
                  points: routePoints,
                  color: Colors.blue,
                  width: 5,
                  patterns: [PatternItem.dash(30), PatternItem.gap(10)],
                ),
              );
              _isLoadingRoute = false;
            });

            // Fit map to show both markers and route
            _fitMapToRoute();
          }
        }
      } else {
        // Fallback: draw straight line
        _drawStraightLine();
      }
    } catch (e) {
      debugPrint('Error drawing route: $e');
      // Fallback: draw straight line
      _drawStraightLine();
    }
  }

  void _drawStraightLine() {
    if (_pickupLocation == null || _dropOffLocation == null) return;

    setState(() {
      _polylines.clear();
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('straight_route'),
          points: [_pickupLocation!, _dropOffLocation!],
          color: Colors.blue,
          width: 5,
          patterns: [PatternItem.dash(30), PatternItem.gap(10)],
        ),
      );
      _isLoadingRoute = false;
    });

    _fitMapToRoute();
  }

  void _fitMapToRoute() {
    if (_pickupLocation == null || _dropOffLocation == null) return;

    // Calculate bounds
    double minLat =
        math.min(_pickupLocation!.latitude, _dropOffLocation!.latitude);
    double maxLat =
        math.max(_pickupLocation!.latitude, _dropOffLocation!.latitude);
    double minLng =
        math.min(_pickupLocation!.longitude, _dropOffLocation!.longitude);
    double maxLng =
        math.max(_pickupLocation!.longitude, _dropOffLocation!.longitude);

    // Add padding
    double latPadding = (maxLat - minLat) * 0.2;
    double lngPadding = (maxLng - minLng) * 0.2;

    LatLng southwest = LatLng(minLat - latPadding, minLng - lngPadding);
    LatLng northeast = LatLng(maxLat + latPadding, maxLng + lngPadding);

    // Calculate center and zoom
    LatLng center = LatLng(
      (southwest.latitude + northeast.latitude) / 2,
      (southwest.longitude + northeast.longitude) / 2,
    );

    // Calculate appropriate zoom level
    double zoom = _calculateZoomLevel(southwest, northeast);

    _moveMapToLocation(center, zoom);
  }

  double _calculateZoomLevel(LatLng southwest, LatLng northeast) {
    double latDiff = northeast.latitude - southwest.latitude;
    double lngDiff = northeast.longitude - southwest.longitude;
    double maxDiff = math.max(latDiff, lngDiff);

    if (maxDiff < 0.01) return 15.0;
    if (maxDiff < 0.05) return 13.0;
    if (maxDiff < 0.1) return 11.0;
    if (maxDiff < 0.5) return 9.0;
    return 7.0;
  }

  Future<String> _reverseGeocode(LatLng position) async {
    try {
      // Try Nominatim reverse geocoding first
      final response = await http.get(
        Uri.parse(
            'https://nominatim.openstreetmap.org/reverse?lat=${position.latitude}&lon=${position.longitude}&format=json&addressdetails=1'),
        headers: {
          'User-Agent': 'ShifftersApp/1.0',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Format Pakistani address
        if (data['address'] != null) {
          return _formatPakistaniAddress(data);
        }
        return data['display_name'] ?? 'Unknown Location';
      }
    } catch (e) {
      debugPrint('Error with Nominatim reverse geocoding: $e');
    }

    // Fallback to local reverse geocoding
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        List<String> addressParts = [];

        if (place.street != null && place.street!.isNotEmpty) {
          addressParts.add(place.street!);
        }
        if (place.locality != null && place.locality!.isNotEmpty) {
          addressParts.add(place.locality!);
        }
        if (place.administrativeArea != null &&
            place.administrativeArea!.isNotEmpty) {
          addressParts.add(place.administrativeArea!);
        }
        addressParts.add('Pakistan');

        return addressParts.join(', ');
      }
    } catch (e) {
      debugPrint('Error with local reverse geocoding: $e');
    }

    return 'Unknown Location, Pakistan';
  }

  String _formatPakistaniAddress(Map<String, dynamic> data) {
    Map<String, dynamic> address = data['address'] ?? {};
    List<String> addressParts = [];

    // Add house number and road
    if (address['house_number'] != null) {
      addressParts.add(address['house_number']);
    }
    if (address['road'] != null) {
      addressParts.add(address['road']);
    }

    // Add area/suburb
    if (address['suburb'] != null) {
      addressParts.add(address['suburb']);
    } else if (address['neighbourhood'] != null) {
      addressParts.add(address['neighbourhood']);
    }

    // Add city
    if (address['city'] != null) {
      addressParts.add(address['city']);
    } else if (address['town'] != null) {
      addressParts.add(address['town']);
    }

    // Add province/state
    if (address['state'] != null) {
      addressParts.add(address['state']);
    }

    // Always add Pakistan
    addressParts.add('Pakistan');

    return addressParts.join(', ');
  }

  void _addMarker(LatLng position, String type, String address) {
    // Animation handled by Google Maps automatically

    setState(() {
      // Remove existing marker of the same type
      _markers.removeWhere((marker) => marker.markerId.value == type);

      // Add new Google Maps marker
      _markers.add(
        Marker(
          markerId: MarkerId(type),
          position: position,
          infoWindow: InfoWindow(
            title: type == 'pickup' ? 'Pickup Location' : 'Drop-off Location',
            snippet: address,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            type == 'pickup'
                ? BitmapDescriptor.hueGreen
                : BitmapDescriptor.hueRed,
          ),
          onTap: () {
            _showMarkerInfo(type, address);
          },
        ),
      );
    });
  }

  void _showMarkerInfo(String type, String address) {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isDarkMode = themeService.isDarkMode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor:
            isDarkMode ? const Color(0xFF2D2D3C) : AppTheme.lightCardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          type == 'pickup' ? 'Pickup Location' : 'Drop-off Location',
          style: GoogleFonts.albertSans(
            color: isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          address,
          style: GoogleFonts.albertSans(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.8)
                : AppTheme.lightTextSecondaryColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.albertSans(
                color: isDarkMode
                    ? AppColors.yellowAccent
                    : AppTheme.lightPrimaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onContinue() {
    if (_pickupLocation == null || _dropOffLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Text(
                'Please select both pickup and drop-off locations',
                style: GoogleFonts.albertSans(
                    color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
      return;
    }

    HapticFeedback.lightImpact();

    // Calculate distance
    double distance = Geolocator.distanceBetween(
          _pickupLocation!.latitude,
          _pickupLocation!.longitude,
          _dropOffLocation!.latitude,
          _dropOffLocation!.longitude,
        ) /
        1000; // Convert to kilometers

    // Navigate to ProductsListingScreen instead of popping
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductsListingScreen(
          routeData: {
            'pickup': {
              'location': _pickupLocation,
              'address': _pickupController.text,
            },
            'dropoff': {
              'location': _dropOffLocation,
              'address': _dropOffController.text,
            },
            'distance': distance,
            'route': _polylines.isNotEmpty ? _polylines.first.points : [],
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    _pickupController.dispose();
    _dropOffController.dispose();
    _pickupFocusNode.dispose();
    _dropOffFocusNode.dispose();
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
          backgroundColor: isDarkMode
              ? const Color(0xFF1E1E2C)
              : AppTheme.lightBackgroundColor,
          // Remove resizeToAvoidBottomInset to prevent layout shifts
          resizeToAvoidBottomInset: false,
          body: Stack(
            children: [
              // Map - Full screen with proper clipping
              Positioned.fill(
                child: _buildMap(),
              ),

              // Loading indicator for route
              if (_isLoadingRoute)
                Positioned(
                  top: MediaQuery.of(context).size.height * 0.5,
                  left: MediaQuery.of(context).size.width * 0.5 - 20,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.black.withValues(alpha: 0.7)
                          : AppTheme.lightCardColor.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: isDarkMode
                              ? Colors.black.withValues(alpha: 0.2)
                              : AppTheme.lightShadowMedium,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isDarkMode
                              ? Colors.white
                              : AppTheme.lightPrimaryColor,
                        ),
                      ),
                    ),
                  ),
                ),

              // Top UI
              _buildTopUI(isTablet, isDarkMode),

              // Bottom UI
              _buildBottomUI(isTablet, isDarkMode),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMap() {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        final isDarkMode = themeService.isDarkMode;

        return ClipRect(
          child: Container(
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1E1E2C) : Colors.white,
            ),
            child: GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: _currentPosition,
                zoom: _currentZoom,
              ),
              onTap: _onMapTap,
              onLongPress: _onMapLongPress,
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              mapType: MapType.normal,
              // Use dark map style for dark mode
              style: isDarkMode ? _darkMapStyle : null,
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopUI(bool isTablet, bool isDarkMode) {
    return SafeArea(
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          margin: EdgeInsets.all(isTablet ? 24 : 16),
          child: Column(
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.black.withValues(alpha: 0.7)
                            : AppTheme.lightCardColor.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                        border: isDarkMode
                            ? null
                            : Border.all(
                                color: AppTheme.lightBorderColor,
                                width: 1,
                              ),
                        boxShadow: [
                          BoxShadow(
                            color: isDarkMode
                                ? Colors.black.withValues(alpha: 0.2)
                                : AppTheme.lightShadowMedium,
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.arrow_back,
                        color: isDarkMode
                            ? Colors.white
                            : AppTheme.lightTextPrimaryColor,
                        size: isTablet ? 24 : 20,
                      ),
                    ),
                  ),

                  Text(
                    'Add Locations',
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 20 : 18,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode
                          ? Colors.white
                          : AppTheme.lightTextPrimaryColor,
                    ),
                  ),

                  // Enhanced single-tap target icon with current location fetching
                  GestureDetector(
                    onTap: _handleTargetIconTap,
                    child: AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: (_isGeocodingPickup ||
                                      _isFetchingCurrentLocation)
                                  ? isDarkMode
                                      ? AppColors.yellowAccent
                                          .withValues(alpha: 0.3)
                                      : AppTheme.lightPrimaryColor
                                          .withValues(alpha: 0.3)
                                  : isDarkMode
                                      ? Colors.black.withValues(alpha: 0.7)
                                      : AppTheme.lightCardColor
                                          .withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  (_tapCount > 0 || _isFetchingCurrentLocation)
                                      ? Border.all(
                                          color: isDarkMode
                                              ? AppColors.yellowAccent
                                              : AppTheme.lightPrimaryColor,
                                          width: 2,
                                        )
                                      : isDarkMode
                                          ? null
                                          : Border.all(
                                              color: AppTheme.lightBorderColor,
                                              width: 1,
                                            ),
                              boxShadow: [
                                BoxShadow(
                                  color: isDarkMode
                                      ? Colors.black.withValues(alpha: 0.2)
                                      : AppTheme.lightShadowMedium,
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: (_isGeocodingPickup ||
                                    _isFetchingCurrentLocation)
                                ? SizedBox(
                                    width: isTablet ? 24 : 20,
                                    height: isTablet ? 24 : 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        isDarkMode
                                            ? AppColors.yellowAccent
                                            : AppTheme.lightPrimaryColor,
                                      ),
                                    ),
                                  )
                                : Icon(
                                    Icons.my_location,
                                    color: (_tapCount > 0 ||
                                            _isFetchingCurrentLocation)
                                        ? isDarkMode
                                            ? AppColors.yellowAccent
                                            : AppTheme.lightPrimaryColor
                                        : isDarkMode
                                            ? Colors.white
                                            : AppTheme.lightTextPrimaryColor,
                                    size: isTablet ? 24 : 20,
                                  ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Location Input Fields
              _buildLocationInputs(isTablet, isDarkMode),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationInputs(bool isTablet, bool isDarkMode) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          // Pickup Location
          Container(
            padding: EdgeInsets.all(isTablet ? 20 : 16),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? AppColors.yellowAccent.withValues(alpha: 0.1)
                  : AppTheme.lightPrimaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDarkMode
                    ? AppColors.yellowAccent
                    : AppTheme.lightPrimaryColor,
                width: isDarkMode ? 2 : 1.5,
              ),
              boxShadow: isDarkMode
                  ? null
                  : [
                      BoxShadow(
                        color:
                            AppTheme.lightPrimaryColor.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.radio_button_checked,
                      color: isDarkMode
                          ? AppColors.yellowAccent
                          : AppTheme.lightPrimaryColor,
                      size: isTablet ? 20 : 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Pickup Location',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 14 : 12,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode
                            ? AppColors.yellowAccent
                            : AppTheme.lightPrimaryColor,
                      ),
                    ),
                    if (_isFetchingCurrentLocation) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isDarkMode
                                ? AppColors.yellowAccent
                                : AppTheme.lightPrimaryColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _pickupController,
                  focusNode: _pickupFocusNode,
                  hintText: 'Type pickup address or tap location icon',
                  isTablet: isTablet,
                  isDarkMode: isDarkMode,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Drop-off Location
          Container(
            padding: EdgeInsets.all(isTablet ? 20 : 16),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.1)
                  : AppTheme.lightCardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.2)
                    : AppTheme.lightBorderColor,
                width: isDarkMode ? 1 : 1.5,
              ),
              boxShadow: isDarkMode
                  ? null
                  : [
                      BoxShadow(
                        color: AppTheme.lightShadowMedium,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: isDarkMode
                          ? Colors.white
                          : AppTheme.lightTextPrimaryColor,
                      size: isTablet ? 20 : 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Drop Off Location',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 14 : 12,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode
                            ? Colors.white
                            : AppTheme.lightTextPrimaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _dropOffController,
                  focusNode: _dropOffFocusNode,
                  hintText: 'Type address in Pakistan',
                  isTablet: isTablet,
                  isDarkMode: isDarkMode,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hintText,
    required bool isTablet,
    required bool isDarkMode,
  }) {
    return GestureDetector(
      onTap: () {
        // Determine which field was tapped and open enter route screen
        if (focusNode == _pickupFocusNode) {
          _openEnterRouteScreen('pickup');
        } else if (focusNode == _dropOffFocusNode) {
          _openEnterRouteScreen('dropoff');
        }
      },
      child: AbsorbPointer(
        // Prevent the TextField from receiving focus
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          style: GoogleFonts.albertSans(
            fontSize: isTablet ? 16 : 14,
            color: isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: GoogleFonts.albertSans(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.6)
                  : Colors.grey.withValues(alpha: 0.7),
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.7)
                  : Colors.grey.withValues(alpha: 0.7),
              size: isTablet ? 24 : 20,
            ),
            filled: true,
            fillColor:
                isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDarkMode
                    ? AppColors.yellowAccent
                    : AppTheme.lightPrimaryColor,
                width: 2,
              ),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: isTablet ? 16 : 12,
              vertical: isTablet ? 16 : 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomUI(bool isTablet, bool isDarkMode) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            padding: EdgeInsets.all(isTablet ? 24 : 20),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? const Color(0xFF1E1E2C).withValues(alpha: 0.95)
                  : AppTheme.lightCardColor.withValues(alpha: 0.95),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: isDarkMode
                      ? Colors.black.withValues(alpha: 0.1)
                      : AppTheme.lightShadowMedium,
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                // Action Buttons
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.1)
                        : AppTheme.lightPrimaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline,
                    color:
                        isDarkMode ? Colors.white : AppTheme.lightPrimaryColor,
                    size: isTablet ? 24 : 20,
                  ),
                ),

                const SizedBox(width: 16),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.1)
                        : AppTheme.lightPrimaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.phone,
                    color:
                        isDarkMode ? Colors.white : AppTheme.lightPrimaryColor,
                    size: isTablet ? 24 : 20,
                  ),
                ),

                const Spacer(),

                // Continue Button
                GestureDetector(
                  onTap: _onContinue,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 32 : 24,
                      vertical: isTablet ? 16 : 14,
                    ),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? AppColors.yellowAccent
                          : AppTheme.lightPrimaryColor,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: isDarkMode
                              ? AppColors.yellowAccent.withValues(alpha: 0.3)
                              : AppTheme.lightPrimaryColor
                                  .withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Continue',
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 16 : 14,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.black : Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward,
                          color: isDarkMode ? Colors.black : Colors.white,
                          size: isTablet ? 20 : 18,
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
    );
  }
}

class AddressSuggestion {
  final String address;
  final String placeId;
  final LatLng location;

  AddressSuggestion({
    required this.address,
    required this.placeId,
    required this.location,
  });
}
