# FinTrust Mobile (Flutter)

A clean, lightweight Flutter fintech demo for Android and iOS.

## Features
- Register and login
- Auto-create a default wallet on registration
- Dashboard with balance
- Transfer money with risk decision:
  - Allow
  - Step-Up
  - Deny
- Risk events log
- Security Center

## Stack
- Flutter
- Provider
- SQLite (`sqflite`)
- Shared Preferences (demo session)

## Run
1. Install Flutter SDK
2. Open this project in VS Code or Android Studio
3. Run:
   ```bash
   flutter pub get
   flutter run
   ```

## Notes
- This is a local demo app. Data is stored on-device.
- Session is stored using `shared_preferences` for simplicity.
