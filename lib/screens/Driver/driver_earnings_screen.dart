import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shiffters/theme/app_colors.dart';
import 'package:shiffters/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shiffters/services/theme_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class DriverEarningsScreen extends StatefulWidget {
  final String driverId;

  const DriverEarningsScreen({
    super.key,
    required this.driverId,
  });

  @override
  State<DriverEarningsScreen> createState() => _DriverEarningsScreenState();
}

class _DriverEarningsScreenState extends State<DriverEarningsScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String _selectedPeriod = 'This Month';
  final List<String> _periods = [
    'Today',
    'This Week',
    'This Month',
    'All Time'
  ];

  String _selectedChartType = 'Line';
  final List<String> _chartTypes = ['Line', 'Bar'];

  // Firebase data
  Map<String, Map<String, dynamic>> _earningsData = {};
  List<Map<String, dynamic>> _completedJobs = [];
  List<Map<String, dynamic>> _chartData = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadEarningsData();

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

  Future<void> _loadEarningsData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Get completed orders for this driver
      final ordersQuery = await FirebaseFirestore.instance
          .collection('orders')
          .where('driverId', isEqualTo: widget.driverId)
          .where('status', isEqualTo: 'completed')
          .orderBy('startedAt', descending: true)
          .get();

      final orders = ordersQuery.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
          'startedAt': (data['startedAt'] as Timestamp).toDate(),
        };
      }).toList();

      // Calculate earnings for different periods
      _calculateEarnings(orders);
      _generateChartData(orders);

      // Get recent completed jobs (last 10)
      _completedJobs = orders.take(10).toList();

      setState(() {
        _isLoading = false;
      });

      _startAnimations();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to load earnings data: ${e.toString()}';
      });
    }
  }

  void _calculateEarnings(List<Map<String, dynamic>> orders) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thisWeekStart = today.subtract(Duration(days: now.weekday - 1));
    final thisMonthStart = DateTime(now.year, now.month, 1);

    // Initialize earnings data
    _earningsData = {
      'Today': {'total': 0.0, 'jobs': 0, 'average': 0.0, 'bonus': 0.0},
      'This Week': {'total': 0.0, 'jobs': 0, 'average': 0.0, 'bonus': 0.0},
      'This Month': {'total': 0.0, 'jobs': 0, 'average': 0.0, 'bonus': 0.0},
      'All Time': {'total': 0.0, 'jobs': 0, 'average': 0.0, 'bonus': 0.0},
    };

    for (final order in orders) {
      final startedAt = order['startedAt'] as DateTime;
      final totalAmount = (order['totalAmount'] ?? 0).toDouble();
      final bonus = (order['bonus'] ?? 0).toDouble();

      // All Time
      _earningsData['All Time']!['total'] += totalAmount;
      _earningsData['All Time']!['jobs'] += 1;
      _earningsData['All Time']!['bonus'] += bonus;

      // This Month
      if (startedAt.isAfter(thisMonthStart) ||
          startedAt.isAtSameMomentAs(thisMonthStart)) {
        _earningsData['This Month']!['total'] += totalAmount;
        _earningsData['This Month']!['jobs'] += 1;
        _earningsData['This Month']!['bonus'] += bonus;
      }

      // This Week
      if (startedAt.isAfter(thisWeekStart) ||
          startedAt.isAtSameMomentAs(thisWeekStart)) {
        _earningsData['This Week']!['total'] += totalAmount;
        _earningsData['This Week']!['jobs'] += 1;
        _earningsData['This Week']!['bonus'] += bonus;
      }

      // Today
      if (startedAt.isAfter(today) || startedAt.isAtSameMomentAs(today)) {
        _earningsData['Today']!['total'] += totalAmount;
        _earningsData['Today']!['jobs'] += 1;
        _earningsData['Today']!['bonus'] += bonus;
      }
    }

    // Calculate averages
    for (final period in _earningsData.keys) {
      final data = _earningsData[period]!;
      final jobs = data['jobs'] as int;
      if (jobs > 0) {
        data['average'] = (data['total'] as double) / jobs;
      }
    }
  }

  void _generateChartData(List<Map<String, dynamic>> orders) {
    _chartData.clear();

    if (orders.isEmpty) return;

    final now = DateTime.now();
    Map<String, double> dailyEarnings = {};

    // Generate data based on selected period
    switch (_selectedPeriod) {
      case 'Today':
        // Hourly data for today
        for (int hour = 0; hour < 24; hour++) {
          final hourKey = hour.toString().padLeft(2, '0');
          dailyEarnings[hourKey] = 0.0;
        }

        for (final order in orders) {
          final startedAt = order['startedAt'] as DateTime;
          if (startedAt.day == now.day &&
              startedAt.month == now.month &&
              startedAt.year == now.year) {
            final hourKey = startedAt.hour.toString().padLeft(2, '0');
            dailyEarnings[hourKey] = (dailyEarnings[hourKey] ?? 0) +
                (order['totalAmount'] ?? 0).toDouble();
          }
        }
        break;

      case 'This Week':
        // Daily data for this week
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        for (int i = 0; i < 7; i++) {
          final day = weekStart.add(Duration(days: i));
          final dayKey = DateFormat('EEE').format(day);
          dailyEarnings[dayKey] = 0.0;
        }

        for (final order in orders) {
          final startedAt = order['startedAt'] as DateTime;
          final weekStartCheck = now.subtract(Duration(days: now.weekday - 1));
          if (startedAt.isAfter(weekStartCheck) ||
              startedAt.isAtSameMomentAs(weekStartCheck)) {
            final dayKey = DateFormat('EEE').format(startedAt);
            dailyEarnings[dayKey] = (dailyEarnings[dayKey] ?? 0) +
                (order['totalAmount'] ?? 0).toDouble();
          }
        }
        break;

      case 'This Month':
        // Daily data for this month
        final monthStart = DateTime(now.year, now.month, 1);
        final daysInMonth = DateTime(now.year, now.month + 1, 0).day;

        for (int day = 1; day <= daysInMonth; day++) {
          dailyEarnings[day.toString()] = 0.0;
        }

        for (final order in orders) {
          final startedAt = order['startedAt'] as DateTime;
          if (startedAt.isAfter(monthStart) ||
              startedAt.isAtSameMomentAs(monthStart)) {
            final dayKey = startedAt.day.toString();
            dailyEarnings[dayKey] = (dailyEarnings[dayKey] ?? 0) +
                (order['totalAmount'] ?? 0).toDouble();
          }
        }
        break;

      case 'All Time':
        // Monthly data for all time
        Map<String, double> monthlyEarnings = {};

        for (final order in orders) {
          final startedAt = order['startedAt'] as DateTime;
          final monthKey = DateFormat('MMM yy').format(startedAt);
          monthlyEarnings[monthKey] = (monthlyEarnings[monthKey] ?? 0) +
              (order['totalAmount'] ?? 0).toDouble();
        }

        // Take last 12 months or available data
        final sortedMonths = monthlyEarnings.keys.toList()..sort();
        final recentMonths = sortedMonths.length > 12
            ? sortedMonths.sublist(sortedMonths.length - 12)
            : sortedMonths;

        for (final month in recentMonths) {
          dailyEarnings[month] = monthlyEarnings[month] ?? 0.0;
        }
        break;
    }

    // Convert to chart data format
    int index = 0;
    for (final entry in dailyEarnings.entries) {
      _chartData.add({
        'x': index.toDouble(),
        'y': entry.value,
        'label': entry.key,
      });
      index++;
    }
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
          backgroundColor: isDarkMode
              ? const Color(0xFF1E1E2C)
              : AppTheme.lightBackgroundColor,
          appBar: null,
          body: Column(
            children: [
              // Header with gradient background like dashboard
              Container(
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
                    padding:
                        EdgeInsets.symmetric(horizontal: isTablet ? 20 : 16),
                    child: Row(
                      children: [
                        // Back button
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Title
                        Text(
                          'Earnings & History',
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 24 : 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _downloadStatement();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.download,
                              size: isTablet ? 24 : 22,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Content
              Expanded(
                child: SafeArea(
                  top: false,
                  child: _isLoading
                      ? _buildLoadingState(isDarkMode)
                      : _error != null
                          ? _buildErrorState(isTablet, isDarkMode)
                          : RefreshIndicator(
                              onRefresh: _loadEarningsData,
                              child: SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isTablet ? 32 : 20,
                                  ),
                                  child: Column(
                                    children: [
                                      const SizedBox(height: 24),

                                      // Period tabs
                                      _buildPeriodTabs(isTablet, isDarkMode),

                                      const SizedBox(height: 24),

                                      // Earnings summary
                                      _buildEarningsSummary(
                                          isTablet, isDarkMode),

                                      const SizedBox(height: 24),

                                      _buildEarningsChart(isTablet, isDarkMode),

                                      const SizedBox(height: 24),

                                      // Completed jobs
                                      if (_completedJobs.isNotEmpty)
                                        _buildCompletedJobs(
                                            isTablet, isDarkMode),

                                      const SizedBox(height: 100),
                                    ],
                                  ),
                                ),
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

  Widget _buildLoadingState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              isDarkMode ? AppColors.yellowAccent : AppTheme.lightPrimaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading earnings data...',
            style: GoogleFonts.albertSans(
              fontSize: 16,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.7)
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isTablet, bool isDarkMode) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 32 : 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: isTablet ? 80 : 64,
              color: Colors.red.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              'Error Loading Data',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 24 : 20,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error occurred',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 16 : 14,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.7)
                    : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadEarningsData,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDarkMode
                    ? AppColors.yellowAccent
                    : AppTheme.lightPrimaryColor,
                foregroundColor: isDarkMode ? Colors.black : Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 32 : 24,
                  vertical: isTablet ? 16 : 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Retry',
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 16 : 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Header is now implemented inline in the build method

  Widget _buildPeriodTabs(bool isTablet, bool isDarkMode) {
    return SlideTransition(
      position: _slideAnimation,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: _periods.map((period) {
            final isSelected = _selectedPeriod == period;
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _selectedPeriod = period;
                    _generateChartData(_completedJobs);
                  });
                },
                child:
                    _buildPeriodTab(period, isSelected, isTablet, isDarkMode),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPeriodTab(
      String title, bool isSelected, bool isTablet, bool isDarkMode) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(50),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? (isDarkMode
                  ? AppColors.yellowAccent
                  : AppTheme.lightPrimaryColor)
              : isDarkMode
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.withValues(alpha: 0.1),
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
                        ? AppColors.yellowAccent.withValues(alpha: 0.4)
                        : AppTheme.lightPrimaryColor.withValues(alpha: 0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                    spreadRadius: 1,
                  ),
                ]
              : null,
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
                  ? Colors.white
                  : isDarkMode
                      ? Colors.white.withValues(alpha: 0.7)
                      : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEarningsSummary(bool isTablet, bool isDarkMode) {
    final data = _earningsData[_selectedPeriod] ??
        {'total': 0.0, 'jobs': 0, 'average': 0.0, 'bonus': 0.0};

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
            // Total earnings
            Center(
              child: Column(
                children: [
                  Text(
                    'Total Earnings',
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 16 : 14,
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.7)
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Rs. ${data['total'].toStringAsFixed(0)}',
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 36 : 32,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode
                          ? AppColors.yellowAccent
                          : AppTheme.lightPrimaryColor,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Stats row
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Jobs Completed',
                    '${data['jobs']}',
                    Icons.work,
                    Colors.green,
                    isTablet,
                    isDarkMode,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Average',
                    'Rs. ${data['average'].toStringAsFixed(0)}',
                    Icons.trending_up,
                    Colors.blue,
                    isTablet,
                    isDarkMode,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Bonus',
                    'Rs. ${data['bonus'].toStringAsFixed(0)}',
                    Icons.star,
                    Colors.orange,
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

  Widget _buildEarningsChart(bool isTablet, bool isDarkMode) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        height: 300,
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
            // Chart header with type selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.bar_chart,
                      color: isDarkMode
                          ? AppColors.yellowAccent
                          : AppTheme.lightPrimaryColor,
                      size: isTablet ? 24 : 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Earnings Trend',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 18 : 16,
                        fontWeight: FontWeight.bold,
                        color:
                            isDarkMode ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                // Chart type selector
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: _chartTypes.map((type) {
                      final isSelected = _selectedChartType == type;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            _selectedChartType = type;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDarkMode
                                    ? AppColors.yellowAccent
                                    : AppTheme.lightPrimaryColor)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            type,
                            style: GoogleFonts.albertSans(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? (isDarkMode ? Colors.black : Colors.white)
                                  : (isDarkMode
                                      ? Colors.white.withValues(alpha: 0.7)
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

            const SizedBox(height: 20),

            // Chart
            Expanded(
              child: _chartData.isEmpty
                  ? _buildEmptyChart(isTablet, isDarkMode)
                  : _selectedChartType == 'Line'
                      ? _buildLineChart(isDarkMode)
                      : _buildBarChart(isDarkMode),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyChart(bool isTablet, bool isDarkMode) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: isDarkMode
            ? Border.all(color: Colors.white.withValues(alpha: 0.1))
            : Border.all(color: AppTheme.lightPrimaryColor, width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.show_chart,
            size: isTablet ? 60 : 48,
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.3)
                : AppColors.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 8),
          Text(
            'No Data Available',
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 16 : 14,
              fontWeight: FontWeight.w600,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.7)
                  : AppColors.textSecondary,
            ),
          ),
          Text(
            'Complete some orders to see your earnings trend',
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 12 : 10,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.5)
                  : AppColors.textSecondary.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart(bool isDarkMode) {
    final maxY = _chartData.isEmpty
        ? 100.0
        : _chartData
            .map((e) => e['y'] as double)
            .reduce((a, b) => a > b ? a : b);

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: maxY / 5,
          verticalInterval: 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.3),
              strokeWidth: 1,
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.3),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (double value, TitleMeta meta) {
                final index = value.toInt();
                if (index >= 0 && index < _chartData.length) {
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      _chartData[index]['label'],
                      style: GoogleFonts.albertSans(
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.7)
                            : AppColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  );
                }
                return Container();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: maxY / 5,
              reservedSize: 42,
              getTitlesWidget: (double value, TitleMeta meta) {
                return Text(
                  'Rs.${value.toInt()}',
                  style: GoogleFonts.albertSans(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.7)
                        : AppColors.textSecondary,
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.2)
                : Colors.grey.withValues(alpha: 0.3),
          ),
        ),
        minX: 0,
        maxX: (_chartData.length - 1).toDouble(),
        minY: 0,
        maxY: maxY * 1.2,
        lineBarsData: [
          LineChartBarData(
            spots: _chartData
                .map((data) => FlSpot(data['x'] as double, data['y'] as double))
                .toList(),
            isCurved: true,
            gradient: LinearGradient(
              colors: [
                isDarkMode
                    ? AppColors.yellowAccent
                    : AppTheme.lightPrimaryColor,
                isDarkMode
                    ? AppColors.yellowAccent.withValues(alpha: 0.7)
                    : AppTheme.lightPrimaryColor.withValues(alpha: 0.7),
              ],
            ),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  isDarkMode
                      ? AppColors.yellowAccent.withValues(alpha: 0.3)
                      : AppTheme.lightPrimaryColor.withValues(alpha: 0.3),
                  isDarkMode
                      ? AppColors.yellowAccent.withValues(alpha: 0.1)
                      : AppTheme.lightPrimaryColor.withValues(alpha: 0.1),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) =>
                isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
            getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
              return touchedBarSpots.map((barSpot) {
                final index = barSpot.x.toInt();
                final label =
                    index < _chartData.length ? _chartData[index]['label'] : '';
                return LineTooltipItem(
                  '$label\nRs.${barSpot.y.toStringAsFixed(0)}',
                  GoogleFonts.albertSans(
                    color: isDarkMode ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBarChart(bool isDarkMode) {
    final maxY = _chartData.isEmpty
        ? 100.0
        : _chartData
            .map((e) => e['y'] as double)
            .reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY * 1.2,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) =>
                isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final label = groupIndex < _chartData.length
                  ? _chartData[groupIndex]['label']
                  : '';
              return BarTooltipItem(
                '$label\nRs.${rod.toY.toStringAsFixed(0)}',
                GoogleFonts.albertSans(
                  color: isDarkMode ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                final index = value.toInt();
                if (index >= 0 && index < _chartData.length) {
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      _chartData[index]['label'],
                      style: GoogleFonts.albertSans(
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.7)
                            : AppColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  );
                }
                return Container();
              },
              reservedSize: 38,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              interval: maxY / 5,
              getTitlesWidget: (double value, TitleMeta meta) {
                return Text(
                  'Rs.${value.toInt()}',
                  style: GoogleFonts.albertSans(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.7)
                        : AppColors.textSecondary,
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: false,
        ),
        barGroups: _chartData.asMap().entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: entry.value['y'] as double,
                gradient: LinearGradient(
                  colors: [
                    isDarkMode
                        ? AppColors.yellowAccent
                        : AppTheme.lightPrimaryColor,
                    isDarkMode
                        ? AppColors.yellowAccent.withValues(alpha: 0.7)
                        : AppTheme.lightPrimaryColor.withValues(alpha: 0.7),
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                width: 16,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
        gridData: FlGridData(
          show: true,
          drawHorizontalLine: true,
          horizontalInterval: maxY / 5,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.3),
              strokeWidth: 1,
            );
          },
        ),
      ),
    );
  }

  Widget _buildCompletedJobs(bool isTablet, bool isDarkMode) {
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
                  Icons.history,
                  color: isDarkMode
                      ? AppColors.yellowAccent
                      : AppTheme.lightPrimaryColor,
                  size: isTablet ? 24 : 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Recent Completed Jobs',
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Jobs list
            if (_completedJobs.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.work_off,
                        size: isTablet ? 60 : 48,
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.3)
                            : AppColors.textSecondary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No completed jobs yet',
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 16 : 14,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.7)
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...List.generate(_completedJobs.length, (index) {
                final job = _completedJobs[index];
                return _buildJobCard(job, isTablet, isDarkMode);
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color,
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
        ],
      ),
    );
  }

  Widget _buildJobCard(
      Map<String, dynamic> job, bool isTablet, bool isDarkMode) {
    final startedAt = job['startedAt'] as DateTime;
    final formattedDate = DateFormat('MMM dd, yyyy').format(startedAt);
    final formattedTime = DateFormat('h:mm a').format(startedAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Row(
        children: [
          // Job icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? AppColors.yellowAccent.withValues(alpha: 0.2)
                  : AppTheme.lightPrimaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.work,
              color: isDarkMode
                  ? AppColors.yellowAccent
                  : AppTheme.lightPrimaryColor,
              size: isTablet ? 20 : 18,
            ),
          ),

          const SizedBox(width: 12),

          // Job details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order #${job['id'].substring(0, 8)}',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 14 : 12,
                        fontWeight: FontWeight.bold,
                        color:
                            isDarkMode ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Rs. ${(job['totalAmount'] ?? 0).toStringAsFixed(0)}',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 14 : 12,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode
                            ? AppColors.yellowAccent
                            : AppTheme.lightPrimaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${job['contactName'] ?? 'Customer'} • $formattedDate • $formattedTime',
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 12 : 10,
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.7)
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: Colors.blue,
                      size: isTablet ? 16 : 14,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        job['dropoffLocation']?['address'] ??
                            'Location not available',
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 12 : 10,
                          fontWeight: FontWeight.w500,
                          color:
                              isDarkMode ? Colors.white : AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if ((job['bonus'] ?? 0) > 0) ...[
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green, width: 1),
                        ),
                        child: Text(
                          '+Rs. ${(job['bonus'] ?? 0).toStringAsFixed(0)}',
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 10 : 8,
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _downloadStatement() {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isDarkMode = themeService.isDarkMode;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Statement download started',
          style: GoogleFonts.albertSans(
            fontWeight: FontWeight.w500,
            color: Colors.white,
            shadows: [
              Shadow(
                offset: const Offset(0, 0),
                blurRadius: 10,
                color: Colors.white.withValues(alpha: 0.8),
              ),
              Shadow(
                offset: const Offset(0, 0),
                blurRadius: 20,
                color: Colors.white.withValues(alpha: 0.6),
              ),
              Shadow(
                offset: const Offset(0, 0),
                blurRadius: 30,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
        backgroundColor:
            isDarkMode ? AppColors.yellowAccent : AppTheme.lightPrimaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
