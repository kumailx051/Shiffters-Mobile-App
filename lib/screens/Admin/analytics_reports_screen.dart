import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shiffters/theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:shiffters/services/theme_service.dart';

class AnalyticsReportsScreen extends StatefulWidget {
  const AnalyticsReportsScreen({super.key});

  @override
  State<AnalyticsReportsScreen> createState() => _AnalyticsReportsScreenState();
}

class _AnalyticsReportsScreenState extends State<AnalyticsReportsScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  String _selectedPeriod = 'This Month';

  // Mock analytics data
  final Map<String, dynamic> _analyticsData = {
    'totalRevenue': 2500000.0,
    'totalOrders': 1250,
    'totalUsers': 850,
    'totalDrivers': 145,
    'averageOrderValue': 2000.0,
    'completionRate': 94.5,
    'customerSatisfaction': 4.7,
    'activeUsers': 520,
    'revenueGrowth': 12.5,
    'orderGrowth': 8.3,
    'userGrowth': 15.2,
    'driverGrowth': 6.8,
    'topCities': [
      {'name': 'Karachi', 'orders': 450, 'revenue': 900000.0, 'growth': 15.0},
      {'name': 'Lahore', 'orders': 320, 'revenue': 640000.0, 'growth': 12.0},
      {'name': 'Islamabad', 'orders': 180, 'revenue': 360000.0, 'growth': 18.0},
      {'name': 'Rawalpindi', 'orders': 120, 'revenue': 240000.0, 'growth': 8.0},
      {
        'name': 'Faisalabad',
        'orders': 100,
        'revenue': 200000.0,
        'growth': 10.0
      },
    ],
    'ordersByStatus': {
      'Completed': 850,
      'In Progress': 120,
      'Pending': 180,
      'Cancelled': 100,
    },
    'revenueByMonth': [
      {'month': 'Jan', 'revenue': 180000.0, 'orders': 90},
      {'month': 'Feb', 'revenue': 220000.0, 'orders': 110},
      {'month': 'Mar', 'revenue': 280000.0, 'orders': 140},
      {'month': 'Apr', 'revenue': 320000.0, 'orders': 160},
      {'month': 'May', 'revenue': 380000.0, 'orders': 190},
      {'month': 'Jun', 'revenue': 420000.0, 'orders': 210},
      {'month': 'Jul', 'revenue': 450000.0, 'orders': 225},
    ],
    'driverPerformance': [
      {
        'name': 'Muhammad Ali',
        'rating': 4.9,
        'orders': 89,
        'revenue': 178000.0
      },
      {'name': 'Hassan Khan', 'rating': 4.8, 'orders': 76, 'revenue': 152000.0},
      {
        'name': 'Ahmed Sheikh',
        'rating': 4.7,
        'orders': 65,
        'revenue': 130000.0
      },
      {'name': 'Omar Malik', 'rating': 4.6, 'orders': 58, 'revenue': 116000.0},
      {'name': 'Zain Ahmed', 'rating': 4.5, 'orders': 52, 'revenue': 104000.0},
    ],
    'customerInsights': {
      'newCustomers': 120,
      'returningCustomers': 730,
      'churnRate': 5.2,
      'averageLifetime': 8.5,
      'mostActiveHours': ['2 PM - 4 PM', '6 PM - 8 PM'],
      'popularServices': ['Truck', 'Van', 'Pickup'],
    },
  };

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
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

  @override
  void dispose() {
    _animationController.dispose();
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
          body: SafeArea(
            child: Column(
              children: [
                // Header
                _buildHeader(isTablet, isDarkMode),

                // Content
                Expanded(
                  child: SafeArea(
                    top: false,
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 32 : 20,
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 20),

                            // Overview cards
                            _buildOverviewCards(isTablet, isDarkMode),

                            const SizedBox(height: 20),

                            // Charts section
                            _buildChartsSection(isTablet, isDarkMode),

                            const SizedBox(height: 20),

                            // City performance
                            _buildCityPerformance(isTablet, isDarkMode),

                            const SizedBox(height: 20),

                            // Driver performance
                            _buildDriverPerformance(isTablet, isDarkMode),

                            const SizedBox(height: 20),

                            // Customer insights
                            _buildCustomerInsights(isTablet, isDarkMode),

                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
          padding: EdgeInsets.symmetric(horizontal: isTablet ? 20 : 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Title
              Padding(
                padding: const EdgeInsets.only(left: 10, right: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Analytics & Reports',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 28 : 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Business insights',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 14 : 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              // Period selector
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showPeriodSelector();
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Text(
                          _selectedPeriod,
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 14 : 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.white,
                          size: 16,
                        ),
                      ],
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

  void _showPeriodSelector() {
    // Placeholder for period selection
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Period selection coming soon',
          style: GoogleFonts.albertSans(),
        ),
        backgroundColor: const Color(0xFF1E88E5),
      ),
    );
  }

  Widget _buildOverviewCards(bool isTablet, bool isDarkMode) {
    return SlideTransition(
      position: _slideAnimation,
      child: Column(
        children: [
          // First row
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Total Revenue',
                  'Rs. ${(_analyticsData['totalRevenue'] / 1000000).toStringAsFixed(1)}M',
                  Icons.attach_money,
                  Colors.green,
                  '+${_analyticsData['revenueGrowth']}%',
                  isTablet,
                  isDarkMode,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Total Orders',
                  '${_analyticsData['totalOrders']}',
                  Icons.receipt_long,
                  Colors.blue,
                  '+${_analyticsData['orderGrowth']}%',
                  isTablet,
                  isDarkMode,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Second row
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Total Users',
                  '${_analyticsData['totalUsers']}',
                  Icons.people,
                  Colors.purple,
                  '+${_analyticsData['userGrowth']}%',
                  isTablet,
                  isDarkMode,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Active Drivers',
                  '${_analyticsData['totalDrivers']}',
                  Icons.local_shipping,
                  Colors.orange,
                  '+${_analyticsData['driverGrowth']}%',
                  isTablet,
                  isDarkMode,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Third row
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Avg Order Value',
                  'Rs. ${_analyticsData['averageOrderValue'].toStringAsFixed(0)}',
                  Icons.trending_up,
                  isDarkMode ? AppColors.yellowAccent : AppColors.lightPrimary,
                  '+5.2%',
                  isTablet,
                  isDarkMode,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Completion Rate',
                  '${_analyticsData['completionRate']}%',
                  Icons.check_circle,
                  Colors.green,
                  '+2.1%',
                  isTablet,
                  isDarkMode,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon,
      Color color, String growth, bool isTablet, bool isDarkMode) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 16 : 12),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: color,
                size: isTablet ? 24 : 20,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  growth,
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 10 : 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 20 : 20,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : AppColors.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 12 : 10,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.7)
                  : AppColors.textSecondary,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildChartsSection(bool isTablet, bool isDarkMode) {
    return SlideTransition(
      position: _slideAnimation,
      child: Column(
        children: [
          // Revenue chart
          _buildChartCard(
            'Revenue Trend',
            'Monthly revenue growth',
            _buildRevenueChart(isTablet, isDarkMode),
            isTablet,
            isDarkMode,
          ),

          const SizedBox(height: 16),

          // Orders by status
          _buildChartCard(
            'Order Status Distribution',
            'Current order breakdown',
            _buildOrderStatusChart(isTablet, isDarkMode),
            isTablet,
            isDarkMode,
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(String title, String subtitle, Widget chart,
      bool isTablet, bool isDarkMode) {
    return SingleChildScrollView(
      child: Container(
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
            Text(
              title,
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 18 : 16,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 14 : 12,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.7)
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            chart,
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueChart(bool isTablet, bool isDarkMode) {
    return Container(
      height: isTablet ? 180 : 140,
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _analyticsData['revenueByMonth'].map<Widget>((data) {
                final maxRevenue = _analyticsData['revenueByMonth'].fold(
                    0.0,
                    (max, item) =>
                        item['revenue'] > max ? item['revenue'] : max);
                final heightRatio = data['revenue'] / maxRevenue;

                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final barHeight = constraints.maxHeight * heightRatio;
                        return Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            height: barHeight,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  isDarkMode
                                      ? AppColors.yellowAccent
                                      : AppColors.lightPrimary,
                                  (isDarkMode
                                          ? AppColors.yellowAccent
                                          : AppColors.lightPrimary)
                                      .withOpacity(0.7),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: (isDarkMode
                                          ? AppColors.yellowAccent
                                          : AppColors.lightPrimary)
                                      .withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: _analyticsData['revenueByMonth'].map<Widget>((data) {
              return Expanded(
                child: Text(
                  data['month'],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 12 : 10,
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.7)
                        : AppColors.textSecondary,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderStatusChart(bool isTablet, bool isDarkMode) {
    final statusData = _analyticsData['ordersByStatus'];
    final total = statusData.values.fold(0, (sum, value) => sum + value);

    return Container(
      height: isTablet ? 160 : 120,
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              children: statusData.entries.map<Widget>((entry) {
                final percentage =
                    (entry.value / total * 100).toStringAsFixed(1);
                Color color;
                switch (entry.key) {
                  case 'Completed':
                    color = Colors.green;
                    break;
                  case 'In Progress':
                    color = Colors.blue;
                    break;
                  case 'Pending':
                    color = Colors.orange;
                    break;
                  case 'Cancelled':
                    color = Colors.red;
                    break;
                  default:
                    color = Colors.grey;
                }

                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: color.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            entry.key,
                            style: GoogleFonts.albertSans(
                              fontSize: isTablet ? 14 : 12,
                              color: isDarkMode
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          '$percentage%',
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 14 : 12,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: (isDarkMode
                        ? AppColors.yellowAccent
                        : AppColors.lightPrimary)
                    .withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDarkMode
                      ? AppColors.yellowAccent
                      : AppColors.lightPrimary,
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  '$total\nOrders',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCityPerformance(bool isTablet, bool isDarkMode) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Top Performing Cities',
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                Icon(
                  Icons.location_city,
                  color: isDarkMode
                      ? AppColors.yellowAccent
                      : AppColors.lightPrimary,
                  size: isTablet ? 24 : 20,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Cities with highest order volume',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 14 : 12,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.7)
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            ...(_analyticsData['topCities'] as List).map((city) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                  border: isDarkMode
                      ? Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                          width: 1,
                        )
                      : Border.all(
                          color: AppColors.lightPrimary.withValues(alpha: 0.3),
                          width: 1,
                        ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isDarkMode
                                ? AppColors.yellowAccent
                                : AppColors.lightPrimary)
                            .withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.location_on,
                        color: isDarkMode
                            ? AppColors.yellowAccent
                            : AppColors.lightPrimary,
                        size: isTablet ? 20 : 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            city['name'],
                            style: GoogleFonts.albertSans(
                              fontSize: isTablet ? 16 : 14,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '${city['orders']} orders • Rs. ${(city['revenue'] / 1000).toStringAsFixed(0)}K',
                            style: GoogleFonts.albertSans(
                              fontSize: isTablet ? 12 : 10,
                              color: isDarkMode
                                  ? Colors.white.withValues(alpha: 0.7)
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.green,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '+${city['growth']}%',
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 12 : 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverPerformance(bool isTablet, bool isDarkMode) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Top Performing Drivers',
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                Icon(
                  Icons.local_shipping,
                  color: isDarkMode
                      ? AppColors.yellowAccent
                      : AppColors.lightPrimary,
                  size: isTablet ? 24 : 20,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Drivers with highest ratings and orders',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 14 : 12,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.7)
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            ...(_analyticsData['driverPerformance'] as List).map((driver) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                  border: isDarkMode
                      ? Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                          width: 1,
                        )
                      : Border.all(
                          color: AppColors.lightPrimary.withValues(alpha: 0.3),
                          width: 1,
                        ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: isTablet ? 40 : 32,
                      height: isTablet ? 40 : 32,
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? AppColors.yellowAccent
                            : AppColors.lightPrimary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (isDarkMode
                                    ? AppColors.yellowAccent
                                    : AppColors.lightPrimary)
                                .withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          driver['name'].split(' ').map((n) => n[0]).join(''),
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 14 : 12,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.black : Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            driver['name'],
                            style: GoogleFonts.albertSans(
                              fontSize: isTablet ? 16 : 14,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                          Row(
                            children: [
                              Icon(
                                Icons.star,
                                color: Colors.orange,
                                size: isTablet ? 16 : 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${driver['rating']}',
                                style: GoogleFonts.albertSans(
                                  fontSize: isTablet ? 12 : 10,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '${driver['orders']} orders',
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
                    ),
                    Text(
                      'Rs. ${(driver['revenue'] / 1000).toStringAsFixed(0)}K',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 14 : 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerInsights(bool isTablet, bool isDarkMode) {
    final insights = _analyticsData['customerInsights'];

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Customer Insights',
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                Icon(
                  Icons.insights,
                  color: isDarkMode
                      ? AppColors.yellowAccent
                      : AppColors.lightPrimary,
                  size: isTablet ? 24 : 20,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Customer behavior and preferences',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 14 : 12,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.7)
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildInsightCard(
                    'New Customers',
                    '${insights['newCustomers']}',
                    Icons.person_add,
                    Colors.green,
                    isTablet,
                    isDarkMode,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInsightCard(
                    'Returning',
                    '${insights['returningCustomers']}',
                    Icons.repeat,
                    Colors.blue,
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
                  child: _buildInsightCard(
                    'Churn Rate',
                    '${insights['churnRate']}%',
                    Icons.trending_down,
                    Colors.red,
                    isTablet,
                    isDarkMode,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInsightCard(
                    'Avg Lifetime',
                    '${insights['averageLifetime']} mo',
                    Icons.access_time,
                    Colors.purple,
                    isTablet,
                    isDarkMode,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
                border: isDarkMode
                    ? Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 1,
                      )
                    : Border.all(
                        color: AppColors.lightPrimary.withValues(alpha: 0.3),
                        width: 1,
                      ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Most Active Hours',
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 14 : 12,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    insights['mostActiveHours'].join(', '),
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 12 : 10,
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.7)
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Popular Services',
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 14 : 12,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children:
                        insights['popularServices'].map<Widget>((service) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isDarkMode
                                  ? AppColors.yellowAccent
                                  : AppColors.lightPrimary)
                              .withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDarkMode
                                ? AppColors.yellowAccent
                                : AppColors.lightPrimary,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          service,
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 12 : 10,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode
                                ? AppColors.yellowAccent
                                : AppColors.lightPrimary,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightCard(String title, String value, IconData icon,
      Color color, bool isTablet, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: isDarkMode
            ? Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              )
            : Border.all(
                color: AppColors.lightPrimary.withValues(alpha: 0.3),
                width: 1,
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: color,
            size: isTablet ? 20 : 16,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 18 : 16,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 12 : 10,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.7)
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
