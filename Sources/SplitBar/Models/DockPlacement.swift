import Foundation

public enum DockEdge: String, Codable, CaseIterable, Sendable {
    case left
    case right
    case bottom
}

extension DockEdge {
    /// Config versions before the split architecture allowed `.top`; SplitBar never occupies the
    /// menu-bar edge, so persisted `"top"` values decode as `.bottom` instead of failing the load.
    public init(lenientlyDecoding raw: String) {
        if let decoded = DockEdge(rawValue: raw), raw != "top" {
            self = decoded
        } else {
            self = .bottom
        }
    }
}

public struct DockPlacement: Codable, Equatable, Sendable {
    public let edge: DockEdge
    public let verticalOffsetFraction: Double
    public let autoHide: Bool

    public init(
        edge: DockEdge,
        verticalOffsetFraction: Double,
        autoHide: Bool
    ) {
        self.edge = edge
        self.verticalOffsetFraction = verticalOffsetFraction
        self.autoHide = autoHide
    }

    private enum CodingKeys: String, CodingKey {
        case edge
        case verticalOffsetFraction
        case autoHide
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Uygulama içinde oluşturulan kodlama enum'un rawValue'sudur; eski config'deki "top" burada .bottom'a düşer
        let rawEdge = try container.decode(String.self, forKey: .edge)
        self.edge = DockEdge(lenientlyDecoding: rawEdge)
        self.verticalOffsetFraction = try container.decode(Double.self, forKey: .verticalOffsetFraction)
        self.autoHide = try container.decode(Bool.self, forKey: .autoHide)
    }
}
