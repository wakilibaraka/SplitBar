import AppKit
import Foundation
import OSLog

/// Real macOS Dock çarpışma yönetimi: SplitBar'ın işgal ettiği kenarda duran gerçek Dock'u
/// başka kenara kaydırır ve auto-hide'a alır. CLAUDE.md kuralları:
/// - Orijinal orientation+autohide, mutasyondan ÖNCE diske yazılır.
/// - Launch'ta kayıt dosyası varsa önce geri yüklenir (crash recovery).
/// - applicationWillTerminate ve SIGTERM/SIGINT üzerinde geri yüklenir.
/// - Hızlı iterasyon için SPLITBAR_SKIP_DOCK_MANIPULATION=1 tüm işlemi atlar.
@MainActor
public final class DockController {
    private struct SavedDockState: Codable {
        let orientation: String
        let autohide: Bool
    }

    public static let dockPreferencesDomain = "com.apple.dock"
    private let savedStateURL: URL
    /// SplitBar alt kenarı işgal ettiğinde gerçek Dock'un taşınacağı kenar (kullanıcı seçimi).
    public var relocationSide: DockEdge
    private var hasMutatedRealDock = false

    public init(supportDirectory: URL, relocationSide: DockEdge = .right) {
        self.savedStateURL = supportDirectory.appendingPathComponent("realDockState.json")
        self.relocationSide = relocationSide
    }

    // MARK: - Reading real Dock state

    private func currentOrientation() -> String? {
        CFPreferencesCopyAppValue("orientation" as CFString, Self.dockPreferencesDomain as CFString) as? String
    }

    private func currentAutohide() -> Bool {
        (CFPreferencesCopyAppValue("autohide" as CFString, Self.dockPreferencesDomain as CFString) as? Bool) ?? false
    }

    private func readSavedState() -> SavedDockState? {
        guard let data = try? Data(contentsOf: savedStateURL) else { return nil }
        return try? JSONDecoder().decode(SavedDockState.self, from: data)
    }

    private func writeSavedState(_ state: SavedDockState) {
        do {
            try FileManager.default.createDirectory(
                at: savedStateURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(state).write(to: savedStateURL, options: .atomic)
        } catch {
            Logger.persistence.error("Failed to persist real Dock state error=\(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Applying / restoring

    private func applyDockSettings(orientation: String, autohide: Bool) {
        guard ProcessInfo.processInfo.environment["SPLITBAR_SKIP_DOCK_MANIPULATION"] != "1" else {
            Logger.lifecycle.info("Skipping real Dock manipulation (dev flag)")
            return
        }
        let defaults = Process()
        do {
            defaults.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
            defaults.arguments = [
                "write", Self.dockPreferencesDomain, "orientation", "-string", orientation
            ]
            try defaults.run()
            defaults.waitUntilExit()
            guard defaults.terminationStatus == 0 else {
                Logger.lifecycle.error("defaults write orientation failed status=\(defaults.terminationStatus)")
                return
            }

            let autohideProcess = Process()
            autohideProcess.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
            autohideProcess.arguments = [
                "write", Self.dockPreferencesDomain, "autohide", "-bool", autohide ? "true" : "false"
            ]
            try autohideProcess.run()
            autohideProcess.waitUntilExit()

            let restart = Process()
            restart.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            restart.arguments = ["Dock"]
            try restart.run()
            hasMutatedRealDock = true
            Logger.lifecycle.info("Real Dock moved orientation=\(orientation, privacy: .public) autohide=\(autohide)")
        } catch {
            Logger.lifecycle.error("Failed to apply real Dock settings error=\(String(describing: error), privacy: .public)")
        }
    }

    /// Launch'ta çökmeden kalan kayıt varsa önce gerçek Dock'u eski haline getirir.
    public func recoverIfNeeded() {
        guard let saved = readSavedState() else { return }
        Logger.lifecycle.notice("Recovering real Dock state from previous session orientation=\(saved.orientation, privacy: .public)")
        applyDockSettings(orientation: saved.orientation, autohide: saved.autohide)
        try? FileManager.default.removeItem(at: savedStateURL)
        hasMutatedRealDock = false
    }

    /// SplitBar'ın işgal ettiği kenara göre gerçek Dock'u yeniden konumlandırır.
    /// SplitBar bottom'dayken Dock relocationSide'a (varsayılan sağ) gider ve auto-hide olur.
    public func applyPlacement(edge: DockEdge) {
        let targetOrientation: String
        switch edge {
        case .bottom:
            switch relocationSide {
            case .left: targetOrientation = "left"
            default: targetOrientation = "right"
            }
        case .left:
            // SplitBar soldaysa Dock sağa; ancak relocationSide sağ seçiliyse sola çakışır -> yine sağ
            targetOrientation = "right"
        case .right:
            targetOrientation = "left"
        }

        let liveOrientation = currentOrientation() ?? "bottom"
        guard liveOrientation != targetOrientation || !currentAutohide() else { return }

        // Mutasyondan ÖNCE orijinal durum diske yazılır (CLAUDE.md kuralı)
        if !hasMutatedRealDock, let orientation = currentOrientation() {
            writeSavedState(SavedDockState(orientation: orientation, autohide: currentAutohide()))
        }
        applyDockSettings(orientation: targetOrientation, autohide: true)
    }

    /// Uygulama çıkışında gerçek Dock'u geri yükler; yalnızca gerçekten değiştirdiysek.
    public func restore() {
        guard hasMutatedRealDock else { return }
        if let saved = readSavedState() {
            applyDockSettings(orientation: saved.orientation, autohide: saved.autohide)
        } else {
            applyDockSettings(orientation: "bottom", autohide: false)
        }
        try? FileManager.default.removeItem(at: savedStateURL)
        hasMutatedRealDock = false
        Logger.lifecycle.info("Real Dock restored")
    }

    /// SIGTERM/SIGINT yakalama; restore senkron çalışır.
    public func installSignalHandlers() {
        signal(SIGTERM, SIG_IGN)
        signal(SIGINT, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        source.setEventHandler { [weak self] in
            self?.restore()
            exit(0)
        }
        source.resume()
        self.sigtermSource = source

        let intSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        intSource.setEventHandler { [weak self] in
            self?.restore()
            exit(0)
        }
        intSource.resume()
        self.sigintSource = intSource
    }

    private var sigtermSource: DispatchSourceSignal?
    private var sigintSource: DispatchSourceSignal?
}
