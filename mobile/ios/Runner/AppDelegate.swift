import AudioToolbox
import Flutter
import UIKit
import UserNotifications
import Vision

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
/// haptics. System sounds follow the silent switch and the ringer volume.
enum Feel {
  private static var sounds: [String: SystemSoundID] = [:]

  static func register(registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "spendsnap/feel", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "play":
        if let asset = call.arguments as? String { play(registrar.lookupKey(forAsset: asset)) }
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

  private static func play(_ key: String) {
    if sounds[key] == nil, let path = Bundle.main.path(forResource: key, ofType: nil) {
      var id: SystemSoundID = 0
      if AudioServicesCreateSystemSoundID(URL(fileURLWithPath: path) as CFURL, &id) == kAudioServicesNoError {
        sounds[key] = id
      }
    }
    if let id = sounds[key] { AudioServicesPlaySystemSound(id) }
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
        center.removePendingNotificationRequests(withIdentifiers: ids)
        let cal = Calendar.current
        let now = Date()
        for day in 0..<7 {
          guard let date = cal.date(byAdding: .day, value: day, to: now),
            let at = cal.date(bySettingHour: hour, minute: minute, second: 0, of: date),
            at > now, !(day == 0 && skipToday)
          else { continue }
          let content = UNMutableNotificationContent()
          content.title = "Spend Snap"
          content.body = lines[day % lines.count]
          content.sound = .default
          let when = cal.dateComponents([.year, .month, .day, .hour, .minute], from: at)
          let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: false)
          center.add(UNNotificationRequest(identifier: ids[day], content: content, trigger: trigger))
        }
        result(nil)
      case "cancel":
        center.removePendingNotificationRequests(withIdentifiers: ids)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
