import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shiffters/theme/app_colors.dart';
import 'package:shiffters/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shiffters/services/theme_service.dart';
import 'pickup_drop_details_screen.dart';

class PickupDropPackageScreen extends StatefulWidget {
  final Map<String, dynamic> packageData;

  const PickupDropPackageScreen({
    super.key,
    required this.packageData,
  });

  @override
  State<PickupDropPackageScreen> createState() =>
      _PickupDropPackageScreenState();
}

class _PickupDropPackageScreenState extends State<PickupDropPackageScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final TextEditingController _packageNameController = TextEditingController();
  final TextEditingController _packageDescriptionController =
      TextEditingController();
  final TextEditingController _packageWeightController =
      TextEditingController();
  final TextEditingController _senderNameController = TextEditingController();
  final TextEditingController _senderPhoneController = TextEditingController();
  final TextEditingController _receiverNameController = TextEditingController();
  final TextEditingController _receiverPhoneController =
      TextEditingController();

  String _selectedPackageType = 'Document';
  bool _isFragile = false;
  bool _isLoading = false;

  final List<Map<String, dynamic>> _packageTypes = [
    {'name': 'Document', 'icon': Icons.description},
    {'name': 'Electronics', 'icon': Icons.devices},
    {'name': 'Clothing', 'icon': Icons.checkroom},
    {'name': 'Food', 'icon': Icons.restaurant},
    {'name': 'Medical', 'icon': Icons.medical_services},
    {'name': 'Other', 'icon': Icons.category},
  ];

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
    _setupPhoneFormatting();

    debugPrint('Package data received: ${widget.packageData}');
  }

  void _setupPhoneFormatting() {
    // Add listeners for phone number formatting
    _senderPhoneController.addListener(() {
      _formatPhoneNumber(_senderPhoneController);
    });

    _receiverPhoneController.addListener(() {
      _formatPhoneNumber(_receiverPhoneController);
    });
  }

  void _formatPhoneNumber(TextEditingController controller) {
    String text = controller.text
        .replaceAll(RegExp(r'[^0-9]'), ''); // Remove all non-digits

    if (text.length >= 4 && text.length <= 11) {
      // Format as 0336-5017866
      if (text.length <= 4) {
        controller.value = controller.value.copyWith(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      } else {
        String formatted = text.substring(0, 4) + '-' + text.substring(4);
        controller.value = controller.value.copyWith(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
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

  @override
  void dispose() {
    _animationController.dispose();
    _packageNameController.dispose();
    _packageDescriptionController.dispose();
    _packageWeightController.dispose();
    _senderNameController.dispose();
    _senderPhoneController.dispose();
    _receiverNameController.dispose();
    _receiverPhoneController.dispose();
    super.dispose();
  }

  void _onContinue() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      HapticFeedback.lightImpact();

      try {
        // Prepare data for next screen
        Map<String, dynamic> completePackageData = {
          ...widget.packageData,
          'packageDetails': {
            'name': _packageNameController.text.trim(),
            'description': _packageDescriptionController.text.trim(),
            'type': _selectedPackageType,
            'weight': _packageWeightController.text.trim(),
            'isFragile': _isFragile,
          },
          'contactDetails': {
            'sender': {
              'name': _senderNameController.text.trim(),
              'phone': _senderPhoneController.text.trim(),
            },
            'receiver': {
              'name': _receiverNameController.text.trim(),
              'phone': _receiverPhoneController.text.trim(),
            },
          },
        };

        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  PickupDropDetailsScreen(routeData: completePackageData),
            ),
          );
        }
      } catch (e) {
        debugPrint('Error navigating to details screen: $e');
        if (mounted) {
          _showMessage('Error processing request. Please try again.',
              isError: true);
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else {
      _showMessage('Please fill all required fields', isError: true);
    }
  }

  void _showMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError
            ? Colors.red.withValues(alpha: 0.9)
            : Colors.green.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.albertSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        final isDarkMode = themeService.isDarkMode;

        return Scaffold(
          backgroundColor: isDarkMode
              ? const Color(0xFF1E1E2C)
              : AppTheme.lightBackgroundColor,
          body: SafeArea(
            child: Column(
              children: [
                // Header
                _buildHeader(isTablet, isDarkMode),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 24 : 20,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),

                          // Title Section
                          _buildTitleSection(isTablet, isDarkMode),

                          const SizedBox(height: 30),

                          // Package Details Section
                          _buildPackageDetailsSection(isTablet, isDarkMode),

                          const SizedBox(height: 24),

                          // Contact Details Section
                          _buildContactDetailsSection(isTablet, isDarkMode),

                          const SizedBox(
                              height: 100), // Space for bottom button
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom Continue Button
                _buildBottomButton(isTablet, isDarkMode),
              ],
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
        padding: EdgeInsets.all(isTablet ? 24 : 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.arrow_back,
                  color: isDarkMode
                      ? Colors.white
                      : AppTheme.lightTextPrimaryColor,
                  size: isTablet ? 24 : 20,
                ),
              ),
            ),
            Text(
              'Package Details',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 22 : 20,
                fontWeight: FontWeight.bold,
                color:
                    isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                color: AppColors.yellowAccent,
                size: isTablet ? 24 : 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleSection(bool isTablet, bool isDarkMode) {
    return SlideTransition(
      position: _slideAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Package Information',
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 24 : 22,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please provide details about your package and contact information for pickup and delivery.',
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 16 : 14,
              fontWeight: FontWeight.w400,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.7)
                  : AppTheme.lightTextSecondaryColor,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageDetailsSection(bool isTablet, bool isDarkMode) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        padding: EdgeInsets.all(isTablet ? 24 : 20),
        decoration: BoxDecoration(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : AppTheme.lightCardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isDarkMode ? Colors.white.withValues(alpha: 0.2) : Colors.blue,
            width: 1,
          ),
          boxShadow: isDarkMode
              ? null
              : [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    spreadRadius: 1,
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            Row(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  color: isDarkMode
                      ? AppColors.yellowAccent
                      : AppTheme.lightPrimaryColor,
                  size: isTablet ? 24 : 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Package Information',
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode
                        ? Colors.white
                        : AppTheme.lightTextPrimaryColor,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Package Name
            _buildInputField(
              controller: _packageNameController,
              label: 'Package Name *',
              hint: 'Enter package name (e.g., Documents, Laptop)',
              isTablet: isTablet,
              isDarkMode: isDarkMode,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter package name';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Package Description
            _buildInputField(
              controller: _packageDescriptionController,
              label: 'Description (Optional)',
              hint: 'Brief description of the package contents',
              isTablet: isTablet,
              isDarkMode: isDarkMode,
              maxLines: 2,
            ),

            const SizedBox(height: 16),

            // Package Type Selection
            _buildPackageTypeSelection(isTablet, isDarkMode),

            const SizedBox(height: 16),

            // Weight Field
            _buildInputField(
              controller: _packageWeightController,
              label: 'Weight (kg) *',
              hint: 'Enter package weight',
              isTablet: isTablet,
              isDarkMode: isDarkMode,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'[0-9.]')), // Only numbers and decimal point
              ],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter package weight';
                }
                final weight = double.tryParse(value.trim());
                if (weight == null) {
                  return 'Please enter a valid number';
                }
                if (weight <= 0) {
                  return 'Weight must be greater than 0';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Fragile Checkbox
            GestureDetector(
              onTap: () {
                setState(() {
                  _isFragile = !_isFragile;
                });
                HapticFeedback.lightImpact();
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isFragile
                      ? AppColors.yellowAccent.withValues(alpha: 0.1)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isFragile
                        ? AppColors.yellowAccent.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.2),
                    width: _isFragile ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _isFragile
                            ? AppColors.yellowAccent
                            : Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        _isFragile ? Icons.check : Icons.warning_outlined,
                        color: _isFragile ? Colors.black : Colors.orange,
                        size: isTablet ? 20 : 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fragile Package',
                            style: GoogleFonts.albertSans(
                              fontSize: isTablet ? 14 : 12,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode
                                  ? Colors.white
                                  : AppTheme.lightTextPrimaryColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Check if this package requires special handling',
                            style: GoogleFonts.albertSans(
                              fontSize: isTablet ? 12 : 10,
                              color: isDarkMode
                                  ? Colors.white.withValues(alpha: 0.7)
                                  : AppTheme.lightTextSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPackageTypeSelection(bool isTablet, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Package Type *',
          style: GoogleFonts.albertSans(
            fontSize: isTablet ? 14 : 12,
            fontWeight: FontWeight.w600,
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.8)
                : AppTheme.lightTextSecondaryColor,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _packageTypes.map((type) {
            final isSelected = _selectedPackageType == type['name'];
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedPackageType = type['name'];
                });
                HapticFeedback.lightImpact();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDarkMode
                          ? AppColors.yellowAccent.withValues(alpha: 0.2)
                          : AppTheme.lightPrimaryColor.withValues(alpha: 0.1))
                      : (isDarkMode
                          ? Colors.white.withValues(alpha: 0.05)
                          : AppTheme.lightCardColor),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? (isDarkMode
                            ? AppColors.yellowAccent
                            : AppTheme.lightPrimaryColor)
                        : (isDarkMode
                            ? Colors.white.withValues(alpha: 0.2)
                            : AppTheme.lightBorderColor),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      type['icon'],
                      color: isSelected
                          ? (isDarkMode
                              ? AppColors.yellowAccent
                              : AppTheme.lightPrimaryColor)
                          : (isDarkMode
                              ? Colors.white
                              : AppTheme.lightTextSecondaryColor),
                      size: isTablet ? 18 : 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      type['name'],
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 12 : 11,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? (isDarkMode
                                ? Colors.white
                                : AppTheme.lightPrimaryColor)
                            : (isDarkMode
                                ? Colors.white
                                : AppTheme.lightTextPrimaryColor),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildContactDetailsSection(bool isTablet, bool isDarkMode) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        padding: EdgeInsets.all(isTablet ? 24 : 20),
        decoration: BoxDecoration(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : AppTheme.lightCardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isDarkMode ? Colors.white.withValues(alpha: 0.2) : Colors.blue,
            width: 1,
          ),
          boxShadow: isDarkMode
              ? null
              : [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    spreadRadius: 1,
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            Row(
              children: [
                Icon(
                  Icons.contacts_outlined,
                  color: isDarkMode
                      ? AppColors.yellowAccent
                      : AppTheme.lightPrimaryColor,
                  size: isTablet ? 24 : 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Contact Information',
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode
                        ? Colors.white
                        : AppTheme.lightTextPrimaryColor,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Sender Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.blue.withValues(alpha: 0.3),
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
                          color: Colors.blue.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.person_outline,
                          color: Colors.blue,
                          size: isTablet ? 20 : 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Sender Details',
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 16 : 14,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode
                              ? Colors.white
                              : AppTheme.lightTextPrimaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _senderNameController,
                    label: 'Sender Name *',
                    hint: 'Enter sender full name',
                    isTablet: isTablet,
                    isDarkMode: isDarkMode,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'[a-zA-Z\s]')), // Only letters and spaces
                    ],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter sender name';
                      }
                      if (value.trim().length < 2) {
                        return 'Name must be at least 2 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildInputField(
                    controller: _senderPhoneController,
                    label: 'Sender Phone *',
                    hint: '0336-5017866',
                    isTablet: isTablet,
                    isDarkMode: isDarkMode,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9-]')), // Only numbers and dash
                      LengthLimitingTextInputFormatter(
                          12), // Max length including dash
                    ],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter sender phone number';
                      }
                      String cleanPhone = value.replaceAll('-', '');
                      if (cleanPhone.length != 11) {
                        return 'Phone number must be 11 digits';
                      }
                      if (!cleanPhone.startsWith('03')) {
                        return 'Phone number must start with 03';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Receiver Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.red.withValues(alpha: 0.3),
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
                          color: Colors.red.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.person_pin_circle_outlined,
                          color: Colors.red,
                          size: isTablet ? 20 : 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Receiver Details',
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 16 : 14,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode
                              ? Colors.white
                              : AppTheme.lightTextPrimaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _receiverNameController,
                    label: 'Receiver Name *',
                    hint: 'Enter receiver full name',
                    isTablet: isTablet,
                    isDarkMode: isDarkMode,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'[a-zA-Z\s]')), // Only letters and spaces
                    ],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter receiver name';
                      }
                      if (value.trim().length < 2) {
                        return 'Name must be at least 2 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildInputField(
                    controller: _receiverPhoneController,
                    label: 'Receiver Phone *',
                    hint: '0336-5017866',
                    isTablet: isTablet,
                    isDarkMode: isDarkMode,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9-]')), // Only numbers and dash
                      LengthLimitingTextInputFormatter(
                          12), // Max length including dash
                    ],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter receiver phone number';
                      }
                      String cleanPhone = value.replaceAll('-', '');
                      if (cleanPhone.length != 11) {
                        return 'Phone number must be 11 digits';
                      }
                      if (!cleanPhone.startsWith('03')) {
                        return 'Phone number must start with 03';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isTablet,
    required bool isDarkMode,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.albertSans(
            fontSize: isTablet ? 14 : 12,
            fontWeight: FontWeight.w600,
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.8)
                : AppTheme.lightTextSecondaryColor,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          inputFormatters: inputFormatters,
          style: GoogleFonts.albertSans(
            fontSize: isTablet ? 14 : 12,
            color: isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
          ),
          cursorColor:
              isDarkMode ? AppColors.yellowAccent : AppTheme.lightPrimaryColor,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.albertSans(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.5)
                  : AppTheme.lightTextSecondaryColor.withValues(alpha: 0.6),
              fontSize: isTablet ? 14 : 12,
            ),
            filled: true,
            fillColor:
                isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.3)
                    : AppTheme.lightBorderColor,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.3)
                    : AppTheme.lightBorderColor,
              ),
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
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Colors.red,
              ),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: isTablet ? 16 : 12,
              vertical: isTablet ? 16 : 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomButton(bool isTablet, bool isDarkMode) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: EdgeInsets.all(isTablet ? 24 : 20),
        decoration: BoxDecoration(
          color: isDarkMode
              ? const Color(0xFF1E1E2C).withValues(alpha: 0.95)
              : AppTheme.lightBackgroundColor.withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: isDarkMode
              ? null
              : Border(
                  top: BorderSide(
                    color: AppTheme.lightBorderColor,
                    width: 1,
                  ),
                ),
        ),
        child: SafeArea(
          child: GestureDetector(
            onTap: _isLoading ? null : _onContinue,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                vertical: isTablet ? 18 : 16,
              ),
              decoration: BoxDecoration(
                color: _isLoading
                    ? Colors.grey.withValues(alpha: 0.5)
                    : (isDarkMode
                        ? AppColors.yellowAccent
                        : AppTheme.lightPrimaryColor),
                borderRadius: BorderRadius.circular(25),
                boxShadow: _isLoading
                    ? null
                    : [
                        BoxShadow(
                          color: (isDarkMode
                                  ? AppColors.yellowAccent
                                  : AppTheme.lightPrimaryColor)
                              .withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isLoading)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  else ...[
                    Text(
                      'Continue to Details',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 16 : 14,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.black : Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward,
                      color: isDarkMode ? Colors.black : Colors.white,
                      size: isTablet ? 20 : 18,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
