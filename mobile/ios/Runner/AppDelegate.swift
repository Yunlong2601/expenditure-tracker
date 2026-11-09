import AVFoundation
import Flutter
import UIKit
import UniformTypeIdentifiers
import UserNotifications
import Vision
import WidgetKit

/// The app's name as the Home Screen shows it, in the phone's language:
/// Purrpose, or 喵学伴 in Chinese.
let appTitle =
  Bundle.main.localizedInfoDictionary?["CFBundleDisplayName"] as? String
  ?? Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
  ?? "Purrpose"

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SpendSnapText") {
      ReceiptText.register(messenger: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SpendSnapFeel") {
      Feel.register(registrar: registrar)
      Remind.register(messenger: registrar.messenger())
      Share.register(messenger: registrar.messenger())
      Study.register(messenger: registrar.messenger())
      TodayWidgetBridge.register(messenger: registrar.messenger())
    }
  }
}

/// Reads the text in a receipt photo or payment screenshot with Apple's
/// on-device Vision framework. Nothing leaves the phone.
///
/// Returns one entry per line, top to bottom: ["text": String, "height": Double],
/// where height is the text height as a fraction of the image height.
enum ReceiptText {
  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "spendsnap/text", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "read" else { return result(FlutterMethodNotImplemented) }
      guard let data = (call.arguments as? FlutterStandardTypedData)?.data,
        let image = UIImage(data: data), let cg = image.cgImage
      else {
        return result(FlutterError(code: "bad_image", message: "Not an image", details: nil))
      }
      let orient = orientation(image)
      DispatchQueue.global(qos: .userInitiated).async {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US", "zh-Hans", "zh-Hant"]
        let handler = VNImageRequestHandler(cgImage: cg, orientation: orient, options: [:])
        do {
          try handler.perform([request])
          let lines = group(request.results ?? [])
          DispatchQueue.main.async { result(lines) }
        } catch {
          DispatchQueue.main.async {
            result(FlutterError(code: "read_failed", message: error.localizedDescription, details: nil))
          }
        }
      }
    }
  }

  /// Vision returns separate boxes for "TOTAL" and "12.80" on the same printed
  /// line; join boxes that sit at the same height, left to right.
  private static func group(_ boxes: [VNRecognizedTextObservation]) -> [[String: Any]] {
    let items: [(text: String, box: CGRect)] = boxes.compactMap {
      guard let t = $0.topCandidates(1).first?.string, !t.isEmpty else { return nil }
      return (t, $0.boundingBox)
    }
    // Vision's origin is bottom-left, so a higher midY is nearer the top.
    let sorted = items.sorted { $0.box.midY > $1.box.midY }
    var rows: [[(text: String, box: CGRect)]] = []
    for item in sorted {
      if let last = rows.last?.last,
        abs(last.box.midY - item.box.midY) < min(last.box.height, item.box.height) * 0.5
      {
        rows[rows.count - 1].append(item)
      } else {
        rows.append([item])
      }
    }
    return rows.map { row in
      let ordered = row.sorted { $0.box.minX < $1.box.minX }
      return [
        "text": ordered.map { $0.text }.joined(separator: "  "),
        "height": Double(ordered.map { $0.box.height }.max() ?? 0),
      ]
    }
  }

  private static func orientation(_ image: UIImage) -> CGImagePropertyOrientation {
    switch image.imageOrientation {
    case .up: return .up
    case .down: return .down
    case .left: return .left
    case .right: return .right
    case .upMirrored: return .upMirrored
    case .downMirrored: return .downMirrored
    case .leftMirrored: return .leftMirrored
    case .rightMirrored: return .rightMirrored
    @unknown default: return .up
    }
  }
}

/// Plays the app's short interface sounds and the system success/warning
/// haptics. Sounds use the media volume, mix with her music, and stay quiet
/// when the silent switch is on.
enum Feel {
  /// A few players per sound, so quick taps in a row each get their pop.
  private static var players: [String: [AVAudioPlayer]] = [:]
  private static var sessionReady = false

  static func register(registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "spendsnap/feel", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "play":
        if let asset = call.arguments as? String { play(registrar.lookupKey(forAsset: asset)) }
      case "loop":
        if let asset = call.arguments as? String { loop(registrar.lookupKey(forAsset: asset)) }
      case "stopLoop":
        looping?.stop()
        looping = nil
      case "success":
        UINotificationFeedbackGenerator().notificationOccurred(.success)
      case "warning":
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
      default:
        return result(FlutterMethodNotImplemented)
      }
      result(nil)
    }
  }

  /// The calm sound playing under a focus session, if any.
  private static var looping: AVAudioPlayer?

  private static func readySession() {
    if sessionReady { return }
    // Ambient: obeys the silent switch and doesn't stop her music.
    try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
    try? AVAudioSession.sharedInstance().setActive(true)
    sessionReady = true
  }

  /// Plays a sound over and over, softly, until "stopLoop".
  private static func loop(_ key: String) {
    readySession()
    looping?.stop()
    looping = nil
    guard let path = Bundle.main.path(forResource: key, ofType: nil),
      let player = try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
    else { return }
    player.numberOfLoops = -1
    player.volume = 0.6
    player.play()
    looping = player
  }

  private static func play(_ key: String) {
    readySession()
    if players[key] == nil, let path = Bundle.main.path(forResource: key, ofType: nil) {
      let url = URL(fileURLWithPath: path)
      players[key] = (0..<3).compactMap { _ in
        let p = try? AVAudioPlayer(contentsOf: url)
        p?.prepareToPlay()
        return p
      }
    }
    guard let pool = players[key], !pool.isEmpty else { return }
    let player = pool.first { !$0.isPlaying } ?? pool[0]
    player.currentTime = 0
    player.play()
  }
}

/// The cat's evening reminder: one local notification per day for the next
/// week, at her chosen time. Nothing is sent anywhere.
enum Remind {
  private static let ids = (0..<7).map { "evening-\($0)" }
  private static let lines = [
    "Meow! Did you spend anything today?",
    "Psst... any bubble tea today? Log it in 3 seconds.",
    "Canteen, snacks, bus? Tell me before you forget!",
    "Quick check before bed: anything to log today?",
  ]

  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "spendsnap/remind", binaryMessenger: messenger)
    let center = UNUserNotificationCenter.current()
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "ask":
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
          DispatchQueue.main.async { result(granted) }
        }
      case "schedule":
        guard let a = call.arguments as? [String: Any], let hour = a["hour"] as? Int,
          let minute = a["minute"] as? Int
        else { return result(FlutterError(code: "bad_args", message: nil, details: nil)) }
        let skipToday = a["skipToday"] as? Bool ?? false
        let texts = (a["lines"] as? [String]).flatMap { $0.isEmpty ? nil : $0 } ?? lines
        center.removePendingNotificationRequests(withIdentifiers: ids)
        let cal = Calendar.current
        let now = Date()
        for day in 0..<7 {
          guard let date = cal.date(byAdding: .day, value: day, to: now),
            let at = cal.date(bySettingHour: hour, minute: minute, second: 0, of: date),
            at > now, !(day == 0 && skipToday)
          else { continue }
          let content = UNMutableNotificationContent()
          content.title = appTitle
          content.body = texts[day % texts.count]
          content.sound = .default
          let when = cal.dateComponents([.year, .month, .day, .hour, .minute], from: at)
          let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: false)
          center.add(UNNotificationRequest(identifier: ids[day], content: content, trigger: trigger))
        }
        result(nil)
      case "cancel":
        center.removePendingNotificationRequests(withIdentifiers: ids)
        result(nil)
      case "openSettings":
        // The app's page in Settings, or straight to its notifications
        // where iOS can (16 and later), to turn on what she said no to.
        var page = UIApplication.openSettingsURLString
        if call.arguments as? String == "notifications", #available(iOS 16.0, *) {
          page = UIApplication.openNotificationSettingsURLString
        }
        if let url = URL(string: page) { UIApplication.shared.open(url) }
        result(nil)
      case "alerts":
        // Task and countdown reminders, each once at its time: replace them all.
        let items = call.arguments as? [[String: Any]] ?? []
        center.getPendingNotificationRequests { pending in
          let old = pending.map { $0.identifier }.filter { $0.hasPrefix("alert-") }
          center.removePendingNotificationRequests(withIdentifiers: old)
          let cal = Calendar.current
          for item in items {
            guard let id = item["id"] as? String, let ms = (item["at"] as? NSNumber)?.doubleValue,
              let body = item["body"] as? String
            else { continue }
            let content = UNMutableNotificationContent()
            content.title = appTitle
            content.body = body
            if item["sound"] as? Bool ?? true { content.sound = .default }
            let at = Date(timeIntervalSince1970: ms / 1000)
            let when = cal.dateComponents([.year, .month, .day, .hour, .minute], from: at)
            let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: false)
            center.add(UNNotificationRequest(identifier: "alert-\(id)", content: content, trigger: trigger))
          }
          DispatchQueue.main.async { result(nil) }
        }
      case "checkins":
        // The cat's daily check-ins: replace every one with the new list.
        let items = call.arguments as? [[String: Any]] ?? []
        center.getPendingNotificationRequests { pending in
          let old = pending.map { $0.identifier }.filter { $0.hasPrefix("checkin-") }
          center.removePendingNotificationRequests(withIdentifiers: old)
          for item in items {
            guard let id = item["id"] as? String, let hour = item["hour"] as? Int,
              let minute = item["minute"] as? Int, let body = item["body"] as? String
            else { continue }
            let content = UNMutableNotificationContent()
            content.title = appTitle
            content.body = body
            content.sound = .default
            var when = DateComponents()
            when.hour = hour
            when.minute = minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: true)
            center.add(UNNotificationRequest(identifier: "checkin-\(id)", content: content, trigger: trigger))
          }
          DispatchQueue.main.async { result(nil) }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

/// Hands today's words (lib/today_widget.dart) to the Home Screen widget
/// through the App Group both share, and asks the widget to redraw.
enum TodayWidgetBridge {
  static let appGroup = "group.com.shenetic.purrse"

  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "spendsnap/widget", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "update" else { return result(FlutterMethodNotImplemented) }
      UserDefaults(suiteName: appGroup)?.set(call.arguments as? String, forKey: "today")
      WidgetCenter.shared.reloadTimelines(ofKind: "TodayWidget")
      result(nil)
    }
  }
}

/// Study mode: keeps the screen on, sees whether Guided Access holds the
/// phone on the app, and lines up the cat's call to come back after she
/// leaves the app in the middle of a session.
enum Study {
  private static let ids = (0..<4).map { "study-\($0)" }

  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "spendsnap/study", binaryMessenger: messenger)
    let center = UNUserNotificationCenter.current()
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "awake":
        UIApplication.shared.isIdleTimerDisabled = call.arguments as? Bool ?? false
        result(nil)
      case "locked":
        result(UIAccessibility.isGuidedAccessEnabled)
      case "lock":
        // Only school or family-managed phones let an app start Guided
        // Access itself; on others this answers false and she triple-clicks.
        let on = call.arguments as? Bool ?? false
        if on == UIAccessibility.isGuidedAccessEnabled { return result(true) }
        UIAccessibility.requestGuidedAccessSession(enabled: on) { ok in
          DispatchQueue.main.async { result(ok) }
        }
      case "callBack":
        let items = call.arguments as? [[String: Any]] ?? []
        center.removePendingNotificationRequests(withIdentifiers: ids)
        for (i, item) in items.prefix(ids.count).enumerated() {
          guard let seconds = (item["seconds"] as? NSNumber)?.doubleValue,
            let body = item["body"] as? String
          else { continue }
          let content = UNMutableNotificationContent()
          content.title = appTitle
          content.body = body
          content.sound = .default
          let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
          center.add(UNNotificationRequest(identifier: ids[i], content: content, trigger: trigger))
        }
        result(nil)
      case "cancelCallBack":
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

/// The iPhone share sheet (save a picture, send a backup to Files or a chat)
/// and the Files picker for restoring a backup.
final class Share: NSObject, UIDocumentPickerDelegate {
  private static let shared = Share()
  private var pending: FlutterResult?

  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "spendsnap/share", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard let top = topController() else {
        return result(FlutterError(code: "no_window", message: nil, details: nil))
      }
      switch call.method {
      case "file":
        guard let path = call.arguments as? String else { return result(nil) }
        let url = URL(fileURLWithPath: path)
        // A picture shares as an image, so "Save Image" shows up.
        let item: Any = url.pathExtension == "png" ? (UIImage(contentsOfFile: path) ?? url) : url
        let sheet = UIActivityViewController(activityItems: [item], applicationActivities: nil)
        sheet.popoverPresentationController?.sourceView = top.view
        sheet.popoverPresentationController?.sourceRect = CGRect(
          x: top.view.bounds.midX, y: top.view.bounds.midY, width: 0, height: 0)
        sheet.completionWithItemsHandler = { _, done, _, _ in result(done) }
        top.present(sheet, animated: true)
      case "pick":
        shared.pending = result
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json, .data], asCopy: true)
        picker.delegate = shared
        top.present(picker, animated: true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func topController() -> UIViewController? {
    let window = UIApplication.shared.connectedScenes
      .compactMap { ($0 as? UIWindowScene)?.keyWindow }
      .first
    var top = window?.rootViewController
    while let next = top?.presentedViewController { top = next }
    return top
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    pending?(urls.first?.path)
    pending = nil
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    pending?(nil)
    pending = nil
  }
}
