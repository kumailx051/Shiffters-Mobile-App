import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'package:shiffters/theme/app_colors.dart';
import 'package:shiffters/theme/app_theme.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:shiffters/screens/user/profile_screen.dart';
import 'package:shiffters/screens/user/orders_screen.dart';
import 'package:shiffters/screens/user/shifting/addLocation_screen.dart';
import 'package:shiffters/screens/User/chat_bot.dart';
import 'package:shiffters/screens/User/message_screen.dart';
import 'package:shiffters/screens/User/FAQs.dart';
import 'package:shiffters/screens/User/Help_and_support_screen.dart';
import 'package:shiffters/screens/Driver/become_driver_screen.dart';
import 'package:shiffters/screens/User/pickupndrop/pickup_drop_screen.dart';
import 'package:shiffters/utils/navigation_utils.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:shiffters/services/theme_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shiffters/screens/Driver/application_submitted_screen.dart';
import 'package:shiffters/screens/Driver/driver_dashboard.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _animationController;
  late AnimationController _botPopupController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _botPopupOpacity;
  late Animation<Offset> _botPopupSlide;

  int _selectedIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  bool _showBotPopup = false;
  Timer? _botPopupTimer;
  final GlobalKey _menuKey = GlobalKey();

  // Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _orders = [];
  bool _isLoadingOrders = true;
  StreamSubscription<QuerySnapshot>? _ordersSubscription;

  // Driver application status
  String? _driverApplicationStatus;
  bool _isLoadingDriverStatus = true;

  // Announcements
  List<Map<String, dynamic>> _announcements = [];
  bool _isLoadingAnnouncements = true;
  int _currentAnnouncementIndex = 0;
  Timer? _announcementTimer;
  StreamSubscription<QuerySnapshot>? _announcementSubscription;
  Set<String> _readAnnouncementIds = {};
  OverlayEntry? _announcementOverlay;

  // Message notifications
  int _unreadMessageCount = 0;
  StreamSubscription<QuerySnapshot>? _messageSubscription;

  // Announcement animation controllers
  late AnimationController _announcementController;
  late Animation<double> _announcementFadeAnimation;
  late Animation<Offset> _announcementSlideAnimation;
  bool _isAnimatingAnnouncement = false;

  @override
  void initState() {
    super.initState();

    _initializeAnimations();
    _startAnimations();
    _startBotPopupTimer();
    _setupOrdersListener(); // Changed from _fetchOrders to real-time listener
    _checkDriverApplicationStatus();
    _loadReadAnnouncementIds();
    _setupAnnouncementListener();
    _setupMessageListener();

    // Add lifecycle observer
    WidgetsBinding.instance.addObserver(this);

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

  // Safe method to get data from Firestore document
  T? _safeGet<T>(Map<String, dynamic> data, String key, [T? defaultValue]) {
    try {
      if (data.containsKey(key) && data[key] != null) {
        return data[key] as T;
      }
      return defaultValue;
    } catch (e) {
      print('Error getting $key: $e');
      return defaultValue;
    }
  }

  // Safe method to get list from Firestore (handles both List and Map)
  List<String> _safeGetList(Map<String, dynamic> data, String key) {
    try {
      if (data.containsKey(key) && data[key] != null) {
        final value = data[key];
        if (value is List) {
          return value.map((e) => e.toString()).toList();
        } else if (value is Map) {
          return value.values.map((e) => e.toString()).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error getting list $key: $e');
      return [];
    }
  }

  // Helper method to truncate address at word boundaries
  String _truncateAddress(String address, int maxLength) {
    if (address.length <= maxLength) {
      return address;
    }

    // Find the last space before maxLength
    int lastSpaceIndex = address.lastIndexOf(' ', maxLength);

    // If no space found or too close to beginning, just truncate
    if (lastSpaceIndex == -1 || lastSpaceIndex < maxLength ~/ 2) {
      return '${address.substring(0, maxLength)}...';
    }

    return '${address.substring(0, lastSpaceIndex)}...';
  }

  // Setup real-time orders listener
  void _setupOrdersListener() {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      print("❌ No user logged in");
      if (mounted) {
        setState(() {
          _orders = [];
          _isLoadingOrders = false;
        });
      }
      return;
    }

    print("✅ Setting up real-time orders listener for UID: ${currentUser.uid}");

    // Cancel existing subscription if any
    _ordersSubscription?.cancel();

    setState(() {
      _isLoadingOrders = true;
    });

    try {
      _ordersSubscription = _firestore
          .collection('orders')
          .where('uid', isEqualTo: currentUser.uid)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots()
          .listen(
        (QuerySnapshot querySnapshot) {
          print(
              "✅ Real-time update: Found ${querySnapshot.docs.length} orders");

          List<Map<String, dynamic>> orders = [];
          for (var doc in querySnapshot.docs) {
            try {
              Map<String, dynamic> orderData =
                  doc.data() as Map<String, dynamic>;
              orderData['id'] = doc.id;
              orders.add(orderData);
              print(
                  "✅ Real-time order: ${doc.id}, Status: ${orderData['status']}, UID: ${orderData['uid']}");
            } catch (e) {
              print('Error processing real-time document ${doc.id}: $e');
              continue;
            }
          }

          print("✅ Real-time total orders processed: ${orders.length}");

          if (mounted) {
            setState(() {
              _orders = orders;
              _isLoadingOrders = false;
            });
          }
        },
        onError: (error) {
          print('❌ Real-time orders error: $error');

          // If it's an index error, try without orderBy as a fallback
          if (error.toString().contains('index') ||
              error.toString().contains('failed-precondition')) {
            print("🔧 Trying fallback real-time query without orderBy...");

            _ordersSubscription?.cancel();
            _ordersSubscription = _firestore
                .collection('orders')
                .where('uid', isEqualTo: currentUser.uid)
                .limit(5)
                .snapshots()
                .listen(
              (QuerySnapshot querySnapshot) {
                print(
                    "🔧 Fallback real-time update: Found ${querySnapshot.docs.length} orders");

                List<Map<String, dynamic>> orders = [];
                for (var doc in querySnapshot.docs) {
                  try {
                    Map<String, dynamic> orderData =
                        doc.data() as Map<String, dynamic>;
                    orderData['id'] = doc.id;
                    orders.add(orderData);
                  } catch (e) {
                    print(
                        'Error processing fallback real-time document ${doc.id}: $e');
                    continue;
                  }
                }

                // Sort orders manually since we can't use orderBy
                orders.sort((a, b) {
                  try {
                    final timestampA = a['createdAt'];
                    final timestampB = b['createdAt'];

                    if (timestampA == null && timestampB == null) return 0;
                    if (timestampA == null) return 1;
                    if (timestampB == null) return -1;

                    DateTime dateA = timestampA is Timestamp
                        ? timestampA.toDate()
                        : DateTime.parse(timestampA.toString());
                    DateTime dateB = timestampB is Timestamp
                        ? timestampB.toDate()
                        : DateTime.parse(timestampB.toString());

                    return dateB.compareTo(dateA); // Newest first
                  } catch (e) {
                    return 0;
                  }
                });

                if (mounted) {
                  setState(() {
                    _orders = orders;
                    _isLoadingOrders = false;
                  });
                }
              },
              onError: (fallbackError) {
                print("❌ Fallback real-time query also failed: $fallbackError");
                if (mounted) {
                  setState(() {
                    _isLoadingOrders = false;
                  });
                }
              },
            );
          } else {
            if (mounted) {
              setState(() {
                _isLoadingOrders = false;
              });
            }
          }
        },
      );
    } catch (e) {
      print('❌ Error setting up real-time listener: $e');
      if (mounted) {
        setState(() {
          _isLoadingOrders = false;
        });
      }
    }
  }

  // Get progress percentage based on status
  double _getProgressPercentage(String status) {
    switch (status.toLowerCase()) {
      case 'started':
        return 0.25; // 25%
      case 'picked_up':
      case 'pickedup':
        return 0.50; // 50%
      case 'in_transit':
      case 'in transit':
        return 0.75; // 75%
      case 'delivered':
      case 'completed':
        return 1.0; // 100%
      case 'confirmed':
      case 'pending':
        return 0.0; // 0%
      default:
        return 0.0;
    }
  }

  // Get status color
  Color _getStatusColor(String status, bool isDarkMode) {
    switch (status.toLowerCase()) {
      case 'started':
        return Colors.orange;
      case 'picked_up':
      case 'pickedup':
        return Colors.blue;
      case 'in_transit':
      case 'in transit':
        return Colors.purple;
      case 'delivered':
      case 'completed':
        return Colors.green;
      case 'confirmed':
      case 'pending':
        return Colors.grey;
      default:
        return isDarkMode ? Colors.grey : Colors.grey.shade600;
    }
  }

  // Check driver application status from Firestore
  Future<void> _checkDriverApplicationStatus() async {
    try {
      setState(() {
        _isLoadingDriverStatus = true;
      });

      final User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot driverDoc =
            await _firestore.collection('drivers').doc(user.uid).get();

        if (mounted) {
          setState(() {
            if (driverDoc.exists) {
              final data = driverDoc.data() as Map<String, dynamic>?;
              _driverApplicationStatus = data?['applicationStatus'];
            } else {
              _driverApplicationStatus = null;
            }
            _isLoadingDriverStatus = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _driverApplicationStatus = null;
            _isLoadingDriverStatus = false;
          });
        }
      }
    } catch (e) {
      print('Error checking driver application status: $e');
      if (mounted) {
        setState(() {
          _driverApplicationStatus = null;
          _isLoadingDriverStatus = false;
        });
      }
    }
  }

  // Handle driver button tap based on application status
  void _handleDriverButtonTap() async {
    // Show loading if status is still being checked
    if (_isLoadingDriverStatus) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loading driver status...'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    if (_driverApplicationStatus == 'pending') {
      // Navigate to application submitted screen
      NavigationUtils.navigateWithSlide(
          context, const ApplicationSubmittedScreen());
    } else if (_driverApplicationStatus == 'approved') {
      // Save driver mode preference
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_mode', 'driver');

      // Navigate to driver dashboard
      NavigationUtils.navigateWithSlide(context, const DriverDashboard());
    } else {
      // No application or rejected - navigate to become driver screen
      NavigationUtils.navigateWithSlide(context, const BecomeDriverScreen());
    }
  }

  // Announcement methods
  void _setupAnnouncementListener() {
    _announcementSubscription = _firestore
        .collection('announcements')
        .where('for', whereIn: ['All Users', 'all_users'])
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

  // Load read announcement IDs from SharedPreferences
  Future<void> _loadReadAnnouncementIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final readIds = prefs.getStringList('read_announcement_ids') ?? [];
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
          'read_announcement_ids', _readAnnouncementIds.toList());
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
      // Show modern snackbar for no announcements
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.notifications_off_outlined,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'No notifications available',
                style: GoogleFonts.albertSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          backgroundColor:
              isDarkMode ? const Color(0xFF2D2D3C) : const Color(0xFF1E88E5),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.all(16),
          elevation: 8,
        ),
      );
      return;
    }

    // Create overlay entry for popup with animation
    _announcementOverlay = OverlayEntry(
      builder: (context) => _buildModernAnnouncementPopup(isDarkMode),
    );

    // Insert overlay
    Overlay.of(context).insert(_announcementOverlay!);
  }

  Widget _buildModernAnnouncementPopup(bool isDarkMode) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOut, // Use a simpler curve to avoid layout issues
      builder: (context, animation, child) {
        return Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: _closeAnnouncementPopup,
            child: Container(
              color: Colors.black.withOpacity(0.3 * animation),
              child: Stack(
                children: [
                  // Positioned popup coming from notification icon
                  Positioned(
                    top: kToolbarHeight +
                        20, // Fixed position to avoid layout jumps
                    right: _unreadMessageCount > 0
                        ? 70 // Account for message badge with smaller offset to move popup more to the right
                        : 48, // Position over notification icon - closer to the right edge of the screen
                    child: Transform.scale(
                      scale: animation, // Simpler scale animation
                      alignment: Alignment.topRight,
                      child: Opacity(
                        opacity: animation,
                        child: GestureDetector(
                          onTap:
                              () {}, // Prevent popup from closing when tapped
                          child: Stack(
                            children: [
                              // Main popup container
                              Container(
                                width: MediaQuery.of(context).size.width * 0.85,
                                margin: const EdgeInsets.only(
                                    top: 8,
                                    right: 0), // Adjusted space for the pointer
                                constraints: BoxConstraints(
                                  maxHeight:
                                      MediaQuery.of(context).size.height * 0.75,
                                  maxWidth: 380,
                                ),
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? const Color(0xFF2D2D3C)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.25),
                                      blurRadius: 25,
                                      offset: const Offset(0, 10),
                                      spreadRadius: 0,
                                    ),
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5),
                                      spreadRadius: 0,
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Modern header with gradient
                                    Container(
                                      padding: const EdgeInsets.all(20),
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
                                          topLeft: Radius.circular(20),
                                          topRight: Radius.circular(20),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color:
                                                  Colors.white.withOpacity(0.2),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Icon(
                                              Icons.notifications_rounded,
                                              color: Colors.white,
                                              size: 24,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Notifications',
                                                  style: GoogleFonts.albertSans(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                Text(
                                                  '${_announcements.length} ${_announcements.length == 1 ? 'notification' : 'notifications'}',
                                                  style: GoogleFonts.albertSans(
                                                    fontSize: 14,
                                                    color: Colors.white
                                                        .withOpacity(0.8),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: _closeAnnouncementPopup,
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.white
                                                    .withOpacity(0.2),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                Icons.close_rounded,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Content with modern styling
                                    Flexible(
                                      child: ListView.builder(
                                        shrinkWrap: true,
                                        padding: const EdgeInsets.all(20),
                                        itemCount: _announcements.length,
                                        itemBuilder: (context, index) {
                                          final announcement =
                                              _announcements[index];
                                          final title = announcement['title']
                                                  as String? ??
                                              'No Title';
                                          final message =
                                              announcement['message']
                                                      as String? ??
                                                  'No Message';
                                          final createdAt =
                                              announcement['createdAt'];
                                          final announcementId =
                                              announcement['id'] as String? ??
                                                  '';
                                          final isRead =
                                              announcementId.isNotEmpty &&
                                                  _readAnnouncementIds
                                                      .contains(announcementId);

                                          return Container(
                                            margin: const EdgeInsets.only(
                                                bottom: 16),
                                            padding: const EdgeInsets.all(20),
                                            decoration: BoxDecoration(
                                              color: isDarkMode
                                                  ? Colors.white
                                                      .withOpacity(0.05)
                                                  : const Color(0xFFF8F9FA),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: Border.all(
                                                color: isDarkMode
                                                    ? Colors.white
                                                        .withOpacity(0.1)
                                                    : const Color(0xFFE3F2FD),
                                                width: 1,
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    if (!isRead)
                                                      Container(
                                                        width: 10,
                                                        height: 10,
                                                        margin: const EdgeInsets
                                                            .only(
                                                            right: 12, top: 2),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: isDarkMode
                                                              ? const Color(
                                                                  0xFFFDD835)
                                                              : const Color(
                                                                  0xFF1E88E5),
                                                          shape:
                                                              BoxShape.circle,
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: (isDarkMode
                                                                      ? const Color(
                                                                          0xFFFDD835)
                                                                      : const Color(
                                                                          0xFF1E88E5))
                                                                  .withOpacity(
                                                                      0.3),
                                                              blurRadius: 4,
                                                              spreadRadius: 1,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    if (isRead)
                                                      const SizedBox(width: 22),
                                                    Expanded(
                                                      child: Text(
                                                        title,
                                                        style: GoogleFonts
                                                            .albertSans(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: isDarkMode
                                                              ? Colors.white
                                                              : const Color(
                                                                  0xFF1A1A1A),
                                                        ),
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  message,
                                                  style: GoogleFonts.albertSans(
                                                    fontSize: 14,
                                                    color: isDarkMode
                                                        ? Colors.white
                                                            .withOpacity(0.8)
                                                        : const Color(
                                                            0xFF6B7280),
                                                    height: 1.5,
                                                  ),
                                                  maxLines: 4,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 12),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.schedule_rounded,
                                                      size: 14,
                                                      color: isDarkMode
                                                          ? Colors.white
                                                              .withOpacity(0.5)
                                                          : const Color(
                                                              0xFF9CA3AF),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      _formatAnnouncementDate(
                                                          createdAt),
                                                      style: GoogleFonts
                                                          .albertSans(
                                                        fontSize: 12,
                                                        color: isDarkMode
                                                            ? Colors.white
                                                                .withOpacity(
                                                                    0.5)
                                                            : const Color(
                                                                0xFF9CA3AF),
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Triangular pointer pointing to notification icon
                              Positioned(
                                top: 0,
                                right:
                                    35, // Adjusted 5px left to align with notification icon
                                child: CustomPaint(
                                  size: const Size(16,
                                      8), // Smaller size to avoid layout issues
                                  painter: TrianglePointerPainter(
                                    color: isDarkMode
                                        ? const Color(
                                            0xFF2D2D3C) // Match dark popup header
                                        : const Color(
                                            0xFF1E88E5), // Match light popup header gradient start
                                  ),
                                ),
                              ),
                            ],
                          ),
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

  // Message notification methods
  void _setupMessageListener() {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    print("✅ [Home Screen] Setting up message listener for user: ${user.uid}");

    _messageSubscription = _firestore
        .collection('conversations')
        .where('participants', arrayContains: user.uid)
        .snapshots()
        .listen((QuerySnapshot conversationSnapshot) async {
      int totalUnreadCount = 0;

      print(
          "🔍 [Home Screen] Found ${conversationSnapshot.docs.length} conversations");

      for (var conversationDoc in conversationSnapshot.docs) {
        try {
          final conversationData =
              conversationDoc.data() as Map<String, dynamic>;
          final conversationId = conversationDoc.id;

          print("🔍 [Home Screen] Processing conversation: $conversationId");

          // Check if current user was the driver for this conversation/order
          bool currentUserWasDriver = false;

          // First check if conversation has driverId field directly
          final String conversationDriverId =
              conversationData['driverId'] ?? '';
          if (conversationDriverId == user.uid) {
            currentUserWasDriver = true;
            print(
                "🚫 [Home Screen] Skipping conversation $conversationId - current user is driver in conversation");
          }

          // Also check the order document if orderId exists
          if (!currentUserWasDriver) {
            final String orderId = conversationData['orderId'] ?? '';
            if (orderId.isNotEmpty) {
              try {
                final orderDoc =
                    await _firestore.collection('orders').doc(orderId).get();
                if (orderDoc.exists) {
                  final orderData = orderDoc.data() as Map<String, dynamic>;
                  final String orderDriverId = orderData['driverId'] ?? '';

                  if (orderDriverId == user.uid) {
                    currentUserWasDriver = true;
                    print(
                        "🚫 [Home Screen] Skipping conversation $conversationId - current user was driver for order $orderId");
                  }
                }
              } catch (e) {
                print("⚠️ [Home Screen] Error checking order $orderId: $e");
              }
            }
          }

          // Skip this conversation if current user was the driver
          if (currentUserWasDriver) {
            print(
                "🚫 [Home Screen] FINAL SKIP: Conversation $conversationId skipped - user ${user.uid} was driver");
            continue;
          }

          // Get unread count for this conversation (only for customer conversations)
          final Map<String, dynamic> unreadCounts =
              conversationData['unreadCounts'] as Map<String, dynamic>? ?? {};
          final int unreadCount = unreadCounts[user.uid] as int? ?? 0;

          if (unreadCount > 0) {
            print(
                "✅ [Home Screen] Adding $unreadCount unread messages from conversation $conversationId");
          }

          totalUnreadCount += unreadCount;
        } catch (e) {
          print(
              '❌ [Home Screen] Error processing conversation ${conversationDoc.id}: $e');
        }
      }

      print("✅ [Home Screen] Total unread message count: $totalUnreadCount");

      if (mounted) {
        setState(() {
          _unreadMessageCount = totalUnreadCount;
        });
      }
    }, onError: (error) {
      print('❌ [Home Screen] Error listening to messages: $error');
    });
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _botPopupController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // Announcement animation controller
    _announcementController = AnimationController(
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

    _botPopupOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _botPopupController,
      curve: Curves.easeOut,
    ));

    _botPopupSlide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _botPopupController,
      curve: Curves.easeOutBack,
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

  void _startBotPopupTimer() {
    _botPopupTimer?.cancel();

    _botPopupTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showBotPopup = true;
        });
        if (mounted) {
          _botPopupController.forward();
        }

        Timer(const Duration(seconds: 3), () {
          if (mounted) {
            _botPopupController.reverse().then((_) {
              if (mounted) {
                setState(() {
                  _showBotPopup = false;
                });
              }
            });
          }
        });
      }
    });
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

      showMenu(
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
          PopupMenuItem(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? AppColors.yellowAccent.withOpacity(0.1)
                        : AppTheme.lightOrangeAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Image.asset(
                    'assets/icons/car.png',
                    width: 32,
                    height: 32,
                    fit: BoxFit.contain,
                    // Keep original colors by not applying any color filter
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _isLoadingDriverStatus
                      ? 'Loading...'
                      : _driverApplicationStatus == 'approved'
                          ? 'Switch to Driver'
                          : _driverApplicationStatus == 'pending'
                              ? 'View Application'
                              : 'Become a Driver',
                  style: GoogleFonts.inter(
                    color: isDarkMode
                        ? Colors.white
                        : AppTheme.lightTextPrimaryColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            onTap: () {
              if (mounted) {
                _handleDriverButtonTap();
              }
            },
          ),
          PopupMenuItem(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? AppColors.yellowAccent.withOpacity(0.1)
                        : AppTheme.lightPrimaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Image.asset(
                    'assets/icons/support.png',
                    width: 32,
                    height: 32,
                    fit: BoxFit.contain,
                    // Keep original colors by not applying any color filter
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Help & Support',
                  style: GoogleFonts.inter(
                    color: isDarkMode
                        ? Colors.white
                        : AppTheme.lightTextPrimaryColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            onTap: () {
              if (mounted) {
                NavigationUtils.navigateWithSlide(
                    context, const HelpAndSupportScreen());
              }
            },
          ),
          PopupMenuItem(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? AppColors.yellowAccent.withOpacity(0.1)
                        : AppTheme.lightGreenAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Image.asset(
                    'assets/icons/faq.png',
                    width: 32,
                    height: 32,
                    fit: BoxFit.contain,
                    // Keep original colors by not applying any color filter
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'FAQs',
                  style: GoogleFonts.inter(
                    color: isDarkMode
                        ? Colors.white
                        : AppTheme.lightTextPrimaryColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            onTap: () {
              if (mounted) {
                NavigationUtils.navigateWithSlide(context, const FAQsScreen());
              }
            },
          ),
        ],
      );
    } catch (e) {
      debugPrint('Error showing menu: $e');
    }
  }

  @override
  void dispose() {
    try {
      _botPopupTimer?.cancel();
      _announcementTimer?.cancel();
      _announcementSubscription?.cancel();
      _messageSubscription?.cancel();
      _ordersSubscription?.cancel(); // Cancel orders subscription
      _announcementOverlay?.remove();
      _animationController.dispose();
      _botPopupController.dispose();
      _announcementController.dispose();
      _searchController.dispose();
      _pickupController.dispose();
      _destinationController.dispose();
      // Remove lifecycle observer
      WidgetsBinding.instance.removeObserver(this);
    } catch (e) {
      debugPrint('Error during dispose: $e');
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Refresh driver status when app is resumed
      _refreshDriverStatus();
    }
  }

  // Refresh driver status when returning to screen
  void _refreshDriverStatus() {
    _checkDriverApplicationStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        final isDarkMode = themeService.isDarkMode;

        return Scaffold(
          backgroundColor:
              isDarkMode ? const Color(0xFF1E1E2C) : const Color(0xFFE8E8F0),
          body: IndexedStack(
            index: _selectedIndex,
            children: [
              _buildMainContentWithHeader(isDarkMode),
              const OrdersScreen(),
              const MessageScreen(),
              const ProfileScreen(),
            ],
          ),
          bottomNavigationBar: CurvedNavigationBar(
            key: const ValueKey('professional_bottom_nav'),
            backgroundColor: isDarkMode
                ? const Color(0xFF1E1E2C)
                : AppTheme.lightBackgroundColor,
            color: isDarkMode
                ? const Color(0xFF2D2D3C)
                : AppTheme.lightPrimaryColor,
            buttonBackgroundColor:
                isDarkMode ? const Color(0xFF2D2D3C) : AppTheme.lightCardColor,
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
              _buildNavIcon('assets/icons/home.png', 0, isDarkMode),
              _buildNavIcon('assets/icons/order.png', 1, isDarkMode),
              _buildNavIcon('assets/icons/chat.png', 2, isDarkMode),
              _buildNavIcon('assets/icons/profile.png', 3, isDarkMode),
            ],
          ),
          floatingActionButton:
              _selectedIndex == 0 ? _buildAIBotWidget(isDarkMode) : null,
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        );
      },
    );
  }

  Widget _buildNavIcon(String imagePath, int index, bool isDarkMode) {
    final isSelected = _selectedIndex == index;
    final isMessageIcon = index == 2; // Message icon is at index 2
    final showBadge = isMessageIcon && _unreadMessageCount > 0;

    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDarkMode
                    ? Colors.yellow.shade700
                    : AppTheme.lightPrimaryColor)
                : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(
              isSelected
                  ? (isDarkMode ? Colors.black : AppTheme.lightCardColor)
                  : Colors.white, // Make icons white
              BlendMode.srcIn,
            ),
            child: Image.asset(
              imagePath,
              width: 26,
              height: 26,
              fit: BoxFit.contain,
            ),
          ),
        ),
        // Badge for unread messages
        if (showBadge)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
                  width: 2,
                ),
              ),
              constraints: const BoxConstraints(
                minWidth: 20,
                minHeight: 20,
              ),
              child: Text(
                _unreadMessageCount > 99 ? '99+' : '$_unreadMessageCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAIBotWidget(bool isDarkMode) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_showBotPopup)
          SlideTransition(
            position: _botPopupSlide,
            child: FadeTransition(
              opacity: _botPopupOpacity,
              child: Container(
                margin: const EdgeInsets.only(bottom: 10, right: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? const Color(0xFF2D2D3C)
                      : Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                  border: isDarkMode
                      ? Border.all(
                          color: AppColors.yellowAccent.withValues(alpha: 0.3))
                      : Border.all(
                          color: AppTheme.lightPrimaryColor, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.smart_toy,
                      color: AppColors.yellowAccent,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Shiffters bot ready to help you',
                      style: GoogleFonts.albertSans(
                        color:
                            isDarkMode ? Colors.white : AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        GestureDetector(
          onTap: () {
            if (!mounted) return;
            HapticFeedback.lightImpact();
            NavigationUtils.navigateWithSlide(context, const ChatBotScreen());
          },
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: isDarkMode
                  ? AppColors.yellowAccent
                  : AppTheme.lightPrimaryColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: isDarkMode
                      ? AppColors.yellowAccent.withValues(alpha: 0.4)
                      : AppTheme.lightPrimaryColor.withValues(alpha: 0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Lottie.asset(
              'assets/animations/aibot.json',
              width: 40,
              height: 40,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMainContentWithHeader(bool isDarkMode) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return Column(
      children: [
        _buildHeader(isTablet, isDarkMode),
        Expanded(
          child: _buildMainContent(isDarkMode),
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
              Row(
                children: [
                  // Logo
                  Image.asset(
                    isDarkMode
                        ? 'assets/logo/darklogo.png'
                        : 'assets/logo/lightlogo.png',
                    width: isTablet ? 90 : 80,
                    height: isTablet ? 90 : 80,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 12),
                  // Welcome text
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Welcome to',
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 16 : 14,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      Text(
                        'Shiffters',
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 28 : 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  // Notification icon with badge for announcements
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _showAnnouncementDialog();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Stack(
                        children: [
                          Image.asset(
                            'assets/icons/bell.png',
                            width: isTablet ? 24 : 20,
                            height: isTablet ? 24 : 20,
                            fit: BoxFit.contain,
                            color: Colors.white, // Make bell icon white
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
                  // Message notification badge
                  if (_unreadMessageCount > 0)
                    Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color:
                            isDarkMode ? const Color(0xFFFDD835) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _unreadMessageCount > 99
                            ? '99+'
                            : _unreadMessageCount.toString(),
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 12 : 10,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode
                              ? Colors.black
                              : const Color(0xFF1E88E5),
                        ),
                      ),
                    ),
                  // Menu button
                  GestureDetector(
                    key: _menuKey,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _showMenuOptions();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Image.asset(
                        'assets/icons/menu.png',
                        width: isTablet ? 24 : 20,
                        height: isTablet ? 24 : 20,
                        fit: BoxFit.contain,
                        color: Colors.white, // Make menu icon white
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

  Widget _buildMainContent(bool isDarkMode) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 32 : 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            _buildPromoBanner(isTablet, isDarkMode),
            const SizedBox(height: 30),
            _buildTagline(isTablet, isDarkMode),
            const SizedBox(height: 25),
            _buildSearchBar(isTablet, isDarkMode),
            const SizedBox(height: 30),
            _buildServiceIcons(isTablet, isDarkMode),
            const SizedBox(height: 30),
            _buildOrdersSection(isTablet, isDarkMode),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildPromoBanner(bool isTablet, bool isDarkMode) {
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
                  'Loading announcements...',
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
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Image.asset(
                    'assets/icons/loudspeaker.png',
                    width: isTablet ? 56 : 48,
                    height: isTablet ? 56 : 48,
                    fit: BoxFit.contain,
                    // Keep original colors by not applying any color filter
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDarkMode
                          ? 'Speed picks up rapidly.'
                          : 'Premium Logistics',
                      style: GoogleFonts.inter(
                        fontSize: isTablet ? 18 : 16,
                        fontWeight: FontWeight.bold,
                        color:
                            isDarkMode ? Colors.white : AppTheme.lightCardColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    isDarkMode
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.yellowAccent,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.yellowAccent
                                      .withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              'First move, 30% off!',
                              style: GoogleFonts.albertSans(
                                fontSize: isTablet ? 12 : 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                          )
                        : Text(
                            'Solutions at Your Fingertips',
                            style: GoogleFonts.inter(
                              fontSize: isTablet ? 14 : 12,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.lightCardColor.withOpacity(0.9),
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
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Image.asset(
                      'assets/icons/loudspeaker.png',
                      width: isTablet ? 56 : 48,
                      height: isTablet ? 56 : 48,
                      fit: BoxFit.contain,
                      // Keep original colors by not applying any color filter
                    ),
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
                              currentAnnouncement['title'] ?? 'Announcement',
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

  Widget _buildTagline(bool isTablet, bool isDarkMode) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Text(
        isDarkMode
            ? 'Hawk-eye your deliveries with ease!'
            : 'Experience Premium Logistics Excellence',
        style: isDarkMode
            ? GoogleFonts.albertSans(
                fontSize: isTablet ? 20 : 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                shadows: [
                  Shadow(
                    offset: const Offset(0, 0),
                    blurRadius: 10,
                    color: AppColors.yellowAccent.withValues(alpha: 0.3),
                  ),
                ],
              )
            : GoogleFonts.inter(
                fontSize: isTablet ? 24 : 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.lightTextPrimaryColor,
                height: 1.2,
              ),
      ),
    );
  }

  Widget _buildSearchBar(bool isTablet, bool isDarkMode) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? null : AppTheme.lightCardColor,
          borderRadius: BorderRadius.circular(isDarkMode ? 25 : 16),
          border: isDarkMode
              ? null
              : Border.all(color: AppTheme.lightPrimaryColor, width: 1.5),
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
        child: TextFormField(
          controller: _searchController,
          style: isDarkMode
              ? GoogleFonts.albertSans(
                  fontSize: isTablet ? 16 : 14,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                )
              : GoogleFonts.inter(
                  fontSize: isTablet ? 16 : 14,
                  color: AppTheme.lightTextPrimaryColor,
                  fontWeight: FontWeight.w500,
                ),
          decoration: InputDecoration(
            hintText: isDarkMode
                ? 'Search services'
                : 'Search services, track packages...',
            hintStyle: isDarkMode
                ? GoogleFonts.albertSans(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w400,
                  )
                : GoogleFonts.inter(
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
                      color: AppTheme.lightPrimaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.search_rounded,
                      color: AppTheme.lightPrimaryColor,
                      size: isTablet ? 20 : 18,
                    ),
                  ),
            filled: true,
            fillColor: isDarkMode
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.transparent,
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
    );
  }

  Widget _buildServiceIcons(bool isTablet, bool isDarkMode) {
    return SlideTransition(
      position: _slideAnimation,
      child: Row(
        children: [
          Expanded(
            child: _buildServiceIcon(
              imagePath: 'assets/icons/shifting.png',
              title: 'Premium Shifting',
              onTap: () {
                HapticFeedback.lightImpact();
                NavigationUtils.navigateWithSlide(
                    context, const AddLocationScreen());
              },
              isTablet: isTablet,
              isDarkMode: isDarkMode,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildServiceIcon(
              imagePath: 'assets/icons/pickup.png',
              title: 'Express Pickup',
              onTap: () {
                HapticFeedback.lightImpact();
                NavigationUtils.navigateWithSlide(
                    context, const PickupDropScreen());
              },
              isTablet: isTablet,
              isDarkMode: isDarkMode,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceIcon({
    required String imagePath,
    required String title,
    required VoidCallback onTap,
    required bool isTablet,
    required bool isDarkMode,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: isTablet ? 32 : 28,
          horizontal: isTablet ? 20 : 16,
        ),
        decoration: BoxDecoration(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.08)
              : AppTheme.lightCardColor,
          borderRadius: BorderRadius.circular(isDarkMode ? 16 : 20),
          border: isDarkMode
              ? null
              : Border.all(color: AppTheme.lightPrimaryColor, width: 1.5),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: isTablet ? 72 : 64,
              height: isTablet ? 72 : 64,
              decoration: BoxDecoration(
                color: isDarkMode
                    ? AppColors.yellowAccent.withValues(alpha: 0.2)
                    : AppTheme.lightOrangeAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(18),
                border: isDarkMode
                    ? Border.all(
                        color: AppColors.yellowAccent.withValues(alpha: 0.3),
                        width: 1,
                      )
                    : null,
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Image.asset(
                  imagePath,
                  width: isTablet ? 48 : 40,
                  height: isTablet ? 48 : 40,
                  fit: BoxFit.contain,
                  // Keep original colors by not applying any color filter
                ),
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: Text(
                title,
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 14 : 13,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode
                      ? Colors.white
                      : AppTheme.lightTextPrimaryColor,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Fixed orders section with proper error handling
  Widget _buildOrdersSection(bool isTablet, bool isDarkMode) {
    return SlideTransition(
      position: _slideAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Orders',
                style: isDarkMode
                    ? GoogleFonts.albertSans(
                        fontSize: isTablet ? 18 : 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      )
                    : GoogleFonts.inter(
                        fontSize: isTablet ? 20 : 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.lightTextPrimaryColor,
                      ),
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _selectedIndex = 1;
                  });
                },
                child: Text(
                  'View All',
                  style: isDarkMode
                      ? GoogleFonts.albertSans(
                          fontSize: isTablet ? 14 : 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.yellowAccent,
                        )
                      : GoogleFonts.inter(
                          fontSize: isTablet ? 14 : 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.lightPrimaryColor,
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _isLoadingOrders
              ? _buildLoadingOrders(isTablet, isDarkMode)
              : _orders.isEmpty
                  ? _buildEmptyOrders(isTablet, isDarkMode)
                  : Column(
                      children: _orders
                          .take(3)
                          .map((order) =>
                              _buildOrderCard(order, isTablet, isDarkMode))
                          .toList(),
                    ),
        ],
      ),
    );
  }

  Widget _buildLoadingOrders(bool isTablet, bool isDarkMode) {
    return Column(
      children: List.generate(
        2,
        (index) => Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: EdgeInsets.all(isTablet ? 20 : 16),
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
                : Border.all(color: AppTheme.lightPrimaryColor, width: 1.5),
          ),
          child: Column(
            children: [
              Container(
                height: 16,
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 80,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.2)
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  Container(
                    width: 60,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.2)
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(6),
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

  Widget _buildEmptyOrders(bool isTablet, bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 32 : 24),
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
            : Border.all(color: AppTheme.lightPrimaryColor, width: 1.5),
      ),
      child: Column(
        children: [
          SizedBox(
            width: isTablet ? 120 : 100,
            height: isTablet ? 120 : 100,
            child: Lottie.asset(
              'assets/animations/noorder.json',
              fit: BoxFit.contain,
              repeat: true,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No orders yet',
            style: GoogleFonts.inter(
              fontSize: isTablet ? 18 : 16,
              fontWeight: FontWeight.w600,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.8)
                  : AppTheme.lightTextSecondaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your recent orders will appear here',
            style: GoogleFonts.inter(
              fontSize: isTablet ? 14 : 12,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.6)
                  : AppTheme.lightTextLightColor,
            ),
          ),
        ],
      ),
    );
  }

  // Fixed order card with safe data access
  Widget _buildOrderCard(
      Map<String, dynamic> order, bool isTablet, bool isDarkMode) {
    // Safely extract data with fallbacks
    final String orderId = _safeGet<String>(order, 'id', 'N/A') ?? 'N/A';
    final String status =
        _safeGet<String>(order, 'status', 'confirmed') ?? 'confirmed';
    final String orderType =
        _safeGet<String>(order, 'orderType', 'shifting') ?? 'shifting';
    final double totalAmount =
        (_safeGet<num>(order, 'totalAmount', 0) ?? 0).toDouble();

    // Safely get items list
    final List<String> items = _safeGetList(order, 'items');

    // Safely get pickup and drop locations from nested structure
    final pickupLocationData = order['pickupLocation'] as Map<String, dynamic>?;
    final dropoffLocationData =
        order['dropoffLocation'] as Map<String, dynamic>?;

    final String pickupAddress =
        pickupLocationData?['address']?.toString() ?? 'Pickup location';
    final String dropoffAddress =
        dropoffLocationData?['address']?.toString() ?? 'Drop location';

    final double progressPercentage = _getProgressPercentage(status);
    final Color statusColor = _getStatusColor(status, isDarkMode);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(isTablet ? 20 : 16),
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
            : Border.all(color: AppTheme.lightPrimaryColor, width: 1.5),
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
          // Order Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${orderId.length > 8 ? orderId.substring(0, 8).toUpperCase() : orderId.toUpperCase()}',
                      style: GoogleFonts.inter(
                        fontSize: isTablet ? 16 : 14,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode
                            ? Colors.white
                            : AppTheme.lightTextPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      orderType.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: isTablet ? 12 : 10,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode
                            ? AppColors.yellowAccent
                            : AppTheme.lightPrimaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor, width: 1),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: isTablet ? 10 : 9,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Progress Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Progress',
                style: GoogleFonts.inter(
                  fontSize: isTablet ? 12 : 11,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.8)
                      : AppTheme.lightTextSecondaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.2)
                      : AppTheme.lightBorderColor,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progressPercentage,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          statusColor,
                          statusColor.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(progressPercentage * 100).toInt()}% Complete',
                style: GoogleFonts.inter(
                  fontSize: isTablet ? 10 : 9,
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.6)
                      : AppTheme.lightTextLightColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Location Info
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'From',
                      style: GoogleFonts.inter(
                        fontSize: isTablet ? 12 : 10,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.8)
                            : AppTheme.lightTextSecondaryColor,
                      ),
                    ),
                    Text(
                      _truncateAddress(pickupAddress, 30),
                      style: GoogleFonts.inter(
                        fontSize: isTablet ? 11 : 10,
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.7)
                            : AppTheme.lightTextLightColor,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward,
                size: 16,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.5)
                    : AppTheme.lightTextLightColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'To',
                      style: GoogleFonts.inter(
                        fontSize: isTablet ? 12 : 10,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.8)
                            : AppTheme.lightTextSecondaryColor,
                      ),
                    ),
                    Text(
                      _truncateAddress(dropoffAddress, 30),
                      style: GoogleFonts.inter(
                        fontSize: isTablet ? 11 : 10,
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.7)
                            : AppTheme.lightTextLightColor,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Bottom Info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Items: ${items.length}',
                style: GoogleFonts.inter(
                  fontSize: isTablet ? 12 : 11,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.8)
                      : AppTheme.lightTextSecondaryColor,
                ),
              ),
              Text(
                'Rs ${totalAmount.toStringAsFixed(0)}',
                style: GoogleFonts.inter(
                  fontSize: isTablet ? 14 : 12,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode
                      ? AppColors.yellowAccent
                      : AppTheme.lightPrimaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Custom painter for triangular pointer
class TrianglePointerPainter extends CustomPainter {
  final Color color;

  TrianglePointerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return; // Safety check

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true; // Smoother rendering

    final path = Path();
    // Draw a triangle pointing upward
    path.moveTo(size.width / 2, 0); // Top center point
    path.lineTo(0, size.height); // Bottom left
    path.lineTo(size.width, size.height); // Bottom right
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant TrianglePointerPainter oldDelegate) {
    return color != oldDelegate.color;
  }
}
