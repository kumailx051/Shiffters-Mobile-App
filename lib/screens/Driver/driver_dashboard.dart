import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shiffters/theme/app_colors.dart';
import 'package:shiffters/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shiffters/services/theme_service.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'driver_orders_screen.dart';
import 'driver_earnings_screen.dart';
import 'driver_profile_screen.dart';
import 'driver_help_screen.dart';
import 'driver_accept_screen.dart';
import 'package:shiffters/screens/User/home_screen.dart';
import 'package:shiffters/screens/welcome_screen.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  int _selectedIndex = 0;
  bool _isOnShift = false;

  // Today's statistics (dynamic data)
  int _todaysJobs = 0;
  double _todaysEarnings = 0.0;
  bool _isLoadingTodaysData = true;

  final GlobalKey _menuKey = GlobalKey();

  // User data
  String _userName = 'Loading...';
  String _profileImageUrl = '';
  bool _isLoadingUserData = true;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Announcements for drivers
  List<Map<String, dynamic>> _announcements = [];
  bool _isLoadingAnnouncements = true;
  int _currentAnnouncementIndex = 0;
  Timer? _announcementTimer;
  StreamSubscription<QuerySnapshot>? _announcementSubscription;
  Set<String> _readAnnouncementIds = {};
  OverlayEntry? _announcementOverlay;

  // Announcement animation controllers
  late AnimationController _announcementController;
  late Animation<double> _announcementFadeAnimation;
  late Animation<Offset> _announcementSlideAnimation;
  bool _isAnimatingAnnouncement = false;

  // Message notification tracking
  int _unreadMessageCount = 0;
  StreamSubscription<QuerySnapshot>? _messageSubscription;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
    _fetchUserData();
    _loadTodaysData();
    _loadReadAnnouncementIds();
    _setupAnnouncementListener();
    _setupMessageListener();

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

    // Announcement animation controller
    _announcementController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    // Announcement animations
    _announcementFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _announcementController,
      curve: Curves.easeInOut,
    ));

    _announcementSlideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0), // Slide in from right
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _announcementController,
      curve: Curves.easeOutCubic,
    ));

    // Start announcement animation
    _announcementController.forward();
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      _animationController.forward();
    }
  }

  // Fetch user data from Firestore
  Future<void> _fetchUserData() async {
    try {
      setState(() {
        _isLoadingUserData = true;
      });

      final User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // First try to get from drivers collection
        DocumentSnapshot driverDoc =
            await _firestore.collection('drivers').doc(user.uid).get();

        if (driverDoc.exists) {
          final driverData = driverDoc.data() as Map<String, dynamic>?;
          final firstName =
              driverData?['personalInfo']?['firstName']?.toString() ?? '';
          final profileImageUrl =
              driverData?['profileImageUrl']?.toString() ?? '';

          if (firstName.isNotEmpty) {
            if (mounted) {
              setState(() {
                _userName = firstName;
                _profileImageUrl = profileImageUrl;
                _isLoadingUserData = false;
              });
            }
            return;
          }
        }

        // If not found in drivers, try users collection
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(user.uid).get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>?;
          final firstName = userData?['firstName']?.toString() ??
              userData?['name']?.toString() ??
              'User';
          final profileImageUrl =
              userData?['profileImageUrl']?.toString() ?? '';

          if (mounted) {
            setState(() {
              _userName = firstName;
              _profileImageUrl = profileImageUrl;
              _isLoadingUserData = false;
            });
          }
        } else {
          // Fallback to user email or default
          if (mounted) {
            setState(() {
              _userName = user.email?.split('@')[0] ?? 'User';
              _profileImageUrl = '';
              _isLoadingUserData = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _userName = 'Guest';
            _profileImageUrl = '';
            _isLoadingUserData = false;
          });
        }
      }
    } catch (e) {
      print('Error fetching user data: $e');
      if (mounted) {
        setState(() {
          _userName = 'User';
          _profileImageUrl = '';
          _isLoadingUserData = false;
        });
      }
    }
  }

  Future<void> _loadTodaysData() async {
    try {
      setState(() {
        _isLoadingTodaysData = true;
      });

      final User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Get today's date range (start and end of today)
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

        debugPrint(
            'Loading today\'s data for date range: $todayStart to $todayEnd');

        // Query today's completed orders for this driver
        final todaysOrdersQuery = await _firestore
            .collection('orders')
            .where('driverId', isEqualTo: user.uid)
            .where('status', isEqualTo: 'completed')
            .get();

        int todaysJobsCount = 0;
        double todaysEarningsTotal = 0.0;

        // Filter and calculate today's data
        for (var doc in todaysOrdersQuery.docs) {
          final data = doc.data();

          // Check if the order was completed today using startedAt field
          final startedAt = data['startedAt'] as Timestamp?;
          if (startedAt != null) {
            final orderDate = startedAt.toDate();

            // Check if the order was started today
            if (orderDate
                    .isAfter(todayStart.subtract(const Duration(seconds: 1))) &&
                orderDate.isBefore(todayEnd.add(const Duration(seconds: 1)))) {
              todaysJobsCount++;

              // Add to today's earnings
              final amount = data['totalAmount'];
              if (amount != null) {
                if (amount is num) {
                  todaysEarningsTotal += amount.toDouble();
                } else if (amount is String) {
                  todaysEarningsTotal += double.tryParse(amount) ?? 0.0;
                }
              }

              debugPrint(
                  'Found today\'s order: ${doc.id}, amount: $amount, started: $orderDate');
            }
          }
        }

        if (mounted) {
          setState(() {
            _todaysJobs = todaysJobsCount;
            _todaysEarnings = todaysEarningsTotal;
            _isLoadingTodaysData = false;
          });
        }

        debugPrint(
            'Today\'s Summary - Jobs: $_todaysJobs, Earnings: $_todaysEarnings');
      }
    } catch (e) {
      debugPrint('Error loading today\'s data: $e');
      if (mounted) {
        setState(() {
          _isLoadingTodaysData = false;
        });
      }
    }
  }

  // Clear remember me saved information
  Future<void> _clearRememberMeData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auto_login', false);
      await prefs.setBool('remember_me', false);
      await prefs.remove('saved_email');
      await prefs.remove('saved_password');
    } catch (e) {
      debugPrint('Error clearing remember me data: $e');
    }
  }

  // Handle logout functionality
  Future<void> _handleLogout() async {
    try {
      // Show confirmation dialog
      bool? shouldLogout = await showDialog<bool>(
        context: context,
        barrierDismissible: false, // Prevent dismissing by tapping outside
        builder: (BuildContext context) {
          final themeService =
              Provider.of<ThemeService>(context, listen: false);
          final isDarkMode = themeService.isDarkMode;

          return WillPopScope(
            onWillPop: () async => false, // Prevent back button dismissal
            child: AlertDialog(
              backgroundColor:
                  isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Logout',
                style: GoogleFonts.albertSans(
                  color: isDarkMode ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
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
                  onPressed: () => Navigator.of(context).pop(false),
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
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Logout',
                    style: GoogleFonts.albertSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );

      if (shouldLogout == true) {
        // Show loading indicator
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              final themeService =
                  Provider.of<ThemeService>(context, listen: false);
              final isDarkMode = themeService.isDarkMode;

              return WillPopScope(
                onWillPop: () async => false,
                child: AlertDialog(
                  backgroundColor:
                      isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        color: isDarkMode
                            ? AppColors.yellowAccent
                            : AppTheme.lightPrimaryColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Logging out...',
                        style: GoogleFonts.albertSans(
                          color:
                              isDarkMode ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }

        // Clear remember me saved information before logout
        await _clearRememberMeData();

        // Reset user mode to user
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_mode', 'user');

        // Sign out from Firebase
        await FirebaseAuth.instance.signOut();

        // Navigate to welcome screen and clear all previous routes
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const WelcomeScreen()),
            (Route<dynamic> route) => false,
          );
        }
      }
    } catch (e) {
      // Handle logout error
      print('Error during logout: $e');

      // Close loading dialog if it's showing
      if (mounted) {
        Navigator.of(context).pop();

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error during logout. Please try again.',
              style: GoogleFonts.albertSans(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    try {
      _announcementTimer?.cancel();
      _announcementSubscription?.cancel();
      _messageSubscription?.cancel();
      _announcementOverlay?.remove();
      _animationController.dispose();
      _announcementController.dispose();
    } catch (e) {
      debugPrint('Error during dispose: $e');
    }
    super.dispose();
  }

  // Announcement methods
  void _setupAnnouncementListener() {
    _announcementSubscription = _firestore
        .collection('announcements')
        .where('for', whereIn: ['All Drivers', 'all_drivers'])
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((QuerySnapshot snapshot) {
          final List<Map<String, dynamic>> announcements = [];

          for (var doc in snapshot.docs) {
            try {
              final data = doc.data() as Map<String, dynamic>;
              data['id'] = doc.id;
              announcements.add(data);
            } catch (e) {
              print('Error processing announcement ${doc.id}: $e');
            }
          }

          if (mounted) {
            setState(() {
              _announcements = announcements;
              _isLoadingAnnouncements = false;
              _currentAnnouncementIndex = 0;
            });

            _startAnnouncementCarousel();
          }
        }, onError: (error) {
          print('Error fetching announcements: $error');
          if (mounted) {
            setState(() {
              _isLoadingAnnouncements = false;
            });
          }
        });
  }

  void _startAnnouncementCarousel() {
    _announcementTimer?.cancel();

    if (_announcements.length > 1) {
      _announcementTimer =
          Timer.periodic(const Duration(seconds: 5), (timer) async {
        if (!mounted || _announcements.isEmpty || _isAnimatingAnnouncement)
          return;

        setState(() {
          _isAnimatingAnnouncement = true;
        });

        try {
          // Animate out current announcement
          await _announcementController.reverse();

          if (mounted && _announcements.isNotEmpty) {
            // Change to next announcement
            setState(() {
              _currentAnnouncementIndex =
                  (_currentAnnouncementIndex + 1) % _announcements.length;
            });

            // Animate in new announcement
            await _announcementController.forward();
          }
        } catch (e) {
          debugPrint('Error in announcement animation: $e');
        } finally {
          if (mounted) {
            setState(() {
              _isAnimatingAnnouncement = false;
            });
          }
        }
      });
    }
  }

  // Message notification setup for driver mode
  void _setupMessageListener() {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("❌ [Driver Dashboard] No user logged in");
      return;
    }

    print(
        "✅ [Driver Dashboard] Setting up message listener for driver: ${user.uid}");

    try {
      _messageSubscription = FirebaseFirestore.instance
          .collection('conversations')
          .where('participants', arrayContains: user.uid)
          .snapshots()
          .listen((QuerySnapshot snapshot) async {
        print(
            "✅ [Driver Dashboard] Found ${snapshot.docs.length} conversations");
        await _processDriverConversations(snapshot, user.uid);
      }, onError: (error) {
        print('❌ [Driver Dashboard] Error with message listener: $error');
      });
    } catch (e) {
      print('❌ [Driver Dashboard] Error setting up message listener: $e');
    }
  }

  Future<void> _processDriverConversations(
      QuerySnapshot snapshot, String currentUserId) async {
    int totalUnreadCount = 0;

    for (var doc in snapshot.docs) {
      try {
        final conversationData = doc.data() as Map<String, dynamic>;
        final conversationId = doc.id;

        print("🔍 [Driver Dashboard] Processing conversation: $conversationId");
        print("🔍 [Driver Dashboard] Current user ID: $currentUserId");

        // Get the other participant (not the current user)
        final List<dynamic> participants =
            conversationData['participants'] ?? [];
        print("🔍 [Driver Dashboard] Conversation participants: $participants");

        final String? otherUserId = participants.firstWhere(
          (id) => id != currentUserId,
          orElse: () => null,
        );

        if (otherUserId == null) {
          print(
              "⚠️ [Driver Dashboard] No other participant found in conversation: $conversationId");
          continue;
        }

        print("🔍 [Driver Dashboard] Other user ID: $otherUserId");

        // Get order ID from conversation to check if current user is driver
        final String orderId = conversationData['orderId'] ?? '';

        // Check if current user is the driver for this order
        bool currentUserIsDriver = false;

        // First check if conversation has driverId field directly
        final String conversationDriverId = conversationData['driverId'] ?? '';
        if (conversationDriverId == currentUserId) {
          currentUserIsDriver = true;
          print("✅ [Driver Dashboard] Current user is driver in conversation");
        }

        // Also check the order document if orderId exists
        if (!currentUserIsDriver && orderId.isNotEmpty) {
          try {
            final orderDoc = await FirebaseFirestore.instance
                .collection('orders')
                .doc(orderId)
                .get();

            if (orderDoc.exists) {
              final orderData = orderDoc.data() as Map<String, dynamic>;
              final String orderDriverId = orderData['driverId'] ?? '';

              if (orderDriverId == currentUserId) {
                currentUserIsDriver = true;
                print(
                    "✅ [Driver Dashboard] Current user is driver for order $orderId");
              }
            }
          } catch (e) {
            print("⚠️ [Driver Dashboard] Error checking order $orderId: $e");
          }
        }

        // Only count conversations where current user is the driver
        if (currentUserIsDriver) {
          // Get unread count for current user (driver)
          final Map<String, dynamic> unreadCounts =
              conversationData['unreadCounts'] as Map<String, dynamic>? ?? {};
          final int unreadCount = unreadCounts[currentUserId] as int? ?? 0;

          totalUnreadCount += unreadCount;

          print(
              "✅ [Driver Dashboard] Added conversation for order $orderId - UnreadCount: $unreadCount");
        } else {
          print(
              "🚫 [Driver Dashboard] Skipping conversation $conversationId - current user is not driver");
        }
      } catch (e) {
        print(
            '❌ [Driver Dashboard] Error processing conversation ${doc.id}: $e');
      }
    }

    print(
        "✅ [Driver Dashboard] Total unread messages for driver: $totalUnreadCount");

    if (mounted) {
      setState(() {
        _unreadMessageCount = totalUnreadCount;
      });
    }
  }

  // Load read announcement IDs from SharedPreferences
  Future<void> _loadReadAnnouncementIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final readIds = prefs.getStringList('read_announcement_ids_driver') ?? [];
      if (mounted) {
        setState(() {
          _readAnnouncementIds = readIds.toSet();
        });
      }
    } catch (e) {
      print('Error loading read announcement IDs: $e');
    }
  }

  // Save read announcement IDs to SharedPreferences
  Future<void> _saveReadAnnouncementIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
          'read_announcement_ids_driver', _readAnnouncementIds.toList());
    } catch (e) {
      print('Error saving read announcement IDs: $e');
    }
  }

  // Mark all announcements as read
  Future<void> _markAllAnnouncementsAsRead() async {
    bool hasNewReads = false;
    for (final announcement in _announcements) {
      final id = announcement['id'] as String? ?? '';
      if (id.isNotEmpty && !_readAnnouncementIds.contains(id)) {
        _readAnnouncementIds.add(id);
        hasNewReads = true;
      }
    }

    if (hasNewReads) {
      setState(() {});
      await _saveReadAnnouncementIds();
    }
  }

  // Get unread announcements count
  int get _unreadAnnouncementsCount {
    return _announcements.where((announcement) {
      final id = announcement['id'] as String? ?? '';
      return id.isNotEmpty && !_readAnnouncementIds.contains(id);
    }).length;
  }

  void _showAnnouncementDialog() {
    // Remove existing overlay if present
    _announcementOverlay?.remove();
    _announcementOverlay = null;

    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isDarkMode = themeService.isDarkMode;

    // Mark all announcements as read when popup is opened
    _markAllAnnouncementsAsRead();

    if (_announcements.isEmpty) {
      // Show simple snackbar for no announcements
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No notifications available',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor:
              isDarkMode ? const Color(0xFF2D2D3C) : Colors.black87,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    // Create overlay entry for popup
    _announcementOverlay = OverlayEntry(
      builder: (context) => _buildAnnouncementPopup(isDarkMode),
    );

    // Insert overlay
    Overlay.of(context).insert(_announcementOverlay!);
  }

  Widget _buildAnnouncementPopup(bool isDarkMode) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: _closeAnnouncementPopup,
        child: Container(
          color: Colors.black.withValues(alpha: 0.3),
          child: Stack(
            children: [
              // Positioned popup near notification icon
              Positioned(
                top: kToolbarHeight + 40, // Below app bar
                right: 16,
                child: GestureDetector(
                  onTap: () {}, // Prevent popup from closing when tapped
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.85,
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.7,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
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
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: isDarkMode
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : AppTheme.lightBorderColor,
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.notifications,
                                color: isDarkMode
                                    ? AppColors.yellowAccent
                                    : AppTheme.lightPrimaryColor,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Driver Notifications',
                                  style: GoogleFonts.inter(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: isDarkMode
                                        ? Colors.white
                                        : AppTheme.lightTextPrimaryColor,
                                  ),
                                ),
                              ),
                              // Only show count badge if there are unread notifications
                              if (_unreadAnnouncementsCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDarkMode
                                        ? AppColors.yellowAccent
                                            .withValues(alpha: 0.2)
                                        : AppTheme.lightPrimaryColor
                                            .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$_unreadAnnouncementsCount',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isDarkMode
                                          ? AppColors.yellowAccent
                                          : AppTheme.lightPrimaryColor,
                                    ),
                                  ),
                                ),
                              if (_unreadAnnouncementsCount > 0)
                                const SizedBox(width: 8),
                              IconButton(
                                onPressed: _closeAnnouncementPopup,
                                icon: Icon(
                                  Icons.close,
                                  color: isDarkMode
                                      ? Colors.white.withValues(alpha: 0.7)
                                      : AppTheme.lightTextSecondaryColor,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Content
                        Flexible(
                          child: ListView.builder(
                            shrinkWrap: true,
                            padding: const EdgeInsets.all(16),
                            itemCount: _announcements.length,
                            itemBuilder: (context, index) {
                              final announcement = _announcements[index];
                              final announcementId =
                                  announcement['id'] as String? ?? '';
                              final isRead =
                                  _readAnnouncementIds.contains(announcementId);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : AppTheme.lightCardColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDarkMode
                                        ? Colors.white.withValues(alpha: 0.1)
                                        : AppTheme.lightBorderColor,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Blue dot for unread notifications
                                    Container(
                                      width: 8,
                                      height: 8,
                                      margin: const EdgeInsets.only(
                                          top: 6, right: 12),
                                      decoration: BoxDecoration(
                                        color: isRead
                                            ? Colors.transparent
                                            : Colors.blue,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            announcement['title'] ?? 'No title',
                                            style: GoogleFonts.inter(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: isDarkMode
                                                  ? Colors.white
                                                  : AppTheme
                                                      .lightTextPrimaryColor,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            announcement['message'] ??
                                                'No message',
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              color: isDarkMode
                                                  ? Colors.white
                                                      .withValues(alpha: 0.8)
                                                  : AppTheme
                                                      .lightTextSecondaryColor,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            _formatAnnouncementDate(
                                                announcement['createdAt']),
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: isDarkMode
                                                  ? Colors.white
                                                      .withValues(alpha: 0.6)
                                                  : AppTheme
                                                      .lightTextSecondaryColor
                                                      .withOpacity(0.7),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        // Close button
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _closeAnnouncementPopup,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.yellowAccent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                                padding: EdgeInsets.zero,
                              ),
                              child: Text(
                                'Close',
                                style: GoogleFonts.albertSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
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
  }

  void _closeAnnouncementPopup() {
    _announcementOverlay?.remove();
    _announcementOverlay = null;
  }

  String _formatAnnouncementDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown date';

    try {
      DateTime dateTime;
      if (timestamp is Timestamp) {
        dateTime = timestamp.toDate();
      } else if (timestamp is String) {
        dateTime = DateTime.parse(timestamp);
      } else {
        return 'Unknown date';
      }

      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 0) {
        return '${difference.inDays} days ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hours ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minutes ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Unknown date';
    }
  }

  String _formatEarnings(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    } else {
      return amount.toStringAsFixed(0);
    }
  }

  void _showMenuOptions() {
    if (!mounted || _menuKey.currentContext == null) return;

    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isDarkMode = themeService.isDarkMode;

    try {
      final RenderBox? renderBox =
          _menuKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null || !renderBox.attached) return;

      final position = renderBox.localToGlobal(Offset.zero);

      showMenu<String>(
        context: context,
        position: RelativeRect.fromLTRB(
          position.dx - 150,
          position.dy + 40,
          position.dx,
          position.dy + 200,
        ),
        color: isDarkMode ? const Color(0xFF2D2D3C) : AppTheme.lightCardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.2)
                : AppTheme.lightBorderColor,
            width: 1,
          ),
        ),
        elevation: 8,
        items: [
          PopupMenuItem<String>(
            value: 'switch_to_user',
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? AppColors.yellowAccent.withValues(alpha: 0.1)
                        : AppTheme.lightPrimaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.swap_horiz,
                    color: isDarkMode
                        ? AppColors.yellowAccent
                        : AppTheme.lightPrimaryColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Switch to User',
                  style: GoogleFonts.albertSans(
                    color: isDarkMode ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'logout',
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.red.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.logout,
                    color: Colors.red,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Logout',
                  style: GoogleFonts.albertSans(
                    color: Colors.red,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ).then((value) async {
        // Handle menu selection
        if (value != null && mounted) {
          if (value == 'switch_to_user') {
            // Save user mode preference
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('user_mode', 'user');

            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const HomeScreen(),
              ),
            );
          } else if (value == 'logout') {
            // Add a small delay to ensure menu is closed before showing logout dialog
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                _handleLogout();
              }
            });
          }
        }
      });
    } catch (e) {
      debugPrint('Error showing menu: $e');
    }
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
          appBar: null,
          backgroundColor: isDarkMode
              ? const Color(0xFF1E1E2C)
              : AppTheme.lightBackgroundColor,
          body: Container(
            key: const ValueKey('driver_main_container'),
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                _buildDashboard(isTablet, isDarkMode),
                const DriverAcceptOrderScreen(
                    key: PageStorageKey('driver_accept_screen')),
                const DriverOrdersScreen(
                    key: PageStorageKey('driver_orders_screen')),
                const DriverProfileScreen(
                    key: PageStorageKey('driver_profile_screen')),
              ],
            ),
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: isDarkMode
                      ? Colors.black.withOpacity(0.3)
                      : AppTheme.lightPrimaryColor.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: CurvedNavigationBar(
              key: const ValueKey('driver_professional_bottom_nav'),
              backgroundColor: isDarkMode
                  ? const Color(0xFF1E1E2C)
                  : AppTheme.lightBackgroundColor,
              color: isDarkMode
                  ? const Color(0xFF2D2D3C)
                  : AppTheme.lightPrimaryColor,
              buttonBackgroundColor: isDarkMode
                  ? const Color(0xFF2D2D3C)
                  : AppTheme.lightCardColor,
              height: 65,
              animationDuration: const Duration(milliseconds: 300),
              animationCurve: Curves.easeInOutCubic,
              index: _selectedIndex,
              onTap: (index) {
                if (!mounted) return;

                HapticFeedback.lightImpact();
                if (mounted) {
                  setState(() {
                    _selectedIndex = index;
                  });
                }
              },
              items: [
                _buildNavIcon(Icons.home_rounded, 0, isDarkMode),
                _buildNavIcon(Icons.local_shipping_rounded, 1, isDarkMode),
                _buildNavIcon(Icons.assignment_rounded, 2, isDarkMode),
                _buildNavIcon(Icons.person_rounded, 3, isDarkMode),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavIcon(IconData icon, int index, bool isDarkMode) {
    final isSelected = _selectedIndex == index;
    final isOrdersTab = index == 2; // Orders tab
    final showBadge = isOrdersTab && _unreadMessageCount > 0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDarkMode
                    ? AppColors.yellowAccent
                    : AppTheme.lightPrimaryColor)
                : Colors.transparent,
            shape: BoxShape.circle,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: isDarkMode
                          ? AppColors.yellowAccent.withOpacity(0.6)
                          : AppTheme.lightPrimaryColor.withOpacity(0.3),
                      blurRadius: isDarkMode ? 15 : 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            size: 26,
            color: isSelected
                ? (isDarkMode ? Colors.black : AppTheme.lightCardColor)
                : (isDarkMode ? Colors.white : AppTheme.lightCardColor),
          ),
        ),
        // Unread message badge
        if (showBadge)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red, Colors.red.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.4),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              constraints: const BoxConstraints(
                minWidth: 20,
                minHeight: 20,
              ),
              child: Text(
                _unreadMessageCount > 99
                    ? '99+'
                    : _unreadMessageCount.toString(),
                style: GoogleFonts.albertSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDashboard(bool isTablet, bool isDarkMode) {
    return Column(
      children: [
        // Header - Full width like reference screens
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

                  // Announcement Banner
                  _buildAnnouncementBanner(isTablet, isDarkMode),

                  const SizedBox(height: 24),

                  // Shift Status
                  _buildShiftStatus(isTablet, isDarkMode),

                  const SizedBox(height: 24),

                  // Today's Summary
                  _buildTodaysSummary(isTablet, isDarkMode),

                  const SizedBox(height: 24),

                  // Quick Actions
                  _buildQuickActions(isTablet, isDarkMode),

                  const SizedBox(height: 24),

                  // AI Suggestions
                  _buildAISuggestions(isTablet, isDarkMode),

                  const SizedBox(
                      height: 100), // Extra space for bottom navigation
                ],
              ),
            ),
          ),
        ),
      ],
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
              // Title with greeting
              Text(
                _isLoadingUserData ? 'Driver Dashboard' : 'Welcome, $_userName',
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 28 : 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),

              Row(
                children: [
                  // Notifications
                  GestureDetector(
                    onTap: _showAnnouncementDialog,
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Stack(
                        children: [
                          Icon(
                            Icons.notifications_outlined,
                            size: isTablet ? 24 : 20,
                            color: Colors.white,
                          ),
                          // Notification badge for announcements
                          if (_unreadAnnouncementsCount > 0 &&
                              !_isLoadingAnnouncements)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    _unreadAnnouncementsCount > 9
                                        ? '9+'
                                        : _unreadAnnouncementsCount.toString(),
                                    style: GoogleFonts.albertSans(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Menu button
                  GestureDetector(
                    key: _menuKey,
                    onTap: _showMenuOptions,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.more_vert,
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
    );
  }

  Widget _buildAnnouncementBanner(bool isTablet, bool isDarkMode) {
    // If loading announcements, show loading state
    if (_isLoadingAnnouncements) {
      return SlideTransition(
        position: _slideAnimation,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(isTablet ? 28 : 24),
          decoration: BoxDecoration(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.1)
                : AppTheme.lightPrimaryColor,
            borderRadius: BorderRadius.circular(20),
            border: isDarkMode
                ? Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1,
                  )
                : null,
            boxShadow: isDarkMode
                ? null
                : [
                    BoxShadow(
                      color: AppTheme.lightPrimaryColor.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
          ),
          child: Row(
            children: [
              Container(
                width: isTablet ? 72 : 64,
                height: isTablet ? 72 : 64,
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? AppColors.yellowAccent.withValues(alpha: 0.2)
                      : AppTheme.lightCardColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const CircularProgressIndicator(),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  'Loading driver notifications...',
                  style: GoogleFonts.inter(
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.white : AppTheme.lightCardColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // If no announcements, show default content
    if (_announcements.isEmpty) {
      return SlideTransition(
        position: _slideAnimation,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(isTablet ? 28 : 24),
          decoration: BoxDecoration(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.1)
                : AppTheme.lightPrimaryColor,
            borderRadius: BorderRadius.circular(20),
            border: isDarkMode
                ? Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1,
                  )
                : null,
            boxShadow: isDarkMode
                ? null
                : [
                    BoxShadow(
                      color: AppTheme.lightPrimaryColor.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
          ),
          child: Row(
            children: [
              Container(
                width: isTablet ? 72 : 64,
                height: isTablet ? 72 : 64,
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? AppColors.yellowAccent.withValues(alpha: 0.2)
                      : AppTheme.lightCardColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.local_shipping_rounded,
                  color: isDarkMode
                      ? AppColors.yellowAccent
                      : AppTheme.lightCardColor,
                  size: isTablet ? 36 : 32,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ready to Drive',
                      style: GoogleFonts.inter(
                        fontSize: isTablet ? 18 : 16,
                        fontWeight: FontWeight.bold,
                        color:
                            isDarkMode ? Colors.white : AppTheme.lightCardColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your route to success starts here',
                      style: GoogleFonts.inter(
                        fontSize: isTablet ? 14 : 12,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.9)
                            : AppTheme.lightCardColor.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Display announcement carousel
    final currentAnnouncement = _announcements[_currentAnnouncementIndex];
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(isTablet ? 28 : 24),
        decoration: BoxDecoration(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : AppTheme.lightPrimaryColor,
          borderRadius: BorderRadius.circular(20),
          border: isDarkMode
              ? Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                )
              : null,
          boxShadow: isDarkMode
              ? null
              : [
                  BoxShadow(
                    color: AppTheme.lightPrimaryColor.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
        ),
        child: SlideTransition(
          position: _announcementSlideAnimation,
          child: FadeTransition(
            opacity: _announcementFadeAnimation,
            child: Row(
              children: [
                Container(
                  width: isTablet ? 72 : 64,
                  height: isTablet ? 72 : 64,
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? AppColors.yellowAccent.withValues(alpha: 0.2)
                        : AppTheme.lightCardColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.campaign_rounded, // Announcement icon
                    color: isDarkMode
                        ? AppColors.yellowAccent
                        : AppTheme.lightCardColor,
                    size: isTablet ? 36 : 32,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              currentAnnouncement['title'] ??
                                  'Driver Announcement',
                              style: GoogleFonts.inter(
                                fontSize: isTablet ? 18 : 16,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode
                                    ? Colors.white
                                    : AppTheme.lightCardColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Carousel indicator
                          if (_announcements.length > 1)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? Colors.white.withValues(alpha: 0.2)
                                    : AppTheme.lightCardColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_currentAnnouncementIndex + 1}/${_announcements.length}',
                                style: GoogleFonts.inter(
                                  fontSize: isTablet ? 10 : 9,
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode
                                      ? Colors.white.withValues(alpha: 0.8)
                                      : AppTheme.lightCardColor
                                          .withOpacity(0.8),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        currentAnnouncement['message'] ?? 'No message',
                        style: GoogleFonts.inter(
                          fontSize: isTablet ? 14 : 12,
                          fontWeight: FontWeight.w500,
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.9)
                              : AppTheme.lightCardColor.withOpacity(0.9),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShiftStatus(bool isTablet, bool isDarkMode) {
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
        child: Row(
          children: [
            // Status indicator
            Container(
              width: isTablet ? 64 : 56,
              height: isTablet ? 64 : 56,
              decoration: BoxDecoration(
                color: _isOnShift ? Colors.green : Colors.grey,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (_isOnShift ? Colors.green : Colors.grey)
                        .withValues(alpha: 0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                _isOnShift ? Icons.work : Icons.work_off,
                color: Colors.white,
                size: isTablet ? 32 : 28,
              ),
            ),

            const SizedBox(width: 16),

            // Status text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isOnShift ? 'You are ON SHIFT' : 'You are OFF SHIFT',
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 18 : 16,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isOnShift
                        ? 'Ready to accept jobs'
                        : 'Start shift to receive jobs',
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 14 : 12,
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.7)
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Toggle button
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _isOnShift = !_isOnShift;
                });
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? AppColors.yellowAccent
                      : AppTheme.lightPrimaryColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: isDarkMode
                          ? AppColors.yellowAccent.withValues(alpha: 0.4)
                          : AppTheme.lightPrimaryColor.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  _isOnShift ? 'End Shift' : 'Start Shift',
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 14 : 12,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.black : Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodaysSummary(bool isTablet, bool isDarkMode) {
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
              children: [
                Icon(
                  Icons.today,
                  color: isDarkMode
                      ? AppColors.yellowAccent
                      : AppTheme.lightPrimaryColor,
                  size: isTablet ? 24 : 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Today\'s Summary',
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Jobs Completed',
                    _isLoadingTodaysData ? '...' : '$_todaysJobs',
                    Icons.check_circle,
                    Colors.green,
                    isTablet,
                    isDarkMode,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryItem(
                    'Earnings',
                    _isLoadingTodaysData
                        ? '...'
                        : 'Rs. ${_formatEarnings(_todaysEarnings)}',
                    Icons.account_balance_wallet,
                    isDarkMode
                        ? AppColors.yellowAccent
                        : AppTheme.lightPrimaryColor,
                    isTablet,
                    isDarkMode,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(bool isTablet, bool isDarkMode) {
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
              children: [
                Icon(
                  Icons.flash_on,
                  color: isDarkMode
                      ? AppColors.yellowAccent
                      : AppTheme.lightPrimaryColor,
                  size: isTablet ? 24 : 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Quick Actions',
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionButton(
                    'View Orders',
                    Icons.list_alt,
                    () {
                      setState(() {
                        _selectedIndex =
                            2; // Changed from 1 to 2 to match DriverOrdersScreen
                      });
                    },
                    isTablet,
                    isDarkMode,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionButton(
                    'Live Map',
                    Icons.map,
                    () {
                      setState(() {
                        _selectedIndex =
                            1; // Changed from 2 to 1 to match DriverAcceptOrderScreen
                      });
                    },
                    isTablet,
                    isDarkMode,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionButton(
                    'Earnings',
                    Icons.account_balance_wallet,
                    () {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                DriverEarningsScreen(driverId: user.uid),
                          ),
                        );
                      }
                    },
                    isTablet,
                    isDarkMode,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionButton(
                    'Support',
                    Icons.help_outline,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const DriverHelpScreen()),
                    ),
                    isTablet,
                    isDarkMode,
                  ),
                ),
              ],
            ),
          ],
        ),
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
              children: [
                Icon(
                  Icons.psychology_outlined,
                  color: isDarkMode
                      ? AppColors.yellowAccent
                      : AppTheme.lightPrimaryColor,
                  size: isTablet ? 24 : 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'AI Recommendations',
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSuggestionItem(
              'Best shift time: 8:00 AM - 6:00 PM',
              'Based on your historical earnings',
              Icons.access_time,
              isTablet,
              isDarkMode,
            ),
            const SizedBox(height: 12),
            _buildSuggestionItem(
              'Heavy traffic expected on Main Street',
              'Consider alternative routes',
              Icons.traffic,
              isTablet,
              isDarkMode,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String title, String value, IconData icon,
      Color color, bool isTablet, bool isDarkMode) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 16 : 12),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: isTablet ? 20 : 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 12 : 10,
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.7)
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
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
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(String title, IconData icon,
      VoidCallback onTap, bool isTablet, bool isDarkMode) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: EdgeInsets.all(isTablet ? 16 : 12),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.transparent : AppTheme.lightPrimaryColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDarkMode
                ? AppColors.yellowAccent
                : AppTheme.lightPrimaryColor,
            width: 2,
          ),
          boxShadow: isDarkMode
              ? null
              : [
                  BoxShadow(
                    color: AppTheme.lightPrimaryColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          children: [
            Icon(icon,
                color: isDarkMode ? AppColors.yellowAccent : Colors.white,
                size: isTablet ? 24 : 20),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 12 : 10,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? AppColors.yellowAccent : Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionItem(String title, String subtitle, IconData icon,
      bool isTablet, bool isDarkMode) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: isDarkMode
            ? AppColors.yellowAccent.withValues(alpha: 0.1)
            : AppTheme.lightPrimaryColor.withValues(alpha: 0.1),
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
          Icon(icon,
              color: isDarkMode
                  ? AppColors.yellowAccent
                  : AppTheme.lightPrimaryColor,
              size: isTablet ? 20 : 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 14 : 12,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 12 : 10,
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.7)
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
