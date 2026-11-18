import Foundation
import OSLog

protocol MenuProposing: Sendable {
    func propose(_ input: MenuProposalInput) async throws -> [[String]]
}

struct MenuProposalInput: Encodable, Sendable {
    struct Slot: Encodable, Sendable {
        let meal: MealSlot
        let allowedRecipeIDs: [String]
    }

    struct Candidate: Encodable, Sendable {
        let id: String
        let title: String
        let baseAdultPortions: Int
        let ingredients: [RecipeRequirement]
        let containsMeat: Bool
        let preferenceScore: Int
    }

    struct Package: Encodable, Sendable {
        let ingredientID: String
        let quantity: Int64
        let priceMinorUnits: Int64
    }

    let slots: [Slot]
    let recipes: [Candidate]
    let packages: [Package]
    let adultHalfPortions: Int
    let remainingBudgetMinorUnits: Int64
    let requiresMeat: Bool
    let goals: [String]

    init(request: PlanRequest, slots: [MealSlot], candidates: [[Recipe]], preferenceScores: [String: Int]) {
        self.slots = zip(slots, candidates).map { meal, recipes in
            Slot(meal: meal, allowedRecipeIDs: recipes.map(\.id))
        }
        let candidateIDs = Set(candidates.flatMap { $0.map(\.id) })
        recipes = request.catalog.recipes.filter { candidateIDs.contains($0.id) }.map {
            Candidate(id: $0.id, title: $0.title, baseAdultPortions: $0.baseAdultPortions,
                      ingredients: $0.ingredients, containsMeat: $0.containsMeat == true, preferenceScore: preferenceScores[$0.id] ?? 0)
        }
        let ingredientIDs = Set(recipes.flatMap { $0.ingredients.map(\.ingredientID) })
        packages = request.catalog.offers.filter { offer in
            offer.storeID == request.profile.storeID && ingredientIDs.contains(offer.ingredientID) &&
                (request.offerOverrides?[offer.ingredientID] ?? offer.id) == offer.id
        }.map {
            Package(ingredientID: $0.ingredientID, quantity: $0.packageQuantity, priceMinorUnits: $0.priceMinorUnits)
        }
        adultHalfPortions = request.profile.adultHalfPortions
        remainingBudgetMinorUnits = max(0, request.profile.budgetMinorUnits - (request.resources?.committedMinorUnits ?? 0))
        requiresMeat = request.profile.requiresMeat
        goals = (request.profile.onboarding?.goals ?? []).map(\.rawValue).sorted()
    }
}

#if DEBUG
struct GeminiMenuProposer: MenuProposing {
    private static let logger = Logger(subsystem: "ryanmerrick.MealWise", category: "Planning")
    private static let primaryModel = "gemini-4-hydrogen"
    private static let fallbackModel = "gemini-3.5-flash-lite"
    private let apiKey: String
    private let session: URLSession

    init?(environment: [String: String] = ProcessInfo.processInfo.environment) {
        let launchKey = environment["GEMINI_API_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let key: String
        if let launchKey, !launchKey.isEmpty {
            key = launchKey
        } else {
            #if targetEnvironment(simulator)
            let keyFile = URL.applicationSupportDirectory.appending(path: ".gemini-api-key")
            guard let savedKey = try? String(contentsOf: keyFile, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines), !savedKey.isEmpty else { return nil }
            key = savedKey
            #else
            return nil
            #endif
        }
        apiKey = key
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForResource = 20
        session = URLSession(configuration: configuration)
        Self.logger.notice("Gemini client configured")
    }

    func propose(_ input: MenuProposalInput) async throws -> [[String]] {
        let menuData = String(decoding: try JSONEncoder().encode(input), as: UTF8.self)
        let prompt = """
        Propose up to three complete weekly menus in preference order. Each menu is an array with one recipe ID per slot, in the given order. Use only the IDs allowed for each slot.
        Prefer variety in proteins, vegetables, flavors, and cooking styles. If requiresMeat is true, every menu must include at least one recipe marked containsMeat. Include a mix of meat and plant-based meals when both are among the eligible choices. Avoid repeats where practical.
        Favor recipes with higher preferenceScore to reflect the user's recipe ratings and planning preferences. When goals include saveMoney, prioritize lower package costs. When goals include wasteLess, prioritize using more of each purchased package across the menu.
        The budget is a hard cap, and there is no minimum spend. Estimate costs by scaling recipe quantities to the household, combining them across slots, then rounding up to whole packages. Two adult half portions equal one adult portion. Return a lower-cost alternative when possible. Return an empty menus array if you have no suggestions.

        \(menuData)
        """
        let schema: [String: Any] = [
            "type": "object",
            "required": ["menus"],
            "properties": ["menus": [
                "type": "array",
                "maxItems": 3,
                "items": ["type": "array", "items": ["type": "string"]]
            ]]
        ]
        do {
            return try await requestMenus(model: Self.primaryModel, prompt: prompt, schema: schema)
        } catch where (error as? RequestError) == .temporarilyUnavailable || (error as? URLError)?.code == .timedOut {
            try Task.checkCancellation()
            return try await requestMenus(model: Self.fallbackModel, prompt: prompt, schema: schema)
        }
    }

    private func requestMenus(model: String, prompt: String, schema: [String: Any]) async throws -> [[String]] {
        let endpoint = URL(string: "https://generativelanguage.googleapis.com/v1beta/interactions")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2026-05-20", forHTTPHeaderField: "Api-Revision")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": model,
            "input": prompt,
            "store": false,
            "generation_config": ["thinking_level": "low"],
            "response_format": ["type": "text", "mime_type": "application/json", "schema": schema]
        ])
        Self.logger.notice("Requesting menus from \(model, privacy: .public)")
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        Self.logger.notice("\(model, privacy: .public) returned HTTP \(httpResponse.statusCode, privacy: .public)")
        if httpResponse.statusCode == 429 || (500...599).contains(httpResponse.statusCode) {
            throw RequestError.temporarilyUnavailable
        }
        guard httpResponse.statusCode == 200 else { throw URLError(.badServerResponse) }
        let decoder = JSONDecoder()
        let interaction = try decoder.decode(Interaction.self, from: data)
        guard interaction.status == "completed",
              let output = interaction.steps.last(where: { $0.type == "model_output" })?.content else { return [] }
        let json = output.filter { $0.type == "text" }.compactMap(\.text).joined()
        return try decoder.decode(Menus.self, from: Data(json.utf8)).menus
    }

    private enum RequestError: Error {
        case temporarilyUnavailable
    }

    private struct Menus: Decodable {
        let menus: [[String]]
    }

    private struct Interaction: Decodable {
        struct Step: Decodable {
            struct Part: Decodable {
                let type: String
                let text: String?
            }

            let type: String
            let content: [Part]?
        }

        let status: String
        let steps: [Step]
    }
}
#endif
