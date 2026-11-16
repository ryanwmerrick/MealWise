import Foundation

/// Development metadata only; no duration or safety guarantee is inferred.
enum StorageKind: String, Codable, CaseIterable, Sendable { case shelfStable, fresh, openedCan, frozen }

extension StorageKind {
    var title: String {
        switch self {
        case .shelfStable: "Shelf-stable"
        case .fresh: "Fresh"
        case .openedCan: "Opened can"
        case .frozen: "Frozen"
        }
    }
}
