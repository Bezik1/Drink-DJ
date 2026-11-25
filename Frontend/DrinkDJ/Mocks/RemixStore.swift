import Foundation
import Observation

enum TasteDimension: String, CaseIterable, Identifiable, Codable {
    case sweet = "Sweet"
    case sour = "Sour"
    case bitter = "Bitter"
    case strong = "Strong"

    var id: Self { self }
}

struct PreferenceLevel: Identifiable, Codable, Equatable {
    var id: String { name }
    let name: String
    var level: Double
}

struct TastePreferences: Codable, Equatable {
    var intensity: Double
    var taste: [PreferenceLevel]
    var character: [PreferenceLevel]
    var likedSpirits: Set<String>
    var likedIngredients: Set<String>

    static var initial: Self {
        Self(
            intensity: MockData.intensity,
            taste: MockData.tasteLevels.map { PreferenceLevel(name: $0.name, level: $0.level) },
            character: MockData.characterLevels.map { PreferenceLevel(name: $0.name, level: $0.level) },
            likedSpirits: MockData.likedSpirits,
            likedIngredients: MockData.likedIngredients
        )
    }

    func target(_ dimension: TasteDimension) -> Double {
        let value = dimension == .strong ? intensity : taste.first { $0.name == dimension.rawValue }?.level ?? 10
        return min(1, max(0, value / 20))
    }

    mutating func setTarget(_ target: Double, for dimension: TasteDimension) {
        let level = min(20, max(0, target * 20))
        if dimension == .strong {
            intensity = level
        } else if let index = taste.firstIndex(where: { $0.name == dimension.rawValue }) {
            taste[index].level = level
        } else {
            taste.append(PreferenceLevel(name: dimension.rawValue, level: level))
        }
    }
}

struct RemixMatch: Equatable {
    static let modelVersion = "ingredient-ratios-v1"
    let percent: Int
    let tastePercent: Int
    let favoritesPercent: Int?

    static func estimate(recipe: RemixRecipe, preferences: TastePreferences) -> Self {
        guard recipe.ingredients.contains(where: { $0.amount > 0 }) else {
            return Self(percent: 0, tastePercent: 0, favoritesPercent: nil)
        }
        let distance = TasteDimension.allCases.reduce(0.0) {
            $0 + abs(recipe.estimate($1.rawValue) - preferences.target($1))
        } / Double(TasteDimension.allCases.count)
        let taste = min(1, max(0, 1 - distance))
        let names = recipe.ingredients.filter { $0.amount > 0 }.map { $0.name.lowercased() }
        let favorites = preferences.likedSpirits.union(preferences.likedIngredients)
        let affinity: Double? = favorites.isEmpty ? nil : (
            favorites.contains { favorite in names.contains { $0.contains(favorite.lowercased()) } } ? 1 : 0
        )
        let combined = affinity.map { taste * 0.85 + $0 * 0.15 } ?? taste
        return Self(
            percent: Int((combined * 100).rounded()),
            tastePercent: Int((taste * 100).rounded()),
            favoritesPercent: affinity.map { Int($0 * 100) }
        )
    }
}

struct RemixWorkingCopy: Codable, Equatable {
    var recipe: RemixRecipe
    var original: RemixRecipe
    var baseVersionID: UUID?
}

struct RemixVersion: Identifiable, Codable, Equatable {
    let id: UUID
    let rootID: UUID
    let parentID: UUID?
    let number: Int
    let branch: String
    let name: String
    let message: String
    let date: Date
    let recipe: RemixRecipe
    let original: RemixRecipe
    let preferences: TastePreferences
    let estimatedMatch: Int
    let matchModelVersion: String

    var label: String { "v\(number) · \(branch)" }
}

enum TastePerception: String, CaseIterable, Identifiable, Codable {
    case notRated = "Not rated"
    case tooLittle = "Too little"
    case justRight = "Just right"
    case tooMuch = "Too much"

    var id: Self { self }
}

struct TasteAssessment: Identifiable, Codable, Equatable {
    var id: TasteDimension { dimension }
    let dimension: TasteDimension
    var perception: TastePerception = .notRated
}

struct TastingFeedback: Identifiable, Codable {
    let id: UUID
    let date: Date
    let revisionID: UUID?
    let baseRevisionID: UUID?
    let recipe: RemixRecipe
    let rating: Int
    let assessments: [TasteAssessment]
    let notes: String
    let preferencesBefore: TastePreferences
    let preferencesAfter: TastePreferences
    let learned: Bool
    let learningEnabled: Bool
    let confirmedTasted: Bool
    let estimatedMatch: Int
    let modelVersion: String
}

struct PreferenceChange: Identifiable, Codable {
    let id: UUID
    let date: Date
    let feedbackID: UUID?
    let before: TastePreferences
    let after: TastePreferences
}

struct RemixDraftBackup: Identifiable, Codable {
    let id: UUID
    let date: Date
    let copy: RemixWorkingCopy
}

struct RemixArchive: Codable {
    let schemaVersion: Int
    let participantID: UUID
    var preferences: TastePreferences
    var versions: [RemixVersion]
    var feedback: [TastingFeedback]
    var preferenceChanges: [PreferenceChange]
    var draftBackups: [RemixDraftBackup]

    static var empty: Self {
        Self(schemaVersion: 1, participantID: UUID(), preferences: .initial, versions: [], feedback: [], preferenceChanges: [], draftBackups: [])
    }
}

struct RemixExport: Codable {
    let schemaVersion: Int
    let exportedAt: Date
    let matchModelVersion: String
    let archive: RemixArchive
    let drafts: [RemixWorkingCopy]
}

enum RemixDataError: LocalizedError {
    case unreadable
    case invalidParent
    case branchExists
    case invalidFeedback

    var errorDescription: String? {
        switch self {
        case .unreadable: "Existing remix data could not be read. It has been preserved; new data was not written over it."
        case .invalidParent: "The starting version is unavailable. Reopen a version from history and try again."
        case .branchExists: "That branch already has a newer version. Choose another branch name or check out its latest version."
        case .invalidFeedback: "Choose a rating and confirm that you tasted this recipe."
        }
    }
}

@MainActor
@Observable
final class RemixStore {
    static let shared = RemixStore()
    private(set) var archive: RemixArchive
    private(set) var loadError: String?
    private let defaults: UserDefaults
    private var readOnly = false
    private static let archiveKey = "mixer.research.v1"

    var preferences: TastePreferences { archive.preferences }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        var initial = RemixArchive.empty
        var errorMessage: String?
        var blocked = false
        if let data = defaults.data(forKey: Self.archiveKey) {
            do {
                initial = try JSONDecoder().decode(RemixArchive.self, from: data)
                guard initial.schemaVersion == 1 else { throw RemixDataError.unreadable }
            } catch {
                errorMessage = RemixDataError.unreadable.localizedDescription
                blocked = true
            }
        } else if let data = defaults.data(forKey: "mixer.saved.v2") {
            do {
                let legacy = try JSONDecoder().decode([SavedRemix].self, from: data).sorted { $0.date < $1.date }
                var roots: [String: UUID] = [:]
                for item in legacy {
                    let root = roots[item.recipe.source] ?? UUID()
                    roots[item.recipe.source] = root
                    let number = initial.versions.filter { $0.rootID == root }.count + 1
                    initial.versions.append(RemixVersion(
                        id: item.id, rootID: root, parentID: nil, number: number,
                        branch: "imported-\(number)", name: item.name,
                        message: "Imported earlier save; ancestry was not recorded.",
                        date: item.date, recipe: item.recipe, original: item.original,
                        preferences: initial.preferences,
                        estimatedMatch: RemixMatch.estimate(recipe: item.recipe, preferences: initial.preferences).percent,
                        matchModelVersion: RemixMatch.modelVersion
                    ))
                }
            } catch {
                errorMessage = RemixDataError.unreadable.localizedDescription
                blocked = true
            }
        }
        if !blocked && defaults.data(forKey: Self.archiveKey) == nil {
            do {
                defaults.set(try JSONEncoder().encode(initial), forKey: Self.archiveKey)
            } catch {
                errorMessage = error.localizedDescription
                blocked = true
            }
        }
        archive = initial
        loadError = errorMessage
        readOnly = blocked
    }

    func versions(for source: String) -> [RemixVersion] {
        archive.versions.filter { $0.recipe.source == source }.sorted { $0.number > $1.number }
    }

    func version(_ id: UUID?) -> RemixVersion? {
        guard let id else { return nil }
        return archive.versions.first { $0.id == id }
    }

    func isHead(_ version: RemixVersion) -> Bool {
        !archive.versions.contains { $0.rootID == version.rootID && $0.branch == version.branch && $0.number > version.number }
    }

    func suggestedBranch(for copy: RemixWorkingCopy) -> String {
        if let parent = version(copy.baseVersionID) {
            return isHead(parent) ? parent.branch : "experiment-\(versions(for: copy.recipe.source).count + 1)"
        }
        return versions(for: copy.recipe.source).isEmpty ? "main" : "experiment-\(versions(for: copy.recipe.source).count + 1)"
    }

    @discardableResult
    func commit(copy: RemixWorkingCopy, name: String, message: String, branch: String) throws -> RemixVersion {
        let parent = version(copy.baseVersionID)
        if copy.baseVersionID != nil && parent == nil { throw RemixDataError.invalidParent }
        if let parent, parent.recipe.source != copy.recipe.source { throw RemixDataError.invalidParent }
        let root = parent?.rootID ?? versions(for: copy.recipe.source).first?.rootID ?? UUID()
        let branchName = branch.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeBranch = branchName.isEmpty ? suggestedBranch(for: copy) : branchName
        let existingHead = archive.versions
            .filter { $0.rootID == root && $0.branch == safeBranch }
            .max { $0.number < $1.number }
        if let existingHead, existingHead.id != parent?.id { throw RemixDataError.branchExists }
        let number = (archive.versions.filter { $0.rootID == root }.map(\.number).max() ?? 0) + 1
        let revision = RemixVersion(
            id: UUID(), rootID: root, parentID: parent?.id, number: number, branch: safeBranch,
            name: name, message: message, date: Date(), recipe: copy.recipe, original: copy.original,
            preferences: preferences,
            estimatedMatch: RemixMatch.estimate(recipe: copy.recipe, preferences: preferences).percent,
            matchModelVersion: RemixMatch.modelVersion
        )
        var updated = archive
        updated.versions.append(revision)
        try persist(updated)
        return revision
    }

    func updatePreferences(_ preferences: TastePreferences) throws {
        guard preferences != archive.preferences else { return }
        var updated = archive
        updated.preferenceChanges.append(PreferenceChange(id: UUID(), date: Date(), feedbackID: nil, before: updated.preferences, after: preferences))
        updated.preferences = preferences
        try persist(updated)
    }

    @discardableResult
    func recordTasting(
        copy: RemixWorkingCopy, rating: Int, assessments: [TasteAssessment],
        notes: String, tasted: Bool, learn: Bool
    ) throws -> TastingFeedback {
        guard tasted, (1...5).contains(rating), !copy.recipe.ingredients.isEmpty else {
            throw RemixDataError.invalidFeedback
        }
        let before = preferences
        var after = before
        if learn {
            for dimension in TasteDimension.allCases {
                let perception = assessments.first { $0.dimension == dimension }?.perception ?? .notRated
                let actual = copy.recipe.estimate(dimension.rawValue)
                let target: Double?
                switch perception {
                case .tooMuch: target = max(0, min(before.target(dimension) - 0.05, actual - 0.15))
                case .tooLittle: target = min(1, max(before.target(dimension) + 0.05, actual + 0.15))
                case .justRight: target = actual
                case .notRated: target = rating >= 4 ? actual : nil
                }
                if let target {
                    // Move gently toward a tasted preference, preserving the user's other settings.
                    after.setTarget(before.target(dimension) * 0.75 + target * 0.25, for: dimension)
                }
            }
        }
        let revision = version(copy.baseVersionID)
        let feedback = TastingFeedback(
            id: UUID(), date: Date(),
            revisionID: revision?.recipe == copy.recipe ? revision?.id : nil,
            baseRevisionID: copy.baseVersionID,
            recipe: copy.recipe, rating: rating, assessments: assessments, notes: notes,
            preferencesBefore: before, preferencesAfter: after, learned: after != before,
            learningEnabled: learn, confirmedTasted: tasted,
            estimatedMatch: RemixMatch.estimate(recipe: copy.recipe, preferences: before).percent,
            modelVersion: RemixMatch.modelVersion
        )
        var updated = archive
        updated.feedback.append(feedback)
        if after != before {
            updated.preferences = after
            updated.preferenceChanges.append(PreferenceChange(id: UUID(), date: feedback.date, feedbackID: feedback.id, before: before, after: after))
        }
        try persist(updated)
        return feedback
    }

    func preserveDraft(_ copy: RemixWorkingCopy) throws {
        guard archive.draftBackups.last?.copy != copy else { return }
        var updated = archive
        updated.draftBackups.append(RemixDraftBackup(id: UUID(), date: Date(), copy: copy))
        try persist(updated)
    }

    func loadDraft(baseline: RemixRecipe) -> RemixWorkingCopy {
        if let data = defaults.data(forKey: draftKey(baseline.source)),
           let copy = try? JSONDecoder().decode(RemixWorkingCopy.self, from: data) {
            return copy
        }
        let legacy = defaults.data(forKey: "mixer.draft.v2.\(baseline.source)")
            .flatMap { try? JSONDecoder().decode(RemixRecipe.self, from: $0) }
        return RemixWorkingCopy(recipe: legacy ?? baseline, original: baseline, baseVersionID: nil)
    }

    func saveDraft(_ copy: RemixWorkingCopy) throws {
        guard !readOnly else { throw RemixDataError.unreadable }
        defaults.set(try JSONEncoder().encode(copy), forKey: draftKey(copy.recipe.source))
    }

    func exportData() throws -> Data {
        guard !readOnly else { throw RemixDataError.unreadable }
        let drafts = defaults.dictionaryRepresentation().compactMap { key, value -> RemixWorkingCopy? in
            guard key.hasPrefix("mixer.draft.v3."), let data = value as? Data else { return nil }
            return try? JSONDecoder().decode(RemixWorkingCopy.self, from: data)
        }
        let export = RemixExport(schemaVersion: 1, exportedAt: Date(), matchModelVersion: RemixMatch.modelVersion, archive: archive, drafts: drafts)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(export)
    }

    private func draftKey(_ source: String) -> String { "mixer.draft.v3.\(source)" }

    private func persist(_ updated: RemixArchive) throws {
        guard !readOnly else { throw RemixDataError.unreadable }
        let data = try JSONEncoder().encode(updated)
        defaults.set(data, forKey: Self.archiveKey)
        archive = updated
    }
}

enum RemixSuggestion {
    static func recipe(after feedback: TastingFeedback) -> RemixRecipe {
        var recipe = feedback.recipe
        for index in recipe.ingredients.indices {
            guard recipe.ingredients[index].unit == "ml", recipe.ingredients[index].amount > 0 else { continue }
            let name = recipe.ingredients[index].name.lowercased()
            let dimension: TasteDimension?
            if ["lime", "lemon", "grapefruit", "citrus"].contains(where: { name.contains($0) }) { dimension = .sour }
            else if ["syrup", "honey", "agave", "liqueur", "curaçao"].contains(where: { name.contains($0) }) { dimension = .sweet }
            else if ["campari", "aperol", "bitters", "tonic", "coffee", "espresso"].contains(where: { name.contains($0) }) { dimension = .bitter }
            else if ["gin", "vodka", "rum", "tequila", "whisky", "whiskey", "mezcal"].contains(where: { name.contains($0) }) && !name.contains("zero") { dimension = .strong }
            else { dimension = nil }
            guard let dimension,
                  let perception = feedback.assessments.first(where: { $0.dimension == dimension })?.perception else { continue }
            let multiplier = perception == .tooMuch ? 0.85 : perception == .tooLittle ? 1.15 : 1
            if multiplier != 1 {
                recipe.ingredients[index].amount = max(1, (recipe.ingredients[index].amount * multiplier).rounded())
            }
        }
        return recipe
    }
}
