import AppKit
import Foundation
import OSLog
import SwiftUI

/// DockDoor tarzı canlı pencere önizlemeleri: hover edilen uygulama ikonunun üstünde
/// yüzen şerit panel; ScreenCaptureKit canlı küçük resimleriyle kart dizisi.
@MainActor
public final class WindowPreviewStripController {
    public let panel: NSPanel
    private var hostingView: NSHostingView<WindowPreviewStripView>?
    private var currentBundleIdentifier: String?
    private var currentStrip: StripConfiguration?
    private var thumbnailVersion = 0
    /// Tekrar hover'da titremesin diye pencere ID bazlı küçük resim önbelleği.
    private let thumbnailCache = NSCache<NSNumber, NSImage>()
    private var currentTask: Task<Void, Never>?

    private struct StripConfiguration {
        let appName: String
        let windows: [AppWindowInfo]
        let onSelectWindow: (AppWindowInfo) -> Void
    }

    public init() {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false
        self.panel = panel
    }

    /// Hover edilen ikonun üstünde şeridi gösterir; pencere yoksa hiçbir şey yapmaz.
    public func show(
        appName: String,
        bundleIdentifier: String,
        appIconURL: URL?,
        anchorFrame: CGRect,
        screen: ScreenGeometry,
        edge: DockEdge,
        previewService: AppWindowPreviewService,
        onSelectWindow: @escaping (AppWindowInfo) -> Void
    ) {
        let windows = previewService.windows(forBundleIdentifier: bundleIdentifier, appName: appName)
        guard !windows.isEmpty else { return }

        currentBundleIdentifier = bundleIdentifier
        let configuration = StripConfiguration(
            appName: appName,
            windows: windows,
            onSelectWindow: { [weak self] window in
                self?.hide()
                onSelectWindow(window)
            }
        )
        self.currentStrip = configuration
        installStripView(configuration: configuration)

        // Şerit genişliği: pencere sayısına göre kart dizisi (en fazla 4 kart görünür alanda)
        let cardWidth: CGFloat = 232.0
        let visibleCards = min(CGFloat(windows.count), 4.0)
        let stripWidth = visibleCards * cardWidth + max(0.0, visibleCards - 1.0) * 10.0 + 24.0
        let stripHeight: CGFloat = 208.0

        let frame = flyoutPanelFrame(
            anchoredToItem: anchorFrame,
            screen: screen,
            edge: edge,
            flyoutSize: CGSize(width: stripWidth, height: stripHeight),
            gap: 10.0
        )
        panel.setFrame(frame, display: true, animate: false)
        panel.orderFrontRegardless()

        // Küçük resimler asenkron çekilir; geldikçe kartlar doldurulur
        currentTask?.cancel()
        currentTask = Task { [weak self] in
            for window in windows {
                if Task.isCancelled { return }
                if let image = await previewService.captureThumbnail(forWindowID: window.id) {
                    await MainActor.run {
                        guard let self = self, !Task.isCancelled else { return }
                        self.thumbnailCache.setObject(image, forKey: NSNumber(value: window.id))
                        self.thumbnailVersion += 1
                        if let configuration = self.currentStrip {
                            self.installStripView(configuration: configuration)
                        }
                    }
                }
            }
        }
    }

    /// Şerit görünümünü kurar/yeniler; token değişimi küçük resimlerin yeniden çizilmesini tetikler.
    private func installStripView(configuration: StripConfiguration) {
        let stripView = WindowPreviewStripView(
            appName: configuration.appName,
            windows: configuration.windows,
            refreshToken: thumbnailVersion,
            thumbnailProvider: { [weak self] windowID in
                self?.thumbnailCache.object(forKey: NSNumber(value: windowID))
            },
            onSelectWindow: configuration.onSelectWindow
        )
        if let hostingView = hostingView {
            hostingView.rootView = stripView
        } else {
            let hostingView = NSHostingView(rootView: stripView)
            hostingView.sizingOptions = []
            panel.contentView = hostingView
            self.hostingView = hostingView
        }
    }

    public func hide() {
        currentTask?.cancel()
        currentTask = nil
        currentBundleIdentifier = nil
        currentStrip = nil
        if panel.isVisible {
            panel.orderOut(nil)
        }
    }

    /// Aynı uygulama için tekrar tetiklenirse içerik yenilenmez (hover titremesini önler).
    public func isShowing(bundleIdentifier: String) -> Bool {
        return panel.isVisible && currentBundleIdentifier == bundleIdentifier
    }
}

/// Şerit içeriği: başlık satırı + yatay kart dizisi.
public struct WindowPreviewStripView: View {
    public let appName: String
    public let windows: [AppWindowInfo]
    /// Küçük resim önbelleği değiştikçe artar; yeniden çizimi tetikler.
    public let refreshToken: Int
    public let thumbnailProvider: (CGWindowID) -> NSImage?
    public let onSelectWindow: (AppWindowInfo) -> Void

    public var body: some View {
        VStack(alignment: .leading, spacing: 8.0) {
            Text(appName)
                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .padding(.horizontal, 4.0)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10.0) {
                    ForEach(windows) { window in
                        WindowPreviewCard(
                            window: window,
                            thumbnail: thumbnailProvider(window.id),
                            onSelect: {
                                onSelectWindow(window)
                            }
                        )
                    }
                }
                .padding(.vertical, 2.0)
                .padding(.horizontal, 2.0)
            }
        }
        .padding(12.0)
        .background(
            RoundedRectangle(cornerRadius: 18.0, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18.0, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.22), lineWidth: 1.0)
                )
        )
        .environment(\.colorScheme, .dark)
    }
}

/// Tek pencere kartı: canlı küçük resim + başlık + boyut; tıkla odakla.
public struct WindowPreviewCard: View {
    public let window: AppWindowInfo
    public let thumbnail: NSImage?
    public let onSelect: () -> Void

    @State private var isHovered = false

    public var body: some View {
        Button(action: {
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
            onSelect()
        }) {
            VStack(alignment: .leading, spacing: 6.0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10.0, style: .continuous)
                        .fill(Color.black.opacity(0.35))

                    if let thumbnail = thumbnail {
                        Image(nsImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 208.0, height: 128.0)
                            .clipShape(RoundedRectangle(cornerRadius: 10.0, style: .continuous))
                    } else {
                        Image(systemName: "macwindow")
                            .font(.system(size: 24.0, weight: .light))
                            .foregroundColor(.white.opacity(0.55))
                            .frame(width: 208.0, height: 128.0)
                    }
                }
                .frame(width: 208.0, height: 128.0)
                .overlay(
                    RoundedRectangle(cornerRadius: 10.0, style: .continuous)
                        .strokeBorder(
                            isHovered ? Color.accentColor : Color.white.opacity(0.20),
                            lineWidth: isHovered ? 1.6 : 0.8
                        )
                )

                Text(window.title)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text("\(Int(window.bounds.width))×\(Int(window.bounds.height))")
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(6.0)
            .background(
                RoundedRectangle(cornerRadius: 13.0, style: .continuous)
                    .fill(isHovered ? Color.white.opacity(0.10) : Color.white.opacity(0.04))
            )
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }
}
