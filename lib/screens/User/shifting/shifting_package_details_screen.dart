import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shiffters/theme/app_colors.dart';
import 'package:shiffters/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shiffters/services/theme_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'shifting_payment_screen.dart';

class ShiftingPackageDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> shiftingData;

  const ShiftingPackageDetailsScreen({
    super.key,
    required this.shiftingData,
  });

  @override
  State<ShiftingPackageDetailsScreen> createState() =>
      _ShiftingPackageDetailsScreenState();
}

class _ShiftingPackageDetailsScreenState
    extends State<ShiftingPackageDetailsScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final TextEditingController _specialInstructionsController =
      TextEditingController();
  final TextEditingController _contactNameController = TextEditingController();
  final TextEditingController _contactPhoneController = TextEditingController();
  final TextEditingController _alternatePhoneController =
      TextEditingController();

  bool _needAssemblyDisassembly = false;
  bool _needPackingMaterials = false;
  bool _needExtraHelpers = false;
  bool _isLoading = false;

  String _selectedFloorLevel = 'Ground Floor';
  String _selectedTimeSlot = 'Morning (8 AM - 12 PM)';

  final List<String> _floorLevels = [
    'Ground Floor',
    '1st Floor',
    '2nd Floor',
    '3rd Floor',
    '4th Floor',
    '5th Floor or higher (Elevator available)',
    '5th Floor or higher (No elevator)',
  ];

  final List<String> _timeSlots = [
    'Morning (8 AM - 12 PM)',
    'Afternoon (12 PM - 4 PM)',
    'Evening (4 PM - 8 PM)',
  ];

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
    _setupPhoneFormatting();

    // Debug print to check if data is received
    debugPrint('Shifting data received: ${widget.shiftingData}');
  }

  void _setupPhoneFormatting() {
    // Add listeners for phone number formatting
    _contactPhoneController.addListener(() {
      _formatPhoneNumber(_contactPhoneController);
    });

    _alternatePhoneController.addListener(() {
      _formatPhoneNumber(_alternatePhoneController);
    });
  }

  void _formatPhoneNumber(TextEditingController controller) {
    String text = controller.text
        .replaceAll(RegExp(r'[^0-9]'), ''); // Remove all non-digits

    if (text.length >= 4 && text.length <= 11) {
      // Format as 0336-5017866
      if (text.length <= 4) {
        controller.value = controller.value.copyWith(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      } else {
        String formatted = text.substring(0, 4) + '-' + text.substring(4);
        controller.value = controller.value.copyWith(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
    }
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

  @override
  void dispose() {
    _animationController.dispose();
    _specialInstructionsController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _alternatePhoneController.dispose();
    super.dispose();
  }

  // Save shifting summary to Firestore orders collection
  Future<String?> _saveShiftingSummary(Map<String, dynamic> orderData) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Debug print to check the structure of orderData
      debugPrint('Order data structure: ${orderData.keys}');
      debugPrint('Vehicle data: ${orderData['vehicle']}');
      debugPrint('Route data: ${orderData['route_data']}');

      // Extract data from orderData
      final vehicle = orderData['vehicle'] as Map<String, dynamic>? ?? {};
      final routeData = orderData['route_data'] as Map<String, dynamic>? ?? {};
      final items = orderData['items'] as List<dynamic>? ?? [];
      final additionalDetails =
          orderData['additionalDetails'] as Map<String, dynamic>? ?? {};
      final contactDetails =
          orderData['contactDetails'] as Map<String, dynamic>? ?? {};

      // Safely extract route data
      final pickupData = routeData['pickup'] as Map<String, dynamic>? ?? {};
      final dropoffData = routeData['dropoff'] as Map<String, dynamic>? ?? {};

      // Extract LatLng objects and coordinates
      final pickupLocation = pickupData['location'];
      final dropoffLocation = dropoffData['location'];

      // Convert items list to a map with string keys for Firestore compatibility
      final Map<String, dynamic> itemsMap = {};
      for (int i = 0; i < items.length; i++) {
        itemsMap[i.toString()] = items[i].toString();
      }

      // Create structured order data according to requirements
      final cleanOrderData = {
        'items': itemsMap, // Map with string keys for Firestore compatibility
        'vehicleType': vehicle['name']?.toString() ?? 'Unknown Vehicle',
        'distance': (routeData['distance'] as num?)?.toDouble() ?? 0.0,
        'duration': (routeData['duration'] as num?)?.toDouble() ?? 0.0,
        'basePrice': (vehicle['basePrice'] as num?)?.toDouble() ?? 0.0,
        'additionDetails': {
          'floorLevel':
              additionalDetails['floorLevel']?.toString() ?? 'Ground Floor',
          'preferredTimeSlot': additionalDetails['timeSlot']?.toString() ??
              'Morning (8 AM - 12 PM)',
          'AdditionalServices': {
            'assembly/disasemly':
                additionalDetails['needAssemblyDisassembly'] ?? false,
            'packingMateritals':
                additionalDetails['needPackingMaterials'] ?? false,
            'extraHelpers': additionalDetails['needExtraHelpers'] ?? false,
          },
          'specialInstructions':
              additionalDetails['specialInstructions']?.toString() ?? '',
          'additionalServicesCost':
              (additionalDetails['additionalServicesCost'] as num?)
                      ?.toDouble() ??
                  0.0,
        },
        'ContactInformation': {
          'contactName': contactDetails['name']?.toString() ?? '',
          'contactPhone': contactDetails['phone']?.toString() ?? '',
          'alternatePhone': contactDetails['alternatePhone']?.toString() ?? '',
        },

        'pickupLocation': {
          'address': pickupData['address']?.toString() ?? '',
          'latitude': pickupLocation?.latitude?.toDouble(),
          'longitude': pickupLocation?.longitude?.toDouble(),
        },
        'dropoffLocation': {
          'address': dropoffData['address']?.toString() ?? '',
          'latitude': dropoffLocation?.latitude?.toDouble(),
          'longitude': dropoffLocation?.longitude?.toDouble(),
        },

        'paymentMethod': '', // Will be updated during payment
        'uid': user.uid,
        'orderType': 'shifting',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'status': 'pending_payment',
      };

      // Save to Firestore orders collection
      debugPrint('Attempting to save order data: ${cleanOrderData.keys}');
      final docRef = await FirebaseFirestore.instance
          .collection('orders')
          .add(cleanOrderData);

      debugPrint('Order saved successfully with ID: ${docRef.id}');
      return docRef.id;
    } catch (e, stackTrace) {
      debugPrint('Error saving order: $e');
      debugPrint('Stack trace: $stackTrace');

      // More specific error logging
      if (e.toString().contains('type') && e.toString().contains('subtype')) {
        debugPrint('Type casting error detected. Order data types:');
        orderData.forEach((key, value) {
          debugPrint('  $key: ${value.runtimeType} = $value');
        });
      }

      rethrow;
    }
  }

  void _onContinue() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      HapticFeedback.lightImpact();

      try {
        // Calculate additional services cost
        double additionalServicesCost = 0;
        if (_needAssemblyDisassembly) additionalServicesCost += 500;
        if (_needPackingMaterials) additionalServicesCost += 300;
        if (_needExtraHelpers) additionalServicesCost += 400;

        // Prepare complete shifting data
        Map<String, dynamic> completeShiftingData = {
          ...widget.shiftingData,
          'additionalDetails': {
            'floorLevel': _selectedFloorLevel,
            'timeSlot': _selectedTimeSlot,
            'needAssemblyDisassembly': _needAssemblyDisassembly,
            'needPackingMaterials': _needPackingMaterials,
            'needExtraHelpers': _needExtraHelpers,
            'specialInstructions': _specialInstructionsController.text.trim(),
            'additionalServicesCost': additionalServicesCost,
          },
          'contactDetails': {
            'name': _contactNameController.text.trim(),
            'phone': _contactPhoneController.text.trim(),
            'alternatePhone': _alternatePhoneController.text.trim(),
          },
        };

        // Calculate total cost
        final vehicle =
            widget.shiftingData['vehicle'] as Map<String, dynamic>? ?? {};
        final basePrice = (vehicle['basePrice'] as num?)?.toDouble() ?? 0.0;
        final totalCost = basePrice + additionalServicesCost;

        completeShiftingData['totalCost'] = totalCost;
        completeShiftingData['basePrice'] = basePrice;

        // Save to Firestore orders collection
        final orderId = await _saveShiftingSummary(completeShiftingData);

        if (orderId != null) {
          completeShiftingData['orderId'] = orderId;

          // Show success message
          _showMessage('Order details saved successfully!', isError: false);

          // Add a small delay to show success message
          await Future.delayed(const Duration(milliseconds: 1000));

          if (mounted) {
            // Navigate to payment screen
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ShiftingPaymentScreen(shiftingData: completeShiftingData),
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Error processing order: $e');
        if (mounted) {
          _showMessage('Error saving order details. Please try again.',
              isError: true);
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else {
      _showMessage('Please fill all required fields', isError: true);
    }
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
        duration: const Duration(seconds: 3),
      ),
    );
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
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),

                          // Shifting Summary Section
                          _buildShiftingSummary(isTablet, isDarkMode),

                          const SizedBox(height: 24),

                          // Additional Details Section
                          _buildAdditionalDetailsSection(isTablet, isDarkMode),

                          const SizedBox(height: 24),

                          // Contact Details Section
                          _buildContactDetailsSection(isTablet, isDarkMode),

                          const SizedBox(
                              height: 100), // Space for bottom button
                        ],
                      ),
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
              'Shifting Details',
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
                Icons.receipt_long,
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

  Widget _buildShiftingSummary(bool isTablet, bool isDarkMode) {
    // Extract data from shiftingData
    final vehicle =
        widget.shiftingData['vehicle'] as Map<String, dynamic>? ?? {};
    final routeData =
        widget.shiftingData['route_data'] as Map<String, dynamic>? ?? {};
    final items = widget.shiftingData['items'] as List<dynamic>? ?? [];

    return SlideTransition(
      position: _slideAnimation,
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
            // Section Header
            Row(
              children: [
                Icon(
                  Icons.local_shipping,
                  color: isDarkMode
                      ? AppColors.yellowAccent
                      : AppTheme.lightPrimaryColor,
                  size: isTablet ? 24 : 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Shifting Summary',
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

            const SizedBox(height: 20),

            // Vehicle Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? AppColors.yellowAccent.withValues(alpha: 0.1)
                    : AppTheme.lightPrimaryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDarkMode
                      ? AppColors.yellowAccent.withValues(alpha: 0.3)
                      : AppTheme.lightPrimaryColor.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? AppColors.yellowAccent.withValues(alpha: 0.2)
                          : AppTheme.lightPrimaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.local_shipping,
                      color: isDarkMode
                          ? AppColors.yellowAccent
                          : AppTheme.lightPrimaryColor,
                      size: isTablet ? 24 : 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicle['name'] ?? 'Vehicle',
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 16 : 14,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode
                                ? Colors.white
                                : AppTheme.lightTextPrimaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Capacity: ${vehicle['capacity'] ?? 'N/A'} • ETA: ${vehicle['estimatedTime'] ?? 'N/A'}',
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 12 : 11,
                            color: isDarkMode
                                ? Colors.white.withValues(alpha: 0.7)
                                : AppTheme.lightTextSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? AppColors.yellowAccent
                          : AppTheme.lightPrimaryColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Rs. ${vehicle['basePrice']?.round() ?? 0}',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 14 : 12,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.black : Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Route Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.05)
                    : AppTheme.lightCardColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
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
                        'Route Information',
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 14 : 12,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode
                              ? Colors.white
                              : AppTheme.lightTextPrimaryColor,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.blue.withValues(alpha: 0.2)
                              : AppTheme.lightPrimaryColor
                                  .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${routeData['distance']?.toStringAsFixed(1) ?? '0'} km',
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 12 : 10,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode
                                ? Colors.blue
                                : AppTheme.lightPrimaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // From location
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.radio_button_checked,
                          color: Colors.green,
                          size: isTablet ? 16 : 14,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pickup Location',
                              style: GoogleFonts.albertSans(
                                fontSize: isTablet ? 11 : 10,
                                fontWeight: FontWeight.w500,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              routeData['pickup']?['address'] ??
                                  'Origin location',
                              style: GoogleFonts.albertSans(
                                fontSize: isTablet ? 12 : 11,
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
                  ),

                  const SizedBox(height: 12),

                  // To location
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: isTablet ? 16 : 14,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Drop-off Location',
                              style: GoogleFonts.albertSans(
                                fontSize: isTablet ? 11 : 10,
                                fontWeight: FontWeight.w500,
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              routeData['dropoff']?['address'] ??
                                  'Destination location',
                              style: GoogleFonts.albertSans(
                                fontSize: isTablet ? 12 : 11,
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
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Items Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.05)
                    : AppTheme.lightCardColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
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
                  Row(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        color: isDarkMode
                            ? AppColors.yellowAccent
                            : AppTheme.lightPrimaryColor,
                        size: isTablet ? 20 : 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Items to Shift (${items.length})',
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 14 : 12,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode
                              ? Colors.white
                              : AppTheme.lightTextPrimaryColor,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Items list
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: items.map((item) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.1)
                              : AppTheme.lightBorderColor
                                  .withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDarkMode
                                ? Colors.white.withValues(alpha: 0.2)
                                : AppTheme.lightBorderColor,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          item.toString(),
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 12 : 10,
                            fontWeight: FontWeight.w500,
                            color: isDarkMode
                                ? Colors.white
                                : AppTheme.lightTextSecondaryColor,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalDetailsSection(bool isTablet, bool isDarkMode) {
    return SlideTransition(
      position: _slideAnimation,
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
            // Section Header
            Row(
              children: [
                Icon(
                  Icons.settings,
                  color: isDarkMode
                      ? AppColors.yellowAccent
                      : AppTheme.lightPrimaryColor,
                  size: isTablet ? 24 : 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Additional Details',
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

            const SizedBox(height: 20),

            // Floor Level
            _buildDropdown(
              label: 'Floor Level *',
              value: _selectedFloorLevel,
              items: _floorLevels,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedFloorLevel = value;
                  });
                }
              },
              isTablet: isTablet,
              isDarkMode: isDarkMode,
            ),

            const SizedBox(height: 16),

            // Time Slot
            _buildDropdown(
              label: 'Preferred Time Slot *',
              value: _selectedTimeSlot,
              items: _timeSlots,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedTimeSlot = value;
                  });
                }
              },
              isTablet: isTablet,
              isDarkMode: isDarkMode,
            ),

            const SizedBox(height: 20),

            // Additional Services
            Text(
              'Additional Services',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 16 : 14,
                fontWeight: FontWeight.bold,
                color:
                    isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
              ),
            ),

            const SizedBox(height: 12),

            // Assembly/Disassembly Checkbox
            _buildServiceCheckbox(
              title: 'Assembly/Disassembly Service',
              description:
                  'Our team will help disassemble and reassemble furniture',
              price: '+Rs. 500',
              value: _needAssemblyDisassembly,
              onChanged: (value) {
                setState(() {
                  _needAssemblyDisassembly = value ?? false;
                });
              },
              isTablet: isTablet,
              isDarkMode: isDarkMode,
            ),

            const SizedBox(height: 12),

            // Packing Materials Checkbox
            _buildServiceCheckbox(
              title: 'Packing Materials',
              description:
                  'We provide boxes, bubble wrap, and other packing materials',
              price: '+Rs. 300',
              value: _needPackingMaterials,
              onChanged: (value) {
                setState(() {
                  _needPackingMaterials = value ?? false;
                });
              },
              isTablet: isTablet,
              isDarkMode: isDarkMode,
            ),

            const SizedBox(height: 12),

            // Extra Helpers Checkbox
            _buildServiceCheckbox(
              title: 'Extra Helpers',
              description: 'Additional helpers for faster loading/unloading',
              price: '+Rs. 400',
              value: _needExtraHelpers,
              onChanged: (value) {
                setState(() {
                  _needExtraHelpers = value ?? false;
                });
              },
              isTablet: isTablet,
              isDarkMode: isDarkMode,
            ),

            const SizedBox(height: 16),

            // Special Instructions
            _buildInputField(
              controller: _specialInstructionsController,
              label: 'Special Instructions (Optional)',
              hint:
                  'Any special requirements or instructions for the shifting team',
              isTablet: isTablet,
              isDarkMode: isDarkMode,
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactDetailsSection(bool isTablet, bool isDarkMode) {
    return SlideTransition(
      position: _slideAnimation,
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
            // Section Header
            Row(
              children: [
                Icon(
                  Icons.contacts_outlined,
                  color: isDarkMode
                      ? AppColors.yellowAccent
                      : AppTheme.lightPrimaryColor,
                  size: isTablet ? 24 : 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Contact Information',
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

            const SizedBox(height: 20),

            // Contact Name
            _buildInputField(
              controller: _contactNameController,
              label: 'Contact Name *',
              hint: 'Enter your full name',
              isTablet: isTablet,
              isDarkMode: isDarkMode,
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'[a-zA-Z\s]')), // Only letters and spaces
              ],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your name';
                }
                if (value.trim().length < 2) {
                  return 'Name must be at least 2 characters';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Contact Phone
            _buildInputField(
              controller: _contactPhoneController,
              label: 'Contact Phone *',
              hint: '0336-5017866',
              isTablet: isTablet,
              isDarkMode: isDarkMode,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'[0-9-]')), // Only numbers and dash
                LengthLimitingTextInputFormatter(
                    12), // Max length including dash
              ],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your phone number';
                }
                String cleanPhone = value.replaceAll('-', '');
                if (cleanPhone.length != 11) {
                  return 'Phone number must be 11 digits';
                }
                if (!cleanPhone.startsWith('03')) {
                  return 'Phone number must start with 03';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Alternate Phone
            _buildInputField(
              controller: _alternatePhoneController,
              label: 'Alternate Phone (Optional)',
              hint: '0336-5017866',
              isTablet: isTablet,
              isDarkMode: isDarkMode,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'[0-9-]')), // Only numbers and dash
                LengthLimitingTextInputFormatter(
                    12), // Max length including dash
              ],
              validator: (value) {
                if (value != null && value.trim().isNotEmpty) {
                  String cleanPhone = value.replaceAll('-', '');
                  if (cleanPhone.length != 11) {
                    return 'Phone number must be 11 digits';
                  }
                  if (!cleanPhone.startsWith('03')) {
                    return 'Phone number must start with 03';
                  }
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCheckbox({
    required String title,
    required String description,
    required String price,
    required bool value,
    required void Function(bool?) onChanged,
    required bool isTablet,
    required bool isDarkMode,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.05)
            : AppTheme.lightCardColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value
              ? (isDarkMode
                  ? AppColors.yellowAccent.withValues(alpha: 0.5)
                  : AppTheme.lightPrimaryColor.withValues(alpha: 0.5))
              : (isDarkMode
                  ? Colors.white.withValues(alpha: 0.2)
                  : AppTheme.lightBorderColor),
          width: value ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Transform.scale(
            scale: 1.2,
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: isDarkMode
                  ? AppColors.yellowAccent
                  : AppTheme.lightPrimaryColor,
              checkColor: isDarkMode ? Colors.black : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
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
                    fontWeight: FontWeight.bold,
                    color: isDarkMode
                        ? Colors.white
                        : AppTheme.lightTextPrimaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 12 : 10,
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.7)
                        : AppTheme.lightTextSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? AppColors.yellowAccent.withValues(alpha: 0.2)
                  : AppTheme.lightPrimaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              price,
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 12 : 10,
                fontWeight: FontWeight.bold,
                color: isDarkMode
                    ? AppColors.yellowAccent
                    : AppTheme.lightPrimaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isTablet,
    required bool isDarkMode,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.albertSans(
            fontSize: isTablet ? 14 : 12,
            fontWeight: FontWeight.w600,
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.8)
                : AppTheme.lightTextSecondaryColor,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          inputFormatters: inputFormatters,
          style: GoogleFonts.albertSans(
            fontSize: isTablet ? 14 : 12,
            color: isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
          ),
          cursorColor:
              isDarkMode ? AppColors.yellowAccent : AppTheme.lightPrimaryColor,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.albertSans(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.5)
                  : AppTheme.lightTextSecondaryColor.withValues(alpha: 0.7),
              fontSize: isTablet ? 14 : 12,
            ),
            filled: true,
            fillColor: isDarkMode
                ? Colors.white.withValues(alpha: 0.1)
                : AppTheme.lightCardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.3)
                    : AppTheme.lightBorderColor,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.3)
                    : AppTheme.lightBorderColor,
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
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Colors.red,
              ),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: isTablet ? 16 : 12,
              vertical: isTablet ? 16 : 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
    required bool isTablet,
    required bool isDarkMode,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.albertSans(
            fontSize: isTablet ? 14 : 12,
            fontWeight: FontWeight.w600,
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.8)
                : AppTheme.lightTextSecondaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.1)
                : AppTheme.lightCardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.3)
                  : AppTheme.lightBorderColor,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: Icon(
                Icons.arrow_drop_down,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.7)
                    : AppTheme.lightTextSecondaryColor,
              ),
              dropdownColor: isDarkMode
                  ? const Color(0xFF2D2D3C)
                  : AppTheme.lightCardColor,
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 14 : 12,
                color:
                    isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
              ),
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(item),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
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
        child: SafeArea(
          child: GestureDetector(
            onTap: _isLoading ? null : _onContinue,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                vertical: isTablet ? 18 : 16,
              ),
              decoration: BoxDecoration(
                color: _isLoading
                    ? (isDarkMode
                        ? Colors.grey.withValues(alpha: 0.5)
                        : AppTheme.lightBorderColor.withValues(alpha: 0.5))
                    : (isDarkMode
                        ? AppColors.yellowAccent
                        : AppTheme.lightPrimaryColor),
                borderRadius: BorderRadius.circular(25),
                boxShadow: _isLoading
                    ? null
                    : [
                        BoxShadow(
                          color: isDarkMode
                              ? AppColors.yellowAccent.withValues(alpha: 0.3)
                              : AppTheme.lightPrimaryColor
                                  .withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isLoading)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  else ...[
                    Text(
                      'Continue to Payment',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 16 : 14,
                        fontWeight: FontWeight.bold,
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
