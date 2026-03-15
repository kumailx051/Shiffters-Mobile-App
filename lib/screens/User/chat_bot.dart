import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shiffters/theme/app_colors.dart';
import 'package:shiffters/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shiffters/services/theme_service.dart';
import 'dart:math' as math;

class ChatBotScreen extends StatefulWidget {
  const ChatBotScreen({super.key});

  @override
  State<ChatBotScreen> createState() => _ChatBotScreenState();
}

class _ChatBotScreenState extends State<ChatBotScreen>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  late AnimationController _animationController;

  // Gemini API configuration
  static const String _apiKey = 'AIzaSyCl17XZcG8tEutCM-hE_ul3KJf8MepbCYM';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  // App-specific context and knowledge base
  static const String _appContext = '''
You are SHIFFTERS AI Assistant, a specialized chatbot for the SHIFFTERS moving and relocation app. 

ABOUT SHIFFTERS:
- SHIFFTERS is a comprehensive moving and relocation service app
- Services include: Home shifting, office relocation, pickup & drop services, package tracking
- Features: Real-time tracking, location-based services, AI recommendations, order management
- The app helps users with moving, packing, transportation, and delivery services
- Users can book services, track packages, manage orders, and get moving assistance

YOUR ROLE:
- ONLY answer questions related to moving, relocation, shipping, delivery, packing, transportation, and SHIFFTERS app features
- Provide helpful information about moving tips, packing advice, relocation planning, and app usage
- Be friendly, professional, and focused on moving/logistics topics
- If asked about unrelated topics, politely redirect to moving/relocation services
- Provide responses in plain text without markdown formatting like ** or ## or other special characters

TOPICS YOU CAN HELP WITH:
✅ Moving and relocation services
✅ Packing tips and advice
✅ Transportation and logistics
✅ Package tracking and delivery
✅ Moving cost estimates
✅ Relocation planning
✅ SHIFFTERS app features and usage
✅ Moving safety and best practices
✅ Storage solutions
✅ Moving timelines and scheduling

TOPICS TO DECLINE:
❌ General knowledge questions unrelated to moving
❌ Programming, technology (unless app-related)
❌ Medical, legal, financial advice
❌ Entertainment, sports, politics
❌ Personal relationships
❌ Academic subjects unrelated to logistics

If asked about unrelated topics, respond with: "I'm specialized in helping with moving, relocation, and delivery services through SHIFFTERS. How can I assist you with your moving needs today?"
''';

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _addWelcomeMessage();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Animation controller is initialized but no longer using fade animation
    _animationController.forward();
  }

  void _addWelcomeMessage() {
    setState(() {
      _messages.add(ChatMessage(
        text:
            "Hello! I'm your SHIFFTERS AI assistant. I'm here to help you with all your moving, relocation, and delivery needs. Whether you need packing tips, moving advice, or help using the app, I'm ready to assist! How can I help you today?",
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  bool _isMovingRelated(String message) {
    // Keywords related to moving, relocation, and app services
    final movingKeywords = [
      'move',
      'moving',
      'relocation',
      'relocate',
      'shift',
      'shifting',
      'transport',
      'delivery',
      'package',
      'pickup',
      'drop',
      'packing',
      'pack',
      'unpack',
      'truck',
      'vehicle',
      'shipping',
      'freight',
      'logistics',
      'storage',
      'box',
      'boxes',
      'furniture',
      'household',
      'office',
      'commercial',
      'track',
      'tracking',
      'order',
      'booking',
      'schedule',
      'estimate',
      'cost',
      'price',
      'quote',
      'service',
      'shiffters',
      'app',
      'location',
      'address',
      'distance',
      'time',
      'safety',
      'insurance',
      'fragile',
      'heavy',
      'loading',
      'unloading',
      'driver',
      'team',
      'crew',
      'apartment',
      'house',
      'home',
      'building',
      'floor',
      'stairs',
      'elevator',
      'parking',
      'access',
      'inventory',
      'checklist'
    ];

    final lowerMessage = message.toLowerCase();
    return movingKeywords.any((keyword) => lowerMessage.contains(keyword));
  }

  String _cleanMarkdownFormatting(String text) {
    // Remove markdown formatting
    String cleanedText = text;

    // Remove bold formatting (**text**)
    cleanedText = cleanedText.replaceAll(RegExp(r'\*\*(.*?)\*\*'), r'$1');

    // Remove italic formatting (*text*)
    cleanedText = cleanedText.replaceAll(RegExp(r'\*(.*?)\*'), r'$1');

    // Remove headers (## text)
    cleanedText =
        cleanedText.replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '');

    // Remove other markdown symbols that might appear
    cleanedText = cleanedText.replaceAll(
        RegExp(r'`(.*?)`'), r'$1'); // Remove code formatting
    cleanedText = cleanedText.replaceAll(
        RegExp(r'~~(.*?)~~'), r'$1'); // Remove strikethrough

    // Clean up extra whitespace
    cleanedText = cleanedText.replaceAll(
        RegExp(r'\n\s*\n'), '\n\n'); // Multiple newlines to double newline
    cleanedText = cleanedText.trim();

    return cleanedText;
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    // Add user message
    setState(() {
      _messages.add(ChatMessage(
        text: message,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      // Check if the message is related to moving/relocation
      if (!_isMovingRelated(message)) {
        setState(() {
          _messages.add(ChatMessage(
            text:
                "I'm specialized in helping with moving, relocation, and delivery services through SHIFFTERS. I can assist you with:\n\n• Moving and packing tips\n• Relocation planning\n• Package tracking\n• Service bookings\n• Moving cost estimates\n• App features and usage\n\nHow can I help you with your moving needs today?",
            isUser: false,
            timestamp: DateTime.now(),
          ));
          _isLoading = false;
        });
        _scrollToBottom();
        return;
      }

      final response = await _callGeminiAPI(message);

      setState(() {
        _messages.add(ChatMessage(
          text: response,
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text:
              "Sorry, I'm having trouble connecting right now. Please try again later, or feel free to ask me about moving services, packing tips, or how to use the SHIFFTERS app!",
          isUser: false,
          timestamp: DateTime.now(),
          isError: true,
        ));
        _isLoading = false;
      });
    }

    _scrollToBottom();
  }

  Future<String> _callGeminiAPI(String message) async {
    final url = Uri.parse('$_baseUrl?key=$_apiKey');

    final requestBody = {
      'contents': [
        {
          'parts': [
            {
              'text':
                  '$_appContext\n\nUser Question: $message\n\nPlease provide a helpful response focused on moving, relocation, or SHIFFTERS app services. Use plain text without any markdown formatting:'
            }
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.7,
        'topK': 40,
        'topP': 0.95,
        'maxOutputTokens': 1024,
      },
      'safetySettings': [
        {
          'category': 'HARM_CATEGORY_HARASSMENT',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
        },
        {
          'category': 'HARM_CATEGORY_HATE_SPEECH',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
        }
      ]
    };

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: json.encode(requestBody),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      String aiResponse = data['candidates'][0]['content']['parts'][0]['text'];

      // Clean markdown formatting from the response
      aiResponse = _cleanMarkdownFormatting(aiResponse);

      // Additional filtering to ensure response stays on topic
      if (!_isResponseAppropriate(aiResponse)) {
        return "I'm here to help specifically with moving, relocation, and delivery services. Could you please ask me something related to your moving needs or how to use the SHIFFTERS app?";
      }

      return aiResponse;
    } else {
      throw Exception('Failed to get response from Gemini API');
    }
  }

  bool _isResponseAppropriate(String response) {
    final inappropriateTopics = [
      'programming',
      'code',
      'software development',
      'politics',
      'religion',
      'medical advice',
      'legal advice',
      'financial advice',
      'investment',
      'cryptocurrency',
      'dating',
      'relationship',
      'entertainment',
      'movies',
      'sports',
      'games',
      'cooking',
      'recipes',
      'weather',
      'news'
    ];

    final lowerResponse = response.toLowerCase();

    // If response contains inappropriate topics and doesn't mention moving/logistics
    bool hasInappropriate =
        inappropriateTopics.any((topic) => lowerResponse.contains(topic));
    bool hasMovingContent = _isMovingRelated(response);

    return !hasInappropriate || hasMovingContent;
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
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        final isDarkMode = themeService.isDarkMode;
        final accent =
            isDarkMode ? AppColors.yellowAccent : AppTheme.lightPrimaryColor;

        // Set system UI overlay style based on theme
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                isDarkMode ? Brightness.light : Brightness.dark,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness:
                isDarkMode ? Brightness.light : Brightness.dark,
          ),
        );

        return Scaffold(
          backgroundColor:
              isDarkMode ? const Color(0xFF1E1E2C) : Colors.grey[50],
          appBar: null,
          body: Column(
            children: [
              // Header with gradient background like dashboard
              Container(
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
                    padding:
                        EdgeInsets.symmetric(horizontal: isTablet ? 20 : 16),
                    child: Row(
                      children: [
                        // Back button
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // AI Assistant icon
                        Container(
                          width: isTablet ? 42 : 38,
                          height: isTablet ? 42 : 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.smart_toy_rounded,
                            color: Colors.white,
                            size: isTablet ? 24 : 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Title
                        Text(
                          'SHIFFTERS AI Assistant',
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 24 : 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Chat Messages
              Expanded(
                child: _buildChatArea(isTablet, isDarkMode, accent),
              ),

              // Input Area
              _buildInputArea(isTablet, isDarkMode, accent),
            ],
          ),
        );
      },
    );
  }

  // Old header implementation removed - now using inline gradient header

  Widget _buildChatArea(bool isTablet, bool isDarkMode, Color accent) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 24 : 16,
        vertical: isTablet ? 16 : 12,
      ),
      child: ListView.builder(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        itemCount: _messages.length + (_isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _messages.length && _isLoading) {
            return _buildTypingIndicator(isTablet, isDarkMode, accent);
          }

          final message = _messages[index];
          return _buildMessageBubble(message, isTablet, isDarkMode, accent);
        },
      ),
    );
  }

  Widget _buildMessageBubble(
      ChatMessage message, bool isTablet, bool isDarkMode, Color accent) {
    return Container(
      margin: EdgeInsets.only(
        bottom: isTablet ? 16 : 12,
        left: message.isUser ? (isTablet ? 60 : 40) : 0,
        right: message.isUser ? 0 : (isTablet ? 60 : 40),
      ),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              width: isTablet ? 40 : 32,
              height: isTablet ? 40 : 32,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: accent,
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.smart_toy,
                color: accent,
                size: isTablet ? 20 : 16,
              ),
            ),
            SizedBox(width: isTablet ? 12 : 8),
          ],
          Flexible(
            child: Container(
              padding: EdgeInsets.all(isTablet ? 16 : 12),
              decoration: BoxDecoration(
                color: message.isUser
                    ? accent
                    : (message.isError
                        ? Colors.red.withValues(alpha: 0.1)
                        : isDarkMode
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.white),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(message.isUser ? 16 : 4),
                  bottomRight: Radius.circular(message.isUser ? 4 : 16),
                ),
                border: message.isError
                    ? Border.all(
                        color: Colors.red.withValues(alpha: 0.3), width: 1)
                    : !isDarkMode && !message.isUser
                        ? Border.all(
                            color: Colors.grey.withValues(alpha: 0.2), width: 1)
                        : null,
                boxShadow: !isDarkMode && !message.isUser
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 16 : 14,
                      color: message.isUser
                          ? (isDarkMode ? Colors.black : Colors.white)
                          : (message.isError
                              ? Colors.red
                              : isDarkMode
                                  ? Colors.white
                                  : Colors.black),
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: isTablet ? 8 : 4),
                  Text(
                    _formatTime(message.timestamp),
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 12 : 10,
                      color: message.isUser
                          ? (isDarkMode
                              ? Colors.black.withValues(alpha: 0.6)
                              : Colors.white.withValues(alpha: 0.7))
                          : (isDarkMode
                              ? Colors.white.withValues(alpha: 0.5)
                              : Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (message.isUser) ...[
            SizedBox(width: isTablet ? 12 : 8),
            Container(
              width: isTablet ? 40 : 32,
              height: isTablet ? 40 : 32,
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.grey[100],
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.3)
                      : Colors.grey.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.person,
                color: isDarkMode ? Colors.white : Colors.grey[700],
                size: isTablet ? 20 : 16,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(bool isTablet, bool isDarkMode, Color accent) {
    return Container(
      margin: EdgeInsets.only(
        bottom: isTablet ? 16 : 12,
        right: isTablet ? 60 : 40,
      ),
      child: Row(
        children: [
          Container(
            width: isTablet ? 40 : 32,
            height: isTablet ? 40 : 32,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: accent,
                width: 1,
              ),
            ),
            child: Icon(
              Icons.smart_toy,
              color: accent,
              size: isTablet ? 20 : 16,
            ),
          ),
          SizedBox(width: isTablet ? 12 : 8),
          Container(
            padding: EdgeInsets.all(isTablet ? 16 : 12),
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
              border: !isDarkMode
                  ? Border.all(
                      color: Colors.grey.withValues(alpha: 0.2),
                      width: 1,
                    )
                  : null,
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
                _buildTypingDot(0, accent),
                SizedBox(width: isTablet ? 4 : 2),
                _buildTypingDot(1, accent),
                SizedBox(width: isTablet ? 4 : 2),
                _buildTypingDot(2, accent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingDot(int index, Color accent) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.5 +
              (0.5 * (1 + math.sin((value * 2 * math.pi) + (index * 0.5)))),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputArea(bool isTablet, bool isDarkMode, Color accent) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 24 : 16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.white,
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
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.grey.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _messageController,
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 16 : 14,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                decoration: InputDecoration(
                  hintText: 'Ask about moving, packing, or app features...',
                  hintStyle: GoogleFonts.albertSans(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.5)
                        : Colors.grey[600],
                    fontSize: isTablet ? 16 : 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 20 : 16,
                    vertical: isTablet ? 16 : 12,
                  ),
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          SizedBox(width: isTablet ? 16 : 12),
          GestureDetector(
            onTap: _isLoading ? null : _sendMessage,
            child: Container(
              width: isTablet ? 56 : 48,
              height: isTablet ? 56 : 48,
              decoration: BoxDecoration(
                color: _isLoading ? Colors.grey.withValues(alpha: 0.3) : accent,
                shape: BoxShape.circle,
                boxShadow: _isLoading
                    ? null
                    : [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Icon(
                Icons.send,
                color: _isLoading
                    ? Colors.grey
                    : (isDarkMode ? Colors.black : Colors.white),
                size: isTablet ? 24 : 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
  });
}
