import SwiftUI

struct ProviderSettingsView: View {
    @StateObject private var store = ProviderSettingsStore()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            VStack(alignment: .leading, spacing: 14) {
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
            }

            if let statusMessage = store.statusMessage {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: store.isStatusError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(store.isStatusError ? .orange : .green)

                    Text(statusMessage)
                        .font(.callout)
                        .foregroundStyle(store.isStatusError ? .primary : .secondary)
                        .textSelection(.enabled)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
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
        .padding(24)
        .frame(width: 560)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "network")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.tint)

                Text("LLM Provider")
                    .font(.title2.bold())
            }

            Text("Configure an OpenAI-compatible endpoint. API Keys are stored only in macOS Keychain.")
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

    private var apiKeyPlaceholder: String {
        store.hasSavedAPIKey ? "Leave blank to keep saved Keychain API Key" : "sk-..."
    }

    private var apiKeyHelpText: String {
        store.hasSavedAPIKey
            ? "A Keychain API Key is saved. Enter a new key to replace it."
            : "The API Key is never saved to UserDefaults, project files, or logs."
    }
}

struct ProviderSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ProviderSettingsView()
    }
}
