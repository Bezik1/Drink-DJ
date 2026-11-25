import SwiftUI
import PhotosUI
import UIKit

struct NewAlbumView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var albumName = "Album Name"
    @State private var selectedDrinks: [LibraryDrink] = []
    @State private var showingDrinkPicker = false
    @State private var searchText = ""
    @State private var pickerSearchText = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var albumPhotoData: Data?

    /// Passes the album name, selected drinks, and optional photo to the local save handler.
    var onSave: (String, [LibraryDrink], Data?) -> Void = { _, _, _ in }

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

    private var filteredSelectedDrinks: [LibraryDrink] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return selectedDrinks }

        return selectedDrinks.filter { drink in
            drink.name.localizedCaseInsensitiveContains(query)
                || drink.ingredients.contains {
                    $0.localizedCaseInsensitiveContains(query)
                }
        }
    }

    var body: some View {
        VStack(spacing: 22) {
            topBar
            header
            searchSection
            drinksPanel
            addButton
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: selectedPhotoItem) {
            guard let item = selectedPhotoItem else { return }
            Task { @MainActor in
                albumPhotoData = try? await item.loadTransferable(type: Data.self)
            }
        }
        .sheet(isPresented: $showingDrinkPicker) {
            drinkPicker
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var topBar: some View {
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
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("NEW ALBUM")
                    .font(.caption2.weight(.bold))
                    .tracking(1.5)
                    .foregroundStyle(.cyan)

                TextField("Album Name", text: $albumName)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                    .tint(.cyan)
                    .submitLabel(.done)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer ()

            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                ZStack {
                    if albumPhotoData == nil {
                        if #available(iOS 26, *) {
                            Circle().fill(.clear)
                                .glassEffect(.regular, in: .circle)
                        } else {
                            Circle().fill(.ultraThinMaterial)
                        }
                    }

                    if let albumPhotoData, let image = UIImage(data: albumPhotoData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "photo")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(Circle())
                .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
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
            .accessibilityLabel("Choose album photo")
        }
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
                showingDrinkPicker = true
            } label: {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
                    .frame(width: 32, height: 32)
            }
            .glassButtonStyle()
            .buttonBorderShape(.circle)
            .accessibilityLabel("Add drinks")
        }
    }

    private var drinksPanel: some View {
        ScrollView {
            if selectedDrinks.isEmpty {
                ContentUnavailableView(
                    "No drinks yet",
                    systemImage: "wineglass",
                    description: Text("Use the plus button to choose drinks for this album.")
                )
                .foregroundStyle(.white)
                .padding(.vertical, 24)
                .padding(.horizontal, 12)
            } else if filteredSelectedDrinks.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .foregroundStyle(.white)
                    .padding(.vertical, 24)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(filteredSelectedDrinks) { drink in
                        selectedDrinkRow(drink)
                    }
                }
                .padding(12)
            }
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.black)
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(.white.opacity(0.14), lineWidth: 1)
                }
        }
    }

    private func selectedDrinkRow(_ drink: LibraryDrink) -> some View {
        HStack(spacing: 14) {
            drinkImage(drink)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(drink.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(drink.ingredients.formatted(.list(type: .and, width: .narrow)))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)

                Label(drink.category.title, systemImage: drink.category.symbolName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.cyan)
            }

            Spacer(minLength: 8)

            Button {
                selectedDrinks.removeAll { $0.id == drink.id }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 32, height: 32)
            }
            .tint(.pink)
            .glassButtonStyle()
            .buttonBorderShape(.circle)
            .accessibilityLabel("Remove \(drink.name)")
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

    private var addButton: some View {
        Button {
            onSave(albumName, selectedDrinks, albumPhotoData)
            dismiss()
        } label: {
            Text("Add")
                .frame(minWidth: 100)
                .font(.headline.weight(.bold))
        }
        .tint(.cyan)
        .controlSize(.large)
        .glassButtonStyle(isProminent: true)
        .disabled(albumName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private var drinkPicker: some View {
        NavigationStack {
            List {
                ForEach(filteredPickerDrinks) { drink in
                    Button {
                        if selectedDrinks.contains(where: { $0.id == drink.id }) {
                            selectedDrinks.removeAll { $0.id == drink.id }
                        } else {
                            selectedDrinks.append(drink)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            drinkImage(drink)
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

                            if selectedDrinks.contains(where: { $0.id == drink.id }) {
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
            .navigationTitle("Add Drinks")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $pickerSearchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search drinks or ingredients"
            )
            .overlay {
                if filteredPickerDrinks.isEmpty {
                    ContentUnavailableView.search(text: pickerSearchText)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showingDrinkPicker = false
                        pickerSearchText = ""
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func drinkImage(_ drink: LibraryDrink) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [drink.tint.opacity(0.8), drink.tint.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: drink.symbolName)
                .font(.system(size: 23, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

}

#Preview {
    NavigationStack {
        NewAlbumView()
    }
}
