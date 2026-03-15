import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shiffters/services/theme_service.dart';
import 'package:shiffters/theme/app_colors.dart';
import 'package:shiffters/theme/app_theme.dart';
import 'package:shiffters/screens/User/chat_screen.dart';

import 'driver_job_details_screen.dart';

class DriverOrdersScreen extends StatefulWidget {
  const DriverOrdersScreen({super.key});

  @override
  State<DriverOrdersScreen> createState() => _DriverOrdersScreenState();
}

class _DriverOrdersScreenState extends State<DriverOrdersScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Active', 'Completed', 'Cancelled'];

  // Unread message tracking
  Map<String, int> _unreadCounts = {};

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
    _setupUnreadCountsListener();

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

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      _animationController.forward();
    }
  }

  void _setupUnreadCountsListener() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    print(
        "✅ [Driver Orders] Setting up unread counts listener for driver: $currentUserId");

    // Listen to all conversations where current user is a participant
    FirebaseFirestore.instance
        .collection('conversations')
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .listen((QuerySnapshot snapshot) {
      print("🔍 [Driver Orders] Found ${snapshot.docs.length} conversations");

      Map<String, int> newUnreadCounts = {};

      for (var doc in snapshot.docs) {
        try {
          final conversationData = doc.data() as Map<String, dynamic>;
          final String orderId = conversationData['orderId'] ?? '';

          if (orderId.isNotEmpty) {
            // Get unread count for current user
            final Map<String, dynamic> unreadCounts =
                conversationData['unreadCounts'] as Map<String, dynamic>? ?? {};
            final int unreadCount = unreadCounts[currentUserId] as int? ?? 0;

            if (unreadCount > 0) {
              newUnreadCounts[orderId] = unreadCount;
              print(
                  "🔍 [Driver Orders] Order $orderId has $unreadCount unread messages");
            }
          }
        } catch (e) {
          print(
              "❌ [Driver Orders] Error processing conversation ${doc.id}: $e");
        }
      }

      if (mounted) {
        setState(() {
          _unreadCounts = newUnreadCounts;
        });
      }

      print("✅ [Driver Orders] Updated unread counts: $_unreadCounts");
    }, onError: (error) {
      print("❌ [Driver Orders] Error listening to conversations: $error");
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    // Clear unread counts to prevent memory leaks
    _unreadCounts.clear();
    super.dispose();
  }

  // Firestore stream for current driver's orders
  Stream<QuerySnapshot<Map<String, dynamic>>> _ordersStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      // Empty stream if user not logged in
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }
    // If you add orderBy in future, ensure composite index exists.
    return FirebaseFirestore.instance
        .collection('orders')
        .where('driverId', isEqualTo: uid)
        .snapshots();
  }

  // Convert Firestore doc to the UI-friendly order map
  Map<String, dynamic> _docToOrder(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    // Status mapping to UI expected categories
    final rawStatus = (data['status'] ?? '').toString().toLowerCase();
    final status = _mapStatus(rawStatus);

    // Timestamps -> human time (use startedAt if present, else paymentTimestamp)
    final Timestamp? ts = (data['startedAt'] is Timestamp)
        ? data['startedAt'] as Timestamp
        : (data['paymentTimestamp'] is Timestamp
            ? data['paymentTimestamp'] as Timestamp
            : null);
    final timeString = _formatTime(ts);

    // Items
    final itemsList = (data['items'] is List)
        ? List<String>.from(data['items'].map((e) => e.toString()))
        : <String>[];
    final itemsJoined = itemsList.isEmpty ? '—' : itemsList.join(', ');

    // Addresses
    final pickupAddress = (data['pickupLocation']?['address'] ?? '').toString();
    final dropoffAddress =
        (data['dropoffLocation']?['address'] ?? '').toString();

    // Earnings
    final num? totalAmount = data['totalAmount'] as num?;

    // Duration (minutes or any number), default pretty string
    final num? duration = data['duration'] as num?;
    final estimatedDuration = _formatDuration(duration);

    // Optional fields (customer name/phone might not exist in your schema)
    final customer =
        (data['customerName'] ?? data['customer'] ?? 'Customer').toString();
    final customerPhone = (data['customerPhone'] ?? 'N/A').toString();

    // Priority (not in schema - default Medium)
    final priority =
        (data['priority'] ?? _inferPriority(totalAmount)).toString();

    return {
      'id': doc.id,
      'customer': customer,
      'pickupAddress': pickupAddress.isEmpty ? '—' : pickupAddress,
      'dropoffAddress': dropoffAddress.isEmpty ? '—' : dropoffAddress,
      'time': timeString,
      'status': status, // "Active" | "Completed" | "Cancelled"
      'earnings': (totalAmount ?? 0).toDouble(),
      'items': itemsJoined,
      'customerPhone': customerPhone,
      'estimatedDuration': estimatedDuration,
      'priority': priority,
      // Raw fields if needed later
      '_rawStatus': rawStatus,
      '_timestamp': ts,
      '_itemsList': itemsList,
      '_data': data,
    };
  }

  String _mapStatus(String s) {
    switch (s) {
      case 'started':
      case 'in_progress':
      case 'in-progress':
      case 'ongoing':
      case 'active':
        return 'Active';
      case 'completed':
      case 'complete':
        return 'Completed';
      case 'cancelled':
      case 'canceled':
        return 'Cancelled';
      default:
        return 'Active';
    }
  }

  String _inferPriority(num? amount) {
    if (amount == null) return 'Medium';
    if (amount >= 1000) return 'High';
    if (amount >= 500) return 'Medium';
    return 'Low';
  }

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '—';
    final dt = ts.toDate();
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
    // For locale-aware formatting, consider the intl package if available.
  }

  String _formatDuration(num? value) {
    if (value == null) return '—';
    final minutes = value.toInt();
    if (minutes <= 0) return '—';
    if (minutes >= 120) {
      final hours = (minutes / 60).floor();
      final rem = minutes % 60;
      return rem == 0 ? '$hours hours' : '$hours h ${rem}m';
    } else if (minutes >= 60) {
      final hours = (minutes / 60).floor();
      final rem = minutes % 60;
      return '$hours h ${rem}m';
    }
    return '$minutes min';
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> orders) {
    var filtered = orders;

    if (_selectedFilter != 'All') {
      filtered = filtered
          .where((order) => order['status'] == _selectedFilter)
          .toList();
    }

    if (_searchController.text.isNotEmpty) {
      final q = _searchController.text.toLowerCase();
      filtered = filtered.where((order) {
        final customer = (order['customer'] ?? '').toString().toLowerCase();
        final id = (order['id'] ?? '').toString().toLowerCase();
        final items = (order['items'] ?? '').toString().toLowerCase();
        return customer.contains(q) || id.contains(q) || items.contains(q);
      }).toList();
    }

    return filtered;
  }

  Map<String, int> _computeCounts(List<Map<String, dynamic>> orders) {
    final all = orders.length;
    final active = orders.where((o) => o['status'] == 'Active').length;
    final completed = orders.where((o) => o['status'] == 'Completed').length;
    final cancelled = orders.where((o) => o['status'] == 'Cancelled').length;
    return {
      'All': all,
      'Active': active,
      'Completed': completed,
      'Cancelled': cancelled,
    };
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        final darkMode = themeService.isDarkMode;

        return Scaffold(
          backgroundColor: darkMode
              ? const Color(0xFF1E1E2C)
              : AppTheme.lightBackgroundColor,
          body: Column(
            children: [
              _buildHeader(isTablet, darkMode),
              Expanded(
                child: SafeArea(
                  top: false,
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _ordersStream(),
                    builder: (context, snapshot) {
                      if (FirebaseAuth.instance.currentUser == null) {
                        return _buildCenteredMessage(
                          isTablet,
                          darkMode,
                          icon: Icons.lock_outline,
                          title: 'Sign in required',
                          subtitle: 'Please sign in to view your orders.',
                        );
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return _buildCenteredMessage(
                          isTablet,
                          darkMode,
                          icon: Icons.error_outline,
                          title: 'Something went wrong',
                          subtitle: '${snapshot.error}',
                        );
                      }

                      final docs = snapshot.data?.docs ?? [];
                      final orders = docs
                          .map((d) => _docToOrder(d))
                          .toList(growable: false);
                      final counts = _computeCounts(orders);
                      final filteredOrders = _applyFilters(orders);

                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 32 : 20,
                          ),
                          child: Column(
                            children: [
                              const SizedBox(height: 24),
                              _buildSearchBar(isTablet, darkMode),
                              const SizedBox(height: 20),
                              _buildFilterTabs(isTablet, darkMode, counts),
                              const SizedBox(height: 20),
                              _buildOrdersList(
                                  filteredOrders, isTablet, darkMode),
                              const SizedBox(height: 100),
                            ],
                          ),
                        ),
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
                  ? Colors.white.withValues(alpha: 0.3)
                  : AppColors.textSecondary.withValues(alpha: 0.5),
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
                    ? Colors.white.withValues(alpha: 0.5)
                    : AppColors.textSecondary.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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
                'My Orders',
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 28 : 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),

              // Refresh button
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _refreshOrders();
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

  Widget _buildSearchBar(bool isTablet, bool isDarkMode) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
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
        child: TextField(
          controller: _searchController,
          onChanged: (value) => setState(() {}),
          style: GoogleFonts.albertSans(
            fontSize: isTablet ? 16 : 14,
            color: isDarkMode ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: 'Search orders, customers, items...',
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
            suffixIcon: _searchController.text.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() {});
                    },
                    child: Icon(
                      Icons.clear,
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.7)
                          : AppColors.textSecondary,
                      size: isTablet ? 20 : 18,
                    ),
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDarkMode
                    ? AppColors.yellowAccent
                    : AppTheme.lightPrimaryColor,
                width: 2,
              ),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: isTablet ? 20 : 16,
              vertical: isTablet ? 18 : 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterTabs(
      bool isTablet, bool isDarkMode, Map<String, int> counts) {
    return SlideTransition(
      position: _slideAnimation,
      child: ClipRect(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: _filters.map((filter) {
              final isSelected = _selectedFilter == filter;
              final count = counts[filter] ?? 0;

              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _selectedFilter = filter;
                    });
                  },
                  child: _buildFilterTab(
                      filter, count, isSelected, isTablet, isDarkMode),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterTab(String title, int count, bool isSelected,
      bool isTablet, bool isDarkMode) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 20 : 16,
        vertical: isTablet ? 12 : 10,
      ),
      decoration: BoxDecoration(
        color: isSelected
            ? (isDarkMode ? AppColors.yellowAccent : AppTheme.lightPrimaryColor)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: isSelected
              ? (isDarkMode
                  ? AppColors.yellowAccent
                  : AppTheme.lightPrimaryColor)
              : isDarkMode
                  ? Colors.white.withValues(alpha: 0.3)
                  : AppTheme.lightPrimaryColor.withValues(alpha: 0.4),
          width: isSelected ? 0 : 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 14 : 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? (isDarkMode ? Colors.black : Colors.white)
                  : isDarkMode
                      ? Colors.white.withValues(alpha: 0.8)
                      : AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDarkMode
                      ? Colors.black.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.3))
                  : (isDarkMode
                      ? AppColors.yellowAccent.withValues(alpha: 0.3)
                      : AppTheme.lightPrimaryColor.withValues(alpha: 0.2)),
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: Text(
              '$count',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 10 : 8,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? (isDarkMode ? Colors.black : Colors.white)
                    : isDarkMode
                        ? AppColors.yellowAccent
                        : AppTheme.lightPrimaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList(List<Map<String, dynamic>> filteredOrders,
      bool isTablet, bool isDarkMode) {
    if (filteredOrders.isEmpty) {
      return SizedBox(
        height: 300,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: isTablet ? 80 : 60,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.3)
                  : AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No orders found',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 18 : 16,
                fontWeight: FontWeight.w600,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.7)
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchController.text.isNotEmpty
                  ? 'Try adjusting your search terms'
                  : 'New orders will appear here',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 14 : 12,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.5)
                    : AppColors.textSecondary.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    // Sort orders: completed orders at the bottom, others at the top
    final sortedOrders = List<Map<String, dynamic>>.from(filteredOrders);
    sortedOrders.sort((a, b) {
      final aStatus = a['status'] as String;
      final bStatus = b['status'] as String;

      // If both are completed or both are not completed, maintain original order
      if ((aStatus == 'Completed') == (bStatus == 'Completed')) {
        return 0;
      }

      // Completed orders go to the bottom (return 1 means a comes after b)
      if (aStatus == 'Completed') return 1;
      if (bStatus == 'Completed') return -1;

      return 0;
    });

    return Column(
      children: List.generate(sortedOrders.length, (index) {
        final order = sortedOrders[index];
        return _buildOrderCard(order, isTablet, isDarkMode);
      }),
    );
  }

  Widget _buildOrderCard(
      Map<String, dynamic> order, bool isTablet, bool isDarkMode) {
    Color statusColor = _getStatusColor(order['status']);
    Color priorityColor = _getPriorityColor(order['priority']);

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: EdgeInsets.all(isTablet ? 20 : 16),
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
            // Header
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(isTablet ? 8 : 6),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? AppColors.yellowAccent.withValues(alpha: 0.2)
                              : AppTheme.lightPrimaryColor
                                  .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.local_shipping,
                          color: isDarkMode
                              ? AppColors.yellowAccent
                              : AppTheme.lightPrimaryColor,
                          size: isTablet ? 20 : 16,
                        ),
                      ),
                      SizedBox(width: isTablet ? 12 : 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order #${order['id']}',
                              style: GoogleFonts.albertSans(
                                fontSize: isTablet ? 16 : 13,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              order['customer'] ?? 'Customer',
                              style: GoogleFonts.albertSans(
                                fontSize: isTablet ? 14 : 11,
                                color: isDarkMode
                                    ? Colors.white.withValues(alpha: 0.7)
                                    : AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: isTablet ? 12 : 8),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 10 : 8,
                            vertical: isTablet ? 4 : 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: statusColor, width: 1),
                        ),
                        child: Text(
                          (order['status'] ?? '').toString(),
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 10 : 8,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(height: isTablet ? 4 : 3),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 8 : 6,
                            vertical: isTablet ? 2 : 2),
                        decoration: BoxDecoration(
                          color: priorityColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: priorityColor, width: 1),
                        ),
                        child: Text(
                          (order['priority'] ?? 'Medium').toString(),
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 8 : 7,
                            fontWeight: FontWeight.w600,
                            color: priorityColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Items
            Container(
              padding: EdgeInsets.all(isTablet ? 12 : 10),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(8),
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
                    Icons.inventory_2,
                    color: isDarkMode
                        ? AppColors.yellowAccent
                        : AppTheme.lightPrimaryColor,
                    size: isTablet ? 16 : 14,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Items: ${order['items']}',
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 12 : 10,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Addresses
            _buildAddressRow(
              Icons.my_location,
              'Pickup',
              (order['pickupAddress'] ?? '—') as String,
              Colors.green,
              isTablet,
              isDarkMode,
            ),

            const SizedBox(height: 8),

            _buildAddressRow(
              Icons.location_on,
              'Drop-off',
              (order['dropoffAddress'] ?? '—') as String,
              Colors.red,
              isTablet,
              isDarkMode,
            ),

            const SizedBox(height: 16),

            // Time, duration and earnings
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoChip(
                  Icons.access_time,
                  (order['time'] ?? '—') as String,
                  isDarkMode
                      ? AppColors.yellowAccent
                      : AppTheme.lightPrimaryColor,
                  isTablet,
                  isDarkMode,
                ),
                _buildInfoChip(
                  Icons.timer,
                  (order['estimatedDuration'] ?? '—') as String,
                  Colors.blue,
                  isTablet,
                  isDarkMode,
                ),
                _buildInfoChip(
                  Icons.account_balance_wallet,
                  'Rs. ${(order['earnings'] as double).toStringAsFixed(0)}',
                  Colors.green,
                  isTablet,
                  isDarkMode,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      // Don't navigate if status is completed
                      if (order['status'] != 'Completed') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                DriverJobDetailsScreen(orderData: order),
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: order['status'] == 'Completed'
                            ? Colors.green
                            : (isDarkMode
                                ? AppColors.yellowAccent
                                : AppTheme.lightPrimaryColor),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: order['status'] == 'Completed'
                                ? Colors.green.withValues(alpha: 0.3)
                                : (isDarkMode
                                    ? AppColors.yellowAccent
                                        .withValues(alpha: 0.3)
                                    : AppTheme.lightPrimaryColor
                                        .withValues(alpha: 0.3)),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (order['status'] == 'Completed')
                            Icon(
                              Icons.check_circle,
                              color: Colors.white,
                              size: isTablet ? 16 : 14,
                            ),
                          if (order['status'] == 'Completed')
                            const SizedBox(width: 6),
                          Text(
                            order['status'] == 'Completed'
                                ? 'Completed'
                                : 'View Details',
                            style: GoogleFonts.albertSans(
                              fontSize: isTablet ? 14 : 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Only show message icon if status is not Completed
                if (order['status'] != 'Completed')
                  _buildMessageIconWithBadge(order, isTablet, isDarkMode),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressRow(IconData icon, String title, String address,
      Color iconColor, bool isTablet, bool isDarkMode) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: isTablet ? 18 : 16),
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
              const SizedBox(height: 2),
              Text(
                address,
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 13 : 11,
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
    );
  }

  Widget _buildInfoChip(
      IconData icon, String text, Color color, bool isTablet, bool isDarkMode) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 10 : 8,
        vertical: isTablet ? 6 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: isTablet ? 14 : 12),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 11 : 9,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageIconWithBadge(
      Map<String, dynamic> order, bool isTablet, bool isDarkMode) {
    final String orderId = order['id'] ?? '';
    final int unreadCount = _unreadCounts[orderId] ?? 0;
    final bool hasUnreadMessages = unreadCount > 0;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _openChatWithCustomer(order);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hasUnreadMessages
                    ? (isDarkMode
                        ? AppColors.yellowAccent.withValues(alpha: 0.2)
                        : AppTheme.lightPrimaryColor.withValues(alpha: 0.1))
                    : (isDarkMode
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.white.withValues(alpha: 0.8)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasUnreadMessages
                      ? (isDarkMode
                          ? AppColors.yellowAccent
                          : AppTheme.lightPrimaryColor)
                      : (isDarkMode
                          ? AppColors.yellowAccent.withValues(alpha: 0.5)
                          : AppTheme.lightPrimaryColor.withValues(alpha: 0.5)),
                  width: hasUnreadMessages ? 2.5 : 2,
                ),
                boxShadow: hasUnreadMessages
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
              child: Icon(
                hasUnreadMessages ? Icons.mark_email_unread : Icons.message,
                color: hasUnreadMessages
                    ? (isDarkMode
                        ? AppColors.yellowAccent
                        : AppTheme.lightPrimaryColor)
                    : (isDarkMode
                        ? AppColors.yellowAccent.withValues(alpha: 0.7)
                        : AppTheme.lightPrimaryColor.withValues(alpha: 0.7)),
                size: isTablet ? 20 : 18,
              ),
            ),
            // Unread count badge
            if (hasUnreadMessages)
              Positioned(
                right: -4,
                top: -4,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.red, Colors.red.shade700],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 10 : 8,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Active':
        return isDarkMode ? AppColors.yellowAccent : AppTheme.lightPrimaryColor;
      case 'Completed':
        return Colors.green;
      case 'Cancelled':
        return Colors.red;
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

  void _refreshOrders() {
    // StreamBuilder will keep listening; this triggers a UI refresh and a snackbar.
    setState(() {});
    _showGlowingSnackBar(
      'Orders refreshed successfully',
      isDarkMode ? AppColors.yellowAccent : AppTheme.lightPrimaryColor,
    );
  }

  void _openChatWithCustomer(Map<String, dynamic> order) async {
    try {
      // Get the order data to extract user ID
      final orderData = order['_data'] as Map<String, dynamic>;
      final customerId = orderData['uid'] as String?;
      final customerName =
          orderData['customerName'] ?? orderData['customer'] ?? 'Customer';
      final orderId = order['id'] as String;

      if (customerId == null) {
        _showGlowingSnackBar(
          'Unable to find customer information',
          Colors.red,
        );
        return;
      }

      // Clear unread count locally for immediate UI update
      setState(() {
        _unreadCounts.remove(orderId);
      });

      print(
          "📱 [Driver Orders] Opening chat for order: $orderId with customer: $customerId");

      // Navigate to chat screen with driver mode enabled
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            orderId: orderId,
            otherUserId: customerId,
            otherUserName: customerName.toString(),
            isDriverMode: true,
          ),
        ),
      );

      // After returning from chat, the unread count should already be cleared
      // by the ChatScreen's markMessagesAsRead functionality
      print("📱 [Driver Orders] Returned from chat screen for order: $orderId");
    } catch (e) {
      print("❌ [Driver Orders] Error opening chat: $e");
      _showGlowingSnackBar(
        'Error opening chat: $e',
        Colors.red,
      );
    }
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

  bool get isDarkMode =>
      Provider.of<ThemeService>(context, listen: false).isDarkMode;
}
