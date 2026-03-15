import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shiffters/services/biometric_auth_service.dart';
import 'package:shiffters/services/theme_service.dart';
import 'package:shiffters/theme/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shiffters/screens/welcome_screen.dart';

class BiometricLockScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;

  const BiometricLockScreen({
    super.key,
    required this.onAuthenticated,
  });

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen>
    with TickerProviderStateMixin {
  final BiometricAuthService _biometricService = BiometricAuthService();

  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;

  bool _isAuthenticating = false;
  String _biometricType = 'Biometric';
  String _errorMessage = '';
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkBiometricType();
    _startAnimations();

    // Auto-trigger biometric authentication after animations
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _authenticateWithBiometric();
      }
    });
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _pulseController = AnimationController(
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

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  void _startAnimations() {
    _animationController.forward();
    _pulseController.repeat(reverse: true);
  }

  Future<void> _checkBiometricType() async {
    try {
      final availableBiometrics =
          await _biometricService.getAvailableBiometrics();
      setState(() {
        _biometricType =
            _biometricService.getBiometricTypeName(availableBiometrics);
      });
    } catch (e) {
      debugPrint('Error checking biometric type: $e');
    }
  }

  Future<void> _authenticateWithBiometric() async {
    if (_isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
      _showError = false;
      _errorMessage = '';
    });

    try {
      HapticFeedback.lightImpact();

      final bool isAuthenticated =
          await _biometricService.authenticateOnAppLaunch();

      if (isAuthenticated) {
        HapticFeedback.mediumImpact();

        // Add a small delay for better UX
        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          widget.onAuthenticated();
        }
      } else {
        setState(() {
          _showError = true;
          _errorMessage = 'Authentication failed. Please try again.';
        });

        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      setState(() {
        _showError = true;
        _errorMessage = 'Authentication error. Please try again.';
      });

      HapticFeedback.heavyImpact();
      debugPrint('Biometric authentication error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D3C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Sign Out',
          style: GoogleFonts.albertSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to sign out?',
          style: GoogleFonts.albertSans(
            color: Colors.white70,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.albertSans(
                color: Colors.white70,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              // Clear biometric cache and sign out
              await _biometricService.clearBiometricCache();
              await FirebaseAuth.instance.signOut();

              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                      builder: (context) => const WelcomeScreen()),
                  (route) => false,
                );
              }
            },
            child: Text(
              'Sign Out',
              style: GoogleFonts.albertSans(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        final isDarkMode = themeService.isDarkMode;

        return Scaffold(
          backgroundColor: isDarkMode ? const Color(0xFF1E1E2C) : Colors.white,
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDarkMode
                    ? [
                        const Color(0xFF1E1E2C),
                        const Color(0xFF2D2D3C),
                        const Color(0xFF1E1E2C),
                      ]
                    : [
                        Colors.white,
                        Colors.grey[50]!,
                        Colors.white,
                      ],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.all(isTablet ? 32 : 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),

                    // App Logo/Icon
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        width: isTablet ? 120 : 100,
                        height: isTablet ? 120 : 100,
                        decoration: BoxDecoration(
                          color: AppColors.lightPrimary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.lightPrimary.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.local_shipping_rounded,
                          size: isTablet ? 60 : 50,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    SizedBox(height: isTablet ? 40 : 32),

                    // App Name
                    SlideTransition(
                      position: _slideAnimation,
                      child: Text(
                        'SHIFFTERS',
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 32 : 28,
                          fontWeight: FontWeight.bold,
                          color:
                              isDarkMode ? Colors.white : AppColors.textPrimary,
                          letterSpacing: 2,
                        ),
                      ),
                    ),

                    SizedBox(height: isTablet ? 16 : 12),

                    // Subtitle
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Text(
                        'Your Relocation Partner',
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 16 : 14,
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.7)
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    SizedBox(height: isTablet ? 60 : 48),

                    // Biometric Icon
                    SlideTransition(
                      position: _slideAnimation,
                      child: ScaleTransition(
                        scale: _pulseAnimation,
                        child: GestureDetector(
                          onTap: _authenticateWithBiometric,
                          child: Container(
                            width: isTablet ? 100 : 80,
                            height: isTablet ? 100 : 80,
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? const Color(0xFF2D2D3C)
                                  : Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _isAuthenticating
                                    ? AppColors.lightPrimary
                                    : (isDarkMode
                                        ? Colors.white.withOpacity(0.2)
                                        : Colors.grey.withOpacity(0.3)),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isDarkMode
                                      ? Colors.black.withOpacity(0.3)
                                      : Colors.grey.withOpacity(0.2),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                if (_isAuthenticating)
                                  SizedBox(
                                    width: isTablet ? 60 : 50,
                                    height: isTablet ? 60 : 50,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.lightPrimary,
                                      ),
                                    ),
                                  ),
                                Icon(
                                  _biometricType == 'Face ID'
                                      ? Icons.face
                                      : Icons.fingerprint,
                                  size: isTablet ? 40 : 32,
                                  color: _isAuthenticating
                                      ? AppColors.lightPrimary
                                      : (isDarkMode
                                          ? Colors.white
                                          : AppColors.textPrimary),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: isTablet ? 24 : 20),

                    // Instruction Text
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Text(
                        _isAuthenticating
                            ? 'Authenticating...'
                            : 'Touch $_biometricType to unlock',
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 18 : 16,
                          fontWeight: FontWeight.w600,
                          color:
                              isDarkMode ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),

                    SizedBox(height: isTablet ? 12 : 8),

                    // Error Message
                    if (_showError)
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 20 : 16,
                            vertical: isTablet ? 12 : 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.error.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            _errorMessage,
                            style: GoogleFonts.albertSans(
                              fontSize: isTablet ? 14 : 12,
                              color: AppColors.error,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),

                    const Spacer(),

                    // Alternative Actions
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          // Retry Button
                          if (_showError)
                            Padding(
                              padding:
                                  EdgeInsets.only(bottom: isTablet ? 16 : 12),
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _authenticateWithBiometric,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.lightPrimary,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(
                                      vertical: isTablet ? 16 : 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    'Try Again',
                                    style: GoogleFonts.albertSans(
                                      fontSize: isTablet ? 16 : 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          // Sign Out Button
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _logout,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isDarkMode
                                    ? Colors.white
                                    : AppColors.textPrimary,
                                side: BorderSide(
                                  color: isDarkMode
                                      ? Colors.white.withOpacity(0.3)
                                      : Colors.grey.withOpacity(0.3),
                                ),
                                padding: EdgeInsets.symmetric(
                                  vertical: isTablet ? 16 : 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Sign Out',
                                style: GoogleFonts.albertSans(
                                  fontSize: isTablet ? 16 : 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
