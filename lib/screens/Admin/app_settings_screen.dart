import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shiffters/theme/app_colors.dart';
import 'package:shiffters/theme/app_theme.dart';
import 'package:shiffters/services/theme_service.dart';
import 'dart:async';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late AnimationController _animationController;
  late AnimationController _cardAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _cardScaleAnimation;

  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Settings state
  bool _maintenanceMode = false;
  bool _registrationEnabled = true;
  bool _emailNotifications = true;
  bool _pushNotifications = true;
  bool _smsNotifications = false;
  bool _autoAssignOrders = true;
  bool _locationTracking = true;
  bool _backgroundSync = true;
  bool _crashReporting = true;
  bool _analyticsEnabled = true;
  bool _isLoading = false;
  bool _isSaving = false;

  double _commissionRate = 10.0;
  double _deliveryRadius = 50.0;
  double _maxOrderValue = 100000.0;
  double _minOrderValue = 500.0;

  String _paymentGateway = 'EasyPaisa';
  String _mapProvider = 'Google Maps';
  String _defaultCurrency = 'PKR';
  String _timeZone = 'Asia/Karachi';
  String _apiKey = '';
  String _gatewaySecret = '';

  final List<String> _paymentGateways = [
    'EasyPaisa',
    'JazzCash',
    'Stripe',
    'PayPal'
  ];
  final List<String> _mapProviders = ['Google Maps', 'OpenStreetMap', 'Mapbox'];
  final List<String> _currencies = ['PKR', 'USD', 'EUR', 'GBP'];
  final List<String> _timeZones = [
    'Asia/Karachi',
    'UTC',
    'Asia/Dubai',
    'America/New_York'
  ];

  // Settings subscription for real-time updates
  StreamSubscription<DocumentSnapshot>? _settingsSubscription;

  @override
  void initState() {
    super.initState();

    _initializeAnimations();
    _startAnimations();
    _loadSettings();
    _setupSettingsListener();

    // Set system UI overlay style
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _cardAnimationController = AnimationController(
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

    _cardScaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cardAnimationController,
      curve: Curves.easeOutBack,
    ));
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      _animationController.forward();
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) {
        _cardAnimationController.forward();
      }
    }
  }

  // Load settings from Firebase and SharedPreferences
  Future<void> _loadSettings() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Load from Firebase
      final settingsDoc =
          await _firestore.collection('app_settings').doc('global').get();
      if (settingsDoc.exists) {
        final data = settingsDoc.data() as Map<String, dynamic>;

        if (mounted) {
          setState(() {
            _maintenanceMode = data['maintenanceMode'] ?? false;
            _registrationEnabled = data['registrationEnabled'] ?? true;
            _emailNotifications = data['emailNotifications'] ?? true;
            _pushNotifications = data['pushNotifications'] ?? true;
            _smsNotifications = data['smsNotifications'] ?? false;
            _autoAssignOrders = data['autoAssignOrders'] ?? true;
            _locationTracking = data['locationTracking'] ?? true;
            _backgroundSync = data['backgroundSync'] ?? true;
            _crashReporting = data['crashReporting'] ?? true;
            _analyticsEnabled = data['analyticsEnabled'] ?? true;

            _commissionRate = (data['commissionRate'] ?? 10.0).toDouble();
            _deliveryRadius = (data['deliveryRadius'] ?? 50.0).toDouble();
            _maxOrderValue = (data['maxOrderValue'] ?? 100000.0).toDouble();
            _minOrderValue = (data['minOrderValue'] ?? 500.0).toDouble();

            _paymentGateway = data['paymentGateway'] ?? 'EasyPaisa';
            _mapProvider = data['mapProvider'] ?? 'Google Maps';
            _defaultCurrency = data['defaultCurrency'] ?? 'PKR';
            _timeZone = data['timeZone'] ?? 'Asia/Karachi';
            _apiKey = data['apiKey'] ?? '';
            _gatewaySecret = data['gatewaySecret'] ?? '';
          });
        }
      }

      // Load local preferences
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _backgroundSync = prefs.getBool('backgroundSync') ?? _backgroundSync;
          _crashReporting = prefs.getBool('crashReporting') ?? _crashReporting;
          _analyticsEnabled =
              prefs.getBool('analyticsEnabled') ?? _analyticsEnabled;
        });
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showGlowingSnackBar(
          'Error loading settings: $e',
          AppColors.error,
        );
      }
    }
  }

  // Save settings to Firebase and SharedPreferences
  Future<void> _saveSettings() async {
    try {
      setState(() {
        _isSaving = true;
      });

      // Save to Firebase
      await _firestore.collection('app_settings').doc('global').set({
        'maintenanceMode': _maintenanceMode,
        'registrationEnabled': _registrationEnabled,
        'emailNotifications': _emailNotifications,
        'pushNotifications': _pushNotifications,
        'smsNotifications': _smsNotifications,
        'autoAssignOrders': _autoAssignOrders,
        'locationTracking': _locationTracking,
        'backgroundSync': _backgroundSync,
        'crashReporting': _crashReporting,
        'analyticsEnabled': _analyticsEnabled,
        'commissionRate': _commissionRate,
        'deliveryRadius': _deliveryRadius,
        'maxOrderValue': _maxOrderValue,
        'minOrderValue': _minOrderValue,
        'paymentGateway': _paymentGateway,
        'mapProvider': _mapProvider,
        'defaultCurrency': _defaultCurrency,
        'timeZone': _timeZone,
        'apiKey': _apiKey,
        'gatewaySecret': _gatewaySecret,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': _auth.currentUser?.uid,
      }, SetOptions(merge: true));

      // Save local preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('backgroundSync', _backgroundSync);
      await prefs.setBool('crashReporting', _crashReporting);
      await prefs.setBool('analyticsEnabled', _analyticsEnabled);

      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        _showGlowingSnackBar(
          'Settings saved successfully!',
          AppColors.success,
        );
      }
    } catch (e) {
      debugPrint('Error saving settings: $e');
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        _showGlowingSnackBar(
          'Error saving settings: $e',
          AppColors.error,
        );
      }
    }
  }

  // Auto-save settings (without showing success message)
  Future<void> _autoSaveSettings() async {
    try {
      // Show brief saving indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Auto-saving...',
                  style: GoogleFonts.albertSans(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.grey[800],
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            duration: const Duration(milliseconds: 1500),
          ),
        );
      }

      // Save to Firebase silently
      await _firestore.collection('app_settings').doc('global').set({
        'maintenanceMode': _maintenanceMode,
        'registrationEnabled': _registrationEnabled,
        'emailNotifications': _emailNotifications,
        'pushNotifications': _pushNotifications,
        'smsNotifications': _smsNotifications,
        'autoAssignOrders': _autoAssignOrders,
        'locationTracking': _locationTracking,
        'backgroundSync': _backgroundSync,
        'crashReporting': _crashReporting,
        'analyticsEnabled': _analyticsEnabled,
        'commissionRate': _commissionRate,
        'deliveryRadius': _deliveryRadius,
        'maxOrderValue': _maxOrderValue,
        'minOrderValue': _minOrderValue,
        'paymentGateway': _paymentGateway,
        'mapProvider': _mapProvider,
        'defaultCurrency': _defaultCurrency,
        'timeZone': _timeZone,
        'apiKey': _apiKey,
        'gatewaySecret': _gatewaySecret,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': _auth.currentUser?.uid,
      }, SetOptions(merge: true));

      // Save local preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('backgroundSync', _backgroundSync);
      await prefs.setBool('crashReporting', _crashReporting);
      await prefs.setBool('analyticsEnabled', _analyticsEnabled);

      debugPrint('Settings auto-saved to Firebase');
    } catch (e) {
      debugPrint('Error auto-saving settings: $e');
      if (mounted) {
        _showGlowingSnackBar(
          'Error auto-saving: $e',
          Colors.red,
        );
      }
    }
  }

  // Setup real-time settings listener
  void _setupSettingsListener() {
    _settingsSubscription = _firestore
        .collection('app_settings')
        .doc('global')
        .snapshots()
        .listen((DocumentSnapshot snapshot) {
      if (snapshot.exists && mounted) {
        final data = snapshot.data() as Map<String, dynamic>;

        // Only update if the change was made by another user
        if (data['updatedBy'] != _auth.currentUser?.uid) {
          setState(() {
            _maintenanceMode = data['maintenanceMode'] ?? false;
            _registrationEnabled = data['registrationEnabled'] ?? true;
            _emailNotifications = data['emailNotifications'] ?? true;
            _pushNotifications = data['pushNotifications'] ?? true;
            _smsNotifications = data['smsNotifications'] ?? false;
            _autoAssignOrders = data['autoAssignOrders'] ?? true;
            _locationTracking = data['locationTracking'] ?? true;
            _backgroundSync = data['backgroundSync'] ?? true;
            _crashReporting = data['crashReporting'] ?? true;
            _analyticsEnabled = data['analyticsEnabled'] ?? true;

            _commissionRate = (data['commissionRate'] ?? 10.0).toDouble();
            _deliveryRadius = (data['deliveryRadius'] ?? 50.0).toDouble();
            _maxOrderValue = (data['maxOrderValue'] ?? 100000.0).toDouble();
            _minOrderValue = (data['minOrderValue'] ?? 500.0).toDouble();

            _paymentGateway = data['paymentGateway'] ?? 'EasyPaisa';
            _mapProvider = data['mapProvider'] ?? 'Google Maps';
            _defaultCurrency = data['defaultCurrency'] ?? 'PKR';
            _timeZone = data['timeZone'] ?? 'Asia/Karachi';
            _apiKey = data['apiKey'] ?? '';
            _gatewaySecret = data['gatewaySecret'] ?? '';
          });

          // Show notification that settings were updated by another admin
          _showGlowingSnackBar(
            'Settings updated by another admin',
            Colors.blue,
          );
        }
      }
    }, onError: (error) {
      debugPrint('Error listening to settings changes: $error');
    });
  }

  // Show glowing snackbar with white glowing text
  void _showGlowingSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.albertSans(
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    _settingsSubscription?.cancel();
    _animationController.dispose();
    _cardAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        final isDarkMode = themeService.isDarkMode;

        return Scaffold(
          backgroundColor: isDarkMode
              ? const Color(0xFF1E1E2C)
              : AppTheme.lightBackgroundColor,
          body: Container(
            decoration: isDarkMode
                ? null
                : const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage(
                          'assets/background/splashScreenBackground.jpg'),
                      fit: BoxFit.cover,
                      opacity: 0.1,
                    ),
                  ),
            child: SafeArea(
              child: Column(
                children: [
                  // Header
                  _buildHeader(isTablet, isDarkMode),

                  // Content
                  Expanded(
                    child: _isLoading
                        ? _buildLoadingState(isTablet, isDarkMode)
                        : SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: isTablet ? 32 : 20,
                              ),
                              child: Column(
                                children: [
                                  const SizedBox(height: 24),

                                  // General Settings
                                  _buildGeneralSettings(isTablet, isDarkMode),

                                  const SizedBox(height: 24),

                                  // App Configuration
                                  _buildAppConfiguration(isTablet, isDarkMode),

                                  const SizedBox(height: 24),

                                  // Order Settings
                                  _buildOrderSettings(isTablet, isDarkMode),

                                  const SizedBox(height: 24),

                                  // Notification Settings
                                  _buildNotificationSettings(
                                      isTablet, isDarkMode),

                                  const SizedBox(height: 24),

                                  // Payment Settings
                                  _buildPaymentSettings(isTablet, isDarkMode),

                                  const SizedBox(height: 24),

                                  // System Settings
                                  _buildSystemSettings(isTablet, isDarkMode),

                                  const SizedBox(height: 24),

                                  // Backup & Security
                                  _buildBackupSecurity(isTablet, isDarkMode),

                                  const SizedBox(height: 100),
                                ],
                              ),
                            ),
                          ),
                  ),
                ],
              ),
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
                    // Back button
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.arrow_back_ios,
                          size: isTablet ? 24 : 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Title
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'App Settings',
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 28 : 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Configure application',
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 14 : 12,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Save button
                GestureDetector(
                  onTap: _isSaving
                      ? null
                      : () {
                          HapticFeedback.lightImpact();
                          _saveSettings();
                        },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.save,
                      size: isTablet ? 24 : 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(bool isTablet, bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: isDarkMode
                ? AppColors.yellowAccent
                : AppTheme.lightPrimaryColor,
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading settings...',
            style: GoogleFonts.albertSans(
              fontSize: isTablet ? 16 : 14,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.7)
                  : AppTheme.lightTextSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralSettings(bool isTablet, bool isDarkMode) {
    return _buildSettingsSection(
      'General Settings',
      'Basic application configuration',
      Icons.settings_outlined,
      [
        _buildSwitchTile(
          'Maintenance Mode',
          'Enable to temporarily disable the app for users',
          _maintenanceMode,
          (value) {
            setState(() => _maintenanceMode = value);
            _autoSaveSettings();
          },
          Icons.build_outlined,
          isTablet,
          isDarkMode,
        ),
        _buildSwitchTile(
          'User Registration',
          'Allow new users to register on the platform',
          _registrationEnabled,
          (value) {
            setState(() => _registrationEnabled = value);
            _autoSaveSettings();
          },
          Icons.person_add_outlined,
          isTablet,
          isDarkMode,
        ),
        _buildSwitchTile(
          'Location Tracking',
          'Track user and driver locations for better service',
          _locationTracking,
          (value) {
            setState(() => _locationTracking = value);
            _autoSaveSettings();
          },
          Icons.location_on_outlined,
          isTablet,
          isDarkMode,
        ),
        _buildSwitchTile(
          'Background Sync',
          'Sync data in background for better performance',
          _backgroundSync,
          (value) {
            setState(() => _backgroundSync = value);
            _autoSaveSettings();
          },
          Icons.sync_outlined,
          isTablet,
          isDarkMode,
        ),
      ],
      isTablet,
      isDarkMode,
    );
  }

  Widget _buildAppConfiguration(bool isTablet, bool isDarkMode) {
    return _buildSettingsSection(
      'App Configuration',
      'Core application settings and preferences',
      Icons.tune_outlined,
      [
        _buildDropdownTile(
          'Default Currency',
          'Set the default currency for transactions',
          _defaultCurrency,
          _currencies,
          (value) {
            setState(() => _defaultCurrency = value!);
            _autoSaveSettings();
          },
          Icons.attach_money_outlined,
          isTablet,
          isDarkMode,
        ),
        _buildDropdownTile(
          'Time Zone',
          'Set the default time zone for the application',
          _timeZone,
          _timeZones,
          (value) {
            setState(() => _timeZone = value!);
            _autoSaveSettings();
          },
          Icons.access_time_outlined,
          isTablet,
          isDarkMode,
        ),
        _buildDropdownTile(
          'Map Provider',
          'Choose the map service for location features',
          _mapProvider,
          _mapProviders,
          (value) {
            setState(() => _mapProvider = value!);
            _autoSaveSettings();
          },
          Icons.map_outlined,
          isTablet,
          isDarkMode,
        ),
        _buildSliderTile(
          'Delivery Radius',
          'Maximum delivery distance in kilometers',
          _deliveryRadius,
          10.0,
          100.0,
          (value) {
            setState(() => _deliveryRadius = value);
            _autoSaveSettings();
          },
          Icons.radio_button_unchecked_outlined,
          isTablet,
          isDarkMode,
          suffix: 'km',
        ),
      ],
      isTablet,
      isDarkMode,
    );
  }

  Widget _buildOrderSettings(bool isTablet, bool isDarkMode) {
    return _buildSettingsSection(
      'Order Settings',
      'Configure order management and processing',
      Icons.shopping_bag_outlined,
      [
        _buildSwitchTile(
          'Auto-assign Orders',
          'Automatically assign orders to available drivers',
          _autoAssignOrders,
          (value) {
            setState(() => _autoAssignOrders = value);
            _autoSaveSettings();
          },
          Icons.assignment_outlined,
          isTablet,
          isDarkMode,
        ),
        _buildSliderTile(
          'Commission Rate',
          'Platform commission percentage on orders',
          _commissionRate,
          5.0,
          25.0,
          (value) {
            setState(() => _commissionRate = value);
            _autoSaveSettings();
          },
          Icons.percent_outlined,
          isTablet,
          isDarkMode,
          suffix: '%',
          divisions: 20,
        ),
        _buildSliderTile(
          'Minimum Order Value',
          'Minimum order amount required',
          _minOrderValue,
          100.0,
          2000.0,
          (value) {
            setState(() => _minOrderValue = value);
            _autoSaveSettings();
          },
          Icons.money_off_outlined,
          isTablet,
          isDarkMode,
          suffix: ' PKR',
          divisions: 19,
        ),
        _buildSliderTile(
          'Maximum Order Value',
          'Maximum order amount allowed',
          _maxOrderValue,
          10000.0,
          500000.0,
          (value) {
            setState(() => _maxOrderValue = value);
            _autoSaveSettings();
          },
          Icons.money_outlined,
          isTablet,
          isDarkMode,
          suffix: ' PKR',
          divisions: 49,
        ),
      ],
      isTablet,
      isDarkMode,
    );
  }

  Widget _buildNotificationSettings(bool isTablet, bool isDarkMode) {
    return _buildSettingsSection(
      'Notification Settings',
      'Configure notification preferences and delivery',
      Icons.notifications_outlined,
      [
        _buildSwitchTile(
          'Email Notifications',
          'Send email notifications for important events',
          _emailNotifications,
          (value) {
            setState(() => _emailNotifications = value);
            _autoSaveSettings();
          },
          Icons.email_outlined,
          isTablet,
          isDarkMode,
        ),
        _buildSwitchTile(
          'Push Notifications',
          'Send push notifications to mobile devices',
          _pushNotifications,
          (value) {
            setState(() => _pushNotifications = value);
            _autoSaveSettings();
          },
          Icons.notifications_active_outlined,
          isTablet,
          isDarkMode,
        ),
        _buildSwitchTile(
          'SMS Notifications',
          'Send SMS notifications for critical updates',
          _smsNotifications,
          (value) {
            setState(() => _smsNotifications = value);
            _autoSaveSettings();
          },
          Icons.sms_outlined,
          isTablet,
          isDarkMode,
        ),
      ],
      isTablet,
      isDarkMode,
    );
  }

  Widget _buildPaymentSettings(bool isTablet, bool isDarkMode) {
    return _buildSettingsSection(
      'Payment Settings',
      'Configure payment gateway and processing',
      Icons.payment_outlined,
      [
        _buildDropdownTile(
          'Payment Gateway',
          'Select the primary payment provider',
          _paymentGateway,
          _paymentGateways,
          (value) {
            setState(() => _paymentGateway = value!);
            _autoSaveSettings();
          },
          Icons.payment_outlined,
          isTablet,
          isDarkMode,
        ),
        _buildTextTile(
          'Gateway API Key',
          'Enter API key for the selected payment gateway',
          _apiKey.isEmpty ? 'Not configured' : '••••••••••••••••',
          Icons.vpn_key_outlined,
          () => _showApiKeyDialog(),
          isTablet,
          isDarkMode,
        ),
        _buildTextTile(
          'Gateway Secret',
          'Enter secret key for the selected payment gateway',
          _gatewaySecret.isEmpty ? 'Not configured' : '••••••••••••••••',
          Icons.security_outlined,
          () => _showSecretKeyDialog(),
          isTablet,
          isDarkMode,
        ),
      ],
      isTablet,
      isDarkMode,
    );
  }

  Widget _buildSystemSettings(bool isTablet, bool isDarkMode) {
    return _buildSettingsSection(
      'System Settings',
      'Application monitoring and debugging options',
      Icons.computer_outlined,
      [
        _buildSwitchTile(
          'Crash Reporting',
          'Enable automatic crash reporting for debugging',
          _crashReporting,
          (value) {
            setState(() => _crashReporting = value);
            _autoSaveSettings();
          },
          Icons.bug_report_outlined,
          isTablet,
          isDarkMode,
        ),
        _buildSwitchTile(
          'Analytics',
          'Enable analytics tracking for app improvement',
          _analyticsEnabled,
          (value) {
            setState(() => _analyticsEnabled = value);
            _autoSaveSettings();
          },
          Icons.analytics_outlined,
          isTablet,
          isDarkMode,
        ),
        _buildActionTile(
          'Clear Cache',
          'Clear application cache and temporary files',
          Icons.clear_all_outlined,
          () => _clearCache(),
          isTablet,
          isDarkMode,
        ),
        _buildActionTile(
          'View Logs',
          'View application logs and error reports',
          Icons.list_alt_outlined,
          () => _viewLogs(),
          isTablet,
          isDarkMode,
        ),
      ],
      isTablet,
      isDarkMode,
    );
  }

  Widget _buildBackupSecurity(bool isTablet, bool isDarkMode) {
    return _buildSettingsSection(
      'Backup & Security',
      'Data backup and security management options',
      Icons.security_outlined,
      [
        _buildActionTile(
          'Backup Database',
          'Create a backup of the application database',
          Icons.backup_outlined,
          () => _backupDatabase(),
          isTablet,
          isDarkMode,
        ),
        _buildActionTile(
          'Restore Database',
          'Restore database from a previous backup',
          Icons.restore_outlined,
          () => _restoreDatabase(),
          isTablet,
          isDarkMode,
        ),
        _buildActionTile(
          'Reset App',
          'Reset application to default settings',
          Icons.refresh_outlined,
          () => _resetApp(),
          isTablet,
          isDarkMode,
        ),
        _buildActionTile(
          'Security Audit',
          'Run comprehensive security audit',
          Icons.shield_outlined,
          () => _securityAudit(),
          isTablet,
          isDarkMode,
        ),
      ],
      isTablet,
      isDarkMode,
    );
  }

  Widget _buildSettingsSection(
      String title,
      String subtitle,
      IconData headerIcon,
      List<Widget> children,
      bool isTablet,
      bool isDarkMode) {
    return SlideTransition(
      position: _slideAnimation,
      child: ScaleTransition(
        scale: _cardScaleAnimation,
        child: Container(
          padding: EdgeInsets.all(isTablet ? 24 : 20),
          decoration: BoxDecoration(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.1)
                : AppTheme.lightCardColor,
            borderRadius: BorderRadius.circular(16),
            border: isDarkMode
                ? null
                : Border.all(
                    color: AppTheme.lightPrimaryColor,
                    width: 1.5,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    headerIcon,
                    color: isDarkMode
                        ? AppColors.yellowAccent
                        : AppTheme.lightPrimaryColor,
                    size: isTablet ? 24 : 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
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
                          subtitle,
                          style: GoogleFonts.albertSans(
                            fontSize: isTablet ? 14 : 12,
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
              SizedBox(height: isTablet ? 20 : 16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value,
      Function(bool) onChanged, IconData icon, bool isTablet, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: isDarkMode
            ? null
            : Border.all(
                color: AppTheme.lightBorderColor,
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
              icon,
              color: isDarkMode
                  ? AppColors.yellowAccent
                  : AppTheme.lightPrimaryColor,
              size: isTablet ? 20 : 18,
            ),
          ),
          SizedBox(width: isTablet ? 16 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode
                        ? Colors.white
                        : AppTheme.lightTextPrimaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
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
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: isDarkMode
                ? AppColors.yellowAccent
                : AppTheme.lightPrimaryColor,
            activeTrackColor: isDarkMode
                ? AppColors.yellowAccent.withValues(alpha: 0.3)
                : AppTheme.lightPrimaryColor.withValues(alpha: 0.3),
            inactiveThumbColor: isDarkMode
                ? Colors.white.withValues(alpha: 0.5)
                : AppColors.grey400,
            inactiveTrackColor: isDarkMode
                ? Colors.white.withValues(alpha: 0.2)
                : AppColors.grey300,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownTile(
      String title,
      String subtitle,
      String value,
      List<String> options,
      Function(String?) onChanged,
      IconData icon,
      bool isTablet,
      bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: isDarkMode
            ? null
            : Border.all(
                color: AppTheme.lightBorderColor,
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
              icon,
              color: isDarkMode
                  ? AppColors.yellowAccent
                  : AppTheme.lightPrimaryColor,
              size: isTablet ? 20 : 18,
            ),
          ),
          SizedBox(width: isTablet ? 16 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode
                        ? Colors.white
                        : AppTheme.lightTextPrimaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.1)
                  : AppColors.grey100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.2)
                    : AppColors.grey300,
                width: 1,
              ),
            ),
            child: DropdownButton<String>(
              value: value,
              items: options.map((option) {
                return DropdownMenuItem(
                  value: option,
                  child: Text(
                    option,
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 14 : 12,
                      color: isDarkMode
                          ? Colors.white
                          : AppTheme.lightTextPrimaryColor,
                    ),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
              underline: Container(),
              dropdownColor:
                  isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.7)
                    : AppTheme.lightTextSecondaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderTile(
    String title,
    String subtitle,
    double value,
    double min,
    double max,
    Function(double) onChanged,
    IconData icon,
    bool isTablet,
    bool isDarkMode, {
    String suffix = '',
    int? divisions,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: isDarkMode
            ? null
            : Border.all(
                color: AppTheme.lightBorderColor,
                width: 1,
              ),
      ),
      child: Column(
        children: [
          Row(
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
                  icon,
                  color: isDarkMode
                      ? AppColors.yellowAccent
                      : AppTheme.lightPrimaryColor,
                  size: isTablet ? 20 : 18,
                ),
              ),
              SizedBox(width: isTablet ? 16 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 16 : 14,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode
                            ? Colors.white
                            : AppTheme.lightTextPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
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
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? AppColors.yellowAccent.withValues(alpha: 0.2)
                      : AppTheme.lightPrimaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${value.toStringAsFixed(suffix == '%' ? 1 : 0)}$suffix',
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode
                        ? AppColors.yellowAccent
                        : AppTheme.lightPrimaryColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isTablet ? 16 : 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: isDarkMode
                  ? AppColors.yellowAccent
                  : AppTheme.lightPrimaryColor,
              inactiveTrackColor: isDarkMode
                  ? AppColors.yellowAccent.withValues(alpha: 0.3)
                  : AppTheme.lightPrimaryColor.withValues(alpha: 0.3),
              thumbColor: isDarkMode
                  ? AppColors.yellowAccent
                  : AppTheme.lightPrimaryColor,
              overlayColor: isDarkMode
                  ? AppColors.yellowAccent.withValues(alpha: 0.2)
                  : AppTheme.lightPrimaryColor.withValues(alpha: 0.2),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions ?? (max - min).toInt(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextTile(String title, String subtitle, String value,
      IconData icon, VoidCallback onTap, bool isTablet, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.all(isTablet ? 16 : 12),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
              border: isDarkMode
                  ? null
                  : Border.all(
                      color: AppTheme.lightBorderColor,
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
                    icon,
                    color: isDarkMode
                        ? AppColors.yellowAccent
                        : AppTheme.lightPrimaryColor,
                    size: isTablet ? 20 : 18,
                  ),
                ),
                SizedBox(width: isTablet ? 16 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 16 : 14,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode
                              ? Colors.white
                              : AppTheme.lightTextPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
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
                Text(
                  value,
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 14 : 12,
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.7)
                        : AppTheme.lightTextSecondaryColor,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios,
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.5)
                      : AppTheme.lightTextSecondaryColor,
                  size: isTablet ? 18 : 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile(String title, String subtitle, IconData icon,
      VoidCallback onTap, bool isTablet, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.all(isTablet ? 16 : 12),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
              border: isDarkMode
                  ? null
                  : Border.all(
                      color: AppTheme.lightBorderColor,
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
                    icon,
                    color: isDarkMode
                        ? AppColors.yellowAccent
                        : AppTheme.lightPrimaryColor,
                    size: isTablet ? 20 : 18,
                  ),
                ),
                SizedBox(width: isTablet ? 16 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 16 : 14,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode
                              ? Colors.white
                              : AppTheme.lightTextPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
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
                Icon(
                  Icons.arrow_forward_ios,
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.5)
                      : AppTheme.lightTextSecondaryColor,
                  size: isTablet ? 18 : 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showApiKeyDialog() {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isDarkMode = themeService.isDarkMode;
    final controller = TextEditingController(text: _apiKey);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Gateway API Key',
          style: GoogleFonts.albertSans(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
          ),
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'API Key',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDarkMode
                    ? AppColors.yellowAccent
                    : AppTheme.lightPrimaryColor,
              ),
            ),
          ),
          style: GoogleFonts.albertSans(
            color: isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.albertSans(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.7)
                    : AppTheme.lightTextSecondaryColor,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _apiKey = controller.text;
              });
              _autoSaveSettings();
              Navigator.pop(context);
            },
            child: Text(
              'Save',
              style: GoogleFonts.albertSans(
                color: isDarkMode
                    ? AppColors.yellowAccent
                    : AppTheme.lightPrimaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSecretKeyDialog() {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isDarkMode = themeService.isDarkMode;
    final controller = TextEditingController(text: _gatewaySecret);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Gateway Secret Key',
          style: GoogleFonts.albertSans(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
          ),
        ),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Secret Key',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDarkMode
                    ? AppColors.yellowAccent
                    : AppTheme.lightPrimaryColor,
              ),
            ),
          ),
          style: GoogleFonts.albertSans(
            color: isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.albertSans(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.7)
                    : AppTheme.lightTextSecondaryColor,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _gatewaySecret = controller.text;
              });
              _autoSaveSettings();
              Navigator.pop(context);
            },
            child: Text(
              'Save',
              style: GoogleFonts.albertSans(
                color: isDarkMode
                    ? AppColors.yellowAccent
                    : AppTheme.lightPrimaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _clearCache() {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isDarkMode = themeService.isDarkMode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Clear Cache',
          style: GoogleFonts.albertSans(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
          ),
        ),
        content: Text(
          'Are you sure you want to clear the application cache? This will remove temporary files and may improve performance.',
          style: GoogleFonts.albertSans(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.8)
                : AppTheme.lightTextSecondaryColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.albertSans(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.7)
                    : AppTheme.lightTextSecondaryColor,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showGlowingSnackBar(
                'Cache cleared successfully!',
                AppColors.success,
              );
            },
            child: Text(
              'Clear',
              style: GoogleFonts.albertSans(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _viewLogs() {
    _showGlowingSnackBar(
      'Logs viewer coming soon',
      Colors.blue,
    );
  }

  void _backupDatabase() {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isDarkMode = themeService.isDarkMode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Backup Database',
          style: GoogleFonts.albertSans(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
          ),
        ),
        content: Text(
          'Are you sure you want to create a backup of the database? This process may take a few minutes.',
          style: GoogleFonts.albertSans(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.8)
                : AppTheme.lightTextSecondaryColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.albertSans(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.7)
                    : AppTheme.lightTextSecondaryColor,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showGlowingSnackBar(
                'Database backup created successfully!',
                AppColors.success,
              );
            },
            child: Text(
              'Backup',
              style: GoogleFonts.albertSans(
                color: isDarkMode
                    ? AppColors.yellowAccent
                    : AppTheme.lightPrimaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _restoreDatabase() {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isDarkMode = themeService.isDarkMode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Restore Database',
          style: GoogleFonts.albertSans(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
          ),
        ),
        content: Text(
          'This will restore the database from the latest backup. All current data will be replaced. This action cannot be undone.',
          style: GoogleFonts.albertSans(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.8)
                : AppTheme.lightTextSecondaryColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.albertSans(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.7)
                    : AppTheme.lightTextSecondaryColor,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showGlowingSnackBar(
                'Database restored successfully!',
                AppColors.success,
              );
            },
            child: Text(
              'Restore',
              style: GoogleFonts.albertSans(
                color: Colors.orange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _resetApp() {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isDarkMode = themeService.isDarkMode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Reset App',
          style: GoogleFonts.albertSans(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
          ),
        ),
        content: Text(
          'This will reset all settings to default values. This action cannot be undone. Are you sure you want to continue?',
          style: GoogleFonts.albertSans(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.8)
                : AppTheme.lightTextSecondaryColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.albertSans(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.7)
                    : AppTheme.lightTextSecondaryColor,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showGlowingSnackBar(
                'App reset successfully!',
                AppColors.success,
              );
            },
            child: Text(
              'Reset',
              style: GoogleFonts.albertSans(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _securityAudit() {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isDarkMode = themeService.isDarkMode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Security Audit',
          style: GoogleFonts.albertSans(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : AppTheme.lightTextPrimaryColor,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: isDarkMode
                  ? AppColors.yellowAccent
                  : AppTheme.lightPrimaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Running comprehensive security audit...',
              style: GoogleFonts.albertSans(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.8)
                    : AppTheme.lightTextSecondaryColor,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showGlowingSnackBar(
                'Security audit completed - No issues found!',
                AppColors.success,
              );
            },
            child: Text(
              'Close',
              style: GoogleFonts.albertSans(
                color: isDarkMode
                    ? AppColors.yellowAccent
                    : AppTheme.lightPrimaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
