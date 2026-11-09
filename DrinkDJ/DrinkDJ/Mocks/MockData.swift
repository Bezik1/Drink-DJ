import Foundation

struct Ingredient: Identifiable {
    var id: String { name }
    let name: String
    let amount: String
}

struct FlavourLevel: Identifiable {
    var id: String { name }
    let name: String
    var level: Double
}

struct Mix {
    let name: String
    let details: String
    var match: String?
    let flavours: [FlavourLevel]
    let recipe: [Ingredient]
    let suggestions: [Ingredient]

    var isEmpty: Bool { recipe.isEmpty }
}

enum MockData {
    static let email = "demo@example.com"
    static let password = "drinkdj-demo"

    static let spirits = ["Gin", "Rum", "Tequila", "Vodka", "Whisky", "Zero-proof"]
    static let likedSpirits: Set<String> = ["Gin"]
    static let ingredients = ["Lemon", "Lime", "Honey", "Sprite", "Mint"]
    static let likedIngredients: Set<String> = ["Lemon", "Lime"]

    static let intensity = 14.0
    static let tasteLevels = [
        FlavourLevel(name: "Sweet", level: 12),
        FlavourLevel(name: "Sour", level: 16),
        FlavourLevel(name: "Spicy", level: 3),
        FlavourLevel(name: "Bitter", level: 5),
    ]
    static let characterLevels = [
        FlavourLevel(name: "Fruity", level: 11),
        FlavourLevel(name: "Herbal", level: 17),
        FlavourLevel(name: "Smoky", level: 3),
        FlavourLevel(name: "Fizz", level: 14),
    ]

    static let opinions = ["Too sweet", "Too sour", "Perfect", "Too strong"]

    static let newMix = Mix(
        name: "New mix",
        details: "0 ml · 0% · draft",
        flavours: (tasteLevels + characterLevels).map { FlavourLevel(name: $0.name, level: 0) },
        recipe: [],
        suggestions: [
            Ingredient(name: "Gin", amount: "50 ml"),
            Ingredient(name: "Vodka", amount: "50 ml"),
            Ingredient(name: "White rum", amount: "50 ml"),
            Ingredient(name: "Whisky", amount: "50 ml"),
        ]
    )

    static let blueLagoonDub = Mix(
        name: "Blue Lagoon Dub",
        details: "160 ml · 12% · v1.0",
        match: "84%",
        flavours: [
            FlavourLevel(name: "Sweet", level: 12),
            FlavourLevel(name: "Sour", level: 15),
            FlavourLevel(name: "Spicy", level: 3),
            FlavourLevel(name: "Bitter", level: 4),
            FlavourLevel(name: "Fruity", level: 10),
            FlavourLevel(name: "Herbal", level: 17),
            FlavourLevel(name: "Smoky", level: 1),
            FlavourLevel(name: "Fizz", level: 14),
        ],
        recipe: [
            Ingredient(name: "Gin", amount: "50 ml"),
            Ingredient(name: "Blue curaçao", amount: "15 ml"),
            Ingredient(name: "Lime juice", amount: "20 ml"),
            Ingredient(name: "Simple syrup", amount: "10 ml"),
            Ingredient(name: "Soda water", amount: "60 ml"),
            Ingredient(name: "Ice", amount: ""),
        ],
        suggestions: [
            Ingredient(name: "Mint", amount: "8 leaves"),
            Ingredient(name: "Elderflower", amount: "10 ml"),
            Ingredient(name: "Ginger beer", amount: "40 ml"),
        ]
    )
}
