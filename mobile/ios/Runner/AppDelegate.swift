import Flutter
import UIKit
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
