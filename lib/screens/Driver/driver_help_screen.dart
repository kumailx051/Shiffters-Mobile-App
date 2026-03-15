import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shiffters/theme/app_colors.dart';
import 'package:shiffters/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shiffters/services/theme_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DriverHelpScreen extends StatefulWidget {
  const DriverHelpScreen({super.key});

  @override
  State<DriverHelpScreen> createState() => _DriverHelpScreenState();
}

class _DriverHelpScreenState extends State<DriverHelpScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _replyController = TextEditingController();

  List<Map<String, dynamic>> _tickets = [];
  bool _isLoadingTickets = false;
  bool _isSubmittingReply = false;
  bool _isResolvingTicket = false;
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'General',
    'Shift Management',
    'Scheduling & Viewing',
    'Notes & Events',
    'Earnings & Stats'
  ];

  // FAQ data organized by categories matching the image
  final Map<String, List<Map<String, dynamic>>> _faqCategories = {
    'General': [
      {
        'question': 'What is Shiffters Mobile App?',
        'answer':
            'Shiffters is a comprehensive logistics platform that connects drivers with customers who need transportation services. Our mobile app allows drivers to manage their shifts, accept orders, track earnings, and communicate with customers seamlessly. The app provides real-time navigation, order management, and detailed analytics to help you maximize your earnings.',
        'isExpanded': false,
        'priority': 'High',
        'category': 'General',
      },
      {
        'question': 'Is Shiffters free?',
        'answer':
            'Yes, downloading and using the Shiffters driver app is completely free. There are no subscription fees or upfront costs. We only take a small commission from completed orders to maintain and improve our platform services. You can see the exact commission rate in your driver agreement.',
        'isExpanded': false,
        'priority': 'High',
        'category': 'General',
      },
      {
        'question': 'How do I get started as a driver?',
        'answer':
            'To get started: 1) Complete your driver registration with personal details, 2) Upload required documents (license, insurance, vehicle registration), 3) Wait for document verification (usually 24-48 hours), 4) Complete the onboarding tutorial, 5) Start accepting orders by going online in the app.',
        'isExpanded': false,
        'priority': 'High',
        'category': 'General',
      },
      {
        'question': 'What documents do I need to provide?',
        'answer':
            'Required documents include: Valid driver\'s license, Vehicle registration certificate, Insurance documents, Recent vehicle inspection certificate, Profile photo, and Bank account details for payments. All documents must be current and clearly visible.',
        'isExpanded': false,
        'priority': 'Medium',
        'category': 'General',
      },
      {
        'question': 'How do I contact customer support?',
        'answer':
            'You can contact support through: In-app chat support (24/7), Submit a ticket through this help section, Call our support hotline, or Email support@shiffters.com. For urgent issues, use the in-app chat for fastest response.',
        'isExpanded': false,
        'priority': 'Medium',
        'category': 'General',
      },
    ],
    'Shift Management': [
      {
        'question': 'How do I create and manage shifts?',
        'answer':
            'Go to the Shifts section in the app, tap "Create Shift", set your availability hours, select your service area, choose vehicle type, and save. You can edit shift details, change availability, or delete shifts anytime before they start. The app will notify you 30 minutes before your shift begins.',
        'isExpanded': false,
        'priority': 'High',
        'category': 'Shift Management',
      },
      {
        'question': 'Can I set reminders for my shifts?',
        'answer':
            'Yes, you can enable shift reminders in Settings > Notifications. The app will send push notifications 30 minutes, 15 minutes, and 5 minutes before your scheduled shift starts. You can customize reminder timing and choose notification sounds.',
        'isExpanded': false,
        'priority': 'Medium',
        'category': 'Shift Management',
      },
      {
        'question': 'Can I view multiple shifts per day?',
        'answer':
            'You can create multiple shifts throughout the day with at least 1-hour gap between them. The app ensures no overlap between shift times and recommends adequate rest periods. You can view all shifts in the daily, weekly, or monthly calendar view.',
        'isExpanded': false,
        'priority': 'Medium',
        'category': 'Shift Management',
      },
      {
        'question': 'How do I cancel or modify a shift?',
        'answer':
            'To modify a shift: Go to Shifts > Select the shift > Tap Edit. You can change timing, location, or vehicle type up to 2 hours before the shift starts. To cancel, tap Delete and confirm. Frequent cancellations may affect your driver rating.',
        'isExpanded': false,
        'priority': 'Low',
        'category': 'Shift Management',
      },
      {
        'question': 'What happens if I miss a shift?',
        'answer':
            'Missing shifts affects your reliability score and may impact future shift assignments. If you can\'t make a shift, cancel it at least 2 hours in advance. Emergency cancellations are understood but should be rare. Contact support if you have a valid emergency.',
        'isExpanded': false,
        'priority': 'Low',
        'category': 'Shift Management',
      },
    ],
    'Scheduling & Viewing': [
      {
        'question': 'What calendar views are available?',
        'answer':
            'The app offers multiple calendar views: Daily view (hourly breakdown), Weekly view (7-day overview), Monthly view (full month), and List view (chronological order). You can switch between views using the tabs at the top of the schedule screen.',
        'isExpanded': false,
        'priority': 'High',
        'category': 'Scheduling & Viewing',
      },
      {
        'question': 'Can I export my schedule?',
        'answer':
            'Yes, you can export your schedule in multiple formats: Export to device calendar (Google Calendar, Apple Calendar), Download as PDF file, Export as CSV for spreadsheet applications, or Share via email. Go to Schedule > Export and choose your preferred format.',
        'isExpanded': false,
        'priority': 'Medium',
        'category': 'Scheduling & Viewing',
      },
      {
        'question': 'How do I sync with my phone calendar?',
        'answer':
            'Enable calendar sync in Settings > Calendar Integration. Choose your default calendar app (Google Calendar, Apple Calendar, Outlook). The app will automatically add your Shiffters shifts to your phone calendar with reminders and location details.',
        'isExpanded': false,
        'priority': 'Medium',
        'category': 'Scheduling & Viewing',
      },
      {
        'question': 'Can I see my earnings in the calendar?',
        'answer':
            'Yes, the calendar view shows earnings for each completed shift. Tap on any completed shift to see detailed earnings breakdown including base fare, bonuses, tips, and total amount. You can also view weekly and monthly earning summaries.',
        'isExpanded': false,
        'priority': 'Low',
        'category': 'Scheduling & Viewing',
      },
      {
        'question': 'How do I filter my schedule view?',
        'answer':
            'Use the filter options at the top of the schedule screen to view: All shifts, Upcoming shifts only, Completed shifts, Cancelled shifts, or shifts by specific vehicle type. You can also search for specific dates or shift types.',
        'isExpanded': false,
        'priority': 'Low',
        'category': 'Scheduling & Viewing',
      },
    ],
    'Notes & Events': [
      {
        'question': 'Can I add notes or personal events?',
        'answer':
            'Yes, you can add personal notes and events to your calendar. Tap the "+" button and select "Add Note" or "Add Event". These are private to your account and help you keep track of important dates, maintenance schedules, or personal appointments alongside your work schedule.',
        'isExpanded': false,
        'priority': 'Medium',
        'category': 'Notes & Events',
      },
      {
        'question': 'How do I set event reminders?',
        'answer':
            'When creating a note or event, tap "Set Reminder" and choose your preferred notification time (5 minutes to 1 week before). You can set multiple reminders for important events. The app will send push notifications at your specified times.',
        'isExpanded': false,
        'priority': 'Medium',
        'category': 'Notes & Events',
      },
      {
        'question': 'Can I share events with other drivers?',
        'answer':
            'Currently, notes and events are private to your account for security reasons. However, you can coordinate with other drivers through the in-app messaging system or create group chats for team coordination and sharing important information.',
        'isExpanded': false,
        'priority': 'Low',
        'category': 'Notes & Events',
      },
      {
        'question': 'How do I organize my notes?',
        'answer':
            'You can organize notes using categories: Personal, Work, Maintenance, Important, or create custom categories. Use tags to make notes searchable, set priority levels (High, Medium, Low), and use color coding for quick visual identification.',
        'isExpanded': false,
        'priority': 'Low',
        'category': 'Notes & Events',
      },
      {
        'question': 'Can I attach files to notes?',
        'answer':
            'Yes, you can attach photos, documents, or voice recordings to your notes. This is useful for vehicle maintenance records, important documents, or voice memos. Maximum file size is 10MB per attachment.',
        'isExpanded': false,
        'priority': 'Low',
        'category': 'Notes & Events',
      },
    ],
    'Earnings & Stats': [
      {
        'question': 'How are my earnings calculated?',
        'answer':
            'Your earnings include: Base fare (distance + time), Surge pricing during high demand, Customer tips, Completion bonuses, Referral bonuses, and Special promotions. The app shows a detailed breakdown for each completed order with transparent calculation methods.',
        'isExpanded': false,
        'priority': 'High',
        'category': 'Earnings & Stats',
      },
      {
        'question': 'When do I receive payments?',
        'answer':
            'Payments are processed daily at midnight and transferred to your registered bank account within 24-48 hours (excluding weekends and holidays). You can track payment status in the Earnings section and view transaction history with detailed breakdowns.',
        'isExpanded': false,
        'priority': 'High',
        'category': 'Earnings & Stats',
      },
      {
        'question': 'Can I view my performance statistics?',
        'answer':
            'Yes, the app provides comprehensive statistics: Acceptance rate, Completion rate, Customer ratings (average and individual), Total distance driven, Total orders completed, Peak hour performance, Earnings trends over time, and Comparison with other drivers in your area.',
        'isExpanded': false,
        'priority': 'High',
        'category': 'Earnings & Stats',
      },
      {
        'question': 'How do I improve my driver rating?',
        'answer':
            'To improve your rating: Arrive on time, Communicate with customers, Keep your vehicle clean, Be professional and courteous, Follow GPS routes accurately, Handle items carefully, and Resolve issues promptly. High ratings lead to more order opportunities.',
        'isExpanded': false,
        'priority': 'Medium',
        'category': 'Earnings & Stats',
      },
      {
        'question': 'Can I see my tax information?',
        'answer':
            'Yes, the app provides tax-related information including: Annual earnings summary, Expense tracking, Mileage logs, 1099 forms (for US drivers), Monthly/quarterly reports, and Downloadable tax documents. Consult a tax professional for specific advice.',
        'isExpanded': false,
        'priority': 'Medium',
        'category': 'Earnings & Stats',
      },
      {
        'question': 'What are the different bonus types?',
        'answer':
            'Available bonuses include: Completion bonuses (for finishing orders), Peak hour bonuses (during high demand), Weekly targets (complete X orders), Referral bonuses (invite new drivers), Quality bonuses (high ratings), and Special event bonuses during holidays or promotions.',
        'isExpanded': false,
        'priority': 'Low',
        'category': 'Earnings & Stats',
      },
    ],
  };

  List<Map<String, dynamic>> _filteredFaqs = [];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
    _loadTickets();
    _filterFaqs();

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
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    _searchController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  void _filterFaqs() {
    setState(() {
      _filteredFaqs = [];

      if (_selectedCategory == 'All') {
        _faqCategories.forEach((category, faqs) {
          for (var faq in faqs) {
            final matchesSearch = _searchController.text.isEmpty ||
                faq['question']
                    .toLowerCase()
                    .contains(_searchController.text.toLowerCase()) ||
                faq['answer']
                    .toLowerCase()
                    .contains(_searchController.text.toLowerCase()) ||
                category
                    .toLowerCase()
                    .contains(_searchController.text.toLowerCase());

            if (matchesSearch) {
              final faqWithCategory = Map<String, dynamic>.from(faq);
              faqWithCategory['category'] = category;
              _filteredFaqs.add(faqWithCategory);
            }
          }
        });
      } else {
        final categoryFaqs = _faqCategories[_selectedCategory] ?? [];
        for (var faq in categoryFaqs) {
          final matchesSearch = _searchController.text.isEmpty ||
              faq['question']
                  .toLowerCase()
                  .contains(_searchController.text.toLowerCase()) ||
              faq['answer']
                  .toLowerCase()
                  .contains(_searchController.text.toLowerCase());

          if (matchesSearch) {
            final faqWithCategory = Map<String, dynamic>.from(faq);
            faqWithCategory['category'] = _selectedCategory;
            _filteredFaqs.add(faqWithCategory);
          }
        }
      }

      // Sort by priority: High -> Medium -> Low
      _filteredFaqs.sort((a, b) {
        const priorityOrder = {'High': 0, 'Medium': 1, 'Low': 2};
        return priorityOrder[a['priority']]!
            .compareTo(priorityOrder[b['priority']]!);
      });
    });
  }

  Future<void> _loadTickets() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isLoadingTickets = true;
    });

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('tickets')
          .where('uid', isEqualTo: user.uid)
          .where('role', isEqualTo: 'driver')
          .get();

      setState(() {
        _tickets = querySnapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();

        _tickets.sort((a, b) {
          final aTime = a['updatedAt'] as Timestamp?;
          final bTime = b['updatedAt'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });

        _isLoadingTickets = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingTickets = false;
      });
      _showGlowingSnackBar(
          'Error loading tickets: ${e.toString()}', Colors.red);
    }
  }

  Future<void> _submitTicket() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showGlowingSnackBar('Please login to submit ticket', Colors.red);
      return;
    }

    if (_subjectController.text.trim().isEmpty ||
        _messageController.text.trim().isEmpty) {
      _showGlowingSnackBar('Please fill in all fields', Colors.orange);
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('tickets').add({
        'uid': user.uid,
        'role': 'driver',
        'subject': _subjectController.text.trim(),
        'message': _messageController.text.trim(),
        'status': 'Open',
        'priority': 'Medium',
        'category': 'General',
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      _subjectController.clear();
      _messageController.clear();
      Navigator.of(context).pop();
      _showGlowingSnackBar('Ticket submitted successfully!', Colors.green);
      _loadTickets();
    } catch (e) {
      _showGlowingSnackBar(
          'Error submitting ticket: ${e.toString()}', Colors.red);
    }
  }

  Future<void> _submitReply(String ticketId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showGlowingSnackBar('Please login to submit reply', Colors.red);
      return;
    }

    if (_replyController.text.trim().isEmpty) {
      _showGlowingSnackBar('Please enter a reply message', Colors.orange);
      return;
    }

    setState(() {
      _isSubmittingReply = true;
    });

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userName = userDoc.data()?['name'] ?? 'Driver';

      await FirebaseFirestore.instance
          .collection('tickets')
          .doc(ticketId)
          .update({
        'driverResponses': FieldValue.arrayUnion([
          {
            'message': _replyController.text.trim(),
            'driverName': userName,
            'timestamp': Timestamp.now(),
          }
        ]),
        'status': 'In Progress',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _replyController.clear();
      _showGlowingSnackBar('Reply sent successfully!', Colors.green);
      _loadTickets();
      // Close and reopen the dialog to show updated content
      Navigator.of(context).pop();

      // Wait a moment for the data to refresh, then reopen the dialog
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        // Find the updated ticket
        final updatedTicket = _tickets.firstWhere(
          (t) => t['id'] == ticketId,
          orElse: () => <String, dynamic>{},
        );
        if (updatedTicket.isNotEmpty) {
          _showTicketDetailsDialog(
              updatedTicket,
              MediaQuery.of(context).size.width > 600,
              Provider.of<ThemeService>(context, listen: false).isDarkMode);
        }
      }
    } catch (e) {
      _showGlowingSnackBar(
          'Error submitting reply: ${e.toString()}', Colors.red);
    } finally {
      setState(() {
        _isSubmittingReply = false;
      });
    }
  }

  Future<void> _resolveTicket(String ticketId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showGlowingSnackBar('Please login to resolve ticket', Colors.red);
      return;
    }

    setState(() {
      _isResolvingTicket = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('tickets')
          .doc(ticketId)
          .update({
        'status': 'Resolved',
        'resolvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _showGlowingSnackBar('Ticket marked as resolved!', Colors.green);
      _loadTickets();
      Navigator.of(context).pop(); // Close the dialog
    } catch (e) {
      _showGlowingSnackBar(
          'Error resolving ticket: ${e.toString()}', Colors.red);
    } finally {
      setState(() {
        _isResolvingTicket = false;
      });
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

        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Scaffold(
              backgroundColor: isDarkMode
                  ? const Color(0xFF1E1E2C)
                  : AppTheme.lightBackgroundColor,
              appBar: null,
              body: Column(
                children: [
                  // Custom header like dashboard
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
                        padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 20 : 16),
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
                                  color: Colors.white.withValues(alpha: 0.2),
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
                            // Title
                            Text(
                              'Frequently Asked Questions',
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
                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 32 : 20,
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 20),

                            // Search bar
                            _buildSearchBar(isTablet, isDarkMode),

                            const SizedBox(height: 20),

                            // Category tabs
                            _buildCategoryTabs(isTablet, isDarkMode),

                            const SizedBox(height: 20),

                            // FAQ Categories or Filtered Results
                            if (_selectedCategory == 'All' &&
                                _searchController.text.isEmpty)
                              ..._buildFAQCategories(isTablet, isDarkMode)
                            else
                              _buildFilteredFAQs(isTablet, isDarkMode),

                            const SizedBox(height: 30),

                            // Contact Support Section
                            _buildContactSupport(isTablet, isDarkMode),

                            const SizedBox(height: 20),

                            // My Tickets Section
                            _buildMyTicketsSection(isTablet, isDarkMode),

                            const SizedBox(height: 100),
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
      },
    );
  }

  Widget _buildSearchBar(bool isTablet, bool isDarkMode) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        decoration: BoxDecoration(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : AppTheme.lightCardColor,
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
        child: TextField(
          controller: _searchController,
          onChanged: (value) => _filterFaqs(),
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
                ? 'Search FAQs, categories, keywords...'
                : 'Search FAQs, categories, keywords...',
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
                    Icons.search_rounded,
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
            suffixIcon: _searchController.text.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      _filterFaqs();
                    },
                    child: Container(
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.2)
                            : AppTheme.lightPrimaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.clear_rounded,
                        color: isDarkMode
                            ? Colors.white
                            : AppTheme.lightPrimaryColor,
                        size: 16,
                      ),
                    ),
                  )
                : null,
            filled: true,
            fillColor: isDarkMode ? Colors.transparent : Colors.transparent,
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

  Widget _buildCategoryTabs(bool isTablet, bool isDarkMode) {
    return SlideTransition(
      position: _slideAnimation,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: _categories.map((category) {
            final isSelected = _selectedCategory == category;
            int count = 0;

            if (category == 'All') {
              _faqCategories.forEach((key, value) {
                count += value.length;
              });
            } else {
              count = _faqCategories[category]?.length ?? 0;
            }

            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _selectedCategory = category;
                    _filterFaqs();
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 20 : 16,
                    vertical: isTablet ? 12 : 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDarkMode
                            ? AppColors.yellowAccent
                            : AppTheme.lightPrimaryColor)
                        : isDarkMode
                            ? Colors.white.withValues(alpha: 0.1)
                            : AppTheme.lightCardColor,
                    borderRadius: BorderRadius.circular(25),
                    border: isSelected
                        ? null
                        : Border.all(
                            color: isDarkMode
                                ? Colors.white.withValues(alpha: 0.2)
                                : AppTheme.lightPrimaryColor,
                            width: isDarkMode ? 1 : 1.5,
                          ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: isDarkMode
                                  ? AppColors.yellowAccent
                                      .withValues(alpha: 0.4)
                                  : AppTheme.lightPrimaryColor
                                      .withValues(alpha: 0.4),
                              blurRadius: 15,
                              offset: const Offset(0, 6),
                              spreadRadius: 1,
                            ),
                          ]
                        : isDarkMode
                            ? null
                            : [
                                BoxShadow(
                                  color: AppTheme.lightShadowLight,
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        category,
                        style: GoogleFonts.inter(
                          fontSize: isTablet ? 14 : 12,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? (isDarkMode ? Colors.black : Colors.white)
                              : isDarkMode
                                  ? Colors.white.withValues(alpha: 0.8)
                                  : AppTheme.lightTextPrimaryColor,
                        ),
                      ),
                      if (count > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDarkMode
                                    ? Colors.black.withValues(alpha: 0.2)
                                    : Colors.white.withValues(alpha: 0.3))
                                : (isDarkMode
                                    ? AppColors.yellowAccent
                                        .withValues(alpha: 0.3)
                                    : AppTheme.lightPrimaryColor
                                        .withValues(alpha: 0.2)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$count',
                            style: GoogleFonts.inter(
                              fontSize: isTablet ? 10 : 8,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? (isDarkMode ? Colors.black : Colors.white)
                                  : isDarkMode
                                      ? AppColors.yellowAccent
                                      : AppTheme.lightPrimaryColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  List<Widget> _buildFAQCategories(bool isTablet, bool isDarkMode) {
    final List<Widget> categoryWidgets = [];

    _faqCategories.forEach((categoryName, faqs) {
      categoryWidgets.add(
        SlideTransition(
          position: _slideAnimation,
          child:
              _buildCategorySection(categoryName, faqs, isTablet, isDarkMode),
        ),
      );
      categoryWidgets.add(const SizedBox(height: 20));
    });

    return categoryWidgets;
  }

  Widget _buildFilteredFAQs(bool isTablet, bool isDarkMode) {
    if (_filteredFaqs.isEmpty) {
      return _buildEmptyState(isTablet, isDarkMode);
    }

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        padding: EdgeInsets.all(isTablet ? 24 : 20),
        decoration: BoxDecoration(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : AppTheme.lightCardColor,
          borderRadius: BorderRadius.circular(isDarkMode ? 20 : 16),
          border: isDarkMode
              ? Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                )
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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? AppColors.yellowAccent.withValues(alpha: 0.2)
                        : AppTheme.lightPrimaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.quiz_rounded,
                    color: isDarkMode
                        ? AppColors.yellowAccent
                        : AppTheme.lightPrimaryColor,
                    size: isTablet ? 24 : 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedCategory == 'All'
                        ? 'Search Results'
                        : _selectedCategory,
                    style: GoogleFonts.inter(
                      fontSize: isTablet ? 18 : 16,
                      fontWeight: FontWeight.w700,
                      color: isDarkMode
                          ? Colors.white
                          : AppTheme.lightTextPrimaryColor,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? AppColors.yellowAccent.withValues(alpha: 0.2)
                        : AppTheme.lightPrimaryColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_filteredFaqs.length}',
                    style: GoogleFonts.inter(
                      fontSize: isTablet ? 12 : 10,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode
                          ? AppColors.yellowAccent
                          : AppTheme.lightPrimaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...List.generate(_filteredFaqs.length, (index) {
              final faq = _filteredFaqs[index];
              return _buildFAQItem(faq, index, isTablet, isDarkMode);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isTablet, bool isDarkMode) {
    return Container(
      height: 300,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.1)
                    : AppTheme.lightCardColor,
                shape: BoxShape.circle,
                border: isDarkMode
                    ? Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 1,
                      )
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
              child: Icon(
                Icons.search_off_rounded,
                size: 80,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.4)
                    : AppTheme.lightTextLightColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No FAQs found',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.8)
                    : AppTheme.lightTextPrimaryColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Try adjusting your search or filter criteria\nto find the information you\'re looking for',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.6)
                    : AppTheme.lightTextLightColor,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection(String categoryName,
      List<Map<String, dynamic>> faqs, bool isTablet, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Header
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 20 : 16,
            vertical: isTablet ? 16 : 12,
          ),
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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? AppColors.yellowAccent.withValues(alpha: 0.2)
                      : AppTheme.lightPrimaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: isDarkMode
                      ? Border.all(
                          color: AppColors.yellowAccent.withValues(alpha: 0.3),
                          width: 1,
                        )
                      : null,
                ),
                child: Icon(
                  _getCategoryIcon(categoryName),
                  color: isDarkMode
                      ? AppColors.yellowAccent
                      : AppTheme.lightPrimaryColor,
                  size: isTablet ? 24 : 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  categoryName,
                  style: GoogleFonts.inter(
                    fontSize: isTablet ? 20 : 18,
                    fontWeight: FontWeight.w700,
                    color: isDarkMode
                        ? AppColors.yellowAccent
                        : AppTheme.lightPrimaryColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? AppColors.yellowAccent.withValues(alpha: 0.2)
                      : AppTheme.lightPrimaryColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${faqs.length}',
                  style: GoogleFonts.inter(
                    fontSize: isTablet ? 12 : 10,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode
                        ? AppColors.yellowAccent
                        : AppTheme.lightPrimaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // FAQ Items
        ...faqs.asMap().entries.map((entry) {
          final index = entry.key;
          final faq = entry.value;
          return TweenAnimationBuilder<double>(
            duration: Duration(milliseconds: 300 + (index * 100)),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, 30 * (1 - value)),
                child: Opacity(
                  opacity: value,
                  child: _buildFAQItem(faq, index, isTablet, isDarkMode),
                ),
              );
            },
          );
        }).toList(),
      ],
    );
  }

  Widget _buildFAQItem(
      Map<String, dynamic> faq, int index, bool isTablet, bool isDarkMode) {
    final priorityColor = _getPriorityColor(faq['priority']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          expansionTileTheme: const ExpansionTileThemeData(
            backgroundColor: Colors.transparent,
            collapsedBackgroundColor: Colors.transparent,
          ),
        ),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(
            horizontal: isTablet ? 20 : 16,
            vertical: isTablet ? 12 : 8,
          ),
          childrenPadding: EdgeInsets.only(
            left: isTablet ? 20 : 16,
            right: isTablet ? 20 : 16,
            bottom: isTablet ? 20 : 16,
          ),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? AppColors.yellowAccent.withValues(alpha: 0.2)
                  : AppTheme.lightPrimaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.help_outline_rounded,
              color: isDarkMode
                  ? AppColors.yellowAccent
                  : AppTheme.lightPrimaryColor,
              size: isTablet ? 20 : 16,
            ),
          ),
          title: Text(
            faq['question'],
            style: GoogleFonts.inter(
              fontSize: isTablet ? 16 : 14,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
            ),
          ),
          subtitle: faq['category'] != null
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? AppColors.yellowAccent.withValues(alpha: 0.2)
                              : AppTheme.lightPrimaryColor
                                  .withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          faq['category'],
                          style: GoogleFonts.inter(
                            fontSize: isTablet ? 10 : 8,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode
                                ? AppColors.yellowAccent
                                : AppTheme.lightPrimaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: priorityColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: priorityColor, width: 1),
                        ),
                        child: Text(
                          faq['priority'],
                          style: GoogleFonts.inter(
                            fontSize: isTablet ? 8 : 7,
                            fontWeight: FontWeight.w600,
                            color: priorityColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : null,
          iconColor: isDarkMode
              ? Colors.white.withValues(alpha: 0.8)
              : AppTheme.lightTextPrimaryColor,
          collapsedIconColor: isDarkMode
              ? Colors.white.withValues(alpha: 0.8)
              : AppTheme.lightTextPrimaryColor,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isTablet ? 20 : 16),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                faq['answer'],
                style: GoogleFonts.inter(
                  fontSize: isTablet ? 14 : 12,
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.9)
                      : AppTheme.lightTextSecondaryColor,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactSupport(bool isTablet, bool isDarkMode) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        padding: EdgeInsets.all(isTablet ? 24 : 20),
        decoration: BoxDecoration(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : AppTheme.lightCardColor,
          borderRadius: BorderRadius.circular(isDarkMode ? 20 : 16),
          border: isDarkMode
              ? Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                )
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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? AppColors.yellowAccent.withValues(alpha: 0.2)
                        : AppTheme.lightPrimaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: isDarkMode
                        ? Border.all(
                            color:
                                AppColors.yellowAccent.withValues(alpha: 0.3),
                            width: 1,
                          )
                        : null,
                  ),
                  child: Icon(
                    Icons.headset_mic_rounded,
                    color: isDarkMode
                        ? AppColors.yellowAccent
                        : AppTheme.lightPrimaryColor,
                    size: isTablet ? 24 : 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Still Need Help?',
                    style: GoogleFonts.inter(
                      fontSize: isTablet ? 20 : 18,
                      fontWeight: FontWeight.w700,
                      color: isDarkMode
                          ? Colors.white
                          : AppTheme.lightTextPrimaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Can\'t find what you\'re looking for? Our support team is available 24/7 to help you with any questions or issues. We\'re here to ensure your driving experience is smooth and successful.',
              style: GoogleFonts.inter(
                fontSize: isTablet ? 14 : 12,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.8)
                    : AppTheme.lightTextSecondaryColor,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _showSubmitTicketDialog();
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 24 : 16,
                        vertical: isTablet ? 16 : 12,
                      ),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? AppColors.yellowAccent
                            : AppTheme.lightPrimaryColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: isDarkMode
                                ? AppColors.yellowAccent.withValues(alpha: 0.4)
                                : AppTheme.lightPrimaryColor
                                    .withValues(alpha: 0.4),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.support_agent_rounded,
                            color: isDarkMode ? Colors.black : Colors.white,
                            size: isTablet ? 20 : 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Submit Ticket',
                            style: GoogleFonts.inter(
                              fontSize: isTablet ? 14 : 12,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? Colors.black : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _openLiveChat();
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 24 : 16,
                        vertical: isTablet ? 16 : 12,
                      ),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDarkMode
                              ? AppColors.yellowAccent
                              : AppTheme.lightPrimaryColor,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_rounded,
                            color: isDarkMode
                                ? AppColors.yellowAccent
                                : AppTheme.lightPrimaryColor,
                            size: isTablet ? 20 : 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Live Chat',
                            style: GoogleFonts.inter(
                              fontSize: isTablet ? 14 : 12,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode
                                  ? AppColors.yellowAccent
                                  : AppTheme.lightPrimaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyTicketsSection(bool isTablet, bool isDarkMode) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        padding: EdgeInsets.all(isTablet ? 24 : 20),
        decoration: BoxDecoration(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : AppTheme.lightCardColor,
          borderRadius: BorderRadius.circular(isDarkMode ? 20 : 16),
          border: isDarkMode
              ? Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                )
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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? AppColors.yellowAccent.withValues(alpha: 0.2)
                        : AppTheme.lightPrimaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: isDarkMode
                        ? Border.all(
                            color:
                                AppColors.yellowAccent.withValues(alpha: 0.3),
                            width: 1,
                          )
                        : null,
                  ),
                  child: Icon(
                    Icons.receipt_long_rounded,
                    color: isDarkMode
                        ? AppColors.yellowAccent
                        : AppTheme.lightPrimaryColor,
                    size: isTablet ? 24 : 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'My Support Tickets',
                    style: GoogleFonts.inter(
                      fontSize: isTablet ? 20 : 18,
                      fontWeight: FontWeight.w700,
                      color: isDarkMode
                          ? Colors.white
                          : AppTheme.lightTextPrimaryColor,
                    ),
                  ),
                ),
                if (_tickets.isNotEmpty)
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? AppColors.yellowAccent.withValues(alpha: 0.2)
                                : AppTheme.lightPrimaryColor
                                    .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_tickets.length}',
                            style: GoogleFonts.inter(
                              fontSize: isTablet ? 12 : 10,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode
                                  ? AppColors.yellowAccent
                                  : AppTheme.lightPrimaryColor,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),

            const SizedBox(height: 20),

            // Tickets list
            if (_isLoadingTickets) ...[
              Container(
                height: 120,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isDarkMode
                              ? AppColors.yellowAccent
                              : AppTheme.lightPrimaryColor,
                        ),
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Loading your tickets...',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.7)
                              : AppTheme.lightTextSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (_tickets.isNotEmpty) ...[
              ...List.generate(_tickets.length > 3 ? 3 : _tickets.length,
                  (index) {
                final ticket = _tickets[index];
                return _buildTicketItem(ticket, isTablet, isDarkMode);
              }),
              if (_tickets.length > 3) ...[
                const SizedBox(height: 16),
                Center(
                  child: GestureDetector(
                    onTap: () => _showAllTicketsDialog(isTablet, isDarkMode),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 24 : 16,
                        vertical: isTablet ? 12 : 10,
                      ),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.1)
                            : AppTheme.lightCardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDarkMode
                              ? AppColors.yellowAccent
                              : AppTheme.lightPrimaryColor,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.visibility_rounded,
                            size: 18,
                            color: isDarkMode
                                ? AppColors.yellowAccent
                                : AppTheme.lightPrimaryColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'View All Tickets (${_tickets.length})',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color: isDarkMode
                                  ? AppColors.yellowAccent
                                  : AppTheme.lightPrimaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ] else ...[
              Container(
                height: 150,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.1)
                              : AppTheme.lightCardColor,
                          shape: BoxShape.circle,
                          border: isDarkMode
                              ? Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  width: 1,
                                )
                              : Border.all(
                                  color: AppTheme.lightPrimaryColor,
                                  width: 1.5,
                                ),
                        ),
                        child: Icon(
                          Icons.receipt_long_outlined,
                          size: isTablet ? 48 : 40,
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.4)
                              : AppTheme.lightTextLightColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No tickets submitted yet',
                        style: GoogleFonts.inter(
                          fontSize: isTablet ? 18 : 16,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.8)
                              : AppTheme.lightTextPrimaryColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Submit a ticket to get help with any issues',
                        style: GoogleFonts.inter(
                          fontSize: isTablet ? 14 : 12,
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.6)
                              : AppTheme.lightTextLightColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTicketItem(
      Map<String, dynamic> ticket, bool isTablet, bool isDarkMode) {
    final status = ticket['status'] ?? 'Open';
    final statusColor = _getStatusColor(status);
    final createdAt = ticket['updatedAt'] as Timestamp?;
    final dateString =
        createdAt != null ? _formatDate(createdAt.toDate()) : 'Unknown date';

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _showTicketDetailsDialog(ticket, isTablet, isDarkMode);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(isTablet ? 16 : 12),
        decoration: BoxDecoration(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
          border: isDarkMode
              ? Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                )
              : Border.all(
                  color: AppTheme.lightPrimaryColor.withValues(alpha: 0.3),
                  width: 1,
                ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ticket['subject'] ?? 'No Subject',
                    style: GoogleFonts.inter(
                      fontSize: isTablet ? 16 : 14,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode
                          ? Colors.white
                          : AppTheme.lightTextPrimaryColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor, width: 1),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: isTablet ? 10 : 8,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              ticket['message'] ?? 'No message',
              style: GoogleFonts.inter(
                fontSize: isTablet ? 12 : 10,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.7)
                    : AppTheme.lightTextSecondaryColor,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 14,
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.5)
                      : AppTheme.lightTextLightColor,
                ),
                const SizedBox(width: 4),
                Text(
                  dateString,
                  style: GoogleFonts.inter(
                    fontSize: isTablet ? 10 : 8,
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.5)
                        : AppTheme.lightTextLightColor,
                  ),
                ),
                const Spacer(),
                if (ticket['adminResponses'] != null &&
                    (ticket['adminResponses'] as List<dynamic>).isNotEmpty) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.blue,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.message_rounded,
                          size: 12,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Admin replied',
                          style: GoogleFonts.inter(
                            fontSize: isTablet ? 9 : 8,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.5)
                      : AppTheme.lightTextLightColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String categoryName) {
    switch (categoryName) {
      case 'General':
        return Icons.help_outline_rounded;
      case 'Shift Management':
        return Icons.access_time_rounded;
      case 'Scheduling & Viewing':
        return Icons.calendar_today_rounded;
      case 'Notes & Events':
        return Icons.note_add_rounded;
      case 'Earnings & Stats':
        return Icons.bar_chart_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'High':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      case 'Low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open':
      case 'pending':
        return Colors.orange;
      case 'in progress':
      case 'in_progress':
        return Colors.blue;
      case 'resolved':
      case 'completed':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatFullDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];

    final hour =
        date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
    final amPm = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');

    return '${months[date.month - 1]} ${date.day}, ${date.year} at $hour:$minute $amPm';
  }

  void _showSubmitTicketDialog() {
    final isTablet = MediaQuery.of(context).size.width > 600;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Consumer<ThemeService>(
          builder: (context, themeService, child) {
            final isDarkMode = themeService.isDarkMode;

            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? const Color(0xFF2D2D3C)
                      : AppTheme.lightCardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: isDarkMode
                      ? Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1.5,
                        )
                      : Border.all(
                          color: AppTheme.lightPrimaryColor,
                          width: 1.5,
                        ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? AppColors.yellowAccent.withValues(alpha: 0.2)
                            : AppTheme.lightPrimaryColor.withOpacity(0.1),
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
                              color: isDarkMode
                                  ? AppColors.yellowAccent
                                  : AppTheme.lightPrimaryColor,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: isDarkMode
                                      ? AppColors.yellowAccent
                                          .withValues(alpha: 0.4)
                                      : AppTheme.lightPrimaryColor
                                          .withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.support_agent_rounded,
                              color: isDarkMode ? Colors.black : Colors.white,
                              size: isTablet ? 24 : 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Submit Support Ticket',
                              style: GoogleFonts.inter(
                                fontSize: isTablet ? 20 : 18,
                                fontWeight: FontWeight.w700,
                                color: isDarkMode
                                    ? Colors.white
                                    : AppTheme.lightTextPrimaryColor,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _subjectController.clear();
                              _messageController.clear();
                            },
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : AppTheme.lightPrimaryColor
                                        .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                color: isDarkMode
                                    ? Colors.white
                                    : AppTheme.lightPrimaryColor,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Content
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Subject',
                            style: GoogleFonts.inter(
                              fontSize: isTablet ? 16 : 14,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode
                                  ? Colors.white
                                  : AppTheme.lightTextPrimaryColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _subjectController,
                            style: GoogleFonts.inter(
                              fontSize: isTablet ? 16 : 14,
                              color: isDarkMode
                                  ? Colors.white
                                  : AppTheme.lightTextPrimaryColor,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Enter ticket subject',
                              hintStyle: GoogleFonts.inter(
                                color: isDarkMode
                                    ? Colors.white.withValues(alpha: 0.6)
                                    : AppTheme.lightTextLightColor,
                              ),
                              filled: true,
                              fillColor: isDarkMode
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.grey.withValues(alpha: 0.1),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: isDarkMode
                                      ? AppColors.yellowAccent
                                      : AppTheme.lightPrimaryColor,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Message',
                            style: GoogleFonts.inter(
                              fontSize: isTablet ? 16 : 14,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode
                                  ? Colors.white
                                  : AppTheme.lightTextPrimaryColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _messageController,
                            maxLines: 4,
                            style: GoogleFonts.inter(
                              fontSize: isTablet ? 16 : 14,
                              color: isDarkMode
                                  ? Colors.white
                                  : AppTheme.lightTextPrimaryColor,
                            ),
                            decoration: InputDecoration(
                              hintText:
                                  'Describe your issue or question in detail...',
                              hintStyle: GoogleFonts.inter(
                                color: isDarkMode
                                    ? Colors.white.withValues(alpha: 0.6)
                                    : AppTheme.lightTextLightColor,
                              ),
                              filled: true,
                              fillColor: isDarkMode
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.grey.withValues(alpha: 0.1),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: isDarkMode
                                      ? AppColors.yellowAccent
                                      : AppTheme.lightPrimaryColor,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    _subjectController.clear();
                                    _messageController.clear();
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: isDarkMode
                                        ? Colors.white.withValues(alpha: 0.7)
                                        : AppTheme.lightTextSecondaryColor,
                                    side: BorderSide(
                                      color: isDarkMode
                                          ? Colors.white.withValues(alpha: 0.3)
                                          : AppTheme.lightPrimaryColor
                                              .withValues(alpha: 0.3),
                                      width: 1,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    'Cancel',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 2,
                                child: Container(
                                  height: 52,
                                  child: ElevatedButton.icon(
                                    onPressed: _submitTicket,
                                    icon: const Icon(Icons.send_rounded,
                                        size: 18),
                                    label: Text(
                                      'Submit Ticket',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isDarkMode
                                          ? AppColors.yellowAccent
                                          : AppTheme.lightPrimaryColor,
                                      foregroundColor: isDarkMode
                                          ? Colors.black
                                          : Colors.white,
                                      elevation: 0,
                                      shadowColor: Colors.transparent,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 0),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: isDarkMode
                                            ? AppColors.yellowAccent
                                                .withValues(alpha: 0.3)
                                            : AppTheme.lightPrimaryColor
                                                .withValues(alpha: 0.25),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                      BoxShadow(
                                        color: isDarkMode
                                            ? AppColors.yellowAccent
                                                .withValues(alpha: 0.1)
                                            : AppTheme.lightPrimaryColor
                                                .withValues(alpha: 0.15),
                                        blurRadius: 16,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
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
            );
          },
        );
      },
    );
  }

  void _showAllTicketsDialog(bool isTablet, bool isDarkMode) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Consumer<ThemeService>(
          builder: (context, themeService, child) {
            final isDarkMode = themeService.isDarkMode;

            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.95,
                height: MediaQuery.of(context).size.height * 0.8,
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? const Color(0xFF2D2D3C)
                      : AppTheme.lightCardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: isDarkMode
                      ? Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1.5,
                        )
                      : Border.all(
                          color: AppTheme.lightPrimaryColor,
                          width: 1.5,
                        ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? AppColors.yellowAccent.withValues(alpha: 0.2)
                            : AppTheme.lightPrimaryColor.withOpacity(0.1),
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
                              color: isDarkMode
                                  ? AppColors.yellowAccent
                                  : AppTheme.lightPrimaryColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.receipt_long_rounded,
                              color: isDarkMode ? Colors.black : Colors.white,
                              size: isTablet ? 24 : 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'All My Tickets (${_tickets.length})',
                              style: GoogleFonts.inter(
                                fontSize: isTablet ? 20 : 18,
                                fontWeight: FontWeight.w700,
                                color: isDarkMode
                                    ? Colors.white
                                    : AppTheme.lightTextPrimaryColor,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : AppTheme.lightPrimaryColor
                                        .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                color: isDarkMode
                                    ? Colors.white
                                    : AppTheme.lightPrimaryColor,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Content
                    Expanded(
                      child: _tickets.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.receipt_long_outlined,
                                    size: 80,
                                    color: isDarkMode
                                        ? Colors.white.withValues(alpha: 0.4)
                                        : AppTheme.lightTextLightColor,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No tickets found',
                                    style: GoogleFonts.inter(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: isDarkMode
                                          ? Colors.white.withValues(alpha: 0.7)
                                          : AppTheme.lightTextSecondaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(24),
                              itemCount: _tickets.length,
                              itemBuilder: (context, index) {
                                final ticket = _tickets[index];
                                return _buildTicketItem(
                                    ticket, isTablet, isDarkMode);
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showTicketDetailsDialog(
      Map<String, dynamic> ticket, bool isTablet, bool isDarkMode) {
    final status = ticket['status'] ?? 'Open';
    final statusColor = _getStatusColor(status);
    final createdAt = ticket['createdAt'] as Timestamp?;
    final updatedAt = ticket['updatedAt'] as Timestamp?;
    final createdDateString = createdAt != null
        ? _formatFullDate(createdAt.toDate())
        : 'Unknown date';
    final updatedDateString = updatedAt != null
        ? _formatFullDate(updatedAt.toDate())
        : 'Unknown date';

    final adminResponses = ticket['adminResponses'] as List<dynamic>? ?? [];
    final driverResponses = ticket['driverResponses'] as List<dynamic>? ?? [];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Consumer<ThemeService>(
          builder: (context, themeService, child) {
            final isDarkMode = themeService.isDarkMode;

            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.95,
                height: MediaQuery.of(context).size.height * 0.9,
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? const Color(0xFF2D2D3C)
                      : AppTheme.lightCardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: isDarkMode
                      ? Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1.5,
                        )
                      : Border.all(
                          color: AppTheme.lightPrimaryColor,
                          width: 1.5,
                        ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.2),
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
                              color: statusColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.receipt_rounded,
                              color: Colors.white,
                              size: isTablet ? 24 : 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ticket Details',
                                  style: GoogleFonts.inter(
                                    fontSize: isTablet ? 20 : 18,
                                    fontWeight: FontWeight.w700,
                                    color: isDarkMode
                                        ? Colors.white
                                        : AppTheme.lightTextPrimaryColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: GoogleFonts.inter(
                                      fontSize: isTablet ? 10 : 8,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : AppTheme.lightPrimaryColor
                                        .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                color: isDarkMode
                                    ? Colors.white
                                    : AppTheme.lightPrimaryColor,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Content
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Subject
                            _buildDetailCard(
                              'Subject',
                              ticket['subject'] ?? 'No Subject',
                              Icons.subject_rounded,
                              isTablet,
                              isDarkMode,
                            ),

                            const SizedBox(height: 16),

                            // Message
                            _buildDetailCard(
                              'Your Message',
                              ticket['message'] ?? 'No message',
                              Icons.message_rounded,
                              isTablet,
                              isDarkMode,
                            ),

                            const SizedBox(height: 16),

                            // Conversation History (Admin and Driver responses in chronological order)
                            if (adminResponses.isNotEmpty ||
                                driverResponses.isNotEmpty) ...[
                              _buildConversationHistory(adminResponses,
                                  driverResponses, isTablet, isDarkMode),
                              const SizedBox(height: 16),
                            ] else ...[
                              _buildPendingResponseCard(isTablet, isDarkMode),
                              const SizedBox(height: 16),
                            ],

                            // Reply Section (only if ticket is not resolved or closed)
                            if (status.toLowerCase() != 'resolved' &&
                                status.toLowerCase() != 'closed') ...[
                              _buildReplySection(
                                  ticket['id'], isTablet, isDarkMode),
                              const SizedBox(height: 16),
                            ],

                            // Date Information
                            _buildDateInfoCard(createdDateString,
                                updatedDateString, isTablet, isDarkMode),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailCard(String title, String content, IconData icon,
      bool isTablet, bool isDarkMode) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: isDarkMode
            ? Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? AppColors.yellowAccent.withValues(alpha: 0.2)
                      : AppTheme.lightPrimaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: isDarkMode
                      ? AppColors.yellowAccent
                      : AppTheme.lightPrimaryColor,
                  size: isTablet ? 20 : 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: isTablet ? 16 : 14,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode
                      ? Colors.white
                      : AppTheme.lightTextPrimaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isTablet ? 16 : 12),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              content,
              style: GoogleFonts.inter(
                fontSize: isTablet ? 14 : 12,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.9)
                    : AppTheme.lightTextSecondaryColor,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationHistory(List<dynamic> adminResponses,
      List<dynamic> driverResponses, bool isTablet, bool isDarkMode) {
    // Combine all messages and sort by timestamp
    List<Map<String, dynamic>> allMessages = [];

    // Add admin responses
    for (var response in adminResponses) {
      final responseData = response as Map<String, dynamic>;
      allMessages.add({
        'type': 'admin',
        'message': responseData['message'] ?? '',
        'senderName': responseData['adminName'] ?? 'Admin',
        'timestamp': responseData['timestamp'],
      });
    }

    // Add driver responses
    for (var response in driverResponses) {
      final responseData = response as Map<String, dynamic>;
      allMessages.add({
        'type': 'driver',
        'message': responseData['message'] ?? '',
        'senderName': responseData['driverName'] ?? 'You',
        'timestamp': responseData['timestamp'],
      });
    }

    // Sort messages by timestamp (oldest first, newest last)
    allMessages.sort((a, b) {
      final aTimestamp = a['timestamp'];
      final bTimestamp = b['timestamp'];

      if (aTimestamp == null && bTimestamp == null) return 0;
      if (aTimestamp == null) return -1;
      if (bTimestamp == null) return 1;

      if (aTimestamp is Timestamp && bTimestamp is Timestamp) {
        return aTimestamp.compareTo(bTimestamp);
      }

      return 0;
    });

    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: isDarkMode
            ? Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              )
            : Border.all(
                color: AppTheme.lightPrimaryColor.withValues(alpha: 0.3),
                width: 1,
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? AppColors.yellowAccent.withValues(alpha: 0.2)
                      : AppTheme.lightPrimaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.chat_rounded,
                  color: isDarkMode
                      ? AppColors.yellowAccent
                      : AppTheme.lightPrimaryColor,
                  size: isTablet ? 20 : 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Conversation (${allMessages.length})',
                style: GoogleFonts.inter(
                  fontSize: isTablet ? 16 : 14,
                  fontWeight: FontWeight.w700,
                  color: isDarkMode
                      ? Colors.white
                      : AppTheme.lightTextPrimaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...allMessages.map((message) {
            final isAdmin = message['type'] == 'admin';
            final timestamp = message['timestamp'];
            String timeString = 'Unknown time';

            if (timestamp is Timestamp) {
              timeString = _formatFullDate(timestamp.toDate());
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: EdgeInsets.all(isTablet ? 16 : 12),
              decoration: BoxDecoration(
                color: isAdmin
                    ? Colors.green.withValues(alpha: 0.15)
                    : Colors.blue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isAdmin
                      ? Colors.green.withValues(alpha: 0.3)
                      : Colors.blue.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isAdmin ? Colors.green : Colors.blue,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          isAdmin
                              ? Icons.admin_panel_settings_rounded
                              : Icons.person_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        message['senderName'],
                        style: GoogleFonts.inter(
                          fontSize: isTablet ? 12 : 10,
                          fontWeight: FontWeight.w600,
                          color: isAdmin ? Colors.green : Colors.blue,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        timeString,
                        style: GoogleFonts.inter(
                          fontSize: isTablet ? 10 : 9,
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.5)
                              : AppTheme.lightTextLightColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message['message'],
                    style: GoogleFonts.inter(
                      fontSize: isTablet ? 14 : 12,
                      color: isDarkMode
                          ? Colors.white
                          : AppTheme.lightTextPrimaryColor,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildReplySection(String ticketId, bool isTablet, bool isDarkMode) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: isDarkMode
            ? Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              )
            : Border.all(
                color: AppTheme.lightPrimaryColor.withValues(alpha: 0.3),
                width: 1,
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? AppColors.yellowAccent.withValues(alpha: 0.2)
                      : AppTheme.lightPrimaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.reply_rounded,
                  color: isDarkMode
                      ? AppColors.yellowAccent
                      : AppTheme.lightPrimaryColor,
                  size: isTablet ? 20 : 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Reply to Admin',
                style: GoogleFonts.inter(
                  fontSize: isTablet ? 16 : 14,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode
                      ? Colors.white
                      : AppTheme.lightTextPrimaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _replyController,
            maxLines: 3,
            style: GoogleFonts.inter(
              fontSize: isTablet ? 16 : 14,
              color: isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
            ),
            decoration: InputDecoration(
              hintText: 'Type your reply here...',
              hintStyle: GoogleFonts.inter(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.6)
                    : AppTheme.lightTextLightColor,
              ),
              filled: true,
              fillColor: isDarkMode
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white.withValues(alpha: 0.7),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDarkMode
                      ? AppColors.yellowAccent
                      : AppTheme.lightPrimaryColor,
                  width: 2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmittingReply
                        ? null
                        : () => _submitReply(ticketId),
                    icon: _isSubmittingReply
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isDarkMode ? Colors.black : Colors.white,
                              ),
                            ),
                          )
                        : Icon(Icons.send_rounded, size: 18),
                    label: Text(
                      _isSubmittingReply ? 'Sending...' : 'Send Reply',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDarkMode
                          ? AppColors.yellowAccent
                          : AppTheme.lightPrimaryColor,
                      foregroundColor: isDarkMode ? Colors.black : Colors.white,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: isDarkMode
                            ? AppColors.yellowAccent.withValues(alpha: 0.3)
                            : AppTheme.lightPrimaryColor
                                .withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                      BoxShadow(
                        color: isDarkMode
                            ? AppColors.yellowAccent.withValues(alpha: 0.1)
                            : AppTheme.lightPrimaryColor
                                .withValues(alpha: 0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isResolvingTicket
                      ? null
                      : () => _resolveTicket(ticketId),
                  icon: _isResolvingTicket
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Icon(Icons.check_circle_rounded, size: 18),
                  label: Text(
                    _isResolvingTicket ? 'Resolving...' : 'Resolve',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 0,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                    BoxShadow(
                      color: Colors.green.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendingResponseCard(bool isTablet, bool isDarkMode) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.pending_rounded,
              color: Colors.white,
              size: isTablet ? 20 : 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Waiting for admin response...',
              style: GoogleFonts.inter(
                fontSize: isTablet ? 14 : 12,
                fontWeight: FontWeight.w600,
                color:
                    isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateInfoCard(
      String createdDate, String updatedDate, bool isTablet, bool isDarkMode) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 16,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.6)
                    : AppTheme.lightTextLightColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Created: $createdDate',
                style: GoogleFonts.inter(
                  fontSize: isTablet ? 12 : 10,
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.6)
                      : AppTheme.lightTextLightColor,
                ),
              ),
            ],
          ),
          if (updatedDate != createdDate) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.update_rounded,
                  size: 16,
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.6)
                      : AppTheme.lightTextLightColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Updated: $updatedDate',
                  style: GoogleFonts.inter(
                    fontSize: isTablet ? 12 : 10,
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.6)
                        : AppTheme.lightTextLightColor,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _openLiveChat() {
    _showGlowingSnackBar('Live chat will be available soon', Colors.blue);
  }

  void _showGlowingSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        elevation: 8,
      ),
    );
  }
}
