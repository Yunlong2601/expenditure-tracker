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

## Study mode

Start studying opens a full-screen view with the clock and the cat, and keeps
the screen on. Pick a subject (Study, Homework, Reading, Revision, or a task)
and what happens if you leave the app:

- **Nudge me**: the clock pauses while you're away and the cat sends a
  notification to call you back.
- **Strict**: like Forest, leave for more than 15 seconds and the session ends
  and doesn't count.
- **Lock me in**: Strict, plus the iPhone's own Guided Access, which keeps the
  phone on this app until a passcode is entered. The app shows how to turn it
  on once in Settings; then a triple-click of the side button locks it.

Pulling down Control Center or a notification doesn't count as leaving.
Study time is tracked per subject, with today, the last 7 days, how often you
left, and a list of recent sessions. Blocking other apps by name, as Opal
does, needs Apple's Screen Time permission (the Family Controls entitlement),
which Apple has to approve for TestFlight or the App Store.

**Study together** is for friends sitting side by side. One of them picks a
length and makes a 4-digit code; the others type it in, and every timer
starts at the same minute, a minute or two later. The code only says when to
start and for how long, and each phone's clock is already right, so nothing
goes online and nobody needs an account.

The app follows the phone's language and light or dark mode until you pick
others in Me.

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

The Home Screen widget shares today's tasks with the app through an App Group
(`group.com.shenetic.purrse`), and Apple only allows App Groups on a paid
Apple Developer account (US$99/year). A free Apple ID can't sign this app any
more.

**Option A: your own Mac.**
1. Install Xcode from the Mac App Store and [Flutter](https://docs.flutter.dev/get-started/install/macos).
2. `cd mobile && flutter pub get`
3. Open `ios/Runner.xcworkspace` in Xcode. For both the **Runner** and the
   **TodayWidgetExtension** targets, open **Signing & Capabilities**, tick
   *Automatically manage signing* and pick your team. Xcode registers the App
   Group for you.
   If Xcode says the bundle id or the App Group is taken, change both: the
   bundle ids (the widget's must start with the app's), and the group in
   `Runner/Runner.entitlements`, `TodayWidget/TodayWidget.entitlements`,
   `Runner/AppDelegate.swift` and `TodayWidget/TodayWidget.swift`.
4. Plug in your iPhone, then `flutter run --release`.
5. Touch and hold the Home Screen, tap **Edit > Add Widget**, and pick
   Tiny Habits Cat.

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
