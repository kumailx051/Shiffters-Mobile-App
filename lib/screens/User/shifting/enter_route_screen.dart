import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:shiffters/theme/app_colors.dart';
import 'package:shiffters/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shiffters/services/theme_service.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

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

class _EnterRouteScreenState extends State<EnterRouteScreen>
    with TickerProviderStateMixin {
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
    if (address.length >= 8) {
      setState(() {
        if (field == 'from') {
          _canSaveFromManually = true;
        } else {
          _canSaveToManually = true;
        }
      });
    }

    _searchTimer = Timer(const Duration(milliseconds: 200), () {
      _searchAddresses(address, field);
    });
  }

  Future<void> _searchAddresses(String query, String field) async {
    try {
      List<AddressSuggestion> allSuggestions = [];

      // First, try multiple enhanced search strategies
      await Future.wait([
        _searchWithNominatim(query)
            .then((results) => allSuggestions.addAll(results)),
        _searchWithPhoton(query)
            .then((results) => allSuggestions.addAll(results)),
        _searchWithLocalPatterns(query)
            .then((results) => allSuggestions.addAll(results)),
      ]);

      // Remove duplicates based on location proximity (within 100 meters)
      List<AddressSuggestion> uniqueSuggestions = [];
      for (var suggestion in allSuggestions) {
        bool isDuplicate = false;
        for (var existing in uniqueSuggestions) {
          double distance = _calculateDistance(
            suggestion.location.latitude,
            suggestion.location.longitude,
            existing.location.latitude,
            existing.location.longitude,
          );
          if (distance < 0.1) {
            // Less than 100 meters
            isDuplicate = true;
            // Keep the one with better relevance
            if (suggestion.importance > existing.importance) {
              uniqueSuggestions.remove(existing);
              uniqueSuggestions.add(suggestion);
            }
            break;
          }
        }
        if (!isDuplicate) {
          uniqueSuggestions.add(suggestion);
        }
      }

      // Sort suggestions by relevance and Pakistani address patterns
      uniqueSuggestions.sort((a, b) {
        String queryLower = query.toLowerCase();
        String aLower = a.address.toLowerCase();
        String bLower = b.address.toLowerCase();

        // Prioritize exact sector matches (G-10, F-7, etc.)
        bool aHasSector = _containsPakistaniSector(aLower, queryLower);
        bool bHasSector = _containsPakistaniSector(bLower, queryLower);
        if (aHasSector && !bHasSector) return -1;
        if (!aHasSector && bHasSector) return 1;

        // Prioritize street addresses over general areas
        int aTypeWeight = _getAddressTypeWeight(a.placeType, a.address);
        int bTypeWeight = _getAddressTypeWeight(b.placeType, b.address);
        if (aTypeWeight != bTypeWeight)
          return aTypeWeight.compareTo(bTypeWeight);

        // Prioritize exact matches
        if (aLower.startsWith(queryLower) && !bLower.startsWith(queryLower))
          return -1;
        if (!aLower.startsWith(queryLower) && bLower.startsWith(queryLower))
          return 1;

        // Then by relevance score
        return b.importance.compareTo(a.importance);
      });

      // Limit to 10 suggestions for better UX
      if (uniqueSuggestions.length > 10) {
        uniqueSuggestions = uniqueSuggestions.take(10).toList();
      }

      setState(() {
        if (field == 'from') {
          _fromSuggestions = uniqueSuggestions;
          _showFromSuggestions = uniqueSuggestions.isNotEmpty;
          if (uniqueSuggestions.isEmpty && query.length >= 8) {
            _canSaveFromManually = true;
          }
        } else {
          _toSuggestions = uniqueSuggestions;
          _showToSuggestions = uniqueSuggestions.isNotEmpty;
          if (uniqueSuggestions.isEmpty && query.length >= 8) {
            _canSaveToManually = true;
          }
        }
      });
    } catch (e) {
      debugPrint('Error searching addresses: $e');
      _fallbackGeocoding(query, field);
    }
  }

  // Enhanced Nominatim search with Pakistani-specific parameters
  Future<List<AddressSuggestion>> _searchWithNominatim(String query) async {
    List<AddressSuggestion> suggestions = [];

    try {
      // Enhance query for Pakistani addressing patterns
      String enhancedQuery = _enhanceQueryForPakistan(query);

      final response = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/search?'
            'q=${Uri.encodeComponent(enhancedQuery)}&'
            'format=json&'
            'limit=15&'
            'addressdetails=1&'
            'countrycodes=pk&'
            'bounded=1&'
            'viewbox=60.9,23.6,77.8,37.1&'
            'extratags=1&'
            'namedetails=1&'
            'dedupe=1&'
            'polygon_geojson=0'),
        headers: {
          'User-Agent': 'ShifftersApp/1.0 (contact@shiffters.com)',
          'Accept-Language': 'en,ur',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        for (var item in data) {
          double lat = double.parse(item['lat']);
          double lon = double.parse(item['lon']);

          if (_isLocationInPakistan(lat, lon)) {
            String formattedAddress =
                _formatEnhancedPakistaniAddress(item, query);
            double relevance = _calculateRelevanceScore(item, query);

            suggestions.add(AddressSuggestion(
              address: formattedAddress,
              placeId: item['place_id']?.toString() ?? '',
              location: LatLng(lat, lon),
              displayName: item['display_name'] ?? '',
              addressComponents: item['address'] ?? {},
              importance: relevance,
              placeType: _determinePlaceType(item),
              context: [],
            ));
          }
        }
      }
    } catch (e) {
      debugPrint('Nominatim search error: $e');
    }

    return suggestions;
  }

  // Photon search for additional coverage
  Future<List<AddressSuggestion>> _searchWithPhoton(String query) async {
    List<AddressSuggestion> suggestions = [];

    try {
      String enhancedQuery = _enhanceQueryForPakistan(query);

      final response = await http.get(
        Uri.parse('https://photon.komoot.io/api/?'
            'q=${Uri.encodeComponent(enhancedQuery)}&'
            'limit=10&'
            'osm_tag=place:city,place:town,place:village,place:suburb,place:neighbourhood,'
            'highway:residential,highway:primary,highway:secondary,highway:tertiary,'
            'amenity:hospital,amenity:school,amenity:university,amenity:bank,'
            'shop:supermarket,shop:mall&'
            'bbox=60.9,23.6,77.8,37.1&'
            'lang=en'),
        headers: {
          'User-Agent': 'ShifftersApp/1.0',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> features = data['features'] ?? [];

        for (var feature in features) {
          final geometry = feature['geometry'];
          final properties = feature['properties'] ?? {};

          if (geometry != null && geometry['coordinates'] != null) {
            final coordinates = geometry['coordinates'];
            double lon = coordinates[0].toDouble();
            double lat = coordinates[1].toDouble();

            if (_isLocationInPakistan(lat, lon)) {
              String formattedAddress = _formatPhotonAddress(properties, query);
              double relevance = _calculatePhotonRelevance(properties, query);

              suggestions.add(AddressSuggestion(
                address: formattedAddress,
                placeId: properties['osm_id']?.toString() ?? '',
                location: LatLng(lat, lon),
                displayName: properties['name'] ?? formattedAddress,
                addressComponents: properties,
                importance: relevance,
                placeType: _determinePhotonPlaceType(properties),
                context: [],
              ));
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Photon search error: $e');
    }

    return suggestions;
  }

  // Local pattern matching for Pakistani addresses
  Future<List<AddressSuggestion>> _searchWithLocalPatterns(String query) async {
    List<AddressSuggestion> suggestions = [];

    // Check if query matches Pakistani sector patterns
    if (_isPakistaniSectorPattern(query)) {
      // Generate suggestions for common sector variations
      List<String> sectorVariations = _generateSectorVariations(query);

      for (String variation in sectorVariations) {
        try {
          List<Location> locations =
              await locationFromAddress('$variation, Pakistan');

          for (Location location in locations.take(2)) {
            if (_isLocationInPakistan(location.latitude, location.longitude)) {
              suggestions.add(AddressSuggestion(
                address: variation,
                placeId: 'local_${variation.replaceAll(' ', '_')}',
                location: LatLng(location.latitude, location.longitude),
                displayName: '$variation, Pakistan',
                addressComponents: {},
                importance: 0.8,
                placeType: 'sector',
                context: [],
              ));
            }
          }
        } catch (e) {
          debugPrint('Local pattern search error for $variation: $e');
        }
      }
    }

    return suggestions;
  }

  // Helper methods for Pakistani address patterns
  String _enhanceQueryForPakistan(String query) {
    String enhanced = query.trim();

    // Handle sector patterns (G-10, F-7, etc.)
    if (RegExp(r'^[A-Z]-?\d+(/\d+)?', caseSensitive: false)
        .hasMatch(enhanced)) {
      // Add common Pakistani cities for sector searches
      List<String> majorCities = [
        'Islamabad',
        'Lahore',
        'Karachi',
        'Rawalpindi'
      ];
      for (String city in majorCities) {
        if (!enhanced.toLowerCase().contains(city.toLowerCase())) {
          enhanced = '$enhanced $city';
          break; // Try with first major city
        }
      }
    }

    // Handle street patterns
    if (enhanced.toLowerCase().contains('street') ||
        enhanced.toLowerCase().contains('road') ||
        enhanced.toLowerCase().contains('lane')) {
      if (!enhanced.toLowerCase().contains('pakistan')) {
        enhanced = '$enhanced Pakistan';
      }
    }

    return enhanced;
  }

  bool _isPakistaniSectorPattern(String query) {
    return RegExp(r'^[A-Z]-?\d+(/\d+)?\s*(street|road|lane|\d+)?',
            caseSensitive: false)
        .hasMatch(query.trim());
  }

  List<String> _generateSectorVariations(String query) {
    List<String> variations = [];

    // Common Pakistani cities with sector systems
    List<String> sectorCities = [
      'Islamabad',
      'Rawalpindi',
      'Lahore',
      'Faisalabad',
      'Multan'
    ];

    for (String city in sectorCities) {
      variations.add('$query, $city, Pakistan');
      variations.add('Sector $query, $city, Pakistan');

      // Add common sector suffixes
      if (!query.contains('/')) {
        variations.add('$query/1, $city, Pakistan');
        variations.add('$query/2, $city, Pakistan');
        variations.add('$query/3, $city, Pakistan');
        variations.add('$query/4, $city, Pakistan');
      }
    }

    return variations;
  }

  bool _containsPakistaniSector(String address, String query) {
    // Check if address contains sector pattern that matches query
    RegExp sectorPattern = RegExp(r'[A-Z]-?\d+(/\d+)?', caseSensitive: false);
    RegExp queryPattern = RegExp(r'[A-Z]-?\d+(/\d+)?', caseSensitive: false);

    Match? addressMatch = sectorPattern.firstMatch(address);
    Match? queryMatch = queryPattern.firstMatch(query);

    if (addressMatch != null && queryMatch != null) {
      return addressMatch.group(0)?.toLowerCase() ==
          queryMatch.group(0)?.toLowerCase();
    }

    return false;
  }

  int _getAddressTypeWeight(String placeType, String address) {
    // Prioritize street addresses and sectors
    if (placeType == 'sector' || _containsSectorPattern(address)) return 1;
    if (placeType == 'address' || address.toLowerCase().contains('street'))
      return 2;
    if (placeType == 'poi') return 3;
    if (placeType == 'neighborhood') return 4;
    if (placeType == 'locality') return 5;
    return 6;
  }

  bool _containsSectorPattern(String address) {
    return RegExp(r'[A-Z]-?\d+(/\d+)?', caseSensitive: false).hasMatch(address);
  }

  String _formatEnhancedPakistaniAddress(
      Map<String, dynamic> item, String query) {
    Map<String, dynamic> address = item['address'] ?? {};
    List<String> addressParts = [];

    // Handle house number and street
    if (address['house_number'] != null &&
        address['house_number'].toString().isNotEmpty) {
      addressParts.add(address['house_number'].toString());
    }

    // Handle road/street with various keys
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

    // Handle sectors and neighborhoods
    List<String> areaKeys = [
      'suburb',
      'neighbourhood',
      'quarter',
      'residential',
      'commercial'
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

    // Handle city/town
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

    // Add state/province
    if (address['state'] != null && address['state'].toString().isNotEmpty) {
      addressParts.add(address['state'].toString());
    }

    // Always add Pakistan
    addressParts.add('Pakistan');

    // Clean up duplicates
    List<String> cleanedParts = [];
    for (String part in addressParts) {
      String cleaned = part.trim();
      if (cleaned.isNotEmpty &&
          !cleanedParts.any(
              (existing) => existing.toLowerCase() == cleaned.toLowerCase())) {
        cleanedParts.add(cleaned);
      }
    }

    return cleanedParts.join(', ');
  }

  String _formatPhotonAddress(Map<String, dynamic> properties, String query) {
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

  double _calculateRelevanceScore(Map<String, dynamic> item, String query) {
    double score =
        double.tryParse(item['importance']?.toString() ?? '0') ?? 0.0;

    String displayName = (item['display_name'] ?? '').toLowerCase();
    String queryLower = query.toLowerCase();

    // Boost score for exact matches
    if (displayName.contains(queryLower)) {
      score += 0.3;
    }

    // Boost score for sector matches
    if (_containsPakistaniSector(displayName, queryLower)) {
      score += 0.5;
    }

    // Boost score for street addresses
    if (displayName.contains('street') || displayName.contains('road')) {
      score += 0.2;
    }

    return score;
  }

  double _calculatePhotonRelevance(
      Map<String, dynamic> properties, String query) {
    double score = 0.5; // Base score

    String name = (properties['name'] ?? '').toLowerCase();
    String queryLower = query.toLowerCase();

    if (name.contains(queryLower)) {
      score += 0.4;
    }

    if (_containsPakistaniSector(name, queryLower)) {
      score += 0.3;
    }

    return score;
  }

  String _determinePlaceType(Map<String, dynamic> item) {
    String type = item['type'] ?? '';
    String className = item['class'] ?? '';

    if (type == 'house' || className == 'building') return 'address';
    if (type == 'road' || className == 'highway') return 'street';
    if (type == 'suburb' || type == 'neighbourhood') return 'neighborhood';
    if (type == 'city' || type == 'town') return 'locality';
    if (className == 'amenity' || className == 'shop') return 'poi';

    return 'address';
  }

  String _determinePhotonPlaceType(Map<String, dynamic> properties) {
    String osmKey = properties['osm_key'] ?? '';
    String osmValue = properties['osm_value'] ?? '';

    if (osmKey == 'highway') return 'street';
    if (osmKey == 'place' && ['city', 'town', 'village'].contains(osmValue))
      return 'locality';
    if (osmKey == 'place' && ['suburb', 'neighbourhood'].contains(osmValue))
      return 'neighborhood';
    if (osmKey == 'amenity' || osmKey == 'shop') return 'poi';

    return 'address';
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);

    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  bool _isLocationInPakistan(double lat, double lng) {
    const double northBound = 37.1;
    const double southBound = 23.6;
    const double eastBound = 77.8;
    const double westBound = 60.9;

    return lat >= southBound &&
        lat <= northBound &&
        lng >= westBound &&
        lng <= eastBound;
  }

  Future<void> _fallbackGeocoding(String query, String field) async {
    try {
      String pakistanQuery = '$query, Pakistan';
      List<Location> locations = await locationFromAddress(pakistanQuery);
      List<AddressSuggestion> suggestions = [];

      for (int i = 0; i < locations.length && i < 5; i++) {
        if (_isLocationInPakistan(
            locations[i].latitude, locations[i].longitude)) {
          suggestions.add(AddressSuggestion(
            address: '$query, Pakistan',
            placeId: 'local_$i',
            location: LatLng(locations[i].latitude, locations[i].longitude),
            displayName: '$query, Pakistan',
            addressComponents: {},
            importance: 0.5,
            placeType: 'address',
            context: [],
          ));
        }
      }

      setState(() {
        if (field == 'from') {
          _fromSuggestions = suggestions;
          _showFromSuggestions = suggestions.isNotEmpty;
          if (suggestions.isEmpty && query.length >= 8) {
            _canSaveFromManually = true;
          }
        } else {
          _toSuggestions = suggestions;
          _showToSuggestions = suggestions.isNotEmpty;
          if (suggestions.isEmpty && query.length >= 8) {
            _canSaveToManually = true;
          }
        }
      });
    } catch (e) {
      debugPrint('Error with fallback geocoding: $e');
      setState(() {
        if (field == 'from' && query.length >= 8) {
          _canSaveFromManually = true;
        } else if (field == 'to' && query.length >= 8) {
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
      String pakistanQuery =
          address.contains('Pakistan') ? address : '$address, Pakistan';
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
      debugPrint('Error geocoding manual address: $e');
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
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isDarkMode = themeService.isDarkMode;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isDarkMode
            ? Colors.red.withValues(alpha: 0.9)
            : Colors.red.shade600,
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

  // Convert from latlong2 LatLng to Google Maps LatLng
  gmaps.LatLng? _convertToGoogleMapsLatLng(LatLng? latlongLatLng) {
    if (latlongLatLng == null) return null;
    return gmaps.LatLng(latlongLatLng.latitude, latlongLatLng.longitude);
  }

  void _checkAndNavigateBack() {
    if (_fromLocation != null &&
        _toLocation != null &&
        _fromController.text.isNotEmpty &&
        _toController.text.isNotEmpty) {
      // Show success feedback
      HapticFeedback.mediumImpact();

      // Small delay to show the selection before navigating back
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          Navigator.pop(context, {
            'pickup': {
              'location': _convertToGoogleMapsLatLng(_fromLocation),
              'address': _fromController.text,
            },
            'dropoff': {
              'location': _convertToGoogleMapsLatLng(_toLocation),
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
      'pickup': _fromLocation != null
          ? {
              'location': _convertToGoogleMapsLatLng(_fromLocation),
              'address': _fromController.text,
            }
          : null,
      'dropoff': _toLocation != null
          ? {
              'location': _convertToGoogleMapsLatLng(_toLocation),
              'address': _toController.text,
            }
          : null,
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

    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        final isDarkMode = themeService.isDarkMode;

        return Scaffold(
          backgroundColor: isDarkMode
              ? const Color(0xFF1E1E2C)
              : AppTheme.lightBackgroundColor,
          body: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  // Header
                  _buildHeader(isTablet, isDarkMode),

                  // Content
                  Expanded(
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        children: [
                          // Input Fields
                          _buildInputFields(isTablet, isDarkMode),

                          // Choose on Map Option
                          _buildChooseOnMapOption(isTablet, isDarkMode),

                          // Manual Save Options
                          if (_canSaveFromManually || _canSaveToManually)
                            _buildManualSaveOptions(isTablet, isDarkMode),

                          // Suggestions
                          if (_showFromSuggestions || _showToSuggestions)
                            Expanded(
                                child: _buildSuggestionsList(
                                    isTablet, isDarkMode)),

                          // Show completion indicator when both fields are filled
                          if (_fromLocation != null && _toLocation != null)
                            _buildCompletionIndicator(isTablet, isDarkMode),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isTablet, bool isDarkMode) {
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
              color: isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.1)
                    : AppTheme.lightPrimaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close,
                color:
                    isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
                size: isTablet ? 24 : 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputFields(bool isTablet, bool isDarkMode) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 20),
      child: Column(
        children: [
          // Pickup Location Section - Matching addLocation_screen style
          Container(
            margin: const EdgeInsets.only(bottom: 16),
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
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pickup Location Label
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
                // Pickup Input Field
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isDarkMode
                        ? []
                        : [
                            BoxShadow(
                              color: AppTheme.lightShadowMedium,
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: TextField(
                    controller: _fromController,
                    focusNode: _fromFocusNode,
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 16 : 14,
                      color: isDarkMode
                          ? Colors.black87
                          : AppTheme.lightTextPrimaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g., G-10/3, Street 12, Sector F-7',
                      hintStyle: GoogleFonts.albertSans(
                        color: isDarkMode
                            ? Colors.grey.shade500
                            : AppTheme.lightTextLightColor,
                        fontWeight: FontWeight.w400,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: isDarkMode
                            ? Colors.grey.shade600
                            : AppTheme.lightTextSecondaryColor,
                        size: isTablet ? 24 : 20,
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
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          isDarkMode
                                              ? AppColors.yellowAccent
                                              : AppTheme.lightPrimaryColor,
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
                                    color: isDarkMode
                                        ? Colors.grey.shade600
                                        : AppTheme.lightTextSecondaryColor,
                                    size: 18,
                                  ),
                                ),
                              ],
                            )
                          : null,
                      filled: true,
                      fillColor: isDarkMode
                          ? Colors.white.withValues(alpha: 0.95)
                          : AppTheme.lightCardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
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
              ],
            ),
          ),

          // Drop Off Location Section - Matching addLocation_screen style
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
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drop Off Location Label
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
                // Drop Off Input Field
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isDarkMode
                        ? []
                        : [
                            BoxShadow(
                              color: AppTheme.lightShadowMedium,
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: TextField(
                    controller: _toController,
                    focusNode: _toFocusNode,
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 16 : 14,
                      color: isDarkMode
                          ? Colors.black87
                          : AppTheme.lightTextPrimaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g., F-8 Markaz, Blue Area, Mall Road',
                      hintStyle: GoogleFonts.albertSans(
                        color: isDarkMode
                            ? Colors.grey.shade500
                            : AppTheme.lightTextLightColor,
                        fontWeight: FontWeight.w400,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: isDarkMode
                            ? Colors.grey.shade600
                            : AppTheme.lightTextSecondaryColor,
                        size: isTablet ? 24 : 20,
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
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          isDarkMode
                                              ? AppColors.yellowAccent
                                              : AppTheme.lightPrimaryColor,
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
                                    color: isDarkMode
                                        ? Colors.grey.shade600
                                        : AppTheme.lightTextSecondaryColor,
                                    size: 18,
                                  ),
                                ),
                              ],
                            )
                          : null,
                      filled: true,
                      fillColor: isDarkMode
                          ? Colors.white.withValues(alpha: 0.95)
                          : AppTheme.lightCardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualSaveOptions(bool isTablet, bool isDarkMode) {
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
                    color: isDarkMode
                        ? AppColors.yellowAccent.withValues(alpha: 0.1)
                        : AppTheme.lightPrimaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDarkMode
                          ? AppColors.yellowAccent.withValues(alpha: 0.3)
                          : AppTheme.lightPrimaryColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? AppColors.yellowAccent.withValues(alpha: 0.2)
                              : AppTheme.lightPrimaryColor
                                  .withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.add_location,
                          color: isDarkMode
                              ? AppColors.yellowAccent
                              : AppTheme.lightPrimaryColor,
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
                            color: isDarkMode
                                ? AppColors.yellowAccent
                                : AppTheme.lightPrimaryColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: isDarkMode
                            ? AppColors.yellowAccent
                            : AppTheme.lightPrimaryColor,
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
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.1)
                        : AppTheme.lightCardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.3)
                          : AppTheme.lightBorderColor,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.2)
                              : AppTheme.lightPrimaryColor
                                  .withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.add_location,
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.8)
                              : AppTheme.lightPrimaryColor,
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
                            color: isDarkMode
                                ? Colors.white.withValues(alpha: 0.8)
                                : AppTheme.lightTextPrimaryColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.8)
                            : AppTheme.lightTextSecondaryColor,
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

  Widget _buildChooseOnMapOption(bool isTablet, bool isDarkMode) {
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
                color: isDarkMode
                    ? Colors.blue.withValues(alpha: 0.2)
                    : AppTheme.lightPrimaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.location_on,
                color: isDarkMode ? Colors.blue : AppTheme.lightPrimaryColor,
                size: isTablet ? 24 : 20,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              'Choose on map',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 16 : 14,
                fontWeight: FontWeight.w500,
                color: isDarkMode ? Colors.blue : AppTheme.lightPrimaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionIndicator(bool isTablet, bool isDarkMode) {
    return Container(
      margin: EdgeInsets.all(isTablet ? 24 : 20),
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 20 : 16,
        vertical: isTablet ? 12 : 10,
      ),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.green.withValues(alpha: 0.1)
            : AppTheme.lightGreenAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDarkMode
              ? Colors.green.withValues(alpha: 0.3)
              : AppTheme.lightGreenAccent.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.green.withValues(alpha: 0.2)
                  : AppTheme.lightGreenAccent.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check,
              color: isDarkMode ? Colors.green : AppTheme.lightGreenAccent,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Route complete - returning to map...',
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 14 : 12,
              fontWeight: FontWeight.w500,
              color: isDarkMode ? Colors.green : AppTheme.lightGreenAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsList(bool isTablet, bool isDarkMode) {
    List<AddressSuggestion> suggestions =
        _showFromSuggestions ? _fromSuggestions : _toSuggestions;
    String field = _showFromSuggestions ? 'from' : 'to';

    return Container(
      margin: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2D2D3C) : AppTheme.lightCardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : AppTheme.lightBorderColor,
          width: 1,
        ),
        boxShadow: isDarkMode
            ? []
            : [
                BoxShadow(
                  color: AppTheme.lightShadowMedium,
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
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
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.1)
                            : AppTheme.lightBorderColor,
                        width: 0.5,
                      ),
                    )
                  : null,
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? (field == 'from'
                          ? AppColors.yellowAccent.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.2))
                      : (field == 'from'
                          ? AppTheme.lightPrimaryColor.withValues(alpha: 0.2)
                          : AppTheme.lightTextSecondaryColor
                              .withValues(alpha: 0.2)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getPlaceTypeIcon(suggestion.placeType),
                  color: isDarkMode
                      ? (field == 'from'
                          ? AppColors.yellowAccent
                          : Colors.white.withValues(alpha: 0.8))
                      : (field == 'from'
                          ? AppTheme.lightPrimaryColor
                          : AppTheme.lightTextSecondaryColor),
                  size: 18,
                ),
              ),
              title: Text(
                suggestion.address,
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 14 : 13,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode
                      ? Colors.white
                      : AppTheme.lightTextPrimaryColor,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (suggestion.displayName != suggestion.address)
                    Text(
                      suggestion.displayName,
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 12 : 11,
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.6)
                            : AppTheme.lightTextLightColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  // Show place type badge
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getPlaceTypeColor(suggestion.placeType)
                          .withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getPlaceTypeLabel(suggestion.placeType),
                      style: GoogleFonts.albertSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: _getPlaceTypeColor(suggestion.placeType),
                      ),
                    ),
                  ),
                ],
              ),
              onTap: () => _onSuggestionTap(suggestion, field),
            ),
          );
        },
      ),
    );
  }

  // Helper methods for place type display
  IconData _getPlaceTypeIcon(String placeType) {
    switch (placeType) {
      case 'address':
      case 'street':
        return Icons.home;
      case 'sector':
        return Icons.grid_view;
      case 'poi':
        return Icons.place;
      case 'neighborhood':
        return Icons.location_city;
      case 'locality':
        return Icons.location_on;
      default:
        return Icons.location_on;
    }
  }

  Color _getPlaceTypeColor(String placeType) {
    switch (placeType) {
      case 'address':
      case 'street':
        return Colors.green;
      case 'sector':
        return Colors.amber;
      case 'poi':
        return Colors.blue;
      case 'neighborhood':
        return Colors.orange;
      case 'locality':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getPlaceTypeLabel(String placeType) {
    switch (placeType) {
      case 'address':
        return 'Street Address';
      case 'street':
        return 'Street';
      case 'sector':
        return 'Sector';
      case 'poi':
        return 'Point of Interest';
      case 'neighborhood':
        return 'Neighborhood';
      case 'locality':
        return 'City/Town';
      default:
        return 'Location';
    }
  }
}

class AddressSuggestion {
  final String address;
  final String placeId;
  final LatLng location;
  final String displayName;
  final Map<String, dynamic> addressComponents;
  final double importance;
  final String placeType;
  final List<dynamic> context;

  AddressSuggestion({
    required this.address,
    required this.placeId,
    required this.location,
    required this.displayName,
    required this.addressComponents,
    required this.importance,
    this.placeType = 'address',
    this.context = const [],
  });
}
