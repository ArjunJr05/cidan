# CIDAN - Regulatory Compliance & Policy AI Engine

[![Pub Version](https://img.shields.io/pub/v/cidan.svg)](https://pub.dev/packages/cidan)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Platform-Flutter%20%7C%20Android%20%7C%20iOS%20%7C%20Web-02569B.svg?logo=flutter)](https://flutter.dev)

**CIDAN** is an enterprise-grade AI engine for regulatory circular ingestion, policy gap validation, control delta mapping, and compliance auditing in Flutter applications. 

With CIDAN, developers can embed a complete automated compliance ingestion and validation workflow into any Flutter app with a single method call: `cidan.application()`.

---

## 🌟 Key Features

- **⚡ Instant 1-Line Embedding:** Drop the complete regulatory compliance suite into your app with `cidan.application()`.
- **📄 Regulatory Circular Ingestion:** Supports upload and analysis of circulars (PDF, TXT, DOCX) up to 25MB.
- **🔍 Automated Obligation Extraction:** Identifies mandatory checkpoints and regulatory thresholds.
- **⚖️ Policy Gap & Control Delta Mapping:** Compares circular requirements against internal underwriting handbooks.
- **🧪 Sandbox Verification Testcases:** Executes automated verification tests (PASS / FLAGGED / FAIL).
- **💾 Local Storage Report Export:** Generates executive regulatory audit reports and saves directly to device storage.
- **🔐 Enterprise Session & History:** Integrates with Supabase for persistent audit trail logging and live OTP verification.

---

## 🚀 Getting Started

### 1. Add Dependency

Add `cidan` to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  cidan: ^1.0.0
```

Or run:

```bash
flutter pub add cidan
```

---

## 💻 Usage

### Option A: Run as Standalone App

Replace your `main()` function to launch CIDAN directly:

```dart
import 'package:flutter/material.dart';
import 'package:cidan/cidan.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(cidan.application());
}
```

### Option B: Embed into an Existing Flutter App

Navigate to the CIDAN compliance suite from any screen in your existing app:

```dart
import 'package:flutter/material.dart';
import 'package:cidan/cidan.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Banking App')),
      body: Center(
        child: ElevatedButton.icon(
          onPressed: () {
            // Open CIDAN inside your existing app's navigation
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => cidan.application(standalone: false),
              ),
            );
          },
          icon: const Icon(Icons.security_rounded),
          label: const Text('Open CIDAN Compliance AI'),
        ),
      ),
    );
  }
}
```

### Option C: Pre-Authenticated Enterprise Session

If your user is already signed in within your parent app, pass their email to skip login:

```dart
cidan.application(
  userEmail: 'compliance.officer@bank.com',
  isLoggedIn: true,
  standalone: false,
);
```

### Option D: Custom Supabase Backend

You can optionally supply your own Supabase project endpoint:

```dart
cidan.application(
  supabaseUrl: 'https://your-project.supabase.co',
  supabaseAnonKey: 'your-anon-key',
);
```

---

## ⚙️ Platform Permissions

### Android
In `android/app/src/main/AndroidManifest.xml`, ensure network and storage permissions are declared:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>
</manifest>
```

### iOS
In `ios/Runner/Info.plist`:

```xml
<key>UISupportsDocumentBrowser</key>
<true/>
<key>LSSupportsOpeningDocumentsInPlace</key>
<true/>
```

---

## 📦 Exported Modules

In addition to `cidan.application()`, the package exports granular models and services:

- `ComplianceReportModel`: Parsed response model for circular obligations, testcases, and findings.
- `SupabaseService`: Centralized backend database and live history auditor.
- `CidanApiService`: API client for regulatory document processing.
- `ComplianceDashboardScreen`: Full compliance audit review and sign-off dashboard.
- `UploadDocumentScreen`: Circular upload, analysis video playback, and recent history viewer.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
