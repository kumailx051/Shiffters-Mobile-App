import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;

class StripeService {
  static const String _publishableKey =
      String.fromEnvironment('STRIPE_PUBLISHABLE_KEY');
  static const String _secretKey = String.fromEnvironment('STRIPE_SECRET_KEY');

  static Future<void> init() async {
    try {
      if (_publishableKey.isEmpty) {
        throw Exception(
            'Missing STRIPE_PUBLISHABLE_KEY. Pass it using --dart-define.');
      }
      Stripe.publishableKey = _publishableKey;
      await Stripe.instance.applySettings();
      debugPrint('✅ Stripe initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing Stripe: $e');
      rethrow;
    }
  }

  // Create payment intent on Stripe servers
  static Future<Map<String, dynamic>> createPaymentIntent({
    required double amount, // Amount in dollars
    required String currency,
    required String description,
  }) async {
    try {
      if (_secretKey.isEmpty) {
        return {
          'success': false,
          'error':
              'Missing STRIPE_SECRET_KEY. Configure backend payment intents or pass --dart-define for test mode.',
        };
      }

      // Convert amount to cents (Stripe uses smallest currency unit)
      int amountInCents = (amount * 100).round();

      Map<String, dynamic> body = {
        'amount': amountInCents.toString(),
        'currency': currency,
        'description': description,
        'automatic_payment_methods[enabled]': 'true',
      };

      var response = await http.post(
        Uri.parse('https://api.stripe.com/v1/payment_intents'),
        headers: {
          'Authorization': 'Bearer $_secretKey',
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: body,
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> paymentIntent = json.decode(response.body);
        debugPrint('✅ Payment Intent created: ${paymentIntent['id']}');
        return {
          'success': true,
          'paymentIntent': paymentIntent,
          'clientSecret': paymentIntent['client_secret'],
        };
      } else {
        debugPrint('❌ Error creating payment intent: ${response.body}');
        return {
          'success': false,
          'error': 'Failed to create payment intent: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('❌ Exception creating payment intent: $e');
      return {
        'success': false,
        'error': 'Exception occurred: $e',
      };
    }
  }

  // Complete payment flow using payment sheet
  static Future<Map<String, dynamic>> makePayment({
    required double amount,
    required String currency,
    required String description,
    required String cardNumber,
    required String expiryMonth,
    required String expiryYear,
    required String cvc,
    required String cardHolderName,
  }) async {
    try {
      // Step 1: Create payment intent
      debugPrint(
          '🔄 Creating payment intent for amount: \$${amount.toStringAsFixed(2)}');
      Map<String, dynamic> paymentIntentResult = await createPaymentIntent(
        amount: amount,
        currency: currency,
        description: description,
      );

      if (!paymentIntentResult['success']) {
        return paymentIntentResult;
      }

      String clientSecret = paymentIntentResult['clientSecret'];

      // Step 2: Initialize Payment Sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Shiffters',
        ),
      );

      // Step 3: Present Payment Sheet
      await Stripe.instance.presentPaymentSheet();

      debugPrint('✅ Payment completed successfully');
      return {
        'success': true,
        'message': 'Payment completed successfully',
        'paymentIntentId': paymentIntentResult['paymentIntent']['id'],
      };
    } on StripeException catch (e) {
      debugPrint('❌ Stripe payment error: ${e.error.localizedMessage}');
      String errorMessage = e.error.localizedMessage ?? 'Payment failed';

      // Handle common error cases
      if (errorMessage.toLowerCase().contains('cancel')) {
        errorMessage = 'Payment was cancelled.';
      } else if (errorMessage.toLowerCase().contains('fail')) {
        errorMessage = 'Payment failed. Please try again.';
      }

      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      debugPrint('❌ Payment processing error: $e');
      return {
        'success': false,
        'error': 'An unexpected error occurred during payment processing',
      };
    }
  }

  // Alternative method for manual card entry (without payment sheet)
  static Future<Map<String, dynamic>> makePaymentWithCard({
    required double amount,
    required String currency,
    required String description,
    required String cardNumber,
    required String expiryMonth,
    required String expiryYear,
    required String cvc,
    required String cardHolderName,
  }) async {
    try {
      // Step 1: Create payment intent
      debugPrint(
          '🔄 Creating payment intent for amount: \$${amount.toStringAsFixed(2)}');
      Map<String, dynamic> paymentIntentResult = await createPaymentIntent(
        amount: amount,
        currency: currency,
        description: description,
      );

      if (!paymentIntentResult['success']) {
        return paymentIntentResult;
      }

      String clientSecret = paymentIntentResult['clientSecret'];

      // Step 2: Confirm payment with card details
      debugPrint('🔄 Confirming payment with card details');
      await Stripe.instance.confirmPayment(
        paymentIntentClientSecret: clientSecret,
        data: PaymentMethodParams.card(
          paymentMethodData: PaymentMethodData(
            billingDetails: BillingDetails(
              name: cardHolderName,
            ),
          ),
        ),
      );

      debugPrint('✅ Payment completed successfully');
      return {
        'success': true,
        'message': 'Payment completed successfully',
        'paymentIntentId': paymentIntentResult['paymentIntent']['id'],
      };
    } on StripeException catch (e) {
      debugPrint('❌ Stripe payment error: ${e.error.localizedMessage}');
      String errorMessage = e.error.localizedMessage ?? 'Payment failed';

      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      debugPrint('❌ Payment processing error: $e');
      return {
        'success': false,
        'error': 'An unexpected error occurred during payment processing',
      };
    }
  }

  // Validate card details
  static Map<String, dynamic> validateCardDetails({
    required String cardNumber,
    required String expiryDate,
    required String cvc,
    required String cardHolderName,
  }) {
    List<String> errors = [];

    // Validate card number
    String cleanCardNumber = cardNumber.replaceAll(' ', '');
    if (cleanCardNumber.isEmpty) {
      errors.add('Card number is required');
    } else if (cleanCardNumber.length < 13 || cleanCardNumber.length > 19) {
      errors.add('Card number must be between 13 and 19 digits');
    } else if (!RegExp(r'^[0-9]+$').hasMatch(cleanCardNumber)) {
      errors.add('Card number must contain only digits');
    }

    // Validate expiry date
    if (expiryDate.isEmpty) {
      errors.add('Expiry date is required');
    } else if (!RegExp(r'^(0[1-9]|1[0-2])\/([0-9]{2})$').hasMatch(expiryDate)) {
      errors.add('Expiry date must be in MM/YY format');
    } else {
      List<String> parts = expiryDate.split('/');
      int month = int.parse(parts[0]);
      int year = 2000 + int.parse(parts[1]);
      DateTime now = DateTime.now();
      DateTime cardExpiry = DateTime(year, month);

      if (cardExpiry.isBefore(DateTime(now.year, now.month))) {
        errors.add('Card has expired');
      }
    }

    // Validate CVC
    if (cvc.isEmpty) {
      errors.add('CVC is required');
    } else if (cvc.length < 3 || cvc.length > 4) {
      errors.add('CVC must be 3 or 4 digits');
    } else if (!RegExp(r'^[0-9]+$').hasMatch(cvc)) {
      errors.add('CVC must contain only digits');
    }

    // Validate card holder name
    if (cardHolderName.trim().isEmpty) {
      errors.add('Card holder name is required');
    } else if (cardHolderName.trim().length < 2) {
      errors.add('Card holder name must be at least 2 characters');
    }

    return {
      'isValid': errors.isEmpty,
      'errors': errors,
    };
  }

  // Format card number with spaces
  static String formatCardNumber(String cardNumber) {
    String cleanNumber = cardNumber.replaceAll(' ', '');
    String formatted = '';

    for (int i = 0; i < cleanNumber.length; i++) {
      if (i > 0 && i % 4 == 0) {
        formatted += ' ';
      }
      formatted += cleanNumber[i];
    }

    return formatted;
  }

  // Get card type from card number
  static String getCardType(String cardNumber) {
    String cleanNumber = cardNumber.replaceAll(' ', '');

    if (cleanNumber.startsWith('4')) {
      return 'Visa';
    } else if (cleanNumber.startsWith(RegExp(r'^5[1-5]')) ||
        cleanNumber.startsWith(RegExp(r'^2[2-7]'))) {
      return 'MasterCard';
    } else if (cleanNumber.startsWith('34') || cleanNumber.startsWith('37')) {
      return 'American Express';
    } else {
      return 'Unknown';
    }
  }
}
