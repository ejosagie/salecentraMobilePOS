# SaleCentra POS

A Flutter POS application for SaleCentra — built specifically for Sunmi Android POS terminals.

**Current Version: 1.0.0+1**

## Features

- **Combined Login**: Business owner (email + password) and staff (email + staff name + passcode) login
- **POS Activation**: Admin-controlled POS activation per merchant with terminal registration
- **Minimal Dashboard**: 6-item menu — Sales, History, Inventory, Deliver, Returns, Payment (Settings + Notifications in AppBar)
- **Thermal Printing**: 58mm receipt printing via Sunmi built-in printer (auto-print after sale + reprint)
- **Offline Support**: Full offline sales capability — sales are saved locally when offline and auto-sync when connectivity returns; inventory cached for offline viewing; 3-day session cache
- **Sales**: Cart-based sales entry with discounts, cash/bank transfer payment, thermal receipt
- **Returns**: Full and partial refund processing with thermal refund receipt
- **Inventory**: View-only for staff (low stock alerts, search, expiry tracking); full CRUD for business owner
- **Deliveries**: Book and track deliveries with provider selection
- **Online Payment**: Generate Flutterwave payment links for manual payment collection
- **Bank Details**: POS bank account capture for settlement
- **Connection Status**: Real-time online/offline indicator with days remaining

## Target Device

- **Platform**: Android only (Sunmi POS terminals)
- **Package**: `com.neurowavesds.salecentra.sunmi`
- **App Label**: SaleCentra POS
- **No iOS support** — this build is exclusively for Sunmi Android devices

## Getting Started

### Prerequisites

- Flutter SDK (>=3.0.0)
- Android Studio or VS Code
- Android SDK

### Installation

1. Navigate to the project directory:
```bash
cd salecentraMobilePOS
```

2. Get dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

### Building APK (for direct install on Sunmi devices)

```bash
flutter clean
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

## Project Structure

```
lib/
├── main.dart                          # App entry point & routing
├── models/                            # Data models
│   ├── user.dart
│   ├── inventory.dart
│   ├── sale.dart
│   ├── customer.dart
│   ├── shop_order.dart
│   └── ...
├── screens/                           # UI screens
│   ├── splash_screen.dart
│   ├── auth/
│   │   └── pos_login_screen.dart      # Combined owner/staff login
│   ├── dashboard/
│   │   └── dashboard_screen.dart      # Minimal 6-item POS menu
│   ├── inventory/
│   │   └── inventory_screen.dart
│   ├── sales/
│   │   ├── sales_screen.dart          # POS sales with thermal print
│   │   ├── sales_history_screen.dart
│   │   └── returns_screen.dart        # Refunds/returns
│   ├── deliveries/
│   │   └── delivery_screen.dart
│   └── settings/
│       └── bank_details_screen.dart   # POS bank account capture
├── services/                          # Business logic & API
│   ├── api_service.dart
│   ├── auth_service.dart
│   ├── remote_database_service.dart
│   ├── thermal_printer_service.dart   # Sunmi 58mm thermal printing
│   ├── offline_service.dart           # 3-day offline session cache
│   ├── pos_service.dart               # POS activation & terminal API
│   ├── pdf_service.dart
│   └── delivery_service.dart
├── widgets/
│   ├── app_logo.dart
│   └── connection_status_indicator.dart
└── utils/
    ├── theme.dart
    └── constants.dart
```

## API Integration

The app communicates with the SaleCentra backend at `https://mysalecentra.com/api`:

- **Auth**: Owner login, staff login, session management
- **POS**: Activation status, terminal registration, bank details
- **Sales**: CRUD operations, refunds, history
- **Inventory**: Stock management
- **Deliveries**: Provider listing, booking, tracking

## Sunmi-Specific Features

- **Auto-start on boot**: App launches when device powers on (`BootReceiver.kt`)
- **Thermal printer**: 58mm receipt printing via `sunmi_printer_plus`
- **Wake lock**: Screen stays on during active use
- **Battery optimization**: Requests ignore battery optimizations
- **Offline cache**: Secure storage for session data (3-day expiry)

## License

Copyright (c) 2024-2026 SaleCentra
