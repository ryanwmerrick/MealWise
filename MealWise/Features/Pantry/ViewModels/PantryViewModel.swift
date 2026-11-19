import Combine
import Foundation

@MainActor
final class PantryViewModel: ObservableObject {
    @Published private(set) var isLoading = true
    @Published private(set) var items: [PantryInventoryItem] = []
    @Published private(set) var errorMessage: String?
    private let repository: any PantryRepositoryProtocol
    private let planID: UUID
    init(planID: UUID, repository: any PantryRepositoryProtocol) {
        self.planID = planID
        self.repository = repository
    }
    func load() async {
        isLoading = true; defer { isLoading = false }
        do { let items = try await repository.inventory(planID: planID); try Task.checkCancellation(); self.items = items; errorMessage = nil }
        catch is CancellationError { return }
        catch { errorMessage = "Pantry stock could not be loaded. Please retry." }
    }
}

@MainActor
final class PantryEditorViewModel: ObservableObject {
    @Published var ingredientID: String
    @Published var quantityText: String
    @Published var storage: StorageKind?
    @Published var hasExpiry: Bool
    @Published var expiry: Date
    @Published var available: Bool
    @Published var customName: String
    @Published var customUnit: QuantityUnit
    @Published var hasAcquiredDate: Bool
    @Published var acquiredAt: Date
    @Published private(set) var errorMessage: String?
    @Published private(set) var isWorking = false
    let original: PantryItem?
    let catalog: RecipeCatalog
    private let repository: any PantryRepositoryProtocol
    init(item: PantryItem?, catalog: RecipeCatalog, repository: any PantryRepositoryProtocol) {
        original = item; self.catalog = catalog; self.repository = repository
        ingredientID = item?.customName != nil ? "" : (item?.ingredientID ?? catalog.ingredients.first?.id ?? "")
        quantityText = item.flatMap { $0.unknownQuantity == nil ? PantryQuantityInput.text(amount: $0.quantity, unit: $0.unit) : nil } ?? ""
        storage = item?.storage; hasExpiry = item?.expiry != nil; expiry = item?.expiry ?? .now; available = item?.availabilityConfirmed ?? true
        customName = item?.customName ?? ""
        customUnit = item?.unit ?? .count
        hasAcquiredDate = item?.acquiredAt != nil
        acquiredAt = item?.acquiredAt ?? .now
    }
    var unit: QuantityUnit { ingredientID.isEmpty ? customUnit : (catalog.ingredients.first { $0.id == ingredientID }?.unit ?? .count) }
    func save() async -> Bool {
        guard !isWorking else { return false }
        isWorking = true; defer { isWorking = false }
        do {
            let amount = try PantryQuantityInput.parse(quantityText, unit: unit)
            guard amount > 0 else { throw PantryError.invalidQuantity }
            let date = hasExpiry ? Calendar.autoupdatingCurrent.dateInterval(of: .day, for: expiry)?.end.addingTimeInterval(-0.001) : nil
            let id = original?.id ?? UUID()
            let name = ingredientID.isEmpty ? customName.trimmingCharacters(in: .whitespacesAndNewlines) : nil
            let item = PantryItem(id: id, ingredientID: name == nil ? ingredientID : "custom-" + id.uuidString,
                                  quantity: amount, unit: unit, storage: storage, expiry: date, availabilityConfirmed: available,
                                  revision: original?.revision ?? UUID(), acquiredAt: hasAcquiredDate ? acquiredAt : nil, customName: name)
            try await repository.save(item, expectedRevision: original?.revision); errorMessage = nil; return true
        } catch PantryError.staleStock { errorMessage = "This stock changed. Close the editor and reopen the current item."; return false }
        catch { errorMessage = "Enter a positive quantity in the displayed unit. The stock could not be saved; please check it and retry."; return false }
    }
    func remove() async -> Bool {
        guard let original, !isWorking else { return false }
        isWorking = true; defer { isWorking = false }
        do { try await repository.remove(id: original.id, expectedRevision: original.revision); return true }
        catch { errorMessage = "This stock could not be removed. Close the editor and reopen the current item."; return false }
    }
}

@MainActor
final class CycleHistoryViewModel: ObservableObject {
    @Published private(set) var isLoading = true
    @Published private(set) var cycles: [CycleHistory] = []
    @Published private(set) var archives: [PlanArchive] = []
    @Published private(set) var errorMessage: String?
    private let repository: any HistoryRepositoryProtocol
    init(repository: any HistoryRepositoryProtocol) { self.repository = repository }
    func load() async {
        isLoading = true; defer { isLoading = false }
        do {
            async let completed = repository.loadCycles()
            async let reset = repository.loadArchives()
            let (cycles, archives) = try await (completed, reset)
            try Task.checkCancellation()
            self.cycles = cycles; self.archives = archives.filter { archive in !cycles.contains { $0.id == archive.id } }; errorMessage = nil
        } catch is CancellationError { return }
        catch { errorMessage = "Week history could not be loaded. Please retry." }
    }
}
