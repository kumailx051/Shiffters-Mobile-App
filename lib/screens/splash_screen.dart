import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'onboarding_screen.dart';
import 'user/home_screen.dart';
import 'admin/admin_dashboard_screen.dart';
import 'Driver/driver_dashboard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _scaleController;
  late AnimationController _dotsController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  bool _lottieLoaded = false;
  bool _allAssetsLoaded = false;

  @override
  void initState() {
    super.initState();

    // Set system UI overlay style for immersive experience
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    _initializeAnimations();
    _preloadAssets();
    _navigateToHome();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600), // Reduced from 1000ms
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800), // Reduced from 1500ms
      vsync: this,
    );

    _dotsController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut, // Simplified from easeInOut
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.85, // Less dramatic than 0.7
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOut, // Simplified from elasticOut
    ));

    // Start dots animation and repeat
    _dotsController.repeat();
  }

  void _preloadAssets() async {
    // Preload Lottie animation
    _preloadLottieAnimation();

    // Check if all assets are loaded every 50ms
    _checkAssetsLoaded();
  }

  void _preloadLottieAnimation() async {
    try {
      // Preload Lottie file into memory
      await rootBundle.load('assets/animations/splashScreen1.json');
      if (mounted) {
        setState(() {
          _lottieLoaded = true;
        });
        _checkAllAssetsLoaded();
      }
    } catch (e) {
      // Handle Lottie loading error
      if (mounted) {
        setState(() {
          _lottieLoaded = true; // Set to true to continue
        });
        _checkAllAssetsLoaded();
      }
    }
  }

  void _checkAssetsLoaded() async {
    // Wait maximum 2 seconds for assets to load
    int attempts = 0;
    const maxAttempts = 40; // 40 * 50ms = 2 seconds

    while (!_allAssetsLoaded && attempts < maxAttempts && mounted) {
      await Future.delayed(const Duration(milliseconds: 50));
      attempts++;
      _checkAllAssetsLoaded();
    }

    // Force start animations after timeout
    if (mounted && !_allAssetsLoaded) {
      setState(() {
        _allAssetsLoaded = true;
      });
      _startAnimations();
    }
  }

  void _checkAllAssetsLoaded() {
    if (_lottieLoaded && !_allAssetsLoaded) {
      setState(() {
        _allAssetsLoaded = true;
      });
      _startAnimations();
    }
  }

  void _startAnimations() {
    if (mounted) {
      _animationController.forward();
      _scaleController.forward();
    }
  }

  Future<void> _navigateToHome() async {
    // Wait for 4 seconds total (reduced from 6)
    await Future.delayed(const Duration(seconds: 4));

    if (mounted) {
      // Check for auto-login before navigating
      await _checkAutoLogin();
    }
  }

  // Check if user should be automatically logged in
  Future<void> _checkAutoLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shouldAutoLogin = prefs.getBool('auto_login') ?? false;
      final currentUser = FirebaseAuth.instance.currentUser;

      debugPrint(
          '🔍 Auto-login check: shouldAutoLogin=$shouldAutoLogin, currentUser=${currentUser?.email}');

      if (shouldAutoLogin && currentUser != null) {
        // Get user role to navigate to correct screen
        final userRole = await _getUserRole(currentUser.uid);

        // Check user mode preference (driver/user)
        final userMode = prefs.getString('user_mode') ?? 'user';

        debugPrint(
            '🎭 User role determined: $userRole, mode: $userMode for ${currentUser.email}');

        if (userRole == 'admin') {
          debugPrint(
              '✅ Auto-login successful, navigating to AdminDashboardScreen');
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  AdminDashboardScreen(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
              transitionDuration: const Duration(milliseconds: 600),
            ),
          );
        } else if (userMode == 'driver') {
          // Check if user has approved driver status
          final hasDriverAccess = await _checkDriverAccess(currentUser.uid);
          if (hasDriverAccess) {
            debugPrint(
                '✅ Auto-login successful, navigating to DriverDashboard');
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    const DriverDashboard(),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
                transitionDuration: const Duration(milliseconds: 600),
              ),
            );
          } else {
            // Driver mode but no access, reset to user mode and go to home
            await prefs.setString('user_mode', 'user');
            debugPrint('✅ Driver access revoked, navigating to HomeScreen');
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    const HomeScreen(),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
                transitionDuration: const Duration(milliseconds: 600),
              ),
            );
          }
        } else {
          debugPrint('✅ Auto-login successful, navigating to HomeScreen');
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const HomeScreen(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
              transitionDuration: const Duration(milliseconds: 600),
            ),
          );
        }
      } else {
        // Navigate to onboarding screen
        debugPrint(
            '❌ Auto-login not available, navigating to OnboardingScreen');
        _navigateToOnboarding();
      }
    } catch (e) {
      debugPrint('Error checking auto login: $e');
      // If there's an error, navigate to onboarding as fallback
      _navigateToOnboarding();
    }
  }

  // Get user role from Firestore
  Future<String> _getUserRole(String uid) async {
    try {
      debugPrint('🔍 Getting user role for UID: $uid');

      // Get current user email for fallback check
      final currentUserEmail = FirebaseAuth.instance.currentUser?.email ?? '';
      debugPrint('📧 Current user email: $currentUserEmail');

      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final role = userData['role'] ?? 'user';
        debugPrint('✅ User role found: $role for UID: $uid');

        // Check if role is admin (case insensitive)
        if (role.toString().toLowerCase() == 'admin') {
          return 'admin';
        }

        // Fallback: Check if email contains admin
        if (currentUserEmail.toLowerCase().contains('admin')) {
          debugPrint(
              '🔄 Fallback: Email contains admin, treating as admin user');
          return 'admin';
        }

        return role;
      } else {
        debugPrint('❌ User document does not exist for UID: $uid');

        // Fallback: Check if email contains admin even if document doesn't exist
        if (currentUserEmail.toLowerCase().contains('admin')) {
          debugPrint(
              '🔄 Fallback: No document but email contains admin, treating as admin user');
          return 'admin';
        }

        return 'user';
      }
    } catch (e) {
      debugPrint('❌ Error getting user role: $e');

      // Fallback: Check email even on error
      final currentUserEmail = FirebaseAuth.instance.currentUser?.email ?? '';
      if (currentUserEmail.toLowerCase().contains('admin')) {
        debugPrint(
            '🔄 Error fallback: Email contains admin, treating as admin user');
        return 'admin';
      }

      return 'user';
    }
  }

  // Check if user has approved driver access
  Future<bool> _checkDriverAccess(String uid) async {
    try {
      debugPrint('🚗 Checking driver access for UID: $uid');

      final driverDoc =
          await FirebaseFirestore.instance.collection('drivers').doc(uid).get();

      if (driverDoc.exists) {
        final data = driverDoc.data() as Map<String, dynamic>;
        final status = data['applicationStatus']?.toString() ?? '';
        debugPrint('🚗 Driver application status: $status');
        return status.toLowerCase() == 'approved';
      }

      debugPrint('🚗 No driver document found');
      return false;
    } catch (e) {
      debugPrint('❌ Error checking driver access: $e');
      return false;
    }
  }

  // Navigate to onboarding screen
  void _navigateToOnboarding() {
    // Reset system UI before navigation
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const OnboardingScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration:
            const Duration(milliseconds: 600), // Smooth professional fade
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scaleController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  // Build animated loading dots
  Widget _buildLoadingDots() {
    return AnimatedBuilder(
      animation: _dotsController,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            // Create staggered animation for each dot
            double animationValue =
                (_dotsController.value - (index * 0.2)).clamp(0.0, 1.0);
            double opacity = (0.4 +
                    (0.6 *
                        (0.5 +
                            0.5 *
                                (animationValue < 0.5
                                    ? 2 * animationValue
                                    : 2 * (1 - animationValue)))))
                .clamp(0.0, 1.0);

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(opacity),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final isSmallScreen = screenSize.height < 700;
    final isLargeScreen = screenSize.height > 900;

    // Optimized responsive sizing
    double getLottieSize() {
      if (isTablet) {
        return screenSize.width * 0.5;
      } else if (isSmallScreen) {
        return screenSize.width * 0.75;
      } else if (isLargeScreen) {
        return screenSize.width * 0.8;
      } else {
        return screenSize.width * 0.78;
      }
    }

    final lottieSize = getLottieSize();

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E88E5), // Your app's blue color
              Color(0xFF42A5F5),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Lottie Animation with optimized loading
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      width: lottieSize,
                      height: lottieSize,
                      constraints: BoxConstraints(
                        maxWidth: isTablet ? 450 : 350,
                        maxHeight: isTablet ? 450 : 350,
                        minWidth: isSmallScreen ? 250 : 280,
                        minHeight: isSmallScreen ? 250 : 280,
                      ),
                      child: _allAssetsLoaded
                          ? Lottie.asset(
                              'assets/animations/splashScreen1.json',
                              fit: BoxFit.contain,
                              repeat: true,
                              animate: true,
                              frameRate: FrameRate.max,
                              filterQuality: FilterQuality.high,
                              // Optimize for performance
                              options: LottieOptions(
                                enableMergePaths: true,
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                    ),
                  ),

                  // Add spacing between animation and loading dots
                  SizedBox(height: isTablet ? 60 : 40),

                  // 3-dot loading animation
                  _buildLoadingDots(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
