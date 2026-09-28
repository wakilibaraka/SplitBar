import AppKit
import Foundation
import SwiftUI

/// Segment türüne göre içerik seçen konteyner: `.apps` mevcut EdgeDockView ile çizilir,
/// widget/tray türleri B3 hap görünümleriyle çizilir.
public struct SegmentContainerView: View {
    public let segment: SegmentViewState
    public let materialStyle: DockMaterialStyle
    public let reduceMotion: Bool
    public let autoHide: Bool
    public let iconBaseSize: CGFloat
    public let onItemFrames: (UUID, [DockItemGeometry]) -> Void
    public let onAction: (AppAction) -> Void
    public let onOpenAddPanel: () -> Void
    public let onSelectTheme: (DockMaterialStyle) -> Void
    public let onToggleAutoHide: () -> Void
    public let onShowAppWindows: (String, String, URL?) -> Void
    public let onHoverItem: (DockItemViewState?, CGPoint?) -> Void
    public let shouldAutoHideOnHoverEnd: () -> Bool
    public let onUpdateIconSize: (Double) -> Void
    @State private var autoHideTimer: DispatchWorkItem?

    public var body: some View {
        Group {
            switch segment.kind {
            case .apps:
                EdgeDockView(
                    viewState: DockViewState(
                        items: segment.items,
                        edge: segment.edge,
                        isRevealed: true,
                        selectedItemID: nil
                    ),
                    materialStyle: materialStyle,
                    reduceMotion: reduceMotion,
                    autoHide: autoHide,
                    iconBaseSize: iconBaseSize,
                    onAction: onAction,
                    onOpenAddPanel: onOpenAddPanel,
                    onSelectTheme: onSelectTheme,
                    onToggleAutoHide: onToggleAutoHide,
                    onShowAppWindows: onShowAppWindows,
                    onUpdateIconSize: onUpdateIconSize
                )
                .onPreferenceChange(DockItemFramesPreferenceKey.self) { preferences in
                    let geometries = preferences.map { pref in
                        DockItemGeometry(id: pref.id, logicalFrame: pref.frame)
                    }
                    onItemFrames(segment.id, geometries)
                }
            case .widget(let widgetKind):
                let metrics = PillMetrics(iconBaseSize: iconBaseSize)
                switch widgetKind {
                case .weather:
                    WeatherPillView(segment: segment, materialStyle: materialStyle, metrics: metrics, onAction: onAction)
                case .calendar:
                    CalendarPillView(segment: segment, materialStyle: materialStyle, metrics: metrics)
                case .notes, .nowPlaying, .systemMonitor, .custom:
                    PlaceholderSegmentPillView(title: placeholderTitle(widgetKind), materialStyle: materialStyle, metrics: metrics)
                }
            case .tray:
                TrayClusterView(
                    segment: segment,
                    materialStyle: materialStyle,
                    metrics: PillMetrics(iconBaseSize: iconBaseSize),
                    onAction: onAction
                )
            }
        }
        .onContinuousHover { phase in
            switch phase {
            case .active:
                autoHideTimer?.cancel()
                autoHideTimer = nil
            case .ended:
                onHoverItem(nil, nil)
                if autoHide && shouldAutoHideOnHoverEnd() {
                    let task = DispatchWorkItem {
                        onAction(.hideDock)
                    }
                    autoHideTimer = task
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.65, execute: task)
                }
            }
        }
    }

    private func placeholderTitle(_ widgetKind: WidgetKind) -> String {
        switch widgetKind {
        case .notes: return "Notes"
        case .nowPlaying: return "Now Playing"
        case .systemMonitor: return "System"
        case .custom: return "Widget"
        default: return "Widget"
        }
    }
}

@MainActor
private final class SegmentPanelController {
    let panel: NSPanel
    var hostingView: NSHostingView<SegmentContainerView>?

    init(collectionBehavior: NSWindow.CollectionBehavior) {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = collectionBehavior
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.acceptsMouseMovedEvents = true
        self.panel = panel
    }
}

@MainActor
public final class SegmentPanelManager {
    public struct Configuration {
        public var materialStyle: DockMaterialStyle
        public var reduceMotion: Bool
        public var autoHide: Bool
        public var iconBaseSize: CGFloat
        /// Hava durumu hapı genişliği canlı durum metnine göre ölçülür.
        public var weatherState: WeatherState?
        /// Bölüm içindeki öğe çerçeveleri (panel koordinatı); flyout ikon üstüne bağlanır.
        public var onItemFrames: (UUID, [DockItemGeometry]) -> Void
        public var onAction: (AppAction) -> Void
        public var onOpenAddPanel: () -> Void
        public var onSelectTheme: (DockMaterialStyle) -> Void
        public var onToggleAutoHide: () -> Void
        public var onShowAppWindows: (String, String, URL?) -> Void
        public var onHoverItem: (DockItemViewState?, CGPoint?) -> Void
        public var shouldAutoHideOnHoverEnd: () -> Bool
        public var onUpdateIconSize: (Double) -> Void

        public init(
            materialStyle: DockMaterialStyle,
            reduceMotion: Bool,
            autoHide: Bool,
            iconBaseSize: CGFloat,
            weatherState: WeatherState? = nil,
            onItemFrames: @escaping (UUID, [DockItemGeometry]) -> Void,
            onAction: @escaping (AppAction) -> Void,
            onOpenAddPanel: @escaping () -> Void,
            onSelectTheme: @escaping (DockMaterialStyle) -> Void,
            onToggleAutoHide: @escaping () -> Void,
            onShowAppWindows: @escaping (String, String, URL?) -> Void,
            onHoverItem: @escaping (DockItemViewState?, CGPoint?) -> Void,
            shouldAutoHideOnHoverEnd: @escaping () -> Bool,
            onUpdateIconSize: @escaping (Double) -> Void
        ) {
            self.materialStyle = materialStyle
            self.reduceMotion = reduceMotion
            self.autoHide = autoHide
            self.iconBaseSize = iconBaseSize
            self.weatherState = weatherState
            self.onItemFrames = onItemFrames
            self.onAction = onAction
            self.onOpenAddPanel = onOpenAddPanel
            self.onSelectTheme = onSelectTheme
            self.onToggleAutoHide = onToggleAutoHide
            self.onShowAppWindows = onShowAppWindows
            self.onHoverItem = onHoverItem
            self.shouldAutoHideOnHoverEnd = shouldAutoHideOnHoverEnd
            self.onUpdateIconSize = onUpdateIconSize
        }
    }

    /// Ardışık segmentler arasındaki minimum boşluk (yarı piksel zorunlu kılınır).
    public static let minimumInterSegmentGap: CGFloat = 0.5

    private var controllers: [UUID: SegmentPanelController] = [:]
    public private(set) var lastSegmentFrames: [UUID: CGRect] = [:]
    /// En son bildirilen öğe çerçeveleri (panel içi mantıksal koordinat).
    public private(set) var lastItemFrames: [UUID: [UUID: CGRect]] = [:]
    /// İlk sync'te tam yapılandırma alınır; panel sahibi init sırasında henüz hazır olmayabilir.
    private var configuration: Configuration?
    private let collectionBehavior = edgePanelCollectionBehavior()

    public init() {
    }

    /// Bir segmentin doğal boyutu: mevcut dock panel matematiğiyle aynı formüller.
    public func size(for segment: DockSegment, on edge: DockEdge) -> CGSize {
        // sync öncesi çerçeve sorgusu gelirse 46 pt varsayılan ikon boyutu kullanılır
        let iconBaseSize = configuration?.iconBaseSize ?? 46.0
        // Tüm segmentler tek görünür şerit gibi aynı kalınlıkta çizilir
        let thickness = iconBaseSize + 22.0
        let itemSlotSize = iconBaseSize + 8.0
        let naturalLength: CGFloat
        switch segment.kind {
        case .apps(let ids):
            naturalLength = max(160.0, CGFloat(ids.count) * itemSlotSize + 72.0)
        case .widget(let widgetKind):
            // Durum metnine göre ölçülür; PillMetrics oranlarıyla kalibre edilir
            let metrics = PillMetrics(iconBaseSize: iconBaseSize)
            switch widgetKind {
            case .weather:
                let condition = configuration?.weatherState?.conditionText
                let textWidth = CGFloat((condition ?? "Weather").count) * (metrics.secondaryFontSize * 0.52)
                naturalLength = max(130.0, min(220.0, metrics.iconSize + metrics.horizontalPadding * 2 + textWidth + metrics.primaryFontSize * 4.4))
            case .calendar:
                naturalLength = metrics.iconSize + metrics.horizontalPadding * 2 + metrics.primaryFontSize * 3.4
            case .notes, .nowPlaying, .systemMonitor, .custom:
                naturalLength = metrics.iconSize + metrics.horizontalPadding * 2 + metrics.primaryFontSize * 5.0
            }
        case .tray(let identifiers):
            let metrics = PillMetrics(iconBaseSize: iconBaseSize)
            naturalLength = CGFloat(identifiers.count) * metrics.trayIconSlot + metrics.horizontalPadding * 2 + metrics.primaryFontSize * 3.2 + 14.0
        }
        let length = segment.length ?? naturalLength
        return (edge == .bottom)
            ? CGSize(width: length, height: thickness)
            : CGSize(width: thickness, height: length)
    }

    /// Tek segmentin çerçevesi: edge + alignment + offset + length + screen frame.
    public func frame(
        for segment: DockSegment,
        on screen: ScreenGeometry,
        edgeInset: CGFloat = 10.0
    ) -> CGRect {
        segmentPanelFrame(
            segment: segment,
            screen: screen,
            segmentSize: size(for: segment, on: segment.edge),
            edgeInset: edgeInset
        )
    }

    /// Tüm segmentlerin çerçeveleri; aynı kenarda üst üste binen komşular yarı piksel aralıkla ayrılır.
    public func frames(for segments: [DockSegment], on screen: ScreenGeometry) -> [UUID: CGRect] {
        var frames: [UUID: CGRect] = [:]
        for segment in segments {
            frames[segment.id] = frame(for: segment, on: screen)
        }

        for edge in DockEdge.allCases {
            let idsOnEdge = segments
                .filter { $0.edge == edge }
                .map(\.id)
            guard idsOnEdge.count > 1 else { continue }
            let isHorizontal = (edge == .bottom)

            func originAxis(_ rect: CGRect) -> CGFloat { isHorizontal ? rect.minX : rect.minY }
            func endAxis(_ rect: CGRect) -> CGFloat { isHorizontal ? rect.maxX : rect.maxY }
            func setOriginAxis(_ rect: CGRect, _ value: CGFloat) -> CGRect {
                isHorizontal
                    ? rect.offsetBy(dx: value - rect.minX, dy: 0.0)
                    : rect.offsetBy(dx: 0.0, dy: value - rect.minY)
            }

            // Haplar gerçek genişliğini .fixedSize ile seçtiği için tahmini çerçeveler arasında
            // görsel nefes payı bırakılır; yarı piksel minimum sıkışınca yine devreye girer.
            let spacing = max(Self.minimumInterSegmentGap, 10.0)
            let ordered = idsOnEdge.sorted {
                originAxis(frames[$0] ?? .zero) < originAxis(frames[$1] ?? .zero)
            }
            for (index, id) in ordered.enumerated() where index > 0 {
                let previousID = ordered[index - 1]
                guard let previous = frames[previousID], var current = frames[id] else { continue }
                let minimumOrigin = endAxis(previous) + spacing
                if originAxis(current) < minimumOrigin {
                    current = setOriginAxis(current, minimumOrigin)
                    frames[id] = current
                }
            }
            // Ekranın dışına itilen kuyruk geri alınır
            if let lastID = ordered.last, let last = frames[lastID] {
                let maxOrigin = isHorizontal
                    ? screen.visibleFrame.maxX - last.width
                    : screen.visibleFrame.maxY - last.height
                if (isHorizontal ? last.minX : last.minY) > maxOrigin {
                    frames[lastID] = setOriginAxis(last, maxOrigin)
                }
            }
        }
        return frames
    }

    /// Panel envanterini segment listesiyle uzlaştırır: yeni ID için panel açılır, silinen ID'nin
    /// paneli kapatılır, değişenler yerinde yeniden yapılandırılır. Her değişimde toplu yeniden kurulum yapılmaz.
    public func sync(
        segments: [DockSegment],
        itemStates: [SegmentViewState],
        screen: ScreenGeometry,
        isRevealed: Bool,
        configuration newConfiguration: Configuration
    ) {
        self.configuration = newConfiguration
        let frames = frames(for: segments, on: screen)

        // Kaldırılan segmentlerin panelleri kapatılır
        for id in controllers.keys where !segments.contains(where: { $0.id == id }) {
            if let controller = controllers.removeValue(forKey: id) {
                controller.panel.orderOut(nil)
                controller.panel.contentView = nil
            }
            lastSegmentFrames[id] = nil
            lastItemFrames[id] = nil
        }

        let statesByID = Dictionary(uniqueKeysWithValues: itemStates.map { ($0.id, $0) })
        for segment in segments {
            // B3: tüm segment türleri kendi panelinde yaşar; widget/tray haplar da artık açılır
            let frame = frames[segment.id] ?? .zero
            let controller = controllers[segment.id] ?? {
                let created = SegmentPanelController(collectionBehavior: collectionBehavior)
                controllers[segment.id] = created
                return created
            }()

            if let state = statesByID[segment.id], let rootView = makeContainerView(state: state) {
                if let hostingView = controller.hostingView {
                    hostingView.rootView = rootView
                } else {
                    let hostingView = NSHostingView(rootView: rootView)
                    // Sabit çerçeveli panelde sizingOptions kısıtları hosting-view çelişkisi yaratır
                    hostingView.sizingOptions = []
                    controller.panel.contentView = hostingView
                    controller.hostingView = hostingView
                }
            }

            if controller.panel.frame != frame {
                controller.panel.setFrame(frame, display: true, animate: false)
            }
            if isRevealed {
                controller.panel.orderFrontRegardless()
            } else if controller.panel.isVisible {
                controller.panel.orderOut(nil)
            }
            lastSegmentFrames[segment.id] = frame
        }
    }

    private func makeContainerView(state: SegmentViewState) -> SegmentContainerView? {
        guard let configuration = self.configuration else { return nil }
        return SegmentContainerView(
            segment: state,
            materialStyle: configuration.materialStyle,
            reduceMotion: configuration.reduceMotion,
            autoHide: configuration.autoHide,
            iconBaseSize: configuration.iconBaseSize,
            onItemFrames: configuration.onItemFrames,
            onAction: configuration.onAction,
            onOpenAddPanel: configuration.onOpenAddPanel,
            onSelectTheme: configuration.onSelectTheme,
            onToggleAutoHide: configuration.onToggleAutoHide,
            onShowAppWindows: configuration.onShowAppWindows,
            onHoverItem: configuration.onHoverItem,
            shouldAutoHideOnHoverEnd: configuration.shouldAutoHideOnHoverEnd,
            onUpdateIconSize: configuration.onUpdateIconSize
        )
    }

    /// Tüm segmentlerin birleşik çerçevesi; flyout ve tooltip çıpaları bunu kullanır.
    public func boundingFrame() -> CGRect? {
        let visible = lastSegmentFrames.values.filter { $0.width > 0.0 && $0.height > 0.0 }
        guard let first = visible.first else { return nil }
        return visible.reduce(first) { $0.union($1) }
    }

    /// Bir segmentin çerçevesi; widget hapları kendi flyout'ları için bunu bağlaç olarak kullanır.
    public func frame(forSegment segmentID: UUID) -> CGRect? {
        let frame = lastSegmentFrames[segmentID]
        guard let frame = frame, frame.width > 0.0, frame.height > 0.0 else { return nil }
        return frame
    }

    /// SwiftUI preference akışı: bölümün öğe çerçevelerini saklar (panel içi mantıksal koordinat).
    func lastItemFramesReport(segmentID: UUID, geometries: [DockItemGeometry]) {
        var byID: [UUID: CGRect] = [:]
        for geometry in geometries {
            byID[geometry.id] = geometry.logicalFrame
        }
        lastItemFrames[segmentID] = byID
    }

    /// Öğenin ekran koordinatlarındaki çerçevesi: panel çerçevesi + panel içi mantıksal çerçeve.
    /// SwiftUI y-ekseni yukarı doğru panel mantığına göre çevrilir (maxY - frame.maxY).
    public func screenFrame(forItem itemID: UUID, inSegment segmentID: UUID) -> CGRect? {
        guard let panelFrame = frame(forSegment: segmentID),
              let logical = lastItemFrames[segmentID]?[itemID] else {
            return nil
        }
        return CGRect(
            x: panelFrame.minX + logical.minX,
            y: panelFrame.maxY - logical.maxY,
            width: logical.width,
            height: logical.height
        )
    }
}
