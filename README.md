# SaleCentra Flutter

A Flutter mobile application for SaleCentra - Smart Sales & Business Management.

## Features

- **Authentication**: Secure login for business owners and staff
- **Dashboard**: Quick overview of sales, inventory, and business metrics
- **Inventory Management**: Add, edit, and track stock levels
- **Point of Sale (POS)**: Quick sales entry with cart functionality
- **Customer Management**: Store and manage customer information
- **Expense Tracking**: Record and categorize business expenses
- **Debt Management**: Track money owed to you and debts you owe
- **Reports**: View sales and expense analytics

## Getting Started

### Prerequisites

- Flutter SDK (>=3.0.0)
- Android Studio or VS Code
- Android SDK

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

```bash
flutter build apk --release
```

The APK will be generated at:
`build/app/outputs/flutter-apk/app-release.apk`

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
│   ├── user.dart
│   ├── inventory.dart
│   ├── sale.dart
│   ├── customer.dart
│   ├── expense.dart
│   ├── debt.dart
│   └── invoice.dart
├── screens/                  # UI screens
│   ├── splash_screen.dart
│   ├── auth/
│   │   ├── login_screen.dart
│   │   └── register_screen.dart
│   ├── dashboard/
│   │   └── dashboard_screen.dart
│   ├── inventory/
│   │   └── inventory_screen.dart
│   ├── sales/
│   │   └── sales_screen.dart
│   ├── customers/
│   │   └── customers_screen.dart
│   ├── expenses/
│   │   └── expenses_screen.dart
│   ├── debts/
│   │   └── debts_screen.dart
│   ├── reports/
│   │   └── reports_screen.dart
│   ├── more/
│   │   └── more_screen.dart
│   └── staff/
│       └── staff_login_screen.dart
├── services/                 # Business logic
│   ├── auth_service.dart
│   └── database_service.dart
└── utils/                    # Utilities
    ├── theme.dart
    └── constants.dart
```

## License

Copyright (c) 2024 SaleCentra
