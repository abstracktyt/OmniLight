import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), status: "Подключено")
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), status: "Подключено")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let userDefaults = UserDefaults(suiteName: "group.com.abstrackt.omnilight")
        let status = userDefaults?.string(forKey: "widget_status") ?? "Отключено"
        
        let entry = SimpleEntry(date: Date(), status: status)
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let status: String
}

struct OmniLightWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("OmniLight")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Статус: \(entry.status)")
                .font(.caption)
                .foregroundColor(.gray)
            
            Spacer()
            
            HStack {
                Link(destination: URL(string: "omnilight://color?hex=FF3B30")!) {
                    Circle().fill(Color.red).frame(width: 30, height: 30)
                }
                Spacer()
                Link(destination: URL(string: "omnilight://color?hex=34C759")!) {
                    Circle().fill(Color.green).frame(width: 30, height: 30)
                }
                Spacer()
                Link(destination: URL(string: "omnilight://color?hex=007AFF")!) {
                    Circle().fill(Color.blue).frame(width: 30, height: 30)
                }
                Spacer()
                Link(destination: URL(string: "omnilight://color?hex=FFFFFF")!) {
                    Circle().fill(Color.white).frame(width: 30, height: 30)
                }
            }
        }
    }
}

struct OmniLightWidget: Widget {
    let kind: String = "OmniLightWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                OmniLightWidgetEntryView(entry: entry)
                    .containerBackground(Color(red: 28/255, green: 28/255, blue: 30/255), for: .widget)
            } else {
                OmniLightWidgetEntryView(entry: entry)
                    .padding()
                    .background(Color(red: 28/255, green: 28/255, blue: 30/255))
            }
        }
        .configurationDisplayName("OmniLight Контроль")
        .description("Управляйте лентами прямо с рабочего стола.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
