import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shiffters/theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:shiffters/services/theme_service.dart';

class DriverChatScreen extends StatefulWidget {
  final String? chatId;
  final String? customerName;
  final String? orderId;
  
  const DriverChatScreen({
    super.key,
    this.chatId,
    this.customerName,
    this.orderId,
  });

  @override
  State<DriverChatScreen> createState() => _DriverChatScreenState();
}

class _DriverChatScreenState extends State<DriverChatScreen> with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isTyping = false;
  bool _isOnline = true;

  // Mock chat messages
  List<Map<String, dynamic>> _messages = [
    {
      'id': '1',
      'text': 'Hi! I\'m your driver for today. I\'m on my way to the pickup location.',
      'sender': 'driver',
      'timestamp': DateTime.now().subtract(const Duration(minutes: 15)),
      'isRead': true,
    },
    {
      'id': '2',
      'text': 'Great! Thank you for the update. How long will it take?',
      'sender': 'customer',
      'timestamp': DateTime.now().subtract(const Duration(minutes: 14)),
      'isRead': true,
    },
    {
      'id': '3',
      'text': 'I should be there in about 10 minutes. Traffic is light.',
      'sender': 'driver',
      'timestamp': DateTime.now().subtract(const Duration(minutes: 13)),
      'isRead': true,
    },
    {
      'id': '4',
      'text': 'Perfect! I\'ll be ready with the items.',
      'sender': 'customer',
      'timestamp': DateTime.now().subtract(const Duration(minutes: 12)),
      'isRead': true,
    },
    {
      'id': '5',
      'text': 'I\'ve arrived at the pickup location. I\'m in a blue truck.',
      'sender': 'driver',
      'timestamp': DateTime.now().subtract(const Duration(minutes: 5)),
      'isRead': true,
    },
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
    _scrollToBottom();
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    final message = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'text': _messageController.text.trim(),
      'sender': 'driver',
      'timestamp': DateTime.now(),
      'isRead': false,
    };

    setState(() {
      _messages.add(message);
      _messageController.clear();
    });

    HapticFeedback.lightImpact();
    _scrollToBottom();

    // Simulate customer typing response
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isTyping = true;
        });
      }
    });

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add({
            'id': DateTime.now().millisecondsSinceEpoch.toString(),
            'text': 'Thank you for the update!',
            'sender': 'customer',
            'timestamp': DateTime.now(),
            'isRead': false,
          });
        });
        _scrollToBottom();
      }
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
          backgroundColor: isDarkMode ? const Color(0xFF1E1E2C) : Colors.transparent,
          body: Container(
            decoration: isDarkMode
              ? null
              : const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/background/splashScreenBackground.jpg'),
                    fit: BoxFit.cover,
                  ),
                ),
            child: SafeArea(
              child: Column(
                children: [
                  // Header
                  _buildHeader(isTablet, isDarkMode),
                  
                  // Chat messages
                  Expanded(
                    child: _buildChatMessages(isTablet, isDarkMode),
                  ),
                  
                  // Message input
                  _buildMessageInput(isTablet, isDarkMode),
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
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 32 : 20,
          vertical: isTablet ? 24 : 16,
        ),
        decoration: BoxDecoration(
          color: isDarkMode 
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.9),
          border: Border(
            bottom: BorderSide(
              color: isDarkMode 
                ? Colors.white.withValues(alpha: 0.1)
                : AppColors.yellowAccent.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // Back button
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDarkMode 
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                  border: isDarkMode ? null : Border.all(
                    color: AppColors.yellowAccent.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.arrow_back,
                  size: isTablet ? 26 : 24,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Profile picture
            Container(
              width: isTablet ? 50 : 45,
              height: isTablet ? 50 : 45,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.yellowAccent,
                  width: 2,
                ),
                image: const DecorationImage(
                  image: AssetImage('assets/background/splashScreenBackground.jpg'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Customer info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.customerName ?? 'Customer',
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 18 : 16,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _isOnline ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isOnline ? 'Online' : 'Offline',
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 12 : 10,
                          color: isDarkMode ? Colors.white.withValues(alpha: 0.7) : Colors.black.withValues(alpha: 0.7),
                        ),
                      ),
                      if (widget.orderId != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '• Order #${widget.orderId}',
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 12 : 10,
                            color: isDarkMode ? Colors.white.withValues(alpha: 0.7) : Colors.black.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            
            // Call button
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _callCustomer();
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.call,
                  size: isTablet ? 24 : 20,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatMessages(bool isTablet, bool isDarkMode) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 32 : 20,
          vertical: isTablet ? 16 : 12,
        ),
        child: ListView.builder(
          controller: _scrollController,
          itemCount: _messages.length + (_isTyping ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == _messages.length && _isTyping) {
              return _buildTypingIndicator(isTablet, isDarkMode);
            }
            
            final message = _messages[index];
            final isDriver = message['sender'] == 'driver';
            final isLastMessage = index == _messages.length - 1;
            
            return _buildMessageBubble(
              message,
              isDriver,
              isLastMessage,
              isTablet,
              isDarkMode,
            );
          },
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
    Map<String, dynamic> message,
    bool isDriver,
    bool isLastMessage,
    bool isTablet,
    bool isDarkMode,
  ) {
    final timestamp = message['timestamp'] as DateTime;
    final timeString = '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    
    return Container(
      margin: EdgeInsets.only(
        bottom: isLastMessage ? 16 : 8,
        left: isDriver ? 60 : 0,
        right: isDriver ? 0 : 60,
      ),
      child: Column(
        crossAxisAlignment: isDriver ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(isTablet ? 16 : 12),
            decoration: BoxDecoration(
              color: isDriver 
                ? AppColors.yellowAccent
                : (isDarkMode 
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.9)),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isDriver ? 16 : 4),
                bottomRight: Radius.circular(isDriver ? 4 : 16),
              ),
              border: Border.all(
                color: isDriver 
                  ? AppColors.yellowAccent
                  : (isDarkMode 
                      ? Colors.white.withValues(alpha: 0.2)
                      : AppColors.yellowAccent.withValues(alpha: 0.3)),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isDriver ? AppColors.yellowAccent : Colors.grey).withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message['text'],
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 16 : 14,
                    color: isDriver 
                      ? Colors.black
                      : (isDarkMode ? Colors.white : Colors.black),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      timeString,
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 12 : 10,
                        color: isDriver 
                          ? Colors.black.withValues(alpha: 0.7)
                          : (isDarkMode 
                              ? Colors.white.withValues(alpha: 0.5)
                              : Colors.black.withValues(alpha: 0.5)),
                      ),
                    ),
                    if (isDriver) ...[
                      const SizedBox(width: 4),
                      Icon(
                        message['isRead'] ? Icons.done_all : Icons.done,
                        size: isTablet ? 16 : 14,
                        color: message['isRead'] 
                          ? Colors.blue
                          : Colors.black.withValues(alpha: 0.7),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(bool isTablet, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8, right: 60),
      child: Container(
        padding: EdgeInsets.all(isTablet ? 16 : 12),
        decoration: BoxDecoration(
          color: isDarkMode 
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.9),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(
            color: isDarkMode 
              ? Colors.white.withValues(alpha: 0.2)
              : AppColors.yellowAccent.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Typing',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 14 : 12,
                fontStyle: FontStyle.italic,
                color: isDarkMode ? Colors.white.withValues(alpha: 0.7) : Colors.black.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 20,
              height: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(3, (index) {
                  return AnimatedContainer(
                    duration: Duration(milliseconds: 300 + (index * 100)),
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.white.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput(bool isTablet, bool isDarkMode) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 32 : 20,
          vertical: isTablet ? 16 : 12,
        ),
        decoration: BoxDecoration(
          color: isDarkMode 
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.9),
          border: Border(
            top: BorderSide(
              color: isDarkMode 
                ? Colors.white.withValues(alpha: 0.1)
                : AppColors.yellowAccent.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // Quick message button
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _showQuickMessages();
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDarkMode 
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDarkMode 
                      ? Colors.white.withValues(alpha: 0.2)
                      : AppColors.yellowAccent.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.flash_on,
                  size: isTablet ? 24 : 20,
                  color: isDarkMode ? Colors.white.withValues(alpha: 0.7) : Colors.black.withValues(alpha: 0.7),
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Message input field
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isDarkMode 
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: isDarkMode 
                      ? Colors.white.withValues(alpha: 0.2)
                      : AppColors.yellowAccent.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _messageController,
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 16 : 14,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  maxLines: 3,
                  minLines: 1,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: GoogleFonts.albertSans(
                      fontSize: isTablet ? 16 : 14,
                      color: isDarkMode ? Colors.white.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.5),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onSubmitted: (value) => _sendMessage(),
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Send button
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.yellowAccent,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.yellowAccent.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.send,
                  size: isTablet ? 24 : 20,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _callCustomer() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Call Customer',
          style: GoogleFonts.albertSans(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Would you like to call ${widget.customerName ?? 'the customer'}?',
          style: GoogleFonts.albertSans(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.albertSans()),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.yellowAccent,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  content: Text(
                    'Calling customer...',
                    style: GoogleFonts.albertSans(color: Colors.black, fontWeight: FontWeight.w500),
                  ),
                ),
              );
            },
            child: Text('Call', style: GoogleFonts.albertSans(color: Colors.green)),
          ),
        ],
      ),
    );
  }

  void _showQuickMessages() {
    final quickMessages = [
      'I\'m on my way',
      'I\'ve arrived',
      'Running 5 minutes late',
      'Please provide more details',
      'Items loaded successfully',
      'Delivery completed',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Messages',
              style: GoogleFonts.albertSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...quickMessages.map((message) => ListTile(
              title: Text(
                message,
                style: GoogleFonts.albertSans(),
              ),
              onTap: () {
                Navigator.pop(context);
                _messageController.text = message;
                _sendMessage();
              },
            )),
          ],
        ),
      ),
    );
  }
}
