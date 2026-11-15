import SwiftUI

struct MixerView: View {
    let mix: Mix

    @State private var flavours: [Double]
    @State private var channels: [MixerChannel]
    @State private var adventure = 0.35
    @State private var history: [MixerSnapshot] = []
    @State private var activeKnob: Int?
    @State private var step: MixerStep
    @State private var vibe = DrinkVibe.refreshing
    @State private var preferredStrength = 0.45
    @State private var preferredDryness = 0.55
    @State private var spirit = SpiritChoice.chooseForMe
    @State private var showsFeedback = false
    @State private var adjustmentNote: LocalizedStringResource?

    private let originalFlavours: [Double]
    private let originalChannels: [MixerChannel]

    @MainActor init(mix: Mix) {
        self.mix = mix
        let values = Array(mix.flavours.prefix(4)).map(\.level)
            + Array(repeating: 10, count: max(0, 4 - mix.flavours.prefix(4).count))
        let recipe = mix.recipe.map(MixerChannel.init)
        originalFlavours = values
        originalChannels = recipe
        _flavours = State(initialValue: values)
        _channels = State(initialValue: recipe)
        _step = State(initialValue: mix.isEmpty ? .vibe : .tune)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                MixerHeader(
                    name: mix.isEmpty ? "Untitled Mix" : mix.name,
                    volume: totalVolume,
                    strength: strength,
                    fit: fit,
                    canUndo: !history.isEmpty,
                    undo: undo,
                    reset: reset
                )
                MixerStepProgress(step: $step, hasBaseline: !channels.isEmpty)
                MixerStepIntroduction(step: step)

                switch step {
                case .vibe:
                    VibeBrief(
                        vibe: $vibe,
                        strength: $preferredStrength,
                        dryness: $preferredDryness,
                        spirit: $spirit
                    )
                case .tune:
                    if let adjustmentNote {
                        AdjustmentNote(note: adjustmentNote)
                    }
                    DrinkPreview(
                        fill: min(1, max(0.12, Double(totalVolume) / 220)),
                        tint: drinkTint,
                        compact: true
                    )
                    FlavourDeck(
                        names: flavourNames,
                        values: $flavours,
                        activeKnob: $activeKnob,
                        remember: remember
                    )
                    Crossfader(value: $adventure, remember: remember)
                    DisclosureGroup {
                        ChannelDeck(
                            channels: $channels,
                            suggestions: mix.suggestions,
                            remember: remember,
                            add: add,
                            remove: remove
                        )
                        .padding(.top, 12)
                    } label: {
                        Label("Fine-tune ingredients", systemImage: "slider.horizontal.3")
                            .font(.subheadline.weight(.semibold))
                    }
                    .tint(.cyan)
                    .consolePanel()
                case .finish:
                    DrinkPreview(
                        fill: min(1, max(0.12, Double(totalVolume) / 220)),
                        tint: drinkTint
                    )
                    MixSummary(
                        channels: channels,
                        volume: totalVolume,
                        strength: strength,
                        fit: fit
                    )
                    FinishActions(
                        taste: { showsFeedback = true },
                        remix: surpriseMe
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(MixerBackground())
        .safeAreaInset(edge: .bottom) {
            MixerStepNavigation(
                step: step,
                canContinue: step != .tune || !channels.isEmpty,
                back: previousStep,
                next: nextStep
            )
        }
        .sheet(isPresented: $showsFeedback) {
            TasteFeedbackSheet(apply: applyFeedback)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .preferredColorScheme(.dark)
    }

    private var flavourNames: [String] {
        let existing = Array(mix.flavours.prefix(4)).map(\.name)
        let defaults = ["Sweet", "Sour", "Bitter", "Fizz"]
        return existing + defaults.dropFirst(existing.count)
    }

    private var totalVolume: Int {
        Int(channels.reduce(0) { $0 + $1.amount })
    }

    private var strength: Int {
        guard totalVolume > 0 else { return 0 }
        let spiritVolume = channels.filter(\.isSpirit).reduce(0) { $0 + $1.amount }
        return Int((spiritVolume * 0.4 / Double(totalVolume) * 100).rounded())
    }

    private var fit: Int {
        let imbalance = flavours.reduce(0) { $0 + abs($1 - 10) }
        return max(42, min(98, Int(96 - imbalance * 0.7 + adventure * 6)))
    }

    private var drinkTint: Color {
        guard let strongest = flavours.indices.max(by: { flavours[$0] < flavours[$1] }) else {
            return .cyan
        }
        return [.pink, .yellow, .orange, .cyan][strongest]
    }

    private func remember() {
        let snapshot = MixerSnapshot(flavours: flavours, channels: channels, adventure: adventure)
        guard history.last != snapshot else { return }
        history.append(snapshot)
        if history.count > 20 { history.removeFirst() }
    }

    private func undo() {
        guard let snapshot = history.popLast() else { return }
        withAnimation(.snappy) {
            flavours = snapshot.flavours
            channels = snapshot.channels
            adventure = snapshot.adventure
        }
    }

    private func reset() {
        if originalChannels.isEmpty {
            generateBaseline()
            return
        }
        remember()
        withAnimation(.snappy) {
            flavours = originalFlavours
            channels = originalChannels
            adventure = 0.35
        }
    }

    private func surpriseMe() {
        remember()
        withAnimation(.bouncy) {
            flavours = flavours.map { _ in Double.random(in: 3...19) }
            adventure = Double.random(in: 0.55...1)
            channels = channels.map {
                var channel = $0
                channel.amount = min(120, max(5, channel.amount + Double.random(in: -15...25)))
                return channel
            }
        }
    }

    private func add(_ ingredient: Ingredient) {
        remember()
        withAnimation(.snappy) {
            channels.append(MixerChannel(ingredient: ingredient))
        }
    }

    private func remove(_ id: String) {
        remember()
        withAnimation(.snappy) {
            channels.removeAll { $0.id == id }
        }
    }

    private func previousStep() {
        guard let previous = MixerStep(rawValue: step.rawValue - 1) else { return }
        withAnimation(.snappy) { step = previous }
    }

    private func nextStep() {
        if step == .vibe {
            generateBaseline()
            return
        }
        guard let next = MixerStep(rawValue: step.rawValue + 1) else { return }
        withAnimation(.snappy) { step = next }
    }

    private func generateBaseline() {
        remember()
        let baseName = spirit.generatedBase
        let baseAmount = 30 + preferredStrength * 35
        let sweetAmount = max(5, 25 - preferredDryness * 18)
        let sourAmount = 12 + preferredDryness * 12

        channels = [
            MixerChannel(name: baseName, amount: baseAmount, isSpirit: spirit != .zeroProof),
            MixerChannel(name: vibe.accentIngredient, amount: vibe.accentAmount),
            MixerChannel(name: "Fresh citrus", amount: sourAmount),
            MixerChannel(name: "House syrup", amount: sweetAmount),
            MixerChannel(name: vibe.topper, amount: 65)
        ]
        flavours = vibe.flavours
        adjustmentNote = nil
        withAnimation(.snappy) { step = .tune }
    }

    private func applyFeedback(_ feedback: TasteFeedback) {
        remember()
        switch feedback {
        case .tooSweet:
            flavours[0] = max(0, flavours[0] - 3)
            adjustChannel(named: "House syrup", by: -5)
            adjustmentNote = "Less syrup, with a drier finish."
        case .tooSour:
            flavours[1] = max(0, flavours[1] - 3)
            adjustChannel(named: "Fresh citrus", by: -5)
            adjustmentNote = "Softer citrus and a rounder balance."
        case .tooStrong:
            channels.indices.filter { channels[$0].isSpirit }.forEach {
                channels[$0].amount = max(10, channels[$0].amount - 10)
            }
            adjustmentNote = "Reduced the spirit and kept the flavour profile."
        case .tooWeak:
            channels.indices.filter { channels[$0].isSpirit }.forEach {
                channels[$0].amount = min(120, channels[$0].amount + 10)
            }
            adjustmentNote = "Lifted the base spirit by 10 ml."
        case .needsSpark:
            flavours[3] = min(20, flavours[3] + 4)
            adjustmentNote = "Added brightness and a livelier finish."
        case .perfect:
            adjustmentNote = "Locked in. This mix is ready to save."
        }
        showsFeedback = false
        withAnimation(.snappy) { step = feedback == .perfect ? .finish : .tune }
    }

    private func adjustChannel(named name: String, by delta: Double) {
        guard let index = channels.firstIndex(where: { $0.name == name }) else { return }
        channels[index].amount = max(0, min(120, channels[index].amount + delta))
    }
}

private enum MixerStep: Int, CaseIterable, Identifiable {
    case vibe
    case tune
    case finish

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .vibe: "Vibe"
        case .tune: "Tune"
        case .finish: "Finish"
        }
    }

    var eyebrow: LocalizedStringResource {
        switch self {
        case .vibe: "STEP 1 · SET THE VIBE"
        case .tune: "STEP 2 · SHAPE THE SOUND"
        case .finish: "STEP 3 · DROP THE MIX"
        }
    }

    var detail: LocalizedStringResource {
        switch self {
        case .vibe: "Tell us what you want. We’ll build the recipe."
        case .tune: "Turn the flavour knobs until it feels right."
        case .finish: "Review your creation, then save or remix it."
        }
    }
}

private struct MixerStepProgress: View {
    @Binding var step: MixerStep
    let hasBaseline: Bool

    var body: some View {
        HStack(spacing: 6) {
            ForEach(MixerStep.allCases) { item in
                Button {
                    withAnimation(.snappy) { step = item }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: item.rawValue < step.rawValue ? "checkmark" : "\(item.rawValue + 1)")
                            .font(.caption2.bold())
                            .frame(width: 22, height: 22)
                            .background(
                                item.rawValue <= step.rawValue ? Color.cyan : Color.white.opacity(0.08),
                                in: Circle()
                            )
                            .foregroundStyle(item.rawValue <= step.rawValue ? .black : .secondary)
                        Text(item.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(item == step ? .white : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        item == step ? Color.white.opacity(0.08) : Color.clear,
                        in: Capsule()
                    )
                }
                .buttonStyle(.plain)
                .disabled(!hasBaseline && item != .vibe)
                .opacity(!hasBaseline && item != .vibe ? 0.45 : 1)
                .accessibilityLabel("Step \(item.rawValue + 1), \(String(localized: item.title))")
            }
        }
        .padding(4)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

private struct MixerStepIntroduction: View {
    let step: MixerStep

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(step.eyebrow)
                .font(.caption2.bold())
                .foregroundStyle(.cyan)
            Text(step.detail)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentTransition(.interpolate)
    }
}

private enum DrinkVibe: String, CaseIterable, Identifiable {
    case refreshing
    case tropical
    case elegant
    case cozy
    case bold
    case surprising

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .refreshing: "Refreshing"
        case .tropical: "Tropical"
        case .elegant: "Elegant"
        case .cozy: "Cozy"
        case .bold: "Bold"
        case .surprising: "Surprising"
        }
    }

    var symbol: String {
        switch self {
        case .refreshing: "drop.fill"
        case .tropical: "sun.max.fill"
        case .elegant: "sparkles"
        case .cozy: "flame.fill"
        case .bold: "bolt.fill"
        case .surprising: "wand.and.stars"
        }
    }

    var accentIngredient: String {
        switch self {
        case .refreshing: "Cucumber"
        case .tropical: "Pineapple"
        case .elegant: "Elderflower"
        case .cozy: "Spiced honey"
        case .bold: "Ginger"
        case .surprising: "Basil"
        }
    }

    var accentAmount: Double {
        switch self {
        case .refreshing, .elegant, .surprising: 15
        case .tropical: 35
        case .cozy, .bold: 20
        }
    }

    var topper: String {
        switch self {
        case .refreshing, .elegant: "Soda water"
        case .tropical: "Coconut water"
        case .cozy: "Cloudy apple"
        case .bold: "Ginger beer"
        case .surprising: "Tonic water"
        }
    }

    var flavours: [Double] {
        switch self {
        case .refreshing: [7, 13, 3, 17]
        case .tropical: [14, 10, 2, 9]
        case .elegant: [7, 9, 6, 11]
        case .cozy: [13, 5, 9, 2]
        case .bold: [8, 12, 15, 7]
        case .surprising: [9, 11, 13, 12]
        }
    }
}

private enum SpiritChoice: String, CaseIterable, Identifiable {
    case chooseForMe
    case gin
    case rum
    case tequila
    case vodka
    case zeroProof

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .chooseForMe: "Choose for me"
        case .gin: "Gin"
        case .rum: "Rum"
        case .tequila: "Tequila"
        case .vodka: "Vodka"
        case .zeroProof: "Zero-proof"
        }
    }

    var generatedBase: String {
        switch self {
        case .chooseForMe, .gin: "Gin"
        case .rum: "White rum"
        case .tequila: "Tequila"
        case .vodka: "Vodka"
        case .zeroProof: "Juniper spirit"
        }
    }
}

private struct VibeBrief: View {
    @Binding var vibe: DrinkVibe
    @Binding var strength: Double
    @Binding var dryness: Double
    @Binding var spirit: SpiritChoice

    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                DeckTitle(title: "WHAT SHOULD IT FEEL LIKE?", detail: "Pick one")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(DrinkVibe.allCases) { option in
                        Button {
                            withAnimation(.snappy) { vibe = option }
                        } label: {
                            Label(option.title, systemImage: option.symbol)
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(
                                    option == vibe ? Color.cyan : Color.white.opacity(0.06),
                                    in: RoundedRectangle(cornerRadius: 14)
                                )
                                .foregroundStyle(option == vibe ? .black : .white)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .consolePanel()

            VStack(alignment: .leading, spacing: 18) {
                PreferenceFader(
                    title: "STRENGTH",
                    low: "Light",
                    high: "Spirit-forward",
                    value: $strength,
                    tint: .cyan
                )
                PreferenceFader(
                    title: "FINISH",
                    low: "Soft & sweet",
                    high: "Crisp & dry",
                    value: $dryness,
                    tint: .pink
                )
            }
            .consolePanel()

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("BASE SPIRIT")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                    Text("Optional — the bartender can choose")
                        .font(.caption)
                        .foregroundStyle(.white)
                }
                Spacer()
                Picker("Base spirit", selection: $spirit) {
                    ForEach(SpiritChoice.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .tint(.cyan)
            }
            .consolePanel()
        }
    }
}

private struct PreferenceFader: View {
    let title: LocalizedStringResource
    let low: LocalizedStringResource
    let high: LocalizedStringResource
    @Binding var value: Double
    let tint: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Slider(value: $value, in: 0...1)
                .tint(tint)
            HStack {
                Text(low)
                Spacer()
                Text(high)
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
        }
    }
}

private struct AdjustmentNote: View {
    let note: LocalizedStringResource

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "wand.and.stars")
                .foregroundStyle(.cyan)
            VStack(alignment: .leading, spacing: 2) {
                Text("REMIX APPLIED")
                    .font(.caption2.bold())
                    .foregroundStyle(.cyan)
                Text(note)
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }
            Spacer()
        }
        .consolePanel()
    }
}

private struct MixerHeader: View {
    let name: String
    let volume: Int
    let strength: Int
    let fit: Int
    let canUndo: Bool
    let undo: () -> Void
    let reset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("NOW MIXING")
                        .font(.caption2.bold())
                        .foregroundStyle(.cyan)
                    Text(name)
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                        .lineLimit(2)
                }
                Spacer()
                HStack(spacing: 8) {
                    Button(action: undo) { Image(systemName: "arrow.uturn.backward") }
                        .disabled(!canUndo)
                        .accessibilityLabel("Undo last mixer change")
                    Button(action: reset) { Image(systemName: "arrow.counterclockwise") }
                        .accessibilityLabel("Reset mixer")
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
            }
            HStack(spacing: 0) {
                Metric(value: "\(volume) ml", title: "VOLUME")
                Metric(value: "\(strength)%", title: "ABV")
                Metric(value: "\(fit)%", title: "FIT")
            }
            .padding(.vertical, 10)
            .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 14))
        }
    }
}

private struct Metric: View {
    let value: String
    let title: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.monospacedDigit())
                .contentTransition(.numericText())
            Text(title)
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct DrinkPreview: View {
    let fill: Double
    let tint: Color
    var compact = false

    var body: some View {
        ZStack {
            Circle().fill(tint.opacity(0.13)).blur(radius: 24)
            ZStack(alignment: .bottom) {
                glassShape.fill(.white.opacity(0.05))
                glassShape
                    .fill(LinearGradient(colors: [tint.opacity(0.55), tint], startPoint: .top, endPoint: .bottom))
                    .frame(height: 126 * fill)
                    .padding(5)
            }
            .frame(width: 108, height: 136)
            .overlay { glassShape.stroke(.white.opacity(0.24), lineWidth: 1.5) }
            .shadow(color: tint.opacity(0.4), radius: 22)
        }
        .frame(maxWidth: .infinity)
        .frame(height: compact ? 118 : 160)
        .scaleEffect(compact ? 0.72 : 1)
        .padding(.vertical, compact ? -14 : 0)
        .animation(.bouncy, value: fill)
        .accessibilityLabel("Drink preview, \(Int(fill * 100)) percent full")
    }

    private var glassShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 8,
            bottomLeadingRadius: 38,
            bottomTrailingRadius: 38,
            topTrailingRadius: 8
        )
    }
}

private struct MixSummary: View {
    let channels: [MixerChannel]
    let volume: Int
    let strength: Int
    let fit: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DeckTitle(title: "FINAL TRACK", detail: "\(channels.count) channels")

            ForEach(channels) { channel in
                HStack {
                    Circle()
                        .fill(channel.tint)
                        .frame(width: 8, height: 8)
                    Text(channel.name)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(channel.amount, format: .number.precision(.fractionLength(0)))
                        .font(.subheadline.monospacedDigit().bold())
                    Text(channel.unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider().overlay(.white.opacity(0.1))

            HStack(spacing: 0) {
                Metric(value: "\(volume) ml", title: "VOLUME")
                Metric(value: "\(strength)%", title: "ABV")
                Metric(value: "\(fit)%", title: "FIT")
            }
        }
        .consolePanel()
    }
}

private struct MixerStepNavigation: View {
    let step: MixerStep
    let canContinue: Bool
    let back: () -> Void
    let next: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if step != .vibe {
                Button(action: back) {
                    Label("Back", systemImage: "chevron.left")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            if step != .finish {
                Button(action: next) {
                    Label(step == .vibe ? "Generate my mix" : "Finish mix", systemImage: step == .vibe ? "sparkles" : "chevron.right")
                        .labelStyle(TrailingIconLabelStyle())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
                .foregroundStyle(.black)
                .disabled(!canContinue)
            }
        }
        .controlSize(.large)
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 4)
        .background(.ultraThinMaterial)
    }
}

private struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.title
            configuration.icon
        }
    }
}

private struct FlavourDeck: View {
    let names: [String]
    @Binding var values: [Double]
    @Binding var activeKnob: Int?
    let remember: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DeckTitle(title: "FLAVOUR DECK", detail: "Drag the knobs")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 18) {
                ForEach(values.indices, id: \.self) { index in
                    MixerKnob(
                        name: names[index],
                        value: $values[index],
                        isActive: activeKnob == index,
                        begin: {
                            if activeKnob != index {
                                remember()
                                activeKnob = index
                            }
                        },
                        end: { activeKnob = nil }
                    )
                }
            }
        }
        .consolePanel()
    }
}

private struct MixerKnob: View {
    let name: String
    @Binding var value: Double
    let isActive: Bool
    let begin: () -> Void
    let end: () -> Void
    @State private var startingValue = 0.0

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().stroke(.white.opacity(0.09), lineWidth: 9)
                Circle()
                    .trim(from: 0, to: value / 20)
                    .stroke(
                        AngularGradient(colors: [.cyan, .purple, .pink], center: .center),
                        style: StrokeStyle(lineWidth: 9, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                Circle()
                    .fill(RadialGradient(colors: [.white.opacity(0.18), .black], center: .topLeading, startRadius: 0, endRadius: 48))
                    .padding(12)
                    .overlay {
                        Capsule()
                            .fill(.white)
                            .frame(width: 3, height: 20)
                            .offset(y: -20)
                            .rotationEffect(.degrees(-135 + value / 20 * 270))
                    }
                    .shadow(color: isActive ? .cyan.opacity(0.8) : .clear, radius: 12)
                Text(value, format: .number.precision(.fractionLength(0)))
                    .font(.caption.monospacedDigit().bold())
            }
            .frame(width: 88, height: 88)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !isActive {
                            startingValue = value
                            begin()
                        }
                        value = min(20, max(0, startingValue - gesture.translation.height / 5))
                    }
                    .onEnded { _ in end() }
            )
            .accessibilityElement()
            .accessibilityLabel(name)
            .accessibilityValue("\(Int(value)) out of 20")
            .accessibilityAdjustableAction { direction in
                begin()
                switch direction {
                case .increment: value = min(20, value + 1)
                case .decrement: value = max(0, value - 1)
                @unknown default: break
                }
                end()
            }
            Text(name.uppercased())
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
        }
    }
}

private struct Crossfader: View {
    @Binding var value: Double
    let remember: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DeckTitle(title: "CROSSFADER", detail: "How far should we push it?")
            Slider(value: $value, in: 0...1, onEditingChanged: { if $0 { remember() } })
                .tint(.pink)
            HStack {
                Label("Familiar", systemImage: "record.circle")
                Spacer()
                Label("Wildcard", systemImage: "sparkles")
            }
            .font(.caption2.bold())
            .foregroundStyle(.secondary)
        }
        .consolePanel()
    }
}

private struct ChannelDeck: View {
    @Binding var channels: [MixerChannel]
    let suggestions: [Ingredient]
    let remember: () -> Void
    let add: (Ingredient) -> Void
    let remove: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DeckTitle(title: "INGREDIENT CHANNELS", detail: "Shape the recipe")
            if channels.isEmpty {
                ContentUnavailableView(
                    "No channels loaded",
                    systemImage: "slider.horizontal.3",
                    description: Text("Add an ingredient below to start mixing.")
                )
            } else {
                ForEach($channels) { $channel in
                    IngredientFader(
                        channel: $channel,
                        remember: remember,
                        remove: { remove(channel.id) }
                    )
                }
            }
            if !suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestions) { ingredient in
                            Button { add(ingredient) } label: {
                                Label(ingredient.name, systemImage: "plus")
                            }
                            .buttonStyle(.bordered)
                            .tint(.cyan)
                            .disabled(channels.contains { $0.name == ingredient.name })
                        }
                    }
                }
            } else {
                Button(action: {}) {
                    Label("Add ingredient", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.cyan)
            }
        }
        .consolePanel()
    }
}

private struct IngredientFader: View {
    @Binding var channel: MixerChannel
    let remember: () -> Void
    let remove: () -> Void

    var body: some View {
        VStack(spacing: 7) {
            HStack {
                Circle()
                    .fill(channel.tint)
                    .frame(width: 8, height: 8)
                    .shadow(color: channel.tint, radius: 4)
                Text(channel.name).font(.subheadline.bold())
                Spacer()
                Text(channel.amount, format: .number.precision(.fractionLength(0)))
                    .font(.subheadline.monospacedDigit().bold())
                    .contentTransition(.numericText())
                Text(channel.unit).font(.caption).foregroundStyle(.secondary)
                Button(role: .destructive, action: remove) {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Remove \(channel.name)")
            }
            Slider(value: $channel.amount, in: 0...120, step: 5, onEditingChanged: {
                if $0 { remember() }
            })
            .tint(channel.tint)
            .accessibilityLabel("\(channel.name) amount")
        }
        .padding(.vertical, 4)
    }
}

private struct FinishActions: View {
    let taste: () -> Void
    let remix: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Button(action: taste) {
                Label("I made it — taste check", systemImage: "mouth.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.cyan)
            .foregroundStyle(.black)

            HStack(spacing: 12) {
                Button(action: remix) {
                    Label("Remix", systemImage: "shuffle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(action: {}) {
                    Label("Save", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .controlSize(.large)
    }
}

private enum TasteFeedback: String, CaseIterable, Identifiable {
    case tooSweet
    case tooSour
    case tooStrong
    case tooWeak
    case needsSpark
    case perfect

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .tooSweet: "Too sweet"
        case .tooSour: "Too sour"
        case .tooStrong: "Too strong"
        case .tooWeak: "Too weak"
        case .needsSpark: "Needs a spark"
        case .perfect: "Perfect"
        }
    }

    var symbol: String {
        switch self {
        case .tooSweet: "cube.fill"
        case .tooSour: "drop.triangle.fill"
        case .tooStrong: "flame.fill"
        case .tooWeak: "arrow.down"
        case .needsSpark: "sparkles"
        case .perfect: "checkmark.circle.fill"
        }
    }
}

private struct TasteFeedbackSheet: View {
    let apply: (TasteFeedback) -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("How did it land?")
                        .font(.title.bold())
                    Text("Pick the closest reaction. The mixer will rebalance the recipe for you.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(TasteFeedback.allCases) { feedback in
                        Button {
                            apply(feedback)
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: feedback.symbol)
                                    .font(.title2)
                                    .foregroundStyle(feedback == .perfect ? .green : .cyan)
                                Text(feedback.title)
                                    .font(.subheadline.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity, minHeight: 76)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Taste check")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct DeckTitle: View {
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.caption2.bold())
            Spacer()
            Text(detail).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

private struct MixerBackground: View {
    var body: some View {
        ZStack {
            Color.black
            RadialGradient(
                colors: [.cyan.opacity(0.12), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 340
            )
        }
        .ignoresSafeArea()
    }
}

private struct MixerChannel: Identifiable, Equatable {
    let id: String
    let name: String
    var amount: Double
    let unit: String
    let tint: Color
    let isSpirit: Bool

    init(name: String, amount: Double, unit: String = "ml", isSpirit: Bool = false) {
        id = name
        self.name = name
        self.amount = amount
        self.unit = unit
        self.isSpirit = isSpirit
        tint = isSpirit ? .cyan : Self.tint(for: name.lowercased())
    }

    init(ingredient: Ingredient) {
        id = ingredient.name
        name = ingredient.name
        let parts = ingredient.amount.split(separator: " ")
        amount = Double(parts.first ?? "") ?? 15
        let parsedUnit = parts.dropFirst().joined(separator: " ")
        unit = parsedUnit.isEmpty ? "ml" : parsedUnit
        let lowercasedName = ingredient.name.lowercased()
        isSpirit = ["gin", "rum", "vodka", "tequila", "whisky", "whiskey", "bourbon", "liqueur"]
            .contains { lowercasedName.contains($0) }
        tint = isSpirit ? .cyan : Self.tint(for: lowercasedName)
    }

    private static func tint(for name: String) -> Color {
        if name.contains("lemon") || name.contains("lime") { return .yellow }
        if name.contains("mint") || name.contains("basil") { return .green }
        if name.contains("berry") || name.contains("grenadine") { return .pink }
        return .orange
    }
}

private struct MixerSnapshot: Equatable {
    let flavours: [Double]
    let channels: [MixerChannel]
    let adventure: Double
}

private extension View {
    func consolePanel() -> some View {
        padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            }
    }
}

#Preview("Existing drink") {
    NavigationStack {
        MixerView(mix: MockData.blueLagoonDub)
    }
}

#Preview("New mix") {
    NavigationStack {
        MixerView(mix: MockData.newMix)
    }
}
