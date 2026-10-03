# 🌟 LUMORA — Mental Wellness & AI Companion App

LUMORA is a cross-platform Flutter application designed to support mental health and personal wellness. It combines AI-powered tools, community features, sleep tracking, daily routines, and professional therapist connectivity into a single, beautifully designed experience.

---

## ✨ Features

| Feature | Description |
|---|---|
| 🤖 **AI Chat (Lumora AI)** | Conversational AI powered by Google Gemini for journaling prompts, emotional support, and guidance |
| 🧠 **Care Hub** | Personalized mental health resource recommendations using AI |
| 📔 **Journal** | Create and manage private personal journal entries |
| 📋 **My Tasks** | To-do and wellness task management with daily tracking |
| ⏰ **Daily Routine** | Build and track structured daily routines powered by AI suggestions |
| 😴 **Sleep Dashboard** | Log and visualize sleep patterns and quality trends |
| 🆘 **Crisis Mode** | Immediate access to crisis resources and emergency contacts |
| 🌍 **Community** | Post, comment, and connect with a supportive mental health community |
| 👩‍⚕️ **Therapist Portal** | A separate dashboard for therapists to manage patients and chats |
| 💬 **Professional Chat** | Real-time messaging between users and their assigned therapists |
| 🗺️ **Map Picker** | Find nearby mental health resources and clinics using Google Maps |

---

## 🛠️ Tech Stack

- **Framework**: [Flutter](https://flutter.dev) (Dart SDK `^3.11.1`)
- **Backend & Auth**: [Firebase](https://firebase.google.com) (Authentication, Firestore)
- **AI**: [Google Generative AI (Gemini)](https://pub.dev/packages/google_generative_ai)
- **Maps**: google_maps_flutter + geocoding
- **Charts**: fl_chart
- **Speech**: speech_to_text
- **Fonts**: Google Fonts
- **Video**: youtube_explode_dart

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Dart SDK `^3.11.1`)
- A Firebase project with **Authentication** and **Firestore** enabled
- A **Google Gemini API Key** from [Google AI Studio](https://aistudio.google.com)
- For Android: Android Studio or ADB installed
- For iOS: Xcode (macOS only)

---

### 1. Clone the repository

```bash
git clone <your-repo-url>
cd lumora
```

### 2. Set up environment variables

Create a `.env` file in the **root** of the project:

```env
GEMINI_API_KEY=your_actual_gemini_api_key_here
```

> ⚠️ **Never commit this file to Git.** It is already listed in `.gitignore`.

### 3. Configure Firebase

Run the FlutterFire CLI to connect your Firebase project:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

This will generate `lib/firebase_options.dart` automatically.

### 4. Install dependencies

```bash
flutter pub get
```

### 5. Run the app

**On a connected Android/iOS device:**
```bash
flutter run
```

**On a specific device:**
```bash
flutter devices              # list connected devices
flutter run -d <device_id>
```

**On Chrome (web):**
```bash
flutter run -d chrome
```

---

## 📱 Running on a Physical Phone via USB

### Android

1. **Enable Developer Options**: Go to *Settings → About Phone* and tap **Build Number** 7 times.
2. **Enable USB Debugging**: Go to *Developer Options* and toggle on **USB Debugging**.
3. Connect your phone via USB cable and tap **Allow** when prompted on the phone.
4. Verify Flutter detects your device:
   ```bash
   flutter devices
   ```
5. Run the app:
   ```bash
   flutter run
   ```

### iOS

1. **Enable Developer Mode**: Go to *Settings → Privacy & Security → Developer Mode* and turn it on (requires a restart).
2. Trust your computer on the device when prompted.
3. Open `ios/Runner.xcworkspace` in **Xcode**, set your Apple Team under *Signing & Capabilities*.
4. Run:
   ```bash
   flutter run
   ```

---

## 📁 Project Structure

```
lumora/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── firebase_options.dart        # Firebase config (auto-generated, do not commit)
│   ├── screens/                     # All UI screens
│   │   ├── home_screen.dart
│   │   ├── ai_chat_screen.dart
│   │   ├── care_hub_screen.dart
│   │   ├── journal_screen.dart
│   │   ├── sleep_dashboard_screen.dart
│   │   ├── community_screen.dart
│   │   ├── therapist_dashboard_screen.dart
│   │   ├── crisis_mode_screen.dart
│   │   └── ...
│   ├── services/                    # Business logic & API calls
│   │   ├── auth_service.dart
│   │   ├── firestore_service.dart
│   │   ├── care_hub_service.dart
│   │   ├── sleep_storage_service.dart
│   │   └── ...
│   ├── models/                      # Data models
│   ├── widgets/                     # Reusable UI components
│   └── theme/                       # App-wide theming
├── assets/
│   └── icons/                       # App icons
├── android/                         # Android-specific configuration
├── ios/                             # iOS-specific configuration
├── .env                             # 🔒 Secret API keys (never commit this)
└── pubspec.yaml                     # Dependencies & assets manifest
```

---

## 🔑 Environment Variables

| Variable | Description |
|---|---|
| `GEMINI_API_KEY` | Your Google Gemini API Key from [AI Studio](https://aistudio.google.com) |

---

## 👥 User Roles

LUMORA supports two types of users:

- **Patient / User** — Access to all wellness features: AI chat, journal, tasks, routine builder, sleep tracking, community, and crisis resources.
- **Therapist** — A dedicated dashboard to manage assigned patients, track their progress, and communicate via a real-time professional chat.

---

## ⚠️ Troubleshooting

| Problem | Solution |
|---|---|
| `.env` file not found on build | Create a `.env` file in the project root with your `GEMINI_API_KEY` |
| Device not detected by Flutter | Enable USB Debugging on your phone; run `flutter doctor` to diagnose |
| Firebase initialization error | Run `flutterfire configure` to regenerate `lib/firebase_options.dart` |
| Build failures / dependency issues | Run `flutter clean && flutter pub get` then try again |
| Outdated packages warning | Run `flutter pub outdated` to review available upgrades |

---

## 📄 License

This project is private and not published to pub.dev.
