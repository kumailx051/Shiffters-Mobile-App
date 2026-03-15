import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:shiffters/theme/app_colors.dart';
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

        // Get the other participant (not the current user)
        final List<dynamic> participants =
            conversationData['participants'] ?? [];
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

        // Fetch other user details from users collection
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(otherUserId)
            .get();

        String otherUserName = 'Unknown User';
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          otherUserName = userData['name'] ?? 'Unknown User';
          print("✅ [Message Screen] Fetched user name: $otherUserName");
        } else {
          print(
              "⚠️ [Message Screen] User document not found for: $otherUserId");
        }

        // Get order ID from conversation
        final String orderId = conversationData['orderId'] ?? '';

        // Get last message
        final String lastMessage =
            conversationData['lastMessage'] ?? 'No messages yet';
        final Timestamp? lastMessageTimestamp =
            conversationData['lastMessageTimestamp'];

        // Get unread count for current user
        final Map<String, dynamic> unreadCounts =
            conversationData['unreadCounts'] as Map<String, dynamic>? ?? {};
        final int unreadCount = unreadCounts[currentUserId] as int? ?? 0;

        // Determine if the other user is driver or customer based on role
        final String userRole = userDoc.exists
            ? ((userDoc.data() as Map<String, dynamic>)['role'] ?? 'user')
            : 'user';

        final bool isOtherUserDriver = userRole == 'driver';

        conversations.add({
          'id': conversationId,
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
            "✅ [Message Screen] Added conversation with $otherUserName ($userRole)");
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

    if (mounted) {
      setState(() {
        _conversations = conversations;
        _filteredConversations = List.from(conversations);
        _isLoadingConversations = false;
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

  void _openChat(Map<String, dynamic> conversation) {
    HapticFeedback.lightImpact();

    // Mark conversation as read
    setState(() {
      conversation['unreadCount'] = 0;
    });

    // Determine if the current user is in driver mode or customer mode
    final bool isDriverMode =
        false; // This is always customer mode for user side

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          orderId: conversation['orderId'] ?? '',
          otherUserId: conversation['otherUserId'] ?? '',
          otherUserName: conversation['otherUserName'] ?? 'Unknown User',
          isDriverMode: isDriverMode,
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
          backgroundColor: isDarkMode ? const Color(0xFF1E1E2C) : Colors.white,
          body: Column(
            children: [
              _buildAppBar(isTablet, isDarkMode),
              _buildSearchBar(isTablet, isDarkMode),
              Expanded(child: _buildMessagesList(isTablet, isDarkMode)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAppBar(bool isTablet, bool isDarkMode) {
    return SafeArea(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 20 : 16,
          vertical: 16,
        ),
        decoration: BoxDecoration(
          color: isDarkMode
              ? const Color(0xFF2D2D3C)
              : Colors.white.withValues(alpha: 0.9),
          boxShadow: isDarkMode
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              width: isTablet ? 35 : 30,
              height: isTablet ? 35 : 30,
              decoration: BoxDecoration(
                color: AppColors.lightPrimary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.chat_bubble_rounded,
                color: Colors.white,
                size: isTablet ? 20 : 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Messages',
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 22 : 20,
                  fontWeight: FontWeight.w700,
                  color: isDarkMode ? Colors.white : Colors.black,
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
          borderRadius: BorderRadius.circular(25),
          boxShadow: isDarkMode
              ? [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: TextFormField(
          controller: _searchController,
          onChanged: _filterConversations,
          style: GoogleFonts.albertSans(
            fontSize: isTablet ? 16 : 14,
            color: isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: 'Search messages...',
            hintStyle: GoogleFonts.albertSans(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.6)
                  : Colors.grey[600],
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.6)
                  : Colors.grey[600],
              size: isTablet ? 24 : 20,
            ),
            filled: true,
            fillColor: isDarkMode
                ? const Color(0xFF2D2D3C)
                : Colors.white.withValues(alpha: 0.9),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25),
              borderSide: BorderSide.none,
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: isTablet ? 20 : 16,
              vertical: isTablet ? 16 : 14,
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openChat(conversation),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.all(isTablet ? 20 : 16),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? const Color(0xFF2D2D3C).withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16),
              border: isDarkMode
                  ? null
                  : Border.all(
                      color: Colors.blue.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
              boxShadow: isDarkMode
                  ? [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Row(
              children: [
                // User Avatar
                Container(
                  width: isTablet ? 60 : 50,
                  height: isTablet ? 60 : 50,
                  decoration: BoxDecoration(
                    color: conversation['isOtherUserDriver'] == true
                        ? AppColors.lightPrimary
                        : Colors.orange,
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
                                      color: AppColors.lightPrimary,
                                    ),
                                  )
                                else
                                  Text(
                                    'Customer',
                                    style: GoogleFonts.albertSans(
                                      fontSize: isTablet ? 10 : 8,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.orange,
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
                            color: AppColors.lightPrimary,
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
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      (conversation['unreadCount'] ?? 0).toString(),
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 12 : 10,
                        fontWeight: FontWeight.w600,
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
}
