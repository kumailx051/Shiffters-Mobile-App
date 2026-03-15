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
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import 'package:shiffters/services/theme_service.dart';
import 'package:latlong2/latlong.dart' as latlong;

// Import the next screens in the workflow
import 'pickup_drop_package_screen.dart';
// Import enter_route_screen for location selection
import 'package:shiffters/screens/User/shifting/enter_route_screen.dart';

class PickupDropScreen extends StatefulWidget {
  const PickupDropScreen({super.key});

  @override
  State<PickupDropScreen> createState() => _PickupDropScreenState();
}

class _PickupDropScreenState extends State<PickupDropScreen>
    with TickerProviderStateMixin {
  final Completer<GoogleMapController> _mapController =
      Completer<GoogleMapController>();
  late AnimationController _animationController;
  late AnimationController _markerAnimationController;
  late AnimationController _pulseController;
  late AnimationController _routeGlowController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;

  // Location and map state
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dropOffController = TextEditingController();
  final FocusNode _pickupFocusNode = FocusNode();
  final FocusNode _dropOffFocusNode = FocusNode();

  Set<Marker> _markers = <Marker>{};
  Set<Polyline> _polylines = <Polyline>{};
  List<LatLng> _routePoints = [];
  LatLng? _pickupLocation;
  LatLng? _dropOffLocation;
  // Default to Pakistan (Lahore coordinates)
  LatLng _currentPosition = const LatLng(31.5204, 74.3587);

  bool _isLoadingLocation = true;
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
  static const String _darkMapStyle = '''
  [
    {
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#242f3e"
        }
      ]
    },
    {
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#746855"
        }
      ]
    },
    {
      "elementType": "labels.text.stroke",
      "stylers": [
        {
          "color": "#242f3e"
        }
      ]
    },
    {
      "featureType": "administrative.locality",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#d59563"
        }
      ]
    },
    {
      "featureType": "poi",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#d59563"
        }
      ]
    },
    {
      "featureType": "poi.park",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#263c3f"
        }
      ]
    },
    {
      "featureType": "poi.park",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#6b9a76"
        }
      ]
    },
    {
      "featureType": "road",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#38414e"
        }
      ]
    },
    {
      "featureType": "road",
      "elementType": "geometry.stroke",
      "stylers": [
        {
          "color": "#212a37"
        }
      ]
    },
    {
      "featureType": "road",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#9ca5b3"
        }
      ]
    },
    {
      "featureType": "road.highway",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#746855"
        }
      ]
    },
    {
      "featureType": "road.highway",
      "elementType": "geometry.stroke",
      "stylers": [
        {
          "color": "#1f2835"
        }
      ]
    },
    {
      "featureType": "road.highway",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#f3d19c"
        }
      ]
    },
    {
      "featureType": "transit",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#2f3948"
        }
      ]
    },
    {
      "featureType": "transit.station",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#d59563"
        }
      ]
    },
    {
      "featureType": "water",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#17263c"
        }
      ]
    },
    {
      "featureType": "water",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#515c6d"
        }
      ]
    },
    {
      "featureType": "water",
      "elementType": "labels.text.stroke",
      "stylers": [
        {
          "color": "#17263c"
        }
      ]
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
  }

  // Google Maps controller callback
  void _onMapCreated(GoogleMapController controller) {
    debugPrint('🗺️ Google Map created successfully in PickupDropScreen');
    _mapController.complete(controller);
    // Apply dark theme if needed
    final theme = Provider.of<ThemeService>(context, listen: false);
    if (theme.isDarkMode) {
      controller.setMapStyle(_darkMapStyle);
    }
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _markerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _routeGlowController = AnimationController(
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
          initialPickupLocation: _pickupLocation != null
              ? latlong.LatLng(
                  _pickupLocation!.latitude, _pickupLocation!.longitude)
              : null,
          initialDropOffLocation: _dropOffLocation != null
              ? latlong.LatLng(
                  _dropOffLocation!.latitude, _dropOffLocation!.longitude)
              : null,
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

    if (_tapCount >= 2) {
      _fetchCurrentLocationAndSetAsPickup();
      _tapCount = 0; // Reset tap count
    }

    // Reset tap count after 500ms if no second tap
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_tapCount == 1 &&
          _lastTapTime != null &&
          now.difference(_lastTapTime!).inMilliseconds >= 500) {
        _tapCount = 0;
      }
    });
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
          _showLocationError('Location permissions are denied');
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
            'Location services are disabled. Please enable them.');
        return;
      }

      // Get current position with high accuracy
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
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
        _currentPosition = currentLocation; // Update current position marker
        _pickupLocation = currentLocation;
        _pickupController.text = detailedAddress;
      });

      // Add marker for pickup location
      _addMarker(_pickupLocation!, 'pickup', detailedAddress);

      // Move map to current location
      final GoogleMapController controller = await _mapController.future;
      controller.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(target: currentLocation, zoom: 16.0),
      ));

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
        errorMessage = 'Location permissions are denied. Please grant them.';
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
        addresses.add(nominatimAddress);
      } catch (e) {
        debugPrint('Nominatim failed: $e');
      }

      // 2. Try Photon geocoding
      try {
        String photonAddress = await _getPhotonDetailedAddress(position);
        addresses.add(photonAddress);
      } catch (e) {
        debugPrint('Photon failed: $e');
      }

      // 3. Fallback to local geocoding
      try {
        String localAddress = await _getLocalDetailedAddress(position);
        addresses.add(localAddress);
      } catch (e) {
        debugPrint('Local geocoding failed: $e');
      }

      // Return the most detailed address (usually the first successful one)
      if (addresses.isNotEmpty) {
        // Sort by detail score and return the best one
        addresses.sort((a, b) => _calculateAddressDetailScore(b)
            .compareTo(_calculateAddressDetailScore(a)));
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
      Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=18'),
      headers: {
        'Accept-Language': 'en,ur',
        'User-Agent': 'ShifftersApp/1.0',
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
      Uri.parse(
          'https://photon.komoot.io/reverse?lat=${position.latitude}&lon=${position.longitude}&lang=en'),
      headers: {
        'User-Agent': 'ShifftersApp/1.0',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['features'] != null && data['features'].isNotEmpty) {
        final properties = data['features'][0]['properties'];
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
      return _formatLocalPlacemark(placemarks.first);
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
        addressParts.add(address[key].toString());
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
        addressParts.add(address[key].toString());
        break;
      }
    }

    // Add city/town with priority
    List<String> cityKeys = ['city', 'town', 'municipality', 'village'];
    for (String key in cityKeys) {
      if (address[key] != null && address[key].toString().isNotEmpty) {
        addressParts.add(address[key].toString());
        break;
      }
    }

    // Add district/county if different from city
    if (address['county'] != null && address['county'].toString().isNotEmpty) {
      String county = address['county'].toString();
      if (addressParts.isEmpty ||
          !addressParts.last.toLowerCase().contains(county.toLowerCase())) {
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
      if (!uniqueParts
          .any((existing) => existing.toLowerCase() == part.toLowerCase())) {
        uniqueParts.add(part);
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
      addressParts.add(properties['street'].toString());
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

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        // Check if current location is within Pakistan bounds
        if (_isLocationInPakistan(position.latitude, position.longitude)) {
          setState(() {
            _currentPosition = LatLng(position.latitude, position.longitude);
            _isLoadingLocation = false;
          });
        } else {
          // If outside Pakistan, use default Pakistan location (Lahore)
          setState(() {
            _currentPosition = LatLng(31.5204, 74.3587);
            _isLoadingLocation = false;
          });
        }

        if (_shouldMoveMap) {
          final GoogleMapController controller = await _mapController.future;
          controller.animateCamera(CameraUpdate.newCameraPosition(
            CameraPosition(target: _currentPosition, zoom: 15.0),
          ));
        }
      } else {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingLocation = false;
      });
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
        _routePoints.clear(); // Clear route when marker is removed

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF2D2D3C),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: [
              Icon(Icons.location_off, color: AppColors.yellowAccent, size: 20),
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
              _routePoints = routePoints;
              _polylines = {
                Polyline(
                  polylineId: const PolylineId('route'),
                  color: AppColors.yellowAccent,
                  width: 4,
                  points: routePoints,
                ),
              };
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

    final List<LatLng> straightLine = [_pickupLocation!, _dropOffLocation!];

    setState(() {
      _routePoints = straightLine;
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          color: AppColors.yellowAccent,
          width: 4,
          points: straightLine,
        ),
      };
      _isLoadingRoute = false;
    });

    _fitMapToRoute();
  }

  void _fitMapToRoute() async {
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

    final GoogleMapController controller = await _mapController.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: center, zoom: zoom),
    ));
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
    // Reset and start marker animation
    _markerAnimationController.reset();
    _markerAnimationController.forward();

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
          icon: type == 'pickup'
              ? BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueYellow)
              : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isDarkMode
              ? BorderSide.none
              : BorderSide(
                  color: AppTheme.lightBorderColor,
                  width: 1,
                ),
        ),
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
              Expanded(
                child: Text(
                  'Please select both pickup and drop-off locations',
                  style: GoogleFonts.albertSans(
                      color: Colors.white, fontWeight: FontWeight.w500),
                ),
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

    // Navigate to package screen (first step in the flow)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PickupDropPackageScreen(
          packageData: {
            'pickup': {
              'location': _pickupLocation,
              'address': _pickupController.text,
            },
            'dropoff': {
              'location': _dropOffLocation,
              'address': _dropOffController.text,
            },
            'distance': distance,
            'route': _routePoints,
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _markerAnimationController.dispose();
    _pulseController.dispose();
    _routeGlowController.dispose();
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
          body: Container(
            decoration: isDarkMode
                ? null
                : BoxDecoration(
                    color: AppTheme
                        .lightBackgroundColor, // Use proper light background
                  ),
            child: Stack(
              children: [
                // Map
                _buildMap(),

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
          ),
        );
      },
    );
  }

  Widget _buildMap() {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        final isDarkMode = themeService.isDarkMode;

        return Container(
          decoration: BoxDecoration(
            color: isDarkMode
                ? const Color(0xFF2D2D3C).withValues(alpha: 0.8)
                : Colors
                    .white, // Use plain white instead of AppTheme.lightBackgroundColor
            boxShadow: isDarkMode
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: _buildGoogleMap(),
        );
      },
    );
  }

  /// Google Maps widget for both web and mobile
  Widget _buildGoogleMap() {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        // Create a combined set of markers including current location
        Set<Marker> allMarkers = Set.from(_markers);

        // Add current location marker if not loading
        if (!_isLoadingLocation) {
          allMarkers.add(
            Marker(
              markerId: const MarkerId('current_location'),
              position: _currentPosition,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueBlue),
              infoWindow: const InfoWindow(
                title: 'Current Location',
              ),
            ),
          );
        }

        return GoogleMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition: CameraPosition(
            target: _currentPosition,
            zoom: _currentZoom,
          ),
          onTap: _onMapTap,
          onLongPress: _onMapLongPress,
          markers: allMarkers,
          polylines: _polylines,
          myLocationEnabled: false, // We'll show custom current location marker
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          buildingsEnabled: true,
          compassEnabled: false,
          indoorViewEnabled: false,
          mapType: MapType.normal,
          trafficEnabled: false,
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
                      child: Icon(
                        Icons.arrow_back,
                        color: isDarkMode
                            ? Colors.white
                            : AppTheme.lightTextPrimaryColor,
                        size: isTablet ? 24 : 20,
                      ),
                    ),
                  ),

                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    child: Text(
                      'Pickup & Drop Service',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 20 : 18,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode
                            ? Colors.white
                            : AppTheme.lightTextPrimaryColor,
                      ),
                    ),
                  ),

                  // Double-tap target icon
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
                                  ? (isDarkMode
                                      ? AppColors.yellowAccent
                                          .withValues(alpha: 0.3)
                                      : AppTheme.lightPrimaryColor
                                          .withValues(alpha: 0.2))
                                  : (isDarkMode
                                      ? Colors.black.withValues(alpha: 0.7)
                                      : AppTheme.lightCardColor
                                          .withValues(alpha: 0.9)),
                              borderRadius: BorderRadius.circular(12),
                              border: _tapCount > 0
                                  ? Border.all(
                                      color: isDarkMode
                                          ? AppColors.yellowAccent
                                          : AppTheme.lightPrimaryColor,
                                      width: 2,
                                    )
                                  : (isDarkMode
                                      ? null
                                      : Border.all(
                                          color: AppTheme.lightBorderColor,
                                          width: 1,
                                        )),
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
                                    color: _tapCount > 0
                                        ? (isDarkMode
                                            ? AppColors.yellowAccent
                                            : AppTheme.lightPrimaryColor)
                                        : (isDarkMode
                                            ? Colors.white
                                            : AppTheme.lightTextSecondaryColor),
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
                width: 2,
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
                  ],
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _pickupController,
                  focusNode: _pickupFocusNode,
                  hintText: 'Type pickup address in Pakistan',
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
                  : AppTheme.lightCardColor.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.2)
                    : AppTheme.lightBorderColor,
                width: 1,
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
                          : AppTheme.lightTextSecondaryColor,
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
                            : AppTheme.lightTextSecondaryColor,
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
            color: isDarkMode ? Colors.black : AppTheme.lightTextPrimaryColor,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: GoogleFonts.albertSans(
              color: isDarkMode
                  ? Colors.grey.withValues(alpha: 0.7)
                  : AppTheme.lightTextLightColor,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: isDarkMode
                  ? Colors.grey.withValues(alpha: 0.7)
                  : AppTheme.lightTextSecondaryColor,
              size: isTablet ? 24 : 20,
            ),
            filled: true,
            fillColor: isDarkMode ? Colors.white : AppTheme.lightCardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: isDarkMode
                  ? BorderSide.none
                  : BorderSide(
                      color: AppTheme.lightBorderColor,
                      width: 1,
                    ),
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
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: isDarkMode
                  ? BorderSide.none
                  : BorderSide(
                      color: AppTheme.lightBorderColor,
                      width: 1,
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
              border: isDarkMode
                  ? null
                  : Border(
                      top: BorderSide(
                        color: AppTheme.lightBorderColor,
                        width: 1,
                      ),
                    ),
              boxShadow: isDarkMode
                  ? null
                  : [
                      BoxShadow(
                        color: AppTheme.lightShadowMedium,
                        blurRadius: 12,
                        offset: const Offset(0, -2),
                      ),
                    ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
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
                          color: (isDarkMode
                                  ? AppColors.yellowAccent
                                  : AppTheme.lightPrimaryColor)
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
