import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shiffters/theme/app_colors.dart';
import 'package:shiffters/screens/auth/createAccount_screen.dart';
import 'package:shiffters/screens/auth/forgot_password_screen.dart';
import 'package:shiffters/screens/user/home_screen.dart';
import 'package:shiffters/screens/admin/admin_dashboard_screen.dart';

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

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();

    _initializeAnimations();
    _startAnimations();
    _loadRememberMePreference();
    _checkAutoLogin();

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
  }

  void _startAnimations() async {
    await Future.delayed(
        const Duration(milliseconds: 100)); // Reduced from 200ms
    if (mounted) {
      _animationController.forward();
      await Future.delayed(
          const Duration(milliseconds: 150)); // Reduced from 300ms
      if (mounted) {
        _formAnimationController.forward();
        setState(() {
          _animationsStarted = true;
        });
      }
    }
  }

  // Load Remember Me preference
  void _loadRememberMePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rememberMeEnabled = prefs.getBool('remember_me') ?? false;
      final savedEmail = prefs.getString('saved_email') ?? '';
      final savedPassword = prefs.getString('saved_password') ?? '';

      debugPrint('Loading remember me preference: $rememberMeEnabled');
      debugPrint('Saved email: $savedEmail');

      setState(() {
        _rememberMe = rememberMeEnabled;
      });

      // Load saved credentials if remember me is enabled and credentials exist
      if (_rememberMe && savedEmail.isNotEmpty && savedPassword.isNotEmpty) {
        _emailController.text = savedEmail;
        _passwordController.text = savedPassword;
        debugPrint('Loaded saved credentials for: $savedEmail');
      } else if (_rememberMe && (savedEmail.isEmpty || savedPassword.isEmpty)) {
        // Remember me is enabled but credentials are missing, disable it
        debugPrint(
            'Remember me enabled but credentials missing, clearing preferences');
        await _clearAutoLoginData();
        setState(() {
          _rememberMe = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading remember me preference: $e');
    }
  }

  // Check for auto login
  void _checkAutoLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shouldAutoLogin = prefs.getBool('auto_login') ?? false;
      final savedEmail = prefs.getString('saved_email') ?? '';
      final savedPassword = prefs.getString('saved_password') ?? '';

      debugPrint('🔄 Auto-login check: shouldAutoLogin=$shouldAutoLogin');
      debugPrint('💾 Saved email: $savedEmail');
      debugPrint('🔐 Current user: ${_auth.currentUser?.email}');

      if (shouldAutoLogin &&
          savedEmail.isNotEmpty &&
          savedPassword.isNotEmpty) {
        // Check if current user matches saved credentials
        if (_auth.currentUser != null &&
            _auth.currentUser!.email == savedEmail) {
          // Current Firebase user matches saved email, proceed with auto login
          debugPrint('✅ Auto login: Current user matches saved credentials');
          debugPrint(
              '🚀 Auto login: Proceeding with existing session for ${_auth.currentUser!.email}');
          debugPrint(
              '⚡ Auto login: Calling _navigateBasedOnRole from login screen');
          await _updateLastLoginTime(_auth.currentUser!.uid);
          await _navigateBasedOnRole(_auth.currentUser!);
        } else {
          // Current user doesn't match or no user signed in, sign out and re-authenticate
          debugPrint('🔄 Auto login: Re-authenticating with saved credentials');
          debugPrint(
              '❌ Current user (${_auth.currentUser?.email}) does not match saved email ($savedEmail)');
          if (_auth.currentUser != null) {
            await _auth.signOut();
          }

          // Attempt to sign in with saved credentials
          debugPrint(
              '🔐 Auto login: Signing in with saved credentials for $savedEmail');
          final result =
              await _signInWithSavedCredentials(savedEmail, savedPassword);
          if (result['success'] && mounted) {
            final User user = result['user'];
            debugPrint('✅ Auto login successful for ${user.email}');
            await _updateLastLoginTime(user.uid);
            await _navigateBasedOnRole(user);
          } else {
            // Auto login failed, clear saved credentials and show login screen
            debugPrint('❌ Auto login failed: ${result['error']}');
            await _clearAutoLoginData();
          }
        }
      } else {
        debugPrint('ℹ️ Auto login not enabled or credentials missing');
      }
    } catch (e) {
      debugPrint('❌ Error checking auto login: $e');
      await _clearAutoLoginData();
    }
  }

  // Sign in with saved credentials for auto login
  Future<Map<String, dynamic>> _signInWithSavedCredentials(
      String email, String password) async {
    try {
      final UserCredential userCredential =
          await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        return {
          'success': true,
          'user': userCredential.user,
          'message': 'Auto login successful!',
        };
      } else {
        return {
          'success': false,
          'error': 'Auto login failed. Please sign in again.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Auto login failed: $e',
      };
    }
  }

  // Clear auto login data
  Future<void> _clearAutoLoginData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auto_login', false);
      await prefs.setBool('remember_me', false);
      await prefs.remove('saved_email');
      await prefs.remove('saved_password');
    } catch (e) {
      debugPrint('Error clearing auto login data: $e');
    }
  }

  // Save Remember Me preference
  Future<void> _saveRememberMePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remember_me', _rememberMe);

      if (_rememberMe) {
        // Save credentials only for the currently authenticated user
        final currentEmail = _emailController.text.trim();
        debugPrint('Saving remember me for: $currentEmail');

        await prefs.setString('saved_email', currentEmail);
        await prefs.setString('saved_password', _passwordController.text);
        await prefs.setBool('auto_login', true);

        debugPrint('Remember me preferences saved successfully');
      } else {
        // Clear saved credentials
        debugPrint('Clearing remember me preferences');
        await prefs.remove('saved_email');
        await prefs.remove('saved_password');
        await prefs.setBool('auto_login', false);
      }
    } catch (e) {
      debugPrint('Error saving remember me preference: $e');
    }
  }

  // Update last login time in Firestore
  Future<Map<String, dynamic>> _updateLastLoginTime(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Last login time updated successfully for user: $uid');
      return {
        'success': true,
        'message': 'Last login time updated successfully',
      };
    } catch (e) {
      debugPrint('❌ Error updating last login time: $e');
      return {
        'success': false,
        'error': 'Failed to update last login time: $e',
      };
    }
  }

  // Get user role from Firestore
  Future<String> _getUserRole(String uid) async {
    try {
      debugPrint('🔍 Getting user role for UID: $uid');

      // Get current user email for fallback check
      final currentUserEmail = _auth.currentUser?.email ?? '';
      debugPrint('📧 Current user email: $currentUserEmail');

      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final role = userData['role'] ?? 'user';
        debugPrint('✅ User role found: $role for UID: $uid');
        debugPrint('📄 Full user data: $userData');

        // Check if role is admin (case insensitive)
        if (role.toString().toLowerCase() == 'admin') {
          return 'admin';
        }

        // Fallback: Check if email contains admin
        if (currentUserEmail.toLowerCase().contains('admin')) {
          debugPrint(
              '🔄 Fallback: Email contains admin, treating as admin user');
          return 'admin';
        }

        return role;
      } else {
        debugPrint('❌ User document does not exist for UID: $uid');

        // Fallback: Check if email contains admin even if document doesn't exist
        if (currentUserEmail.toLowerCase().contains('admin')) {
          debugPrint(
              '🔄 Fallback: No document but email contains admin, treating as admin user');
          return 'admin';
        }

        return 'user';
      }
    } catch (e) {
      debugPrint('❌ Error getting user role: $e');

      // Fallback: Check email even on error
      final currentUserEmail = _auth.currentUser?.email ?? '';
      if (currentUserEmail.toLowerCase().contains('admin')) {
        debugPrint(
            '🔄 Error fallback: Email contains admin, treating as admin user');
        return 'admin';
      }

      return 'user';
    }
  }

  // Navigate based on user role
  Future<void> _navigateBasedOnRole(User user) async {
    try {
      debugPrint(
          '🚀 Navigating based on role for user: ${user.email} (UID: ${user.uid})');
      final userRole = await _getUserRole(user.uid);
      debugPrint('🎭 Determined user role: $userRole');

      if (mounted) {
        if (userRole == 'admin') {
          debugPrint('🔐 Navigating to Admin Dashboard');
          // Navigate to Admin Dashboard
          Navigator.pushAndRemoveUntil(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  AdminDashboardScreen(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return ScaleTransition(
                  scale: Tween<double>(
                    begin: 0.8,
                    end: 1.0,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  )),
                  child: FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                );
              },
              transitionDuration: const Duration(milliseconds: 600),
            ),
            (route) => false,
          );
        } else {
          debugPrint('👤 Navigating to User Home Screen');
          // Navigate to User Home Screen
          Navigator.pushAndRemoveUntil(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  HomeScreen(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return ScaleTransition(
                  scale: Tween<double>(
                    begin: 0.8,
                    end: 1.0,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  )),
                  child: FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                );
              },
              transitionDuration: const Duration(milliseconds: 600),
            ),
            (route) => false,
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error navigating based on role: $e');
      _showErrorMessage('Navigation error occurred. Please try again.');
    }
  }

  // Firebase sign in
  Future<Map<String, dynamic>> _signInWithEmailAndPassword() async {
    try {
      final UserCredential userCredential =
          await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (userCredential.user != null) {
        return {
          'success': true,
          'user': userCredential.user,
          'message': 'Login successful!',
        };
      } else {
        return {
          'success': false,
          'error': 'Login failed. Please try again.',
        };
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('🔥 Firebase Auth Error: ${e.code} - ${e.message}');
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found with this email address.';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password. Please try again.';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email address format.';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many failed attempts. Please try again later.';
          break;
        case 'network-request-failed':
          errorMessage = 'Network error. Please check your connection.';
          break;
        default:
          errorMessage = 'Login failed Incorrect Password or Email.';
      }
      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      debugPrint('💥 Unexpected error in _signInWithEmailAndPassword: $e');
      return {
        'success': false,
        'error': 'An unexpected error occurred: $e',
      };
    }
  }

  void _onSignInPressed() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      HapticFeedback.lightImpact();

      try {
        debugPrint(
            '🔄 Starting login process for: ${_emailController.text.trim()}');

        // Skip maintenance mode check for now to avoid Firestore issues
        bool maintenanceMode = false;

        try {
          // Try to check maintenance mode from Firestore (optional)
          final settingsDoc =
              await _firestore.collection('app_settings').doc('global').get();
          maintenanceMode = settingsDoc.data()?['maintenanceMode'] ?? false;
          debugPrint('✅ Maintenance mode check: $maintenanceMode');
        } catch (e) {
          debugPrint(
              '⚠️ Could not check maintenance mode (proceeding anyway): $e');
          // Continue with login even if maintenance check fails
        }

        if (maintenanceMode == true) {
          // Check if user is admin by email (since not logged in yet)
          final email = _emailController.text.trim();
          if (!email.toLowerCase().contains('admin')) {
            setState(() {
              _isLoading = false;
            });
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: const Text('App is under maintenance'),
                content: const Text(
                    'The app is temporarily unavailable due to maintenance. Please try again later.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
            return;
          }
        }

        // Sign in with Firebase
        debugPrint('🔐 Attempting Firebase authentication...');
        Map<String, dynamic> result = await _signInWithEmailAndPassword();
        debugPrint('🔐 Firebase auth result: ${result['success']}');

        if (mounted) {
          setState(() {
            _isLoading = false;
          });

          if (result['success']) {
            final User user = result['user'];
            debugPrint('✅ Login successful for user: ${user.email}');

            // After login, check role in Firestore (with error handling)
            String role = 'user'; // Default role
            try {
              final userDoc =
                  await _firestore.collection('users').doc(user.uid).get();
              role = userDoc.data()?['role'] ?? 'user';
              debugPrint('✅ User role retrieved: $role');
            } catch (e) {
              debugPrint('⚠️ Could not fetch user role (using default): $e');
              // Continue with default role
            }

            if (maintenanceMode == true && role != 'admin') {
              // Sign out and show maintenance dialog
              await _auth.signOut();
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                  title: const Text('App is under maintenance'),
                  content: const Text(
                      'The app is temporarily unavailable due to maintenance. Please try again later.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
              return;
            }

            // Update last login time in Firestore
            debugPrint('🔄 Updating last login time for user: ${user.uid}');
            Map<String, dynamic> loginTimeResult =
                await _updateLastLoginTime(user.uid);
            if (loginTimeResult['success']) {
              debugPrint('✅ Last login time updated successfully');
            } else {
              debugPrint(
                  '⚠️ Failed to update last login time: ${loginTimeResult['error']}');
              // Don't block the login process if lastLoginAt update fails
            }

            // Save remember me preference
            await _saveRememberMePreference();

            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  result['message'],
                  style: GoogleFonts.albertSans(
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                duration: const Duration(seconds: 2),
              ),
            );

            // Navigate based on user role
            await _navigateBasedOnRole(user);
          } else {
            // Show error message with more context
            String errorMessage =
                result['error'] ?? 'Login failed due to an unexpected error.';
            debugPrint('❌ Login failed: $errorMessage');
            _showErrorMessage(errorMessage);
          }
        }
      } catch (e) {
        debugPrint('💥 Unexpected error during login: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          _showErrorMessage(
              'An unexpected error occurred. Please check your connection and try again.');
        }
      }
    }
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.albertSans(
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _formAnimationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onForgotPasswordPressed() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const ForgotPasswordScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  void _onCreateAccountPressed() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const CreateAccountScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
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
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  Shadow(
                    offset: const Offset(0, 0),
                    blurRadius: 30,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  Shadow(
                    offset: const Offset(0, 0),
                    blurRadius: 45,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                  // Regular shadow for depth
                  Shadow(
                    offset: const Offset(0, 1),
                    blurRadius: 4,
                    color: Colors.black.withValues(alpha: 0.3),
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
                    offset: const Offset(0, 0),
                    blurRadius: 80,
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                  // Regular shadows for depth
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
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                    .hasMatch(value)) {
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
            color: Colors.black.withValues(alpha: 0.1),
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
                    _isPasswordVisible
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: AppColors.grey600,
                    size: isTablet ? 24 : 20,
                  ),
                )
              : null,
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
                color: Colors.white.withValues(alpha: 0.6),
                width: 2,
              ),
            ),
          ),
          SizedBox(width: isTablet ? 12 : 8),
          Text(
            'Remember me',
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 16 : (isSmallScreen ? 13 : 14),
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w500,
              shadows: [
                Shadow(
                  offset: const Offset(0, 1),
                  blurRadius: 4,
                  color: Colors.black.withValues(alpha: 0.3),
                ),
              ],
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
          color: Colors.white.withValues(alpha: 0.8),
          fontWeight: FontWeight.w500,
          decoration: TextDecoration.underline,
          decorationColor: Colors.white.withValues(alpha: 0.8),
          shadows: [
            Shadow(
              offset: const Offset(0, 1),
              blurRadius: 4,
              color: Colors.black.withValues(alpha: 0.3),
            ),
          ],
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
            color: Colors.white.withValues(alpha: 0.8),
            shadows: [
              Shadow(
                offset: const Offset(0, 1),
                blurRadius: 4,
                color: Colors.black.withValues(alpha: 0.3),
              ),
            ],
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
