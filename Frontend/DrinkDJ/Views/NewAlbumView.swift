import SwiftUI

struct NewAlbumView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var albumName = "Album Name"
    @State private var selectedDrinks: [AlbumDrink] = []
    @State private var showingDrinkPicker = false

    /// Connect this closure to your app's save logic
    var onSave: (String, [AlbumDrink]) -> Void = { _, _ in }

    var body: some View {
        VStack(spacing: 16) {
            topBar
            header
            addDrinksButton
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

            Spacer()

            Button(action: {}) {
                Image(systemName: "photo")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
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
            .accessibilityLabel("Choose album image")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("NEW ALBUM")
                .font(.caption.weight(.bold))
                .tracking(2)
                .foregroundStyle(.cyan)

            TextField("Album Name", text: $albumName)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
                .tint(.pink)
                .submitLabel(.done)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var addDrinksButton: some View {
        Button {
            showingDrinkPicker = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                Text("Add Drinks")
                Spacer()
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(height: 42)
            .background {
                if #available(iOS 26, *) {
                    Capsule().fill(.clear)
                        .glassEffect(.regular, in: .capsule)
                } else {
                    Capsule().fill(.ultraThinMaterial)
                }
            }
            .overlay(Capsule().stroke(.white.opacity(0.16), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var drinksPanel: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(selectedDrinks) { drink in
                    selectedDrinkRow(drink)
                }

                if selectedDrinks.isEmpty {
                    Text("Search above to add drinks to this album.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                }
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(.white.opacity(0.14), lineWidth: 1)
                }
        }
    }

    private func selectedDrinkRow(_ drink: AlbumDrink) -> some View {
        HStack(spacing: 12) {
            drinkImage(drink)
                .frame(width: 48, height: 48)
                .clipShape(Circle())
                .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))

            Text(drink.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer()

            Button {
                selectedDrinks.removeAll { $0.id == drink.id }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.pink)
                    .frame(width: 32, height: 32)
                    .background(.black, in: Circle())
                    .overlay {
                            Circle()
                                .stroke(.pink.opacity(0.7), lineWidth: 1)
                        }
            }
            .accessibilityLabel("Remove \(drink.name)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            if #available(iOS 26, *) {
                Capsule().fill(.clear)
                    .glassEffect(.regular, in: .capsule)
            } else {
                Capsule().fill(.ultraThinMaterial)
            }
        }
        .overlay(Capsule().stroke(.white.opacity(0.14), lineWidth: 1))
    }

    private var addButton: some View {
        Button {
            onSave(albumName, selectedDrinks)
            dismiss()
        } label: {
            Text("Add")
                .frame(minWidth: 90)
                .font(.headline)
                .fontWeight(.bold)
        }
        .tint(.cyan)
        .controlSize(.large)
        .glassButtonStyle(isProminent: true)
        .disabled(albumName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private var drinkPicker: some View {
        NavigationStack {
            List {
                ForEach(MockData.albumDrinks) { drink in
                    Button {
                        if !selectedDrinks.contains(where: { $0.id == drink.id }) {
                            selectedDrinks.append(drink)
                        }
                        showingDrinkPicker = false
                    } label: {
                        HStack(spacing: 12) {
                            drinkImage(drink)
                                .frame(width: 42, height: 42)
                                .clipShape(Circle())

                            Text(drink.name)
                                .foregroundStyle(.primary)

                            Spacer()

                            if selectedDrinks.contains(where: { $0.id == drink.id }) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Drinks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showingDrinkPicker = false
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func drinkImage(_ drink: AlbumDrink) -> some View {
        if UIImage(named: drink.imageName) != nil {
            Image(drink.imageName)
                .resizable()
                .scaledToFill()
        } else {
            Image(systemName: "wineglass")
                .font(.title3)
                .foregroundStyle(.cyan)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.white.opacity(0.08))
        }
    }
}

#Preview {
    NavigationStack {
        NewAlbumView()
    }
}
