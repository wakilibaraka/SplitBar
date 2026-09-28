import AppKit
import CoreGraphics
import Foundation

public struct ScreenGeometry: Equatable, Sendable {
    public let identifier: String
    public let frame: CGRect
    public let visibleFrame: CGRect

    public init(
        identifier: String,
        frame: CGRect,
        visibleFrame: CGRect
    ) {
        self.identifier = identifier
        self.frame = frame
        self.visibleFrame = visibleFrame
    }
}

public func edgePanelFrame(
    screen: ScreenGeometry,
    panelSize: CGSize,
    edge: DockEdge,
    edgeInset: CGFloat
) -> CGRect {
    let x: CGFloat
    let y: CGFloat
    switch edge {
    case .right:
        x = screen.visibleFrame.maxX - panelSize.width - edgeInset
        let unclampedY = screen.visibleFrame.midY - (panelSize.height / 2.0)
        y = min(max(unclampedY, screen.visibleFrame.minY), screen.visibleFrame.maxY - panelSize.height)
    case .left:
        x = screen.visibleFrame.minX + edgeInset
        let unclampedY = screen.visibleFrame.midY - (panelSize.height / 2.0)
        y = min(max(unclampedY, screen.visibleFrame.minY), screen.visibleFrame.maxY - panelSize.height)
    case .bottom:
        let unclampedX = screen.visibleFrame.midX - (panelSize.width / 2.0)
        x = min(max(unclampedX, screen.visibleFrame.minX), screen.visibleFrame.maxX - panelSize.width)
        y = screen.visibleFrame.minY + edgeInset
    }
    return CGRect(x: x, y: y, width: panelSize.width, height: panelSize.height)
}

public func flyoutPanelFrame(
    anchorFrame: CGRect,
    screen: ScreenGeometry,
    edge: DockEdge,
    flyoutSize: CGSize,
    gap: CGFloat
) -> CGRect {
    let unclampedX: CGFloat
    let unclampedY: CGFloat
    switch edge {
    case .right:
        unclampedX = anchorFrame.minX - flyoutSize.width - gap
        unclampedY = anchorFrame.midY - (flyoutSize.height / 2.0)
    case .left:
        unclampedX = anchorFrame.maxX + gap
        unclampedY = anchorFrame.midY - (flyoutSize.height / 2.0)
    case .bottom:
        unclampedX = anchorFrame.midX - (flyoutSize.width / 2.0)
        unclampedY = anchorFrame.maxY + gap
    }

    let clampedX = min(max(unclampedX, screen.visibleFrame.minX), screen.visibleFrame.maxX - flyoutSize.width)
    let clampedY = min(max(unclampedY, screen.visibleFrame.minY), screen.visibleFrame.maxY - flyoutSize.height)

    return CGRect(x: clampedX, y: clampedY, width: flyoutSize.width, height: flyoutSize.height)
}

public func edgeActivationFrame(
    screen: ScreenGeometry,
    edge: DockEdge,
    thickness: CGFloat
) -> CGRect {
    switch edge {
    case .right:
        return CGRect(
            x: screen.visibleFrame.maxX - thickness,
            y: screen.visibleFrame.minY,
            width: thickness,
            height: screen.visibleFrame.height
        )
    case .left:
        return CGRect(
            x: screen.visibleFrame.minX,
            y: screen.visibleFrame.minY,
            width: thickness,
            height: screen.visibleFrame.height
        )
    case .bottom:
        return CGRect(
            x: screen.visibleFrame.minX,
            y: screen.visibleFrame.minY,
            width: screen.visibleFrame.width,
            height: thickness
        )
    }
}

/// Dock gizliyken ekran kenarında, dock'un ortasına hizalı duran küçük tutamacın çerçevesi.
public func edgeHandleFrame(
    dockFrame: CGRect,
    screen: ScreenGeometry,
    edge: DockEdge,
    length: CGFloat,
    thickness: CGFloat
) -> CGRect {
    let inset: CGFloat = 3.0
    switch edge {
    case .right:
        return CGRect(x: screen.visibleFrame.maxX - thickness - inset, y: dockFrame.midY - length / 2.0, width: thickness, height: length)
    case .left:
        return CGRect(x: screen.visibleFrame.minX + inset, y: dockFrame.midY - length / 2.0, width: thickness, height: length)
    case .bottom:
        return CGRect(x: dockFrame.midX - length / 2.0, y: screen.visibleFrame.minY + inset, width: length, height: thickness)
    }
}

/// Bölüm çerçevesi: edge + alignment + offset + length + screen frame'den hesaplanır.
/// Alt kenarda panel taban kenara sabitlenir; offscreen bölümler görünür alana sabitlenir.
public func segmentPanelFrame(
    segment: DockSegment,
    screen: ScreenGeometry,
    segmentSize: CGSize,
    edgeInset: CGFloat
) -> CGRect {
    let visible = screen.visibleFrame
    let verticalEdge = (segment.edge == .bottom)

    // offset, kenarın merkezinden segmentin uzun eksenindeki kaymadır (pozitif = sağa / yukarı)
    let crossOrigin: CGFloat
    switch segment.alignment {
    case .leading:
        crossOrigin = verticalEdge ? visible.minX : visible.minY
    case .trailing:
        crossOrigin = verticalEdge ? visible.maxX - segmentSize.width : visible.maxY - segmentSize.height
    case .center:
        crossOrigin = verticalEdge ? (visible.width - segmentSize.width) / 2.0 : (visible.height - segmentSize.height) / 2.0
    }

    let origin: CGPoint
    if verticalEdge {
        // Hizalama temel konumu verir; offset uzun eksende kaydırır (pozitif = sağa)
        let unclampedX = crossOrigin + segment.offset
        let x = min(max(unclampedX, visible.minX), visible.maxX - segmentSize.width)
        origin = CGPoint(x: x, y: visible.minY + edgeInset)
    } else {
        let unclampedY = crossOrigin + segment.offset
        let y = min(max(unclampedY, visible.minY), visible.maxY - segmentSize.height)
        origin = CGPoint(x: visible.minX + edgeInset, y: y)
    }

    return CGRect(origin: origin, size: segmentSize)
}

public func edgePanelCollectionBehavior() -> NSWindow.CollectionBehavior {
    return [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
}
