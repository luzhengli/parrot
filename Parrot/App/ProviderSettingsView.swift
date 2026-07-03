import SwiftUI

struct ProviderSettingsView: View {
    private static let translationSectionHeight: CGFloat = 600
    static let settingsContentWidth: CGFloat = 600

    enum Section: String, CaseIterable, Identifiable {
        case model = "Model"
        case shortcuts = "Shortcuts"
        case translation = "Translation"
        case privacy = "Privacy"

        var id: String { rawValue }

        var contentHeight: CGFloat {
            switch self {
            case .model:
                return 520
            case .shortcuts:
                return 620
            case .translation:
                return 800
            case .privacy:
                return 360
            }
        }
    }

    @StateObject private var store = ProviderSettingsStore()
    @StateObject private var shortcutStore = ShortcutSettingsStore()
    @StateObject private var glossaryStore = TranslationGlossaryStore.shared
    @ObservedObject private var historyStore = TranslationHistoryStore.shared
    @State private var selectedSection: Section = .model
    @State private var translationStyle = TranslationStyle.loadSaved()
    @State private var floatingWindowPositionPreference = FloatingWindowPositionPreference.loadSaved()
    @State private var hasSavedFloatingWindowPositionPreference = FloatingWindowPositionPreference.hasSavedPreference()
    @State private var floatingWindowPositionStatusMessage: String?
    @State private var promptPreferences = TranslationPromptPreferences.loadSaved()
    @State private var promptStatusMessage: String?
    @State private var isPromptStatusError = false
    @State private var glossaryDraft = TranslationGlossaryEntry()
    @State private var editingGlossaryID: UUID?
    @State private var glossarySearchText = ""

    let onShortcutsSaved: () -> Void
    let onSectionChanged: (Section) -> Void

    init(
        onShortcutsSaved: @escaping () -> Void = {},
        onSectionChanged: @escaping (Section) -> Void = { _ in }
    ) {
        self.onShortcutsSaved = onShortcutsSaved
        self.onSectionChanged = onSectionChanged
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            Picker("Settings Section", selection: $selectedSection) {
                ForEach(Section.allCases) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)

            Divider()

            selectedSettingsSection
        }
        .padding(24)
        .frame(width: Self.settingsContentWidth, height: selectedSection.contentHeight, alignment: .top)
        .onChange(of: selectedSection) { newSection in
            onSectionChanged(newSection)
        }
    }

    @ViewBuilder
    private var selectedSettingsSection: some View {
        switch selectedSection {
        case .model:
            modelSettings
        case .shortcuts:
            ShortcutSettingsSection(store: shortcutStore, onSaved: onShortcutsSaved)
        case .translation:
            translationSettings
        case .privacy:
            historySettings
        }
    }

    private var modelSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !store.hasSavedAPIKey {
                setupGuide
            }

            LabeledContent("Provider") {
                VStack(alignment: .leading, spacing: 6) {
                    Picker("Provider", selection: providerSelection) {
                        ForEach(LLMProviderPreset.presets) { preset in
                            Text(preset.name).tag(preset.id)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(minWidth: 320)

                    Text(store.selectedPreset.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            LabeledContent("Base URL") {
                TextField(store.selectedPreset.baseURLString, text: $store.baseURLString)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 320)
            }

            LabeledContent("Model") {
                TextField(store.selectedPreset.modelName, text: $store.modelName)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 320)
            }

            LabeledContent("API Key") {
                VStack(alignment: .leading, spacing: 6) {
                    SecureField(apiKeyPlaceholder, text: $store.apiKeyInput)
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 320)

                    Text(apiKeyHelpText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let statusMessage = store.statusMessage {
                StatusMessageView(
                    message: statusMessage,
                    isError: store.isStatusError
                )
            }

            HStack {
                Button("Save") {
                    store.saveSettings()
                }
                .keyboardShortcut("s", modifiers: [.command])

                Button {
                    Task {
                        await store.testConnection()
                    }
                } label: {
                    if store.isTesting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Test Connection")
                    }
                }
                .disabled(store.isTesting)

                Spacer()

                Button("Delete API Key", role: .destructive) {
                    store.deleteAPIKey()
                }
                .disabled(!store.hasSavedAPIKey)
            }
        }
    }

    private var setupGuide: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "key.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(width: 24, height: 24, alignment: .top)

            VStack(alignment: .leading, spacing: 4) {
                Text("API Key setup required")
                    .font(.headline)

                Text("Save a provider API Key once before translating. Parrot only accesses Keychain when you save, replace, delete, or explicitly test a saved key here; translation windows show in-app setup errors instead of system Keychain password prompts.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var historySettings: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Save translation history", isOn: historyEnabledBinding)

            Text(historyStore.isHistoryEnabled
                 ? "Successful translations are saved locally and never include screenshot images or API Keys."
                 : "New translations will not be saved while history is disabled.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var translationSettings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                LabeledContent("Style") {
                    VStack(alignment: .leading, spacing: 6) {
                        Picker("Translation Style", selection: translationStyleBinding) {
                            ForEach(TranslationStyle.allCases) { style in
                                Text(style.displayName).tag(style)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(minWidth: 360)

                        Text(translationStyle.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Text("Style is applied to Quick Text and Screenshot translation prompts. Use Again or Retry in an open translation window to retranslate with the latest style.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()

                floatingWindowPositionSettings

                Divider()

                LabeledContent("Default Prompt") {
                    VStack(alignment: .leading, spacing: 6) {
                        TextEditor(text: .constant(TranslationPromptPreferences.defaultPromptTemplate))
                            .font(.system(.caption, design: .monospaced))
                            .frame(minHeight: 180)
                            .scrollContentBackground(.hidden)
                            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                            .disabled(true)

                        Text("This is the built-in Prompt structure. Parrot sends source text only to the configured provider during translation.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Toggle("Enable custom Prompt template", isOn: $promptPreferences.isCustomPromptEnabled)

                if promptPreferences.isCustomPromptEnabled {
                    LabeledContent("Custom Prompt") {
                        VStack(alignment: .leading, spacing: 6) {
                            TextEditor(text: $promptPreferences.customPromptTemplate)
                                .font(.system(.caption, design: .monospaced))
                                .frame(minHeight: 160)
                                .scrollContentBackground(.hidden)
                                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))

                            Text("Required variables: {target_language}, {text}. Supported variables: \(TranslationPromptPreferences.supportedVariables.joined(separator: ", ")).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                if let promptValidationMessage {
                    StatusMessageView(message: promptValidationMessage, isError: true)
                } else if let promptStatusMessage {
                    StatusMessageView(message: promptStatusMessage, isError: isPromptStatusError)
                }

                HStack {
                    Button("Save Prompt") {
                        savePromptPreferences()
                    }
                    .disabled(promptValidationMessage != nil)

                    Button("Restore Default") {
                        restoreDefaultPrompt()
                    }

                    Spacer()
                }

                Divider()

                glossarySettings
            }
            .padding(.trailing, 4)
        }
        .frame(height: Self.translationSectionHeight)
    }

    private var floatingWindowPositionSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Floating Windows")
                    .font(.headline)

                Text(hasSavedFloatingWindowPositionPreference
                     ? "Saved placement applies to Quick Text and Screenshot result windows."
                     : "Workflow defaults are active: Quick Text opens centered; Screenshot results open near the selected region when possible.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            LabeledContent("Position") {
                VStack(alignment: .leading, spacing: 6) {
                    Picker("Window Position", selection: floatingWindowPositionBinding) {
                        ForEach(FloatingWindowPositionPreference.allCases) { preference in
                            Text(preference.displayName).tag(preference)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(minWidth: 360)

                    Text(floatingWindowPositionPreference.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let floatingWindowPositionStatusMessage {
                StatusMessageView(message: floatingWindowPositionStatusMessage, isError: false)
            }

            HStack {
                Button("Save Current Choice") {
                    saveFloatingWindowPositionPreference(floatingWindowPositionPreference)
                }

                Button("Restore Workflow Defaults") {
                    restoreFloatingWindowDefaults()
                }

                Spacer()
            }
        }
    }

    private var glossarySettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Terminology Glossary")
                    .font(.headline)

                Text("Entries stay local. During translation, Parrot only sends enabled terms that appear in the current source text and match the target language.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            glossaryEditor

            if let statusMessage = glossaryStore.statusMessage {
                StatusMessageView(message: statusMessage, isError: glossaryStore.isStatusError)
            }

            TextField("Search source or target term", text: $glossarySearchText)
                .textFieldStyle(.roundedBorder)

            let visibleEntries = glossaryStore.filteredEntries(searchText: glossarySearchText)
            if visibleEntries.isEmpty {
                Text(glossarySearchText.isEmpty ? "No glossary entries yet." : "No matching glossary entries.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 18)
            } else {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(visibleEntries) { entry in
                        GlossaryEntryRow(
                            entry: entry,
                            onToggle: { isEnabled in glossaryStore.setEnabled(entry, isEnabled: isEnabled) },
                            onEdit: { beginEditingGlossary(entry) },
                            onDelete: { glossaryStore.delete(entry) }
                        )
                    }
                }
            }
        }
    }

    private var glossaryEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Source Term")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Parrot", text: $glossaryDraft.sourceTerm)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Target Term")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Parrot", text: $glossaryDraft.targetTerm)
                        .textFieldStyle(.roundedBorder)
                }
            }

            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Target Language")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("Target Language", selection: glossaryTargetLanguageBinding) {
                        Text("Any").tag("")
                        ForEach(TranslationLanguage.allCases) { language in
                            Text(language.displayName).tag(language.rawValue)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 150, alignment: .leading)
                }

                Toggle("Enabled", isOn: $glossaryDraft.isEnabled)
                    .padding(.top, 22)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Context")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Optional note, product area, or usage hint", text: $glossaryDraft.context)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Button(editingGlossaryID == nil ? "Add Entry" : "Save Entry") {
                    saveGlossaryDraft()
                }

                if editingGlossaryID != nil {
                    Button("Cancel") {
                        resetGlossaryDraft()
                    }
                }

                Spacer()
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "gearshape")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.tint)

                Text("Settings")
                    .font(.title2.bold())
            }

            Text("Configure Model, Shortcuts, Translation, and Privacy for the current Parrot workflows.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var providerSelection: Binding<String> {
        Binding(
            get: { store.selectedProviderID },
            set: { store.selectProvider($0) }
        )
    }

    private var historyEnabledBinding: Binding<Bool> {
        Binding(
            get: { historyStore.isHistoryEnabled },
            set: { historyStore.setHistoryEnabled($0) }
        )
    }

    private var translationStyleBinding: Binding<TranslationStyle> {
        Binding(
            get: { translationStyle },
            set: { newValue in
                translationStyle = newValue
                newValue.save()
            }
        )
    }

    private var floatingWindowPositionBinding: Binding<FloatingWindowPositionPreference> {
        Binding(
            get: { floatingWindowPositionPreference },
            set: { newValue in
                floatingWindowPositionPreference = newValue
                saveFloatingWindowPositionPreference(newValue)
            }
        )
    }

    private var glossaryTargetLanguageBinding: Binding<String> {
        Binding(
            get: { glossaryDraft.targetLanguage?.rawValue ?? "" },
            set: { rawValue in
                glossaryDraft.targetLanguage = rawValue.isEmpty ? nil : TranslationLanguage(rawValue: rawValue)
            }
        )
    }

    private var promptValidationMessage: String? {
        guard promptPreferences.isCustomPromptEnabled else {
            return nil
        }

        return TranslationPromptPreferences.validationMessage(for: promptPreferences.customPromptTemplate)
    }

    private func savePromptPreferences() {
        do {
            try promptPreferences.save()
            promptStatusMessage = promptPreferences.isCustomPromptEnabled
                ? "Custom Prompt saved. Use Again or Retry in an open translation window to apply it."
                : "Custom Prompt disabled. Translation uses the built-in Prompt."
            isPromptStatusError = false
        } catch {
            promptStatusMessage = error.userFacingMessage
            isPromptStatusError = true
        }
    }

    private func restoreDefaultPrompt() {
        TranslationPromptPreferences.restoreDefault()
        promptPreferences = .defaults
        promptStatusMessage = "Default Prompt restored. Translation uses the built-in Prompt behavior."
        isPromptStatusError = false
    }

    private func saveFloatingWindowPositionPreference(_ preference: FloatingWindowPositionPreference) {
        preference.save()
        hasSavedFloatingWindowPositionPreference = true
        floatingWindowPositionStatusMessage = "\(preference.displayName) saved for translation windows."
    }

    private func restoreFloatingWindowDefaults() {
        FloatingWindowPositionPreference.clearSavedPreference()
        floatingWindowPositionPreference = FloatingWindowPositionPreference.loadSaved()
        hasSavedFloatingWindowPositionPreference = false
        floatingWindowPositionStatusMessage = "Workflow defaults restored."
    }

    private func saveGlossaryDraft() {
        if glossaryStore.save(entry: glossaryDraft, editingID: editingGlossaryID) {
            resetGlossaryDraft()
        }
    }

    private func beginEditingGlossary(_ entry: TranslationGlossaryEntry) {
        glossaryDraft = entry
        editingGlossaryID = entry.id
    }

    private func resetGlossaryDraft() {
        glossaryDraft = TranslationGlossaryEntry()
        editingGlossaryID = nil
    }

    private var apiKeyPlaceholder: String {
        store.hasSavedAPIKey ? "Leave blank to keep saved Keychain API Key" : "sk-..."
    }

    private var apiKeyHelpText: String {
        store.hasSavedAPIKey
            ? "A Keychain API Key is saved. Enter a new key to replace it if macOS asks for Keychain access during debugging."
            : "The API Key is saved only to Keychain. Parrot keeps only a non-secret setup flag in UserDefaults."
    }
}

private struct GlossaryEntryRow: View {
    let entry: TranslationGlossaryEntry
    let onToggle: (Bool) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.sourceTerm)
                    .font(.headline)

                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(entry.targetTerm)
                    .font(.headline)

                Spacer()

                Toggle("Enabled", isOn: enabledBinding)
                    .labelsHidden()
            }

            HStack(spacing: 8) {
                Text(entry.targetLanguage?.displayName ?? "Any target")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !entry.trimmedContext.isEmpty {
                    Text(entry.trimmedContext)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            HStack {
                Button("Edit", action: onEdit)
                Button("Delete", role: .destructive, action: onDelete)
                Spacer()
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { entry.isEnabled },
            set: { onToggle($0) }
        )
    }
}

struct ProviderSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ProviderSettingsView()
    }
}
