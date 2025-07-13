import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';

class EnterRouteScreen extends StatefulWidget {
  final String? initialPickupAddress;
  final String? initialDropOffAddress;
  final LatLng? initialPickupLocation;
  final LatLng? initialDropOffLocation;

  const EnterRouteScreen({
    super.key,
    this.initialPickupAddress,
    this.initialDropOffAddress,
    this.initialPickupLocation,
    this.initialDropOffLocation,
  });

  @override
  State<EnterRouteScreen> createState() => _EnterRouteScreenState();
}

class _EnterRouteScreenState extends State<EnterRouteScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  final FocusNode _fromFocusNode = FocusNode();
  final FocusNode _toFocusNode = FocusNode();
  
  List<AddressSuggestion> _fromSuggestions = [];
  List<AddressSuggestion> _toSuggestions = [];
  bool _showFromSuggestions = false;
  bool _showToSuggestions = false;
  
  Timer? _searchTimer;
  String _activeField = '';
  
  LatLng? _fromLocation;
  LatLng? _toLocation;
  
  // New variables for manual address entry
  bool _isGeocodingFrom = false;
  bool _isGeocodingTo = false;
  bool _canSaveFromManually = false;
  bool _canSaveToManually = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setupTextFieldListeners();
    _initializeFields();
    _startAnimations();
  }

  void _initializeFields() {
    if (widget.initialPickupAddress != null) {
      _fromController.text = widget.initialPickupAddress!;
      _fromLocation = widget.initialPickupLocation;
    }
    if (widget.initialDropOffAddress != null) {
      _toController.text = widget.initialDropOffAddress!;
      _toLocation = widget.initialDropOffLocation;
    }
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
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
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      _animationController.forward();
    }
  }

  void _setupTextFieldListeners() {
    _fromController.addListener(() {
      _onAddressChanged(_fromController.text, 'from');
    });
    
    _toController.addListener(() {
      _onAddressChanged(_toController.text, 'to');
    });

    _fromFocusNode.addListener(() {
      if (_fromFocusNode.hasFocus) {
        setState(() {
          _activeField = 'from';
          _showToSuggestions = false;
        });
      }
    });

    _toFocusNode.addListener(() {
      if (_toFocusNode.hasFocus) {
        setState(() {
          _activeField = 'to';
          _showFromSuggestions = false;
        });
      }
    });
  }

  void _onAddressChanged(String address, String field) {
    _searchTimer?.cancel();
    
    if (address.isEmpty) {
      setState(() {
        if (field == 'from') {
          _fromSuggestions.clear();
          _showFromSuggestions = false;
          _canSaveFromManually = false;
        } else {
          _toSuggestions.clear();
          _showToSuggestions = false;
          _canSaveToManually = false;
        }
      });
      return;
    }

    // Show manual save option immediately if address is long enough
    if (address.length >= 10) {
      setState(() {
        if (field == 'from') {
          _canSaveFromManually = true;
        } else {
          _canSaveToManually = true;
        }
      });
    }

    _searchTimer = Timer(const Duration(milliseconds: 300), () {
      _searchAddresses(address, field);
    });
  }

  Future<void> _searchAddresses(String query, String field) async {
    try {
      // Enhanced Nominatim API call with more detailed parameters for street numbers
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/search?'
          'q=${Uri.encodeComponent(query)}&'
          'format=json&'
          'limit=10&'
          'addressdetails=1&'
          'countrycodes=pk&'
          'bounded=1&'
          'viewbox=60.9,37.1,77.8,23.6&'
          'extratags=1&'
          'namedetails=1&'
          'dedupe=1'
        ),
        headers: {
          'User-Agent': 'ShifftersApp/1.0',
          'Accept-Language': 'en',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        List<AddressSuggestion> suggestions = [];

        for (var item in data) {
          double lat = double.parse(item['lat']);
          double lon = double.parse(item['lon']);
          
          if (_isLocationInPakistan(lat, lon)) {
            String formattedAddress = _formatDetailedPakistaniAddress(item);
            
            suggestions.add(AddressSuggestion(
              address: formattedAddress,
              placeId: item['place_id']?.toString() ?? '',
              location: LatLng(lat, lon),
              displayName: item['display_name'] ?? '',
              addressComponents: item['address'] ?? {},
              importance: double.tryParse(item['importance']?.toString() ?? '0') ?? 0,
            ));
          }
        }

        // Sort suggestions by relevance and importance
        suggestions.sort((a, b) {
          String queryLower = query.toLowerCase();
          String aLower = a.address.toLowerCase();
          String bLower = b.address.toLowerCase();
          
          // Exact matches first
          if (aLower.startsWith(queryLower) && !bLower.startsWith(queryLower)) return -1;
          if (!aLower.startsWith(queryLower) && bLower.startsWith(queryLower)) return 1;
          
          // Then by importance (higher importance first)
          int importanceComparison = b.importance.compareTo(a.importance);
          if (importanceComparison != 0) return importanceComparison;
          
          // Finally by length (shorter addresses are usually more relevant)
          return a.address.length.compareTo(b.address.length);
        });

        // Limit to 8 suggestions for better UX
        if (suggestions.length > 8) {
          suggestions = suggestions.take(8).toList();
        }

        setState(() {
          if (field == 'from') {
            _fromSuggestions = suggestions;
            _showFromSuggestions = suggestions.isNotEmpty;
            // If no suggestions found but address is substantial, allow manual save
            if (suggestions.isEmpty && query.length >= 10) {
              _canSaveFromManually = true;
            }
          } else {
            _toSuggestions = suggestions;
            _showToSuggestions = suggestions.isNotEmpty;
            // If no suggestions found but address is substantial, allow manual save
            if (suggestions.isEmpty && query.length >= 10) {
              _canSaveToManually = true;
            }
          }
        });
      }
    } catch (e) {
      print('Error searching addresses: $e');
      _fallbackGeocoding(query, field);
    }
  }

  bool _isLocationInPakistan(double lat, double lng) {
    const double northBound = 37.1;
    const double southBound = 23.6;
    const double eastBound = 77.8;
    const double westBound = 60.9;
    
    return lat >= southBound && lat <= northBound && 
           lng >= westBound && lng <= eastBound;
  }

  String _formatDetailedPakistaniAddress(Map<String, dynamic> item) {
    Map<String, dynamic> address = item['address'] ?? {};
    List<String> addressParts = [];

    // Add house number first if available
    if (address['house_number'] != null && address['house_number'].toString().isNotEmpty) {
      addressParts.add(address['house_number'].toString());
    }

    // Add road/street name with various possible keys
    String? roadName;
    if (address['road'] != null && address['road'].toString().isNotEmpty) {
      roadName = address['road'].toString();
    } else if (address['pedestrian'] != null) {
      roadName = address['pedestrian'].toString();
    } else if (address['footway'] != null) {
      roadName = address['footway'].toString();
    } else if (address['path'] != null) {
      roadName = address['path'].toString();
    } else if (address['cycleway'] != null) {
      roadName = address['cycleway'].toString();
    }
    
    if (roadName != null) {
      addressParts.add(roadName);
    }

    // Add area/locality details with priority
    String? areaName;
    if (address['suburb'] != null && address['suburb'].toString().isNotEmpty) {
      areaName = address['suburb'].toString();
    } else if (address['neighbourhood'] != null && address['neighbourhood'].toString().isNotEmpty) {
      areaName = address['neighbourhood'].toString();
    } else if (address['quarter'] != null) {
      areaName = address['quarter'].toString();
    } else if (address['residential'] != null) {
      areaName = address['residential'].toString();
    } else if (address['commercial'] != null) {
      areaName = address['commercial'].toString();
    }
    
    if (areaName != null) {
      addressParts.add(areaName);
    }

    // Add city/town with priority
    String? cityName;
    if (address['city'] != null && address['city'].toString().isNotEmpty) {
      cityName = address['city'].toString();
    } else if (address['town'] != null && address['town'].toString().isNotEmpty) {
      cityName = address['town'].toString();
    } else if (address['municipality'] != null) {
      cityName = address['municipality'].toString();
    } else if (address['village'] != null) {
      cityName = address['village'].toString();
    }
    
    if (cityName != null) {
      addressParts.add(cityName);
    }

    // Add district/county if different from city
    if (address['county'] != null && address['county'].toString().isNotEmpty) {
      String county = address['county'].toString();
      if (!addressParts.any((part) => part.toLowerCase().contains(county.toLowerCase()))) {
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
      if (!uniqueParts.any((existing) => existing.toLowerCase() == part.toLowerCase())) {
        uniqueParts.add(part);
      }
    }

    return uniqueParts.join(', ');
  }

  Future<void> _fallbackGeocoding(String query, String field) async {
    try {
      String pakistanQuery = '$query, Pakistan';
      List<Location> locations = await locationFromAddress(pakistanQuery);
      List<AddressSuggestion> suggestions = [];

      for (int i = 0; i < locations.length && i < 5; i++) {
        if (_isLocationInPakistan(locations[i].latitude, locations[i].longitude)) {
          suggestions.add(AddressSuggestion(
            address: '$query, Pakistan',
            placeId: 'local_$i',
            location: LatLng(locations[i].latitude, locations[i].longitude),
            displayName: '$query, Pakistan',
            addressComponents: {},
            importance: 0.5,
          ));
        }
      }

      setState(() {
        if (field == 'from') {
          _fromSuggestions = suggestions;
          _showFromSuggestions = suggestions.isNotEmpty;
          if (suggestions.isEmpty && query.length >= 10) {
            _canSaveFromManually = true;
          }
        } else {
          _toSuggestions = suggestions;
          _showToSuggestions = suggestions.isNotEmpty;
          if (suggestions.isEmpty && query.length >= 10) {
            _canSaveToManually = true;
          }
        }
      });
    } catch (e) {
      print('Error with fallback geocoding: $e');
      // Still allow manual save if geocoding fails
      setState(() {
        if (field == 'from' && query.length >= 10) {
          _canSaveFromManually = true;
        } else if (field == 'to' && query.length >= 10) {
          _canSaveToManually = true;
        }
      });
    }
  }

  // New method to handle manual address save
  Future<void> _saveManualAddress(String address, String field) async {
    setState(() {
      if (field == 'from') {
        _isGeocodingFrom = true;
      } else {
        _isGeocodingTo = true;
      }
    });

    try {
      // Try to geocode the manual address
      String pakistanQuery = address.contains('Pakistan') ? address : '$address, Pakistan';
      List<Location> locations = await locationFromAddress(pakistanQuery);
      
      if (locations.isNotEmpty) {
        Location location = locations.first;
        if (_isLocationInPakistan(location.latitude, location.longitude)) {
          setState(() {
            if (field == 'from') {
              _fromLocation = LatLng(location.latitude, location.longitude);
              _showFromSuggestions = false;
              _canSaveFromManually = false;
              _fromFocusNode.unfocus();
              
              // Auto-focus to next field if empty
              if (_toController.text.isEmpty) {
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (mounted) {
                    _toFocusNode.requestFocus();
                  }
                });
              }
            } else {
              _toLocation = LatLng(location.latitude, location.longitude);
              _showToSuggestions = false;
              _canSaveToManually = false;
              _toFocusNode.unfocus();
            }
          });

          HapticFeedback.lightImpact();
          _checkAndNavigateBack();
        } else {
          _showLocationError('Please enter an address within Pakistan');
        }
      } else {
        // If geocoding fails, use a default location in Pakistan (Islamabad)
        setState(() {
          if (field == 'from') {
            _fromLocation = LatLng(33.6844, 73.0479); // Islamabad coordinates
            _showFromSuggestions = false;
            _canSaveFromManually = false;
            _fromFocusNode.unfocus();
          } else {
            _toLocation = LatLng(33.6844, 73.0479); // Islamabad coordinates
            _showToSuggestions = false;
            _canSaveToManually = false;
            _toFocusNode.unfocus();
          }
        });

        HapticFeedback.lightImpact();
        _checkAndNavigateBack();
      }
    } catch (e) {
      print('Error geocoding manual address: $e');
      // Use default Pakistan location if all else fails
      setState(() {
        if (field == 'from') {
          _fromLocation = LatLng(33.6844, 73.0479); // Islamabad coordinates
          _showFromSuggestions = false;
          _canSaveFromManually = false;
        } else {
          _toLocation = LatLng(33.6844, 73.0479); // Islamabad coordinates
          _showToSuggestions = false;
          _canSaveToManually = false;
        }
      });

      HapticFeedback.lightImpact();
      _checkAndNavigateBack();
    } finally {
      setState(() {
        if (field == 'from') {
          _isGeocodingFrom = false;
        } else {
          _isGeocodingTo = false;
        }
      });
    }
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

  void _onSuggestionTap(AddressSuggestion suggestion, String field) {
    HapticFeedback.lightImpact();
    
    setState(() {
      if (field == 'from') {
        _fromController.text = suggestion.address;
        _fromLocation = suggestion.location;
        _showFromSuggestions = false;
        _canSaveFromManually = false;
        _fromFocusNode.unfocus();
        
        // Auto-focus to field if from is filled and to is empty
        if (_toController.text.isEmpty) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              _toFocusNode.requestFocus();
            }
          });
        }
      } else {
        _toController.text = suggestion.address;
        _toLocation = suggestion.location;
        _showToSuggestions = false;
        _canSaveToManually = false;
        _toFocusNode.unfocus();
      }
    });

    // Auto-navigate back if both fields are filled
    _checkAndNavigateBack();
  }

  void _checkAndNavigateBack() {
    if (_fromLocation != null && _toLocation != null && 
        _fromController.text.isNotEmpty && _toController.text.isNotEmpty) {
      
      // Show success feedback
      HapticFeedback.mediumImpact();
      
      // Small delay to show the selection before navigating back
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          Navigator.pop(context, {
            'pickup': {
              'location': _fromLocation,
              'address': _fromController.text,
            },
            'dropoff': {
              'location': _toLocation,
              'address': _toController.text,
            },
          });
        }
      });
    }
  }

  void _onChooseOnMap() {
    HapticFeedback.lightImpact();
    Navigator.pop(context, {
      'choose_on_map': true,
      'pickup': _fromLocation != null ? {
        'location': _fromLocation,
        'address': _fromController.text,
      } : null,
      'dropoff': _toLocation != null ? {
        'location': _toLocation,
        'address': _toController.text,
      } : null,
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _fromController.dispose();
    _toController.dispose();
    _fromFocusNode.dispose();
    _toFocusNode.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              // Header
              _buildHeader(isTablet),
              
              // Content
              Expanded(
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    children: [
                      // Input Fields
                      _buildInputFields(isTablet),
                      
                      // Choose on Map Option
                      _buildChooseOnMapOption(isTablet),
                      
                      // Manual Save Options
                      if (_canSaveFromManually || _canSaveToManually)
                        _buildManualSaveOptions(isTablet),
                      
                      // Suggestions
                      if (_showFromSuggestions || _showToSuggestions)
                        Expanded(child: _buildSuggestionsList(isTablet)),
                      
                      // Show completion indicator when both fields are filled
                      if (_fromLocation != null && _toLocation != null)
                        _buildCompletionIndicator(isTablet),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 24 : 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 40), // Spacer for centering
          Text(
            'Enter your route',
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 22 : 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close,
                color: Colors.white,
                size: isTablet ? 24 : 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputFields(bool isTablet) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 20),
      child: Column(
        children: [
          // Pickup Location Section
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFFFD700), // Golden yellow border
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pickup Location Label
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFD700), // Golden yellow dot
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Pickup Location',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 16 : 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFFFD700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Pickup Input Field
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: TextField(
                    controller: _fromController,
                    focusNode: _fromFocusNode,
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 16 : 14,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Type pickup address in Pakistan',
                      hintStyle: GoogleFonts.albertSans(
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w400,
                        fontSize: isTablet ? 14 : 12,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.grey.shade600,
                        size: 20,
                      ),
                      suffixIcon: _fromController.text.isNotEmpty
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isGeocodingFrom)
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                  ),
                                IconButton(
                                  onPressed: () {
                                    _fromController.clear();
                                    _fromLocation = null;
                                    setState(() {
                                      _showFromSuggestions = false;
                                      _canSaveFromManually = false;
                                    });
                                  },
                                  icon: Icon(
                                    Icons.clear,
                                    color: Colors.grey.shade600,
                                    size: 18,
                                  ),
                                ),
                              ],
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 20 : 16,
                        vertical: isTablet ? 16 : 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Drop Off Location Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.3), // Light gray border
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drop Off Location Label
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Drop Off Location',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 16 : 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Drop Off Input Field
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: TextField(
                    controller: _toController,
                    focusNode: _toFocusNode,
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 16 : 14,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Type address in Pakistan',
                      hintStyle: GoogleFonts.albertSans(
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w400,
                        fontSize: isTablet ? 14 : 12,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.grey.shade600,
                        size: 20,
                      ),
                      suffixIcon: _toController.text.isNotEmpty
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isGeocodingTo)
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                  ),
                                IconButton(
                                  onPressed: () {
                                    _toController.clear();
                                    _toLocation = null;
                                    setState(() {
                                      _showToSuggestions = false;
                                      _canSaveToManually = false;
                                    });
                                  },
                                  icon: Icon(
                                    Icons.clear,
                                    color: Colors.grey.shade600,
                                    size: 18,
                                  ),
                                ),
                              ],
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 20 : 16,
                        vertical: isTablet ? 16 : 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualSaveOptions(bool isTablet) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 20),
      child: Column(
        children: [
          if (_canSaveFromManually && _activeField == 'from')
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => _saveManualAddress(_fromController.text, 'from'),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 20 : 16,
                    vertical: isTablet ? 12 : 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFFFD700).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700).withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add_location,
                          color: Color(0xFFFFD700),
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Use "${_fromController.text}" as pickup location',
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 14 : 12,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFFFFD700),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: Color(0xFFFFD700),
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_canSaveToManually && _activeField == 'to')
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => _saveManualAddress(_toController.text, 'to'),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 20 : 16,
                    vertical: isTablet ? 12 : 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.add_location,
                          color: Colors.white.withOpacity(0.8),
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Use "${_toController.text}" as drop-off location',
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 14 : 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white.withOpacity(0.8),
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChooseOnMapOption(bool isTablet) {
    return GestureDetector(
      onTap: _onChooseOnMap,
      child: Container(
        margin: EdgeInsets.all(isTablet ? 24 : 20),
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 20 : 16,
          vertical: isTablet ? 16 : 14,
        ),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.location_on,
                color: Colors.blue,
                size: isTablet ? 24 : 20,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              'Choose on map',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 16 : 14,
                fontWeight: FontWeight.w500,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionIndicator(bool isTablet) {
    return Container(
      margin: EdgeInsets.all(isTablet ? 24 : 20),
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 20 : 16,
        vertical: isTablet ? 12 : 10,
      ),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.green.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check,
              color: Colors.green,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Route complete - returning to map...',
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 14 : 12,
              fontWeight: FontWeight.w500,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsList(bool isTablet) {
    List<AddressSuggestion> suggestions = _showFromSuggestions 
        ? _fromSuggestions 
        : _toSuggestions;
    String field = _showFromSuggestions ? 'from' : 'to';
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 20),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D3C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: suggestions.length,
        itemBuilder: (context, index) {
          final suggestion = suggestions[index];
          return Container(
            decoration: BoxDecoration(
              border: index < suggestions.length - 1
                  ? Border(
                      bottom: BorderSide(
                        color: Colors.white.withOpacity(0.1),
                        width: 0.5,
                      ),
                    )
                  : null,
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: field == 'from' 
                      ? const Color(0xFFFFD700).withOpacity(0.2)
                      : Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.location_on,
                  color: field == 'from' 
                      ? const Color(0xFFFFD700) 
                      : Colors.white.withOpacity(0.8),
                  size: 18,
                ),
              ),
              title: Text(
                suggestion.address,
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 14 : 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: suggestion.displayName != suggestion.address
                  ? Text(
                      suggestion.displayName,
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 12 : 11,
                        color: Colors.white.withOpacity(0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : null,
              onTap: () => _onSuggestionTap(suggestion, field),
            ),
          );
        },
      ),
    );
  }
}

class AddressSuggestion {
  final String address;
  final String placeId;
  final LatLng location;
  final String displayName;
  final Map<String, dynamic> addressComponents;
  final double importance;

  AddressSuggestion({
    required this.address,
    required this.placeId,
    required this.location,
    required this.displayName,
    required this.addressComponents,
    required this.importance,
  });
}