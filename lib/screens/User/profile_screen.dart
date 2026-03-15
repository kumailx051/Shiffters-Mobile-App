import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
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
import 'package:shiffters/services/biometric_auth_service.dart';
import 'package:shiffters/screens/welcome_screen.dart';

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

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late AnimationController _animationController;
  late AnimationController _editAnimationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _editScaleAnimation;
  late Animation<double> _editOpacityAnimation;

  bool _isEditMode = false;
  bool _notificationsEnabled = true;
  bool _savePaymentMethod = false;
  bool _biometricEnabled = false;
  String _selectedLanguage = 'English';
  bool _isUploadingImage = false;
  String? _profileImageUrl;
  bool _isBiometricAvailable = false;

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();
  final BiometricAuthService _biometricService = BiometricAuthService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    _initializeAnimations();
    _startAnimations();
    _loadUserData();
    _checkBiometricAvailability();
    _loadCurrentBiometricState();

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

  // Load user data from Firebase
  Future<void> _loadUserData() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists && mounted) {
          final userData = userDoc.data() as Map<String, dynamic>;
          setState(() {
            _nameController.text = userData['name'] ?? '';
            _emailController.text = userData['email'] ?? user.email ?? '';
            _phoneController.text = userData['phoneNumber'] ?? '';
            _addressController.text = userData['address'] ?? '';
            _profileImageUrl = userData['profileImageUrl'];

            // Load preferences
            final preferences =
                userData['preferences'] as Map<String, dynamic>?;
            if (preferences != null) {
              _notificationsEnabled = preferences['notifications'] ?? true;
              _biometricEnabled = preferences['biometricEnabled'] ?? false;
              _savePaymentMethod = preferences['savePayment'] ?? false;
              _selectedLanguage =
                  preferences['language'] == 'ur' ? 'Urdu' : 'English';
            }
          });
        } else if (mounted) {
          // If document doesn't exist, set default values from Firebase Auth
          setState(() {
            _nameController.text = user.displayName ?? '';
            _emailController.text = user.email ?? '';
            _phoneController.text = '';
            _addressController.text = '';
            _profileImageUrl = user.photoURL;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (mounted) {
        _showGlowingSnackBar(
          'Error loading profile data',
          AppColors.error,
        );
      }
    }
  }

  // Update user data in Firebase
  Future<void> _updateUserData() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'phoneNumber': _phoneController.text.trim(),
          'address': _addressController.text.trim(),
          'profileImageUrl': _profileImageUrl,
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
      debugPrint('Error updating user data: $e');
      if (mounted) {
        _showGlowingSnackBar(
          'Error updating profile: $e',
          AppColors.error,
        );
      }
    }
  }

  // Update save payment preference in Firebase
  Future<void> _updateSavePaymentPreference(bool value) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        debugPrint(
            '🔄 Updating savePayment preference to: $value for user: ${user.uid}');

        // Check if user document exists
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        if (!userDoc.exists) {
          debugPrint('⚠️ User document does not exist, creating it first');
          // Create user document if it doesn't exist
          await _firestore.collection('users').doc(user.uid).set({
            'uid': user.uid,
            'email': user.email,
            'name': user.displayName ?? '',
            'createdAt': FieldValue.serverTimestamp(),
            'preferences': {
              'savePayment': value,
            },
          });
        } else {
          // Update existing document
          await _firestore.collection('users').doc(user.uid).update({
            'preferences.savePayment': value,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        debugPrint('✅ Successfully updated savePayment preference to: $value');

        setState(() {
          _savePaymentMethod = value;
        });

        if (mounted) {
          _showGlowingSnackBar(
            value
                ? 'Payment methods will be saved for future use'
                : 'Payment methods will not be saved',
            AppColors.success,
          );
        }
      } else {
        debugPrint(
            '❌ Cannot update savePayment preference: User is not authenticated');
      }
    } catch (e) {
      debugPrint('❌ Error updating save payment preference: $e');
      if (mounted) {
        _showGlowingSnackBar(
          'Error updating payment preference',
          AppColors.error,
        );
      }
    }
  } // Update notifications preference in Firebase

  Future<void> _updateNotificationPreference(bool value) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'preferences.notifications': value,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        setState(() {
          _notificationsEnabled = value;
        });

        if (mounted) {
          _showGlowingSnackBar(
            'Notification preference updated!',
            AppColors.success,
          );
        }
      }
    } catch (e) {
      debugPrint('Error updating notification preference: $e');
      if (mounted) {
        _showGlowingSnackBar(
          'Error updating notification preference',
          AppColors.error,
        );
      }
    }
  }

  // Update language preference in Firebase
  Future<void> _updateLanguagePreference(String language) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        String languageCode = language == 'Urdu' ? 'ur' : 'en';

        await _firestore.collection('users').doc(user.uid).update({
          'preferences.language': languageCode,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        setState(() {
          _selectedLanguage = language;
        });

        if (mounted) {
          _showGlowingSnackBar(
            'Language updated to $language!',
            AppColors.success,
          );
        }
      }
    } catch (e) {
      debugPrint('Error updating language preference: $e');
      if (mounted) {
        _showGlowingSnackBar(
          'Error updating language preference',
          AppColors.error,
        );
      }
    }
  }

  // Check if biometric authentication is available
  Future<void> _checkBiometricAvailability() async {
    try {
      final isAvailable = await _biometricService.isBiometricAvailable();
      if (mounted) {
        setState(() {
          _isBiometricAvailable = isAvailable;
        });
      }
    } catch (e) {
      debugPrint('Error checking biometric availability: $e');
    }
  }

  // Load current biometric state from the service
  Future<void> _loadCurrentBiometricState() async {
    // First check if biometric is available
    await _checkBiometricAvailability();

    if (!_isBiometricAvailable) return;

    try {
      final isEnabled = await _biometricService.isBiometricEnabled();
      if (mounted) {
        setState(() {
          _biometricEnabled = isEnabled;
        });
      }
    } catch (e) {
      debugPrint('Error loading biometric state: $e');
    }
  }

  // Update biometric preference
  Future<void> _updateBiometricPreference(bool value) async {
    if (!_isBiometricAvailable) {
      _showGlowingSnackBar(
        'Biometric authentication is not available on this device',
        AppColors.error,
      );
      return;
    }

    try {
      if (value) {
        // Check if biometrics are enrolled
        final availableBiometrics =
            await _biometricService.getAvailableBiometrics();
        if (availableBiometrics.isEmpty) {
          _showGlowingSnackBar(
            'Please set up biometric authentication in your device settings first',
            AppColors.error,
          );
          return;
        }

        // Enable biometric
        final success = await _biometricService.enableBiometric();
        if (success) {
          setState(() {
            _biometricEnabled = true;
          });

          if (mounted) {
            _showGlowingSnackBar(
              'Biometric authentication enabled successfully',
              AppColors.success,
            );
          }
        } else {
          if (mounted) {
            _showGlowingSnackBar(
              'Failed to enable biometric authentication. Please check your biometric settings and try again.',
              AppColors.error,
            );
          }
        }
      } else {
        // Disable biometric
        final success = await _biometricService.disableBiometric();
        if (success) {
          setState(() {
            _biometricEnabled = false;
          });

          if (mounted) {
            _showGlowingSnackBar(
              'Biometric authentication disabled',
              AppColors.success,
            );
          }
        } else {
          if (mounted) {
            _showGlowingSnackBar(
              'Failed to disable biometric authentication',
              AppColors.error,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error updating biometric preference: $e');
      if (mounted) {
        String errorMessage = 'Error updating biometric preference';

        // Provide more specific error messages
        if (e.toString().contains('BiometricStatus.notAvailable')) {
          errorMessage =
              'Biometric authentication is not available on this device';
        } else if (e.toString().contains('BiometricStatus.notEnrolled')) {
          errorMessage =
              'No biometric credentials are enrolled. Please set up biometric authentication in your device settings';
        } else if (e.toString().contains('UserCancel')) {
          errorMessage = 'Biometric setup was cancelled';
        } else if (e.toString().contains('PermanentlyLockedOut')) {
          errorMessage =
              'Biometric authentication is temporarily locked. Please try again later';
        } else if (e.toString().contains('LockedOut')) {
          errorMessage = 'Too many failed attempts. Please wait and try again';
        }

        _showGlowingSnackBar(
          errorMessage,
          AppColors.error,
        );
      }
    }
  }

  // Show snackbar with plain white text
  void _showGlowingSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.albertSans(
            fontWeight: FontWeight.w500,
            color: Colors.white,
            shadows: [], // No shadows for plain text
          ),
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
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
    _addressController.dispose();
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
                child: kIsWeb
                    ? Image.network(
                        imageFile.path,
                        fit: BoxFit.cover,
                        width: 200,
                        height: 200,
                      )
                    : Image.file(
                        File(imageFile.path),
                        fit: BoxFit.cover,
                        width: 200,
                        height: 200,
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

        // Upload to ImageBB - handling web vs mobile
        String? imageUrl;
        if (kIsWeb) {
          // For web, we need a different approach
          try {
            final response = await http.get(Uri.parse(imageFile.path));
            if (response.statusCode == 200) {
              final bytes = response.bodyBytes;
              const String apiKey = 'f31e40432a7b500dd75ce5255d3ea517';
              const String uploadUrl = 'https://api.imgbb.com/1/upload';

              String base64Image = base64Encode(bytes);

              // Prepare the request
              var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
              request.fields['key'] = apiKey;
              request.fields['image'] = base64Image;

              // Send the request
              var uploadResponse = await request.send();
              var responseData = await uploadResponse.stream.bytesToString();
              var jsonResponse = json.decode(responseData);

              if (uploadResponse.statusCode == 200 && jsonResponse['success']) {
                imageUrl = jsonResponse['data']['url'];
              }
            }
          } catch (e) {
            debugPrint('Error processing web image: $e');
          }
        } else {
          // Mobile approach
          imageUrl = await _uploadImageToImageBB(File(imageFile.path));
        }

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
  Future<String?> _uploadImageToImageBB(File imageFile) async {
    try {
      const String apiKey = 'f31e40432a7b500dd75ce5255d3ea517';
      const String uploadUrl = 'https://api.imgbb.com/1/upload';

      // Convert image to base64
      List<int> imageBytes = await imageFile.readAsBytes();
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

  // Helper method to get month name
  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }

  // Helper method to safely extract location string from either string or map
  String _extractLocationString(dynamic location) {
    if (location == null) return 'N/A';

    if (location is String) {
      return location.isNotEmpty ? location : 'N/A';
    } else if (location is Map) {
      // Try different possible keys for location data
      return location['address'] ??
          location['name'] ??
          location['description'] ??
          location['formatted_address'] ??
          location['display_name'] ??
          'N/A';
    }

    return 'N/A';
  }

  // Show order details modal
  void _showOrderDetailsModal(Map<String, dynamic> order, String orderId,
      bool isTablet, bool isDarkMode) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: EdgeInsets.only(
          top: MediaQuery.of(context).size.height * 0.2,
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom,
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
          padding: EdgeInsets.all(isTablet ? 32 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order Details',
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 24 : 20,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : AppColors.textPrimary,
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
                        color:
                            isDarkMode ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: isTablet ? 24 : 20),

              // Order ID
              _buildDetailRow('Order ID', orderId, isTablet, isDarkMode),

              // Status
              _buildDetailRow(
                'Status',
                order['status'] ?? 'N/A',
                isTablet,
                isDarkMode,
                valueColor:
                    order['status'] == 'completed' ? Colors.green : Colors.red,
              ),

              // Date
              if (order['createdAt'] != null)
                _buildDetailRow(
                  'Date',
                  _formatFullDate(order['createdAt'] as Timestamp),
                  isTablet,
                  isDarkMode,
                ),

              // Locations - Handle both string and map formats
              _buildDetailRow(
                  'From',
                  _extractLocationString(order['pickupLocation']),
                  isTablet,
                  isDarkMode),
              _buildDetailRow(
                  'To',
                  _extractLocationString(order['dropoffLocation']),
                  isTablet,
                  isDarkMode),

              // Items
              if (order['items'] != null &&
                  order['items'] is List &&
                  (order['items'] as List).isNotEmpty) ...[
                SizedBox(height: isTablet ? 16 : 12),
                Text(
                  'Items',
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: isTablet ? 8 : 6),
                ...(order['items'] as List).map((item) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: isTablet ? 4 : 2),
                    child: Text(
                      '• ${item['name'] ?? 'Item'} ${item['quantity'] != null ? '(${item['quantity']})' : ''}',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 14 : 12,
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.8)
                            : AppColors.textSecondary,
                      ),
                    ),
                  );
                }).toList(),
              ],

              // Total Amount
              if (order['totalAmount'] != null)
                _buildDetailRow(
                  'Total Amount',
                  '\Rs ${order['totalAmount']}',
                  isTablet,
                  isDarkMode,
                  valueColor: isDarkMode
                      ? AppColors.yellowAccent
                      : AppTheme.lightPrimaryColor,
                ),

              // Phone numbers
              if (order['phoneNumber'] != null)
                _buildDetailRow(
                    'Phone', order['phoneNumber'], isTablet, isDarkMode),

              // Special instructions
              if (order['specialInstructions'] != null &&
                  order['specialInstructions'].toString().trim().isNotEmpty)
                _buildDetailRow('Instructions', order['specialInstructions'],
                    isTablet, isDarkMode),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
      String label, String value, bool isTablet, bool isDarkMode,
      {Color? valueColor}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isTablet ? 12 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: isTablet ? 120 : 100,
            child: Text(
              '$label:',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 14 : 12,
                fontWeight: FontWeight.w500,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.7)
                    : AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 14 : 12,
                color: valueColor ??
                    (isDarkMode ? Colors.white : AppColors.textPrimary),
                fontWeight:
                    valueColor != null ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatFullDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
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

  void _logout() {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isDarkMode = themeService.isDarkMode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Log Out',
          style: GoogleFonts.albertSans(
            color: isDarkMode ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to log out?',
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
            onPressed: () async {
              Navigator.pop(context); // Close dialog

              try {
                // Clear biometric cache
                await _biometricService.clearBiometricCache();

                // Clear SharedPreferences (remember me and auto login)
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear(); // Clear all saved preferences

                // Alternative: Clear specific keys if you want to preserve some data
                // await prefs.remove('remember_me');
                // await prefs.remove('saved_email');
                // await prefs.remove('saved_password');
                // await prefs.setBool('auto_login', false);

                // Sign out from Firebase Auth
                await FirebaseAuth.instance.signOut();

                // Navigate to welcome screen immediately without showing snackbar first
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        const WelcomeScreen(),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
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
                  (route) => false, // Remove all previous routes
                );

                // Show success message after navigation
                await Future.delayed(const Duration(milliseconds: 800));
                if (!mounted) return;
                _showGlowingSnackBar(
                  'Successfully logged out',
                  AppColors.success,
                );
              } catch (e) {
                // Handle logout error
                if (!mounted) return;
                _showGlowingSnackBar(
                  'Error logging out: $e',
                  AppColors.error,
                );
              }
            },
            child: Text(
              'Log Out',
              style: GoogleFonts.albertSans(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showChangeAddressModal() {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isDarkMode = themeService.isDarkMode;
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    final TextEditingController addressController =
        TextEditingController(text: _addressController.text);

    HapticFeedback.lightImpact();
    _editAnimationController.forward();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AnimatedBuilder(
        animation: _editAnimationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _editScaleAnimation.value,
            child: Opacity(
              opacity: _editOpacityAnimation.value,
              child: Container(
                margin: EdgeInsets.only(
                  top: screenSize.height * 0.15,
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom,
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
                              'Change Address',
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

                        // Address Input
                        _buildGlowingEditField(
                          controller: addressController,
                          label: 'New Address',
                          icon: Icons.location_on_outlined,
                          isTablet: isTablet,
                          maxLines: 3,
                        ),

                        SizedBox(height: isTablet ? 32 : 24),

                        // Update Button
                        GestureDetector(
                          onTap: () async {
                            if (addressController.text.trim().isEmpty) {
                              _showGlowingSnackBar(
                                'Please enter a valid address',
                                AppColors.error,
                              );
                              return;
                            }

                            // Update address
                            _addressController.text =
                                addressController.text.trim();

                            // Update in Firebase
                            try {
                              final user = _auth.currentUser;
                              if (user != null) {
                                await _firestore
                                    .collection('users')
                                    .doc(user.uid)
                                    .update({
                                  'address': _addressController.text,
                                  'updatedAt': FieldValue.serverTimestamp(),
                                });
                              }

                              if (!mounted) return;
                              Navigator.pop(context);
                              setState(() {});

                              _showGlowingSnackBar(
                                'Address updated successfully!',
                                AppColors.success,
                              );
                            } catch (e) {
                              if (!mounted) return;
                              _showGlowingSnackBar(
                                'Error updating address: $e',
                                AppColors.error,
                              );
                            }
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
                              'Update Address',
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
      ),
    ).then((_) {
      _editAnimationController.reverse();
    });
  }

  void _showChangePasswordModal() {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isDarkMode = themeService.isDarkMode;
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    final TextEditingController currentPasswordController =
        TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController =
        TextEditingController();

    bool obscureCurrentPassword = true;
    bool obscureNewPassword = true;
    bool obscureConfirmPassword = true;

    HapticFeedback.lightImpact();
    _editAnimationController.forward();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AnimatedBuilder(
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
                    bottom: MediaQuery.of(context).viewInsets.bottom,
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
                                'Change Password',
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

                          // Current Password
                          _buildGlowingPasswordField(
                            controller: currentPasswordController,
                            label: 'Current Password',
                            icon: Icons.lock_outline,
                            isTablet: isTablet,
                            obscureText: obscureCurrentPassword,
                            onVisibilityToggle: () {
                              setModalState(() {
                                obscureCurrentPassword =
                                    !obscureCurrentPassword;
                              });
                            },
                          ),

                          SizedBox(height: isTablet ? 20 : 16),

                          // New Password
                          _buildGlowingPasswordField(
                            controller: newPasswordController,
                            label: 'New Password',
                            icon: Icons.lock_outline,
                            isTablet: isTablet,
                            obscureText: obscureNewPassword,
                            onVisibilityToggle: () {
                              setModalState(() {
                                obscureNewPassword = !obscureNewPassword;
                              });
                            },
                          ),

                          SizedBox(height: isTablet ? 20 : 16),

                          // Confirm Password
                          _buildGlowingPasswordField(
                            controller: confirmPasswordController,
                            label: 'Confirm New Password',
                            icon: Icons.lock_outline,
                            isTablet: isTablet,
                            obscureText: obscureConfirmPassword,
                            onVisibilityToggle: () {
                              setModalState(() {
                                obscureConfirmPassword =
                                    !obscureConfirmPassword;
                              });
                            },
                          ),

                          SizedBox(height: isTablet ? 32 : 24),

                          // Update Button
                          GestureDetector(
                            onTap: () async {
                              // Validation
                              if (currentPasswordController.text
                                  .trim()
                                  .isEmpty) {
                                _showGlowingSnackBar(
                                  'Please enter your current password',
                                  AppColors.error,
                                );
                                return;
                              }

                              if (newPasswordController.text.trim().length <
                                  6) {
                                _showGlowingSnackBar(
                                  'New password must be at least 6 characters',
                                  AppColors.error,
                                );
                                return;
                              }

                              if (newPasswordController.text !=
                                  confirmPasswordController.text) {
                                _showGlowingSnackBar(
                                  'New passwords do not match',
                                  AppColors.error,
                                );
                                return;
                              }

                              // Update password in Firebase
                              try {
                                final user = _auth.currentUser;
                                if (user != null) {
                                  // Re-authenticate user first
                                  final credential =
                                      EmailAuthProvider.credential(
                                    email: user.email!,
                                    password: currentPasswordController.text,
                                  );

                                  await user
                                      .reauthenticateWithCredential(credential);

                                  // Update password
                                  await user.updatePassword(
                                      newPasswordController.text);

                                  if (!mounted) return;
                                  Navigator.pop(context);

                                  _showGlowingSnackBar(
                                    'Password updated successfully!',
                                    AppColors.success,
                                  );
                                }
                              } catch (e) {
                                if (!mounted) return;
                                String errorMessage = 'Error updating password';

                                if (e.toString().contains('wrong-password')) {
                                  errorMessage =
                                      'Current password is incorrect';
                                } else if (e
                                    .toString()
                                    .contains('weak-password')) {
                                  errorMessage = 'New password is too weak';
                                }

                                _showGlowingSnackBar(
                                  errorMessage,
                                  AppColors.error,
                                );
                              }
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
                                'Update Password',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.albertSans(
                                  fontSize: isTablet ? 18 : 16,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      isDarkMode ? Colors.black : Colors.white,
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
        ),
      ),
    ).then((_) {
      _editAnimationController.reverse();
    });
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
          backgroundColor:
              isDarkMode ? const Color(0xFF1E1E2C) : const Color(0xFFE8E8F0),
          body: Container(
            decoration: isDarkMode
                ? null
                : null, // Remove background image for clean look
            child: SafeArea(
              child: Column(
                children: [
                  // Header - Full width
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

                            // Current Address Section
                            _buildAddressSection(isTablet, isDarkMode),

                            const SizedBox(height: 24),

                            // Relocation History
                            _buildRelocationHistory(isTablet, isDarkMode),

                            const SizedBox(height: 24),

                            // AI Suggestions
                            _buildAISuggestions(isTablet, isDarkMode),

                            const SizedBox(height: 24),

                            // Settings Section
                            _buildSettingsSection(
                                isTablet, isDarkMode, themeService),

                            const SizedBox(height: 24),

                            // Security Section
                            _buildSecuritySection(isTablet, isDarkMode),

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
    return Container(
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
              Text(
                'Profile',
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 28 : 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _isEditMode = !_isEditMode;
                  });
                  if (_isEditMode) {
                    _showEditProfileModal();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.edit_outlined,
                    color: Colors.white,
                    size: isTablet ? 24 : 20,
                  ),
                ),
              ),
            ],
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
                if (_isEditMode)
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
                          color: isDarkMode
                              ? const Color(0xFF1E1E2C)
                              : Colors.white,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                AppColors.yellowAccent.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.edit,
                        size: 16,
                        color: Colors.black,
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
              _emailController.text,
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
              _phoneController.text,
              textAlign: TextAlign.center,
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 16 : 14,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.7)
                    : AppColors.textSecondary,
              ),
            ),

            SizedBox(height: isTablet ? 20 : 16),

            // Edit Profile Button - Centered
            Center(
              child: GestureDetector(
                onTap: _showEditProfileModal, // Always show modal on tap
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

  Widget _buildAddressSection(bool isTablet, bool isDarkMode) {
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
                  'Default Pickup Address',
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                Icon(
                  Icons.home_outlined,
                  color: isDarkMode
                      ? AppColors.yellowAccent
                      : AppTheme.lightPrimaryColor,
                  size: isTablet ? 24 : 20,
                ),
              ],
            ),
            SizedBox(height: isTablet ? 16 : 12),
            Text(
              _addressController.text,
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 16 : 14,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.8)
                    : AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            SizedBox(height: isTablet ? 20 : 16),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _showChangeAddressModal();
              },
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 20 : 16,
                  vertical: isTablet ? 12 : 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.3)
                        : AppTheme.lightPrimaryColor.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.edit_location_outlined,
                      size: isTablet ? 18 : 16,
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.8)
                          : AppColors.textSecondary,
                    ),
                    SizedBox(width: isTablet ? 8 : 6),
                    Text(
                      'Change Address',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 14 : 12,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.8)
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRelocationHistory(bool isTablet, bool isDarkMode) {
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
                  'Relocation History',
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                Icon(
                  Icons.history,
                  color: isDarkMode
                      ? AppColors.yellowAccent
                      : AppTheme.lightPrimaryColor,
                  size: isTablet ? 24 : 20,
                ),
              ],
            ),

            SizedBox(height: isTablet ? 20 : 16),

            // Firebase Orders Stream - temporarily show all orders for debugging
            StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('orders').limit(10).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: isDarkMode
                          ? AppColors.yellowAccent
                          : AppTheme.lightPrimaryColor,
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading orders',
                      style: GoogleFonts.albertSans(
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.7)
                            : AppColors.textSecondary,
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.history_outlined,
                          size: 48,
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.3)
                              : AppColors.textSecondary.withValues(alpha: 0.5),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No order history yet',
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 16 : 14,
                            color: isDarkMode
                                ? Colors.white.withValues(alpha: 0.7)
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final orders = snapshot.data!.docs;

                // Debug info
                debugPrint('Current User UID: ${_auth.currentUser?.uid}');
                debugPrint('Total orders found: ${orders.length}');

                // Filter for current user's orders first
                final userOrders = orders.where((doc) {
                  final order = doc.data() as Map<String, dynamic>;
                  final orderUid = order['uid']?.toString();
                  debugPrint(
                      'Order UID: $orderUid, Matches: ${orderUid == _auth.currentUser?.uid}');
                  return orderUid == _auth.currentUser?.uid;
                }).toList();

                debugPrint('User orders found: ${userOrders.length}');

                // Filter for completed and cancelled orders
                final filteredOrders = userOrders.where((doc) {
                  final order = doc.data() as Map<String, dynamic>;
                  final status = order['status']?.toString().toLowerCase();
                  debugPrint('Order status: $status');
                  return status == 'completed' || status == 'cancelled';
                }).toList();

                // Debug info - print current user and order count
                debugPrint('Current User UID: ${_auth.currentUser?.uid}');
                debugPrint('Total orders found: ${orders.length}');
                debugPrint(
                    'Filtered orders (completed/cancelled): ${filteredOrders.length}');

                if (filteredOrders.isEmpty) {
                  return Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.history_outlined,
                          size: 48,
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.3)
                              : AppColors.textSecondary.withValues(alpha: 0.5),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No completed or cancelled orders yet',
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 16 : 14,
                            color: isDarkMode
                                ? Colors.white.withValues(alpha: 0.7)
                                : AppColors.textSecondary,
                          ),
                        ),
                        if (orders.isNotEmpty) ...[
                          SizedBox(height: 8),
                          Text(
                            'Found ${orders.length} total orders',
                            style: GoogleFonts.albertSans(
                              fontSize: isTablet ? 12 : 10,
                              color: isDarkMode
                                  ? Colors.white.withValues(alpha: 0.5)
                                  : AppColors.textSecondary
                                      .withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                // Sort by most recent first and limit to 5
                filteredOrders.sort((a, b) {
                  final orderA = a.data() as Map<String, dynamic>;
                  final orderB = b.data() as Map<String, dynamic>;

                  dynamic timestampA = orderA['startedAt'] ??
                      orderA['updatedAt'] ??
                      orderA['paymentTimestamp'];
                  dynamic timestampB = orderB['startedAt'] ??
                      orderB['updatedAt'] ??
                      orderB['paymentTimestamp'];

                  if (timestampA == null && timestampB == null) return 0;
                  if (timestampA == null) return 1;
                  if (timestampB == null) return -1;

                  try {
                    DateTime dateA = timestampA is Timestamp
                        ? timestampA.toDate()
                        : DateTime.parse(timestampA.toString());
                    DateTime dateB = timestampB is Timestamp
                        ? timestampB.toDate()
                        : DateTime.parse(timestampB.toString());
                    return dateB.compareTo(dateA);
                  } catch (e) {
                    return 0;
                  }
                });

                final displayOrders = filteredOrders.take(5).toList();

                return Column(
                  children: displayOrders.asMap().entries.map((entry) {
                    final index = entry.key;
                    final doc = entry.value;
                    final order = doc.data() as Map<String, dynamic>;

                    // Format date - use startedAt or other available timestamps
                    String formattedDate = 'N/A';
                    dynamic timestampField = order['startedAt'] ??
                        order['updatedAt'] ??
                        order['paymentTimestamp'];

                    if (timestampField != null) {
                      try {
                        final timestamp = timestampField as Timestamp;
                        final date = timestamp.toDate();
                        formattedDate =
                            '${date.day} ${_getMonthName(date.month)} ${date.year}';
                      } catch (e) {
                        formattedDate = 'Recent';
                      }
                    }

                    // Extract location strings safely
                    String fromLocation = 'Unknown';
                    String toLocation = 'Unknown';

                    if (order['pickupLocation'] != null) {
                      if (order['pickupLocation'] is String) {
                        fromLocation = order['pickupLocation'];
                      } else if (order['pickupLocation'] is Map) {
                        fromLocation = order['pickupLocation']['address'] ??
                            order['pickupLocation']['name'] ??
                            order['pickupLocation']['description'] ??
                            'Unknown';
                      }
                    }

                    if (order['dropoffLocation'] != null) {
                      if (order['dropoffLocation'] is String) {
                        toLocation = order['dropoffLocation'];
                      } else if (order['dropoffLocation'] is Map) {
                        toLocation = order['dropoffLocation']['address'] ??
                            order['dropoffLocation']['name'] ??
                            order['dropoffLocation']['description'] ??
                            'Unknown';
                      }
                    }

                    return Column(
                      children: [
                        _buildHistoryItem(
                          date: formattedDate,
                          from: fromLocation,
                          to: toLocation,
                          status: order['status'] == 'completed'
                              ? 'Completed'
                              : 'Cancelled',
                          statusColor: order['status'] == 'completed'
                              ? Colors.green
                              : Colors.red,
                          orderId: doc.id,
                          order: order,
                          isTablet: isTablet,
                          isDarkMode: isDarkMode,
                        ),
                        if (index < displayOrders.length - 1)
                          SizedBox(height: isTablet ? 16 : 12),
                      ],
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem({
    required String date,
    required String from,
    required String to,
    required String status,
    required Color statusColor,
    String? orderId,
    Map<String, dynamic>? order,
    required bool isTablet,
    required bool isDarkMode,
  }) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                date,
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 14 : 12,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : AppColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 12 : 10,
                    fontWeight: FontWeight.w500,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: isTablet ? 8 : 6),

          Row(
            children: [
              Expanded(
                child: Text(
                  from,
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 13 : 11,
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.7)
                        : AppColors.textSecondary,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward,
                size: isTablet ? 16 : 14,
                color: isDarkMode
                    ? AppColors.yellowAccent
                    : AppTheme.lightPrimaryColor,
              ),
              Expanded(
                child: Text(
                  to,
                  textAlign: TextAlign.end,
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 13 : 11,
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.7)
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),

          // Show additional order details if available
          if (order != null) ...[
            SizedBox(height: isTablet ? 8 : 6),

            // Items count
            if (order['items'] != null && order['items'] is List)
              Text(
                '${(order['items'] as List).length} items',
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 12 : 10,
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.6)
                      : AppColors.textSecondary,
                ),
              ),

            // Total amount if available
            if (order['totalAmount'] != null)
              Text(
                'Amount: \Rs ${order['totalAmount']}',
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 12 : 10,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode
                      ? AppColors.yellowAccent
                      : AppTheme.lightPrimaryColor,
                ),
              ),
          ],

          SizedBox(height: isTablet ? 8 : 6),

          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              if (order != null && orderId != null) {
                _showOrderDetailsModal(order, orderId, isTablet, isDarkMode);
              }
            },
            child: Text(
              'View Details',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 12 : 10,
                fontWeight: FontWeight.w500,
                color: isDarkMode
                    ? AppColors.yellowAccent
                    : AppTheme.lightPrimaryColor,
                decoration: TextDecoration.underline,
                decorationColor: isDarkMode
                    ? AppColors.yellowAccent
                    : AppTheme.lightPrimaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAISuggestions(bool isTablet, bool isDarkMode) {
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
                  'AI Recommendations',
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                Icon(
                  Icons.psychology_outlined,
                  color: isDarkMode
                      ? AppColors.yellowAccent
                      : AppTheme.lightPrimaryColor,
                  size: isTablet ? 24 : 20,
                ),
              ],
            ),
            SizedBox(height: isTablet ? 16 : 12),
            _buildSuggestionItem(
              icon: Icons.schedule,
              text:
                  'Based on your past moves, we recommend booking 3 days in advance.',
              isTablet: isTablet,
              isDarkMode: isDarkMode,
            ),
            SizedBox(height: isTablet ? 12 : 8),
            _buildSuggestionItem(
              icon: Icons.inventory_2_outlined,
              text:
                  'You usually move 2BHK items. Would you like to pre-fill your inventory?',
              isTablet: isTablet,
              isDarkMode: isDarkMode,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionItem({
    required IconData icon,
    required String text,
    required bool isTablet,
    required bool isDarkMode,
  }) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: AppColors.yellowAccent.withValues(alpha: isDarkMode ? 0.1 : 0.2),
        borderRadius: BorderRadius.circular(12),
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
                  color: AppColors.yellowAccent.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: isDarkMode
                ? AppColors.yellowAccent
                : AppTheme.lightPrimaryColor,
            size: isTablet ? 20 : 18,
          ),
          SizedBox(width: isTablet ? 12 : 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 14 : 12,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.9)
                    : AppColors.textPrimary,
                height: 1.4,
              ),
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
                  'Settings',
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
            SizedBox(height: isTablet ? 20 : 16),
            _buildSettingItem(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              isSwitch: true,
              value: _notificationsEnabled,
              onChanged: (value) {
                _updateNotificationPreference(value);
              },
              isTablet: isTablet,
              isDarkMode: isDarkMode,
            ),
            SizedBox(height: isTablet ? 16 : 12),
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
            SizedBox(height: isTablet ? 16 : 12),
            _buildSettingItem(
              icon: Icons.payment_outlined,
              title: 'Save Payment Method',
              subtitle: _savePaymentMethod
                  ? 'Your payment cards will be securely saved for faster checkout'
                  : 'Payment details will not be saved',
              isSwitch: true,
              value: _savePaymentMethod,
              onChanged: (value) {
                _updateSavePaymentPreference(value);
              },
              isTablet: isTablet,
              isDarkMode: isDarkMode,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecuritySection(bool isTablet, bool isDarkMode) {
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
                  'Security',
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                Icon(
                  Icons.security_outlined,
                  color: isDarkMode
                      ? AppColors.yellowAccent
                      : AppTheme.lightPrimaryColor,
                  size: isTablet ? 24 : 20,
                ),
              ],
            ),
            SizedBox(height: isTablet ? 20 : 16),
            _buildSettingItem(
              icon: Icons.lock_outline,
              title: 'Change Password',
              onTap: () {
                HapticFeedback.lightImpact();
                _showChangePasswordModal();
              },
              isTablet: isTablet,
              isDarkMode: isDarkMode,
            ),
            SizedBox(height: isTablet ? 16 : 12),
            _buildSettingItem(
              icon: Icons.fingerprint,
              title: 'Biometric Login',
              subtitle: _isBiometricAvailable
                  ? 'Face ID / Fingerprint'
                  : 'Not available on this device',
              isSwitch: true,
              value: _biometricEnabled,
              onChanged: _updateBiometricPreference,
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
            if (isSwitch && value != null)
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

  Widget _buildLogoutButton(bool isTablet, bool isDarkMode) {
    return SlideTransition(
      position: _slideAnimation,
      child: GestureDetector(
        onTap: _logout,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            vertical: isTablet ? 16 : 14,
          ),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.transparent : AppTheme.lightCardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.red,
              width: 2,
            ),
            boxShadow: isDarkMode
                ? null
                : [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.logout,
                color: Colors.red,
                size: isTablet ? 22 : 20,
              ),
              SizedBox(width: isTablet ? 12 : 8),
              Text(
                'Log Out',
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 18 : 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
            ],
          ),
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

                      SizedBox(height: isTablet ? 32 : 24),

                      // Save Button
                      GestureDetector(
                        onTap: () async {
                          HapticFeedback.lightImpact();

                          // Update user data in Firebase
                          await _updateUserData();

                          if (!mounted) return;
                          Navigator.pop(context);
                          setState(() {
                            _isEditMode = false;
                          });
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
            borderRadius: BorderRadius.circular(16), // Increased border radius
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
                borderRadius:
                    BorderRadius.circular(16), // Maintain rounded corners
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                    16), // Maintain rounded corners when focused
                borderSide: BorderSide(
                  color: AppColors.yellowAccent,
                  width: 2,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                    16), // Maintain rounded corners when enabled
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

  Widget _buildGlowingPasswordField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isTablet,
    required bool obscureText,
    required VoidCallback onVisibilityToggle,
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
            borderRadius: BorderRadius.circular(16), // Increased border radius
            border: Border.all(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.2)
                  : AppColors.grey300,
              width: 1,
            ),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
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
              suffixIcon: IconButton(
                onPressed: onVisibilityToggle,
                icon: Icon(
                  obscureText ? Icons.visibility_off : Icons.visibility,
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.6)
                      : AppColors.textSecondary,
                  size: isTablet ? 24 : 20,
                ),
              ),
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(16), // Maintain rounded corners
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                    16), // Maintain rounded corners when focused
                borderSide: BorderSide(
                  color: AppColors.yellowAccent,
                  width: 2,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                    16), // Maintain rounded corners when enabled
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
    final languages = ['English', 'Urdu']; // Only English and Urdu

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
                      _updateLanguagePreference(language);
                      Navigator.pop(context);
                    },
                  ))
              .toList(),
        ],
      ),
    );
  }
}
