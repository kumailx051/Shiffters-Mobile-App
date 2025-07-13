import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:shiffters/theme/app_colors.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

// Import your enter_route_screen
import 'enter_route_screen.dart';
// Import the new products_listing_screen
import 'product_listing.dart';

class AddLocationScreen extends StatefulWidget {
  const AddLocationScreen({super.key});

  @override
  State<AddLocationScreen> createState() => _AddLocationScreenState();
}

class _AddLocationScreenState extends State<AddLocationScreen> with TickerProviderStateMixin {
  late MapController _mapController;
  late AnimationController _animationController;
  late AnimationController _markerAnimationController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _markerScaleAnimation;
  late Animation<double> _pulseAnimation;
  
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dropOffController = TextEditingController();
  final FocusNode _pickupFocusNode = FocusNode();
  final FocusNode _dropOffFocusNode = FocusNode();
  
  List<Marker> _markers = [];
  List<LatLng> _routePoints = [];
  LatLng? _pickupLocation;
  LatLng? _dropOffLocation;
  // Default to Pakistan (Lahore coordinates)
  LatLng _currentPosition = LatLng(31.5204, 74.3587);
  
  bool _isLoadingLocation = true;
  bool _isLoadingRoute = false;
  bool _isGeocodingPickup = false;
  String _selectedField = '';
  double _currentZoom = 15.0;
  bool _shouldMoveMap = true;

  // Double tap detection variables
  int _tapCount = 0;
  DateTime? _lastTapTime;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _initializeAnimations();
    _startAnimations();
    _getCurrentLocation();
    _setupTextFieldListeners();
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

    _markerScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _markerAnimationController,
      curve: Curves.elasticOut,
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
    
    if (_lastTapTime != null && now.difference(_lastTapTime!).inMilliseconds < 500) {
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
      _saveCurrentLocationAsPickup();
      _tapCount = 0; // Reset tap count
    }
    
    // Reset tap count after 500ms if no second tap
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_tapCount == 1 && _lastTapTime != null && 
          now.difference(_lastTapTime!).inMilliseconds >= 500) {
        _tapCount = 0;
      }
    });
  }

  Future<void> _saveCurrentLocationAsPickup() async {
    setState(() {
      _isGeocodingPickup = true;
    });

    try {
      // Get the center of the current map view
      LatLng centerLocation = _mapController.camera.center;
      
      // Check if location is within Pakistan bounds
      if (!_isLocationInPakistan(centerLocation.latitude, centerLocation.longitude)) {
        _showLocationError('Please select a location within Pakistan');
        return;
      }

      // Reverse geocode to get address
      String address = await _reverseGeocode(centerLocation);

      setState(() {
        _pickupLocation = centerLocation;
        _pickupController.text = address;
      });

      // Add marker for pickup location
      _addMarker(_pickupLocation!, 'pickup', address);

      // Show success feedback
      HapticFeedback.mediumImpact();
      _showSuccessMessage('Pickup location set successfully!');

      // Draw route if both locations are set
      if (_pickupLocation != null && _dropOffLocation != null) {
        _drawRoute();
      }

    } catch (e) {
      _showLocationError('Failed to get address: $e');
    } finally {
      setState(() {
        _isGeocodingPickup = false;
      });
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.albertSans(color: Colors.white, fontWeight: FontWeight.w500),
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
        backgroundColor: Colors.red.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.albertSans(color: Colors.white, fontWeight: FontWeight.w500),
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
          initialPickupAddress: _pickupController.text.isNotEmpty ? _pickupController.text : null,
          initialDropOffAddress: _dropOffController.text.isNotEmpty ? _dropOffController.text : null,
          initialPickupLocation: _pickupLocation,
          initialDropOffLocation: _dropOffLocation,
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
          _mapController.move(_currentPosition, 15.0);
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
    
    return lat >= southBound && lat <= northBound && 
           lng >= westBound && lng <= eastBound;
  }

  void _onMapTap(TapPosition tapPosition, LatLng position) async {
    HapticFeedback.lightImpact();
    
    // Only allow tapping within Pakistan bounds
    if (!_isLocationInPakistan(position.latitude, position.longitude)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.orange.withOpacity(0.9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: [
              const Icon(Icons.warning_outlined, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Text(
                'Please select a location within Pakistan',
                style: GoogleFonts.albertSans(color: Colors.white, fontWeight: FontWeight.w500),
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
      print('Error getting address: $e');
    }
  }

  void _onMapLongPress(TapPosition tapPosition, LatLng position) {
    HapticFeedback.mediumImpact();
    
    // Find and remove nearby marker
    Marker? markerToRemove;
    for (Marker marker in _markers) {
      double distance = Geolocator.distanceBetween(
        marker.point.latitude,
        marker.point.longitude,
        position.latitude,
        position.longitude,
      );
      
      if (distance < 100) { // Within 100 meters
        markerToRemove = marker;
        break;
      }
    }

    if (markerToRemove != null) {
      setState(() {
        _markers.remove(markerToRemove);
        _routePoints.clear(); // Clear route when marker is removed
        
        if (markerToRemove!.key == const ValueKey('pickup')) {
          _pickupLocation = null;
          _pickupController.clear();
        } else if (markerToRemove.key == const ValueKey('dropoff')) {
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: [
              Icon(Icons.location_off, color: AppColors.yellowAccent, size: 20),
              const SizedBox(width: 12),
              Text(
                'Location marker removed',
                style: GoogleFonts.albertSans(color: Colors.white, fontWeight: FontWeight.w500),
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
          'https://router.project-osrm.org/route/v1/driving/${_pickupLocation!.longitude},${_pickupLocation!.latitude};${_dropOffLocation!.longitude},${_dropOffLocation!.latitude}?overview=full&geometries=geojson'
        ),
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
              routePoints.add(LatLng(coord[1], coord[0])); // Note: OSRM returns [lng, lat]
            }
            
            setState(() {
              _routePoints = routePoints;
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
      print('Error drawing route: $e');
      // Fallback: draw straight line
      _drawStraightLine();
    }
  }

  void _drawStraightLine() {
    if (_pickupLocation == null || _dropOffLocation == null) return;

    setState(() {
      _routePoints = [_pickupLocation!, _dropOffLocation!];
      _isLoadingRoute = false;
    });

    _fitMapToRoute();
  }

  void _fitMapToRoute() {
    if (_pickupLocation == null || _dropOffLocation == null) return;

    // Calculate bounds
    double minLat = math.min(_pickupLocation!.latitude, _dropOffLocation!.latitude);
    double maxLat = math.max(_pickupLocation!.latitude, _dropOffLocation!.latitude);
    double minLng = math.min(_pickupLocation!.longitude, _dropOffLocation!.longitude);
    double maxLng = math.max(_pickupLocation!.longitude, _dropOffLocation!.longitude);

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

    _mapController.move(center, zoom);
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
          'https://nominatim.openstreetmap.org/reverse?lat=${position.latitude}&lon=${position.longitude}&format=json&addressdetails=1'
        ),
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
      print('Error with Nominatim reverse geocoding: $e');
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
        if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
          addressParts.add(place.administrativeArea!);
        }
        addressParts.add('Pakistan');
        
        return addressParts.join(', ');
      }
    } catch (e) {
      print('Error with local reverse geocoding: $e');
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
      _markers.removeWhere((marker) => marker.key == ValueKey(type));
      
      // Add new marker with animation
      _markers.add(
        Marker(
          key: ValueKey(type),
          point: position,
          width: 50,
          height: 50,
          child: AnimatedBuilder(
            animation: _markerScaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _markerScaleAnimation.value,
                child: GestureDetector(
                  onTap: () {
                    _showMarkerInfo(type, address);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: type == 'pickup' ? AppColors.yellowAccent : Colors.red,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: Icon(
                      type == 'pickup' ? Icons.my_location : Icons.location_on,
                      color: type == 'pickup' ? Colors.black : Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    });
  }

  void _showMarkerInfo(String type, String address) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D3C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          type == 'pickup' ? 'Pickup Location' : 'Drop-off Location',
          style: GoogleFonts.albertSans(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          address,
          style: GoogleFonts.albertSans(
            color: Colors.white.withOpacity(0.8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.albertSans(
                color: AppColors.yellowAccent,
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
          backgroundColor: Colors.red.withOpacity(0.9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Text(
                'Please select both pickup and drop-off locations',
                style: GoogleFonts.albertSans(color: Colors.white, fontWeight: FontWeight.w500),
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
    ) / 1000; // Convert to kilometers

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
    
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      body: Stack(
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
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
          
          // Top UI
          _buildTopUI(isTablet),
          
          // Bottom UI
          _buildBottomUI(isTablet),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        0.2126, 0.7152, 0.0722, 0, 0,  // Red channel
        0.2126, 0.7152, 0.0722, 0, 0,  // Green channel  
        0.2126, 0.7152, 0.0722, 0, 0,  // Blue channel
        0,      0,      0,      1, 0,  // Alpha channel
      ]),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2D2D3C).withOpacity(0.8),
        ),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentPosition,
            initialZoom: _currentZoom,
            onTap: _onMapTap,
            onLongPress: _onMapLongPress,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
          ),
          children: [
            // Dark OpenStreetMap Tile Layer
            TileLayer(
              urlTemplate: 'https://cartodb-basemaps-{s}.global.ssl.fastly.net/dark_all/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'com.shiffters.app',
              maxZoom: 19,
            ),
            
            // Route Polyline Layer
            if (_routePoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routePoints,
                    strokeWidth: 4.0,
                    color: AppColors.yellowAccent,
                    pattern: StrokePattern.dashed(segments: [10, 5]),
                  ),
                ],
              ),
            
            // Markers Layer
            MarkerLayer(
              markers: _markers,
            ),
            
            // Current Location Marker
            if (!_isLoadingLocation)
              MarkerLayer(
                markers: [
                  Marker(
                    point: _currentPosition,
                    width: 24,
                    height: 24,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.my_location,
                        color: Colors.white,
                        size: 12,
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

  Widget _buildTopUI(bool isTablet) {
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
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: isTablet ? 24 : 20,
                      ),
                    ),
                  ),
                  
                  Text(
                    'Add Locations',
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 20 : 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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
                              color: _isGeocodingPickup 
                                  ? AppColors.yellowAccent.withOpacity(0.3)
                                  : Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(12),
                              border: _tapCount > 0 
                                  ? Border.all(
                                      color: AppColors.yellowAccent,
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: _isGeocodingPickup
                                ? SizedBox(
                                    width: isTablet ? 24 : 20,
                                    height: isTablet ? 24 : 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.yellowAccent,
                                      ),
                                    ),
                                  )
                                : Icon(
                                    Icons.my_location,
                                    color: _tapCount > 0 
                                        ? AppColors.yellowAccent
                                        : Colors.white,
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
              _buildLocationInputs(isTablet),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationInputs(bool isTablet) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          // Pickup Location
          Container(
            padding: EdgeInsets.all(isTablet ? 20 : 16),
            decoration: BoxDecoration(
              color: AppColors.yellowAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.yellowAccent,
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.radio_button_checked,
                      color: AppColors.yellowAccent,
                      size: isTablet ? 20 : 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Pickup Location',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 14 : 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.yellowAccent,
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
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Drop-off Location
          Container(
            padding: EdgeInsets.all(isTablet ? 20 : 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: Colors.white,
                      size: isTablet ? 20 : 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Drop Off Location',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 14 : 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
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
      child: AbsorbPointer( // Prevent the TextField from receiving focus
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          style: GoogleFonts.albertSans(
            fontSize: isTablet ? 16 : 14,
            color: Colors.black,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: GoogleFonts.albertSans(
              color: Colors.grey.withOpacity(0.7),
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: Colors.grey.withOpacity(0.7),
              size: isTablet ? 24 : 20,
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.yellowAccent,
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

  Widget _buildBottomUI(bool isTablet) {
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
              color: const Color(0xFF1E1E2C).withOpacity(0.95),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                // Action Buttons
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline,
                    color: Colors.white,
                    size: isTablet ? 24 : 20,
                  ),
                ),
                
                const SizedBox(width: 16),
                
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.phone,
                    color: Colors.white,
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
                      color: AppColors.yellowAccent,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.yellowAccent.withOpacity(0.3),
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
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward,
                          color: Colors.black,
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