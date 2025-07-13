import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shiffters/theme/app_colors.dart';
import 'package:shiffters/screens/User/chat_screen.dart';

class MessageScreen extends StatefulWidget {
  const MessageScreen({super.key});

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  
  List<Conversation> conversations = [
    Conversation(
      id: '1',
      driverName: 'John Smith',
      driverImage: null,
      lastMessage: 'Perfect! I\'m on my way. You can track my location in real-time through the app.',
      timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
      unreadCount: 0,
      isOnline: true,
      packageId: '#SH123548',
      status: 'In Transit',
    ),
    Conversation(
      id: '2',
      driverName: 'Sarah Johnson',
      driverImage: null,
      lastMessage: 'Your package has been delivered successfully. Thank you for choosing Speedway!',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      unreadCount: 0,
      isOnline: false,
      packageId: '#SH123547',
      status: 'Delivered',
    ),
    Conversation(
      id: '3',
      driverName: 'Mike Wilson',
      driverImage: null,
      lastMessage: 'I\'ll be there in 10 minutes for pickup. Please have the package ready.',
      timestamp: DateTime.now().subtract(const Duration(hours: 4)),
      unreadCount: 2,
      isOnline: true,
      packageId: '#SH123546',
      status: 'Pickup Scheduled',
    ),
    Conversation(
      id: '4',
      driverName: 'Emma Davis',
      driverImage: null,
      lastMessage: 'Package picked up successfully. Estimated delivery time is 2 hours.',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      unreadCount: 0,
      isOnline: false,
      packageId: '#SH123545',
      status: 'Delivered',
    ),
    Conversation(
      id: '5',
      driverName: 'Alex Rodriguez',
      driverImage: null,
      lastMessage: 'There\'s a slight delay due to traffic. Will update you shortly.',
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
      unreadCount: 1,
      isOnline: false,
      packageId: '#SH123544',
      status: 'Delayed',
    ),
    Conversation(
      id: '6',
      driverName: 'Lisa Chen',
      driverImage: null,
      lastMessage: 'Package delivered to the front desk as requested. Have a great day!',
      timestamp: DateTime.now().subtract(const Duration(days: 3)),
      unreadCount: 0,
      isOnline: false,
      packageId: '#SH123543',
      status: 'Delivered',
    ),
  ];

  List<Conversation> filteredConversations = [];

  @override
  void initState() {
    super.initState();
    filteredConversations = List.from(conversations);
    _initializeAnimations();
    _startAnimations();
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

  void _filterConversations(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredConversations = List.from(conversations);
      } else {
        filteredConversations = conversations.where((conversation) {
          return conversation.driverName.toLowerCase().contains(query.toLowerCase()) ||
                 conversation.packageId.toLowerCase().contains(query.toLowerCase()) ||
                 conversation.lastMessage.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  void _deleteConversation(int index, Conversation conversation) {
    // Add haptic feedback
    HapticFeedback.mediumImpact();
    
    // Remove from both lists
    final originalIndex = conversations.indexOf(conversation);
    conversations.removeAt(originalIndex);
    
    setState(() {
      filteredConversations.removeAt(index);
    });

    // Show snackbar with undo option
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF2D2D3C),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: Row(
          children: [
            Icon(
              Icons.delete_outline,
              color: AppColors.yellowAccent,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Conversation with ${conversation.driverName} deleted',
                style: GoogleFonts.albertSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'Undo',
          textColor: AppColors.yellowAccent,
          onPressed: () {
            _undoDelete(originalIndex, conversation);
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _undoDelete(int originalIndex, Conversation conversation) {
    HapticFeedback.lightImpact();
    
    // Add back to original position
    conversations.insert(originalIndex, conversation);
    
    // Refresh filtered list
    _filterConversations(_searchController.text);
  }

  void _openChat(Conversation conversation) {
    HapticFeedback.lightImpact();
    
    // Mark conversation as read
    setState(() {
      conversation.unreadCount = 0;
    });
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ChatScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
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
          // Search Bar
          _buildSearchBar(isTablet),
          
          // Messages List
          Expanded(
            child: _buildMessagesList(isTablet),
          ),
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
            width: isTablet ? 35 : 30,
            height: isTablet ? 35 : 30,
            decoration: BoxDecoration(
              color: AppColors.yellowAccent,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: AppColors.yellowAccent.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              color: Colors.black,
              size: isTablet ? 18 : 16,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Messages',
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 20 : 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.more_vert,
            color: Colors.white,
            size: isTablet ? 24 : 20,
          ),
          onPressed: () {
            _showMoreOptions();
          },
        ),
      ],
    );
  }

  Widget _buildSearchBar(bool isTablet) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: EdgeInsets.all(isTablet ? 20 : 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
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
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: 'Search messages...',
            hintStyle: GoogleFonts.albertSans(
              color: Colors.white.withOpacity(0.6),
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: Colors.white.withOpacity(0.7),
              size: isTablet ? 24 : 20,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear,
                      color: Colors.white.withOpacity(0.7),
                      size: isTablet ? 20 : 18,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      _filterConversations('');
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25),
              borderSide: BorderSide(
                color: AppColors.yellowAccent,
                width: 2,
              ),
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

  Widget _buildMessagesList(bool isTablet) {
    if (filteredConversations.isEmpty) {
      return _buildEmptyState(isTablet);
    }

    return SlideTransition(
      position: _slideAnimation,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: isTablet ? 20 : 16),
        itemCount: filteredConversations.length,
        itemBuilder: (context, index) {
          return _buildSwipeableConversationTile(
            filteredConversations[index], 
            index, 
            isTablet
          );
        },
      ),
    );
  }

  Widget _buildSwipeableConversationTile(Conversation conversation, int index, bool isTablet) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: Key(conversation.id),
        direction: DismissDirection.endToStart,
        dismissThresholds: const {
          DismissDirection.endToStart: 0.3,
        },
        background: _buildSwipeBackground(isTablet),
        confirmDismiss: (direction) async {
          // Add haptic feedback when swipe threshold is reached
          HapticFeedback.mediumImpact();
          return await _showDeleteConfirmation(conversation);
        },
        onDismissed: (direction) {
          _deleteConversation(index, conversation);
        },
        child: _buildConversationTile(conversation, isTablet),
      ),
    );
  }

  Widget _buildSwipeBackground(bool isTablet) {
    return Container(
      alignment: Alignment.centerRight,
      padding: EdgeInsets.only(right: isTablet ? 30 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.red.withOpacity(0.1),
            Colors.red.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.delete_outline,
            color: Colors.white,
            size: isTablet ? 28 : 24,
          ),
          const SizedBox(height: 4),
          Text(
            'Delete',
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 12 : 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _showDeleteConfirmation(Conversation conversation) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2D2D3C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.delete_outline,
                color: Colors.red,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Delete Conversation',
                style: GoogleFonts.albertSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          content: RichText(
            text: TextSpan(
              style: GoogleFonts.albertSans(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.white.withOpacity(0.8),
              ),
              children: [
                const TextSpan(text: 'Are you sure you want to delete the conversation with '),
                TextSpan(
                  text: conversation.driverName,
                  style: GoogleFonts.albertSans(
                    fontWeight: FontWeight.w600,
                    color: AppColors.yellowAccent,
                  ),
                ),
                const TextSpan(text: '? This action can be undone within 4 seconds.'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: GoogleFonts.albertSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                backgroundColor: Colors.red.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Delete',
                style: GoogleFonts.albertSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        );
      },
    ) ?? false;
  }

  Widget _buildConversationTile(Conversation conversation, bool isTablet) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openChat(conversation),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(isTablet ? 20 : 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Driver Avatar
              Stack(
                children: [
                  Container(
                    width: isTablet ? 55 : 50,
                    height: isTablet ? 55 : 50,
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
                      size: isTablet ? 25 : 22,
                    ),
                  ),
                  
                  // Online Status Indicator
                  if (conversation.isOnline)
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        width: isTablet ? 16 : 14,
                        height: isTablet ? 16 : 14,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF1E1E2C),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              
              const SizedBox(width: 16),
              
              // Message Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Driver Name and Package ID
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            conversation.driverName,
                            style: GoogleFonts.albertSans(
                              fontSize: isTablet ? 16 : 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _formatTime(conversation.timestamp),
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 11 : 10,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // Package ID and Status
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.yellowAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            conversation.packageId,
                            style: GoogleFonts.albertSans(
                              fontSize: isTablet ? 10 : 9,
                              fontWeight: FontWeight.w500,
                              color: AppColors.yellowAccent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(conversation.status).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            conversation.status,
                            style: GoogleFonts.albertSans(
                              fontSize: isTablet ? 10 : 9,
                              fontWeight: FontWeight.w500,
                              color: _getStatusColor(conversation.status),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Last Message
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.lastMessage,
                            style: GoogleFonts.albertSans(
                              fontSize: isTablet ? 13 : 12,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withOpacity(0.7),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        
                        // Unread Count Badge
                        if (conversation.unreadCount > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.yellowAccent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              conversation.unreadCount.toString(),
                              style: GoogleFonts.albertSans(
                                fontSize: isTablet ? 11 : 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
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
      ),
    );
  }

  Widget _buildEmptyState(bool isTablet) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: isTablet ? 100 : 80,
              height: isTablet ? 100 : 80,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline,
                size: isTablet ? 50 : 40,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _searchController.text.isNotEmpty 
                  ? 'No messages found'
                  : 'No messages yet',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 18 : 16,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchController.text.isNotEmpty
                  ? 'Try searching with different keywords'
                  : 'Your conversations with drivers will appear here',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 14 : 12,
                fontWeight: FontWeight.w400,
                color: Colors.white.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return Colors.green;
      case 'in transit':
        return Colors.blue;
      case 'pickup scheduled':
        return AppColors.yellowAccent;
      case 'delayed':
        return Colors.orange;
      default:
        return Colors.grey;
    }
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

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2D2D3C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              
              _buildBottomSheetOption(
                icon: Icons.mark_chat_read,
                title: 'Mark all as read',
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    for (var conversation in conversations) {
                      conversation.unreadCount = 0;
                    }
                  });
                },
              ),
              
              _buildBottomSheetOption(
                icon: Icons.delete_outline,
                title: 'Clear all messages',
                onTap: () {
                  Navigator.pop(context);
                  _showClearConfirmation();
                },
              ),
              
              _buildBottomSheetOption(
                icon: Icons.settings,
                title: 'Message settings',
                onTap: () {
                  Navigator.pop(context);
                  // Handle settings
                },
              ),
              
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomSheetOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: Colors.white,
        size: 24,
      ),
      title: Text(
        title,
        style: GoogleFonts.albertSans(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  void _showClearConfirmation() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2D2D3C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Clear All Messages',
            style: GoogleFonts.albertSans(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          content: Text(
            'Are you sure you want to clear all messages? This action cannot be undone.',
            style: GoogleFonts.albertSans(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.albertSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  conversations.clear();
                  filteredConversations.clear();
                });
              },
              child: Text(
                'Clear',
                style: GoogleFonts.albertSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class Conversation {
  final String id;
  final String driverName;
  final String? driverImage;
  final String lastMessage;
  final DateTime timestamp;
  int unreadCount;
  final bool isOnline;
  final String packageId;
  final String status;

  Conversation({
    required this.id,
    required this.driverName,
    this.driverImage,
    required this.lastMessage,
    required this.timestamp,
    required this.unreadCount,
    required this.isOnline,
    required this.packageId,
    required this.status,
  });
}