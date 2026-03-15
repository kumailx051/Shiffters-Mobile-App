import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shiffters/theme/app_colors.dart';
import 'package:shiffters/screens/auth/userDetails_screen.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String email;
  final String name;
  final String sentOTP;
  final User firebaseUser; // Added Firebase user parameter

  const OTPVerificationScreen({
    super.key,
    required this.email,
    required this.name,
    required this.sentOTP,
    required this.firebaseUser, // Required Firebase user
  });

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _formAnimationController;
  late AnimationController _pulseAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _formScaleAnimation;
  late Animation<double> _pulseAnimation;

  final List<TextEditingController> _otpControllers =
      List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());

  bool _isLoading = false;
  bool _animationsStarted = false;
  bool _canResend = false;
  int _resendTimer = 60;
  Timer? _timer;
  String _currentOTP = '';

  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
      duration: const Duration(milliseconds: 500), // Reduced from 800ms
      vsync: this,
    );

    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000), // Reduced from 1500ms
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut, // Simplified from easeInOut
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1), // Reduced from 0.3
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut, // Simplified from easeOutCubic
    ));

    _formScaleAnimation = Tween<double>(
      begin: 0.97, // Less dramatic than 0.9
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _formAnimationController,
      curve: Curves.easeOut, // Simplified from easeOutBack
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.03, // Reduced from 1.05
    ).animate(CurvedAnimation(
      parent: _pulseAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) {
      _animationController.forward();
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        _formAnimationController.forward();
        setState(() {
          _animationsStarted = true;
        });
        // Focus on first OTP field
        _focusNodes[0].requestFocus();
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
    if (value.isNotEmpty) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    // Update current OTP
    _currentOTP = _otpControllers.map((controller) => controller.text).join();

    // Auto-verify when all 6 digits are entered
    if (_currentOTP.length == 6) {
      _verifyOTP();
    }
  }

  // Update email verification status in Firestore
  Future<Map<String, dynamic>> _updateEmailVerificationStatus() async {
    try {
      await _firestore.collection('users').doc(widget.firebaseUser.uid).update({
        'isEmailVerified': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return {
        'success': true,
        'message': 'Email verification status updated successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to update email verification status: $e',
      };
    }
  }

  void _verifyOTP() async {
    if (_currentOTP.length != 6) {
      _showErrorMessage('Please enter all 6 digits');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    HapticFeedback.lightImpact();

    // Start pulse animation for verification
    _pulseAnimationController.repeat(reverse: true);

    try {
      // Add debugging
      debugPrint('🔍 Entered OTP: "$_currentOTP"');
      debugPrint('🔍 Expected OTP: "${widget.sentOTP}"');

      // Simulate verification delay
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        _pulseAnimationController.stop();
        _pulseAnimationController.reset();

        // Clean and compare OTPs
        String enteredOTP = _currentOTP.trim();
        String expectedOTP = widget.sentOTP.toString().trim();

        // Check if OTP matches
        if (enteredOTP == expectedOTP) {
          // Success - Update Firestore email verification status
          Map<String, dynamic> updateResult =
              await _updateEmailVerificationStatus();

          if (updateResult['success']) {
            // Optionally, reload the Firebase user
            try {
              await widget.firebaseUser.reload();
            } catch (e) {
              debugPrint('⚠️ Failed to reload Firebase user: $e');
            }

            // Success
            HapticFeedback.heavyImpact();
            _showSuccessMessage();

            // Navigate to next screen after delay
            await Future.delayed(const Duration(seconds: 2));
            if (mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      UserDetailsScreen(
                    name: widget.name,
                    email: widget.email,
                  ),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
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
                  transitionDuration: const Duration(milliseconds: 800),
                ),
                (route) => false,
              );
            }
          } else {
            _showErrorMessage(
                'Verification successful, but failed to update account status. Please contact support.');
          }
        } else {
          // Failed verification
          HapticFeedback.heavyImpact();
          _showErrorMessage('Invalid OTP. Please try again');
          _clearOTP();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _pulseAnimationController.stop();
        _pulseAnimationController.reset();
        _showErrorMessage('Verification failed. Please try again.');
      }
    }
  }

  void _clearOTP() {
    for (var controller in _otpControllers) {
      controller.clear();
    }
    _currentOTP = '';
    _focusNodes[0].requestFocus();
  }

  Future<void> _resendOTP() async {
    if (!_canResend) return;

    setState(() {
      _isLoading = true;
    });

    HapticFeedback.lightImpact();

    try {
      final response = await http
          .post(
            Uri.parse('$_otpServerUrl/send-otp'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode({
              'email': widget.email,
              'name': widget.name,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (response.statusCode == 200) {
          Map<String, dynamic> result = json.decode(response.body);
          if (result['success'] == true) {
            setState(() {
              _canResend = false;
              _resendTimer = 60;
            });
            _startResendTimer();
            _clearOTP();

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '✅ New OTP sent to ${widget.email}',
                  style: GoogleFonts.albertSans(fontWeight: FontWeight.w500),
                ),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                duration: const Duration(seconds: 3),
              ),
            );
          } else {
            _showErrorMessage('Failed to resend OTP. Please try again.');
          }
        } else {
          _showErrorMessage(
              'Network error. Please check your connection and try again.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorMessage(
            'Unable to connect to email service. Please check your internet connection.');
      }
    }
  }

  void _showSuccessMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.white,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              '🎉 Email Verified Successfully!',
              style: GoogleFonts.albertSans(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Your account has been verified. Welcome to SHIFFTERS!',
              style: GoogleFonts.albertSans(
                fontWeight: FontWeight.w400,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.albertSans(fontWeight: FontWeight.w500),
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final isSmallScreen = screenSize.height < 700;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
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

                    SizedBox(height: isSmallScreen ? 40 : 80),

                    // Email icon
                    _buildEmailIcon(isTablet),

                    SizedBox(height: isSmallScreen ? 30 : 40),

                    // Title
                    _buildTitle(isTablet, isSmallScreen),

                    SizedBox(height: isSmallScreen ? 20 : 30),

                    // Description
                    _buildDescription(isTablet, isSmallScreen),

                    SizedBox(height: isSmallScreen ? 8 : 12),

                    // Email address
                    _buildEmailAddress(isTablet, isSmallScreen),

                    SizedBox(height: isSmallScreen ? 40 : 60),

                    // OTP Input Fields
                    _buildOTPFields(isTablet, isSmallScreen),

                    SizedBox(height: isSmallScreen ? 30 : 40),

                    // Verify Button
                    _buildVerifyButton(isTablet, isSmallScreen),

                    SizedBox(height: isSmallScreen ? 30 : 40),

                    // Timer and Resend
                    _buildResendSection(isTablet, isSmallScreen),
                  ],
                ),
              ),
            ),
          ),
        ),
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

  Widget _buildEmailIcon(bool isTablet) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        width: isTablet ? 80 : 70,
        height: isTablet ? 80 : 70,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          Icons.mark_email_read_outlined,
          size: isTablet ? 40 : 35,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildTitle(bool isTablet, bool isSmallScreen) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Text(
          'Verify Your Email',
          textAlign: TextAlign.center,
          style: GoogleFonts.albertSans(
            fontSize: isTablet ? 36 : (isSmallScreen ? 28 : 32),
            fontWeight: FontWeight.bold,
            color: Colors.white,
            height: 1.2,
            shadows: [
              Shadow(
                offset: const Offset(0, 0),
                blurRadius: 20,
                color: Colors.white.withValues(alpha: 0.8),
              ),
              Shadow(
                offset: const Offset(0, 0),
                blurRadius: 40,
                color: Colors.white.withValues(alpha: 0.6),
              ),
              Shadow(
                offset: const Offset(0, 0),
                blurRadius: 60,
                color: Colors.white.withValues(alpha: 0.4),
              ),
              Shadow(
                offset: const Offset(0, 2),
                blurRadius: 8,
                color: Colors.black.withValues(alpha: 0.3),
              ),
              Shadow(
                offset: const Offset(0, 4),
                blurRadius: 16,
                color: Colors.black.withValues(alpha: 0.2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDescription(bool isTablet, bool isSmallScreen) {
    return Text(
      'We\'ve sent a 6-digit verification code to',
      textAlign: TextAlign.center,
      style: GoogleFonts.albertSans(
        fontSize: isTablet ? 18 : (isSmallScreen ? 15 : 16),
        color: Colors.white.withValues(alpha: 0.9),
        fontWeight: FontWeight.w400,
        shadows: [
          Shadow(
            offset: const Offset(0, 1),
            blurRadius: 4,
            color: Colors.black.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailAddress(bool isTablet, bool isSmallScreen) {
    return Text(
      widget.email,
      textAlign: TextAlign.center,
      style: GoogleFonts.albertSans(
        fontSize: isTablet ? 20 : (isSmallScreen ? 17 : 18),
        color: Colors.white.withValues(alpha: 0.9),
        fontWeight: FontWeight.w600,
        shadows: [
          Shadow(
            offset: const Offset(0, 1),
            blurRadius: 4,
            color: Colors.black.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildOTPFields(bool isTablet, bool isSmallScreen) {
    return ScaleTransition(
      scale: _formScaleAnimation,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _isLoading ? _pulseAnimation.value : 1.0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(6, (index) {
                return Container(
                  width: isTablet ? 60 : 50,
                  height: isTablet ? 70 : 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextFormField(
                    controller: _otpControllers[index],
                    focusNode: _focusNodes[index],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    enabled: !_isLoading,
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 24 : 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.yellowAccent,
                          width: 2,
                        ),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        vertical: isTablet ? 20 : 16,
                      ),
                    ),
                    onChanged: (value) => _onOTPChanged(value, index),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                  ),
                );
              }),
            ),
          );
        },
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
          BoxShadow(
            color: AppColors.yellowAccent.withValues(alpha: 0.3),
            blurRadius: 40,
            spreadRadius: 0,
            offset: const Offset(0, 16),
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
          padding: EdgeInsets.zero,
        ),
        child: _isLoading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                'Verify Email',
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 18 : (isSmallScreen ? 15 : 16),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }

  Widget _buildResendSection(bool isTablet, bool isSmallScreen) {
    return Column(
      children: [
        // Timer text
        if (!_canResend)
          Text(
            'Resend code in ${_resendTimer}s',
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 18 : (isSmallScreen ? 15 : 16),
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w400,
              shadows: [
                Shadow(
                  offset: const Offset(0, 1),
                  blurRadius: 4,
                  color: Colors.black.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),

        SizedBox(height: isSmallScreen ? 12 : 16),

        // Resend button
        GestureDetector(
          onTap: _canResend && !_isLoading ? _resendOTP : null,
          child: Text(
            'Didn\'t receive the code? Resend',
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 18 : (isSmallScreen ? 15 : 16),
              color: _canResend && !_isLoading
                  ? Colors.white.withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w400,
              decoration: _canResend && !_isLoading
                  ? TextDecoration.underline
                  : TextDecoration.none,
              decorationColor: Colors.white,
              shadows: [
                Shadow(
                  offset: const Offset(0, 1),
                  blurRadius: 4,
                  color: Colors.black.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
