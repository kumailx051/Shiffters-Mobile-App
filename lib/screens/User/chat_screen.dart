import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shiffters/theme/app_colors.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  List<ChatMessage> messages = [
    ChatMessage(
      text: "Hello! I'm your driver for today's delivery. I'll be picking up your package shortly.",
      isUser: false,
      timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
      driverName: "John Smith",
    ),
    ChatMessage(
      text: "Great! What's the estimated pickup time?",
      isUser: true,
      timestamp: DateTime.now().subtract(const Duration(minutes: 28)),
    ),
    ChatMessage(
      text: "I'll be there in about 15 minutes. The package is ready for pickup, right?",
      isUser: false,
      timestamp: DateTime.now().subtract(const Duration(minutes: 25)),
      driverName: "John Smith",
    ),
    ChatMessage(
      text: "Yes, everything is ready. I'll be waiting at the main entrance.",
      isUser: true,
      timestamp: DateTime.now().subtract(const Duration(minutes: 20)),
    ),
    ChatMessage(
      text: "Perfect! I'm on my way. You can track my location in real-time through the app.",
      isUser: false,
      timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
      driverName: "John Smith",
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
    
    // Auto scroll to bottom when new messages arrive
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
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

  void _sendMessage() {
    if (_messageController.text.trim().isNotEmpty) {
      setState(() {
        messages.add(
          ChatMessage(
            text: _messageController.text.trim(),
            isUser: true,
            timestamp: DateTime.now(),
          ),
        );
      });
      
      _messageController.clear();
      
      // Auto scroll to bottom after sending message
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollToBottom();
      });
      
      // Simulate driver response after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            messages.add(
              ChatMessage(
                text: "Thanks for the update! I'll keep you posted on the delivery status.",
                isUser: false,
                timestamp: DateTime.now(),
                driverName: "John Smith",
              ),
            );
          });
          _scrollToBottom();
        }
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: _buildAppBar(isTablet),
      body: Column(
        children: [
          // Driver Info Card
          _buildDriverInfoCard(isTablet),
          
          // Messages List
          Expanded(
            child: _buildMessagesList(isTablet),
          ),
          
          // Message Input
          _buildMessageInput(isTablet),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isTablet) {
    return AppBar(
      backgroundColor: const Color(0xFF2D2D3C),
      elevation: 0,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios,
          color: Colors.white,
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
              color: AppColors.yellowAccent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.yellowAccent.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.person,
              color: Colors.black,
              size: isTablet ? 20 : 18,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'John Smith',
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 16 : 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                'Your Driver',
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 12 : 10,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.phone,
            color: AppColors.yellowAccent,
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
            color: Colors.white,
            size: isTablet ? 24 : 20,
          ),
          onPressed: () {
            // Handle more options
          },
        ),
      ],
    );
  }

  Widget _buildDriverInfoCard(bool isTablet) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: EdgeInsets.all(isTablet ? 20 : 16),
        padding: EdgeInsets.all(isTablet ? 20 : 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: isTablet ? 50 : 45,
              height: isTablet ? 50 : 45,
              decoration: BoxDecoration(
                color: AppColors.yellowAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.local_shipping,
                color: AppColors.yellowAccent,
                size: isTablet ? 25 : 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Package #SH123548',
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 16 : 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'En route to destination',
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 12 : 11,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
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

  Widget _buildMessagesList(bool isTablet) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 20 : 16,
          vertical: 8,
        ),
        itemCount: messages.length,
        itemBuilder: (context, index) {
          return _buildMessageBubble(messages[index], isTablet);
        },
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isTablet) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: message.isUser 
            ? MainAxisAlignment.end 
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              width: isTablet ? 35 : 30,
              height: isTablet ? 35 : 30,
              decoration: BoxDecoration(
                color: AppColors.yellowAccent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person,
                color: Colors.black,
                size: isTablet ? 18 : 16,
              ),
            ),
            const SizedBox(width: 12),
          ],
          
          Flexible(
            child: Column(
              crossAxisAlignment: message.isUser 
                  ? CrossAxisAlignment.end 
                  : CrossAxisAlignment.start,
              children: [
                if (!message.isUser && message.driverName != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      message.driverName!,
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 12 : 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.yellowAccent,
                      ),
                    ),
                  ),
                
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 16 : 14,
                    vertical: isTablet ? 12 : 10,
                  ),
                  decoration: BoxDecoration(
                    color: message.isUser 
                        ? AppColors.yellowAccent 
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(message.isUser ? 16 : 4),
                      bottomRight: Radius.circular(message.isUser ? 4 : 16),
                    ),
                    border: message.isUser 
                        ? null 
                        : Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                  ),
                  child: Text(
                    message.text,
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 14 : 13,
                      fontWeight: FontWeight.w400,
                      color: message.isUser ? Colors.black : Colors.white,
                    ),
                  ),
                ),
                
                const SizedBox(height: 4),
                
                Text(
                  _formatTime(message.timestamp),
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 10 : 9,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          
          if (message.isUser) ...[
            const SizedBox(width: 12),
            Container(
              width: isTablet ? 35 : 30,
              height: isTablet ? 35 : 30,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.person,
                color: Colors.white,
                size: isTablet ? 18 : 16,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageInput(bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D3C),
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _messageController,
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 14 : 13,
                    color: Colors.white,
                    fontWeight: FontWeight.w400,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: GoogleFonts.albertSans(
                      color: Colors.white.withOpacity(0.5),
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
                  color: AppColors.yellowAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.yellowAccent.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.send,
                  color: Colors.black,
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
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? driverName;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.driverName,
  });
}