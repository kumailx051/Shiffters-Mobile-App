import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shiffters/theme/app_colors.dart';
import 'package:shiffters/screens/auth/createAccount_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _formAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _formScaleAnimation;
  
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isPasswordVisible = false;
  bool _rememberMe = false;
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
    _passwordController.dispose();
    super.dispose();
  }

  void _onSignInPressed() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      
      HapticFeedback.lightImpact();
      
      // Simulate API call
      await Future.delayed(const Duration(seconds: 2));
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        // Navigate to home screen or show success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Login successful!',
              style: GoogleFonts.albertSans(fontWeight: FontWeight.w500),
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _onForgotPasswordPressed() {
    HapticFeedback.lightImpact();
    // Navigate to forgot password screen
    print('Forgot password pressed');
    
    // Show dialog for now
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Forgot Password',
          style: GoogleFonts.albertSans(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Password reset functionality will be implemented here.',
          style: GoogleFonts.albertSans(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: GoogleFonts.albertSans(
                color: AppColors.lightPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onCreateAccountPressed() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const CreateAccountScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(-1.0, 0.0),
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
                      
                      SizedBox(height: isSmallScreen ? 30 : 60),
                      
                      // Welcome text and title
                      _buildHeader(isTablet, isSmallScreen),
                      
                      SizedBox(height: isSmallScreen ? 40 : 60),
                      
                      // Form
                      _buildForm(isTablet, isSmallScreen),
                      
                      SizedBox(height: isSmallScreen ? 16 : 20),
                      
                      // Remember me checkbox
                      _buildRememberMe(isTablet, isSmallScreen),
                      
                      SizedBox(height: isSmallScreen ? 30 : 40),
                      
                      // Sign In Button
                      _buildSignInButton(isTablet, isSmallScreen),
                      
                      SizedBox(height: isSmallScreen ? 20 : 30),
                      
                      // Forgot password link
                      _buildForgotPasswordLink(isTablet, isSmallScreen),
                      
                      SizedBox(height: isSmallScreen ? 20 : 30),
                      
                      // Create account link
                      _buildCreateAccountLink(isTablet, isSmallScreen),
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

  Widget _buildHeader(bool isTablet, bool isSmallScreen) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Column(
          children: [
            // Welcome back text with glowing effect
            Text(
              'Welcome Back',
              textAlign: TextAlign.center,
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 18 : (isSmallScreen ? 14 : 16),
                fontWeight: FontWeight.w500,
                color: Colors.white,
                letterSpacing: 0.5,
                shadows: [
                  // Glowing effect for welcome text
                  Shadow(
                    offset: const Offset(0, 0),
                    blurRadius: 15,
                    color: Colors.white.withOpacity(0.7),
                  ),
                  Shadow(
                    offset: const Offset(0, 0),
                    blurRadius: 30,
                    color: Colors.white.withOpacity(0.5),
                  ),
                  Shadow(
                    offset: const Offset(0, 0),
                    blurRadius: 45,
                    color: Colors.white.withOpacity(0.3),
                  ),
                  // Regular shadow for depth
                  Shadow(
                    offset: const Offset(0, 1),
                    blurRadius: 4,
                    color: Colors.black.withOpacity(0.3),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: isSmallScreen ? 8 : 12),
            
            // Sign In title with enhanced glowing effect
            Text(
              'Sign In',
              textAlign: TextAlign.center,
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 36 : (isSmallScreen ? 28 : 32),
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.0,
                shadows: [
                  // Enhanced glowing effect - multiple shadows for better glow
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
                  Shadow(
                    offset: const Offset(0, 0),
                    blurRadius: 80,
                    color: Colors.white.withOpacity(0.2),
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

  Widget _buildRememberMe(bool isTablet, bool isSmallScreen) {
    return ScaleTransition(
      scale: _formScaleAnimation,
      child: Row(
        children: [
          Transform.scale(
            scale: isTablet ? 1.2 : 1.0,
            child: Checkbox(
              value: _rememberMe,
              onChanged: (value) {
                setState(() {
                  _rememberMe = value ?? false;
                });
                HapticFeedback.selectionClick();
              },
              activeColor: AppColors.yellowAccent,
              checkColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              side: BorderSide(
                color: Colors.white.withOpacity(0.6),
                width: 2,
              ),
            ),
          ),
          SizedBox(width: isTablet ? 12 : 8),
          Text(
            'Remember me',
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 16 : (isSmallScreen ? 13 : 14),
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignInButton(bool isTablet, bool isSmallScreen) {
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
        onPressed: _isLoading ? null : _onSignInPressed,
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
                'Sign In',
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 18 : (isSmallScreen ? 15 : 16),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }

  Widget _buildForgotPasswordLink(bool isTablet, bool isSmallScreen) {
    return GestureDetector(
      onTap: _onForgotPasswordPressed,
      child: Text(
        'Forgot password?',
        style: GoogleFonts.albertSans(
          fontSize: isTablet ? 16 : (isSmallScreen ? 13 : 14),
          color: Colors.white.withOpacity(0.8),
          fontWeight: FontWeight.w500,
          decoration: TextDecoration.underline,
          decorationColor: Colors.white.withOpacity(0.8),
        ),
      ),
    );
  }

  Widget _buildCreateAccountLink(bool isTablet, bool isSmallScreen) {
    return GestureDetector(
      onTap: _onCreateAccountPressed,
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: GoogleFonts.albertSans(
            fontSize: isTablet ? 16 : (isSmallScreen ? 13 : 14),
            color: Colors.white.withOpacity(0.8),
          ),
          children: [
            const TextSpan(text: "Don't have an account? "),
            TextSpan(
              text: 'Create Account',
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