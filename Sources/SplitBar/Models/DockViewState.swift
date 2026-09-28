import AppKit
import CoreGraphics
import Foundation

public struct DockItemViewState: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let kind: DockItemKind
    public let isSelected: Bool
    public let isRunning: Bool
    public let badgeText: String?
    public let transform: DockItemVisualTransform

    public init(
        id: UUID,
        name: String,
        kind: DockItemKind,
        isSelected: Bool,
        isRunning: Bool,
        badgeText: String?,
        transform: DockItemVisualTransform
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.isSelected = isSelected
        self.isRunning = isRunning
        self.badgeText = badgeText
        self.transform = transform
    }
}

public struct DockViewState: Equatable, Sendable {
    public let items: [DockItemViewState]
    public let edge: DockEdge
    public let isRevealed: Bool
    public let selectedItemID: UUID?

    public init(
        items: [DockItemViewState],
        edge: DockEdge,
        isRevealed: Bool,
        selectedItemID: UUID?
    ) {
        self.items = items
        self.edge = edge
        self.isRevealed = isRevealed
        self.selectedItemID = selectedItemID
    }
}

public struct SegmentViewState: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let kind: SegmentKind
    public let items: [DockItemViewState]
    public let edge: DockEdge
    /// Widget hapları için canlı hava durumu; nil ise yer tutucu çizilir.
    public let weather: WeatherState?
    /// Tray saatinin çizim anı; her içerik yenilemesinde güncellenir.
    public let date: Date
    /// Tray segmentinin barındırdığı widget görünümleri (config sırasıyla).
    public let trayItems: [DockItemViewState]
    /// Widget segmentinin tıklanınca açacağı flyout öğesinin ID'si (ör. hava durumu).
    public let actionItemID: UUID?

    public init(
        id: UUID,
        kind: SegmentKind,
        items: [DockItemViewState],
        edge: DockEdge,
        weather: WeatherState? = nil,
        date: Date = Date(),
        trayItems: [DockItemViewState] = [],
        actionItemID: UUID? = nil
    ) {
        self.id = id
        self.kind = kind
        self.items = items
        self.edge = edge
        self.weather = weather
        self.date = date
        self.trayItems = trayItems
        self.actionItemID = actionItemID
    }
}

public func makeSegmentViewStates(
    state: AppState,
    pointer: CGPoint?,
    itemFrames: [DockItemGeometry],
    configuration: DockMagnificationConfiguration,
    weatherState: WeatherState?,
    aiUsageState: AIUsageState?,
    systemMetrics: SystemMetrics?,
    nowPlayingState: NowPlayingState?
) -> [SegmentViewState] {
    // Tray segmentlerinin referans verdiği widget öğeleri de görünüm üretir
    let trayIdentifiers = Set(state.segments.flatMap { segment -> [String] in
        if case .tray(let identifiers) = segment.kind { return identifiers }
        return []
    })
    let trayItemIDs = Set(state.dockItems.compactMap { item -> UUID? in
        if case .widget(let widgetID) = item.kind, trayIdentifiers.contains(widgetID) { return item.id }
        return nil
    })
    let sharedItemIDs = Set(state.segments.flatMap { $0.itemIDs }).union(trayItemIDs)
    let items = state.dockItems.filter { sharedItemIDs.contains($0.id) }
    let itemViews = makeDockViewState(
        state: AppState(
            dockItems: items,
            selectedItemID: state.selectedItemID,
            placement: state.placement,
            isDockRevealed: state.isDockRevealed,
            flyout: state.flyout
        ),
        pointer: pointer,
        itemFrames: itemFrames,
        configuration: configuration,
        weatherState: weatherState,
        aiUsageState: aiUsageState,
        systemMetrics: systemMetrics,
        nowPlayingState: nowPlayingState
    ).items

    let viewsByID = Dictionary(uniqueKeysWithValues: itemViews.map { ($0.id, $0) })
    // Widget tanımlayıcısı -> görünüm (tray düğmeleri badge/çalışma durumuyla çizilsin diye)
    var widgetViewsByID: [String: DockItemViewState] = [:]
    for item in state.dockItems {
        if case .widget(let widgetID) = item.kind, let view = viewsByID[item.id] {
            widgetViewsByID[widgetID] = view
        }
    }
    let now = Date()
    return state.segments.map { segment in
        var trayItems: [DockItemViewState] = []
        var actionItemID: UUID?
        switch segment.kind {
        case .tray(let identifiers):
            trayItems = identifiers.compactMap { widgetViewsByID[$0] }
        case .widget(let widgetKind):
            let expectedID: String?
            switch widgetKind {
            case .weather: expectedID = "weather"
            case .calendar: expectedID = nil // takvim hapı Calendar.app'i doğrudan açar
            case .notes: expectedID = "quick_notes"
            case .nowPlaying: expectedID = "now_playing"
            case .systemMonitor: expectedID = "system_monitor"
            case .custom: expectedID = nil
            }
            if let expectedID = expectedID {
                actionItemID = widgetViewsByID[expectedID]?.id
            }
        case .apps:
            break
        }
        return SegmentViewState(
            id: segment.id,
            kind: segment.kind,
            items: segment.itemIDs.compactMap { viewsByID[$0] },
            edge: segment.edge,
            weather: weatherState,
            date: now,
            trayItems: trayItems,
            actionItemID: actionItemID
        )
    }
}

public func makeDockViewState(
    state: AppState,
    pointer: CGPoint?,
    itemFrames: [DockItemGeometry],
    configuration: DockMagnificationConfiguration,
    weatherState: WeatherState?,
    aiUsageState: AIUsageState?,
    systemMetrics: SystemMetrics?,
    nowPlayingState: NowPlayingState?
) -> DockViewState {
    let transforms = magnificationTransforms(
        items: itemFrames,
        pointer: pointer,
        configuration: configuration
    )

    var itemViews: [DockItemViewState] = []
    for item in state.dockItems {
        let isSelected = (state.selectedItemID == item.id)
        let transform = transforms[item.id] ?? DockItemVisualTransform(
            scale: 1.0,
            translationY: 0.0,
            logicalFrame: itemFrames.first(where: { $0.id == item.id })?.logicalFrame ?? .zero
        )

        var isRunning = false
        var badgeText: String? = nil
        switch item.kind {
        case .application(let bundleID, _):
            isRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
        case .widget(let wid):
            if wid == "weather" {
                badgeText = weatherState?.formattedTemperature ?? "—°"
            } else if wid == "ai_usage" {
                if let ai = aiUsageState {
                    isRunning = ai.hasRunningAgent
                    // Gerçek plan limiti biliniyorsa en az kalan 5 saatlik kota gösterilir
                    if let percent = ai.lowestFiveHourRemainingPercent(now: Date()) {
                        badgeText = "\(Int(percent.rounded()))%"
                    } else {
                        badgeText = ai.hasRunningAgent ? "LIVE" : "AI"
                    }
                } else {
                    badgeText = "AI"
                }
            } else if wid == "system_monitor" {
                if let metrics = systemMetrics {
                    badgeText = "\(Int(round(metrics.cpu.usagePercent)))%"
                } else {
                    badgeText = "CPU"
                }
            } else if wid == "now_playing" {
                if let np = nowPlayingState, np.isPlaying {
                    isRunning = true
                    badgeText = "PLAY"
                } else {
                    isRunning = false
                    badgeText = "Music"
                }
            } else if wid == "bluetooth" {
                badgeText = "BT"
            } else if wid == "quick_notes" {
                badgeText = "Note"
            } else if wid == "clipboard" {
                badgeText = "Clip"
            }
        case .link:
            break
        }

        itemViews.append(
            DockItemViewState(
                id: item.id,
                name: item.name,
                kind: item.kind,
                isSelected: isSelected,
                isRunning: isRunning,
                badgeText: badgeText,
                transform: transform
            )
        )
    }

    return DockViewState(
        items: itemViews,
        edge: state.placement.edge,
        isRevealed: state.isDockRevealed,
        selectedItemID: state.selectedItemID
    )
}
