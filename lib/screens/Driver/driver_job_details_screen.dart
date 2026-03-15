import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shiffters/services/theme_service.dart';
import 'package:shiffters/theme/app_colors.dart';
import 'package:shiffters/theme/app_theme.dart';

import 'driver_tracking_screen.dart';
import 'driver_orders_screen.dart';
import 'item_verification_screen.dart';

class DriverJobDetailsScreen extends StatefulWidget {
  /// Pass the order map from the list. It MUST contain the Firestore doc id in `id`.
  /// If you prefer, you can change the constructor to accept just `orderId` and
  /// update the call site accordingly.
  final Map<String, dynamic> orderData;

  const DriverJobDetailsScreen({
    super.key,
    required this.orderData,
  });

  @override
  State<DriverJobDetailsScreen> createState() => _DriverJobDetailsScreenState();
}

class _DriverJobDetailsScreenState extends State<DriverJobDetailsScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Map<String, dynamic>? _currentOrder;
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;

  // UI status for timeline button; will be synchronized with Firestore stream.
  String _jobStatus = 'Pending';
  final List<String> _statusOptions = const [
    'Pending',
    'Started',
    'Picked Up',
    'In Transit',
    'Delivered'
  ];

  final List<String> _shiftingStatusOptions = const [
    'Pending',
    'Started',
    'Picked Up',
    'In Transit',
    'Delivered',
    'Verify Items'
  ];

  bool get _isShiftingOrder {
    // Check current order data first (from stream), then fallback to widget data
    final orderType = _currentOrder?['orderType']?.toString().toLowerCase() ??
        widget.orderData['orderType']?.toString().toLowerCase();
    final isShifting = orderType == 'shifting';
    print('🔍 Order type: $orderType, isShifting: $isShifting');
    return isShifting;
  }

  List<String> get _currentStatusOptions {
    final options = _isShiftingOrder ? _shiftingStatusOptions : _statusOptions;
    print('📋 Current status options: $options');
    return options;
  }

  // Convenience: stream the order document by id
  Stream<DocumentSnapshot<Map<String, dynamic>>> _orderStream(String orderId) {
    return FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .snapshots();
  }

  // Fetch user data by uid
  Future<Map<String, dynamic>?> _fetchUserData(String uid) async {
    if (uid.isEmpty) return null;

    try {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (userDoc.exists) {
        return userDoc.data();
      }
    } catch (e) {
      print('Error fetching user data: $e');
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();

    // Initialize status from initial data (will be overridden by stream)
    final initial = (widget.orderData['status'] ?? '').toString();
    _jobStatus = _toUiStatus(initial);

    // System UI
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    _animationController.forward();
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // For AutomaticKeepAliveClientMixin

    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        final isDarkMode = themeService.isDarkMode;
        final orderId = (widget.orderData['id'] ?? '').toString();

        return Scaffold(
          backgroundColor: isDarkMode
              ? const Color(0xFF1E1E2C)
              : AppTheme.lightBackgroundColor,
          body: Column(
            children: [
              _buildHeader(isTablet, isDarkMode, orderId),
              Expanded(
                child: SafeArea(
                  top: false,
                  child: orderId.isEmpty
                      ? _buildCenteredMessage(
                          isTablet,
                          isDarkMode,
                          icon: Icons.error_outline,
                          title: 'Missing order id',
                          subtitle: 'Could not load order details.',
                        )
                      : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: _orderStream(orderId),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }

                            if (snapshot.hasError) {
                              return _buildCenteredMessage(
                                isTablet,
                                isDarkMode,
                                icon: Icons.error_outline,
                                title: 'Something went wrong',
                                subtitle: '${snapshot.error}',
                              );
                            }

                            final doc = snapshot.data;
                            if (doc == null || !doc.exists) {
                              return _buildCenteredMessage(
                                isTablet,
                                isDarkMode,
                                icon: Icons.inbox_outlined,
                                title: 'Order not found',
                                subtitle: 'This order may have been removed.',
                              );
                            }

                            final data = doc.data()!;
                            final uid = (data['uid'] ?? '').toString();

                            // Update current order data
                            _currentOrder = data;

                            // Keep timeline/status in sync with Firestore
                            final newStatus =
                                _toUiStatus((data['status'] ?? '').toString());
                            if (newStatus != _jobStatus) {
                              // Avoid setState during build-frame jank
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted)
                                  setState(() => _jobStatus = newStatus);
                              });
                            }

                            return FutureBuilder<Map<String, dynamic>?>(
                              future: _fetchUserData(uid),
                              builder: (context, userSnapshot) {
                                // Normalize fields for UI with user data
                                final uiData = _toUiOrderMap(
                                    doc.id, data, userSnapshot.data);

                                return SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isTablet ? 32 : 20,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 24),
                                        _buildCustomerInfo(
                                            isTablet, isDarkMode, uiData),
                                        const SizedBox(height: 20),
                                        _buildJobDetails(
                                            isTablet, isDarkMode, uiData),
                                        const SizedBox(height: 20),
                                        _buildJobTimeline(isTablet, isDarkMode),
                                        const SizedBox(height: 20),
                                        _buildActionButtons(
                                          isTablet,
                                          isDarkMode,
                                          orderId,
                                          uiData,
                                        ),
                                        const SizedBox(height: 100),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------- UI Sections ----------------

  Widget _buildCenteredMessage(
    bool isTablet,
    bool isDarkMode, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: isTablet ? 80 : 60,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.3)
                  : AppColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 18 : 16,
                fontWeight: FontWeight.w600,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.7)
                    : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 14 : 12,
                color: isDarkMode
                    ? Colors.white.withOpacity(0.5)
                    : AppColors.textSecondary.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isTablet, bool isDarkMode, String orderId) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 20 : 16,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: isDarkMode
            ? const Color(0xFF2D2D3C)
            : Colors.white.withOpacity(0.9),
        boxShadow: isDarkMode
            ? null
            : [
                BoxShadow(
                  color: AppColors.lightPrimary.withValues(alpha: 0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Title section
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Job Details',
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 28 : 24,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode
                          ? Colors.white
                          : AppTheme.lightTextPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Order #$orderId',
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 16 : 14,
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.7)
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Status badge with pulse animation
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (ctx, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(_jobStatus, isDarkMode)
                          .withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getStatusColor(_jobStatus, isDarkMode),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _getStatusColor(_jobStatus, isDarkMode)
                              .withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      _jobStatus,
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 12 : 10,
                        fontWeight: FontWeight.w700,
                        color: _getStatusColor(_jobStatus, isDarkMode),
                      ),
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

  Widget _buildCustomerInfo(
    bool isTablet,
    bool isDarkMode,
    Map<String, dynamic> uiData,
  ) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        padding: EdgeInsets.all(isTablet ? 24 : 20),
        decoration: BoxDecoration(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : AppTheme.lightCardColor,
          borderRadius: BorderRadius.circular(16),
          border: isDarkMode
              ? null
              : Border.all(color: AppTheme.lightPrimaryColor, width: 1.5),
          boxShadow: isDarkMode
              ? null
              : [
                  BoxShadow(
                    color: AppTheme.lightShadowMedium,
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.person,
                  color: isDarkMode
                      ? AppColors.yellowAccent
                      : AppTheme.lightPrimaryColor,
                  size: isTablet ? 24 : 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Customer Information',
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                // Avatar with profile image support
                Container(
                  width: isTablet ? 64 : 56,
                  height: isTablet ? 64 : 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDarkMode
                        ? AppColors.yellowAccent.withValues(alpha: 0.2)
                        : AppTheme.lightPrimaryColor.withValues(alpha: 0.1),
                    border: Border.all(
                      color: isDarkMode
                          ? AppColors.yellowAccent
                          : AppTheme.lightPrimaryColor,
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: uiData['profileImageUrl'] != null &&
                            uiData['profileImageUrl'].toString().isNotEmpty
                        ? Image.network(
                            uiData['profileImageUrl'],
                            width: isTablet ? 64 : 56,
                            height: isTablet ? 64 : 56,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.person,
                                size: isTablet ? 32 : 28,
                                color: isDarkMode
                                    ? AppColors.yellowAccent
                                    : AppTheme.lightPrimaryColor,
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes !=
                                          null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isDarkMode
                                        ? AppColors.yellowAccent
                                        : AppTheme.lightPrimaryColor,
                                  ),
                                  strokeWidth: 2,
                                ),
                              );
                            },
                          )
                        : Icon(
                            Icons.person,
                            size: isTablet ? 32 : 28,
                            color: isDarkMode
                                ? AppColors.yellowAccent
                                : AppTheme.lightPrimaryColor,
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        uiData['customer'] ?? 'Customer',
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 18 : 16,
                          fontWeight: FontWeight.bold,
                          color:
                              isDarkMode ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        uiData['customerPhone'] ?? 'No phone number',
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 14 : 12,
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.7)
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                // Call
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _callCustomer(
                        context, uiData['customerPhone'] ?? 'Unknown');
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(Icons.phone,
                        color: Colors.white, size: isTablet ? 24 : 20),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobDetails(
    bool isTablet,
    bool isDarkMode,
    Map<String, dynamic> uiData,
  ) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        padding: EdgeInsets.all(isTablet ? 24 : 20),
        decoration: BoxDecoration(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : AppTheme.lightCardColor,
          borderRadius: BorderRadius.circular(16),
          border: isDarkMode
              ? null
              : Border.all(color: AppTheme.lightPrimaryColor, width: 1.5),
          boxShadow: isDarkMode
              ? null
              : [
                  BoxShadow(
                    color: AppTheme.lightShadowMedium,
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.work,
                    color: isDarkMode
                        ? AppColors.yellowAccent
                        : AppTheme.lightPrimaryColor,
                    size: isTablet ? 24 : 20),
                const SizedBox(width: 12),
                Text(
                  'Job Details',
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Pickup
            _buildLocationItem(
              Icons.my_location,
              'Pickup Location',
              uiData['pickupAddress'] ?? '—',
              Colors.green,
              isTablet,
              isDarkMode,
            ),
            const SizedBox(height: 16),

            // Drop-off
            _buildLocationItem(
              Icons.location_on,
              'Drop-off Location',
              uiData['dropoffAddress'] ?? '—',
              Colors.red,
              isTablet,
              isDarkMode,
            ),
            const SizedBox(height: 16),

            // Items
            Container(
              padding: EdgeInsets.all(isTablet ? 16 : 12),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
                border: isDarkMode
                    ? null
                    : Border.all(color: AppTheme.lightPrimaryColor, width: 1.5),
              ),
              child: Row(
                children: [
                  Icon(Icons.inventory_2,
                      color: isDarkMode
                          ? AppColors.yellowAccent
                          : AppTheme.lightPrimaryColor,
                      size: isTablet ? 20 : 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Items to Transport',
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 12 : 10,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode
                                ? Colors.white.withValues(alpha: 0.8)
                                : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          uiData['items'] ?? '—',
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 14 : 12,
                            fontWeight: FontWeight.w500,
                            color: isDarkMode
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Info grid
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    'Duration',
                    (uiData['estimatedDuration'] ?? '—').toString(),
                    Icons.access_time,
                    Colors.blue,
                    isTablet,
                    isDarkMode,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInfoItem(
                    'Scheduled',
                    (uiData['time'] ?? '—').toString(),
                    Icons.schedule,
                    Colors.orange,
                    isTablet,
                    isDarkMode,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    'Earnings',
                    'Rs. ${(uiData['earnings'] as double).toStringAsFixed(0)}',
                    Icons.account_balance_wallet,
                    Colors.green,
                    isTablet,
                    isDarkMode,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInfoItem(
                    'Priority',
                    (uiData['priority'] ?? 'Medium').toString(),
                    Icons.flag,
                    _getPriorityColor(
                        (uiData['priority'] ?? 'Medium').toString()),
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

  Widget _buildJobTimeline(bool isTablet, bool isDarkMode) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        padding: EdgeInsets.all(isTablet ? 24 : 20),
        decoration: BoxDecoration(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : AppTheme.lightCardColor,
          borderRadius: BorderRadius.circular(16),
          border: isDarkMode
              ? null
              : Border.all(color: AppTheme.lightPrimaryColor, width: 1.5),
          boxShadow: isDarkMode
              ? null
              : [
                  BoxShadow(
                    color: AppTheme.lightShadowMedium,
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline,
                    color: isDarkMode
                        ? AppColors.yellowAccent
                        : AppTheme.lightPrimaryColor,
                    size: isTablet ? 24 : 20),
                const SizedBox(width: 12),
                Text(
                  'Job Progress',
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...List.generate(_currentStatusOptions.length, (index) {
              final status = _currentStatusOptions[index];
              final currentStatusIndex =
                  _currentStatusOptions.indexOf(_jobStatus);
              final isCompleted = currentStatusIndex >= index;
              final isCurrent = currentStatusIndex == index;
              final isLast = index == _currentStatusOptions.length - 1;

              print(
                  '🔢 Timeline item $index: $status (completed: $isCompleted, current: $isCurrent)');

              return _buildTimelineItem(
                status,
                isCompleted,
                isCurrent,
                isLast,
                isTablet,
                isDarkMode,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(
    bool isTablet,
    bool isDarkMode,
    String orderId,
    Map<String, dynamic> uiData,
  ) {
    return SlideTransition(
      position: _slideAnimation,
      child: Column(
        children: [
          // Primary action button
          GestureDetector(
            onTap: () async {
              // Handle verification button for shifting orders
              if (_jobStatus == 'Verify Items') {
                HapticFeedback.lightImpact();
                await _startItemVerification(orderId, isDarkMode);
                return;
              }

              // Only allow interaction if not already completed
              if (_jobStatus != 'Delivered' &&
                  _getActionButtonText().contains('Job Completed')) {
                _showGlowingSnackBar(
                    context, 'Complete previous steps first', Colors.orange);
                return;
              }

              HapticFeedback.lightImpact();
              await _advanceAndPersistStatus(orderId, isDarkMode);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: _getActionButtonText() == 'Job Completed' &&
                        _jobStatus != 'Delivered'
                    ? Colors.grey.withValues(alpha: 0.5)
                    : (isDarkMode
                        ? AppColors.yellowAccent
                        : AppTheme.lightPrimaryColor),
                borderRadius: BorderRadius.circular(12),
                boxShadow: _getActionButtonText() == 'Job Completed' &&
                        _jobStatus != 'Delivered'
                    ? []
                    : [
                        BoxShadow(
                          color: (isDarkMode
                                  ? AppColors.yellowAccent
                                  : AppTheme.lightPrimaryColor)
                              .withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Text(
                _getActionButtonText(),
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 16 : 14,
                  fontWeight: FontWeight.w600,
                  color: _getActionButtonText() == 'Job Completed' &&
                          _jobStatus != 'Delivered'
                      ? Colors.grey.shade600
                      : (isDarkMode ? Colors.black : Colors.white),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Secondary buttons
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DriverTrackingScreen(
                            orderId: widget.orderData['id']),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDarkMode
                            ? AppColors.yellowAccent
                            : AppTheme.lightPrimaryColor,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.map,
                            color: isDarkMode
                                ? AppColors.yellowAccent
                                : AppTheme.lightPrimaryColor,
                            size: isTablet ? 20 : 18),
                        const SizedBox(width: 8),
                        Text(
                          'Open Map',
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
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _reportIssue(context, isDarkMode);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red, width: 2),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.report,
                            color: Colors.red, size: isTablet ? 20 : 18),
                        const SizedBox(width: 8),
                        Text(
                          'Report Issue',
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 14 : 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------- Small UI pieces ----------------

  Widget _buildLocationItem(IconData icon, String title, String address,
      Color iconColor, bool isTablet, bool isDarkMode) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: isDarkMode
            ? null
            : Border.all(color: AppTheme.lightPrimaryColor, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: isTablet ? 20 : 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 12 : 10,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.8)
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  address,
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 14 : 12,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.white : AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String title, String value, IconData icon, Color color,
      bool isTablet, bool isDarkMode) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: isDarkMode
            ? null
            : Border.all(color: AppTheme.lightPrimaryColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: isTablet ? 18 : 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 12 : 10,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.8)
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 14 : 12,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(String status, bool isCompleted, bool isCurrent,
      bool isLast, bool isTablet, bool isDarkMode) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            AnimatedBuilder(
              animation: isCurrent ? _pulseAnimation : _fadeAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: isCurrent ? _pulseAnimation.value : 1.0,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? (isDarkMode
                              ? AppColors.yellowAccent
                              : AppTheme.lightPrimaryColor)
                          : Colors.grey.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isCompleted
                            ? (isDarkMode
                                ? AppColors.yellowAccent
                                : AppTheme.lightPrimaryColor)
                            : Colors.grey,
                        width: 2,
                      ),
                      boxShadow: isCompleted
                          ? [
                              BoxShadow(
                                color: (isDarkMode
                                        ? AppColors.yellowAccent
                                        : AppTheme.lightPrimaryColor)
                                    .withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: isCompleted
                        ? Icon(
                            Icons.check,
                            size: 14,
                            color: isDarkMode ? Colors.black : Colors.white,
                          )
                        : null,
                  ),
                );
              },
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: isCompleted
                    ? (isDarkMode
                        ? AppColors.yellowAccent
                        : AppTheme.lightPrimaryColor)
                    : Colors.grey.withValues(alpha: 0.3),
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status,
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.w600,
                    color: isCompleted
                        ? (isDarkMode ? Colors.white : AppColors.textPrimary)
                        : Colors.grey,
                  ),
                ),
                if (isCurrent)
                  Text(
                    'Current Status',
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 12 : 10,
                      color: isDarkMode
                          ? AppColors.yellowAccent
                          : AppTheme.lightPrimaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------- Helpers / Mapping ----------------

  Map<String, dynamic> _toUiOrderMap(String id, Map<String, dynamic> data,
      [Map<String, dynamic>? userData]) {
    final rawStatus = (data['status'] ?? '').toString().toLowerCase();
    final uiStatus = _toUiStatus(rawStatus);

    final Timestamp? ts = data['startedAt'] is Timestamp
        ? data['startedAt'] as Timestamp
        : (data['paymentTimestamp'] is Timestamp
            ? data['paymentTimestamp'] as Timestamp
            : null);

    String timeString = '—';
    if (ts != null) {
      final dt = ts.toDate();
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      timeString = '$hour:$minute $ampm';
    }

    final itemsList = (data['items'] is List)
        ? List<String>.from((data['items'] as List).map((e) => e.toString()))
        : <String>[];
    final itemsJoined = itemsList.isEmpty ? '—' : itemsList.join(', ');

    final pickupAddr = (data['pickupLocation']?['address'] ?? '').toString();
    final dropoffAddr = (data['dropoffLocation']?['address'] ?? '').toString();

    final num? totalAmount = data['totalAmount'] as num?;
    final num? duration = data['duration'] as num?;

    // Get customer info from user data if available, otherwise fallback to order data
    String customerName = 'Customer';
    String customerPhone = 'N/A';
    String? profileImageUrl;

    if (userData != null) {
      customerName =
          (userData['name'] ?? userData['userName'] ?? 'Customer').toString();
      customerPhone =
          (userData['phoneNumber'] ?? userData['phone'] ?? 'N/A').toString();
      profileImageUrl = userData['profileImageUrl']?.toString();
    } else {
      // Fallback to order data
      customerName =
          (data['customerName'] ?? data['customer'] ?? 'Customer').toString();
      customerPhone = (data['customerPhone'] ?? 'N/A').toString();
    }

    return {
      'id': id,
      'customer': customerName,
      'customerPhone': customerPhone,
      'profileImageUrl': profileImageUrl,
      'pickupAddress': pickupAddr.isEmpty ? '—' : pickupAddr,
      'dropoffAddress': dropoffAddr.isEmpty ? '—' : dropoffAddr,
      'items': itemsJoined,
      'time': timeString,
      'estimatedDuration': _formatDuration(duration),
      'earnings': (totalAmount ?? 0).toDouble(),
      'priority': (data['priority'] ?? _inferPriority(totalAmount)).toString(),
      'status': uiStatus,
    };
  }

  String _toUiStatus(String raw) {
    switch (raw.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'started':
      case 'in_progress':
      case 'in-progress':
        return 'Started';
      case 'picked_up':
      case 'pickedup':
      case 'picked up':
        return 'Picked Up';
      case 'in_transit':
      case 'in-transit':
      case 'transit':
        return 'In Transit';
      case 'delivered':
        return 'Delivered';
      case 'verify_items':
      case 'verifyitems':
      case 'verify items':
        return 'Verify Items';
      case 'completed':
        return _isShiftingOrder ? 'Verify Items' : 'Delivered';
      default:
        // If unknown, consider active job
        return 'Started';
    }
  }

  String _toRawStatus(String ui) {
    switch (ui) {
      case 'Pending':
        return 'pending';
      case 'Started':
        return 'started';
      case 'Picked Up':
        return 'picked_up';
      case 'In Transit':
        return 'in_transit';
      case 'Delivered':
        return 'delivered';
      case 'Verify Items':
        return 'verify_items';
      default:
        return 'started';
    }
  }

  String _formatDuration(num? value) {
    if (value == null) return '—';
    final minutes = value.toInt();
    if (minutes <= 0) return '—';
    if (minutes >= 60) {
      final hours = (minutes / 60).floor();
      final rem = minutes % 60;
      return rem == 0 ? '$hours hours' : '$hours h ${rem}m';
    }
    return '$minutes min';
  }

  String _inferPriority(num? amount) {
    if (amount == null) return 'Medium';
    if (amount >= 1000) return 'High';
    if (amount >= 500) return 'Medium';
    return 'Low';
  }

  Color _getStatusColor(String status, bool isDarkMode) {
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'Started':
        return Colors.blue;
      case 'Picked Up':
        return isDarkMode ? AppColors.yellowAccent : AppTheme.lightPrimaryColor;
      case 'In Transit':
        return Colors.purple;
      case 'Delivered':
        return Colors.green;
      case 'Verify Items':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'High':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      case 'Low':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getActionButtonText() {
    switch (_jobStatus) {
      case 'Pending':
        return 'Start Job';
      case 'Started':
        return 'Mark as Picked Up';
      case 'Picked Up':
        return 'Start Transit';
      case 'In Transit':
        return 'Mark as Delivered';
      case 'Delivered':
        // Check if verification is already completed
        final verificationCompleted =
            widget.orderData['verification_completed'] ?? false;
        if (_isShiftingOrder) {
          return verificationCompleted
              ? 'Complete Job'
              : 'Start Item Verification';
        }
        return 'Job Completed';
      case 'Verify Items':
        return 'Complete Item Verification';
      default:
        return 'Update Status';
    }
  }

  // ---------------- Actions ----------------

  Future<void> _advanceAndPersistStatus(String orderId, bool isDarkMode) async {
    final currentOptions = _currentStatusOptions;
    final idx = currentOptions.indexOf(_jobStatus);
    if (idx < 0) return;

    // Special handling for "Job Completed" button
    if (_jobStatus == 'Delivered' && !_isShiftingOrder) {
      await _completeJob(orderId);
      return;
    }

    // Handle verification for shifting orders
    if (_jobStatus == 'Delivered' && _isShiftingOrder) {
      // Check if verification is already completed
      final verificationCompleted =
          widget.orderData['verification_completed'] ?? false;
      if (verificationCompleted) {
        // Verification done, complete the job
        await _completeJob(orderId);
      } else {
        // Start verification
        await _startItemVerification(orderId, isDarkMode);
      }
      return;
    }

    if (_jobStatus == 'Verify Items') {
      await _completeJob(orderId);
      return;
    }

    if (idx >= currentOptions.length - 1) {
      _showGlowingSnackBar(context, 'Job already completed!', Colors.green);
      return;
    }

    final nextUi = currentOptions[idx + 1];
    final nextRaw = _toRawStatus(nextUi);

    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({
        'status': nextRaw,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() => _jobStatus = nextUi);
      }

      _showGlowingSnackBar(
        context,
        'Job status updated to $nextUi',
        isDarkMode ? AppColors.yellowAccent : AppTheme.lightPrimaryColor,
      );
    } catch (e) {
      _showGlowingSnackBar(context, 'Failed to update status: $e', Colors.red);
    }
  }

  Future<void> _completeJob(String orderId) async {
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({
        'status': 'completed',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _showGlowingSnackBar(
        context,
        'Job completed successfully!',
        Colors.green,
      );

      // Navigate to driver orders screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const DriverOrdersScreen(),
        ),
      );
    } catch (e) {
      _showGlowingSnackBar(context, 'Failed to complete job: $e', Colors.red);
    }
  }

  Future<void> _startItemVerification(String orderId, bool isDarkMode) async {
    // Navigate to camera verification screen
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ItemVerificationScreen(
          orderId: orderId,
          orderData: widget.orderData,
        ),
      ),
    );

    if (result == true) {
      // All items verified successfully - order status is already 'completed'
      // Show success message and navigate away
      _showGlowingSnackBar(
        context,
        'Order completed successfully! All items verified.',
        Colors.green,
      );

      // Navigate back to driver orders screen after a short delay
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const DriverOrdersScreen(),
          ),
        );
      }
    } else if (result == false) {
      // Some items missing - verification incomplete
      // Stay on this screen so driver can verify again
      _showGlowingSnackBar(
        context,
        'Some items are missing. Tap "Start Item Verification" again to scan remaining items.',
        Colors.orange,
      );

      // Refresh the screen to allow another verification attempt
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _callCustomer(BuildContext context, String phone) {
    _showGlowingSnackBar(
      context,
      phone == 'N/A' ? 'No phone number available' : 'Calling $phone...',
      Colors.green,
    );
  }

  void _reportIssue(BuildContext context, bool isDarkMode) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.report, color: Colors.red, size: 28),
            const SizedBox(width: 8),
            Text(
              'Report Issue',
              style: GoogleFonts.albertSans(
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          'Would you like to report an issue with this job? Our support team will be notified immediately.',
          style: GoogleFonts.albertSans(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.8)
                : AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              'Cancel',
              style: GoogleFonts.albertSans(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.7)
                    : AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              _showGlowingSnackBar(
                  context, 'Issue reported successfully', Colors.red);
            },
            child: Text(
              'Report',
              style: GoogleFonts.albertSans(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showGlowingSnackBar(
      BuildContext context, String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.albertSans(
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
