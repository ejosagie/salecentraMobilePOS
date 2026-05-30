# SaleCentra Flutter

A Flutter mobile application for SaleCentra - Smart Sales & Business Management.

## Features

- **Authentication**: Secure login for business owners and staff
- **Dashboard**: Quick overview of sales, inventory, and business metrics with a full-featured grid menu
- **Inventory Management**: Add, edit, and track stock levels
- **Point of Sale (POS)**: Quick sales entry with cart functionality
- **Staff Sales Entry**: Dedicated staff login mode for recording sales independently
- **Sales History**: View and track all past sales transactions
- **Customer Management**: Store and manage customer information
- **Expense Tracking**: Record and categorize business expenses
- **Debt Management**: Track money owed to you and debts you owe
- **Invoices**: Create and manage customer invoices
- **Forecast**: Sales forecasting and projections
- **Price Pilot**: Price comparison and optimization tools
- **Reports**: View sales, expense, and business analytics
- **Notifications**: In-app alerts and updates
- **PDF Receipts**: Generate and share professional PDF receipts after each sale
- **Settings**: Business settings, staff management, and app preferences

## Getting Started

### Prerequisites

- Flutter SDK (>=3.0.0)
- Android Studio or VS Code
- Android SDK
- Xcode (for iOS builds)
- CocoaPods (for iOS dependency management)

### Installation

1. Navigate to the project directory:
```bash
cd salecentra_flutter
```

2. Get dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

### Building for Android

**APK (for direct install):**
```bash
flutter clean
flutter build apk --release
```
Output: `build/app/outputs/flutter-apk/app-release.apk`

**App Bundle (AAB for Google Play Store):**
```bash
flutter clean
flutter build appbundle --release
```
Output: `build/app/outputs/bundle/release/app-release.aab`

### Building for iOS

**IPA (requires Apple Developer account and signing certificates):**
```bash
flutter clean
flutter build ipa --release
```
Output: `build/ios/ipa/SaleCentra.ipa`

### Upload to Google Play Console

1. Build the AAB:
```bash
flutter build appbundle --release
```
2. Go to [Google Play Console](https://play.google.com/console)
3. Navigate to **Testing → Internal testing**
4. Upload `build/app/outputs/bundle/release/app-release.aab`
5. Add testers and share the opt-in link

### Upload to App Store (via Codemagic CI/CD)

This project includes a `codemagic.yaml` for automated iOS builds.

1. Push code to GitHub
2. Go to [Codemagic](https://codemagic.io) and connect your repo
3. Configure **App Store Connect API key** in Codemagic settings
4. Trigger the `ios-release` workflow
5. The IPA is automatically uploaded to App Store Connect and distributed to TestFlight internal testers

## Project Structure

```
lib/
├── main.dart                          # App entry point & routing
├── models/                            # Data models
│   ├── user.dart
│   ├── inventory.dart
│   ├── sale.dart
│   ├── customer.dart
│   ├── expense.dart
│   ├── debt.dart
│   └── invoice.dart
├── screens/                           # UI screens
│   ├── splash_screen.dart
│   ├── onboarding/
│   │   └── onboarding_screen.dart
│   ├── auth/
│   │   ├── login_screen.dart
│   │   └── register_screen.dart
│   ├── dashboard/
│   │   └── dashboard_screen.dart
│   ├── inventory/
│   │   └── inventory_screen.dart
│   ├── sales/
│   │   ├── sales_screen.dart
│   │   └── sales_history_screen.dart
│   ├── customers/
│   │   └── customers_screen.dart
│   ├── expenses/
│   │   └── expenses_screen.dart
│   ├── debts/
│   │   └── debts_screen.dart
│   ├── invoices/
│   │   └── invoices_screen.dart
│   ├── reports/
│   │   └── reports_screen.dart
│   ├── forecast/
│   │   └── forecast_screen.dart
│   ├── price_pilot/
│   │   └── price_pilot_screen.dart
│   ├── notifications/
│   │   └── notifications_screen.dart
│   ├── settings/
│   │   ├── settings_screen.dart
│   │   ├── business_settings_screen.dart
│   │   └── staff_settings_screen.dart
│   ├── more/
│   │   └── more_screen.dart
│   └── staff/
│       └── staff_login_screen.dart
├── services/                          # Business logic
│   ├── auth_service.dart
│   ├── remote_database_service.dart
│   └── pdf_service.dart
├── widgets/                           # Reusable widgets
│   └── app_logo.dart
└── utils/                             # Utilities
    ├── theme.dart
    └── constants.dart
```

## CI/CD

### Codemagic Workflow (`codemagic.yaml`)

- **iOS Release**: Automatically builds signed IPA, increments build number, and submits to TestFlight
- **Android Release**: Can be extended to build AAB and upload to Google Play

## License

Copyright (c) 2024 SaleCentra
