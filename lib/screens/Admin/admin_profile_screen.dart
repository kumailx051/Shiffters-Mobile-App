import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shiffters/theme/app_colors.dart';
import 'package:shiffters/theme/app_theme.dart';
import 'package:shiffters/services/theme_service.dart';

// Phone Number Formatter Class
class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Remove all non-digit characters
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    // Limit to 11 digits
    if (digitsOnly.length > 11) {
      digitsOnly = digitsOnly.substring(0, 11);
    }

    // Apply formatting based on length
    String formatted = '';
    if (digitsOnly.isNotEmpty) {
      if (digitsOnly.length <= 4) {
        formatted = digitsOnly;
      } else if (digitsOnly.length <= 7) {
        formatted = '${digitsOnly.substring(0, 4)}-${digitsOnly.substring(4)}';
      } else {
        formatted =
            '${digitsOnly.substring(0, 4)}-${digitsOnly.substring(4, 7)}${digitsOnly.substring(7)}';
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late AnimationController _animationController;
  late AnimationController _editAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _editScaleAnimation;
  late Animation<double> _editOpacityAnimation;

  bool _pushNotifications = true;
  bool _isUploadingImage = false;
  String? _profileImageUrl;

  String _selectedLanguage = 'English';

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _employeeIdController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _initializeAnimations();
    _startAnimations();
    _loadAdminData();

    // Set system UI overlay style for dark theme
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
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _editAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
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

    _editScaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _editAnimationController,
      curve: Curves.easeOutBack,
    ));

    _editOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _editAnimationController,
      curve: Curves.easeOut,
    ));
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      _animationController.forward();
    }
  }

  // Load admin data from Firebase
  Future<void> _loadAdminData() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final adminDoc =
            await _firestore.collection('users').doc(user.uid).get();
        if (adminDoc.exists && mounted) {
          final adminData = adminDoc.data() as Map<String, dynamic>;
          setState(() {
            _nameController.text = adminData['name'] ?? 'Admin User';
            _emailController.text = adminData['email'] ?? user.email ?? '';
            _phoneController.text = adminData['phoneNumber'] ?? '';
            _departmentController.text =
                adminData['department'] ?? 'IT Administration';
            _employeeIdController.text = adminData['employeeId'] ?? 'ADM001';
            _profileImageUrl = adminData['profileImageUrl'];

            // Load preferences
            final preferences =
                adminData['preferences'] as Map<String, dynamic>?;
            if (preferences != null) {
              _pushNotifications = preferences['pushNotifications'] ?? true;
              _selectedLanguage =
                  preferences['language'] == 'ur' ? 'Urdu' : 'English';
            }
          });
        } else if (mounted) {
          // If document doesn't exist, set default values from Firebase Auth
          setState(() {
            _nameController.text = user.displayName ?? 'Admin User';
            _emailController.text = user.email ?? '';
            _phoneController.text = '';
            _departmentController.text = 'IT Administration';
            _employeeIdController.text = 'ADM001';
            _profileImageUrl = user.photoURL;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading admin data: $e');
      if (mounted) {
        _showGlowingSnackBar(
          'Error loading profile data',
          AppColors.error,
        );
      }
    }
  }

  // Update admin data in Firebase
  Future<void> _updateAdminData() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'phoneNumber': _phoneController.text.trim(),
          'department': _departmentController.text.trim(),
          'employeeId': _employeeIdController.text.trim(),
          'profileImageUrl': _profileImageUrl,
          'preferences': {
            'pushNotifications': _pushNotifications,
            'language': _selectedLanguage == 'Urdu' ? 'ur' : 'en',
          },
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          _showGlowingSnackBar(
            'Profile updated successfully!',
            AppColors.success,
          );
        }
      }
    } catch (e) {
      debugPrint('Error updating admin data: $e');
      if (mounted) {
        _showGlowingSnackBar(
          'Error updating profile: $e',
          AppColors.error,
        );
      }
    }
  }

  // Show glowing snackbar with white glowing text
  void _showGlowingSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.albertSans(
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _editAnimationController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _departmentController.dispose();
    _employeeIdController.dispose();
    super.dispose();
  }

  void _showEditProfileModal() {
    HapticFeedback.lightImpact();
    _editAnimationController.forward();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildEditProfileModal(),
    ).then((_) {
      _editAnimationController.reverse();
    });
  }

  // Show image source selection dialog
  Future<void> _showImageSourceDialog() async {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isDarkMode = themeService.isDarkMode;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select Image Source',
              style: GoogleFonts.albertSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),

            // Camera Option
            ListTile(
              leading: Icon(
                Icons.camera_alt,
                color: AppColors.yellowAccent,
                size: 28,
              ),
              title: Text(
                'Camera',
                style: GoogleFonts.albertSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.white : AppColors.textPrimary,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromSource(ImageSource.camera);
              },
            ),

            // Gallery Option
            ListTile(
              leading: Icon(
                Icons.photo_library,
                color: AppColors.yellowAccent,
                size: 28,
              ),
              title: Text(
                'Gallery',
                style: GoogleFonts.albertSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.white : AppColors.textPrimary,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromSource(ImageSource.gallery);
              },
            ),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // Show image preview and confirm upload
  Future<void> _showImagePreview(XFile imageFile) async {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isDarkMode = themeService.isDarkMode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
        title: Text(
          'Confirm Profile Image',
          style: GoogleFonts.albertSans(
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : AppColors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDarkMode
                      ? AppColors.yellowAccent
                      : AppTheme.lightPrimaryColor,
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: Image.network(
                  kIsWeb
                      ? imageFile.path
                      : '', // Only preview on web if possible
                  fit: BoxFit.cover,
                  width: 200,
                  height: 200,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.image, size: 80),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Do you want to use this image as your profile picture?',
              style: GoogleFonts.albertSans(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.8)
                    : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.albertSans(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.7)
                    : AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDarkMode
                  ? AppColors.yellowAccent
                  : AppTheme.lightPrimaryColor,
              foregroundColor: isDarkMode ? Colors.black : Colors.white,
            ),
            child: Text(
              'Use Image',
              style: GoogleFonts.albertSans(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed == true) {
        setState(() {
          _isUploadingImage = true;
        });

        // Upload to ImageBB (read as bytes)
        final bytes = await imageFile.readAsBytes();
        final imageUrl = await _uploadImageToImageBB(bytes);

        if (imageUrl != null) {
          setState(() {
            _profileImageUrl = imageUrl;
            _isUploadingImage = false;
          });

          // Update in Firebase
          final user = _auth.currentUser;
          if (user != null) {
            await _firestore.collection('users').doc(user.uid).update({
              'profileImageUrl': imageUrl,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }

          if (mounted) {
            _showGlowingSnackBar(
              'Profile image updated successfully!',
              AppColors.success,
            );
          }
        } else {
          setState(() {
            _isUploadingImage = false;
          });
        }
      }
    });
  }

  // Pick image from specified source and upload to ImageBB
  Future<void> _pickImageFromSource(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        // Show preview dialog instead of directly uploading
        await _showImagePreview(image);
      }
    } catch (e) {
      if (mounted) {
        _showGlowingSnackBar(
          'Error selecting image: $e',
          AppColors.error,
        );
      }
    }
  }

  // Wrapper method for backward compatibility
  Future<void> _pickImage() async {
    await _showImageSourceDialog();
  }

  // Upload image to ImageBB API
  Future<String?> _uploadImageToImageBB(List<int> imageBytes) async {
    try {
      const String apiKey = 'f31e40432a7b500dd75ce5255d3ea517';
      const String uploadUrl = 'https://api.imgbb.com/1/upload';

      String base64Image = base64Encode(imageBytes);

      // Prepare the request
      var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
      request.fields['key'] = apiKey;
      request.fields['image'] = base64Image;

      // Send the request
      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var jsonResponse = json.decode(responseData);

      if (response.statusCode == 200 && jsonResponse['success']) {
        return jsonResponse['data']['url'];
      } else {
        debugPrint(
            'ImageBB upload failed: ${jsonResponse['error']['message']}');
        return null;
      }
    } catch (e) {
      debugPrint('Error uploading to ImageBB: $e');
      return null;
    }
  }

  void _showLanguageSelector() {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isDarkMode = themeService.isDarkMode;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildLanguageSelector(),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        final isDarkMode = themeService.isDarkMode;

        return Scaffold(
          backgroundColor: isDarkMode
              ? const Color(0xFF1E1E2C)
              : AppTheme.lightBackgroundColor,
          body: Container(
            decoration: isDarkMode
                ? null
                : const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage(
                          'assets/background/splashScreenBackground.jpg'),
                      fit: BoxFit.cover,
                      opacity: 0.1,
                    ),
                  ),
            child: SafeArea(
              child: Column(
                children: [
                  // Header
                  _buildHeader(isTablet, isDarkMode),

                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 32 : 20,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 24),

                            // Profile Section
                            _buildProfileSection(isTablet, isDarkMode),

                            const SizedBox(height: 24),

                            // Personal Information Section
                            _buildPersonalInfoSection(isTablet, isDarkMode),

                            const SizedBox(height: 24),

                            // Settings Section
                            _buildSettingsSection(
                                isTablet, isDarkMode, themeService),

                            const SizedBox(height: 24),

                            // Logout Button
                            _buildLogoutButton(isTablet, isDarkMode),

                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isTablet, bool isDarkMode) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDarkMode
                ? [
                    const Color(0xFF2D2D3C),
                    const Color(0xFF1E1E2C),
                  ]
                : [
                    const Color(0xFF1E88E5),
                    const Color(0xFF42A5F5),
                  ],
          ),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: isTablet ? 20 : 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    // Back button
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.arrow_back_ios,
                          size: isTablet ? 24 : 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Title
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Admin Profile',
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 28 : 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Account settings',
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 14 : 12,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Edit profile button
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    // Toggle edit mode or show edit options
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.edit,
                      size: isTablet ? 24 : 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection(bool isTablet, bool isDarkMode) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        padding: EdgeInsets.all(isTablet ? 24 : 20),
        decoration: BoxDecoration(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : AppTheme.lightCardColor,
          borderRadius: BorderRadius.circular(16),
          border: isDarkMode
              ? null
              : Border.all(
                  color: AppTheme.lightPrimaryColor,
                  width: 1.5,
                ),
          boxShadow: isDarkMode
              ? null
              : [
                  BoxShadow(
                    color: AppTheme.lightShadowMedium,
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Avatar and Edit Icon
            Stack(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: isTablet ? 100 : 80,
                    height: isTablet ? 100 : 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDarkMode
                            ? AppColors.yellowAccent
                            : AppTheme.lightPrimaryColor,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDarkMode
                              ? AppColors.yellowAccent.withValues(alpha: 0.4)
                              : AppTheme.lightPrimaryColor
                                  .withValues(alpha: 0.4),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: _profileImageUrl != null &&
                              _profileImageUrl!.isNotEmpty
                          ? Image.network(
                              _profileImageUrl!,
                              width: isTablet ? 100 : 80,
                              height: isTablet ? 100 : 80,
                              fit: BoxFit.cover,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  width: isTablet ? 100 : 80,
                                  height: isTablet ? 100 : 80,
                                  color: isDarkMode
                                      ? AppColors.yellowAccent
                                          .withValues(alpha: 0.2)
                                      : AppTheme.lightPrimaryColor
                                          .withValues(alpha: 0.2),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: isDarkMode
                                          ? AppColors.yellowAccent
                                          : AppTheme.lightPrimaryColor,
                                      strokeWidth: 2,
                                      value:
                                          loadingProgress.expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                              : null,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: isDarkMode
                                      ? AppColors.yellowAccent
                                          .withValues(alpha: 0.2)
                                      : AppTheme.lightPrimaryColor
                                          .withValues(alpha: 0.2),
                                  child: Icon(
                                    Icons.person,
                                    size: isTablet ? 50 : 40,
                                    color: isDarkMode
                                        ? AppColors.yellowAccent
                                        : AppTheme.lightPrimaryColor,
                                  ),
                                );
                              },
                            )
                          : Container(
                              color: isDarkMode
                                  ? AppColors.yellowAccent
                                      .withValues(alpha: 0.2)
                                  : AppTheme.lightPrimaryColor
                                      .withValues(alpha: 0.2),
                              child: Icon(
                                Icons.person,
                                size: isTablet ? 50 : 40,
                                color: isDarkMode
                                    ? AppColors.yellowAccent
                                    : AppTheme.lightPrimaryColor,
                              ),
                            ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? AppColors.yellowAccent
                          : AppTheme.lightPrimaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color:
                            isDarkMode ? const Color(0xFF1E1E2C) : Colors.white,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.yellowAccent.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      size: 16,
                      color: isDarkMode ? Colors.black : Colors.white,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: isTablet ? 20 : 16),

            // User Info - All Centered
            Text(
              _nameController.text,
              textAlign: TextAlign.center,
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 24 : 20,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : AppColors.textPrimary,
              ),
            ),

            SizedBox(height: isTablet ? 8 : 6),

            Text(
              'System Administrator',
              textAlign: TextAlign.center,
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 16 : 14,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.7)
                    : AppColors.textSecondary,
              ),
            ),

            SizedBox(height: isTablet ? 4 : 2),

            Text(
              _departmentController.text,
              textAlign: TextAlign.center,
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 14 : 12,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.7)
                    : AppColors.textSecondary,
              ),
            ),

            SizedBox(height: isTablet ? 20 : 16),

            // Edit Profile Button - Centered
            Center(
              child: GestureDetector(
                onTap: _showEditProfileModal,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 24 : 20,
                    vertical: isTablet ? 12 : 10,
                  ),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.transparent
                        : AppTheme.lightPrimaryColor,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: isDarkMode
                          ? AppColors.yellowAccent
                          : AppTheme.lightPrimaryColor,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    'Edit Profile',
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 16 : 14,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? AppColors.yellowAccent : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalInfoSection(bool isTablet, bool isDarkMode) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        padding: EdgeInsets.all(isTablet ? 24 : 20),
        decoration: BoxDecoration(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : AppTheme.lightCardColor,
          borderRadius: BorderRadius.circular(16),
          border: isDarkMode
              ? null
              : Border.all(
                  color: AppTheme.lightPrimaryColor,
                  width: 1.5,
                ),
          boxShadow: isDarkMode
              ? null
              : [
                  BoxShadow(
                    color: AppTheme.lightShadowMedium,
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Personal Information',
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                Icon(
                  Icons.person_outline,
                  color: isDarkMode
                      ? AppColors.yellowAccent
                      : AppTheme.lightPrimaryColor,
                  size: isTablet ? 24 : 20,
                ),
              ],
            ),

            SizedBox(height: isTablet ? 16 : 12),

            Text(
              'Update your personal details and contact information',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 14 : 12,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.8)
                    : AppColors.textSecondary,
                height: 1.4,
              ),
            ),

            SizedBox(height: isTablet ? 20 : 16),

            // Personal info items
            _buildInfoItem(
              'Full Name',
              _nameController.text,
              Icons.person,
              isTablet,
              isDarkMode,
            ),

            SizedBox(height: isTablet ? 12 : 8),

            _buildInfoItem(
              'Email Address',
              _emailController.text,
              Icons.email,
              isTablet,
              isDarkMode,
            ),

            SizedBox(height: isTablet ? 12 : 8),

            _buildInfoItem(
              'Phone Number',
              _phoneController.text.isEmpty
                  ? 'Not provided'
                  : _phoneController.text,
              Icons.phone,
              isTablet,
              isDarkMode,
            ),

            SizedBox(height: isTablet ? 12 : 8),

            _buildInfoItem(
              'Employee ID',
              _employeeIdController.text,
              Icons.badge,
              isTablet,
              isDarkMode,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon,
      bool isTablet, bool isDarkMode) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: isDarkMode
            ? null
            : Border.all(
                color: AppTheme.lightPrimaryColor,
                width: 1.5,
              ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? AppColors.yellowAccent.withValues(alpha: 0.2)
                  : AppTheme.lightPrimaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: isDarkMode
                  ? AppColors.yellowAccent
                  : AppTheme.lightPrimaryColor,
              size: isTablet ? 20 : 18,
            ),
          ),
          SizedBox(width: isTablet ? 16 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 12 : 10,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.8)
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 14 : 12,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(
      bool isTablet, bool isDarkMode, ThemeService themeService) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        padding: EdgeInsets.all(isTablet ? 24 : 20),
        decoration: BoxDecoration(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : AppTheme.lightCardColor,
          borderRadius: BorderRadius.circular(16),
          border: isDarkMode
              ? null
              : Border.all(
                  color: AppTheme.lightPrimaryColor,
                  width: 1.5,
                ),
          boxShadow: isDarkMode
              ? null
              : [
                  BoxShadow(
                    color: AppTheme.lightShadowMedium,
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Preferences',
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                Icon(
                  Icons.settings_outlined,
                  color: isDarkMode
                      ? AppColors.yellowAccent
                      : AppTheme.lightPrimaryColor,
                  size: isTablet ? 24 : 20,
                ),
              ],
            ),
            SizedBox(height: isTablet ? 16 : 12),
            Text(
              'Configure your app preferences and display settings',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 14 : 12,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.8)
                    : AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            SizedBox(height: isTablet ? 20 : 16),
            _buildSettingItem(
              icon: Icons.language_outlined,
              title: 'Language',
              subtitle: _selectedLanguage,
              onTap: _showLanguageSelector,
              isTablet: isTablet,
              isDarkMode: isDarkMode,
            ),
            SizedBox(height: isTablet ? 16 : 12),
            _buildSettingItem(
              icon: Icons.dark_mode_outlined,
              title: 'Dark Mode',
              isSwitch: true,
              value: isDarkMode,
              onChanged: (value) {
                themeService.setTheme(value);
              },
              isTablet: isTablet,
              isDarkMode: isDarkMode,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    String? subtitle,
    bool isSwitch = false,
    bool? value,
    ValueChanged<bool>? onChanged,
    VoidCallback? onTap,
    required bool isTablet,
    required bool isDarkMode,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 16 : 12,
          vertical: isTablet ? 16 : 12,
        ),
        decoration: BoxDecoration(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: isDarkMode
              ? null
              : Border.all(
                  color: AppTheme.lightPrimaryColor,
                  width: 1.5,
                ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.8)
                  : AppColors.textSecondary,
              size: isTablet ? 22 : 20,
            ),
            SizedBox(width: isTablet ? 16 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 16 : 14,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 14 : 12,
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.6)
                            : AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            if (isSwitch && value != null && onChanged != null)
              Switch(
                value: value,
                onChanged: onChanged,
                activeColor: isDarkMode
                    ? AppColors.yellowAccent
                    : AppTheme.lightPrimaryColor,
                activeTrackColor: isDarkMode
                    ? AppColors.yellowAccent.withValues(alpha: 0.3)
                    : AppTheme.lightPrimaryColor.withValues(alpha: 0.3),
                inactiveThumbColor: isDarkMode
                    ? Colors.white.withValues(alpha: 0.5)
                    : AppColors.grey400,
                inactiveTrackColor: isDarkMode
                    ? Colors.white.withValues(alpha: 0.2)
                    : AppColors.grey300,
              )
            else if (!isSwitch)
              Icon(
                Icons.arrow_forward_ios,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.5)
                    : AppColors.textSecondary,
                size: isTablet ? 18 : 16,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditProfileModal() {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isDarkMode = themeService.isDarkMode;

    return AnimatedBuilder(
      animation: _editAnimationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _editScaleAnimation.value,
          child: Opacity(
            opacity: _editOpacityAnimation.value,
            child: Container(
              margin: EdgeInsets.only(
                top: screenSize.height * 0.1,
                left: 16,
                right: 16,
                bottom: keyboardHeight,
              ),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: isDarkMode
                        ? Colors.black.withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.all(isTablet ? 32 : 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Edit Profile',
                            style: GoogleFonts.albertSans(
                              fontSize: isTablet ? 24 : 20,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : AppColors.grey100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.close,
                                size: isTablet ? 24 : 20,
                                color: isDarkMode
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: isTablet ? 32 : 24),

                      // Profile Image Upload Section
                      _buildProfileImageSection(isTablet),

                      SizedBox(height: isTablet ? 24 : 20),

                      // Form Fields
                      _buildGlowingEditField(
                        controller: _nameController,
                        label: 'Full Name',
                        icon: Icons.person_outline,
                        isTablet: isTablet,
                      ),

                      SizedBox(height: isTablet ? 20 : 16),

                      _buildGlowingEditField(
                        controller: _emailController,
                        label: 'Email',
                        icon: Icons.email_outlined,
                        isTablet: isTablet,
                        keyboardType: TextInputType.emailAddress,
                      ),

                      SizedBox(height: isTablet ? 20 : 16),

                      _buildGlowingEditField(
                        controller: _phoneController,
                        label: 'Phone Number',
                        icon: Icons.phone_outlined,
                        isTablet: isTablet,
                        inputFormatters: [PhoneNumberFormatter()],
                        keyboardType: TextInputType.phone,
                      ),

                      SizedBox(height: isTablet ? 20 : 16),

                      _buildGlowingEditField(
                        controller: _departmentController,
                        label: 'Department',
                        icon: Icons.business_outlined,
                        isTablet: isTablet,
                      ),

                      SizedBox(height: isTablet ? 20 : 16),

                      _buildGlowingEditField(
                        controller: _employeeIdController,
                        label: 'Employee ID',
                        icon: Icons.badge_outlined,
                        isTablet: isTablet,
                      ),

                      SizedBox(height: isTablet ? 32 : 24),

                      // Save Button
                      GestureDetector(
                        onTap: () async {
                          HapticFeedback.lightImpact();

                          // Update admin data in Firebase
                          await _updateAdminData();

                          if (!mounted) return;
                          Navigator.pop(context);
                        },
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            vertical: isTablet ? 16 : 14,
                          ),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? AppColors.yellowAccent
                                : AppTheme.lightPrimaryColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: isDarkMode
                                    ? AppColors.yellowAccent
                                        .withValues(alpha: 0.6)
                                    : AppTheme.lightPrimaryColor
                                        .withValues(alpha: 0.6),
                                blurRadius: 20,
                                spreadRadius: 0,
                                offset: const Offset(0, 8),
                              ),
                              BoxShadow(
                                color: isDarkMode
                                    ? AppColors.yellowAccent
                                        .withValues(alpha: 0.3)
                                    : AppTheme.lightPrimaryColor
                                        .withValues(alpha: 0.3),
                                blurRadius: 40,
                                spreadRadius: 0,
                                offset: const Offset(0, 16),
                              ),
                            ],
                          ),
                          child: Text(
                            'Save Changes',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.albertSans(
                              fontSize: isTablet ? 18 : 16,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? Colors.black : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileImageSection(bool isTablet) {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isDarkMode = themeService.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Profile Image',
          style: GoogleFonts.albertSans(
            fontSize: isTablet ? 16 : 14,
            fontWeight: FontWeight.w500,
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.8)
                : AppColors.textSecondary,
          ),
        ),
        SizedBox(height: isTablet ? 12 : 8),
        Row(
          children: [
            // Current profile image or placeholder
            Container(
              width: isTablet ? 80 : 70,
              height: isTablet ? 80 : 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDarkMode
                      ? AppColors.yellowAccent
                      : AppTheme.lightPrimaryColor,
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                    ? Image.network(
                        _profileImageUrl!,
                        width: isTablet ? 80 : 70,
                        height: isTablet ? 80 : 70,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: isTablet ? 80 : 70,
                            height: isTablet ? 80 : 70,
                            color: isDarkMode
                                ? AppColors.yellowAccent.withValues(alpha: 0.2)
                                : AppTheme.lightPrimaryColor
                                    .withValues(alpha: 0.2),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: isDarkMode
                                    ? AppColors.yellowAccent
                                    : AppTheme.lightPrimaryColor,
                                strokeWidth: 2,
                                value: loadingProgress.expectedTotalBytes !=
                                        null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: isDarkMode
                                ? AppColors.yellowAccent.withValues(alpha: 0.2)
                                : AppTheme.lightPrimaryColor
                                    .withValues(alpha: 0.2),
                            child: Icon(
                              Icons.person,
                              size: isTablet ? 40 : 35,
                              color: isDarkMode
                                  ? AppColors.yellowAccent
                                  : AppTheme.lightPrimaryColor,
                            ),
                          );
                        },
                      )
                    : Container(
                        color: isDarkMode
                            ? AppColors.yellowAccent.withValues(alpha: 0.2)
                            : AppTheme.lightPrimaryColor.withValues(alpha: 0.2),
                        child: Icon(
                          Icons.person,
                          size: isTablet ? 40 : 35,
                          color: isDarkMode
                              ? AppColors.yellowAccent
                              : AppTheme.lightPrimaryColor,
                        ),
                      ),
              ),
            ),

            SizedBox(width: isTablet ? 20 : 16),

            // Upload button
            Expanded(
              child: GestureDetector(
                onTap: _isUploadingImage ? null : _pickImage,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 16 : 12,
                    vertical: isTablet ? 12 : 10,
                  ),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.1)
                        : AppColors.grey100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.2)
                          : AppColors.grey300,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isUploadingImage)
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: isDarkMode
                                ? Colors.white
                                : AppColors.yellowAccent,
                            strokeWidth: 2,
                          ),
                        )
                      else
                        Icon(
                          Icons.upload,
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.8)
                              : AppColors.textSecondary,
                          size: isTablet ? 20 : 18,
                        ),
                      SizedBox(width: isTablet ? 8 : 6),
                      Text(
                        _isUploadingImage
                            ? 'Uploading...'
                            : (_profileImageUrl != null &&
                                    _profileImageUrl!.isNotEmpty
                                ? 'Change Image'
                                : 'Upload Image'),
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 14 : 12,
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.8)
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGlowingEditField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isTablet,
    List<TextInputFormatter>? inputFormatters,
    TextInputType? keyboardType,
    int? maxLines,
  }) {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isDarkMode = themeService.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.albertSans(
            fontSize: isTablet ? 16 : 14,
            fontWeight: FontWeight.w500,
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.8)
                : AppColors.textSecondary,
          ),
        ),
        SizedBox(height: isTablet ? 8 : 6),
        Container(
          decoration: BoxDecoration(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.1)
                : AppColors.grey100,
            borderRadius: BorderRadius.circular(16),
            border: isDarkMode
                ? Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1,
                  )
                : Border.all(
                    color: AppTheme.lightPrimaryColor,
                    width: 1.5,
                  ),
          ),
          child: TextField(
            controller: controller,
            inputFormatters: inputFormatters,
            keyboardType: keyboardType,
            maxLines: maxLines ?? 1,
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 16 : 14,
              color: isDarkMode ? Colors.white : AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(
                icon,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.6)
                    : AppColors.textSecondary,
                size: isTablet ? 24 : 20,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: isDarkMode
                      ? AppColors.yellowAccent
                      : AppTheme.lightPrimaryColor,
                  width: 2,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: isTablet ? 20 : 16,
                vertical: isTablet ? 18 : 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageSelector() {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isDarkMode = themeService.isDarkMode;
    final languages = ['English', 'Urdu'];

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Select Language',
            style: GoogleFonts.albertSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          ...languages
              .map((language) => ListTile(
                    title: Text(
                      language,
                      style: GoogleFonts.albertSans(
                        color:
                            isDarkMode ? Colors.white : AppColors.textPrimary,
                        fontWeight: _selectedLanguage == language
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    trailing: _selectedLanguage == language
                        ? Icon(Icons.check, color: AppColors.yellowAccent)
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedLanguage = language;
                      });
                      Navigator.pop(context);
                    },
                  ))
              .toList(),
        ],
      ),
    );
  }

  Future<void> _clearRememberMeData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auto_login', false);
      await prefs.setBool('remember_me', false);
      await prefs.remove('saved_email');
      await prefs.remove('saved_password');
      debugPrint('Remember me data cleared successfully');
    } catch (e) {
      debugPrint('Error clearing remember me data: $e');
    }
  }

  Future<void> _performLogout() async {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isDarkMode = themeService.isDarkMode;

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
              ),
              const SizedBox(height: 16),
              Text(
                'Signing out...',
                style: GoogleFonts.albertSans(
                  color: isDarkMode ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      );

      // Clear remember me saved information before logout
      await _clearRememberMeData();

      // Sign out from Firebase
      await _auth.signOut();

      // Close loading dialog
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // Show success message
      _showGlowingSnackBar('Successfully logged out', Colors.green);

      // Navigate to login screen
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } catch (e) {
      // Close loading dialog if open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      debugPrint('Error during logout: $e');
      _showGlowingSnackBar('Error during logout', Colors.red);
    }
  }

  Widget _buildLogoutButton(bool isTablet, bool isDarkMode) {
    final buttonWidth = isTablet ? 320.0 : double.infinity;
    final buttonHeight = isTablet ? 56.0 : 52.0;

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(isTablet ? 24 : 20),
        child: Container(
          width: buttonWidth,
          height: buttonHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ElevatedButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor:
                      isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: Text(
                    'Logout',
                    style: GoogleFonts.albertSans(
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  content: Text(
                    'Are you sure you want to logout?',
                    style: GoogleFonts.albertSans(
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.8)
                          : AppColors.textSecondary,
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.albertSans(
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.7)
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _performLogout();
                      },
                      child: Text(
                        'Logout',
                        style: GoogleFonts.albertSans(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
              padding: EdgeInsets.zero,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.logout_rounded,
                  size: isTablet ? 24 : 20,
                ),
                SizedBox(width: isTablet ? 12 : 8),
                Text(
                  'Logout',
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
