import Foundation
import SwiftData

enum PersistenceError: Error { case openFailed, readFailed, corruptData, saveFailed }

enum StoreSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [StoredDocument.self] }

    @Model
    final class StoredDocument {
        @Attribute(.unique) var key: String
        var payload: Data

        init(key: String, payload: Data) {
            self.key = key
            self.payload = payload
        }
    }
}

typealias StoredDocument = StoreSchemaV1.StoredDocument

enum LocalStore {
    static func makeContainer(inMemory: Bool = false, url: URL? = nil) async throws -> ModelContainer {
        do {
            let schema = Schema(versionedSchema: StoreSchemaV1.self)
            let configuration: ModelConfiguration
            if let url {
                configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
            } else {
                configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
            }
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch { throw PersistenceError.openFailed }
    }
}
