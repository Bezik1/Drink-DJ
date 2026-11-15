import SwiftUI

enum LibraryMode {
    case home
    case library
}

struct LibraryView: View {
    let mode: LibraryMode
    let searchActivationID: Int
    let openLibrary: () -> Void
    let openMixer: (Mix) -> Void
    let openAlbums: () -> Void

    @State private var searchText = ""
    @State private var selectedAlcohols = Set(MockData.libraryAlcohols)
    @State private var selectedFlavours = Set(MockData.libraryFlavours)
    @State private var selectedIngredients = Set(MockData.libraryIngredients)
    @State private var activeFilter: LibraryFilter?
    @FocusState private var isSearchFocused: Bool

    private let drinks = MockData.libraryDrinks

    private var filteredDrinks: [LibraryDrink] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        return drinks.filter { drink in
            let matchesQuery = query.isEmpty
                || drink.name.localizedCaseInsensitiveContains(query)
                || drink.ingredients.contains {
                    $0.localizedCaseInsensitiveContains(query)
                }
            let matchesAlcohol = selectedAlcohols.contains(drink.category.title)
            let matchesFlavours = drink.flavours.isSubset(of: selectedFlavours)
            let matchesIngredients = Set(drink.ingredients).isSubset(of: selectedIngredients)

            return matchesQuery && matchesAlcohol && matchesFlavours && matchesIngredients
        }
    }

    private var hasActiveFilters: Bool {
        selectedAlcohols.count != MockData.libraryAlcohols.count
            || selectedFlavours.count != MockData.libraryFlavours.count
            || selectedIngredients.count != MockData.libraryIngredients.count
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                LibraryHeader(isHome: mode == .home)

                if mode == .home {
                    HomeSearchButton(openLibrary: openLibrary)
                    HomeQuickActions(
                        drinks: drinks,
                        openMixer: openMixer,
                        openAlbums: openAlbums
                    )
                    HomeDrinkShelf(
                        title: "MADE FOR YOUR TASTE",
                        subtitle: "Fresh picks based on what you like",
                        drinks: Array(drinks.prefix(4)),
                        openMixer: openMixer
                    )
                    HomeDrinkShelf(
                        title: "TONIGHT'S PICKS",
                        subtitle: "A little inspiration for later",
                        drinks: Array(drinks.suffix(4)),
                        openMixer: openMixer
                    )
                    BrowseLibraryCard(drinkCount: drinks.count, browse: openLibrary)
                } else {
                    LibrarySearchField(
                        searchText: $searchText,
                        isFocused: $isSearchFocused
                    )
                    LibraryFilterMenu(
                        selectedAlcoholCount: selectedAlcohols.count,
                        alcoholCount: MockData.libraryAlcohols.count,
                        selectedFlavourCount: selectedFlavours.count,
                        flavourCount: MockData.libraryFlavours.count,
                        selectedIngredientCount: selectedIngredients.count,
                        ingredientCount: MockData.libraryIngredients.count,
                        activeFilter: $activeFilter
                    )

                    ExcludedFiltersBar(
                        allAlcohols: MockData.libraryAlcohols,
                        allFlavours: MockData.libraryFlavours,
                        allIngredients: MockData.libraryIngredients,
                        selectedAlcohols: $selectedAlcohols,
                        selectedFlavours: $selectedFlavours,
                        selectedIngredients: $selectedIngredients
                    )

                    LibraryResultsSection(
                        drinks: filteredDrinks,
                        isSearching: !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || hasActiveFilters
                    )
                }
            }
            .padding(.vertical)
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .navigationBar)
        .task(id: searchActivationID) {
            guard mode == .library, searchActivationID > 0 else { return }
            await Task.yield()
            isSearchFocused = true
        }
        .sheet(item: $activeFilter) { filter in
            FilterSelectionSheet(
                filter: filter,
                options: options(for: filter),
                selection: selectionBinding(for: filter),
                matchingDrinkCount: filteredDrinks.count
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(.ultraThinMaterial)
        }
    }

    private func options(for filter: LibraryFilter) -> [String] {
        switch filter {
        case .alcohols:
            MockData.libraryAlcohols
        case .flavours:
            MockData.libraryFlavours
        case .ingredients:
            MockData.libraryIngredients
        }
    }

    private func selectionBinding(for filter: LibraryFilter) -> Binding<Set<String>> {
        switch filter {
        case .alcohols:
            $selectedAlcohols
        case .flavours:
            $selectedFlavours
        case .ingredients:
            $selectedIngredients
        }
    }

}

private struct LibraryModeHeader: View {
    let returnHome: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("DRINK LIBRARY")
                    .font(.caption2.weight(.bold))
                    .tracking(1.5)
                    .foregroundStyle(.cyan)

                Text("Search and shape the menu")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.65))
            }

            Spacer()

            Button("Back home", systemImage: "house") {
                returnHome()
            }
            .labelStyle(.iconOnly)
            .glassButtonStyle()
            .buttonBorderShape(.circle)
            .accessibilityHint("Clears search and filters")
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }
}

private struct HomeQuickActions: View {
    let drinks: [LibraryDrink]
    let openMixer: (Mix) -> Void
    let openAlbums: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            Button {
                openMixer(MockData.newMix)
            } label: {
                HomeQuickActionLabel(
                    title: "Start a new mix",
                    symbolName: "plus",
                    tint: .cyan
                )
            }

            if let recentDrink = drinks.first(where: { $0.id == "blue-lagoon" }) {
                Button {
                    openMixer(recentDrink.mix)
                } label: {
                    HomeQuickActionLabel(
                        title: "Continue mixing",
                        symbolName: "slider.vertical.3",
                        tint: recentDrink.tint
                    )
                }
            }

            Button {
                openAlbums()
            } label: {
                HomeQuickActionLabel(
                    title: "Your albums",
                    symbolName: "square.stack.fill",
                    tint: .purple
                )
            }

            if let surpriseDrink = drinks.last {
                Button {
                    openMixer(surpriseDrink.mix)
                } label: {
                    HomeQuickActionLabel(
                        title: "Surprise me",
                        symbolName: "sparkles",
                        tint: surpriseDrink.tint
                    )
                }
            }
        }
        .padding(.horizontal)
    }
}

private struct HomeQuickActionLabel: View {
    let title: String
    let symbolName: String
    let tint: Color

    var body: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.gradient)

                Image(systemName: symbolName)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 44, height: 44)
            .accessibilityHidden(true)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct HomeDrinkShelf: View {
    let title: String
    let subtitle: String
    let drinks: [LibraryDrink]
    let openMixer: (Mix) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption2.weight(.bold))
                    .tracking(1.3)
                    .foregroundStyle(.gray)

                Text(subtitle)
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(drinks) { drink in
                        Button {
                            openMixer(drink.mix)
                        } label: {
                            HomeDrinkCard(drink: drink)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

private struct HomeDrinkCard: View {
    let drink: LibraryDrink

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [drink.tint, drink.tint.opacity(0.28), .black.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Image(systemName: drink.symbolName)
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Text(drink.mix.match ?? "For you")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.cyan, in: Capsule())
                    .padding(10)
            }
            .frame(width: 156, height: 156)
            .accessibilityHidden(true)

            Text(drink.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(drink.flavours.sorted().prefix(3).formatted(.list(type: .and, width: .narrow)))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.58))
                .lineLimit(1)
        }
        .frame(width: 156, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the recipe in the mixer")
    }
}

private struct BrowseLibraryCard: View {
    let drinkCount: Int
    let browse: () -> Void

    var body: some View {
        Button {
            browse()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "wineglass")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.cyan)
                    .frame(width: 48, height: 48)
                    .background(.cyan.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("Browse the full library")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text("Search and filter all \(drinkCount) drinks")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.white.opacity(0.14), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }
}

private enum LibraryFilter: String, Identifiable {
    case alcohols
    case flavours
    case ingredients

    var id: Self { self }

    var title: String {
        switch self {
        case .alcohols: "Alcohols"
        case .flavours: "Flavours"
        case .ingredients: "Ingredients"
        }
    }

    var symbolName: String {
        switch self {
        case .alcohols: "wineglass"
        case .flavours: "paintpalette"
        case .ingredients: "leaf"
        }
    }

    var guidance: String {
        switch self {
        case .alcohols:
            "Untick any base you don’t want in your results."
        case .flavours:
            "Keep the flavour notes that suit your mood."
        case .ingredients:
            "Search the bar, then untick anything you want to avoid."
        }
    }
}

private struct LibraryHeader: View {
    let isHome: Bool

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(isHome ? "GOOD EVENING" : "YOUR COLLECTION")
                    .font(.caption2.weight(.bold))
                    .tracking(1.5)
                    .foregroundStyle(.cyan)

                Text(isHome ? "What are we mixing?" : "Drink Library")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)

                Text(isHome
                    ? "Pick up where you left off or discover something new."
                    : "Search and shape the menu around your taste.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer(minLength: 16)

            AccountButton()
        }
        .padding(.horizontal)
    }
}

private struct HomeSearchButton: View {
    let openLibrary: () -> Void

    var body: some View {
        Button {
            openLibrary()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.white.opacity(0.6))

                Text("Search drinks or ingredients")
                    .foregroundStyle(.white.opacity(0.55))

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.cyan)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 50)
            .background {
                if #available(iOS 26, *) {
                    Capsule()
                        .fill(.clear)
                        .glassEffect(.regular, in: .capsule)
                } else {
                    Capsule()
                        .fill(.ultraThinMaterial)
                }
            }
            .overlay {
                Capsule()
                    .stroke(.white.opacity(0.14), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .accessibilityHint("Opens the Drink Library and focuses search")
    }
}

private struct LibrarySearchField: View {
    @Binding var searchText: String
    @FocusState.Binding var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.6))

            TextField("Search drinks or ingredients", text: $searchText)
                .focused($isFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .foregroundStyle(.white)
                .tint(.cyan)

            if !searchText.isEmpty {
                Button("Clear search", systemImage: "xmark.circle.fill") {
                    searchText = ""
                }
                .labelStyle(.iconOnly)
                .foregroundStyle(.white.opacity(0.55))
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 50)
        .background {
            if #available(iOS 26, *) {
                Capsule()
                    .fill(.clear)
                    .glassEffect(.regular, in: .capsule)
            } else {
                Capsule()
                    .fill(.ultraThinMaterial)
            }
        }
        .overlay {
            Capsule()
                .stroke(.white.opacity(0.14), lineWidth: 1)
        }
        .padding(.horizontal)
    }
}

private struct LibraryFilterMenu: View {
    let selectedAlcoholCount: Int
    let alcoholCount: Int
    let selectedFlavourCount: Int
    let flavourCount: Int
    let selectedIngredientCount: Int
    let ingredientCount: Int
    @Binding var activeFilter: LibraryFilter?

    var body: some View {
        HStack(spacing: 10) {
            LibraryFilterButton(
                filter: .alcohols,
                selectedCount: selectedAlcoholCount,
                totalCount: alcoholCount,
                tint: .cyan,
                activeFilter: $activeFilter
            )
            LibraryFilterButton(
                filter: .flavours,
                selectedCount: selectedFlavourCount,
                totalCount: flavourCount,
                tint: .pink,
                activeFilter: $activeFilter
            )
            LibraryFilterButton(
                filter: .ingredients,
                selectedCount: selectedIngredientCount,
                totalCount: ingredientCount,
                tint: .green,
                activeFilter: $activeFilter
            )
        }
        .padding(.horizontal)
    }
}

private struct LibraryFilterButton: View {
    let filter: LibraryFilter
    let selectedCount: Int
    let totalCount: Int
    let tint: Color
    @Binding var activeFilter: LibraryFilter?

    private var summary: String {
        if selectedCount == totalCount {
            "All"
        } else if selectedCount == 0 {
            "None"
        } else {
            "\(selectedCount) kept"
        }
    }

    var body: some View {
        Button {
            activeFilter = filter
        } label: {
            VStack(spacing: 6) {
                Image(systemName: filter.symbolName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(tint)

                Text(filter.title)
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(summary)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(selectedCount == totalCount ? .white.opacity(0.5) : tint)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 78)
            .background(
                LinearGradient(
                    colors: [tint.opacity(0.16), .white.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        selectedCount == totalCount ? .white.opacity(0.14) : tint.opacity(0.75),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(filter.title), \(summary)")
        .accessibilityHint("Opens filter options")
    }
}

private struct ExcludedFiltersBar: View {
    let allAlcohols: [String]
    let allFlavours: [String]
    let allIngredients: [String]
    @Binding var selectedAlcohols: Set<String>
    @Binding var selectedFlavours: Set<String>
    @Binding var selectedIngredients: Set<String>

    private var exclusions: [ExcludedFilter] {
        allAlcohols.filter { !selectedAlcohols.contains($0) }.map {
            ExcludedFilter(group: .alcohols, value: $0)
        }
        + allFlavours.filter { !selectedFlavours.contains($0) }.map {
            ExcludedFilter(group: .flavours, value: $0)
        }
        + allIngredients.filter { !selectedIngredients.contains($0) }.map {
            ExcludedFilter(group: .ingredients, value: $0)
        }
    }

    var body: some View {
        if !exclusions.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(exclusions) { exclusion in
                        Button {
                            restore(exclusion)
                        } label: {
                            Label("Without \(exclusion.value)", systemImage: "xmark")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .frame(minHeight: 34)
                                .foregroundStyle(exclusion.group.tint)
                                .background(exclusion.group.tint.opacity(0.14), in: Capsule())
                                .overlay {
                                    Capsule()
                                        .stroke(exclusion.group.tint.opacity(0.45), lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Adds this option back")
                    }

                    Button("Reset filters", systemImage: "arrow.counterclockwise") {
                        selectedAlcohols = Set(allAlcohols)
                        selectedFlavours = Set(allFlavours)
                        selectedIngredients = Set(allIngredients)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                }
                .padding(.horizontal)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func restore(_ exclusion: ExcludedFilter) {
        switch exclusion.group {
        case .alcohols:
            selectedAlcohols.insert(exclusion.value)
        case .flavours:
            selectedFlavours.insert(exclusion.value)
        case .ingredients:
            selectedIngredients.insert(exclusion.value)
        }
    }
}

private struct ExcludedFilter: Identifiable {
    let group: LibraryFilter
    let value: String

    var id: String { "\(group.rawValue)-\(value)" }
}

private extension LibraryFilter {
    var tint: Color {
        switch self {
        case .alcohols: .cyan
        case .flavours: .pink
        case .ingredients: .green
        }
    }
}

private struct FilterSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss

    let filter: LibraryFilter
    let options: [String]
    @Binding var selection: Set<String>
    let matchingDrinkCount: Int

    @State private var optionSearch = ""

    private var visibleOptions: [String] {
        guard filter == .ingredients, !optionSearch.isEmpty else {
            return options
        }

        return options.filter {
            $0.localizedCaseInsensitiveContains(optionSearch)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    FilterSheetIntroduction(
                        symbolName: filter.symbolName,
                        title: filter.title,
                        guidance: filter.guidance,
                        tint: filter.tint
                    )

                    if filter == .ingredients {
                        FilterOptionSearchField(text: $optionSearch)
                    }

                    LazyVGrid(
                        columns: [
                            GridItem(
                                .adaptive(minimum: 145),
                                spacing: 10
                            )
                        ],
                        alignment: .leading,
                        spacing: 10
                    ) {
                        ForEach(visibleOptions, id: \.self) { option in
                            FilterOptionChip(
                                title: option,
                                isSelected: selection.contains(option),
                                tint: optionTint(for: option)
                            ) {
                                toggle(option)
                            }
                        }
                    }

                    if visibleOptions.isEmpty {
                        ContentUnavailableView.search(text: optionSearch)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(20)
            }
            .navigationTitle(filter.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Select All", systemImage: "checkmark.circle") {
                            selection = Set(options)
                        }
                        .disabled(selection.count == options.count)

                        Button("Deselect All", systemImage: "circle") {
                            selection.removeAll()
                        }
                        .disabled(selection.isEmpty)
                    } label: {
                        Label("Selection options", systemImage: "ellipsis.circle")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                FilterResultsButton(count: matchingDrinkCount) {
                    dismiss()
                }
            }
        }
    }

    private func toggle(_ option: String) {
        if selection.contains(option) {
            selection.remove(option)
        } else {
            selection.insert(option)
        }
    }

    private func optionTint(for option: String) -> Color {
        guard filter == .flavours else {
            return filter.tint
        }

        return switch option {
        case "Sweet": .pink
        case "Sour": .yellow
        case "Spicy": .red
        case "Bitter": .orange
        case "Fruity": .purple
        case "Herbal": .green
        case "Smoky": .gray
        case "Fizz": .cyan
        default: filter.tint
        }
    }
}

private struct FilterSheetIntroduction: View {
    let symbolName: String
    let title: String
    let guidance: String
    let tint: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbolName)
                .font(.title2.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 48, height: 48)
                .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 15))

            VStack(alignment: .leading, spacing: 3) {
                Text("Choose \(title.lowercased())")
                    .font(.headline)

                Text(guidance)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct FilterOptionSearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Find an ingredient", text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !text.isEmpty {
                Button("Clear", systemImage: "xmark.circle.fill") {
                    text = ""
                }
                .labelStyle(.iconOnly)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .background(.thinMaterial, in: Capsule())
    }
}

private struct FilterOptionChip: View {
    let title: String
    let isSelected: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.subheadline.weight(.semibold))

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(isSelected ? tint : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(isSelected ? tint.opacity(0.16) : Color.secondary.opacity(0.08), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(isSelected ? tint.opacity(0.7) : Color.secondary.opacity(0.2), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct FilterResultsButton: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text("Show drinks")
                Spacer()
                Text(count, format: .number)
                    .contentTransition(.numericText())
            }
            .font(.headline)
            .foregroundStyle(.black)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(.cyan, in: Capsule())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}

private struct LibraryResultsSection: View {
    let drinks: [LibraryDrink]
    let isSearching: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(isSearching ? "YOUR MATCHES" : "POPULAR NOW")
                    .font(.caption2.weight(.bold))
                    .tracking(1.5)
                    .foregroundStyle(.gray)

                Spacer()

                Text("\(drinks.count) drinks")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            .padding(.horizontal)

            if drinks.isEmpty {
                ContentUnavailableView(
                    "Nothing behind the bar",
                    systemImage: "wineglass",
                    description: Text("Add an excluded option back or try another search.")
                )
                .foregroundStyle(.white)
                .padding(.vertical, 28)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(drinks) { drink in
                        NavigationLink {
                            MixerView(mix: drink.mix)
                        } label: {
                            LibraryDrinkRow(drink: drink)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

private struct LibraryDrinkRow: View {
    let drink: LibraryDrink

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [drink.tint.opacity(0.8), drink.tint.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Image(systemName: drink.symbolName)
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 64, height: 64)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(drink.name)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(drink.ingredients.formatted(.list(type: .and, width: .narrow)))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)

                Label(drink.category.title, systemImage: drink.category.symbolName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.cyan)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.45))
                .accessibilityHidden(true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 88)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the recipe in the mixer")
    }
}

#Preview {
    NavigationStack {
        LibraryView(
            mode: .home,
            searchActivationID: 0,
            openLibrary: {},
            openMixer: { _ in },
            openAlbums: {}
        )
    }
}
