import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shiffters/theme/app_colors.dart';
import 'package:shiffters/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shiffters/services/theme_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shiffters/screens/Driver/driver_help_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  // Controllers for form fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _vehicleNumberController =
      TextEditingController();
  final TextEditingController _vehicleTypeController = TextEditingController();
  final TextEditingController _emergencyContactController =
      TextEditingController();

  bool _isEditing = false;
  bool _notificationsEnabled = true;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isUploadingImage = false;
  String? _profileImageUrl;

  // Order statistics
  int _completedOrdersCount = 0;
  int _thisMonthOrdersCount = 0;
  double _totalEarnings = 0.0;

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadDriverData();
    _startAnimations();

    // Set system UI overlay style
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

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
  }

  void _loadDriverData() async {
    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Fetch driver data from Firestore
        final driverDoc =
            await _firestore.collection('drivers').doc(user.uid).get();

        if (driverDoc.exists) {
          final data = driverDoc.data()!;
          _nameController.text = data['personalInfo']?['firstName'] ?? '';
          _phoneController.text = data['personalInfo']?['phone'] ?? '';
          _emailController.text = data['personalInfo']?['email'] ?? '';
          _vehicleNumberController.text = data['vehicle']?['plateNumber'] ?? '';
          _vehicleTypeController.text = data['vehicle']?['type'] ?? '';
          _emergencyContactController.text =
              data['personalInfo']?['emergencyContact'] ?? '';

          // Load profile image URL
          _profileImageUrl = data['profileImageUrl'];

          // Update settings
          setState(() {
            _notificationsEnabled = data['settings']?['notifications'] ?? true;
          });
        } else {
          // If no driver document exists, create one with default values
          await _createDefaultDriverProfile();
        }

        // Load order statistics
        await _loadOrderStatistics();

        debugPrint('Driver data and order statistics loaded successfully');
      }
    } catch (e) {
      debugPrint('Error loading driver data: $e');
      _showGlowingSnackBar(
        'Error loading profile data',
        Colors.red,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadOrderStatistics() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Get current date for this month filter
        final now = DateTime.now();
        final startOfMonth = DateTime(now.year, now.month, 1);
        final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

        // Query all completed orders for this driver (simplified query to avoid index issues)
        final completedOrdersQuery = await _firestore
            .collection('orders')
            .where('driverId', isEqualTo: user.uid)
            .where('status', isEqualTo: 'completed')
            .get();

        int completedCount = completedOrdersQuery.docs.length;
        int thisMonthCount = 0;
        double totalEarnings = 0.0;

        // Calculate statistics from all completed orders
        for (var doc in completedOrdersQuery.docs) {
          final data = doc.data();

          // Calculate total earnings
          final amount = data['totalAmount'];
          if (amount != null) {
            if (amount is num) {
              totalEarnings += amount.toDouble();
            } else if (amount is String) {
              totalEarnings += double.tryParse(amount) ?? 0.0;
            }
          }

          // Check if this order was completed this month
          final updatedAt = data['updatedAt'] as Timestamp?;
          if (updatedAt != null) {
            final orderDate = updatedAt.toDate();
            if (orderDate
                    .isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
                orderDate.isBefore(endOfMonth.add(const Duration(days: 1)))) {
              thisMonthCount++;
            }
          }
        }

        setState(() {
          _completedOrdersCount = completedCount;
          _thisMonthOrdersCount = thisMonthCount;
          _totalEarnings = totalEarnings;
        });

        // Debug output to verify data
        debugPrint('Driver Orders Statistics:');
        debugPrint('Total completed orders: $completedCount');
        debugPrint('This month orders: $thisMonthCount');
        debugPrint('Total earnings: $totalEarnings');
      }
    } catch (e) {
      debugPrint('Error loading order statistics: $e');
    }
  }

  Future<void> _showOrdersDialog() async {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isDarkMode = themeService.isDarkMode;

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Show loading dialog first
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDarkMode
                      ? AppColors.yellowAccent
                      : AppTheme.lightPrimaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading orders...',
                style: GoogleFonts.albertSans(
                  color: isDarkMode ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      );

      // Fetch completed orders
      final completedOrdersQuery = await _firestore
          .collection('orders')
          .where('driverId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'completed')
          .limit(50) // Limit to recent 50 orders
          .get();

      // Sort orders by updatedAt on client side
      final sortedDocs = completedOrdersQuery.docs;
      sortedDocs.sort((a, b) {
        final aTimestamp = a.data()['updatedAt'] as Timestamp?;
        final bTimestamp = b.data()['updatedAt'] as Timestamp?;

        if (aTimestamp == null && bTimestamp == null) return 0;
        if (aTimestamp == null) return 1;
        if (bTimestamp == null) return -1;

        return bTimestamp.compareTo(aTimestamp); // Descending order
      });

      // Close loading dialog
      Navigator.pop(context);

      // Show orders in a dialog
      if (sortedDocs.isNotEmpty) {
        showDialog(
          context: context,
          builder: (context) => _buildOrdersDialog(isDarkMode, sortedDocs),
        );
      } else {
        _showGlowingSnackBar('No completed orders found', Colors.orange);
      }
    } catch (e) {
      // Close loading dialog if open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      debugPrint('Error loading orders: $e');
      _showGlowingSnackBar('Error loading orders', Colors.red);
    }
  }

  Widget _buildOrdersDialog(
      bool isDarkMode, List<QueryDocumentSnapshot> orders) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.green.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Completed Orders ($_completedOrdersCount)',
                    style: GoogleFonts.albertSans(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.close,
                        color:
                            isDarkMode ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Orders List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];
                  final data = order.data() as Map<String, dynamic>;
                  final orderId = order.id;
                  final totalAmount = data['totalAmount'] ?? 0;
                  final updatedAt = data['updatedAt'] as Timestamp?;
                  final pickupLocation =
                      data['pickupLocation']?['address'] ?? 'Unknown';
                  final dropoffLocation =
                      data['dropoffLocation']?['address'] ?? 'Unknown';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Order Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Order #${orderId.substring(0, 8)}',
                              style: GoogleFonts.albertSans(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green),
                              ),
                              child: Text(
                                'Rs. ${totalAmount is num ? totalAmount.toStringAsFixed(0) : totalAmount}',
                                style: GoogleFonts.albertSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Locations
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 16,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'From: ${pickupLocation.length > 30 ? '${pickupLocation.substring(0, 30)}...' : pickupLocation}',
                                style: GoogleFonts.albertSans(
                                  fontSize: 12,
                                  color: isDarkMode
                                      ? Colors.white.withValues(alpha: 0.8)
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.flag,
                              size: 16,
                              color: Colors.red,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'To: ${dropoffLocation.length > 30 ? '${dropoffLocation.substring(0, 30)}...' : dropoffLocation}',
                                style: GoogleFonts.albertSans(
                                  fontSize: 12,
                                  color: isDarkMode
                                      ? Colors.white.withValues(alpha: 0.8)
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Date
                        if (updatedAt != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 16,
                                color: isDarkMode
                                    ? Colors.white.withValues(alpha: 0.6)
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Completed: ${_formatDate(updatedAt.toDate())}',
                                style: GoogleFonts.albertSans(
                                  fontSize: 12,
                                  color: isDarkMode
                                      ? Colors.white.withValues(alpha: 0.6)
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatEarnings(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    } else {
      return amount.toStringAsFixed(0);
    }
  }

  Future<void> _createDefaultDriverProfile() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final defaultData = {
          'uid': user.uid,
          'applicationStatus': 'approved',
          'personalInfo': {
            'firstName': user.displayName ?? '',
            'email': user.email ?? '',
            'phone': '',
          },
          'vehicle': {
            'type': '',
            'plateNumber': '',
            'model': '',
            'year': '',
            'hasInsurance': false,
            'insuranceNumber': '',
          },
          'settings': {
            'notifications': true,
          },
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        await _firestore.collection('drivers').doc(user.uid).set(defaultData);

        // Update controllers with default values
        _nameController.text = user.displayName ?? '';
        _emailController.text = user.email ?? '';
      }
    } catch (e) {
      debugPrint('Error creating default driver profile: $e');
    }
  }

  Future<void> _saveDriverData() async {
    if (!_validateFields()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = _auth.currentUser;
      if (user != null) {
        final updateData = {
          'personalInfo': {
            'firstName': _nameController.text.trim(),
            'email': _emailController.text.trim(),
            'phone': _phoneController.text.trim(),
            'emergencyContact': _emergencyContactController.text.trim(),
          },
          'vehicle': {
            'type': _vehicleTypeController.text.trim(),
            'plateNumber': _vehicleNumberController.text.trim(),
          },
          'settings': {
            'notifications': _notificationsEnabled,
          },
          'updatedAt': FieldValue.serverTimestamp(),
        };

        await _firestore.collection('drivers').doc(user.uid).update(updateData);

        setState(() => _isEditing = false);

        _showGlowingSnackBar(
          'Profile updated successfully',
          isDarkMode ? AppColors.yellowAccent : AppTheme.lightPrimaryColor,
        );
      }
    } catch (e) {
      debugPrint('Error saving driver data: $e');
      _showGlowingSnackBar(
        'Error updating profile',
        Colors.red,
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _updateSetting(String settingKey, bool value) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('drivers').doc(user.uid).update({
          'settings.$settingKey': value,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error updating setting: $e');
      _showGlowingSnackBar(
        'Error updating settings',
        Colors.red,
      );
    }
  }

  Future<void> _refreshProfile() async {
    _loadDriverData();
  }

  bool _validateFields() {
    if (_nameController.text.trim().isEmpty) {
      _showGlowingSnackBar('Please enter your name', Colors.red);
      return false;
    }
    if (_phoneController.text.trim().isEmpty) {
      _showGlowingSnackBar('Please enter your phone number', Colors.red);
      return false;
    }
    if (_emailController.text.trim().isEmpty) {
      _showGlowingSnackBar('Please enter your email address', Colors.red);
      return false;
    }
    return true;
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _vehicleNumberController.dispose();
    _vehicleTypeController.dispose();
    _emergencyContactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        final isDarkMode = themeService.isDarkMode;

        return Scaffold(
          backgroundColor: isDarkMode
              ? const Color(0xFF1E1E2C)
              : AppTheme.lightBackgroundColor,
          body: Stack(
            children: [
              Column(
                children: [
                  // Header - Full width
                  _buildHeader(isTablet, isDarkMode),

                  // Content
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _refreshProfile,
                      color: isDarkMode
                          ? AppColors.yellowAccent
                          : AppTheme.lightPrimaryColor,
                      backgroundColor:
                          isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 32 : 20,
                          ),
                          child: Column(
                            children: [
                              const SizedBox(height: 24),

                              // Profile picture and basic info
                              _buildProfileHeader(isTablet, isDarkMode),

                              const SizedBox(height: 24),

                              // Statistics cards
                              _buildStatisticsRow(isTablet, isDarkMode),

                              const SizedBox(height: 24),

                              // Profile form
                              _buildProfileForm(isTablet, isDarkMode),

                              const SizedBox(height: 24),

                              // Quick actions
                              _buildQuickActions(isTablet, isDarkMode),

                              const SizedBox(height: 24),

                              // Settings section
                              _buildSettingsSection(
                                  isTablet, isDarkMode, themeService),

                              const SizedBox(height: 24),

                              // Logout button
                              _buildLogoutButton(isTablet, isDarkMode),

                              const SizedBox(height: 100),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Loading overlay
              if (_isLoading)
                Container(
                  color: Colors.black.withValues(alpha: 0.3),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color:
                            isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isDarkMode
                                  ? AppColors.yellowAccent
                                  : AppTheme.lightPrimaryColor,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Loading profile...',
                            style: GoogleFonts.albertSans(
                              color: isDarkMode
                                  ? Colors.white
                                  : AppColors.textPrimary,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isTablet, bool isDarkMode) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [
                  const Color(0xFF2D2D3C),
                  const Color(0xFF1E1E2C),
                ]
              : [
                  const Color(0xFF1E88E5),
                  const Color(0xFF42A5F5),
                ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: isTablet ? 20 : 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Title
              Text(
                'Driver Profile',
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 28 : 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),

              Row(
                children: [
                  // Cancel button (only show when editing)
                  if (_isEditing) ...[
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _isEditing = false;
                        });
                        // Reload data to discard changes
                        _loadDriverData();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.cancel_outlined,
                          size: isTablet ? 24 : 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],

                  // Edit/Save button
                  GestureDetector(
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      if (_isEditing) {
                        // Save changes
                        await _saveDriverData();
                      } else {
                        // Show options: Edit Profile or Upload Image
                        _showEditOptions(isDarkMode);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isEditing
                            ? Colors.green.withValues(alpha: 0.7)
                            : Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _isSaving
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Icon(
                              _isEditing ? Icons.save : Icons.edit,
                              size: isTablet ? 24 : 20,
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

  Widget _buildProfileHeader(bool isTablet, bool isDarkMode) {
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
              : Border.all(
                  color: AppTheme.lightPrimaryColor,
                  width: 1.5,
                ),
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
          children: [
            // Profile picture
            Stack(
              children: [
                Container(
                  width: isTablet ? 120 : 100,
                  height: isTablet ? 120 : 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.blue,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: _isUploadingImage
                        ? Container(
                            color: isDarkMode
                                ? Colors.grey.withValues(alpha: 0.2)
                                : Colors.grey.withValues(alpha: 0.1),
                            child: Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.blue,
                                ),
                                strokeWidth: 2,
                              ),
                            ),
                          )
                        : _profileImageUrl != null
                            ? Image.network(
                                _profileImageUrl!,
                                fit: BoxFit.cover,
                                width: isTablet ? 120 : 100,
                                height: isTablet ? 120 : 100,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: isDarkMode
                                        ? Colors.blue.withValues(alpha: 0.2)
                                        : Colors.blue.withValues(alpha: 0.2),
                                    child: Icon(
                                      Icons.person,
                                      size: isTablet ? 50 : 40,
                                      color: Colors.blue,
                                    ),
                                  );
                                },
                              )
                            : Container(
                                color: isDarkMode
                                    ? Colors.blue.withValues(alpha: 0.2)
                                    : Colors.blue.withValues(alpha: 0.2),
                                child: Icon(
                                  Icons.person,
                                  size: isTablet ? 50 : 40,
                                  color: Colors.blue,
                                ),
                              ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Name and rating
            Text(
              _nameController.text,
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 24 : 20,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: 4),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green, width: 1),
              ),
              child: Text(
                'Online',
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 12 : 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsRow(bool isTablet, bool isDarkMode) {
    return SlideTransition(
      position: _slideAnimation,
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Jobs Completed',
              '$_completedOrdersCount',
              Icons.work,
              Colors.green,
              isTablet,
              isDarkMode,
              onTap: _showOrdersDialog,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'This Month',
              '$_thisMonthOrdersCount',
              Icons.calendar_today,
              Colors.blue,
              isTablet,
              isDarkMode,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Total Earnings',
              'Rs. ${_formatEarnings(_totalEarnings)}',
              Icons.attach_money,
              Colors.orange,
              isTablet,
              isDarkMode,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileForm(bool isTablet, bool isDarkMode) {
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
              : Border.all(
                  color: AppTheme.lightPrimaryColor,
                  width: 1.5,
                ),
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
                  'Personal Information',
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Form fields
            _buildFormField('Full Name', _nameController, Icons.person,
                isTablet, isDarkMode),
            const SizedBox(height: 16),
            _buildFormField('Phone Number', _phoneController, Icons.phone,
                isTablet, isDarkMode),
            const SizedBox(height: 16),
            _buildFormField('Email Address', _emailController, Icons.email,
                isTablet, isDarkMode),
            const SizedBox(height: 16),
            _buildFormField('Vehicle Number', _vehicleNumberController,
                Icons.directions_car, isTablet, isDarkMode),
            const SizedBox(height: 16),
            _buildFormField('Vehicle Type', _vehicleTypeController,
                Icons.local_shipping, isTablet, isDarkMode),
            const SizedBox(height: 16),
            _buildFormField('Emergency Contact', _emergencyContactController,
                Icons.emergency, isTablet, isDarkMode),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(bool isTablet, bool isDarkMode) {
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
              : Border.all(
                  color: AppTheme.lightPrimaryColor,
                  width: 1.5,
                ),
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
                  Icons.flash_on,
                  color: isDarkMode
                      ? AppColors.yellowAccent
                      : AppTheme.lightPrimaryColor,
                  size: isTablet ? 24 : 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Quick Actions',
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    'View Documents',
                    Icons.document_scanner,
                    Colors.blue,
                    () => _viewDocuments(),
                    isTablet,
                    isDarkMode,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    'Support',
                    Icons.help,
                    Colors.orange,
                    () => _contactSupport(),
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

  Widget _buildSettingsSection(
      bool isTablet, bool isDarkMode, ThemeService themeService) {
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
              : Border.all(
                  color: AppTheme.lightPrimaryColor,
                  width: 1.5,
                ),
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
                  Icons.settings,
                  color: isDarkMode
                      ? AppColors.yellowAccent
                      : AppTheme.lightPrimaryColor,
                  size: isTablet ? 24 : 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Settings',
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Settings items
            _buildSettingsItem(
              'Notifications',
              Icons.notifications,
              _notificationsEnabled,
              (value) {
                setState(() => _notificationsEnabled = value);
                _updateSetting('notifications', value);
              },
              isTablet,
              isDarkMode,
            ),
            _buildSettingsItem(
              'Dark Mode',
              Icons.dark_mode,
              isDarkMode,
              (value) => themeService.setTheme(value),
              isTablet,
              isDarkMode,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(bool isTablet, bool isDarkMode) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(isTablet ? 24 : 20),
        decoration: BoxDecoration(
          color: isDarkMode
              ? Colors.red.withValues(alpha: 0.1)
              : Colors.red.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.red.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.logout,
              color: Colors.red,
              size: isTablet ? 28 : 24,
            ),
            const SizedBox(height: 12),
            Text(
              'Sign Out',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 18 : 16,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You will be signed out of your account',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 14 : 12,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.7)
                    : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _showLogoutConfirmation(isDarkMode);
              },
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  vertical: isTablet ? 16 : 14,
                  horizontal: isTablet ? 32 : 24,
                ),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  'Logout',
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color,
      bool isTablet, bool isDarkMode,
      {VoidCallback? onTap}) {
    Widget cardContent = Container(
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.1)
            : AppTheme.lightCardColor,
        borderRadius: BorderRadius.circular(12),
        border: isDarkMode
            ? null
            : Border.all(
                color: AppTheme.lightPrimaryColor,
                width: 1.5,
              ),
        boxShadow: isDarkMode
            ? null
            : [
                BoxShadow(
                  color: color.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: isTablet ? 24 : 20),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 12 : 10,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.7)
                  : AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 16 : 14,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : AppColors.textPrimary,
            ),
          ),
          // Show tap indicator if onTap is provided
          if (onTap != null) ...[
            const SizedBox(height: 4),
            Icon(
              Icons.touch_app,
              size: 12,
              color: color.withValues(alpha: 0.7),
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: cardContent,
      );
    } else {
      return cardContent;
    }
  }

  Widget _buildFormField(String label, TextEditingController controller,
      IconData icon, bool isTablet, bool isDarkMode) {
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
                : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.1)
                : AppColors.grey100,
            borderRadius: BorderRadius.circular(16),
            border: isDarkMode
                ? Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1,
                  )
                : Border.all(
                    color: AppTheme.lightPrimaryColor,
                    width: 1.5,
                  ),
          ),
          child: TextField(
            controller: controller,
            enabled: _isEditing,
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 14 : 12,
              color: isDarkMode ? Colors.white : AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(
                icon,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.6)
                    : AppColors.textSecondary,
                size: isTablet ? 20 : 18,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Colors.blue,
                  width: 2,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: isTablet ? 20 : 16,
                vertical: isTablet ? 18 : 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(String title, IconData icon, Color color,
      VoidCallback onTap, bool isTablet, bool isDarkMode) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: EdgeInsets.all(isTablet ? 16 : 12),
        decoration: BoxDecoration(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
          border: isDarkMode
              ? null
              : Border.all(
                  color: AppTheme.lightPrimaryColor,
                  width: 1.5,
                ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: isTablet ? 24 : 20),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 12 : 10,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsItem(String title, IconData icon, bool value,
      Function(bool) onChanged, bool isTablet, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 16 : 12,
          vertical: isTablet ? 16 : 12,
        ),
        decoration: BoxDecoration(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: isDarkMode
              ? null
              : Border.all(
                  color: AppTheme.lightPrimaryColor,
                  width: 1.5,
                ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.8)
                  : AppColors.textSecondary,
              size: isTablet ? 22 : 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 16 : 14,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: Colors.blue,
              activeTrackColor: Colors.blue.withValues(alpha: 0.3),
              inactiveThumbColor: isDarkMode
                  ? Colors.white.withValues(alpha: 0.5)
                  : AppColors.grey400,
              inactiveTrackColor: isDarkMode
                  ? Colors.white.withValues(alpha: 0.2)
                  : AppColors.grey300,
            ),
          ],
        ),
      ),
    );
  }

  void _changeProfilePicture() {
    _showImageSourceDialog();
  }

  // Show image source selection dialog
  Future<void> _showImageSourceDialog() async {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isDarkMode = themeService.isDarkMode;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select Image Source',
              style: GoogleFonts.albertSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),

            // Camera Option
            ListTile(
              leading: Icon(
                Icons.camera_alt,
                color: Colors.blue,
                size: 28,
              ),
              title: Text(
                'Camera',
                style: GoogleFonts.albertSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.white : AppColors.textPrimary,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromSource(ImageSource.camera);
              },
            ),

            // Gallery Option
            ListTile(
              leading: Icon(
                Icons.photo_library,
                color: Colors.blue,
                size: 28,
              ),
              title: Text(
                'Gallery',
                style: GoogleFonts.albertSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.white : AppColors.textPrimary,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromSource(ImageSource.gallery);
              },
            ),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // Pick image from specified source and upload to ImageBB
  Future<void> _pickImageFromSource(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        // Show preview dialog instead of directly uploading
        await _showImagePreview(image);
      }
    } catch (e) {
      if (mounted) {
        _showGlowingSnackBar(
          'Error selecting image: $e',
          Colors.red,
        );
      }
    }
  }

  // Show image preview and confirm upload
  Future<void> _showImagePreview(XFile imageFile) async {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isDarkMode = themeService.isDarkMode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
        title: Text(
          'Confirm Profile Image',
          style: GoogleFonts.albertSans(
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : AppColors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.blue,
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: Image.file(
                  File(imageFile.path),
                  fit: BoxFit.cover,
                  width: 200,
                  height: 200,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Do you want to use this image as your profile picture?',
              style: GoogleFonts.albertSans(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.8)
                    : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.albertSans(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.7)
                    : AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Use Image',
              style: GoogleFonts.albertSans(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed == true) {
        setState(() {
          _isUploadingImage = true;
        });

        // Upload to ImageBB
        final imageUrl = await _uploadImageToImageBB(File(imageFile.path));

        if (imageUrl != null) {
          setState(() {
            _profileImageUrl = imageUrl;
            _isUploadingImage = false;
          });

          // Update in Firebase
          final user = _auth.currentUser;
          if (user != null) {
            await _firestore.collection('drivers').doc(user.uid).update({
              'profileImageUrl': imageUrl,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }

          if (mounted) {
            _showGlowingSnackBar(
              'Profile image updated successfully!',
              Colors.green,
            );
          }
        } else {
          setState(() {
            _isUploadingImage = false;
          });

          if (mounted) {
            _showGlowingSnackBar(
              'Failed to upload image. Please try again.',
              Colors.red,
            );
          }
        }
      }
    });
  }

  // Upload image to ImageBB API
  Future<String?> _uploadImageToImageBB(File imageFile) async {
    try {
      const String apiKey = 'f31e40432a7b500dd75ce5255d3ea517';
      const String uploadUrl = 'https://api.imgbb.com/1/upload';

      // Convert image to base64
      List<int> imageBytes = await imageFile.readAsBytes();
      String base64Image = base64Encode(imageBytes);

      // Prepare the request
      var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
      request.fields['key'] = apiKey;
      request.fields['image'] = base64Image;

      // Send the request
      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var jsonResponse = json.decode(responseData);

      if (response.statusCode == 200 && jsonResponse['success']) {
        return jsonResponse['data']['url'];
      } else {
        debugPrint(
            'ImageBB upload failed: ${jsonResponse['error']['message']}');
        return null;
      }
    } catch (e) {
      debugPrint('Error uploading to ImageBB: $e');
      return null;
    }
  }

  // Show edit options: Edit Profile or Upload Image
  Future<void> _showEditOptions(bool isDarkMode) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Profile Options',
              style: GoogleFonts.albertSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),

            // Edit Profile Option
            ListTile(
              leading: Icon(
                Icons.edit,
                color: Colors.blue,
                size: 28,
              ),
              title: Text(
                'Edit Profile',
                style: GoogleFonts.albertSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.white : AppColors.textPrimary,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _isEditing = !_isEditing;
                });
              },
            ),

            // Upload Image Option
            ListTile(
              leading: Icon(
                Icons.image,
                color: Colors.blue,
                size: 28,
              ),
              title: Text(
                'Upload Profile Image',
                style: GoogleFonts.albertSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.white : AppColors.textPrimary,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _changeProfilePicture();
              },
            ),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _viewDocuments() async {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isDarkMode = themeService.isDarkMode;

    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Show loading dialog first
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor:
                isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.blue,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading documents...',
                  style: GoogleFonts.albertSans(
                    color: isDarkMode ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );

        // Fetch driver data from Firebase
        final driverDoc =
            await _firestore.collection('drivers').doc(user.uid).get();

        // Close loading dialog
        Navigator.pop(context);

        if (driverDoc.exists) {
          final data = driverDoc.data()!;
          final documents = data['documents'] as Map<String, dynamic>?;

          String? cnicFrontUrl = documents?['cnicFront'];
          String? cnicBackUrl = documents?['cnicBack'];

          // Show document viewer dialog
          showDialog(
            context: context,
            builder: (context) => _buildDocumentViewerDialog(
              isDarkMode,
              cnicFrontUrl,
              cnicBackUrl,
            ),
          );
        } else {
          _showGlowingSnackBar(
            'No documents found',
            Colors.orange,
          );
        }
      }
    } catch (e) {
      // Close loading dialog if open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      debugPrint('Error loading documents: $e');
      _showGlowingSnackBar(
        'Error loading documents',
        Colors.red,
      );
    }
  }

  Widget _buildDocumentViewerDialog(
      bool isDarkMode, String? cnicFrontUrl, String? cnicBackUrl) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? AppColors.yellowAccent.withValues(alpha: 0.1)
                    : AppTheme.lightPrimaryColor.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'CNIC Documents',
                    style: GoogleFonts.albertSans(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.close,
                        color:
                            isDarkMode ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // CNIC Front
                    Expanded(
                      child: _buildDocumentCard(
                        'CNIC Front',
                        cnicFrontUrl,
                        isDarkMode,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // CNIC Back
                    Expanded(
                      child: _buildDocumentCard(
                        'CNIC Back',
                        cnicBackUrl,
                        isDarkMode,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentCard(String title, String? imageUrl, bool isDarkMode) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.05)
            : AppColors.grey100,
        borderRadius: BorderRadius.circular(12),
        border: isDarkMode
            ? Border.all(color: Colors.white.withValues(alpha: 0.1))
            : Border.all(
                color: AppTheme.lightPrimaryColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          // Title
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? AppColors.yellowAccent.withValues(alpha: 0.1)
                  : AppTheme.lightPrimaryColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Text(
              title,
              style: GoogleFonts.albertSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Image
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isDarkMode
                                    ? AppColors.yellowAccent
                                    : AppTheme.lightPrimaryColor,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 48,
                                  color: Colors.red.withValues(alpha: 0.7),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Failed to load image',
                                  style: GoogleFonts.albertSans(
                                    color: isDarkMode
                                        ? Colors.white.withValues(alpha: 0.7)
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_not_supported_outlined,
                            size: 48,
                            color: isDarkMode
                                ? Colors.white.withValues(alpha: 0.5)
                                : AppColors.textSecondary
                                    .withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No image available',
                            style: GoogleFonts.albertSans(
                              color: isDarkMode
                                  ? Colors.white.withValues(alpha: 0.7)
                                  : AppColors.textSecondary,
                            ),
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

  void _contactSupport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DriverHelpScreen(),
      ),
    );
  }

  void _showGlowingSnackBar(String message, Color backgroundColor) {
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

  void _showLogoutConfirmation(bool isDarkMode) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.logout,
                color: Colors.red,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Logout',
                style: GoogleFonts.albertSans(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to logout? You will be signed out of your account and redirected to the login screen.',
            style: GoogleFonts.albertSans(
              fontSize: 16,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.8)
                  : AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.albertSans(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.7)
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _performLogout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(
                'Logout',
                style: GoogleFonts.albertSans(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Clear remember me saved information
  Future<void> _clearRememberMeData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auto_login', false);
      await prefs.setBool('remember_me', false);
      await prefs.remove('saved_email');
      await prefs.remove('saved_password');
      debugPrint('Remember me data cleared successfully');
    } catch (e) {
      debugPrint('Error clearing remember me data: $e');
    }
  }

  Future<void> _performLogout() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
              ),
              const SizedBox(height: 16),
              Text(
                'Signing out...',
                style: GoogleFonts.albertSans(
                  color: isDarkMode ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      );

      // Clear remember me saved information before logout
      await _clearRememberMeData();

      // Sign out from Firebase
      await _auth.signOut();

      // Close loading dialog
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // Show success message
      _showGlowingSnackBar('Successfully logged out', Colors.green);

      // Navigate to login screen (you may need to adjust this based on your app's navigation structure)
      // For now, we'll just pop all routes and assume the app will handle showing login
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } catch (e) {
      // Close loading dialog if open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      debugPrint('Error during logout: $e');
      _showGlowingSnackBar('Error during logout', Colors.red);
    }
  }

  bool get isDarkMode =>
      Provider.of<ThemeService>(context, listen: false).isDarkMode;
}
