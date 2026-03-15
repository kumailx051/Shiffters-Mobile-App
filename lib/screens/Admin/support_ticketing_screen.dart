import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shiffters/theme/app_colors.dart';
import 'package:shiffters/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shiffters/services/theme_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SupportTicketingScreen extends StatefulWidget {
  const SupportTicketingScreen({super.key});

  @override
  State<SupportTicketingScreen> createState() => _SupportTicketingScreenState();
}

class _SupportTicketingScreenState extends State<SupportTicketingScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late AnimationController _animationController;
  late AnimationController _cardAnimationController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';
  final List<String> _filterOptions = [
    'All',
    'Open',
    'In Progress',
    'Resolved',
    'Closed'
  ];

  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _allTickets = [];
  List<Map<String, dynamic>> _filteredTickets = [];
  Set<String> _selectedTickets = {};
  bool _isLoading = false;
  bool _showStats = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadTickets();
    _startAnimations();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _cardAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

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

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cardAnimationController,
      curve: Curves.elasticOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      _animationController.forward();
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        _cardAnimationController.forward();
      }
    }
  }

  // Load tickets from Firebase
  Future<void> _loadTickets() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final ticketsSnapshot = await _firestore
          .collection('tickets')
          .orderBy('createdAt', descending: true)
          .get();

      if (mounted) {
        List<Map<String, dynamic>> tickets = [];

        for (var doc in ticketsSnapshot.docs) {
          final data = doc.data();

          // Fetch user details from users collection using uid
          String userName = 'Unknown User';
          String userEmail = '';
          String userPhone = '';

          if (data['uid'] != null && data['uid'].isNotEmpty) {
            try {
              final userDoc =
                  await _firestore.collection('users').doc(data['uid']).get();

              if (userDoc.exists) {
                final userData = userDoc.data()!;
                userName = userData['name'] ?? 'Unknown User';
                userEmail = userData['email'] ?? '';
                userPhone = userData['phoneNumber'] ?? userData['phone'] ?? '';
              }
            } catch (e) {
              debugPrint('Error fetching user details: $e');
            }
          }

          tickets.add({
            'id': doc.id,
            'ticketId': data['ticketId'] ?? doc.id,
            'subject': data['subject'] ?? 'No Subject',
            'message': data['message'] ?? '',
            'user': userName,
            'userEmail': userEmail,
            'userPhone': userPhone,
            'userType': data['role'] == 'driver' ? 'Driver' : 'Customer',
            'priority': data['priority'] ?? 'Medium',
            'status': data['status'] ?? 'Open',
            'category': data['category'] ?? 'General',
            'createdAt': _formatDate(data['createdAt']),
            'updatedAt': _formatDate(data['updatedAt']),
            'uid': data['uid'] ?? '',
            'role': data['role'] ?? 'user',
          });
        }

        setState(() {
          _allTickets = tickets;
          _filterTickets();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading tickets: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showGlowingSnackBar(
          'Error loading tickets: $e',
          Colors.red,
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

  // Update ticket status in Firebase
  Future<void> _updateTicketStatusInFirebase(
      String ticketId, String newStatus) async {
    try {
      await _firestore.collection('tickets').doc(ticketId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': _auth.currentUser?.uid,
      });

      if (mounted) {
        _showGlowingSnackBar(
          'Ticket status updated successfully!',
          Colors.green,
        );
        _loadTickets(); // Refresh the list
      }
    } catch (e) {
      debugPrint('Error updating ticket status: $e');
      if (mounted) {
        _showGlowingSnackBar(
          'Error updating ticket status: $e',
          Colors.red,
        );
      }
    }
  }

  // Bulk update ticket statuses in Firebase
  Future<void> _bulkUpdateStatusInFirebase(
      List<String> ticketIds, String newStatus) async {
    try {
      final batch = _firestore.batch();

      for (String ticketId in ticketIds) {
        final ticketRef = _firestore.collection('tickets').doc(ticketId);
        batch.update(ticketRef, {
          'status': newStatus,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': _auth.currentUser?.uid,
        });
      }

      await batch.commit();

      if (mounted) {
        _showGlowingSnackBar(
          'Tickets updated successfully!',
          Colors.green,
        );
        setState(() {
          _selectedTickets.clear();
        });
        _loadTickets(); // Refresh the list
      }
    } catch (e) {
      debugPrint('Error bulk updating tickets: $e');
      if (mounted) {
        _showGlowingSnackBar(
          'Error updating tickets: $e',
          Colors.red,
        );
      }
    }
  }

  void _filterTickets() {
    setState(() {
      _filteredTickets = _allTickets.where((ticket) {
        final matchesFilter =
            _selectedFilter == 'All' || ticket['status'] == _selectedFilter;
        final matchesSearch = _searchController.text.isEmpty ||
            ticket['ticketId']
                .toLowerCase()
                .contains(_searchController.text.toLowerCase()) ||
            ticket['subject']
                .toLowerCase()
                .contains(_searchController.text.toLowerCase()) ||
            ticket['user']
                .toLowerCase()
                .contains(_searchController.text.toLowerCase()) ||
            ticket['category']
                .toLowerCase()
                .contains(_searchController.text.toLowerCase()) ||
            ticket['message']
                .toLowerCase()
                .contains(_searchController.text.toLowerCase());
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
    _pulseController.dispose();
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
          backgroundColor: isDarkMode
              ? const Color(0xFF1E1E2C)
              : AppTheme.lightBackgroundColor,
          body: Column(
            children: [
              // Header
              _buildProfessionalHeader(isTablet, isDarkMode),

              // Content
              Expanded(
                child: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      // Hero Section with Stats
                      _buildHeroSection(isTablet, isDarkMode),

                      // Search and filters
                      _buildSearchAndFilters(isTablet, isDarkMode),

                      // Bulk actions
                      if (_selectedTickets.isNotEmpty)
                        _buildBulkActions(isTablet, isDarkMode),

                      // Content
                      Expanded(
                        child: _isLoading
                            ? _buildLoadingIndicator(isDarkMode)
                            : _buildTicketsList(isTablet, isDarkMode),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton: _buildFloatingActionButton(isDarkMode),
        );
      },
    );
  }

  Widget _buildProfessionalHeader(bool isTablet, bool isDarkMode) {
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
          child: FadeTransition(
            opacity: _fadeAnimation,
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
                          'Support Center',
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 28 : 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Customer support tickets',
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
                // Stats toggle button
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _showStats = !_showStats;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _showStats ? Icons.visibility_off : Icons.visibility,
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

  Widget _buildHeroSection(bool isTablet, bool isDarkMode) {
    if (!_showStats) return const SizedBox.shrink();

    final openTickets = _allTickets.where((t) => t['status'] == 'Open').length;
    final inProgressTickets =
        _allTickets.where((t) => t['status'] == 'In Progress').length;
    final resolvedTickets =
        _allTickets.where((t) => t['status'] == 'Resolved').length;
    final highPriorityTickets =
        _allTickets.where((t) => t['priority'] == 'High').length;

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: isTablet ? 32 : 20,
          vertical: isTablet ? 20 : 16,
        ),
        child: Column(
          children: [
            // Main hero card
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isTablet ? 28 : 24),
              decoration: BoxDecoration(
                gradient: isDarkMode
                    ? LinearGradient(
                        colors: [
                          AppColors.yellowAccent.withValues(alpha: 0.2),
                          AppColors.yellowAccent.withValues(alpha: 0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : LinearGradient(
                        colors: [
                          AppTheme.lightPrimaryColor,
                          AppTheme.lightPrimaryColor.withValues(alpha: 0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                borderRadius: BorderRadius.circular(20),
                border: isDarkMode
                    ? Border.all(
                        color: AppColors.yellowAccent.withValues(alpha: 0.3),
                        width: 1,
                      )
                    : null,
                boxShadow: isDarkMode
                    ? [
                        BoxShadow(
                          color: AppColors.yellowAccent.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color:
                              AppTheme.lightPrimaryColor.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
              ),
              child: Row(
                children: [
                  // Icon with animation
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      width: isTablet ? 80 : 70,
                      height: isTablet ? 80 : 70,
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.support_agent_rounded,
                        color: isDarkMode ? Colors.white : Colors.white,
                        size: isTablet ? 40 : 35,
                      ),
                    ),
                  ),

                  const SizedBox(width: 20),

                  // Text content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Support Dashboard',
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 22 : 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_filteredTickets.length} tickets • ${openTickets} pending',
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 16 : 14,
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Real-time updates',
                            style: GoogleFonts.albertSans(
                              fontSize: isTablet ? 12 : 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Stats cards row
            Row(
              children: [
                Expanded(
                  child: _buildAnimatedStatsCard(
                    'Open',
                    '$openTickets',
                    Icons.support_agent,
                    Colors.red,
                    isTablet,
                    isDarkMode,
                    0,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildAnimatedStatsCard(
                    'In Progress',
                    '$inProgressTickets',
                    Icons.work_outline,
                    Colors.orange,
                    isTablet,
                    isDarkMode,
                    100,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildAnimatedStatsCard(
                    'Resolved',
                    '$resolvedTickets',
                    Icons.check_circle_outline,
                    Colors.green,
                    isTablet,
                    isDarkMode,
                    200,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildAnimatedStatsCard(
                    'High Priority',
                    '$highPriorityTickets',
                    Icons.priority_high,
                    Colors.purple,
                    isTablet,
                    isDarkMode,
                    300,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedStatsCard(String title, String value, IconData icon,
      Color color, bool isTablet, bool isDarkMode, int delay) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 800 + delay),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.elasticOut,
      builder: (context, animationValue, child) {
        return Transform.scale(
          scale: animationValue,
          child: Container(
            padding: EdgeInsets.all(isTablet ? 16 : 12),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.1)
                  : AppTheme.lightCardColor,
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
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        color: color,
                        size: isTablet ? 20 : 18,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(
                        Icons.trending_up,
                        color: Colors.green,
                        size: isTablet ? 12 : 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  value,
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 24 : 20,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode
                        ? Colors.white
                        : AppTheme.lightTextPrimaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 12 : 10,
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.7)
                        : AppTheme.lightTextSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
              vertical: isTablet ? 8 : 4,
            ),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.1)
                  : AppTheme.lightCardColor,
              borderRadius: BorderRadius.circular(isDarkMode ? 25 : 16),
              border: isDarkMode
                  ? null
                  : Border.all(
                      color: AppTheme.lightPrimaryColor,
                      width: 1.5,
                    ),
              boxShadow: isDarkMode
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: AppTheme.lightShadowMedium,
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => _filterTickets(),
              style: isDarkMode
                  ? GoogleFonts.albertSans(
                      fontSize: isTablet ? 16 : 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    )
                  : GoogleFonts.albertSans(
                      fontSize: isTablet ? 16 : 14,
                      color: AppTheme.lightTextPrimaryColor,
                      fontWeight: FontWeight.w500,
                    ),
              decoration: InputDecoration(
                hintText: isDarkMode
                    ? 'Search tickets...'
                    : 'Search tickets by ID, title, user, or description...',
                hintStyle: isDarkMode
                    ? GoogleFonts.albertSans(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w400,
                      )
                    : GoogleFonts.albertSans(
                        color: AppTheme.lightTextLightColor,
                        fontWeight: FontWeight.w400,
                      ),
                prefixIcon: isDarkMode
                    ? Icon(
                        Icons.search,
                        color: Colors.white.withValues(alpha: 0.7),
                        size: isTablet ? 24 : 20,
                      )
                    : Container(
                        margin: const EdgeInsets.all(12),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color:
                              AppTheme.lightPrimaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.search_rounded,
                          color: AppTheme.lightPrimaryColor,
                          size: isTablet ? 20 : 18,
                        ),
                      ),
                filled: true,
                fillColor: isDarkMode ? Colors.transparent : Colors.transparent,
                border: isDarkMode
                    ? OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      )
                    : InputBorder.none,
                enabledBorder: isDarkMode
                    ? OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      )
                    : InputBorder.none,
                focusedBorder: isDarkMode
                    ? OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide(
                          color: AppColors.yellowAccent,
                          width: 2,
                        ),
                      )
                    : InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 20 : 16,
                  vertical: isTablet ? 20 : 18,
                ),
              ),
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
              physics: const BouncingScrollPhysics(),
              itemCount: _filterOptions.length,
              itemBuilder: (context, index) {
                final option = _filterOptions[index];
                final isSelected = _selectedFilter == option;

                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _selectedFilter = option;
                        _filterTickets();
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 24 : 20,
                        vertical: isTablet ? 12 : 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDarkMode
                                ? AppColors.yellowAccent
                                : AppTheme.lightPrimaryColor)
                            : isDarkMode
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(50),
                        border: isSelected
                            ? null
                            : Border.all(
                                color: isDarkMode
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : Colors.grey.withValues(alpha: 0.3),
                                width: 1,
                              ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: isDarkMode
                                      ? AppColors.yellowAccent
                                          .withValues(alpha: 0.4)
                                      : AppTheme.lightPrimaryColor
                                          .withValues(alpha: 0.4),
                                  blurRadius: 15,
                                  offset: const Offset(0, 6),
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        option,
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 14 : 12,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? (isDarkMode ? Colors.black : Colors.white)
                              : isDarkMode
                                  ? Colors.white.withValues(alpha: 0.7)
                                  : Colors.grey.shade600,
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
              ? AppColors.yellowAccent.withValues(alpha: 0.1)
              : AppTheme.lightPrimaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDarkMode
                ? AppColors.yellowAccent.withValues(alpha: 0.3)
                : AppTheme.lightPrimaryColor.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDarkMode
                  ? AppColors.yellowAccent.withValues(alpha: 0.2)
                  : AppTheme.lightPrimaryColor.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              Icons.checklist,
              color: isDarkMode
                  ? AppColors.yellowAccent
                  : AppTheme.lightPrimaryColor,
              size: isTablet ? 24 : 20,
            ),
            const SizedBox(width: 12),
            Text(
              '${_selectedTickets.length} selected',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 16 : 14,
                fontWeight: FontWeight.w600,
                color:
                    isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
              ),
            ),
            const Spacer(),
            _buildActionButton(
              'Update Status',
              Icons.update,
              Colors.blue,
              _bulkUpdateStatus,
              isTablet,
            ),
            const SizedBox(width: 8),
            _buildActionButton(
              'Close',
              Icons.close,
              Colors.red,
              _bulkClose,
              isTablet,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String text, IconData icon, Color color,
      VoidCallback onPressed, bool isTablet) {
    return Container(
      height: isTablet ? 40 : 36,
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
          text,
          style: GoogleFonts.albertSans(
            fontSize: isTablet ? 14 : 12,
            color: Colors.white,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 16 : 12,
            vertical: 0,
          ),
        ),
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated loading icon
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isDarkMode
                    ? AppColors.yellowAccent.withValues(alpha: 0.2)
                    : AppTheme.lightPrimaryColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.support_agent,
                color: isDarkMode
                    ? AppColors.yellowAccent
                    : AppTheme.lightPrimaryColor,
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: 24),
          CircularProgressIndicator(
            color: isDarkMode
                ? AppColors.yellowAccent
                : AppTheme.lightPrimaryColor,
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading support tickets...',
            style: GoogleFonts.albertSans(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please wait while we fetch the latest data',
            style: GoogleFonts.albertSans(
              fontSize: 14,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.7)
                  : AppTheme.lightTextSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketsList(bool isTablet, bool isDarkMode) {
    if (_filteredTickets.isEmpty) {
      return _buildEmptyState(isDarkMode, isTablet);
    }

    return SlideTransition(
      position: _slideAnimation,
      child: RefreshIndicator(
        onRefresh: _refreshTickets,
        color: isDarkMode ? AppColors.yellowAccent : AppTheme.lightPrimaryColor,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 32 : 20,
            vertical: isTablet ? 16 : 12,
          ),
          itemCount: _filteredTickets.length,
          itemBuilder: (context, index) {
            final ticket = _filteredTickets[index];
            return TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 300 + (index * 100)),
              tween: Tween(begin: 0.0, end: 1.0),
              curve: Curves.easeOutCubic,
              builder: (context, animationValue, child) {
                return Transform.translate(
                  offset: Offset(0, 50 * (1 - animationValue)),
                  child: Opacity(
                    opacity: animationValue,
                    child:
                        _buildEnhancedTicketCard(ticket, isTablet, isDarkMode),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode, bool isTablet) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated empty state icon
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: isTablet ? 120 : 100,
              height: isTablet ? 120 : 100,
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.1)
                    : AppTheme.lightPrimaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(
                Icons.support_agent_outlined,
                size: isTablet ? 60 : 50,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.5)
                    : AppTheme.lightTextLightColor,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No tickets found',
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 24 : 20,
              fontWeight: FontWeight.bold,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.8)
                  : AppTheme.lightTextPrimaryColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Try adjusting your search or filter criteria\nto find the tickets you\'re looking for',
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 16 : 14,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.6)
                  : AppTheme.lightTextSecondaryColor,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                _selectedFilter = 'All';
                _searchController.clear();
                _filterTickets();
              });
            },
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 24 : 20,
                vertical: isTablet ? 16 : 14,
              ),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? AppColors.yellowAccent
                    : AppTheme.lightPrimaryColor,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: isDarkMode
                        ? AppColors.yellowAccent.withValues(alpha: 0.4)
                        : AppTheme.lightPrimaryColor.withValues(alpha: 0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.refresh,
                    color: isDarkMode ? Colors.black : Colors.white,
                    size: isTablet ? 20 : 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Clear Filters',
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 16 : 14,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.black : Colors.white,
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

  Widget _buildEnhancedTicketCard(
      Map<String, dynamic> ticket, bool isTablet, bool isDarkMode) {
    final isSelected = _selectedTickets.contains(ticket['id']);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
                  : AppTheme.lightPrimaryColor),
          width: isSelected ? 2 : 1.5,
        ),
        boxShadow: isDarkMode
            ? isSelected
                ? [
                    BoxShadow(
                      color: AppColors.yellowAccent.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null
            : [
                BoxShadow(
                  color: AppTheme.lightShadowMedium,
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Priority indicator bar
            Container(
              height: 4,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _getPriorityColor(ticket['priority']),
                    _getPriorityColor(ticket['priority'])
                        .withValues(alpha: 0.6),
                  ],
                ),
              ),
            ),

            // Card content
            Padding(
              padding: EdgeInsets.all(isTablet ? 20 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    children: [
                      // Checkbox
                      Transform.scale(
                        scale: isTablet ? 1.2 : 1.0,
                        child: Checkbox(
                          value: isSelected,
                          onChanged: (bool? value) {
                            HapticFeedback.lightImpact();
                            setState(() {
                              if (value == true) {
                                _selectedTickets.add(ticket['id']);
                              } else {
                                _selectedTickets.remove(ticket['id']);
                              }
                            });
                          },
                          activeColor: isDarkMode
                              ? AppColors.yellowAccent
                              : AppTheme.lightPrimaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Ticket ID and Subject
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDarkMode
                                        ? AppColors.yellowAccent
                                            .withValues(alpha: 0.2)
                                        : AppTheme.lightPrimaryColor
                                            .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '#${ticket['ticketId']?.toString().substring(0, 8) ?? 'No ID'}',
                                    style: GoogleFonts.albertSans(
                                      fontSize: isTablet ? 12 : 10,
                                      fontWeight: FontWeight.bold,
                                      color: isDarkMode
                                          ? AppColors.yellowAccent
                                          : AppTheme.lightPrimaryColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getUserTypeColor(ticket['userType'])
                                        .withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    ticket['userType'] ?? 'Customer',
                                    style: GoogleFonts.albertSans(
                                      fontSize: isTablet ? 10 : 8,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          _getUserTypeColor(ticket['userType']),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              ticket['subject'] ?? 'No Subject',
                              style: GoogleFonts.albertSans(
                                fontSize: isTablet ? 16 : 14,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode
                                    ? Colors.white
                                    : AppTheme.lightTextPrimaryColor,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // Status and Priority badges
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getStatusColor(ticket['status'])
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _getStatusColor(ticket['status'])
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            child: Text(
                              ticket['status'] ?? 'Open',
                              style: GoogleFonts.albertSans(
                                fontSize: isTablet ? 12 : 10,
                                fontWeight: FontWeight.w700,
                                color: _getStatusColor(ticket['status']),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getPriorityColor(ticket['priority'])
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getPriorityIcon(ticket['priority']),
                                  size: isTablet ? 12 : 10,
                                  color: _getPriorityColor(ticket['priority']),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  ticket['priority'] ?? 'Medium',
                                  style: GoogleFonts.albertSans(
                                    fontSize: isTablet ? 10 : 8,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        _getPriorityColor(ticket['priority']),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // User info section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: isDarkMode
                          ? null
                          : Border.all(
                              color: AppTheme.lightPrimaryColor
                                  .withValues(alpha: 0.2),
                            ),
                    ),
                    child: Row(
                      children: [
                        // User avatar
                        Container(
                          width: isTablet ? 50 : 40,
                          height: isTablet ? 50 : 40,
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? AppColors.yellowAccent.withValues(alpha: 0.2)
                                : AppTheme.lightPrimaryColor
                                    .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.person,
                            color: isDarkMode
                                ? AppColors.yellowAccent
                                : AppTheme.lightPrimaryColor,
                            size: isTablet ? 24 : 20,
                          ),
                        ),

                        const SizedBox(width: 12),

                        // User details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ticket['user'] ?? 'Unknown User',
                                style: GoogleFonts.albertSans(
                                  fontSize: isTablet ? 16 : 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode
                                      ? Colors.white
                                      : AppTheme.lightTextPrimaryColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${ticket['category'] ?? 'General'} • ${ticket['createdAt']?.toString().split(' ').first ?? 'Unknown date'}',
                                style: GoogleFonts.albertSans(
                                  fontSize: isTablet ? 12 : 10,
                                  color: isDarkMode
                                      ? Colors.white.withValues(alpha: 0.7)
                                      : AppTheme.lightTextSecondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Time indicator
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.white.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.access_time,
                                size: isTablet ? 12 : 10,
                                color: isDarkMode
                                    ? Colors.white.withValues(alpha: 0.7)
                                    : AppTheme.lightTextSecondaryColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _getTimeAgo(ticket['createdAt']),
                                style: GoogleFonts.albertSans(
                                  fontSize: isTablet ? 10 : 8,
                                  color: isDarkMode
                                      ? Colors.white.withValues(alpha: 0.7)
                                      : AppTheme.lightTextSecondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Message preview
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.blue.withValues(alpha: 0.1)
                          : Colors.blue.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDarkMode
                            ? Colors.blue.withValues(alpha: 0.3)
                            : Colors.blue.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.message_outlined,
                              size: isTablet ? 16 : 14,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Message Preview',
                              style: GoogleFonts.albertSans(
                                fontSize: isTablet ? 12 : 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          ticket['message'] ?? 'No message content',
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 14 : 12,
                            color: isDarkMode
                                ? Colors.white.withValues(alpha: 0.8)
                                : AppTheme.lightTextSecondaryColor,
                            height: 1.4,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Container(
                          height: isTablet ? 48 : 44,
                          child: ElevatedButton.icon(
                            onPressed: () => _viewTicketDetails(ticket),
                            icon: Icon(
                              Icons.visibility_outlined,
                              size: isTablet ? 18 : 16,
                              color: isDarkMode ? Colors.black : Colors.white,
                            ),
                            label: Text(
                              'View Details',
                              style: GoogleFonts.albertSans(
                                fontSize: isTablet ? 14 : 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                                color: isDarkMode ? Colors.black : Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDarkMode
                                  ? AppColors.yellowAccent
                                  : AppTheme.lightPrimaryColor,
                              foregroundColor:
                                  isDarkMode ? Colors.black : Colors.white,
                              elevation: 0,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 0),
                            ),
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: isDarkMode
                                    ? AppColors.yellowAccent
                                        .withValues(alpha: 0.3)
                                    : AppTheme.lightPrimaryColor
                                        .withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                              BoxShadow(
                                color: isDarkMode
                                    ? AppColors.yellowAccent
                                        .withValues(alpha: 0.1)
                                    : AppTheme.lightPrimaryColor
                                        .withValues(alpha: 0.1),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          height: isTablet ? 48 : 44,
                          child: ElevatedButton.icon(
                            onPressed: () => _updateTicketStatus(ticket),
                            icon: Icon(
                              Icons.update,
                              size: isTablet ? 16 : 14,
                              color: _getStatusColor(ticket['status']),
                            ),
                            label: Text(
                              'Update',
                              style: GoogleFonts.albertSans(
                                fontSize: isTablet ? 12 : 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                                color: _getStatusColor(ticket['status']),
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _getStatusColor(ticket['status'])
                                  .withValues(alpha: 0.1),
                              foregroundColor:
                                  _getStatusColor(ticket['status']),
                              elevation: 0,
                              shadowColor: Colors.transparent,
                              side: BorderSide(
                                color: _getStatusColor(ticket['status'])
                                    .withValues(alpha: 0.5),
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 0),
                            ),
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: _getStatusColor(ticket['status'])
                                    .withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                              BoxShadow(
                                color: _getStatusColor(ticket['status'])
                                    .withValues(alpha: 0.1),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton(bool isDarkMode) {
    return ScaleTransition(
      scale: _pulseAnimation,
      child: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.lightImpact();
          _refreshTickets();
        },
        backgroundColor:
            isDarkMode ? AppColors.yellowAccent : AppTheme.lightPrimaryColor,
        foregroundColor: isDarkMode ? Colors.black : Colors.white,
        elevation: 8,
        icon: const Icon(Icons.refresh),
        label: Text(
          'Refresh',
          style: GoogleFonts.albertSans(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'Open':
        return Colors.red;
      case 'In Progress':
        return Colors.orange;
      case 'Resolved':
        return Colors.green;
      case 'Closed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Color _getPriorityColor(String? priority) {
    switch (priority) {
      case 'High':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      case 'Low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _getUserTypeColor(String? userType) {
    switch (userType) {
      case 'Driver':
        return Colors.purple;
      case 'Customer':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getPriorityIcon(String? priority) {
    switch (priority) {
      case 'High':
        return Icons.priority_high;
      case 'Medium':
        return Icons.remove;
      case 'Low':
        return Icons.keyboard_arrow_down;
      default:
        return Icons.remove;
    }
  }

  String _getTimeAgo(String? dateString) {
    if (dateString == null) return 'Unknown';

    try {
      // Simple time ago calculation - you can enhance this
      return 'Today';
    } catch (e) {
      return 'Unknown';
    }
  }

  Future<void> _refreshTickets() async {
    await _loadTickets();
  }

  void _viewTicketDetails(Map<String, dynamic> ticket) {
    final isDarkMode =
        Provider.of<ThemeService>(context, listen: false).isDarkMode;
    final TextEditingController responseController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
            borderRadius: BorderRadius.circular(20),
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
              // Header
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
                    Icon(
                      Icons.support_agent,
                      color: isDarkMode
                          ? AppColors.yellowAccent
                          : AppTheme.lightPrimaryColor,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ticket Details',
                            style: GoogleFonts.albertSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: isDarkMode
                                  ? Colors.white
                                  : AppTheme.lightTextPrimaryColor,
                            ),
                          ),
                          Text(
                            'ID: ${ticket['ticketId'] ?? 'No ID'}',
                            style: GoogleFonts.albertSans(
                              fontSize: 14,
                              color: isDarkMode
                                  ? Colors.white.withValues(alpha: 0.7)
                                  : AppTheme.lightTextSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close,
                        color: isDarkMode
                            ? Colors.white
                            : AppTheme.lightTextPrimaryColor,
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
                      // User Info Card
                      _buildInfoCard(
                        'User Information',
                        Icons.person,
                        [
                          _buildDetailRow('Name:',
                              ticket['user'] ?? 'Unknown User', isDarkMode),
                          _buildDetailRow('Type:',
                              ticket['userType'] ?? 'Customer', isDarkMode),
                          _buildDetailRow('Email:',
                              ticket['userEmail'] ?? 'No email', isDarkMode),
                          _buildDetailRow('Phone:',
                              ticket['userPhone'] ?? 'No phone', isDarkMode),
                        ],
                        isDarkMode,
                      ),

                      const SizedBox(height: 16),

                      // Ticket Info Card
                      _buildInfoCard(
                        'Ticket Information',
                        Icons.confirmation_number,
                        [
                          _buildDetailRow('Subject:',
                              ticket['subject'] ?? 'No Subject', isDarkMode),
                          _buildDetailRow('Category:',
                              ticket['category'] ?? 'General', isDarkMode),
                          _buildDetailRowWithColor(
                              'Priority:',
                              ticket['priority'] ?? 'Medium',
                              _getPriorityColor(ticket['priority']),
                              isDarkMode),
                          _buildDetailRowWithColor(
                              'Status:',
                              ticket['status'] ?? 'Open',
                              _getStatusColor(ticket['status']),
                              isDarkMode),
                          _buildDetailRow(
                              'Created:',
                              ticket['createdAt'] ?? 'Not available',
                              isDarkMode),
                          _buildDetailRow(
                              'Updated:',
                              ticket['updatedAt'] ?? 'Not available',
                              isDarkMode),
                        ],
                        isDarkMode,
                      ),

                      const SizedBox(height: 16),

                      // Original Message Card
                      _buildMessageCard(
                        'Original Message',
                        ticket['message'] ?? 'No message',
                        Icons.message,
                        isDarkMode,
                      ),

                      const SizedBox(height: 16),

                      // Combined Conversation History (Admin and Driver responses)
                      _buildConversationHistory(ticket, isDarkMode),

                      const SizedBox(height: 16),

                      // Reply Section - only show if ticket is not resolved
                      if (ticket['status'] != 'Resolved')
                        _buildReplySection(
                            responseController, ticket, isDarkMode),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.albertSans(
                fontWeight: FontWeight.w600,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.7)
                    : AppTheme.lightTextSecondaryColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'Not available',
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

  Widget _buildDetailRowWithColor(
      String label, String? value, Color valueColor, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.albertSans(
                fontWeight: FontWeight.w600,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.7)
                    : AppTheme.lightTextSecondaryColor,
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: valueColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: valueColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                value ?? 'Not available',
                style: GoogleFonts.albertSans(
                  color: valueColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
      String title, IconData icon, List<Widget> children, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: isDarkMode
                    ? AppColors.yellowAccent
                    : AppTheme.lightPrimaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.albertSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isDarkMode
                      ? Colors.white
                      : AppTheme.lightTextPrimaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildMessageCard(
      String title, String message, IconData icon, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.blue.withValues(alpha: 0.1)
            : Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode
              ? Colors.blue.withValues(alpha: 0.3)
              : Colors.blue.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: Colors.blue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.albertSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isDarkMode
                      ? Colors.white
                      : AppTheme.lightTextPrimaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              message,
              style: GoogleFonts.albertSans(
                color:
                    isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplySection(TextEditingController controller,
      Map<String, dynamic> ticket, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? AppColors.yellowAccent.withValues(alpha: 0.1)
            : AppTheme.lightPrimaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode
              ? AppColors.yellowAccent.withValues(alpha: 0.3)
              : AppTheme.lightPrimaryColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.reply,
                color: isDarkMode
                    ? AppColors.yellowAccent
                    : AppTheme.lightPrimaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Send Reply',
                style: GoogleFonts.albertSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isDarkMode
                      ? Colors.white
                      : AppTheme.lightTextPrimaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Type your response here...',
              hintStyle: GoogleFonts.albertSans(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.5)
                    : AppTheme.lightTextSecondaryColor,
              ),
              filled: true,
              fillColor: isDarkMode
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white.withValues(alpha: 0.7),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
            style: GoogleFonts.albertSans(
              color: isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Spacer(),
              Container(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () =>
                      _sendAdminResponse(ticket, controller.text, controller),
                  icon: const Icon(Icons.send, size: 18),
                  label: Text(
                    'Send Reply',
                    style: GoogleFonts.albertSans(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDarkMode
                        ? AppColors.yellowAccent
                        : AppTheme.lightPrimaryColor,
                    foregroundColor: isDarkMode ? Colors.black : Colors.white,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 0,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: isDarkMode
                          ? AppColors.yellowAccent.withValues(alpha: 0.3)
                          : AppTheme.lightPrimaryColor.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                    BoxShadow(
                      color: isDarkMode
                          ? AppColors.yellowAccent.withValues(alpha: 0.1)
                          : AppTheme.lightPrimaryColor.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _updateTicketStatus(Map<String, dynamic> ticket) {
    final isDarkMode =
        Provider.of<ThemeService>(context, listen: false).isDarkMode;

    // Available status options (excluding "All" and "Closed")
    final availableStatuses = ['Open', 'In Progress', 'Resolved'];

    showDialog(
      context: context,
      builder: (context) {
        String selectedStatus = ticket['status'] ?? 'Open';
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor:
                isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? AppColors.yellowAccent.withValues(alpha: 0.2)
                        : AppTheme.lightPrimaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.edit_rounded,
                    color: isDarkMode
                        ? AppColors.yellowAccent
                        : AppTheme.lightPrimaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Update Status',
                  style: GoogleFonts.albertSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: isDarkMode
                        ? Colors.white
                        : AppTheme.lightTextPrimaryColor,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select new status for this ticket:',
                  style: GoogleFonts.albertSans(
                    fontSize: 14,
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.8)
                        : AppTheme.lightTextSecondaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.2)
                          : Colors.grey.withValues(alpha: 0.3),
                    ),
                  ),
                  child: DropdownButton<String>(
                    value: selectedStatus,
                    isExpanded: true,
                    underline: const SizedBox(),
                    dropdownColor:
                        isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
                    items: availableStatuses.map((status) {
                      Color statusColor = _getStatusColor(status);
                      return DropdownMenuItem(
                        value: status,
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              status,
                              style: GoogleFonts.albertSans(
                                color: isDarkMode
                                    ? Colors.white
                                    : AppTheme.lightTextPrimaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          selectedStatus = value;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.albertSans(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.7)
                        : AppTheme.lightTextSecondaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _updateTicketStatusInFirebase(
                        ticket['id'] ?? '', selectedStatus);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDarkMode
                        ? AppColors.yellowAccent
                        : AppTheme.lightPrimaryColor,
                    foregroundColor: isDarkMode ? Colors.black : Colors.white,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_rounded, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Update',
                        style: GoogleFonts.albertSans(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: isDarkMode
                          ? AppColors.yellowAccent.withValues(alpha: 0.3)
                          : AppTheme.lightPrimaryColor.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                    BoxShadow(
                      color: isDarkMode
                          ? AppColors.yellowAccent.withValues(alpha: 0.1)
                          : AppTheme.lightPrimaryColor.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _bulkUpdateStatus() {
    if (_selectedTickets.isEmpty) return;

    final isDarkMode =
        Provider.of<ThemeService>(context, listen: false).isDarkMode;

    // Available status options (excluding "All" and "Closed")
    final availableStatuses = ['Open', 'In Progress', 'Resolved'];

    showDialog(
      context: context,
      builder: (context) {
        String selectedStatus = 'In Progress';
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor:
                isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              'Bulk Update Status',
              style: GoogleFonts.albertSans(
                fontWeight: FontWeight.bold,
                color:
                    isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Update ${_selectedTickets.length} tickets to:',
                  style: GoogleFonts.albertSans(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.8)
                        : AppTheme.lightTextSecondaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButton<String>(
                  value: selectedStatus,
                  dropdownColor:
                      isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
                  items: availableStatuses.map((status) {
                    return DropdownMenuItem(
                      value: status,
                      child: Text(
                        status,
                        style: GoogleFonts.albertSans(
                          color: isDarkMode
                              ? Colors.white
                              : AppTheme.lightTextPrimaryColor,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() {
                        selectedStatus = value;
                      });
                    }
                  },
                ),
              ],
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
                onPressed: () {
                  Navigator.pop(context);
                  _bulkUpdateStatusInFirebase(
                      _selectedTickets.toList(), selectedStatus);
                },
                child: Text(
                  'Update',
                  style: GoogleFonts.albertSans(
                    color: isDarkMode
                        ? AppColors.yellowAccent
                        : AppTheme.lightPrimaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _bulkClose() {
    if (_selectedTickets.isEmpty) return;

    final isDarkMode =
        Provider.of<ThemeService>(context, listen: false).isDarkMode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Bulk Close',
          style: GoogleFonts.albertSans(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
          ),
        ),
        content: Text(
          'Are you sure you want to close ${_selectedTickets.length} selected tickets?',
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
            onPressed: () {
              Navigator.pop(context);
              _bulkUpdateStatusInFirebase(_selectedTickets.toList(), 'Closed');
            },
            child: Text(
              'Close Tickets',
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

  // Build combined conversation history (admin and driver responses)
  Widget _buildConversationHistory(
      Map<String, dynamic> ticket, bool isDarkMode) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('tickets').doc(ticket['id']).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.grey.withValues(alpha: 0.3),
              ),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: isDarkMode
                  ? Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1,
                    )
                  : Border.all(
                      color: Colors.grey.withValues(alpha: 0.3),
                      width: 1,
                    ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                        Icons.chat_rounded,
                        color: isDarkMode
                            ? AppColors.yellowAccent
                            : AppTheme.lightPrimaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Conversation (0)',
                      style: GoogleFonts.albertSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDarkMode
                            ? Colors.white
                            : AppTheme.lightTextPrimaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'No messages yet',
                  style: GoogleFonts.albertSans(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.5)
                        : AppTheme.lightTextSecondaryColor,
                  ),
                ),
              ],
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final adminResponses = data['adminResponses'] as List<dynamic>? ?? [];
        final driverResponses = data['driverResponses'] as List<dynamic>? ?? [];
        final userResponses = data['userResponses'] as List<dynamic>? ?? [];
        final ticketRole = data['role'] ??
            'driver'; // Default to driver for backward compatibility

        // Combine all messages and sort by timestamp
        List<Map<String, dynamic>> allMessages = [];

        // Add admin responses
        for (var response in adminResponses) {
          final responseData = response as Map<String, dynamic>;
          allMessages.add({
            'type': 'admin',
            'message': responseData['message'] ?? '',
            'senderName': responseData['adminName'] ?? 'Admin',
            'timestamp': _formatDate(responseData['timestamp']),
            'rawTimestamp': responseData['timestamp'],
          });
        }

        // Add driver or user responses based on ticket role
        if (ticketRole == 'user') {
          // Add user responses
          for (var response in userResponses) {
            final responseData = response as Map<String, dynamic>;
            allMessages.add({
              'type': 'user',
              'message': responseData['message'] ?? '',
              'senderName': responseData['userName'] ?? 'User',
              'timestamp': _formatDate(responseData['timestamp']),
              'rawTimestamp': responseData['timestamp'],
            });
          }
        } else {
          // Add driver responses (default behavior)
          for (var response in driverResponses) {
            final responseData = response as Map<String, dynamic>;
            allMessages.add({
              'type': 'driver',
              'message': responseData['message'] ?? '',
              'senderName': responseData['driverName'] ?? 'Driver',
              'timestamp': _formatDate(responseData['timestamp']),
              'rawTimestamp': responseData['timestamp'],
            });
          }
        }

        // Sort messages by timestamp (oldest first, newest last)
        allMessages.sort((a, b) {
          final aTimestamp = a['rawTimestamp'];
          final bTimestamp = b['rawTimestamp'];

          if (aTimestamp == null && bTimestamp == null) return 0;
          if (aTimestamp == null) return -1;
          if (bTimestamp == null) return 1;

          if (aTimestamp is Timestamp && bTimestamp is Timestamp) {
            return aTimestamp.compareTo(bTimestamp);
          }

          return 0;
        });

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: isDarkMode
                ? Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1,
                  )
                : Border.all(
                    color: Colors.grey.withValues(alpha: 0.3),
                    width: 1,
                  ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                      Icons.chat_rounded,
                      color: isDarkMode
                          ? AppColors.yellowAccent
                          : AppTheme.lightPrimaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Conversation (${allMessages.length})',
                    style: GoogleFonts.albertSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDarkMode
                          ? Colors.white
                          : AppTheme.lightTextPrimaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (allMessages.isEmpty)
                Text(
                  'No messages yet',
                  style: GoogleFonts.albertSans(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.5)
                        : AppTheme.lightTextSecondaryColor,
                  ),
                )
              else
                ...allMessages.map((message) {
                  final isAdmin = message['type'] == 'admin';
                  final isUser = message['type'] == 'user';

                  // Determine colors and icons based on message type
                  Color messageColor;
                  IconData messageIcon;

                  if (isAdmin) {
                    messageColor = Colors.green;
                    messageIcon = Icons.admin_panel_settings_rounded;
                  } else if (isUser) {
                    messageColor = Colors.orange;
                    messageIcon = Icons.person_rounded;
                  } else {
                    messageColor = Colors.blue;
                    messageIcon = Icons.local_shipping_rounded;
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: messageColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: messageColor.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: messageColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                messageIcon,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              message['senderName'],
                              style: GoogleFonts.albertSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: messageColor,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              message['timestamp'],
                              style: GoogleFonts.albertSans(
                                fontSize: 10,
                                color: isDarkMode
                                    ? Colors.white.withValues(alpha: 0.5)
                                    : AppTheme.lightTextSecondaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          message['message'],
                          style: GoogleFonts.albertSans(
                            fontSize: 14,
                            color: isDarkMode
                                ? Colors.white
                                : AppTheme.lightTextPrimaryColor,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
            ],
          ),
        );
      },
    );
  }

  // Send admin response
  Future<void> _sendAdminResponse(Map<String, dynamic> ticket, String message,
      TextEditingController controller) async {
    if (message.trim().isEmpty) {
      _showGlowingSnackBar('Please enter a response message', Colors.red);
      return;
    }

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        _showGlowingSnackBar(
            'You must be logged in to send a response', Colors.red);
        return;
      }

      // Get admin name (you might want to fetch this from admin collection)
      String adminName = 'Admin';
      try {
        final adminDoc =
            await _firestore.collection('admins').doc(currentUser.uid).get();
        if (adminDoc.exists) {
          adminName = adminDoc.data()?['name'] ?? 'Admin';
        }
      } catch (e) {
        debugPrint('Could not fetch admin name: $e');
      }

      final response = {
        'message': message.trim(),
        'adminId': currentUser.uid,
        'adminName': adminName,
        'timestamp': Timestamp.now(),
      };

      // Update the ticket with the new admin response
      await _firestore.collection('tickets').doc(ticket['id']).update({
        'adminResponses': FieldValue.arrayUnion([response]),
        'updatedAt': FieldValue.serverTimestamp(),
        'status':
            'In Progress', // Automatically set to In Progress when admin responds
      });

      // Clear the text field instead of closing the dialog
      controller.clear();

      // Refresh tickets list to show the update
      await _loadTickets();
    } catch (e) {
      debugPrint('Error sending admin response: $e');
      _showGlowingSnackBar('Error sending response: $e', Colors.red);
    }
  }
}
