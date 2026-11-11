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

enum AlbumArtwork {
    case symbol(String)
    case asset(String)
}

struct AlbumItem: Identifiable {
    let id: String
    let title: String
    let drinkCount: Int
    let artwork: AlbumArtwork
}

struct AlbumDrink: Identifiable {
    let id: String
    let name: String
    let imageName: String
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
            drinkCount: 23,
            artwork: .symbol("star")
        ),
        AlbumItem(
            id: "to-check-out",
            title: "To Check Out",
            drinkCount: 11,
            artwork: .symbol("wineglass")
        ),
        AlbumItem(
            id: "your-drinks",
            title: "Your Drinks",
            drinkCount: 5,
            artwork: .symbol("flask")
        ),
        AlbumItem(
            id: "album-1",
            title: "Album1",
            drinkCount: 8,
            artwork: .asset("cat_album1")
        ),
        AlbumItem(
            id: "bitter-ones",
            title: "Bitter ones",
            drinkCount: 3,
            artwork: .asset("cat_album2")
        )
    ]
    
    static let albumDrinks: [AlbumDrink] = [
        AlbumDrink(id: "mojito", name: "Mojito", imageName: "drink_mojito"),
        AlbumDrink(id: "blue-lagoon", name: "Blue Lagoon", imageName: "drink_blue_lagoon"),
        AlbumDrink(id: "martini", name: "Martini", imageName: "drink_martini")
    ]
}
