# Security and Secrets Guidance

This project currently contains sensitive configuration patterns that should be hardened before production.

## Key Risks Identified

- Stripe secret key exists in client-side source code.
- Firebase client config is committed (expected for client apps, but still should be environment-controlled).
- Potential broad access if backend security rules are not strictly enforced.

## Required Actions Before Production

1. Remove secret keys from app source files.
2. Move payment intent creation to a secure backend service.
3. Rotate any exposed Stripe/Firebase/API credentials.
4. Use separate environments: dev, staging, production.
5. Validate Firebase Auth and Firestore security rules.
6. Ensure release builds use secure signing and obfuscation policy where applicable.

## Secure Payment Pattern

Recommended Stripe pattern:

1. App sends order/payment request to backend.
2. Backend validates business rules.
3. Backend creates PaymentIntent using secret key.
4. Backend returns client_secret only.
5. App confirms payment through Stripe SDK.

## Mobile Hardening Checklist

- Disable verbose logging in release.
- Avoid storing sensitive user data in plain text.
- Use secure storage for tokens where needed.
- Verify Android/iOS permission prompts are minimal and justified.
- Add abuse controls for auth and payment workflows.

## Incident Response Basics

If secrets were exposed:

1. Revoke/rotate keys immediately.
2. Audit access logs.
3. Redeploy with new environment values.
4. Notify stakeholders and document remediation.
