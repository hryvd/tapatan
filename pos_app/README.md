# Sar-E — Smart POS & Store Manager

> **Sar-E** is a Flutter mobile application designed as a smart Point-of-Sale and store management system for Filipino sari-sari stores. It operates **offline-first** with optional Firebase cloud sync, and integrates AI-powered product scanning via a custom TFLite model.

---

## 📱 Overview

Sar-E is the **merchant-facing POS app** of the tap@tan system. Store owners use it to:

- Scan products via barcode or AI camera recognition (TFLite model)
- Manage inventory with categories, stock levels, and product images
- Process sales transactions and accept NFC-tokenized payments from the tap@tan user app
- Track customer credit (*Listahan*) — the digital equivalent of a neighborhood credit ledger
- View sales analytics, export PDF reports, and sync data to Firebase

The app is built for low-connectivity environments: all data is persisted locally in SQLite and synced to Firestore when a connection is available.

---

## 🏗️ Architecture

```
Sar-E POS (Flutter)
├── Auth Screen          — Login / Google Sign-In / biometric unlock
├── Setup Screen         — Initial store configuration
├── Scanner Screen       — Barcode + AI camera scan, cart management
├── Barcode Scanner View — Live mobile_scanner view
├── Inventory Screen     — Product CRUD, categories, stock tracking
├── Listahan Screen      — Customer credit ledger (utang tracker)
├── Transactions Screen  — Full transaction history
├── Analytics Screen     — Sales charts, top products, revenue trends
├── Notifications Screen — Low-stock alerts, sync status
├── Settings Screen      — Locale, theme, PDF export
└── Profile Screen       — Store info, sign out
```

State is managed using **Riverpod** (`flutter_riverpod`). Data access is split across provider-level DAOs backed by **SQLite** (`sqflite`) for offline persistence.

---

## 🤖 AI Scanning

The scanner screen integrates a custom **TFLite** image classification model (`product_model.pth` converted to `.tflite`) that recognizes common sari-sari store products from the camera feed.

- Uses `tflite_flutter ^0.11.0` for on-device inference
- AI scan runs alongside standard mobile barcode scanning (`mobile_scanner`)
- Falls back to manual barcode input when AI confidence is low
- Model assets are bundled under `assets/models/`

---

## 💾 Data Layer

```
lib/data/local/
├── database.dart           — SQLite database initialization & migrations
└── daos/
    ├── product_dao.dart
    ├── transaction_dao.dart
    ├── customer_dao.dart
    ├── credit_dao.dart
    └── user_dao.dart
```

### Domain Entities

| Entity | Description |
|---|---|
| `Product` | Store inventory item with barcode, price, stock |
| `Transaction` | Completed sale record |
| `Customer` | Registered customer profile |
| `CreditEntry` | Individual credit (utang) record |
| `SalesSummary` | Aggregated daily/weekly/monthly sales |
| `Category` | Product grouping |
| `UserCredential` | Store owner auth data |

---

## 🔒 Authentication

- **Firebase Auth** — email/password and Google Sign-In
- **Local biometric auth** — fingerprint/face via `local_auth`
- **Offline PIN fallback** — for use without connectivity

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter 3 (Dart SDK ^3.5.0) |
| State Management | Riverpod (`flutter_riverpod ^2.6.1`) |
| Local Database | SQLite (`sqflite ^2.4.2`) |
| Cloud Sync | Firebase Firestore (`cloud_firestore ^5.6.6`) |
| Auth | Firebase Auth + Google Sign-In + `local_auth` |
| AI Scanning | TFLite (`tflite_flutter ^0.11.0`), `camera ^0.12.0` |
| Barcode Scan | `mobile_scanner ^7.2.0` |
| PDF Export | `pdf ^3.11.3`, `printing ^5.14.2` |
| Charts | `fl_chart ^1.2.0` |
| QR Display | `qr_flutter ^4.1.0` |
| Fonts | Google Fonts |
| Connectivity | `connectivity_plus ^6.1.4` |

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK ≥ 3.5.0
- Dart SDK ≥ 3.5.0
- Firebase project with Firestore and Authentication enabled
- Android device or emulator with camera support

### Setup

```bash
# 1. Clone the repository
git clone https://github.com/hryvd/tapatan_sare.git
cd tapatan_sare/pos_app

# 2. Install dependencies
flutter pub get

# 3. Configure Firebase
# Replace lib/firebase_options.dart with your own project's generated options
# (use `flutterfire configure` from the FlutterFire CLI)

# 4. Run on device
flutter run
```

> **Note:** The AI scanning feature requires a physical device with a camera. The barcode scanner also works best on a real device.

---

## 📋 Features

### 🛒 Scanner / POS
- Scan barcodes with live camera or image gallery
- AI-powered product recognition via TFLite model
- Cart management — add, remove, adjust quantities
- QR code display for customer-facing price confirmation
- Checkout with NFC payment acceptance (tap@tan integration)

### 📦 Inventory
- Add/edit/delete products with images, categories, and stock levels
- Barcode assignment
- Low-stock threshold alerts

### 📒 Listahan (Credit Ledger)
- Track per-customer utang (credit)
- Record partial and full payments
- View credit history per customer

### 📊 Analytics
- Daily, weekly, monthly sales breakdowns
- Top-selling products chart
- Revenue trends with `fl_chart`
- PDF report export

### ☁️ Sync
- Background Firebase sync via `sync_provider`
- Conflict resolution for offline-first edits
- Connectivity status indicator

---

## 🗂️ Project Structure

```
lib/
├── main.dart
├── application/
│   ├── ai_scan_service.dart
│   ├── analytics_provider.dart
│   ├── auth_provider.dart
│   ├── cart_provider.dart
│   ├── inventory_provider.dart
│   ├── listahan_provider.dart
│   ├── locale_provider.dart
│   ├── notifications_provider.dart
│   └── sync_provider.dart
├── data/local/
│   ├── database.dart
│   └── daos/
├── domain/entities/
├── screens/
│   ├── login_screen.dart
│   ├── setup_screen.dart
│   ├── scanner_screen.dart
│   ├── inventory_screen.dart
│   ├── listahan_screen.dart
│   ├── transactions_screen.dart
│   ├── analytics_screen.dart
│   ├── notifications_screen.dart
│   ├── settings_screen.dart
│   ├── profile_screen.dart
│   └── main_shell.dart
├── theme/
│   └── app_theme.dart
└── widgets/
    ├── glass_container.dart
    ├── glass_dialog.dart
    ├── liquid_background.dart
    └── toast_overlay.dart
```

---

## 📄 License

This project is part of an academic thesis. All rights reserved.
