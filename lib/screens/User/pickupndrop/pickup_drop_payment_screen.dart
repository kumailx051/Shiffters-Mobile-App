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
import 'pickup_drop_confirmation_screen.dart';

class PickupDropPaymentScreen extends StatefulWidget {
  final Map<String, dynamic> packageData;

  const PickupDropPaymentScreen({
    super.key,
    required this.packageData,
  });

  @override
  State<PickupDropPaymentScreen> createState() =>
      _PickupDropPaymentScreenState();
}

class _PickupDropPaymentScreenState extends State<PickupDropPaymentScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String _selectedPaymentMethod = 'Cash on Pickup';
  String _selectedCardType = 'Visa';
  bool _isLoading = false;
  bool _hasSavedCard = false;
  bool _useSavedCard = false;
  Map<String, dynamic>? _savedCardDetails;

  // Discount related variables
  final TextEditingController _discountCodeController = TextEditingController();
  bool _isApplyingDiscount = false;
  bool _isDiscountApplied = false;
  Map<String, dynamic>? _appliedDiscount;

  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _cardHolderController = TextEditingController();
  final TextEditingController _expiryDateController = TextEditingController();
  final TextEditingController _cvvController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

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
      begin: const Offset(0, 0.1),
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

  void _onContinue() async {
    if (_isLoading) return;

    if (_isCardPayment()) {
      if (!_useSavedCard && !_formKey.currentState!.validate()) {
        _showErrorMessage('Please fill all required card details');
      } else {
        await _processPayment();
      }
    } else {
      await _processPayment();
    }
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.albertSans(
                    color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processPayment() async {
    if (mounted) setState(() => _isLoading = true);

    HapticFeedback.lightImpact();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showErrorMessage('User not authenticated. Please login first.');
        return;
      }

      Map<String, dynamic> paymentResult = {'success': true};
      String? transactionId;

      // Get payment amount
      double amount = 0.0;
      try {
        amount = (widget.packageData['price'] as num?)?.toDouble() ?? 0.0;

        // Apply discount if applicable
        if (_isDiscountApplied && _appliedDiscount != null) {
          final discountType = _appliedDiscount!['discountType'];
          final discountValue =
              (_appliedDiscount!['discountValue'] as num).toDouble();

          double discountAmount = 0.0;
          if (discountType == 'percentage') {
            // Apply percentage discount
            discountAmount = amount * (discountValue / 100);
          } else if (discountType == 'fixed') {
            // Apply fixed amount discount
            discountAmount = discountValue;
          }

          // Ensure discount doesn't exceed the total amount
          discountAmount = discountAmount > amount ? amount : discountAmount;

          // Apply discount to total amount
          amount = amount - discountAmount;
        }
      } catch (e) {
        debugPrint('Error getting payment amount: $e');
        _showErrorMessage('Invalid payment amount');
        return;
      }

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
          // Validate card details
          final validation = StripeService.validateCardDetails(
            cardNumber: _cardNumberController.text,
            expiryDate: _expiryDateController.text,
            cvc: _cvvController.text,
            cardHolderName: _cardHolderController.text,
          );

          if (!validation['isValid']) {
            final errors = validation['errors'] as List<String>;
            _showErrorMessage(errors.first);
            return;
          }

          // Extract expiry month and year
          final expiryParts = _expiryDateController.text.split('/');
          final expiryMonth = expiryParts[0];
          final expiryYear = '20${expiryParts[1]}'; // Convert YY to YYYY

          // Process Stripe payment
          debugPrint(
              '🔄 Processing Stripe payment for amount: \$${amount.toStringAsFixed(2)}');

          paymentResult = await StripeService.makePaymentWithCard(
            amount: amount,
            currency: 'usd',
            description: 'Shiffters Pickup & Drop Service',
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
            _showErrorMessage(paymentResult['error'] ?? 'Payment failed');
            return;
          }
        }
      }

      // Prepare data for Firebase
      final orderData = _prepareOrderData(user.uid, transactionId);

      // Save to Firebase
      DocumentReference orderRef =
          await FirebaseFirestore.instance.collection('orders').add(orderData);

      // Add orderId to the data
      await orderRef.update({'orderId': orderRef.id});

      // Prepare complete data for confirmation screen
      Map<String, dynamic> completePackageData = {
        ...widget.packageData,
        'orderId': orderRef.id,
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
          'timestamp': DateTime.now().toString(),
          'status': paymentResult['success'] ? 'Completed' : 'Failed',
          'transactionId':
              transactionId ?? 'TXN${DateTime.now().millisecondsSinceEpoch}',
          'stripePaymentIntentId': transactionId,
        },
      };

      _showSuccessMessage(paymentResult['success']
          ? 'Payment successful! Order placed.'
          : 'Order placed successfully!');

      // Navigate to confirmation screen
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                PickupDropConfirmationScreen(packageData: completePackageData),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error processing payment: $e');
      _showErrorMessage('Failed to place order. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _prepareOrderData(String uid, String? transactionId) {
    // Extract package details
    final packageDetails =
        widget.packageData['packageDetails'] as Map<String, dynamic>? ?? {};
    final contactDetails =
        widget.packageData['contactDetails'] as Map<String, dynamic>? ?? {};
    final pickup = widget.packageData['pickup'] as Map<String, dynamic>? ?? {};
    final dropoff =
        widget.packageData['dropoff'] as Map<String, dynamic>? ?? {};

    Map<String, dynamic> orderData = {
      'uid': uid,
      'orderType': 'pickndrop',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'status': 'active',

      // Location data
      'pickupLocation': {
        'address': pickup['address'] ?? '',
        'latitude': pickup['location']?.latitude ?? 0.0,
        'longitude': pickup['location']?.longitude ?? 0.0,
      },
      'dropoffLocation': {
        'address': dropoff['address'] ?? '',
        'latitude': dropoff['location']?.latitude ?? 0.0,
        'longitude': dropoff['location']?.longitude ?? 0.0,
      },

      // Package information
      'packageInformation': {
        'packageName': packageDetails['name'] ?? '',
        'description': packageDetails['description'] ?? '',
        'packageType': packageDetails['type'] ?? '',
        'weight': packageDetails['weight'] ?? '',
        'fragile': packageDetails['isFragile'] ?? false,
      },

      // Contact information
      'contactInformation': {
        'senderName': contactDetails['sender']?['name'] ?? '',
        'senderPhone': contactDetails['sender']?['phone'] ?? '',
        'receiverName': contactDetails['receiver']?['name'] ?? '',
        'receiverPhone': contactDetails['receiver']?['phone'] ?? '',
      },

      // Service details
      'vehicleType': widget.packageData['vehicleType'] ?? 'Bike',
      'totalAmount': widget.packageData['price'] ?? 0.0,
      'paymentMethod': _selectedPaymentMethod,
      'paymentStatus': _isCardPayment()
          ? (transactionId != null ? 'completed' : 'failed')
          : 'pending',
      'distance': widget.packageData['distance'] ?? 0.0,

      // Payment processing details
      'paymentDetails': {
        'method': _selectedPaymentMethod,
        'cardType': _isCardPayment() ? _selectedCardType : null,
        'transactionId': transactionId,
        'stripePaymentIntentId': transactionId,
        'processedAt': _isCardPayment() ? FieldValue.serverTimestamp() : null,
        'amount': widget.packageData['price'] ?? 0.0,
        'currency': 'usd',
      },
    };

    // Add discount information if applied
    if (_isDiscountApplied && _appliedDiscount != null) {
      final discountType = _appliedDiscount!['discountType'];
      final discountValue =
          (_appliedDiscount!['discountValue'] as num).toDouble();

      // Calculate original amount and discount amount
      double originalAmount =
          (widget.packageData['price'] as num?)?.toDouble() ?? 0.0;
      double discountAmount = 0.0;

      if (discountType == 'percentage') {
        discountAmount = originalAmount * (discountValue / 100);
      } else {
        discountAmount = discountValue;
      }

      // Ensure discount doesn't exceed the total amount
      discountAmount =
          discountAmount > originalAmount ? originalAmount : discountAmount;

      orderData['discount'] = {
        'discountCode': _appliedDiscount!['code'],
        'discountType': discountType,
        'discountValue': discountValue,
        'discountAmount': discountAmount,
        'originalAmount': originalAmount,
        'finalAmount': originalAmount - discountAmount,
      };
    }

    // Add card details if card payment
    if (_isCardPayment()) {
      if (_useSavedCard && _savedCardDetails != null) {
        // Use saved card details
        orderData['cardDetails'] = _savedCardDetails;
        orderData['usedSavedCard'] = true;
      } else {
        // Use entered card details
        orderData['cardDetails'] = {
          'cardType': _selectedCardType,
          'cardLastFour':
              _cardNumberController.text.replaceAll(' ', '').length >= 4
                  ? _cardNumberController.text.replaceAll(' ', '').substring(
                      _cardNumberController.text.replaceAll(' ', '').length - 4)
                  : '',
          'cardHolderName': _cardHolderController.text.trim(),
        };
      }
    }

    return orderData;
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

      // User has save payment enabled, add new card to saved cards
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'savedCards': FieldValue.arrayUnion([cardDetails]),
      });

      debugPrint('✅ Card details saved successfully');
    } catch (e) {
      debugPrint('❌ Error saving card details: $e');
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline,
                color: Colors.white, size: 20),
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

  // Method to validate and apply discount code
  Future<void> _validateAndApplyDiscountCode() async {
    final discountCode = _discountCodeController.text.trim().toUpperCase();
    if (discountCode.isEmpty) {
      _showErrorMessage('Please enter a discount code');
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
        _showErrorMessage('Invalid discount code');
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
        _showErrorMessage('This discount code has expired');
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

      _showSuccessMessage('Discount applied: $discountText');
    } catch (e) {
      setState(() {
        _isApplyingDiscount = false;
      });
      _showErrorMessage('Error applying discount: $e');
    }
  }

  // Method to remove applied discount
  void _removeDiscount() {
    setState(() {
      _isDiscountApplied = false;
      _appliedDiscount = null;
      _discountCodeController.clear();
    });
    _showSuccessMessage('Discount removed');
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        final isDarkMode = themeService.isDarkMode;

        return Scaffold(
          backgroundColor:
              isDarkMode ? const Color(0xFF1E1E2C) : Colors.grey[50],
          appBar: AppBar(
            backgroundColor:
                isDarkMode ? const Color(0xFF1E1E2C) : Colors.white,
            elevation: 2,
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(
                Icons.arrow_back,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            title: Text(
              'Payment',
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 20 : 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            centerTitle: true,
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Content
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Padding(
                        padding: EdgeInsets.all(isTablet ? 24 : 16),
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
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
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: _buildBottomBar(isTablet, isDarkMode),
        );
      },
    );
  }

  Widget _buildOrderSummary(bool isTablet, bool isDarkMode) {
    // Safely extract data
    String vehicleType = 'Unknown';
    String timeSlot = 'Unknown';

    try {
      vehicleType = widget.packageData['vehicleType']?.toString() ?? 'Unknown';
      timeSlot = widget.packageData['timeSlot']?.toString() ?? 'Unknown';
    } catch (e) {
      debugPrint('Error extracting package data: $e');
    }

    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: isDarkMode
            ? null
            : Border.all(
                color: AppTheme.lightPrimaryColor,
                width: 1,
              ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Summary',
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 18 : 16,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),

          const SizedBox(height: 16),

          // Package Details
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? AppColors.yellowAccent.withValues(alpha: 0.2)
                      : AppTheme.lightPrimaryColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.local_shipping,
                  color: isDarkMode
                      ? AppColors.yellowAccent
                      : AppTheme.lightPrimaryColor,
                  size: isTablet ? 20 : 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pickup & Drop Service',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 14 : 12,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Vehicle: $vehicleType • Time: $timeSlot',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 12 : 10,
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          Divider(color: isDarkMode ? Colors.white24 : Colors.grey.shade300),
          const SizedBox(height: 16),

          // Discount Code Input
          Container(
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.grey.withValues(alpha: 0.2),
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
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _discountCodeController,
                          enabled: !_isDiscountApplied && !_isApplyingDiscount,
                          style: GoogleFonts.albertSans(
                            color: isDarkMode ? Colors.white : Colors.black,
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
                                ? AppColors.yellowAccent.withValues(alpha: 0.5)
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
                            : AppTheme.lightPrimaryColor.withValues(alpha: 0.1),
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

          // Price breakdown
          Builder(builder: (context) {
            double originalPrice =
                (widget.packageData['price'] as num?)?.toDouble() ?? 0.0;
            double finalPrice = originalPrice;
            double discountAmount = 0.0;

            // Calculate discount if applied
            if (_isDiscountApplied && _appliedDiscount != null) {
              final discountType = _appliedDiscount!['discountType'];
              final discountValue =
                  (_appliedDiscount!['discountValue'] as num).toDouble();

              if (discountType == 'percentage') {
                discountAmount = originalPrice * (discountValue / 100);
              } else {
                discountAmount = discountValue;
              }

              // Ensure discount doesn't exceed the total amount
              discountAmount = discountAmount > originalPrice
                  ? originalPrice
                  : discountAmount;
              finalPrice = originalPrice - discountAmount;
            }

            // If discount is applied, show subtotal, discount and final price
            if (_isDiscountApplied && discountAmount > 0) {
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
                              : Colors.black54,
                        ),
                      ),
                      Text(
                        'Rs. ${originalPrice.toStringAsFixed(0)}',
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 14 : 12,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black,
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
                  const SizedBox(height: 12),
                  Divider(
                      color:
                          isDarkMode ? Colors.white24 : Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Amount',
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 16 : 14,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? AppColors.yellowAccent
                              : AppTheme.lightPrimaryColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Rs. ${finalPrice.toStringAsFixed(0)}',
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 16 : 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            } else {
              // Original price row without discount
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Amount',
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 16 : 14,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
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
                      'Rs. ${originalPrice.toStringAsFixed(0)}',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 16 : 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              );
            }
          }),
        ],
      ),
    );
  }

  Widget _buildPaymentMethod(bool isTablet, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Method',
          style: GoogleFonts.albertSans(
            fontSize: isTablet ? 18 : 16,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),

        const SizedBox(height: 16),

        // Payment Method Options
        ...List.generate(_paymentMethods.length, (index) {
          final method = _paymentMethods[index];
          final methodName = method['name'] as String;
          final icon = method['icon'] as IconData;
          final isSelected = _selectedPaymentMethod == methodName;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedPaymentMethod = methodName;
              });
              HapticFeedback.lightImpact();
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: EdgeInsets.all(isTablet ? 16 : 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDarkMode
                        ? AppColors.yellowAccent.withValues(alpha: 0.1)
                        : AppTheme.lightPrimaryColor.withValues(alpha: 0.1))
                    : (isDarkMode
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.white.withValues(alpha: 0.7)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? (isDarkMode
                          ? AppColors.yellowAccent
                          : AppTheme.lightPrimaryColor)
                      : (isDarkMode
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.grey.withValues(alpha: 0.3)),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDarkMode
                              ? AppColors.yellowAccent.withValues(alpha: 0.2)
                              : AppTheme.lightPrimaryColor
                                  .withValues(alpha: 0.2))
                          : (isDarkMode
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.grey.withValues(alpha: 0.1)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      color: isSelected
                          ? (isDarkMode
                              ? AppColors.yellowAccent
                              : AppTheme.lightPrimaryColor)
                          : (isDarkMode ? Colors.white : Colors.black),
                      size: isTablet ? 20 : 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    methodName,
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 14 : 12,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  const Spacer(),
                  if (isSelected)
                    Icon(
                      Icons.check_circle,
                      color: isDarkMode
                          ? AppColors.yellowAccent
                          : AppTheme.lightPrimaryColor,
                      size: isTablet ? 20 : 16,
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCardDetails(bool isTablet, bool isDarkMode) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: isDarkMode
            ? null
            : Border.all(
                color: AppTheme.lightPrimaryColor,
                width: 1,
              ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Card Details',
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 18 : 16,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),

          // Saved Card Option
          if (_hasSavedCard) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.credit_card,
                    color: isDarkMode
                        ? AppColors.yellowAccent
                        : AppTheme.lightPrimaryColor,
                    size: isTablet ? 20 : 16,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Use saved card',
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 14 : 12,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        if (_savedCardDetails != null)
                          Text(
                            '${_savedCardDetails!['cardType']} **** ${_savedCardDetails!['cardLastFour']}',
                            style: GoogleFonts.albertSans(
                              fontSize: isTablet ? 12 : 10,
                              color:
                                  isDarkMode ? Colors.white70 : Colors.black54,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _useSavedCard,
                    onChanged: (value) {
                      setState(() {
                        _useSavedCard = value;
                      });
                      HapticFeedback.lightImpact();
                    },
                    activeColor: isDarkMode
                        ? AppColors.yellowAccent
                        : AppTheme.lightPrimaryColor,
                  ),
                ],
              ),
            ),
          ],

          if (!_useSavedCard) ...[
            const SizedBox(height: 20),

            // Card Type
            _buildDropdownField(
              label: 'Card Type',
              value: _selectedCardType,
              items: _cardTypes,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedCardType = value;
                  });
                }
              },
              isTablet: isTablet,
              isDarkMode: isDarkMode,
            ),

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
                    hint: 'XXX', // Default to 3 digits
                    isTablet: isTablet,
                    isDarkMode: isDarkMode,
                    keyboardType: TextInputType.number,
                    maxLength: 3, // Default to 3, will be updated by card type
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3), // Default to 3
                    ],
                    validator: (value) {
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
        ],
      ),
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
            fontWeight: FontWeight.w500,
            color: isDarkMode ? Colors.white70 : Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          style: GoogleFonts.albertSans(
            fontSize: isTablet ? 14 : 12,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.albertSans(
              color: isDarkMode ? Colors.white30 : Colors.black38,
              fontSize: isTablet ? 14 : 12,
            ),
            filled: true,
            fillColor: isDarkMode
                ? Colors.white.withValues(alpha: 0.05)
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
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Colors.red,
                width: 1,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Colors.red,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            counterText: maxLength != null
                ? ''
                : null, // Hide counter for fields with maxLength
          ),
          keyboardType: keyboardType,
          validator: validator,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<Map<String, dynamic>> items,
    required void Function(String?) onChanged,
    required bool isTablet,
    required bool isDarkMode,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.albertSans(
            fontSize: isTablet ? 14 : 12,
            fontWeight: FontWeight.w500,
            color: isDarkMode ? Colors.white70 : Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: Icon(
                Icons.arrow_drop_down,
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
              dropdownColor:
                  isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
              style: GoogleFonts.albertSans(
                fontSize: isTablet ? 14 : 12,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
              items: items.map((item) {
                return DropdownMenuItem<String>(
                  value: item['name'] as String,
                  child: Text(item['name'] as String),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(bool isTablet, bool isDarkMode) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 360;

    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E2C) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _onContinue,
            style: ElevatedButton.styleFrom(
              backgroundColor: isDarkMode
                  ? AppColors.yellowAccent
                  : AppTheme.lightPrimaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
              padding: EdgeInsets.zero,
            ),
            child: Container(
              height: isTablet ? 54 : 50,
              child: Center(
                child: _isLoading
                    ? const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      )
                    : Text(
                        'Pay Now',
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet
                              ? 18
                              : isSmallScreen
                                  ? 14
                                  : 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
