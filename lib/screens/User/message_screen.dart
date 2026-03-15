import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:shiffters/screens/User/chat_screen.dart';
import 'package:provider/provider.dart';
import 'package:shiffters/services/theme_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MessageScreen extends StatefulWidget {
  const MessageScreen({super.key});

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _filteredConversations = [];
  bool _isLoadingConversations = true;
  StreamSubscription<QuerySnapshot>? _conversationSubscription;
  bool _hasNewMessages = false;
  int _totalUnreadCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
    _setupConversationListener();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
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
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) {
      _animationController.forward();
    }
  }

  void _setupConversationListener() {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("❌ [Message Screen] No user logged in");
      setState(() {
        _isLoadingConversations = false;
      });
      return;
    }

    print(
        "✅ [Message Screen] Setting up conversation listener for user: ${user.uid}");

    try {
      _conversationSubscription = FirebaseFirestore.instance
          .collection('conversations')
          .where('participants', arrayContains: user.uid)
          .orderBy('lastMessageTimestamp', descending: true)
          .snapshots()
          .listen((QuerySnapshot snapshot) async {
        print("✅ [Message Screen] Found ${snapshot.docs.length} conversations");
        await _processConversations(snapshot, user.uid);
      }, onError: (error) {
        print('❌ [Message Screen] Error with ordered query: $error');

        // Fallback: Try without orderBy
        if (error.toString().contains('index') ||
            error.toString().contains('failed-precondition')) {
          print("🔧 [Message Screen] Trying fallback query without orderBy...");

          _conversationSubscription?.cancel();
          _conversationSubscription = FirebaseFirestore.instance
              .collection('conversations')
              .where('participants', arrayContains: user.uid)
              .snapshots()
              .listen((QuerySnapshot snapshot) async {
            print(
                "🔧 [Message Screen] Fallback found ${snapshot.docs.length} conversations");
            await _processConversations(snapshot, user.uid);
          }, onError: (fallbackError) {
            print(
                "❌ [Message Screen] Fallback query also failed: $fallbackError");
            if (mounted) {
              setState(() {
                _isLoadingConversations = false;
              });
            }
          });
        } else {
          if (mounted) {
            setState(() {
              _isLoadingConversations = false;
            });
          }
        }
      });
    } catch (e) {
      print('❌ [Message Screen] Error setting up listener: $e');
      if (mounted) {
        setState(() {
          _isLoadingConversations = false;
        });
      }
    }
  }

  Future<void> _processConversations(
      QuerySnapshot snapshot, String currentUserId) async {
    List<Map<String, dynamic>> conversations = [];

    for (var doc in snapshot.docs) {
      try {
        final conversationData = doc.data() as Map<String, dynamic>;
        final conversationId = doc.id;

        print("🔍 [Message Screen] Processing conversation: $conversationId");
        print("🔍 [Message Screen] Current user ID: $currentUserId");

        // Get the other participant (not the current user)
        final List<dynamic> participants =
            conversationData['participants'] ?? [];
        print("🔍 [Message Screen] Conversation participants: $participants");
        final String? otherUserId = participants.firstWhere(
          (id) => id != currentUserId,
          orElse: () => null,
        );

        if (otherUserId == null) {
          print(
              "⚠️ [Message Screen] No other participant found in conversation: $conversationId");
          continue;
        }

        print("🔍 [Message Screen] Other user ID: $otherUserId");

        // Get order ID from conversation to check if current user was driver
        final String orderId = conversationData['orderId'] ?? '';

        // Check if current user was the driver for this order
        bool currentUserWasDriver = false;

        // First check if conversation has driverId field directly
        final String conversationDriverId = conversationData['driverId'] ?? '';
        if (conversationDriverId == currentUserId) {
          currentUserWasDriver = true;
          print(
              "🚫 [Message Screen] Skipping conversation $conversationId - current user is driver in conversation");
        }

        // Also check the order document if orderId exists
        if (!currentUserWasDriver && orderId.isNotEmpty) {
          try {
            final orderDoc = await FirebaseFirestore.instance
                .collection('orders')
                .doc(orderId)
                .get();

            if (orderDoc.exists) {
              final orderData = orderDoc.data() as Map<String, dynamic>;
              final String orderDriverId = orderData['driverId'] ?? '';

              if (orderDriverId == currentUserId) {
                currentUserWasDriver = true;
                print(
                    "🚫 [Message Screen] Skipping conversation $conversationId - current user was driver for order $orderId");
              }
            }
          } catch (e) {
            print("⚠️ [Message Screen] Error checking order $orderId: $e");
          }
        }

        // Skip this conversation if current user was the driver
        if (currentUserWasDriver) {
          print(
              "🚫 [Message Screen] FINAL SKIP: Conversation $conversationId skipped - user $currentUserId was driver");
          continue;
        }

        // Fetch other user details from users collection
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(otherUserId)
            .get();

        String otherUserName = 'Unknown User';
        String userRole = 'user';
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          otherUserName = userData['name'] ?? 'Unknown User';
          userRole = userData['role'] ?? 'user';
          print(
              "✅ [Message Screen] Fetched user name: $otherUserName (Role: $userRole)");
        } else {
          print(
              "⚠️ [Message Screen] User document not found for: $otherUserId");
        }

        // Get last message
        final String lastMessage =
            conversationData['lastMessage'] ?? 'No messages yet';
        final Timestamp? lastMessageTimestamp =
            conversationData['lastMessageTimestamp'];

        // Get unread count for current user
        final Map<String, dynamic> unreadCounts =
            conversationData['unreadCounts'] as Map<String, dynamic>? ?? {};
        final int unreadCount = unreadCounts[currentUserId] as int? ?? 0;

        print(
            "🔍 [Message Screen] Conversation $conversationId - UnreadCounts: $unreadCounts");
        print(
            "🔍 [Message Screen] Current user unread count: $unreadCount for user: $currentUserId");
        print("🔍 [Message Screen] Last message: $lastMessage");
        print("🔍 [Message Screen] Timestamp: $lastMessageTimestamp");

        // Determine if the other user is driver or customer
        final bool isOtherUserDriver = userRole == 'driver';

        conversations.add({
          'id': conversationId,
          'driverName': otherUserName, // Keep this key for compatibility
          'driverId': otherUserId, // Keep this key for compatibility
          'otherUserName': otherUserName,
          'otherUserId': otherUserId,
          'lastMessage': lastMessage,
          'timestamp': lastMessageTimestamp?.toDate() ?? DateTime.now(),
          'unreadCount': unreadCount,
          'orderId': orderId,
          'isOnline': false,
          'isOtherUserDriver': isOtherUserDriver,
          'userRole': userRole,
        });

        print(
            "✅ [Message Screen] Added conversation with $otherUserName ($userRole) for order $orderId - UnreadCount: $unreadCount");
      } catch (e) {
        print('❌ [Message Screen] Error processing conversation ${doc.id}: $e');
      }
    }

    // Sort conversations manually if needed (for fallback query)
    conversations.sort((a, b) {
      try {
        final DateTime timestampA = a['timestamp'] ?? DateTime.now();
        final DateTime timestampB = b['timestamp'] ?? DateTime.now();
        return timestampB.compareTo(timestampA); // Newest first
      } catch (e) {
        return 0;
      }
    });

    print(
        "✅ [Message Screen] Total conversations processed: ${conversations.length}");

    // Calculate total unread count and check for new messages
    int totalUnread = 0;
    bool hasNewMessages = false;

    for (var conversation in conversations) {
      final int unreadCount = conversation['unreadCount'] ?? 0;
      totalUnread += unreadCount;
      if (unreadCount > 0) {
        hasNewMessages = true;
      }
    }

    if (mounted) {
      setState(() {
        _conversations = conversations;
        _filteredConversations = List.from(conversations);
        _isLoadingConversations = false;
        _totalUnreadCount = totalUnread;

        // Check if we have new messages
        _hasNewMessages = hasNewMessages;
      });
    }
  }

  void _filterConversations(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredConversations = List.from(_conversations);
      } else {
        _filteredConversations = _conversations.where((conversation) {
          return conversation['otherUserName']
                  .toString()
                  .toLowerCase()
                  .contains(query.toLowerCase()) ||
              conversation['driverName']
                  .toString()
                  .toLowerCase()
                  .contains(query.toLowerCase()) ||
              conversation['orderId']
                  .toString()
                  .toLowerCase()
                  .contains(query.toLowerCase()) ||
              conversation['lastMessage']
                  .toString()
                  .toLowerCase()
                  .contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  void _openChat(Map<String, dynamic> conversation) async {
    HapticFeedback.lightImpact();

    final String conversationId = conversation['id'] ?? '';
    final int previousUnreadCount = conversation['unreadCount'] ?? 0;

    // Mark conversation as read locally first for immediate UI update
    setState(() {
      conversation['unreadCount'] = 0;
      // Recalculate total unread count
      _totalUnreadCount = _conversations.fold(
          0, (sum, conv) => sum + (conv['unreadCount'] as int? ?? 0));
      _hasNewMessages = _totalUnreadCount > 0;
    });

    // Mark conversation as read in Firebase
    if (conversationId.isNotEmpty && previousUnreadCount > 0) {
      try {
        final User? user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('conversations')
              .doc(conversationId)
              .update({
            'unreadCounts.${user.uid}': 0,
          });

          print(
              "✅ [Message Screen] Marked conversation $conversationId as read");
        }
      } catch (e) {
        print("❌ [Message Screen] Error marking conversation as read: $e");
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          orderId: conversation['orderId'] ?? '',
          otherUserId:
              conversation['otherUserId'] ?? conversation['driverId'] ?? '',
          otherUserName: conversation['otherUserName'] ??
              conversation['driverName'] ??
              'Unknown User',
          isDriverMode: false,
        ),
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }

  @override
  void dispose() {
    _conversationSubscription?.cancel();
    _animationController.dispose();
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
          body: Column(
            children: [
              _buildAppBar(isTablet, isDarkMode),
              if (_hasNewMessages)
                Container(
                  margin: EdgeInsets.only(top: 16),
                  child: _buildNewMessageNotification(isTablet, isDarkMode),
                ),
              Container(
                margin: EdgeInsets.only(top: 16),
                child: _buildSearchBar(isTablet, isDarkMode),
              ),
              Expanded(child: _buildMessagesList(isTablet, isDarkMode)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAppBar(bool isTablet, bool isDarkMode) {
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
                  Text(
                    'Messages',
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 28 : 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Connection indicator for message status
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _hasNewMessages
                          ? Colors.green
                          : Colors.white.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  // Notification badge for unread messages
                  if (_totalUnreadCount > 0)
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
                        _totalUnreadCount > 99
                            ? '99+'
                            : _totalUnreadCount.toString(),
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 12 : 10,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode
                              ? Colors.black
                              : const Color(0xFF1E88E5),
                        ),
                      ),
                    ),
                  // Refresh/sync button
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _setupConversationListener(); // Refresh conversations
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.refresh,
                        color: Colors.white,
                        size: 20,
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

  Widget _buildNewMessageNotification(bool isTablet, bool isDarkMode) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: _hasNewMessages ? (isTablet ? 60 : 50) : 0,
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: isTablet ? 20 : 16,
          vertical: 4,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 16 : 12,
          vertical: isTablet ? 12 : 8,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.green.withValues(alpha: 0.1),
              Colors.green.withValues(alpha: 0.05),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.green.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: isTablet ? 32 : 24,
              height: isTablet ? 32 : 24,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_active,
                color: Colors.white,
                size: isTablet ? 18 : 14,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _totalUnreadCount == 1
                    ? 'You have 1 new message'
                    : 'You have $_totalUnreadCount new messages',
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 14 : 12,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  _hasNewMessages = false;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close,
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.7)
                      : Colors.grey[600],
                  size: isTablet ? 18 : 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isTablet, bool isDarkMode) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: EdgeInsets.all(isTablet ? 20 : 16),
        decoration: BoxDecoration(
          color: isDarkMode ? null : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isDarkMode
              ? null
              : Border.all(color: const Color(0xFF1E88E5), width: 1.5),
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
                    color: const Color(0xFF1E88E5).withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: TextFormField(
          controller: _searchController,
          onChanged: _filterConversations,
          style: GoogleFonts.albertSans(
            fontSize: isTablet ? 16 : 14,
            color: isDarkMode ? Colors.white : const Color(0xFF2D3748),
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: 'Search messages...',
            hintStyle: GoogleFonts.albertSans(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.6)
                  : const Color(0xFF718096),
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: isDarkMode
                ? Icon(
                    Icons.search_rounded,
                    color: Colors.white.withValues(alpha: 0.7),
                    size: isTablet ? 24 : 20,
                  )
                : Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E88E5).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.search_rounded,
                      color: const Color(0xFF1E88E5),
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
                      color: const Color(0xFFFDD835),
                      width: 2,
                    ),
                  )
                : InputBorder.none,
            contentPadding: EdgeInsets.symmetric(
              horizontal: isTablet ? 20 : 16,
              vertical: isTablet ? 18 : 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessagesList(bool isTablet, bool isDarkMode) {
    if (_isLoadingConversations) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_filteredConversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/animations/noorder.json',
              width: 150,
              height: 150,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 24),
            Text(
              'No messages yet',
              style: GoogleFonts.albertSans(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.7)
                    : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your conversations will appear here',
              style: GoogleFonts.albertSans(
                fontSize: 14,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.5)
                    : Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return SlideTransition(
      position: _slideAnimation,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: isTablet ? 20 : 16),
        itemCount: _filteredConversations.length,
        itemBuilder: (context, index) {
          final conversation = _filteredConversations[index];
          return _buildConversationTile(conversation, isTablet, isDarkMode);
        },
      ),
    );
  }

  Widget _buildConversationTile(
      Map<String, dynamic> conversation, bool isTablet, bool isDarkMode) {
    final bool hasUnreadMessages = (conversation['unreadCount'] ?? 0) > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openChat(conversation),
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.all(isTablet ? 20 : 16),
            decoration: BoxDecoration(
              color: hasUnreadMessages
                  ? (isDarkMode
                      ? const Color(0xFF2D2D3C).withValues(alpha: 0.9)
                      : const Color(0xFF1E88E5).withValues(alpha: 0.05))
                  : (isDarkMode
                      ? const Color(0xFF2D2D3C).withValues(alpha: 0.7)
                      : Colors.white),
              borderRadius: BorderRadius.circular(16),
              border: hasUnreadMessages
                  ? Border.all(
                      color: const Color(0xFF1E88E5).withValues(alpha: 0.5),
                      width: 2,
                    )
                  : (isDarkMode
                      ? null
                      : Border.all(
                          color: const Color(0xFF1E88E5).withValues(alpha: 0.3),
                          width: 1.5,
                        )),
              boxShadow: hasUnreadMessages
                  ? [
                      BoxShadow(
                        color: const Color(0xFF1E88E5).withValues(alpha: 0.2),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : (isDarkMode
                      ? [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color:
                                const Color(0xFF1E88E5).withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ]),
            ),
            child: Row(
              children: [
                // User Avatar
                Container(
                  width: isTablet ? 60 : 50,
                  height: isTablet ? 60 : 50,
                  decoration: BoxDecoration(
                    color: conversation['isOtherUserDriver'] == true
                        ? const Color(0xFF1E88E5)
                        : const Color(0xFF42A5F5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person,
                    color: Colors.white,
                    size: isTablet ? 30 : 24,
                  ),
                ),
                const SizedBox(width: 16),

                // Message Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User name and timestamp
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  conversation['otherUserName'] ??
                                      conversation['driverName'] ??
                                      'Unknown User',
                                  style: GoogleFonts.albertSans(
                                    fontSize: isTablet ? 16 : 14,
                                    fontWeight: FontWeight.w600,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                // Show role indicator
                                if (conversation['isOtherUserDriver'] == true)
                                  Text(
                                    'Driver',
                                    style: GoogleFonts.albertSans(
                                      fontSize: isTablet ? 10 : 8,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF1E88E5),
                                    ),
                                  )
                                else
                                  Text(
                                    'Customer',
                                    style: GoogleFonts.albertSans(
                                      fontSize: isTablet ? 10 : 8,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF42A5F5),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            _formatTime(
                                conversation['timestamp'] ?? DateTime.now()),
                            style: GoogleFonts.albertSans(
                              fontSize: isTablet ? 12 : 10,
                              fontWeight: FontWeight.w400,
                              color: isDarkMode
                                  ? Colors.white.withValues(alpha: 0.6)
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Order ID
                      if (conversation['orderId'] != null &&
                          conversation['orderId'].isNotEmpty)
                        Text(
                          'Order #${conversation['orderId']}',
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 12 : 10,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF1E88E5),
                          ),
                        ),
                      const SizedBox(height: 8),

                      // Last message
                      Text(
                        conversation['lastMessage'] ?? 'No messages yet',
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 14 : 12,
                          fontWeight: FontWeight.w400,
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.8)
                              : Colors.grey[700],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Unread badge
                if ((conversation['unreadCount'] ?? 0) > 0)
                  Container(
                    margin: const EdgeInsets.only(left: 12),
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 10 : 8,
                      vertical: isTablet ? 8 : 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: isDarkMode
                          ? LinearGradient(
                              colors: [
                                const Color(0xFFFDD835),
                                const Color(0xFFF57F17)
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : LinearGradient(
                              colors: [Colors.red, Colors.red.shade700],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: isDarkMode
                              ? const Color(0xFFFDD835).withValues(alpha: 0.3)
                              : Colors.red.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      (conversation['unreadCount'] ?? 0) > 99
                          ? '99+'
                          : (conversation['unreadCount'] ?? 0).toString(),
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 12 : 10,
                        fontWeight: FontWeight.w700,
                        color: isDarkMode ? Colors.black : Colors.white,
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
}
