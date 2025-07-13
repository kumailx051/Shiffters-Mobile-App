import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shiffters/theme/app_colors.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 32 : 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              
              // Header
              _buildHeader(isTablet),
              
              const SizedBox(height: 30),
              
              // Filter Tabs
              _buildFilterTabs(isTablet),
              
              const SizedBox(height: 20),
              
              // Orders List
              Expanded(
                child: _buildOrdersList(isTablet),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isTablet) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'My Orders',
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 28 : 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.filter_list,
              size: isTablet ? 26 : 24,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs(bool isTablet) {
    return SlideTransition(
      position: _slideAnimation,
      child: Row(
        children: [
          _buildFilterTab('All', true, isTablet),
          const SizedBox(width: 12),
          _buildFilterTab('Active', false, isTablet),
          const SizedBox(width: 12),
          _buildFilterTab('Completed', false, isTablet),
          const SizedBox(width: 12),
          _buildFilterTab('Cancelled', false, isTablet),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String title, bool isSelected, bool isTablet) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 20 : 16,
        vertical: isTablet ? 12 : 10,
      ),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.yellowAccent : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: isSelected ? AppColors.yellowAccent : Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Text(
        title,
        style: GoogleFonts.albertSans(
          fontSize: isTablet ? 14 : 12,
          fontWeight: FontWeight.w600,
          color: isSelected ? Colors.black : Colors.white.withOpacity(0.8),
        ),
      ),
    );
  }

  Widget _buildOrdersList(bool isTablet) {
    return SlideTransition(
      position: _slideAnimation,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        itemCount: 8,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: EdgeInsets.all(isTablet ? 20 : 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order #SH12354${index + 1}',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 16 : 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(index).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getStatusText(index),
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 12 : 10,
                          fontWeight: FontWeight.w600,
                          color: _getStatusColor(index),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: isTablet ? 18 : 16,
                      color: Colors.white.withOpacity(0.6),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'From: ${_getFromLocation(index)}',
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 14 : 12,
                          color: Colors.white.withOpacity(0.7),
                        ),
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
                      color: AppColors.yellowAccent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'To: ${_getToLocation(index)}',
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 14 : 12,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'June ${20 + index}, 2024',
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 12 : 11,
                            color: Colors.white.withOpacity(0.6),
                          ),
                        ),
                        Text(
                          '${_getItemCount(index)} items',
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 12 : 11,
                            color: Colors.white.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${(45 + index * 5)}.00',
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 16 : 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.yellowAccent,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            // Handle view details
                          },
                          child: Text(
                            'View Details',
                            style: GoogleFonts.albertSans(
                              fontSize: isTablet ? 12 : 11,
                              color: Colors.white.withOpacity(0.8),
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(int index) {
    switch (index % 4) {
      case 0:
        return AppColors.yellowAccent;
      case 1:
        return Colors.green;
      case 2:
        return Colors.blue;
      case 3:
        return Colors.red;
      default:
        return AppColors.yellowAccent;
    }
  }

  String _getStatusText(int index) {
    switch (index % 4) {
      case 0:
        return 'In Transit';
      case 1:
        return 'Delivered';
      case 2:
        return 'Picked Up';
      case 3:
        return 'Cancelled';
      default:
        return 'In Transit';
    }
  }

  String _getFromLocation(int index) {
    final locations = [
      'New York, NY',
      'Los Angeles, CA',
      'Chicago, IL',
      'Houston, TX',
      'Phoenix, AZ',
      'Philadelphia, PA',
      'San Antonio, TX',
      'San Diego, CA',
    ];
    return locations[index % locations.length];
  }

  String _getToLocation(int index) {
    final locations = [
      'Miami, FL',
      'Boston, MA',
      'Seattle, WA',
      'Denver, CO',
      'Atlanta, GA',
      'Las Vegas, NV',
      'Portland, OR',
      'Nashville, TN',
    ];
    return locations[index % locations.length];
  }

  int _getItemCount(int index) {
    return 5 + (index % 10);
  }
}
