import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shiffters/theme/app_colors.dart';
import 'dart:async';
import 'dart:math' as math;

class VehicleRecommendationScreen extends StatefulWidget {
  final Map<String, dynamic>? routeData;
  final List<String>? items;

  const VehicleRecommendationScreen({
    super.key,
    this.routeData,
    this.items,
  });

  @override
  State<VehicleRecommendationScreen> createState() => _VehicleRecommendationScreenState();
}

class _VehicleRecommendationScreenState extends State<VehicleRecommendationScreen> 
    with TickerProviderStateMixin {
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
    
    // Generate vehicle options based on items and distance
    _vehicles = [
      VehicleOption(
        id: 'bike',
        name: 'Motorcycle',
        subtitle: 'Perfect for small items',
        capacity: '15 kg',
        dimensions: '40×30×25 cm',
        estimatedTime: '${(distance * 2.5).round()}-${(distance * 3.5).round()} min',
        basePrice: _calculatePrice('bike', distance, itemCount),
        features: ['Fast delivery', 'Eco-friendly', 'Traffic-friendly'],
        icon: Icons.two_wheeler,
        color: Colors.blue,
        isRecommended: itemCount <= 2,
        maxItems: 2,
      ),
      VehicleOption(
        id: 'rickshaw',
        name: 'Auto Rickshaw',
        subtitle: 'Great for medium loads',
        capacity: '50 kg',
        dimensions: '80×60×50 cm',
        estimatedTime: '${(distance * 3).round()}-${(distance * 4).round()} min',
        basePrice: _calculatePrice('rickshaw', distance, itemCount),
        features: ['Covered transport', 'Weather protection', 'Affordable'],
        icon: Icons.agriculture,
        color: Colors.green,
        isRecommended: itemCount > 2 && itemCount <= 5,
        maxItems: 5,
      ),
      VehicleOption(
        id: 'van',
        name: 'Delivery Van',
        subtitle: 'Ideal for furniture & appliances',
        capacity: '200 kg',
        dimensions: '180×120×100 cm',
        estimatedTime: '${(distance * 4).round()}-${(distance * 5).round()} min',
        basePrice: _calculatePrice('van', distance, itemCount),
        features: ['Large capacity', 'Furniture friendly', 'Professional service'],
        icon: Icons.local_shipping,
        color: Colors.orange,
        isRecommended: itemCount > 5 && itemCount <= 10,
        maxItems: 10,
      ),
      VehicleOption(
        id: 'truck',
        name: 'Mini Truck',
        subtitle: 'For heavy & bulk items',
        capacity: '500 kg',
        dimensions: '250×150×120 cm',
        estimatedTime: '${(distance * 5).round()}-${(distance * 6).round()} min',
        basePrice: _calculatePrice('truck', distance, itemCount),
        features: ['Heavy duty', 'Bulk transport', 'Loading assistance'],
        icon: Icons.fire_truck,
        color: Colors.red,
        isRecommended: itemCount > 10,
        maxItems: 20,
      ),
    ];

    // Sort by recommendation
    _vehicles.sort((a, b) => b.isRecommended ? 1 : -1);
  }

  double _calculatePrice(String vehicleType, double distance, int itemCount) {
    Map<String, double> basePrices = {
      'bike': 150.0,
      'rickshaw': 250.0,
      'van': 500.0,
      'truck': 800.0,
    };

    Map<String, double> perKmRates = {
      'bike': 8.0,
      'rickshaw': 12.0,
      'van': 20.0,
      'truck': 30.0,
    };

    double basePrice = basePrices[vehicleType] ?? 200.0;
    double perKmRate = perKmRates[vehicleType] ?? 15.0;
    double itemMultiplier = 1.0 + (itemCount * 0.1);

    return (basePrice + (distance * perKmRate)) * itemMultiplier;
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
    
    // Navigate to next screen with vehicle data
    Navigator.pop(context, {
      'vehicle': selectedVehicle.toMap(),
      'route_data': widget.routeData,
      'items': widget.items,
    });
  }

  void _showMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError 
            ? Colors.red.withOpacity(0.9)
            : Colors.green.withOpacity(0.9),
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

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(isTablet),
            
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
                    _buildTitleSection(isTablet),
                    
                    const SizedBox(height: 20),
                    
                    // Route Summary
                    _buildRouteSummary(isTablet),
                    
                    const SizedBox(height: 30),
                    
                    // Vehicle Options
                    _buildVehicleOptions(isTablet),
                    
                    const SizedBox(height: 100), // Space for bottom button
                  ],
                ),
              ),
            ),
            
            // Bottom Continue Button
            _buildBottomButton(isTablet),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isTablet) {
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
                  color: Colors.white.withOpacity(0.1),
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
              'Choose Vehicle',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 22 : 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.local_shipping,
                color: AppColors.yellowAccent,
                size: isTablet ? 24 : 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleSection(bool isTablet) {
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
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Based on your items and route, we recommend these vehicles for optimal delivery.',
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 16 : 14,
              fontWeight: FontWeight.w400,
              color: Colors.white.withOpacity(0.7),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteSummary(bool isTablet) {
    final distance = widget.routeData?['distance'] ?? 0.0;
    final itemCount = widget.items?.length ?? 0;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: EdgeInsets.all(isTablet ? 20 : 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
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
                        color: AppColors.yellowAccent,
                        size: isTablet ? 20 : 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Route Distance',
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 14 : 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.7),
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
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              height: 40,
              color: Colors.white.withOpacity(0.2),
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
                        color: AppColors.yellowAccent,
                        size: isTablet ? 20 : 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Total Items',
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 14 : 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.7),
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
                        color: Colors.white,
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

  Widget _buildVehicleOptions(bool isTablet) {
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
                            ? AppColors.yellowAccent.withOpacity(0.1)
                            : Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected 
                              ? AppColors.yellowAccent
                              : Colors.white.withOpacity(0.2),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected ? [
                          BoxShadow(
                            color: AppColors.yellowAccent.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ] : null,
                      ),
                      child: Column(
                        children: [
                          // Header with icon and recommendation badge
                          Row(
                            children: [
                              Container(
                                width: isTablet ? 60 : 50,
                                height: isTablet ? 60 : 50,
                                decoration: BoxDecoration(
                                  color: vehicle.color.withOpacity(0.2),
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
                                    Row(
                                      children: [
                                        Text(
                                          vehicle.name,
                                          style: GoogleFonts.albertSans(
                                            fontSize: isTablet ? 18 : 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        if (vehicle.isRecommended) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.yellowAccent,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              'RECOMMENDED',
                                              style: GoogleFonts.albertSans(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      vehicle.subtitle,
                                      style: GoogleFonts.albertSans(
                                        fontSize: isTablet ? 14 : 12,
                                        fontWeight: FontWeight.w400,
                                        color: Colors.white.withOpacity(0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'PKR ${vehicle.basePrice.round()}',
                                    style: GoogleFonts.albertSans(
                                      fontSize: isTablet ? 18 : 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.yellowAccent,
                                    ),
                                  ),
                                  Text(
                                    'Estimated',
                                    style: GoogleFonts.albertSans(
                                      fontSize: isTablet ? 12 : 10,
                                      fontWeight: FontWeight.w400,
                                      color: Colors.white.withOpacity(0.5),
                                    ),
                                  ),
                                ],
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
                                ),
                              ),
                              Expanded(
                                child: _buildSpecItem(
                                  Icons.straighten,
                                  'Dimensions',
                                  vehicle.dimensions,
                                  isTablet,
                                ),
                              ),
                              Expanded(
                                child: _buildSpecItem(
                                  Icons.access_time,
                                  'ETA',
                                  vehicle.estimatedTime,
                                  isTablet,
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
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  feature,
                                  style: GoogleFonts.albertSans(
                                    fontSize: isTablet ? 12 : 10,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              );
                            }).toList(),
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

  Widget _buildSpecItem(IconData icon, String label, String value, bool isTablet) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.white.withOpacity(0.7),
          size: isTablet ? 20 : 18,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.albertSans(
            fontSize: isTablet ? 12 : 10,
            fontWeight: FontWeight.w500,
            color: Colors.white.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.albertSans(
            fontSize: isTablet ? 14 : 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildBottomButton(bool isTablet) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: EdgeInsets.all(isTablet ? 24 : 20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2C).withOpacity(0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Row(
          children: [
            // Selected vehicle info
            if (_selectedVehicleIndex != -1) ...[
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 16 : 12,
                  vertical: isTablet ? 12 : 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _vehicles[_selectedVehicleIndex].icon,
                      color: AppColors.yellowAccent,
                      size: isTablet ? 20 : 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _vehicles[_selectedVehicleIndex].name,
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 14 : 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
            ],
            
            // Continue Button
            Expanded(
              child: GestureDetector(
                onTap: _onContinue,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    vertical: isTablet ? 16 : 14,
                  ),
                  decoration: BoxDecoration(
                    color: _selectedVehicleIndex != -1 
                        ? AppColors.yellowAccent
                        : Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: _selectedVehicleIndex != -1 ? [
                      BoxShadow(
                        color: AppColors.yellowAccent.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ] : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _selectedVehicleIndex != -1 
                            ? 'Continue with ${_vehicles[_selectedVehicleIndex].name}'
                            : 'Select a Vehicle',
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 16 : 14,
                          fontWeight: FontWeight.bold,
                          color: _selectedVehicleIndex != -1 ? Colors.black : Colors.white,
                        ),
                      ),
                      if (_selectedVehicleIndex != -1) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward,
                          color: Colors.black,
                          size: isTablet ? 20 : 18,
                        ),
                      ],
                    ],
                  ),
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