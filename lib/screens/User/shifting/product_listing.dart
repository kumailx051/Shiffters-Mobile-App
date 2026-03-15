import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shiffters/theme/app_colors.dart';
import 'package:shiffters/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shiffters/services/theme_service.dart';
import 'dart:async';
import 'vehicle_recommandation_screen.dart';
import 'live_object_detection_screen.dart';

class ProductsListingScreen extends StatefulWidget {
  final Map<String, dynamic>? routeData;

  const ProductsListingScreen({
    super.key,
    this.routeData,
  });

  @override
  State<ProductsListingScreen> createState() => _ProductsListingScreenState();
}

class _ProductsListingScreenState extends State<ProductsListingScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _addFieldController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _addFieldAnimation;

  List<TextEditingController> _itemControllers = [];
  List<FocusNode> _itemFocusNodes = [];
  List<Key> _fieldKeys = [];
  List<bool> _fieldFocusStates = [];
  bool _isProcessingAI = false;
  int _fieldKeyCounter = 0; // Counter for unique keys

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeFields();
    _startAnimations();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _addFieldController = AnimationController(
      duration: const Duration(milliseconds: 400),
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

    _addFieldAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _addFieldController,
      curve: Curves.elasticOut,
    ));
  }

  void _initializeFields() {
    // Initialize with 3 default fields
    for (int i = 0; i < 3; i++) {
      _addNewField(animate: false);
    }
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) {
      _animationController.forward();
    }
  }

  void _addNewField({bool animate = true}) {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    // Create unique key using counter to prevent conflicts
    final key = ValueKey('field_${_fieldKeyCounter++}');

    // Add listener to focus node to update focus state
    focusNode.addListener(() {
      setState(() {
        int index = _itemFocusNodes.indexOf(focusNode);
        if (index != -1) {
          _fieldFocusStates[index] = focusNode.hasFocus;
        }
      });
    });

    setState(() {
      _itemControllers.add(controller);
      _itemFocusNodes.add(focusNode);
      _fieldKeys.add(key);
      _fieldFocusStates.add(false);
    });

    if (animate) {
      _addFieldController.reset();
      _addFieldController.forward();

      // Auto-focus the new field
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          focusNode.requestFocus();
        }
      });
    }
  }

  void _removeField(int index) {
    if (_itemControllers.length <= 1) {
      _showMessage('At least one item is required', isError: true);
      return;
    }

    if (index < 0 || index >= _itemControllers.length) {
      return; // Prevent out of bounds errors
    }

    HapticFeedback.lightImpact();

    // Dispose of resources before removing from lists
    _itemControllers[index].dispose();
    _itemFocusNodes[index].dispose();

    setState(() {
      _itemControllers.removeAt(index);
      _itemFocusNodes.removeAt(index);
      _fieldKeys.removeAt(index);
      _fieldFocusStates.removeAt(index);
    });

    _showMessage('Item removed', isError: false);
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
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleAIObjectRecognition() async {
    HapticFeedback.mediumImpact();

    try {
      setState(() {
        _isProcessingAI = true;
      });

      // Directly launch live detection screen
      setState(() {
        _isProcessingAI = false;
      });

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LiveObjectDetectionScreen(
            onObjectsSelected: (List<String> selectedObjects) {
              if (selectedObjects.isEmpty) return;

              setState(() {
                // Fill from the top - find empty fields first
                int objectIndex = 0;

                // First, fill existing empty fields from the top
                for (int i = 0;
                    i < _itemControllers.length &&
                        objectIndex < selectedObjects.length;
                    i++) {
                  if (_itemControllers[i].text.trim().isEmpty) {
                    _itemControllers[i].text = selectedObjects[objectIndex];
                    objectIndex++;
                  }
                }

                // If we still have objects to add, create new fields for them
                while (objectIndex < selectedObjects.length) {
                  _addNewField(animate: false);
                  _itemControllers.last.text = selectedObjects[objectIndex];
                  objectIndex++;
                }
              });

              _showMessage(
                  '${selectedObjects.length} items added from live detection!',
                  isError: false);
            },
          ),
        ),
      );
    } catch (e) {
      print('Error in AI object recognition: $e');
      _showMessage('Failed to detect objects. Please try again.',
          isError: true);
    } finally {
      setState(() {
        _isProcessingAI = false;
      });
    }
  }

  void _onContinue() {
    // Get all non-empty items
    List<String> items = _itemControllers
        .map((controller) => controller.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();

    if (items.isEmpty) {
      _showMessage('Please add at least one item', isError: true);
      return;
    }

    HapticFeedback.lightImpact();

    // Navigate to VehicleRecommandationScreen with items data
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VehicleRecommendationScreen(
          items: items,
          routeData: widget.routeData,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _addFieldController.dispose();
    for (var controller in _itemControllers) {
      controller.dispose();
    }
    for (var focusNode in _itemFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),

                        // Title and Description
                        _buildTitleSection(isTablet, isDarkMode),

                        const SizedBox(height: 30),

                        // Items List
                        _buildItemsList(isTablet, isDarkMode),

                        const SizedBox(height: 20),

                        // Add Item Button
                        _buildAddItemButton(isTablet, isDarkMode),

                        const SizedBox(height: 30),

                        // AI Recognition Section
                        _buildAISection(isTablet, isDarkMode),

                        const SizedBox(height: 100), // Space for bottom button
                      ],
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
                      : AppTheme.lightCardColor.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                  border: isDarkMode
                      ? null
                      : Border.all(
                          color: AppTheme.lightBorderColor,
                          width: 1,
                        ),
                  boxShadow: isDarkMode
                      ? null
                      : [
                          BoxShadow(
                            color: AppTheme.lightShadowMedium,
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
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
              'Items to Shift',
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
                    : AppTheme.lightCardColor.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
                border: isDarkMode
                    ? null
                    : Border.all(
                        color: AppTheme.lightBorderColor,
                        width: 1,
                      ),
                boxShadow: isDarkMode
                    ? null
                    : [
                        BoxShadow(
                          color: AppTheme.lightShadowMedium,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                color: isDarkMode
                    ? AppColors.yellowAccent
                    : AppTheme.lightPrimaryColor,
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
            'What are you shifting?',
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 24 : 22,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'List all items you want to move. This helps us provide accurate pricing and ensure proper handling.',
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 16 : 14,
              fontWeight: FontWeight.w400,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.7)
                  : AppTheme.lightTextSecondaryColor,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          // Swipe instruction
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 16 : 12,
              vertical: isTablet ? 10 : 8,
            ),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? AppColors.yellowAccent.withValues(alpha: 0.1)
                  : AppTheme.lightPrimaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDarkMode
                    ? AppColors.yellowAccent.withValues(alpha: 0.3)
                    : AppTheme.lightPrimaryColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.swipe_left,
                  color: isDarkMode
                      ? AppColors.yellowAccent
                      : AppTheme.lightPrimaryColor,
                  size: isTablet ? 18 : 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Swipe left on any item to delete',
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 12 : 11,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode
                        ? AppColors.yellowAccent
                        : AppTheme.lightPrimaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(bool isTablet, bool isDarkMode) {
    return SlideTransition(
      position: _slideAnimation,
      child: Column(
        children: List.generate(_itemControllers.length, (index) {
          bool isFocused = index < _fieldFocusStates.length
              ? _fieldFocusStates[index]
              : false;

          return AnimatedBuilder(
            animation: _addFieldAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: index == _itemControllers.length - 1
                    ? _addFieldAnimation.value
                    : 1.0,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Dismissible(
                    key: _fieldKeys[index],
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.8),
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
                              color: Colors.white,
                              fontSize: isTablet ? 12 : 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    confirmDismiss: (direction) async {
                      if (_itemControllers.length <= 1) {
                        _showMessage('At least one item is required',
                            isError: true);
                        return false;
                      }

                      // Validate index is still valid
                      if (index < 0 || index >= _itemControllers.length) {
                        return false;
                      }

                      // Show confirmation dialog
                      return await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: isDarkMode
                                  ? const Color(0xFF2D2D3C)
                                  : AppTheme.lightCardColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: isDarkMode
                                    ? BorderSide.none
                                    : BorderSide(
                                        color: AppTheme.lightBorderColor,
                                        width: 1,
                                      ),
                              ),
                              title: Text(
                                'Delete Item',
                                style: GoogleFonts.albertSans(
                                  color: isDarkMode
                                      ? Colors.white
                                      : AppTheme.lightTextPrimaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              content: Text(
                                'Are you sure you want to delete this item?',
                                style: GoogleFonts.albertSans(
                                  color: isDarkMode
                                      ? Colors.white.withValues(alpha: 0.8)
                                      : AppTheme.lightTextSecondaryColor,
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: Text(
                                    'Cancel',
                                    style: GoogleFonts.albertSans(
                                      color: isDarkMode
                                          ? Colors.white.withValues(alpha: 0.7)
                                          : AppTheme.lightTextSecondaryColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  child: Text(
                                    'Delete',
                                    style: GoogleFonts.albertSans(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ) ??
                          false;
                    },
                    onDismissed: (direction) {
                      // Double-check that the index is still valid before removing
                      if (index >= 0 && index < _itemControllers.length) {
                        HapticFeedback.mediumImpact();
                        _removeField(index);
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      padding: EdgeInsets.all(isTablet ? 20 : 16),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.1)
                            : AppTheme.lightCardColor.withValues(alpha: 0.9),
                        // More curved corners - increased border radius
                        borderRadius:
                            BorderRadius.circular(isFocused ? 20 : 16),
                        border: Border.all(
                          // Fixed color - theme-aware focus colors
                          color: isFocused
                              ? (isDarkMode
                                  ? AppColors.yellowAccent
                                  : AppTheme.lightPrimaryColor)
                              : (isDarkMode
                                  ? Colors.white.withValues(alpha: 0.2)
                                  : AppTheme.lightBorderColor),
                          width: isFocused ? 2 : 1,
                        ),
                        // Add subtle shadow when focused
                        boxShadow: isFocused
                            ? [
                                BoxShadow(
                                  color: isDarkMode
                                      ? AppColors.yellowAccent
                                          .withValues(alpha: 0.2)
                                      : AppTheme.lightPrimaryColor
                                          .withValues(alpha: 0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : (isDarkMode
                                ? null
                                : [
                                    BoxShadow(
                                      color: AppTheme.lightShadowLight,
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]),
                      ),
                      child: Row(
                        children: [
                          // Item Number
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isFocused
                                  ? (isDarkMode
                                      ? AppColors.yellowAccent
                                          .withValues(alpha: 0.3)
                                      : AppTheme.lightPrimaryColor
                                          .withValues(alpha: 0.3))
                                  : (isDarkMode
                                      ? AppColors.yellowAccent
                                          .withValues(alpha: 0.2)
                                      : AppTheme.lightPrimaryColor
                                          .withValues(alpha: 0.2)),
                              borderRadius:
                                  BorderRadius.circular(isFocused ? 16 : 12),
                              border: Border.all(
                                color: isFocused
                                    ? (isDarkMode
                                        ? AppColors.yellowAccent
                                            .withValues(alpha: 0.5)
                                        : AppTheme.lightPrimaryColor
                                            .withValues(alpha: 0.5))
                                    : (isDarkMode
                                        ? AppColors.yellowAccent
                                            .withValues(alpha: 0.3)
                                        : AppTheme.lightPrimaryColor
                                            .withValues(alpha: 0.3)),
                                width: isFocused ? 2 : 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: GoogleFonts.albertSans(
                                  fontSize: isTablet ? 16 : 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode
                                      ? AppColors.yellowAccent
                                      : AppTheme.lightPrimaryColor,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 16),

                          // Text Field
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isTablet ? 12 : 10,
                                vertical: isTablet ? 8 : 6,
                              ),
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.black.withValues(alpha: 0.05),
                                borderRadius:
                                    BorderRadius.circular(isFocused ? 12 : 8),
                                border: Border.all(
                                  color: Colors.transparent,
                                  width: 0,
                                ),
                              ),
                              child: Theme(
                                // Override the default focus color to ensure proper theme colors
                                data: Theme.of(context).copyWith(
                                  colorScheme:
                                      Theme.of(context).colorScheme.copyWith(
                                            primary: isDarkMode
                                                ? AppColors.yellowAccent
                                                : AppTheme.lightPrimaryColor,
                                          ),
                                ),
                                child: TextField(
                                  controller: _itemControllers[index],
                                  focusNode: _itemFocusNodes[index],
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(RegExp(
                                        r'[a-zA-Z\s]')), // Only letters and spaces
                                  ],
                                  style: GoogleFonts.albertSans(
                                    fontSize: isTablet ? 16 : 14,
                                    color: isDarkMode
                                        ? Colors.white
                                        : AppTheme.lightTextPrimaryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  cursorColor: isDarkMode
                                      ? AppColors.yellowAccent
                                      : AppTheme
                                          .lightPrimaryColor, // Ensure cursor follows theme
                                  decoration: InputDecoration(
                                    hintText:
                                        'Enter item name (e.g., Sofa, TV, Boxes)',
                                    hintStyle: GoogleFonts.albertSans(
                                      color: isDarkMode
                                          ? Colors.white.withValues(alpha: 0.5)
                                          : AppTheme.lightTextLightColor,
                                      fontWeight: FontWeight.w400,
                                      fontSize: isTablet ? 14 : 12,
                                    ),
                                    border: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  textInputAction: TextInputAction.next,
                                  onSubmitted: (_) {
                                    if (index < _itemFocusNodes.length - 1) {
                                      _itemFocusNodes[index + 1].requestFocus();
                                    } else {
                                      _addNewField();
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),

                          // Delete Button (tap to delete)
                          if (_itemControllers.length > 1)
                            GestureDetector(
                              onTap: () => _removeField(index),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(
                                      isFocused ? 14 : 10),
                                ),
                                child: Icon(
                                  Icons.remove,
                                  color: Colors.red,
                                  size: isTablet ? 20 : 18,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }

  Widget _buildAddItemButton(bool isTablet, bool isDarkMode) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          _addNewField();
        },
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            vertical: isTablet ? 16 : 14,
            horizontal: isTablet ? 20 : 16,
          ),
          decoration: BoxDecoration(
            color: isDarkMode
                ? AppColors.yellowAccent.withValues(alpha: 0.1)
                : AppTheme.lightPrimaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDarkMode
                  ? AppColors.yellowAccent.withValues(alpha: 0.3)
                  : AppTheme.lightPrimaryColor.withValues(alpha: 0.3),
              width: 2,
            ),
            boxShadow: isDarkMode
                ? null
                : [
                    BoxShadow(
                      color: AppTheme.lightShadowLight,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? AppColors.yellowAccent.withValues(alpha: 0.2)
                      : AppTheme.lightPrimaryColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add,
                  color: isDarkMode
                      ? AppColors.yellowAccent
                      : AppTheme.lightPrimaryColor,
                  size: isTablet ? 20 : 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Add Another Item',
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 16 : 14,
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
    );
  }

  Widget _buildAISection(bool isTablet, bool isDarkMode) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(isTablet ? 24 : 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDarkMode
                ? [
                    Colors.white.withValues(alpha: 0.1),
                    Colors.white.withValues(alpha: 0.05),
                  ]
                : [
                    AppTheme.lightCardColor.withValues(alpha: 0.8),
                    AppTheme.lightCardColor.withValues(alpha: 0.6),
                  ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.2)
                : AppTheme.lightBorderColor,
            width: 1,
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
          children: [
            // AI Icon and Title
            Row(
              children: [
                Container(
                  width: isTablet ? 50 : 45,
                  height: isTablet ? 50 : 45,
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? AppColors.yellowAccent.withValues(alpha: 0.2)
                        : AppTheme.lightPrimaryColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.smart_toy,
                    color: isDarkMode
                        ? AppColors.yellowAccent
                        : AppTheme.lightPrimaryColor,
                    size: isTablet ? 28 : 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Object Recognition',
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 18 : 16,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode
                              ? Colors.white
                              : AppTheme.lightTextPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Real-time camera detection - point at objects and tap to add them instantly',
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 14 : 12,
                          fontWeight: FontWeight.w400,
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

            const SizedBox(height: 20),

            // Camera Button
            GestureDetector(
              onTap: _isProcessingAI ? null : _handleAIObjectRecognition,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  vertical: isTablet ? 16 : 14,
                ),
                decoration: BoxDecoration(
                  color: _isProcessingAI
                      ? Colors.grey.withValues(alpha: 0.3)
                      : (isDarkMode
                          ? AppColors.yellowAccent
                          : AppTheme.lightPrimaryColor),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: _isProcessingAI
                      ? null
                      : [
                          BoxShadow(
                            color: isDarkMode
                                ? AppColors.yellowAccent.withValues(alpha: 0.3)
                                : AppTheme.lightPrimaryColor
                                    .withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isProcessingAI)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isDarkMode ? Colors.white : Colors.white,
                          ),
                        ),
                      )
                    else
                      Icon(
                        Icons.videocam,
                        color: isDarkMode ? Colors.black : Colors.white,
                        size: isTablet ? 24 : 20,
                      ),
                    const SizedBox(width: 12),
                    Text(
                      _isProcessingAI
                          ? 'Opening Camera...'
                          : 'Start Live Detection',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 16 : 14,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.black : Colors.white,
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

  Widget _buildBottomButton(bool isTablet, bool isDarkMode) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: EdgeInsets.all(isTablet ? 24 : 20),
        decoration: BoxDecoration(
          color: isDarkMode
              ? const Color(0xFF1E1E2C).withValues(alpha: 0.95)
              : AppTheme.lightCardColor.withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: isDarkMode
              ? null
              : Border(
                  top: BorderSide(
                    color: AppTheme.lightBorderColor,
                    width: 1,
                  ),
                ),
          boxShadow: isDarkMode
              ? null
              : [
                  BoxShadow(
                    color: AppTheme.lightShadowMedium,
                    blurRadius: 12,
                    offset: const Offset(0, -2),
                  ),
                ],
        ),
        child: Row(
          children: [
            // Items Count
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 16 : 12,
                vertical: isTablet ? 12 : 10,
              ),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.1)
                    : AppTheme.lightBackgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: isDarkMode
                    ? null
                    : Border.all(
                        color: AppTheme.lightBorderColor,
                        width: 1,
                      ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    color: isDarkMode
                        ? AppColors.yellowAccent
                        : AppTheme.lightPrimaryColor,
                    size: isTablet ? 20 : 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_itemControllers.where((c) => c.text.trim().isNotEmpty).length} items',
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 14 : 12,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode
                          ? Colors.white
                          : AppTheme.lightTextPrimaryColor,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 16),

            // Continue Button
            Expanded(
              child: GestureDetector(
                onTap: _onContinue,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    vertical: isTablet ? 16 : 14,
                  ),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? AppColors.yellowAccent
                        : AppTheme.lightPrimaryColor,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: isDarkMode
                            ? AppColors.yellowAccent.withValues(alpha: 0.3)
                            : AppTheme.lightPrimaryColor.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Continue',
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
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
