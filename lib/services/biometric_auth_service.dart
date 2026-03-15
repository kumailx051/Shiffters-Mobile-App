import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BiometricAuthService {
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _lastBiometricPromptKey = 'last_biometric_prompt';

  final LocalAuthentication _localAuth = LocalAuthentication();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Check if biometric authentication is available on the device
  Future<bool> isBiometricAvailable() async {
    try {
      final bool isAvailable = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();
      return isAvailable && isDeviceSupported;
    } catch (e) {
      debugPrint('Error checking biometric availability: $e');
      return false;
    }
  }

  // Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('Error getting available biometrics: $e');
      return [];
    }
  }

  // Check if biometric authentication is enabled for current user
  Future<bool> isBiometricEnabled() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Check Firebase first
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final preferences =
            userData['preferences'] as Map<String, dynamic>? ?? {};
        return preferences['biometricEnabled'] as bool? ?? false;
      }

      // Fallback to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('${_biometricEnabledKey}_${user.uid}') ?? false;
    } catch (e) {
      debugPrint('Error checking biometric enabled status: $e');
      return false;
    }
  }

  // Enable biometric authentication
  Future<bool> enableBiometric() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('No authenticated user found');
        return false;
      }

      // Check if biometrics are available and enrolled
      final bool isAvailable = await isBiometricAvailable();
      if (!isAvailable) {
        debugPrint('Biometric authentication is not available');
        return false;
      }

      final availableBiometrics = await getAvailableBiometrics();
      if (availableBiometrics.isEmpty) {
        debugPrint('No biometric credentials are enrolled');
        return false;
      }

      // First, test if biometric authentication works
      final bool didAuthenticate = await _authenticateWithBiometric(
        reason: 'Please verify your identity to enable biometric login',
      );

      if (didAuthenticate) {
        // Save to Firebase
        await _firestore.collection('users').doc(user.uid).update({
          'preferences.biometricEnabled': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Save to SharedPreferences as backup
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('${_biometricEnabledKey}_${user.uid}', true);

        debugPrint('Biometric authentication enabled successfully');
        return true;
      } else {
        debugPrint('Biometric authentication failed during setup');
        return false;
      }
    } catch (e) {
      debugPrint('Error enabling biometric: $e');
      rethrow; // Rethrow to let the caller handle specific errors
    }
  }

  // Disable biometric authentication
  Future<bool> disableBiometric() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Save to Firebase
      await _firestore.collection('users').doc(user.uid).update({
        'preferences.biometricEnabled': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Save to SharedPreferences as backup
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('${_biometricEnabledKey}_${user.uid}', false);

      return true;
    } catch (e) {
      debugPrint('Error disabling biometric: $e');
      return false;
    }
  }

  // Authenticate with biometric
  Future<bool> _authenticateWithBiometric({required String reason}) async {
    try {
      // Check if biometric is available first
      final bool isAvailable = await isBiometricAvailable();
      if (!isAvailable) {
        throw PlatformException(
          code: 'BiometricStatus.notAvailable',
          message: 'Biometric authentication is not available on this device',
        );
      }

      // Check if biometrics are enrolled
      final availableBiometrics = await getAvailableBiometrics();
      if (availableBiometrics.isEmpty) {
        throw PlatformException(
          code: 'BiometricStatus.notEnrolled',
          message: 'No biometric credentials are enrolled',
        );
      }

      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true, // Only use biometric, not device passcode
        ),
      );

      return didAuthenticate;
    } on PlatformException catch (e) {
      debugPrint('Biometric authentication error: ${e.code} - ${e.message}');

      // Handle specific error cases and rethrow with more context
      switch (e.code) {
        case 'BiometricStatus.notAvailable':
          throw PlatformException(
            code: e.code,
            message: 'Biometric authentication not available',
          );
        case 'BiometricStatus.notEnrolled':
          throw PlatformException(
            code: e.code,
            message: 'No biometric credentials enrolled',
          );
        case 'UserCancel':
          throw PlatformException(
            code: e.code,
            message: 'User cancelled biometric authentication',
          );
        case 'PermanentlyLockedOut':
          throw PlatformException(
            code: e.code,
            message: 'Biometric authentication permanently locked',
          );
        case 'LockedOut':
          throw PlatformException(
            code: e.code,
            message: 'Too many failed attempts',
          );
        default:
          rethrow;
      }
    } catch (e) {
      debugPrint('Unexpected biometric authentication error: $e');
      rethrow;
    }
  }

  // Check if we should show biometric prompt on app launch
  Future<bool> shouldShowBiometricPrompt() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final bool isEnabled = await isBiometricEnabled();
      if (!isEnabled) return false;

      final prefs = await SharedPreferences.getInstance();
      final lastPrompt =
          prefs.getInt('${_lastBiometricPromptKey}_${user.uid}') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      // Show prompt if more than 5 minutes have passed since last successful authentication
      const fiveMinutesInMs = 5 * 60 * 1000;
      return (now - lastPrompt) > fiveMinutesInMs;
    } catch (e) {
      debugPrint('Error checking if should show biometric prompt: $e');
      return false;
    }
  }

  // Authenticate user on app launch
  Future<bool> authenticateOnAppLaunch() async {
    try {
      final bool shouldPrompt = await shouldShowBiometricPrompt();
      if (!shouldPrompt) return true; // Already authenticated recently

      final bool didAuthenticate = await _authenticateWithBiometric(
        reason: 'Please verify your identity to access the app',
      );

      if (didAuthenticate) {
        // Update last successful authentication time
        final user = _auth.currentUser;
        if (user != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt(
            '${_lastBiometricPromptKey}_${user.uid}',
            DateTime.now().millisecondsSinceEpoch,
          );
        }
      }

      return didAuthenticate;
    } catch (e) {
      debugPrint('Error authenticating on app launch: $e');
      return false;
    }
  }

  // Clear biometric authentication cache (useful on logout)
  Future<void> clearBiometricCache() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('${_lastBiometricPromptKey}_${user.uid}');
        await prefs.remove('${_biometricEnabledKey}_${user.uid}');
      }
    } catch (e) {
      debugPrint('Error clearing biometric cache: $e');
    }
  }

  // Get biometric type name for display
  String getBiometricTypeName(List<BiometricType> types) {
    if (types.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (types.contains(BiometricType.fingerprint)) {
      return 'Fingerprint';
    } else if (types.contains(BiometricType.iris)) {
      return 'Iris';
    } else if (types.contains(BiometricType.strong)) {
      return 'Biometric';
    } else if (types.contains(BiometricType.weak)) {
      return 'Biometric';
    }
    return 'Biometric';
  }
}
