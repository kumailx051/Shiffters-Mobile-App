import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'package:shiffters/theme/app_colors.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:shiffters/screens/user/profile_screen.dart';
import 'package:shiffters/screens/user/orders_screen.dart';
import 'package:shiffters/screens/user/track_screen.dart';
import 'package:shiffters/screens/user/addLocation_screen.dart';
import 'package:shiffters/screens/User/chat_bot.dart';
import 'package:shiffters/screens/User/message_screen.dart'; // Added import
import 'package:lottie/lottie.dart';
import 'dart:async';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _popupAnimationController;
  late AnimationController _botPopupController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _popupScaleAnimation;
  late Animation<double> _popupOpacityAnimation;
  late Animation<double> _botPopupOpacity;
  late Animation<Offset> _botPopupSlide;
  late PageController _pageController;
  
  int _selectedIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  
  bool _showBotPopup = false;
  Timer? _botPopupTimer;
  final GlobalKey _menuKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    
    _pageController = PageController();
    _initializeAnimations();
    _startAnimations();
    _startBotPopupTimer();
    
    // Set system UI overlay style for dark theme
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

    _popupAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _botPopupController = AnimationController(
      duration: const Duration(milliseconds: 400),
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

    _popupScaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _popupAnimationController,
      curve: Curves.easeOutBack,
    ));
    
    _popupOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _popupAnimationController,
      curve: Curves.easeOut,
    ));

    _botPopupOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _botPopupController,
      curve: Curves.easeOut,
    ));

    _botPopupSlide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _botPopupController,
      curve: Curves.easeOutBack,
    ));
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      _animationController.forward();
    }
  }

  void _startBotPopupTimer() {
    _botPopupTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showBotPopup = true;
        });
        _botPopupController.forward();
        
        // Hide popup after 3 seconds
        Timer(const Duration(seconds: 3), () {
          if (mounted) {
            _botPopupController.reverse().then((_) {
              if (mounted) {
                setState(() {
                  _showBotPopup = false;
                });
              }
            });
          }
        });
      }
    });
  }

  void _showMenuOptions() {
    final RenderBox renderBox = _menuKey.currentContext!.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx - 150,
        position.dy + 40,
        position.dx,
        position.dy + 200,
      ),
      color: const Color(0xFF2D2D3C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withOpacity(0.2)),
      ),
      items: [
        PopupMenuItem(
          child: Row(
            children: [
              Icon(Icons.drive_eta, color: AppColors.yellowAccent, size: 20),
              const SizedBox(width: 12),
              Text(
                'Become a Driver',
                style: GoogleFonts.albertSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          onTap: () {
            // Handle Become a Driver
            print('Become a Driver tapped');
          },
        ),
        PopupMenuItem(
          child: Row(
            children: [
              Icon(Icons.help_outline, color: AppColors.yellowAccent, size: 20),
              const SizedBox(width: 12),
              Text(
                'Help & Support',
                style: GoogleFonts.albertSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          onTap: () {
            // Handle Help & Support
            print('Help & Support tapped');
          },
        ),
        PopupMenuItem(
          child: Row(
            children: [
              Icon(Icons.quiz_outlined, color: AppColors.yellowAccent, size: 20),
              const SizedBox(width: 12),
              Text(
                'FAQs',
                style: GoogleFonts.albertSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          onTap: () {
            // Handle FAQs
            print('FAQs tapped');
          },
        ),
      ],
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _popupAnimationController.dispose();
    _botPopupController.dispose();
    _pageController.dispose();
    _searchController.dispose();
    _pickupController.dispose();
    _destinationController.dispose();
    _botPopupTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C), // Dark background
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            children: [
              _buildMainContent(),
              const OrdersScreen(),
              const MessageScreen(), // Updated to ChatScreen
              const ProfileScreen(),
            ],
          ),
          
          // AI Bot Animation and Popup
          _buildAIBotWidget(),
        ],
      ),
      bottomNavigationBar: CurvedNavigationBar(
        backgroundColor: const Color(0xFF1E1E2C),
        color: const Color(0xFF2D2D3C),
        buttonBackgroundColor: const Color(0xFF2D2D3C),
        height: 60,
        animationDuration: const Duration(milliseconds: 300),
        index: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        items: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _selectedIndex == 0 ? AppColors.yellowAccent : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.home,
              size: 25,
              color: _selectedIndex == 0 ? Colors.black : Colors.white,
            ),
          ),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _selectedIndex == 1 ? AppColors.yellowAccent : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long,
              size: 25,
              color: _selectedIndex == 1 ? Colors.black : Colors.white,
            ),
          ),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _selectedIndex == 2 ? AppColors.yellowAccent : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline, // This is the chat icon
              size: 25,
              color: _selectedIndex == 2 ? Colors.black : Colors.white,
            ),
          ),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _selectedIndex == 3 ? AppColors.yellowAccent : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person,
              size: 25,
              color: _selectedIndex == 3 ? Colors.black : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIBotWidget() {
    return Positioned(
      bottom: 100,
      right: 20,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Popup Message
          if (_showBotPopup)
            SlideTransition(
              position: _botPopupSlide,
              child: FadeTransition(
                opacity: _botPopupOpacity,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10, right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D2D3C),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.yellowAccent.withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.smart_toy,
                        color: AppColors.yellowAccent,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Shiffters bot ready to help you',
                        style: GoogleFonts.albertSans(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          // AI Bot Animation
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChatBotScreen(),
                ),
              );
            },
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.yellowAccent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.yellowAccent.withOpacity(0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Lottie.asset(
                'assets/animations/aibot.json',
                width: 40,
                height: 40,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    
    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 32 : 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              
              // Header with logo and notification
              _buildHeader(isTablet),
              
              const SizedBox(height: 24),
              
              // Promotional Banner
              _buildPromoBanner(isTablet),
              
              const SizedBox(height: 30),
              
              // Tagline
              _buildTagline(isTablet),
              
              const SizedBox(height: 25),
              
              // Search Bar
              _buildSearchBar(isTablet),
              
              const SizedBox(height: 30),
              
              // Action Buttons
              _buildActionButtons(isTablet),
              
              const SizedBox(height: 30),
              
              // Service Icons
              _buildServiceIcons(isTablet),
              
              const SizedBox(height: 30),
              
              // Package Tracking Section
              _buildPackageTracking(isTablet),
              
              const SizedBox(height: 100), // Space for bottom nav
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
          // Logo and Brand
          Row(
            children: [
              Container(
                width: isTablet ? 40 : 35,
                height: isTablet ? 40 : 35,
                decoration: BoxDecoration(
                  color: AppColors.yellowAccent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.yellowAccent.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.local_shipping,
                  color: Colors.black,
                  size: isTablet ? 24 : 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Speedway',
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 24 : 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          
          // Notification and Menu Icons
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.notifications_outlined,
                  size: isTablet ? 26 : 24,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                key: _menuKey,
                onTap: _showMenuOptions,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.menu,
                    size: isTablet ? 26 : 24,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPromoBanner(bool isTablet) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(isTablet ? 24 : 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.white.withOpacity(0.1),
              Colors.white.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Truck Icon
            Container(
              width: isTablet ? 60 : 50,
              height: isTablet ? 60 : 50,
              decoration: BoxDecoration(
                color: AppColors.yellowAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.local_shipping,
                color: AppColors.yellowAccent,
                size: isTablet ? 30 : 25,
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Speed picks up rapidly.',
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 16 : 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.yellowAccent,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.yellowAccent.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      'First move, 30% off!',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 12 : 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagline(bool isTablet) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Text(
        'Hawk-eye your deliveries with ease!',
        style: GoogleFonts.albertSans(
          fontSize: isTablet ? 20 : 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          shadows: [
            Shadow(
              offset: const Offset(0, 0),
              blurRadius: 10,
              color: AppColors.yellowAccent.withOpacity(0.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isTablet) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextFormField(
          controller: _searchController,
          style: GoogleFonts.albertSans(
            fontSize: isTablet ? 16 : 14,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: 'Search services',
            hintStyle: GoogleFonts.albertSans(
              color: Colors.white.withOpacity(0.6),
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: Colors.white.withOpacity(0.7),
              size: isTablet ? 24 : 20,
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25),
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

  Widget _buildActionButtons(bool isTablet) {
    return SlideTransition(
      position: _slideAnimation,
      child: Row(
        children: [
          // New Track Button - Updated to navigate to TrackScreen
          Expanded(
            child: _buildActionButton(
              icon: Icons.add_location_alt,
              title: 'New Track',
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TrackScreen(),
                  ),
                );
              },
              isTablet: isTablet,
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Order Us Button
          Expanded(
            child: _buildActionButton(
              icon: Icons.shopping_bag_outlined,
              title: 'Order Us',
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _selectedIndex = 1;
                });
                _pageController.animateToPage(
                  1,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              isTablet: isTablet,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required bool isTablet,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: isTablet ? 20 : 16,
          horizontal: isTablet ? 24 : 16,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.yellowAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: AppColors.yellowAccent,
                size: isTablet ? 24 : 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 16 : 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceIcons(bool isTablet) {
    return SlideTransition(
      position: _slideAnimation,
      child: Row(
        children: [
          // Shifting Service
          Expanded(
            child: _buildServiceIcon(
              icon: Icons.move_up,
              title: 'Shifting',
              onTap: () {
                HapticFeedback.lightImpact();
                // Navigate to AddLocationScreen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddLocationScreen(),
                  ),
                );
              },
              isTablet: isTablet,
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Pickup & Drop Service
          Expanded(
            child: _buildServiceIcon(
              icon: Icons.local_shipping_outlined,
              title: 'Pickup & Drop',
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _selectedIndex = 1;
                });
                _pageController.animateToPage(
                  1,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              isTablet: isTablet,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceIcon({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required bool isTablet,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: isTablet ? 24 : 20,
          horizontal: isTablet ? 20 : 16,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Container(
              width: isTablet ? 60 : 50,
              height: isTablet ? 60 : 50,
              decoration: BoxDecoration(
                color: AppColors.yellowAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.yellowAccent.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                icon,
                color: AppColors.yellowAccent,
                size: isTablet ? 28 : 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
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
    );
  }

  Widget _buildPackageTracking(bool isTablet) {
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
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Parcel Peek',
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    // Navigate to TrackScreen instead of changing tab
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TrackScreen(),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.yellowAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.yellowAccent,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Track',
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 12 : 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.yellowAccent,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward,
                          color: AppColors.yellowAccent,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Package Info
            Text(
              'Your',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 14 : 12,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
            Text(
              'Package',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 14 : 12,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '#SH123548',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 16 : 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Progress Bar
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: 0.6,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.yellowAccent,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.yellowAccent.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Location Info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '20 June',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 14 : 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'California, USA',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 12 : 11,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Estimated: 22 June',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 14 : 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'New York, USA',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 12 : 11,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}