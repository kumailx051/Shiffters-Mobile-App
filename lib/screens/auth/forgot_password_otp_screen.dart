import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:shiffters/theme/app_colors.dart';
import 'reset_password_screen.dart';

class ForgotPasswordOTPScreen extends StatefulWidget {
  final String email;
  final String sentOTP;

  const ForgotPasswordOTPScreen({
    super.key,
    required this.email,
    required this.sentOTP,
  });

  @override
  State<ForgotPasswordOTPScreen> createState() => _ForgotPasswordOTPScreenState();
}

class _ForgotPasswordOTPScreenState extends State<ForgotPasswordOTPScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _formAnimationController;
  late AnimationController _pulseAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _formScaleAnimation;
  late Animation<double> _pulseAnimation;

  final List<TextEditingController> _otpControllers = List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  
  bool _isLoading = false;
  bool _canResend = false;
  int _resendTimer = 60;
  Timer? _timer;
  String _currentOTP = '';

  // OTP Server Configuration
  static const String _otpServerUrl = 'https://otp-server-qa0y.onrender.com';

  @override
  void initState() {
    super.initState();
    
    _initializeAnimations();
    _startAnimations();
    _startResendTimer();
    
    // Set system UI overlay style
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
      duration: const Duration(milliseconds: 600), // Reduced from 1000ms
      vsync: this,
    );
    
    _formAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400), // Reduced from 800ms
      vsync: this,
    );

    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000), // Increased for smoother pulse
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut, // Simpler curve
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1), // Reduced slide distance
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut, // Simpler curve
    ));
    
    _formScaleAnimation = Tween<double>(
      begin: 0.95, // Reduced scale difference
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _formAnimationController,
      curve: Curves.easeOut, // Simpler curve
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05, // Reduced pulse intensity
    ).animate(CurvedAnimation(
      parent: _pulseAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 100)); // Reduced delay
    if (mounted) {
      _animationController.forward();
      await Future.delayed(const Duration(milliseconds: 200)); // Reduced delay
      if (mounted) {
        _formAnimationController.forward();
        _pulseAnimationController.repeat(reverse: true);
      }
    }
  }

  void _startResendTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimer > 0) {
        setState(() {
          _resendTimer--;
        });
      } else {
        setState(() {
          _canResend = true;
        });
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _formAnimationController.dispose();
    _pulseAnimationController.dispose();
    _timer?.cancel();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _onOTPChanged(String value, int index) {
    setState(() {
      _currentOTP = _otpControllers.map((controller) => controller.text).join();
    });

    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    // Auto-verify when all 6 digits are entered
    if (_currentOTP.length == 6) {
      _verifyOTP();
    }
  }

  // Show glowing snackbar
  void _showGlowingSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.albertSans(
            fontWeight: FontWeight.w500,
            color: Colors.white,
            shadows: [
              Shadow(
                offset: const Offset(0, 0),
                blurRadius: 10,
                color: Colors.white.withValues(alpha: 0.8),
              ),
              Shadow(
                offset: const Offset(0, 0),
                blurRadius: 20,
                color: Colors.white.withValues(alpha: 0.6),
              ),
              Shadow(
                offset: const Offset(0, 1),
                blurRadius: 3,
                color: Colors.black.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // Resend OTP
  Future<void> _resendOTP() async {
    setState(() {
      _isLoading = true;
      _canResend = false;
      _resendTimer = 60;
    });

    try {
      final response = await http.post(
        Uri.parse('$_otpServerUrl/send-otp'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'email': widget.email,
          'name': 'User',
        }),
      ).timeout(const Duration(seconds: 30));

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (response.statusCode == 200) {
          _startResendTimer();
          _showGlowingSnackBar('OTP resent successfully!', AppColors.success);
        } else {
          setState(() {
            _canResend = true;
          });
          _showGlowingSnackBar('Failed to resend OTP. Please try again.', AppColors.error);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _canResend = true;
        });
        _showGlowingSnackBar('Network error. Please try again.', AppColors.error);
      }
    }
  }

  // Verify OTP
  void _verifyOTP() async {
    if (_currentOTP.length != 6) {
      _showGlowingSnackBar('Please enter complete OTP', AppColors.error);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    HapticFeedback.lightImpact();

    try {
      // Simulate OTP verification (in real app, verify with server)
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // For demo, we'll consider OTP as verified if it matches sent OTP
        // In production, you should verify with server
        if (_currentOTP == widget.sentOTP) {
          // Show success message
          _showGlowingSnackBar('OTP verified successfully!', AppColors.success);

          // Navigate to reset password screen with custom flow
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => ResetPasswordScreen(
                email: widget.email,
                oobCode: 'custom_otp_verified',
                isCustomOTPFlow: true, // Flag for custom OTP flow
              ),
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
        } else {
          // Clear OTP fields and show error
          for (var controller in _otpControllers) {
            controller.clear();
          }
          setState(() {
            _currentOTP = '';
          });
          _focusNodes[0].requestFocus();

          _showGlowingSnackBar('Invalid OTP. Please try again.', AppColors.error);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showGlowingSnackBar('Verification failed. Please try again.', AppColors.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final isSmallScreen = screenSize.height < 700;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1A1A2E),
                  Color(0xFF16213E),
                  Color(0xFF0F3460),
                ],
              ),
            ),
          ),
          
          // Main content
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(bottom: keyboardHeight),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: screenSize.height - 
                    MediaQuery.of(context).padding.top - 
                    MediaQuery.of(context).padding.bottom - 
                    keyboardHeight,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 40 : 24,
                    vertical: isSmallScreen ? 20 : 32,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Back button
                      _buildBackButton(),
                      
                      SizedBox(height: isSmallScreen ? 30 : 60),
                      
                      // Header
                      _buildHeader(isTablet, isSmallScreen),
                      
                      SizedBox(height: isSmallScreen ? 40 : 60),
                      
                      // OTP Input
                      _buildOTPInput(isTablet, isSmallScreen),
                      
                      SizedBox(height: isSmallScreen ? 30 : 40),
                      
                      // Verify Button
                      _buildVerifyButton(isTablet, isSmallScreen),
                      
                      SizedBox(height: isSmallScreen ? 20 : 30),
                      
                      // Resend OTP
                      _buildResendOTP(isTablet, isSmallScreen),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return Align(
      alignment: Alignment.topLeft,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white,
              size: 20,
            ),
            padding: const EdgeInsets.all(12),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isTablet, bool isSmallScreen) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Column(
          children: [
            // Security icon with pulse animation
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                padding: EdgeInsets.all(isTablet ? 20 : 16),
                decoration: BoxDecoration(
                  color: AppColors.yellowAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.yellowAccent.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.security,
                  size: isTablet ? 60 : 50,
                  color: AppColors.yellowAccent,
                ),
              ),
            ),
            
            SizedBox(height: isSmallScreen ? 20 : 30),
            
            // Title
            Text(
              'Verify OTP',
              textAlign: TextAlign.center,
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 36 : (isSmallScreen ? 28 : 32),
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.0,
                shadows: [
                  Shadow(
                    offset: const Offset(0, 0),
                    blurRadius: 20,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                  Shadow(
                    offset: const Offset(0, 2),
                    blurRadius: 8,
                    color: Colors.black.withValues(alpha: 0.3),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: isSmallScreen ? 12 : 16),
            
            // Subtitle
            Text(
              'We\'ve sent a 6-digit OTP to',
              textAlign: TextAlign.center,
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 16 : (isSmallScreen ? 14 : 15),
                fontWeight: FontWeight.w400,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            
            SizedBox(height: isSmallScreen ? 8 : 12),
            
            // Email
            Text(
              widget.email,
              textAlign: TextAlign.center,
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 18 : (isSmallScreen ? 16 : 17),
                fontWeight: FontWeight.w600,
                color: AppColors.yellowAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOTPInput(bool isTablet, bool isSmallScreen) {
    return ScaleTransition(
      scale: _formScaleAnimation,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(6, (index) {
          return Container(
            width: isTablet ? 60 : 50,
            height: isTablet ? 60 : 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _focusNodes[index].hasFocus
                      ? AppColors.yellowAccent.withValues(alpha: 0.4)
                      : Colors.black.withValues(alpha: 0.1),
                  blurRadius: _focusNodes[index].hasFocus ? 15 : 8,
                  offset: const Offset(0, 4),
                  spreadRadius: _focusNodes[index].hasFocus ? 2 : 0,
                ),
              ],
            ),
            child: TextField(
              controller: _otpControllers[index],
              focusNode: _focusNodes[index],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 1,
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 24 : 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              decoration: InputDecoration(
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: Colors.grey.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: _otpControllers[index].text.isNotEmpty
                        ? AppColors.yellowAccent.withValues(alpha: 0.5)
                        : Colors.grey.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: AppColors.yellowAccent,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.95),
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (value) {
                setState(() {}); // Trigger rebuild for border color change
                _onOTPChanged(value, index);
              },
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildVerifyButton(bool isTablet, bool isSmallScreen) {
    final buttonWidth = isTablet ? 320.0 : double.infinity;
    final buttonHeight = isTablet ? 56.0 : 52.0;
    
    return Container(
      width: buttonWidth,
      height: buttonHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.yellowAccent.withValues(alpha: 0.6),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _verifyOTP,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.yellowAccent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                'Verify OTP',
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 18 : (isSmallScreen ? 15 : 16),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }

  Widget _buildResendOTP(bool isTablet, bool isSmallScreen) {
    return Column(
      children: [
        if (!_canResend)
          Text(
            'Resend OTP in ${_resendTimer}s',
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 16 : (isSmallScreen ? 13 : 14),
              color: Colors.white.withValues(alpha: 0.7),
            ),
          )
        else
          GestureDetector(
            onTap: _resendOTP,
            child: Text(
              'Resend OTP',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 16 : (isSmallScreen ? 13 : 14),
                color: AppColors.yellowAccent,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.yellowAccent,
              ),
            ),
          ),
      ],
    );
  }
}