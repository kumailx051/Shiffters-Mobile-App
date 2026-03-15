import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shiffters/screens/User/FAQs.dart';
import 'package:shiffters/theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:shiffters/services/theme_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class HelpAndSupportScreen extends StatefulWidget {
  const HelpAndSupportScreen({super.key});

  @override
  State<HelpAndSupportScreen> createState() => _HelpAndSupportScreenState();
}

class _HelpAndSupportScreenState extends State<HelpAndSupportScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  final _replyController = TextEditingController();

  bool _isSubmitting = false;
  bool _isSubmittingReply = false;
  bool _isResolvingTicket = false;
  List<Map<String, dynamic>> _userTickets = [];
  bool _isLoadingTickets = true;
  StreamSubscription<QuerySnapshot>? _ticketsSubscription;

  @override
  void initState() {
    super.initState();
    _setupTicketsListener();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    _replyController.dispose();
    _ticketsSubscription?.cancel();
    super.dispose();
  }

  void _setupTicketsListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _ticketsSubscription = FirebaseFirestore.instance
          .collection('tickets')
          .where('uid', isEqualTo: user.uid)
          .where('role', isEqualTo: 'user')
          .snapshots()
          .listen(
        (snapshot) {
          if (mounted) {
            setState(() {
              _userTickets = snapshot.docs
                  .map((doc) => {'id': doc.id, ...doc.data()})
                  .toList();

              // Sort tickets by createdAt in descending order (newest first)
              _userTickets.sort((a, b) {
                final aTime = a['createdAt'] as Timestamp?;
                final bTime = b['createdAt'] as Timestamp?;
                if (aTime == null && bTime == null) return 0;
                if (aTime == null) return 1;
                if (bTime == null) return -1;
                return bTime.compareTo(aTime); // Descending order
              });

              _isLoadingTickets = false;
            });
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _isLoadingTickets = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error loading tickets: $error'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            );
          }
        },
      );
    } else {
      setState(() {
        _isLoadingTickets = false;
      });
    }
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please login to submit a ticket',
            style: GoogleFonts.albertSans(fontWeight: FontWeight.w500),
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final ticketData = {
        'subject': _subjectController.text.trim(),
        'message': _messageController.text.trim(),
        'uid': user.uid,
        'role': 'user',
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('tickets').add(ticketData);

      // Clear form
      _subjectController.clear();
      _messageController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Ticket submitted successfully! We\'ll get back to you soon.',
              style: GoogleFonts.albertSans(fontWeight: FontWeight.w500),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error submitting ticket: $e',
              style: GoogleFonts.albertSans(fontWeight: FontWeight.w500),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _submitReply(String ticketId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please login to submit reply',
            style: GoogleFonts.albertSans(fontWeight: FontWeight.w500),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    if (_replyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter a reply message',
            style: GoogleFonts.albertSans(fontWeight: FontWeight.w500),
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() {
      _isSubmittingReply = true;
    });

    try {
      // Get user document to get the name
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userName = userDoc.data()?['name'] ?? 'User';

      await FirebaseFirestore.instance
          .collection('tickets')
          .doc(ticketId)
          .update({
        'userResponses': FieldValue.arrayUnion([
          {
            'message': _replyController.text.trim(),
            'userName': userName,
            'timestamp': Timestamp.now(),
          }
        ]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _replyController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error submitting reply: ${e.toString()}',
            style: GoogleFonts.albertSans(fontWeight: FontWeight.w500),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      setState(() {
        _isSubmittingReply = false;
      });
    }
  }

  Future<void> _resolveTicket(String ticketId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please login to resolve ticket',
            style: GoogleFonts.albertSans(fontWeight: FontWeight.w500),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
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
        'updatedAt': FieldValue.serverTimestamp(),
      });

      Navigator.of(context).pop(); // Close the dialog
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error resolving ticket: ${e.toString()}',
            style: GoogleFonts.albertSans(fontWeight: FontWeight.w500),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      setState(() {
        _isResolvingTicket = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        final isDarkMode = themeService.isDarkMode;
        final screenSize = MediaQuery.of(context).size;
        final isTablet = screenSize.width > 600;

        return Scaffold(
          backgroundColor:
              isDarkMode ? const Color(0xFF1E1E2C) : const Color(0xFFE8E8F0),
          body: Column(
            children: [
              _buildHeader(isTablet, isDarkMode),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 32 : 20,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Get in Touch', isDarkMode),
                      const SizedBox(height: 16),
                      _buildContactCard(
                        icon: Icons.email_outlined,
                        title: 'Email Support',
                        subtitle: 'support@shiffters.com',
                        isDarkMode: isDarkMode,
                        onTap: () {
                          // Add mailto functionality
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildContactCard(
                        icon: Icons.phone_outlined,
                        title: 'Call Us',
                        subtitle: '+1 (800) 123-4567',
                        isDarkMode: isDarkMode,
                        onTap: () {
                          // Add tel functionality
                        },
                      ),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Common Questions', isDarkMode),
                      const SizedBox(height: 16),
                      _buildNavigationCard(
                        icon: Icons.quiz_outlined,
                        title: 'Frequently Asked Questions',
                        isDarkMode: isDarkMode,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const FAQsScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Submit a Ticket', isDarkMode),
                      const SizedBox(height: 16),
                      _buildTicketForm(isDarkMode),
                      const SizedBox(height: 24),
                      _buildSectionTitle('My Tickets', isDarkMode),
                      const SizedBox(height: 16),
                      _buildTicketsList(isDarkMode),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios,
                        color: Colors.white,
                        size: isTablet ? 24 : 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Help & Support',
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
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDarkMode) {
    return Text(
      title,
      style: GoogleFonts.albertSans(
        color: isDarkMode ? const Color(0xFFFFC107) : const Color(0xFF4285F4),
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDarkMode,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
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
                    color: const Color(0x0F000000),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isDarkMode
                    ? AppColors.yellowAccent
                    : AppColors.lightPrimary,
                size: 24),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.albertSans(
                    color: isDarkMode ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.albertSans(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.7)
                        : AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              color: isDarkMode ? Colors.white : AppColors.textPrimary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationCard({
    required IconData icon,
    required String title,
    required bool isDarkMode,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
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
                    color: const Color(0x0F000000),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isDarkMode
                    ? AppColors.yellowAccent
                    : AppColors.lightPrimary,
                size: 24),
            const SizedBox(width: 16),
            Text(
              title,
              style: GoogleFonts.albertSans(
                color: isDarkMode ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              color: isDarkMode ? Colors.white : AppColors.textPrimary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketForm(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
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
                  color: const Color(0x0F000000),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _subjectController,
              style: GoogleFonts.albertSans(
                color: isDarkMode ? Colors.white : AppColors.textPrimary,
              ),
              decoration: _inputDecoration('Subject', isDarkMode),
              validator: (value) =>
                  value!.isEmpty ? 'Please enter a subject' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _messageController,
              style: GoogleFonts.albertSans(
                color: isDarkMode ? Colors.white : AppColors.textPrimary,
              ),
              decoration: _inputDecoration('Message', isDarkMode),
              maxLines: 5,
              validator: (value) =>
                  value!.isEmpty ? 'Please enter a message' : null,
            ),
            const SizedBox(height: 20),
            Container(
              height: 52,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitTicket,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDarkMode
                      ? AppColors.yellowAccent
                      : const Color(0xFF4285F4),
                  foregroundColor: isDarkMode ? Colors.black : Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isDarkMode ? Colors.black : Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        'Submit',
                        style: GoogleFonts.albertSans(
                          color: isDarkMode ? Colors.black : Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          fontSize: 16,
                        ),
                      ),
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: isDarkMode
                        ? AppColors.yellowAccent.withValues(alpha: 0.3)
                        : const Color(0xFF4285F4).withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                  BoxShadow(
                    color: isDarkMode
                        ? AppColors.yellowAccent.withValues(alpha: 0.1)
                        : const Color(0xFF4285F4).withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, bool isDarkMode) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.albertSans(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.7)
            : AppColors.textSecondary,
      ),
      filled: true,
      fillColor: isDarkMode
          ? Colors.white.withValues(alpha: 0.1)
          : Colors.white.withValues(alpha: 0.8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: isDarkMode
            ? BorderSide.none
            : BorderSide(
                color: AppColors.lightPrimary,
                width: 1.5,
              ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: isDarkMode
            ? BorderSide.none
            : BorderSide(
                color: AppColors.lightPrimary,
                width: 1.5,
              ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.lightPrimary, width: 2),
      ),
    );
  }

  Widget _buildTicketsList(bool isDarkMode) {
    if (_isLoadingTickets) {
      return Container(
        padding: const EdgeInsets.all(16),
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
                    color: const Color(0x0F000000),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                isDarkMode ? AppColors.yellowAccent : AppColors.lightPrimary,
              ),
            ),
          ),
        ),
      );
    }

    if (_userTickets.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
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
                    color: const Color(0x0F000000),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Center(
          child: Column(
            children: [
              const SizedBox(height: 24),
              Icon(
                Icons.inbox_outlined,
                size: 48,
                color: isDarkMode
                    ? AppColors.yellowAccent
                    : AppColors.lightPrimary,
              ),
              const SizedBox(height: 16),
              Text(
                'No tickets submitted yet',
                style: GoogleFonts.albertSans(
                  fontSize: 16,
                  color: isDarkMode ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with ticket count
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: isDarkMode
                ? Border.all(color: const Color(0xFF4A4A5A), width: 1)
                : Border.all(color: Colors.grey[200]!, width: 1),
            boxShadow: isDarkMode
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? AppColors.yellowAccent.withOpacity(0.2)
                      : AppColors.lightPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.confirmation_number_rounded,
                  color: isDarkMode
                      ? AppColors.yellowAccent
                      : AppColors.lightPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'My Support Tickets',
                style: GoogleFonts.albertSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? AppColors.yellowAccent.withOpacity(0.2)
                      : AppColors.lightPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_userTickets.length}',
                  style: GoogleFonts.albertSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode
                        ? AppColors.yellowAccent
                        : AppColors.lightPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Individual ticket cards
        ...List.generate(_userTickets.length, (index) {
          final ticket = _userTickets[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildTicketItem(ticket, isDarkMode),
          );
        }),
      ],
    );
  }

  Widget _buildTicketItem(Map<String, dynamic> ticket, bool isDarkMode) {
    final status = ticket['status'] ?? 'pending';
    final createdAt = ticket['createdAt'] as Timestamp?;
    final updatedAt = ticket['updatedAt'] as Timestamp?;
    final timeToShow = updatedAt ?? createdAt;
    final timeStr =
        timeToShow != null ? _formatDate(timeToShow.toDate()) : 'Unknown time';

    Color statusColor;
    String statusText;

    switch (status.toLowerCase()) {
      case 'resolved':
        statusColor = Colors.green;
        statusText = 'RESOLVED';
        break;
      case 'in_progress':
        statusColor = Colors.blue;
        statusText = 'IN PROGRESS';
        break;
      case 'open':
      case 'pending':
      default:
        statusColor = Colors.blue;
        statusText = 'IN PROGRESS';
        break;
    }

    // Check if admin has replied
    final adminResponses = ticket['adminResponses'] as List<dynamic>? ?? [];
    final hasAdminReply = adminResponses.isNotEmpty;

    return GestureDetector(
      onTap: () => _showTicketDetailsDialog(ticket, isDarkMode),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isDarkMode
              ? Border.all(color: const Color(0xFF4A4A5A), width: 1)
              : Border.all(color: Colors.grey[200]!, width: 1),
          boxShadow: isDarkMode
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subject and Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    ticket['subject'] ?? 'No Subject',
                    style: GoogleFonts.albertSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    statusText,
                    style: GoogleFonts.albertSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Message preview
            Text(
              ticket['message'] ?? 'No Message',
              style: GoogleFonts.albertSans(
                fontSize: 14,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),

            // Bottom row with timestamp and admin reply indicator
            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 14,
                  color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
                ),
                const SizedBox(width: 4),
                Text(
                  timeStr,
                  style: GoogleFonts.albertSans(
                    fontSize: 12,
                    color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const Spacer(),

                // Admin reply indicator
                if (hasAdminReply) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.reply_rounded,
                          size: 12,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Admin replied',
                          style: GoogleFonts.albertSans(
                            fontSize: 10,
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
                  color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showTicketDetailsDialog(Map<String, dynamic> ticket, bool isDarkMode) {
    // This is a placeholder for the detailed dialog implementation
    // You can add the full dialog implementation from the original file here
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ticket Details'),
        content: Text('Subject: ${ticket['subject'] ?? 'No Subject'}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
