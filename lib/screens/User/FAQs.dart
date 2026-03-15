import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shiffters/theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:shiffters/services/theme_service.dart';

class FAQsScreen extends StatefulWidget {
  const FAQsScreen({super.key});

  @override
  State<FAQsScreen> createState() => _FAQsScreenState();
}

class _FAQsScreenState extends State<FAQsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final List<Map<String, dynamic>> _faqData = [
    {
      'category': '❓ General',
      'questions': [
        {
          'q': 'What is Shiffters Mobile App?',
          'a':
              'Shiffters is a shift-management and calendar app designed for shift workers—it helps you track work hours, set reminders, log notes, and analyze earnings all in one place.'
        },
        {
          'q': 'Is Shiffters free?',
          'a':
              'Yes, the core features are free. We may offer a PRO version or in-app purchases for advanced options like unlimited calendars, enhanced reporting, and custom alarms.'
        },
      ]
    },
    {
      'category': '🕒 Shift Management',
      'questions': [
        {
          'q': 'How do I create and manage shifts?',
          'a':
              'Go to the "Shifts" section to add or edit shifts. You can define start & end times, split shifts, breaks, overtime settings, and assign icons or labels.'
        },
        {
          'q': 'Can I set reminders for my shifts?',
          'a':
              'Yes! You can configure reminders for individual shifts—either on the same day or the day before—and choose custom alert sounds.'
        },
        {
          'q': 'Can I view multiple shifts per day?',
          'a':
              'Absolutely. You can paint up to two different shifts per day. Some versions allow multiple calendars for different jobs or people.'
        },
      ]
    },
    {
      'category': '📅 Scheduling & Viewing',
      'questions': [
        {
          'q': 'What calendar views are available?',
          'a':
              'Enjoy monthly and annual calendar overviews with color-coded days. Some versions support widgets to view your calendar without opening the app.'
        },
        {
          'q': 'Can I export my schedule?',
          'a':
              'Yes, you can export to Google Calendar or share calendar views via email, WhatsApp, or Telegram. Backups are also supported.'
        },
      ]
    },
    {
      'category': '📝 Notes & Events',
      'questions': [
        {
          'q': 'Can I add notes or personal events?',
          'a':
              'Definitely. You can attach notes to any date, include images or drawings, and set reminders. Notes show up in your calendar overview.'
        },
      ]
    },
    {
      'category': '💵 Earnings & Stats',
      'questions': [
        {
          'q': 'How do I track earnings and work hours?',
          'a':
              'Enter your hourly wage (and overtime rates if needed), and the app estimates your earnings, including overtime and early exits. It also provides date-range statistics.'
        },
      ]
    },
    {
      'category': '🔄 Imports & Sync',
      'questions': [
        {
          'q': 'Can I import shifts from another calendar?',
          'a':
              'Yes! You can import calendars from Google (or others) and even transfer shifts between calendars within the app.'
        },
        {
          'q': 'Does it include country holidays?',
          'a':
              'Many versions allow adding national holidays automatically, depending on your locale and calendar sync.'
        },
      ]
    },
    {
      'category': '⚙️ Customization',
      'questions': [
        {
          'q': 'Can I customize alarms and notifications?',
          'a':
              'Yes—you can select custom sounds for alarms, choose when reminders fire, and even configure alerts directly from the widget (if supported).'
        },
        {
          'q': 'How do I customize shift types or icons?',
          'a':
              'Each shift can be labeled, color-coded, and assigned with a unique icon for quick identification in the calendar view.'
        },
      ]
    },
    {
      'category': '🛠️ Support & Troubleshooting',
      'questions': [
        {
          'q': 'Who can I contact for help?',
          'a':
              "You'll find a Help or Support section in-app. You can reach out via email, or explore our community channels (like Facebook or Instagram) for tutorials and updates."
        },
        {
          'q': "What should I do if alarms aren't working?",
          'a':
              'First, check notification permissions. If issues persist, contact support at [support email] with your device model and app version details.'
        },
      ]
    },
    {
      'category': '🔐 Privacy & Security',
      'questions': [
        {
          'q': 'Do you collect personal data?',
          'a':
              'We collect minimal data—like device identifiers—to enable reminders and calendar functionality. We do not share your personal data with third parties.'
        },
        {
          'q': 'How is my data protected?',
          'a':
              'All personal data is encrypted in transit and stored securely. You can also back up or export your data at any time.'
        },
      ]
    },
  ];

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
              // New App Bar with curved bottom design
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
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios,
                            color: Colors.white,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Expanded(
                          child: Text(
                            'Frequently Asked Questions',
                            style: GoogleFonts.albertSans(
                              fontSize: isTablet ? 24 : 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // FAQ Content
              Expanded(
                child: Container(
                  margin: EdgeInsets.all(isTablet ? 24 : 20),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: _faqData.length,
                    itemBuilder: (context, index) {
                      final category = _faqData[index];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            child: Text(
                              category['category'],
                              style: GoogleFonts.albertSans(
                                color: isDarkMode
                                    ? AppColors.yellowAccent
                                    : AppColors.lightPrimary,
                                fontSize: isTablet ? 20 : 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          ...List.generate(
                            category['questions'].length,
                            (qIndex) {
                              final qa = category['questions'][qIndex];
                              return _buildExpansionTile(
                                  qa['q'], qa['a'], isDarkMode, isTablet);
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExpansionTile(
      String question, String answer, bool isDarkMode, bool isTablet) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isDarkMode
            ? Border.all(
                color: const Color(0xFF4A4A5A),
                width: 1,
              )
            : Border.all(
                color: AppColors.lightPrimary,
                width: 1.5,
              ),
        boxShadow: isDarkMode
            ? null
            : [
                BoxShadow(
                  color: const Color(
                      0x0F000000), // AppTheme.lightShadowLight equivalent
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: ExpansionTile(
        title: Text(
          question,
          style: GoogleFonts.albertSans(
            color: isDarkMode ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: isTablet ? 16 : 14,
          ),
        ),
        iconColor: isDarkMode ? AppColors.yellowAccent : AppColors.lightPrimary,
        collapsedIconColor: isDarkMode ? Colors.white : AppColors.textPrimary,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              answer,
              style: GoogleFonts.albertSans(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.8)
                    : AppColors.textSecondary,
                fontSize: isTablet ? 15 : 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
