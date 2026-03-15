import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shiffters/theme/app_colors.dart';
import 'package:shiffters/theme/app_theme.dart';
import 'package:shiffters/services/theme_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late AnimationController _animationController;
  late AnimationController _cardAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _cardScaleAnimation;

  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';
  final List<String> _filterOptions = ['All', 'Active', 'Blocked', 'New'];

  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  Set<String> _selectedUsers = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    _initializeAnimations();
    _startAnimations();
    _loadUsers();

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
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _cardAnimationController = AnimationController(
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

    _cardScaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cardAnimationController,
      curve: Curves.easeOutBack,
    ));
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      _animationController.forward();
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) {
        _cardAnimationController.forward();
      }
    }
  }

  // Load users from Firebase
  Future<void> _loadUsers() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final usersSnapshot = await _firestore
          .collection('users')
          .orderBy('createdAt', descending: true)
          .get();

      if (mounted) {
        setState(() {
          _allUsers = usersSnapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'name': data['name'] ?? 'Unknown User',
              'email': data['email'] ?? '',
              'phone': data['phoneNumber'] ?? '',
              'gender': data['gender'] ?? '',
              'status': data['status'] ?? 'New',
              'dateOfBirth': data['dateOfBirth'] ?? '',
              'emergencyContact': data['emergencyContact'] ?? '',
              'registrationDate': _formatDate(data['createdAt']),
              'lastLogin': _formatDate(data['lastLoginAt']),
              'updatedAt': _formatDate(data['updatedAt']),
              'totalOrders': data['totalOrders'] ?? 0,
              'profileImageUrl': data['profileImageUrl'] ?? '',
              'address': data['address'] ?? '',
              'city': data['city'] ?? '',
              'country': data['country'] ?? '',
              'isEmailVerified': data['isEmailVerified'] ?? false,
              'isPhoneVerified': data['isPhoneVerified'] ?? false,
              'itemsVerified': data['itemsVerified'] ?? false,
              'profileCompleted': data['profileCompleted'] ?? false,
              'isActive': data['isActive'] ?? true,
              'preferences': data['preferences'] ?? {},
              'role': data['role'] ?? 'user',
            };
          }).toList();

          _filterUsers();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading users: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showGlowingSnackBar(
          'Error loading users: $e',
          AppColors.error,
        );
      }
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Not available';

    try {
      DateTime date;
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is String) {
        return timestamp;
      } else {
        return 'Invalid date';
      }

      return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalid date';
    }
  }

  // Update user status in Firebase
  Future<void> _updateUserStatus(String userId, String newStatus) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': _auth.currentUser?.uid,
      });

      if (mounted) {
        _showGlowingSnackBar(
          'User status updated successfully!',
          AppColors.success,
        );
      }
    } catch (e) {
      debugPrint('Error updating user status: $e');
      if (mounted) {
        _showGlowingSnackBar(
          'Error updating user status: $e',
          AppColors.error,
        );
      }
    }
  }

  // Bulk update user statuses
  Future<void> _bulkUpdateStatus(List<String> userIds, String newStatus) async {
    try {
      final batch = _firestore.batch();

      for (String userId in userIds) {
        final userRef = _firestore.collection('users').doc(userId);
        batch.update(userRef, {
          'status': newStatus,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': _auth.currentUser?.uid,
        });
      }

      await batch.commit();

      if (mounted) {
        _showGlowingSnackBar(
          'Users updated successfully!',
          AppColors.success,
        );
        _loadUsers(); // Refresh the list
      }
    } catch (e) {
      debugPrint('Error bulk updating users: $e');
      if (mounted) {
        _showGlowingSnackBar(
          'Error updating users: $e',
          AppColors.error,
        );
      }
    }
  }

  // Delete users from Firebase
  Future<void> _deleteUsers(List<String> userIds) async {
    try {
      final batch = _firestore.batch();

      for (String userId in userIds) {
        final userRef = _firestore.collection('users').doc(userId);
        batch.delete(userRef);
      }

      await batch.commit();

      if (mounted) {
        _showGlowingSnackBar(
          'Users deleted successfully!',
          AppColors.success,
        );
        _loadUsers(); // Refresh the list
      }
    } catch (e) {
      debugPrint('Error deleting users: $e');
      if (mounted) {
        _showGlowingSnackBar(
          'Error deleting users: $e',
          AppColors.error,
        );
      }
    }
  }

  void _filterUsers() {
    setState(() {
      _filteredUsers = _allUsers.where((user) {
        final matchesFilter =
            _selectedFilter == 'All' || user['status'] == _selectedFilter;
        final matchesSearch = _searchController.text.isEmpty ||
            user['name']
                .toLowerCase()
                .contains(_searchController.text.toLowerCase()) ||
            user['email']
                .toLowerCase()
                .contains(_searchController.text.toLowerCase()) ||
            user['phone'].contains(_searchController.text);
        return matchesFilter && matchesSearch;
      }).toList();
    });
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
    _cardAnimationController.dispose();
    _searchController.dispose();
    super.dispose();
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

                  // Search and filters
                  _buildSearchAndFilters(isTablet, isDarkMode),

                  // Bulk actions
                  if (_selectedUsers.isNotEmpty)
                    _buildBulkActions(isTablet, isDarkMode),

                  // Content
                  Expanded(
                    child: _isLoading
                        ? _buildLoadingIndicator(isDarkMode)
                        : _buildUsersList(isTablet, isDarkMode),
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
                // Title
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'User Management',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 28 : 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Manage platform users',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 14 : 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
                // Actions
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _showUserFilters();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.filter_list,
                          size: isTablet ? 24 : 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters(bool isTablet, bool isDarkMode) {
    return SlideTransition(
      position: _slideAnimation,
      child: Column(
        children: [
          // Search bar
          Container(
            margin: EdgeInsets.symmetric(
              horizontal: isTablet ? 32 : 20,
              vertical: isTablet ? 16 : 12,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.1)
                  : AppTheme.lightCardColor,
              borderRadius: BorderRadius.circular(16),
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
            child: Row(
              children: [
                Icon(
                  Icons.search,
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.7)
                      : AppTheme.lightTextSecondaryColor,
                  size: isTablet ? 24 : 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => _filterUsers(),
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 16 : 14,
                      color: isDarkMode
                          ? Colors.white
                          : AppTheme.lightTextPrimaryColor,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search by name, email, or phone...',
                      hintStyle: GoogleFonts.albertSans(
                        fontSize: isTablet ? 16 : 14,
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.5)
                            : AppTheme.lightTextSecondaryColor,
                      ),
                      border: InputBorder.none,
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: isDarkMode
                              ? AppColors.yellowAccent
                              : AppTheme.lightPrimaryColor,
                          width: 2.0,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.3)
                              : AppTheme.lightPrimaryColor,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Filter tabs
          Container(
            height: 50,
            margin: EdgeInsets.symmetric(
              horizontal: isTablet ? 32 : 20,
              vertical: isTablet ? 8 : 4,
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _filterOptions.length,
              itemBuilder: (context, index) {
                final option = _filterOptions[index];
                final isSelected = _selectedFilter == option;

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _selectedFilter = option;
                      _filterUsers();
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDarkMode
                              ? AppColors.yellowAccent
                              : AppTheme.lightPrimaryColor)
                          : (isDarkMode
                              ? Colors.white.withValues(alpha: 0.1)
                              : AppTheme.lightCardColor),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: isSelected
                            ? (isDarkMode
                                ? AppColors.yellowAccent
                                : AppTheme.lightPrimaryColor)
                            : (isDarkMode
                                ? Colors.white.withValues(alpha: 0.3)
                                : AppTheme.lightBorderColor),
                        width: 1.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: (isDarkMode
                                        ? AppColors.yellowAccent
                                        : AppTheme.lightPrimaryColor)
                                    .withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        option,
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 14 : 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? (isDarkMode ? Colors.black : Colors.white)
                              : (isDarkMode
                                  ? Colors.white
                                  : AppTheme.lightTextPrimaryColor),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulkActions(bool isTablet, bool isDarkMode) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: isTablet ? 32 : 20,
          vertical: isTablet ? 8 : 4,
        ),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode
              ? AppColors.yellowAccent.withValues(alpha: 0.2)
              : AppTheme.lightPrimaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDarkMode
                ? AppColors.yellowAccent
                : AppTheme.lightPrimaryColor,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (isDarkMode
                      ? AppColors.yellowAccent
                      : AppTheme.lightPrimaryColor)
                  .withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: isDarkMode
                  ? AppColors.yellowAccent
                  : AppTheme.lightPrimaryColor,
              size: isTablet ? 24 : 20,
            ),
            const SizedBox(width: 12),
            Text(
              '${_selectedUsers.length} selected',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 16 : 14,
                fontWeight: FontWeight.w600,
                color:
                    isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
              ),
            ),
            const Spacer(),
            _buildBulkActionButton(
              'Block',
              Colors.red,
              Icons.block,
              _bulkBlock,
              isTablet,
            ),
            const SizedBox(width: 8),
            _buildBulkActionButton(
              'Unblock',
              Colors.green,
              Icons.check_circle,
              _bulkUnblock,
              isTablet,
            ),
            const SizedBox(width: 8),
            _buildBulkActionButton(
              'Delete',
              Colors.red,
              Icons.delete,
              _bulkDelete,
              isTablet,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBulkActionButton(
    String label,
    Color color,
    IconData icon,
    VoidCallback onPressed,
    bool isTablet,
  ) {
    return Container(
      height: isTablet ? 36.0 : 32.0,
      child: ElevatedButton.icon(
        onPressed: () {
          HapticFeedback.lightImpact();
          onPressed();
        },
        icon: Icon(
          icon,
          color: Colors.white,
          size: isTablet ? 16 : 14,
        ),
        label: Text(
          label,
          style: GoogleFonts.albertSans(
            fontSize: isTablet ? 12 : 10,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: 0.2,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 12 : 8,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: isDarkMode
                ? AppColors.yellowAccent
                : AppTheme.lightPrimaryColor,
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading users...',
            style: GoogleFonts.albertSans(
              fontSize: 16,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.7)
                  : AppTheme.lightTextSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList(bool isTablet, bool isDarkMode) {
    if (_filteredUsers.isEmpty) {
      return _buildEmptyState(isDarkMode);
    }

    return SlideTransition(
      position: _slideAnimation,
      child: RefreshIndicator(
        onRefresh: _refreshUsers,
        color: isDarkMode ? AppColors.yellowAccent : AppTheme.lightPrimaryColor,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 32 : 20,
            vertical: isTablet ? 16 : 12,
          ),
          itemCount: _filteredUsers.length,
          itemBuilder: (context, index) {
            final user = _filteredUsers[index];
            return _buildUserCard(user, isTablet, isDarkMode);
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.3)
                : AppTheme.lightTextSecondaryColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No users found',
            style: GoogleFonts.albertSans(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.7)
                  : AppTheme.lightTextSecondaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or filter criteria',
            style: GoogleFonts.albertSans(
              fontSize: 14,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.5)
                  : AppTheme.lightTextSecondaryColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(
      Map<String, dynamic> user, bool isTablet, bool isDarkMode) {
    final isSelected = _selectedUsers.contains(user['id']);

    return ScaleTransition(
      scale: _cardScaleAnimation,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: EdgeInsets.all(isTablet ? 20 : 16),
        decoration: BoxDecoration(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : AppTheme.lightCardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? (isDarkMode
                    ? AppColors.yellowAccent
                    : AppTheme.lightPrimaryColor)
                : (isDarkMode
                    ? Colors.white.withValues(alpha: 0.2)
                    : AppTheme.lightBorderColor),
            width: isSelected ? 2 : 1.5,
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
          children: [
            Row(
              children: [
                // Checkbox
                Checkbox(
                  value: isSelected,
                  onChanged: (bool? value) {
                    HapticFeedback.lightImpact();
                    setState(() {
                      if (value == true) {
                        _selectedUsers.add(user['id']);
                      } else {
                        _selectedUsers.remove(user['id']);
                      }
                    });
                  },
                  activeColor: isDarkMode
                      ? AppColors.yellowAccent
                      : AppTheme.lightPrimaryColor,
                  checkColor: isDarkMode ? Colors.black : Colors.white,
                ),

                // Avatar
                Container(
                  width: isTablet ? 70 : 60,
                  height: isTablet ? 70 : 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDarkMode
                          ? AppColors.yellowAccent
                          : AppTheme.lightPrimaryColor,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isDarkMode
                                ? AppColors.yellowAccent
                                : AppTheme.lightPrimaryColor)
                            .withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: user['profileImageUrl'] != null &&
                            user['profileImageUrl'].isNotEmpty
                        ? Image.network(
                            user['profileImageUrl'],
                            width: isTablet ? 70 : 60,
                            height: isTablet ? 70 : 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: isDarkMode
                                    ? AppColors.yellowAccent
                                        .withValues(alpha: 0.2)
                                    : AppTheme.lightPrimaryColor
                                        .withValues(alpha: 0.2),
                                child: Icon(
                                  Icons.person,
                                  size: isTablet ? 35 : 30,
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
                                : AppTheme.lightPrimaryColor
                                    .withValues(alpha: 0.2),
                            child: Icon(
                              Icons.person,
                              size: isTablet ? 35 : 30,
                              color: isDarkMode
                                  ? AppColors.yellowAccent
                                  : AppTheme.lightPrimaryColor,
                            ),
                          ),
                  ),
                ),

                const SizedBox(width: 16),

                // User info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              user['name'],
                              style: GoogleFonts.albertSans(
                                fontSize: isTablet ? 18 : 16,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode
                                    ? Colors.white
                                    : AppTheme.lightTextPrimaryColor,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(user['status'])
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _getStatusColor(user['status']),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              user['status'],
                              style: GoogleFonts.albertSans(
                                fontSize: isTablet ? 12 : 10,
                                fontWeight: FontWeight.w600,
                                color: _getStatusColor(user['status']),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.email_outlined,
                            size: isTablet ? 16 : 14,
                            color: isDarkMode
                                ? Colors.white.withValues(alpha: 0.6)
                                : AppTheme.lightTextSecondaryColor,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              user['email'],
                              style: GoogleFonts.albertSans(
                                fontSize: isTablet ? 14 : 12,
                                color: isDarkMode
                                    ? Colors.white.withValues(alpha: 0.7)
                                    : AppTheme.lightTextSecondaryColor,
                              ),
                            ),
                          ),
                          if (user['isEmailVerified'])
                            Icon(
                              Icons.verified,
                              size: isTablet ? 16 : 14,
                              color: Colors.green,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: isTablet ? 16 : 14,
                            color: isDarkMode
                                ? Colors.white.withValues(alpha: 0.6)
                                : AppTheme.lightTextSecondaryColor,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              user['phone'].isEmpty
                                  ? 'Not provided'
                                  : user['phone'],
                              style: GoogleFonts.albertSans(
                                fontSize: isTablet ? 14 : 12,
                                color: isDarkMode
                                    ? Colors.white.withValues(alpha: 0.7)
                                    : AppTheme.lightTextSecondaryColor,
                              ),
                            ),
                          ),
                          if (user['isPhoneVerified'])
                            Icon(
                              Icons.verified,
                              size: isTablet ? 16 : 14,
                              color: Colors.green,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Statistics
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
                border: isDarkMode
                    ? null
                    : Border.all(
                        color: AppTheme.lightBorderColor,
                        width: 1,
                      ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      'Total Orders',
                      '${user['totalOrders']}',
                      Icons.shopping_bag_outlined,
                      isTablet,
                      isDarkMode,
                    ),
                  ),
                  Container(
                    height: 40,
                    width: 1,
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.2)
                        : AppTheme.lightBorderColor,
                  ),
                  Expanded(
                    child: _buildStatItem(
                      'Member Since',
                      user['registrationDate'],
                      Icons.calendar_today_outlined,
                      isTablet,
                      isDarkMode,
                    ),
                  ),
                  Container(
                    height: 40,
                    width: 1,
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.2)
                        : AppTheme.lightBorderColor,
                  ),
                  Expanded(
                    child: _buildStatItem(
                      'Last Login',
                      user['lastLogin'].isEmpty ? 'Never' : user['lastLogin'],
                      Icons.login_outlined,
                      isTablet,
                      isDarkMode,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Actions
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: isTablet ? 48.0 : 44.0,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: (isDarkMode
                                  ? AppColors.yellowAccent
                                  : AppTheme.lightPrimaryColor)
                              .withValues(alpha: 0.4),
                          blurRadius: 12,
                          spreadRadius: 0,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: (isDarkMode
                                  ? AppColors.yellowAccent
                                  : AppTheme.lightPrimaryColor)
                              .withValues(alpha: 0.2),
                          blurRadius: 24,
                          spreadRadius: 0,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () => _viewUserDetails(user),
                      icon: Icon(Icons.visibility_outlined,
                          size: isTablet ? 18 : 16),
                      label: Text(
                        'View Details',
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 14 : 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDarkMode
                            ? AppColors.yellowAccent
                            : AppTheme.lightPrimaryColor,
                        foregroundColor:
                            isDarkMode ? Colors.black : Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  height: isTablet ? 48.0 : 44.0,
                  width: isTablet ? 100.0 : 80.0,
                  child: ElevatedButton(
                    onPressed: () => _toggleUserStatus(user),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: user['status'] == 'Blocked'
                          ? Colors.green
                          : Colors.red,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      user['status'] == 'Blocked' ? 'Unblock' : 'Block',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 12 : 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon,
      bool isTablet, bool isDarkMode) {
    return Column(
      children: [
        Icon(
          icon,
          size: isTablet ? 20 : 18,
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.7)
              : AppTheme.lightTextSecondaryColor,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.albertSans(
            fontSize: isTablet ? 10 : 8,
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.5)
                : AppTheme.lightTextSecondaryColor,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.albertSans(
            fontSize: isTablet ? 12 : 10,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Active':
        return Colors.green;
      case 'Blocked':
        return Colors.red;
      case 'New':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Future<void> _refreshUsers() async {
    await _loadUsers();
  }

  void _viewUserDetails(Map<String, dynamic> user) {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isDarkMode = themeService.isDarkMode;
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: isTablet ? 600 : screenSize.width * 0.9,
          height: screenSize.height * 0.8,
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDarkMode
                  ? AppColors.yellowAccent.withValues(alpha: 0.3)
                  : AppTheme.lightPrimaryColor.withValues(alpha: 0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header with avatar and basic info
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? AppColors.yellowAccent.withValues(alpha: 0.1)
                      : AppTheme.lightPrimaryColor.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDarkMode
                              ? AppColors.yellowAccent
                              : AppTheme.lightPrimaryColor,
                          width: 3,
                        ),
                        color: isDarkMode
                            ? AppColors.yellowAccent.withValues(alpha: 0.2)
                            : AppTheme.lightPrimaryColor.withValues(alpha: 0.2),
                      ),
                      child: ClipOval(
                        child: user['profileImageUrl'] != null &&
                                user['profileImageUrl'].isNotEmpty
                            ? Image.network(
                                user['profileImageUrl'],
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.person,
                                    size: 40,
                                    color: isDarkMode
                                        ? AppColors.yellowAccent
                                        : AppTheme.lightPrimaryColor,
                                  );
                                },
                              )
                            : Icon(
                                Icons.person,
                                size: 40,
                                color: isDarkMode
                                    ? AppColors.yellowAccent
                                    : AppTheme.lightPrimaryColor,
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Basic info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user['name'],
                            style: GoogleFonts.albertSans(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode
                                  ? Colors.white
                                  : AppTheme.lightTextPrimaryColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(user['status'])
                                      .withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  user['status'],
                                  style: GoogleFonts.albertSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _getStatusColor(user['status']),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (user['isActive'] == true)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: Colors.green,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Active',
                                        style: GoogleFonts.albertSans(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.shopping_bag_outlined,
                                color: isDarkMode
                                    ? Colors.white.withValues(alpha: 0.7)
                                    : AppTheme.lightTextSecondaryColor,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${user['totalOrders']} orders',
                                style: GoogleFonts.albertSans(
                                  fontSize: 12,
                                  color: isDarkMode
                                      ? Colors.white.withValues(alpha: 0.7)
                                      : AppTheme.lightTextSecondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Close button
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.close,
                          color: isDarkMode ? Colors.white : Colors.black,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Personal Information Section
                      _buildDetailSection(
                        'Personal Information',
                        [
                          _buildDetailRow(
                              'Full Name', user['name'], isDarkMode),
                          _buildDetailRow('Email', user['email'], isDarkMode),
                          _buildDetailRow(
                              'Phone',
                              user['phone'].isEmpty
                                  ? 'Not provided'
                                  : user['phone'],
                              isDarkMode),
                          _buildDetailRow(
                              'Gender',
                              user['gender'].isEmpty
                                  ? 'Not provided'
                                  : user['gender'],
                              isDarkMode),
                          _buildDetailRow(
                              'Date of Birth',
                              user['dateOfBirth'].isEmpty
                                  ? 'Not provided'
                                  : user['dateOfBirth'],
                              isDarkMode),
                          _buildDetailRow(
                              'Emergency Contact',
                              user['emergencyContact'].isEmpty
                                  ? 'Not provided'
                                  : user['emergencyContact'],
                              isDarkMode),
                        ],
                        isDarkMode,
                      ),

                      const SizedBox(height: 20),

                      // Address Information Section
                      _buildDetailSection(
                        'Address Information',
                        [
                          _buildDetailRow(
                              'Address',
                              user['address'].isEmpty
                                  ? 'Not provided'
                                  : user['address'],
                              isDarkMode),
                          _buildDetailRow(
                              'City',
                              user['city'].isEmpty
                                  ? 'Not provided'
                                  : user['city'],
                              isDarkMode),
                          _buildDetailRow(
                              'Country',
                              user['country'].isEmpty
                                  ? 'Not provided'
                                  : user['country'],
                              isDarkMode),
                        ],
                        isDarkMode,
                      ),

                      const SizedBox(height: 20),

                      // Account Status Section
                      _buildDetailSection(
                        'Account Status',
                        [
                          _buildVerificationRow('Email Verified',
                              user['isEmailVerified'], isDarkMode),
                          _buildVerificationRow('Phone Verified',
                              user['isPhoneVerified'], isDarkMode),
                          _buildVerificationRow('Items Verified',
                              user['itemsVerified'], isDarkMode),
                          _buildVerificationRow('Profile Completed',
                              user['profileCompleted'], isDarkMode),
                        ],
                        isDarkMode,
                      ),

                      const SizedBox(height: 20),

                      // Statistics Section
                      _buildDetailSection(
                        'Statistics & Activity',
                        [
                          _buildDetailRow('Total Orders',
                              user['totalOrders'].toString(), isDarkMode),
                          _buildDetailRow(
                              'Account Status', user['status'], isDarkMode),
                          _buildDetailRow(
                              'User Role', user['role'], isDarkMode),
                          _buildDetailRow('Registration Date',
                              user['registrationDate'], isDarkMode),
                          _buildDetailRow(
                              'Last Login',
                              user['lastLogin'].isEmpty
                                  ? 'Never'
                                  : user['lastLogin'],
                              isDarkMode),
                          _buildDetailRow(
                              'Profile Updated', user['updatedAt'], isDarkMode),
                        ],
                        isDarkMode,
                      ),

                      const SizedBox(height: 20),

                      // User Preferences Section
                      _buildDetailSection(
                        'User Preferences',
                        [
                          _buildDetailRow(
                              'Dark Mode',
                              user['preferences']?['darkMode'] == true
                                  ? 'Enabled'
                                  : 'Disabled',
                              isDarkMode),
                          _buildDetailRow(
                              'Notifications',
                              user['preferences']?['notifications'] != false
                                  ? 'Enabled'
                                  : 'Disabled',
                              isDarkMode),
                          _buildDetailRow(
                              'Location Access',
                              user['preferences']?['locationAccess'] == true
                                  ? 'Enabled'
                                  : 'Disabled',
                              isDarkMode),
                          _buildDetailRow(
                              'Language',
                              user['preferences']?['language'] ?? 'Default',
                              isDarkMode),
                        ],
                        isDarkMode,
                      ),
                    ],
                  ),
                ),
              ),

              // Action buttons
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    // Always show Activate and Block buttons
                    Expanded(
                      child: Container(
                        height: 48.0,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withValues(alpha: 0.4),
                              blurRadius: 12,
                              spreadRadius: 0,
                              offset: const Offset(0, 4),
                            ),
                            BoxShadow(
                              color: Colors.green.withValues(alpha: 0.2),
                              blurRadius: 24,
                              spreadRadius: 0,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _activateUserFromPopup(user);
                          },
                          icon: const Icon(Icons.check, size: 18),
                          label: Text(
                            'Activate',
                            style: GoogleFonts.albertSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _blockUserFromPopup(user);
                        },
                        icon: const Icon(Icons.block, size: 18),
                        label: Text(
                          'Block',
                          style: GoogleFonts.albertSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(
      String title, List<Widget> children, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.albertSans(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDarkMode
                  ? AppColors.yellowAccent
                  : AppTheme.lightPrimaryColor,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildVerificationRow(String label, bool isVerified, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: GoogleFonts.albertSans(
                fontWeight: FontWeight.w600,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.8)
                    : AppTheme.lightTextSecondaryColor,
              ),
            ),
          ),
          Icon(
            isVerified ? Icons.check_circle : Icons.cancel,
            color: isVerified ? Colors.green : Colors.red,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            isVerified ? 'Yes' : 'No',
            style: GoogleFonts.albertSans(
              fontWeight: FontWeight.w600,
              color: isVerified ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _activateUserFromPopup(Map<String, dynamic> user) async {
    try {
      await _firestore.collection('users').doc(user['id']).update({
        'status': 'Active',
        'isActive': true,
        'activatedAt': FieldValue.serverTimestamp(),
        'activatedBy': _auth.currentUser?.uid,
      });

      setState(() {
        user['status'] = 'Active';
        user['isActive'] = true;
        // Update the user in both lists
        final index = _allUsers.indexWhere((u) => u['id'] == user['id']);
        if (index != -1) {
          _allUsers[index]['status'] = 'Active';
          _allUsers[index]['isActive'] = true;
        }
      });
      _filterUsers();

      _showGlowingSnackBar(
        'User activated successfully',
        Colors.green,
      );
    } catch (e) {
      _showGlowingSnackBar(
        'Error activating user: $e',
        Colors.red,
      );
    }
  }

  Future<void> _blockUserFromPopup(Map<String, dynamic> user) async {
    try {
      await _firestore.collection('users').doc(user['id']).update({
        'status': 'Blocked',
        'isActive': false,
        'blockedAt': FieldValue.serverTimestamp(),
        'blockedBy': _auth.currentUser?.uid,
      });

      setState(() {
        user['status'] = 'Blocked';
        user['isActive'] = false;
        // Update the user in both lists
        final index = _allUsers.indexWhere((u) => u['id'] == user['id']);
        if (index != -1) {
          _allUsers[index]['status'] = 'Blocked';
          _allUsers[index]['isActive'] = false;
        }
      });
      _filterUsers();

      _showGlowingSnackBar(
        'User blocked successfully',
        Colors.orange,
      );
    } catch (e) {
      _showGlowingSnackBar(
        'Error blocking user: $e',
        Colors.red,
      );
    }
  }

  Widget _buildDetailRow(String label, String value, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: GoogleFonts.albertSans(
                fontWeight: FontWeight.w600,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.8)
                    : AppTheme.lightTextSecondaryColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.albertSans(
                color:
                    isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleUserStatus(Map<String, dynamic> user) {
    final newStatus = user['status'] == 'Blocked' ? 'Active' : 'Blocked';
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isDarkMode = themeService.isDarkMode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '${newStatus == 'Blocked' ? 'Block' : 'Unblock'} User',
          style: GoogleFonts.albertSans(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
          ),
        ),
        content: Text(
          'Are you sure you want to ${newStatus == 'Blocked' ? 'block' : 'unblock'} ${user['name']}?',
          style: GoogleFonts.albertSans(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.8)
                : AppTheme.lightTextSecondaryColor,
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
                    : AppTheme.lightTextSecondaryColor,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              // Update in local state immediately for UI responsiveness
              setState(() {
                user['status'] = newStatus;
              });
              _filterUsers();

              // Update in Firebase
              await _updateUserStatus(user['id'], newStatus);
            },
            child: Text(
              newStatus == 'Blocked' ? 'Block' : 'Unblock',
              style: GoogleFonts.albertSans(
                color: newStatus == 'Blocked' ? Colors.red : Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _bulkBlock() {
    if (_selectedUsers.isEmpty) return;

    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isDarkMode = themeService.isDarkMode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Block Users',
          style: GoogleFonts.albertSans(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
          ),
        ),
        content: Text(
          'Are you sure you want to block ${_selectedUsers.length} selected users?',
          style: GoogleFonts.albertSans(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.8)
                : AppTheme.lightTextSecondaryColor,
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
                    : AppTheme.lightTextSecondaryColor,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              await _bulkUpdateStatus(_selectedUsers.toList(), 'Blocked');

              setState(() {
                _selectedUsers.clear();
              });
            },
            child: Text(
              'Block',
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

  void _bulkUnblock() {
    if (_selectedUsers.isEmpty) return;

    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isDarkMode = themeService.isDarkMode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Unblock Users',
          style: GoogleFonts.albertSans(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
          ),
        ),
        content: Text(
          'Are you sure you want to unblock ${_selectedUsers.length} selected users?',
          style: GoogleFonts.albertSans(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.8)
                : AppTheme.lightTextSecondaryColor,
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
                    : AppTheme.lightTextSecondaryColor,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              await _bulkUpdateStatus(_selectedUsers.toList(), 'Active');

              setState(() {
                _selectedUsers.clear();
              });
            },
            child: Text(
              'Unblock',
              style: GoogleFonts.albertSans(
                color: Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _bulkDelete() {
    if (_selectedUsers.isEmpty) return;

    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isDarkMode = themeService.isDarkMode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Users',
          style: GoogleFonts.albertSans(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
          ),
        ),
        content: Text(
          'Are you sure you want to delete ${_selectedUsers.length} selected users? This action cannot be undone.',
          style: GoogleFonts.albertSans(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.8)
                : AppTheme.lightTextSecondaryColor,
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
                    : AppTheme.lightTextSecondaryColor,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              await _deleteUsers(_selectedUsers.toList());

              setState(() {
                _selectedUsers.clear();
              });
            },
            child: Text(
              'Delete',
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

  void _showUserFilters() {
    // Placeholder for filter functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Filter options coming soon',
          style: GoogleFonts.albertSans(),
        ),
        backgroundColor: const Color(0xFF1E88E5),
      ),
    );
  }
}
