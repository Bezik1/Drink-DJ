import SwiftUI

struct MixerView: View {
    let mix: Mix

    @State private var opinion = "Perfect"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection

                flavourProfileSection

                suggestionsSection

                fullRecipeSection

                if !mix.isEmpty {
                    afterTastingSection
                }
            }
            .padding(.vertical)
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MIXER")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.cyan)

                    Text(mix.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    Text(mix.details)
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                }

                Spacer()

                ZStack(alignment: .bottomTrailing) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .frame(width: 64, height: 64)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                        .overlay(
                            Image(systemName: mix.isEmpty ? "camera" : "wineglass.fill")
                                .font(.title2)
                                .foregroundStyle(mix.isEmpty ? .gray : .cyan)
                        )

                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.cyan, .black)
                        .offset(x: 4, y: 4)
                }
            }

            if let match = mix.match {
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Text("40")
                            .font(.caption)
                            .fontWeight(.bold)
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.pink, in: Capsule())

                    Text("\(match) Match")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.cyan, in: Capsule())
                }
            }
        }
        .padding(.horizontal)
    }

    private var flavourProfileSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("FLAVOUR PROFILE")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.gray)

                Spacer()

                if !mix.isEmpty {
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.cyan)
                            .frame(width: 8, height: 8)
                        Text("This mix")
                            .font(.caption2)
                            .foregroundStyle(.gray)
                    }
                }
            }

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(mix.flavours) { flavour in
                    VStack(spacing: 8) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.08))
                                .frame(height: 60)

                            if flavour.level > 0 {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.cyan)
                                    .frame(height: CGFloat(flavour.level / 20.0) * 60)
                            }
                        }

                        Text(flavour.name.prefix(3).uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.gray)
                    }
                }
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
        }
        .padding(.horizontal)
    }

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(mix.isEmpty ? "START WITH A BASE" : "SUGGESTED TO ADD")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.gray)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(mix.suggestions) { ingredient in
                        suggestionCard(ingredient)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var fullRecipeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("FULL RECIPE")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.gray)

                Spacer()

                if !mix.isEmpty {
                    Button("Edit") {}
                        .font(.caption)
                        .foregroundStyle(Color.cyan)
                }
            }
            .padding(.horizontal)

            if mix.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "wineglass")
                        .font(.largeTitle)
                        .foregroundStyle(Color.cyan)

                    Text("No ingredients yet")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text("Pick a base above or add your first ingredient to start mixing.")
                        .font(.caption)
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)

                    Button {
                    } label: {
                        Text("+ Add ingredient")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.white, in: Capsule())
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .padding(.horizontal, 16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .padding(.horizontal)
            } else {
                VStack(spacing: 10) {
                    ForEach(mix.recipe) { ingredient in
                        recipeRow(ingredient)
                    }
                }
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .padding(.horizontal)
            }
        }
    }

    private var afterTastingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("AFTER TASTING")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.gray)

                Spacer()

                Text("Share your opinion")
                    .font(.caption2)
                    .foregroundStyle(.gray)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(MockData.opinions, id: \.self) { item in
                        let isSelected = opinion == item
                        Button {
                            opinion = item
                        } label: {
                            Text(item)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(isSelected ? .black : .white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    Group {
                                        if isSelected {
                                            Capsule()
                                                .fill(Color.white)
                                        } else {
                                            Capsule()
                                                .fill(.ultraThinMaterial)
                                                .overlay(
                                                    Capsule()
                                                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                                )
                                        }
                                    }
                                )
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func recipeRow(_ ingredient: Ingredient) -> some View {
        HStack {
            Circle()
                .fill(Color.yellow)
                .frame(width: 8, height: 8)

            Text(ingredient.name)
                .font(.subheadline)
                .foregroundStyle(.white)

            Spacer()

            Text(ingredient.amount)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(.white)
        }
    }

    private func suggestionCard(_ ingredient: Ingredient) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 8, height: 8)

                Spacer()

                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.white, Color.white.opacity(0.2))
            }

            Spacer(minLength: 0)

            Text(ingredient.name)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)

            Text(ingredient.amount)
                .font(.caption)
                .foregroundStyle(.cyan)
        }
        .padding(12)
        .frame(width: 110, height: 110)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }
}
