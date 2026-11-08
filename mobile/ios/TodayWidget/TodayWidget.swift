import SwiftUI
import UIKit
import WidgetKit

/// The App Group the app and this widget share. The app writes today's
/// words here (TodayWidgetBridge in AppDelegate.swift) whenever its list
/// changes; the widget only reads them.
let appGroup = "group.com.shenetic.purrse"

struct TodayTask: Decodable {
  let title: String
  let time: String?
}

/// What lib/today_widget.dart sends, already in her language.
struct TodayWords: Decodable {
  let day: String
  let title: String
  let tasks: [TodayTask]
  let more: String?
  let done: String?
  let empty: String
  let streak: Int
  let streakText: String
  let stale: String
}

struct TodayEntry: TimelineEntry {
  let date: Date
  let words: TodayWords?
}

/// "2026-11-08", the same day key the app uses.
func dayKey(_ date: Date) -> String {
  let f = DateFormatter()
  f.calendar = Calendar(identifier: .gregorian)
  f.locale = Locale(identifier: "en_US_POSIX")
  f.dateFormat = "yyyy-MM-dd"
  return f.string(from: date)
}

var chinese: Bool { Locale.preferredLanguages.first?.hasPrefix("zh") ?? false }

struct TodayProvider: TimelineProvider {
  func placeholder(in context: Context) -> TodayEntry {
    TodayEntry(date: Date(), words: nil)
  }

  func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
    completion(TodayEntry(date: Date(), words: load()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
    let now = Date()
    let words = load()
    // At midnight the words become yesterday's: show "open the app" then,
    // and ask again after.
    let midnight = Calendar.current.startOfDay(for: now.addingTimeInterval(24 * 60 * 60))
    let entries = [TodayEntry(date: now, words: words), TodayEntry(date: midnight, words: words)]
    completion(Timeline(entries: entries, policy: .after(midnight)))
  }

  private func load() -> TodayWords? {
    guard let json = UserDefaults(suiteName: appGroup)?.string(forKey: "today"),
      let data = json.data(using: .utf8)
    else { return nil }
    return try? JSONDecoder().decode(TodayWords.self, from: data)
  }
}

private let green = Color(
  UIColor { $0.userInterfaceStyle == .dark
    ? UIColor(red: 0.66, green: 0.84, blue: 0.68, alpha: 1)
    : UIColor(red: 0.25, green: 0.42, blue: 0.27, alpha: 1)
  })
private let paper = Color(
  UIColor { $0.userInterfaceStyle == .dark
    ? UIColor(red: 0.14, green: 0.15, blue: 0.13, alpha: 1)
    : UIColor(red: 0.98, green: 0.97, blue: 0.94, alpha: 1)
  })

struct TodayView: View {
  let entry: TodayEntry

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 4) {
        Text(entry.words?.title ?? (chinese ? "今天" : "Today"))
          .font(.headline)
          .foregroundColor(green)
        Spacer(minLength: 0)
        if let w = entry.words, w.streak > 0 {
          Text("🔥 \(w.streakText)").font(.caption).bold().lineLimit(1)
        }
      }
      if let w = entry.words, w.day == dayKey(entry.date) {
        if w.tasks.isEmpty {
          Text(w.empty).font(.subheadline).foregroundColor(.secondary)
        }
        ForEach(Array(w.tasks.prefix(3).enumerated()), id: \.offset) { _, task in
          HStack(spacing: 6) {
            Image(systemName: "circle").font(.caption2).foregroundColor(green)
            Text(task.title).font(.subheadline).lineLimit(1)
            Spacer(minLength: 0)
            if let time = task.time {
              Text(time).font(.caption).foregroundColor(.secondary)
            }
          }
        }
        if let more = w.more {
          Text(more).font(.caption).foregroundColor(.secondary)
        }
        Spacer(minLength: 0)
        if let done = w.done {
          Text(done).font(.caption2).foregroundColor(.secondary)
        }
      } else {
        Text(entry.words?.stale ?? (chinese ? "打开 Tiny Habits Cat 看看今天" : "Open Tiny Habits Cat to see today"))
          .font(.subheadline)
          .foregroundColor(.secondary)
        Spacer(minLength: 0)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}

extension View {
  /// iOS 17 draws the background itself and asks for it this way.
  @ViewBuilder func todayBackground() -> some View {
    if #available(iOS 17.0, *) {
      containerBackground(for: .widget) { paper }
    } else {
      padding().background(paper)
    }
  }
}

@main
struct TodayWidget: Widget {
  private let name: String = chinese ? "今天" : "Today"
  private let about: String =
    chinese ? "接下来的三件事和连续打卡天数。" : "Your next three things to do, and your streak."

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "TodayWidget", provider: TodayProvider()) { entry in
      TodayView(entry: entry).todayBackground()
    }
    .configurationDisplayName(name)
    .description(about)
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
