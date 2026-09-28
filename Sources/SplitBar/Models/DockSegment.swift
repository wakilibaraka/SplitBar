import CoreGraphics
import Foundation

/// Widget türleri segment tanımında yer alır; B1'de yalnızca `.apps` render edilir,
/// diğerleri yer tutucu olarak tanımlıdır.
public enum WidgetKind: String, Codable, CaseIterable, Sendable {
    case systemMonitor = "system_monitor"
    case weather
    case calendar
    case notes
    case nowPlaying = "now_playing"
    case custom
}

public enum SegmentKind: Codable, Equatable, Sendable {
    /// `.apps` segmentinin gösterdiği dock öğelerinin sıralı ID'leri.
    case apps([UUID])
    case widget(WidgetKind)
    /// Sistem tepsisi: barındırdığı widget tanımlayıcıları (config ile tanımlanır).
    case tray([String])
}

public enum SegmentAlignment: String, Codable, CaseIterable, Sendable {
    case leading
    case center
    case trailing
}

/// Split mimarisinde bağımsız yüzen panel parçalarının tanımı; config ile kalıcıdır.
public struct DockSegment: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let kind: SegmentKind
    public let edge: DockEdge
    public let alignment: SegmentAlignment
    public let offset: CGFloat
    public let length: CGFloat?

    public init(
        id: UUID = UUID(),
        kind: SegmentKind,
        edge: DockEdge,
        alignment: SegmentAlignment,
        offset: CGFloat = 0.0,
        length: CGFloat? = nil
    ) {
        self.id = id
        self.kind = kind
        self.edge = edge
        self.alignment = alignment
        self.offset = offset
        self.length = length
    }
}

extension DockSegment {
    /// `.apps` segmentinin gösterdiği dock öğelerinin sıralı ID'leri.
    public var itemIDs: [UUID] {
        switch kind {
        case .apps(let ids):
            return ids
        case .widget, .tray:
            return []
        }
    }

    /// Widget segmentinin türü; diğer türler için nil.
    public var widgetKind: WidgetKind? {
        if case .widget(let kind) = kind { return kind }
        return nil
    }
}

public extension DockSegment {
    private enum CodingKeys: String, CodingKey {
        case id
        case kind
        case edge
        case alignment
        case offset
        case length
        case apps
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.edge = DockEdge(lenientlyDecoding: try container.decode(String.self, forKey: .edge))
        self.alignment = try container.decodeIfPresent(SegmentAlignment.self, forKey: .alignment) ?? .center
        self.offset = try container.decodeIfPresent(CGFloat.self, forKey: .offset) ?? 0.0
        self.length = try container.decodeIfPresent(CGFloat.self, forKey: .length)

        let kindRaw = try container.decode(String.self, forKey: .kind)
        if kindRaw == "apps" {
            self.kind = .apps(try container.decodeIfPresent([UUID].self, forKey: .apps) ?? [])
        } else if kindRaw == "tray" {
            self.kind = .tray(try container.decodeIfPresent([String].self, forKey: .apps) ?? SegmentDefaults.trayWidgetIdentifiers)
        } else if kindRaw == "widget",
                  let widgetRaw = try? container.decode(String.self, forKey: .apps),
                  let widgetKind = WidgetKind(rawValue: widgetRaw) {
            self.kind = .widget(widgetKind)
        } else {
            self.kind = .apps([])
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(edge, forKey: .edge)
        try container.encode(alignment, forKey: .alignment)
        try container.encode(offset, forKey: .offset)
        try container.encodeIfPresent(length, forKey: .length)
        switch kind {
        case .apps(let ids):
            try container.encode("apps", forKey: .kind)
            try container.encode(ids, forKey: .apps)
        case .widget(let widgetKind):
            try container.encode("widget", forKey: .kind)
            try container.encode(widgetKind.rawValue, forKey: .apps)
        case .tray(let widgetIdentifiers):
            try container.encode("tray", forKey: .kind)
            try container.encode(widgetIdentifiers, forKey: .apps)
        }
    }
}

public enum SegmentDefaults {
    /// B1 varsayılanı: alt kenarda ARALARINDA boşluk olan İKİ bağımsız `.apps` segmenti.
    /// Uygulama listesi ikiye bölünür; bir segment `.leading`, diğeri `.trailing` hizalanır.
    public static func defaultSegments(appItems: [DockItem]) -> [DockSegment] {
        let apps = appItems.filter {
            if case .application = $0.kind { return true }
            return false
        }
        let halfCount = Int(ceil(Double(apps.count) / 2.0))
        let leadingIDs = apps.prefix(halfCount).map(\.id)
        let trailingIDs = apps.suffix(apps.count - leadingIDs.count).map(\.id)
        return [
            DockSegment(kind: .apps(leadingIDs), edge: .bottom, alignment: .leading, offset: 0.0),
            DockSegment(kind: .apps(trailingIDs), edge: .bottom, alignment: .trailing, offset: 0.0)
        ]
    }

    /// Standart tray içeriği: tıklanabilir flyout widgetları (sağ küme).
    public static let trayWidgetIdentifiers: [String] = [
        "clipboard",
        "ai_usage",
        "now_playing",
        "quick_notes",
        "system_monitor"
    ]

    /// Ekran görüntüsündeki düzen: sol altta hava durumu hapı, ortada TEK uygulama çubuğu,
    /// sağ altta takvim + tray. Tüm segmentler aynı kalınlıkta çizilir.
    public static func screenshotLayout(appItems: [DockItem]) -> [DockSegment] {
        let appIDs = appItems.filter {
            if case .application = $0.kind { return true }
            return false
        }.map(\.id)
        return [
            DockSegment(kind: .widget(.weather), edge: .bottom, alignment: .leading, offset: 0.0),
            DockSegment(kind: .apps(appIDs), edge: .bottom, alignment: .center, offset: 0.0),
            DockSegment(kind: .widget(.calendar), edge: .bottom, alignment: .trailing, offset: 0.0),
            DockSegment(kind: .tray(trayWidgetIdentifiers), edge: .bottom, alignment: .trailing, offset: 0.0)
        ]
    }

    /// Eski otomatik düzenleri tanır (elle düzenlenmiş config'lere dokunmaz): B1'in iki
    /// `.apps` segmenti ve B3/B4'ün otomatik 5-segment düzenleri.
    public static func isAutoB1Layout(appItems: [DockItem], segments: [DockSegment]) -> Bool {
        if matchesB1Layout(appItems: appItems, segments: segments) { return true }
        if matchesLegacyFiveSegmentLayout(
            appItems: appItems,
            segments: segments,
            calendarAlignment: .leading,
            calendarOffset: 8.0
        ) { return true }
        return matchesLegacyFiveSegmentLayout(
            appItems: appItems,
            segments: segments,
            calendarAlignment: .trailing,
            calendarOffset: 0.0
        )
    }

    /// B1: iki `.apps` segmenti (leading + trailing), widget yok.
    private static func matchesB1Layout(appItems: [DockItem], segments: [DockSegment]) -> Bool {
        let expected = defaultSegments(appItems: appItems)
        guard segments.count == expected.count else { return false }
        for (segment, expectedSegment) in zip(segments, expected) {
            switch (segment.kind, expectedSegment.kind) {
            case (.apps(let ids), .apps(let expectedIDs)):
                guard ids == expectedIDs else { return false }
            case (.tray(let ids), .tray(let expectedIDs)):
                guard ids == expectedIDs else { return false }
            case (.widget(let a), .widget(let b)):
                guard a == b else { return false }
            default:
                return false
            }
            guard segment.edge == expectedSegment.edge,
                  segment.alignment == expectedSegment.alignment,
                  segment.offset == expectedSegment.offset else {
                return false
            }
        }
        return true
    }

    /// B3/B4 otomatik düzenleri: [hava, uygulamalar ×2, takvim, tray]; takvim hangi tarafta
    /// olduğu sürüme göre değişir. Uygulama ID'leri ikiye bölünme dışında eşleşmek zorunda.
    private static func matchesLegacyFiveSegmentLayout(
        appItems: [DockItem],
        segments: [DockSegment],
        calendarAlignment: SegmentAlignment,
        calendarOffset: CGFloat
    ) -> Bool {
        guard segments.count == 5 else { return false }
        let apps = appItems.filter {
            if case .application = $0.kind { return true }
            return false
        }
        let halfCount = Int(ceil(Double(apps.count) / 2.0))
        let leadingIDs = Array(apps.prefix(halfCount).map(\.id))
        let trailingIDs = Array(apps.suffix(apps.count - leadingIDs.count).map(\.id))

        let expectedKinds: [(SegmentKind, DockEdge, SegmentAlignment, CGFloat)] = [
            (.widget(.weather), .bottom, .leading, 0.0),
            (.apps(leadingIDs), .bottom, .center, 0.0),
            (.apps(trailingIDs), .bottom, .center, 0.0),
            (.widget(.calendar), .bottom, calendarAlignment, calendarOffset),
            (.tray(trayWidgetIdentifiers), .bottom, .trailing, 0.0)
        ]
        for (segment, expected) in zip(segments, expectedKinds) {
            let kindMatches: Bool
            switch (segment.kind, expected.0) {
            case (.apps(let ids), .apps(let expectedIDs)):
                kindMatches = (ids == expectedIDs)
            case (.widget(let a), .widget(let b)):
                kindMatches = (a == b)
            case (.tray(let ids), .tray(let expectedIDs)):
                kindMatches = (ids == expectedIDs)
            default:
                kindMatches = false
            }
            guard kindMatches,
                  segment.edge == expected.1,
                  segment.alignment == expected.2,
                  segment.offset == expected.3 else {
                return false
            }
        }
        return true
    }
}
