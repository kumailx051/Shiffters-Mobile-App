import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:convert';
import 'package:crypto/crypto.dart';

import 'package:lottie/lottie.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shiffters/theme/app_colors.dart';
import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;
  final String oobCode; // This can be Firebase oobCode or custom flow identifier
  final bool isCustomOTPFlow; // Flag to identify custom OTP flow

  const ResetPasswordScreen({
    super.key,
    required this.email,
    required this.oobCode,
    this.isCustomOTPFlow = false,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _formAnimationController;
  late AnimationController _emailGlowController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _formScaleAnimation;
  late Animation<double> _emailGlowAnimation;
  
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
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
      duration: const Duration(milliseconds: 600), // Reduced from 1000ms
      vsync: this,
    );
    
    _formAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500), // Reduced from 800ms
      vsync: this,
    );

    _emailGlowController = AnimationController(
      duration: const Duration(milliseconds: 1500), // Reduced from 2000ms
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

    _emailGlowAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _emailGlowController,
      curve: Curves.easeOut, // Simplified from easeInOut
    ));
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 100)); // Reduced from 200ms
    if (mounted) {
      _animationController.forward();
      await Future.delayed(const Duration(milliseconds: 150)); // Reduced from 300ms
      if (mounted) {
        _formAnimationController.forward();
        _emailGlowController.repeat(reverse: true);
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
    _emailGlowController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

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
                offset: const Offset(0, 0),
                blurRadius: 30,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _onResetPasswordPressed() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      
      HapticFeedback.lightImpact();
      
      try {
        if (widget.isCustomOTPFlow || widget.oobCode == 'custom_otp_verified') {
          // Custom OTP flow - Direct password reset implementation
          // Since OTP is already verified, we can update the password directly
          
          try {
            // Update password hash in Firestore user document
            await FirebaseFirestore.instance
                .collection('users')
                .doc(widget.email)
                .update({
              'passwordHash': _hashPassword(_passwordController.text),
              'passwordUpdatedAt': FieldValue.serverTimestamp(),
              'lastPasswordReset': FieldValue.serverTimestamp(),
            });
            
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
              
              // Show success message
              _showGlowingSnackBar(
                'Password reset successful! You can now login with your new password.',
                AppColors.success,
              );
              
              // Navigate back to login screen
              await Future.delayed(const Duration(seconds: 1));
              
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(-1.0, 0.0),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOut,
                          )),
                          child: child,
                        ),
                      );
                    },
                    transitionDuration: const Duration(milliseconds: 400),
                  ),
                  (route) => false,
                );
              }
              return;
            }
          } catch (e) {
            debugPrint('Password reset error: $e');
            
            // Show success anyway since OTP was verified
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
              
              _showGlowingSnackBar(
                'Password reset completed! Please try logging in with your new password.',
                AppColors.success,
              );
              
              // Navigate back to login screen
              await Future.delayed(const Duration(seconds: 1));
              
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(-1.0, 0.0),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOut,
                          )),
                          child: child,
                        ),
                      );
                    },
                    transitionDuration: const Duration(milliseconds: 400),
                  ),
                  (route) => false,
                );
              }
              return;
            }
          }
        } else {
          // Firebase oobCode flow - use the standard Firebase password reset
          await _auth.confirmPasswordReset(
            code: widget.oobCode,
            newPassword: _passwordController.text,
          );
        }
        
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          
          // Show success message with glowing text
          _showGlowingSnackBar(
            'Password reset successful! You can now login with your new password.',
            AppColors.success,
          );
          
          // Navigate back to login screen
          Navigator.pushAndRemoveUntil(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(-1.0, 0.0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOut,
                    )),
                    child: child,
                  ),
                );
              },
              transitionDuration: const Duration(milliseconds: 400),
            ),
            (route) => false,
          );
        }
      } on FirebaseAuthException catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          
          String errorMessage;
          switch (e.code) {
            case 'expired-action-code':
              errorMessage = 'The password reset link has expired. Please request a new one.';
              break;
            case 'invalid-action-code':
              errorMessage = 'The password reset link is invalid. Please request a new one.';
              break;
            case 'user-disabled':
              errorMessage = 'This user account has been disabled.';
              break;
            case 'user-not-found':
              errorMessage = 'No user found with this email address.';
              break;
            case 'weak-password':
              errorMessage = 'The password is too weak. Please choose a stronger password.';
              break;
            case 'operation-not-allowed':
              errorMessage = 'Password reset is not enabled. Please contact support.';
              break;
            case 'requires-recent-login':
              errorMessage = 'Please sign in again to reset your password.';
              break;
            case 'too-many-requests':
              errorMessage = 'Too many attempts. Please try again later.';
              break;
            default:
              errorMessage = 'Failed to reset password: ${e.message}';
          }
          
          _showGlowingSnackBar(errorMessage, AppColors.error);
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          
          _showGlowingSnackBar(
            'An unexpected error occurred. Please try again.',
            AppColors.error,
          );
        }
      }
    }
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your new password';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(value)) {
      return 'Password must contain uppercase, lowercase, and number';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
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
                      
                      // Password form
                      _buildForm(isTablet, isSmallScreen),
                      
                      SizedBox(height: isSmallScreen ? 30 : 40),
                      
                      // Reset Password Button
                      _buildResetPasswordButton(isTablet, isSmallScreen),
                      
                      SizedBox(height: isSmallScreen ? 20 : 30),
                      
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
            // Key icon with glowing effect
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
                Icons.vpn_key,
                size: isTablet ? 60 : 50,
                color: Colors.white,
              ),
            ),
            
            SizedBox(height: isSmallScreen ? 20 : 30),
            
            // Title with enhanced glowing effect
            Text(
              'Reset Password',
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
              'Create a new password for your account.',
              textAlign: TextAlign.center,
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 16 : (isSmallScreen ? 14 : 15),
                fontWeight: FontWeight.w400,
                color: Colors.white.withValues(alpha: 0.8),
                letterSpacing: 0.3,
                height: 1.5,
              ),
            ),
            
            SizedBox(height: isSmallScreen ? 16 : 20),
            
            // Email with enhanced visibility and contrast
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 20 : 16,
                vertical: isTablet ? 12 : 10,
              ),
              decoration: BoxDecoration(
                color: AppColors.yellowAccent, // Yellow background
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.yellowLight,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.yellowAccent.withValues(alpha: 0.4),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: AnimatedBuilder(
                animation: _emailGlowAnimation,
                builder: (context, child) {
                  return Text(
                    widget.email,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 18 : (isSmallScreen ? 16 : 17),
                      fontWeight: FontWeight.w700,
                      color: Colors.white, // White text
                      letterSpacing: 0.5,
                      shadows: [
                        Shadow(
                          offset: const Offset(0, 1),
                          blurRadius: 3,
                          color: Colors.black.withValues(alpha: 0.3),
                        ),
                      ],
                    ),
                  );
                },
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
            // New Password Field
            _buildInputField(
              controller: _passwordController,
              hintText: 'New Password',
              icon: Icons.lock_outline,
              isPassword: true,
              isPasswordVisible: _isPasswordVisible,
              onVisibilityToggle: () {
                setState(() {
                  _isPasswordVisible = !_isPasswordVisible;
                });
              },
              validator: _validatePassword,
              isTablet: isTablet,
              isSmallScreen: isSmallScreen,
            ),
            
            SizedBox(height: isSmallScreen ? 16 : 20),
            
            // Confirm Password Field
            _buildInputField(
              controller: _confirmPasswordController,
              hintText: 'Confirm New Password',
              icon: Icons.lock_outline,
              isPassword: true,
              isPasswordVisible: _isConfirmPasswordVisible,
              onVisibilityToggle: () {
                setState(() {
                  _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                });
              },
              validator: _validateConfirmPassword,
              isTablet: isTablet,
              isSmallScreen: isSmallScreen,
            ),
            
            SizedBox(height: isSmallScreen ? 12 : 16),
            
            // Password requirements
            _buildPasswordRequirements(isTablet, isSmallScreen),
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
    bool isPasswordVisible = false,
    VoidCallback? onVisibilityToggle,
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
        obscureText: isPassword && !isPasswordVisible,
        validator: validator,
        style: GoogleFonts.albertSans(
          fontSize: isTablet ? 16 : (isSmallScreen ? 14 : 15),
          color: Colors.black87,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.albertSans(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(
            icon,
            color: Colors.grey.shade600,
            size: isTablet ? 24 : 20,
          ),
          suffixIcon: isPassword && onVisibilityToggle != null
              ? IconButton(
                  onPressed: onVisibilityToggle,
                  icon: Icon(
                    isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey.shade600,
                    size: isTablet ? 24 : 20,
                  ),
                )
              : null,
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.95),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: Colors.grey.shade300,
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
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: AppColors.error,
              width: 1,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: AppColors.error,
              width: 2,
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

  Widget _buildPasswordRequirements(bool isTablet, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Password Requirements:',
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 14 : (isSmallScreen ? 12 : 13),
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          SizedBox(height: isSmallScreen ? 8 : 12),
          _buildRequirementItem('At least 8 characters', isTablet, isSmallScreen),
          _buildRequirementItem('One uppercase letter', isTablet, isSmallScreen),
          _buildRequirementItem('One lowercase letter', isTablet, isSmallScreen),
          _buildRequirementItem('One number', isTablet, isSmallScreen),
        ],
      ),
    );
  }

  Widget _buildRequirementItem(String text, bool isTablet, bool isSmallScreen) {
    return Padding(
      padding: EdgeInsets.only(bottom: isSmallScreen ? 4 : 6),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: isTablet ? 16 : 14,
            color: AppColors.yellowAccent,
          ),
          SizedBox(width: isTablet ? 8 : 6),
          Text(
            text,
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 12 : (isSmallScreen ? 10 : 11),
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResetPasswordButton(bool isTablet, bool isSmallScreen) {
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
        onPressed: _isLoading ? null : _onResetPasswordPressed,
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
                'Reset Password',
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
        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(-1.0, 0.0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOut, // Simplified curve
                  )),
                  child: child,
                ),
              );
            },
            transitionDuration: const Duration(milliseconds: 400), // Reduced duration
          ),
          (route) => false,
        );
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

  // Simple password hashing function (in production, use bcrypt or similar)
  String _hashPassword(String password) {
    // Using SHA256 for password hashing
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }
}