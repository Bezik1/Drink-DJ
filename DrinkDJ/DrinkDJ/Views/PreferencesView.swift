import SwiftUI

struct PreferencesView: View {
    @State private var preferences = RemixStore.shared.preferences
    @State private var saveError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CONSOLE")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.cyan)

                    Text("Tune your drink")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    Text("Your saved tastes guide the match estimate. Preferences save automatically.")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                }
                .padding(.horizontal)

                horizontalSelectionSection(
                    title: "BASE SPIRIT",
                    items: MockData.spirits,
                    selection: $preferences.likedSpirits
                )

                horizontalSelectionSection(
                    title: "INGREDIENTS",
                    items: MockData.ingredients,
                    selection: $preferences.likedIngredients
                )

                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        Text("INTENSITY")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.gray)

                        HStack {
                            Text("HOUSE PARTY")
                                .font(.caption2)
                                .foregroundStyle(.gray)
                            
                            Spacer()

                            Slider(value: $preferences.intensity, in: 0...20, step: 1)
                                .tint(.cyan)

                            Spacer()

                            Text("PROJECT X")
                                .font(.caption2)
                                .foregroundStyle(.gray)
                        }
                    }

                    Divider()
                        .background(Color.white.opacity(0.15))

                    knobSection(title: "TASTE", levels: $preferences.taste)

                    Divider()
                        .background(Color.white.opacity(0.15))

                    knobSection(title: "CHARACTER", levels: $preferences.character)
                }
                .padding(20)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .task(id: preferences) {
            do {
                try await Task.sleep(for: .milliseconds(350))
                try RemixStore.shared.updatePreferences(preferences)
            } catch is CancellationError {
                // A newer edit or dismissal will save the latest state.
            } catch {
                saveError = error.localizedDescription
            }
        }
        .onDisappear {
            do { try RemixStore.shared.updatePreferences(preferences) }
            catch { saveError = error.localizedDescription }
        }
        .alert("Preferences not saved", isPresented: Binding(
            get: { saveError != nil }, set: { if !$0 { saveError = nil } }
        )) {
            Button("OK") { saveError = nil }
        } message: { Text(saveError ?? "") }
    }

    private func horizontalSelectionSection(
        title: String,
        items: [String],
        selection: Binding<Set<String>>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.gray)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(items, id: \.self) { item in
                        let isSelected = selection.wrappedValue.contains(item)
                        Button {
                            if isSelected {
                                selection.wrappedValue.remove(item)
                            } else {
                                selection.wrappedValue.insert(item)
                            }
                        } label: {
                            Text(item)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(isSelected ? .black : .white)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(
                                    Group {
                                        if isSelected {
                                            Capsule()
                                                .fill(Color.cyan)
                                                .shadow(color: .cyan.opacity(0.6), radius: 8)
                                        } else {
                                            Capsule()
                                                .fill(.ultraThinMaterial)
                                                .overlay(
                                                    Capsule()
                                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                                )
                                        }
                                    }
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }
        }
    }

    private func knobSection(title: String, levels: Binding<[PreferenceLevel]>) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.gray)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(levels) { $flavour in
                    VStack(spacing: 8) {
                        Slider(value: $flavour.level, in: 0...20, step: 1)
                            .tint(.cyan)

                        Text(flavour.name.uppercased())
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.gray)
                    }
                    .padding(14)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        PreferencesView()
    }
}
