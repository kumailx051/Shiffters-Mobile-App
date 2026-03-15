# Setup Guide

This document describes how to run Shiffters locally and prepare Android/iOS/web/desktop builds.

## 1. Prerequisites

- Flutter SDK (stable)
- Dart SDK (bundled with Flutter)
- Android Studio (Android SDK + emulator)
- Xcode (for iOS/macOS builds on macOS)
- Git

Recommended checks:

- flutter --version
- flutter doctor -v

## 2. Install Dependencies

From project root:

flutter pub get

## 3. Firebase Configuration

The app is configured via:

- lib/firebase_options.dart
- android/app/google-services.json
- iOS/macOS Firebase files (if applicable)

If you need to reconfigure Firebase:

1. Install FlutterFire CLI.
2. Run flutterfire configure.
3. Regenerate platform files.

## 4. Stripe Configuration

Current payment flow initializes Stripe in lib/services/stripe_service.dart.

Production recommendation:

- Keep publishable key in client-side config.
- Never keep Stripe secret key in the app.
- Create payment intents in a secure backend endpoint.

Local test mode (temporary only) can be run with:

flutter run --dart-define=STRIPE_PUBLISHABLE_KEY=your_publishable_key --dart-define=STRIPE_SECRET_KEY=your_test_secret_key

## 5. Maps and Location Setup

Packages used:

- google_maps_flutter
- geolocator
- geocoding

Ensure platform-specific location permissions are present:

- AndroidManifest.xml
- Info.plist

If map tiles/API fail, verify your map API key configuration per target platform.

## 6. Run the App

General:

flutter run

Specific device examples:

- flutter run -d android
- flutter run -d chrome
- flutter run -d windows

## 7. Build Artifacts

Android APK:

flutter build apk --release

Android App Bundle:

flutter build appbundle --release

Web:

flutter build web --release

Windows:

flutter build windows --release

## 8. Common Troubleshooting

Dependency lock or package issues:

- flutter pub get
- flutter pub upgrade

Build cache issues:

- flutter clean
- flutter pub get

Android Gradle issues:

- verify JDK 17
- verify compileSdk/targetSdk

## 9. Environment Checklist

Before sharing a build:

- remove hardcoded secrets
- verify Firebase project selection
- confirm Stripe mode (test vs live)
- verify role-based flows (User/Driver/Admin)
- run flutter analyze and flutter test
