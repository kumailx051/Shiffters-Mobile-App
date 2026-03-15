import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shiffters/theme/app_colors.dart';
import 'package:shiffters/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shiffters/services/theme_service.dart';
import 'package:shiffters/services/stripe_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lottie/lottie.dart';
import 'shifting_confirmation_screen.dart';

// Extension for color opacity - replaces withValues
extension ColorExtension on Color {
  Color withValues({double? alpha}) {
    return withOpacity(alpha ?? 1.0);
  }
}

class ShiftingPaymentScreen extends StatefulWidget {
  final Map<String, dynamic> shiftingData;

  const ShiftingPaymentScreen({
    super.key,
    required this.shiftingData,
  });

  @override
  State<ShiftingPaymentScreen> createState() => _ShiftingPaymentScreenState();
}

class _ShiftingPaymentScreenState extends State<ShiftingPaymentScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String _selectedPaymentMethod = 'Cash on Pickup';
  String _selectedCardType = 'Visa';
  bool _isProcessing = false;
  bool _hasSavedCard = false;
  bool _useSavedCard = false;
  Map<String, dynamic>? _savedCardDetails;

  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _cardHolderController = TextEditingController();
  final TextEditingController _expiryDateController = TextEditingController();
  final TextEditingController _cvvController = TextEditingController();
  final TextEditingController _discountCodeController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  // Discount related variables
  bool _isApplyingDiscount = false;
  bool _isDiscountApplied = false;
  Map<String, dynamic>? _appliedDiscount;

  final List<Map<String, dynamic>> _paymentMethods = [
    {
      'name': 'Cash on Pickup',
      'icon': Icons.money,
      'description': 'Pay when we arrive to pick up your items'
    },
    {
      'name': 'Cash on Delivery',
      'icon': Icons.delivery_dining,
      'description': 'Pay when items are delivered'
    },
    {
      'name': 'Credit/Debit Card',
      'icon': Icons.credit_card,
      'description': 'Pay securely with your card'
    },
  ];

  final List<Map<String, dynamic>> _cardTypes = [
    {'name': 'Visa', 'icon': Icons.credit_card},
    {'name': 'MasterCard', 'icon': Icons.credit_card},
    {'name': 'American Express', 'icon': Icons.credit_card},
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
    _setupCardNumberFormatting();
    _checkForSavedCards();
  }

  // Check if user has saved cards
  Future<void> _checkForSavedCards() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Check if user has save payment enabled
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return;

      final userData = userDoc.data() as Map<String, dynamic>;
      final preferences =
          userData['preferences'] as Map<String, dynamic>? ?? {};
      final savePayment = preferences['savePayment'] ?? false;

      if (!savePayment) return;

      // Check if user has any saved card details
      final savedCards = userData['savedCards'] as List<dynamic>? ?? [];

      if (savedCards.isNotEmpty) {
        // Use the most recent saved card
        final latestCard = savedCards.last as Map<String, dynamic>;

        setState(() {
          _hasSavedCard = true;
          _savedCardDetails = latestCard;
        });

        debugPrint('✅ Found saved card: ${_savedCardDetails}');
      } else {
        // Check previous orders for card details
        final ordersSnapshot = await FirebaseFirestore.instance
            .collection('orders')
            .where('uid', isEqualTo: user.uid)
            .where('paymentMethod', isEqualTo: 'Credit/Debit Card')
            .where('cardDetails', isNull: false)
            .orderBy('paymentTimestamp', descending: true)
            .limit(1)
            .get();

        if (ordersSnapshot.docs.isNotEmpty) {
          final latestOrder = ordersSnapshot.docs.first.data();
          final cardDetails =
              latestOrder['cardDetails'] as Map<String, dynamic>?;

          if (cardDetails != null) {
            setState(() {
              _hasSavedCard = true;
              _savedCardDetails = cardDetails;
            });

            debugPrint(
                '✅ Found card from previous order: ${_savedCardDetails}');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error checking for saved cards: $e');
    }
  }

  void _setupCardNumberFormatting() {
    _cardNumberController.addListener(() {
      final text = _cardNumberController.text;
      final formattedText = StripeService.formatCardNumber(text);

      if (text != formattedText) {
        _cardNumberController.value = _cardNumberController.value.copyWith(
          text: formattedText,
          selection: TextSelection.collapsed(offset: formattedText.length),
        );
      }

      // Auto-detect card type
      final cardType = StripeService.getCardType(formattedText);
      if (cardType != 'Unknown' && cardType != _selectedCardType) {
        setState(() {
          _selectedCardType = cardType;
        });
      }
    });

    // Enhanced expiry date formatting
    _expiryDateController.addListener(() {
      final text = _expiryDateController.text;

      // Remove everything except digits
      final digitsOnly = text.replaceAll(RegExp(r'[^0-9]'), '');

      String formattedText = '';

      if (digitsOnly.isNotEmpty) {
        // Handle month formatting
        if (digitsOnly.length >= 1) {
          String month =
              digitsOnly.substring(0, digitsOnly.length >= 2 ? 2 : 1);

          // Auto-format single digit months
          if (month.length == 1) {
            int monthInt = int.parse(month);
            if (monthInt > 1) {
              month = '0$month';
            }
          }

          // Validate month
          if (month.length == 2) {
            int monthInt = int.parse(month);
            if (monthInt < 1 || monthInt > 12) {
              month = month.substring(0, 1); // Keep only first digit if invalid
            }
          }

          formattedText = month;

          // Add slash after valid month
          if (month.length == 2 && digitsOnly.length > 2) {
            formattedText += '/';
          }
        }

        // Add year (maximum 2 digits)
        if (digitsOnly.length > 2) {
          String year = digitsOnly.substring(2);
          if (year.length > 2) {
            year = year.substring(0, 2);
          }

          if (formattedText.endsWith('/')) {
            formattedText += year;
          } else if (formattedText.length == 2) {
            formattedText += '/$year';
          }
        }
      }

      // Update only if the formatted text is different
      if (text != formattedText) {
        final newSelection =
            TextSelection.collapsed(offset: formattedText.length);
        _expiryDateController.value = _expiryDateController.value.copyWith(
          text: formattedText,
          selection: newSelection,
        );
      }
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

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _cardNumberController.dispose();
    _cardHolderController.dispose();
    _expiryDateController.dispose();
    _cvvController.dispose();
    _discountCodeController.dispose();
    super.dispose();
  }

  bool _isCardPayment() {
    return _selectedPaymentMethod == 'Credit/Debit Card';
  }

  // Update payment details in Firestore
  Future<void> _updateOrderPayment(
      String orderId, double totalAmount, String paymentMethod,
      [String? transactionId]) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      Map<String, dynamic> paymentData = {
        'totalAmount': totalAmount.round(),
        'paymentMethod': paymentMethod,
        'paymentStatus': _isCardPayment()
            ? (transactionId != null ? 'completed' : 'failed')
            : 'pending',
        'paymentTimestamp': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'status': 'active',
      };

      // Add card details if card payment
      if (_isCardPayment()) {
        if (_useSavedCard && _savedCardDetails != null) {
          // Use saved card details
          paymentData['cardDetails'] = _savedCardDetails;
          paymentData['usedSavedCard'] = true;
        } else {
          // Use entered card details
          paymentData['cardDetails'] = {
            'cardType': _selectedCardType,
            'cardLastFour': _cardNumberController.text
                        .replaceAll(' ', '')
                        .length >=
                    4
                ? _cardNumberController.text.replaceAll(' ', '').substring(
                    _cardNumberController.text.replaceAll(' ', '').length - 4)
                : '',
            'cardHolderName': _cardHolderController.text.trim(),
          };
        }

        // Add Stripe payment details
        if (transactionId != null) {
          paymentData['paymentDetails'] = {
            'transactionId': transactionId,
            'stripePaymentIntentId': transactionId,
            'processedAt': FieldValue.serverTimestamp(),
            'amount': totalAmount,
            'currency': 'usd',
          };
        }
      }

      // Add discount information if applied
      if (_isDiscountApplied && _appliedDiscount != null) {
        final discountType = _appliedDiscount!['discountType'];
        final discountValue =
            (_appliedDiscount!['discountValue'] as num).toDouble();

        // Calculate subtotal and discount amount
        final vehicle =
            widget.shiftingData['vehicle'] as Map<String, dynamic>? ?? {};
        final additionalDetails =
            widget.shiftingData['additionalDetails'] as Map<String, dynamic>? ??
                {};

        double basePrice = (vehicle['basePrice'] as num?)?.toDouble() ?? 0.0;
        double additionalCosts = 0.0;

        if (additionalDetails['needAssemblyDisassembly'] == true) {
          additionalCosts += 500.0;
        }
        if (additionalDetails['needPackingMaterials'] == true) {
          additionalCosts += 300.0;
        }
        if (additionalDetails['needExtraHelpers'] == true) {
          additionalCosts += 400.0;
        }

        double subtotal = basePrice + additionalCosts;
        double discountAmount = 0.0;

        if (discountType == 'percentage') {
          discountAmount = subtotal * (discountValue / 100);
        } else {
          discountAmount = discountValue;
        }

        // Ensure discount doesn't exceed subtotal
        discountAmount = discountAmount > subtotal ? subtotal : discountAmount;

        paymentData['subtotal'] = subtotal;
        paymentData['discount'] = {
          'discountCode': _appliedDiscount!['code'],
          'discountType': discountType,
          'discountValue': discountValue,
          'discountAmount': discountAmount,
        };
      }

      // Update the order in Firestore
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update(paymentData);

      debugPrint('Payment details updated successfully for order: $orderId');
    } catch (e) {
      debugPrint('Error updating payment details: $e');
      rethrow;
    }
  }

  void _onContinue() async {
    if (_isCardPayment()) {
      if (!_useSavedCard && !_formKey.currentState!.validate()) {
        _showMessage('Please fill all required card details', isError: true);
        return;
      }
    }

    setState(() {
      _isProcessing = true;
    });

    HapticFeedback.lightImpact();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showMessage('User not authenticated. Please login first.',
            isError: true);
        return;
      }

      // Calculate total amount
      final totalAmount = _calculateTotalAmount();
      final orderId = widget.shiftingData['orderId'] as String?;

      if (orderId == null) {
        throw Exception('Order ID not found');
      }

      Map<String, dynamic> paymentResult = {'success': true};
      String? transactionId;

      // Show processing animation
      _showProcessingDialog();

      // Process Stripe payment for card payments
      if (_isCardPayment()) {
        if (_useSavedCard && _savedCardDetails != null) {
          // Simulate successful payment with saved card
          debugPrint('✅ Using saved card for payment');
          await Future.delayed(const Duration(seconds: 2));
          transactionId = 'saved-${DateTime.now().millisecondsSinceEpoch}';
          paymentResult = {
            'success': true,
            'paymentIntentId': transactionId,
          };
        } else {
          // Process with new card details
          // Validate card details
          final validation = StripeService.validateCardDetails(
            cardNumber: _cardNumberController.text,
            expiryDate: _expiryDateController.text,
            cvc: _cvvController.text,
            cardHolderName: _cardHolderController.text,
          );

          if (!validation['isValid']) {
            final errors = validation['errors'] as List<String>;
            // Close processing dialog
            if (mounted) {
              Navigator.of(context).pop();
            }
            _showMessage(errors.first, isError: true);
            return;
          }

          // Extract expiry month and year
          final expiryParts = _expiryDateController.text.split('/');
          final expiryMonth = expiryParts[0];
          final expiryYear = '20${expiryParts[1]}'; // Convert YY to YYYY

          // Process Stripe payment
          debugPrint(
              '🔄 Processing Stripe payment for amount: \$${totalAmount.toStringAsFixed(2)}');

          paymentResult = await StripeService.makePaymentWithCard(
            amount: totalAmount,
            currency: 'usd',
            description: 'Shiffters Shifting Service',
            cardNumber: _cardNumberController.text,
            expiryMonth: expiryMonth,
            expiryYear: expiryYear,
            cvc: _cvvController.text,
            cardHolderName: _cardHolderController.text,
          );

          if (paymentResult['success']) {
            transactionId = paymentResult['paymentIntentId'];
            debugPrint('✅ Stripe payment successful: $transactionId');

            // Check if we should save this card
            await _saveCardIfEnabled(user.uid, {
              'cardType': _selectedCardType,
              'cardLastFour': _cardNumberController.text
                  .replaceAll(' ', '')
                  .substring(
                      _cardNumberController.text.replaceAll(' ', '').length -
                          4),
              'cardHolderName': _cardHolderController.text.trim(),
              'savedAt': FieldValue.serverTimestamp(),
            });
          } else {
            debugPrint('❌ Stripe payment failed: ${paymentResult['error']}');
            // Close processing dialog
            if (mounted) {
              Navigator.of(context).pop();
            }
            _showMessage(paymentResult['error'] ?? 'Payment failed',
                isError: true);
            return;
          }
        }
      } else {
        // Simulate processing delay for non-card payments
        await Future.delayed(const Duration(seconds: 2));
      }

      // Update payment details in Firestore
      await _updateOrderPayment(
          orderId, totalAmount, _selectedPaymentMethod, transactionId);

      // Close processing dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Calculate subtotal and discount amount
      final vehicle =
          widget.shiftingData['vehicle'] as Map<String, dynamic>? ?? {};
      final additionalDetails =
          widget.shiftingData['additionalDetails'] as Map<String, dynamic>? ??
              {};

      double basePrice = (vehicle['basePrice'] as num?)?.toDouble() ?? 0.0;
      double additionalCosts = 0.0;

      if (additionalDetails['needAssemblyDisassembly'] == true) {
        additionalCosts += 500.0;
      }
      if (additionalDetails['needPackingMaterials'] == true) {
        additionalCosts += 300.0;
      }
      if (additionalDetails['needExtraHelpers'] == true) {
        additionalCosts += 400.0;
      }

      double subtotal = basePrice + additionalCosts;
      double discountAmount = 0.0;

      // Include discount information if applied
      Map<String, dynamic> discountInfo = {};
      if (_isDiscountApplied && _appliedDiscount != null) {
        final discountType = _appliedDiscount!['discountType'];
        final discountValue =
            (_appliedDiscount!['discountValue'] as num).toDouble();

        if (discountType == 'percentage') {
          discountAmount = subtotal * (discountValue / 100);
        } else {
          discountAmount = discountValue;
        }

        // Ensure discount doesn't exceed subtotal
        discountAmount = discountAmount > subtotal ? subtotal : discountAmount;

        discountInfo = {
          'discountCode': _appliedDiscount!['code'],
          'discountType': discountType,
          'discountValue': discountValue,
          'discountAmount': discountAmount,
        };
      }

      // Prepare complete data for confirmation screen
      Map<String, dynamic> completeShiftingData = {
        ...widget.shiftingData,
        'payment': {
          'method': _selectedPaymentMethod,
          'cardType': _isCardPayment()
              ? (_useSavedCard && _savedCardDetails != null
                  ? _savedCardDetails!['cardType']
                  : _selectedCardType)
              : null,
          'cardNumber': _isCardPayment()
              ? '**** **** **** ${_useSavedCard && _savedCardDetails != null ? _savedCardDetails!['cardLastFour'] : _cardNumberController.text.replaceAll(' ', '').substring(_cardNumberController.text.replaceAll(' ', '').length - 4)}'
              : null,
          'timestamp': DateTime.now().toIso8601String(),
          'status': paymentResult['success'] ? 'completed' : 'failed',
          'transactionId':
              transactionId ?? 'TXN${DateTime.now().millisecondsSinceEpoch}',
          'stripePaymentIntentId': transactionId,
          'subtotal': subtotal,
          'discount': _isDiscountApplied ? discountInfo : null,
        },
        'totalAmount': totalAmount.round(),
        'paymentStatus': 'completed',
        'orderStatus': 'confirmed',
      };

      _showMessage(
          paymentResult['success']
              ? 'Payment successful! Order confirmed.'
              : 'Order placed successfully!',
          isError: false);

      // Navigate to confirmation screen
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ShiftingConfirmationScreen(shiftingData: completeShiftingData),
          ),
        );
      }
    } catch (e) {
      debugPrint('Payment processing error: $e');

      // Close processing dialog if open
      if (mounted && _isProcessing) {
        Navigator.of(context).pop();
      }

      _showMessage('Payment failed. Please try again.', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // Save card details if user has save payment enabled
  Future<void> _saveCardIfEnabled(
      String userId, Map<String, dynamic> cardDetails) async {
    try {
      // Check if user has save payment enabled
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) return;

      final userData = userDoc.data() as Map<String, dynamic>;
      final preferences =
          userData['preferences'] as Map<String, dynamic>? ?? {};
      final savePayment = preferences['savePayment'] ?? false;

      if (!savePayment) return;

      // User has save payment enabled, save card details
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'savedCards': FieldValue.arrayUnion([cardDetails]),
      });

      debugPrint('✅ Card details saved successfully');
    } catch (e) {
      debugPrint('❌ Error saving card details: $e');
    }
  }

  void _showProcessingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Consumer<ThemeService>(
        builder: (context, themeService, child) {
          final isDarkMode = themeService.isDarkMode;
          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? const Color(0xFF1E1E2C)
                    : AppTheme.lightCardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDarkMode
                      ? AppColors.yellowAccent.withValues(alpha: 0.3)
                      : AppTheme.lightBorderColor,
                  width: 1,
                ),
                boxShadow: isDarkMode
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.grey.withValues(alpha: 0.2),
                          spreadRadius: 2,
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Lottie Animation
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: Lottie.asset(
                      'assets/animations/processingMoney.json',
                      fit: BoxFit.contain,
                      repeat: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Processing Payment...',
                    style: GoogleFonts.albertSans(
                      color: isDarkMode
                          ? Colors.white
                          : AppTheme.lightTextPrimaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please wait while we process your payment',
                    style: GoogleFonts.albertSans(
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.7)
                          : AppTheme.lightTextSecondaryColor,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  double _calculateTotalAmount() {
    // Extract data
    final vehicle =
        widget.shiftingData['vehicle'] as Map<String, dynamic>? ?? {};
    final additionalDetails =
        widget.shiftingData['additionalDetails'] as Map<String, dynamic>? ?? {};

    // Calculate costs
    double basePrice = (vehicle['basePrice'] as num?)?.toDouble() ?? 0.0;
    double additionalCosts = 0.0;

    if (additionalDetails['needAssemblyDisassembly'] == true) {
      additionalCosts += 500.0;
    }
    if (additionalDetails['needPackingMaterials'] == true) {
      additionalCosts += 300.0;
    }
    if (additionalDetails['needExtraHelpers'] == true) {
      additionalCosts += 400.0;
    }

    // Calculate subtotal
    double subtotal = basePrice + additionalCosts;

    // Apply discount if applicable
    double discountAmount = 0.0;
    if (_isDiscountApplied && _appliedDiscount != null) {
      final discountType = _appliedDiscount!['discountType'];
      final discountValue =
          (_appliedDiscount!['discountValue'] as num).toDouble();

      if (discountType == 'percentage') {
        // Apply percentage discount
        discountAmount = subtotal * (discountValue / 100);
      } else if (discountType == 'fixed') {
        // Apply fixed amount discount
        discountAmount = discountValue;
      }
    }

    // Ensure discount doesn't exceed the total amount
    discountAmount = discountAmount > subtotal ? subtotal : discountAmount;

    return subtotal - discountAmount;
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
                  fontSize: 14,
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

  // Method to validate and apply discount code
  Future<void> _validateAndApplyDiscountCode() async {
    final discountCode = _discountCodeController.text.trim().toUpperCase();
    if (discountCode.isEmpty) {
      _showMessage('Please enter a discount code', isError: true);
      return;
    }

    setState(() {
      _isApplyingDiscount = true;
    });

    try {
      // Check if the discount code exists and is valid
      final discountSnapshot = await FirebaseFirestore.instance
          .collection('discounts')
          .where('code', isEqualTo: discountCode)
          .get();

      if (discountSnapshot.docs.isEmpty) {
        setState(() {
          _isApplyingDiscount = false;
        });
        _showMessage('Invalid discount code', isError: true);
        return;
      }

      // Get the discount document
      final discountDoc = discountSnapshot.docs.first;
      final discountData = discountDoc.data();

      // Check if the discount has expired
      final expiryDate = discountData['expiryDate'] as Timestamp?;
      if (expiryDate != null && expiryDate.toDate().isBefore(DateTime.now())) {
        setState(() {
          _isApplyingDiscount = false;
        });
        _showMessage('This discount code has expired', isError: true);
        return;
      }

      // Apply the discount
      setState(() {
        _appliedDiscount = discountData;
        _isDiscountApplied = true;
        _isApplyingDiscount = false;
      });

      // Show success message
      final discountType = discountData['discountType'];
      final discountValue = discountData['discountValue'];
      String discountText;

      if (discountType == 'percentage') {
        discountText = '$discountValue% off';
      } else {
        discountText = 'Rs. $discountValue off';
      }

      _showMessage('Discount applied: $discountText', isError: false);
    } catch (e) {
      setState(() {
        _isApplyingDiscount = false;
      });
      _showMessage('Error applying discount: $e', isError: true);
    }
  }

  // Method to remove applied discount
  void _removeDiscount() {
    setState(() {
      _isDiscountApplied = false;
      _appliedDiscount = null;
      _discountCodeController.clear();
    });
    _showMessage('Discount removed', isError: false);
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

                          // Order Summary
                          _buildOrderSummary(isTablet, isDarkMode),

                          const SizedBox(height: 24),

                          // Payment Method
                          _buildPaymentMethod(isTablet, isDarkMode),

                          // Card Details (if card payment selected)
                          if (_isCardPayment()) ...[
                            const SizedBox(height: 24),
                            _buildCardDetails(isTablet, isDarkMode),
                          ],

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
              'Payment',
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
                Icons.payment,
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

  Widget _buildOrderSummary(bool isTablet, bool isDarkMode) {
    // Extract data
    final vehicle =
        widget.shiftingData['vehicle'] as Map<String, dynamic>? ?? {};
    final additionalDetails =
        widget.shiftingData['additionalDetails'] as Map<String, dynamic>? ?? {};
    final routeData =
        widget.shiftingData['route_data'] as Map<String, dynamic>? ?? {};

    // Calculate costs
    final totalAmount = _calculateTotalAmount();
    double basePrice = (vehicle['basePrice'] as num?)?.toDouble() ?? 0.0;

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
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.2)
                : AppTheme.lightBorderColor,
            width: 1,
          ),
          boxShadow: isDarkMode
              ? null
              : [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    spreadRadius: 1,
                    blurRadius: 8,
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
                  Icons.receipt_long,
                  color: isDarkMode
                      ? AppColors.yellowAccent
                      : AppTheme.lightPrimaryColor,
                  size: isTablet ? 24 : 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Order Summary',
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

            // Shifting Service
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? AppColors.yellowAccent.withValues(alpha: 0.1)
                    : AppTheme.lightPrimaryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDarkMode
                      ? AppColors.yellowAccent.withValues(alpha: 0.3)
                      : AppTheme.lightPrimaryColor.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? AppColors.yellowAccent.withValues(alpha: 0.2)
                          : AppTheme.lightPrimaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.local_shipping,
                      color: isDarkMode
                          ? AppColors.yellowAccent
                          : AppTheme.lightPrimaryColor,
                      size: isTablet ? 20 : 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Shifting Service',
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 14 : 12,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode
                                ? Colors.white
                                : AppTheme.lightTextPrimaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Vehicle: ${vehicle['name'] ?? 'N/A'} • Time: ${additionalDetails['timeSlot'] ?? 'N/A'}',
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

            const SizedBox(height: 16),

            // Route Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.05)
                    : AppTheme.lightBackgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.2)
                      : AppTheme.lightBorderColor,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.blue.withValues(alpha: 0.2)
                          : AppTheme.lightPrimaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.route,
                      color:
                          isDarkMode ? Colors.blue : AppTheme.lightPrimaryColor,
                      size: isTablet ? 20 : 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Route',
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 14 : 12,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode
                                ? Colors.white
                                : AppTheme.lightTextPrimaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${routeData['distance']?.toStringAsFixed(1) ?? '0'} km • N/A',
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

            const SizedBox(height: 20),

            // Cost Breakdown Header
            Text(
              'Cost Breakdown',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 16 : 14,
                fontWeight: FontWeight.bold,
                color:
                    isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
              ),
            ),

            const SizedBox(height: 12),

            // Base Price
            _buildCostRow('Base Price', 'Rs. ${basePrice.toStringAsFixed(0)}',
                isTablet, isDarkMode),

            // Additional Services
            if (additionalDetails['needAssemblyDisassembly'] == true)
              _buildCostRow('Assembly/Disassembly Service', 'Rs. 500', isTablet,
                  isDarkMode),

            if (additionalDetails['needPackingMaterials'] == true)
              _buildCostRow(
                  'Packing Materials', 'Rs. 300', isTablet, isDarkMode),

            if (additionalDetails['needExtraHelpers'] == true)
              _buildCostRow('Extra Helpers', 'Rs. 400', isTablet, isDarkMode),

            const SizedBox(height: 16),

            // Discount Code Input
            Container(
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.05)
                    : AppTheme.lightBackgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.2)
                      : AppTheme.lightBorderColor,
                  width: 1,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(isTablet ? 12 : 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Discount Code',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 14 : 12,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode
                            ? Colors.white
                            : AppTheme.lightTextPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _discountCodeController,
                            enabled:
                                !_isDiscountApplied && !_isApplyingDiscount,
                            style: GoogleFonts.albertSans(
                              color: isDarkMode
                                  ? Colors.white
                                  : AppTheme.lightTextPrimaryColor,
                              fontSize: isTablet ? 14 : 12,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Enter discount code',
                              hintStyle: GoogleFonts.albertSans(
                                color: isDarkMode
                                    ? Colors.white.withValues(alpha: 0.5)
                                    : Colors.grey,
                                fontSize: isTablet ? 14 : 12,
                              ),
                              filled: true,
                              fillColor: isDarkMode
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.grey.shade100,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: isTablet ? 10 : 8,
                              ),
                            ),
                            textCapitalization: TextCapitalization.characters,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[A-Za-z0-9]')),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_isDiscountApplied)
                          ElevatedButton.icon(
                            onPressed: _removeDiscount,
                            icon: Icon(
                              Icons.close,
                              size: isTablet ? 16 : 14,
                            ),
                            label: Text(
                              'Remove',
                              style: GoogleFonts.albertSans(
                                fontSize: isTablet ? 12 : 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDarkMode
                                  ? Colors.red.withValues(alpha: 0.8)
                                  : Colors.red,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: isTablet ? 12 : 10,
                                vertical: isTablet ? 10 : 8,
                              ),
                            ),
                          )
                        else
                          ElevatedButton.icon(
                            onPressed: _isApplyingDiscount
                                ? null
                                : _validateAndApplyDiscountCode,
                            icon: _isApplyingDiscount
                                ? SizedBox(
                                    width: isTablet ? 14 : 12,
                                    height: isTablet ? 14 : 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(
                                    Icons.local_offer,
                                    size: isTablet ? 16 : 14,
                                  ),
                            label: Text(
                              _isApplyingDiscount ? 'Applying...' : 'Apply',
                              style: GoogleFonts.albertSans(
                                fontSize: isTablet ? 12 : 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDarkMode
                                  ? AppColors.yellowAccent
                                  : AppTheme.lightPrimaryColor,
                              foregroundColor:
                                  isDarkMode ? Colors.black : Colors.white,
                              disabledBackgroundColor: isDarkMode
                                  ? AppColors.yellowAccent
                                      .withValues(alpha: 0.5)
                                  : AppTheme.lightPrimaryColor
                                      .withValues(alpha: 0.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: isTablet ? 12 : 10,
                                vertical: isTablet ? 10 : 8,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (_isDiscountApplied && _appliedDiscount != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? AppColors.yellowAccent.withValues(alpha: 0.2)
                              : AppTheme.lightPrimaryColor
                                  .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _appliedDiscount!['discountType'] == 'percentage'
                              ? '${_appliedDiscount!['discountValue']}% off applied'
                              : 'Rs. ${_appliedDiscount!['discountValue']} off applied',
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 12 : 10,
                            fontWeight: FontWeight.w500,
                            color: isDarkMode
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

            const SizedBox(height: 16),

            // Divider
            Container(
              height: 1,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.2)
                  : AppTheme.lightBorderColor,
            ),

            const SizedBox(height: 16),

            // Calculate subtotal and discount amount for display
            Builder(builder: (context) {
              // Extract data
              final vehicle =
                  widget.shiftingData['vehicle'] as Map<String, dynamic>? ?? {};
              final additionalDetails = widget.shiftingData['additionalDetails']
                      as Map<String, dynamic>? ??
                  {};

              // Calculate costs
              double basePrice =
                  (vehicle['basePrice'] as num?)?.toDouble() ?? 0.0;
              double additionalCosts = 0.0;

              if (additionalDetails['needAssemblyDisassembly'] == true) {
                additionalCosts += 500.0;
              }
              if (additionalDetails['needPackingMaterials'] == true) {
                additionalCosts += 300.0;
              }
              if (additionalDetails['needExtraHelpers'] == true) {
                additionalCosts += 400.0;
              }

              final subtotal = basePrice + additionalCosts;
              double discountAmount = 0.0;

              if (_isDiscountApplied && _appliedDiscount != null) {
                final discountType = _appliedDiscount!['discountType'];
                final discountValue =
                    (_appliedDiscount!['discountValue'] as num).toDouble();

                if (discountType == 'percentage') {
                  discountAmount = subtotal * (discountValue / 100);
                } else if (discountType == 'fixed') {
                  discountAmount = discountValue;
                }

                // Ensure discount doesn't exceed the total amount
                discountAmount =
                    discountAmount > subtotal ? subtotal : discountAmount;

                // Display the subtotal and discount amount
                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Subtotal',
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 14 : 12,
                            color: isDarkMode
                                ? Colors.white.withValues(alpha: 0.7)
                                : AppTheme.lightTextSecondaryColor,
                          ),
                        ),
                        Text(
                          'Rs. ${subtotal.toStringAsFixed(0)}',
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
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.local_offer,
                              size: isTablet ? 16 : 14,
                              color: isDarkMode
                                  ? AppColors.yellowAccent
                                  : AppTheme.lightPrimaryColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Discount',
                              style: GoogleFonts.albertSans(
                                fontSize: isTablet ? 14 : 12,
                                color: isDarkMode
                                    ? AppColors.yellowAccent
                                    : AppTheme.lightPrimaryColor,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '- Rs. ${discountAmount.toStringAsFixed(0)}',
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 14 : 12,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode
                                ? AppColors.yellowAccent
                                : AppTheme.lightPrimaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              } else {
                return const SizedBox.shrink();
              }
            }),

            // Total Amount
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Amount',
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode
                        ? Colors.white
                        : AppTheme.lightTextPrimaryColor,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? AppColors.yellowAccent
                        : AppTheme.lightPrimaryColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Rs. ${totalAmount.toStringAsFixed(0)}',
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 18 : 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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

  Widget _buildCostRow(
      String label, String amount, bool isTablet, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 12 : 11,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.7)
                  : AppTheme.lightTextSecondaryColor,
            ),
          ),
          Text(
            amount,
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 12 : 11,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethod(bool isTablet, bool isDarkMode) {
    return SlideTransition(
      position: _slideAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Method',
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 18 : 16,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
            ),
          ),

          const SizedBox(height: 16),

          // Payment Method Options
          ...List.generate(_paymentMethods.length, (index) {
            final method = _paymentMethods[index];
            final isSelected = _selectedPaymentMethod == method['name'];

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedPaymentMethod = method['name'];
                });
                HapticFeedback.lightImpact();
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: EdgeInsets.all(isTablet ? 18 : 16),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? (isSelected
                          ? AppColors.yellowAccent.withValues(alpha: 0.1)
                          : Colors.white.withValues(alpha: 0.05))
                      : (isSelected
                          ? AppTheme.lightPrimaryColor.withValues(alpha: 0.1)
                          : AppTheme.lightCardColor),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDarkMode
                        ? (isSelected
                            ? AppColors.yellowAccent
                            : Colors.white.withValues(alpha: 0.2))
                        : (isSelected
                            ? AppTheme.lightPrimaryColor
                            : AppTheme.lightBorderColor),
                    width: isSelected ? 2 : 1,
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
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? (isSelected
                                ? AppColors.yellowAccent.withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.1))
                            : (isSelected
                                ? AppTheme.lightPrimaryColor
                                    .withValues(alpha: 0.2)
                                : AppTheme.lightBackgroundColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        method['icon'],
                        color: isDarkMode
                            ? (isSelected
                                ? AppColors.yellowAccent
                                : Colors.white)
                            : (isSelected
                                ? AppTheme.lightPrimaryColor
                                : AppTheme.lightTextSecondaryColor),
                        size: isTablet ? 22 : 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        method['name'],
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 14 : 12,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode
                              ? Colors.white
                              : AppTheme.lightTextPrimaryColor,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? AppColors.yellowAccent
                              : AppTheme.lightPrimaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check,
                          color: Colors.white,
                          size: isTablet ? 18 : 16,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCardDetails(bool isTablet, bool isDarkMode) {
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
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.2)
                : AppTheme.lightBorderColor,
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
                  Icons.credit_card,
                  color: isDarkMode
                      ? AppColors.yellowAccent
                      : AppTheme.lightPrimaryColor,
                  size: isTablet ? 24 : 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Card Details',
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

            // Saved Card Option if available
            if (_hasSavedCard && _savedCardDetails != null) ...[
              Container(
                padding: EdgeInsets.all(isTablet ? 16 : 12),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? (_useSavedCard
                          ? AppColors.yellowAccent.withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.05))
                      : (_useSavedCard
                          ? AppTheme.lightPrimaryColor.withValues(alpha: 0.1)
                          : Colors.grey.withValues(alpha: 0.05)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDarkMode
                        ? (_useSavedCard
                            ? AppColors.yellowAccent
                            : Colors.white.withValues(alpha: 0.2))
                        : (_useSavedCard
                            ? AppTheme.lightPrimaryColor
                            : AppTheme.lightBorderColor),
                    width: _useSavedCard ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.1)
                            : AppTheme.lightPrimaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.credit_card,
                        color: isDarkMode
                            ? Colors.white
                            : AppTheme.lightPrimaryColor,
                        size: isTablet ? 20 : 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_savedCardDetails!['cardType'] ?? 'Card'} ending in ${_savedCardDetails!['cardLastFour'] ?? '****'}',
                            style: GoogleFonts.albertSans(
                              fontSize: isTablet ? 14 : 12,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode
                                  ? Colors.white
                                  : AppTheme.lightTextPrimaryColor,
                            ),
                          ),
                          if (_savedCardDetails!['cardHolderName'] != null)
                            Text(
                              _savedCardDetails!['cardHolderName'],
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
                    Checkbox(
                      value: _useSavedCard,
                      onChanged: (value) {
                        setState(() {
                          _useSavedCard = value ?? false;
                        });
                      },
                      activeColor: isDarkMode
                          ? AppColors.yellowAccent
                          : AppTheme.lightPrimaryColor,
                      checkColor: Colors.white,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _useSavedCard
                    ? 'Or enter new card details:'
                    : 'Enter card details:',
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 14 : 12,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.8)
                      : AppTheme.lightTextSecondaryColor,
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Card Type Dropdown
            _buildCardTypeDropdown(isTablet, isDarkMode),

            const SizedBox(height: 16),

            // Card Number
            _buildTextField(
              controller: _cardNumberController,
              label: 'Card Number',
              hint: 'XXXX XXXX XXXX XXXX',
              isTablet: isTablet,
              isDarkMode: isDarkMode,
              keyboardType: TextInputType.number,
              maxLength:
                  23, // 16 digits + 3 spaces = 19, allowing extra for formatting
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'[0-9\s]')), // Allow digits and spaces
                LengthLimitingTextInputFormatter(23),
              ],
              validator: (value) {
                if (_useSavedCard) return null;

                if (value == null || value.isEmpty) {
                  return 'Please enter card number';
                }
                String cleanNumber = value.replaceAll(' ', '');
                if (cleanNumber.length < 13 || cleanNumber.length > 19) {
                  return 'Card number must be 13-19 digits';
                }
                if (!RegExp(r'^[0-9]+$').hasMatch(cleanNumber)) {
                  return 'Card number must contain only digits';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Card Holder Name
            _buildTextField(
              controller: _cardHolderController,
              label: 'Card Holder Name',
              hint: 'Enter name as on card',
              isTablet: isTablet,
              isDarkMode: isDarkMode,
              validator: (value) {
                if (_useSavedCard) return null;

                if (value == null || value.trim().isEmpty) {
                  return 'Please enter card holder name';
                }
                if (value.trim().length < 2) {
                  return 'Name must be at least 2 characters';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Expiry Date and CVV
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _expiryDateController,
                    label: 'Expiry Date',
                    hint: 'MM/YY',
                    isTablet: isTablet,
                    isDarkMode: isDarkMode,
                    keyboardType: TextInputType.number,
                    maxLength: 5,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')),
                      LengthLimitingTextInputFormatter(5),
                    ],
                    validator: (value) {
                      if (_useSavedCard) return null;

                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }

                      // Check basic format
                      if (!value.contains('/')) {
                        return 'Use MM/YY format';
                      }

                      if (!RegExp(r'^(0[1-9]|1[0-2])\/([0-9]{2})$')
                          .hasMatch(value)) {
                        return 'Invalid date';
                      }

                      // Check if card is expired
                      try {
                        List<String> parts = value.split('/');
                        int month = int.parse(parts[0]);
                        int year = 2000 + int.parse(parts[1]);
                        DateTime now = DateTime.now();
                        DateTime cardExpiry = DateTime(year, month);

                        if (cardExpiry
                            .isBefore(DateTime(now.year, now.month))) {
                          return 'Expired';
                        }

                        // Check if year is too far in the future (more than 20 years)
                        if (year > now.year + 20) {
                          return 'Invalid year';
                        }
                      } catch (e) {
                        return 'Invalid date';
                      }

                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _cvvController,
                    label: 'CVV',
                    hint: 'XXX',
                    isTablet: isTablet,
                    isDarkMode: isDarkMode,
                    keyboardType: TextInputType.number,
                    maxLength: 3,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    validator: (value) {
                      if (_useSavedCard) return null;

                      if (value == null || value.isEmpty) {
                        return 'CVV required';
                      }

                      // Always expect 3 digits unless it's Amex
                      if (value.length != 3) {
                        return 'CVV requires 3 digits';
                      }

                      if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
                        return 'Only digits allowed';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardTypeDropdown(bool isTablet, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Card Type',
          style: GoogleFonts.albertSans(
            fontSize: isTablet ? 14 : 12,
            fontWeight: FontWeight.w600,
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.8)
                : AppTheme.lightTextSecondaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.1)
                : AppTheme.lightCardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.3)
                  : AppTheme.lightBorderColor,
            ),
            boxShadow: isDarkMode
                ? null
                : [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.1),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCardType,
              isExpanded: true,
              icon: Icon(
                Icons.arrow_drop_down,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.7)
                    : AppTheme.lightTextSecondaryColor,
              ),
              dropdownColor: isDarkMode
                  ? const Color(0xFF2D2D3C)
                  : AppTheme.lightCardColor,
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 14 : 12,
                color:
                    isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
              ),
              items: _cardTypes.map((cardType) {
                return DropdownMenuItem<String>(
                  value: cardType['name'],
                  child: Row(
                    children: [
                      Icon(
                        cardType['icon'],
                        color: isDarkMode
                            ? Colors.white
                            : AppTheme.lightTextPrimaryColor,
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Text(cardType['name']),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedCardType = value;
                  });
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isTablet,
    required bool isDarkMode,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
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
          validator: validator,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
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
                  : AppTheme.lightTextSecondaryColor.withValues(alpha: 0.7),
              fontSize: isTablet ? 14 : 12,
            ),
            filled: true,
            fillColor: isDarkMode
                ? Colors.white.withValues(alpha: 0.1)
                : AppTheme.lightCardColor,
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
            counterText: maxLength != null
                ? ''
                : null, // Hide counter for fields with maxLength
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
              : AppTheme.lightCardColor.withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: isDarkMode
              ? null
              : [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.2),
                    spreadRadius: 1,
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
        ),
        child: SafeArea(
          child: GestureDetector(
            onTap: _isProcessing ? null : _onContinue,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                vertical: isTablet ? 18 : 16,
              ),
              decoration: BoxDecoration(
                color: _isProcessing
                    ? Colors.grey.withValues(alpha: 0.5)
                    : (isDarkMode
                        ? AppColors.yellowAccent
                        : AppTheme.lightPrimaryColor),
                borderRadius: BorderRadius.circular(25),
                boxShadow: _isProcessing
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
                  if (_isProcessing)
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
                      'Continue to Payment',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 16 : 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward,
                      color: Colors.white,
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
