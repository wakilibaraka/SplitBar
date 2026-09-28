import Foundation

public struct AppPreferences: Codable, Equatable, Sendable {
    public var placement: DockPlacement
    public var materialStyle: DockMaterialStyle
    public var shortcutBindings: [ShortcutBinding]
    public var clipboardRetention: ClipboardRetentionPolicy
    public var clipboardExcludedBundleIdentifiers: Set<String>
    public var selectedScreenIdentifier: String?
    public var reduceMotion: Bool
    public var language: AppLanguage
    public var dockIconSize: Double
    public var segments: [DockSegment]
    /// SplitBar alt kenarı işgal ettiğinde gerçek Dock'un taşınacağı kenar (sol/sağ).
    public var realDockSide: DockEdge

    public init(
        placement: DockPlacement,
        materialStyle: DockMaterialStyle,
        shortcutBindings: [ShortcutBinding],
        clipboardRetention: ClipboardRetentionPolicy,
        clipboardExcludedBundleIdentifiers: Set<String>,
        selectedScreenIdentifier: String?,
        reduceMotion: Bool,
        language: AppLanguage,
        dockIconSize: Double,
        segments: [DockSegment]? = nil,
        realDockSide: DockEdge? = nil
    ) {
        self.placement = placement
        self.materialStyle = materialStyle
        self.shortcutBindings = shortcutBindings
        self.clipboardRetention = clipboardRetention
        self.clipboardExcludedBundleIdentifiers = clipboardExcludedBundleIdentifiers
        self.selectedScreenIdentifier = selectedScreenIdentifier
        self.reduceMotion = reduceMotion
        self.language = language
        self.dockIconSize = dockIconSize
        self.segments = segments ?? []
        self.realDockSide = realDockSide ?? .right
    }

    private enum CodingKeys: String, CodingKey {
        case placement
        case materialStyle
        case shortcutBindings
        case clipboardRetention
        case clipboardExcludedBundleIdentifiers
        case selectedScreenIdentifier
        case reduceMotion
        case language
        case dockIconSize
        case segments
        case realDockSide
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.placement = try container.decode(DockPlacement.self, forKey: .placement)
        self.materialStyle = try container.decode(DockMaterialStyle.self, forKey: .materialStyle)
        self.shortcutBindings = try container.decode([ShortcutBinding].self, forKey: .shortcutBindings)
        self.clipboardRetention = try container.decode(ClipboardRetentionPolicy.self, forKey: .clipboardRetention)
        self.clipboardExcludedBundleIdentifiers = try container.decode(Set<String>.self, forKey: .clipboardExcludedBundleIdentifiers)
        self.selectedScreenIdentifier = try container.decodeIfPresent(String.self, forKey: .selectedScreenIdentifier)
        self.reduceMotion = try container.decode(Bool.self, forKey: .reduceMotion)
        self.language = try container.decodeIfPresent(AppLanguage.self, forKey: .language) ?? .english
        self.dockIconSize = try container.decodeIfPresent(Double.self, forKey: .dockIconSize) ?? 46.0
        // Eski config'lerde bölüm tanımı yoktur; SegmentPanelManager .apps öğeleri için varsayılanı üretir
        self.segments = try container.decodeIfPresent([DockSegment].self, forKey: .segments) ?? []
        self.realDockSide = try container.decodeIfPresent(DockEdge.self, forKey: .realDockSide) ?? .right
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(placement, forKey: .placement)
        try container.encode(materialStyle, forKey: .materialStyle)
        try container.encode(shortcutBindings, forKey: .shortcutBindings)
        try container.encode(clipboardRetention, forKey: .clipboardRetention)
        try container.encode(clipboardExcludedBundleIdentifiers, forKey: .clipboardExcludedBundleIdentifiers)
        try container.encodeIfPresent(selectedScreenIdentifier, forKey: .selectedScreenIdentifier)
        try container.encode(reduceMotion, forKey: .reduceMotion)
        try container.encode(language, forKey: .language)
        try container.encode(dockIconSize, forKey: .dockIconSize)
        try container.encode(segments, forKey: .segments)
        try container.encode(realDockSide, forKey: .realDockSide)
    }
}
