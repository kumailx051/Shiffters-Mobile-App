import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shiffters/theme/app_colors.dart';
import 'package:shiffters/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shiffters/services/theme_service.dart';
import 'package:shiffters/services/email_service.dart';
import 'package:shiffters/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../home_screen.dart';
import '../track_screen.dart';

class PickupDropConfirmationScreen extends StatefulWidget {
  final Map<String, dynamic> packageData;

  const PickupDropConfirmationScreen({
    super.key,
    required this.packageData,
  });

  @override
  State<PickupDropConfirmationScreen> createState() =>
      _PickupDropConfirmationScreenState();
}

class _PickupDropConfirmationScreenState
    extends State<PickupDropConfirmationScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  String _trackingNumber = '';
  bool _emailSent = false;
  bool _sendingEmail = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
    _generateTrackingNumber();
    _sendOrderConfirmationEmail();


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

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      _animationController.forward();
    }
  }

  void _generateTrackingNumber() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = timestamp % 10000;
    _trackingNumber =
        'SFT-${randomPart.toString().padLeft(4, '0')}-${(timestamp ~/ 10000) % 10000}';
  }

  /// Send order confirmation email to user
  Future<void> _sendOrderConfirmationEmail() async {
    if (_sendingEmail || _emailSent) return;

    setState(() {
      _sendingEmail = true;
    });

    try {
      debugPrint('🔄 Starting email sending process...');

      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('❌ No authenticated user found');
        _showEmailErrorSnackBar(
            'No user logged in. Please login and try again.');
        setState(() {
          _sendingEmail = false;
        });
        return;
      }



      // Get user data from Firestore to get the user's name and email

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        debugPrint('❌ User document not found in Firestore');
        // Use Firebase Auth email as fallback
        String fallbackEmail = user.email ?? '';

        if (fallbackEmail.isNotEmpty) {

          await _sendEmailWithUserData(
            userEmail: fallbackEmail,
            userName: user.displayName ?? 'User',
          );
          return;
        } else {
          _showEmailErrorSnackBar(
              'User profile not found. Please complete your profile.');
          setState(() {
            _sendingEmail = false;
          });
          return;
        }
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      debugPrint('✅ User data retrieved: $userData');

      final userName = userData['name'] ?? user.displayName ?? 'User';
      String userEmail = userData['email'] ?? user.email ?? '';





      if (userEmail.isEmpty) {
        debugPrint('❌ User email not found in both Firestore and Auth');
        _showEmailErrorSnackBar(
            'No email address found. Please update your profile.');
        setState(() {
          _sendingEmail = false;
        });
        return;
      }

      await _sendEmailWithUserData(
        userEmail: userEmail,
        userName: userName,
      );
    } catch (e) {
      debugPrint('❌ Exception in _sendOrderConfirmationEmail: $e');
      setState(() {
        _sendingEmail = false;
      });
      _showEmailErrorSnackBar('Error preparing email: $e');
    }
  }

  /// Helper method to send email with user data
  Future<void> _sendEmailWithUserData({
    required String userEmail,
    required String userName,
  }) async {
    try {


      // Prepare order data for email
      Map<String, dynamic> emailOrderData = {
        ...widget.packageData,
        'trackingNumber': _trackingNumber,
        'timestamp':
            DateTime.now().toString().substring(0, 19), // YYYY-MM-DD HH:MM:SS
      };

      debugPrint(
          '📦 Email order data prepared: ${emailOrderData.keys.toList()}');

      // Test email server connectivity first
      final connectivityTest = await EmailService.testEmailServer();

      if (!connectivityTest['success']) {
        debugPrint(
            '❌ Email server not reachable: ${connectivityTest['error']}');
        _showEmailErrorSnackBar(
            'Email server is not available: ${connectivityTest['error']}');
        setState(() {
          _sendingEmail = false;
        });
        return;
      }

      debugPrint('✅ Email server is reachable. Sending email...');

      // Send the email
      final result = await EmailService.sendOrderConfirmationEmail(
        userEmail: userEmail,
        userName: userName,
        orderData: emailOrderData,
      );

      debugPrint('📧 Email sending result: $result');

      if (result['success']) {
        debugPrint(
            '✅ Order confirmation email sent successfully to $userEmail');
        setState(() {
          _emailSent = true;
          _sendingEmail = false;
        });
        _showSuccessSnackBar('✅ Confirmation email sent to $userEmail');
      } else {
        debugPrint(
            '❌ Failed to send order confirmation email: ${result['error']}');
        setState(() {
          _sendingEmail = false;
        });
        _showEmailErrorSnackBar('❌ Failed to send email: ${result['error']}');
      }
    } catch (e) {
      debugPrint('❌ Exception in _sendEmailWithUserData: $e');
      setState(() {
        _sendingEmail = false;
      });
      _showEmailErrorSnackBar('❌ Error sending email: $e');
    }
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(Icons.email_outlined, color: Colors.white, size: 20),
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
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showEmailErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.orange.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(Icons.email_outlined, color: Colors.white, size: 20),
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
        duration: const Duration(seconds: 5),
      ),
    );
  }



  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _goToHome() {
    HapticFeedback.mediumImpact();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const HomeScreen(),
      ),
      (route) => false,
    );
  }

  void _trackOrder() {
    HapticFeedback.lightImpact();

    // Prepare real order data for tracking
    final String? orderId = widget.packageData['orderId'] as String?;

    if (orderId == null) {
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
                  'Unable to track order. Order ID not found.',
                  style: GoogleFonts.albertSans(
                      color: Colors.white, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    // Create comprehensive order data for tracking
    Map<String, dynamic> trackingOrderData = {
      'id': orderId,
      'orderType': 'pickndrop',
      'status': 'active',
    };

    // Add pickup and dropoff locations from package data
    final pickup = widget.packageData['pickup'] as Map<String, dynamic>? ?? {};
    final dropoff =
        widget.packageData['dropoff'] as Map<String, dynamic>? ?? {};

    if (pickup['location'] != null) {
      trackingOrderData['pickupLocation'] = {
        'address': pickup['address'] ?? '',
        'latitude': pickup['location'].latitude ?? 0.0,
        'longitude': pickup['location'].longitude ?? 0.0,
      };
    }

    if (dropoff['location'] != null) {
      trackingOrderData['dropoffLocation'] = {
        'address': dropoff['address'] ?? '',
        'latitude': dropoff['location'].latitude ?? 0.0,
        'longitude': dropoff['location'].longitude ?? 0.0,
      };
    }

    // Add package information
    final packageDetails =
        widget.packageData['packageDetails'] as Map<String, dynamic>? ?? {};
    trackingOrderData['packageInformation'] = {
      'packageName': packageDetails['name'] ?? '',
      'description': packageDetails['description'] ?? '',
      'packageType': packageDetails['type'] ?? '',
      'weight': packageDetails['weight'] ?? '',
      'fragile': packageDetails['isFragile'] ?? false,
    };

    // Add payment information
    final payment =
        widget.packageData['payment'] as Map<String, dynamic>? ?? {};
    trackingOrderData['paymentMethod'] = payment['method'] ?? '';
    trackingOrderData['totalAmount'] = widget.packageData['price'] ?? 0.0;
    trackingOrderData['vehicleType'] =
        widget.packageData['vehicleType'] ?? 'Bike';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TrackScreen(
          orderData: trackingOrderData,
        ),
      ),
    );
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
          backgroundColor:
              isDarkMode ? const Color(0xFF1E1E2C) : Colors.grey[50],
          appBar: AppBar(
            backgroundColor:
                isDarkMode ? const Color(0xFF1E1E2C) : Colors.white,
            elevation: 0,
            automaticallyImplyLeading: false,
            title: Text(
              'Order Confirmation',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 20 : 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.all(isTablet ? 24 : 16),
            child: Column(
              children: [
                const SizedBox(height: 20),

                // Success Animation
                _buildSuccessSection(isTablet, isDarkMode),

                const SizedBox(height: 30),

                // Tracking Info
                _buildTrackingCard(isTablet, isDarkMode),

                const SizedBox(height: 20),

                // Package Details
                _buildPackageDetailsCard(isTablet, isDarkMode),

                const SizedBox(height: 20),

                // Payment Info
                _buildPaymentCard(isTablet, isDarkMode),

                const SizedBox(height: 100), // Space for bottom buttons
              ],
            ),
          ),
          bottomNavigationBar:
              _buildBottomButtons(isTablet, isDarkMode, isSmallScreen),
        );
      },
    );
  }

  Widget _buildSuccessSection(bool isTablet, bool isDarkMode) {
    final accent =
        isDarkMode ? AppColors.yellowAccent : AppTheme.lightPrimaryColor;
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Column(
          children: [
            // Success Icon
            Container(
              width: isTablet ? 100 : 80,
              height: isTablet ? 100 : 80,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                Icons.check,
                color: isDarkMode ? Colors.black : Colors.white,
                size: isTablet ? 50 : 40,
              ),
            ),

            const SizedBox(height: 20),

            // Success Text
            Text(
              'Order Confirmed!',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 24 : 20,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Your package has been scheduled for pickup',
              textAlign: TextAlign.center,
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 16 : 14,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.7)
                    : Colors.grey[600],
              ),
            ),

            const SizedBox(height: 16),

            // Time Slot Info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.1)
                    : AppTheme.lightPrimaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: (isDarkMode
                          ? AppColors.yellowAccent
                          : AppTheme.lightPrimaryColor)
                      .withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.access_time,
                    color: isDarkMode
                        ? AppColors.yellowAccent
                        : AppTheme.lightPrimaryColor,
                    size: isTablet ? 18 : 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Estimated Pickup: ${widget.packageData['timeSlot'] ?? 'As soon as possible'}',
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 14 : 12,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Email Status Info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _emailSent
                    ? Colors.green.withValues(alpha: 0.1)
                    : _sendingEmail
                        ? Colors.orange.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _emailSent
                      ? Colors.green.withValues(alpha: 0.3)
                      : _sendingEmail
                          ? Colors.orange.withValues(alpha: 0.3)
                          : Colors.grey.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_sendingEmail)
                    SizedBox(
                      width: isTablet ? 16 : 14,
                      height: isTablet ? 16 : 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.orange,
                      ),
                    )
                  else
                    Icon(
                      _emailSent ? Icons.email : Icons.email_outlined,
                      color: _emailSent ? Colors.green : Colors.grey,
                      size: isTablet ? 18 : 16,
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _sendingEmail
                          ? 'Sending confirmation email...'
                          : _emailSent
                              ? 'Confirmation email sent'
                              : 'Email notification pending',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 14 : 12,
                        fontWeight: FontWeight.w500,
                        color: _emailSent
                            ? Colors.green
                            : _sendingEmail
                                ? Colors.orange
                                : Colors.grey,
                      ),
                    ),
                  ),
                  if (!_emailSent && !_sendingEmail)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _emailSent = false;
                          _sendingEmail = false;
                        });
                        _sendOrderConfirmationEmail();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Retry',
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 12 : 10,
                            fontWeight: FontWeight.w600,
                            color: accent,
                          ),
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

  Widget _buildTrackingCard(bool isTablet, bool isDarkMode) {
    final accent =
        isDarkMode ? AppColors.yellowAccent : AppTheme.lightPrimaryColor;
    return Card(
      color: isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.white,
      elevation: isDarkMode ? 0 : 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 20 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.local_shipping,
                  color: accent,
                  size: isTablet ? 24 : 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Tracking Information',
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Tracking Number
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: accent.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tracking Number',
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 12 : 10,
                            color: isDarkMode
                                ? Colors.white.withValues(alpha: 0.7)
                                : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _trackingNumber,
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 16 : 14,
                            fontWeight: FontWeight.bold,
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _trackingNumber));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: accent,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          content: Text(
                            'Tracking number copied!',
                            style: GoogleFonts.albertSans(
                                color: isDarkMode ? Colors.black : Colors.white,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      );
                    },
                    icon: Icon(
                      Icons.copy,
                      color: isDarkMode ? Colors.white : Colors.black,
                      size: isTablet ? 20 : 18,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Status Info
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    'Status',
                    'Confirmed',
                    Colors.green,
                    isTablet,
                    isDarkMode,
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    'Vehicle',
                    widget.packageData['vehicleType'] ?? 'Unknown',
                    isDarkMode ? Colors.white : Colors.black,
                    isTablet,
                    isDarkMode,
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    'Date',
                    DateTime.now().toString().substring(0, 10),
                    isDarkMode ? Colors.white : Colors.black,
                    isTablet,
                    isDarkMode,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPackageDetailsCard(bool isTablet, bool isDarkMode) {
    final accent =
        isDarkMode ? AppColors.yellowAccent : AppTheme.lightPrimaryColor;
    final packageDetails =
        widget.packageData['packageDetails'] as Map<String, dynamic>? ?? {};
    final pickup = widget.packageData['pickup'] as Map<String, dynamic>? ?? {};
    final dropoff =
        widget.packageData['dropoff'] as Map<String, dynamic>? ?? {};

    return Card(
      color: isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.white,
      elevation: isDarkMode ? 0 : 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 20 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  color: accent,
                  size: isTablet ? 24 : 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Package Details',
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Package Info
            _buildDetailRow(
              'Package Name',
              packageDetails['name'] ?? 'N/A',
              Icons.inventory_2,
              isTablet,
              isDarkMode,
            ),

            const SizedBox(height: 12),

            _buildDetailRow(
              'Type & Size',
              '${packageDetails['type'] ?? 'N/A'} • ${packageDetails['size'] ?? 'N/A'}',
              Icons.category,
              isTablet,
              isDarkMode,
            ),

            const SizedBox(height: 12),

            _buildDetailRow(
              'Weight & Value',
              '${packageDetails['weight'] ?? 'N/A'} kg • Rs. ${packageDetails['value'] ?? 'N/A'}',
              Icons.fitness_center,
              isTablet,
              isDarkMode,
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // Locations
            Text(
              'Locations',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 16 : 14,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),

            const SizedBox(height: 12),

            _buildLocationRow(
              'Pickup',
              pickup['address']?.toString() ?? 'Unknown location',
              Icons.my_location,
              Colors.green,
              isTablet,
              isDarkMode,
            ),

            const SizedBox(height: 12),

            _buildLocationRow(
              'Drop-off',
              dropoff['address']?.toString() ?? 'Unknown location',
              Icons.location_on,
              Colors.red,
              isTablet,
              isDarkMode,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCard(bool isTablet, bool isDarkMode) {
    final accent =
        isDarkMode ? AppColors.yellowAccent : AppTheme.lightPrimaryColor;
    final payment =
        widget.packageData['payment'] as Map<String, dynamic>? ?? {};
    final price = (widget.packageData['price'] as num?)?.toDouble() ?? 0.0;

    return Card(
      color: isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.white,
      elevation: isDarkMode ? 0 : 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 20 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.payment,
                  color: accent,
                  size: isTablet ? 24 : 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Payment Information',
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Payment Details
            _buildDetailRow(
              'Payment Method',
              payment['method']?.toString() ?? 'N/A',
              Icons.payment,
              isTablet,
              isDarkMode,
            ),

            const SizedBox(height: 12),

            _buildDetailRow(
              'Transaction ID',
              payment['transactionId']?.toString() ?? 'N/A',
              Icons.receipt_long,
              isTablet,
              isDarkMode,
            ),

            const SizedBox(height: 12),

            _buildDetailRow(
              'Status',
              payment['status']?.toString() ?? 'N/A',
              Icons.check_circle,
              isTablet,
              isDarkMode,
              valueColor: Colors.green,
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // Total Amount
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Amount',
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
                    color: accent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Rs. ${price.toStringAsFixed(0)}',
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 16 : 14,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.black : Colors.white,
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

  Widget _buildInfoItem(String title, String value, Color valueColor,
      bool isTablet, bool isDarkMode) {
    return Column(
      children: [
        Text(
          title,
          style: GoogleFonts.albertSans(
            fontSize: isTablet ? 12 : 10,
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.7)
                : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: valueColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value,
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 12 : 10,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(
      String title, String value, IconData icon, bool isTablet, bool isDarkMode,
      {Color? valueColor}) {
    final accent =
        isDarkMode ? AppColors.yellowAccent : AppTheme.lightPrimaryColor;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: (isDarkMode
                    ? AppColors.yellowAccent
                    : AppTheme.lightPrimaryColor)
                .withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            color: accent,
            size: isTablet ? 16 : 14,
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
                  fontSize: isTablet ? 12 : 10,
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.7)
                      : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 14 : 12,
                  fontWeight: FontWeight.w600,
                  color:
                      valueColor ?? (isDarkMode ? Colors.white : Colors.black),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocationRow(String title, String address, IconData icon,
      Color iconColor, bool isTablet, bool isDarkMode) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: isTablet ? 16 : 14,
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
                  fontSize: isTablet ? 12 : 10,
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.7)
                      : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                address,
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
      ],
    );
  }

  Widget _buildBottomButtons(
      bool isTablet, bool isDarkMode, bool isSmallScreen) {
    final accent =
        isDarkMode ? AppColors.yellowAccent : AppTheme.lightPrimaryColor;
    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E2C) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _trackOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDarkMode
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.grey[100],
                  foregroundColor: isDarkMode ? Colors.white : Colors.black,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: accent,
                      width: 2,
                    ),
                  ),
                  elevation: 0,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: isTablet ? 16 : 14),
                  child: Text(
                    'Track Order',
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 18 : (isSmallScreen ? 15 : 16),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _goToHome,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: isDarkMode ? Colors.black : Colors.white,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: isTablet ? 16 : 14),
                  child: Text(
                    'Go to Home',
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 18 : (isSmallScreen ? 15 : 16),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
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
