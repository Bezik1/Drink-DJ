import Foundation

struct RemixIngredient: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var amount: Double
    var unit: String

    var quantity: String { "\(amount.formatted(.number.precision(.fractionLength(0...1)))) \(unit)" }

    init(id: UUID = UUID(), name: String, amount: Double, unit: String = "ml") {
        self.id = id
        self.name = name
        self.amount = amount
        self.unit = unit
    }

    init(_ ingredient: Ingredient, index: Int) {
        // Stable baseline identities allow restored drafts to compare against the original.
        id = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index + 1)) ?? UUID()
        name = ingredient.name
        let parts = ingredient.amount.split(separator: " ", maxSplits: 1)
        amount = parts.first.flatMap { Double($0) } ?? 1
        unit = parts.count > 1 ? String(parts[1]) : "portion"
    }
}

enum PreparationMethod: String, CaseIterable, Identifiable, Codable {
    case shake = "Shake"
    case stir = "Stir"
    case muddle = "Muddle"
    case build = "Build"
    case strain = "Strain"
    case serve = "Serve"

    var id: Self { self }
    var isTimed: Bool { self == .shake || self == .stir || self == .muddle }
    var seconds: Double { self == .stir ? 30 : self == .muddle ? 10 : 12 }
    var symbol: String {
        switch self {
        case .shake: "arrow.up.arrow.down"
        case .stir: "arrow.trianglehead.2.clockwise.rotate.90"
        case .muddle: "arrow.down.to.line"
        case .build: "plus"
        case .strain: "line.3.horizontal.decrease"
        case .serve: "wineglass"
        }
    }
    var guidance: String {
        switch self {
        case .shake: "Chills, mixes, and adds air. Shake the non-carbonated ingredients; add soda afterward."
        case .stir: "Chills and mixes with less air. Expect a smoother, less airy texture than shaking."
        case .muddle: "Press gently to release juice and aroma. Avoid shredding herbs, which can taste bitter."
        case .build: "Add ingredients directly to the glass. Add carbonated mixers last and stir gently."
        case .strain: "Separate the drink from the mixing ice. Double strain to catch fine pulp and herb pieces."
        case .serve: "Choose a glass and finishing touches. Fresh ice keeps the drink cold as you sip."
        }
    }
}

struct RemixPreparationStep: Identifiable, Codable, Equatable {
    var id = UUID()
    var method: PreparationMethod
    var seconds: Double
    var ice = "Cubed ice"
    var intensity = "Gentle"
    var straining = "Single strain"
    var glass = "Rocks glass"
    var garnish = ""

    init(id: UUID = UUID(), method: PreparationMethod) {
        self.id = id
        self.method = method
        seconds = method.seconds
        intensity = method == .shake ? "Vigorous" : "Gentle"
    }

    var summary: String {
        if method.isTimed { return "\(Int(seconds)) sec · \(ice)" }
        switch method {
        case .strain: return straining
        case .serve: return "\(glass) · \(ice)"
        default: return "In the serving glass"
        }
    }
}

struct RemixRecipe: Codable, Equatable {
    var source: String
    var ingredients: [RemixIngredient]
    var steps: [RemixPreparationStep]

    static func startingRecipe(for mix: Mix) -> Self {
        let base: [Ingredient] = mix.isEmpty ? [
            Ingredient(name: "Tequila", amount: "50 ml"),
            Ingredient(name: "Lime juice", amount: "30 ml"),
            Ingredient(name: "Orange liqueur", amount: "20 ml")
        ] : mix.recipe
        let name = mix.isEmpty ? "Classic Margarita" : mix.name
        let lower = name.lowercased()
        let methods: [PreparationMethod]
        if lower.contains("mojito") { methods = [.muddle, .build, .serve] }
        else if lower.contains("martini") || lower.contains("negroni") { methods = [.stir, .strain, .serve] }
        else if base.contains(where: { $0.name.lowercased().contains("soda") || $0.name.lowercased().contains("tonic") }) {
            methods = [.build, .serve]
        } else { methods = [.shake, .strain, .serve] }
        let steps = methods.enumerated().map { index, method in
            var step = RemixPreparationStep(
                id: UUID(uuidString: String(format: "00000000-0000-0000-0001-%012d", index + 1)) ?? UUID(),
                method: method
            )
            if lower.contains("margarita") && method == .serve {
                step.glass = "Coupe"
                step.ice = "No ice"
                step.garnish = "Lime wheel · optional salt rim"
            }
            return step
        }
        return Self(source: name, ingredients: base.enumerated().map { RemixIngredient($0.element, index: $0.offset) }, steps: steps)
    }

    // Directional prototype estimates, not a calibrated flavour or alcohol model.
    func estimate(_ dimension: String) -> Double {
        let liquid = ingredients.filter { $0.unit == "ml" }
        let total = liquid.reduce(0) { $0 + $1.amount }
        guard total > 0 else { return 0 }
        let contribution = liquid.reduce(0.0) { result, ingredient in
            let name = ingredient.name.lowercased()
            let matches: Bool
            switch dimension {
            case "Sweet":
                matches = ["syrup", "liqueur", "curaçao", "honey", "agave", "juice", "ginger beer"].contains { name.contains($0) }
                    && !name.contains("lime") && !name.contains("lemon")
            case "Sour": matches = ["lime", "lemon", "grapefruit", "citrus"].contains { name.contains($0) }
            case "Bitter": matches = ["campari", "aperol", "bitters", "tonic", "coffee", "espresso"].contains { name.contains($0) }
            default: matches = ["gin", "vodka", "rum", "tequila", "whisky", "whiskey", "mezcal"].contains { name.contains($0) }
                && !name.contains("zero") && !name.contains("syrup")
            }
            return result + (matches ? ingredient.amount : 0)
        }
        return min(1, contribution / total * (dimension == "Strong" ? 1.3 : 2))
    }
}

struct SavedRemix: Identifiable, Codable {
    let id: UUID
    let name: String
    let date: Date
    let recipe: RemixRecipe
    let original: RemixRecipe
}

