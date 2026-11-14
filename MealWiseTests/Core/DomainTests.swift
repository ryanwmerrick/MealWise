import Foundation
import Testing
@testable import MealWise

struct DomainTests {
    @Test func moneyDoesNotUseBinaryFloatingPoint() throws {
        let total = try Money.parse("0.10").adding(Money.parse("0.20"))
        #expect(total.minorUnits == 30)
        #expect(try Money.parse("64.30").minorUnits == 6430)
    }

    @Test(arguments: ["-1", "1.001", "1e2", "1,000", "", ".", "NaN"])
    func malformedMoneyRejected(_ text: String) {
        #expect(throws: MoneyError.self) { try Money.parse(text) }
    }

    @Test func overflowRejected() throws {
        let largest = try Money(minorUnits: Int64.max)
        #expect(throws: MoneyError.self) { try largest.adding(Money(minorUnits: 1)) }
    }

    @Test func invalidDecodedMoneyRejected() {
        let payload = Data(#"{"minorUnits":-1,"currencyCode":"USD"}"#.utf8)
        #expect(throws: MoneyError.self) { try JSONDecoder().decode(Money.self, from: payload) }
    }

    @Test func invalidDecodedQuantityRejected() {
        let payload = Data(#"{"canonicalAmount":-1,"unit":"milligrams"}"#.utf8)
        #expect(throws: QuantityError.self) { try JSONDecoder().decode(Quantity.self, from: payload) }
    }

    @Test func packageBoundaryRoundsUp() throws {
        let offer = PackageOffer(id: "test", ingredientID: "rice", storeID: "development-grocery", packageQuantity: 500000, unit: .milligrams, priceMinorUnits: 249, currencyCode: "USD", priceDate: "2026-11-13", validThrough: "2026-12-13", provenance: "Synthetic test", reviewStatus: .developmentApproved)
        #expect(try offer.purchaseCost(for: Quantity(amount: 501, unit: .grams)).minorUnits == 498)
        #expect(try offer.purchaseCost(for: Quantity(amount: 500, unit: .grams)).minorUnits == 249)
    }

    @Test func incompatibleUnitsRejected() throws {
        let mass = try Quantity(amount: 1, unit: .grams)
        #expect(throws: QuantityError.self) { try mass.adding(Quantity(amount: 1, unit: .milliliters)) }
        #expect(try Quantity(amount: 1, unit: .kilograms).canonicalAmount == 1000000)
    }

    @Test func invalidHouseholdRejected() throws {
        var profile = PlanningProfile.fixture
        profile.adults = 0
        #expect(throws: ProfileError.self) { try profile.validate() }
        profile.adults = 1
        profile.children = -1
        #expect(throws: ProfileError.self) { try profile.validate() }
    }

    @Test func duplicateDaysRejected() {
        var profile = PlanningProfile.fixture
        profile.days = [profile.days[0], profile.days[0].addingTimeInterval(60)]
        #expect(throws: ProfileError.self) { try profile.validate() }
    }

    @Test func unknownAllergenIsNotSafe() {
        let ingredient = Ingredient(id: "rice", name: "Rice", allergens: [], allergensVerified: false, reviewStatus: .developmentApproved, nutrition: .init(vegetable: false, protein: false, wholeGrain: true), unit: .milligrams)
        #expect(!ingredient.isSafe(excluding: [.peanut]))
    }
}

extension PlanningProfile {
    static var fixture: PlanningProfile {
        PlanningProfile(budgetMinorUnits: 7000, adults: 1, children: 2,
                        days: [Date(timeIntervalSince1970: 1794528000)], mealSlots: [.dinner],
                        cookingTime: .thirty, skill: .beginner, storeID: "development-grocery",
                        allergies: [], preferences: [])
    }
}
