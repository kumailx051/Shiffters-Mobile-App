
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shiffters/theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:shiffters/services/theme_service.dart';
import 'home_screen.dart';
import 'track_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
    _generateTrackingNumber();


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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TrackScreen(
          orderData: {'id': 'sample_id', 'status': 'pending'},
        ),
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
          bottomNavigationBar: _buildBottomButtons(isTablet, isDarkMode),
        );
      },
    );
  }

  Widget _buildSuccessSection(bool isTablet, bool isDarkMode) {
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
                color: AppColors.yellowAccent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.yellowAccent.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                Icons.check,
                color: Colors.black,
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
                    : AppColors.yellowAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.yellowAccent.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.access_time,
                    color: AppColors.yellowAccent,
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
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingCard(bool isTablet, bool isDarkMode) {
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
                  color: AppColors.yellowAccent,
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
                  color: AppColors.yellowAccent.withValues(alpha: 0.3),
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
                            color: AppColors.yellowAccent,
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
                          backgroundColor: AppColors.yellowAccent,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          content: Text(
                            'Tracking number copied!',
                            style: GoogleFonts.albertSans(
                                color: Colors.black,
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
                  color: AppColors.yellowAccent,
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
                  color: AppColors.yellowAccent,
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
                    color: AppColors.yellowAccent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Rs. ${price.toStringAsFixed(0)}',
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 16 : 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
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
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.yellowAccent.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            color: AppColors.yellowAccent,
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

  Widget _buildBottomButtons(bool isTablet, bool isDarkMode) {
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
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey[100],
                  foregroundColor: isDarkMode ? Colors.white : Colors.black,
                  padding: EdgeInsets.symmetric(vertical: isTablet ? 16 : 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: AppColors.yellowAccent,
                      width: 2,
                    ),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Track Order',
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _goToHome,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.yellowAccent,
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(vertical: isTablet ? 16 : 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 5,
                ),
                child: Text(
                  'Go to Home',
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.w600,
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
