import AppKit
import SwiftUI

struct ProviderSettingsView: View {
    private static let translationSectionHeight: CGFloat = 660
    static let settingsContentWidth: CGFloat = 980

    enum Section: String, CaseIterable, Identifiable {
        case setup = "Setup"
        case launch = "Launch"
        case model = "Model"
        case shortcuts = "Shortcuts"
        case translation = "Translation"
        case privacy = "Privacy"
        case about = "About"

        var id: String { rawValue }

        var contentHeight: CGFloat {
            switch self {
            case .setup:
                return 820
            case .launch:
                return 560
            case .model:
                return 700
            case .shortcuts:
                return 740
            case .translation:
                return 900
            case .privacy:
                return 520
            case .about:
                return 860
            }
        }

        var iconName: String {
            switch self {
            case .setup:
                return "checklist"
            case .launch:
                return "rectangle.on.rectangle"
            case .model:
                return "cpu"
            case .shortcuts:
                return "keyboard"
            case .translation:
                return "text.bubble"
            case .privacy:
                return "lock.shield"
            case .about:
                return "info.circle"
            }
        }
    }

    @StateObject private var store = ProviderSettingsStore()
    @StateObject private var shortcutStore = ShortcutSettingsStore()
    @StateObject private var glossaryStore = TranslationGlossaryStore.shared
    @StateObject private var updateChecker = ParrotUpdateChecker()
    @StateObject private var updateDownloader = ParrotUpdateDownloader()
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
    @State private var aboutStatusMessage: String?
    @State private var onboardingState = ParrotOnboardingState.load()
    @State private var onboardingStatusMessage: String?
    @State private var launchHubPreferences = ParrotLaunchHubPreferences.load()
    @State private var dockIconPreferences = ParrotDockIconPreferences.load()
    @State private var launchStatusMessage: String?
    @State private var settingsAlwaysOnTop: Bool
    @State private var aboutAlwaysOnTop: Bool

    let onShortcutsSaved: () -> Void
    let onSectionChanged: (Section) -> Void
    let onOpenQuickText: () -> Void
    let onOpenScreenshot: () -> Void
    let onOpenHistory: () -> Void
    let onOpenLaunchHub: () -> Void
    let onDockIconVisibilityChanged: (Bool) -> Void
    let onAlwaysOnTopChanged: (ParrotAlwaysOnTopSurface, Bool) -> Void

    init(
        initialSection: Section = .model,
        onShortcutsSaved: @escaping () -> Void = {},
        onSectionChanged: @escaping (Section) -> Void = { _ in },
        onOpenQuickText: @escaping () -> Void = {},
        onOpenScreenshot: @escaping () -> Void = {},
        onOpenHistory: @escaping () -> Void = {},
        onOpenLaunchHub: @escaping () -> Void = {},
        onDockIconVisibilityChanged: @escaping (Bool) -> Void = { _ in },
        isSettingsAlwaysOnTop: Bool = false,
        isAboutAlwaysOnTop: Bool = false,
        onAlwaysOnTopChanged: @escaping (ParrotAlwaysOnTopSurface, Bool) -> Void = { _, _ in }
    ) {
        _selectedSection = State(initialValue: initialSection)
        _settingsAlwaysOnTop = State(initialValue: isSettingsAlwaysOnTop)
        _aboutAlwaysOnTop = State(initialValue: isAboutAlwaysOnTop)
        self.onShortcutsSaved = onShortcutsSaved
        self.onSectionChanged = onSectionChanged
        self.onOpenQuickText = onOpenQuickText
        self.onOpenScreenshot = onOpenScreenshot
        self.onOpenHistory = onOpenHistory
        self.onOpenLaunchHub = onOpenLaunchHub
        self.onDockIconVisibilityChanged = onDockIconVisibilityChanged
        self.onAlwaysOnTopChanged = onAlwaysOnTopChanged
    }

    var body: some View {
        VStack(spacing: 0) {
            ParrotWindowTitleBar(title: "Settings", height: 52) {
                ParrotAlwaysOnTopButton(
                    surface: activeAlwaysOnTopSurface,
                    isEnabled: activeAlwaysOnTopBinding,
                    onChange: { isEnabled in
                        onAlwaysOnTopChanged(activeAlwaysOnTopSurface, isEnabled)
                    }
                )
            }

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
            let surface = alwaysOnTopSurface(for: newSection)
            onAlwaysOnTopChanged(surface, isAlwaysOnTopEnabled(for: surface))
        }
    }

    private var activeAlwaysOnTopSurface: ParrotAlwaysOnTopSurface {
        alwaysOnTopSurface(for: selectedSection)
    }

    private var activeAlwaysOnTopBinding: Binding<Bool> {
        Binding(
            get: {
                isAlwaysOnTopEnabled(for: activeAlwaysOnTopSurface)
            },
            set: { isEnabled in
                setAlwaysOnTop(isEnabled, for: activeAlwaysOnTopSurface)
            }
        )
    }

    private func alwaysOnTopSurface(for section: Section) -> ParrotAlwaysOnTopSurface {
        section == .about ? .about : .settings
    }

    private func isAlwaysOnTopEnabled(for surface: ParrotAlwaysOnTopSurface) -> Bool {
        surface == .about ? aboutAlwaysOnTop : settingsAlwaysOnTop
    }

    private func setAlwaysOnTop(_ isEnabled: Bool, for surface: ParrotAlwaysOnTopSurface) {
        if surface == .about {
            aboutAlwaysOnTop = isEnabled
        } else {
            settingsAlwaysOnTop = isEnabled
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
        case .launch:
            launchSettings
        case .model:
            modelSettings
        case .shortcuts:
            ShortcutSettingsSection(store: shortcutStore, onSaved: onShortcutsSaved)
        case .translation:
            translationSettings
        case .privacy:
            historySettings
        case .about:
            aboutSettings
        }
    }

    private var setupChecklist: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                onboardingGuide

                Divider()

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
                    isPassing: connectionTestSucceeded,
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
            }
            .frame(maxWidth: 650, alignment: .leading)
            .padding(.trailing, 4)
        }
    }

    private var launchSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            ParrotStatusBanner(
                kind: .info,
                title: "Startup Entry",
                message: "Launch Hub opens after onboarding is complete and provider setup is valid. Invalid setup or onboarding always takes priority."
            )

            VStack(alignment: .leading, spacing: 12) {
                Toggle("Show Launch Hub on Startup", isOn: launchHubStartupBinding)

                Text(launchHubPreferences.showOnStartup
                     ? "Parrot will show Launch Hub on startup when no setup or onboarding window needs attention."
                     : "Parrot will stay quiet on startup unless provider setup or onboarding needs attention.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .parrotPanel(fill: Color(nsColor: .controlBackgroundColor).opacity(0.45))

            VStack(alignment: .leading, spacing: 12) {
                Toggle("Show Dock icon", isOn: dockIconBinding)

                Text(dockIconPreferences.showDockIcon
                     ? "Parrot appears in the Dock and App Switcher. Closing windows keeps Parrot running; use Quit Parrot to exit."
                     : "Parrot stays in menu-bar mode. You can still open it from Launch Hub, the menu bar, or shortcuts.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .parrotPanel(fill: Color(nsColor: .controlBackgroundColor).opacity(0.45))

            VStack(alignment: .leading, spacing: 10) {
                Text("Entry Points")
                    .font(.headline)

                launchInfoRow(
                    systemImageName: "text.cursor",
                    title: "Quick Text",
                    message: shortcutStore.preferences[.quickTextTranslation].displayString
                )
                launchInfoRow(
                    systemImageName: "text.viewfinder",
                    title: "Screenshot OCR",
                    message: shortcutStore.preferences[.screenshotTranslation].displayString
                )
                launchInfoRow(
                    systemImageName: "gearshape",
                    title: "Settings",
                    message: shortcutStore.preferences[.openSettings].displayString
                )
            }
            .padding(12)
            .parrotPanel(fill: Color(nsColor: .controlBackgroundColor).opacity(0.45))

            if let launchStatusMessage {
                StatusMessageView(message: launchStatusMessage, isError: false)
            }

            HStack(spacing: 8) {
                Button {
                    onOpenLaunchHub()
                } label: {
                    Label("Open Launch Hub", systemImage: "rectangle.on.rectangle")
                }

                Button("Reset Startup Display") {
                    setLaunchHubStartupEnabled(true)
                }

                Spacer()
            }
        }
        .frame(maxWidth: 650, alignment: .leading)
    }

    private var onboardingGuide: some View {
        VStack(alignment: .leading, spacing: 12) {
            ParrotStatusBanner(
                kind: onboardingState.status == .completed ? .success : .info,
                title: "Onboarding Guide",
                message: onboardingGuideMessage
            )

            HStack(spacing: 8) {
                Label("Status: \(onboardingState.status.displayName)", systemImage: "flag")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Schema \(ParrotOnboardingState.currentSchemaVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            onboardingStepRow(
                number: 1,
                title: "Welcome",
                detail: "Parrot lives in the menu bar. It translates typed text or locally recognized screenshot text, and it keeps API Keys in Keychain.",
                isPassing: true,
                actionTitle: "Privacy Summary",
                action: { selectedSection = .about }
            )

            onboardingStepRow(
                number: 2,
                title: "Provider",
                detail: providerReadyForTranslation
                    ? "Provider, endpoint, model, and Keychain setup look ready."
                    : "Choose a provider, confirm the HTTPS endpoint and model, then save the API Key to Keychain.",
                isPassing: providerReadyForTranslation,
                actionTitle: "Configure",
                action: { selectedSection = .model }
            )

            onboardingStepRow(
                number: 3,
                title: "Test Connection",
                detail: connectionTestSucceeded
                    ? "The configured provider accepted the test request."
                    : "Run the same connection path used by Quick Text and Screenshot Translation.",
                isPassing: connectionTestSucceeded,
                actionTitle: store.isTesting ? nil : "Test",
                action: {
                    Task {
                        await store.testConnection()
                    }
                }
            )

            onboardingStepRow(
                number: 4,
                title: "Learn Shortcuts",
                detail: "Quick Text: \(shortcutStore.preferences[.quickTextTranslation].displayString). Screenshot: \(shortcutStore.preferences[.screenshotTranslation].displayString). Settings: \(shortcutStore.preferences[.openSettings].displayString).",
                isPassing: shortcutStore.validationMessages.isEmpty,
                actionTitle: "Review",
                action: { selectedSection = .shortcuts }
            )

            onboardingStepRow(
                number: 5,
                title: "First Translation",
                detail: "Open Quick Text, type a short sentence, and translate it. This step does not use Screen Recording.",
                isPassing: providerReadyForTranslation,
                actionTitle: "Open Quick Text",
                action: onOpenQuickText
            )

            onboardingStepRow(
                number: 6,
                title: "Screenshot OCR",
                detail: screenRecordingPermissionGranted
                    ? "Screen Recording is enabled for optional screenshot translation."
                    : "Optional. Screenshot Translation uses Screen Recording only for local capture and OCR; Quick Text still works if you skip it.",
                isPassing: screenRecordingPermissionGranted,
                isOptional: true,
                actionTitle: "Open System Settings",
                action: openScreenRecordingSettings
            )

            if let onboardingStatusMessage {
                StatusMessageView(message: onboardingStatusMessage, isError: false)
            }

            HStack(spacing: 8) {
                Button("Mark Complete") {
                    markOnboardingComplete()
                }
                .disabled(!providerReadyForTranslation)

                Button("Skip for This Version") {
                    skipOnboarding()
                }

                if onboardingState.status != .notStarted {
                    Button("Reset Guide") {
                        resetOnboarding()
                    }
                }

                Spacer()
            }
        }
        .padding(12)
        .parrotPanel(fill: Color(nsColor: .controlBackgroundColor).opacity(0.45))
    }

    private func onboardingStepRow(
        number: Int,
        title: String,
        detail: String,
        isPassing: Bool,
        isOptional: Bool = false,
        actionTitle: String?,
        action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(isPassing ? Color.accentColor.opacity(0.14) : Color(nsColor: .controlBackgroundColor))
                    .overlay {
                        Circle()
                            .strokeBorder(isPassing ? Color.accentColor.opacity(0.35) : Color(nsColor: .separatorColor), lineWidth: 1)
                    }

                if isPassing {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                } else {
                    Text("\(number)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)

                    if isOptional {
                        Text("Optional")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

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

    private var aboutSettings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Parrot")
                        .font(.title3.weight(.semibold))

                    Text("Unsigned release candidate for local macOS translation workflows.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 10) {
                    settingsInfoRow("Version", value: appVersion)
                    settingsInfoRow("Build", value: buildNumber)
                    settingsInfoRow("Bundle ID", value: bundleIdentifier)
                    settingsInfoRow("Requires", value: ParrotAboutInfo.macOSRequirement)
                    settingsInfoRow("Release Channel", value: ParrotAboutInfo.releaseChannel)
                }
                .padding(12)
                .parrotPanel(fill: Color(nsColor: .controlBackgroundColor).opacity(0.45))

                ParrotStatusBanner(
                    kind: .warning,
                    title: "Unsigned RC",
                    message: "This build is not Developer ID signed or notarized. macOS Gatekeeper may require manual approval before launch."
                )

                updateCheckSection

                aboutPrivacySummary

                diagnosticsSummarySection

                if let aboutStatusMessage {
                    StatusMessageView(message: aboutStatusMessage, isError: false)
                }

                HStack(spacing: 8) {
                    Button {
                        checkForUpdates()
                    } label: {
                        if updateChecker.status == .checking {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("Check for Updates", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                    .disabled(updateChecker.status == .checking)

                    Button {
                        openReleaseNotes()
                    } label: {
                        Label("Open Release Notes", systemImage: "doc.text")
                    }

                    Button {
                        copyDiagnosticsSummary()
                    } label: {
                        Label("Copy Diagnostics Summary", systemImage: "doc.on.doc")
                    }

                    Button {
                        sendFeedback()
                    } label: {
                        Label("Send Feedback", systemImage: "bubble.left.and.bubble.right")
                    }

                    Spacer()
                }
            }
            .frame(maxWidth: 650, alignment: .leading)
            .padding(.trailing, 4)
        }
    }

    private var aboutPrivacySummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Privacy Summary")
                .font(.headline)

            privacySummaryRow(
                systemImageName: "key.fill",
                title: "API Key in Keychain",
                message: "Parrot stores API keys only in macOS Keychain and keeps only a non-secret setup record in UserDefaults."
            )
            privacySummaryRow(
                systemImageName: "text.viewfinder",
                title: "Local OCR",
                message: "Screenshot images are processed locally for text recognition and are not saved to history."
            )
            privacySummaryRow(
                systemImageName: "paperplane",
                title: "Recognized text only",
                message: "Only recognized or typed text is sent to the configured provider during translation."
            )
            privacySummaryRow(
                systemImageName: "clock.arrow.circlepath",
                title: "Text-only history",
                message: "History stores local text records only, can be disabled, and can be cleared from Privacy settings."
            )
        }
        .padding(12)
        .parrotPanel(fill: Color(nsColor: .controlBackgroundColor).opacity(0.45))
    }

    private var updateCheckSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Text("Updates")
                    .font(.headline)

                Spacer()

                Button {
                    checkForUpdates()
                } label: {
                    if updateChecker.status == .checking {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Check", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                .disabled(updateChecker.status == .checking)
            }

            updateStatusView
        }
        .padding(12)
        .parrotPanel(fill: Color(nsColor: .controlBackgroundColor).opacity(0.45))
    }

    @ViewBuilder
    private var updateStatusView: some View {
        switch updateChecker.status {
        case .idle:
            Text("Manual update checks use GitHub Releases. Parrot does not send API keys, provider settings, translation text, screenshots, history, or diagnostics.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        case .checking:
            ParrotStatusBanner(
                kind: .progress,
                title: "Checking for Updates",
                message: "Contacting GitHub Releases for the latest Parrot release."
            )
        case .upToDate(let message):
            ParrotStatusBanner(
                kind: .success,
                title: "Up to Date",
                message: message
            )
        case .unableToCheck(let message):
            ParrotStatusBanner(
                kind: .error,
                title: "Unable to Check",
                message: message
            )
        case .updateAvailable(let release, let message):
            VStack(alignment: .leading, spacing: 10) {
                ParrotStatusBanner(
                    kind: .info,
                    title: "Update Available",
                    message: message
                )

                HStack(spacing: 8) {
                    Button {
                        NSWorkspace.shared.open(release.releaseNotesURL)
                    } label: {
                        Label("Open Release Notes", systemImage: "doc.text")
                    }

                    Button {
                        downloadAndOpenUpdate(release)
                    } label: {
                        if case .downloading = updateDownloader.status {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("Download and Open Update", systemImage: "arrow.down.circle")
                        }
                    }
                    .disabled(isUpdateDownloading)

                    Button {
                        copyUpdateVersionInfo()
                    } label: {
                        Label("Copy Version Info", systemImage: "doc.on.doc")
                    }
                }

                updateDownloadStatusView
            }
        }
    }

    private var isUpdateDownloading: Bool {
        if case .downloading = updateDownloader.status {
            return true
        }
        return false
    }

    @ViewBuilder
    private var updateDownloadStatusView: some View {
        switch updateDownloader.status {
        case .idle:
            EmptyView()
        case .downloading(let fileName):
            ParrotStatusBanner(
                kind: .progress,
                title: "Downloading Update",
                message: "Downloading \(fileName) to your Downloads folder."
            )
        case .downloaded(let fileName, let fileURL):
            ParrotStatusBanner(
                kind: .success,
                title: "Update Downloaded",
                message: "\(fileName) was saved to \(fileURL.deletingLastPathComponent().path) and opened with macOS."
            )
        case .unableToDownload(let message):
            ParrotStatusBanner(
                kind: .error,
                title: "Unable to Download",
                message: message
            )
        }
    }

    private var diagnosticsSummarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Diagnostics Summary")
                .font(.headline)

            Text("This summary excludes API keys, endpoint hosts, source text, provider responses, history content, screenshots, window titles, and source app names.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(currentDiagnosticsSummary.text)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .parrotPanel(fill: Color(nsColor: .textBackgroundColor))
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

                Text("Configure Launch, Model, Shortcuts, Translation, Privacy, and release information for the current Parrot workflows.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func settingsInfoRow(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 118, alignment: .trailing)

            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .textSelection(.enabled)

            Spacer(minLength: 0)
        }
    }

    private func privacySummaryRow(
        systemImageName: String,
        title: String,
        message: String
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImageName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 18)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func launchInfoRow(
        systemImageName: String,
        title: String,
        message: String
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: systemImageName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18)

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 12)

            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
    }

    private var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "unknown"
    }

    private var currentDiagnosticsSummary: ParrotDiagnosticsSummary {
        ParrotDiagnosticsSummary.current(
            settings: LLMProviderSettings(
                providerID: store.selectedProviderID,
                baseURLString: store.baseURLString,
                modelName: store.modelName
            ),
            screenRecordingPermissionGranted: screenRecordingPermissionGranted
        )
    }

    private func copyDiagnosticsSummary() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(currentDiagnosticsSummary.text, forType: .string)
        aboutStatusMessage = "Diagnostics summary copied without API keys, endpoints, source text, provider responses, history, or screenshots."
    }

    private func checkForUpdates() {
        aboutStatusMessage = nil
        updateDownloader.reset()
        Task {
            await updateChecker.checkForUpdates(
                currentVersion: appVersion,
                currentBuild: buildNumber
            )
        }
    }

    private func downloadAndOpenUpdate(_ release: ParrotReleaseInfo) {
        aboutStatusMessage = nil
        Task {
            if let fileURL = await updateDownloader.download(release) {
                NSWorkspace.shared.open(fileURL)
            }
        }
    }

    private func copyUpdateVersionInfo() {
        let text = ParrotUpdateChecker.versionInfoText(
            currentVersion: appVersion,
            currentBuild: buildNumber,
            status: updateChecker.status
        )
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        aboutStatusMessage = "Version info copied without API keys, provider settings, user text, history, screenshots, or diagnostics."
    }

    private func openReleaseNotes() {
        NSWorkspace.shared.open(ParrotAboutInfo.releaseNotesURL)
        aboutStatusMessage = "Opened release notes in the browser."
    }

    private func sendFeedback() {
        NSWorkspace.shared.open(ParrotAboutInfo.feedbackURL)
        aboutStatusMessage = "Opened GitHub Issues for feedback."
    }

    private func markOnboardingComplete() {
        onboardingState = ParrotOnboardingState.markCompleted()
        onboardingStatusMessage = "Onboarding marked complete for this version."
    }

    private func skipOnboarding() {
        onboardingState = ParrotOnboardingState.markSkipped()
        onboardingStatusMessage = "Onboarding skipped for this version. You can restart it here later."
    }

    private func resetOnboarding() {
        onboardingState = ParrotOnboardingState.reset()
        onboardingStatusMessage = "Onboarding reset."
    }

    private func setLaunchHubStartupEnabled(_ isEnabled: Bool) {
        launchHubPreferences = ParrotLaunchHubPreferences.setShowOnStartup(isEnabled)
        launchStatusMessage = isEnabled
            ? "Launch Hub will open on startup after setup and onboarding are complete."
            : "Launch Hub startup display is off. Setup and onboarding can still open when needed."
    }

    private func setDockIconVisible(_ isVisible: Bool) {
        dockIconPreferences = ParrotDockIconPreferences.setShowDockIcon(isVisible)
        onDockIconVisibilityChanged(isVisible)
        launchStatusMessage = isVisible
            ? "Dock icon enabled. Parrot now appears in the Dock and App Switcher."
            : "Dock icon hidden. Parrot remains available from Launch Hub, the menu bar, and shortcuts."
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

    private var providerReadyForTranslation: Bool {
        store.hasSavedAPIKey && providerEndpointIsValid
    }

    private var connectionTestSucceeded: Bool {
        store.statusMessage?.localizedCaseInsensitiveContains("succeeded") == true
    }

    private var onboardingGuideMessage: String {
        switch onboardingState.status {
        case .notStarted:
            return "Complete these steps once for this version. You can skip the guide and reopen it from Settings > Setup."
        case .skipped:
            return "Skipped for this version. Parrot will not reopen onboarding automatically unless setup becomes invalid or the onboarding schema changes."
        case .completed:
            return "Complete for this version. Future launches will stay quiet unless setup becomes invalid or a later onboarding schema requires attention."
        }
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

    private var launchHubStartupBinding: Binding<Bool> {
        Binding(
            get: { launchHubPreferences.showOnStartup },
            set: { setLaunchHubStartupEnabled($0) }
        )
    }

    private var dockIconBinding: Binding<Bool> {
        Binding(
            get: { dockIconPreferences.showDockIcon },
            set: { setDockIconVisible($0) }
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
