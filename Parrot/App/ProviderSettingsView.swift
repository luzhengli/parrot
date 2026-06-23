import SwiftUI

struct ProviderSettingsView: View {
    enum Section: String, CaseIterable, Identifiable {
        case model = "Model"
        case shortcuts = "Shortcuts"
        case translation = "Translation"
        case privacy = "Privacy"

        var id: String { rawValue }
    }

    @StateObject private var store = ProviderSettingsStore()
    @StateObject private var shortcutStore = ShortcutSettingsStore()
    @ObservedObject private var historyStore = TranslationHistoryStore.shared
    @State private var selectedSection: Section = .model
    @State private var translationStyle = TranslationStyle.loadSaved()

    let onShortcutsSaved: () -> Void

    init(onShortcutsSaved: @escaping () -> Void = {}) {
        self.onShortcutsSaved = onShortcutsSaved
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
        .frame(width: 600)
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
        }
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

    private var apiKeyPlaceholder: String {
        store.hasSavedAPIKey ? "Leave blank to keep saved Keychain API Key" : "sk-..."
    }

    private var apiKeyHelpText: String {
        store.hasSavedAPIKey
            ? "A Keychain API Key is saved. Enter a new key to replace it if macOS asks for Keychain access during debugging."
            : "The API Key is saved only to Keychain. Parrot keeps only a non-secret setup flag in UserDefaults."
    }
}

struct ProviderSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ProviderSettingsView()
    }
}
