import Foundation

/// Development metadata only; no duration or safety guarantee is inferred.
enum StorageKind: String, Codable, Sendable { case shelfStable, fresh, openedCan, frozen }
