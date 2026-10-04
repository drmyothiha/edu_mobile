# 📱 EduPlatform Mobile Application (`edu_mobile`)

The mobile client application for the **Myanmar AI Education Hub**, built with **Flutter** and **Dart** for Android and iOS.

Designed with an offline-first architecture, `edu_mobile` serves students, parents/guardians, teachers, and school staff with decentralized digital identities (W3C Verifiable Credentials), local SQLite curriculum caching, and real-time school communications.

---

## 🌐 Ecosystem Architecture

`edu_mobile` interacts with the centralized `edu_server` backend and pairs with `edu_desktop` kiosk terminals:

```
                          ┌──────────────────────────┐
                          │   edu_server (Go / DB)   │
                          │  REST API & DID Issuer   │
                          └─────────────┬────────────┘
                                        │ (HTTPS / SSE)
                 ┌──────────────────────┴──────────────────────┐
                 │                                             │
                 ▼                                             ▼
  ┌──────────────────────────────┐              ┌──────────────────────────────┐
  │   edu_desktop (Tauri/React)  │  QR Pairing  │    edu_mobile (Flutter)      │
  │   - Kiosk Gate Scanner       │◄────────────►│    - Student Identity Wallet │
  │   - Principal & Staff Portal │              │    - Parent Progress Monitor │
  └──────────────────────────────┘              │    - Teacher Field Scanner   │
                                                └──────────────────────────────┘
```

---

## ✨ Key Features by Role

### 🎓 Student Workspace
- **Decentralized Identity Wallet (`student_wallet_screen.dart`)**:
  - Securely holds tamper-evident **W3C Verifiable Credentials** (Student ID cards, Grade Records, Diplomas).
  - Cryptographically verifiable QR presentation for campus gate access and exam check-in without requiring an active internet connection.
- **Offline Curriculum Calendar (`student_curriculum_calendar_screen.dart`)**:
  - Local **SQLite** storage allows students to access their weekly class timetable, period rooms, and subject schedules completely offline.
- **Child Privacy Mode (`student_under13_screen.dart`)**:
  - COPPA / Child Safety compliant interface for primary school students with parental consent restrictions.

### 👨‍👩‍👧 Parent & Guardian Workspace
- **Guardian Dashboard (`guardian_dashboard_screen.dart`)**:
  - Real-time attendance monitoring (arrival/departure gate scan alerts).
  - Academic performance indicators, homework assignments, and teacher notes.
  - **Whole-Child Matrix**: Holistic child development assessments tracking health, physical growth, and early childhood milestones.

### 👩‍🏫 Teacher Workspace
- **Gate Verifier Scanner (`gate_verifier_screen.dart`)**:
  - Rapid camera-based QR scanner for taking student ingress/egress attendance at facility gates or field trips.
- **Scan History (`scan_history_screen.dart`)**:
  - Log of all student gate interactions with timestamps and status indicators.
- **Classroom Offline Sync (`classroom_sync_screen.dart`)**:
  - Caches student rosters locally and batches offline attendance entries, automatically synchronizing once Wi-Fi or mobile data becomes available.

### 🛡️ Admin & Kiosk Utility
- **Kiosk Pairing Scanner (`kiosk_pairing_scanner_screen.dart`)**:
  - Securely binds mobile handheld scanners to desktop gate kiosk terminals via encrypted pairing tokens.

### ⚡ Platform Utilities
- **Configurable Server Gateway (`server_settings_screen.dart`)**:
  - Allows switching between cloud clusters, local school LAN microservers (e.g., Raspberry Pi or local Go instances), or staging environments.
- **Real-Time SSE Notifications (`sse_notification_service.dart`)**:
  - Low-latency Server-Sent Events delivering instant campus emergency alerts and attendance notifications.
- **In-App Messaging (`chat_screen.dart`)**:
  - Real-time messaging between teachers, guardians, and school administrators.

---

## 🛠️ Tech Stack

| Category | Technology |
| :--- | :--- |
| **Framework** | [Flutter 3.x](https://flutter.dev/) |
| **Language** | [Dart](https://dart.dev/) |
| **Local Database** | [sqflite](https://pub.dev/packages/sqflite) (SQLite for mobile) |
| **Cryptography** | Ed25519, SHA-256, W3C DID verification |
| **State Management** | Provider / State Notifiers |
| **Hardware Access** | Camera & QR Code Scanning |
| **Real-Time** | Server-Sent Events (SSE) & HTTP Streaming |
| **Platforms** | Android (API 21+) & iOS (12.0+) |

---

## 📂 Project Structure

```
edu_mobile/
├── android/                        # Native Android project configuration
├── ios/                            # Native iOS project configuration
├── pubspec.yaml                    # Flutter dependencies and assets
├── pubspec.lock                    # Locked dependency versions
├── test/                           # Automated unit, widget, and RBAC tests
│   ├── crypto_test.dart            # Ed25519 & DID signature tests
│   ├── rbac_test.dart              # Role-Based Access Control logic tests
│   ├── role_routing_test.dart      # Dynamic role router tests
│   ├── server_settings_test.dart   # Server configuration persistence tests
│   └── timetable_sqlite_test.dart  # Offline SQLite database tests
└── lib/
    ├── main.dart                   # Application entrypoint & dependency injection
    ├── admin/                      # School Admin & Kiosk pairing screens
    ├── parents/                    # Guardian dashboard & child monitoring screens
    ├── students/                   # Student ID wallet, timetable & profile screens
    ├── teacher/                    # Teacher gate verifier & attendance sync screens
    ├── screens/                    # Shared screens (Login, Chat, Notifications, Settings)
    ├── models/                     # Data models (Verifiable Credentials, Roles, Timetables)
    ├── routes/                     # Declarative routing & role guards (app_router.dart)
    ├── services/                   # Business services & network layers
    │   ├── api_service.dart        # REST API client for edu_server
    │   ├── crypto_service.dart     # W3C DID & Ed25519 cryptographic validator
    │   ├── jwt_decoder.dart        # JWT token inspection & role extraction
    │   ├── sqlite_timetable_helper.dart # Local SQLite persistence layer
    │   ├── sse_notification_service.dart# Server-Sent Events listener
    │   ├── storage_service.dart    # Encrypted local key-value storage
    │   └── timetable_storage_service.dart # Timetable synchronization service
    └── theme/                      # App theme, typography & color palettes
```

---

## 🚀 Getting Started

### Prerequisites

1. **Flutter SDK**: v3.22.0 or higher ([Install Flutter](https://docs.flutter.dev/get-started/install))
2. **Dart SDK**: Bundled with Flutter
3. **Android**: Android Studio with Android SDK (API 34), build-tools, and emulator
4. **iOS** (macOS only): Xcode 15+ and CocoaPods

Verify your setup:
```bash
flutter doctor
```

---

### Installation

Clone the repository and install dependencies:

```bash
cd edu_mobile
flutter pub get
```

---

### Running in Development

Connect a physical device or start an emulator/simulator, then run:

```bash
flutter run
```

To run on a specific target:
```bash
# List available devices
flutter devices

# Run on specific device ID
flutter run -d <device-id>
```

---

### Running Tests

Execute the complete automated test suite:

```bash
flutter test
```

Run specific test suites:
```bash
flutter test test/crypto_test.dart
flutter test test/rbac_test.dart
flutter test test/timetable_sqlite_test.dart
```

---

### Building for Production

#### Build Android APK / App Bundle:
```bash
# Standalone release APK (split per ABI or fat)
flutter build apk --release

# Google Play App Bundle (AAB)
flutter build appbundle --release
```
Outputs: `build/app/outputs/flutter-apk/app-release.apk`.

#### Build iOS Release:
```bash
flutter build ipa --release
```
Outputs: `build/ios/archive/Runner.xcarchive`.

---

## ⚙️ Server Configuration

To point `edu_mobile` to your running backend:
1. Open the app and navigate to **Settings** -> **Server Configuration** (or click the settings gear on the login screen).
2. Enter your backend host (e.g. `http://192.168.1.100:8080` for a local network server, or `https://api.yourdomain.com`).
3. Tap **Save & Test Connection**.

---

## 📄 License

Proprietary — Myanmar AI Education Hub Platform.
