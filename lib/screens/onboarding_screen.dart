import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'welcome_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  int _currentPage = 0;
  bool _isLastPage = false;

  final List<OnboardingData> _onboardingData = [
    OnboardingData(
      title: '🚚 Welcome to SHIFFTERS',
      subtitle: 'Easily manage and track your deliveries with just a few taps.',
      animationPath: 'assets/animations/blueTruck.json',
    ),
    OnboardingData(
      title: '📦 Fast & Secure Shipping',
      subtitle: 'Your packages are delivered safely, on time, every time.',
      animationPath: 'assets/animations/manHat.json',
    ),
    OnboardingData(
      title: '📱 Real-Time Tracking',
      subtitle: 'Stay updated with live location tracking and instant notifications.',
      animationPath: 'assets/animations/truckFactory.json',
    ),
  ];

  @override
  void initState() {
    super.initState();
    
    _pageController = PageController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
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
    
    _animationController.forward();
    
    // Set system UI overlay style
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
      _isLastPage = page == _onboardingData.length - 1;
    });
    
    // Restart animation for new page
    _animationController.reset();
    _animationController.forward();
  }

  void _nextPage() {
    if (_isLastPage) {
      _navigateToHome();
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const WelcomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final isSmallScreen = screenSize.height < 700;
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background/splashScreenBackground.jpg'),
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
        ),
        child: SafeArea(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: _onboardingData.length,
            itemBuilder: (context, index) {
              return _buildOnboardingPage(
                _onboardingData[index],
                screenSize,
                isTablet,
                isSmallScreen,
                index, // Pass the index to identify which page
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildOnboardingPage(
    OnboardingData data,
    Size screenSize,
    bool isTablet,
    bool isSmallScreen,
    int pageIndex, // Add page index parameter
  ) {
    // Use larger size for the first animation (blueTruck.json)
    final animationSize = pageIndex == 0 
        ? _getFirstAnimationSize(screenSize, isTablet, isSmallScreen)
        : _getAnimationSize(screenSize, isTablet, isSmallScreen);
    final buttonSize = isTablet ? 70.0 : 60.0;
    
    return Column(
      children: [
        // Top section with animation - even larger
        Expanded(
          flex: isSmallScreen ? 8 : 9, // Increased animation area
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 30 : 15,
              vertical: isSmallScreen ? 15 : 25,
            ),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Center(
                  child: Container(
                    width: animationSize,
                    height: animationSize,
                    constraints: BoxConstraints(
                      maxWidth: pageIndex == 0 
                          ? (isTablet ? 700 : 550) // Larger max sizes for first animation
                          : (isTablet ? 600 : 480),
                      maxHeight: pageIndex == 0 
                          ? (isTablet ? 700 : 550) // Larger max sizes for first animation
                          : (isTablet ? 600 : 480),
                      minWidth: pageIndex == 0 ? 380 : 320, // Larger min sizes for first animation
                      minHeight: pageIndex == 0 ? 380 : 320,
                    ),
                    child: Lottie.asset(
                      data.animationPath,
                      fit: BoxFit.contain,
                      repeat: true,
                      animate: true,
                      frameRate: FrameRate.max,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        
        // Bottom card section with overlapping button
        Container(
          width: double.infinity,
          margin: EdgeInsets.fromLTRB(
            isTablet ? 24 : 20, // left
            0, // top
            isTablet ? 24 : 20, // right
            buttonSize / 2, // bottom - half button height for overlap
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Main card
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  isTablet ? 32 : 28, // left
                  isTablet ? 28 : 24, // top
                  isTablet ? 32 : 28, // right
                  buttonSize / 2 + (isTablet ? 20 : 16), // bottom - space for overlapping button
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(isTablet ? 24 : 20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      spreadRadius: 0,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 40,
                      spreadRadius: 0,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Page indicators at the top
                    _buildPageIndicators(isTablet),
                    
                    SizedBox(height: isSmallScreen ? 20 : 28),
                    
                    // Title
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Text(
                        data.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: _getTitleFontSize(isTablet, isSmallScreen),
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          height: 1.2,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    
                    SizedBox(height: isSmallScreen ? 12 : 16),
                    
                    // Subtitle
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Text(
                        data.subtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: _getSubtitleFontSize(isTablet, isSmallScreen),
                          color: Colors.grey.shade600,
                          height: 1.5,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Overlapping button at bottom center
              Positioned(
                bottom: -buttonSize / 2,
                left: 0,
                right: 0,
                child: Center(
                  child: _buildOverlappingButton(buttonSize),
                ),
              ),
            ],
          ),
        ),
        
        // Bottom spacing
        SizedBox(height: buttonSize / 2 + (isTablet ? 20 : 16)),
      ],
    );
  }

  Widget _buildPageIndicators(bool isTablet) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _onboardingData.length,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: EdgeInsets.symmetric(horizontal: isTablet ? 4 : 3),
          width: isTablet ? 8 : 6,
          height: isTablet ? 8 : 6,
          decoration: BoxDecoration(
            color: _currentPage == index 
                ? Colors.grey.shade600 // Active dot
                : Colors.grey.shade300, // Inactive dots
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _buildOverlappingButton(double size) {
    return GestureDetector(
      onTap: _nextPage,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFFFC107), // Yellow color matching reference
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFC107).withOpacity(0.4),
              blurRadius: 16,
              spreadRadius: 0,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          Icons.arrow_forward,
          color: Colors.white,
          size: size * 0.4, // Icon size relative to button
        ),
      ),
    );
  }

  // New method for first animation size (blueTruck.json) - larger than others
  double _getFirstAnimationSize(Size screenSize, bool isTablet, bool isSmallScreen) {
    if (isTablet) {
      return screenSize.width * 1.0; // Increased from 0.85
    } else if (isSmallScreen) {
      return screenSize.width * 1.1; // Increased from 0.95
    } else {
      return screenSize.width * 1.15; // Increased from 1.0 - even larger
    }
  }

  // Original method for other animations
  double _getAnimationSize(Size screenSize, bool isTablet, bool isSmallScreen) {
    if (isTablet) {
      return screenSize.width * 0.85; // Original size
    } else if (isSmallScreen) {
      return screenSize.width * 0.95; // Original size
    } else {
      return screenSize.width * 1.0; // Original size
    }
  }

  double _getTitleFontSize(bool isTablet, bool isSmallScreen) {
    if (isTablet) return 28.0;
    if (isSmallScreen) return 20.0;
    return 24.0;
  }

  double _getSubtitleFontSize(bool isTablet, bool isSmallScreen) {
    if (isTablet) return 18.0;
    if (isSmallScreen) return 15.0;
    return 16.0;
  }
}

class OnboardingData {
  final String title;
  final String subtitle;
  final String animationPath;

  OnboardingData({
    required this.title,
    required this.subtitle,
    required this.animationPath,
  });
}