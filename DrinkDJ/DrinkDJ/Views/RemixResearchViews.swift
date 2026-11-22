import SwiftUI
import UniformTypeIdentifiers

extension RemixVersion {
    var userFacingLabel: String { "Version \(number)" }
}

private extension TasteDimension {
    var ratingTitle: String {
        switch self {
        case .sweet: "Sweetness"
        case .sour: "Sourness"
        case .bitter: "Bitterness"
        case .strong: "Strength"
        }
    }

    func ratingChoice(_ perception: TastePerception) -> String {
        switch perception {
        case .notRated: return "Skip"
        case .justRight: return "Just right"
        case .tooLittle:
            switch self {
            case .sweet: return "Not sweet enough"
            case .sour: return "Not sour enough"
            case .bitter: return "Not bitter enough"
            case .strong: return "Too weak"
            }
        case .tooMuch:
            switch self {
            case .sweet: return "Too sweet"
            case .sour: return "Too sour"
            case .bitter: return "Too bitter"
            case .strong: return "Too strong"
            }
        }
    }
}

struct RemixSavedConfirmation: View {
    let version: RemixVersion
    let rate: () -> Void
    let keepMixing: () -> Void
    let seeVersions: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.largeTitle).foregroundStyle(.cyan)
                        Text("Your remix is saved").font(.title.bold())
                        Text(version.name).font(.headline)
                        Text("\(version.userFacingLabel) · Earlier recipes are kept too.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(.black, in: RoundedRectangle(cornerRadius: 26))
                    .overlay { RoundedRectangle(cornerRadius: 26).strokeBorder(.white.opacity(0.15)) }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Have you tried this drink yet?").font(.title3.bold())
                        Text("Rate it after you’ve made it. Your rating helps improve your future matches.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Button(action: rate) {
                            Label("I’ve tasted it — add a rating", systemImage: "star.bubble")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.borderedProminent).foregroundStyle(.black)
                        Button(action: keepMixing) {
                            Text("Not yet — keep mixing").frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                    }
                    Button(action: seeVersions) {
                        Label("See saved recipes", systemImage: "clock.arrow.circlepath")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
                .padding(20)
            }
            .background(Color(red: 0.035, green: 0.055, blue: 0.075))
            .navigationTitle("Saved").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done", action: keepMixing) }
            }
        }
        .preferredColorScheme(.dark).tint(.cyan)
    }
}

struct RemixSessionControls: View {
    let match: Int?
    let version: String
    let modified: Bool
    let canUndo: Bool
    let canGiveFeedback: Bool
    let showMatch: () -> Void
    let showPreferences: () -> Void
    let showHistory: () -> Void
    let showFeedback: () -> Void
    let undo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: showMatch) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(match.map { "\($0)% match" } ?? "Add ingredients").font(.subheadline.bold())
                    Text("Estimated for your tastes").font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            Button("Preferences", systemImage: "slider.horizontal.3", action: showPreferences)
                .labelStyle(.iconOnly).frame(minWidth: 32, minHeight: 44)
            Button(action: showHistory) {
                VStack(spacing: 2) {
                    Image(systemName: "clock.arrow.circlepath")
                    Text(modified ? "Unsaved edits" : "Saved recipes").font(.caption2)
                }
                .frame(minWidth: 40, minHeight: 44)
            }
            .accessibilityLabel("Saved recipes. \(version)\(modified ? ", with unsaved changes" : "")")
            Button(action: showFeedback) {
                VStack(spacing: 2) {
                    Image(systemName: "star.bubble")
                    Text("Rate taste").font(.caption2)
                }
                .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("Rate a drink you’ve made")
            .disabled(!canGiveFeedback)
            if canUndo {
                Button("Undo", systemImage: "arrow.uturn.backward", action: undo)
                    .labelStyle(.iconOnly).frame(minWidth: 32, minHeight: 44)
            }
        }
        .tint(.cyan)
    }
}

struct RemixMatchSheet: View {
    @Environment(\.dismiss) private var dismiss
    let recipe: RemixRecipe
    let preferences: TastePreferences
    let editPreferences: () -> Void

    var body: some View {
        let match = RemixMatch.estimate(recipe: recipe, preferences: preferences)
        NavigationStack {
            List {
                Section {
                    Text("\(match.percent)% estimated match").font(.title2.bold()).foregroundStyle(.cyan)
                    Text("A fit estimate from your saved tastes and ingredient proportions. It is not a measured taste rating.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Section("Recipe estimate / your preference") {
                    ForEach(TasteDimension.allCases) { dimension in
                        HStack {
                            Text(dimension.rawValue)
                            Spacer()
                            Text("\(Int(recipe.estimate(dimension.rawValue) * 100)) / \(Int(preferences.target(dimension) * 100))")
                                .monospacedDigit().foregroundStyle(.secondary)
                        }
                    }
                }
                Section("How it works") {
                    Text("Taste fit: \(match.tastePercent)%")
                    if match.favoritesPercent != nil {
                        Text("Taste balance contributes 85%. Including one of your favorite spirits or ingredients contributes 15%.")
                    } else {
                        Text("With no favorites selected, the score uses taste balance only.")
                    }
                    Text("Only Sweet, Sour, Bitter, and Strong are estimated right now. Brand, dilution, preparation, and other flavor characteristics are not modeled.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Button("Edit my preferences", systemImage: "slider.horizontal.3", action: editPreferences)
            }
            .navigationTitle("Your match").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .tint(.cyan).preferredColorScheme(.dark)
    }
}

struct RemixPreferencesSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PreferencesView()
                .navigationTitle("Your tastes").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .preferredColorScheme(.dark).tint(.cyan)
    }
}

enum RemixDiff {
    static func lines(from original: RemixRecipe, to recipe: RemixRecipe) -> [String] {
        var lines: [String] = []
        for ingredient in recipe.ingredients {
            if let previous = original.ingredients.first(where: { $0.id == ingredient.id }) {
                if previous.name != ingredient.name {
                    lines.append("\(previous.name) → \(ingredient.name), \(ingredient.quantity)")
                } else if previous != ingredient {
                    lines.append("\(ingredient.name): \(previous.quantity) → \(ingredient.quantity)")
                }
            } else {
                lines.append("Added \(ingredient.name), \(ingredient.quantity)")
            }
        }
        for ingredient in original.ingredients where !recipe.ingredients.contains(where: { $0.id == ingredient.id }) {
            lines.append("Removed \(ingredient.name)")
        }
        if recipe.steps != original.steps {
            for (index, step) in recipe.steps.enumerated() {
                lines.append("Step \(index + 1): \(step.method.rawValue) · \(step.summary)")
            }
            if recipe.steps.isEmpty { lines.append("Removed preparation steps") }
        }
        return lines
    }
}

struct RemixHistorySheet: View {
    @Environment(\.dismiss) private var dismiss
    let store: RemixStore
    let source: String
    let currentVersionID: UUID?
    let canTaste: Bool
    let tasteCurrent: () -> Void
    let checkout: (RemixVersion) -> Void
    let restoreDraft: (RemixWorkingCopy) -> Void
    @State private var showAll = false
    @State private var exportDocument: RemixExportDocument?
    @State private var showsExport = false
    @State private var exportError: String?

    private var versions: [RemixVersion] {
        showAll ? store.archive.versions.sorted { $0.date > $1.date } : store.versions(for: source)
    }

    private var backups: [RemixDraftBackup] {
        store.archive.draftBackups.filter { showAll || $0.copy.recipe.source == source }.reversed()
    }

    private var feedback: [TastingFeedback] {
        store.archive.feedback.filter { showAll || $0.recipe.source == source }.reversed()
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("I’ve tasted it — add a rating", systemImage: "bubble.left.and.text.bubble.right", action: tasteCurrent)
                        .disabled(!canTaste)
                    Toggle("Show all drinks", isOn: $showAll)
                    Text("Open an earlier recipe to try another idea. Your other saved versions stay available, and any current edits are kept for you.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Saved recipes") {
                    if versions.isEmpty { Text("Tap Save in the mixer to keep your first recipe.").foregroundStyle(.secondary) }
                    ForEach(versions) { version in
                        RemixVersionRow(
                            version: version,
                            parent: store.version(version.parentID),
                            current: currentVersionID == version.id,
                            checkout: { checkout(version) }
                        )
                    }
                }
                if !backups.isEmpty {
                    Section("Edits kept for you") {
                        ForEach(backups) { draft in
                            Button { restoreDraft(draft.copy) } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(draft.copy.recipe.source).font(.headline)
                                    Text(draft.date, format: .dateTime.day().month().hour().minute())
                                        .font(.caption).foregroundStyle(.secondary)
                                    Text("Continue these edits").font(.caption)
                                }
                            }
                        }
                    }
                }
                Section("Your taste ratings") {
                    if feedback.isEmpty { Text("After you make a drink, add a rating to remember what you liked.").foregroundStyle(.secondary) }
                    ForEach(feedback) { item in
                        VStack(alignment: .leading, spacing: 5) {
                            Text("\(item.rating)/5 · \(store.version(item.revisionID)?.userFacingLabel ?? "Recipe you were editing")").font(.headline)
                            Text(item.date, format: .dateTime.day().month().hour().minute()).font(.caption).foregroundStyle(.secondary)
                            ForEach(item.assessments) { assessment in
                                if assessment.perception != .notRated {
                                    Text("\(assessment.dimension.rawValue): \(assessment.perception.rawValue)").font(.caption)
                                }
                            }
                            if !item.notes.isEmpty { Text(item.notes).font(.subheadline) }
                            Text(item.learned ? "Used to improve your matches" : "Your taste preferences stayed the same").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Section {
                    DisclosureGroup("Data export") {
                        Button("Export data (JSON)", systemImage: "square.and.arrow.up") {
                        do {
                            exportDocument = RemixExportDocument(data: try store.exportData())
                            showsExport = true
                        } catch { exportError = error.localizedDescription }
                    }
                    Text("Exports this device’s anonymous participant ID, preferences, version ancestry, recipe snapshots, tasting feedback, and drafts. Nothing is uploaded automatically.")
                        .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Saved recipes").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .fileExporter(
                isPresented: $showsExport, document: exportDocument,
                contentType: .json, defaultFilename: "DrinkDJ-feedback"
            ) { result in
                if case .failure(let error) = result { exportError = error.localizedDescription }
            }
            .alert("Export unavailable", isPresented: Binding(
                get: { exportError != nil }, set: { if !$0 { exportError = nil } }
            )) {
                Button("OK") { exportError = nil }
            } message: { Text(exportError ?? "") }
        }
        .tint(.cyan).preferredColorScheme(.dark)
    }
}

private struct RemixVersionRow: View {
    let version: RemixVersion
    let parent: RemixVersion?
    let current: Bool
    let checkout: () -> Void

    var body: some View {
        DisclosureGroup {
            Text(version.message.isEmpty ? "No change note" : version.message).font(.subheadline)
            ForEach(version.recipe.ingredients) { ingredient in
                LabeledContent(ingredient.name, value: ingredient.quantity).font(.caption)
            }
            let changes = RemixDiff.lines(from: parent?.recipe ?? version.original, to: version.recipe)
            ForEach(changes, id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
            Text("\(version.estimatedMatch)% estimated match when saved").font(.caption).foregroundStyle(.secondary)
            Button(current ? "Start again from this recipe" : "Open this recipe", systemImage: "arrow.uturn.backward", action: checkout)
                .padding(.vertical, 8)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "bookmark").foregroundStyle(.cyan)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 4) {
                    Text(version.userFacingLabel + (current ? " · In your mixer" : "")).font(.caption.monospaced().bold()).foregroundStyle(.cyan)
                    Text(version.name).font(.headline)
                    Text(parent.map { "Based on version \($0.number)" } ?? "Based on the original recipe")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(version.date, format: .dateTime.day().month().hour().minute())
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct RemixExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct RemixFeedbackSheet: View {
    @Environment(\.dismiss) private var dismiss
    let store: RemixStore
    let copy: RemixWorkingCopy
    let applySuggestion: (RemixRecipe) -> Void
    @State private var rating = 0
    @State private var assessments = TasteDimension.allCases.map { TasteAssessment(dimension: $0) }
    @State private var notes = ""
    @State private var tasted = false
    @State private var learn = true
    @State private var recorded: TastingFeedback?
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            Form {
                if let recorded {
                    RemixFeedbackResult(feedback: recorded, apply: applySuggestion)
                } else {
                    Section {
                        Text(copy.recipe.source).font(.headline)
                        Text("Tell us how this recipe tasted. Your rating helps you remember what worked and find drinks you’ll enjoy.")
                            .font(.caption).foregroundStyle(.secondary)
                        Toggle("I’ve made and tasted this drink", isOn: $tasted)
                    }
                    Section("1. How did you like it?") {
                        HStack {
                            ForEach(1...5, id: \.self) { value in
                                Button { rating = value } label: {
                                    Image(systemName: value <= rating ? "star.fill" : "star")
                                        .font(.title2).frame(maxWidth: .infinity, minHeight: 44)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(value) out of 5 stars")
                                .accessibilityAddTraits(value == rating ? .isSelected : [])
                            }
                        }
                    }
                    Section("2. Anything to change? (optional)") {
                        ForEach($assessments) { $assessment in
                            Picker(assessment.dimension.ratingTitle, selection: $assessment.perception) {
                                ForEach(TastePerception.allCases) { perception in
                                    Text(assessment.dimension.ratingChoice(perception)).tag(perception)
                                }
                            }
                        }
                    }
                    Section("Anything else? (optional)") {
                        TextField("What would you keep or change?", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                            .onChange(of: notes) { _, value in if value.count > 2000 { notes = String(value.prefix(2000)) } }
                    }
                    Section {
                        Toggle("Use this rating to improve my matches", isOn: $learn)
                        Text("Gradually learns what you enjoy. Your saved recipe stays the same.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(recorded == nil ? "Rate your drink" : "Rating saved")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(recorded == nil ? "Cancel" : "Done") { dismiss() } }
                if recorded == nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save rating") {
                            do {
                                recorded = try store.recordTasting(
                                    copy: copy, rating: rating, assessments: assessments,
                                    notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                                    tasted: tasted, learn: learn
                                )
                            } catch { saveError = error.localizedDescription }
                        }
                        .disabled(!tasted || rating == 0)
                    }
                }
            }
            .alert("Rating not saved", isPresented: Binding(
                get: { saveError != nil }, set: { if !$0 { saveError = nil } }
            )) {
                Button("OK") { saveError = nil }
            } message: { Text(saveError ?? "") }
        }
        .tint(.cyan).preferredColorScheme(.dark)
    }
}

private struct RemixFeedbackResult: View {
    let feedback: TastingFeedback
    let apply: (RemixRecipe) -> Void

    var body: some View {
        let suggestion = RemixSuggestion.recipe(after: feedback)
        Section {
            Label("Your rating is saved", systemImage: "checkmark.circle.fill").foregroundStyle(.cyan)
            Text(feedback.learned ? "We’ve learned a little more about your taste for future matches." : "Your taste preferences stayed the same.")
            Text("You can find this rating with your saved recipes.")
                .font(.caption).foregroundStyle(.secondary)
        }
        if suggestion != feedback.recipe {
            Section("Want to try a small tweak?") {
                ForEach(RemixDiff.lines(from: feedback.recipe, to: suggestion), id: \.self) { Text($0) }
                Button("Try this adjustment", systemImage: "slider.horizontal.3") { apply(suggestion) }
                Text("Opens the adjusted recipe in your mixer. Your saved recipe stays safe. Save it again if you like the change.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        } else {
            Section {
                Text("Keep mixing, or come back after your next try to add another rating.")
            }
        }
    }
}
