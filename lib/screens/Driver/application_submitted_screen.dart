import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shiffters/services/theme_service.dart';
import 'package:shiffters/theme/app_colors.dart';
import 'package:lottie/lottie.dart';

class ApplicationSubmittedScreen extends StatefulWidget {
  const ApplicationSubmittedScreen({super.key});

  @override
  State<ApplicationSubmittedScreen> createState() =>
      _ApplicationSubmittedScreenState();
}

class _ApplicationSubmittedScreenState extends State<ApplicationSubmittedScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

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
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.4, 1.0, curve: Curves.elasticOut),
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

  void _goHome() {
    HapticFeedback.lightImpact();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        final isDarkMode = themeService.isDarkMode;

        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                isDarkMode ? Brightness.light : Brightness.dark,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness:
                isDarkMode ? Brightness.light : Brightness.dark,
          ),
        );

        return Scaffold(
          backgroundColor: isDarkMode ? const Color(0xFF1E1E2C) : Colors.white,
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 48 : 24,
                vertical: isTablet ? 32 : 20,
              ),
              child: Column(
                children: [
                  // Top spacer
                  const Spacer(flex: 2),

                  // Success Animation
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        width: isTablet ? 200 : 150,
                        height: isTablet ? 200 : 150,
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? AppColors.yellowAccent.withValues(alpha: 0.1)
                              : Colors.green.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDarkMode
                                ? AppColors.yellowAccent.withValues(alpha: 0.3)
                                : Colors.green.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Lottie.asset(
                            'assets/animations/Done.json',
                            width: isTablet ? 120 : 100,
                            height: isTablet ? 120 : 100,
                            fit: BoxFit.contain,
                            repeat: true,
                          ),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: isTablet ? 48 : 32),

                  // Main Content
                  SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          // Success Title
                          Text(
                            'Application Submitted',
                            style: GoogleFonts.albertSans(
                              fontSize: isTablet ? 32 : 28,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          SizedBox(height: isTablet ? 24 : 16),

                          // Success Message
                          Container(
                            padding: EdgeInsets.all(isTablet ? 24 : 20),
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.grey.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDarkMode
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : AppColors.lightPrimary
                                        .withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.schedule,
                                  size: isTablet ? 48 : 40,
                                  color: isDarkMode
                                      ? AppColors.yellowAccent
                                      : AppColors.lightPrimary,
                                ),
                                SizedBox(height: isTablet ? 16 : 12),
                                Text(
                                  'Thank you for your application!',
                                  style: GoogleFonts.albertSans(
                                    fontSize: isTablet ? 20 : 18,
                                    fontWeight: FontWeight.w600,
                                    color: isDarkMode
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: isTablet ? 16 : 12),
                                Text(
                                  'We have received your driver application and all required documents. Our team will review your information and get back to you within 24-48 hours.',
                                  style: GoogleFonts.albertSans(
                                    fontSize: isTablet ? 16 : 14,
                                    height: 1.5,
                                    color: isDarkMode
                                        ? Colors.white.withValues(alpha: 0.8)
                                        : AppColors.textSecondary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: isTablet ? 20 : 16),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isTablet ? 20 : 16,
                                    vertical: isTablet ? 12 : 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDarkMode
                                        ? AppColors.yellowAccent
                                            .withValues(alpha: 0.1)
                                        : Colors.blue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDarkMode
                                          ? AppColors.yellowAccent
                                              .withValues(alpha: 0.3)
                                          : Colors.blue.withValues(alpha: 0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        size: isTablet ? 20 : 18,
                                        color: isDarkMode
                                            ? AppColors.yellowAccent
                                            : Colors.blue,
                                      ),
                                      SizedBox(width: isTablet ? 12 : 8),
                                      Flexible(
                                        child: Text(
                                          'You will receive a notification once your application is reviewed.',
                                          style: GoogleFonts.albertSans(
                                            fontSize: isTablet ? 14 : 12,
                                            fontWeight: FontWeight.w500,
                                            color: isDarkMode
                                                ? AppColors.yellowAccent
                                                : Colors.blue,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: isTablet ? 32 : 24),

                          // Additional Info
                          Container(
                            padding: EdgeInsets.all(isTablet ? 20 : 16),
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? Colors.white.withValues(alpha: 0.03)
                                  : Colors.grey.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDarkMode
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : Colors.grey.withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'What happens next?',
                                  style: GoogleFonts.albertSans(
                                    fontSize: isTablet ? 16 : 14,
                                    fontWeight: FontWeight.w600,
                                    color: isDarkMode
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: isTablet ? 16 : 12),
                                _buildStepItem(
                                  '1',
                                  'Application Review',
                                  'Our team will verify your documents and information',
                                  isDarkMode,
                                  isTablet,
                                ),
                                SizedBox(height: isTablet ? 12 : 8),
                                _buildStepItem(
                                  '2',
                                  'Background Check',
                                  'We will conduct a background verification process',
                                  isDarkMode,
                                  isTablet,
                                ),
                                SizedBox(height: isTablet ? 12 : 8),
                                _buildStepItem(
                                  '3',
                                  'Approval & Onboarding',
                                  'Once approved, you will receive further instructions',
                                  isDarkMode,
                                  isTablet,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom spacer
                  const Spacer(flex: 3),

                  // Home Button
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SizedBox(
                      width: double.infinity,
                      height: isTablet ? 56 : 48,
                      child: ElevatedButton(
                        onPressed: _goHome,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDarkMode
                              ? AppColors.yellowAccent
                              : AppColors.lightPrimary,
                          foregroundColor:
                              isDarkMode ? Colors.black : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                          padding: EdgeInsets.zero,
                        ),
                        child: Text(
                          'Back to Home',
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 18 : 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: isTablet ? 24 : 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStepItem(String number, String title, String description,
      bool isDarkMode, bool isTablet) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: isTablet ? 28 : 24,
          height: isTablet ? 28 : 24,
          decoration: BoxDecoration(
            color: isDarkMode
                ? AppColors.yellowAccent.withValues(alpha: 0.2)
                : AppColors.lightPrimary.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(
              color:
                  isDarkMode ? AppColors.yellowAccent : AppColors.lightPrimary,
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              number,
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 12 : 10,
                fontWeight: FontWeight.bold,
                color: isDarkMode
                    ? AppColors.yellowAccent
                    : AppColors.lightPrimary,
              ),
            ),
          ),
        ),
        SizedBox(width: isTablet ? 16 : 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 14 : 12,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : AppColors.textPrimary,
                ),
              ),
              SizedBox(height: isTablet ? 4 : 2),
              Text(
                description,
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 12 : 11,
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.7)
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
