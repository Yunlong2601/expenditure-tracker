# Spend Snap (iPhone app, Android-ready)

An expense tracker for people who don't want to think about it. Everything
stays on your phone: no account, no server, no internet needed.

- **Payment screenshot**: pick the PayNow, GrabPay, Alipay, WeChat Pay or
  bank-app success screen. Most digital payments in Singapore leave one, so
  this is the main button.
- **Snap receipt**: take a photo of a paper receipt.
- **Paid cash? Type the amount**: type the number, tap a category, done.
  No receipt needed (hawker centres, kopitiams).

The iPhone reads the text itself with Apple's built-in text recognition (the
same one behind Live Text in Photos), in English and Chinese, even in flight
mode. The app then picks out the total, shop, date, currency (SGD, CNY, MYR,
USD) and a category. When it's confident it saves straight away with an Undo
button; when it isn't, it shows a "Quick check" with everything filled in.

Expenses are saved in the app's own folder on the phone together with the
receipt photos, and are included in your iPhone backup. Settings has a button
to copy everything as a spreadsheet (CSV).

**Limits of reading offline.** It works from patterns (the line that says
TOTAL, 合计 or 实付, the big number on a payment screen), so unusual layouts,
crumpled or faded receipts and handwriting will go to the Quick check more
often.

## Tasks, focus and countdowns

- **Today and Schedule** on the Pet tab: Schedule shows a week strip so you
  can plan any day. The magnifier searches every task, done or planned.
- **Repeats**: a task can come back every day, on weekdays or every week, and
  each day is ticked on its own. Countdowns can repeat every year, like
  birthdays, and a day that has passed counts the days since.
- **Reminders**: a task with a time rings at that time, and countdowns ring at
  9 am the day before and on the day. They are local notifications on the
  phone; quiet mode keeps them but makes them silent.
- **Focus**: a timer of 15, 25, 45 or any number of minutes, or a stopwatch.
  Start it from a task with *Focus on this*, and add rain, waves or fire
  sounds (made for this app, in `assets/sounds/`).
- **Dashboard**: done, not done, done rate and day streak, bars for the week,
  and focus totals for the day and the last seven days.

## Chat with the cat

Say "remind me at 8 to read", "add buy milk" or "每天晚上九点提醒我刷牙" and the
cat puts it on your list, on the phone, in English or Chinese.

The cat answers on the phone with short built-in replies. For a real AI chat,
set up the small Supabase function in [`supabase/`](../supabase/README.md) and
build with `--dart-define=CAT_AI_URL=...` and `--dart-define=CAT_AI_KEY=...`.
Spending and private tasks are never sent, and if the AI can't be reached the
cat goes back to on-phone replies.

## Put it on your iPhone

Apple only lets you install apps built on a Mac (or a cloud Mac).

**Option A: your own Mac (free).**
1. Install Xcode from the Mac App Store and [Flutter](https://docs.flutter.dev/get-started/install/macos).
2. `cd mobile && flutter pub get`
3. Open `ios/Runner.xcworkspace` in Xcode, select **Runner > Signing &
   Capabilities**, tick *Automatically manage signing*, and pick your Apple ID
   as the team. Change the bundle id if Xcode says it's taken.
4. Plug in your iPhone, then `flutter run --release`.
   With a free Apple ID the app has to be reinstalled every 7 days.

**Option B: TestFlight (US$99/year Apple Developer account).** Lasts 90 days per
build and installs like a normal app. You can build in the cloud with
[Codemagic](https://codemagic.io) if you don't have a Mac.

**Android later:** `flutter build apk --release` builds an installable APK from
the same code, and the GitHub Actions workflow builds one on every push. Reading
receipts on Android still needs its own text-recognition bridge (for example
Google ML Kit, which also runs on the phone); until then Android users type the
amount on the Quick check.

## Develop

```sh
cd mobile
flutter pub get
flutter analyze
flutter test
```

| File | What it does |
| --- | --- |
| `ios/Runner/AppDelegate.swift` | Reads the text in an image with Apple Vision, on the phone |
| `lib/receipt_parser.dart` | Finds total, shop, date, currency and category in that text |
| `lib/reader.dart` | Connects the two (`OfflineReader`) |
| `lib/ledger.dart` | Saves expenses and receipt photos on the phone, monthly totals, CSV |
| `lib/home_screen.dart` | Monthly total, the big buttons, recent expenses |
| `lib/review_sheet.dart` | "Quick check" shown only when the app is unsure |
| `lib/quick_add_sheet.dart` | Cash entry: amount + one tap on a category |
| `lib/settings_screen.dart` | Privacy note and spreadsheet export |
