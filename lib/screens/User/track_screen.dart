import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shiffters/theme/app_colors.dart';

class TrackScreen extends StatefulWidget {
  const TrackScreen({super.key});

  @override
  State<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends State<TrackScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  final TextEditingController _trackingController = TextEditingController();

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
    _trackingController.dispose();
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
              
              // Search Bar
              _buildSearchBar(isTablet),
              
              const SizedBox(height: 30),
              
              // Current Package Tracking
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      _buildCurrentTracking(isTablet),
                      const SizedBox(height: 24),
                      _buildRecentTracking(isTablet),
                    ],
                  ),
                ),
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
            'Track Package',
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
              Icons.qr_code_scanner,
              size: isTablet ? 26 : 24,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isTablet) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextFormField(
          controller: _trackingController,
          style: GoogleFonts.albertSans(
            fontSize: isTablet ? 16 : 14,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: 'Enter tracking number',
            hintStyle: GoogleFonts.albertSans(
              color: Colors.white.withOpacity(0.6),
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: Colors.white.withOpacity(0.7),
              size: isTablet ? 24 : 20,
            ),
            suffixIcon: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                // Handle search
              },
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.yellowAccent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.arrow_forward,
                  color: Colors.black,
                  size: isTablet ? 20 : 18,
                ),
              ),
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: AppColors.yellowAccent,
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

  Widget _buildCurrentTracking(bool isTablet) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(isTablet ? 24 : 20),
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
                  'Package #SH123548',
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.yellowAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.yellowAccent),
                  ),
                  child: Text(
                    'In Transit',
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 12 : 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.yellowAccent,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Tracking Steps
            _buildTrackingStep(
              title: 'Package Picked Up',
              subtitle: 'California, USA',
              time: 'June 20, 10:30 AM',
              isCompleted: true,
              isTablet: isTablet,
            ),
            
            _buildTrackingStep(
              title: 'In Transit',
              subtitle: 'Phoenix, AZ',
              time: 'June 21, 2:15 PM',
              isCompleted: true,
              isTablet: isTablet,
            ),
            
            _buildTrackingStep(
              title: 'Out for Delivery',
              subtitle: 'New York, NY',
              time: 'June 22, 8:00 AM',
              isCompleted: false,
              isTablet: isTablet,
            ),
            
            _buildTrackingStep(
              title: 'Delivered',
              subtitle: 'New York, NY',
              time: 'Estimated: June 22, 5:00 PM',
              isCompleted: false,
              isTablet: isTablet,
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingStep({
    required String title,
    required String subtitle,
    required String time,
    required bool isCompleted,
    required bool isTablet,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isCompleted ? AppColors.yellowAccent : Colors.white.withOpacity(0.3),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCompleted ? AppColors.yellowAccent : Colors.white.withOpacity(0.5),
                  width: 2,
                ),
              ),
              child: isCompleted
                  ? Icon(
                      Icons.check,
                      size: 12,
                      color: Colors.black,
                    )
                  : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: isCompleted ? AppColors.yellowAccent : Colors.white.withOpacity(0.3),
              ),
          ],
        ),
        
        const SizedBox(width: 16),
        
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 16 : 14,
                  fontWeight: FontWeight.w600,
                  color: isCompleted ? Colors.white : Colors.white.withOpacity(0.7),
                ),
              ),
              
              const SizedBox(height: 4),
              
              Text(
                subtitle,
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 14 : 12,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
              
              const SizedBox(height: 2),
              
              Text(
                time,
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 12 : 11,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
              
              if (!isLast) const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentTracking(bool isTablet) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(isTablet ? 24 : 20),
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
            Text(
              'Recent Packages',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 18 : 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            
            const SizedBox(height: 16),
            
            ...List.generate(3, (index) => _buildRecentItem(
              packageId: 'SH12354${index + 2}',
              status: index == 0 ? 'Delivered' : 'In Transit',
              statusColor: index == 0 ? Colors.green : AppColors.yellowAccent,
              date: 'June ${18 + index}, 2024',
              isTablet: isTablet,
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentItem({
    required String packageId,
    required String status,
    required Color statusColor,
    required String date,
    required bool isTablet,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.local_shipping_outlined,
              color: statusColor,
              size: 20,
            ),
          ),
          
          const SizedBox(width: 12),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Package #$packageId',
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 14 : 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  date,
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 12 : 11,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 10 : 9,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
