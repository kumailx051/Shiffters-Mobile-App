import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shiffters/theme/app_colors.dart';
import 'package:shiffters/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shiffters/services/theme_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'user_management_screen.dart';
import 'driver_management_screen.dart';
import 'order_management_screen.dart';
import 'support_ticketing_screen.dart';
import 'discount_management_screen.dart';
import 'analytics_reports_screen.dart';
import 'app_settings_screen.dart';
import 'notifications_announcements_screen.dart';
import 'admin_profile_screen.dart';
import '../welcome_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late AnimationController _animationController;
  late AnimationController _cardAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _cardScaleAnimation;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Dashboard data
  Map<String, dynamic> _dashboardData = {
    'totalUsers': 0,
    'activeDrivers': 0,
    'ordersToday': 0,
    'revenueToday': 0.0,
    'pendingApprovals': 0,
    'supportTickets': 0,
  };

  List<Map<String, dynamic>> _recentActivities = [];
  List<Map<String, dynamic>> _aiAlerts = [];
  bool _isLoadingData = true;

  // Navigation index
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
    _loadDashboardData();

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

  Future<void> _loadDashboardData() async {
    try {
      setState(() {
        _isLoadingData = true;
      });

      // Load dashboard statistics
      await Future.wait([
        _loadUserStats(),
        _loadDriverStats(),
        _loadOrderStats(),
        _loadRecentActivities(),
        _loadAIAlerts(),
      ]);

      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
      }
    }
  }

  Future<void> _loadUserStats() async {
    try {
      final usersSnapshot = await _firestore.collection('users').get();
      if (mounted) {
        setState(() {
          _dashboardData['totalUsers'] = usersSnapshot.docs.length;
        });
      }
    } catch (e) {
      debugPrint('Error loading user stats: $e');
    }
  }

  Future<void> _loadDriverStats() async {
    try {
      final driversSnapshot = await _firestore
          .collection('drivers')
          .where('applicationStatus', isEqualTo: 'approved')
          .get();
      if (mounted) {
        setState(() {
          _dashboardData['activeDrivers'] = driversSnapshot.docs.length;
        });
      }
    } catch (e) {
      debugPrint('Error loading driver stats: $e');
    }
  }

  Future<void> _loadOrderStats() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final ordersSnapshot = await _firestore
          .collection('orders')
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();

      double totalRevenue = 0.0;
      for (var doc in ordersSnapshot.docs) {
        final data = doc.data();
        final amount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
        totalRevenue += amount;
      }

      if (mounted) {
        setState(() {
          _dashboardData['ordersToday'] = ordersSnapshot.docs.length;
          _dashboardData['revenueToday'] = totalRevenue;
        });
      }
    } catch (e) {
      debugPrint('Error loading order stats: $e');
    }
  }

  Future<void> _loadRecentActivities() async {
    try {
      // Mock recent activities - replace with actual data loading
      _recentActivities = [
        {
          'type': 'new_order',
          'title': 'New Order Placed',
          'description':
              'Order #SH${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
          'time': '2 minutes ago',
          'icon': Icons.shopping_bag_outlined,
          'color': const Color(0xFF6366F1), // Professional indigo
        },
        {
          'type': 'user_signup',
          'title': 'New User Registration',
          'description': 'User joined the platform',
          'time': '15 minutes ago',
          'icon': Icons.person_add_outlined,
          'color': const Color(0xFF10B981), // Professional emerald
        },
        {
          'type': 'driver_approved',
          'title': 'Driver Application Approved',
          'description': 'New driver approved for service',
          'time': '1 hour ago',
          'icon': Icons.check_circle_outline,
          'color': const Color(0xFF8B5CF6), // Professional violet
        },
        {
          'type': 'payment_received',
          'title': 'Payment Processed',
          'description': 'Payment successfully received',
          'time': '2 hours ago',
          'icon': Icons.payment_outlined,
          'color': const Color(0xFF06B6D4), // Professional cyan
        },
      ];
    } catch (e) {
      debugPrint('Error loading recent activities: $e');
    }
  }

  Future<void> _loadAIAlerts() async {
    try {
      // Mock AI alerts - replace with actual AI analysis
      _aiAlerts = [
        {
          'type': 'warning',
          'title': 'Order Volume Analysis',
          'description': 'Order volume is 15% below average for this time',
          'severity': 'medium',
          'action': 'Review marketing strategies',
        },
        {
          'type': 'success',
          'title': 'Driver Performance',
          'description': 'Average driver rating improved to 4.8 stars',
          'severity': 'low',
          'action': 'Continue current training programs',
        },
        {
          'type': 'info',
          'title': 'Peak Hours Detected',
          'description': 'High demand expected between 2-4 PM today',
          'severity': 'low',
          'action': 'Ensure driver availability',
        },
      ];
    } catch (e) {
      debugPrint('Error loading AI alerts: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _cardAnimationController.dispose();
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
          resizeToAvoidBottomInset: false,
          key: _scaffoldKey,
          backgroundColor:
              isDarkMode ? const Color(0xFF1E1E2C) : const Color(0xFFE8E8F0),
          drawer: _buildDrawer(isTablet, isDarkMode),
          body: IndexedStack(
            index: _selectedIndex,
            children: [
              // Dashboard Screen (index 0)
              SafeArea(
                child: Column(
                  children: [
                    // Header
                    _buildHeader(isTablet, isDarkMode),

                    // Content
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 32 : 20,
                            vertical: isTablet ? 16 : 12,
                          ),
                          child: Column(
                            children: [
                              const SizedBox(height: 20),

                              // Summary cards
                              _buildSummaryCards(isTablet, isDarkMode),

                              const SizedBox(height: 24),

                              // AI Alerts
                              _buildAIAlerts(isTablet, isDarkMode),

                              const SizedBox(height: 24),

                              // Charts row
                              _buildChartsRow(isTablet, isDarkMode),

                              const SizedBox(height: 24),

                              // Recent activity
                              _buildRecentActivity(isTablet, isDarkMode),

                              const SizedBox(height: 24),

                              // Quick actions
                              _buildQuickActions(isTablet, isDarkMode),

                              const SizedBox(height: 100),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // User Management Screen (index 1)
              const UserManagementScreen(),
              // Driver Management Screen (index 2)
              const DriverManagementScreen(),
              // Analytics Screen (index 3)
              const AnalyticsReportsScreen(),
            ],
          ),
          bottomNavigationBar: CurvedNavigationBar(
            key: const ValueKey('admin_bottom_nav'),
            backgroundColor:
                isDarkMode ? const Color(0xFF1E1E2C) : const Color(0xFFE8E8F0),
            color:
                isDarkMode ? const Color(0xFF2D2D3C) : const Color(0xFF1E88E5),
            buttonBackgroundColor:
                isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
            height: 60,
            animationDuration: const Duration(milliseconds: 300),
            animationCurve: Curves.easeInOutCubic,
            index: _selectedIndex,
            onTap: (index) {
              if (!mounted) return;
              HapticFeedback.lightImpact();
              if (mounted) {
                setState(() {
                  _selectedIndex = index;
                });
                _handleBottomNavTap(index);
              }
            },
            items: [
              _buildAdminNavIcon(Icons.dashboard_outlined, 0, isDarkMode),
              _buildAdminNavIcon(Icons.people_outline, 1, isDarkMode),
              _buildAdminNavIcon(Icons.local_shipping_outlined, 2, isDarkMode),
              _buildAdminNavIcon(Icons.analytics_outlined, 3, isDarkMode),
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
                    // Logo/Admin Icon
                    Container(
                      width: isTablet ? 80 : 70,
                      height: isTablet ? 80 : 70,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.admin_panel_settings,
                        color: Colors.white,
                        size: isTablet ? 40 : 35,
                      ),
                    ),
                    const SizedBox(
                      width: 12,
                    ),
                    // Welcome text
                    SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Admin Panel',
                            style: GoogleFonts.albertSans(
                              fontSize: isTablet ? 16 : 14,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                          Text(
                            'Dashboard',
                            style: GoogleFonts.albertSans(
                              fontSize: isTablet ? 28 : 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    // Menu button
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _scaffoldKey.currentState?.openDrawer();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.menu,
                          size: isTablet ? 24 : 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    // Notifications
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _showNotifications();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Stack(
                          children: [
                            Icon(
                              Icons.notifications_outlined,
                              size: isTablet ? 24 : 20,
                              color: Colors.white,
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEF4444),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Profile
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const AdminProfileScreen()),
                        );
                      },
                      child: Container(
                        width: isTablet ? 50 : 45,
                        height: isTablet ? 50 : 45,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                        child: Icon(
                          Icons.person,
                          color: Colors.white,
                          size: isTablet ? 24 : 20,
                        ),
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

  Widget _buildSummaryCards(bool isTablet, bool isDarkMode) {
    return SlideTransition(
      position: _slideAnimation,
      child: ScaleTransition(
        scale: _cardScaleAnimation,
        child: Column(
          children: [
            // First row
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Total Users',
                    _isLoadingData ? '...' : '${_dashboardData['totalUsers']}',
                    Icons.people_outline,
                    const Color(0xFF6366F1), // Professional indigo
                    '+12%',
                    true,
                    isTablet,
                    isDarkMode,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryCard(
                    'Active Drivers',
                    _isLoadingData
                        ? '...'
                        : '${_dashboardData['activeDrivers']}',
                    Icons.local_shipping_outlined,
                    const Color(0xFF10B981), // Professional emerald
                    '+5%',
                    true,
                    isTablet,
                    isDarkMode,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Second row
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Orders Today',
                    _isLoadingData ? '...' : '${_dashboardData['ordersToday']}',
                    Icons.shopping_bag_outlined,
                    const Color(0xFF8B5CF6), // Professional violet
                    '+8%',
                    true,
                    isTablet,
                    isDarkMode,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryCard(
                    'Revenue Today',
                    _isLoadingData
                        ? '...'
                        : 'Rs. ${(_dashboardData['revenueToday'] / 1000).toStringAsFixed(0)}K',
                    Icons.trending_up_outlined,
                    const Color(0xFF06B6D4), // Professional cyan
                    '+15%',
                    true,
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

  Widget _buildSummaryCard(
      String title,
      String value,
      IconData icon,
      Color color,
      String change,
      bool isPositive,
      bool isTablet,
      bool isDarkMode) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 24 : 20),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isDarkMode
            ? Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              )
            : null,
        boxShadow: isDarkMode
            ? null
            : [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: isTablet ? 24 : 20),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (isPositive
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444))
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  change,
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 12 : 10,
                    fontWeight: FontWeight.w600,
                    color: isPositive
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 28 : 24,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : const Color(0xFF111827),
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 14 : 12,
              fontWeight: FontWeight.w500,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.7)
                  : const Color(0xFF6B7280),
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildAIAlerts(bool isTablet, bool isDarkMode) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        padding: EdgeInsets.all(isTablet ? 24 : 20),
        decoration: BoxDecoration(
          color:
              isDarkMode ? Colors.white.withValues(alpha: 0.03) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isDarkMode
              ? Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1,
                )
              : Border.all(
                  color: const Color(0xFFE5E7EB),
                  width: 1,
                ),
          boxShadow: isDarkMode
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: const Color(0xFF6B7280).withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                    spreadRadius: -2,
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: isDarkMode
                      ? AppColors.yellowAccent
                      : const Color(0xFF1E88E5),
                  size: isTablet ? 24 : 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'AI Insights & Alerts',
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : const Color(0xFF111827),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoadingData)
              _buildLoadingAlerts(isTablet, isDarkMode)
            else
              ...List.generate(_aiAlerts.length, (index) {
                final alert = _aiAlerts[index];
                return _buildAIAlert(alert, isTablet, isDarkMode);
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingAlerts(bool isTablet, bool isDarkMode) {
    return Column(
      children: List.generate(
          3,
          (index) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: EdgeInsets.all(isTablet ? 16 : 12),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.2)
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 12,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? Colors.white.withValues(alpha: 0.2)
                                  : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 10,
                            width: double.infinity,
                            constraints: const BoxConstraints(maxWidth: 200),
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
    );
  }

  Widget _buildAIAlert(
      Map<String, dynamic> alert, bool isTablet, bool isDarkMode) {
    Color alertColor;
    IconData alertIcon;
    switch (alert['severity']) {
      case 'high':
        alertColor = const Color(0xFFEF4444); // Professional red
        alertIcon = Icons.warning_outlined;
        break;
      case 'medium':
        alertColor = const Color(0xFFF59E0B); // Professional amber
        alertIcon = Icons.info_outline;
        break;
      default:
        alertColor = const Color(0xFF10B981); // Professional emerald
        alertIcon = Icons.check_circle_outline;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: isDarkMode
            ? alertColor.withValues(alpha: 0.08)
            : alertColor.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: alertColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: alertColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              alertIcon,
              color: alertColor,
              size: isTablet ? 20 : 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert['title'],
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 14 : 12,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  alert['description'],
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 12 : 10,
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.7)
                        : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              _showAlertDetails(alert);
            },
            child: Text(
              'View',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 12 : 10,
                color: alertColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartsRow(bool isTablet, bool isDarkMode) {
    return SlideTransition(
      position: _slideAnimation,
      child: Row(
        children: [
          Expanded(
            child: _buildChartCard(
              'Orders Overview',
              Icons.bar_chart_outlined,
              'Weekly orders trend',
              isTablet,
              isDarkMode,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildChartCard(
              'Revenue Analytics',
              Icons.trending_up_outlined,
              'Monthly revenue growth',
              isTablet,
              isDarkMode,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(String title, IconData icon, String subtitle,
      bool isTablet, bool isDarkMode) {
    return Container(
      height: 200,
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isDarkMode
            ? Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              )
            : null,
        boxShadow: isDarkMode
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF1E88E5).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: isDarkMode
                    ? AppColors.yellowAccent
                    : const Color(0xFF6366F1),
                size: isTablet ? 24 : 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 16 : 14,
                        fontWeight: FontWeight.bold,
                        color:
                            isDarkMode ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 12 : 10,
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.7)
                            : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Chart placeholder
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.03)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.show_chart,
                    size: isTablet ? 48 : 40,
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.3)
                        : const Color(0xFF9CA3AF),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Chart Data',
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 14 : 12,
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.5)
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(bool isTablet, bool isDarkMode) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        padding: EdgeInsets.all(isTablet ? 24 : 20),
        decoration: BoxDecoration(
          color:
              isDarkMode ? Colors.white.withValues(alpha: 0.03) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isDarkMode
              ? Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1,
                )
              : Border.all(
                  color: const Color(0xFFE5E7EB),
                  width: 1,
                ),
          boxShadow: isDarkMode
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: const Color(0xFF6B7280).withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                    spreadRadius: -2,
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.timeline,
                  color: isDarkMode
                      ? AppColors.yellowAccent
                      : const Color(0xFF6366F1),
                  size: isTablet ? 24 : 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Recent Activity',
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    // View all activities
                  },
                  child: Text(
                    'View All',
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 14 : 12,
                      color: isDarkMode
                          ? AppColors.yellowAccent
                          : const Color(0xFF6366F1),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoadingData)
              _buildLoadingActivities(isTablet, isDarkMode)
            else
              ...List.generate(_recentActivities.length, (index) {
                final activity = _recentActivities[index];
                return _buildActivityItem(activity, isTablet, isDarkMode);
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingActivities(bool isTablet, bool isDarkMode) {
    return Column(
      children: List.generate(
          4,
          (index) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: EdgeInsets.all(isTablet ? 16 : 12),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.2)
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 12,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? Colors.white.withValues(alpha: 0.2)
                                  : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 10,
                            width: 150,
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
    );
  }

  Widget _buildActivityItem(
      Map<String, dynamic> activity, bool isTablet, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withValues(alpha: 0.03) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isDarkMode
            ? Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              )
            : Border.all(
                color: const Color(0xFFE5E7EB),
                width: 1,
              ),
        boxShadow: isDarkMode
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF6B7280).withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: activity['color'].withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              activity['icon'],
              color: activity['color'],
              size: isTablet ? 20 : 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity['title'],
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 14 : 12,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : const Color(0xFF111827),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                Text(
                  activity['description'],
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 12 : 10,
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.7)
                        : const Color(0xFF6B7280),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
          Text(
            activity['time'],
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 12 : 10,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.5)
                  : const Color(0xFF9CA3AF),
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(bool isTablet, bool isDarkMode) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        padding: EdgeInsets.all(isTablet ? 24 : 20),
        decoration: BoxDecoration(
          color:
              isDarkMode ? Colors.white.withValues(alpha: 0.03) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isDarkMode
              ? Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1,
                )
              : Border.all(
                  color: const Color(0xFFE5E7EB),
                  width: 1,
                ),
          boxShadow: isDarkMode
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: const Color(0xFF6B7280).withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                    spreadRadius: -2,
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
                      : const Color(0xFF6366F1),
                  size: isTablet ? 24 : 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Quick Actions',
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : const Color(0xFF111827),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionButton(
                    'User Management',
                    Icons.people_outline,
                    const Color(0xFF6366F1), // Professional indigo
                    () {
                      setState(() {
                        _selectedIndex = 1; // Switch to User Management tab
                      });
                    },
                    isTablet,
                    isDarkMode,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionButton(
                    'Driver Management',
                    Icons.local_shipping_outlined,
                    const Color(0xFF10B981), // Professional emerald
                    () {
                      setState(() {
                        _selectedIndex = 2; // Switch to Driver Management tab
                      });
                    },
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
                  child: _buildQuickActionButton(
                    'Orders',
                    Icons.shopping_bag_outlined,
                    const Color(0xFF8B5CF6), // Professional violet
                    () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                const OrderManagementScreen())),
                    isTablet,
                    isDarkMode,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionButton(
                    'Analytics',
                    Icons.analytics_outlined,
                    const Color(0xFF06B6D4), // Professional cyan
                    () {
                      setState(() {
                        _selectedIndex = 3; // Switch to Analytics tab
                      });
                    },
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
                  child: _buildQuickActionButton(
                    'Discounts',
                    Icons.local_offer_outlined,
                    const Color(0xFFF59E0B), // Professional amber
                    () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                const DiscountManagementScreen())),
                    isTablet,
                    isDarkMode,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(), // Empty container for alignment
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton(String title, IconData icon, Color color,
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
              ? color.withValues(alpha: 0.08)
              : color.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: isTablet ? 20 : 18),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 12 : 10,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : const Color(0xFF111827),
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(bool isTablet, bool isDarkMode) {
    return Drawer(
      backgroundColor: isDarkMode ? const Color(0xFF111827) : Colors.white,
      child: Column(
        children: [
          // Header
          Container(
            height: 80,
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
            ),
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: SingleChildScrollView(
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                        child: const Icon(
                          Icons.admin_panel_settings,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Admin Panel',
                              style: GoogleFonts.albertSans(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            Text(
                              'Shiffters Platform',
                              style: GoogleFonts.albertSans(
                                fontSize: 8,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 20,
          ),

          // Menu items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(Icons.dashboard_outlined, 'Dashboard', true,
                    () {}, isDarkMode),
                _buildDrawerItem(Icons.people_outline, 'User Management', false,
                    () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const UserManagementScreen()));
                }, isDarkMode),
                _buildDrawerItem(
                    Icons.local_shipping_outlined, 'Driver Management', false,
                    () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              const DriverManagementScreen()));
                }, isDarkMode),
                _buildDrawerItem(
                    Icons.shopping_bag_outlined, 'Order Management', false, () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const OrderManagementScreen()));
                }, isDarkMode),
                _buildDrawerItem(
                    Icons.local_offer_outlined, 'Discount Management', false,
                    () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              const DiscountManagementScreen()));
                }, isDarkMode),
                _buildDrawerItem(
                    Icons.support_agent_outlined, 'Support & Tickets', false,
                    () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              const SupportTicketingScreen()));
                }, isDarkMode),
                _buildDrawerItem(
                    Icons.analytics_outlined, 'Analytics & Reports', false, () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              const AnalyticsReportsScreen()));
                }, isDarkMode),
                _buildDrawerItem(Icons.settings_outlined, 'App Settings', false,
                    () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const AppSettingsScreen()));
                }, isDarkMode),
                _buildDrawerItem(
                    Icons.notifications_outlined, 'Notifications', false, () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              const NotificationsAnnouncementsScreen()));
                }, isDarkMode),
                const Divider(),
                _buildDrawerItem(
                    Icons.account_circle_outlined, 'Profile', false, () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const AdminProfileScreen()));
                }, isDarkMode),
                _buildDrawerItem(Icons.logout_outlined, 'Logout', false, () {
                  _showLogoutDialog();
                }, isDarkMode),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, bool isSelected,
      VoidCallback onTap, bool isDarkMode) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected
            ? (isDarkMode ? AppColors.yellowAccent : const Color(0xFF6366F1))
            : (isDarkMode
                ? Colors.white.withValues(alpha: 0.7)
                : const Color(0xFF6B7280)),
      ),
      title: Text(
        title,
        style: GoogleFonts.albertSans(
          fontSize: 16,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected
              ? (isDarkMode ? AppColors.yellowAccent : const Color(0xFF6366F1))
              : (isDarkMode ? Colors.white : const Color(0xFF374151)),
        ),
      ),
      selected: isSelected,
      selectedTileColor: isDarkMode
          ? AppColors.yellowAccent.withValues(alpha: 0.08)
          : const Color(0xFF6366F1).withValues(alpha: 0.08),
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.pop(context);
        onTap();
      },
    );
  }

  void _showNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => const NotificationsAnnouncementsScreen()),
    );
  }

  void _showAlertDetails(Map<String, dynamic> alert) {
    final isDarkMode =
        Provider.of<ThemeService>(context, listen: false).isDarkMode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          alert['title'],
          style: GoogleFonts.albertSans(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              alert['description'],
              style: GoogleFonts.albertSans(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.8)
                    : AppTheme.lightTextSecondaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Recommended Action:',
              style: GoogleFonts.albertSans(
                fontWeight: FontWeight.w600,
                color:
                    isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              alert['action'],
              style: GoogleFonts.albertSans(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.8)
                    : AppTheme.lightTextSecondaryColor,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.albertSans(
                color: isDarkMode
                    ? AppColors.yellowAccent
                    : AppTheme.lightPrimaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    final isDarkMode =
        Provider.of<ThemeService>(context, listen: false).isDarkMode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Logout',
          style: GoogleFonts.albertSans(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
          ),
        ),
        content: Text(
          'Are you sure you want to logout?',
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
            onPressed: () {
              Navigator.pop(context);
              // Implement logout functionality
              _performLogout();
            },
            child: Text(
              'Logout',
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

  void _performLogout() async {
    try {
      // Close the dialog first
      Navigator.pop(context);

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Clear auto-login data first
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auto_login', false);
      await prefs.setBool('remember_me', false);
      await prefs.remove('saved_email');
      await prefs.remove('saved_password');
      debugPrint('Auto-login data cleared during logout');

      // Sign out from Firebase
      await _auth.signOut();

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      // Navigate to welcome screen and clear all previous routes
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Error during logout: $e');

      // Close loading dialog if still showing
      if (mounted) {
        Navigator.pop(context);

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error during logout: $e',
              style: GoogleFonts.albertSans(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Widget _buildAdminNavIcon(IconData icon, int index, bool isDarkMode) {
    final isSelected = _selectedIndex == index;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isSelected
            ? (isDarkMode ? Colors.yellow.shade700 : const Color(0xFF1E88E5))
            : Colors.transparent,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 26,
        color: isSelected
            ? (isDarkMode ? Colors.black : Colors.white)
            : Colors.white,
      ),
    );
  }

  void _handleBottomNavTap(int index) {
    // Just update the selected index to switch between screens in IndexedStack
    // No navigation needed as IndexedStack handles the screen switching
  }
}
