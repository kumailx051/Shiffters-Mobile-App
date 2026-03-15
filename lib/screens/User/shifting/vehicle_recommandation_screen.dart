import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shiffters/theme/app_colors.dart';
import 'package:shiffters/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shiffters/services/theme_service.dart';
import 'dart:async';
import 'dart:math' as math;
import 'shifting_package_details_screen.dart';

class VehicleRecommendationScreen extends StatefulWidget {
  final Map<String, dynamic>? routeData;
  final List<String>? items;

  const VehicleRecommendationScreen({
    super.key,
    this.routeData,
    this.items,
  });

  @override
  State<VehicleRecommendationScreen> createState() =>
      _VehicleRecommendationScreenState();
}

class _VehicleRecommendationScreenState
    extends State<VehicleRecommendationScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _selectionController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  int _selectedVehicleIndex = -1;
  bool _isCalculatingPrice = false;
  List<VehicleOption> _vehicles = [];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _generateVehicleRecommendations();
    _startAnimations();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _selectionController = AnimationController(
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

    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _selectionController,
      curve: Curves.elasticOut,
    ));
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) {
      _animationController.forward();
    }
  }

  void _generateVehicleRecommendations() {
    final itemCount = widget.items?.length ?? 0;
    final distance = widget.routeData?['distance'] ?? 10.0;

    // Generate vehicle options based on items and distance for shifting purposes
    _vehicles = [
      VehicleOption(
        id: 'mini_pickup',
        name: 'Mini Pickup (Suzuki Ravi)',
        subtitle: 'Ideal for small home moves',
        capacity: '500 kg',
        dimensions: '180×150×120 cm',
        estimatedTime:
            '${(distance * 3.5).round()}-${(distance * 4.5).round()} min',
        basePrice: _calculatePrice('mini_pickup', distance, itemCount),
        features: ['Economical', 'Good for small loads', 'Easy to navigate'],
        icon: Icons.local_shipping,
        color: Colors.blue,
        isRecommended: itemCount <= 8,
        maxItems: 8,
      ),
      VehicleOption(
        id: 'pickup_truck',
        name: 'Pickup Truck (Shehzore / Hilux)',
        subtitle: 'Perfect for medium home moves',
        capacity: '800 kg',
        dimensions: '250×170×150 cm',
        estimatedTime:
            '${(distance * 4).round()}-${(distance * 5).round()} min',
        basePrice: _calculatePrice('pickup_truck', distance, itemCount),
        features: [
          'Strong & durable',
          'Weather resistant',
          'Professional loading'
        ],
        icon: Icons.fire_truck,
        color: Colors.green,
        isRecommended: itemCount > 8 && itemCount <= 12,
        maxItems: 12,
      ),
      VehicleOption(
        id: 'small_truck',
        name: 'Small Truck (Tata Ace)',
        subtitle: 'For small to medium relocations',
        capacity: '1,000 kg',
        dimensions: '270×180×170 cm',
        estimatedTime:
            '${(distance * 4.5).round()}-${(distance * 5.5).round()} min',
        basePrice: _calculatePrice('small_truck', distance, itemCount),
        features: ['Fuel efficient', 'Compact size', 'Urban-friendly'],
        icon: Icons.fire_truck,
        color: Colors.amber,
        isRecommended: itemCount > 10 && itemCount <= 15,
        maxItems: 15,
      ),
      VehicleOption(
        id: 'medium_truck',
        name: 'Medium Truck (Canter 1 Ton)',
        subtitle: 'For medium apartment moves',
        capacity: '1,500 kg',
        dimensions: '320×210×200 cm',
        estimatedTime:
            '${(distance * 5).round()}-${(distance * 6).round()} min',
        basePrice: _calculatePrice('medium_truck', distance, itemCount),
        features: ['Spacious', 'Secure loading', 'Complete house moves'],
        icon: Icons.fire_truck,
        color: Colors.orange,
        isRecommended: itemCount > 15 && itemCount <= 20,
        maxItems: 20,
      ),
      VehicleOption(
        id: 'large_truck',
        name: 'Large Truck (Mazda 2–3 Ton)',
        subtitle: 'For full house relocations',
        capacity: '3,000 kg',
        dimensions: '400×230×220 cm',
        estimatedTime:
            '${(distance * 5.5).round()}-${(distance * 7).round()} min',
        basePrice: _calculatePrice('large_truck', distance, itemCount),
        features: ['Heavy duty', 'Bulk transport', 'Large furniture friendly'],
        icon: Icons.fire_truck,
        color: Colors.red,
        isRecommended: itemCount > 20 && itemCount <= 30,
        maxItems: 30,
      ),
      VehicleOption(
        id: 'covered_truck',
        name: 'Covered Truck / Container',
        subtitle: 'For weather-sensitive items',
        capacity: '2,000 kg',
        dimensions: '380×220×220 cm',
        estimatedTime:
            '${(distance * 5).round()}-${(distance * 6.5).round()} min',
        basePrice: _calculatePrice('covered_truck', distance, itemCount),
        features: ['Weatherproof', 'Secure transport', 'Good for electronics'],
        icon: Icons.fire_truck,
        color: Colors.purple,
        isRecommended: itemCount > 15 && itemCount <= 25,
        maxItems: 25,
      ),
      VehicleOption(
        id: 'loading_van',
        name: 'Loading Van',
        subtitle: 'For quick commercial moves',
        capacity: '1,000 kg',
        dimensions: '300×190×190 cm',
        estimatedTime:
            '${(distance * 4).round()}-${(distance * 5).round()} min',
        basePrice: _calculatePrice('loading_van', distance, itemCount),
        features: ['Easy loading', 'Fast transit', 'Office relocations'],
        icon: Icons.airport_shuttle,
        color: Colors.teal,
        isRecommended: itemCount > 10 && itemCount <= 15,
        maxItems: 15,
      ),
      VehicleOption(
        id: 'open_truck',
        name: 'Open Body Truck',
        subtitle: 'For construction materials',
        capacity: '2,500 kg',
        dimensions: '370×220×180 cm',
        estimatedTime:
            '${(distance * 5).round()}-${(distance * 6).round()} min',
        basePrice: _calculatePrice('open_truck', distance, itemCount),
        features: ['High capacity', 'Easy loading', 'Oversized items'],
        icon: Icons.fire_truck,
        color: Colors.brown,
        isRecommended: itemCount > 20 && itemCount <= 28,
        maxItems: 28,
      ),
      VehicleOption(
        id: 'trailer',
        name: 'Trailer Truck (for bulk shifting)',
        subtitle: 'For large commercial relocations',
        capacity: '7,000 kg',
        dimensions: '600×250×280 cm',
        estimatedTime:
            '${(distance * 6).round()}-${(distance * 8).round()} min',
        basePrice: _calculatePrice('trailer', distance, itemCount),
        features: ['Maximum capacity', 'Long distance', 'Full office moves'],
        icon: Icons.fire_truck,
        color: Colors.blueGrey,
        isRecommended: itemCount > 30,
        maxItems: 60,
      ),
      VehicleOption(
        id: 'furniture_truck',
        name: 'Furniture Carrier Truck',
        subtitle: 'Specialized for furniture',
        capacity: '2,000 kg',
        dimensions: '400×230×220 cm',
        estimatedTime:
            '${(distance * 5).round()}-${(distance * 6.5).round()} min',
        basePrice: _calculatePrice('furniture_truck', distance, itemCount),
        features: ['Padded interior', 'Furniture specific', 'Extra care'],
        icon: Icons.chair,
        color: Colors.indigo,
        isRecommended: false, // Specialized case, not based on count
        maxItems: 25,
      ),
    ];

    // Sort by recommendation
    _vehicles.sort((a, b) => b.isRecommended ? 1 : -1);
  }

  double _calculatePrice(String vehicleType, double distance, int itemCount) {
    // More realistic pricing for shifting vehicles in Pakistan (in PKR)
    Map<String, double> basePrices = {
      'mini_pickup': 2500.0,
      'pickup_truck': 3500.0,
      'small_truck': 4000.0,
      'medium_truck': 5500.0,
      'large_truck': 7000.0,
      'covered_truck': 6500.0,
      'loading_van': 4500.0,
      'open_truck': 6000.0,
      'trailer': 12000.0,
      'furniture_truck': 8000.0,
    };

    Map<String, double> perKmRates = {
      'mini_pickup': 25.0,
      'pickup_truck': 35.0,
      'small_truck': 40.0,
      'medium_truck': 50.0,
      'large_truck': 65.0,
      'covered_truck': 60.0,
      'loading_van': 45.0,
      'open_truck': 55.0,
      'trailer': 100.0,
      'furniture_truck': 70.0,
    };

    // Get base price with fallback
    double basePrice = basePrices[vehicleType] ?? 4000.0;

    // Get per km rate with fallback
    double perKmRate = perKmRates[vehicleType] ?? 40.0;

    // Item multiplier - additional cost for more items (logistics, loading time)
    // Less aggressive than before since shifting vehicle prices already account for capacity
    double itemMultiplier = 1.0 + (itemCount * 0.05);

    // Calculate total price
    double totalPrice = (basePrice + (distance * perKmRate)) * itemMultiplier;

    // Round to nearest hundred for cleaner pricing
    return (totalPrice / 100).round() * 100;
  }

  void _selectVehicle(int index) {
    HapticFeedback.lightImpact();

    setState(() {
      _selectedVehicleIndex = index;
    });

    _selectionController.forward().then((_) {
      _selectionController.reverse();
    });
  }

  void _onContinue() {
    if (_selectedVehicleIndex == -1) {
      _showMessage('Please select a vehicle option', isError: true);
      return;
    }

    HapticFeedback.lightImpact();

    final selectedVehicle = _vehicles[_selectedVehicleIndex];

    // Prepare data for the next screen
    Map<String, dynamic> shiftingData = {
      'vehicle': selectedVehicle.toMap(),
      'route_data': widget.routeData,
      'items': widget.items,
    };

    // Navigate to the shifting package details screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ShiftingPackageDetailsScreen(shiftingData: shiftingData),
      ),
    );
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

  @override
  void dispose() {
    _animationController.dispose();
    _selectionController.dispose();
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
            child: Column(
              children: [
                // Header
                _buildHeader(isTablet, isDarkMode),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 24 : 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),

                        // Title and Description
                        _buildTitleSection(isTablet, isDarkMode),

                        const SizedBox(height: 20),

                        // Route Summary
                        _buildRouteSummary(isTablet, isDarkMode),

                        const SizedBox(height: 30),

                        // Vehicle Options
                        _buildVehicleOptions(isTablet, isDarkMode),

                        const SizedBox(height: 100), // Space for bottom button
                      ],
                    ),
                  ),
                ),

                // Bottom Continue Button
                _buildBottomButton(isTablet, isDarkMode),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isTablet, bool isDarkMode) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: EdgeInsets.all(isTablet ? 24 : 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.1)
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
            Text(
              'Choose Vehicle',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 22 : 20,
                fontWeight: FontWeight.bold,
                color:
                    isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.1)
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
                Icons.local_shipping,
                color: isDarkMode
                    ? AppColors.yellowAccent
                    : AppTheme.lightPrimaryColor,
                size: isTablet ? 24 : 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleSection(bool isTablet, bool isDarkMode) {
    return SlideTransition(
      position: _slideAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recommended Vehicles',
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 24 : 22,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Based on your items and route, we recommend these vehicles for optimal delivery.',
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 16 : 14,
              fontWeight: FontWeight.w400,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.7)
                  : AppTheme.lightTextSecondaryColor,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteSummary(bool isTablet, bool isDarkMode) {
    final distance = widget.routeData?['distance'] ?? 0.0;
    final itemCount = widget.items?.length ?? 0;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
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
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.route,
                        color: isDarkMode
                            ? AppColors.yellowAccent
                            : AppTheme.lightPrimaryColor,
                        size: isTablet ? 20 : 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Route Distance',
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 14 : 12,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.7)
                              : AppTheme.lightTextSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${distance.toStringAsFixed(1)} km',
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 18 : 16,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode
                          ? Colors.white
                          : AppTheme.lightTextPrimaryColor,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              height: 40,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.2)
                  : AppTheme.lightBorderColor,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 16),
                      Icon(
                        Icons.inventory_2_outlined,
                        color: isDarkMode
                            ? AppColors.yellowAccent
                            : AppTheme.lightPrimaryColor,
                        size: isTablet ? 20 : 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Total Items',
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 14 : 12,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.7)
                              : AppTheme.lightTextSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Text(
                      '$itemCount items',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 18 : 16,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode
                            ? Colors.white
                            : AppTheme.lightTextPrimaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleOptions(bool isTablet, bool isDarkMode) {
    return SlideTransition(
      position: _slideAnimation,
      child: Column(
        children: List.generate(_vehicles.length, (index) {
          final vehicle = _vehicles[index];
          final isSelected = _selectedVehicleIndex == index;

          return AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: isSelected ? _scaleAnimation.value : 1.0,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: GestureDetector(
                    onTap: () => _selectVehicle(index),
                    child: Container(
                      padding: EdgeInsets.all(isTablet ? 20 : 16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDarkMode
                                ? AppColors.yellowAccent.withValues(alpha: 0.1)
                                : AppTheme.lightPrimaryColor
                                    .withValues(alpha: 0.05))
                            : (isDarkMode
                                ? Colors.white.withValues(alpha: 0.1)
                                : AppTheme.lightCardColor),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? (isDarkMode
                                  ? AppColors.yellowAccent
                                  : AppTheme.lightPrimaryColor)
                              : (isDarkMode
                                  ? Colors.white.withValues(alpha: 0.2)
                                  : AppTheme.lightBorderColor),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: isDarkMode
                                      ? AppColors.yellowAccent
                                          .withValues(alpha: 0.2)
                                      : AppTheme.lightPrimaryColor
                                          .withValues(alpha: 0.15),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : (isDarkMode
                                ? null
                                : [
                                    BoxShadow(
                                      color: AppTheme.lightShadowMedium,
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header with icon and vehicle name
                          Row(
                            children: [
                              Container(
                                width: isTablet ? 60 : 50,
                                height: isTablet ? 60 : 50,
                                decoration: BoxDecoration(
                                  color: vehicle.color.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  vehicle.icon,
                                  color: vehicle.color,
                                  size: isTablet ? 32 : 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      vehicle.name,
                                      style: GoogleFonts.albertSans(
                                        fontSize: isTablet ? 18 : 16,
                                        fontWeight: FontWeight.bold,
                                        color: isDarkMode
                                            ? Colors.white
                                            : AppTheme.lightTextPrimaryColor,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      vehicle.subtitle,
                                      style: GoogleFonts.albertSans(
                                        fontSize: isTablet ? 14 : 12,
                                        fontWeight: FontWeight.w400,
                                        color: isDarkMode
                                            ? Colors.white
                                                .withValues(alpha: 0.7)
                                            : AppTheme.lightTextSecondaryColor,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Vehicle specs
                          Row(
                            children: [
                              Expanded(
                                child: _buildSpecItem(
                                  Icons.scale,
                                  'Capacity',
                                  vehicle.capacity,
                                  isTablet,
                                  isDarkMode,
                                ),
                              ),
                              Expanded(
                                child: _buildSpecItem(
                                  Icons.straighten,
                                  'Dimensions',
                                  vehicle.dimensions,
                                  isTablet,
                                  isDarkMode,
                                ),
                              ),
                              Expanded(
                                child: _buildSpecItem(
                                  Icons.access_time,
                                  'ETA',
                                  vehicle.estimatedTime,
                                  isTablet,
                                  isDarkMode,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Features
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: vehicle.features.map((feature) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? Colors.white.withValues(alpha: 0.1)
                                      : AppTheme.lightBorderColor
                                          .withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  feature,
                                  style: GoogleFonts.albertSans(
                                    fontSize: isTablet ? 12 : 10,
                                    fontWeight: FontWeight.w500,
                                    color: isDarkMode
                                        ? Colors.white.withValues(alpha: 0.8)
                                        : AppTheme.lightTextSecondaryColor,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),

                          // Price and recommendation bottom bar
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.only(top: 12),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: isDarkMode
                                      ? Colors.white.withValues(alpha: 0.1)
                                      : AppTheme.lightBorderColor
                                          .withValues(alpha: 0.5),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Recommended badge
                                if (vehicle.isRecommended)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDarkMode
                                          ? AppColors.yellowAccent
                                          : AppTheme.lightPrimaryColor,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.recommend,
                                          size: isTablet ? 14 : 12,
                                          color: isDarkMode
                                              ? Colors.black
                                              : Colors.white,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'RECOMMENDED',
                                          style: GoogleFonts.albertSans(
                                            fontSize: isTablet ? 11 : 10,
                                            fontWeight: FontWeight.bold,
                                            color: isDarkMode
                                                ? Colors.black
                                                : Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  const SizedBox(), // Empty space if not recommended

                                // Price
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'PKR ${vehicle.basePrice.round()}',
                                      style: GoogleFonts.albertSans(
                                        fontSize: isTablet ? 18 : 16,
                                        fontWeight: FontWeight.bold,
                                        color: isDarkMode
                                            ? AppColors.yellowAccent
                                            : AppTheme.lightPrimaryColor,
                                      ),
                                    ),
                                    Text(
                                      'Estimated',
                                      style: GoogleFonts.albertSans(
                                        fontSize: isTablet ? 12 : 10,
                                        fontWeight: FontWeight.w400,
                                        color: isDarkMode
                                            ? Colors.white
                                                .withValues(alpha: 0.5)
                                            : AppTheme.lightTextSecondaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }

  Widget _buildSpecItem(IconData icon, String label, String value,
      bool isTablet, bool isDarkMode) {
    return Column(
      children: [
        Icon(
          icon,
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.7)
              : AppTheme.lightPrimaryColor,
          size: isTablet ? 20 : 18,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.albertSans(
            fontSize: isTablet ? 12 : 10,
            fontWeight: FontWeight.w500,
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.6)
                : AppTheme.lightTextSecondaryColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.albertSans(
            fontSize: isTablet ? 14 : 12,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }

  Widget _buildBottomButton(bool isTablet, bool isDarkMode) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: EdgeInsets.all(isTablet ? 24 : 20),
        decoration: BoxDecoration(
          color: isDarkMode
              ? const Color(0xFF1E1E2C).withValues(alpha: 0.95)
              : AppTheme.lightCardColor.withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Selected vehicle info
            if (_selectedVehicleIndex != -1)
              Flexible(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 16 : 12,
                    vertical: isTablet ? 12 : 10,
                  ),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.1)
                        : AppTheme.lightBorderColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _vehicles[_selectedVehicleIndex].icon,
                        color: isDarkMode
                            ? AppColors.yellowAccent
                            : AppTheme.lightPrimaryColor,
                        size: isTablet ? 20 : 18,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _vehicles[_selectedVehicleIndex].name,
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 14 : 12,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode
                                ? Colors.white
                                : AppTheme.lightTextPrimaryColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              const SizedBox.shrink(),

            // Continue Button positioned on the right
            GestureDetector(
              onTap: _onContinue,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 32 : 24,
                  vertical: isTablet ? 16 : 14,
                ),
                decoration: BoxDecoration(
                  color: _selectedVehicleIndex != -1
                      ? (isDarkMode
                          ? AppColors.yellowAccent
                          : AppTheme.lightPrimaryColor)
                      : (isDarkMode
                          ? Colors.grey.withValues(alpha: 0.3)
                          : AppTheme.lightBorderColor.withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: _selectedVehicleIndex != -1
                      ? [
                          BoxShadow(
                            color: isDarkMode
                                ? AppColors.yellowAccent.withValues(alpha: 0.3)
                                : AppTheme.lightPrimaryColor
                                    .withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selectedVehicleIndex != -1
                          ? 'Continue'
                          : 'Select a Vehicle',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 16 : 14,
                        fontWeight: FontWeight.bold,
                        color: _selectedVehicleIndex != -1
                            ? (isDarkMode ? Colors.black : Colors.white)
                            : (isDarkMode
                                ? Colors.white
                                : AppTheme.lightTextSecondaryColor),
                      ),
                    ),
                    if (_selectedVehicleIndex != -1) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward,
                        color: isDarkMode ? Colors.black : Colors.white,
                        size: isTablet ? 20 : 18,
                      ),
                    ],
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

class VehicleOption {
  final String id;
  final String name;
  final String subtitle;
  final String capacity;
  final String dimensions;
  final String estimatedTime;
  final double basePrice;
  final List<String> features;
  final IconData icon;
  final Color color;
  final bool isRecommended;
  final int maxItems;

  VehicleOption({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.capacity,
    required this.dimensions,
    required this.estimatedTime,
    required this.basePrice,
    required this.features,
    required this.icon,
    required this.color,
    required this.isRecommended,
    required this.maxItems,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'subtitle': subtitle,
      'capacity': capacity,
      'dimensions': dimensions,
      'estimatedTime': estimatedTime,
      'basePrice': basePrice,
      'features': features,
      'isRecommended': isRecommended,
      'maxItems': maxItems,
    };
  }
}
