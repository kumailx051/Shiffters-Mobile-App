import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shiffters/theme/app_colors.dart';
import 'dart:async';
import 'package:shiffters/screens/User/vehicle_recommandation_screen.dart';

class ProductsListingScreen extends StatefulWidget {
  final Map<String, dynamic>? routeData;

  const ProductsListingScreen({
    super.key,
    this.routeData,
  });

  @override
  State<ProductsListingScreen> createState() => _ProductsListingScreenState();
}

class _ProductsListingScreenState extends State<ProductsListingScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _addFieldController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _addFieldAnimation;

  List<TextEditingController> _itemControllers = [];
  List<FocusNode> _itemFocusNodes = [];
  List<GlobalKey> _fieldKeys = [];
  bool _isProcessingAI = false;

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
    final key = GlobalKey();

    // Add listener to focus node to update item count when focus is removed
    focusNode.addListener(() {
      if (!focusNode.hasFocus) {
        // Focus has been removed from this field
        if (mounted) {
          setState(() {
            // Trigger a rebuild to update the item count in the bottom bar
          });
        }
      }
    });

    setState(() {
      _itemControllers.add(controller);
      _itemFocusNodes.add(focusNode);
      _fieldKeys.add(key);
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

    HapticFeedback.lightImpact();
    
    setState(() {
      _itemControllers[index].dispose();
      _itemFocusNodes[index].dispose();
      _itemControllers.removeAt(index);
      _itemFocusNodes.removeAt(index);
      _fieldKeys.removeAt(index);
    });

    _showMessage('Item removed', isError: false);
  }

  void _showMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError 
            ? Colors.red.withOpacity(0.9)
            : Colors.green.withOpacity(0.9),
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
    
    setState(() {
      _isProcessingAI = true;
    });

    // Simulate AI processing
    await Future.delayed(const Duration(seconds: 2));

    // Simulate AI detected items
    List<String> detectedItems = [
      'Laptop Computer',
      'Office Chair',
      'Desk Lamp',
      'Books (5 items)',
      'Picture Frame',
    ];

    // Add detected items to the list
    for (String item in detectedItems) {
      _addNewField(animate: false);
      _itemControllers.last.text = item;
    }

    setState(() {
      _isProcessingAI = false;
    });

    _showMessage('${detectedItems.length} items detected and added!', isError: false);
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
      focusNode.dispose(); // Dispose focus node listeners
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(isTablet),
            
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
                    _buildTitleSection(isTablet),
                    
                    const SizedBox(height: 30),
                    
                    // Items List
                    _buildItemsList(isTablet),
                    
                    const SizedBox(height: 20),
                    
                    // Add Item Button
                    _buildAddItemButton(isTablet),
                    
                    const SizedBox(height: 30),
                    
                    // AI Recognition Section
                    _buildAISection(isTablet),
                    
                    const SizedBox(height: 100), // Space for bottom button
                  ],
                ),
              ),
            ),
            
            // Bottom Continue Button
            _buildBottomButton(isTablet),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isTablet) {
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
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: isTablet ? 24 : 20,
                ),
              ),
            ),
            
            Text(
              'Items to Shift',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 22 : 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
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

  Widget _buildTitleSection(bool isTablet) {
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
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'List all items you want to move. This helps us provide accurate pricing and ensure proper handling.',
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 16 : 14,
              fontWeight: FontWeight.w400,
              color: Colors.white.withOpacity(0.7),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(bool isTablet) {
    return SlideTransition(
      position: _slideAnimation,
      child: Column(
        children: List.generate(_itemControllers.length, (index) {
          return AnimatedBuilder(
            animation: _addFieldAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: index == _itemControllers.length - 1 
                    ? _addFieldAnimation.value 
                    : 1.0,
                child: Container(
                  key: _fieldKeys[index],
                  margin: const EdgeInsets.only(bottom: 16),
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
                      // Item Number
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.yellowAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.yellowAccent.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: GoogleFonts.albertSans(
                              fontSize: isTablet ? 16 : 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.yellowAccent,
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 16),
                      
                      // Text Field
                      Expanded(
                        child: TextField(
                          controller: _itemControllers[index],
                          focusNode: _itemFocusNodes[index],
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 16 : 14,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter item name (e.g., Sofa, TV, Boxes)',
                            hintStyle: GoogleFonts.albertSans(
                              color: Colors.white.withOpacity(0.5),
                              fontWeight: FontWeight.w400,
                              fontSize: isTablet ? 14 : 12,
                            ),
                            border: InputBorder.none,
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
                      
                      // Delete Button
                      if (_itemControllers.length > 1)
                        GestureDetector(
                          onTap: () => _removeField(index),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
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
              );
            },
          );
        }),
      ),
    );
  }

  Widget _buildAddItemButton(bool isTablet) {
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
            color: AppColors.yellowAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.yellowAccent.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.yellowAccent.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add,
                  color: AppColors.yellowAccent,
                  size: isTablet ? 20 : 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Add Another Item',
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 16 : 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.yellowAccent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAISection(bool isTablet) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(isTablet ? 24 : 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.1),
              Colors.white.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
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
                    color: AppColors.yellowAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.smart_toy,
                    color: AppColors.yellowAccent,
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
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Take a photo and let AI identify items for you',
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 14 : 12,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withOpacity(0.7),
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
                      ? Colors.grey.withOpacity(0.3)
                      : AppColors.yellowAccent,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: _isProcessingAI ? null : [
                    BoxShadow(
                      color: AppColors.yellowAccent.withOpacity(0.3),
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
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    else
                      Icon(
                        Icons.camera_alt,
                        color: Colors.black,
                        size: isTablet ? 24 : 20,
                      ),
                    const SizedBox(width: 12),
                    Text(
                      _isProcessingAI ? 'Processing...' : 'Scan Items with Camera',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 16 : 14,
                        fontWeight: FontWeight.bold,
                        color: _isProcessingAI ? Colors.white : Colors.black,
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

  Widget _buildBottomButton(bool isTablet) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: EdgeInsets.all(isTablet ? 24 : 20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2C).withOpacity(0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    color: AppColors.yellowAccent,
                    size: isTablet ? 20 : 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_itemControllers.where((c) => c.text.trim().isNotEmpty).length} items',
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 14 : 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
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
                    color: AppColors.yellowAccent,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.yellowAccent.withOpacity(0.3),
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
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward,
                        color: Colors.black,
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