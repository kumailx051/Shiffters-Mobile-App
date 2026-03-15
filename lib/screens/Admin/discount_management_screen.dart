import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shiffters/theme/app_colors.dart';
import 'package:shiffters/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shiffters/services/theme_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class DiscountManagementScreen extends StatefulWidget {
  const DiscountManagementScreen({super.key});

  @override
  State<DiscountManagementScreen> createState() =>
      _DiscountManagementScreenState();
}

class _DiscountManagementScreenState extends State<DiscountManagementScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _allDiscounts = [];
  List<Map<String, dynamic>> _filteredDiscounts = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';

  final List<String> _filterOptions = [
    'All',
    'Active',
    'Expired',
    'Percentage',
    'Fixed'
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
    _fetchDiscounts();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
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
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      _animationController.forward();
    }
  }

  // Safe method to get data from Firestore document
  T? _safeGet<T>(Map<String, dynamic> data, String key, [T? defaultValue]) {
    try {
      if (data.containsKey(key) && data[key] != null) {
        return data[key] as T;
      }
      return defaultValue;
    } catch (e) {
      debugPrint('Error getting $key: $e');
      return defaultValue;
    }
  }

  // Fetch discounts from Firestore
  Future<void> _fetchDiscounts() async {
    try {
      setState(() {
        _isLoading = true;
      });

      QuerySnapshot querySnapshot = await _firestore
          .collection('discounts')
          .orderBy('createdAt', descending: true)
          .get();

      List<Map<String, dynamic>> discounts = [];
      for (var doc in querySnapshot.docs) {
        try {
          Map<String, dynamic> discountData =
              doc.data() as Map<String, dynamic>;
          discountData['id'] = doc.id;

          // Check if discount is expired
          bool isExpired = false;
          if (discountData.containsKey('expiryDate')) {
            final expiryDate =
                (discountData['expiryDate'] as Timestamp?)?.toDate();
            if (expiryDate != null) {
              isExpired = expiryDate.isBefore(DateTime.now());
            }
          }
          discountData['isExpired'] = isExpired;

          discounts.add(discountData);
        } catch (e) {
          debugPrint('Error processing document ${doc.id}: $e');
          continue;
        }
      }

      if (mounted) {
        setState(() {
          _allDiscounts = discounts;
          _filteredDiscounts = List.from(_allDiscounts);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching discounts: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _filterDiscounts() {
    setState(() {
      _filteredDiscounts = _allDiscounts.where((discount) {
        // Filter by status (active/expired)
        if (_selectedFilter == 'Active' && discount['isExpired'] == true) {
          return false;
        }
        if (_selectedFilter == 'Expired' && discount['isExpired'] == false) {
          return false;
        }

        // Filter by type (percentage/fixed)
        if (_selectedFilter == 'Percentage' &&
            discount['discountType'] != 'percentage') {
          return false;
        }
        if (_selectedFilter == 'Fixed' && discount['discountType'] != 'fixed') {
          return false;
        }

        // Search by code or description
        final matchesSearch = _searchController.text.isEmpty ||
            (_safeGet<String>(discount, 'code', '') ?? '')
                .toLowerCase()
                .contains(_searchController.text.toLowerCase()) ||
            (_safeGet<String>(discount, 'description', '') ?? '')
                .toLowerCase()
                .contains(_searchController.text.toLowerCase());

        return matchesSearch;
      }).toList();
    });
  }

  // Format date from Firestore timestamp
  String _formatDate(dynamic timestamp) {
    try {
      if (timestamp is Timestamp) {
        final date = timestamp.toDate();
        return DateFormat('MMM d, yyyy').format(date);
      }
      return 'Date not available';
    } catch (e) {
      return 'Date not available';
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
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
          backgroundColor: isDarkMode ? const Color(0xFF1E1E2C) : Colors.white,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              HapticFeedback.lightImpact();
              _showAddDiscountDialog(context, isDarkMode);
            },
            backgroundColor: isDarkMode
                ? AppColors.yellowAccent
                : AppTheme.lightPrimaryColor,
            foregroundColor: isDarkMode ? Colors.black : Colors.white,
            icon: const Icon(Icons.add),
            label: Text(
              'New Discount',
              style: GoogleFonts.albertSans(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          body: Column(
            children: [
              // Header
              _buildHeader(isTablet, isDarkMode),

              // Search and filters
              _buildSearchAndFilters(isTablet, isDarkMode),

              // Content
              Expanded(
                child: SafeArea(
                  top: false,
                  child: _isLoading
                      ? _buildLoadingIndicator(isDarkMode)
                      : _buildDiscountsList(isTablet, isDarkMode),
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
              Row(
                children: [
                  // Back button
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios,
                        size: isTablet ? 24 : 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Title
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Discount Management',
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 28 : 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${_filteredDiscounts.length} discount codes',
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
              // Refresh button
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _fetchDiscounts();
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.refresh,
                    size: isTablet ? 24 : 20,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters(bool isTablet, bool isDarkMode) {
    return SlideTransition(
      position: _slideAnimation,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 32 : 20,
        ),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Search bar
            Container(
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16),
                border: isDarkMode
                    ? Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 1,
                      )
                    : null,
                boxShadow: isDarkMode
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.grey.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => _filterDiscounts(),
                style: GoogleFonts.albertSans(
                  color: isDarkMode ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Search discount codes...',
                  hintStyle: GoogleFonts.albertSans(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.5)
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.5)
                        : AppColors.textSecondary,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Filter tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: _filterOptions.map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _selectedFilter = filter;
                      });
                      _filterDiscounts();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDarkMode
                                ? AppColors.yellowAccent
                                : AppColors.lightPrimary)
                            : (isDarkMode
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.white),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? (isDarkMode
                                  ? AppColors.yellowAccent
                                  : AppColors.lightPrimary)
                              : (isDarkMode
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.grey.withValues(alpha: 0.3)),
                          width: 1,
                        ),
                        boxShadow: isSelected && !isDarkMode
                            ? [
                                BoxShadow(
                                  color: AppColors.lightPrimary
                                      .withValues(alpha: 0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        filter,
                        style: GoogleFonts.albertSans(
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected
                              ? (isDarkMode ? Colors.black : Colors.white)
                              : (isDarkMode
                                  ? Colors.white
                                  : AppColors.textSecondary),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: isDarkMode ? AppColors.yellowAccent : AppColors.lightPrimary,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading discounts...',
            style: GoogleFonts.albertSans(
              fontSize: 16,
              color: isDarkMode ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountsList(bool isTablet, bool isDarkMode) {
    if (_filteredDiscounts.isEmpty) {
      return _buildEmptyState(isDarkMode);
    }

    return SlideTransition(
      position: _slideAnimation,
      child: RefreshIndicator(
        onRefresh: _fetchDiscounts,
        color: isDarkMode ? AppColors.yellowAccent : AppColors.lightPrimary,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 32 : 20,
            vertical: isTablet ? 16 : 12,
          ),
          itemCount: _filteredDiscounts.length,
          itemBuilder: (context, index) {
            final discount = _filteredDiscounts[index];
            return _buildDiscountCard(discount, isTablet, isDarkMode);
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
            Icons.local_offer_outlined,
            size: 80,
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.3)
                : Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No discount codes found',
            style: GoogleFonts.albertSans(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.7)
                  : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first discount code by tapping the button below',
            style: GoogleFonts.albertSans(
              fontSize: 14,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.5)
                  : Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountCard(
      Map<String, dynamic> discount, bool isTablet, bool isDarkMode) {
    // Safely extract data
    final String code = _safeGet<String>(discount, 'code', 'N/A') ?? 'N/A';
    final String description =
        _safeGet<String>(discount, 'description', 'No description') ??
            'No description';
    final String discountType =
        _safeGet<String>(discount, 'discountType', 'percentage') ??
            'percentage';
    final dynamic discountValue = discount['discountValue'];
    final bool isExpired = discount['isExpired'] ?? false;

    String discountText;
    if (discountType == 'percentage') {
      discountText = '${discountValue.toString()}% off';
    } else {
      discountText = 'Rs. ${discountValue.toString()} off';
    }

    final dynamic createdAt = discount['createdAt'];
    final dynamic expiryDate = discount['expiryDate'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpired
              ? Colors.grey.withValues(alpha: 0.3)
              : (isDarkMode
                  ? AppColors.yellowAccent.withValues(alpha: 0.5)
                  : AppColors.lightPrimary.withValues(alpha: 0.5)),
          width: 1.5,
        ),
        boxShadow: isDarkMode
            ? null
            : [
                BoxShadow(
                  color: isExpired
                      ? Colors.grey.withValues(alpha: 0.1)
                      : AppColors.lightPrimary.withValues(alpha: 0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              // Code and status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isExpired
                                ? Colors.grey.withValues(alpha: 0.2)
                                : (discountType == 'percentage'
                                    ? (isDarkMode
                                        ? const Color(0xFFF59E0B)
                                            .withValues(alpha: 0.2)
                                        : const Color(0xFFF59E0B)
                                            .withValues(alpha: 0.1))
                                    : (isDarkMode
                                        ? const Color(0xFF10B981)
                                            .withValues(alpha: 0.2)
                                        : const Color(0xFF10B981)
                                            .withValues(alpha: 0.1))),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            code.toUpperCase(),
                            style: GoogleFonts.robotoMono(
                              fontSize: isTablet ? 16 : 14,
                              fontWeight: FontWeight.w600,
                              color: isExpired
                                  ? Colors.grey
                                  : (discountType == 'percentage'
                                      ? const Color(0xFFF59E0B)
                                      : const Color(0xFF10B981)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isExpired
                                ? const Color(0xFFEF4444).withValues(alpha: 0.1)
                                : const Color(0xFF10B981)
                                    .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isExpired ? 'Expired' : 'Active',
                            style: GoogleFonts.albertSans(
                              fontSize: isTablet ? 12 : 10,
                              fontWeight: FontWeight.w500,
                              color: isExpired
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 14 : 12,
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.8)
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Discount value
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isExpired
                      ? Colors.grey.withValues(alpha: 0.1)
                      : (isDarkMode
                          ? AppColors.yellowAccent.withValues(alpha: 0.1)
                          : AppColors.lightPrimary.withValues(alpha: 0.1)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  discountText,
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.bold,
                    color: isExpired
                        ? Colors.grey
                        : (isDarkMode
                            ? AppColors.yellowAccent
                            : AppColors.lightPrimary),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Dates info
          Container(
            padding: EdgeInsets.all(isTablet ? 16 : 12),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                // Created date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Created',
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 12 : 10,
                          fontWeight: FontWeight.w500,
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.7)
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(createdAt),
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 14 : 12,
                          fontWeight: FontWeight.w600,
                          color:
                              isDarkMode ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Expiry date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Expires',
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 12 : 10,
                          fontWeight: FontWeight.w500,
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.7)
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        expiryDate != null ? _formatDate(expiryDate) : 'Never',
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 14 : 12,
                          fontWeight: FontWeight.w600,
                          color: isExpired
                              ? const Color(0xFFEF4444)
                              : (isDarkMode
                                  ? Colors.white
                                  : AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Actions
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () {
                    // Copy discount code to clipboard
                    HapticFeedback.lightImpact();
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Discount code copied to clipboard'),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                        backgroundColor: isDarkMode
                            ? AppColors.yellowAccent
                            : AppColors.lightPrimary,
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: Text('Copy Code'),
                  style: TextButton.styleFrom(
                    foregroundColor: isDarkMode
                        ? AppColors.yellowAccent
                        : AppColors.lightPrimary,
                  ),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _showDeleteConfirmDialog(context, discount, isDarkMode);
                  },
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: Text('Delete'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddDiscountDialog(BuildContext context, bool isDarkMode) {
    final TextEditingController codeController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    final TextEditingController valueController = TextEditingController();
    DateTime? expiryDate;
    String discountType = 'percentage';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor:
                  isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Create New Discount',
                style: GoogleFonts.albertSans(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode
                      ? Colors.white
                      : AppTheme.lightTextPrimaryColor,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Discount Code
                    Text(
                      'Discount Code',
                      style: GoogleFonts.albertSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode
                            ? Colors.white
                            : AppTheme.lightTextPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: codeController,
                      style: GoogleFonts.albertSans(
                        color: isDarkMode
                            ? Colors.white
                            : AppTheme.lightTextPrimaryColor,
                      ),
                      decoration: InputDecoration(
                        hintText: 'e.g. SUMMER20',
                        hintStyle: GoogleFonts.albertSans(
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.5)
                              : Colors.grey,
                        ),
                        filled: true,
                        fillColor: isDarkMode
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[A-Za-z0-9]')),
                        UpperCaseTextFormatter(),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Description
                    Text(
                      'Description',
                      style: GoogleFonts.albertSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode
                            ? Colors.white
                            : AppTheme.lightTextPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descriptionController,
                      style: GoogleFonts.albertSans(
                        color: isDarkMode
                            ? Colors.white
                            : AppTheme.lightTextPrimaryColor,
                      ),
                      decoration: InputDecoration(
                        hintText: 'e.g. Summer Sale Discount',
                        hintStyle: GoogleFonts.albertSans(
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.5)
                              : Colors.grey,
                        ),
                        filled: true,
                        fillColor: isDarkMode
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Discount Type
                    Text(
                      'Discount Type',
                      style: GoogleFonts.albertSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode
                            ? Colors.white
                            : AppTheme.lightTextPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                discountType = 'percentage';
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 8,
                              ),
                              decoration: BoxDecoration(
                                color: discountType == 'percentage'
                                    ? (isDarkMode
                                        ? AppColors.yellowAccent
                                        : AppTheme.lightPrimaryColor)
                                    : (isDarkMode
                                        ? Colors.white.withValues(alpha: 0.1)
                                        : Colors.grey.shade100),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Percentage',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.albertSans(
                                  fontWeight: FontWeight.w600,
                                  color: discountType == 'percentage'
                                      ? (isDarkMode
                                          ? Colors.black
                                          : Colors.white)
                                      : (isDarkMode
                                          ? Colors.white
                                          : AppTheme.lightTextPrimaryColor),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                discountType = 'fixed';
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 8,
                              ),
                              decoration: BoxDecoration(
                                color: discountType == 'fixed'
                                    ? (isDarkMode
                                        ? AppColors.yellowAccent
                                        : AppTheme.lightPrimaryColor)
                                    : (isDarkMode
                                        ? Colors.white.withValues(alpha: 0.1)
                                        : Colors.grey.shade100),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Fixed Amount',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.albertSans(
                                  fontWeight: FontWeight.w600,
                                  color: discountType == 'fixed'
                                      ? (isDarkMode
                                          ? Colors.black
                                          : Colors.white)
                                      : (isDarkMode
                                          ? Colors.white
                                          : AppTheme.lightTextPrimaryColor),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Discount Value
                    Text(
                      discountType == 'percentage'
                          ? 'Discount Percentage'
                          : 'Discount Amount (Rs.)',
                      style: GoogleFonts.albertSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode
                            ? Colors.white
                            : AppTheme.lightTextPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: valueController,
                      style: GoogleFonts.albertSans(
                        color: isDarkMode
                            ? Colors.white
                            : AppTheme.lightTextPrimaryColor,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        hintText: discountType == 'percentage'
                            ? 'e.g. 20'
                            : 'e.g. 100',
                        hintStyle: GoogleFonts.albertSans(
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.5)
                              : Colors.grey,
                        ),
                        filled: true,
                        fillColor: isDarkMode
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Expiry Date
                    Text(
                      'Expiry Date (Optional)',
                      style: GoogleFonts.albertSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode
                            ? Colors.white
                            : AppTheme.lightTextPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate:
                              DateTime.now().add(const Duration(days: 30)),
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365 * 2)),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: isDarkMode
                                      ? AppColors.yellowAccent
                                      : AppTheme.lightPrimaryColor,
                                  onPrimary:
                                      isDarkMode ? Colors.black : Colors.white,
                                  surface: isDarkMode
                                      ? const Color(0xFF2D2D3C)
                                      : Colors.white,
                                  onSurface: isDarkMode
                                      ? Colors.white
                                      : AppTheme.lightTextPrimaryColor,
                                ),
                                dialogBackgroundColor: isDarkMode
                                    ? const Color(0xFF2D2D3C)
                                    : Colors.white,
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setState(() {
                            expiryDate = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              expiryDate != null
                                  ? DateFormat('MMM d, yyyy')
                                      .format(expiryDate!)
                                  : 'Select date (or leave empty for no expiry)',
                              style: GoogleFonts.albertSans(
                                color: expiryDate != null
                                    ? (isDarkMode
                                        ? Colors.white
                                        : AppTheme.lightTextPrimaryColor)
                                    : (isDarkMode
                                        ? Colors.white.withValues(alpha: 0.5)
                                        : Colors.grey),
                              ),
                            ),
                            Icon(
                              Icons.calendar_today,
                              size: 18,
                              color: isDarkMode
                                  ? Colors.white.withValues(alpha: 0.5)
                                  : Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.albertSans(
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.7)
                          : Colors.grey.shade700,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (codeController.text.isEmpty ||
                        valueController.text.isEmpty) {
                      // Show error for missing required fields
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Code and value are required'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    // Create and save the discount
                    _createDiscount(
                      code: codeController.text,
                      description: descriptionController.text.isEmpty
                          ? 'Discount code ${codeController.text}'
                          : descriptionController.text,
                      discountType: discountType,
                      discountValue: int.parse(valueController.text),
                      expiryDate: expiryDate,
                    );

                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDarkMode
                        ? AppColors.yellowAccent
                        : AppTheme.lightPrimaryColor,
                    foregroundColor: isDarkMode ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  child: Text(
                    'Create Discount',
                    style: GoogleFonts.albertSans(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      codeController.dispose();
      descriptionController.dispose();
      valueController.dispose();
    });
  }

  Future<void> _createDiscount({
    required String code,
    required String description,
    required String discountType,
    required int discountValue,
    DateTime? expiryDate,
  }) async {
    try {
      // Validate discount value for percentage
      if (discountType == 'percentage' &&
          (discountValue <= 0 || discountValue > 100)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Percentage discount must be between 1 and 100'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Check if code already exists
      final existingDiscount = await _firestore
          .collection('discounts')
          .where('code', isEqualTo: code)
          .get();

      if (existingDiscount.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Discount code already exists'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Create a unique ID for the discount
      final uuid = const Uuid();
      final discountId = uuid.v4();

      // Create the discount object
      final discountData = {
        'code': code,
        'description': description,
        'discountType': discountType,
        'discountValue': discountValue,
        'createdAt': Timestamp.now(),
        'expiryDate':
            expiryDate != null ? Timestamp.fromDate(expiryDate) : null,
        'isActive': true,
      };

      // Save to Firestore
      await _firestore
          .collection('discounts')
          .doc(discountId)
          .set(discountData);

      // Create announcement about the new discount code
      String discountValueText = discountType == 'percentage'
          ? '$discountValue% off'
          : 'Rs. $discountValue off';

      String expiryText = expiryDate != null
          ? ' valid until ${DateFormat('MMM d, yyyy').format(expiryDate)}'
          : '';

      await _firestore.collection('announcements').add({
        'title': 'New Discount Code: ${code.toUpperCase()}',
        'message':
            'Use code ${code.toUpperCase()} for $discountValueText on your next order$expiryText. $description',
        'type': 'announcement',
        'category': 'Promotion',
        'for': 'All Users',
        'status': 'active',
        'priority': 'medium',
        'createdAt': Timestamp.now(),
        'adminId': FirebaseAuth.instance.currentUser?.uid ?? 'admin'
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Discount code created and announced to all users'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Refresh the list
      _fetchDiscounts();
    } catch (e) {
      debugPrint('Error creating discount: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating discount: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDeleteConfirmDialog(
      BuildContext context, Map<String, dynamic> discount, bool isDarkMode) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Delete Discount',
            style: GoogleFonts.albertSans(
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
            ),
          ),
          content: Text(
            'Are you sure you want to delete the discount code "${discount['code']}"? This action cannot be undone.',
            style: GoogleFonts.albertSans(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.8)
                  : AppTheme.lightTextSecondaryColor,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                'Cancel',
                style: GoogleFonts.albertSans(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.7)
                      : Colors.grey.shade700,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                _deleteDiscount(discount['id']);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Delete',
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

  Future<void> _deleteDiscount(String discountId) async {
    try {
      await _firestore.collection('discounts').doc(discountId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Discount deleted successfully'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _fetchDiscounts();
    } catch (e) {
      debugPrint('Error deleting discount: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting discount: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

// Text input formatter to convert input to uppercase
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
