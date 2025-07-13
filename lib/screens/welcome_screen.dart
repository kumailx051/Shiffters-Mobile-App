import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import 'package:shiffters/screens/auth/createAccount_screen.dart';
import 'package:shiffters/screens/auth/login_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _buttonAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _buttonScaleAnimation;
  
  bool _animationsStarted = false;

  @override
  void initState() {
    super.initState();
    
    _initializeAnimations();
    _startAnimations();
    
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

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _buttonAnimationController = AnimationController(
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
    
    _buttonScaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _buttonAnimationController,
      curve: Curves.elasticOut,
    ));
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      _animationController.forward();
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        _buttonAnimationController.forward();
        setState(() {
          _animationsStarted = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _buttonAnimationController.dispose();
    super.dispose();
  }

  void _onCreateAccountPressed() {
    // Add haptic feedback
    HapticFeedback.lightImpact();
    // Navigate to create account screen
    Navigator.push(context, MaterialPageRoute(builder: (context) => CreateAccountScreen()));
    print('Create Account pressed');
  }

  void _onLoginPressed() {
    // Add haptic feedback
    HapticFeedback.lightImpact();
    // Navigate to login screen
    Navigator.push(context, MaterialPageRoute(builder: (context) => LoginScreen()));
    print('Login pressed');
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final isSmallScreen = screenSize.height < 700;
    final isLargeScreen = screenSize.height > 900;
    
    return Scaffold(
      body: Container(
        // Fix background coverage issue
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background/splashScreenBackground.jpg'),
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
            alignment: Alignment.center, // Center the image
          ),
        ),
        child: Container(
          // Add gradient overlay to ensure text visibility
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.1),
                Colors.black.withOpacity(0.05),
                Colors.black.withOpacity(0.1),
              ],
            ),
          ),
          child: SafeArea(
            child: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: screenSize.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
                    minWidth: screenSize.width,
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 40 : 24,
                      vertical: isSmallScreen ? 20 : 32,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Top section with title and subtitle
                        _buildHeaderSection(isTablet, isSmallScreen),
                        
                        // Middle section with animation
                        _buildAnimationSection(screenSize, isTablet, isSmallScreen, isLargeScreen),
                        
                        // Bottom section with buttons
                        _buildButtonSection(isTablet, isSmallScreen),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection(bool isTablet, bool isSmallScreen) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Column(
          children: [
            // Main title with glowing effect
            Text(
              'SHIFFTERS',
              textAlign: TextAlign.center,
              style: GoogleFonts.albertSans(
                fontSize: _getTitleFontSize(isTablet, isSmallScreen),
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2.0,
                shadows: [
                  // Glowing effect - multiple shadows for better glow
                  Shadow(
                    offset: const Offset(0, 0),
                    blurRadius: 20,
                    color: Colors.white.withOpacity(0.8),
                  ),
                  Shadow(
                    offset: const Offset(0, 0),
                    blurRadius: 40,
                    color: Colors.white.withOpacity(0.6),
                  ),
                  Shadow(
                    offset: const Offset(0, 0),
                    blurRadius: 60,
                    color: Colors.white.withOpacity(0.4),
                  ),
                  // Regular shadows for depth
                  Shadow(
                    offset: const Offset(0, 2),
                    blurRadius: 8,
                    color: Colors.black.withOpacity(0.3),
                  ),
                  Shadow(
                    offset: const Offset(0, 4),
                    blurRadius: 16,
                    color: Colors.black.withOpacity(0.2),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: isSmallScreen ? 8 : 12),
            
            // Subtitle with glowing effect
            Text(
              'Lets Relocate',
              textAlign: TextAlign.center,
              style: GoogleFonts.albertSans(
                fontSize: _getSubtitleFontSize(isTablet, isSmallScreen),
                fontWeight: FontWeight.w500,
                color: Colors.white,
                letterSpacing: 0.5,
                shadows: [
                  // Glowing effect for subtitle
                  Shadow(
                    offset: const Offset(0, 0),
                    blurRadius: 15,
                    color: Colors.white.withOpacity(0.7),
                  ),
                  Shadow(
                    offset: const Offset(0, 0),
                    blurRadius: 30,
                    color: Colors.white.withOpacity(0.5),
                  ),
                  Shadow(
                    offset: const Offset(0, 0),
                    blurRadius: 45,
                    color: Colors.white.withOpacity(0.3),
                  ),
                  // Regular shadow for depth
                  Shadow(
                    offset: const Offset(0, 1),
                    blurRadius: 4,
                    color: Colors.black.withOpacity(0.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimationSection(Size screenSize, bool isTablet, bool isSmallScreen, bool isLargeScreen) {
    final animationSize = _getAnimationSize(screenSize, isTablet, isSmallScreen, isLargeScreen);
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        width: animationSize,
        height: animationSize,
        constraints: BoxConstraints(
          maxWidth: isTablet ? 500 : 400,
          maxHeight: isTablet ? 500 : 400,
          minWidth: isSmallScreen ? 280 : 320,
          minHeight: isSmallScreen ? 280 : 320,
        ),
        child: Lottie.asset(
          'assets/animations/manWithTruck.json',
          fit: BoxFit.contain,
          repeat: true,
          animate: _animationsStarted,
          frameRate: FrameRate.max,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }

  Widget _buildButtonSection(bool isTablet, bool isSmallScreen) {
    final buttonWidth = isTablet ? 320.0 : 280.0;
    final buttonHeight = isTablet ? 56.0 : 52.0;
    
    return ScaleTransition(
      scale: _buttonScaleAnimation,
      child: Column(
        children: [
          // Create Account Button (Glowing Yellow)
          _buildCreateAccountButton(buttonWidth, buttonHeight, isTablet, isSmallScreen),
          
          SizedBox(height: isSmallScreen ? 16 : 20),
          
          // Login Button (White with black text)
          _buildLoginButton(buttonWidth, buttonHeight, isTablet, isSmallScreen),
        ],
      ),
    );
  }

  Widget _buildCreateAccountButton(double width, double height, bool isTablet, bool isSmallScreen) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isTablet ? 18 : 16),
        boxShadow: [
          // Glowing effect
          BoxShadow(
            color: AppColors.yellowAccent.withOpacity(0.6),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AppColors.yellowAccent.withOpacity(0.3),
            blurRadius: 40,
            spreadRadius: 0,
            offset: const Offset(0, 16),
          ),
          // Regular shadow
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _onCreateAccountPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.yellowAccent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isTablet ? 18 : 16),
          ),
          elevation: 0, // We handle shadows with Container
          padding: EdgeInsets.zero,
        ),
        child: Text(
          'Create Account',
          style: GoogleFonts.albertSans(
            fontSize: _getButtonFontSize(isTablet, isSmallScreen),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton(double width, double height, bool isTablet, bool isSmallScreen) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isTablet ? 18 : 16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 24,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _onLoginPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isTablet ? 18 : 16),
            side: BorderSide(
              color: Colors.white.withOpacity(0.8),
              width: 1,
            ),
          ),
          elevation: 0, // We handle shadows with Container
          padding: EdgeInsets.zero,
        ),
        child: Text(
          'Login',
          style: GoogleFonts.albertSans(
            fontSize: _getButtonFontSize(isTablet, isSmallScreen),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  // Responsive font and size methods
  double _getTitleFontSize(bool isTablet, bool isSmallScreen) {
    if (isTablet) return 42.0;
    if (isSmallScreen) return 32.0;
    return 36.0;
  }

  double _getSubtitleFontSize(bool isTablet, bool isSmallScreen) {
    if (isTablet) return 20.0;
    if (isSmallScreen) return 16.0;
    return 18.0;
  }

  double _getButtonFontSize(bool isTablet, bool isSmallScreen) {
    if (isTablet) return 18.0;
    if (isSmallScreen) return 15.0;
    return 16.0;
  }

  double _getAnimationSize(Size screenSize, bool isTablet, bool isSmallScreen, bool isLargeScreen) {
    if (isTablet) {
      return screenSize.width * 0.7;
    } else if (isSmallScreen) {
      return screenSize.width * 0.8;
    } else if (isLargeScreen) {
      return screenSize.width * 0.75;
    } else {
      return screenSize.width * 0.8;
    }
  }
}