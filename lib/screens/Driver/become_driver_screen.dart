import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shiffters/services/theme_service.dart';
import 'package:shiffters/theme/app_colors.dart';
import 'package:shiffters/screens/Driver/driver_registration_screen.dart';
import 'package:shiffters/utils/navigation_utils.dart';

class BecomeDriverScreen extends StatefulWidget {
  const BecomeDriverScreen({super.key});

  @override
  State<BecomeDriverScreen> createState() => _BecomeDriverScreenState();
}

class _BecomeDriverScreenState extends State<BecomeDriverScreen>
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
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
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

  void _onContinuePressed() {
    HapticFeedback.lightImpact();
    if (mounted) {
      NavigationUtils.navigateWithSlide(
          context, const DriverRegistrationScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        final isDarkMode = themeService.isDarkMode;

        // Set system UI overlay style based on theme
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
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 40 : 20,
                  vertical: isTablet ? 32 : 16,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height -
                        MediaQuery.of(context).padding.top -
                        MediaQuery.of(context).padding.bottom,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        // Back button
                        _buildBackButton(isDarkMode),

                        SizedBox(height: isTablet ? 40 : 20),

                        // Driver icon
                        _buildDriverIcon(isDarkMode, isTablet),

                        SizedBox(height: isTablet ? 40 : 30),

                        // Main title
                        _buildMainTitle(isDarkMode, isTablet),

                        SizedBox(height: isTablet ? 24 : 16),

                        // Subtitle
                        _buildSubtitle(isDarkMode, isTablet),

                        SizedBox(height: isTablet ? 40 : 30),

                        // Benefits list
                        _buildBenefitsList(isDarkMode, isTablet),

                        const Spacer(),

                        // Continue button
                        _buildContinueButton(isDarkMode, isTablet),

                        SizedBox(height: isTablet ? 20 : 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBackButton(bool isDarkMode) {
    return Align(
      alignment: Alignment.topLeft,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: isDarkMode
                ? Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1,
                  )
                : Border.all(
                    color: AppColors.lightPrimary.withValues(alpha: 0.3),
                    width: 1,
                  ),
          ),
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.arrow_back_ios_new,
              color: isDarkMode ? Colors.white : AppColors.textPrimary,
              size: 20,
            ),
            padding: const EdgeInsets.all(12),
          ),
        ),
      ),
    );
  }

  Widget _buildDriverIcon(bool isDarkMode, bool isTablet) {
    final screenHeight = MediaQuery.of(context).size.height;
    final iconSize =
        screenHeight < 700 ? (isTablet ? 80 : 70) : (isTablet ? 120 : 90);
    final containerIconSize =
        screenHeight < 700 ? (isTablet ? 40 : 35) : (isTablet ? 60 : 45);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: iconSize.toDouble(),
          height: iconSize.toDouble(),
          decoration: BoxDecoration(
            color: isDarkMode ? AppColors.yellowAccent : AppColors.lightPrimary,
            borderRadius: BorderRadius.circular(isTablet ? 30 : 25),
            boxShadow: [
              BoxShadow(
                color: isDarkMode
                    ? AppColors.yellowAccent.withValues(alpha: 0.4)
                    : AppColors.lightPrimary.withValues(alpha: 0.4),
                blurRadius: isTablet ? 20 : 15,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            Icons.local_shipping_outlined,
            size: containerIconSize.toDouble(),
            color: isDarkMode ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildMainTitle(bool isDarkMode, bool isTablet) {
    final screenHeight = MediaQuery.of(context).size.height;
    final fontSize =
        screenHeight < 700 ? (isTablet ? 28 : 26) : (isTablet ? 36 : 30);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Text(
          'Want to Become a Driver?',
          textAlign: TextAlign.center,
          style: GoogleFonts.albertSans(
            fontSize: fontSize.toDouble(),
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : AppColors.textPrimary,
            height: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitle(bool isDarkMode, bool isTablet) {
    final screenHeight = MediaQuery.of(context).size.height;
    final fontSize =
        screenHeight < 700 ? (isTablet ? 22 : 20) : (isTablet ? 28 : 24);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Text(
          'Earn Money',
          textAlign: TextAlign.center,
          style: GoogleFonts.albertSans(
            fontSize: fontSize.toDouble(),
            fontWeight: FontWeight.w600,
            color: isDarkMode ? AppColors.yellowAccent : AppColors.lightPrimary,
            height: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitsList(bool isDarkMode, bool isTablet) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isCompact = screenHeight < 700;

    final benefits = [
      {
        'icon': Icons.attach_money,
        'title': 'Flexible Earnings',
        'description': 'Set your own schedule and earn on your terms'
      },
      {
        'icon': Icons.schedule,
        'title': 'Work Anytime',
        'description': 'Drive when you want, where you want'
      },
      {
        'icon': Icons.support_agent,
        'title': '24/7 Support',
        'description': 'Get help whenever you need it'
      },
    ];

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Column(
          children: benefits.map((benefit) {
            return Container(
              margin: EdgeInsets.only(bottom: isCompact ? 12 : 16),
              padding: EdgeInsets.all(
                  isTablet ? (isCompact ? 16 : 20) : (isCompact ? 12 : 16)),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.white,
                borderRadius: BorderRadius.circular(isCompact ? 12 : 16),
                border: isDarkMode
                    ? Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 1,
                      )
                    : Border.all(
                        color: AppColors.lightPrimary.withValues(alpha: 0.3),
                        width: 1,
                      ),
                boxShadow: isDarkMode
                    ? null
                    : [
                        BoxShadow(
                          color: AppColors.lightPrimary.withValues(alpha: 0.1),
                          blurRadius: isCompact ? 6 : 10,
                          offset: Offset(0, isCompact ? 2 : 4),
                        ),
                      ],
              ),
              child: Row(
                children: [
                  Container(
                    width: isTablet
                        ? (isCompact ? 40 : 50)
                        : (isCompact ? 35 : 45),
                    height: isTablet
                        ? (isCompact ? 40 : 50)
                        : (isCompact ? 35 : 45),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? AppColors.yellowAccent.withValues(alpha: 0.2)
                          : AppColors.lightPrimary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(isCompact ? 8 : 12),
                    ),
                    child: Icon(
                      benefit['icon'] as IconData,
                      color: isDarkMode
                          ? AppColors.yellowAccent
                          : AppColors.lightPrimary,
                      size: isTablet
                          ? (isCompact ? 20 : 28)
                          : (isCompact ? 18 : 24),
                    ),
                  ),
                  SizedBox(
                      width: isTablet
                          ? (isCompact ? 16 : 20)
                          : (isCompact ? 12 : 16)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          benefit['title'] as String,
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet
                                ? (isCompact ? 16 : 18)
                                : (isCompact ? 14 : 16),
                            fontWeight: FontWeight.w600,
                            color: isDarkMode
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: isCompact ? 2 : 4),
                        Text(
                          benefit['description'] as String,
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet
                                ? (isCompact ? 12 : 14)
                                : (isCompact ? 11 : 13),
                            color: isDarkMode
                                ? Colors.white.withValues(alpha: 0.7)
                                : AppColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildContinueButton(bool isDarkMode, bool isTablet) {
    final screenHeight = MediaQuery.of(context).size.height;
    final buttonHeight =
        screenHeight < 700 ? (isTablet ? 50 : 48) : (isTablet ? 56 : 52);
    final fontSize =
        screenHeight < 700 ? (isTablet ? 16 : 15) : (isTablet ? 18 : 16);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: double.infinity,
          height: buttonHeight.toDouble(),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: isDarkMode
                    ? AppColors.yellowAccent.withValues(alpha: 0.4)
                    : AppColors.lightPrimary.withValues(alpha: 0.4),
                blurRadius: screenHeight < 700 ? 15 : 20,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _onContinuePressed,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isDarkMode ? AppColors.yellowAccent : AppColors.lightPrimary,
              foregroundColor: isDarkMode ? Colors.black : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
              padding: EdgeInsets.zero,
            ),
            child: Text(
              'Continue',
              style: GoogleFonts.albertSans(
                fontSize: fontSize.toDouble(),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
