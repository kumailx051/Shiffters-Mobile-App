import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class EmailService {
  // Use the ngrok tunnel endpoint for the OTP server
  static const String _baseUrl =
      'https://trickily-photoactinic-alita.ngrok-free.dev';

  /// Send order confirmation email to user
  static Future<Map<String, dynamic>> sendOrderConfirmationEmail({
    required String userEmail,
    required String userName,
    required Map<String, dynamic> orderData,
  }) async {
    try {
      debugPrint('📧 Sending order confirmation email to: $userEmail');

      // Prepare email data
      final emailData = {
        'email': userEmail,
        'name': userName,
        'orderData': orderData,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/send-order-confirmation'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode(emailData),
      );

      debugPrint('📧 Email API response status: ${response.statusCode}');
      debugPrint('📧 Email API response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          debugPrint('✅ Order confirmation email sent successfully');
          return {
            'success': true,
            'message': 'Order confirmation email sent successfully',
          };
        } else {
          debugPrint(
              '❌ Email API returned success=false: ${responseData['error']}');
          return {
            'success': false,
            'error': responseData['error'] ?? 'Unknown email API error',
          };
        }
      } else {
        debugPrint('❌ Email API returned status ${response.statusCode}');
        return {
          'success': false,
          'error': 'Failed to send email (Status: ${response.statusCode})',
        };
      }
    } catch (e) {
      debugPrint('❌ Exception sending order confirmation email: $e');
      return {
        'success': false,
        'error': 'Failed to send email: $e',
      };
    }
  }

  /// Test email server connectivity
  static Future<Map<String, dynamic>> testEmailServer() async {
    try {
      debugPrint('🔍 Testing email server connectivity...');

      final response = await http.get(
        Uri.parse('$_baseUrl/health'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 10));

      debugPrint('🔍 Health check response status: ${response.statusCode}');
      debugPrint('🔍 Health check response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return {
          'success': true,
          'message': responseData['message'] ?? 'Email server is healthy',
        };
      } else {
        return {
          'success': false,
          'error': 'Email server returned status ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('❌ Email server connectivity test failed: $e');
      return {
        'success': false,
        'error': 'Email server is not reachable: $e',
      };
    }
  }

  /// Send item verification email to user
  static Future<Map<String, dynamic>> sendItemVerificationEmail({
    required String userEmail,
    required String userName,
    required Map<String, dynamic> verificationData,
  }) async {
    try {
      debugPrint('📧 Sending item verification email to: $userEmail');

      // Prepare email data
      final emailData = {
        'email': userEmail,
        'name': userName,
        'verificationData': verificationData,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/send-item-verification'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode(emailData),
      );

      debugPrint(
          '📧 Verification email API response status: ${response.statusCode}');
      debugPrint('📧 Verification email API response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          debugPrint('✅ Item verification email sent successfully');
          return {
            'success': true,
            'message': 'Item verification email sent successfully',
          };
        } else {
          debugPrint(
              '❌ Verification email API returned success=false: ${responseData['error']}');
          return {
            'success': false,
            'error':
                responseData['error'] ?? 'Unknown verification email API error',
          };
        }
      } else {
        debugPrint(
            '❌ Verification email API returned status ${response.statusCode}');
        return {
          'success': false,
          'error':
              'Failed to send verification email (Status: ${response.statusCode})',
        };
      }
    } catch (e) {
      debugPrint('❌ Exception sending item verification email: $e');
      return {
        'success': false,
        'error': 'Failed to send verification email: $e',
      };
    }
  }
}
