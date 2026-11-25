import SwiftUI

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

enum AlbumArtwork {
    case symbol(String)
    case asset(String)
}

struct AlbumItem: Identifiable {
    let id: String
    let title: String
    let artwork: AlbumArtwork
    var drinkIDs: [String] = []
    var photoData: Data? = nil
    var drinkCount: Int {
        drinkIDs.count
    }
}

struct AlbumDrink: Identifiable {
    let id: String
    let name: String
    let imageName: String
}


enum LibraryCategory: String, CaseIterable, Identifiable {
    case all
    case gin
    case rum
    case tequila
    case vodka
    case zeroProof

    var id: Self { self }

    var title: String {
        switch self {
        case .all: "All"
        case .gin: "Gin"
        case .rum: "Rum"
        case .tequila: "Tequila"
        case .vodka: "Vodka"
        case .zeroProof: "Zero-proof"
        }
    }

    var symbolName: String {
        switch self {
        case .all: "sparkles"
        case .gin: "leaf"
        case .rum: "sun.max"
        case .tequila: "flame"
        case .vodka: "snowflake"
        case .zeroProof: "drop"
        }
    }
}

struct LibraryDrink: Identifiable {
    let id: String
    let name: String
    let category: LibraryCategory
    let flavours: Set<String>
    let ingredients: [String]
    let symbolName: String
    let tint: Color
    let mix: Mix
}

enum MockData {
    static let email = "demo@example.com"
    static let password = "drinkdj-demo"
    static let profileName = "Team Sigma"
    static let profileJoinedDate = "12.10.2026"

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

    static let libraryAlcohols = ["Gin", "Rum", "Tequila", "Vodka", "Zero-proof"]
    static let libraryFlavours = ["Sweet", "Sour", "Spicy", "Bitter", "Fruity", "Herbal", "Smoky", "Fizz"]
    static let libraryIngredients = [
        "White rum", "Lime", "Mint", "Vodka", "Blue curaçao", "Lemon",
        "Gin", "Soda", "Tequila", "Grapefruit", "Espresso", "Coffee liqueur",
        "Rosemary", "Tonic"
    ]

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
    
    static let profileImageName = "cat_pfp"

    static let albums: [AlbumItem] = [
        AlbumItem(
            id: "favourites",
            title: "Favourites",
            artwork: .symbol("star"),
            drinkIDs: ["mojito", "blue-lagoon", "espresso-martini"]
        ),
        AlbumItem(
            id: "to-check-out",
            title: "To Check Out",
            artwork: .symbol("wineglass"),
            drinkIDs: ["citrus-garden"]
        ),
        AlbumItem(
            id: "your-drinks",
            title: "Your Drinks",
            artwork: .symbol("flask"),
            drinkIDs: ["blue-lagoon"]
        ),
        AlbumItem(
            id: "album-1",
            title: "Album1",
            artwork: .asset("cat_album1"),
            drinkIDs: ["mojito", "blue-lagoon","tom-collins","citrus-garden","paloma"]
        ),
        AlbumItem(
            id: "bitter-ones",
            title: "Bitter ones",
            artwork: .asset("cat_album2"),
            drinkIDs: []
        )
    ]

    static let libraryDrinks: [LibraryDrink] = [
        LibraryDrink(
            id: "mojito",
            name: "Mojito",
            category: .rum,
            flavours: ["Sweet", "Sour", "Herbal", "Fizz"],
            ingredients: ["White rum", "Lime", "Mint"],
            symbolName: "leaf.fill",
            tint: .green,
            mix: Mix(
                name: "Mojito",
                details: "180 ml · 11% · classic",
                match: "91%",
                flavours: tasteLevels + characterLevels,
                recipe: [
                    Ingredient(name: "White rum", amount: "50 ml"),
                    Ingredient(name: "Lime juice", amount: "25 ml"),
                    Ingredient(name: "Simple syrup", amount: "15 ml"),
                    Ingredient(name: "Mint", amount: "8 leaves"),
                    Ingredient(name: "Soda water", amount: "90 ml")
                ],
                suggestions: [
                    Ingredient(name: "Cucumber", amount: "3 slices"),
                    Ingredient(name: "Ginger beer", amount: "40 ml")
                ]
            )
        ),
        LibraryDrink(
            id: "blue-lagoon",
            name: "Blue Lagoon",
            category: .vodka,
            flavours: ["Sweet", "Sour", "Fruity", "Fizz"],
            ingredients: ["Vodka", "Blue curaçao", "Lemon"],
            symbolName: "water.waves",
            tint: .cyan,
            mix: blueLagoonDub
        ),
        LibraryDrink(
            id: "tom-collins",
            name: "Tom Collins",
            category: .gin,
            flavours: ["Sour", "Herbal", "Fizz"],
            ingredients: ["Gin", "Lemon", "Soda"],
            symbolName: "bubbles.and.sparkles.fill",
            tint: .yellow,
            mix: Mix(
                name: "Tom Collins",
                details: "170 ml · 10% · classic",
                match: "88%",
                flavours: tasteLevels + characterLevels,
                recipe: [
                    Ingredient(name: "Gin", amount: "50 ml"),
                    Ingredient(name: "Lemon juice", amount: "25 ml"),
                    Ingredient(name: "Simple syrup", amount: "15 ml"),
                    Ingredient(name: "Soda water", amount: "80 ml")
                ],
                suggestions: [
                    Ingredient(name: "Basil", amount: "4 leaves"),
                    Ingredient(name: "Elderflower", amount: "10 ml")
                ]
            )
        ),
        LibraryDrink(
            id: "paloma",
            name: "Paloma",
            category: .tequila,
            flavours: ["Sour", "Bitter", "Fruity", "Fizz"],
            ingredients: ["Tequila", "Grapefruit", "Lime"],
            symbolName: "sun.haze.fill",
            tint: .orange,
            mix: Mix(
                name: "Paloma",
                details: "190 ml · 10% · classic",
                match: "86%",
                flavours: tasteLevels + characterLevels,
                recipe: [
                    Ingredient(name: "Tequila", amount: "50 ml"),
                    Ingredient(name: "Grapefruit soda", amount: "120 ml"),
                    Ingredient(name: "Lime juice", amount: "15 ml"),
                    Ingredient(name: "Salt", amount: "1 pinch")
                ],
                suggestions: [
                    Ingredient(name: "Chilli", amount: "1 slice"),
                    Ingredient(name: "Agave syrup", amount: "10 ml")
                ]
            )
        ),
        LibraryDrink(
            id: "espresso-martini",
            name: "Espresso Martini",
            category: .vodka,
            flavours: ["Sweet", "Bitter", "Smoky"],
            ingredients: ["Vodka", "Espresso", "Coffee liqueur"],
            symbolName: "cup.and.saucer.fill",
            tint: .brown,
            mix: Mix(
                name: "Espresso Martini",
                details: "100 ml · 18% · modern classic",
                match: "82%",
                flavours: tasteLevels + characterLevels,
                recipe: [
                    Ingredient(name: "Vodka", amount: "40 ml"),
                    Ingredient(name: "Coffee liqueur", amount: "25 ml"),
                    Ingredient(name: "Espresso", amount: "35 ml")
                ],
                suggestions: [
                    Ingredient(name: "Vanilla syrup", amount: "10 ml"),
                    Ingredient(name: "Cocoa", amount: "1 pinch")
                ]
            )
        ),
        LibraryDrink(
            id: "citrus-garden",
            name: "Citrus Garden",
            category: .zeroProof,
            flavours: ["Sour", "Bitter", "Fruity", "Herbal", "Fizz"],
            ingredients: ["Grapefruit", "Rosemary", "Tonic"],
            symbolName: "camera.macro",
            tint: .pink,
            mix: Mix(
                name: "Citrus Garden",
                details: "200 ml · 0% · zero-proof",
                match: "94%",
                flavours: tasteLevels + characterLevels,
                recipe: [
                    Ingredient(name: "Grapefruit juice", amount: "60 ml"),
                    Ingredient(name: "Lime juice", amount: "15 ml"),
                    Ingredient(name: "Rosemary syrup", amount: "15 ml"),
                    Ingredient(name: "Tonic water", amount: "110 ml")
                ],
                suggestions: [
                    Ingredient(name: "Juniper", amount: "3 berries"),
                    Ingredient(name: "Mint", amount: "4 leaves")
                ]
            )
        )
    ]
}
