import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'package:shiffters/theme/app_colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _editAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _editScaleAnimation;
  late Animation<double> _editOpacityAnimation;
  
  bool _isEditMode = false;
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = true;
  bool _savePaymentMethod = false;
  bool _biometricEnabled = false;
  String _selectedLanguage = 'English';
  
  final TextEditingController _nameController = TextEditingController(text: 'Laurel Johnson');
  final TextEditingController _emailController = TextEditingController(text: 'laurel.johnson@email.com');
  final TextEditingController _phoneController = TextEditingController(text: '+1 (555) 123-4567');
  final TextEditingController _addressController = TextEditingController(text: '123 Main Street, Downtown, New York, NY 10001');

  @override
  void initState() {
    super.initState();
    
    _initializeAnimations();
    _startAnimations();
    
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

  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
    });
    HapticFeedback.lightImpact();
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

  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2D2D3C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildLanguageSelector(),
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D3C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Log Out',
          style: GoogleFonts.albertSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to log out?',
          style: GoogleFonts.albertSans(
            color: Colors.white.withOpacity(0.8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.albertSans(
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Handle logout
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

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 32 : 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                
                // Header
                _buildHeader(isTablet),
                
                const SizedBox(height: 24),
                
                // Profile Section
                _buildProfileSection(isTablet),
                
                const SizedBox(height: 24),
                
                // Current Address Section
                _buildAddressSection(isTablet),
                
                const SizedBox(height: 24),
                
                // Relocation History
                _buildRelocationHistory(isTablet),
                
                const SizedBox(height: 24),
                
                // AI Suggestions
                _buildAISuggestions(isTablet),
                
                const SizedBox(height: 24),
                
                // Settings Section
                _buildSettingsSection(isTablet),
                
                const SizedBox(height: 24),
                
                // Security Section
                _buildSecuritySection(isTablet),
                
                const SizedBox(height: 24),
                
                // Logout Button
                _buildLogoutButton(isTablet),
                
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isTablet) {
    return FadeTransition(
      opacity: _fadeAnimation,
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.settings_outlined,
              size: isTablet ? 26 : 24,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection(bool isTablet) {
  return SlideTransition(
    position: _slideAnimation,
    child: Container(
      padding: EdgeInsets.all(isTablet ? 24 : 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Avatar and Edit Icon
          Stack(
            children: [
              Container(
                width: isTablet ? 100 : 80,
                height: isTablet ? 100 : 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.yellowAccent,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.yellowAccent.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Container(
                    color: AppColors.yellowAccent.withOpacity(0.2),
                    child: Icon(
                      Icons.person,
                      size: isTablet ? 50 : 40,
                      color: AppColors.yellowAccent,
                    ),
                  ),
                ),
              ),
              if (_isEditMode)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.yellowAccent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF1E1E2C),
                        width: 2,
                      ),
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
              color: Colors.white,
            ),
          ),
          
          SizedBox(height: isTablet ? 8 : 6),
          
          Text(
            _emailController.text,
            textAlign: TextAlign.center,
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 16 : 14,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          
          SizedBox(height: isTablet ? 4 : 2),
          
          Text(
            _phoneController.text,
            textAlign: TextAlign.center,
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 16 : 14,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          
          SizedBox(height: isTablet ? 20 : 16),
          
          // Edit Profile Button - Centered
          Center(
            child: GestureDetector(
              onTap: _isEditMode ? _showEditProfileModal : _toggleEditMode,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 24 : 20,
                  vertical: isTablet ? 12 : 10,
                ),
                decoration: BoxDecoration(
                  color: _isEditMode ? AppColors.yellowAccent : Colors.transparent,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: AppColors.yellowAccent,
                    width: 2,
                  ),
                ),
                child: Text(
                  _isEditMode ? 'Save Changes' : 'Edit Profile',
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.w600,
                    color: _isEditMode ? Colors.black : AppColors.yellowAccent,
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

  Widget _buildAddressSection(bool isTablet) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        padding: EdgeInsets.all(isTablet ? 24 : 20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
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
                    color: Colors.white,
                  ),
                ),
                Icon(
                  Icons.home_outlined,
                  color: AppColors.yellowAccent,
                  size: isTablet ? 24 : 20,
                ),
              ],
            ),
            
            SizedBox(height: isTablet ? 16 : 12),
            
            Text(
              _addressController.text,
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 16 : 14,
                color: Colors.white.withOpacity(0.8),
                height: 1.4,
              ),
            ),
            
            SizedBox(height: isTablet ? 20 : 16),
            
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                // Handle address change
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
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.edit_location_outlined,
                      size: isTablet ? 18 : 16,
                      color: Colors.white.withOpacity(0.8),
                    ),
                    SizedBox(width: isTablet ? 8 : 6),
                    Text(
                      'Change Address',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 14 : 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.8),
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

  Widget _buildRelocationHistory(bool isTablet) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        padding: EdgeInsets.all(isTablet ? 24 : 20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
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
                    color: Colors.white,
                  ),
                ),
                Icon(
                  Icons.history,
                  color: AppColors.yellowAccent,
                  size: isTablet ? 24 : 20,
                ),
              ],
            ),
            
            SizedBox(height: isTablet ? 20 : 16),
            
            // History Items
            _buildHistoryItem(
              date: '15 Dec 2023',
              from: 'Downtown, NY',
              to: 'Brooklyn, NY',
              status: 'Completed',
              statusColor: Colors.green,
              isTablet: isTablet,
            ),
            
            SizedBox(height: isTablet ? 16 : 12),
            
            _buildHistoryItem(
              date: '28 Nov 2023',
              from: 'Manhattan, NY',
              to: 'Queens, NY',
              status: 'Completed',
              statusColor: Colors.green,
              isTablet: isTablet,
            ),
            
            SizedBox(height: isTablet ? 16 : 12),
            
            _buildHistoryItem(
              date: '10 Oct 2023',
              from: 'Bronx, NY',
              to: 'Staten Island, NY',
              status: 'Cancelled',
              statusColor: Colors.red,
              isTablet: isTablet,
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
    required bool isTablet,
  }) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
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
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
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
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward,
                size: isTablet ? 16 : 14,
                color: AppColors.yellowAccent,
              ),
              Expanded(
                child: Text(
                  to,
                  textAlign: TextAlign.end,
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 13 : 11,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: isTablet ? 8 : 6),
          
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              // Handle view details
            },
            child: Text(
              'View Details',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 12 : 10,
                fontWeight: FontWeight.w500,
                color: AppColors.yellowAccent,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.yellowAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAISuggestions(bool isTablet) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        padding: EdgeInsets.all(isTablet ? 24 : 20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
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
                    color: Colors.white,
                  ),
                ),
                Icon(
                  Icons.psychology_outlined,
                  color: AppColors.yellowAccent,
                  size: isTablet ? 24 : 20,
                ),
              ],
            ),
            
            SizedBox(height: isTablet ? 16 : 12),
            
            _buildSuggestionItem(
              icon: Icons.schedule,
              text: 'Based on your past moves, we recommend booking 3 days in advance.',
              isTablet: isTablet,
            ),
            
            SizedBox(height: isTablet ? 12 : 8),
            
            _buildSuggestionItem(
              icon: Icons.inventory_2_outlined,
              text: 'You usually move 2BHK items. Would you like to pre-fill your inventory?',
              isTablet: isTablet,
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
  }) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: AppColors.yellowAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.yellowAccent.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppColors.yellowAccent,
            size: isTablet ? 20 : 18,
          ),
          SizedBox(width: isTablet ? 12 : 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 14 : 12,
                color: Colors.white.withOpacity(0.9),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(bool isTablet) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        padding: EdgeInsets.all(isTablet ? 24 : 20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
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
                    color: Colors.white,
                  ),
                ),
                Icon(
                  Icons.settings_outlined,
                  color: AppColors.yellowAccent,
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
                setState(() {
                  _notificationsEnabled = value;
                });
              },
              isTablet: isTablet,
            ),
            
            SizedBox(height: isTablet ? 16 : 12),
            
            _buildSettingItem(
              icon: Icons.language_outlined,
              title: 'Language',
              subtitle: _selectedLanguage,
              onTap: _showLanguageSelector,
              isTablet: isTablet,
            ),
            
            SizedBox(height: isTablet ? 16 : 12),
            
            _buildSettingItem(
              icon: Icons.dark_mode_outlined,
              title: 'Dark Mode',
              isSwitch: true,
              value: _darkModeEnabled,
              onChanged: (value) {
                setState(() {
                  _darkModeEnabled = value;
                });
              },
              isTablet: isTablet,
            ),
            
            SizedBox(height: isTablet ? 16 : 12),
            
            _buildSettingItem(
              icon: Icons.payment_outlined,
              title: 'Save Payment Method',
              isSwitch: true,
              value: _savePaymentMethod,
              onChanged: (value) {
                setState(() {
                  _savePaymentMethod = value;
                });
              },
              isTablet: isTablet,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecuritySection(bool isTablet) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        padding: EdgeInsets.all(isTablet ? 24 : 20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
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
                    color: Colors.white,
                  ),
                ),
                Icon(
                  Icons.security_outlined,
                  color: AppColors.yellowAccent,
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
                // Handle password change
              },
              isTablet: isTablet,
            ),
            
            SizedBox(height: isTablet ? 16 : 12),
            
            _buildSettingItem(
              icon: Icons.fingerprint,
              title: 'Biometric Login',
              subtitle: 'Face ID / Fingerprint',
              isSwitch: true,
              value: _biometricEnabled,
              onChanged: (value) {
                setState(() {
                  _biometricEnabled = value;
                });
              },
              isTablet: isTablet,
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
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 16 : 12,
          vertical: isTablet ? 16 : 12,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: Colors.white.withOpacity(0.8),
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
                      color: Colors.white,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 14 : 12,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                ],
              ),
            ),
            if (isSwitch && value != null && onChanged != null)
              Switch(
                value: value,
                onChanged: onChanged,
                activeColor: AppColors.yellowAccent,
                activeTrackColor: AppColors.yellowAccent.withOpacity(0.3),
                inactiveThumbColor: Colors.white.withOpacity(0.5),
                inactiveTrackColor: Colors.white.withOpacity(0.2),
              )
            else if (!isSwitch)
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.white.withOpacity(0.5),
                size: isTablet ? 18 : 16,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(bool isTablet) {
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
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.red,
              width: 2,
            ),
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
                color: const Color(0xFF2D2D3C),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
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
                              color: Colors.white,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.close,
                                size: isTablet ? 24 : 20,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      SizedBox(height: isTablet ? 32 : 24),
                      
                      // Form Fields
                      _buildEditField(
                        controller: _nameController,
                        label: 'Full Name',
                        icon: Icons.person_outline,
                        isTablet: isTablet,
                      ),
                      
                      SizedBox(height: isTablet ? 20 : 16),
                      
                      _buildEditField(
                        controller: _emailController,
                        label: 'Email',
                        icon: Icons.email_outlined,
                        isTablet: isTablet,
                      ),
                      
                      SizedBox(height: isTablet ? 20 : 16),
                      
                      _buildEditField(
                        controller: _phoneController,
                        label: 'Phone Number',
                        icon: Icons.phone_outlined,
                        isTablet: isTablet,
                      ),
                      
                      SizedBox(height: isTablet ? 32 : 24),
                      
                      // Save Button
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
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
                            color: AppColors.yellowAccent,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.yellowAccent.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text(
                            'Save Changes',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.albertSans(
                              fontSize: isTablet ? 18 : 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
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

  Widget _buildEditField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isTablet,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.albertSans(
            fontSize: isTablet ? 16 : 14,
            fontWeight: FontWeight.w500,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
        SizedBox(height: isTablet ? 8 : 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: TextField(
            controller: controller,
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 16 : 14,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(
                icon,
                color: Colors.white.withOpacity(0.6),
                size: isTablet ? 24 : 20,
              ),
              border: InputBorder.none,
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
    final languages = ['English', 'Spanish', 'French', 'German', 'Italian'];
    
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
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          ...languages.map((language) => ListTile(
            title: Text(
              language,
              style: GoogleFonts.albertSans(
                color: Colors.white,
                fontWeight: _selectedLanguage == language ? FontWeight.w600 : FontWeight.normal,
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
          )).toList(),
        ],
      ),
    );
  }
}
