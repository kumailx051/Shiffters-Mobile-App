import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shiffters/services/biometric_auth_service.dart';
import 'package:shiffters/screens/biometric_lock_screen.dart';

class BiometricWrapper extends StatefulWidget {
  final Widget child;

  const BiometricWrapper({
    super.key,
    required this.child,
  });

  @override
  State<BiometricWrapper> createState() => _BiometricWrapperState();
}

class _BiometricWrapperState extends State<BiometricWrapper>
    with WidgetsBindingObserver {
  final BiometricAuthService _biometricService = BiometricAuthService();
  bool _showBiometricLock = false;
  bool _isCheckingBiometric = true;
  DateTime? _lastPausedTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkBiometricRequirement();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // App is going to background or being closed
        _lastPausedTime = DateTime.now();
        break;

      case AppLifecycleState.resumed:
        // App is coming back to foreground
        if (_lastPausedTime != null) {
          final timeDifference = DateTime.now().difference(_lastPausedTime!);

          // If app was in background for more than 30 seconds, check biometric
          if (timeDifference.inSeconds > 30) {
            _checkBiometricRequirement();
          }
        }
        break;

      case AppLifecycleState.inactive:
        // App is temporarily inactive (e.g., incoming call)
        // Don't trigger biometric for temporary inactivity
        break;

      case AppLifecycleState.hidden:
        // App is hidden (Android only)
        break;
    }
  }

  Future<void> _checkBiometricRequirement() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isCheckingBiometric = false;
          _showBiometricLock = false;
        });
        return;
      }

      final isAvailable = await _biometricService.isBiometricAvailable();
      if (!isAvailable) {
        setState(() {
          _isCheckingBiometric = false;
          _showBiometricLock = false;
        });
        return;
      }

      final isEnabled = await _biometricService.isBiometricEnabled();
      if (!isEnabled) {
        setState(() {
          _isCheckingBiometric = false;
          _showBiometricLock = false;
        });
        return;
      }

      final shouldPrompt = await _biometricService.shouldShowBiometricPrompt();
      setState(() {
        _isCheckingBiometric = false;
        _showBiometricLock = shouldPrompt;
      });
    } catch (e) {
      debugPrint('Error checking biometric requirement: $e');
      setState(() {
        _isCheckingBiometric = false;
        _showBiometricLock = false;
      });
    }
  }

  void _onBiometricAuthenticated() {
    setState(() {
      _showBiometricLock = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingBiometric) {
      // Show loading while checking biometric requirement
      return Scaffold(
        backgroundColor: const Color(0xFF1E1E2C),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).primaryColor,
            ),
          ),
        ),
      );
    }

    if (_showBiometricLock) {
      return BiometricLockScreen(
        onAuthenticated: _onBiometricAuthenticated,
      );
    }

    return widget.child;
  }
}
