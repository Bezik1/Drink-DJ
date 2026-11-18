import SwiftUI

struct OneAlbumView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    let album: AlbumItem

    private var albumDrinks: [LibraryDrink] {
        MockData.libraryDrinks.filter { album.drinkIDs.contains($0.id) }
    }

    private var filteredDrinks: [LibraryDrink] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            return albumDrinks
        }

        return albumDrinks.filter { drink in
            drink.name.localizedCaseInsensitiveContains(query)
                || drink.ingredients.contains {
                    $0.localizedCaseInsensitiveContains(query)
                }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                backButton
                headerSection
                searchSection
                drinksSection
            }
            .padding(.vertical)
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var backButton: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }
            .glassButtonStyle()
            .buttonBorderShape(.circle)

            Spacer()
        }
        .padding(.horizontal)
    }

    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("YOUR COLLECTION")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.cyan)

                Text(album.title)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
            }

            Spacer()

            albumArtwork(album.artwork)
                .frame(width: 52, height: 52)
        }
        .padding(.horizontal)
    }

    private var searchSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.65))

            TextField("Search drinks", text: $searchText)
                .foregroundStyle(.white)
                .tint(.cyan)
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
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

    private var drinksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("DRINKS IN THIS ALBUM")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.gray)

                Spacer()

                Text("\(albumDrinks.count) drinks")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            .padding(.horizontal)

            if filteredDrinks.isEmpty {
                Text(albumDrinks.isEmpty ? "This album has no drinks yet." : "No drinks found")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(filteredDrinks) { drink in
                        NavigationLink {
                            MixerView(mix: drink.mix)
                        } label: {
                            drinkRow(drink)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func drinkRow(_ drink: LibraryDrink) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                drink.tint.opacity(0.8),
                                drink.tint.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Image(systemName: drink.symbolName)
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 58, height: 58)

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
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 82)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    @ViewBuilder
    private func albumArtwork(_ artwork: AlbumArtwork) -> some View {
        switch artwork {
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: 23, weight: .medium))
                .foregroundStyle(.cyan)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.white.opacity(0.08), in: Circle())

        case .asset(let name):
            Image(name)
                .resizable()
                .scaledToFill()
                .clipShape(Circle())
        }
    }
}

#Preview {
    NavigationStack {
        OneAlbumView(album: MockData.albums[0])
    }
}
