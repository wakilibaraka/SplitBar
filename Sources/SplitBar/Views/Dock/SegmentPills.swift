import AppKit
import Foundation
import SwiftUI

/// Bölüm hap görünümlerinin ortak ölçek tabanı: tüm font/ikon/boşluk oranları
/// dock'un ikon boyutu motorundan türetilir; büyütme ayarı hapları da büyütür.
struct PillMetrics {
    let iconBaseSize: CGFloat

    var iconSize: CGFloat { max(12.0, iconBaseSize * 0.34) }
    /// Merkezi dock ile aynı şerit yüksekliği; hap camı paneli doldurur.
    var capsuleHeight: CGFloat { iconBaseSize + 22.0 }
    var primaryFontSize: CGFloat { max(11.0, iconBaseSize * 0.30) }
    var secondaryFontSize: CGFloat { max(8.5, iconBaseSize * 0.20) }
    var horizontalPadding: CGFloat { max(10.0, iconBaseSize * 0.30) }
    var verticalPadding: CGFloat { max(5.0, iconBaseSize * 0.15) }
    var contentSpacing: CGFloat { max(6.0, iconBaseSize * 0.16) }
    var cornerRadius: CGFloat { max(16.0, (iconBaseSize + 22.0) / 2.0) }
    var trayIconSlot: CGFloat { trayIconSize + max(4.0, iconBaseSize * 0.10) }
    var trayIconSize: CGFloat { max(13.0, iconBaseSize * 0.40) }
}

/// Ekran görüntüsündeki sol alttaki hava durumu hapı: canlı sıcaklık + durum metni.
/// Tıklanınca mevcut hava durumu flyout'u hapın üstünde açılır (dockItems'taki weather öğesi).
struct WeatherPillView: View {
    let segment: SegmentViewState
    let materialStyle: DockMaterialStyle
    let metrics: PillMetrics
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
            HStack(spacing: metrics.contentSpacing) {
                Image(systemName: symbolName)
                    .font(.system(size: metrics.iconSize, weight: .semibold))
                    .foregroundStyle(Color.yellow)
                    .shadow(color: Color.black.opacity(0.25), radius: 1.5, x: 0.0, y: 1.0)

                Text(segment.weather?.formattedTemperature ?? "—°")
                    .font(.system(size: metrics.primaryFontSize, weight: .bold, design: .rounded))

                Text(segment.weather?.conditionText ?? "Weather")
                    .font(.system(size: metrics.secondaryFontSize + 1.5, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, metrics.horizontalPadding)
            .padding(.vertical, metrics.verticalPadding)
            .frame(minHeight: metrics.capsuleHeight)
            .background(ThemedGlassBackground(style: materialStyle, cornerRadius: metrics.cornerRadius))
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
        .fixedSize()
        .help("Weather")
    }
}

/// Takvim hapı: haftanın günü + gün numarası; Calendar.app'i açar.
struct CalendarPillView: View {
    let segment: SegmentViewState
    let materialStyle: DockMaterialStyle
    let metrics: PillMetrics

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d"
        return formatter
    }()

    var body: some View {
        Button {
            openCalendarApp()
        } label: {
            HStack(spacing: metrics.contentSpacing - 2.0) {
                Image(systemName: "calendar")
                    .font(.system(size: metrics.iconSize - 2.0, weight: .semibold))
                    .foregroundStyle(Color.red)

                Text(Self.dayFormatter.string(from: segment.date))
                    .font(.system(size: metrics.primaryFontSize - 1.0, weight: .semibold, design: .rounded))
            }
            .padding(.horizontal, metrics.horizontalPadding - 2.0)
            .padding(.vertical, metrics.verticalPadding)
            .frame(minHeight: metrics.capsuleHeight)
            .background(ThemedGlassBackground(style: materialStyle, cornerRadius: metrics.cornerRadius))
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
/// Düğmeler görev çubuğu ikonlarıyla aynı `.selectItem` yolunu kullanır; flyout
/// tıklanan düğmenin üstünde açılır.
struct TrayClusterView: View {
    let segment: SegmentViewState
    let materialStyle: DockMaterialStyle
    let metrics: PillMetrics
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

    var body: some View {
        HStack(spacing: metrics.contentSpacing) {
            ForEach(segment.trayItems) { item in
                Button {
                    onAction(.selectItem(id: item.id))
                } label: {
                    WidgetIconView(identifier: widgetIdentifier(of: item), size: metrics.trayIconSize)
                        .frame(width: metrics.trayIconSlot, height: metrics.trayIconSlot)
                }
                .buttonStyle(.plain)
                .pointingHandCursor()
                .help(item.name)
            }

            Divider()
                .frame(height: metrics.iconSize)
                .overlay(Color.white.opacity(0.30))

            VStack(spacing: 1.0) {
                Text(Self.timeFormatter.string(from: segment.date))
                    .font(.system(size: metrics.primaryFontSize - 1.5, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(Self.dateFormatter.string(from: segment.date))
                    .font(.system(size: metrics.secondaryFontSize, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, metrics.horizontalPadding)
        .padding(.vertical, metrics.verticalPadding)
        .frame(minHeight: metrics.capsuleHeight)
        .background(ThemedGlassBackground(style: materialStyle, cornerRadius: metrics.cornerRadius))
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
    let metrics: PillMetrics

    var body: some View {
        HStack(spacing: metrics.contentSpacing - 2.0) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: metrics.iconSize - 3.0, weight: .medium))
                .foregroundColor(.secondary)
            Text(title)
                .font(.system(size: metrics.secondaryFontSize + 2.5, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, metrics.horizontalPadding - 2.0)
        .padding(.vertical, metrics.verticalPadding)
        .frame(minHeight: metrics.capsuleHeight)
        .background(ThemedGlassBackground(style: materialStyle, cornerRadius: metrics.cornerRadius))
        .fixedSize()
    }
}
