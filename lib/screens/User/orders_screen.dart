import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shiffters/theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:shiffters/services/theme_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lottie/lottie.dart';
import 'package:shiffters/screens/User/chat_screen.dart';
import 'package:shiffters/screens/User/track_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  // Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _orders = [];
  bool _isLoadingOrders = true;
  String _selectedFilter = 'All';
  StreamSubscription<QuerySnapshot>? _ordersSubscription;
  bool _isRealTimeConnected = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
    _setupOrdersListener(); // Changed from _fetchOrders to real-time listener
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

  // Safe method to get list from Firestore (handles both List and Map)
  List<String> _safeGetList(Map<String, dynamic> data, String key) {
    try {
      if (data.containsKey(key) && data[key] != null) {
        final value = data[key];
        if (value is List) {
          return value.map((e) => e.toString()).toList();
        } else if (value is Map) {
          return value.values.map((e) => e.toString()).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error getting list $key: $e');
      return [];
    }
  }

  // Setup real-time orders listener
  void _setupOrdersListener() {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      print("❌ [Orders Screen] No user logged in");
      if (mounted) {
        setState(() {
          _orders = [];
          _isLoadingOrders = false;
        });
      }
      return;
    }

    print(
        "✅ [Orders Screen] Setting up real-time orders listener for UID: ${currentUser.uid}");

    // Cancel existing subscription if any
    _ordersSubscription?.cancel();

    setState(() {
      _isLoadingOrders = true;
    });

    try {
      _ordersSubscription = _firestore
          .collection('orders')
          .where('uid', isEqualTo: currentUser.uid)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen(
        (QuerySnapshot querySnapshot) {
          print(
              "✅ [Orders Screen] Real-time update: Found ${querySnapshot.docs.length} orders");

          List<Map<String, dynamic>> orders = [];
          for (var doc in querySnapshot.docs) {
            try {
              Map<String, dynamic> orderData =
                  doc.data() as Map<String, dynamic>;
              orderData['id'] = doc.id;
              orders.add(orderData);
              print(
                  "✅ [Orders Screen] Real-time order: ${doc.id}, Status: ${orderData['status']}, UID: ${orderData['uid']}");
            } catch (e) {
              print('Error processing real-time document ${doc.id}: $e');
              continue;
            }
          }

          print(
              "✅ [Orders Screen] Real-time total orders processed: ${orders.length}");

          if (mounted) {
            setState(() {
              _orders = orders;
              _isLoadingOrders = false;
              _isRealTimeConnected = true;
            });
          }
        },
        onError: (error) {
          print('❌ [Orders Screen] Real-time orders error: $error');

          if (mounted) {
            setState(() {
              _isRealTimeConnected = false;
            });
          }

          // If it's an index error, try without orderBy as a fallback
          if (error.toString().contains('index') ||
              error.toString().contains('failed-precondition')) {
            print(
                "🔧 [Orders Screen] Trying fallback real-time query without orderBy...");

            _ordersSubscription?.cancel();
            _ordersSubscription = _firestore
                .collection('orders')
                .where('uid', isEqualTo: currentUser.uid)
                .snapshots()
                .listen(
              (QuerySnapshot querySnapshot) {
                print(
                    "🔧 [Orders Screen] Fallback real-time update: Found ${querySnapshot.docs.length} orders");

                List<Map<String, dynamic>> orders = [];
                for (var doc in querySnapshot.docs) {
                  try {
                    Map<String, dynamic> orderData =
                        doc.data() as Map<String, dynamic>;
                    orderData['id'] = doc.id;
                    orders.add(orderData);
                  } catch (e) {
                    print(
                        'Error processing fallback real-time document ${doc.id}: $e');
                    continue;
                  }
                }

                // Sort orders manually since we can't use orderBy
                orders.sort((a, b) {
                  try {
                    final timestampA = a['createdAt'];
                    final timestampB = b['createdAt'];

                    if (timestampA == null && timestampB == null) return 0;
                    if (timestampA == null) return 1;
                    if (timestampB == null) return -1;

                    DateTime dateA = timestampA is Timestamp
                        ? timestampA.toDate()
                        : DateTime.parse(timestampA.toString());
                    DateTime dateB = timestampB is Timestamp
                        ? timestampB.toDate()
                        : DateTime.parse(timestampB.toString());

                    return dateB.compareTo(dateA); // Newest first
                  } catch (e) {
                    return 0;
                  }
                });

                if (mounted) {
                  setState(() {
                    _orders = orders;
                    _isLoadingOrders = false;
                  });
                }
              },
              onError: (fallbackError) {
                print(
                    "❌ [Orders Screen] Fallback real-time query also failed: $fallbackError");
                if (mounted) {
                  setState(() {
                    _isLoadingOrders = false;
                  });
                }
              },
            );
          } else {
            if (mounted) {
              setState(() {
                _isLoadingOrders = false;
              });
            }
          }
        },
      );
    } catch (e) {
      print('❌ [Orders Screen] Error setting up real-time listener: $e');
      if (mounted) {
        setState(() {
          _isLoadingOrders = false;
        });
      }
    }
  }

  // Manual refresh method for pull-to-refresh or refresh button
  Future<void> _refreshOrders() async {
    print("🔄 [Orders Screen] Manual refresh triggered");
    _setupOrdersListener(); // Re-setup the listener
  }

  // Filter orders based on selected filter
  List<Map<String, dynamic>> _getFilteredOrders() {
    List<Map<String, dynamic>> filteredOrders;

    if (_selectedFilter == 'All') {
      filteredOrders = List.from(_orders);
    } else {
      filteredOrders = _orders.where((order) {
        final String status =
            _safeGet<String>(order, 'status', 'confirmed') ?? 'confirmed';

        switch (_selectedFilter) {
          case 'Active':
            return [
              'confirmed',
              'pending',
              'active',
              'started',
              'picked_up',
              'pickedup',
              'in_transit',
              'in transit'
            ].contains(status.toLowerCase());
          case 'Completed':
            return ['delivered', 'completed'].contains(status.toLowerCase());
          case 'Cancelled':
            return ['cancelled', 'canceled'].contains(status.toLowerCase());
          default:
            return true;
        }
      }).toList();
    }

    // Sort orders with active orders first, then completed/cancelled at bottom
    filteredOrders.sort((a, b) {
      final String statusA =
          _safeGet<String>(a, 'status', 'confirmed') ?? 'confirmed';
      final String statusB =
          _safeGet<String>(b, 'status', 'confirmed') ?? 'confirmed';

      // Get priority for each status (lower number = higher priority)
      int getPriority(String status) {
        switch (status.toLowerCase()) {
          case 'confirmed':
          case 'pending':
            return 1;
          case 'active':
          case 'started':
            return 2;
          case 'picked_up':
          case 'pickedup':
            return 3;
          case 'in_transit':
          case 'in transit':
            return 4;
          case 'delivered':
          case 'completed':
            return 8; // Lower priority (towards bottom)
          case 'cancelled':
          case 'canceled':
            return 9; // Lowest priority (at bottom)
          default:
            return 5;
        }
      }

      int priorityA = getPriority(statusA);
      int priorityB = getPriority(statusB);

      // If priorities are different, sort by priority
      if (priorityA != priorityB) {
        return priorityA.compareTo(priorityB);
      }

      // If same priority, sort by creation date (newest first)
      try {
        final timestampA = a['createdAt'];
        final timestampB = b['createdAt'];

        if (timestampA == null && timestampB == null) return 0;
        if (timestampA == null) return 1;
        if (timestampB == null) return -1;

        DateTime dateA = timestampA is Timestamp
            ? timestampA.toDate()
            : DateTime.parse(timestampA.toString());
        DateTime dateB = timestampB is Timestamp
            ? timestampB.toDate()
            : DateTime.parse(timestampB.toString());

        return dateB.compareTo(dateA); // Newest first
      } catch (e) {
        return 0;
      }
    });

    return filteredOrders;
  }

  // Get progress percentage based on status
  double _getProgressPercentage(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'confirmed':
      case 'pending':
        return 0.0; // 0% - Pending
      case 'started':
      case 'picked_up':
      case 'pickedup':
        return 0.33; // 33% - Picked Up
      case 'in_transit':
      case 'in transit':
        return 0.66; // 66% - In Transit
      case 'delivered':
      case 'completed':
        return 1.0; // 100% - Delivered
      default:
        return 0.0;
    }
  }

  // Get status color
  Color _getStatusColor(String status, bool isDarkMode) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'started':
        return Colors.orange;
      case 'picked_up':
      case 'pickedup':
        return Colors.blue;
      case 'in_transit':
      case 'in transit':
        return Colors.purple;
      case 'delivered':
      case 'completed':
        return Colors.green;
      case 'confirmed':
      case 'pending':
        return Colors.grey;
      case 'cancelled':
        return Colors.red;
      default:
        return isDarkMode ? Colors.grey : Colors.grey.shade600;
    }
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
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month];
  }

  @override
  void dispose() {
    _animationController.dispose();
    _ordersSubscription?.cancel(); // Cancel orders subscription
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
              _buildHeader(isTablet, isDarkMode),
              Expanded(
                child: Container(
                  margin: EdgeInsets.all(isTablet ? 24 : 20),
                  child: Column(
                    children: [
                      _buildFilterTabs(isTablet, isDarkMode),
                      const SizedBox(height: 20),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _refreshOrders,
                          color: isDarkMode
                              ? AppColors.yellowAccent
                              : const Color(0xFF1E88E5),
                          backgroundColor: isDarkMode
                              ? const Color(0xFF2D2D3C)
                              : Colors.white,
                          child: _buildOrdersList(isTablet, isDarkMode),
                        ),
                      ),
                    ],
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
              Row(
                children: [
                  Text(
                    'My Orders',
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 28 : 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Real-time connection indicator
                  if (_isRealTimeConnected)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.wifi,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _refreshOrders(); // Refresh orders using new method
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.refresh,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterTabs(bool isTablet, bool isDarkMode) {
    final filters = ['All', 'Active', 'Completed', 'Cancelled'];

    return SlideTransition(
      position: _slideAnimation,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: filters.map((filter) {
            final isSelected = _selectedFilter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _selectedFilter = filter;
                  });
                },
                child:
                    _buildFilterTab(filter, isSelected, isTablet, isDarkMode),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildFilterTab(
      String title, bool isSelected, bool isTablet, bool isDarkMode) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? (isDarkMode ? AppColors.yellowAccent : const Color(0xFF1E88E5))
            : (isDarkMode ? Colors.white.withOpacity(0.1) : Colors.white),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: isSelected
              ? (isDarkMode ? AppColors.yellowAccent : const Color(0xFF1E88E5))
              : (isDarkMode
                  ? Colors.white.withOpacity(0.2)
                  : Colors.grey.shade300),
          width: 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: isDarkMode
                      ? AppColors.yellowAccent.withOpacity(0.3)
                      : const Color(0xFF1E88E5).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 24 : 20,
          vertical: isTablet ? 12 : 10,
        ),
        child: Text(
          title,
          style: GoogleFonts.albertSans(
            fontSize: isTablet ? 14 : 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? (isDarkMode ? Colors.black : Colors.white)
                : (isDarkMode
                    ? Colors.white.withOpacity(0.7)
                    : Colors.grey.shade600),
          ),
        ),
      ),
    );
  }

  Widget _buildOrdersList(bool isTablet, bool isDarkMode) {
    if (_isLoadingOrders) {
      return _buildLoadingOrders(isTablet, isDarkMode);
    }

    final filteredOrders = _getFilteredOrders();

    if (filteredOrders.isEmpty) {
      return _buildEmptyOrders(isTablet, isDarkMode);
    }

    return SlideTransition(
      position: _slideAnimation,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        itemCount: filteredOrders.length,
        itemBuilder: (context, index) {
          final order = filteredOrders[index];
          return _buildOrderCard(order, isTablet, isDarkMode);
        },
      ),
    );
  }

  Widget _buildLoadingOrders(bool isTablet, bool isDarkMode) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: EdgeInsets.all(isTablet ? 20 : 16),
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
          ),
          child: Column(
            children: [
              Container(
                height: 16,
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 80,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.2)
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  Container(
                    width: 60,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.2)
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyOrders(bool isTablet, bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Lottie animation for no orders
          SizedBox(
            width: isTablet ? 200 : 150,
            height: isTablet ? 200 : 150,
            child: Lottie.asset(
              'assets/animations/noorder.json',
              repeat: true,
              animate: true,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _selectedFilter == 'All'
                ? 'No orders yet'
                : 'No ${_selectedFilter.toLowerCase()} orders',
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 20 : 18,
              fontWeight: FontWeight.w600,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.8)
                  : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFilter == 'All'
                ? 'Your orders will appear here'
                : 'No orders match this filter',
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 14 : 12,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.6)
                  : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(
      Map<String, dynamic> order, bool isTablet, bool isDarkMode) {
    // Safely extract data
    final String orderId = _safeGet<String>(order, 'id', 'N/A') ?? 'N/A';
    final String status =
        _safeGet<String>(order, 'status', 'confirmed') ?? 'confirmed';
    final String orderType =
        _safeGet<String>(order, 'orderType', 'shifting') ?? 'shifting';
    final double totalAmount =
        (_safeGet<num>(order, 'totalAmount', 0) ?? 0).toDouble();
    final dynamic createdAt = order['createdAt'];

    // Get items list
    final List<String> items = _safeGetList(order, 'items');

    // Get pickup and drop locations from nested structure
    final pickupLocationData = order['pickupLocation'] as Map<String, dynamic>?;
    final dropoffLocationData =
        order['dropoffLocation'] as Map<String, dynamic>?;

    final String pickupAddress =
        pickupLocationData?['address']?.toString() ?? 'Pickup location';
    final String dropoffAddress =
        dropoffLocationData?['address']?.toString() ?? 'Drop location';

    final double progressPercentage = _getProgressPercentage(status);
    final Color statusColor = _getStatusColor(status, isDarkMode);

    // Extract city names for the reference UI design
    String fromCity = _extractCityName(pickupAddress);
    String toCity = _extractCityName(dropoffAddress);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: EdgeInsets.all(isTablet ? 20 : 20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isDarkMode
            ? Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              )
            : null,
        boxShadow: isDarkMode
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ID and route section
          Text(
            'ID: ${orderId.length > 8 ? orderId.substring(0, 8).toUpperCase() : orderId.toUpperCase()}',
            style: TextStyle(
              color:
                  isDarkMode ? AppColors.yellowAccent : const Color(0xFF1E88E5),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'From',
                      style: TextStyle(
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.6)
                            : Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      fromCity,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'To',
                      style: TextStyle(
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.6)
                            : Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      toCity,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Progress indicator
          _buildDeliveryProgress(status, progressPercentage, statusColor),

          const SizedBox(height: 20),

          // Service info (replacing product info from reference)
          Row(
            children: [
              // Service icon
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.1)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  orderType.toLowerCase().contains('shifting')
                      ? Icons.local_shipping
                      : Icons.delivery_dining,
                  color: isDarkMode
                      ? AppColors.yellowAccent
                      : const Color(0xFF1E88E5),
                  size: 24,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      orderType.toUpperCase(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      '${items.length} items • ${_formatDate(createdAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.6)
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Rs ${totalAmount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode
                          ? AppColors.yellowAccent
                          : const Color(0xFF1E88E5),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _navigateToTrackScreen(order);
                        },
                        child: Text(
                          'View Details',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDarkMode
                                ? Colors.white.withOpacity(0.8)
                                : Colors.grey[600],
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      // Add message button for active orders
                      if (_isActiveOrder(status)) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _openChatWithDriver(order);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? AppColors.yellowAccent.withOpacity(0.2)
                                  : const Color(0xFF1E88E5).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.message,
                              color: isDarkMode
                                  ? AppColors.yellowAccent
                                  : const Color(0xFF1E88E5),
                              size: 12,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper method to extract city name from address
  String _extractCityName(String address) {
    if (address.isEmpty ||
        address == 'Pickup location' ||
        address == 'Drop location') {
      return 'Unknown';
    }

    // Try to extract city name from address
    List<String> parts = address.split(',');
    if (parts.length >= 2) {
      return parts[parts.length - 2].trim();
    } else if (parts.length == 1) {
      // If single part, take first few words
      List<String> words = parts[0].trim().split(' ');
      return words.take(2).join(' ');
    }

    return 'City';
  }

  // Custom progress widget matching the reference design
  Widget _buildDeliveryProgress(
      String status, double progressPercentage, Color statusColor) {
    final List<String> statusLabels = [
      'Pending',
      'Picked Up',
      'In Transit',
      'Delivered'
    ];

    int currentStatusIndex = 0;
    String normalizedStatus = status.toLowerCase();

    // Map current status to progress index
    if (['delivered', 'completed'].contains(normalizedStatus)) {
      currentStatusIndex = 3;
    } else if (['in_transit', 'in transit'].contains(normalizedStatus)) {
      currentStatusIndex = 2;
    } else if (['picked_up', 'pickedup', 'started']
        .contains(normalizedStatus)) {
      currentStatusIndex = 1;
    } else if (['active', 'confirmed', 'pending'].contains(normalizedStatus)) {
      currentStatusIndex = 0;
    } else {
      currentStatusIndex = 0;
    }

    return Column(
      children: [
        // Progress dots and line
        Row(
          children: List.generate(4, (index) {
            bool isActive = index <= currentStatusIndex;
            bool isLast = index == 3;

            // Line should be green if both current dot and next dot are active
            // For example: if currentStatusIndex = 3 (delivered), then:
            // - Line 0->1 should be green (index 0, next is 1, both <= 3)
            // - Line 1->2 should be green (index 1, next is 2, both <= 3)
            // - Line 2->3 should be green (index 2, next is 3, both <= 3)
            bool shouldLineBeActive =
                !isLast && (index + 1 <= currentStatusIndex);

            return Expanded(
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color:
                          isActive ? const Color(0xFF10B981) : Colors.grey[300],
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: shouldLineBeActive
                            ? const Color(0xFF10B981)
                            : Colors.grey[300],
                      ),
                    ),
                ],
              ),
            );
          }),
        ),

        const SizedBox(height: 8),

        // Status labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(4, (index) {
            bool isActive = index <= currentStatusIndex;
            return Text(
              statusLabels[index],
              style: TextStyle(
                fontSize: 10,
                color: isActive ? const Color(0xFF10B981) : Colors.grey[500],
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            );
          }),
        ),
      ],
    );
  }

  // Navigate to track screen with order details
  void _navigateToTrackScreen(Map<String, dynamic> order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TrackScreen(orderData: order),
      ),
    );
  }

  // Helper method to check if order is active (can message driver)
  bool _isActiveOrder(String status) {
    return [
      'confirmed',
      'started',
      'active',
      'in_progress',
      'in-progress',
      'ongoing',
      'in_transit',
      'pickup_scheduled',
      'picked_up',
    ].contains(status.toLowerCase());
  }

  // Method to open chat with driver
  void _openChatWithDriver(Map<String, dynamic> order) async {
    try {
      final driverId = _safeGet<String>(order, 'driverId');
      final driverName = _safeGet<String>(order, 'driverName') ?? 'Driver';
      final orderId = _safeGet<String>(order, 'id') ?? '';

      if (driverId == null || driverId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No driver assigned to this order yet',
              style: GoogleFonts.albertSans(color: Colors.white),
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }

      // Navigate to chat screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            orderId: orderId,
            otherUserId: driverId,
            otherUserName: driverName,
            isDriverMode: false, // This is user mode
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error opening chat: $e',
            style: GoogleFonts.albertSans(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }
}
