import AppKit
import Foundation
import SwiftUI

/// Ekran görüntüsündeki sol alttaki hava durumu hapı: canlı sıcaklık + durum metni.
/// Tıklanınca mevcut hava durumu flyout'u açılır (dockItems'taki weather widget öğesi).
struct WeatherPillView: View {
    let segment: SegmentViewState
    let materialStyle: DockMaterialStyle
    let onAction: (AppAction) -> Void

    private var symbolName: String {
        let condition = (segment.weather?.conditionText ?? "").lowercased()
        if condition.contains("thunder") || condition.contains("storm") { return "cloud.bolt.fill" }
        if condition.contains("snow") { return "cloud.snow.fill" }
        if condition.contains("rain") || condition.contains("drizzle") || condition.contains("shower") { return "cloud.rain.fill" }
        if condition.contains("fog") || condition.contains("mist") { return "cloud.fog.fill" }
        if condition.contains("cloud") || condition.contains("overcast") { return "cloud.fill" }
        if condition.contains("sun") || condition.contains("clear") { return "sun.max.fill" }
        return "cloud.sun.fill"
    }

    var body: some View {
        Button {
            if let actionItemID = segment.actionItemID {
                onAction(.selectItem(id: actionItemID))
            }
        } label: {
            HStack(spacing: 8.0) {
                Image(systemName: symbolName)
                    .font(.system(size: 16.0, weight: .semibold))
                    .foregroundStyle(Color.yellow)
                    .shadow(color: Color.black.opacity(0.25), radius: 1.5, x: 0.0, y: 1.0)

                Text(segment.weather?.formattedTemperature ?? "—°")
                    .font(.system(size: 14.0, weight: .bold, design: .rounded))

                Text(segment.weather?.conditionText ?? "Weather")
                    .font(.system(size: 12.0, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 14.0)
            .padding(.vertical, 8.0)
            .background(ThemedGlassBackground(style: materialStyle, cornerRadius: 18.0))
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
        .fixedSize()
        .help("Weather")
    }
}

/// Hava durumunun sağındaki takvim hapı: haftanın günü + gün numarası; Calendar.app'i açar.
struct CalendarPillView: View {
    let segment: SegmentViewState
    let materialStyle: DockMaterialStyle

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d"
        return formatter
    }()

    var body: some View {
        Button {
            openCalendarApp()
        } label: {
            HStack(spacing: 6.0) {
                Image(systemName: "calendar")
                    .font(.system(size: 13.0, weight: .semibold))
                    .foregroundStyle(Color.red)

                Text(Self.dayFormatter.string(from: segment.date))
                    .font(.system(size: 13.0, weight: .semibold, design: .rounded))
            }
            .padding(.horizontal, 12.0)
            .padding(.vertical, 8.0)
            .background(ThemedGlassBackground(style: materialStyle, cornerRadius: 18.0))
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
        .fixedSize()
        .help("Calendar")
    }

    private func openCalendarApp() {
        let candidatePaths = [
            "/System/Applications/Calendar.app",
            "/Applications/Calendar.app"
        ]
        for path in candidatePaths where FileManager.default.fileExists(atPath: path) {
            NSWorkspace.shared.openApplication(
                at: URL(fileURLWithPath: path),
                configuration: NSWorkspace.OpenConfiguration()
            )
            return
        }
    }
}

/// Sağ alttaki sistem tepsisi: flyout widget düğmeleri + canlı saat/tarih.
/// Düğmeler görev çubuğu ikonlarıyla aynı `.selectItem` yolunu kullanır; böylece
/// mevcut tüm flyout'lar ve dış tıklama davranışı aynen çalışır.
struct TrayClusterView: View {
    let segment: SegmentViewState
    let materialStyle: DockMaterialStyle
    let onAction: (AppAction) -> Void

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter
    }()

    private var trayIconSize: CGFloat {
        if case .tray(let identifiers) = segment.kind {
            return identifiers.count > 4 ? 18.0 : 20.0
        }
        return 20.0
    }

    var body: some View {
        HStack(spacing: 7.0) {
            ForEach(segment.trayItems) { item in
                Button {
                    onAction(.selectItem(id: item.id))
                } label: {
                    WidgetIconView(identifier: widgetIdentifier(of: item), size: trayIconSize)
                        .frame(width: 24.0, height: 24.0)
                }
                .buttonStyle(.plain)
                .pointingHandCursor()
                .help(item.name)
            }

            Divider()
                .frame(height: 18.0)
                .overlay(Color.white.opacity(0.30))

            VStack(spacing: 1.0) {
                Text(Self.timeFormatter.string(from: segment.date))
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(Self.dateFormatter.string(from: segment.date))
                    .font(.system(size: 9.0, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12.0)
        .padding(.vertical, 6.0)
        .background(ThemedGlassBackground(style: materialStyle, cornerRadius: 18.0))
        .fixedSize()
    }

    private func widgetIdentifier(of item: DockItemViewState) -> String {
        if case .widget(let widgetID) = item.kind { return widgetID }
        return ""
    }
}

/// B1'de tanımlanıp henüz çizilmeyen widget türleri için no-op yer tutucu hap.
struct PlaceholderSegmentPillView: View {
    let title: String
    let materialStyle: DockMaterialStyle

    var body: some View {
        HStack(spacing: 6.0) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 12.0, weight: .medium))
                .foregroundColor(.secondary)
            Text(title)
                .font(.system(size: 12.0, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12.0)
        .padding(.vertical, 8.0)
        .background(ThemedGlassBackground(style: materialStyle, cornerRadius: 18.0))
        .fixedSize()
    }
}
