import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shiffters/theme/app_colors.dart';
import 'login_screen.dart';
import 'otpVerification_screen.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _formAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _formScaleAnimation;
  
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _animationsStarted = false;

  // OTP Server Configuration
  static const String _otpServerUrl = 'https://otp-server-qa0y.onrender.com';

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
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Send OTP using HTTP request to Python server
  Future<Map<String, dynamic>> _sendOTPEmail(String email, String name) async {
    try {
    // Send OTP request directly (no health check needed)
    final response = await http.post(
      Uri.parse('$_otpServerUrl/send-otp'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'email': email,
        'name': name,
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      Map<String, dynamic> result = json.decode(response.body);
      return result;
    } else {
      // Try to parse error response
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

  void _onSignUpPressed() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      
      HapticFeedback.lightImpact();
      
      try {
        // Send OTP email using HTTP request
        Map<String, dynamic> result = await _sendOTPEmail(
          _emailController.text.trim(),
          _nameController.text.trim(),
        );
        
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          
          if (result['success'] == true) {
            // Show success message (without OTP code)
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '✅ Verification Email Sent!',
                      style: GoogleFonts.albertSans(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Check your email: ${_emailController.text}',
                      style: GoogleFonts.albertSans(
                        fontWeight: FontWeight.w400,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Enter the 6-digit code to verify your account',
                      style: GoogleFonts.albertSans(
                        fontWeight: FontWeight.w400,
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                duration: const Duration(seconds: 3),
                margin: const EdgeInsets.all(16),
              ),
            );
            
            // Navigate to OTP verification screen
            await Future.delayed(const Duration(milliseconds: 500));
            if (mounted) {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => OTPVerificationScreen(
                    email: _emailController.text.trim(),
                    name: _nameController.text.trim(),
                    sentOTP: result['otp'],
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
            }
            
          } else {
            // Show error message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '❌ Failed to Send Email',
                      style: GoogleFonts.albertSans(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      result['error'] ?? 'Unknown error occurred',
                      style: GoogleFonts.albertSans(
                        fontWeight: FontWeight.w400,
                        fontSize: 12,
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                duration: const Duration(seconds: 8),
                margin: const EdgeInsets.all(16),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'An unexpected error occurred: $e',
                style: GoogleFonts.albertSans(fontWeight: FontWeight.w500),
              ),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    }
  }

  void _onGoogleSignUpPressed() {
    HapticFeedback.lightImpact();
    // Implement Google Sign Up
    print('Google Sign Up pressed');
  }

  void _onLoginPressed() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
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
                      
                      SizedBox(height: isSmallScreen ? 20 : 40),
                      
                      // Title
                      _buildTitle(isTablet, isSmallScreen),
                      
                      SizedBox(height: isSmallScreen ? 30 : 50),
                      
                      // Form
                      _buildForm(isTablet, isSmallScreen),
                      
                      SizedBox(height: isSmallScreen ? 20 : 30),
                      
                      // Sign Up Button
                      _buildSignUpButton(isTablet, isSmallScreen),
                      
                      SizedBox(height: isSmallScreen ? 20 : 30),
                      
                      // Separator
                      _buildSeparator(isTablet),
                      
                      SizedBox(height: isSmallScreen ? 20 : 30),
                      
                      // Google Sign Up
                      _buildGoogleSignUp(isTablet, isSmallScreen),
                      
                      SizedBox(height: isSmallScreen ? 20 : 30),
                      
                      // Login link
                      _buildLoginLink(isTablet, isSmallScreen),
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
        'assets/animations/train.json',
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
            color: Colors.white.withOpacity(0.2),
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

  Widget _buildTitle(bool isTablet, bool isSmallScreen) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Text(
          'Create\nAccount',
          textAlign: TextAlign.center,
          style: GoogleFonts.albertSans(
            fontSize: isTablet ? 36 : (isSmallScreen ? 28 : 32),
            fontWeight: FontWeight.bold,
            color: Colors.white,
            height: 1.2,
            shadows: [
              // Enhanced glowing effect
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
            // Name Field
            _buildInputField(
              controller: _nameController,
              hintText: 'Name',
              icon: Icons.person_outline,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your name';
                }
                return null;
              },
              isTablet: isTablet,
              isSmallScreen: isSmallScreen,
            ),
            
            SizedBox(height: isSmallScreen ? 16 : 20),
            
            // Email Field
            _buildInputField(
              controller: _emailController,
              hintText: 'Email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                  return 'Please enter a valid email';
                }
                return null;
              },
              isTablet: isTablet,
              isSmallScreen: isSmallScreen,
            ),
            
            SizedBox(height: isSmallScreen ? 16 : 20),
            
            // Password Field
            _buildInputField(
              controller: _passwordController,
              hintText: 'Password',
              icon: Icons.lock_outline,
              isPassword: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your password';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
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
    bool isPassword = false,
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
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword && !_isPasswordVisible,
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
          suffixIcon: isPassword
              ? IconButton(
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                  icon: Icon(
                    _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.grey600,
                    size: isTablet ? 24 : 20,
                  ),
                )
              : null,
          filled: true,
          fillColor: Colors.white.withOpacity(0.9),
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

  Widget _buildSignUpButton(bool isTablet, bool isSmallScreen) {
    final buttonWidth = isTablet ? 320.0 : double.infinity;
    final buttonHeight = isTablet ? 56.0 : 52.0;
    
    return Container(
      width: buttonWidth,
      height: buttonHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
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
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _onSignUpPressed,
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
                'Sign Up',
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 18 : (isSmallScreen ? 15 : 16),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }

  Widget _buildSeparator(bool isTablet) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withOpacity(0.3),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'or',
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 16 : 14,
              color: Colors.white.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withOpacity(0.3),
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleSignUp(bool isTablet, bool isSmallScreen) {
    return Container(
      width: isTablet ? 60.0 : 56.0,
      height: isTablet ? 60.0 : 56.0,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        onPressed: _onGoogleSignUpPressed,
        icon: Icon(
          Icons.g_mobiledata,
          color: Colors.red,
          size: isTablet ? 32 : 28,
        ),
      ),
    );
  }

  Widget _buildLoginLink(bool isTablet, bool isSmallScreen) {
    return GestureDetector(
      onTap: _onLoginPressed,
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: GoogleFonts.albertSans(
            fontSize: isTablet ? 16 : (isSmallScreen ? 13 : 14),
            color: Colors.white.withOpacity(0.8),
          ),
          children: [
            const TextSpan(text: 'Already have account? '),
            TextSpan(
              text: 'Login',
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
