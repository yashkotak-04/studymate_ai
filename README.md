# 🎓 StudyMate AI — Production Flutter Application

StudyMate AI is a modern, comprehensive, AI-powered study companion and exam-preparation platform built with **Flutter**, **Firebase**, and **Firebase AI Logic (Gemini 2.5 / 2.0 Flash)**.

Designed specifically for diploma and undergraduate engineering students, StudyMate AI transforms complex syllabi into digestible interactive tutoring, adaptive multiple-choice quizzes, timed mock exams, multimodal document summaries, weekly study timetables, and personalized performance analytics.

---

## 🚀 Key Features

* **🧠 AI Chat Tutor with 4 Explanation Modes**:
  * **Beginner**: Simplifies concepts with relatable everyday analogies and zero jargon.
  * **Student**: Standard university-level conceptual breakdowns.
  * **Exam**: Focuses strictly on high-scoring answers, key definitions, and exam rubrics.
  * **Viva**: Fast-paced, concise bullet points tailored for laboratory vivas and oral examinations.
  * **Voice Input**: Real-time speech-to-text recognition with live audio visualizer.
  * **Contextual Quick Actions**: Instant follow-ups ("Explain Simpler", "Give Example", "Real-world Analogy", "Generate MCQs", "Summarize").

* **📝 Practice MCQs & Timed Mock Exams**:
  * Customizable question sets by subject, topic, and difficulty (Easy, Medium, Hard).
  * Timed **Full-Length Mock Exam Mode** using canonical timed duration (`MockTestConfig`).
  * Interactive question palette, answer tracking, and review mode with AI explanations.
  * **Atomic & Idempotent Finalization**: Single-transaction Firestore ACID writes updating streaks, subject mastery, and daily stats without double-counting.

* **📑 Multimodal Document Summarization & PDF-to-Practice**:
  * Direct PDF & text document upload with file-size enforcement.
  * Structured **5-Section AI Breakdown**: Quick Summary, Important Points, Key Terms, Exam Focus Areas, and Revision Questions.
  * Instant **"Generate Quiz from Document"** pipeline.

* **📅 AI Study Planner**:
  * Generates an adaptive 7-day schedule (Morning/Evening tasks) based on enrolled courses, weak topics, and daily study goals.
  * Persistent interactive task checkboxes saved in real-time to Firestore.

* **📊 Analytics, Progress & Score Trends**:
  * Time-filtered analytics (**Week**, **Month**, **All Time**).
  * Chronological **Score Trend Line Chart** powered by `fl_chart`.
  * Subject Mastery horizontal/vertical bar charts.

* **💡 Personalized Recommendations (`/recommendations`)**:
  * Data-driven diagnostic signals analyzing weak subjects (<70% accuracy), unstudied enrolled courses, and exam timelines.
  * Explicit **Evidence**, **Reason**, and **Action** for each personalized item.

* **🔒 Security, Subjects & Account Management**:
  * Canonical user-scoped security architecture (`users/{uid}/...`).
  * 3-Way Theme selector (**System Default**, **Light**, **Dark**).
  * Comprehensive account deletion with complete Firestore data purging.

---

## 🛠️ Technology Stack

| Layer | Technologies |
|---|---|
| **Framework** | Flutter 3.44+ / Dart 3.10+ |
| **State Management** | Flutter Riverpod 2.6.1 (`flutter_riverpod`) |
| **Navigation** | GoRouter 14.8.1 (`go_router`) with redirect auth guards |
| **Backend & Cloud** | Firebase Core, Firebase Auth, Cloud Firestore, Firebase Storage |
| **AI Integration** | Firebase AI Logic (`firebase_ai`) using Gemini 2.5 / 2.0 Flash |
| **Reliability & Config** | Firebase App Check, Crashlytics, Remote Config, Analytics |
| **Charts & Visuals** | `fl_chart`, `lucide_icons_flutter`, `google_fonts` |
| **Hardware / Native** | `speech_to_text`, `file_picker`, `flutter_native_splash` |

---

## 📁 Repository Structure

```
studymate_ai/
├── .github/workflows/          # GitHub Actions CI pipeline
├── android/                    # Android native project configuration & Kotlin DSL
├── assets/images/              # Launcher icons & assets
├── firestore.indexes.json      # Composite Firestore indexes
├── firestore.rules             # User-scoped Firestore security rules
├── storage.rules               # Firebase Storage validation & upload rules
├── lib/
│   ├── app/
│   │   ├── router/             # GoRouter routes, redirects, and shell navigation
│   │   └── theme/              # Curated light/dark themes, color tokens, and typography
│   ├── core/
│   │   └── services/           # Firebase Service (Remote Config, Analytics, App Check),
│   │                           # AI Service (Gemini Logic, JSON parser), Notification Service
│   ├── features/
│   │   ├── ai_chat/            # AI Tutor chat UI, speech recognition & thread history
│   │   ├── auth/               # Login, Signup, Forgot Password, Onboarding
│   │   ├── dashboard/          # Home dashboard, subject cards, metrics summary
│   │   ├── planner/            # AI 7-day study timetable & task tracking
│   │   ├── practice/           # MCQ generator, Quiz engine, Mock exam timer & result review
│   │   ├── profile/            # Profile settings, subject enrollment, theme & security
│   │   ├── progress/           # Progress analytics, score trend charts & subject mastery
│   │   ├── recommendations/    # Actionable diagnostic study recommendations
│   │   └── summary/            # PDF notes summarizer, 5-section breakdown & quiz bridge
│   ├── shared/
│   │   ├── models/             # Domain models (Subject, Chat, Quiz, Summary, Plan, User)
│   │   ├── providers/          # Global theme and state providers
│   │   └── widgets/            # CustomButton, CustomCard, CustomChip, ProgressRing, ScreenHeader
│   ├── firebase_options.dart   # Platform Firebase configuration
│   └── main.dart               # Sequential bootstrap with App Check & fallback error screen
└── test/                       # Comprehensive unit and widget test suite (25+ passing tests)
```

---

## ⚙️ Getting Started & Local Setup

### 1. Prerequisites
- **Flutter SDK**: `^3.44.0`
- **Dart SDK**: `^3.10.0`
- **Java JDK**: 21 (Temurin)
- **Firebase CLI**: Install via `npm install -g firebase-tools` and run `firebase login`.

### 2. Clone & Install Dependencies
```bash
git clone https://github.com/yashkotak-04/studymate_ai.git
cd studymate_ai
flutter pub get
```

### 3. Link Real Firebase Project
To link your Firebase project and generate production credentials:
```bash
flutterfire configure --project=<YOUR_FIREBASE_PROJECT_ID>
```
Select **Android**, **iOS**, and **Web**. This will populate `lib/firebase_options.dart` and native configuration files (`google-services.json` and `GoogleService-Info.plist`).

### 4. Deploy Firestore & Storage Rules
```bash
firebase deploy --only firestore:rules,firestore:indexes,storage
```

---

## 🔧 Remote Config Parameters

StudyMate AI supports dynamic cloud configuration via **Firebase Remote Config**:

| Parameter Key | Default Value | Description |
|---|---|---|
| `ai_model_name` | `gemini-2.5-flash` | Gemini model identifier used for all AI operations |
| `max_pdf_size_mb` | `10` | Maximum allowable PDF / document upload size in megabytes |
| `max_summary_input_chars` | `20000` | Character limit for plain text notes summarization |
| `enable_ai_caching` | `true` | Enables client-side response caching |

---

## 🧪 Testing & Verification

Run the full automated test suite:
```bash
flutter test
```

Run static analysis:
```bash
flutter analyze
```

Format code check:
```bash
dart format --output=none --set-exit-if-changed .
```

---

## 📦 Building for Production

### Android Debug APK
```bash
flutter build apk --debug
```

### Android Release Bundle (Google Play)
1. Configure your release signing keystore in `android/key.properties`.
2. Run:
```bash
flutter build appbundle --release
```
Artifact output will be located at: `build/app/outputs/bundle/release/app-release.aab`.

---

## 📄 License
This project is proprietary and confidential. All rights reserved.
