# Shiffters Mobile App

A multi-role logistics and relocation mobile application built with Flutter, featuring customer booking flows, live tracking, driver operations, admin tooling, Firebase-backed authentication/data, and Stripe payments.

## Project Snapshot

Shiffters is designed for end-to-end moving and delivery operations with three main personas:

- User: create shifting or pickup/drop orders, chat, track progress, and pay securely.
- Driver: register, accept jobs, verify items, track routes, and monitor earnings.
- Admin: manage users, drivers, discounts, orders, reports, and support workflows.

## Feature Highlights

### User Experience

- Onboarding, auth, OTP, forgot/reset password flows
- Home, profile, and order management screens
- Pickup/drop and shifting booking journeys
- Route entry and vehicle recommendation flows
- In-app messaging and chatbot support
- Real-time style tracking screens with map integrations

### Driver Experience

- Driver registration and profile lifecycle
- Job acceptance and detailed job views
- Item verification and trip tracking screens
- Earnings, help, and chat screens

### Admin Experience

- Dashboard and analytics/reporting screens
- User and driver management consoles
- Order management and discount controls
- Notifications/announcements and support ticketing
- App settings and admin profile management

## Tech Stack

- Flutter (Material UI)
- Dart
- Firebase Core, Auth, Firestore
- Stripe (payment sheet and card handling service)
- Google Maps Flutter + fallback map tooling
- Geolocator + Geocoding
- Local Authentication (biometric lock/wrapper)
- Provider (theme and state management)
- Lottie animations

## Current Structure

- lib/main.dart: app bootstrap, Firebase init, Stripe init, theme provider, biometric wrapper
- lib/screens/: role-based UI flows (User, Driver, Admin, Auth)
- lib/services/: auth, payments, biometric, messaging, theme, CNIC validation
- lib/widgets/: reusable UI elements (including biometric wrappers and sliders)
- assets/: animations, icons, backgrounds, images, ML model asset
- docs/: project documentation

## Quick Start

1. Install Flutter SDK and verify with flutter doctor.
2. Clone the repository.
3. Install dependencies:

   flutter pub get

4. Run the app:

   flutter run

If Stripe is enabled for local testing, pass keys with dart defines:

   flutter run --dart-define=STRIPE_PUBLISHABLE_KEY=your_publishable_key --dart-define=STRIPE_SECRET_KEY=your_test_secret_key

For detailed platform setup and secrets configuration, see docs/SETUP.md.

## Documentation

- docs/SETUP.md: environment, platform setup, configuration checklist
- docs/ARCHITECTURE.md: app structure, data flow, role-based module map
- docs/SECURITY.md: sensitive config guidance and hardening checklist

## Security Notice

Sensitive configuration exists in tracked/generated platform files. Before production release, rotate credentials and keep payment secret operations server-side. See docs/SECURITY.md.

## Development Status

This codebase is functionally rich and UI-heavy with broad multi-role coverage. Suggested next focus:

- strengthen automated test coverage
- move payment intent creation to a backend
- formalize environment separation (dev/staging/prod)
- tighten secrets and release hardening

## Contributing

1. Create a feature branch.
2. Implement and test changes locally.
3. Open a pull request with clear scope and screenshots for UI changes.

## License

No license file is currently included. Add a LICENSE file if you plan to open-source or define usage rights.
