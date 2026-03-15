import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shiffters/theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:shiffters/services/theme_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OrderManagementScreen extends StatefulWidget {
  const OrderManagementScreen({super.key});

  @override
  State<OrderManagementScreen> createState() => _OrderManagementScreenState();
}

class _OrderManagementScreenState extends State<OrderManagementScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';
  final List<String> _filterOptions = [
    'All',
    'Pending',
    'Confirmed',
    'In Transit',
    'Picked Up',
    'Delivered',
    'Cancelled'
  ];

  // Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _allOrders = [];
  List<Map<String, dynamic>> _filteredOrders = [];
  Set<String> _selectedOrders = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
    _fetchOrders();
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
      print('Error getting $key: $e');
      return defaultValue;
    }
  }

  // Fetch orders from Firestore
  Future<void> _fetchOrders() async {
    try {
      setState(() {
        _isLoading = true;
      });

      QuerySnapshot querySnapshot = await _firestore
          .collection('orders')
          .orderBy('createdAt', descending: true)
          .get();

      List<Map<String, dynamic>> orders = [];
      for (var doc in querySnapshot.docs) {
        try {
          Map<String, dynamic> orderData = doc.data() as Map<String, dynamic>;
          orderData['id'] = doc.id;
          orders.add(orderData);
        } catch (e) {
          print('Error processing document ${doc.id}: $e');
          continue;
        }
      }

      if (mounted) {
        setState(() {
          _allOrders = orders;
          _filteredOrders = List.from(_allOrders);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching orders: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _filterOrders() {
    setState(() {
      _filteredOrders = _allOrders.where((order) {
        final String status =
            _safeGet<String>(order, 'status', 'pending') ?? 'pending';
        final matchesFilter = _selectedFilter == 'All' ||
            status.toLowerCase() == _selectedFilter.toLowerCase();

        final matchesSearch = _searchController.text.isEmpty ||
            order['id']
                .toLowerCase()
                .contains(_searchController.text.toLowerCase()) ||
            (_safeGet<String>(order, 'customerName', '') ?? '')
                .toLowerCase()
                .contains(_searchController.text.toLowerCase()) ||
            (_safeGet<String>(order, 'orderType', '') ?? '')
                .toLowerCase()
                .contains(_searchController.text.toLowerCase());

        return matchesFilter && matchesSearch;
      }).toList();
    });
  }

  // Format date from Firestore timestamp
  String _formatDate(dynamic timestamp) {
    try {
      if (timestamp is Timestamp) {
        final date = timestamp.toDate();
        return '${_getMonthName(date.month)} ${date.day}, ${date.year}';
      } else if (timestamp is String) {
        final date = DateTime.parse(timestamp);
        return '${_getMonthName(date.month)} ${date.day}, ${date.year}';
      }
      return 'Date not available';
    } catch (e) {
      return 'Date not available';
    }
  }

  String _getMonthName(int month) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month];
  }

  // Get status color
  Color _getStatusColor(String status, bool isDarkMode) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.orange;
      case 'in transit':
        return Colors.blue;
      case 'picked up':
      case 'pickedup':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'pending':
      default:
        return isDarkMode ? Colors.grey : Colors.grey.shade600;
    }
  }

  // Get priority color
  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
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
    super.build(context);
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        final isDarkMode = themeService.isDarkMode;

        return Scaffold(
          backgroundColor:
              isDarkMode ? const Color(0xFF1E1E2C) : const Color(0xFFE8E8F0),
          body: Column(
            children: [
              // Header
              _buildHeader(isTablet, isDarkMode),

              // Search and filters
              _buildSearchAndFilters(isTablet, isDarkMode),

              // Bulk actions
              if (_selectedOrders.isNotEmpty)
                _buildBulkActions(isTablet, isDarkMode),

              // Content
              Expanded(
                child: SafeArea(
                  top: false,
                  child: _isLoading
                      ? _buildLoadingIndicator(isDarkMode)
                      : _buildOrdersList(isTablet, isDarkMode),
                ),
              ),
            ],
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
                          'Order Management',
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 28 : 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${_filteredOrders.length} orders',
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
                    _fetchOrders();
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
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16),
                border: isDarkMode
                    ? Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 1,
                      )
                    : Border.all(
                        color: AppColors.lightPrimary,
                        width: 1.5,
                      ),
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
              child: TextField(
                controller: _searchController,
                onChanged: (value) => _filterOrders(),
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 16 : 14,
                  color: isDarkMode ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Search orders by ID, customer, or type...',
                  hintStyle: GoogleFonts.albertSans(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.6)
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.7)
                        : AppColors.textSecondary,
                    size: isTablet ? 24 : 20,
                  ),
                  border: OutlineInputBorder(
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

            const SizedBox(height: 20),

            // Filter tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: _filterOptions.map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _selectedFilter = filter;
                          _filterOrders();
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 24 : 20,
                          vertical: isTablet ? 12 : 10,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDarkMode
                                  ? AppColors.yellowAccent
                                  : AppColors.lightPrimary)
                              : isDarkMode
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(50),
                          border: isSelected
                              ? null
                              : Border.all(
                                  color: isDarkMode
                                      ? Colors.white.withValues(alpha: 0.1)
                                      : Colors.grey.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: isDarkMode
                                        ? AppColors.yellowAccent
                                            .withValues(alpha: 0.4)
                                        : AppColors.lightPrimary
                                            .withValues(alpha: 0.4),
                                    blurRadius: 15,
                                    offset: const Offset(0, 6),
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          filter,
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 14 : 12,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : isDarkMode
                                    ? Colors.white.withValues(alpha: 0.7)
                                    : Colors.grey.shade600,
                          ),
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

  Widget _buildBulkActions(bool isTablet, bool isDarkMode) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isTablet ? 32 : 20,
        vertical: isTablet ? 16 : 12,
      ),
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? AppColors.yellowAccent.withValues(alpha: 0.1)
            : AppColors.lightPrimary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode
              ? AppColors.yellowAccent.withValues(alpha: 0.3)
              : AppColors.lightPrimary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Text(
            '${_selectedOrders.length} selected',
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 16 : 14,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _bulkUpdateStatus,
            icon: const Icon(Icons.update, size: 16),
            label: Text(
              'Update Status',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 14 : 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: TextButton.styleFrom(
              foregroundColor:
                  isDarkMode ? AppColors.yellowAccent : AppColors.lightPrimary,
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: _bulkCancel,
            icon: const Icon(Icons.cancel, size: 16),
            label: Text(
              'Cancel',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 14 : 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
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
            color: isDarkMode ? AppColors.yellowAccent : AppColors.lightPrimary,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading orders...',
            style: GoogleFonts.albertSans(
              fontSize: 16,
              color: isDarkMode ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList(bool isTablet, bool isDarkMode) {
    if (_filteredOrders.isEmpty) {
      return _buildEmptyState(isDarkMode);
    }

    return SlideTransition(
      position: _slideAnimation,
      child: RefreshIndicator(
        onRefresh: _fetchOrders,
        color: isDarkMode ? AppColors.yellowAccent : AppColors.lightPrimary,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 32 : 20,
            vertical: isTablet ? 16 : 12,
          ),
          itemCount: _filteredOrders.length,
          itemBuilder: (context, index) {
            final order = _filteredOrders[index];
            return _buildOrderCard(order, isTablet, isDarkMode);
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
            Icons.inbox_outlined,
            size: 80,
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.3)
                : Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No orders found',
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
            'Try adjusting your search or filter criteria',
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

  Widget _buildOrderCard(
      Map<String, dynamic> order, bool isTablet, bool isDarkMode) {
    final isSelected = _selectedOrders.contains(order['id']);

    // Safely extract data
    final String orderId = _safeGet<String>(order, 'id', 'N/A') ?? 'N/A';
    final String status =
        _safeGet<String>(order, 'status', 'pending') ?? 'pending';
    final String orderType =
        _safeGet<String>(order, 'orderType', 'shifting') ?? 'shifting';
    final double totalAmount =
        (_safeGet<num>(order, 'totalAmount', 0) ?? 0).toDouble();
    final dynamic createdAt = order['createdAt'];
    final String customerName =
        _safeGet<String>(order, 'customerName', 'Unknown Customer') ??
            'Unknown Customer';

    // Get pickup and drop locations from nested structure
    final pickupLocationData = order['pickupLocation'] as Map<String, dynamic>?;
    final dropoffLocationData =
        order['dropoffLocation'] as Map<String, dynamic>?;

    final String pickupAddress =
        pickupLocationData?['address']?.toString() ?? 'Pickup location';
    final String dropoffAddress =
        dropoffLocationData?['address']?.toString() ?? 'Drop location';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? (isDarkMode ? AppColors.yellowAccent : AppColors.lightPrimary)
              : isDarkMode
                  ? Colors.white.withValues(alpha: 0.2)
                  : AppColors.lightPrimary,
          width: isSelected ? 2 : 1.5,
        ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              // Checkbox
              Checkbox(
                value: isSelected,
                onChanged: (bool? value) {
                  setState(() {
                    if (value == true) {
                      _selectedOrders.add(order['id']);
                    } else {
                      _selectedOrders.remove(order['id']);
                    }
                  });
                },
                activeColor: isDarkMode
                    ? AppColors.yellowAccent
                    : AppColors.lightPrimary,
              ),

              // Order ID and Status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${orderId.length > 8 ? orderId.substring(0, 8).toUpperCase() : orderId.toUpperCase()}',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 18 : 16,
                        fontWeight: FontWeight.bold,
                        color:
                            isDarkMode ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status, isDarkMode)
                                .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: GoogleFonts.albertSans(
                              fontSize: isTablet ? 12 : 10,
                              fontWeight: FontWeight.w600,
                              color: _getStatusColor(status, isDarkMode),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          orderType.toUpperCase(),
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 12 : 10,
                            fontWeight: FontWeight.w500,
                            color: isDarkMode
                                ? AppColors.yellowAccent
                                : AppColors.lightPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Rs ${totalAmount.toStringAsFixed(0)}',
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 18 : 16,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode
                          ? AppColors.yellowAccent
                          : AppColors.lightPrimary,
                    ),
                  ),
                  Text(
                    _formatDate(createdAt),
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 12 : 10,
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.7)
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Customer info
          Container(
            padding: EdgeInsets.all(isTablet ? 16 : 12),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
              border: isDarkMode
                  ? null
                  : Border.all(
                      color: AppColors.lightPrimary,
                      width: 1.5,
                    ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: isTablet ? 20 : 16,
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.6)
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Customer: $customerName',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 14 : 12,
                        fontWeight: FontWeight.w600,
                        color:
                            isDarkMode ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Location info
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: isTablet ? 18 : 16,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'From: $pickupAddress',
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 12 : 11,
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.7)
                              : AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.flag_outlined,
                      size: isTablet ? 18 : 16,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'To: $dropoffAddress',
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 12 : 11,
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.7)
                              : AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Actions
          Row(
            children: [
              Expanded(
                child: Container(
                  height: isTablet ? 48 : 44,
                  child: ElevatedButton.icon(
                    onPressed: () => _viewOrderDetails(order),
                    icon: const Icon(Icons.visibility, size: 16),
                    label: Text(
                      'View Details',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 14 : 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDarkMode
                          ? AppColors.yellowAccent
                          : AppColors.lightPrimary,
                      foregroundColor: isDarkMode ? Colors.black : Colors.white,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: isDarkMode
                            ? AppColors.yellowAccent.withValues(alpha: 0.3)
                            : AppColors.lightPrimary.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                      BoxShadow(
                        color: isDarkMode
                            ? AppColors.yellowAccent.withValues(alpha: 0.1)
                            : AppColors.lightPrimary.withValues(alpha: 0.1),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: isTablet ? 48 : 44,
                  child: ElevatedButton.icon(
                    onPressed: () => _updateOrderStatus(order),
                    icon: const Icon(Icons.update, size: 16),
                    label: Text(
                      'Update Status',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 14 : 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDarkMode
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.white,
                      foregroundColor:
                          isDarkMode ? Colors.white : AppColors.textPrimary,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.3)
                              : AppColors.lightPrimary.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.1)
                            : AppColors.lightPrimary.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                      BoxShadow(
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.05)
                            : AppColors.lightPrimary.withValues(alpha: 0.1),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _viewOrderDetails(Map<String, dynamic> order) {
    final isDarkMode =
        Provider.of<ThemeService>(context, listen: false).isDarkMode;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.3)
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order Details',
                      style: GoogleFonts.albertSans(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color:
                            isDarkMode ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildDetailRow('Order ID', order['id'], isDarkMode),
                    _buildDetailRow(
                        'Status', order['status'] ?? 'N/A', isDarkMode),
                    _buildDetailRow(
                        'Order Type', order['orderType'] ?? 'N/A', isDarkMode),
                    _buildDetailRow(
                        'Customer', order['customerName'] ?? 'N/A', isDarkMode),
                    _buildDetailRow(
                        'Total Amount',
                        'Rs ${(order['totalAmount'] ?? 0).toString()}',
                        isDarkMode),
                    _buildDetailRow('Created At',
                        _formatDate(order['createdAt']), isDarkMode),
                    const SizedBox(height: 20),
                    Text(
                      'Locations',
                      style: GoogleFonts.albertSans(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color:
                            isDarkMode ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                color: Colors.green,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Pickup: ${(order['pickupLocation'] as Map<String, dynamic>?)?['address'] ?? 'N/A'}',
                                  style: GoogleFonts.albertSans(
                                    fontSize: 14,
                                    color: isDarkMode
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.flag,
                                color: Colors.red,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Drop-off: ${(order['dropoffLocation'] as Map<String, dynamic>?)?['address'] ?? 'N/A'}',
                                  style: GoogleFonts.albertSans(
                                    fontSize: 14,
                                    color: isDarkMode
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
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

  Widget _buildDetailRow(String label, String value, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: GoogleFonts.albertSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.8)
                    : AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.albertSans(
                fontSize: 14,
                color: isDarkMode ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _updateOrderStatus(Map<String, dynamic> order) {
    final isDarkMode =
        Provider.of<ThemeService>(context, listen: false).isDarkMode;
    String selectedStatus = order['status'] ?? 'pending';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
          title: Text(
            'Update Order Status',
            style: GoogleFonts.albertSans(
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : AppColors.textPrimary,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: _filterOptions.skip(1).map((status) {
              return RadioListTile<String>(
                title: Text(
                  status,
                  style: GoogleFonts.albertSans(
                    color: isDarkMode ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                value: status.toLowerCase(),
                groupValue: selectedStatus.toLowerCase(),
                activeColor: isDarkMode
                    ? AppColors.yellowAccent
                    : AppColors.lightPrimary,
                onChanged: (value) {
                  setDialogState(() {
                    selectedStatus = value!;
                  });
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.albertSans(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.7)
                      : AppColors.textSecondary,
                ),
              ),
            ),
            Container(
              height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);

                  try {
                    await _firestore
                        .collection('orders')
                        .doc(order['id'])
                        .update({
                      'status': selectedStatus,
                      'updatedAt': FieldValue.serverTimestamp(),
                    });

                    setState(() {
                      order['status'] = selectedStatus;
                    });
                    _filterOrders();

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        content: Text(
                          'Order status updated successfully',
                          style: GoogleFonts.albertSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        content: Text(
                          'Error updating order status: $e',
                          style: GoogleFonts.albertSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDarkMode
                      ? AppColors.yellowAccent
                      : AppColors.lightPrimary,
                  foregroundColor: isDarkMode ? Colors.black : Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 0),
                ),
                child: Text(
                  'Update',
                  style: GoogleFonts.albertSans(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: isDarkMode
                        ? AppColors.yellowAccent.withValues(alpha: 0.3)
                        : AppColors.lightPrimary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                  BoxShadow(
                    color: isDarkMode
                        ? AppColors.yellowAccent.withValues(alpha: 0.1)
                        : AppColors.lightPrimary.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _bulkUpdateStatus() {
    if (_selectedOrders.isEmpty) return;

    final isDarkMode =
        Provider.of<ThemeService>(context, listen: false).isDarkMode;
    String selectedStatus = 'pending';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
          title: Text(
            'Bulk Update Status',
            style: GoogleFonts.albertSans(
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : AppColors.textPrimary,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Update ${_selectedOrders.length} selected orders to:',
                style: GoogleFonts.albertSans(
                  color: isDarkMode ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              ..._filterOptions.skip(1).map((status) {
                return RadioListTile<String>(
                  title: Text(
                    status,
                    style: GoogleFonts.albertSans(
                      color: isDarkMode ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  value: status.toLowerCase(),
                  groupValue: selectedStatus,
                  activeColor: isDarkMode
                      ? AppColors.yellowAccent
                      : AppColors.lightPrimary,
                  onChanged: (value) {
                    setDialogState(() {
                      selectedStatus = value!;
                    });
                  },
                );
              }).toList(),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.albertSans(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.7)
                      : AppColors.textSecondary,
                ),
              ),
            ),
            Container(
              height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);

                  try {
                    final batch = _firestore.batch();
                    for (String orderId in _selectedOrders) {
                      batch.update(
                        _firestore.collection('orders').doc(orderId),
                        {
                          'status': selectedStatus,
                          'updatedAt': FieldValue.serverTimestamp(),
                        },
                      );
                    }
                    await batch.commit();

                    setState(() {
                      for (var order in _allOrders) {
                        if (_selectedOrders.contains(order['id'])) {
                          order['status'] = selectedStatus;
                        }
                      }
                      _selectedOrders.clear();
                    });
                    _filterOrders();

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        content: Text(
                          'Orders updated successfully',
                          style: GoogleFonts.albertSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        content: Text(
                          'Error updating orders: $e',
                          style: GoogleFonts.albertSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDarkMode
                      ? AppColors.yellowAccent
                      : AppColors.lightPrimary,
                  foregroundColor: isDarkMode ? Colors.black : Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 0),
                ),
                child: Text(
                  'Update All',
                  style: GoogleFonts.albertSans(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: isDarkMode
                        ? AppColors.yellowAccent.withValues(alpha: 0.3)
                        : AppColors.lightPrimary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                  BoxShadow(
                    color: isDarkMode
                        ? AppColors.yellowAccent.withValues(alpha: 0.1)
                        : AppColors.lightPrimary.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _bulkCancel() {
    if (_selectedOrders.isEmpty) return;

    final isDarkMode =
        Provider.of<ThemeService>(context, listen: false).isDarkMode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
        title: Text(
          'Cancel Orders',
          style: GoogleFonts.albertSans(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to cancel ${_selectedOrders.length} selected orders?',
          style: GoogleFonts.albertSans(
            color: isDarkMode ? Colors.white : AppColors.textPrimary,
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
                    : AppColors.textSecondary,
              ),
            ),
          ),
          Container(
            height: 48,
            child: ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);

                try {
                  final batch = _firestore.batch();
                  for (String orderId in _selectedOrders) {
                    batch.update(
                      _firestore.collection('orders').doc(orderId),
                      {
                        'status': 'cancelled',
                        'updatedAt': FieldValue.serverTimestamp(),
                      },
                    );
                  }
                  await batch.commit();

                  setState(() {
                    for (var order in _allOrders) {
                      if (_selectedOrders.contains(order['id'])) {
                        order['status'] = 'cancelled';
                      }
                    }
                    _selectedOrders.clear();
                  });
                  _filterOrders();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.orange,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      content: Text(
                        'Orders cancelled successfully',
                        style: GoogleFonts.albertSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      content: Text(
                        'Error cancelling orders: $e',
                        style: GoogleFonts.albertSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 0),
              ),
              child: Text(
                'Cancel Orders',
                style: GoogleFonts.albertSans(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
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
        ],
      ),
    );
  }

  // Add getter for isDarkMode to use in methods
  bool get isDarkMode =>
      Provider.of<ThemeService>(context, listen: false).isDarkMode;
}
