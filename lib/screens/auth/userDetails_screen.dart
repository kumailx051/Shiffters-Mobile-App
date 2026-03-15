import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:lottie/lottie.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shiffters/theme/app_colors.dart';
import 'package:shiffters/screens/user/home_screen.dart';

// Custom formatter for phone numbers
class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Remove all non-digits
    String digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    
    // Limit to 11 digits
    if (digits.length > 11) {
      digits = digits.substring(0, 11);
    }
    
    String formatted = '';
    if (digits.isNotEmpty) {
      if (digits.length <= 4) {
        formatted = digits;
      } else {
        formatted = '${digits.substring(0, 4)}-${digits.substring(4)}';
      }
    }
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class UserDetailsScreen extends StatefulWidget {
  final String name;
  final String email;

  const UserDetailsScreen({
    super.key,
    required this.name,
    required this.email,
  });

  @override
  State<UserDetailsScreen> createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends State<UserDetailsScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _formAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _formScaleAnimation;
  
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  
  bool _isLoading = false;
  bool _animationsStarted = false;
  
  // User details
  DateTime? _dateOfBirth;
  String _selectedGender = '';
  bool _agreeToTerms = false;
  bool _allowNotifications = true;
  bool _allowLocationAccess = true;

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Gender options
  final List<String> _genderOptions = ['Male', 'Female', 'Other', 'Prefer not to say'];

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
      duration: const Duration(milliseconds: 400), // Reduced from 800ms
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
    _addressController.dispose();
    _phoneController.dispose();
    _emergencyContactController.dispose();
    super.dispose();
  }

  // Save user data to Firestore
  Future<Map<String, dynamic>> _saveUserDataToFirestore() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return {
          'success': false,
          'error': 'No authenticated user found',
        };
      }

      await _firestore.collection('users').doc(currentUser.uid).update({
        'phoneNumber': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'dateOfBirth': _dateOfBirth?.toIso8601String(),
        'gender': _selectedGender,
        'emergencyContact': _emergencyContactController.text.trim(),
        'preferences': {
          'notifications': _allowNotifications,
          'darkMode': false,
          'language': 'en',
          'locationAccess': _allowLocationAccess,
        },
        'updatedAt': FieldValue.serverTimestamp(),
        'profileCompleted': true,
      });

      return {
        'success': true,
        'message': 'User profile updated successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to save user data: $e',
      };
    }
  }

  void _onCompleteProfilePressed() async {
    if (_formKey.currentState!.validate() && _validateRequiredFields()) {
      setState(() {
        _isLoading = true;
      });
      
      HapticFeedback.lightImpact();
      
      try {
        // Save user data to Firestore
        Map<String, dynamic> result = await _saveUserDataToFirestore();
        
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          
          if (result['success']) {
            // Show success message
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
                      '🎉 Profile Completed Successfully!',
                      style: GoogleFonts.albertSans(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Welcome to SHIFFTERS!',
                      style: GoogleFonts.albertSans(
                        fontWeight: FontWeight.w400,
                        fontSize: 16,
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
            
            // Navigate to home screen after delay
            await Future.delayed(const Duration(seconds: 2));
            if (mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => HomeScreen(),
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
                  transitionDuration: const Duration(milliseconds: 800),
                ),
                (route) => false,
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
                      '❌ Failed to Save Profile',
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    }
  }

  bool _validateRequiredFields() {
    if (_dateOfBirth == null) {
      _showErrorMessage('Please select your date of birth');
      return false;
    }
    if (_selectedGender.isEmpty) {
      _showErrorMessage('Please select your gender');
      return false;
    }
    if (!_agreeToTerms) {
      _showErrorMessage('Please agree to terms and conditions');
      return false;
    }
    return true;
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
      ),
    );
  }

  Future<void> _selectDateOfBirth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 20)),
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 100)),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 13)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.yellowAccent,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _dateOfBirth) {
      setState(() {
        _dateOfBirth = picked;
      });
    }
  }

  String? _validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your phone number';
    }
    
    // Remove all non-digits to count actual numbers
    String digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    
    if (digits.length != 11) {
      return 'Phone number must be exactly 11 digits';
    }
    
    // Check if it starts with 0 (Pakistani format)
    if (!digits.startsWith('0')) {
      return 'Phone number should start with 0';
    }
    
    return null;
  }

  String? _validateAddress(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your address';
    }
    if (value.length < 10) {
      return 'Please enter a complete address';
    }
    return null;
  }

  String? _validateEmergencyContact(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter emergency contact number';
    }
    
    // Remove all non-digits to count actual numbers
    String digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    
    if (digits.length != 11) {
      return 'Emergency contact must be exactly 11 digits';
    }
    
    // Check if it starts with 0 (Pakistani format)
    if (!digits.startsWith('0')) {
      return 'Emergency contact should start with 0';
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
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background/splashScreenBackground.jpg'),
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
            alignment: Alignment.center,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(bottom: keyboardHeight),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 40 : 24,
                vertical: isSmallScreen ? 20 : 32,
              ),
              child: Column(
                children: [
                  // Back button
                  _buildBackButton(),
                  
                  SizedBox(height: isSmallScreen ? 40 : 80),
                  
                  // Profile icon
                  _buildProfileIcon(isTablet),
                  
                  SizedBox(height: isSmallScreen ? 30 : 40),
                  
                  // Title
                  _buildTitle(isTablet, isSmallScreen),
                  
                  SizedBox(height: isSmallScreen ? 20 : 30),
                  
                  // Description
                  _buildDescription(isTablet, isSmallScreen),
                  
                  SizedBox(height: isSmallScreen ? 8 : 12),
                  
                  // Welcome message
                  _buildWelcomeMessage(isTablet, isSmallScreen),
                  
                  SizedBox(height: isSmallScreen ? 40 : 60),
                  
                  // Form
                  _buildForm(isTablet, isSmallScreen),
                  
                  SizedBox(height: isSmallScreen ? 40 : 60),
                  
                  // Complete Profile Button
                  _buildCompleteProfileButton(isTablet, isSmallScreen),
                ],
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

  Widget _buildProfileIcon(bool isTablet) {
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
          Icons.person_outline,
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
          'Complete Your\nProfile',
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
      'Help us personalize your experience',
      textAlign: TextAlign.center,
      style: GoogleFonts.albertSans(
        fontSize: isTablet ? 18 : (isSmallScreen ? 15 : 16),
        color: Colors.white,
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

  Widget _buildWelcomeMessage(bool isTablet, bool isSmallScreen) {
    return Text(
      'Welcome ${widget.name}!',
      textAlign: TextAlign.center,
      style: GoogleFonts.albertSans(
        fontSize: isTablet ? 18 : (isSmallScreen ? 15 : 16),
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

  Widget _buildForm(bool isTablet, bool isSmallScreen) {
    return ScaleTransition(
      scale: _formScaleAnimation,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Personal Information Section
            _buildSectionHeader('Personal Information', isTablet, isSmallScreen),
            SizedBox(height: isSmallScreen ? 16 : 20),
            
            // Phone Number
            _buildInputField(
              controller: _phoneController,
              hintText: 'Phone Number',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: _validatePhoneNumber,
              inputFormatters: [PhoneNumberFormatter()],
              isTablet: isTablet,
              isSmallScreen: isSmallScreen,
            ),
            
            SizedBox(height: isSmallScreen ? 16 : 20),
            
            // Date of Birth
            _buildDateOfBirthField(isTablet, isSmallScreen),
            
            SizedBox(height: isSmallScreen ? 16 : 20),
            
            // Gender Selection
            _buildGenderSelection(isTablet, isSmallScreen),
            
            SizedBox(height: isSmallScreen ? 20 : 24),
            
            // Address Section
            _buildSectionHeader('Address Information', isTablet, isSmallScreen),
            SizedBox(height: isSmallScreen ? 16 : 20),
            
            // Address
            _buildInputField(
              controller: _addressController,
              hintText: 'Complete Address',
              icon: Icons.location_on_outlined,
              maxLines: 3,
              validator: _validateAddress,
              inputFormatters: null,
              isTablet: isTablet,
              isSmallScreen: isSmallScreen,
            ),
            
            SizedBox(height: isSmallScreen ? 20 : 24),
            
            // Emergency Contact Section
            _buildSectionHeader('Emergency Contact', isTablet, isSmallScreen),
            SizedBox(height: isSmallScreen ? 16 : 20),
            
            // Emergency Contact
            _buildInputField(
              controller: _emergencyContactController,
              hintText: 'Emergency Contact Number',
              icon: Icons.emergency_outlined,
              keyboardType: TextInputType.phone,
              validator: _validateEmergencyContact,
              inputFormatters: [PhoneNumberFormatter()],
              isTablet: isTablet,
              isSmallScreen: isSmallScreen,
            ),
            
            SizedBox(height: isSmallScreen ? 20 : 24),
            
            // Preferences Section
            _buildSectionHeader('Preferences', isTablet, isSmallScreen),
            SizedBox(height: isSmallScreen ? 16 : 20),
            
            // Notification Settings
            _buildNotificationSettings(isTablet, isSmallScreen),
            
            SizedBox(height: isSmallScreen ? 20 : 24),
            
            // Terms and Conditions
            _buildTermsAndConditions(isTablet, isSmallScreen),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isTablet, bool isSmallScreen) {
    return Text(
      title,
      style: GoogleFonts.albertSans(
        fontSize: isTablet ? 18 : (isSmallScreen ? 16 : 17),
        fontWeight: FontWeight.w600,
        color: Colors.white,
        letterSpacing: 0.5,
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

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
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
        maxLines: maxLines,
        validator: validator,
        inputFormatters: inputFormatters,
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

  Widget _buildDateOfBirthField(bool isTablet, bool isSmallScreen) {
    return GestureDetector(
      onTap: _selectDateOfBirth,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 20 : 16,
          vertical: isTablet ? 20 : 16,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              color: AppColors.grey600,
              size: isTablet ? 24 : 20,
            ),
            SizedBox(width: isTablet ? 16 : 12),
            Text(
              _dateOfBirth == null
                  ? 'Date of Birth'
                  : '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 16 : (isSmallScreen ? 14 : 15),
                color: _dateOfBirth == null ? AppColors.grey500 : AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_drop_down,
              color: AppColors.grey600,
              size: isTablet ? 24 : 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderSelection(bool isTablet, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person_outline,
                color: AppColors.grey600,
                size: isTablet ? 24 : 20,
              ),
              SizedBox(width: isTablet ? 16 : 12),
              Text(
                'Gender',
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 16 : (isSmallScreen ? 14 : 15),
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 12 : 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _genderOptions.map((gender) {
              final isSelected = _selectedGender == gender;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedGender = gender;
                  });
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 16 : 12,
                    vertical: isTablet ? 12 : 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.yellowAccent : Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? AppColors.yellowAccent : Colors.grey.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    gender,
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 14 : (isSmallScreen ? 12 : 13),
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationSettings(bool isTablet, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.notifications_outlined,
                color: AppColors.grey600,
                size: isTablet ? 24 : 20,
              ),
              SizedBox(width: isTablet ? 16 : 12),
              Expanded(
                child: Text(
                  'Allow Notifications',
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 16 : (isSmallScreen ? 14 : 15),
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Switch(
                value: _allowNotifications,
                onChanged: (value) {
                  setState(() {
                    _allowNotifications = value;
                  });
                },
                activeColor: AppColors.yellowAccent,
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 12 : 16),
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                color: AppColors.grey600,
                size: isTablet ? 24 : 20,
              ),
              SizedBox(width: isTablet ? 16 : 12),
              Expanded(
                child: Text(
                  'Allow Location Access',
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 16 : (isSmallScreen ? 14 : 15),
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Switch(
                value: _allowLocationAccess,
                onChanged: (value) {
                  setState(() {
                    _allowLocationAccess = value;
                  });
                },
                activeColor: AppColors.yellowAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTermsAndConditions(bool isTablet, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Checkbox(
            value: _agreeToTerms,
            onChanged: (value) {
              setState(() {
                _agreeToTerms = value ?? false;
              });
            },
            activeColor: AppColors.yellowAccent,
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 14 : (isSmallScreen ? 12 : 13),
                  color: AppColors.textPrimary,
                ),
                children: [
                  const TextSpan(text: 'I agree to the '),
                  TextSpan(
                    text: 'Terms and Conditions',
                    style: GoogleFonts.albertSans(
                      fontWeight: FontWeight.w600,
                      color: AppColors.yellowAccent,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  const TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: GoogleFonts.albertSans(
                      fontWeight: FontWeight.w600,
                      color: AppColors.yellowAccent,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteProfileButton(bool isTablet, bool isSmallScreen) {
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
        onPressed: _isLoading ? null : _onCompleteProfilePressed,
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
                'Complete Profile',
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 18 : (isSmallScreen ? 15 : 16),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }
}
