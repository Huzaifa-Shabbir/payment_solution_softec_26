# 💼 DueDesk — Payment Follow-Up & Creditor Management

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-3.35.0+-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.11.1+-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-2.12.4-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)
![Gemini](https://img.shields.io/badge/Gemini_AI-Integrated-4285F4?style=for-the-badge&logo=google&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web-lightgrey?style=for-the-badge)

**Built for SOFTEC '26 — National Competition Project**

*A smart, offline-first Flutter app for small businesses to track creditors, schedule follow-ups, and recover payments — with AI-powered message generation via Gemini.*

</div>

---

## 📸 Overview

DueDesk helps businesses stay on top of their payment collections. Whether you're a small retailer or a freelancer, DueDesk gives you a clean dashboard to manage who owes you, when payments are due, and how to follow up — complete with WhatsApp & email integration and AI-generated reminder messages.

---

## ✨ Features

### 🏠 Dashboard
- Real-time **overdue payment summary** with live amounts
- Filter creditors by **All / Overdue / Pending** with color-coded status dots
- Search across name, email, and phone in one bar
- Priority-sorted list: overdue → pending → done
- Pull-to-refresh with Supabase sync

### 👥 Creditor Management
- Add, edit, and delete creditors with full form validation
- Fields: Name, Phone, Email, Amount, Due Date
- **Status auto-computation**: Overdue / Pending / Done based on real-time date logic
- Smooth bottom-sheet modal with slide-up animation

### 📩 Follow-Up Actions (per Creditor)
- **3 message templates** with tab switcher:
  - 🟢 Initial Contact
  - 🟡 Follow-Up Reminder
  - 🔴 Final Notice
- Template variables: `{name}`, `{amount}`, `{client}`, `{overdue}`
- One-tap **WhatsApp** launch with pre-filled message
- **Email** client launch with subject + body pre-filled
- **Call** button directly opens the phone dialer
- Copy-to-clipboard for any message draft
- Inline draft editor with toggle edit/save

### 🤖 Gemini AI Integration *(Planned / Extensible)*
> DueDesk is architected to integrate **Google Gemini AI** for intelligent follow-up message generation. The message generator module (`lib/features/followups/message_generator.dart`) is designed as a plug-in point for Gemini's API.

**Planned Gemini-powered capabilities:**
- **Smart message generation** — Gemini analyzes creditor history (amount, overdue days, previous contact attempts) and generates personalized, tone-appropriate follow-up messages
- **Tone calibration** — Gentle nudge for 1-day overdue, firm reminder for 30+ days, formal legal-tone for 90+ days
- **Auto-reply suggestions** — When a creditor responds, Gemini suggests contextual replies
- **Payment risk scoring** — AI-estimated likelihood of recovery based on account history
- **Batch reminder scheduling** — Gemini suggests optimal send times based on creditor timezone and communication pattern

**Integration point:**
```dart
// lib/features/followups/message_generator.dart
// Drop in Gemini API call here:
Future<String> generateFollowUpMessage(Account account, MessageType type) async {
  // POST to Gemini API with account context
  // Returns AI-crafted, personalized follow-up message
}
```

### 📊 Analytics Screen
- **Total Pending** and **Overdue** summary cards
- **Recovery Rate** percentage with visual breakdown
- 6-month **Pending vs Overdue** bar chart (custom-built, no external chart lib)
- **Recovery Rate Over Time** trend chart
- **Performance Metrics**: customer count, total amount, amount collected, overdue count
- **Top Defaulters** list ranked by overdue amount

### 🔔 Paid Credits Screen
- Dedicated view for all settled accounts
- **Total Paid** summary card with gradient design
- Swipe-to-delete with confirmation dialog

### ⚙️ Settings
- Edit all 3 message templates (Initial, Follow-Up, Final)
- Templates persist across sessions via SharedPreferences
- Live placeholder reference shown in editor

---

## 🏗️ Architecture

```
lib/
├── main.dart                          # App entry, GoRouter config, AccountStore init
├── splash_Screen.dart                 # Animated fade-in splash
│
├── core/
│   └── utils/
│       ├── app_messenger.dart         # Global ScaffoldMessengerKey
│       └── state_Management.dart      # AccountStore (ChangeNotifier) + InheritedWidget
│
├── features/
│   ├── accounts/
│   │   ├── account_model.dart         # Account domain model + validation
│   │   ├── account_repository.dart    # Local + Supabase CRUD with smart merge
│   │   ├── account_repository_helpers.dart  # Extension methods (upsertLocal, syncFromSupabase)
│   │   ├── account_list_screen.dart   # Paid credits screen
│   │   ├── account_follow_up_screen.dart    # Creditor detail + message drafting
│   │   ├── add_account_screen.dart    # Add/Edit bottom sheet
│   │   └── accounts_snackbar.dart     # Styled success/error snackbars
│   │
│   ├── core/
│   │   └── Theme.dart                 # AppColors + AppTheme
│   │
│   ├── dashboard/
│   │   ├── dashboard_screen.dart      # Main dashboard with filters + list
│   │   └── account_tile.dart          # Reusable creditor card widget
│   │
│   ├── followups/
│   │   ├── followup_engine.dart       # [Extensible: scheduler logic]
│   │   ├── followup_model.dart        # [Extensible: followup data model]
│   │   ├── message_generator.dart     # [Gemini AI integration point]
│   │   └── reminders_screen.dart      # [Extensible: reminders UI]
│   │
│   ├── notifications/
│   │   └── whatsapp_service.dart      # [Extensible: notification hooks]
│   │
│   ├── reports/
│   │   └── analytics_screen.dart      # Full analytics with custom charts
│   │
│   └── setting/
│       └── setting.dart               # Message template editor
│
└── services/
    ├── local_storage.dart             # SharedPreferences wrapper + debug logging
    ├── supabase_service.dart          # Supabase initialization
    └── whatsapp_service.dart          # WhatsApp URL launcher + phone formatter
```

### State Management Pattern

```
AccountStore (ChangeNotifier)
    └── AccountStoreProvider (InheritedNotifier)
            └── All screens consume via AccountStoreProvider.of(context)
```

No external state management library required — clean vanilla Flutter with `ChangeNotifier` + `InheritedNotifier`.

---

## 🔄 Data Sync Strategy

DueDesk uses a **local-first, cloud-synced** approach:

1. **Local storage** (SharedPreferences as JSON) is the source of truth for the UI
2. On startup and after every mutation, `printMergedUniqueCustomers()` runs a **3-way merge**:
   - Remote-only records → pulled into local
   - Local-only records → pushed to Supabase
   - Matched records (by email or phone) → merged with local values preferred
3. Remote operations are **best-effort** — local changes always persist even when offline

```
Add / Update / Delete
      ↓
  Local Save  ←──── Always succeeds
      ↓
  Supabase Upsert  ←──── Best-effort, swallowed on failure
      ↓
  3-Way Merge Reconcile
```

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK `>=3.35.0`
- Dart SDK `>=3.11.1`
- A Supabase project (see [supabase.com](https://supabase.com))

### 1. Clone the Repository

```bash
git clone https://github.com/your-username/duedesk.git
cd duedesk
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Configure Supabase

Update `lib/services/supabase_service.dart` with your own credentials:

```dart
await Supabase.initialize(
  url: "YOUR_SUPABASE_URL",
  anonKey: "YOUR_ANON_KEY",
);
```

### 4. Run Database Migrations

Apply migrations from the `supabase/migrations/` folder in your Supabase dashboard or via the CLI:

```bash
supabase db push
```

### 5. Run the App

```bash
flutter run
```

---

## 🗄️ Database Schema

```sql
-- customers table
CREATE TABLE customers (
  id            TEXT PRIMARY KEY,
  name          TEXT NOT NULL,
  email         TEXT,
  phone         TEXT,
  amount        NUMERIC,
  due_Date      DATE,
  last_Follow_Up_Date DATE,
  status        TEXT DEFAULT 'Pending'
);

-- reminder_logs table (for scheduled reminders)
CREATE TABLE reminder_logs (
  id            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  customer_id   TEXT REFERENCES customers(id),
  sent_at       TIMESTAMPTZ DEFAULT NOW(),
  message_type  TEXT,
  channel       TEXT
);
```

---

## 📦 Dependencies

| Package | Version | Purpose |
|---|---|---|
| `supabase_flutter` | ^2.12.4 | Cloud database sync |
| `go_router` | ^17.2.1 | Declarative navigation |
| `intl` | ^0.20.2 | Date/currency formatting |
| `http` | ^1.6.0 | HTTP client for API calls |
| `shared_preferences` | transitive | Local key-value persistence |
| `url_launcher` | transitive | WhatsApp, email, phone dialer |

---

## 🔧 Automated Reminders (GitHub Actions)

The project includes a GitHub Actions workflow (`.github/workflows/scheduled-reminders.yml`) and a Supabase Edge Function (`supabase/functions/send-due-reminders/index.ts`) for scheduled reminder dispatch.

The workflow triggers on a cron schedule to invoke the Edge Function, which queries overdue customers and dispatches reminder notifications.

---

## 🧪 Testing

```bash
# Run all tests
flutter test

# Run specific test
flutter test test/features/accounts/account_model_test.dart
```

Test coverage includes:
- `AccountModel` validation (id, name, phone, email, amount, dates)
- Edge cases: empty fields, invalid email, negative amount, NaN values
- Legacy status mapping (`paid` / `done` → `isPaid: true`)

---

## 🌐 Platform Support

| Platform | Status |
|---|---|
| Android | ✅ Fully supported |
| iOS | ✅ Fully supported |
| Web | ✅ Build configured |
| macOS | ✅ Build configured |
| Linux | ✅ Build configured |
| Windows | ✅ Build configured |

---

## 🛣️ Roadmap

- [x] Core CRUD with local + Supabase sync
- [x] WhatsApp / Email / Call integration
- [x] Analytics dashboard with custom charts
- [x] Customizable message templates
- [ ] **Gemini AI message generation** (smart, tone-aware follow-ups)
- [ ] Push notifications via FCM
- [ ] PDF invoice generation
- [ ] Multi-currency support
- [ ] Dark mode
- [ ] CSV / Excel export
- [ ] Reminder scheduling with local notifications

---

## 👤 Author

**Huzaifa Shabbir**
- Student — FAST-NUCES Lahore (23L-0647)
- Built for **SOFTEC '26**

---

## 📄 License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

<div align="center">

Made with ❤️ using Flutter & Supabase

*DueDesk — Because chasing payments shouldn't feel like a full-time job.*

</div>
