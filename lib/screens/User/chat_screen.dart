import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:shiffters/theme/app_colors.dart';
import 'package:shiffters/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shiffters/services/theme_service.dart';
import 'package:shiffters/services/messaging_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatScreen extends StatefulWidget {
  final String orderId;
  final String otherUserId;
  final String otherUserName;
  final bool isDriverMode;

  const ChatScreen({
    super.key,
    required this.orderId,
    required this.otherUserId,
    required this.otherUserName,
    this.isDriverMode = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  Stream<QuerySnapshot>? _messagesStream;
  String? _currentUserId;
  String? _conversationId;
  String?
      _actualOtherUserName; // Changed from _actualCustomerName to be more generic
  String? _otherUserProfileImageUrl; // Add profile image URL
  String? _currentUserProfileImageUrl; // Add current user's profile image URL
  bool _isInitialLoading = true; // Add this to control minimum loading time

  // Typing indicator variables
  bool _isOtherUserTyping = false;
  bool _isCurrentUserTyping = false;
  Timer? _typingTimer;
  StreamSubscription<DocumentSnapshot>? _typingSubscription;
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
    _initializeMessaging();

    // Auto scroll to bottom when new messages arrive
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _initializeMessaging() async {
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (_currentUserId != null) {
      try {
        print("=== Initializing messaging ===");
        print("Order ID: ${widget.orderId}");
        print("Current User ID: $_currentUserId");
        print("Other User ID: ${widget.otherUserId}");
        print("Is Driver Mode: ${widget.isDriverMode}");

        // Fetch the actual other user's name from users collection
        await _fetchOtherUserName();

        // Fetch the current user's profile image
        await _fetchCurrentUserProfileImage();

        // First, try to find existing conversation for this order
        final existingConversation = await FirebaseFirestore.instance
            .collection('conversations')
            .where('orderId', isEqualTo: widget.orderId)
            .limit(1)
            .get();

        if (existingConversation.docs.isNotEmpty) {
          // Use existing conversation
          final conversationDoc = existingConversation.docs.first;
          _conversationId = conversationDoc.id;
          print("Found existing conversation: $_conversationId");
        } else {
          // Create new conversation using MessagingService
          _conversationId = await MessagingService.createOrGetConversation(
            orderId: widget.orderId,
            userId: widget.isDriverMode ? widget.otherUserId : _currentUserId!,
            driverId:
                widget.isDriverMode ? _currentUserId! : widget.otherUserId,
          );
          print("Created new conversation: $_conversationId");
        }

        // Set up messages stream
        _messagesStream = FirebaseFirestore.instance
            .collection('messages')
            .where('conversationId', isEqualTo: _conversationId!)
            .orderBy('timestamp', descending: false)
            .snapshots();

        print("Messages stream set up for conversation: $_conversationId");

        // Mark messages as read when screen loads
        await MessagingService.markMessagesAsRead(
          conversationId: _conversationId!,
          userId: _currentUserId!,
          userType: widget.isDriverMode ? 'driver' : 'user',
        );

        // Setup typing indicator listener
        _setupTypingListener();

        // Add minimum loading time of 1 second
        await Future.delayed(const Duration(seconds: 1));

        // Trigger rebuild to show updated stream
        if (mounted) {
          setState(() {
            _isInitialLoading = false;
          });
        }
      } catch (e) {
        debugPrint('Error initializing messaging: $e');
        print("Error details: $e");

        // Fallback: Try to find messages by order ID directly
        print("Attempting fallback: using order ID as conversation ID");
        _conversationId = widget.orderId;
        _messagesStream = FirebaseFirestore.instance
            .collection('messages')
            .where('conversationId', isEqualTo: _conversationId!)
            .orderBy('timestamp', descending: false)
            .snapshots();

        // Add minimum loading time even for fallback
        await Future.delayed(const Duration(seconds: 3));

        if (mounted) {
          setState(() {
            _isInitialLoading = false;
          });
        }
      }
    }
  }

  Future<void> _fetchOtherUserName() async {
    try {
      print("=== Fetching other user's name and profile image ===");
      print("Other User ID: ${widget.otherUserId}");
      print("Current User ID: $_currentUserId");
      print("Is Driver Mode: ${widget.isDriverMode}");

      // Directly fetch the other user's name and profile image from users collection using their UID
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.otherUserId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final userName = userData['name'] as String?;
        final profileImageUrl = userData['profileImageUrl'] as String?;

        if (userName != null && userName.isNotEmpty) {
          setState(() {
            _actualOtherUserName = userName;
            _otherUserProfileImageUrl = profileImageUrl;
          });
          print(
              "✅ Fetched other user's name: $userName for UID: ${widget.otherUserId}");
          print("✅ Fetched profile image URL: $profileImageUrl");
          print(
              "   Role: ${widget.isDriverMode ? 'Driver viewing Customer' : 'Customer viewing Driver'}");
        } else {
          print("⚠️ User name is empty or null for UID: ${widget.otherUserId}");
          // Fallback to the passed name
          setState(() {
            _actualOtherUserName = widget.otherUserName;
            _otherUserProfileImageUrl = null;
          });
        }
      } else {
        print("⚠️ User document does not exist for UID: ${widget.otherUserId}");
        // Fallback to the passed name
        setState(() {
          _actualOtherUserName = widget.otherUserName;
          _otherUserProfileImageUrl = null;
        });
      }
    } catch (e) {
      print("Error fetching other user's name and profile image: $e");
      // Fallback to the passed name if fetch fails
      setState(() {
        _actualOtherUserName = widget.otherUserName;
        _otherUserProfileImageUrl = null;
      });
    }
  }

  Future<void> _fetchCurrentUserProfileImage() async {
    try {
      print("=== Fetching current user's profile image ===");
      print("Current User ID: $_currentUserId");

      if (_currentUserId != null) {
        // Fetch the current user's profile image from users collection using their UID
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUserId!)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final profileImageUrl = userData['profileImageUrl'] as String?;

          setState(() {
            _currentUserProfileImageUrl = profileImageUrl;
          });
          print("✅ Fetched current user's profile image URL: $profileImageUrl");
        } else {
          print(
              "⚠️ Current user document does not exist for UID: $_currentUserId");
          setState(() {
            _currentUserProfileImageUrl = null;
          });
        }
      }
    } catch (e) {
      print("Error fetching current user's profile image: $e");
      setState(() {
        _currentUserProfileImageUrl = null;
      });
    }
  }

  // Setup typing indicator listener
  void _setupTypingListener() {
    if (_conversationId == null || _currentUserId == null) return;

    print("✅ Setting up typing listener for conversation: $_conversationId");

    _typingSubscription?.cancel();
    _typingSubscription = FirebaseFirestore.instance
        .collection('conversations')
        .doc(_conversationId!)
        .snapshots()
        .listen((DocumentSnapshot doc) {
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          // Get typing status for the other user
          final otherUserTypingKey =
              widget.isDriverMode ? 'userTyping' : 'driverTyping';
          final otherUserTyping = data[otherUserTypingKey] ?? false;

          if (_isOtherUserTyping != otherUserTyping) {
            setState(() {
              _isOtherUserTyping = otherUserTyping;
            });
            print("🔤 Other user typing status: $otherUserTyping");
          }
        }
      }
    });
  }

  // Update typing status in Firestore
  void _updateTypingStatus(bool isTyping) async {
    if (_conversationId == null || _currentUserId == null) return;

    try {
      final typingKey = widget.isDriverMode ? 'driverTyping' : 'userTyping';
      final typingUserKey =
          widget.isDriverMode ? 'driverTypingUser' : 'userTypingUser';

      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(_conversationId!)
          .update({
        typingKey: isTyping,
        typingUserKey: isTyping ? _currentUserId : null,
        '${typingKey}Timestamp': isTyping ? FieldValue.serverTimestamp() : null,
      });

      print("🔤 Updated typing status: $isTyping");
    } catch (e) {
      print("Error updating typing status: $e");
    }
  }

  // Handle text input changes for typing indicator
  void _onTextChanged(String text) {
    // Cancel existing timer
    _typingTimer?.cancel();

    // If user just started typing
    if (!_isCurrentUserTyping && text.isNotEmpty) {
      setState(() {
        _isCurrentUserTyping = true;
      });
      _updateTypingStatus(true);
    }

    // Set timer to stop typing after 2 seconds of inactivity
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_isCurrentUserTyping) {
        setState(() {
          _isCurrentUserTyping = false;
        });
        _updateTypingStatus(false);
      }
    });

    // If text is empty, immediately stop typing
    if (text.isEmpty && _isCurrentUserTyping) {
      setState(() {
        _isCurrentUserTyping = false;
      });
      _updateTypingStatus(false);
    }
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
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) {
      _animationController.forward();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isNotEmpty && _currentUserId != null) {
      final messageText = _messageController.text.trim();
      _messageController.clear();

      // Clear typing status when sending message
      _typingTimer?.cancel();
      if (_isCurrentUserTyping) {
        setState(() {
          _isCurrentUserTyping = false;
        });
        _updateTypingStatus(false);
      }

      try {
        // Ensure conversation exists and get the correct conversation ID
        if (_conversationId == null) {
          _conversationId = await MessagingService.createOrGetConversation(
            orderId: widget.orderId,
            userId: widget.isDriverMode ? widget.otherUserId : _currentUserId!,
            driverId:
                widget.isDriverMode ? _currentUserId! : widget.otherUserId,
          );
        }

        await MessagingService.sendMessage(
          conversationId: _conversationId!,
          senderId: _currentUserId!,
          message: messageText,
          senderType: widget.isDriverMode ? 'driver' : 'user',
        );

        // Auto scroll to bottom after sending message
        Future.delayed(const Duration(milliseconds: 100), () {
          _scrollToBottom();
        });
      } catch (e) {
        debugPrint('Error sending message: $e');
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red,
          ),
        );
        // Restore the message text if sending failed
        _messageController.text = messageText;
      }
    }
  }

  @override
  void dispose() {
    // Clean up typing resources
    _typingTimer?.cancel();
    _typingSubscription?.cancel();

    // Clear typing status when leaving
    if (_isCurrentUserTyping) {
      _updateTypingStatus(false);
    }

    _animationController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        final isDarkMode = themeService.isDarkMode;
        final accent =
            isDarkMode ? AppColors.yellowAccent : AppTheme.lightPrimaryColor;

        return Scaffold(
          backgroundColor:
              isDarkMode ? const Color(0xFF1E1E2C) : Colors.grey[50],
          appBar: _buildAppBar(isTablet, isDarkMode, accent),
          body: Column(
            children: [
              // Driver Info Card
              _buildDriverInfoCard(isTablet, isDarkMode, accent),

              // Messages List
              Expanded(
                child: _buildMessagesList(isTablet, isDarkMode, accent),
              ),

              // Message Input
              _buildMessageInput(isTablet, isDarkMode, accent),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
      bool isTablet, bool isDarkMode, Color accent) {
    return AppBar(
      backgroundColor: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
      elevation: isDarkMode ? 0 : 4,
      shadowColor: isDarkMode ? null : Colors.black.withValues(alpha: 0.1),
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios,
          color: isDarkMode ? Colors.white : Colors.black,
          size: isTablet ? 24 : 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            width: isTablet ? 40 : 35,
            height: isTablet ? 40 : 35,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: _otherUserProfileImageUrl != null &&
                      _otherUserProfileImageUrl!.isNotEmpty
                  ? Image.network(
                      _otherUserProfileImageUrl!,
                      width: isTablet ? 40 : 35,
                      height: isTablet ? 40 : 35,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.person,
                          color: isDarkMode ? Colors.black : Colors.white,
                          size: isTablet ? 20 : 18,
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isDarkMode ? Colors.black : Colors.white,
                            ),
                            strokeWidth: 2,
                          ),
                        );
                      },
                    )
                  : Icon(
                      Icons.person,
                      color: isDarkMode ? Colors.black : Colors.white,
                      size: isTablet ? 20 : 18,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                // Use the fetched other user's name if available, otherwise use the passed name
                _actualOtherUserName ?? widget.otherUserName,
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 16 : 14,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              Text(
                widget.isDriverMode ? 'Customer' : 'Your Driver',
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 12 : 10,
                  fontWeight: FontWeight.w400,
                  color: _isOtherUserTyping
                      ? (isDarkMode
                          ? AppColors.yellowAccent
                          : AppTheme.lightPrimaryColor)
                      : (isDarkMode
                          ? Colors.white.withValues(alpha: 0.7)
                          : Colors.grey[600]),
                ),
              ),
              // Show typing indicator in subtitle
              if (_isOtherUserTyping)
                Row(
                  children: [
                    Text(
                      'typing',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 10 : 9,
                        fontStyle: FontStyle.italic,
                        color: isDarkMode
                            ? AppColors.yellowAccent
                            : AppTheme.lightPrimaryColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 12,
                      height: 6,
                      child: _buildTypingDotsSmall(isDarkMode),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.phone,
            color: accent,
            size: isTablet ? 24 : 20,
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            // Handle phone call
          },
        ),
        IconButton(
          icon: Icon(
            Icons.more_vert,
            color: isDarkMode ? Colors.white : Colors.black,
            size: isTablet ? 24 : 20,
          ),
          onPressed: () {
            // Handle more options
          },
        ),
      ],
    );
  }

  Widget _buildDriverInfoCard(bool isTablet, bool isDarkMode, Color accent) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: EdgeInsets.all(isTablet ? 20 : 16),
        padding: EdgeInsets.all(isTablet ? 20 : 16),
        decoration: BoxDecoration(
          color:
              isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.2)
                : Colors.blue.withValues(alpha: 0.3),
            width: isDarkMode ? 1 : 1.5,
          ),
          boxShadow: isDarkMode
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              width: isTablet ? 50 : 45,
              height: isTablet ? 50 : 45,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.local_shipping,
                color: accent,
                size: isTablet ? 25 : 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order #${widget.orderId.length > 8 ? widget.orderId.substring(0, 8) : widget.orderId}',
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 16 : 14,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'En route to destination',
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 12 : 11,
                      fontWeight: FontWeight.w400,
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.7)
                          : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green, width: 1),
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
                  const SizedBox(width: 6),
                  Text(
                    'Online',
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 10 : 9,
                      fontWeight: FontWeight.w500,
                      color: Colors.green,
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

  Widget _buildMessagesList(bool isTablet, bool isDarkMode, Color accent) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: StreamBuilder<QuerySnapshot>(
        stream: _messagesStream,
        builder: (context, snapshot) {
          print("=== Messages Stream State ===");
          print("Connection state: ${snapshot.connectionState}");
          print("Has error: ${snapshot.hasError}");
          print("Error: ${snapshot.error}");
          print("Has data: ${snapshot.hasData}");
          print("Document count: ${snapshot.data?.docs.length ?? 0}");
          print("Conversation ID: $_conversationId");

          if (snapshot.connectionState == ConnectionState.waiting ||
              _isInitialLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Lottie.asset(
                    'assets/animations/messageLoader.json',
                    width: 120,
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading messages...',
                    style: GoogleFonts.albertSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.7)
                          : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            print("Stream error details: ${snapshot.error}");
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 60,
                    color: Colors.red.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading messages',
                    style: GoogleFonts.albertSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: GoogleFonts.albertSans(
                      fontSize: 12,
                      color: Colors.red,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      _initializeMessaging();
                    },
                    child: Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          print("Processing ${docs.length} messages");

          // Debug: Print message details
          for (var i = 0; i < docs.length; i++) {
            final data = docs[i].data() as Map<String, dynamic>;
            print(
                "Message $i: ${data['message']} from ${data['senderId']} at ${data['timestamp']}");
          }

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 60,
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.3)
                        : Colors.grey.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No messages yet',
                    style: GoogleFonts.albertSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.7)
                          : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start a conversation!',
                    style: GoogleFonts.albertSans(
                      fontSize: 14,
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.5)
                          : Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Conversation ID: $_conversationId',
                    style: GoogleFonts.albertSans(
                      fontSize: 10,
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.3)
                          : Colors.grey[400],
                    ),
                  ),
                ],
              ),
            );
          }

          // Auto scroll to bottom when new messages arrive
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom();
          });

          return ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 20 : 16,
              vertical: 8,
            ),
            itemCount: docs.length +
                (_isOtherUserTyping ? 1 : 0), // Add 1 for typing indicator
            itemBuilder: (context, index) {
              // Show typing indicator as last item if other user is typing
              if (index == docs.length && _isOtherUserTyping) {
                return _buildTypingIndicator(isTablet, isDarkMode, accent);
              }

              final messageDoc = docs[index];
              final data = messageDoc.data() as Map<String, dynamic>;
              return _buildMessageBubble(data, isTablet, isDarkMode, accent);
            },
          );
        },
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> messageData, bool isTablet,
      bool isDarkMode, Color accent) {
    final isCurrentUser = messageData['senderId'] == _currentUserId;
    final text = messageData['message'] ?? '';
    final timestamp = messageData['timestamp'] as Timestamp?;
    // Use the fetched name for other user, fall back to stored name or widget name
    final senderName = isCurrentUser
        ? 'You'
        : (_actualOtherUserName ??
            messageData['senderName'] ??
            widget.otherUserName);
    final isRead = messageData['isRead'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isCurrentUser) ...[
            Container(
              width: isTablet ? 35 : 30,
              height: isTablet ? 35 : 30,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: _otherUserProfileImageUrl != null &&
                        _otherUserProfileImageUrl!.isNotEmpty
                    ? Image.network(
                        _otherUserProfileImageUrl!,
                        width: isTablet ? 35 : 30,
                        height: isTablet ? 35 : 30,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.person,
                            color: isDarkMode ? Colors.black : Colors.white,
                            size: isTablet ? 18 : 16,
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isDarkMode ? Colors.black : Colors.white,
                              ),
                              strokeWidth: 1.5,
                            ),
                          );
                        },
                      )
                    : Icon(
                        Icons.person,
                        color: isDarkMode ? Colors.black : Colors.white,
                        size: isTablet ? 18 : 16,
                      ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isCurrentUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isCurrentUser)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      senderName,
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 12 : 11,
                        fontWeight: FontWeight.w500,
                        color: accent,
                      ),
                    ),
                  ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 16 : 14,
                    vertical: isTablet ? 12 : 10,
                  ),
                  decoration: BoxDecoration(
                    color: isCurrentUser
                        ? accent
                        : isDarkMode
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isCurrentUser ? 16 : 4),
                      bottomRight: Radius.circular(isCurrentUser ? 4 : 16),
                    ),
                    border: isCurrentUser
                        ? null
                        : Border.all(
                            color: isDarkMode
                                ? Colors.white.withValues(alpha: 0.2)
                                : Colors.blue.withValues(alpha: 0.3),
                            width: isDarkMode ? 1 : 1.5,
                          ),
                    boxShadow: !isDarkMode && !isCurrentUser
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    text,
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 14 : 13,
                      fontWeight: FontWeight.w400,
                      color: isCurrentUser
                          ? (isDarkMode ? Colors.black : Colors.white)
                          : (isDarkMode ? Colors.white : Colors.black),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(timestamp?.toDate() ?? DateTime.now()),
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 10 : 9,
                        fontWeight: FontWeight.w400,
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.5)
                            : Colors.grey[600],
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 4),
                      Icon(
                        isRead ? Icons.done_all : Icons.done,
                        size: 12,
                        color: isRead
                            ? accent
                            : (isDarkMode
                                ? Colors.white.withValues(alpha: 0.5)
                                : Colors.grey[600]),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (isCurrentUser) ...[
            const SizedBox(width: 12),
            Container(
              width: isTablet ? 35 : 30,
              height: isTablet ? 35 : 30,
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.grey[100],
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.grey.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: ClipOval(
                child: _currentUserProfileImageUrl != null &&
                        _currentUserProfileImageUrl!.isNotEmpty
                    ? Image.network(
                        _currentUserProfileImageUrl!,
                        width: isTablet ? 35 : 30,
                        height: isTablet ? 35 : 30,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.person,
                            color: isDarkMode ? Colors.white : Colors.grey[700],
                            size: isTablet ? 18 : 16,
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isDarkMode ? Colors.white : Colors.grey[700]!,
                              ),
                              strokeWidth: 1.5,
                            ),
                          );
                        },
                      )
                    : Icon(
                        Icons.person,
                        color: isDarkMode ? Colors.white : Colors.grey[700],
                        size: isTablet ? 18 : 16,
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageInput(bool isTablet, bool isDarkMode, Color accent) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        boxShadow: isDarkMode
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey[50],
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: _isCurrentUserTyping
                        ? (isDarkMode
                            ? AppColors.yellowAccent
                            : AppTheme.lightPrimaryColor)
                        : (isDarkMode
                            ? Colors.white.withValues(alpha: 0.2)
                            : Colors.blue.withValues(alpha: 0.3)),
                    width: _isCurrentUserTyping ? 2 : (isDarkMode ? 1 : 1.5),
                  ),
                  boxShadow: _isCurrentUserTyping
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
                child: TextField(
                  controller: _messageController,
                  onChanged: _onTextChanged, // Add typing indicator handler
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 14 : 13,
                    color: isDarkMode ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w400,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: GoogleFonts.albertSans(
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.5)
                          : Colors.grey[600],
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 20 : 16,
                      vertical: isTablet ? 14 : 12,
                    ),
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                width: isTablet ? 50 : 45,
                height: isTablet ? 50 : 45,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.send,
                  color: isDarkMode ? Colors.black : Colors.white,
                  size: isTablet ? 22 : 20,
                ),
              ),
            ),
          ],
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
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }

  Widget _buildTypingIndicator(bool isTablet, bool isDarkMode, Color accent) {
    if (!_isOtherUserTyping) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 20 : 16,
        vertical: 8,
      ),
      child: Row(
        children: [
          Container(
            width: isTablet ? 35 : 30,
            height: isTablet ? 35 : 30,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: _otherUserProfileImageUrl != null &&
                      _otherUserProfileImageUrl!.isNotEmpty
                  ? Image.network(
                      _otherUserProfileImageUrl!,
                      width: isTablet ? 35 : 30,
                      height: isTablet ? 35 : 30,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.person,
                          color: isDarkMode ? Colors.black : Colors.white,
                          size: isTablet ? 18 : 16,
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isDarkMode ? Colors.black : Colors.white,
                            ),
                            strokeWidth: 1.5,
                          ),
                        );
                      },
                    )
                  : Icon(
                      Icons.person,
                      color: isDarkMode ? Colors.black : Colors.white,
                      size: isTablet ? 18 : 16,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 16 : 14,
              vertical: isTablet ? 12 : 10,
            ),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.blue.withValues(alpha: 0.3),
                width: isDarkMode ? 1 : 1.5,
              ),
              boxShadow: !isDarkMode
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'typing',
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 13 : 12,
                    fontStyle: FontStyle.italic,
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.7)
                        : Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 8),
                _buildTypingDots(isDarkMode),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingDots(bool isDarkMode) {
    return SizedBox(
      width: 20,
      height: 8,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(3, (index) {
          return TweenAnimationBuilder<double>(
            key: ValueKey('typing_dot_$index'),
            duration: const Duration(milliseconds: 600),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              // Create a wave effect with different phases for each dot
              final phase = (index * 0.3) % 1.0;
              final animValue = ((value + phase) % 1.0);
              final scale =
                  0.5 + (0.5 * (1.0 + math.sin(animValue * 2 * math.pi)) / 2);

              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.7)
                        : Colors.grey[600],
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }

  Widget _buildTypingDotsSmall(bool isDarkMode) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(3, (index) {
        return TweenAnimationBuilder<double>(
          key: ValueKey('small_typing_dot_$index'),
          duration: const Duration(milliseconds: 600),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            // Create a wave effect with different phases for each dot
            final phase = (index * 0.3) % 1.0;
            final animValue = ((value + phase) % 1.0);
            final scale =
                0.5 + (0.5 * (1.0 + math.sin(animValue * 2 * math.pi)) / 2);

            return Transform.scale(
              scale: scale,
              child: Container(
                width: 2,
                height: 2,
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? AppColors.yellowAccent
                      : AppTheme.lightPrimaryColor,
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
