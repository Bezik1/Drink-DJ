import SwiftUI
import PhotosUI
import UIKit

struct OneAlbumView: View {
    private enum ActivePicker: String, Identifiable {
        case drinks
        case albums
        var id: String { rawValue }
    }

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var pickerSearchText = ""
    @State private var activePicker: ActivePicker?
    @State private var albumPickerSearchText = ""
    @State private var drinkIDForAlbumPicker: String?
    @State private var temporaryAlbumMemberships: Set<String> = []
    @State private var suppressNextRowTap = false
    @State private var selectedDrinkIDs: Set<String>
    @State private var chosenDrinkIDs: Set<String> = []
    @State private var mixerDrinkID: String?
    @State private var albumName: String
    @State private var selectedAlbumPhoto: PhotosPickerItem?
    @State private var albumPhotoData: Data?

    let album: AlbumItem
    let onAlbumPhotoChanged: (Data) -> Void

    init(album: AlbumItem, onAlbumPhotoChanged: @escaping (Data) -> Void = { _ in }) {
        self.album = album
        self.onAlbumPhotoChanged = onAlbumPhotoChanged
        _selectedDrinkIDs = State(initialValue: Set(album.drinkIDs))
        _albumName = State(initialValue: album.title)
        _albumPhotoData = State(initialValue: album.photoData)
    }

    private var albumDrinks: [LibraryDrink] {
        MockData.libraryDrinks.filter { selectedDrinkIDs.contains($0.id) }
    }

    private var filteredPickerAlbums: [AlbumItem] {
        let query = albumPickerSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return MockData.albums }
        return MockData.albums.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    private var filteredPickerDrinks: [LibraryDrink] {
        let query = pickerSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return MockData.libraryDrinks }

        return MockData.libraryDrinks.filter { drink in
            drink.name.localizedCaseInsensitiveContains(query)
                || drink.ingredients.contains {
                    $0.localizedCaseInsensitiveContains(query)
                }
        }
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
                if chosenDrinkIDs.isEmpty {
                    backButton
                } else {
                    selectionButtons
                }
                headerSection
                searchSection
                drinksSection
            }
            .padding(.vertical)
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: selectedAlbumPhoto) {
            guard let item = selectedAlbumPhoto else { return }
            Task { @MainActor in
                guard let data = try? await item.loadTransferable(type: Data.self) else { return }
                albumPhotoData = data
                onAlbumPhotoChanged(data)
            }
        }
        .sheet(item: $activePicker, onDismiss: {
            suppressNextRowTap = false
        }) { picker in
            Group {
                switch picker {
                case .drinks:
                    drinkPicker
                case .albums:
                    albumPicker
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .navigationDestination(item: $mixerDrinkID) { drinkID in
            if let drink = MockData.libraryDrinks.first(where: { $0.id == drinkID }) {
                MixerView(mix: drink.mix, showsBackButton: true)
            } else {
                ContentUnavailableView("Drink not found", systemImage: "wineglass")
            }
        }
    }

    private var backButton: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background {
                        if #available(iOS 26, *) {
                            Circle().fill(.clear)
                                .glassEffect(.regular, in: .circle)
                        } else {
                            Circle().fill(.ultraThinMaterial)
                        }
                    }
                    .overlay(Circle().stroke(.white.opacity(0.16), lineWidth: 1))
            }
            .accessibilityLabel("Back")

            Spacer()
        }
        .padding(.horizontal)
    }

    private var selectionButtons: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    chosenDrinkIDs.removeAll()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .glassButtonStyle()
            .buttonBorderShape(.circle)
            .accessibilityLabel("Clear selection")

            Spacer()

            Button(role: .destructive) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedDrinkIDs.subtract(chosenDrinkIDs)
                    chosenDrinkIDs.removeAll()
                }
            } label: {
                Label("Remove", systemImage: "trash")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .frame(height: 44)
            }
            .tint(.red)
            .glassButtonStyle()
            .accessibilityLabel("Remove selected drinks from this album")
        }
        .padding(.horizontal)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("YOUR COLLECTION")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.cyan)

                TextField("Album Name", text: $albumName)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                    .tint(.cyan)
                    .submitLabel(.done)
            }

            Spacer()

            PhotosPicker(selection: $selectedAlbumPhoto, matching: .images) {
                albumArtwork(album.artwork, photoData: albumPhotoData)
                    .frame(width: 64, height: 64)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(5)
                            .background(.ultraThinMaterial, in: Circle())
                            .offset(x: 2, y: 2)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Change album photo")
        }
        .padding(.horizontal)
    }

    private var searchSection: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.white.opacity(0.6))

                TextField("Search drinks", text: $searchText)
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

            Button {
                pickerSearchText = ""
                activePicker = .drinks
            } label: {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
                    .frame(width: 32, height: 32)
            }
            .glassButtonStyle()
            .buttonBorderShape(.circle)
            .accessibilityLabel("Add or remove drinks")
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
                        drinkRow(drink)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var drinkPicker: some View {
        NavigationStack {
            List {
                ForEach(filteredPickerDrinks) { drink in
                    Button {
                        if selectedDrinkIDs.contains(drink.id) {
                            selectedDrinkIDs.remove(drink.id)
                            chosenDrinkIDs.remove(drink.id)
                        } else {
                            selectedDrinkIDs.insert(drink.id)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            drinkArtwork(drink)
                                .frame(width: 48, height: 48)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(drink.name)
                                    .foregroundStyle(.primary)

                                Text(drink.ingredients.formatted(.list(type: .and, width: .narrow)))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            if selectedDrinkIDs.contains(drink.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.cyan)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .overlay {
                if filteredPickerDrinks.isEmpty {
                    ContentUnavailableView.search(text: pickerSearchText)
                }
            }
            .navigationTitle("Add Drinks")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $pickerSearchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search drinks or ingredients"
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        activePicker = nil
                        pickerSearchText = ""
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var albumPicker: some View {
        NavigationStack {
            List {
                ForEach(filteredPickerAlbums) { listedAlbum in
                    let containsDrink = temporaryAlbumMemberships.contains(listedAlbum.id)

                    Button {
                        if containsDrink {
                            temporaryAlbumMemberships.remove(listedAlbum.id)
                        } else {
                            temporaryAlbumMemberships.insert(listedAlbum.id)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            albumArtwork(listedAlbum.artwork, photoData: listedAlbum.photoData)
                                .frame(width: 48, height: 48)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(listedAlbum.title)
                                    .foregroundStyle(.primary)

                                Text("\(listedAlbum.drinkCount) drinks")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if containsDrink {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.cyan)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .overlay {
                if filteredPickerAlbums.isEmpty {
                    ContentUnavailableView.search(text: albumPickerSearchText)
                }
            }
            .navigationTitle("Add to Albums")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $albumPickerSearchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search albums"
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        activePicker = nil
                        albumPickerSearchText = ""
                        drinkIDForAlbumPicker = nil
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func drinkArtwork(_ drink: LibraryDrink) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [drink.tint.opacity(0.8), drink.tint.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: drink.symbolName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private func drinkRow(_ drink: LibraryDrink) -> some View {
        let isChosen = chosenDrinkIDs.contains(drink.id)

        return HStack(spacing: 12) {
            Button {
                guard !suppressNextRowTap else {
                    suppressNextRowTap = false
                    return
                }
                if chosenDrinkIDs.isEmpty {
                    mixerDrinkID = drink.id
                } else {
                    toggleChosen(drink.id)
                }
            } label: {
                HStack(spacing: 14) {
                    drinkArtwork(drink)
                        .frame(width: 58, height: 58)
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

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.45))
                        .frame(width: 28, height: 44)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(chosenDrinkIDs.isEmpty ? "Opens this drink in Mixer" : (isChosen ? "Deselects this drink" : "Selects this drink"))
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 82)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    if isChosen {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(
                                LinearGradient(
                                    stops: [
                                        .init(color: .red.opacity(0.62), location: 0),
                                        .init(color: .red.opacity(0.3), location: 0.42),
                                        .init(color: .clear, location: 1)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(isChosen ? .red.opacity(0.45) : .white.opacity(0.14), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5, maximumDistance: 12)
                .onEnded { _ in
                    suppressNextRowTap = true
                    drinkIDForAlbumPicker = drink.id
                    albumPickerSearchText = ""
                    temporaryAlbumMemberships = Set(
                        MockData.albums
                            .filter { $0.drinkIDs.contains(drink.id) }
                            .map(\.id)
                    )
                    activePicker = .albums
                }
        )
        .highPriorityGesture(
            DragGesture(minimumDistance: 8)
                .onEnded { value in
                    let horizontal = value.location.x - value.startLocation.x
                    let vertical = value.location.y - value.startLocation.y
                    // Moving the finger left makes horizontal negative in SwiftUI coordinates.
                    guard horizontal <= -30, abs(horizontal) > abs(vertical) else { return }
                    suppressNextRowTap = true
                    toggleChosen(drink.id)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        suppressNextRowTap = false
                    }
                }
        )
        .animation(.easeInOut(duration: 0.2), value: isChosen)
    }

    private func toggleChosen(_ drinkID: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if chosenDrinkIDs.contains(drinkID) {
                chosenDrinkIDs.remove(drinkID)
            } else {
                chosenDrinkIDs.insert(drinkID)
            }
        }
    }

    @ViewBuilder
    private func albumArtwork(_ artwork: AlbumArtwork, photoData: Data? = nil) -> some View {
        if let photoData, let image = UIImage(data: photoData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .clipShape(Circle())
        } else {
            artworkContent(artwork)
        }
    }

    @ViewBuilder
    private func artworkContent(_ artwork: AlbumArtwork) -> some View {
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
