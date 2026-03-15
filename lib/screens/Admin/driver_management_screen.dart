import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shiffters/theme/app_colors.dart';
import 'package:shiffters/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shiffters/services/theme_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DriverManagementScreen extends StatefulWidget {
  const DriverManagementScreen({super.key});

  @override
  State<DriverManagementScreen> createState() => _DriverManagementScreenState();
}

class _DriverManagementScreenState extends State<DriverManagementScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late AnimationController _animationController;
  late AnimationController _cardAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _cardScaleAnimation;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';
  final List<String> _filterOptions = [
    'All',
    'Active',
    'Pending Approval',
    'Approved',
    'Rejected',
    'Blocked',
    'Suspended'
  ];

  List<Map<String, dynamic>> _allDrivers = [];
  List<Map<String, dynamic>> _filteredDrivers = [];
  Set<String> _selectedDrivers = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
    _loadDrivers();

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

    _cardAnimationController = AnimationController(
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

    _cardScaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cardAnimationController,
      curve: Curves.easeOutBack,
    ));
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      _animationController.forward();
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) {
        _cardAnimationController.forward();
      }
    }
  }

  Future<void> _loadDrivers() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final driversSnapshot = await _firestore
          .collection('drivers')
          .orderBy('createdAt', descending: true)
          .get();

      if (mounted) {
        setState(() {
          _allDrivers = driversSnapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'name': data['personalInfo']?['firstName'] ??
                  data['name'] ??
                  'Unknown Driver',
              'email': data['personalInfo']?['email'] ?? data['email'] ?? '',
              'phone':
                  data['personalInfo']?['phone'] ?? data['phoneNumber'] ?? '',
              'emergencyContact':
                  data['personalInfo']?['emergencyContact'] ?? '',
              'address': data['address'] ?? {},
              'status': data['applicationStatus'] ?? 'Pending Approval',
              'vehicleType':
                  data['vehicle']?['type'] ?? data['vehicleType'] ?? 'Unknown',
              'vehicleNumber': data['vehicle']?['plateNumber'] ??
                  data['vehicleNumber'] ??
                  '',
              'licenseNumber': data['license']?['licenseNumber'] ?? '',
              'experience': data['experience'] ?? '',
              'rating': (data['rating'] as num?)?.toDouble() ?? 0.0,
              'totalJobs': data['totalJobs'] ?? 0,
              'totalEarnings':
                  (data['totalEarnings'] as num?)?.toDouble() ?? 0.0,
              'registrationDate': _formatDate(data['createdAt']),
              'lastActive': _formatDate(data['lastActive']),
              'updatedAt': _formatDate(data['updatedAt']),
              'documents': data['documents'] ??
                  {
                    'license': 'Pending',
                    'cnic': 'Pending',
                    'vehicle': 'Pending',
                  },
              'profileImageUrl': data['profileImageUrl'] ?? '',
              'isOnline': data['isOnline'] ?? false,
              'location': data['location'] ?? {},
              'settings': data['settings'] ?? {},
              'notifications': data['notifications'] ?? true,
              'autoAccept': data['autoAccept'] ?? false,
              'locationSharing': data['locationSharing'] ?? true,
              'hasCommercialLicense':
                  data['license']?['hasCommercialLicense'] ?? false,
            };
          }).toList();

          _filteredDrivers = List.from(_allDrivers);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading drivers: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showGlowingSnackBar(
          'Error loading drivers: $e',
          AppColors.error,
        );
      }
    }
  }

  void _filterDrivers() {
    setState(() {
      _filteredDrivers = _allDrivers.where((driver) {
        final matchesFilter =
            _selectedFilter == 'All' || driver['status'] == _selectedFilter;
        final searchTerm = _searchController.text.toLowerCase();
        final matchesSearch = _searchController.text.isEmpty ||
            driver['name'].toLowerCase().contains(searchTerm) ||
            driver['email'].toLowerCase().contains(searchTerm) ||
            driver['phone'].contains(_searchController.text) ||
            driver['vehicleNumber'].toLowerCase().contains(searchTerm) ||
            driver['vehicleType'].toLowerCase().contains(searchTerm) ||
            driver['licenseNumber'].toLowerCase().contains(searchTerm) ||
            (driver['address']?['city'] ?? '')
                .toLowerCase()
                .contains(searchTerm) ||
            (driver['address']?['state'] ?? '')
                .toLowerCase()
                .contains(searchTerm);
        return matchesFilter && matchesSearch;
      }).toList();
    });
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Not available';

    try {
      DateTime date;
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is String) {
        return timestamp;
      } else {
        return 'Invalid date';
      }

      return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalid date';
    }
  }

  // Show glowing snackbar with white glowing text
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

  @override
  void dispose() {
    _animationController.dispose();
    _cardAnimationController.dispose();
    _searchController.dispose();
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
          backgroundColor:
              isDarkMode ? const Color(0xFF1E1E2C) : const Color(0xFFE8E8F0),
          body: Container(
            decoration: isDarkMode
                ? null
                : const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage(
                          'assets/background/splashScreenBackground.jpg'),
                      fit: BoxFit.cover,
                      opacity: 0.1,
                    ),
                  ),
            child: SafeArea(
              child: Column(
                children: [
                  // Header
                  _buildHeader(isTablet, isDarkMode),

                  // Search and filters
                  _buildSearchAndFilters(isTablet, isDarkMode),

                  // Bulk actions
                  if (_selectedDrivers.isNotEmpty)
                    _buildBulkActions(isTablet, isDarkMode),

                  // Content
                  Expanded(
                    child: _isLoading
                        ? _buildLoadingIndicator(isDarkMode)
                        : _buildDriversList(isTablet, isDarkMode),
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
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Driver Management',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 28 : 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${_filteredDrivers.length} drivers found',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 14 : 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters(bool isTablet, bool isDarkMode) {
    return SlideTransition(
      position: _slideAnimation,
      child: Column(
        children: [
          // Search bar
          Container(
            margin: EdgeInsets.symmetric(
              horizontal: isTablet ? 32 : 20,
              vertical: isTablet ? 16 : 12,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.1)
                  : AppTheme.lightCardColor,
              borderRadius: BorderRadius.circular(16),
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
            child: Row(
              children: [
                Icon(
                  Icons.search,
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.7)
                      : AppTheme.lightTextSecondaryColor,
                  size: isTablet ? 24 : 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => _filterDrivers(),
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 16 : 14,
                      color: isDarkMode
                          ? Colors.white
                          : AppTheme.lightTextPrimaryColor,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          'Search by name, email, phone, vehicle, license, or city...',
                      hintStyle: GoogleFonts.albertSans(
                        fontSize: isTablet ? 16 : 14,
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.5)
                            : AppTheme.lightTextLightColor,
                      ),
                      border: InputBorder.none,
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: isDarkMode
                              ? AppColors.yellowAccent
                              : AppTheme.lightPrimaryColor,
                          width: 2.0,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.3)
                              : AppTheme.lightPrimaryColor,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      _filterDrivers();
                    },
                    child: Icon(
                      Icons.clear,
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.7)
                          : AppTheme.lightTextSecondaryColor,
                      size: isTablet ? 20 : 18,
                    ),
                  ),
              ],
            ),
          ),

          // Filter tabs
          Container(
            height: 50,
            margin: EdgeInsets.symmetric(
              horizontal: isTablet ? 32 : 20,
              vertical: isTablet ? 8 : 4,
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: _filterOptions.length,
              itemBuilder: (context, index) {
                final option = _filterOptions[index];
                final isSelected = _selectedFilter == option;
                final count = option == 'All'
                    ? _allDrivers.length
                    : _allDrivers.where((d) => d['status'] == option).length;

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _selectedFilter = option;
                      _filterDrivers();
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDarkMode
                              ? AppColors.yellowAccent
                              : AppTheme.lightPrimaryColor)
                          : (isDarkMode
                              ? Colors.white.withValues(alpha: 0.1)
                              : AppTheme.lightCardColor),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: isSelected
                            ? (isDarkMode
                                ? AppColors.yellowAccent
                                : AppTheme.lightPrimaryColor)
                            : (isDarkMode
                                ? Colors.white.withValues(alpha: 0.3)
                                : AppTheme.lightBorderColor),
                        width: 1.5,
                      ),
                      boxShadow: isSelected && !isDarkMode
                          ? [
                              BoxShadow(
                                color: AppTheme.lightPrimaryColor
                                    .withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            option,
                            style: GoogleFonts.albertSans(
                              fontSize: isTablet ? 14 : 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? (isDarkMode ? Colors.black : Colors.white)
                                  : (isDarkMode
                                      ? Colors.white
                                      : AppTheme.lightTextPrimaryColor),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDarkMode
                                      ? Colors.black.withValues(alpha: 0.2)
                                      : Colors.white.withValues(alpha: 0.3))
                                  : (isDarkMode
                                      ? AppColors.yellowAccent
                                          .withValues(alpha: 0.3)
                                      : AppTheme.lightPrimaryColor
                                          .withValues(alpha: 0.2)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              count.toString(),
                              style: GoogleFonts.albertSans(
                                fontSize: isTablet ? 10 : 8,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? (isDarkMode ? Colors.black : Colors.white)
                                    : (isDarkMode
                                        ? AppColors.yellowAccent
                                        : AppTheme.lightPrimaryColor),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulkActions(bool isTablet, bool isDarkMode) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: isTablet ? 32 : 20,
          vertical: isTablet ? 8 : 4,
        ),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode
              ? AppColors.yellowAccent.withValues(alpha: 0.1)
              : AppTheme.lightPrimaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDarkMode
                ? AppColors.yellowAccent
                : AppTheme.lightPrimaryColor,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.checklist,
              color: isDarkMode
                  ? AppColors.yellowAccent
                  : AppTheme.lightPrimaryColor,
              size: isTablet ? 24 : 20,
            ),
            const SizedBox(width: 12),
            Text(
              '${_selectedDrivers.length} selected',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 16 : 14,
                fontWeight: FontWeight.w600,
                color:
                    isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
              ),
            ),
            const Spacer(),
            _buildBulkActionButton(
              'Approve',
              Icons.check,
              Colors.green,
              _bulkApprove,
              isTablet,
              isDarkMode,
            ),
            const SizedBox(width: 8),
            _buildBulkActionButton(
              'Block',
              Icons.block,
              Colors.red,
              _bulkBlock,
              isTablet,
              isDarkMode,
            ),
            const SizedBox(width: 8),
            _buildBulkActionButton(
              'Delete',
              Icons.delete,
              Colors.red,
              _bulkDelete,
              isTablet,
              isDarkMode,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBulkActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
    bool isTablet,
    bool isDarkMode,
  ) {
    return Container(
      height: isTablet ? 40 : 36,
      child: ElevatedButton.icon(
        onPressed: () {
          HapticFeedback.lightImpact();
          onPressed();
        },
        icon: Icon(
          icon,
          color: Colors.white,
          size: isTablet ? 16 : 14,
        ),
        label: Text(
          label,
          style: GoogleFonts.albertSans(
            fontSize: isTablet ? 12 : 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 12 : 8,
            vertical: 0,
          ),
        ),
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isDarkMode ? 0.3 : 0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: color.withValues(alpha: isDarkMode ? 0.1 : 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: isDarkMode
                ? AppColors.yellowAccent
                : AppTheme.lightPrimaryColor,
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading drivers...',
            style: GoogleFonts.albertSans(
              fontSize: 16,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.7)
                  : AppTheme.lightTextSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriversList(bool isTablet, bool isDarkMode) {
    if (_filteredDrivers.isEmpty) {
      return _buildEmptyState(isDarkMode);
    }

    return SlideTransition(
      position: _slideAnimation,
      child: RefreshIndicator(
        onRefresh: _refreshDrivers,
        color: isDarkMode ? AppColors.yellowAccent : AppTheme.lightPrimaryColor,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 32 : 20,
            vertical: isTablet ? 16 : 12,
          ),
          itemCount: _filteredDrivers.length,
          itemBuilder: (context, index) {
            final driver = _filteredDrivers[index];
            return ScaleTransition(
              scale: _cardScaleAnimation,
              child: _buildDriverCard(driver, isTablet, isDarkMode),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_shipping_outlined,
            size: 80,
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.3)
                : AppTheme.lightTextLightColor,
          ),
          const SizedBox(height: 16),
          Text(
            'No drivers found',
            style: GoogleFonts.albertSans(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.7)
                  : AppTheme.lightTextSecondaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or filter criteria',
            style: GoogleFonts.albertSans(
              fontSize: 14,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.5)
                  : AppTheme.lightTextLightColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDriverCard(
      Map<String, dynamic> driver, bool isTablet, bool isDarkMode) {
    final isSelected = _selectedDrivers.contains(driver['id']);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.1)
            : AppTheme.lightCardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? (isDarkMode
                  ? AppColors.yellowAccent
                  : AppTheme.lightPrimaryColor)
              : (isDarkMode
                  ? Colors.white.withValues(alpha: 0.2)
                  : AppTheme.lightPrimaryColor),
          width: isSelected ? 2 : 1.5,
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
          Row(
            children: [
              // Checkbox
              GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedDrivers.remove(driver['id']);
                    } else {
                      _selectedDrivers.add(driver['id']);
                    }
                  });
                },
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDarkMode
                            ? AppColors.yellowAccent
                            : AppTheme.lightPrimaryColor)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected
                          ? (isDarkMode
                              ? AppColors.yellowAccent
                              : AppTheme.lightPrimaryColor)
                          : (isDarkMode
                              ? Colors.white.withValues(alpha: 0.5)
                              : AppTheme.lightBorderColor),
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check,
                          size: 16,
                          color: isDarkMode ? Colors.black : Colors.white,
                        )
                      : null,
                ),
              ),

              const SizedBox(width: 16),

              // Avatar
              Container(
                width: isTablet ? 70 : 60,
                height: isTablet ? 70 : 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDarkMode
                        ? AppColors.yellowAccent
                        : AppTheme.lightPrimaryColor,
                    width: 2,
                  ),
                  color: isDarkMode
                      ? AppColors.yellowAccent.withValues(alpha: 0.2)
                      : AppTheme.lightPrimaryColor.withValues(alpha: 0.2),
                ),
                child: ClipOval(
                  child: driver['profileImageUrl'] != null &&
                          driver['profileImageUrl'].isNotEmpty
                      ? Image.network(
                          driver['profileImageUrl'],
                          width: isTablet ? 70 : 60,
                          height: isTablet ? 70 : 60,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.person,
                              size: isTablet ? 35 : 30,
                              color: isDarkMode
                                  ? AppColors.yellowAccent
                                  : AppTheme.lightPrimaryColor,
                            );
                          },
                        )
                      : Icon(
                          Icons.person,
                          size: isTablet ? 35 : 30,
                          color: isDarkMode
                              ? AppColors.yellowAccent
                              : AppTheme.lightPrimaryColor,
                        ),
                ),
              ),

              const SizedBox(width: 16),

              // Driver info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            driver['name'],
                            style: GoogleFonts.albertSans(
                              fontSize: isTablet ? 18 : 16,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode
                                  ? Colors.white
                                  : AppTheme.lightTextPrimaryColor,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(driver['status'])
                                .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            driver['status'],
                            style: GoogleFonts.albertSans(
                              fontSize: isTablet ? 12 : 10,
                              fontWeight: FontWeight.w600,
                              color: _getStatusColor(driver['status']),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${driver['vehicleType']} • ${driver['vehicleNumber']}',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 14 : 12,
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.7)
                            : AppTheme.lightTextSecondaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.star,
                          color: Colors.orange,
                          size: isTablet ? 16 : 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          driver['rating'].toStringAsFixed(1),
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 14 : 12,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode
                                ? Colors.white
                                : AppTheme.lightTextPrimaryColor,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.work_outline,
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.7)
                              : AppTheme.lightTextSecondaryColor,
                          size: isTablet ? 16 : 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${driver['totalJobs']} jobs',
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 12 : 10,
                            color: isDarkMode
                                ? Colors.white.withValues(alpha: 0.7)
                                : AppTheme.lightTextSecondaryColor,
                          ),
                        ),
                        const Spacer(),
                        if (driver['isOnline'] == true)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Documents status
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
              border: isDarkMode
                  ? null
                  : Border.all(
                      color: AppTheme.lightBorderColor,
                      width: 1,
                    ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Documents Status',
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 14 : 12,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode
                        ? Colors.white
                        : AppTheme.lightTextPrimaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildDocumentStatus(
                        'License',
                        driver['documents']['license'] ?? 'Pending',
                        Icons.credit_card,
                        isTablet,
                        isDarkMode,
                      ),
                    ),
                    Expanded(
                      child: _buildDocumentStatus(
                        'CNIC',
                        driver['documents']['cnic'] ?? 'Pending',
                        Icons.badge,
                        isTablet,
                        isDarkMode,
                      ),
                    ),
                    Expanded(
                      child: _buildDocumentStatus(
                        'Vehicle',
                        driver['documents']['vehicle'] ?? 'Pending',
                        Icons.directions_car,
                        isTablet,
                        isDarkMode,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Statistics
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Total Jobs',
                  '${driver['totalJobs']}',
                  Icons.work_outline,
                  isTablet,
                  isDarkMode,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Earnings',
                  'Rs. ${(driver['totalEarnings'] / 1000).toStringAsFixed(0)}K',
                  Icons.attach_money,
                  isTablet,
                  isDarkMode,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Last Active',
                  driver['lastActive'],
                  Icons.access_time,
                  isTablet,
                  isDarkMode,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Actions
          Row(
            children: [
              if (driver['status'] == 'Pending Approval') ...[
                Expanded(
                  child: _buildActionButton(
                    'Approve',
                    Icons.check,
                    Colors.green,
                    () => _approveDriver(driver),
                    isTablet,
                    isDarkMode,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton(
                    'Reject',
                    Icons.close,
                    Colors.red,
                    () => _rejectDriver(driver),
                    isTablet,
                    isDarkMode,
                  ),
                ),
              ] else if (driver['status'] == 'Active' ||
                  driver['status'] == 'approved' ||
                  driver['status'] == 'Approved') ...[
                Expanded(
                  child: _buildActionButton(
                    'Approved',
                    Icons.check_circle,
                    Colors.green,
                    () {}, // No action for approved button
                    isTablet,
                    isDarkMode,
                    isOutlined:
                        true, // Make it outlined to show it's already approved
                  ),
                ),
              ] else ...[
                Expanded(
                  child: _buildActionButton(
                    'View Details',
                    Icons.visibility,
                    isDarkMode
                        ? AppColors.yellowAccent
                        : AppTheme.lightPrimaryColor,
                    () => _viewDriverDetails(driver),
                    isTablet,
                    isDarkMode,
                  ),
                ),
              ],
              const SizedBox(width: 8),
              _buildActionButton(
                driver['status'] == 'Blocked' ? 'Unblock' : 'Block',
                driver['status'] == 'Blocked'
                    ? Icons.check_circle
                    : Icons.block,
                driver['status'] == 'Blocked' ? Colors.green : Colors.red,
                () => _toggleDriverStatus(driver),
                isTablet,
                isDarkMode,
                isCompact: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentStatus(String label, String status, IconData icon,
      bool isTablet, bool isDarkMode) {
    Color statusColor;
    IconData statusIcon;

    switch (status.toLowerCase()) {
      case 'verified':
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      default:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
    }

    return Column(
      children: [
        Icon(
          statusIcon,
          color: statusColor,
          size: isTablet ? 20 : 16,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.albertSans(
            fontSize: isTablet ? 10 : 8,
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.7)
                : AppTheme.lightTextSecondaryColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          status,
          style: GoogleFonts.albertSans(
            fontSize: isTablet ? 10 : 8,
            fontWeight: FontWeight.w600,
            color: statusColor,
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon,
      bool isTablet, bool isDarkMode) {
    return Column(
      children: [
        Icon(
          icon,
          size: isTablet ? 20 : 16,
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.7)
              : AppTheme.lightTextSecondaryColor,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.albertSans(
            fontSize: isTablet ? 10 : 8,
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.5)
                : AppTheme.lightTextLightColor,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.albertSans(
            fontSize: isTablet ? 12 : 10,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
    bool isTablet,
    bool isDarkMode, {
    bool isOutlined = false,
    bool isCompact = false,
  }) {
    return Container(
      height: isCompact ? (isTablet ? 44 : 44) : (isTablet ? 48 : 44),
      child: ElevatedButton.icon(
        onPressed: () {
          HapticFeedback.lightImpact();
          onPressed();
        },
        icon: Icon(
          icon,
          size: isTablet ? 16 : 14,
          color: isOutlined
              ? color
              : (color == AppColors.yellowAccent ? Colors.black : Colors.white),
        ),
        label: isCompact
            ? const SizedBox.shrink()
            : Text(
                label,
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 12 : 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: isOutlined
                      ? color
                      : (color == AppColors.yellowAccent
                          ? Colors.black
                          : Colors.white),
                ),
              ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isOutlined ? Colors.transparent : color,
          foregroundColor: isOutlined
              ? color
              : (color == AppColors.yellowAccent ? Colors.black : Colors.white),
          elevation: 0,
          shadowColor: Colors.transparent,
          side: BorderSide(
            color: color,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? (isTablet ? 8 : 6) : (isTablet ? 16 : 12),
            vertical: 0,
          ),
        ),
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isDarkMode ? 0.3 : 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: color.withValues(alpha: isDarkMode ? 0.1 : 0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'approved':
        return Colors.green;
      case 'blocked':
      case 'suspended':
        return Colors.red;
      case 'pending approval':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _refreshDrivers() async {
    await _loadDrivers();
  }

  void _viewDriverDetails(Map<String, dynamic> driver) {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isDarkMode = themeService.isDarkMode;
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: isTablet ? 600 : screenSize.width * 0.9,
          height: screenSize.height * 0.8,
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDarkMode
                  ? AppColors.yellowAccent.withValues(alpha: 0.3)
                  : AppTheme.lightPrimaryColor.withValues(alpha: 0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header with avatar and basic info
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? AppColors.yellowAccent.withValues(alpha: 0.1)
                      : AppTheme.lightPrimaryColor.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDarkMode
                              ? AppColors.yellowAccent
                              : AppTheme.lightPrimaryColor,
                          width: 3,
                        ),
                        color: isDarkMode
                            ? AppColors.yellowAccent.withValues(alpha: 0.2)
                            : AppTheme.lightPrimaryColor.withValues(alpha: 0.2),
                      ),
                      child: ClipOval(
                        child: driver['profileImageUrl'] != null &&
                                driver['profileImageUrl'].isNotEmpty
                            ? Image.network(
                                driver['profileImageUrl'],
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.person,
                                    size: 40,
                                    color: isDarkMode
                                        ? AppColors.yellowAccent
                                        : AppTheme.lightPrimaryColor,
                                  );
                                },
                              )
                            : Icon(
                                Icons.person,
                                size: 40,
                                color: isDarkMode
                                    ? AppColors.yellowAccent
                                    : AppTheme.lightPrimaryColor,
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Basic info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            driver['name'],
                            style: GoogleFonts.albertSans(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode
                                  ? Colors.white
                                  : AppTheme.lightTextPrimaryColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(driver['status'])
                                      .withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  driver['status'],
                                  style: GoogleFonts.albertSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _getStatusColor(driver['status']),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (driver['isOnline'] == true)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: Colors.green,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Online',
                                        style: GoogleFonts.albertSans(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.star,
                                color: Colors.orange,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                driver['rating'].toStringAsFixed(1),
                                style: GoogleFonts.albertSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode
                                      ? Colors.white
                                      : AppTheme.lightTextPrimaryColor,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Icon(
                                Icons.work_outline,
                                color: isDarkMode
                                    ? Colors.white.withValues(alpha: 0.7)
                                    : AppTheme.lightTextSecondaryColor,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${driver['totalJobs']} jobs',
                                style: GoogleFonts.albertSans(
                                  fontSize: 12,
                                  color: isDarkMode
                                      ? Colors.white.withValues(alpha: 0.7)
                                      : AppTheme.lightTextSecondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Close button
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
                          color: isDarkMode ? Colors.white : Colors.black,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Personal Information Section
                      _buildDetailSection(
                        'Personal Information',
                        [
                          _buildDetailRow(
                              'Full Name', driver['name'], isDarkMode),
                          _buildDetailRow('Email', driver['email'], isDarkMode),
                          _buildDetailRow('Phone', driver['phone'], isDarkMode),
                          _buildDetailRow('Emergency Contact',
                              driver['emergencyContact'], isDarkMode),
                          _buildDetailRow(
                              'Experience', driver['experience'], isDarkMode),
                        ],
                        isDarkMode,
                      ),

                      const SizedBox(height: 20),

                      // Address Information Section
                      _buildDetailSection(
                        'Address Information',
                        [
                          _buildDetailRow(
                              'City',
                              driver['address']?['city'] ?? 'Not provided',
                              isDarkMode),
                          _buildDetailRow(
                              'State',
                              driver['address']?['state'] ?? 'Not provided',
                              isDarkMode),
                          _buildDetailRow(
                              'Street',
                              driver['address']?['street'] ?? 'Not provided',
                              isDarkMode),
                          _buildDetailRow(
                              'Zip Code',
                              driver['address']?['zipcode'] ?? 'Not provided',
                              isDarkMode),
                        ],
                        isDarkMode,
                      ),

                      const SizedBox(height: 20),

                      // Vehicle Information Section
                      _buildDetailSection(
                        'Vehicle Information',
                        [
                          _buildDetailRow('Vehicle Type', driver['vehicleType'],
                              isDarkMode),
                          _buildDetailRow('Plate Number',
                              driver['vehicleNumber'], isDarkMode),
                          _buildDetailRow('License Number',
                              driver['licenseNumber'], isDarkMode),
                          _buildDetailRow(
                              'Commercial License',
                              driver['hasCommercialLicense'] == true
                                  ? 'Yes'
                                  : 'No',
                              isDarkMode),
                        ],
                        isDarkMode,
                      ),

                      const SizedBox(height: 20),

                      // Documents Status Section
                      _buildDetailSection(
                        'Documents Status',
                        [
                          _buildDocumentStatusRow(
                              'License',
                              driver['documents']['license'] ?? 'Pending',
                              isDarkMode),
                          _buildDocumentStatusRow(
                              'CNIC',
                              driver['documents']['cnic'] ?? 'Pending',
                              isDarkMode),
                          _buildDocumentStatusRow(
                              'Vehicle Registration',
                              driver['documents']['vehicle'] ?? 'Pending',
                              isDarkMode),
                        ],
                        isDarkMode,
                      ),

                      const SizedBox(height: 20),

                      // Document Images Section
                      _buildDetailSection(
                        'Document Images',
                        [
                          _buildDocumentImageRow('CNIC Front',
                              driver['documents']?['cnicFront'], isDarkMode),
                          _buildDocumentImageRow('CNIC Back',
                              driver['documents']?['cnicBack'], isDarkMode),
                          _buildDocumentImageRow('Vehicle Registration',
                              driver['documents']?['carBack'], isDarkMode),
                          _buildDocumentImageRow('Vehicle Front',
                              driver['documents']?['carFront'], isDarkMode),
                          _buildDocumentImageRow('Vehicle Side',
                              driver['documents']?['carSide'], isDarkMode),
                        ],
                        isDarkMode,
                      ),

                      const SizedBox(height: 20),

                      // Statistics Section
                      _buildDetailSection(
                        'Statistics & Performance',
                        [
                          _buildDetailRow('Total Jobs Completed',
                              driver['totalJobs'].toString(), isDarkMode),
                          _buildDetailRow(
                              'Total Earnings',
                              'Rs. ${driver['totalEarnings'].toStringAsFixed(2)}',
                              isDarkMode),
                          _buildDetailRow('Average Rating',
                              driver['rating'].toStringAsFixed(1), isDarkMode),
                          _buildDetailRow('Registration Date',
                              driver['registrationDate'], isDarkMode),
                          _buildDetailRow(
                              'Last Active', driver['lastActive'], isDarkMode),
                          _buildDetailRow('Profile Updated',
                              driver['updatedAt'], isDarkMode),
                        ],
                        isDarkMode,
                      ),

                      const SizedBox(height: 20),

                      // Settings Section
                      _buildDetailSection(
                        'App Settings',
                        [
                          _buildDetailRow(
                              'Notifications',
                              driver['notifications'] == true
                                  ? 'Enabled'
                                  : 'Disabled',
                              isDarkMode),
                          _buildDetailRow(
                              'Auto Accept Orders',
                              driver['autoAccept'] == true
                                  ? 'Enabled'
                                  : 'Disabled',
                              isDarkMode),
                          _buildDetailRow(
                              'Location Sharing',
                              driver['locationSharing'] == true
                                  ? 'Enabled'
                                  : 'Disabled',
                              isDarkMode),
                        ],
                        isDarkMode,
                      ),
                    ],
                  ),
                ),
              ),

              // Action buttons
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    // Always show Approve and Reject buttons
                    Expanded(
                      child: Container(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _approveDriverFromPopup(driver);
                          },
                          icon: const Icon(Icons.check, size: 18),
                          label: Text(
                            'Approve',
                            style: GoogleFonts.albertSans(
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                            BoxShadow(
                              color: Colors.green.withValues(alpha: 0.15),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _rejectDriverFromPopup(driver);
                          },
                          icon: const Icon(Icons.close, size: 18),
                          label: Text(
                            'Reject',
                            style: GoogleFonts.albertSans(
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                            BoxShadow(
                              color: Colors.red.withValues(alpha: 0.15),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
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

  Widget _buildDetailSection(
      String title, List<Widget> children, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.albertSans(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDarkMode
                  ? AppColors.yellowAccent
                  : AppTheme.lightPrimaryColor,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDocumentImageRow(
      String label, String? imageUrl, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.albertSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.8)
                  : AppTheme.lightTextSecondaryColor,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              if (imageUrl != null && imageUrl.isNotEmpty) {
                _showImageDialog(imageUrl, label, isDarkMode);
              }
            },
            child: Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.grey.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: progress.expectedTotalBytes != null
                                  ? progress.cumulativeBytesLoaded /
                                      progress.expectedTotalBytes!
                                  : null,
                              color: isDarkMode
                                  ? AppColors.yellowAccent
                                  : AppTheme.lightPrimaryColor,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.broken_image,
                                  size: 40,
                                  color: isDarkMode
                                      ? Colors.white.withValues(alpha: 0.5)
                                      : Colors.grey,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Failed to load image',
                                  style: GoogleFonts.albertSans(
                                    fontSize: 12,
                                    color: isDarkMode
                                        ? Colors.white.withValues(alpha: 0.5)
                                        : Colors.grey,
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
                            Icons.image_not_supported,
                            size: 40,
                            color: isDarkMode
                                ? Colors.white.withValues(alpha: 0.3)
                                : Colors.grey,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No image available',
                            style: GoogleFonts.albertSans(
                              fontSize: 12,
                              color: isDarkMode
                                  ? Colors.white.withValues(alpha: 0.5)
                                  : Colors.grey,
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

  void _showImageDialog(String imageUrl, String title, bool isDarkMode) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
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
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.albertSans(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode
                              ? Colors.white
                              : AppTheme.lightTextPrimaryColor,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Icon(
                        Icons.close,
                        color: isDarkMode
                            ? Colors.white
                            : AppTheme.lightTextPrimaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              // Image
              Flexible(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 200,
                          child: Center(
                            child: Text(
                              'Failed to load image',
                              style: GoogleFonts.albertSans(
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentStatusRow(String label, String status, bool isDarkMode) {
    Color statusColor;
    IconData statusIcon;
    switch (status.toLowerCase()) {
      case 'verified':
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: GoogleFonts.albertSans(
                fontWeight: FontWeight.w600,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.8)
                    : AppTheme.lightTextSecondaryColor,
              ),
            ),
          ),
          Icon(
            statusIcon,
            color: statusColor,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            status,
            style: GoogleFonts.albertSans(
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _approveDriverFromPopup(Map<String, dynamic> driver) async {
    try {
      await _firestore.collection('drivers').doc(driver['id']).update({
        'applicationStatus': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': _auth.currentUser?.uid,
        'documents.license': 'Approved',
        'documents.cnic': 'Approved',
        'documents.vehicle': 'Approved',
      });

      setState(() {
        driver['status'] = 'approved';
        // Update documents status in local data
        driver['documents']['license'] = 'Approved';
        driver['documents']['cnic'] = 'Approved';
        driver['documents']['vehicle'] = 'Approved';

        // Update the driver in both lists
        final index = _allDrivers.indexWhere((d) => d['id'] == driver['id']);
        if (index != -1) {
          _allDrivers[index]['status'] = 'approved';
          _allDrivers[index]['documents']['license'] = 'Approved';
          _allDrivers[index]['documents']['cnic'] = 'Approved';
          _allDrivers[index]['documents']['vehicle'] = 'Approved';
        }
      });
      _filterDrivers();

      _showGlowingSnackBar(
        'Driver approved successfully',
        Colors.green,
      );
    } catch (e) {
      _showGlowingSnackBar(
        'Error approving driver: $e',
        Colors.red,
      );
    }
  }

  Future<void> _rejectDriverFromPopup(Map<String, dynamic> driver) async {
    try {
      await _firestore.collection('drivers').doc(driver['id']).update({
        'applicationStatus': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': _auth.currentUser?.uid,
      });

      setState(() {
        driver['status'] = 'rejected';
        // Update the driver in both lists
        final index = _allDrivers.indexWhere((d) => d['id'] == driver['id']);
        if (index != -1) {
          _allDrivers[index]['status'] = 'rejected';
        }
      });
      _filterDrivers();

      _showGlowingSnackBar(
        'Driver rejected successfully',
        Colors.orange,
      );
    } catch (e) {
      _showGlowingSnackBar(
        'Error rejecting driver: $e',
        Colors.red,
      );
    }
  }

  Widget _buildDetailRow(String label, String value, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: GoogleFonts.albertSans(
                fontWeight: FontWeight.w600,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.8)
                    : AppTheme.lightTextSecondaryColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.albertSans(
                color:
                    isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _approveDriver(Map<String, dynamic> driver) async {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isDarkMode = themeService.isDarkMode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Approve Driver',
          style: GoogleFonts.albertSans(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
          ),
        ),
        content: Text(
          'Are you sure you want to approve ${driver['name']}?',
          style: GoogleFonts.albertSans(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.8)
                : AppTheme.lightTextSecondaryColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.albertSans(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.7)
                    : AppTheme.lightTextSecondaryColor,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              try {
                await _firestore
                    .collection('drivers')
                    .doc(driver['id'])
                    .update({
                  'applicationStatus': 'Active',
                  'approvedAt': FieldValue.serverTimestamp(),
                  'approvedBy': _auth.currentUser?.uid,
                  'documents.license': 'Approved',
                  'documents.cnic': 'Approved',
                  'documents.vehicle': 'Approved',
                });

                setState(() {
                  driver['status'] = 'Active';
                  // Update documents status in local data
                  driver['documents']['license'] = 'Approved';
                  driver['documents']['cnic'] = 'Approved';
                  driver['documents']['vehicle'] = 'Approved';

                  // Update the driver in both lists
                  final index =
                      _allDrivers.indexWhere((d) => d['id'] == driver['id']);
                  if (index != -1) {
                    _allDrivers[index]['status'] = 'Active';
                    _allDrivers[index]['documents']['license'] = 'Approved';
                    _allDrivers[index]['documents']['cnic'] = 'Approved';
                    _allDrivers[index]['documents']['vehicle'] = 'Approved';
                  }
                });
                _filterDrivers();

                _showGlowingSnackBar(
                  'Driver approved successfully',
                  AppColors.success,
                );
              } catch (e) {
                _showGlowingSnackBar(
                  'Error approving driver: $e',
                  AppColors.error,
                );
              }
            },
            child: Text(
              'Approve',
              style: GoogleFonts.albertSans(
                color: Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _rejectDriver(Map<String, dynamic> driver) async {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isDarkMode = themeService.isDarkMode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Reject Driver',
          style: GoogleFonts.albertSans(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
          ),
        ),
        content: Text(
          'Are you sure you want to reject ${driver['name']}?',
          style: GoogleFonts.albertSans(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.8)
                : AppTheme.lightTextSecondaryColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.albertSans(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.7)
                    : AppTheme.lightTextSecondaryColor,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              try {
                await _firestore
                    .collection('drivers')
                    .doc(driver['id'])
                    .update({
                  'applicationStatus': 'Rejected',
                  'rejectedAt': FieldValue.serverTimestamp(),
                  'rejectedBy': _auth.currentUser?.uid,
                });

                setState(() {
                  driver['status'] = 'Rejected';
                });
                _filterDrivers();

                _showGlowingSnackBar(
                  'Driver rejected successfully',
                  AppColors.success,
                );
              } catch (e) {
                _showGlowingSnackBar(
                  'Error rejecting driver: $e',
                  AppColors.error,
                );
              }
            },
            child: Text(
              'Reject',
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

  Future<void> _toggleDriverStatus(Map<String, dynamic> driver) async {
    final newStatus = driver['status'] == 'Blocked' ? 'Active' : 'Blocked';
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isDarkMode = themeService.isDarkMode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '${newStatus == 'Blocked' ? 'Block' : 'Unblock'} Driver',
          style: GoogleFonts.albertSans(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
          ),
        ),
        content: Text(
          'Are you sure you want to ${newStatus == 'Blocked' ? 'block' : 'unblock'} ${driver['name']}?',
          style: GoogleFonts.albertSans(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.8)
                : AppTheme.lightTextSecondaryColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.albertSans(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.7)
                    : AppTheme.lightTextSecondaryColor,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              try {
                await _firestore
                    .collection('drivers')
                    .doc(driver['id'])
                    .update({
                  'applicationStatus': newStatus,
                  'statusUpdatedAt': FieldValue.serverTimestamp(),
                  'statusUpdatedBy': _auth.currentUser?.uid,
                });

                setState(() {
                  driver['status'] = newStatus;
                });
                _filterDrivers();

                _showGlowingSnackBar(
                  'Driver ${newStatus == 'Blocked' ? 'blocked' : 'unblocked'} successfully',
                  AppColors.success,
                );
              } catch (e) {
                _showGlowingSnackBar(
                  'Error updating driver status: $e',
                  AppColors.error,
                );
              }
            },
            child: Text(
              newStatus == 'Blocked' ? 'Block' : 'Unblock',
              style: GoogleFonts.albertSans(
                color: newStatus == 'Blocked' ? Colors.red : Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _bulkApprove() {
    if (_selectedDrivers.isEmpty) return;

    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isDarkMode = themeService.isDarkMode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Approve Drivers',
          style: GoogleFonts.albertSans(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
          ),
        ),
        content: Text(
          'Are you sure you want to approve ${_selectedDrivers.length} selected drivers?',
          style: GoogleFonts.albertSans(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.8)
                : AppTheme.lightTextSecondaryColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.albertSans(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.7)
                    : AppTheme.lightTextSecondaryColor,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              try {
                final batch = _firestore.batch();
                for (final driverId in _selectedDrivers) {
                  final driverRef =
                      _firestore.collection('drivers').doc(driverId);
                  batch.update(driverRef, {
                    'applicationStatus': 'Active',
                    'approvedAt': FieldValue.serverTimestamp(),
                    'approvedBy': _auth.currentUser?.uid,
                    'documents.license': 'Approved',
                    'documents.cnic': 'Approved',
                    'documents.vehicle': 'Approved',
                  });
                }
                await batch.commit();

                setState(() {
                  for (final driver in _allDrivers) {
                    if (_selectedDrivers.contains(driver['id'])) {
                      driver['status'] = 'Active';
                      // Update documents status in local data
                      driver['documents']['license'] = 'Approved';
                      driver['documents']['cnic'] = 'Approved';
                      driver['documents']['vehicle'] = 'Approved';
                    }
                  }
                  _selectedDrivers.clear();
                });
                _filterDrivers();

                _showGlowingSnackBar(
                  'Drivers approved successfully',
                  AppColors.success,
                );
              } catch (e) {
                _showGlowingSnackBar(
                  'Error approving drivers: $e',
                  AppColors.error,
                );
              }
            },
            child: Text(
              'Approve',
              style: GoogleFonts.albertSans(
                color: Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _bulkBlock() {
    if (_selectedDrivers.isEmpty) return;

    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isDarkMode = themeService.isDarkMode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Block Drivers',
          style: GoogleFonts.albertSans(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
          ),
        ),
        content: Text(
          'Are you sure you want to block ${_selectedDrivers.length} selected drivers?',
          style: GoogleFonts.albertSans(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.8)
                : AppTheme.lightTextSecondaryColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.albertSans(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.7)
                    : AppTheme.lightTextSecondaryColor,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              try {
                final batch = _firestore.batch();
                for (final driverId in _selectedDrivers) {
                  final driverRef =
                      _firestore.collection('drivers').doc(driverId);
                  batch.update(driverRef, {
                    'applicationStatus': 'Blocked',
                    'blockedAt': FieldValue.serverTimestamp(),
                    'blockedBy': _auth.currentUser?.uid,
                  });
                }
                await batch.commit();

                setState(() {
                  for (final driver in _allDrivers) {
                    if (_selectedDrivers.contains(driver['id'])) {
                      driver['status'] = 'Blocked';
                    }
                  }
                  _selectedDrivers.clear();
                });
                _filterDrivers();

                _showGlowingSnackBar(
                  'Drivers blocked successfully',
                  AppColors.success,
                );
              } catch (e) {
                _showGlowingSnackBar(
                  'Error blocking drivers: $e',
                  AppColors.error,
                );
              }
            },
            child: Text(
              'Block',
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

  void _bulkDelete() {
    if (_selectedDrivers.isEmpty) return;

    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isDarkMode = themeService.isDarkMode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Drivers',
          style: GoogleFonts.albertSans(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
          ),
        ),
        content: Text(
          'Are you sure you want to delete ${_selectedDrivers.length} selected drivers? This action cannot be undone.',
          style: GoogleFonts.albertSans(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.8)
                : AppTheme.lightTextSecondaryColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.albertSans(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.7)
                    : AppTheme.lightTextSecondaryColor,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              try {
                final batch = _firestore.batch();
                for (final driverId in _selectedDrivers) {
                  final driverRef =
                      _firestore.collection('drivers').doc(driverId);
                  batch.delete(driverRef);
                }
                await batch.commit();

                setState(() {
                  _allDrivers.removeWhere(
                      (driver) => _selectedDrivers.contains(driver['id']));
                  _selectedDrivers.clear();
                });
                _filterDrivers();

                _showGlowingSnackBar(
                  'Drivers deleted successfully',
                  AppColors.success,
                );
              } catch (e) {
                _showGlowingSnackBar(
                  'Error deleting drivers: $e',
                  AppColors.error,
                );
              }
            },
            child: Text(
              'Delete',
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
}
