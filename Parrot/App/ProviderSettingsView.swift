import AppKit
import SwiftUI

struct ProviderSettingsView: View {
    private static let translationSectionHeight: CGFloat = 660
    static let settingsContentWidth: CGFloat = 980

    enum Section: String, CaseIterable, Identifiable {
        case setup = "Setup"
        case model = "Model"
        case shortcuts = "Shortcuts"
        case translation = "Translation"
        case privacy = "Privacy"

        var id: String { rawValue }

        var contentHeight: CGFloat {
            switch self {
            case .setup:
                return 700
            case .model:
                return 700
            case .shortcuts:
                return 740
            case .translation:
                return 900
            case .privacy:
                return 520
            }
        }

        var iconName: String {
            switch self {
            case .setup:
                return "checklist"
            case .model:
                return "cpu"
            case .shortcuts:
                return "keyboard"
            case .translation:
                return "text.bubble"
            case .privacy:
                return "lock.shield"
            }
        }
    }

    @StateObject private var store = ProviderSettingsStore()
    @StateObject private var shortcutStore = ShortcutSettingsStore()
    @StateObject private var glossaryStore = TranslationGlossaryStore.shared
    @ObservedObject private var historyStore = TranslationHistoryStore.shared
    @State private var selectedSection: Section
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
    let onOpenQuickText: () -> Void
    let onOpenScreenshot: () -> Void
    let onOpenHistory: () -> Void

    init(
        initialSection: Section = .model,
        onShortcutsSaved: @escaping () -> Void = {},
        onSectionChanged: @escaping (Section) -> Void = { _ in },
        onOpenQuickText: @escaping () -> Void = {},
        onOpenScreenshot: @escaping () -> Void = {},
        onOpenHistory: @escaping () -> Void = {}
    ) {
        _selectedSection = State(initialValue: initialSection)
        self.onShortcutsSaved = onShortcutsSaved
        self.onSectionChanged = onSectionChanged
        self.onOpenQuickText = onOpenQuickText
        self.onOpenScreenshot = onOpenScreenshot
        self.onOpenHistory = onOpenHistory
    }

    var body: some View {
        VStack(spacing: 0) {
            ParrotWindowTitleBar(title: "Settings", height: 52)

            HStack(spacing: 0) {
                sidebar
                Divider()

                VStack(alignment: .leading, spacing: 28) {
                    header

                    selectedSettingsSection
                }
                .padding(.horizontal, 34)
                .padding(.vertical, 34)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color(nsColor: .windowBackgroundColor))
            }
        }
        .frame(width: Self.settingsContentWidth, height: selectedSection.contentHeight, alignment: .top)
        .onChange(of: selectedSection) { _, newSection in
            onSectionChanged(newSection)
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Parrot")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("Native Translation")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, 46)
            .padding(.trailing, 16)
            .padding(.top, 28)
            .padding(.bottom, 16)

            VStack(alignment: .leading, spacing: 6) {
                sidebarAction(title: "Quick Text", systemImageName: "text.cursor", action: onOpenQuickText)
                sidebarAction(title: "Screenshot", systemImageName: "text.viewfinder", action: onOpenScreenshot)
                sidebarAction(title: "History", systemImageName: "clock.arrow.circlepath", action: onOpenHistory)
            }

            VStack(alignment: .leading, spacing: 5) {
                sidebarSettingsHeader

                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Section.allCases) { section in
                        sidebarSectionButton(section)
                    }
                }
                .padding(.leading, 44)
                .padding(.trailing, 16)
            }

            Spacer(minLength: 0)
        }
        .frame(width: 208, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.36))
    }

    private func sidebarAction(
        title: String,
        systemImageName: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImageName)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title)
    }

    private var sidebarSettingsHeader: some View {
        Label("Settings", systemImage: "gearshape")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
    }

    private func sidebarSectionButton(_ section: Section) -> some View {
        Button {
            selectedSection = section
        } label: {
            Text(section.rawValue)
                .font(.system(size: 13, weight: selectedSection == section ? .semibold : .regular))
                .foregroundStyle(selectedSection == section ? Color.accentColor : Color.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background {
                    if selectedSection == section {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.accentColor.opacity(0.12))
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.trailing, 10)
    }

    @ViewBuilder
    private var selectedSettingsSection: some View {
        switch selectedSection {
        case .setup:
            setupChecklist
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

    private var setupChecklist: some View {
        VStack(alignment: .leading, spacing: 14) {
            ParrotStatusBanner(
                kind: .info,
                title: "Configuration Health",
                message: "Finish the essentials once, then Parrot stays out of the way. Quick Text works without Screen Recording permission."
            )

            setupChecklistRow(
                title: "API Key",
                detail: store.hasSavedAPIKey
                    ? "A non-secret setup record exists and the secret remains in Keychain."
                    : "Save a provider API Key before translating.",
                isPassing: store.hasSavedAPIKey,
                actionTitle: "Configure",
                action: { selectedSection = .model }
            )

            setupChecklistRow(
                title: "Provider Endpoint",
                detail: providerEndpointIsValid
                    ? "Base URL and model look ready for an OpenAI-compatible chat completions request."
                    : "Check the Base URL format and model name.",
                isPassing: providerEndpointIsValid,
                actionTitle: "Review Model",
                action: { selectedSection = .model }
            )

            setupChecklistRow(
                title: "Connection Test",
                detail: store.statusMessage ?? "Use the same endpoint, timeout, model, and API Key path that translation uses.",
                isPassing: store.statusMessage?.localizedCaseInsensitiveContains("succeeded") == true,
                actionTitle: store.isTesting ? nil : "Test Connection",
                action: {
                    Task {
                        await store.testConnection()
                    }
                }
            )

            setupChecklistRow(
                title: "Shortcuts",
                detail: "Quick Text: \(shortcutStore.preferences[.quickTextTranslation].displayString). Screenshot: \(shortcutStore.preferences[.screenshotTranslation].displayString). Settings: \(shortcutStore.preferences[.openSettings].displayString).",
                isPassing: shortcutStore.validationMessages.isEmpty,
                actionTitle: "View Shortcuts",
                action: { selectedSection = .shortcuts }
            )

            setupChecklistRow(
                title: "Screen Recording",
                detail: screenRecordingPermissionGranted
                    ? "Screenshot Translation can capture other apps for local OCR."
                    : "Only Screenshot Translation needs this permission. Quick Text can be used without it.",
                isPassing: screenRecordingPermissionGranted,
                actionTitle: "Open System Settings",
                action: openScreenRecordingSettings
            )

            Spacer(minLength: 0)
        }
        .frame(maxWidth: 650, maxHeight: .infinity, alignment: .topLeading)
    }

    private func setupChecklistRow(
        title: String,
        detail: String,
        isPassing: Bool,
        actionTitle: String?,
        action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isPassing ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isPassing ? Color.green : Color.secondary)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            if let actionTitle {
                Button(actionTitle, action: action)
                    .controlSize(.small)
            }
        }
        .padding(12)
        .parrotPanel(fill: Color(nsColor: .controlBackgroundColor).opacity(0.45))
    }

    private var modelSettings: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 24) {
                if !store.hasSavedAPIKey {
                    setupGuide
                }

                SettingsFormRow("Provider") {
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("Provider", selection: providerSelection) {
                            ForEach(LLMProviderPreset.presets) { preset in
                                Text(preset.name).tag(preset.id)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 420)

                        Text(store.selectedPreset.detail)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }

                SettingsFormRow("Base URL") {
                    TextField(store.selectedPreset.baseURLString, text: $store.baseURLString)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity)
                }

                SettingsFormRow("Model") {
                    TextField(store.selectedPreset.modelName, text: $store.modelName)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity)
                }

                SettingsFormRow("Timeout") {
                    VStack(alignment: .leading, spacing: 6) {
                        Stepper(
                            "\(Int(store.requestTimeoutSeconds.rounded())) seconds",
                            value: timeoutBinding,
                            in: ProviderTimeoutPreference.minimumRequestTimeoutSeconds...ProviderTimeoutPreference.maximumRequestTimeoutSeconds,
                            step: 5
                        )
                        .controlSize(.small)

                        Text("Applies to connection tests, Quick Text, and Screenshot Translation requests. The default is 25 seconds.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                SettingsFormRow("API Key", alignment: .top, labelTopPadding: 7) {
                    VStack(alignment: .leading, spacing: 9) {
                        SecureField(apiKeyPlaceholder, text: $store.apiKeyInput)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: .infinity)

                        Label(apiKeyHelpText, systemImage: "info.circle")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if let statusMessage = store.statusMessage {
                    StatusMessageView(
                        message: statusMessage,
                        isError: store.isStatusError
                    )
                    .padding(.leading, 134)
                }
            }
            .frame(maxWidth: 650, alignment: .leading)

            Spacer(minLength: 24)

            Divider()

            HStack {
                Button("Save") {
                    store.saveSettings()
                }
                .keyboardShortcut("s", modifiers: [.command])
                .frame(minWidth: 80)

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
            .padding(.top, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var setupGuide: some View {
        ParrotStatusBanner(
            kind: .info,
            title: "API Key setup required",
            message: "Save a provider API Key once before translating. Parrot only accesses Keychain when you save, replace, delete, or explicitly test a saved key here; translation windows show in-app setup errors instead of system Keychain password prompts."
        )
    }

    private var historySettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Save translation history", isOn: historyEnabledBinding)

            ParrotStatusBanner(
                kind: .info,
                message: historyStore.isHistoryEnabled
                    ? "Successful translations are saved locally as text records and never include screenshot images or API Keys."
                    : "New translations will not be saved while history is disabled. Existing records remain available until you clear them."
            )
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
                ParrotEmptyState(
                    systemImageName: glossarySearchText.isEmpty ? "text.book.closed" : "magnifyingglass",
                    title: glossarySearchText.isEmpty ? "No glossary entries yet" : "No matching glossary entries",
                    message: glossarySearchText.isEmpty
                        ? "Add source and target terms here. Only matched enabled terms are sent with a translation request."
                        : "Try a different source or target term."
                )
                .frame(height: 150)
                .parrotPanel(fill: Color(nsColor: .controlBackgroundColor).opacity(0.45))
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
        .parrotPanel(fill: Color(nsColor: .controlBackgroundColor).opacity(0.45))
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: "gearshape")
                .font(.system(size: 27, weight: .semibold))
                .foregroundStyle(.tint.opacity(0.86))
                .frame(width: 48, height: 48)
                .background(Color.accentColor.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.accentColor.opacity(0.12), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 6) {
                Text("Settings")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("Configure Model, Shortcuts, Translation, and Privacy for the current Parrot workflows.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var providerSelection: Binding<String> {
        Binding(
            get: { store.selectedProviderID },
            set: { store.selectProvider($0) }
        )
    }

    private var providerEndpointIsValid: Bool {
        (try? ProviderEndpointNormalizer.chatCompletionsURL(from: store.baseURLString)) != nil
            && !store.modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var screenRecordingPermissionGranted: Bool {
        CGPreflightScreenCaptureAccess()
    }

    private var timeoutBinding: Binding<Double> {
        Binding(
            get: { store.requestTimeoutSeconds },
            set: { store.requestTimeoutSeconds = ProviderTimeoutPreference.clamped($0) }
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

    private func openScreenRecordingSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
            ?? URL(fileURLWithPath: "/System/Applications/System Settings.app")
        NSWorkspace.shared.open(url)
    }
}

private struct SettingsFormRow<Content: View>: View {
    let label: String
    var alignment: VerticalAlignment = .center
    var labelTopPadding: CGFloat = 0
    private let content: Content

    init(
        _ label: String,
        alignment: VerticalAlignment = .center,
        labelTopPadding: CGFloat = 0,
        @ViewBuilder content: () -> Content
    ) {
        self.label = label
        self.alignment = alignment
        self.labelTopPadding = labelTopPadding
        self.content = content()
    }

    var body: some View {
        HStack(alignment: alignment, spacing: 20) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 112, alignment: .trailing)
                .padding(.top, labelTopPadding)

            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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
        .parrotPanel(fill: Color(nsColor: .controlBackgroundColor).opacity(0.45))
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
