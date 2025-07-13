import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  
  bool _imageLoaded = false;
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
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));
  }

  void _preloadAssets() async {
    // Preload background image
    _preloadBackgroundImage();
    
    // Preload Lottie animation
    _preloadLottieAnimation();
    
    // Check if all assets are loaded every 50ms
    _checkAssetsLoaded();
  }

  void _preloadBackgroundImage() {
    const AssetImage('assets/background/splashScreenBackground.jpg')
        .resolve(const ImageConfiguration())
        .addListener(
      ImageStreamListener(
        (ImageInfo info, bool synchronousCall) {
          if (mounted) {
            setState(() {
              _imageLoaded = true;
            });
            _checkAllAssetsLoaded();
          }
        },
        onError: (exception, stackTrace) {
          // Handle image loading error
          if (mounted) {
            setState(() {
              _imageLoaded = true; // Set to true to show gradient fallback
            });
            _checkAllAssetsLoaded();
          }
        },
      ),
    );
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
    if (_imageLoaded && _lottieLoaded && !_allAssetsLoaded) {
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
    // Wait for 6 seconds total
    await Future.delayed(const Duration(seconds: 6));
    
    if (mounted) {
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
          pageBuilder: (context, animation, secondaryAnimation) => const OnboardingScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.05),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                )),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scaleController.dispose();
    super.dispose();
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
      body: AnimatedContainer(
        duration: Duration(milliseconds: _allAssetsLoaded ? 300 : 0),
        width: double.infinity,
        height: double.infinity,
        decoration: _allAssetsLoaded && _imageLoaded
            ? const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/background/splashScreenBackground.jpg'),
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                ),
              )
            : const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFF3E5F5), // Very light lavender
                    Color(0xFFE1BEE7), // Light purple
                    Color(0xFFCE93D8), // Medium light purple
                    Color(0xFFBA68C8), // Medium purple
                    Color(0xFF9C27B0), // Deeper purple
                  ],
                  stops: [0.0, 0.25, 0.5, 0.75, 1.0],
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
                  
                  // Responsive spacing
                  
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

 
}