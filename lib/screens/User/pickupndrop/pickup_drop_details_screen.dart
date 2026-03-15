import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shiffters/theme/app_colors.dart';
import 'package:shiffters/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shiffters/services/theme_service.dart';
import 'pickup_drop_payment_screen.dart';

class PickupDropDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> routeData;

  const PickupDropDetailsScreen({
    super.key,
    required this.routeData,
  });

  @override
  State<PickupDropDetailsScreen> createState() =>
      _PickupDropDetailsScreenState();
}

class _PickupDropDetailsScreenState extends State<PickupDropDetailsScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String _selectedVehicleType = 'Bike';
  String _selectedTimeSlot = 'As soon as possible';
  bool _isLoading = false;

  final List<Map<String, dynamic>> _vehicleTypes = [
    {
      'name': 'Bike',
      'icon': Icons.motorcycle,
      'description': 'Small packages, fast delivery',
      'maxWeight': '5 kg',
      'price': 150.0,
    },
    {
      'name': 'Car',
      'icon': Icons.directions_car,
      'description': 'Medium packages, standard delivery',
      'maxWeight': '20 kg',
      'price': 300.0,
    },
    {
      'name': 'Van',
      'icon': Icons.local_shipping,
      'description': 'Large packages, standard delivery',
      'maxWeight': '100 kg',
      'price': 500.0,
    },
  ];

  final List<String> _timeSlots = [
    'As soon as possible',
    'Today (2-4 hours)',
    'Today (4-6 hours)',
    'Tomorrow morning',
    'Tomorrow afternoon',
    'Schedule for later',
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
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
      begin: const Offset(0, 0.1),
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

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  double _calculatePrice() {
    // Get base price from selected vehicle
    double basePrice = _vehicleTypes
        .firstWhere((v) => v['name'] == _selectedVehicleType)['price'];

    // Get distance from route data safely
    double distance = 0.0;
    try {
      distance = (widget.routeData['distance'] as num?)?.toDouble() ?? 5.0;
    } catch (e) {
      distance = 5.0; // Default distance
    }

    // Get weight from package details
    double weight = 1.0; // Default weight
    try {
      final packageDetails =
          widget.routeData['packageDetails'] as Map<String, dynamic>?;
      if (packageDetails != null && packageDetails['weight'] != null) {
        weight = double.tryParse(packageDetails['weight'].toString()) ?? 1.0;
      }
    } catch (e) {
      weight = 1.0; // Default weight
    }

    // Calculate price based on distance, weight, and vehicle type
    double pricePerKm = basePrice / 10; // Price per km
    double pricePerKg = 10.0; // Price per kg (Rs. 10 per kg)

    // Base formula: base price + (distance * price per km) + (weight * price per kg)
    double totalPrice =
        basePrice + (distance * pricePerKm) + (weight * pricePerKg);

    // Add fragile handling charge if applicable
    final packageDetails =
        widget.routeData['packageDetails'] as Map<String, dynamic>?;
    if (packageDetails != null && packageDetails['isFragile'] == true) {
      totalPrice += 100; // Additional Rs. 100 for fragile items
    }

    // Round to nearest 10
    return (totalPrice / 10).round() * 10;
  }

  void _onContinue() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      HapticFeedback.lightImpact();

      // Prepare data for next screen
      Map<String, dynamic> packageData = {
        ...widget.routeData,
        'vehicleType': _selectedVehicleType,
        'timeSlot': _selectedTimeSlot,
        'price': _calculatePrice(),
      };

      // Add a small delay to show loading state
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        // Navigate to payment screen (next step in the flow)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                PickupDropPaymentScreen(packageData: packageData),
          ),
        );
      }
    } catch (e) {
      // Handle navigation error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Navigation error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final isSmallScreen = screenSize.width < 360;

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
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 32 : 20,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),

                          // Route Summary
                          _buildRouteSummary(isTablet, isDarkMode),

                          const SizedBox(height: 30),

                          // Vehicle Type Selection
                          _buildVehicleTypeSelection(isTablet, isDarkMode),

                          const SizedBox(height: 30),

                          // Time Slot Selection
                          _buildTimeSlotSelection(isTablet, isDarkMode),

                          const SizedBox(height: 30),

                          // Price Summary
                          _buildPriceSummary(isTablet, isDarkMode),

                          const SizedBox(
                              height: 100), // Space for bottom button
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar:
              _buildBottomBar(isTablet, isSmallScreen, isDarkMode),
        );
      },
    );
  }

  Widget _buildHeader(bool isTablet, bool isDarkMode) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 32 : 20,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.black.withValues(alpha: 0.3)
            : AppTheme.lightCardColor.withValues(alpha: 0.95),
        boxShadow: isDarkMode
            ? null
            : [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.arrow_back,
                color:
                    isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
                size: isTablet ? 24 : 20,
              ),
            ),
          ),
          Text(
            'Delivery Details',
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 20 : 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
            ),
          ),
          const SizedBox(width: 40), // Balance the header
        ],
      ),
    );
  }

  Widget _buildRouteSummary(bool isTablet, bool isDarkMode) {
    // Safely extract route data
    String pickupAddress = 'Unknown pickup location';
    String dropoffAddress = 'Unknown dropoff location';
    double distance = 0.0;

    try {
      pickupAddress = widget.routeData['pickup']?['address']?.toString() ??
          'Unknown pickup location';
      dropoffAddress = widget.routeData['dropoff']?['address']?.toString() ??
          'Unknown dropoff location';
      distance = (widget.routeData['distance'] as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      debugPrint('Error extracting route data: $e');
    }

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          padding: EdgeInsets.all(isTablet ? 24 : 20),
          decoration: BoxDecoration(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.1)
                : AppTheme.lightCardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.blue,
              width: 1,
            ),
            boxShadow: isDarkMode
                ? null
                : [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.1),
                      spreadRadius: 1,
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Route Summary',
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 18 : 16,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode
                      ? Colors.white
                      : AppTheme.lightTextPrimaryColor,
                ),
              ),

              const SizedBox(height: 16),

              // Pickup Location
              _buildLocationRow(
                icon: Icons.my_location,
                iconColor: AppColors.yellowAccent,
                title: 'Pickup',
                address: pickupAddress,
                isTablet: isTablet,
                isDarkMode: isDarkMode,
              ),

              const SizedBox(height: 16),

              // Drop-off Location
              _buildLocationRow(
                icon: Icons.location_on,
                iconColor: Colors.red,
                title: 'Drop-off',
                address: dropoffAddress,
                isTablet: isTablet,
                isDarkMode: isDarkMode,
              ),

              const SizedBox(height: 16),

              // Distance
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.straighten,
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.7)
                          : Colors.black.withValues(alpha: 0.7),
                      size: isTablet ? 18 : 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Distance: ${distance.toStringAsFixed(1)} km',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 14 : 12,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode ? Colors.white : Colors.black,
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
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String address,
    required bool isTablet,
    required bool isDarkMode,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDarkMode
                ? iconColor.withValues(alpha: 0.2)
                : (iconColor == AppColors.yellowAccent
                    ? AppTheme.lightPrimaryColor.withValues(alpha: 0.1)
                    : iconColor.withValues(alpha: 0.1)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: isDarkMode
                ? iconColor
                : (iconColor == AppColors.yellowAccent
                    ? AppTheme.lightPrimaryColor
                    : iconColor),
            size: isTablet ? 20 : 16,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 14 : 12,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.7)
                      : AppTheme.lightTextSecondaryColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                address,
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 14 : 12,
                  color: isDarkMode
                      ? Colors.white
                      : AppTheme.lightTextPrimaryColor,
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

  Widget _buildVehicleTypeSelection(bool isTablet, bool isDarkMode) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Vehicle Type',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 18 : 16,
                fontWeight: FontWeight.bold,
                color:
                    isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
              ),
            ),

            const SizedBox(height: 16),

            // Vehicle Type Cards
            ...List.generate(_vehicleTypes.length, (index) {
              final vehicle = _vehicleTypes[index];
              final isSelected = _selectedVehicleType == vehicle['name'];

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedVehicleType = vehicle['name'];
                  });
                  HapticFeedback.lightImpact();
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: EdgeInsets.all(isTablet ? 16 : 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDarkMode
                            ? AppColors.yellowAccent.withValues(alpha: 0.2)
                            : AppTheme.lightPrimaryColor.withValues(alpha: 0.1))
                        : (isDarkMode
                            ? Colors.white.withValues(alpha: 0.05)
                            : AppTheme.lightCardColor),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? (isDarkMode
                              ? AppColors.yellowAccent
                              : AppTheme.lightPrimaryColor)
                          : (isDarkMode
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.blue),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isDarkMode
                        ? null
                        : [
                            BoxShadow(
                              color: Colors.grey.withValues(alpha: 0.1),
                              spreadRadius: 1,
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: isTablet ? 60 : 50,
                        height: isTablet ? 60 : 50,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.yellowAccent.withValues(alpha: 0.2)
                              : (isDarkMode
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.grey.withValues(alpha: 0.1)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          vehicle['icon'] as IconData,
                          color: isSelected
                              ? AppColors.yellowAccent
                              : (isDarkMode ? Colors.white : Colors.black),
                          size: isTablet ? 30 : 25,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vehicle['name'] as String,
                              style: GoogleFonts.albertSans(
                                fontSize: isTablet ? 16 : 14,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode
                                    ? Colors.white
                                    : AppTheme.lightTextPrimaryColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              vehicle['description'] as String,
                              style: GoogleFonts.albertSans(
                                fontSize: isTablet ? 14 : 12,
                                color: isDarkMode
                                    ? Colors.white.withValues(alpha: 0.7)
                                    : AppTheme.lightTextSecondaryColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Max weight: ${vehicle['maxWeight']}',
                              style: GoogleFonts.albertSans(
                                fontSize: isTablet ? 12 : 10,
                                color: isDarkMode
                                    ? Colors.white.withValues(alpha: 0.5)
                                    : AppTheme.lightTextSecondaryColor
                                        .withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDarkMode
                                  ? AppColors.yellowAccent
                                  : AppTheme.lightPrimaryColor)
                              : (isDarkMode
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : AppTheme.lightBackgroundColor),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Rs. ${vehicle['price'].toStringAsFixed(0)}',
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 14 : 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : (isDarkMode
                                    ? Colors.white
                                    : AppTheme.lightTextPrimaryColor),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSlotSelection(bool isTablet, bool isDarkMode) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Time Slot',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 18 : 16,
                fontWeight: FontWeight.bold,
                color:
                    isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
              ),
            ),

            const SizedBox(height: 16),

            // Time Slot Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isTablet ? 3 : 2,
                childAspectRatio: isTablet ? 2.5 : 2.2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _timeSlots.length,
              itemBuilder: (context, index) {
                final timeSlot = _timeSlots[index];
                final isSelected = _selectedTimeSlot == timeSlot;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedTimeSlot = timeSlot;
                    });
                    HapticFeedback.lightImpact();
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDarkMode
                              ? AppColors.yellowAccent.withValues(alpha: 0.2)
                              : AppTheme.lightPrimaryColor
                                  .withValues(alpha: 0.1))
                          : (isDarkMode
                              ? Colors.white.withValues(alpha: 0.05)
                              : AppTheme.lightCardColor),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? (isDarkMode
                                ? AppColors.yellowAccent
                                : AppTheme.lightPrimaryColor)
                            : (isDarkMode
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.blue),
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isDarkMode
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.grey.withValues(alpha: 0.1),
                                spreadRadius: 1,
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          index == 0
                              ? Icons.access_time_filled
                              : Icons.access_time,
                          color: isSelected
                              ? (isDarkMode
                                  ? AppColors.yellowAccent
                                  : AppTheme.lightPrimaryColor)
                              : (isDarkMode
                                  ? Colors.white
                                  : AppTheme.lightTextPrimaryColor),
                          size: isTablet ? 20 : 18,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          timeSlot,
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 12 : 10,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isDarkMode
                                ? Colors.white
                                : AppTheme.lightTextPrimaryColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
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

  Widget _buildPriceSummary(bool isTablet, bool isDarkMode) {
    final price = _calculatePrice();
    final basePrice = _vehicleTypes
        .firstWhere((v) => v['name'] == _selectedVehicleType)['price'];
    final distanceCost = price - basePrice;

    double distance = 0.0;
    try {
      distance = (widget.routeData['distance'] as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      distance = 0.0;
    }

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          padding: EdgeInsets.all(isTablet ? 24 : 20),
          decoration: BoxDecoration(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.blue,
              width: 1,
            ),
            boxShadow: isDarkMode
                ? null
                : [
                    BoxShadow(
                      color: AppColors.yellowAccent.withValues(alpha: 0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Price Summary',
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 18 : 16,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),

              const SizedBox(height: 16),

              // Base Price
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Base Price ($_selectedVehicleType)',
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 14 : 12,
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.7)
                          : Colors.black.withValues(alpha: 0.7),
                    ),
                  ),
                  Text(
                    'Rs. ${basePrice.toStringAsFixed(0)}',
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 14 : 12,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Distance Cost
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Distance (${distance.toStringAsFixed(1)} km)',
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 14 : 12,
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.7)
                          : Colors.black.withValues(alpha: 0.7),
                    ),
                  ),
                  Text(
                    'Rs. ${distanceCost.toStringAsFixed(0)}',
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 14 : 12,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // Total Price
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Price',
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 16 : 14,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDarkMode ? AppColors.yellowAccent : Colors.blue,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Rs. ${price.toStringAsFixed(0)}',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 16 : 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(bool isTablet, bool isSmallScreen, bool isDarkMode) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 32 : 20,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E2C) : AppTheme.lightCardColor,
        boxShadow: isDarkMode
            ? null
            : [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
      ),
      child: SafeArea(
        child: Container(
          width: double.infinity,
          height: isTablet ? 56 : 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _onContinue,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isDarkMode ? AppColors.yellowAccent : Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
              padding: EdgeInsets.zero,
            ),
            child: _isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    'Continue to Payment Details',
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 18 : (isSmallScreen ? 15 : 16),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
