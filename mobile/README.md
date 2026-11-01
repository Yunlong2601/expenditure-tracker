# Spend Snap (iPhone app, Android-ready)

A Flutter app for the receipt scanner in [`firefly/`](../firefly). Built for
logging expenses with as little effort as possible:

- **Payment screenshot**: pick the PayNow, GrabPay, Alipay, WeChat Pay or
  bank-app success screen. Most digital payments in Singapore leave one, so
  this is the main button.
- **Snap receipt**: take a photo of a paper receipt.
- **Paid cash? Type the amount**: type the number, tap a category, done.
  No receipt needed (hawker centres, kopitiams).

It saves on its own when the scanner is confident. It only shows a
"Quick check" screen when it couldn't read something, with everything already
filled in. The home screen shows one big number, what you've spent this month,
plus where it went and your recent expenses.

The server address and access key are stored in the iPhone Keychain (Android
Keystore on Android).

## Before you start

The receipt scanner from [`firefly/`](../firefly) must be running and reachable
from your phone (see "Using it from your phone" in that README). In the app
you enter its address, e.g. `http://100.64.0.5:8082`, and your
`RECEIPTS_API_KEY`.

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
the same code. The GitHub Actions workflow already builds one on every push.

## Develop

```sh
cd mobile
flutter pub get
flutter analyze
flutter test
```

| File | What it does |
| --- | --- |
| `lib/api.dart` | Talks to the receipt scanner (`/api/receipt`, `/api/expense`, `/api/expenses`) |
| `lib/home_screen.dart` | Monthly total, the big buttons, recent expenses |
| `lib/review_sheet.dart` | "Quick check" shown only when the scanner is unsure |
| `lib/quick_add_sheet.dart` | Cash entry: amount + one tap on a category |
| `lib/settings_screen.dart` | Server address and access key |
