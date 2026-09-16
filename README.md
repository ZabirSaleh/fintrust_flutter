# FINTRUST

FINTRUST is a Flutter fintech mobile app scaffold for Android and iOS. Sprint 1 includes authentication, registration, profile, logout, password reset, zero-trust style MFA checks, Firebase-ready persistence, transactions, activity, and QR Pay scanning.

See [FINTRUST_End_to_End_Description.md](FINTRUST_End_to_End_Description.md) for the complete architecture, workflows, Firebase setup, blockchain anchoring, reports, testing guide, and deployment notes.

## Sprint 1 Scope

- Register with email, phone, ID document, OTP, and authenticator code fields.
- Login with email, password, and one-time challenge.
- Forgot password flow through Firebase Auth when configured.
- Firebase Auth and Cloud Firestore repository with demo fallback.
- Signed-in home, profile, transactions, activity, and QR Pay tabs.
- Android and iOS camera permissions for QR scanning.

## Firebase Setup

The app is configured for Firebase project `myr-ewallet`.

Registered Firebase apps:

- Android package `com.fintrust.fintrust`
- iOS bundle ID `com.fintrust.fintrust`

Generated config files:

- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

Firestore rules and indexes have been deployed with:

```sh
firebase deploy --only firestore
```

Enable **Authentication > Sign-in method > Email/Password** in the Firebase console before testing real registration/login. `FintrustBackendFactory` initializes Firebase automatically from the generated options.

## Firestore Shape

```text
users/{uid}
users/{uid}/wallets/main
users/{uid}/transactions/{transactionId}
users/{uid}/activity/{activityId}
```

Only the authenticated owner can read or create their own nested records. Wallet updates and deletes are blocked in `firestore.rules`; production money movement should be handled by server-side functions.

## Local Commands

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```
