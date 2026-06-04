# tap@tan — NFC Tokenized Payment App

> **tap@tan** is a Flutter mobile application that enables privacy-preserving, tokenized NFC payments using Java Card technology. Built as a thesis project exploring secure contactless authentication.

---

## 📱 Overview

tap@tan is the **user-facing wallet app** of the tap@tan system. It allows registered users to:

- Authenticate and manage their virtual NFC-linked payment cards
- Initiate NFC payment flows with tiered authentication based on transaction amount
- Track transaction history and card health in real time
- View analytics comparing NFC Card auth against SMS OTP and Biometric methods

The app communicates with a Java Card NFC applet to write one-time tokenized payment payloads — ensuring that no sensitive card data is ever transmitted directly.

---

## 🏗️ Architecture

```
tap@tan (Flutter)
├── Auth Screen         — Login / registration
├── Home Screen         — Balance, quick actions
├── Virtual Cards       — Manage registered NFC cards
├── NFC Flow Screen     — Multi-step payment flow (amount → PIN → OTP → write)
├── NFC Unlock Screen   — PIN-based card arming before tap
├── Analytics Screen    — Transaction stats, benchmark comparisons, card health
└── Profile Screen      — User settings, sign out
```

State is managed using **Riverpod** (`flutter_riverpod`). The `UserProvider` holds the authenticated user state, transaction history, and virtual card list.

---

## 🔐 Authentication Tiers

Transactions are subject to tiered authentication based on amount:

| Amount Range | Auth Required |
|---|---|
| < ₱100 (micro) | Direct NFC write |
| ₱100 – ₱500 (low) | Direct NFC write |
| ₱500 – ₱1,000 (medium) | PIN required |
| ≥ ₱1,000 (high) | PIN + Email OTP |

---

## 🔒 Security Features

- **Java Card NFC tokenization** — payment token written to physical NFC card
- **Card revocation** — each card tracks use count and last tap; revoked cards are blocked
- **5-minute token expiry** — armed tokens auto-expire if not tapped at POS
- **Token payload integrity** — cryptographic hash included in every token (`crypto` package)
- **UUID-based transaction IDs** for non-repudiation

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter 3 (Dart SDK ^3.12.0) |
| State Management | Riverpod (`flutter_riverpod ^2.6.1`) |
| NFC | `nfc_manager ^4.2.1`, `ndef_record ^1.4.2` |
| Local Storage | `shared_preferences ^2.5.5` |
| Charts | `fl_chart ^0.68.0` |
| Fonts | Google Fonts — Inter |
| Crypto | `crypto ^3.0.6`, `uuid ^4.5.1` |
| UI | Material 3, dark theme, glassmorphism |

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK ≥ 3.12.0
- Dart SDK ≥ 3.12.0
- Android device or emulator with NFC support (for NFC features)

### Setup

```bash
# 1. Clone the repository
git clone https://github.com/hryvd/tapatan.git
cd tapatan/tapatan_app

# 2. Install dependencies
flutter pub get

# 3. Run on device
flutter run
```

> **Note:** NFC write functionality requires a physical device with NFC. The app falls back gracefully on simulators with a dev "Simulate POS tap" button.

---

## 📊 Analytics

The Analytics screen provides three tabs:

- **Overview** — Total transactions, success rate, NFC auth speed distribution, recent auth log, security assessment
- **Benchmark** — Side-by-side comparison of NFC Card vs SMS OTP vs Biometric authentication speed and reliability
- **Card Health** — Per-card memory usage, use count, applet version, last tap time

### Key Research Finding

> NFC Card authentication is **5.1× faster** than SMS OTP on average and achieves a **93.6% success rate** vs 81.8% for SMS OTP — while offering significantly stronger security due to physical possession requirements.

---

## 🗂️ Project Structure

```
lib/
├── main.dart
├── providers/
│   └── user_provider.dart
├── screens/
│   ├── auth_screen.dart
│   ├── home_screen.dart
│   ├── virtual_cards_screen.dart
│   ├── nfc_flow_screen.dart
│   ├── nfc_unlock_screen.dart
│   ├── analytics_screen.dart
│   ├── profile_screen.dart
│   ├── security_info_screen.dart
│   └── main_shell.dart
├── services/
│   ├── nfc_service.dart
│   └── card_revocation_service.dart
├── utils/
│   └── lucide_icons.dart
└── widgets/
    ├── glass_button.dart
    └── glass_container.dart
```

---

## 📄 License

This project is part of an academic thesis. All rights reserved.
