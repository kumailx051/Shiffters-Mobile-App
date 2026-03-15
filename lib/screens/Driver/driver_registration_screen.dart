import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shiffters/services/theme_service.dart';
import 'package:shiffters/theme/app_colors.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'application_submitted_screen.dart';

class DriverRegistrationScreen extends StatefulWidget {
  const DriverRegistrationScreen({super.key});

  @override
  State<DriverRegistrationScreen> createState() =>
      _DriverRegistrationScreenState();
}

class _DriverRegistrationScreenState extends State<DriverRegistrationScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();

  // Animation controllersp
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Form controllers
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _vehicleYearController = TextEditingController();
  final _plateNumberController = TextEditingController();
  final _insuranceNumberController = TextEditingController();

  // Form state
  int _currentStep = 0;
  bool _isLoading = false;
  String? _selectedVehicleType;
  String? _selectedExperience;
  bool _hasCommercialLicense = false;
  bool _hasInsurance = true;
  bool _agreedToTerms = false;

  // Image picker
  final ImagePicker _picker = ImagePicker();
  File? _cnicFrontImage;
  File? _cnicBackImage;
  File? _carFrontImage;
  File? _carBackImage;
  File? _carSideImage;

  // For web compatibility
  Uint8List? _cnicFrontBytes;
  Uint8List? _cnicBackBytes;
  Uint8List? _carFrontBytes;
  Uint8List? _carBackBytes;
  Uint8List? _carSideBytes;

  final List<String> _vehicleTypes = [
    'Sedan',
    'SUV',
    'Van',
    'Pickup Truck',
    'Small Truck',
    'Large Truck',
  ];

  final List<String> _experienceOptions = [
    'Less than 1 year',
    '1-3 years',
    '3-5 years',
    '5+ years',
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
    _setupPhoneFormatting();
    _prefillUserEmail();
  }

  void _prefillUserEmail() {
    // Get current user and pre-fill email
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      _emailController.text = user.email!;
    }
  }

  void _setupPhoneFormatting() {
    // Add listener for phone number formatting
    _phoneController.addListener(() {
      _formatPhoneNumber(_phoneController);
    });
  }

  void _formatPhoneNumber(TextEditingController controller) {
    String text = controller.text
        .replaceAll(RegExp(r'[^0-9]'), ''); // Remove all non-digits

    if (text.length >= 4 && text.length <= 11) {
      // Format as 0333-5466545
      String formatted;
      if (text.length <= 4) {
        formatted = text;
      } else {
        formatted = text.substring(0, 4) + '-' + text.substring(4);
      }

      // Only update if the formatted text is different to avoid cursor jumping
      if (controller.text != formatted) {
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
    _pageController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    _licenseNumberController.dispose();
    _vehicleModelController.dispose();
    _vehicleYearController.dispose();
    _plateNumberController.dispose();
    _insuranceNumberController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 3) {
      if (_validateCurrentStep()) {
        setState(() {
          _currentStep++;
        });
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        HapticFeedback.lightImpact();
      } else {
        // Show validation error message
        String errorMessage = '';
        switch (_currentStep) {
          case 0:
            errorMessage =
                'Please fill all personal information fields correctly';
            break;
          case 1:
            errorMessage = 'Please fill all license and address fields';
            break;
          case 2:
            errorMessage = 'Please complete all vehicle information fields';
            break;
          case 3:
            errorMessage = _getDocumentValidationError();
            break;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMessage,
              style: GoogleFonts.albertSans(
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } else {
      _submitForm();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      HapticFeedback.lightImpact();
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _firstNameController.text.isNotEmpty &&
            _lastNameController.text.isNotEmpty &&
            _emailController.text.isNotEmpty &&
            _phoneController.text.isNotEmpty &&
            _isValidEmail(_emailController.text) &&
            _isValidPhone(_phoneController.text);
      case 1:
        return _addressController.text.isNotEmpty &&
            _cityController.text.isNotEmpty &&
            _stateController.text.isNotEmpty &&
            _zipController.text.isNotEmpty &&
            _licenseNumberController.text.isNotEmpty;
      case 2:
        return _selectedVehicleType != null &&
            _vehicleModelController.text.isNotEmpty &&
            _vehicleYearController.text.isNotEmpty &&
            _plateNumberController.text.isNotEmpty &&
            _selectedExperience != null &&
            (_hasInsurance ? _insuranceNumberController.text.isNotEmpty : true);
      case 3:
        return (kIsWeb
                ? (_cnicFrontBytes != null &&
                    _cnicBackBytes != null &&
                    _carFrontBytes != null &&
                    _carBackBytes != null &&
                    _carSideBytes != null)
                : (_cnicFrontImage != null &&
                    _cnicBackImage != null &&
                    _carFrontImage != null &&
                    _carBackImage != null &&
                    _carSideImage != null)) &&
            _agreedToTerms &&
            _isCnicFrontValidated &&
            _isCnicBackValidated;
      default:
        return false;
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  bool _isValidPhone(String phone) {
    return RegExp(r'^\+?[\d\s\-\(\)]{10,}$').hasMatch(phone);
  }

  String _getDocumentValidationError() {
    List<String> missingImages = [];

    // Check CNIC images
    if (kIsWeb) {
      if (_cnicFrontBytes == null) missingImages.add('CNIC Front');
      if (_cnicBackBytes == null) missingImages.add('CNIC Back');
      if (_carFrontBytes == null) missingImages.add('Car Front View');
      if (_carBackBytes == null) missingImages.add('Car Back View');
      if (_carSideBytes == null) missingImages.add('Car Side View');
    } else {
      if (_cnicFrontImage == null) missingImages.add('CNIC Front');
      if (_cnicBackImage == null) missingImages.add('CNIC Back');
      if (_carFrontImage == null) missingImages.add('Car Front View');
      if (_carBackImage == null) missingImages.add('Car Back View');
      if (_carSideImage == null) missingImages.add('Car Side View');
    }

    // Check CNIC validation
    if (!_isCnicFrontValidated &&
        (kIsWeb ? _cnicFrontBytes != null : _cnicFrontImage != null)) {
      return 'CNIC Front image is not validated. Please upload a valid CNIC front image.';
    }
    if (!_isCnicBackValidated &&
        (kIsWeb ? _cnicBackBytes != null : _cnicBackImage != null)) {
      return 'CNIC Back image is not validated. Please upload a valid CNIC back image.';
    }

    if (!_agreedToTerms) {
      missingImages.add('Terms Agreement');
    }

    if (missingImages.isNotEmpty) {
      if (missingImages.length == 1 &&
          missingImages.first == 'Terms Agreement') {
        return 'Please agree to the Terms of Service and Privacy Policy';
      } else if (missingImages.contains('Terms Agreement')) {
        missingImages.remove('Terms Agreement');
        return 'Please upload: ${missingImages.join(', ')} and agree to terms';
      } else {
        return 'Please upload all required images: ${missingImages.join(', ')}';
      }
    }

    return 'Please complete all requirements';
  }

  // ImageBB API configuration
  static const String _imageBBApiKey = 'f31e40432a7b500dd75ce5255d3ea517';
  static const String _imageBBUrl = 'https://api.imgbb.com/1/upload';

  // CNIC Validation API configuration
  static const String _cnicApiBaseUrl =
      'https://trickily-photoactinic-alita.ngrok-free.dev';
  static const String _cnicPredictEndpoint = '/cnic/predict_base64';

  // CNIC validation state
  bool _isCnicFrontValidated = false;
  bool _isCnicBackValidated = false;
  bool _isValidatingCnic = false;

  // Test mode - set to true to bypass CNIC validation for testing
  static const bool _testMode = false;

  // Debug function to manually mark CNIC as validated
  void _debugValidateCnic(String type) {
    setState(() {
      if (type == 'front') {
        _isCnicFrontValidated = true;
      } else {
        _isCnicBackValidated = true;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.bug_report, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              'DEBUG: CNIC ${type == 'front' ? 'Front' : 'Back'} marked as validated',
              style: GoogleFonts.albertSans(
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.purple,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Validate CNIC using API
  Future<bool> _validateCnicImage(
      Uint8List imageBytes, String imageType) async {
    try {
      // Test mode bypass
      if (_testMode) {
        debugPrint('🧪 Test mode: Bypassing CNIC validation');
        setState(() {
          if (imageType == 'front') {
            _isCnicFrontValidated = true;
          } else {
            _isCnicBackValidated = true;
          }
        });
        return true;
      }

      setState(() {
        _isValidatingCnic = true;
      });

      // Convert image to base64
      final base64Image = base64Encode(imageBytes);

      debugPrint('🚀 Sending CNIC validation request...');
      debugPrint('📝 Image type: $imageType');
      debugPrint('📊 Image size: ${imageBytes.length} bytes');

      // Make API request
      final response = await http
          .post(
            Uri.parse('$_cnicApiBaseUrl$_cnicPredictEndpoint'),
            headers: {
              'Content-Type': 'application/json',
              'ngrok-skip-browser-warning': 'true',
            },
            body: json.encode({
              'image': base64Image,
            }),
          )
          .timeout(const Duration(seconds: 30));

      debugPrint('📡 CNIC Validation Response Status: ${response.statusCode}');
      debugPrint('📄 CNIC Validation Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        debugPrint('📊 Full API Response: $jsonResponse');
        debugPrint('🔍 Available keys: ${jsonResponse.keys.toList()}');

        // Check if the response indicates success and has prediction data
        if (jsonResponse['success'] == true &&
            jsonResponse['prediction'] != null) {
          final predictionData = jsonResponse['prediction'];

          debugPrint('🎯 Prediction Data: $predictionData');

          // Extract values from your API response format
          final isCnic = predictionData['is_cnic'] ?? false;
          final label = predictionData['label'] ?? '';
          final confidence = predictionData['confidence'] ?? 0.0;
          final rawScore = predictionData['raw_score'] ?? 0.0;

          debugPrint('✅ is_cnic: $isCnic');
          debugPrint('🏷️ label: "$label"');
          debugPrint('📈 confidence: $confidence%');
          debugPrint('📊 raw_score: $rawScore');

          // More flexible validation - accept if it's classified as CNIC with reasonable confidence
          bool isValidCnic = isCnic == true &&
              confidence >= 30.0; // Lower threshold for testing

          debugPrint(
              '🏁 Final validation result: $isValidCnic (threshold: 30%)');

          if (mounted) {
            if (isValidCnic) {
              // Update validation state
              setState(() {
                if (imageType == 'front') {
                  _isCnicFrontValidated = true;
                } else {
                  _isCnicBackValidated = true;
                }
              });

              // Show success message
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'CNIC ${imageType == 'front' ? 'Front' : 'Back'} Verified Successfully )',
                        style: GoogleFonts.albertSans(
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  duration: const Duration(seconds: 3),
                ),
              );
            } else {
              // Show error message for invalid CNIC
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Please upload a valid CNIC ${imageType == 'front' ? 'front' : 'back'} image)',
                          style: GoogleFonts.albertSans(
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          }

          return isValidCnic;
        }
      }

      // API error - show generic error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Unable to validate CNIC. Please check your internet connection and try again.',
                    style: GoogleFonts.albertSans(
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 4),
          ),
        );
      }

      return false;
    } catch (e) {
      debugPrint('Error validating CNIC: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Error validating CNIC: ${e.toString()}',
                    style: GoogleFonts.albertSans(
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 4),
          ),
        );
      }

      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isValidatingCnic = false;
        });
      }
    }
  }

  // Upload image to ImageBB
  Future<String?> _uploadImageToImageBB(
      dynamic imageData, String fileName) async {
    try {
      Uint8List bytes;

      if (kIsWeb) {
        bytes = imageData as Uint8List;
      } else {
        bytes = await (imageData as File).readAsBytes();
      }

      final base64Image = base64Encode(bytes);

      final response = await http.post(
        Uri.parse(_imageBBUrl),
        body: {
          'key': _imageBBApiKey,
          'image': base64Image,
          'name': fileName,
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          return jsonResponse['data']['url'];
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error uploading image to ImageBB: $e');
      return null;
    }
  }

  // Submit form data to Firebase
  Future<void> _submitToFirebase() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Upload images to ImageBB
      String? cnicFrontUrl, cnicBackUrl, carFrontUrl, carBackUrl, carSideUrl;

      if (kIsWeb) {
        if (_cnicFrontBytes != null) {
          cnicFrontUrl = await _uploadImageToImageBB(
              _cnicFrontBytes!, 'cnic_front_${user.uid}');
        }
        if (_cnicBackBytes != null) {
          cnicBackUrl = await _uploadImageToImageBB(
              _cnicBackBytes!, 'cnic_back_${user.uid}');
        }
        if (_carFrontBytes != null) {
          carFrontUrl = await _uploadImageToImageBB(
              _carFrontBytes!, 'car_front_${user.uid}');
        }
        if (_carBackBytes != null) {
          carBackUrl = await _uploadImageToImageBB(
              _carBackBytes!, 'car_back_${user.uid}');
        }
        if (_carSideBytes != null) {
          carSideUrl = await _uploadImageToImageBB(
              _carSideBytes!, 'car_side_${user.uid}');
        }
      } else {
        if (_cnicFrontImage != null) {
          cnicFrontUrl = await _uploadImageToImageBB(
              _cnicFrontImage!, 'cnic_front_${user.uid}');
        }
        if (_cnicBackImage != null) {
          cnicBackUrl = await _uploadImageToImageBB(
              _cnicBackImage!, 'cnic_back_${user.uid}');
        }
        if (_carFrontImage != null) {
          carFrontUrl = await _uploadImageToImageBB(
              _carFrontImage!, 'car_front_${user.uid}');
        }
        if (_carBackImage != null) {
          carBackUrl = await _uploadImageToImageBB(
              _carBackImage!, 'car_back_${user.uid}');
        }
        if (_carSideImage != null) {
          carSideUrl = await _uploadImageToImageBB(
              _carSideImage!, 'car_side_${user.uid}');
        }
      }

      // Prepare driver data
      final driverData = {
        'userId': user.uid, // Required by security rules
        'uid': user.uid,
        'personalInfo': {
          'firstName': _firstNameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
        },
        'address': {
          'street': _addressController.text.trim(),
          'city': _cityController.text.trim(),
          'state': _stateController.text.trim(),
          'zipCode': _zipController.text.trim(),
        },
        'license': {
          'licenseNumber': _licenseNumberController.text.trim(),
          'hasCommercialLicense': _hasCommercialLicense,
        },
        'vehicle': {
          'type': _selectedVehicleType,
          'model': _vehicleModelController.text.trim(),
          'year': _vehicleYearController.text.trim(),
          'plateNumber': _plateNumberController.text.trim(),
          'hasInsurance': _hasInsurance,
          'insuranceNumber':
              _hasInsurance ? _insuranceNumberController.text.trim() : null,
        },
        'experience': _selectedExperience,
        'documents': {
          'cnicFront': cnicFrontUrl,
          'cnicBack': cnicBackUrl,
          'carFront': carFrontUrl,
          'carBack': carBackUrl,
          'carSide': carSideUrl,
        },
        'applicationStatus': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Save to Firestore - use driverApplications collection
      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(user.uid)
          .set(driverData);

      debugPrint('Driver application submitted successfully');
    } catch (e) {
      debugPrint('Error submitting driver application: $e');
      rethrow;
    }
  }

  void _submitForm() async {
    if (!_validateCurrentStep()) {
      // Show specific validation error for documents step
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _getDocumentValidationError(),
            style: GoogleFonts.albertSans(
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Submit to Firebase with image uploads
      await _submitToFirebase();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Navigate to application submitted screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const ApplicationSubmittedScreen(),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error submitting application: $e');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error submitting application. Please try again.',
              style: GoogleFonts.albertSans(
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _pickImage(String imageType) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();

        // For CNIC images, validate them first
        if (imageType == 'cnicFront' || imageType == 'cnicBack') {
          String cnicType = imageType == 'cnicFront' ? 'front' : 'back';
          bool isValidCnic = await _validateCnicImage(bytes, cnicType);

          if (!isValidCnic) {
            // Don't save the image if it's not a valid CNIC
            return;
          }
        }

        setState(() {
          switch (imageType) {
            case 'cnicFront':
              if (kIsWeb) {
                _cnicFrontBytes = bytes;
              } else {
                _cnicFrontImage = File(image.path);
              }
              break;
            case 'cnicBack':
              if (kIsWeb) {
                _cnicBackBytes = bytes;
              } else {
                _cnicBackImage = File(image.path);
              }
              break;
            case 'carFront':
              if (kIsWeb) {
                _carFrontBytes = bytes;
              } else {
                _carFrontImage = File(image.path);
              }
              break;
            case 'carBack':
              if (kIsWeb) {
                _carBackBytes = bytes;
              } else {
                _carBackImage = File(image.path);
              }
              break;
            case 'carSide':
              if (kIsWeb) {
                _carSideBytes = bytes;
              } else {
                _carSideImage = File(image.path);
              }
              break;
          }
        });
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error picking image: $e',
            style: GoogleFonts.albertSans(
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _showImageSourceDialog(String imageType, String title) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        final isDarkMode =
            Provider.of<ThemeService>(context, listen: false).isDarkMode;

        return AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Select $title',
            style: GoogleFonts.albertSans(
              color: isDarkMode ? Colors.white : AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.camera_alt,
                  color: isDarkMode
                      ? AppColors.yellowAccent
                      : AppColors.lightPrimary,
                ),
                title: Text(
                  'Camera',
                  style: GoogleFonts.albertSans(
                    color: isDarkMode ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _pickImageFromCamera(imageType);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.photo_library,
                  color: isDarkMode
                      ? AppColors.yellowAccent
                      : AppColors.lightPrimary,
                ),
                title: Text(
                  'Gallery',
                  style: GoogleFonts.albertSans(
                    color: isDarkMode ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _pickImage(imageType);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImageFromCamera(String imageType) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();

        // For CNIC images, validate them first
        if (imageType == 'cnicFront' || imageType == 'cnicBack') {
          String cnicType = imageType == 'cnicFront' ? 'front' : 'back';
          bool isValidCnic = await _validateCnicImage(bytes, cnicType);

          if (!isValidCnic) {
            // Don't save the image if it's not a valid CNIC
            return;
          }
        }

        setState(() {
          switch (imageType) {
            case 'cnicFront':
              if (kIsWeb) {
                _cnicFrontBytes = bytes;
              } else {
                _cnicFrontImage = File(image.path);
              }
              break;
            case 'cnicBack':
              if (kIsWeb) {
                _cnicBackBytes = bytes;
              } else {
                _cnicBackImage = File(image.path);
              }
              break;
            case 'carFront':
              if (kIsWeb) {
                _carFrontBytes = bytes;
              } else {
                _carFrontImage = File(image.path);
              }
              break;
            case 'carBack':
              if (kIsWeb) {
                _carBackBytes = bytes;
              } else {
                _carBackImage = File(image.path);
              }
              break;
            case 'carSide':
              if (kIsWeb) {
                _carSideBytes = bytes;
              } else {
                _carSideImage = File(image.path);
              }
              break;
          }
        });
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error taking photo: $e',
            style: GoogleFonts.albertSans(
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        final isDarkMode = themeService.isDarkMode;

        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                isDarkMode ? Brightness.light : Brightness.dark,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness:
                isDarkMode ? Brightness.light : Brightness.dark,
          ),
        );

        return Scaffold(
          backgroundColor: isDarkMode ? const Color(0xFF1E1E2C) : Colors.white,
          appBar: _buildAppBar(isDarkMode, isTablet),
          body: Stack(
            children: [
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Progress indicator
                    _buildProgressIndicator(isDarkMode, isTablet),

                    // Form content
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildPersonalInfoStep(isDarkMode, isTablet),
                          _buildLicenseInfoStep(isDarkMode, isTablet),
                          _buildVehicleInfoStep(isDarkMode, isTablet),
                          _buildDocumentsStep(isDarkMode, isTablet),
                        ],
                      ),
                    ),

                    // Navigation buttons
                    _buildNavigationButtons(isDarkMode, isTablet),
                  ],
                ),
              ),

              // Full-screen loading overlay
              if (_isLoading)
                Container(
                  color: Colors.black.withValues(alpha: 0.7),
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.all(isTablet ? 40 : 30),
                      decoration: BoxDecoration(
                        color:
                            isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: isTablet ? 180 : 150,
                            width: isTablet ? 180 : 150,
                            child: Lottie.asset(
                              'assets/animations/loading.json',
                              width: isTablet ? 180 : 150,
                              height: isTablet ? 180 : 150,
                              fit: BoxFit.contain,
                            ),
                          ),
                          SizedBox(height: isTablet ? 24 : 20),
                          Text(
                            'Submitting Application...',
                            style: GoogleFonts.albertSans(
                              fontSize: isTablet ? 18 : 16,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: isTablet ? 12 : 8),
                          Text(
                            'Please wait while we process your application',
                            style: GoogleFonts.albertSans(
                              fontSize: isTablet ? 14 : 12,
                              color: isDarkMode
                                  ? Colors.white.withValues(alpha: 0.7)
                                  : AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDarkMode, bool isTablet) {
    return AppBar(
      elevation: 0,
      backgroundColor: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: isDarkMode
              ? Border.all(color: Colors.white.withValues(alpha: 0.2))
              : Border.all(
                  color: AppColors.lightPrimary.withValues(alpha: 0.3)),
        ),
        child: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: isDarkMode ? Colors.white : AppColors.textPrimary,
            size: 20,
          ),
        ),
      ),
      title: Text(
        'Driver Registration',
        style: GoogleFonts.albertSans(
          fontSize: isTablet ? 22 : 20,
          fontWeight: FontWeight.w600,
          color: isDarkMode ? Colors.white : AppColors.textPrimary,
        ),
      ),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            isDarkMode ? Brightness.light : Brightness.dark,
      ),
    );
  }

  Widget _buildProgressIndicator(bool isDarkMode, bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 24 : 20),
      child: Row(
        children: List.generate(4, (index) {
          final isActive = index <= _currentStep;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: isActive
                          ? (isDarkMode
                              ? AppColors.yellowAccent
                              : AppColors.lightPrimary)
                          : (isDarkMode
                              ? Colors.white.withValues(alpha: 0.2)
                              : Colors.grey.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                if (index < 3) const SizedBox(width: 8),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPersonalInfoStep(bool isDarkMode, bool isTablet) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: isTablet ? 32 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: isTablet ? 20 : 16),
              Text(
                'Personal Information',
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 24 : 22,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : AppColors.textPrimary,
                ),
              ),
              SizedBox(height: isTablet ? 8 : 6),
              Text(
                'Please provide your basic information',
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 16 : 14,
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.7)
                      : AppColors.textSecondary,
                ),
              ),
              SizedBox(height: isTablet ? 32 : 24),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _firstNameController,
                      label: 'First Name',
                      hint: 'Enter your first name',
                      isDarkMode: isDarkMode,
                      isTablet: isTablet,
                      validator: (value) =>
                          value?.isEmpty == true ? 'Required' : null,
                    ),
                  ),
                  SizedBox(width: isTablet ? 16 : 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _lastNameController,
                      label: 'Last Name',
                      hint: 'Enter your last name',
                      isDarkMode: isDarkMode,
                      isTablet: isTablet,
                      validator: (value) =>
                          value?.isEmpty == true ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              SizedBox(height: isTablet ? 20 : 16),
              _buildTextField(
                controller: _emailController,
                label: 'Email Address',
                hint: 'Your registered email address',
                keyboardType: TextInputType.emailAddress,
                isDarkMode: isDarkMode,
                isTablet: isTablet,
                isReadOnly: true,
                validator: (value) {
                  if (value?.isEmpty == true) return 'Required';
                  if (!_isValidEmail(value!)) return 'Invalid email format';
                  return null;
                },
              ),
              SizedBox(height: isTablet ? 8 : 6),
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: isTablet ? 16 : 14,
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.6)
                        : AppColors.textSecondary,
                  ),
                  SizedBox(width: isTablet ? 8 : 6),
                  Expanded(
                    child: Text(
                      'Email address is automatically filled from your account and cannot be changed.',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 12 : 11,
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.6)
                            : AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: isTablet ? 20 : 16),
              _buildTextField(
                controller: _phoneController,
                label: 'Phone Number',
                hint: '0333-5466545',
                keyboardType: TextInputType.phone,
                isDarkMode: isDarkMode,
                isTablet: isTablet,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'[0-9-]')), // Only numbers and dash
                  LengthLimitingTextInputFormatter(
                      12), // Max length including dash
                ],
                validator: (value) {
                  if (value?.isEmpty == true) return 'Required';
                  String cleanPhone = value!.replaceAll('-', '');
                  if (cleanPhone.length != 11)
                    return 'Phone number must be 11 digits';
                  if (!cleanPhone.startsWith('03'))
                    return 'Phone number must start with 03';
                  return null;
                },
              ),
              SizedBox(height: isTablet ? 40 : 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLicenseInfoStep(bool isDarkMode, bool isTablet) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: isTablet ? 32 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: isTablet ? 20 : 16),
              Text(
                'License & Address',
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 24 : 22,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : AppColors.textPrimary,
                ),
              ),
              SizedBox(height: isTablet ? 8 : 6),
              Text(
                'Provide your license and address details',
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 16 : 14,
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.7)
                      : AppColors.textSecondary,
                ),
              ),
              SizedBox(height: isTablet ? 32 : 24),
              _buildTextField(
                controller: _licenseNumberController,
                label: 'Driver License Number',
                hint: 'Enter your license number',
                isDarkMode: isDarkMode,
                isTablet: isTablet,
                validator: (value) =>
                    value?.isEmpty == true ? 'Required' : null,
              ),
              SizedBox(height: isTablet ? 20 : 16),
              _buildCheckboxTile(
                value: _hasCommercialLicense,
                title: 'I have a Commercial Driver\'s License (CDL)',
                isDarkMode: isDarkMode,
                isTablet: isTablet,
                onChanged: (value) =>
                    setState(() => _hasCommercialLicense = value ?? false),
              ),
              SizedBox(height: isTablet ? 20 : 16),
              _buildTextField(
                controller: _addressController,
                label: 'Street Address',
                hint: 'Enter your street address',
                isDarkMode: isDarkMode,
                isTablet: isTablet,
                validator: (value) =>
                    value?.isEmpty == true ? 'Required' : null,
              ),
              SizedBox(height: isTablet ? 20 : 16),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildTextField(
                      controller: _cityController,
                      label: 'City',
                      hint: 'Enter city',
                      isDarkMode: isDarkMode,
                      isTablet: isTablet,
                      validator: (value) =>
                          value?.isEmpty == true ? 'Required' : null,
                    ),
                  ),
                  SizedBox(width: isTablet ? 16 : 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _stateController,
                      label: 'State',
                      hint: 'State',
                      isDarkMode: isDarkMode,
                      isTablet: isTablet,
                      validator: (value) =>
                          value?.isEmpty == true ? 'Required' : null,
                    ),
                  ),
                  SizedBox(width: isTablet ? 16 : 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _zipController,
                      label: 'ZIP Code',
                      hint: 'ZIP',
                      keyboardType: TextInputType.number,
                      isDarkMode: isDarkMode,
                      isTablet: isTablet,
                      validator: (value) =>
                          value?.isEmpty == true ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              SizedBox(height: isTablet ? 40 : 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleInfoStep(bool isDarkMode, bool isTablet) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: isTablet ? 32 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: isTablet ? 20 : 16),
              Text(
                'Vehicle Information',
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 24 : 22,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : AppColors.textPrimary,
                ),
              ),
              SizedBox(height: isTablet ? 8 : 6),
              Text(
                'Tell us about your vehicle and experience',
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 16 : 14,
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.7)
                      : AppColors.textSecondary,
                ),
              ),
              SizedBox(height: isTablet ? 32 : 24),
              _buildDropdownField(
                value: _selectedVehicleType,
                items: _vehicleTypes,
                label: 'Vehicle Type',
                hint: 'Select vehicle type',
                isDarkMode: isDarkMode,
                isTablet: isTablet,
                onChanged: (value) =>
                    setState(() => _selectedVehicleType = value),
              ),
              SizedBox(height: isTablet ? 20 : 16),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildTextField(
                      controller: _vehicleModelController,
                      label: 'Vehicle Model',
                      hint: 'e.g., Toyota Camry',
                      isDarkMode: isDarkMode,
                      isTablet: isTablet,
                      validator: (value) =>
                          value?.isEmpty == true ? 'Required' : null,
                    ),
                  ),
                  SizedBox(width: isTablet ? 16 : 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _vehicleYearController,
                      label: 'Year',
                      hint: 'e.g., 2020',
                      keyboardType: TextInputType.number,
                      isDarkMode: isDarkMode,
                      isTablet: isTablet,
                      validator: (value) =>
                          value?.isEmpty == true ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              SizedBox(height: isTablet ? 20 : 16),
              _buildTextField(
                controller: _plateNumberController,
                label: 'License Plate Number',
                hint: 'Enter license plate number',
                isDarkMode: isDarkMode,
                isTablet: isTablet,
                validator: (value) =>
                    value?.isEmpty == true ? 'Required' : null,
              ),
              SizedBox(height: isTablet ? 20 : 16),
              _buildDropdownField(
                value: _selectedExperience,
                items: _experienceOptions,
                label: 'Driving Experience',
                hint: 'Select your experience',
                isDarkMode: isDarkMode,
                isTablet: isTablet,
                onChanged: (value) =>
                    setState(() => _selectedExperience = value),
              ),
              SizedBox(height: isTablet ? 20 : 16),
              _buildCheckboxTile(
                value: _hasInsurance,
                title: 'I have valid vehicle insurance',
                isDarkMode: isDarkMode,
                isTablet: isTablet,
                onChanged: (value) =>
                    setState(() => _hasInsurance = value ?? true),
              ),
              if (_hasInsurance) ...[
                SizedBox(height: isTablet ? 16 : 12),
                _buildTextField(
                  controller: _insuranceNumberController,
                  label: 'Insurance Policy Number',
                  hint: 'Enter insurance policy number',
                  isDarkMode: isDarkMode,
                  isTablet: isTablet,
                  validator: (value) => _hasInsurance && value?.isEmpty == true
                      ? 'Required'
                      : null,
                ),
              ],
              SizedBox(height: isTablet ? 40 : 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentsStep(bool isDarkMode, bool isTablet) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: isTablet ? 32 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: isTablet ? 20 : 16),

              Text(
                'Documents & Images',
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 24 : 22,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : AppColors.textPrimary,
                ),
              ),

              SizedBox(height: isTablet ? 8 : 6),

              Text(
                'Please upload required documents and vehicle images',
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 16 : 14,
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.7)
                      : AppColors.textSecondary,
                ),
              ),

              SizedBox(height: isTablet ? 32 : 24),

              // CNIC Section
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'CNIC (Computerized National Identity Card)',
                      style: GoogleFonts.albertSans(
                        fontSize: isTablet ? 18 : 16,
                        fontWeight: FontWeight.w600,
                        color:
                            isDarkMode ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  // Debug button (only in debug mode)
                  if (kDebugMode)
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.bug_report,
                        color: Colors.purple,
                        size: 20,
                      ),
                      onSelected: (value) {
                        if (value == 'validate_front') {
                          _debugValidateCnic('front');
                        } else if (value == 'validate_back') {
                          _debugValidateCnic('back');
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'validate_front',
                          child: Text('✅ Mark Front as Valid'),
                        ),
                        const PopupMenuItem(
                          value: 'validate_back',
                          child: Text('✅ Mark Back as Valid'),
                        ),
                      ],
                    ),
                ],
              ),

              SizedBox(height: isTablet ? 16 : 12),

              Row(
                children: [
                  Expanded(
                    child: _buildImageUploadTile(
                      title: 'CNIC Front',
                      subtitle: 'Upload front side',
                      image: _cnicFrontImage,
                      imageBytes: _cnicFrontBytes,
                      onTap: () =>
                          _showImageSourceDialog('cnicFront', 'CNIC Front'),
                      isDarkMode: isDarkMode,
                      isTablet: isTablet,
                    ),
                  ),
                  SizedBox(width: isTablet ? 16 : 12),
                  Expanded(
                    child: _buildImageUploadTile(
                      title: 'CNIC Back',
                      subtitle: 'Upload back side',
                      image: _cnicBackImage,
                      imageBytes: _cnicBackBytes,
                      onTap: () =>
                          _showImageSourceDialog('cnicBack', 'CNIC Back'),
                      isDarkMode: isDarkMode,
                      isTablet: isTablet,
                    ),
                  ),
                ],
              ),

              SizedBox(height: isTablet ? 32 : 24),

              // Vehicle Images Section
              Text(
                'Vehicle Images',
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 18 : 16,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : AppColors.textPrimary,
                ),
              ),

              SizedBox(height: isTablet ? 16 : 12),

              _buildImageUploadTile(
                title: 'Car Front View',
                subtitle: 'Upload front view of your vehicle',
                image: _carFrontImage,
                imageBytes: _carFrontBytes,
                onTap: () =>
                    _showImageSourceDialog('carFront', 'Car Front View'),
                isDarkMode: isDarkMode,
                isTablet: isTablet,
                isFullWidth: true,
              ),

              SizedBox(height: isTablet ? 16 : 12),

              Row(
                children: [
                  Expanded(
                    child: _buildImageUploadTile(
                      title: 'Car Back View',
                      subtitle: 'Upload back view',
                      image: _carBackImage,
                      imageBytes: _carBackBytes,
                      onTap: () =>
                          _showImageSourceDialog('carBack', 'Car Back View'),
                      isDarkMode: isDarkMode,
                      isTablet: isTablet,
                    ),
                  ),
                  SizedBox(width: isTablet ? 16 : 12),
                  Expanded(
                    child: _buildImageUploadTile(
                      title: 'Car Side View',
                      subtitle: 'Upload side view',
                      image: _carSideImage,
                      imageBytes: _carSideBytes,
                      onTap: () =>
                          _showImageSourceDialog('carSide', 'Car Side View'),
                      isDarkMode: isDarkMode,
                      isTablet: isTablet,
                    ),
                  ),
                ],
              ),

              SizedBox(height: isTablet ? 32 : 24),

              _buildCheckboxTile(
                value: _agreedToTerms,
                title: 'I agree to the Terms of Service and Privacy Policy',
                isDarkMode: isDarkMode,
                isTablet: isTablet,
                onChanged: (value) =>
                    setState(() => _agreedToTerms = value ?? false),
              ),

              SizedBox(height: isTablet ? 40 : 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isDarkMode,
    required bool isTablet,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
    bool isReadOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.albertSans(
            fontSize: isTablet ? 16 : 14,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : AppColors.textPrimary,
          ),
        ),
        SizedBox(height: isTablet ? 8 : 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          inputFormatters: inputFormatters,
          readOnly: isReadOnly,
          style: GoogleFonts.albertSans(
            fontSize: isTablet ? 16 : 14,
            color: isReadOnly
                ? (isDarkMode
                    ? Colors.white.withValues(alpha: 0.6)
                    : AppColors.textSecondary)
                : (isDarkMode ? Colors.white : AppColors.textPrimary),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.albertSans(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.5)
                  : AppColors.textSecondary,
            ),
            filled: true,
            fillColor: isReadOnly
                ? (isDarkMode
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.withValues(alpha: 0.05))
                : (isDarkMode
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.1)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isReadOnly
                    ? (isDarkMode
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.2))
                    : (isDarkMode
                        ? Colors.white.withValues(alpha: 0.2)
                        : AppColors.lightPrimary.withValues(alpha: 0.3)),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isReadOnly
                    ? (isDarkMode
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.2))
                    : (isDarkMode
                        ? Colors.white.withValues(alpha: 0.2)
                        : AppColors.lightPrimary.withValues(alpha: 0.3)),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isReadOnly
                    ? (isDarkMode
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.2))
                    : (isDarkMode
                        ? AppColors.yellowAccent
                        : AppColors.lightPrimary),
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: isTablet ? 16 : 14,
              vertical: isTablet ? 16 : 14,
            ),
            suffixIcon: isReadOnly
                ? Icon(
                    Icons.lock_outline,
                    size: 20,
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.4)
                        : AppColors.textSecondary.withValues(alpha: 0.6),
                  )
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required List<String> items,
    required String label,
    required String hint,
    required bool isDarkMode,
    required bool isTablet,
    required void Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.albertSans(
            fontSize: isTablet ? 16 : 14,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : AppColors.textPrimary,
          ),
        ),
        SizedBox(height: isTablet ? 8 : 6),
        DropdownButtonFormField<String>(
          value: value,
          onChanged: onChanged,
          validator: (value) =>
              value == null ? 'Please select an option' : null,
          style: GoogleFonts.albertSans(
            fontSize: isTablet ? 16 : 14,
            color: isDarkMode ? Colors.white : AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.albertSans(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.5)
                  : AppColors.textSecondary,
            ),
            filled: true,
            fillColor: isDarkMode
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.2)
                    : AppColors.lightPrimary.withValues(alpha: 0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.2)
                    : AppColors.lightPrimary.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDarkMode
                    ? AppColors.yellowAccent
                    : AppColors.lightPrimary,
                width: 2,
              ),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: isTablet ? 16 : 14,
              vertical: isTablet ? 16 : 14,
            ),
          ),
          dropdownColor: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                style: GoogleFonts.albertSans(
                  color: isDarkMode ? Colors.white : AppColors.textPrimary,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCheckboxTile({
    required bool value,
    required String title,
    required bool isDarkMode,
    required bool isTablet,
    required void Function(bool?) onChanged,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged,
          activeColor:
              isDarkMode ? AppColors.yellowAccent : AppColors.lightPrimary,
          checkColor: isDarkMode ? Colors.black : Colors.white,
          side: BorderSide(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.5)
                : AppColors.textSecondary,
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(!value),
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                title,
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 15 : 14,
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.9)
                      : AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationButtons(bool isDarkMode, bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 24 : 20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2D2D3C) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Full width main button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDarkMode
                    ? AppColors.yellowAccent
                    : AppColors.lightPrimary,
                foregroundColor: isDarkMode ? Colors.black : Colors.white,
                padding: EdgeInsets.symmetric(vertical: isTablet ? 20 : 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
                minimumSize: Size(double.infinity, isTablet ? 60 : 56),
              ),
              child: Text(
                _currentStep == 3 ? 'Submit Application' : 'Continue',
                style: GoogleFonts.albertSans(
                  fontSize: isTablet ? 16 : 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          // Previous button (if not on first step)
          if (_currentStep > 0) ...[
            SizedBox(height: isTablet ? 12 : 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _previousStep,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: isTablet ? 20 : 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.3)
                        : AppColors.lightPrimary,
                  ),
                  minimumSize: Size(double.infinity, isTablet ? 60 : 56),
                ),
                child: Text(
                  'Previous',
                  style: GoogleFonts.albertSans(
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : AppColors.lightPrimary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImageUploadTile({
    required String title,
    required String subtitle,
    required File? image,
    required Uint8List? imageBytes,
    required VoidCallback onTap,
    required bool isDarkMode,
    required bool isTablet,
    bool isFullWidth = false,
  }) {
    final bool hasImage = kIsWeb ? imageBytes != null : image != null;
    final bool isCnicImage = title.toLowerCase().contains('cnic');
    final bool isCnicFront = title.toLowerCase().contains('front');
    final bool isValidated = isCnicImage
        ? (isCnicFront ? _isCnicFrontValidated : _isCnicBackValidated)
        : true;

    Color borderColor = Colors.grey;
    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.upload;

    if (hasImage) {
      if (isCnicImage) {
        if (isValidated) {
          borderColor = Colors.green;
          statusColor = Colors.green;
          statusIcon = Icons.verified;
        } else {
          borderColor = Colors.orange;
          statusColor = Colors.orange;
          statusIcon = Icons.warning;
        }
      } else {
        borderColor =
            isDarkMode ? AppColors.yellowAccent : AppColors.lightPrimary;
        statusColor = Colors.green;
        statusIcon = Icons.check;
      }
    }

    return GestureDetector(
      onTap: _isValidatingCnic ? null : onTap,
      child: Container(
        width: isFullWidth ? double.infinity : null,
        height: isTablet ? 140 : 120,
        decoration: BoxDecoration(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: hasImage ? 2 : 1,
          ),
        ),
        child: _isValidatingCnic && isCnicImage
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: isTablet ? 30 : 24,
                    width: isTablet ? 30 : 24,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDarkMode
                            ? AppColors.yellowAccent
                            : AppColors.lightPrimary,
                      ),
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(height: isTablet ? 12 : 8),
                  Text(
                    'Validating CNIC...',
                    style: GoogleFonts.albertSans(
                      fontSize: isTablet ? 12 : 10,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            : hasImage
                ? Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: kIsWeb
                            ? Image.memory(
                                imageBytes!,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                              )
                            : Image.file(
                                image!,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                              ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            statusIcon,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                      if (isCnicImage && !isValidated)
                        Positioned(
                          bottom: 8,
                          left: 8,
                          right: 8,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.all(6),
                            child: Text(
                              'Not Validated',
                              style: GoogleFonts.albertSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cloud_upload_outlined,
                        size: isTablet ? 40 : 32,
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.6)
                            : AppColors.textSecondary,
                      ),
                      SizedBox(height: isTablet ? 12 : 8),
                      Text(
                        title,
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 14 : 12,
                          fontWeight: FontWeight.w600,
                          color:
                              isDarkMode ? Colors.white : AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: isTablet ? 4 : 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.albertSans(
                          fontSize: isTablet ? 12 : 10,
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.6)
                              : AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
      ),
    );
  }
}
