import Foundation
import Testing
@testable import RemixCore

@MainActor
struct RemixTests {
    func isolatedStore() throws -> (String, UserDefaults, RemixStore) {
        let suite = "DrinkDJ.validation." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        return (suite, defaults, RemixStore(defaults: defaults))
    }

    @Test func immutableVersionsForkAndProtectBranchHeads() throws {
        let (suite, defaults, store) = try isolatedStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        let original = RemixRecipe.startingRecipe(for: MockData.newMix)
        let v1 = try store.commit(copy: .init(recipe: original, original: original, baseVersionID: nil), name: "Original", message: "", branch: "main")
        var second = RemixWorkingCopy(recipe: original, original: original, baseVersionID: v1.id)
        let lime = try #require(second.recipe.ingredients.firstIndex { $0.name == "Lime juice" })
        second.recipe.ingredients[lime].amount = 15
        let v2 = try store.commit(copy: second, name: "Less lime", message: "", branch: "main")
        #expect(v2.parentID == v1.id)
        #expect(v2.number == 2)
        let fork = RemixWorkingCopy(recipe: original, original: original, baseVersionID: v1.id)
        let v3 = try store.commit(copy: fork, name: "Fork", message: "", branch: store.suggestedBranch(for: fork))
        #expect(v3.parentID == v1.id)
        #expect(v3.rootID == v1.rootID)
        #expect(v3.branch != "main")
        #expect(store.version(v1.id)?.recipe == original)
        #expect(store.version(v2.id)?.recipe.ingredients[lime].amount == 15)
        #expect(throws: RemixDataError.branchExists) {
            try store.commit(copy: fork, name: "Invalid", message: "", branch: "main")
        }
        #expect(store.archive.versions.count == 3)
    }

    @Test func feedbackLinksExactRecipeAndLearnsInCorrectDirection() throws {
        let (suite, defaults, store) = try isolatedStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        let original = RemixRecipe.startingRecipe(for: MockData.newMix)
        let version = try store.commit(copy: .init(recipe: original, original: original, baseVersionID: nil), name: "Original", message: "", branch: "main")
        var copy = RemixWorkingCopy(recipe: original, original: original, baseVersionID: version.id)
        copy.recipe.ingredients[0].amount += 5
        let before = store.preferences
        let feedback = try store.recordTasting(copy: copy, rating: 3, assessments: [.init(dimension: .sweet, perception: .tooMuch)], notes: "Too sweet", tasted: true, learn: true)
        #expect(feedback.revisionID == nil)
        #expect(feedback.baseRevisionID == version.id)
        #expect(feedback.recipe == copy.recipe)
        #expect(feedback.preferencesBefore == before)
        #expect(store.preferences.target(.sweet) < before.target(.sweet))
        #expect(store.version(version.id)?.recipe == original)
        #expect(RemixSuggestion.recipe(after: feedback) != feedback.recipe)
        let learned = store.preferences
        _ = try store.recordTasting(copy: copy, rating: 5, assessments: [.init(dimension: .strong, perception: .tooLittle)], notes: "Opt out", tasted: true, learn: false)
        #expect(store.preferences == learned)
        #expect(throws: RemixDataError.invalidFeedback) {
            try store.recordTasting(copy: copy, rating: 5, assessments: [], notes: "", tasted: false, learn: true)
        }
        #expect(store.archive.feedback.count == 2)
        let exact = try store.recordTasting(copy: .init(recipe: original, original: original, baseVersionID: version.id), rating: 4, assessments: [], notes: "", tasted: true, learn: false)
        #expect(exact.revisionID == version.id)
    }

    @Test func participantPreferencesDraftsAndExportSurviveReload() throws {
        let (suite, defaults, store) = try isolatedStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        let participant = store.archive.participantID
        #expect(RemixStore(defaults: defaults).archive.participantID == participant)
        var preferences = store.preferences
        preferences.intensity = 2
        try store.updatePreferences(preferences)
        let original = RemixRecipe.startingRecipe(for: MockData.newMix)
        let copy = RemixWorkingCopy(recipe: original, original: original, baseVersionID: nil)
        try store.saveDraft(copy)
        try store.preserveDraft(copy)
        let reload = RemixStore(defaults: defaults)
        #expect(reload.preferences == preferences)
        #expect(reload.loadDraft(baseline: original) == copy)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let export = try decoder.decode(RemixExport.self, from: reload.exportData())
        #expect(export.archive.participantID == participant)
        #expect(export.archive.preferenceChanges.count == 1)
        #expect(export.archive.draftBackups.count == 1)
        #expect(export.drafts.contains(copy))
        #expect(export.matchModelVersion == RemixMatch.modelVersion)
    }

    @Test func migrationPreservesLegacySavesAndCorruptionIsNotOverwritten() throws {
        let suite = "DrinkDJ.validation." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let original = RemixRecipe.startingRecipe(for: MockData.newMix)
        let legacy = SavedRemix(id: UUID(), name: "Legacy", date: Date(), recipe: original, original: original)
        defaults.set(try JSONEncoder().encode([legacy]), forKey: "mixer.saved.v2")
        let migrated = RemixStore(defaults: defaults)
        #expect(migrated.archive.versions.first?.id == legacy.id)
        let root = migrated.archive.versions.first?.rootID
        #expect(RemixStore(defaults: defaults).archive.versions.first?.rootID == root)
        let broken = Data("unreadable".utf8)
        defaults.set(broken, forKey: "mixer.research.v1")
        let blocked = RemixStore(defaults: defaults)
        #expect(blocked.loadError != nil)
        var changed = TastePreferences.initial
        changed.intensity = 1
        #expect(throws: RemixDataError.unreadable) { try blocked.updatePreferences(changed) }
        #expect(defaults.data(forKey: "mixer.research.v1") == broken)
    }

    @Test func matchActuallyUsesSavedPreferences() throws {
        let recipe = RemixRecipe.startingRecipe(for: MockData.newMix)
        var close = TastePreferences.initial
        close.likedIngredients = []
        close.likedSpirits = []
        var far = close
        for dimension in TasteDimension.allCases {
            let actual = recipe.estimate(dimension.rawValue)
            close.setTarget(actual, for: dimension)
            far.setTarget(actual < 0.5 ? 1 : 0, for: dimension)
        }
        #expect(RemixMatch.estimate(recipe: recipe, preferences: close).percent == 100)
        #expect(RemixMatch.estimate(recipe: recipe, preferences: far).percent < 100)
    }
}
