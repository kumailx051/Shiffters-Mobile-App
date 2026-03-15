import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shiffters/theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:shiffters/services/theme_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class NotificationsAnnouncementsScreen extends StatefulWidget {
  const NotificationsAnnouncementsScreen({super.key});

  @override
  State<NotificationsAnnouncementsScreen> createState() =>
      _NotificationsAnnouncementsScreenState();
}

class _NotificationsAnnouncementsScreenState
    extends State<NotificationsAnnouncementsScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';
  final List<String> _filters = [
    'All',
    'Active',
    'Inactive',
    'Draft',
    'Scheduled'
  ];

  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Notification data from Firebase
  List<Map<String, dynamic>> _notifications = [];

  List<Map<String, dynamic>> _filteredNotifications = [];
  Set<String> _selectedNotifications = {};
  bool _isLoading = false;
  StreamSubscription<QuerySnapshot>? _notificationsSubscription;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setupRealtimeListener();
    _startAnimations();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
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
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      _animationController.forward();
    }
  }

  void _setupRealtimeListener() {
    setState(() {
      _isLoading = true;
    });

    _notificationsSubscription = _firestore
        .collection('announcements')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((QuerySnapshot snapshot) async {
      final List<Map<String, dynamic>> fetchedNotifications = [];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // Convert Firestore data to our notification format
        final notification = {
          'id': doc.id,
          'notificationId': 'SHF-${doc.id.substring(0, 8).toUpperCase()}',
          'title': data['title'] ?? 'No Title',
          'message': data['message'] ?? 'No Message',
          'type': _getNotificationTypeFromData(data),
          'status': data['status'] ?? 'active',
          'recipients': data['for'] ?? 'All Users',
          'recipientCount': await _getRecipientCount(data['for']),
          'priority': data['priority'] ?? 'medium',
          'category': data['category'] ?? 'General',
          'imageUrl': data['imageUrl'],
          'createdBy': await _getAdminName(data['adminId']),
          'createdAt': _formatTimestamp(data['createdAt']),
          'sentAt':
              data['sentAt'] != null ? _formatTimestamp(data['sentAt']) : null,
          'scheduledAt': data['scheduledAt'] != null
              ? _formatTimestamp(data['scheduledAt'])
              : null,
          'tags': data['tags'] ?? [],
          'targetAudience':
              data['for']?.toString().toLowerCase().replaceAll(' ', '_') ??
                  'all_users',
          'deliveryRate': data['deliveryRate'],
          'openRate': data['openRate'],
          'clickThroughRate': data['clickThroughRate'],
          'readCount': data['readCount'] ?? 0,
          'clickCount': data['clickCount'] ?? 0,
          'error': data['error'],
        };

        fetchedNotifications.add(notification);
      }

      if (mounted) {
        setState(() {
          _notifications = fetchedNotifications;
          _filteredNotifications = List.from(_notifications);
          _isLoading = false;
        });
        _filterNotifications();
      }
    }, onError: (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackbar('Failed to load notifications: $error');
      }
    });
  }

  void _filterNotifications() {
    setState(() {
      _filteredNotifications = _notifications.where((notification) {
        final matchesFilter = _selectedFilter == 'All' ||
            notification['status'].toString().toLowerCase() ==
                _selectedFilter.toLowerCase();
        final matchesSearch = _searchController.text.isEmpty ||
            notification['title']
                .toLowerCase()
                .contains(_searchController.text.toLowerCase()) ||
            notification['message']
                .toLowerCase()
                .contains(_searchController.text.toLowerCase()) ||
            notification['category']
                .toLowerCase()
                .contains(_searchController.text.toLowerCase()) ||
            notification['notificationId']
                .toLowerCase()
                .contains(_searchController.text.toLowerCase());
        return matchesFilter && matchesSearch;
      }).toList();
    });
  }

  // Firebase Methods
  Future<void> _loadNotificationsFromFirebase() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final QuerySnapshot announcementsSnapshot = await _firestore
          .collection('announcements')
          .orderBy('createdAt', descending: true)
          .get();

      final List<Map<String, dynamic>> fetchedNotifications = [];

      for (var doc in announcementsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // Convert Firestore data to our notification format
        final notification = {
          'id': doc.id,
          'notificationId': 'SHF-${doc.id.substring(0, 8).toUpperCase()}',
          'title': data['title'] ?? 'No Title',
          'message': data['message'] ?? 'No Message',
          'type': _getNotificationTypeFromData(data),
          'status': data['status'] ?? 'active',
          'recipients': data['for'] ?? 'All Users',
          'recipientCount': await _getRecipientCount(data['for']),
          'priority': data['priority'] ?? 'medium',
          'category': data['category'] ?? 'General',
          'imageUrl': data['imageUrl'],
          'createdBy': await _getAdminName(data['adminId']),
          'createdAt': _formatTimestamp(data['createdAt']),
          'sentAt':
              data['sentAt'] != null ? _formatTimestamp(data['sentAt']) : null,
          'scheduledAt': data['scheduledAt'] != null
              ? _formatTimestamp(data['scheduledAt'])
              : null,
          'tags': data['tags'] ?? [],
          'targetAudience':
              data['for']?.toString().toLowerCase().replaceAll(' ', '_') ??
                  'all_users',
          'deliveryRate': data['deliveryRate'],
          'openRate': data['openRate'],
          'clickThroughRate': data['clickThroughRate'],
          'readCount': data['readCount'] ?? 0,
          'clickCount': data['clickCount'] ?? 0,
          'error': data['error'],
        };

        fetchedNotifications.add(notification);
      }

      setState(() {
        _notifications = fetchedNotifications;
        _filteredNotifications = List.from(_notifications);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackbar('Failed to load notifications: $e');
    }
  }

  String _getNotificationTypeFromData(Map<String, dynamic> data) {
    if (data['type'] != null) return data['type'];

    // Determine type based on content or category
    final title = (data['title'] ?? '').toLowerCase();
    final message = (data['message'] ?? '').toLowerCase();
    final category = (data['category'] ?? '').toLowerCase();

    if (title.contains('promotion') ||
        title.contains('discount') ||
        title.contains('offer')) {
      return 'promotion';
    } else if (title.contains('welcome') || message.contains('welcome')) {
      return 'welcome';
    } else if (category.contains('payment') || title.contains('payment')) {
      return 'payment';
    } else if (category.contains('system') || title.contains('maintenance')) {
      return 'system';
    } else if (title.contains('bonus') || title.contains('reward')) {
      return 'reward';
    } else {
      return 'announcement';
    }
  }

  Future<int> _getRecipientCount(String? recipients) async {
    try {
      if (recipients == null || recipients.toLowerCase() == 'all users') {
        final usersSnapshot = await _firestore.collection('users').get();
        return usersSnapshot.docs.length;
      } else if (recipients.toLowerCase() == 'all drivers') {
        final driversSnapshot = await _firestore
            .collection('users')
            .where('role', isEqualTo: 'driver')
            .get();
        return driversSnapshot.docs.length;
      }
    } catch (e) {
      print('Error getting recipient count: $e');
    }
    return 0;
  }

  Future<String> _getAdminName(String? adminId) async {
    try {
      if (adminId == null) return 'System';

      final adminDoc = await _firestore.collection('users').doc(adminId).get();
      if (adminDoc.exists) {
        final adminData = adminDoc.data() as Map<String, dynamic>;
        return adminData['name'] ?? adminData['email'] ?? 'Admin';
      }
    } catch (e) {
      print('Error getting admin name: $e');
    }
    return 'Admin';
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';

    try {
      DateTime dateTime;
      if (timestamp is Timestamp) {
        dateTime = timestamp.toDate();
      } else if (timestamp is String) {
        dateTime = DateTime.parse(timestamp);
      } else {
        return 'Unknown';
      }

      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      print('Error formatting timestamp: $e');
      return 'Unknown';
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _notificationsSubscription?.cancel();
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
          backgroundColor: isDarkMode ? const Color(0xFF1E1E2C) : Colors.white,
          body: SafeArea(
            child: Column(
              children: [
                // Header
                _buildHeader(isTablet, isDarkMode),

                // Search bar
                _buildSearchBar(isTablet, isDarkMode),

                // Filters
                _buildFilters(isTablet, isDarkMode),

                // Stats
                _buildStats(isTablet, isDarkMode),

                // Bulk actions
                if (_selectedNotifications.isNotEmpty)
                  _buildBulkActions(isTablet, isDarkMode),

                // Notifications List
                Expanded(
                  child: _isLoading
                      ? _buildLoadingIndicator(isDarkMode)
                      : _buildNotificationsList(isTablet, isDarkMode),
                ),
              ],
            ),
          ),
          floatingActionButton: _buildFloatingActionButton(isDarkMode),
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
                          'Notifications',
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 28 : 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${_filteredNotifications.length} announcements',
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
                // Add notification button
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showCreateNotificationDialog();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.add,
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

  Widget _buildSearchBar(bool isTablet, bool isDarkMode) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: isTablet ? 32 : 20,
          vertical: isTablet ? 16 : 12,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
          border: isDarkMode
              ? Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                )
              : Border.all(
                  color: AppColors.lightPrimary,
                  width: 1.5,
                ),
          boxShadow: isDarkMode
              ? null
              : [
                  BoxShadow(
                    color: AppColors.lightPrimary.withValues(alpha: 0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
        ),
        child: Row(
          children: [
            Icon(
              Icons.search,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.7)
                  : AppColors.textSecondary,
              size: isTablet ? 24 : 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (value) => _filterNotifications(),
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 16 : 14,
                  color: isDarkMode ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText:
                      'Search notifications by title, message, or category...',
                  hintStyle: GoogleFonts.albertSans(
                    fontSize: isTablet ? 16 : 14,
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.5)
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(bool isTablet, bool isDarkMode) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        height: 50,
        margin: EdgeInsets.symmetric(
          horizontal: isTablet ? 32 : 20,
          vertical: isTablet ? 8 : 4,
        ),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: _filters.length,
          itemBuilder: (context, index) {
            final filter = _filters[index];
            final isSelected = _selectedFilter == filter;

            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _selectedFilter = filter;
                  _filterNotifications();
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
                          : AppColors.lightPrimary)
                      : isDarkMode
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(25),
                  border: isSelected
                      ? null
                      : Border.all(
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.2)
                              : AppColors.lightPrimary.withValues(alpha: 0.3),
                          width: 1,
                        ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: isDarkMode
                                ? AppColors.yellowAccent.withValues(alpha: 0.4)
                                : AppColors.lightPrimary.withValues(alpha: 0.4),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    filter,
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 14 : 12,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : isDarkMode
                              ? Colors.white.withValues(alpha: 0.7)
                              : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStats(bool isTablet, bool isDarkMode) {
    final totalActive =
        _notifications.where((n) => n['status'] == 'active').length;
    final scheduled =
        _notifications.where((n) => n['status'] == 'scheduled').length;
    final totalNotifications = _notifications.length;

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: isTablet ? 32 : 20,
          vertical: isTablet ? 16 : 12,
        ),
        padding: EdgeInsets.all(isTablet ? 20 : 16),
        decoration: BoxDecoration(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
          border: isDarkMode
              ? Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                )
              : Border.all(
                  color: AppColors.lightPrimary,
                  width: 1.5,
                ),
          boxShadow: isDarkMode
              ? null
              : [
                  BoxShadow(
                    color: AppColors.lightPrimary.withValues(alpha: 0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildStatItem(
                'Total Active',
                '$totalActive',
                Icons.check_circle,
                Colors.green,
                isTablet,
                isDarkMode,
              ),
            ),
            Container(
              height: 40,
              width: 1,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.2)
                  : AppColors.textSecondary.withValues(alpha: 0.2),
            ),
            Expanded(
              child: _buildStatItem(
                'Scheduled',
                '$scheduled',
                Icons.schedule,
                Colors.orange,
                isTablet,
                isDarkMode,
              ),
            ),
            Container(
              height: 40,
              width: 1,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.2)
                  : AppColors.textSecondary.withValues(alpha: 0.2),
            ),
            Expanded(
              child: _buildStatItem(
                'Total',
                '$totalNotifications',
                Icons.notifications,
                Colors.blue,
                isTablet,
                isDarkMode,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color,
      bool isTablet, bool isDarkMode) {
    return Column(
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
            size: isTablet ? 24 : 20,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.albertSans(
            fontSize: isTablet ? 18 : 16,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.albertSans(
            fontSize: isTablet ? 12 : 10,
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.7)
                : AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildBulkActions(bool isTablet, bool isDarkMode) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isTablet ? 32 : 20,
        vertical: isTablet ? 8 : 4,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? AppColors.yellowAccent.withValues(alpha: 0.1)
            : AppColors.lightPrimary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode
              ? AppColors.yellowAccent.withValues(alpha: 0.3)
              : AppColors.lightPrimary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Text(
            '${_selectedNotifications.length} selected',
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 16 : 14,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          _buildStyledButton(
            onPressed: _bulkSend,
            backgroundColor:
                isDarkMode ? AppColors.yellowAccent : AppColors.lightPrimary,
            foregroundColor: Colors.white,
            isTablet: isTablet,
            width: isTablet ? 80 : 70,
            height: 36,
            child: Text(
              'Send',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 14 : 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildStyledButton(
            onPressed: _bulkSchedule,
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            isTablet: isTablet,
            width: isTablet ? 100 : 85,
            height: 36,
            child: Text(
              'Schedule',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 14 : 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildStyledButton(
            onPressed: _bulkDelete,
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            isTablet: isTablet,
            width: isTablet ? 80 : 70,
            height: 36,
            child: Text(
              'Delete',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 14 : 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
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
          CircularProgressIndicator(
            color: isDarkMode ? AppColors.yellowAccent : AppColors.lightPrimary,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading notifications...',
            style: GoogleFonts.albertSans(
              fontSize: 16,
              color: isDarkMode ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList(bool isTablet, bool isDarkMode) {
    if (_filteredNotifications.isEmpty) {
      return _buildEmptyState(isDarkMode);
    }

    return SlideTransition(
      position: _slideAnimation,
      child: RefreshIndicator(
        onRefresh: _refreshNotifications,
        color: isDarkMode ? AppColors.yellowAccent : AppColors.lightPrimary,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 32 : 20,
            vertical: isTablet ? 16 : 12,
          ),
          itemCount: _filteredNotifications.length,
          itemBuilder: (context, index) {
            final notification = _filteredNotifications[index];
            return _buildNotificationCard(notification, isTablet, isDarkMode);
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
            Icons.notifications_none_outlined,
            size: 80,
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.3)
                : AppColors.textSecondary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications found',
            style: GoogleFonts.albertSans(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.7)
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or filter criteria',
            style: GoogleFonts.albertSans(
              fontSize: 14,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.5)
                  : AppColors.textSecondary.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(
      Map<String, dynamic> notification, bool isTablet, bool isDarkMode) {
    final isSelected = _selectedNotifications.contains(notification['id']);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? (isDarkMode ? AppColors.yellowAccent : AppColors.lightPrimary)
              : isDarkMode
                  ? Colors.white.withValues(alpha: 0.2)
                  : AppColors.lightPrimary.withValues(alpha: 0.3),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isDarkMode
            ? null
            : [
                BoxShadow(
                  color: AppColors.lightPrimary.withValues(alpha: 0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              // Checkbox
              Checkbox(
                value: isSelected,
                onChanged: (bool? value) {
                  setState(() {
                    if (value == true) {
                      _selectedNotifications.add(notification['id']);
                    } else {
                      _selectedNotifications.remove(notification['id']);
                    }
                  });
                },
                activeColor: isDarkMode
                    ? AppColors.yellowAccent
                    : AppColors.lightPrimary,
              ),

              // Type icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getTypeColor(notification['type'])
                      .withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getTypeIcon(notification['type']),
                  color: _getTypeColor(notification['type']),
                  size: isTablet ? 20 : 18,
                ),
              ),

              const SizedBox(width: 12),

              // Title and ID
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification['notificationId'],
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 14 : 12,
                        fontWeight: FontWeight.bold,
                        color:
                            isDarkMode ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notification['title'],
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 16 : 14,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.9)
                            : AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Status and Priority
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildStatusBadge(
                      notification['status'], isTablet, isDarkMode),
                  const SizedBox(height: 4),
                  _buildPriorityIndicator(notification['priority'], isTablet),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Message
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              notification['message'],
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 14 : 12,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.8)
                    : AppColors.textSecondary,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(height: 16),

          // Recipients and category info
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recipients',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 12 : 10,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.7)
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.group,
                          size: isTablet ? 16 : 14,
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.7)
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${notification['recipients']} (${notification['recipientCount']})',
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 12 : 10,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Category',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 12 : 10,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.7)
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification['category'],
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 12 : 10,
                        fontWeight: FontWeight.w600,
                        color:
                            isDarkMode ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Created By',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 12 : 10,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.7)
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification['createdBy'],
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 12 : 10,
                        fontWeight: FontWeight.w600,
                        color:
                            isDarkMode ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Stats or timestamp based on status
          if (notification['status'] == 'sent' ||
              notification['status'] == 'active') ...[
            if (notification['sentAt'] != null)
              Text(
                'Sent: ${notification['sentAt']}',
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 12 : 10,
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.7)
                      : AppColors.textSecondary,
                ),
              )
            else
              Text(
                'Status: Active',
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 12 : 10,
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.7)
                      : AppColors.textSecondary,
                ),
              ),
          ] else if (notification['status'] == 'scheduled') ...[
            Text(
              'Scheduled: ${notification['scheduledAt']}',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 12 : 10,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.7)
                    : AppColors.textSecondary,
              ),
            ),
          ] else if (notification['status'] == 'failed') ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: isTablet ? 16 : 14,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Error: ${notification['error']}',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 12 : 10,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (notification['status'] == 'draft') ...[
            Text(
              'Created: ${notification['createdAt']}',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 12 : 10,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.7)
                    : AppColors.textSecondary,
              ),
            ),
          ],

          // Tags
          if (notification['tags'] != null &&
              notification['tags'].isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: notification['tags'].map<Widget>((tag) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? AppColors.yellowAccent.withValues(alpha: 0.2)
                        : AppColors.lightPrimary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    tag,
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 10 : 8,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode
                          ? AppColors.yellowAccent
                          : AppColors.lightPrimary,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 16),

          // Actions
          Row(
            children: [
              Expanded(
                child: _buildStyledButton(
                  onPressed: () => _viewNotificationDetails(notification),
                  backgroundColor: isDarkMode
                      ? AppColors.yellowAccent
                      : AppColors.lightPrimary,
                  foregroundColor: isDarkMode ? Colors.black : Colors.white,
                  isTablet: isTablet,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.visibility, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'View Details',
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 14 : 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (notification['status'] == 'draft' ||
                  notification['status'] == 'inactive') ...[
                Expanded(
                  child: _buildStyledButton(
                    onPressed: () => _editNotification(notification),
                    backgroundColor: isDarkMode
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.white,
                    foregroundColor:
                        isDarkMode ? Colors.white : AppColors.textPrimary,
                    isTablet: isTablet,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.edit, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Edit',
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 14 : 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildStyledButton(
                  onPressed: () => _sendNotification(notification),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  isTablet: isTablet,
                  width: isTablet ? 80 : 60,
                  child: Text(
                    'Send',
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 12 : 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ] else if (notification['status'] == 'scheduled') ...[
                Expanded(
                  child: _buildStyledButton(
                    onPressed: () => _editNotification(notification),
                    backgroundColor: isDarkMode
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.white,
                    foregroundColor:
                        isDarkMode ? Colors.white : AppColors.textPrimary,
                    isTablet: isTablet,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.edit, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Edit',
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 14 : 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildStyledButton(
                  onPressed: () => _cancelNotification(notification),
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  isTablet: isTablet,
                  width: isTablet ? 80 : 60,
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 12 : 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ] else if (notification['status'] == 'failed') ...[
                Expanded(
                  child: _buildStyledButton(
                    onPressed: () => _retryNotification(notification),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    isTablet: isTablet,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.refresh, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Retry',
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 14 : 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              _buildStyledButton(
                onPressed: () => _deleteNotification(notification),
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                isTablet: isTablet,
                width: isTablet ? 80 : 60,
                child: Text(
                  'Delete',
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 12 : 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status, bool isTablet, bool isDarkMode) {
    Color color = _getStatusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.albertSans(
          fontSize: isTablet ? 10 : 8,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildPriorityIndicator(String priority, bool isTablet) {
    Color color = _getPriorityColor(priority);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            priority.toUpperCase(),
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 8 : 7,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(
      String text, IconData icon, bool isTablet, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.2)
              : AppColors.lightPrimary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: isTablet ? 12 : 10,
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.7)
                : AppColors.textSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 10 : 8,
              fontWeight: FontWeight.w500,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.7)
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton(bool isDarkMode) {
    return _buildStyledButton(
      onPressed: _showCreateNotificationDialog,
      backgroundColor:
          isDarkMode ? AppColors.yellowAccent : AppColors.lightPrimary,
      foregroundColor: isDarkMode ? Colors.black : Colors.white,
      width: 120,
      height: 56,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.add),
          const SizedBox(width: 8),
          Text(
            'Create',
            style: GoogleFonts.albertSans(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to create buttons with Sign In button styling
  Widget _buildStyledButton({
    required VoidCallback? onPressed,
    required Widget child,
    required Color backgroundColor,
    required Color foregroundColor,
    bool isTablet = false,
    double? width,
    double? height,
  }) {
    final buttonHeight = height ?? (isTablet ? 44.0 : 40.0);

    return Container(
      width: width,
      height: buttonHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withValues(alpha: 0.6),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: backgroundColor.withValues(alpha: 0.3),
            blurRadius: 40,
            spreadRadius: 0,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          padding: EdgeInsets.zero,
        ),
        child: child,
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'promotion':
        return Icons.local_offer;
      case 'announcement':
        return Icons.campaign;
      case 'system':
        return Icons.settings;
      case 'welcome':
        return Icons.waving_hand;
      case 'payment':
        return Icons.payment;
      case 'reward':
        return Icons.card_giftcard;
      default:
        return Icons.notifications;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'promotion':
        return Colors.green;
      case 'announcement':
        return Colors.blue;
      case 'system':
        return Colors.orange;
      case 'welcome':
        return Colors.purple;
      case 'payment':
        return Colors.red;
      case 'reward':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'sent':
        return Colors.green;
      case 'scheduled':
        return Colors.orange;
      case 'draft':
      case 'inactive':
        return Colors.grey;
      case 'failed':
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'critical':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.blue;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Future<void> _refreshNotifications() async {
    await _loadNotificationsFromFirebase();
  }

  void _showCreateNotificationDialog() {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isDarkMode = themeService.isDarkMode;

    // Controllers for form fields
    final TextEditingController titleController = TextEditingController();
    final TextEditingController messageController = TextEditingController();
    String? selectedRecipient;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
        title: Text(
          'Create Notification',
          style: GoogleFonts.albertSans(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : AppColors.textPrimary,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                style: GoogleFonts.albertSans(
                  color: isDarkMode ? Colors.white : AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: 'Title',
                  labelStyle: GoogleFonts.albertSans(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.7)
                        : AppColors.textSecondary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.3)
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: messageController,
                style: GoogleFonts.albertSans(
                  color: isDarkMode ? Colors.white : AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: 'Message',
                  labelStyle: GoogleFonts.albertSans(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.7)
                        : AppColors.textSecondary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.3)
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedRecipient,
                style: GoogleFonts.albertSans(
                  color: isDarkMode ? Colors.white : AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: 'Recipients',
                  labelStyle: GoogleFonts.albertSans(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.7)
                        : AppColors.textSecondary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.3)
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                dropdownColor:
                    isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
                items: [
                  'All Users',
                  'All Drivers',
                ].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value,
                      style: GoogleFonts.albertSans(
                        color:
                            isDarkMode ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  selectedRecipient = value;
                },
              ),
            ],
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
              // Validate form fields
              if (titleController.text.trim().isEmpty) {
                _showErrorSnackbar('Please enter a title');
                return;
              }
              if (messageController.text.trim().isEmpty) {
                _showErrorSnackbar('Please enter a message');
                return;
              }
              if (selectedRecipient == null) {
                _showErrorSnackbar('Please select recipients');
                return;
              }

              try {
                // Get current admin ID
                final currentUser = _auth.currentUser;
                if (currentUser == null) {
                  _showErrorSnackbar('Admin not authenticated');
                  return;
                }

                // Create announcement document
                await _firestore.collection('announcements').add({
                  'title': titleController.text.trim(),
                  'message': messageController.text.trim(),
                  'for': selectedRecipient,
                  'adminId': currentUser.uid,
                  'createdAt': FieldValue.serverTimestamp(),
                  'status': 'active',
                  'priority': 'medium',
                  'category': 'General',
                  'type': 'announcement',
                });

                Navigator.pop(context);
                _showSuccessSnackbar('Notification created successfully');

                // Refresh the notifications list
                _loadNotificationsFromFirebase();
              } catch (e) {
                _showErrorSnackbar('Failed to create notification: $e');
              }
            },
            child: Text(
              'Create',
              style: GoogleFonts.albertSans(
                color: isDarkMode
                    ? AppColors.yellowAccent
                    : AppColors.lightPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _viewNotificationDetails(Map<String, dynamic> notification) {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isDarkMode = themeService.isDarkMode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
        title: Text(
          'Notification Details',
          style: GoogleFonts.albertSans(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : AppColors.textPrimary,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('ID', notification['notificationId'], isDarkMode),
              _buildDetailRow('Title', notification['title'], isDarkMode),
              _buildDetailRow('Type', notification['type'], isDarkMode),
              _buildDetailRow('Status', notification['status'], isDarkMode),
              _buildDetailRow('Priority', notification['priority'], isDarkMode),
              _buildDetailRow('Category', notification['category'], isDarkMode),
              _buildDetailRow(
                  'Recipients',
                  '${notification['recipients']} (${notification['recipientCount']})',
                  isDarkMode),
              _buildDetailRow(
                  'Created By', notification['createdBy'], isDarkMode),
              _buildDetailRow(
                  'Created At', notification['createdAt'], isDarkMode),
              if (notification['sentAt'] != null)
                _buildDetailRow('Sent At', notification['sentAt'], isDarkMode),
              if (notification['scheduledAt'] != null)
                _buildDetailRow(
                    'Scheduled At', notification['scheduledAt'], isDarkMode),
              if (notification['deliveryRate'] != null)
                _buildDetailRow('Delivery Rate',
                    '${notification['deliveryRate']}%', isDarkMode),
              if (notification['openRate'] != null)
                _buildDetailRow(
                    'Open Rate', '${notification['openRate']}%', isDarkMode),
              if (notification['clickThroughRate'] != null)
                _buildDetailRow('Click Rate',
                    '${notification['clickThroughRate']}%', isDarkMode),
              const SizedBox(height: 8),
              Text(
                'Message:',
                style: GoogleFonts.albertSans(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                notification['message'],
                style: GoogleFonts.albertSans(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.8)
                      : AppColors.textSecondary,
                ),
              ),
              if (notification['tags'] != null &&
                  notification['tags'].isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Tags: ${notification['tags'].join(', ')}',
                  style: GoogleFonts.albertSans(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.8)
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.albertSans(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.7)
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
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
                    : AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.albertSans(
                color: isDarkMode ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _editNotification(Map<String, dynamic> notification) {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isDarkMode = themeService.isDarkMode;

    // Controllers for form fields
    final TextEditingController titleController =
        TextEditingController(text: notification['title']);
    final TextEditingController messageController =
        TextEditingController(text: notification['message']);
    String selectedRecipient = notification['recipients'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
        title: Text(
          'Edit Notification',
          style: GoogleFonts.albertSans(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : AppColors.textPrimary,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                style: GoogleFonts.albertSans(
                  color: isDarkMode ? Colors.white : AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: 'Title',
                  labelStyle: GoogleFonts.albertSans(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.7)
                        : AppColors.textSecondary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: messageController,
                style: GoogleFonts.albertSans(
                  color: isDarkMode ? Colors.white : AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: 'Message',
                  labelStyle: GoogleFonts.albertSans(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.7)
                        : AppColors.textSecondary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedRecipient,
                style: GoogleFonts.albertSans(
                  color: isDarkMode ? Colors.white : AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: 'Recipients',
                  labelStyle: GoogleFonts.albertSans(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.7)
                        : AppColors.textSecondary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                dropdownColor:
                    isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
                items: [
                  'All Users',
                  'All Drivers',
                ].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value,
                      style: GoogleFonts.albertSans(
                        color:
                            isDarkMode ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  selectedRecipient = value ?? selectedRecipient;
                },
              ),
            ],
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
              try {
                await _firestore
                    .collection('announcements')
                    .doc(notification['id'])
                    .update({
                  'title': titleController.text.trim(),
                  'message': messageController.text.trim(),
                  'for': selectedRecipient,
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                Navigator.pop(context);
                _showSuccessSnackbar('Notification updated successfully');
              } catch (e) {
                _showErrorSnackbar('Failed to update notification: $e');
              }
            },
            child: Text(
              'Update',
              style: GoogleFonts.albertSans(
                color: isDarkMode
                    ? AppColors.yellowAccent
                    : AppColors.lightPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _sendNotification(Map<String, dynamic> notification) async {
    try {
      await _firestore
          .collection('announcements')
          .doc(notification['id'])
          .update({
        'status': 'sent',
        'sentAt': FieldValue.serverTimestamp(),
      });
      _showSuccessSnackbar('Notification sent successfully');
    } catch (e) {
      _showErrorSnackbar('Failed to send notification: $e');
    }
  }

  void _cancelNotification(Map<String, dynamic> notification) async {
    try {
      await _firestore
          .collection('announcements')
          .doc(notification['id'])
          .update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });
      _showSuccessSnackbar('Notification cancelled successfully');
    } catch (e) {
      _showErrorSnackbar('Failed to cancel notification: $e');
    }
  }

  void _retryNotification(Map<String, dynamic> notification) async {
    try {
      await _firestore
          .collection('announcements')
          .doc(notification['id'])
          .update({
        'status': 'active',
        'retriedAt': FieldValue.serverTimestamp(),
      });
      _showSuccessSnackbar('Notification retry initiated successfully');
    } catch (e) {
      _showErrorSnackbar('Failed to retry notification: $e');
    }
  }

  void _deleteNotification(Map<String, dynamic> notification) {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isDarkMode = themeService.isDarkMode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
        title: Text(
          'Delete Notification',
          style: GoogleFonts.albertSans(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this notification? This action cannot be undone.',
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
              Navigator.pop(context);
              try {
                // Delete from Firebase
                await _firestore
                    .collection('announcements')
                    .doc(notification['id'])
                    .delete();
                _showSuccessSnackbar('Notification deleted successfully');

                // Refresh the notifications list
                _loadNotificationsFromFirebase();
              } catch (e) {
                _showErrorSnackbar('Failed to delete notification: $e');
              }
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

  void _bulkSend() {
    if (_selectedNotifications.isEmpty) return;

    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isDarkMode = themeService.isDarkMode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
        title: Text(
          'Bulk Send Notifications',
          style: GoogleFonts.albertSans(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to send ${_selectedNotifications.length} selected notifications?',
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
              Navigator.pop(context);
              try {
                final batch = _firestore.batch();

                for (final notificationId in _selectedNotifications) {
                  final docRef = _firestore
                      .collection('announcements')
                      .doc(notificationId);
                  batch.update(docRef, {
                    'status': 'sent',
                    'sentAt': FieldValue.serverTimestamp(),
                  });
                }

                await batch.commit();

                setState(() {
                  _selectedNotifications.clear();
                });

                _showSuccessSnackbar('Bulk notifications sent successfully');
              } catch (e) {
                _showErrorSnackbar('Failed to send notifications: $e');
              }
            },
            child: Text(
              'Send',
              style: GoogleFonts.albertSans(
                color: isDarkMode
                    ? AppColors.yellowAccent
                    : AppColors.lightPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _bulkSchedule() {
    if (_selectedNotifications.isEmpty) return;

    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isDarkMode = themeService.isDarkMode;
    final TextEditingController dateController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
        title: Text(
          'Bulk Schedule Notifications',
          style: GoogleFonts.albertSans(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : AppColors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Schedule ${_selectedNotifications.length} selected notifications for:',
              style: GoogleFonts.albertSans(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.8)
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: dateController,
              style: GoogleFonts.albertSans(
                color: isDarkMode ? Colors.white : AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                labelText: 'Date & Time',
                labelStyle: GoogleFonts.albertSans(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.7)
                      : AppColors.textSecondary,
                ),
                hintText: 'YYYY-MM-DD HH:MM',
                hintStyle: GoogleFonts.albertSans(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.5)
                      : AppColors.textSecondary.withValues(alpha: 0.7),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
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
                    : AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final batch = _firestore.batch();

                for (final notificationId in _selectedNotifications) {
                  final docRef = _firestore
                      .collection('announcements')
                      .doc(notificationId);
                  batch.update(docRef, {
                    'status': 'scheduled',
                    'scheduledAt': FieldValue.serverTimestamp(),
                    'scheduledFor': dateController.text.trim(),
                  });
                }

                await batch.commit();

                setState(() {
                  _selectedNotifications.clear();
                });

                _showSuccessSnackbar('Notifications scheduled successfully');
              } catch (e) {
                _showErrorSnackbar('Failed to schedule notifications: $e');
              }
            },
            child: Text(
              'Schedule',
              style: GoogleFonts.albertSans(
                color: Colors.orange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _bulkDelete() {
    if (_selectedNotifications.isEmpty) return;

    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isDarkMode = themeService.isDarkMode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
        title: Text(
          'Bulk Delete Notifications',
          style: GoogleFonts.albertSans(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to delete ${_selectedNotifications.length} selected notifications? This action cannot be undone.',
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
              Navigator.pop(context);
              try {
                // Create a batch to delete multiple documents
                final batch = _firestore.batch();

                for (final notificationId in _selectedNotifications) {
                  final docRef = _firestore
                      .collection('announcements')
                      .doc(notificationId);
                  batch.delete(docRef);
                }

                await batch.commit();

                setState(() {
                  _selectedNotifications.clear();
                });

                _showSuccessSnackbar(
                    'Selected notifications deleted successfully');

                // Refresh the notifications list
                _loadNotificationsFromFirebase();
              } catch (e) {
                _showErrorSnackbar('Failed to delete notifications: $e');
              }
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

  void _showSuccessSnackbar(String message) {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isDarkMode = themeService.isDarkMode;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor:
            isDarkMode ? AppColors.yellowAccent : AppColors.lightPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
          message,
          style: GoogleFonts.albertSans(
            color: isDarkMode ? Colors.black : Colors.white,
            fontWeight: FontWeight.w500,
            shadows: isDarkMode
                ? null
                : [
                    Shadow(
                      offset: const Offset(0, 0),
                      blurRadius: 10,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ],
          ),
        ),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
          message,
          style: GoogleFonts.albertSans(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
