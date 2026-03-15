import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:lottie/lottie.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'forgot_password_otp_screen.dart';
import 'package:shiffters/theme/app_colors.dart';


class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _formAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _formScaleAnimation;
  
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  bool _isLoading = false;
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
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _formAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
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
    
    _formScaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _formAnimationController,
      curve: Curves.easeOutBack,
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
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _formAnimationController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // Simple method to check if email exists in Firestore users collection
  Future<bool> _checkEmailExistsInFirestore(String email) async {
    try {
      print('Checking email in Firestore: $email'); // Debug log
      
      // Query the users collection for documents where email field matches
      final QuerySnapshot querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      
      bool exists = querySnapshot.docs.isNotEmpty;
      print('Email exists in Firestore: $exists'); // Debug log
      
      return exists;
      
    } catch (e) {
      print('Error checking email in Firestore: $e'); // Debug log
      
      // Handle specific Firestore errors
      if (e.toString().contains('network')) {
        throw 'Network error. Please check your internet connection.';
      } else if (e.toString().contains('permission')) {
        throw 'Permission denied. Please contact support.';
      } else {
        throw 'Unable to verify email. Please try again.';
      }
    }
  }

  // OTP Server Configuration
  static const String _otpServerUrl = 'https://otp-server-qa0y.onrender.com';

  Future<Map<String, dynamic>> _sendOTPEmail(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$_otpServerUrl/send-otp'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'email': email,
          'name': 'User',
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        Map<String, dynamic> result = json.decode(response.body);
        return result;
      } else {
        try {
          Map<String, dynamic> errorResult = json.decode(response.body);
          return {
            'success': false,
            'error': errorResult['error'] ?? 'Failed to send OTP. Server returned ${response.statusCode}',
          };
        } catch (e) {
          return {
            'success': false,
            'error': 'Server error: ${response.statusCode}. Please try again.',
          };
        }
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: Unable to connect to email service. Please check your internet connection and try again.',
      };
    }
  }

  void _onSendResetPressed() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      HapticFeedback.lightImpact();
      
      try {
        // Check if email exists in Firestore users collection
        bool emailExists = await _checkEmailExistsInFirestore(_emailController.text.trim());
        
        if (!emailExists) {
          setState(() {
            _isLoading = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '❌ Email Not Found',
                    style: GoogleFonts.albertSans(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'No account found with this email address.',
                    style: GoogleFonts.albertSans(fontWeight: FontWeight.w400, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Please check your email or create a new account.',
                    style: GoogleFonts.albertSans(fontWeight: FontWeight.w400, fontSize: 13, color: Colors.white.withValues(alpha: 0.9)),
                  ),
                ],
              ),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 4),
              margin: const EdgeInsets.all(16),
            ),
          );
          return;
        }
        
        // If email exists in Firestore, proceed to send OTP
        Map<String, dynamic> result = await _sendOTPEmail(_emailController.text.trim());
        
        setState(() {
          _isLoading = false;
        });
        
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '✅ OTP Sent!',
                    style: GoogleFonts.albertSans(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Check your email: ${_emailController.text}',
                    style: GoogleFonts.albertSans(fontWeight: FontWeight.w400, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Enter the 6-digit code to reset your password',
                    style: GoogleFonts.albertSans(fontWeight: FontWeight.w400, fontSize: 13, color: Colors.white.withValues(alpha: 0.9)),
                  ),
                ],
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 3),
              margin: const EdgeInsets.all(16),
            ),
          );
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ForgotPasswordOTPScreen(
                  email: _emailController.text.trim(),
                  sentOTP: result['otp'],
                ),
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '❌ Failed to Send OTP',
                    style: GoogleFonts.albertSans(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    result['error'] ?? 'Unknown error occurred',
                    style: GoogleFonts.albertSans(fontWeight: FontWeight.w400, fontSize: 12),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 8),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '❌ Verification Failed',
                  style: GoogleFonts.albertSans(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  e.toString(),
                  style: GoogleFonts.albertSans(fontWeight: FontWeight.w400, fontSize: 14),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 4),
            margin: const EdgeInsets.all(16),
          ),
        );
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
          // Full screen background animation
          _buildBackgroundAnimation(),
          
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
                      
                      // Header with icon and title
                      _buildHeader(isTablet, isSmallScreen),
                      
                      SizedBox(height: isSmallScreen ? 40 : 60),
                      
                      // Email input form
                      _buildForm(isTablet, isSmallScreen),
                      
                      SizedBox(height: isSmallScreen ? 30 : 40),
                      
                      // Send Reset Email Button
                      _buildSendResetButton(isTablet, isSmallScreen),
                      
                      SizedBox(height: isSmallScreen ? 30 : 40),
                      
                      // Back to login link
                      _buildBackToLoginLink(isTablet, isSmallScreen),
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

  Widget _buildBackgroundAnimation() {
    return Positioned.fill(
      child: Lottie.asset(
        'assets/animations/mountain.json',
        fit: BoxFit.cover,
        repeat: true,
        animate: _animationsStarted,
        frameRate: FrameRate.max,
        filterQuality: FilterQuality.high,
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
            // Lock icon with glowing effect
            Container(
              padding: EdgeInsets.all(isTablet ? 20 : 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                Icons.lock_reset,
                size: isTablet ? 60 : 50,
                color: Colors.white,
              ),
            ),
            
            SizedBox(height: isSmallScreen ? 20 : 30),
            
            // Title with enhanced glowing effect
            Text(
              'Forgot Password?',
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
                ],
              ),
            ),
            
            SizedBox(height: isSmallScreen ? 12 : 16),
            
            // Subtitle
            Text(
              'Enter your email address and we\'ll send you\na link to reset your password.',
              textAlign: TextAlign.center,
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 16 : (isSmallScreen ? 14 : 15),
                fontWeight: FontWeight.w400,
                color: Colors.white.withValues(alpha: 0.8),
                letterSpacing: 0.3,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(bool isTablet, bool isSmallScreen) {
    return ScaleTransition(
      scale: _formScaleAnimation,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Email Field
            _buildInputField(
              controller: _emailController,
              hintText: 'Enter your email address',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email address';
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                  return 'Please enter a valid email address';
                }
                return null;
              },
              isTablet: isTablet,
              isSmallScreen: isSmallScreen,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    required bool isTablet,
    required bool isSmallScreen,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        style: GoogleFonts.albertSans(
          fontSize: isTablet ? 16 : (isSmallScreen ? 14 : 15),
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.albertSans(
            color: AppColors.grey500,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(
            icon,
            color: AppColors.grey600,
            size: isTablet ? 24 : 20,
          ),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.9),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: AppColors.yellowAccent,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: AppColors.error,
              width: 1,
            ),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: isTablet ? 20 : 16,
            vertical: isTablet ? 20 : 16,
          ),
        ),
      ),
    );
  }

  Widget _buildSendResetButton(bool isTablet, bool isSmallScreen) {
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
        onPressed: _isLoading ? null : _onSendResetPressed,
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
                'Send Reset Email',
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 18 : (isSmallScreen ? 15 : 16),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }

  Widget _buildBackToLoginLink(bool isTablet, bool isSmallScreen) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.pop(context);
      },
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: GoogleFonts.albertSans(
            fontSize: isTablet ? 16 : (isSmallScreen ? 13 : 14),
            color: Colors.white.withValues(alpha: 0.8),
          ),
          children: [
            const TextSpan(text: "Remember your password? "),
            TextSpan(
              text: 'Back to Login',
              style: GoogleFonts.albertSans(
                fontWeight: FontWeight.w600,
                color: AppColors.yellowAccent,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.yellowAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}