import SwiftUI

struct AlbumsView: View {
    @State private var searchText = ""

    private let albums = MockData.albums

    private var filteredAlbums: [AlbumItem] {
        guard !searchText.isEmpty else { return albums }
        return albums.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                searchSection
                albumSection
            }
            .padding(.vertical)
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("YOUR COLLECTION")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.cyan)

                Text("Albums")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }

            Spacer()

            Image(MockData.profileImageName)
                .resizable()
                .scaledToFill()
                .frame(width: 48, height: 48)
                .clipShape(Circle())
                .overlay(Circle().stroke(.white.opacity(0.15), lineWidth: 1))
        }
        .padding(.horizontal)
    }

    private var searchSection: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.white.opacity(0.65))

                TextField("Search albums", text: $searchText)
                    .foregroundStyle(.white)
                    .tint(.cyan)
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
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

            Button(action: {
                // Add album action goes here.
            }) {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .contentShape(Circle())
            }
            .background {
                if #available(iOS 26, *) {
                    Circle()
                        .fill(.clear)
                        .glassEffect(.regular, in: .circle)
                } else {
                    Circle()
                        .fill(.ultraThinMaterial)
                }
            }
            .overlay {
                Circle()
                    .stroke(.white.opacity(0.14), lineWidth: 1)
            }
        }
        .padding(.horizontal)
    }

    private var albumSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("YOUR ALBUMS")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.gray)

                Spacer()

                Text("\(filteredAlbums.count) albums")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            .padding(.horizontal)

            if filteredAlbums.isEmpty {
                Text("No albums found")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                    .padding(.horizontal)
            } else {
                VStack(spacing: 10) {
                    ForEach(filteredAlbums) { album in
                        albumRow(album)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func albumRow(_ album: AlbumItem) -> some View {
        HStack(spacing: 12) {
            albumArtwork(album.artwork).offset(x:-10)

            VStack(alignment: .leading, spacing: 4) {
                Text(album.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text("\(album.drinkCount) drinks")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
            }.offset(x:-10)


            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 54)
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
        .contentShape(Capsule())
    }

    @ViewBuilder
    private func albumArtwork(_ artwork: AlbumArtwork) -> some View {
        switch artwork {
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: 23, weight: .medium))
                .foregroundStyle(.cyan)
                .frame(width: 50, height: 50)
                .background(.white.opacity(0.08), in: Circle())

        case .asset(let name):
            Image(name)
                .resizable()
                .scaledToFill()
                .frame(width: 50, height: 50)
                .clipShape(Circle())
        }
    }
}

#Preview {
    NavigationStack {
        AlbumsView()
    }
}
