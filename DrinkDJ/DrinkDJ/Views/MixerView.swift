import SwiftUI
import Foundation

private enum MixerSheet: String, Identifiable {
    case save, saved, history, preferences, feedback, match
    var id: Self { self }
}

struct MixerView: View {
    let mix: Mix
    @State private var store = RemixStore.shared
    @State private var original: RemixRecipe
    @State private var recipe: RemixRecipe
    @State private var baseVersionID: UUID?
    @State private var history: [RemixWorkingCopy] = []
    @State private var comparing = false
    @State private var ingredientPicker: IngredientPickerRequest?
    @State private var activeSheet: MixerSheet?
    @State private var nextSheet: MixerSheet?
    @State private var lastSavedVersion: RemixVersion?
    @State private var storageError: String?

    @MainActor init(mix: Mix) {
        self.mix = mix
        let baseline = RemixRecipe.startingRecipe(for: mix)
        let copy = RemixStore.shared.loadDraft(baseline: baseline)
        _original = State(initialValue: copy.original)
        _recipe = State(initialValue: copy.recipe)
        _baseVersionID = State(initialValue: copy.baseVersionID)
    }

    private var workingCopy: RemixWorkingCopy {
        RemixWorkingCopy(recipe: recipe, original: original, baseVersionID: baseVersionID)
    }

    private var hasChanges: Bool {
        recipe != (store.version(baseVersionID)?.recipe ?? original)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                RemixIntroduction(source: original.source, comparing: $comparing)
                RemixSessionControls(
                    match: recipe.ingredients.isEmpty ? nil : RemixMatch.estimate(
                        recipe: comparing ? original : recipe, preferences: store.preferences
                    ).percent,
                    version: store.version(baseVersionID).map { "Version \($0.number)" } ?? "Not saved",
                    modified: hasChanges,
                    canUndo: !history.isEmpty && !comparing,
                    canGiveFeedback: !comparing && !recipe.ingredients.isEmpty,
                    showMatch: { activeSheet = .match },
                    showPreferences: { activeSheet = .preferences },
                    showHistory: { activeSheet = .history },
                    showFeedback: { activeSheet = .feedback },
                    undo: {
                        if let previous = history.popLast() { setCopy(previous) }
                    }
                )
                if comparing {
                    Label("Viewing Original. Switch to Remix to keep editing.", systemImage: "eye")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                RemixIngredientsSection(
                    ingredients: comparing ? original.ingredients : recipe.ingredients,
                    originals: original.ingredients,
                    editable: !comparing,
                    change: changeIngredient,
                    remember: remember,
                    swap: { ingredientPicker = IngredientPickerRequest(target: $0) },
                    remove: removeIngredient,
                    add: { ingredientPicker = IngredientPickerRequest(target: nil) }
                )
                if !comparing && recipe != original {
                    Button("Reset to original", systemImage: "arrow.counterclockwise") {
                        remember()
                        recipe = original
                    }
                    .font(.subheadline)
                }
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(red: 0.035, green: 0.055, blue: 0.075))
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            RemixSaveBar(recipe: comparing ? original : recipe, comparing: comparing, disabled: comparing || recipe.ingredients.isEmpty) {
                activeSheet = .save
            }
        }
        .sheet(item: $ingredientPicker) { request in
            RemixIngredientPicker(isSwapping: request.target != nil) { name, amount, unit in
                remember()
                if let id = request.target,
                   let index = recipe.ingredients.firstIndex(where: { $0.id == id }) {
                    let previousUnit = recipe.ingredients[index].unit
                    recipe.ingredients[index].name = name
                    recipe.ingredients[index].unit = unit
                    if previousUnit != unit { recipe.ingredients[index].amount = amount }
                } else {
                    recipe.ingredients.append(RemixIngredient(name: name, amount: amount, unit: unit))
                }
                ingredientPicker = nil
            }
        }
        .sheet(item: $activeSheet, onDismiss: {
            if let next = nextSheet {
                nextSheet = nil
                activeSheet = next
            }
        }) { sheet in
            switch sheet {
            case .save:
                RemixSaveSheet(
                    recipe: recipe,
                    original: store.version(baseVersionID)?.recipe ?? original,
                    parentLabel: store.version(baseVersionID)?.userFacingLabel ?? "Original recipe",
                    canCreateVariation: baseVersionID != nil,
                    initialName: store.version(baseVersionID)?.name ?? "\(recipe.source) · My remix"
                ) { name, message, separateIdea in
                    let branch = separateIdea ? "variation-\(UUID().uuidString.prefix(8).lowercased())" : store.suggestedBranch(for: workingCopy)
                    let version = try store.commit(copy: workingCopy, name: name, message: message, branch: branch)
                    baseVersionID = version.id
                    history.removeAll()
                    lastSavedVersion = version
                    nextSheet = .saved
                    activeSheet = nil
                }
            case .saved:
                if let version = lastSavedVersion {
                    RemixSavedConfirmation(
                        version: version,
                        rate: {
                            nextSheet = .feedback
                            activeSheet = nil
                        },
                        keepMixing: { activeSheet = nil },
                        seeVersions: {
                            nextSheet = .history
                            activeSheet = nil
                        }
                    )
                }
            case .history:
                RemixHistorySheet(
                    store: store, source: recipe.source, currentVersionID: baseVersionID,
                    canTaste: !recipe.ingredients.isEmpty,
                    tasteCurrent: {
                        comparing = false
                        nextSheet = .feedback
                        activeSheet = nil
                    },
                    checkout: { version in
                        checkout(RemixWorkingCopy(recipe: version.recipe, original: version.original, baseVersionID: version.id))
                    },
                    restoreDraft: checkout
                )
            case .preferences:
                RemixPreferencesSheet()
            case .feedback:
                RemixFeedbackSheet(store: store, copy: workingCopy) { suggestion in
                    remember()
                    recipe = suggestion
                    comparing = false
                    activeSheet = nil
                }
            case .match:
                RemixMatchSheet(recipe: comparing ? original : recipe, preferences: store.preferences) {
                    nextSheet = .preferences
                    activeSheet = nil
                }
            }
        }
        .alert("Remix data", isPresented: Binding(
            get: { storageError != nil },
            set: { if !$0 { storageError = nil } }
        )) {
            Button("OK") { storageError = nil }
        } message: { Text(storageError ?? "") }
        .onChange(of: workingCopy) { _, copy in
            do { try store.saveDraft(copy) }
            catch { storageError = error.localizedDescription }
        }
        .task {
            if let error = store.loadError { storageError = error }
        }
        .tint(.cyan).preferredColorScheme(.dark)
    }

    private func remember() {
        guard history.last != workingCopy else { return }
        history.append(workingCopy)
        if history.count > 50 { history.removeFirst() }
    }

    private func setCopy(_ copy: RemixWorkingCopy) {
        original = copy.original
        recipe = copy.recipe
        baseVersionID = copy.baseVersionID
        comparing = false
    }

    private func checkout(_ copy: RemixWorkingCopy) {
        do {
            if hasChanges { try store.preserveDraft(workingCopy) }
            remember()
            setCopy(copy)
            activeSheet = nil
        } catch { storageError = error.localizedDescription }
    }

    private func changeIngredient(_ ingredient: RemixIngredient) {
        guard let index = recipe.ingredients.firstIndex(where: { $0.id == ingredient.id }) else { return }
        recipe.ingredients[index] = ingredient
    }

    private func removeIngredient(_ id: UUID) {
        remember()
        recipe.ingredients.removeAll { $0.id == id }
    }
}

private struct IngredientPickerRequest: Identifiable {
    let id = UUID()
    let target: UUID?
}

private struct RemixIntroduction: View {
    let source: String
    @Binding var comparing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(source).font(.title2.bold())
            Picker("Recipe comparison", selection: $comparing) {
                Text("Original").tag(true)
                Text("Remix").tag(false)
            }
            .pickerStyle(.segmented)
        }
    }
}

private struct RemixSectionHeading: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.title2.bold())
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct RemixIngredientsSection: View {
    let ingredients: [RemixIngredient]
    let originals: [RemixIngredient]
    let editable: Bool
    let change: (RemixIngredient) -> Void
    let remember: () -> Void
    let swap: (UUID) -> Void
    let remove: (UUID) -> Void
    let add: () -> Void
    @State private var deleting = false
    @State private var visibleChannel: UUID?
    @State private var visibleChannelIDs: Set<UUID> = []
    @ScaledMetric(relativeTo: .body) private var minimumWidth = 104
    private let addChannelID = UUID(uuid: (255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255))

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("CHANNELS").font(.caption.monospaced().bold()).foregroundStyle(.secondary)
                Spacer()
                Button("Add", systemImage: "plus", action: add).disabled(!editable)
                Button(deleting ? "Done" : "Delete", systemImage: deleting ? "checkmark" : "trash") {
                    deleting.toggle()
                }
                .tint(deleting ? .cyan : .red)
                .disabled(!editable || (ingredients.isEmpty && !deleting))
            }
            .font(.subheadline).frame(minHeight: 44)
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(ingredients) { ingredient in
                        RemixIngredientChannel(
                            ingredient: ingredient,
                            original: originals.first { $0.id == ingredient.id },
                            number: (ingredients.firstIndex { $0.id == ingredient.id } ?? 0) + 1,
                            deleting: deleting,
                            change: change, remember: remember,
                            swap: { swap(ingredient.id) },
                            remove: { remove(ingredient.id) }
                        )
                        .containerRelativeFrame(.horizontal, count: 3, spacing: 8)
                        .frame(minWidth: minimumWidth)
                        .disabled(!editable)
                    }
                    Button(action: add) {
                        VStack(spacing: 12) {
                            Image(systemName: "plus.circle").font(.largeTitle)
                            Text("Add channel").font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity, minHeight: 330)
                        .background(.cyan.opacity(0.035), in: RoundedRectangle(cornerRadius: 14))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(.cyan.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        }
                    }
                    .buttonStyle(.plain)
                    .containerRelativeFrame(.horizontal, count: 3, spacing: 8)
                    .frame(minWidth: minimumWidth)
                    .id(addChannelID)
                    .disabled(!editable)
                }
                .scrollTargetLayout().padding(.vertical, 3)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $visibleChannel, anchor: .leading)
            .scrollIndicators(.hidden)
            .onScrollTargetVisibilityChange(idType: UUID.self, threshold: 0.5) { ids in
                visibleChannelIDs = Set(ids)
            }
            RemixChannelNavigator(
                ingredients: ingredients,
                visibleIDs: visibleChannelIDs,
                canGoNext: !visibleChannelIDs.contains(addChannelID),
                select: { id in withAnimation { visibleChannel = id } },
                previous: {
                    let first = ingredients.firstIndex { visibleChannelIDs.contains($0.id) } ?? 0
                    withAnimation { visibleChannel = ingredients[max(0, first - 1)].id }
                },
                next: {
                    let first = ingredients.firstIndex { visibleChannelIDs.contains($0.id) } ?? 0
                    withAnimation {
                        visibleChannel = first + 1 < ingredients.count ? ingredients[first + 1].id : addChannelID
                    }
                }
            )
            .disabled(ingredients.isEmpty)
            Text(deleting ? "Tap a channel’s red trash button to remove it." : "White marker = original · tap an amount to type")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
}

private struct RemixChannelNavigator: View {
    let ingredients: [RemixIngredient]
    let visibleIDs: Set<UUID>
    let canGoNext: Bool
    let select: (UUID) -> Void
    let previous: () -> Void
    let next: () -> Void

    private var visibleIndices: [Int] {
        ingredients.indices.filter { visibleIDs.contains(ingredients[$0].id) }
    }

    var body: some View {
        HStack(spacing: 8) {
            Button("Previous channel", systemImage: "chevron.left", action: previous)
                .labelStyle(.iconOnly).frame(width: 32, height: 44)
                .disabled(visibleIndices.first == 0)
            GeometryReader { geometry in
                let count = max(1, ingredients.count)
                let gap: CGFloat = 4
                let segmentWidth = max(0, (geometry.size.width - gap * CGFloat(count - 1)) / CGFloat(count))
                let first = visibleIndices.first ?? 0
                let last = visibleIndices.last ?? min(2, count - 1)
                HStack(spacing: gap) {
                    ForEach(ingredients) { ingredient in
                        Button { select(ingredient.id) } label: {
                            Capsule()
                                .fill(RemixChannelStyle.tint(for: ingredient.name))
                                .opacity(visibleIDs.contains(ingredient.id) ? 1 : 0.3)
                                .frame(height: 6)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .accessibilityLabel("Show \(ingredient.name)")
                        .accessibilityAddTraits(visibleIDs.contains(ingredient.id) ? .isSelected : [])
                    }
                }
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(.white.opacity(0.85), lineWidth: 1)
                        .frame(width: segmentWidth * CGFloat(last - first + 1) + gap * CGFloat(last - first), height: 16)
                        .offset(x: CGFloat(first) * (segmentWidth + gap))
                        .allowsHitTesting(false)
                }
                .overlay(alignment: .topLeading) {
                    HStack(spacing: 0) {
                        Rectangle().fill(.white).frame(width: 2, height: 4)
                        Spacer(minLength: 0)
                        Rectangle().fill(.white).frame(width: 2, height: 4)
                    }
                    .frame(width: segmentWidth * CGFloat(last - first + 1) + gap * CGFloat(last - first))
                    .offset(x: CGFloat(first) * (segmentWidth + gap), y: 10)
                    .allowsHitTesting(false)
                }
            }
            .frame(height: 44)
            Button("Next channel", systemImage: "chevron.right", action: next)
                .labelStyle(.iconOnly).frame(width: 32, height: 44)
                .disabled(!canGoNext)
        }
        .tint(.cyan)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Channel overview. Outlined colors are on screen.")
    }
}

private enum RemixChannelStyle {
    static func tint(for name: String) -> Color {
        let name = name.lowercased()
        if ["lime", "lemon", "grapefruit", "citrus"].contains(where: { name.contains($0) }) { return .green }
        if ["syrup", "honey", "agave", "liqueur", "curaçao"].contains(where: { name.contains($0) }) { return .orange }
        if ["mint", "herb", "rosemary", "cucumber"].contains(where: { name.contains($0) }) { return .mint }
        if ["soda", "ice", "tonic", "water"].contains(where: { name.contains($0) }) { return .blue }
        return .cyan
    }
}

private struct RemixIngredientChannel: View {
    let ingredient: RemixIngredient
    let original: RemixIngredient?
    let number: Int
    let deleting: Bool
    let change: (RemixIngredient) -> Void
    let remember: () -> Void
    let swap: () -> Void
    let remove: () -> Void
    private var tint: Color { RemixChannelStyle.tint(for: ingredient.name) }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(String(format: "CH %02d", number)).font(.caption2.monospaced().bold())
                Spacer(minLength: 0)
                Circle().fill(tint).frame(width: 6, height: 6)
            }
            .foregroundStyle(.secondary)
            Text(ingredient.name).font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 42, alignment: .top)
                .fixedSize(horizontal: false, vertical: true)
            RemixAmountField(
                amount: ingredient.amount, unit: ingredient.unit,
                name: ingredient.name, tint: tint, remember: remember, change: updateAmount
            )
            RemixVerticalFader(
                value: Binding(get: { ingredient.amount }, set: updateAmount),
                original: original?.unit == ingredient.unit ? original?.amount : nil,
                maximum: max(ingredient.unit == "ml" ? 150 : 20, original?.amount ?? 0, ingredient.amount),
                tint: tint, label: ingredient.name, unit: ingredient.unit, remember: remember
            )
            .frame(height: 140)
            Text(changeDescription).font(.caption2.monospaced())
                .foregroundStyle(.secondary).multilineTextAlignment(.center).frame(minHeight: 24)
            if deleting {
                Button("Delete", systemImage: "trash", role: .destructive, action: remove)
                    .font(.caption.weight(.semibold)).buttonStyle(.bordered).tint(.red).frame(minHeight: 44)
                    .accessibilityLabel("Delete \(ingredient.name)")
            } else {
                Button("Swap", systemImage: "arrow.triangle.2.circlepath", action: swap)
                    .font(.caption.weight(.semibold)).buttonStyle(.bordered).tint(tint).frame(minHeight: 44)
            }
        }
        .padding(10)
        .background(
            LinearGradient(colors: [Color(white: 0.115), Color(white: 0.065)], startPoint: .top, endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: 14)
        )
        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(deleting ? .red.opacity(0.6) : .white.opacity(0.12)) }
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: 2).fill(tint).frame(height: 3).padding(.horizontal, 12)
                .accessibilityHidden(true)
        }
    }

    private func updateAmount(_ amount: Double) {
        var updated = ingredient
        updated.amount = amount
        change(updated)
    }

    private var changeDescription: String {
        guard let original else { return "" }
        if original.name != ingredient.name { return "SWAPPED" }
        if original.amount == ingredient.amount { return "ORIGINAL" }
        let difference = ingredient.amount - original.amount
        return "\(difference > 0 ? "+" : "")\(difference.formatted()) \(ingredient.unit)"
    }
}

private struct RemixAmountField: View {
    let amount: Double
    let unit: String
    let name: String
    let tint: Color
    let remember: () -> Void
    let change: (Double) -> Void
    @State private var input = ""
    @State private var selection: TextSelection?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 1) {
            TextField("Amount", text: $input, selection: $selection)
                .font(.title2.monospacedDigit().bold())
                .multilineTextAlignment(.center)
                .keyboardType(.decimalPad)
                .focused($focused)
                .accessibilityLabel("\(name) amount in \(unit)")
                .onChange(of: input) { _, text in
                    guard focused,
                          let value = Double(text.replacingOccurrences(of: ",", with: ".")),
                          value.isFinite, (0...1000).contains(value) else { return }
                    change(value)
                }
            Text(unit).font(.caption)
        }
        .foregroundStyle(tint)
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
        .onAppear { input = formattedAmount }
        .onChange(of: amount) { _, _ in if !focused { input = formattedAmount } }
        .onChange(of: focused) { _, editing in
            if editing {
                remember()
                selection = TextSelection(range: input.startIndex..<input.endIndex)
            } else {
                input = formattedAmount
            }
        }
        .toolbar {
            if focused {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focused = false }
                }
            }
        }
    }

    private var formattedAmount: String {
        amount.formatted(.number.grouping(.never).precision(.fractionLength(0...1)))
    }
}

private struct RemixVerticalFader: View {
    @Binding var value: Double
    let original: Double?
    let maximum: Double
    let tint: Color
    let label: String
    let unit: String
    let remember: () -> Void
    @State private var dragStart: Double?
    @State private var dragMaximum: Double?

    var body: some View {
        GeometryReader { geometry in
            let travel = max(1, geometry.size.height - 30)
            let limit = dragMaximum ?? maximum
            let fraction = min(1, max(0, value / limit))
            ZStack {
                VStack {
                    ForEach(0..<11) { tick in
                        HStack {
                            Rectangle().fill(.white.opacity(0.2)).frame(width: tick % 5 == 0 ? 14 : 7, height: 1)
                            Spacer()
                            Rectangle().fill(.white.opacity(0.2)).frame(width: tick % 5 == 0 ? 14 : 7, height: 1)
                        }
                        if tick < 10 { Spacer(minLength: 0) }
                    }
                }
                .padding(.vertical, 15)
                Capsule().fill(.black).frame(width: 7).padding(.vertical, 15)
                Capsule().fill(tint.opacity(0.5))
                    .frame(width: 3, height: travel * fraction)
                    .position(x: geometry.size.width / 2, y: 15 + travel - travel * fraction / 2)
                if let original {
                    Rectangle().fill(.white).frame(width: 20, height: 2)
                        .position(x: geometry.size.width / 2 + 17, y: 15 + travel * (1 - min(1, original / limit)))
                }
                RoundedRectangle(cornerRadius: 5)
                    .fill(LinearGradient(colors: [.gray, Color(white: 0.2), Color(white: 0.42)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 46, height: 30)
                    .overlay {
                        VStack(spacing: 3) {
                            Rectangle().fill(.black.opacity(0.5)).frame(height: 1)
                            Rectangle().fill(tint).frame(height: 2)
                            Rectangle().fill(.black.opacity(0.5)).frame(height: 1)
                        }
                        .padding(.horizontal, 5)
                    }
                    .shadow(color: .black.opacity(0.6), radius: 3, y: 3)
                    .frame(width: 60, height: 50).contentShape(Rectangle())
                    .position(x: geometry.size.width / 2, y: 15 + travel * (1 - fraction))
                    .gesture(
                        DragGesture(minimumDistance: 2, coordinateSpace: .global)
                            .onChanged { event in
                                if dragStart == nil {
                                    remember()
                                    dragStart = value
                                    dragMaximum = maximum
                                }
                                value = min(limit, max(0, (dragStart ?? value) - Double(event.translation.height / travel) * limit)).rounded()
                            }
                            .onEnded { _ in
                                dragStart = nil
                                dragMaximum = nil
                            }
                    )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) amount")
        .accessibilityValue("\(value.formatted()) \(unit)")
        .accessibilityHint("Swipe up or down to adjust. Tap the amount above for exact entry.")
        .accessibilityAdjustableAction { direction in
            remember()
            switch direction {
            case .increment: value = min(maximum, value + 1)
            case .decrement: value = max(0, value - 1)
            @unknown default: break
            }
        }
    }
}

private struct RemixPreparationSection: View {
    let steps: [RemixPreparationStep]
    @Binding var expanded: UUID?
    let editable: Bool
    let change: (RemixPreparationStep) -> Void
    let remove: (UUID) -> Void
    let move: (UUID, Int) -> Void
    let reorder: (UUID, UUID) -> Void
    let add: (PreparationMethod) -> Void
    @State private var targetedStep: UUID?
    @State private var dragNamespace = UUID().uuidString

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                RemixSectionHeading(title: "Preparation rack", detail: "Hold the grip and drag to reorder")
                Spacer()
                Menu {
                    ForEach(PreparationMethod.allCases) { method in
                        Button(method.rawValue) { add(method) }
                    }
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .disabled(!editable)
            }
            ForEach(steps) { step in
                RemixStepCard(
                    step: step,
                    number: (steps.firstIndex(where: { $0.id == step.id }) ?? 0) + 1,
                    expanded: editable && expanded == step.id,
                    dragToken: "drinkdj.preparation.\(dragNamespace).\(step.id.uuidString)",
                    toggle: { expanded = expanded == step.id ? nil : step.id },
                    change: change,
                    remove: { remove(step.id) },
                    moveUp: { move(step.id, -1) },
                    moveDown: { move(step.id, 1) },
                    canMoveUp: steps.first?.id != step.id,
                    canMoveDown: steps.last?.id != step.id
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(targetedStep == step.id ? .cyan : .clear, lineWidth: 2)
                        .allowsHitTesting(false)
                }
                .dropDestination(for: String.self) { values, _ in
                    guard editable, let token = values.first else { return false }
                    let prefix = "drinkdj.preparation.\(dragNamespace)."
                    guard token.hasPrefix(prefix),
                          let source = UUID(uuidString: String(token.dropFirst(prefix.count))),
                          steps.contains(where: { $0.id == source }) else { return false }
                    reorder(source, step.id)
                    targetedStep = nil
                    return true
                } isTargeted: { targeted in
                    targetedStep = targeted && editable ? step.id : nil
                }
                .disabled(!editable)
            }
            if steps.isEmpty {
                Text("Add a preparation step to guide someone making your remix.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}

private struct RemixStepCard: View {
    let step: RemixPreparationStep
    let number: Int
    let expanded: Bool
    let dragToken: String
    let toggle: () -> Void
    let change: (RemixPreparationStep) -> Void
    let remove: () -> Void
    let moveUp: () -> Void
    let moveDown: () -> Void
    let canMoveUp: Bool
    let canMoveDown: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                Button(action: toggle) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(String(format: "FX %02d", number))
                            .font(.caption2.monospaced().bold()).foregroundStyle(.cyan)
                        Label(step.method.rawValue, systemImage: step.method.symbol).font(.headline)
                        Text(step.method.isTimed ? step.ice : step.summary)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                // A reserved center column keeps the knob fixed when settings expand.
                VStack {
                    if step.method.isTimed {
                        RemixMiniDurationKnob(value: binding(\.seconds))
                    } else {
                        Image(systemName: step.method.symbol)
                            .font(.title2).foregroundStyle(.secondary)
                            .frame(width: 48, height: 63)
                    }
                }
                .frame(width: 72)
                Button(action: toggle) {
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption).frame(width: 32, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(expanded ? "Collapse preparation settings" : "Expand preparation settings")
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 52)
                    .contentShape(Rectangle())
                    .draggable(dragToken)
                    .accessibilityLabel("Drag \(step.method.rawValue) to reorder")
            }
            if expanded {
                Divider()
                Picker("Method", selection: Binding(
                    get: { step.method },
                    set: { method in
                        var updated = step
                        updated.method = method
                        updated.seconds = method.seconds
                        updated.intensity = method == .shake ? "Vigorous" : "Gentle"
                        change(updated)
                    }
                )) {
                    ForEach(PreparationMethod.allCases) { method in
                        Text(method.rawValue).tag(method)
                    }
                }
                Text(step.method.guidance).font(.subheadline).foregroundStyle(.secondary)
                if step.method.isTimed {
                    HStack {
                        Text("Suggested: \(Int(step.method.seconds)) sec").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("Reset duration") {
                            var updated = step
                            updated.seconds = step.method.seconds
                            change(updated)
                        }
                        .font(.caption).frame(minHeight: 44)
                    }
                    RemixChoicePicker(title: "Intensity", selection: binding(\.intensity), choices: ["Gentle", "Moderate", "Vigorous"])
                }
                if step.method.isTimed || step.method == .serve {
                    RemixChoicePicker(title: "Ice", selection: binding(\.ice), choices: ["Cubed ice", "Crushed ice", "Large cube", "No ice"])
                }
                if step.method == .strain {
                    RemixChoicePicker(title: "Straining", selection: binding(\.straining), choices: ["Single strain", "Double strain"])
                }
                if step.method == .serve {
                    RemixChoicePicker(title: "Glass", selection: binding(\.glass), choices: ["Rocks glass", "Highball", "Coupe", "Martini glass"])
                    TextField("Garnish or finishing notes", text: binding(\.garnish))
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Garnish or finishing notes")
                }
                HStack {
                    Button("Move up", systemImage: "arrow.up", action: moveUp)
                        .labelStyle(.iconOnly).disabled(!canMoveUp)
                    Button("Move down", systemImage: "arrow.down", action: moveDown)
                        .labelStyle(.iconOnly).disabled(!canMoveDown)
                    Spacer()
                    Button("Remove", systemImage: "minus.circle", role: .destructive, action: remove)
                }
                .frame(minHeight: 44)
            }
        }
        .remixCard()
    }

    private func binding<Value>(_ path: WritableKeyPath<RemixPreparationStep, Value>) -> Binding<Value> {
        Binding(get: { step[keyPath: path] }, set: { value in
            var updated = step
            updated[keyPath: path] = value
            change(updated)
        })
    }
}

private struct RemixMiniDurationKnob: View {
    @Binding var value: Double
    @State private var dragStart: Double?
    @State private var preview: Double?
    private var displayed: Double { preview ?? value }

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                Circle().trim(from: 0, to: 0.75)
                    .stroke(.white.opacity(0.15), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(135))
                Circle().trim(from: 0, to: (displayed - 5) / 115 * 0.75)
                    .stroke(.cyan, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(135))
                Circle().fill(
                    LinearGradient(colors: [Color(white: 0.3), Color(white: 0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .padding(6)
                Capsule().fill(.cyan).frame(width: 2, height: 8).offset(y: -12)
                    .rotationEffect(.degrees(-135 + (displayed - 5) / 115 * 270))
            }
            .frame(width: 48, height: 48)
            Text("\(Int(displayed)) s").font(.caption2.monospacedDigit()).foregroundStyle(.cyan)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 3)
                .onChanged { event in
                    if dragStart == nil { dragStart = value }
                    preview = min(120, max(5, (dragStart ?? value) - Double(event.translation.height))).rounded()
                }
                .onEnded { _ in
                    if let preview { value = preview }
                    preview = nil
                    dragStart = nil
                }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Preparation duration")
        .accessibilityValue("\(Int(displayed)) seconds")
        .accessibilityHint("Drag up or down, or swipe to adjust.")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(120, value + 1)
            case .decrement: value = max(5, value - 1)
            @unknown default: break
            }
        }
    }
}

private struct RemixChoicePicker: View {
    let title: String
    @Binding var selection: String
    let choices: [String]

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(choices, id: \.self) { choice in Text(choice).tag(choice) }
        }
        .pickerStyle(.menu)
        .frame(minHeight: 44)
    }
}

private struct RemixSaveBar: View {
    let recipe: RemixRecipe
    let comparing: Bool
    let disabled: Bool
    let save: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Circle().fill(comparing ? .white : .red).frame(width: 6, height: 6)
                Text(comparing ? "A / ORIGINAL" : "SESSION / YOUR REMIX")
                    .font(.caption2.monospaced().bold())
                Spacer(minLength: 0)
                Button("Save", systemImage: "record.circle", action: save)
                    .font(.subheadline.weight(.semibold)).tint(.red).disabled(disabled)
            }
            .frame(minHeight: 32)
            HStack(spacing: 12) {
                ForEach(["Sweet", "Sour", "Bitter", "Strong"], id: \.self) { name in
                    RemixIslandMeter(name: name, level: recipe.estimate(name))
                }
                Text("EST.").font(.caption2.monospaced()).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.black, in: RoundedRectangle(cornerRadius: 26))
        .overlay {
            RoundedRectangle(cornerRadius: 26)
                .strokeBorder(Color.white.opacity(0.15))
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: recipe)
        .padding(.horizontal, 12).padding(.vertical, 6)
    }
}

private struct RemixIslandMeter: View {
    let name: String
    let level: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name).font(.caption2).foregroundStyle(.secondary)
            HStack(spacing: 2) {
                ForEach(0..<10) { index in
                    let lit = level >= Double(index + 1) / 10
                    RoundedRectangle(cornerRadius: 1)
                        .fill(lit ? Color(hue: 0.5 - Double(index) / 9 * 0.43, saturation: 0.8, brightness: 0.95) : Color.white.opacity(0.1))
                        .frame(height: 9)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name), estimated")
        .accessibilityValue("\(Int(level * 100)) out of 100")
    }
}

private struct RemixIngredientPicker: View {
    @Environment(\.dismiss) private var dismiss
    let isSwapping: Bool
    let select: (String, Double, String) -> Void
    @State private var search = ""
    @State private var customName = ""
    @State private var customUnit = "ml"
    private let catalog = ["Tequila", "Gin", "Vodka", "White rum", "Whisky", "Mezcal", "Lime juice", "Lemon juice", "Orange liqueur", "Blue curaçao", "Simple syrup", "Agave syrup", "Honey syrup", "Soda water", "Tonic", "Ginger beer", "Mint", "Cucumber", "Ice"]

    var body: some View {
        NavigationStack {
            List {
                Section("Choose an ingredient") {
                    ForEach(catalog.filter { search.isEmpty || $0.localizedCaseInsensitiveContains(search) }, id: \.self) { name in
                        Button(name) {
                            let unit = name == "Mint" ? "leaves" : name == "Cucumber" ? "slices" : name == "Ice" ? "cubes" : "ml"
                            select(name, unit == "ml" ? 20 : 3, unit)
                        }
                    }
                }
                Section("Try something else") {
                    TextField("Ingredient name", text: $customName)
                    RemixChoicePicker(title: "Unit", selection: $customUnit, choices: ["ml", "leaves", "slices", "dashes", "cubes", "portion"])
                    Button("Use custom ingredient") {
                        select(customName.trimmingCharacters(in: .whitespacesAndNewlines), customUnit == "ml" ? 20 : 1, customUnit)
                    }
                    .disabled(customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .searchable(text: $search)
            .navigationTitle(isSwapping ? "Swap ingredient" : "Add ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        .tint(.cyan).preferredColorScheme(.dark)
    }
}

private struct RemixSaveSheet: View {
    @Environment(\.dismiss) private var dismiss
    let recipe: RemixRecipe
    let original: RemixRecipe
    let parentLabel: String
    let canCreateVariation: Bool
    let initialName: String
    let save: (String, String, Bool) throws -> Void
    @State private var name = ""
    @State private var separateIdea = false
    @State private var message = ""
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    RemixSaveName(name: $name)
                    RemixSavePlan(parentLabel: parentLabel, canCreateVariation: canCreateVariation, separateIdea: $separateIdea, message: $message)
                    RemixSaveChanges(recipe: recipe, original: original)
                    Text("Save now, make it when you’re ready. You can rate the taste after you’ve tried it.")
                        .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 8)
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(red: 0.035, green: 0.055, blue: 0.075))
            .navigationTitle("Save remix").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save remix") {
                        do {
                            try save(
                                name.trimmingCharacters(in: .whitespacesAndNewlines),
                                message.trimmingCharacters(in: .whitespacesAndNewlines),
                                separateIdea
                            )
                        } catch { saveError = error.localizedDescription }
                    }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if name.isEmpty { name = initialName }
            }
            .alert("Remix not saved", isPresented: Binding(
                get: { saveError != nil }, set: { if !$0 { saveError = nil } }
            )) {
                Button("OK") { saveError = nil }
            } message: { Text(saveError ?? "") }
        }
        .preferredColorScheme(.dark).tint(.cyan)
    }
}

private struct RemixSavePlan: View {
    let parentLabel: String
    let canCreateVariation: Bool
    @Binding var separateIdea: Bool
    @Binding var message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Your earlier recipes stay safe", systemImage: "clock.arrow.circlepath")
                .font(.subheadline.weight(.semibold)).foregroundStyle(.cyan)
            Text("Based on \(parentLabel.lowercased()). Saving keeps this recipe alongside your earlier versions.")
                .font(.caption).foregroundStyle(.secondary)
            if canCreateVariation {
                Toggle("Keep this as a separate idea", isOn: $separateIdea)
                    .font(.subheadline)
            }
            TextField("Add a note, e.g. less lime (optional)", text: $message, axis: .vertical)
                .lineLimit(2...4).accessibilityLabel("Note about this remix, optional")
        }
        .padding(16)
        .modifier(RemixIslandSurface())
    }
}

private struct RemixSaveName: View {
    @Binding var name: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("NAME YOUR DRINK", systemImage: "record.circle")
                .font(.caption.monospaced().bold()).foregroundStyle(.cyan)
            TextField("Remix name", text: $name)
                .font(.title3.weight(.semibold))
                .padding(.vertical, 8)
                .accessibilityLabel("Remix name")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
                    .modifier(RemixIslandSurface())
    }
}

private struct RemixSaveChanges: View {
    let recipe: RemixRecipe
    let original: RemixRecipe

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("YOUR CHANGES").font(.caption.monospaced().bold()).foregroundStyle(.secondary)
            ForEach(recipe.ingredients) { ingredient in
                let baseline = original.ingredients.first { $0.id == ingredient.id }
                if baseline != ingredient {
                    HStack {
                        Circle().fill(RemixChannelStyle.tint(for: ingredient.name)).frame(width: 6, height: 6)
                        Text(ingredient.name)
                        Spacer()
                        Text(ingredient.quantity).monospacedDigit().foregroundStyle(.cyan)
                    }
                }
            }
            ForEach(original.ingredients) { ingredient in
                if !recipe.ingredients.contains(where: { $0.id == ingredient.id }) {
                    Label("Removed \(ingredient.name)", systemImage: "minus.circle")
                        .foregroundStyle(.secondary)
                }
            }
            if recipe.steps != original.steps {
                Text("Preparation: \(recipe.steps.map { $0.method.rawValue }.joined(separator: " → "))")
            }
            if recipe == original { Text("Same recipe — saved so you can return to it later.") }
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
                    .modifier(RemixIslandSurface())
    }
}

private struct RemixIslandSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.black, in: RoundedRectangle(cornerRadius: 26))
            .overlay {
                RoundedRectangle(cornerRadius: 26)
                    .strokeBorder(Color.white.opacity(0.15))
                    .allowsHitTesting(false)
            }
    }
}

private extension View {
    func remixCard() -> some View {
        padding(16)
            .background(
                LinearGradient(colors: [Color(white: 0.105), Color(white: 0.065)], startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.white.opacity(0.09), lineWidth: 1)
            }
    }
}

#Preview("Remix workspace") {
    NavigationStack {
        MixerView(mix: MockData.newMix)
    }
}
