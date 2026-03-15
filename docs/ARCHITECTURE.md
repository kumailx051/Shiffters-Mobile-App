# Architecture Overview

## App Entry

- main.dart initializes:
  - Flutter bindings
  - Firebase
  - Stripe service
  - Theme provider
  - Biometric wrapper around initial navigation

## High-Level Layers

- Presentation: screen widgets grouped by role and use case
- Services: authentication, payments, biometric auth, messaging, theming
- Utilities/Widgets: shared helpers and reusable UI components
- Assets: animations, images, icons, backgrounds, ML model

## Module Layout

- lib/screens/auth: login, signup, OTP, password recovery
- lib/screens/User: booking, profile, orders, chat/help, tracking, shifting flows
- lib/screens/Driver: onboarding, dashboard, jobs, tracking, earnings, support
- lib/screens/Admin: management dashboards and operational controls
- lib/services: app integrations and business logic helpers
- lib/theme: centralized design tokens and themes

## Data and Integration Flow

1. User authenticates through Firebase Auth.
2. Core entities and state are read/write through Firestore.
3. Payments are initiated through Stripe service.
4. Tracking and map visualization use location + maps providers.
5. Theme and local UX state are managed through Provider and local services.

## Cross-Cutting Concerns

- Authentication and role navigation
- Biometric app protection layer
- Error handling and validation in service layer
- Platform-specific capability handling (camera, biometrics, maps)

## Suggested Evolution

- Introduce repository pattern for service abstraction
- Add API/backend layer for payment intent and protected business logic
- Add CI for lint, test, and build validation
- Expand widget/integration test coverage for critical booking flows
