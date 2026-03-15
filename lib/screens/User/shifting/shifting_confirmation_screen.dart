import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shiffters/theme/app_colors.dart';
import 'package:shiffters/theme/app_theme.dart';
import 'package:shiffters/services/theme_service.dart';
import 'package:shiffters/screens/User/home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/email_service.dart';

class ShiftingConfirmationScreen extends StatefulWidget {
  final Map<String, dynamic> shiftingData;

  const ShiftingConfirmationScreen({
    super.key,
    required this.shiftingData,
  });

  @override
  State<ShiftingConfirmationScreen> createState() =>
      _ShiftingConfirmationScreenState();
}

class _ShiftingConfirmationScreenState extends State<ShiftingConfirmationScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _checkAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _checkScaleAnimation;

  String _orderID = '';
  bool _emailSent = false;
  bool _emailSending = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _generateOrderID();
    _startAnimations();
    _sendOrderConfirmationEmail();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _checkAnimationController = AnimationController(
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

    _checkScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _checkAnimationController,
      curve: Curves.elasticOut,
    ));
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) {
      _animationController.forward();
      await Future.delayed(const Duration(milliseconds: 400));
      _checkAnimationController.forward();
    }
  }

  void _generateOrderID() {
    final orderId = widget.shiftingData['orderId'] as String?;
    if (orderId != null && orderId.isNotEmpty) {
      _orderID = 'SFT-${orderId.substring(orderId.length - 4)}';
    } else {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final random = timestamp % 10000;
      _orderID = 'SFT-${random.toString().padLeft(4, '0')}';
    }
  }

  Future<void> _sendOrderConfirmationEmail() async {
    if (_emailSending || _emailSent) return;

    setState(() {
      _emailSending = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      String customerEmail;
      String customerName;

      if (user != null) {
        customerEmail = user.email ?? '';

        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            customerName = userData['displayName'] ??
                userData['name'] ??
                'Valued Customer';
          } else {
            customerName = user.displayName ?? 'Valued Customer';
          }
        } catch (e) {
          customerName = user.displayName ?? 'Valued Customer';
        }
      } else {
        customerEmail = '';
        customerName = 'Valued Customer';
      }

      if (customerEmail.isEmpty) {
        setState(() {
          _emailSending = false;
        });
        return;
      }

      // Extract location data - check both direct fields and route_data
      final routeData =
          widget.shiftingData['route_data'] as Map<String, dynamic>? ?? {};
      final pickupLocation =
          widget.shiftingData['pickupLocation'] as Map<String, dynamic>? ??
              routeData['pickup'] as Map<String, dynamic>? ??
              {};
      final dropoffLocation =
          widget.shiftingData['dropoffLocation'] as Map<String, dynamic>? ??
              routeData['dropoff'] as Map<String, dynamic>? ??
              {};

      final paymentDetails =
          widget.shiftingData['payment'] as Map<String, dynamic>? ?? {};
      final items = widget.shiftingData['items'] as List<dynamic>? ?? [];
      final totalAmount = widget.shiftingData['totalAmount'] ?? 0;

      String itemsList = '';
      for (var item in items) {
        if (item is Map<String, dynamic>) {
          final itemName = item['name']?.toString() ?? 'Item';
          final quantity = item['quantity']?.toString() ?? '1';
          itemsList += '• $itemName (Qty: $quantity)\n';
        }
      }

      final orderData = {
        'order_id': _orderID,
        'service_type': 'Shifting Service',
        'pickup_location':
            pickupLocation['address']?.toString() ?? 'Not specified',
        'dropoff_location':
            dropoffLocation['address']?.toString() ?? 'Not specified',
        'pickup_date':
            widget.shiftingData['pickupDate']?.toString() ?? 'Not specified',
        'pickup_time':
            widget.shiftingData['pickupTime']?.toString() ?? 'Not specified',
        'items': itemsList,
        'total_amount': totalAmount.toString(),
        'payment_method':
            paymentDetails['method']?.toString() ?? 'Not specified',
        'transaction_id':
            paymentDetails['transactionId']?.toString() ?? 'Not specified',
      };

      final result = await EmailService.sendOrderConfirmationEmail(
        userEmail: customerEmail,
        userName: customerName,
        orderData: orderData,
      );

      if (mounted) {
        setState(() {
          _emailSending = false;
          _emailSent = result['success'] == true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _emailSending = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _checkAnimationController.dispose();
    super.dispose();
  }

  void _goToHomeScreen() {
    HapticFeedback.lightImpact();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (route) => false,
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    // Copy phone number to clipboard and show message
    await Clipboard.setData(ClipboardData(text: phoneNumber));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.blue.withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: [
              const Icon(Icons.phone, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Phone number copied to clipboard: $phoneNumber',
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
  }

  Future<void> _sendEmail(String email) async {
    // Copy email to clipboard and show message
    await Clipboard.setData(ClipboardData(text: email));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green.withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: [
              const Icon(Icons.email, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Email address copied to clipboard: $email',
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
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        final isDarkMode = themeService.isDarkMode;

        return Scaffold(
          backgroundColor:
              isDarkMode ? const Color(0xFF1E1E2C) : Colors.grey[50],
          body: SafeArea(
            child: Column(
              children: [
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 24 : 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),

                        // Success Check Icon
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: ScaleTransition(
                            scale: _checkScaleAnimation,
                            child: Container(
                              width: isTablet ? 100 : 80,
                              height: isTablet ? 100 : 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.green.withValues(alpha: 0.2),
                                border: Border.all(
                                  color: Colors.green,
                                  width: 3,
                                ),
                              ),
                              child: Icon(
                                Icons.check,
                                color: Colors.green,
                                size: isTablet ? 50 : 40,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Success Message
                        SlideTransition(
                          position: _slideAnimation,
                          child: Column(
                            children: [
                              Text(
                                'Booking Confirmed!',
                                style: GoogleFonts.albertSans(
                                  fontSize: isTablet ? 28 : 24,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isDarkMode ? Colors.white : Colors.black,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Your shifting service has been booked successfully. We will contact you shortly to confirm the details.',
                                style: GoogleFonts.albertSans(
                                  fontSize: isTablet ? 16 : 14,
                                  color: isDarkMode
                                      ? Colors.white.withValues(alpha: 0.7)
                                      : Colors.black.withValues(alpha: 0.7),
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Email Status Indicator
                        if (_emailSending || _emailSent)
                          SlideTransition(
                            position: _slideAnimation,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: _emailSent
                                    ? Colors.green.withValues(alpha: 0.1)
                                    : Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _emailSent
                                      ? Colors.green.withValues(alpha: 0.3)
                                      : Colors.blue.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_emailSending)
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.blue,
                                        ),
                                      ),
                                    )
                                  else
                                    Icon(
                                      Icons.mark_email_read,
                                      color: Colors.green,
                                      size: 16,
                                    ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _emailSending
                                        ? 'Sending confirmation email...'
                                        : 'Confirmation email sent!',
                                    style: GoogleFonts.albertSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: _emailSent
                                          ? Colors.green
                                          : Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        const SizedBox(height: 16),

                        // Order Details Card
                        SlideTransition(
                          position: _slideAnimation,
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(isTablet ? 24 : 20),
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.white.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(16),
                              border: isDarkMode
                                  ? Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.2),
                                      width: 1,
                                    )
                                  : Border.all(
                                      color: AppTheme.lightPrimaryColor,
                                      width: 1,
                                    ),
                              boxShadow: isDarkMode
                                  ? null
                                  : [
                                      BoxShadow(
                                        color:
                                            Colors.black.withValues(alpha: 0.1),
                                        blurRadius: 10,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Order ID
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Order ID',
                                      style: GoogleFonts.albertSans(
                                        fontSize: isTablet ? 16 : 14,
                                        fontWeight: FontWeight.w600,
                                        color: isDarkMode
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isDarkMode
                                            ? AppColors.yellowAccent
                                            : AppTheme.lightPrimaryColor,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        _orderID,
                                        style: GoogleFonts.albertSans(
                                          fontSize: isTablet ? 14 : 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 20),

                                // Order Details
                                _buildOrderDetails(isTablet, isDarkMode),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Need Help Section
                        SlideTransition(
                          position: _slideAnimation,
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(isTablet ? 24 : 20),
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.white.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(16),
                              border: isDarkMode
                                  ? Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.2),
                                      width: 1,
                                    )
                                  : Border.all(
                                      color: AppTheme.lightPrimaryColor,
                                      width: 1,
                                    ),
                              boxShadow: isDarkMode
                                  ? null
                                  : [
                                      BoxShadow(
                                        color:
                                            Colors.black.withValues(alpha: 0.1),
                                        blurRadius: 10,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Need Help?',
                                  style: GoogleFonts.albertSans(
                                    fontSize: isTablet ? 18 : 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // Call Support
                                GestureDetector(
                                  onTap: () => _makePhoneCall('+923001234567'),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isDarkMode
                                          ? Colors.white.withValues(alpha: 0.05)
                                          : Colors.grey.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isDarkMode
                                            ? Colors.white
                                                .withValues(alpha: 0.1)
                                            : Colors.grey
                                                .withValues(alpha: 0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.blue
                                                .withValues(alpha: 0.2),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            Icons.phone,
                                            color: Colors.blue,
                                            size: isTablet ? 20 : 18,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            'Call Customer Support',
                                            style: GoogleFonts.albertSans(
                                              fontSize: isTablet ? 14 : 12,
                                              fontWeight: FontWeight.w600,
                                              color: isDarkMode
                                                  ? Colors.white
                                                  : Colors.black,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '+92 300 1234567',
                                          style: GoogleFonts.albertSans(
                                            fontSize: isTablet ? 14 : 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 12),

                                // Email Support
                                GestureDetector(
                                  onTap: () =>
                                      _sendEmail('support@shiffters.com'),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isDarkMode
                                          ? Colors.white.withValues(alpha: 0.05)
                                          : Colors.grey.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isDarkMode
                                            ? Colors.white
                                                .withValues(alpha: 0.1)
                                            : Colors.grey
                                                .withValues(alpha: 0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.green
                                                .withValues(alpha: 0.2),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            Icons.email,
                                            color: Colors.green,
                                            size: isTablet ? 20 : 18,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            'Email Support',
                                            style: GoogleFonts.albertSans(
                                              fontSize: isTablet ? 14 : 12,
                                              fontWeight: FontWeight.w600,
                                              color: isDarkMode
                                                  ? Colors.white
                                                  : Colors.black,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          'support@shiffters.com',
                                          style: GoogleFonts.albertSans(
                                            fontSize: isTablet ? 14 : 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 100), // Space for bottom button
                      ],
                    ),
                  ),
                ),

                // Bottom Button
                _buildBottomButton(isTablet, isDarkMode),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrderDetails(bool isTablet, bool isDarkMode) {
    // Extract data - handle potential null values and new structure
    final vehicle =
        widget.shiftingData['vehicle'] as Map<String, dynamic>? ?? {};
    final additionalDetails =
        widget.shiftingData['additionalDetails'] as Map<String, dynamic>? ?? {};
    final payment =
        widget.shiftingData['payment'] as Map<String, dynamic>? ?? {};

    // Handle different possible total amount field names
    final totalAmount = (widget.shiftingData['totalAmount'] as num?) ??
        (widget.shiftingData['totalCost'] as num?) ??
        (widget.shiftingData['totalPrice'] as num?) ??
        0;

    // Format date
    final bookingDate = DateTime.now();
    final formattedDate =
        '${bookingDate.day}/${bookingDate.month}/${bookingDate.year}';

    return Column(
      children: [
        // Date
        _buildDetailRow(
          'Date',
          formattedDate,
          isTablet,
          isDarkMode,
        ),

        const SizedBox(height: 12),

        // Time Slot
        _buildDetailRow(
          'Time Slot',
          additionalDetails['timeSlot'] ?? 'Morning (8 AM - 12 PM)',
          isTablet,
          isDarkMode,
        ),

        const SizedBox(height: 12),

        // Vehicle
        _buildDetailRow(
          'Vehicle',
          vehicle['name'] ?? 'Unknown Vehicle',
          isTablet,
          isDarkMode,
        ),

        const SizedBox(height: 12),

        // Floor Level
        _buildDetailRow(
          'Floor Level',
          additionalDetails['floorLevel'] ?? 'Ground Floor',
          isTablet,
          isDarkMode,
        ),

        const SizedBox(height: 12),

        // Payment Method
        _buildDetailRow(
          'Payment Method',
          payment['method'] ?? 'Cash on Delivery',
          isTablet,
          isDarkMode,
        ),

        const SizedBox(height: 12),

        // Total Amount
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Total Amount',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 14 : 12,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            Text(
              totalAmount > 0
                  ? 'Rs. ${totalAmount.toStringAsFixed(0)}'
                  : 'Rs. N/A',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 14 : 12,
                fontWeight: FontWeight.bold,
                color: isDarkMode
                    ? AppColors.yellowAccent
                    : AppTheme.lightPrimaryColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailRow(
      String label, String value, bool isTablet, bool isDarkMode) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.albertSans(
            fontSize: isTablet ? 14 : 12,
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.7)
                : Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: GoogleFonts.albertSans(
            fontSize: isTablet ? 14 : 12,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : Colors.black,
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
        ),
        child: SafeArea(
          child: GestureDetector(
            onTap: _goToHomeScreen,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                vertical: isTablet ? 18 : 16,
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
                        : AppTheme.lightPrimaryColor.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Back to Home',
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 16 : 14,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.black : Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.home,
                    color: isDarkMode ? Colors.black : Colors.white,
                    size: isTablet ? 20 : 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
