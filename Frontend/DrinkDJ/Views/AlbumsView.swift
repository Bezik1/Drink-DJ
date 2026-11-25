import SwiftUI
import PhotosUI
import UIKit

struct AlbumsView: View {
    @State private var searchText = ""
    @State private var albums = MockData.albums
    @State private var showingRenameAlert = false
    @State private var renameText = ""
    @State private var albumBeingRenamedID: String?
    @State private var showingPhotoPicker = false
    @State private var albumBeingEditedPhotoID: String?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showingRemoveConfirmation = false
    @State private var albumPendingRemovalID: String?

    private let protectedAlbumIDs: Set<String> = ["favourites", "to-check-out", "your-drinks"]

    private var filteredAlbums: [AlbumItem] {
        guard !searchText.isEmpty else { return albums }
        return albums.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                headerSection
                searchSection
                albumSection
            }
            .padding(.vertical)
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .navigationBar)
        .alert("Change Album Name", isPresented: $showingRenameAlert) {
            TextField("Album name", text: $renameText)
            Button("Save") { saveAlbumName() }
            Button("Cancel", role: .cancel) { albumBeingRenamedID = nil }
        } message: {
            Text("Enter a new name for this album.")
        }
        .confirmationDialog(
            "Remove Album?",
            isPresented: $showingRemoveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove Album", role: .destructive) { removePendingAlbum() }
            Button("Cancel", role: .cancel) { albumPendingRemovalID = nil }
        } message: {
            Text("This album will be removed for this session.")
        }
        .photosPicker(
            isPresented: $showingPhotoPicker,
            selection: $selectedPhotoItem,
            matching: .images
        )
        .onChange(of: selectedPhotoItem) {
            guard let item = selectedPhotoItem else { return }
            Task { @MainActor in
                guard let imageData = try? await item.loadTransferable(type: Data.self),
                      let albumID = albumBeingEditedPhotoID else { return }
                updateAlbumPhoto(albumID, with: imageData)
            }
        }
    }

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("YOUR COLLECTION")
                    .font(.caption2.weight(.bold))
                    .tracking(1.5)
                    .foregroundStyle(.cyan)

                Text("Albums")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
            }

            Spacer(minLength: 16)

            AccountButton()
        }
        .padding(.horizontal)
    }

    private var searchSection: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.white.opacity(0.6))

                TextField("Search albums", text: $searchText)
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
                    Capsule().fill(.ultraThinMaterial)
                }
            }
            .overlay {
                Capsule().stroke(.white.opacity(0.14), lineWidth: 1)
            }

            NavigationLink {
                NewAlbumView { name, drinks, photoData in
                    let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    albums.append(
                        AlbumItem(
                            id: UUID().uuidString,
                            title: title.isEmpty ? "New Album" : title,
                            artwork: .symbol("square.stack.3d.up"),
                            drinkIDs: drinks.map(\.id),
                            photoData: photoData
                        )
                    )
                }
            } label: {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
                    .frame(width: 32, height: 32)
            }
            .glassButtonStyle()
            .buttonBorderShape(.circle)
            .accessibilityLabel("Create album")
        }
        .padding(.horizontal)
    }

    private var albumSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("YOUR ALBUMS")
                    .font(.caption2.weight(.bold))
                    .tracking(1.5)
                    .foregroundStyle(.gray)

                Spacer()

                Text("\(filteredAlbums.count) albums")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            .padding(.horizontal)

            if filteredAlbums.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .foregroundStyle(.white)
                    .padding(.vertical, 28)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(filteredAlbums) { album in
                        NavigationLink {
                            OneAlbumView(album: album) { photoData in
                                updateAlbumPhoto(album.id, with: photoData)
                            }
                        } label: {
                            albumRow(album)
                                .contextMenu {
                                    Button("Change Name", systemImage: "pencil") {
                                        beginRenaming(album)
                                    }

                                    Button("Change Photo", systemImage: "photo") {
                                        albumBeingEditedPhotoID = album.id
                                        selectedPhotoItem = nil
                                        showingPhotoPicker = true
                                    }

                                    if photoCanBeRemoved(album) {
                                        Button("Remove Photo", systemImage: "trash", role: .destructive) {
                                            removeAlbumPhoto(album)
                                        }
                                    }

                                    if !protectedAlbumIDs.contains(album.id) {
                                        Button("Remove Album", systemImage: "trash", role: .destructive) {
                                            albumPendingRemovalID = album.id
                                            showingRemoveConfirmation = true
                                        }
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func albumRow(_ album: AlbumItem) -> some View {
        HStack(spacing: 14) {
            albumArtwork(album)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(album.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text("\(album.drinkCount) drinks")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
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
    }

    private func beginRenaming(_ album: AlbumItem) {
        albumBeingRenamedID = album.id
        renameText = album.title
        showingRenameAlert = true
    }

    private func saveAlbumName() {
        guard let albumID = albumBeingRenamedID,
              let index = albums.firstIndex(where: { $0.id == albumID }) else { return }
        let trimmedName = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let current = albums[index]
        albums[index] = AlbumItem(
            id: current.id,
            title: trimmedName,
            artwork: current.artwork,
            drinkIDs: current.drinkIDs,
            photoData: current.photoData
        )
        albumBeingRenamedID = nil
    }

    private func updateAlbumArtwork(_ albumID: String, with artwork: AlbumArtwork) {
        guard let index = albums.firstIndex(where: { $0.id == albumID }) else { return }
        let current = albums[index]
        albums[index] = AlbumItem(
            id: current.id,
            title: current.title,
            artwork: artwork,
            drinkIDs: current.drinkIDs,
            photoData: current.photoData
        )
    }

    private func updateAlbumPhoto(_ albumID: String, with data: Data) {
        guard let index = albums.firstIndex(where: { $0.id == albumID }) else { return }
        let current = albums[index]
        albums[index] = AlbumItem(
            id: current.id,
            title: current.title,
            artwork: current.artwork,
            drinkIDs: current.drinkIDs,
            photoData: data
        )
    }

    private func photoCanBeRemoved(_ album: AlbumItem) -> Bool {
        if album.photoData != nil { return true }
        if case .asset(_) = album.artwork {
            return ["album-1", "bitter-ones"].contains(album.id)
        }
        return false
    }

    private func removeAlbumPhoto(_ album: AlbumItem) {
        guard let index = albums.firstIndex(where: { $0.id == album.id }) else { return }
        let current = albums[index]
        albums[index] = AlbumItem(
            id: current.id,
            title: current.title,
            artwork: .symbol(defaultSymbol(for: current)),
            drinkIDs: current.drinkIDs,
            photoData: nil
        )
    }

    private func defaultSymbol(for album: AlbumItem) -> String {
        switch album.id {
        case "favourites": "star"
        case "to-check-out": "wineglass"
        case "your-drinks": "flask"
        default: "square.stack.3d.up"
        }
    }

    private func removePendingAlbum() {
        guard let albumID = albumPendingRemovalID,
              !protectedAlbumIDs.contains(albumID) else { return }
        albums.removeAll { $0.id == albumID }
        albumPendingRemovalID = nil
    }

    @ViewBuilder
    private func albumArtwork(_ album: AlbumItem) -> some View {
        if let data = album.photoData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 64, height: 64)
                .clipped()
        } else {
            artworkContent(album.artwork)
        }
    }

    @ViewBuilder
    private func artworkContent(_ artwork: AlbumArtwork) -> some View {
        switch artwork {
        case .symbol(let name):
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.cyan.opacity(0.3), .cyan.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Image(systemName: name)
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(.cyan)
            }

        case .asset(let name):
            Image(name)
                .resizable()
                .scaledToFill()
                .frame(width: 64, height: 64)
                .clipped()
        }
    }
}

#Preview {
    NavigationStack {
        AlbumsView()
    }
}
