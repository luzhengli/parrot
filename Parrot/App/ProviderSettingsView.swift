import AppKit
import SwiftUI

struct ProviderSettingsView: View {
    private static let translationSectionHeight: CGFloat = 660
    static let settingsContentWidth: CGFloat = 980

    enum Section: String, CaseIterable, Identifiable {
        case general = "General"
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
            case .general:
                return 480
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
            case .general:
                return "switch.2"
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

        var title: String {
            switch self {
            case .general:
                return AppLocalization.string("settings.section.general")
            case .setup:
                return AppLocalization.string("settings.section.setup")
            case .launch:
                return AppLocalization.string("settings.section.launch")
            case .model:
                return AppLocalization.string("settings.section.model")
            case .shortcuts:
                return AppLocalization.string("settings.section.shortcuts")
            case .translation:
                return AppLocalization.string("settings.section.translation")
            case .privacy:
                return AppLocalization.string("settings.section.privacy")
            case .about:
                return AppLocalization.string("settings.section.about")
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
    @State private var appLanguage = AppLanguagePreference.loadSaved()
    @State private var appLanguageStatusMessage: String?

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
            ParrotWindowTitleBar(title: AppLocalization.string("window.settings.title"), height: 52) {
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

                Text(AppLocalization.string("settings.sidebar.subtitle"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, 46)
            .padding(.trailing, 16)
            .padding(.top, 28)
            .padding(.bottom, 16)

            VStack(alignment: .leading, spacing: 6) {
                sidebarAction(title: AppLocalization.string("launch_hub.quick_text.title"), systemImageName: "text.cursor", action: onOpenQuickText)
                sidebarAction(title: AppLocalization.string("launch_hub.screenshot.title"), systemImageName: "text.viewfinder", action: onOpenScreenshot)
                sidebarAction(title: AppLocalization.string("launch_hub.history.title"), systemImageName: "clock.arrow.circlepath", action: onOpenHistory)
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
        Label(AppLocalization.string("window.settings.title"), systemImage: "gearshape")
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
            Text(section.title)
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
        case .general:
            generalSettings
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

    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            ParrotSurfaceHeader(
                systemImageName: "switch.2",
                title: AppLocalization.string("settings.general.title"),
                subtitle: AppLocalization.string("settings.general.subtitle"),
                iconSize: 44
            )

            SettingsFormRow(AppLocalization.string("settings.language.title"), alignment: .top, labelTopPadding: 4) {
                VStack(alignment: .leading, spacing: 8) {
                    Picker(AppLocalization.string("settings.language.title"), selection: appLanguageBinding) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(AppLocalization.string(language.pickerTitleKey)).tag(language)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 320)

                    Text(AppLocalization.string("settings.language.description"))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let appLanguageStatusMessage {
                ParrotStatusBanner(
                    kind: .info,
                    message: appLanguageStatusMessage
                )
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: 650, alignment: .leading)
    }

    private var setupChecklist: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                onboardingGuide

                Divider()

                ParrotStatusBanner(
                    kind: .info,
                    title: AppLocalization.string("settings.setup.health.title"),
                    message: AppLocalization.string("settings.setup.health.message")
                )

                setupChecklistRow(
                    title: AppLocalization.string("settings.setup.api_key.title"),
                    detail: store.hasSavedAPIKey
                        ? AppLocalization.string("settings.setup.api_key.ready")
                        : AppLocalization.string("settings.setup.api_key.missing"),
                    isPassing: store.hasSavedAPIKey,
                    actionTitle: AppLocalization.string("common.configure"),
                    action: { selectedSection = .model }
                )

                setupChecklistRow(
                    title: AppLocalization.string("settings.setup.endpoint.title"),
                    detail: providerEndpointIsValid
                        ? AppLocalization.string("settings.setup.endpoint.ready")
                        : AppLocalization.string("settings.setup.endpoint.missing"),
                    isPassing: providerEndpointIsValid,
                    actionTitle: AppLocalization.string("settings.section.model"),
                    action: { selectedSection = .model }
                )

                setupChecklistRow(
                    title: AppLocalization.string("settings.setup.connection.title"),
                    detail: store.statusMessage ?? AppLocalization.string("settings.setup.connection.detail"),
                    isPassing: connectionTestSucceeded,
                    actionTitle: store.isTesting ? nil : AppLocalization.string("settings.model.test_connection"),
                    action: {
                        Task {
                            await store.testConnection()
                        }
                    }
                )

                setupChecklistRow(
                    title: AppLocalization.string("settings.setup.shortcuts.title"),
                    detail: AppLocalization.format(
                        "settings.setup.shortcuts.detail",
                        shortcutStore.preferences[.quickTextTranslation].displayString,
                        shortcutStore.preferences[.screenshotTranslation].displayString,
                        shortcutStore.preferences[.openSettings].displayString
                    ),
                    isPassing: shortcutStore.validationMessages.isEmpty,
                    actionTitle: AppLocalization.string("settings.section.shortcuts"),
                    action: { selectedSection = .shortcuts }
                )

                setupChecklistRow(
                    title: AppLocalization.string("settings.setup.screen_recording.title"),
                    detail: screenRecordingPermissionGranted
                        ? AppLocalization.string("settings.setup.screen_recording.ready")
                        : AppLocalization.string("settings.setup.screen_recording.missing"),
                    isPassing: screenRecordingPermissionGranted,
                    actionTitle: AppLocalization.string("settings.setup.open_system_settings"),
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
                title: AppLocalization.string("settings.launch.startup.title"),
                message: AppLocalization.string("settings.launch.startup.message")
            )

            VStack(alignment: .leading, spacing: 12) {
                Toggle(AppLocalization.string("settings.launch.show_hub"), isOn: launchHubStartupBinding)

                Text(launchHubPreferences.showOnStartup
                     ? AppLocalization.string("settings.launch.hub_on")
                     : AppLocalization.string("settings.launch.hub_off"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .parrotPanel(fill: Color(nsColor: .controlBackgroundColor).opacity(0.45))

            VStack(alignment: .leading, spacing: 12) {
                Toggle(AppLocalization.string("settings.launch.show_dock"), isOn: dockIconBinding)

                Text(dockIconPreferences.showDockIcon
                     ? AppLocalization.string("settings.launch.dock_on")
                     : AppLocalization.string("settings.launch.dock_off"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .parrotPanel(fill: Color(nsColor: .controlBackgroundColor).opacity(0.45))

            VStack(alignment: .leading, spacing: 10) {
                Text(AppLocalization.string("settings.launch.entry_points"))
                    .font(.headline)

                launchInfoRow(
                    systemImageName: "text.cursor",
                    title: AppLocalization.string("launch_hub.quick_text.title"),
                    message: shortcutStore.preferences[.quickTextTranslation].displayString
                )
                launchInfoRow(
                    systemImageName: "text.viewfinder",
                    title: AppLocalization.string("launch_hub.screenshot.title"),
                    message: shortcutStore.preferences[.screenshotTranslation].displayString
                )
                launchInfoRow(
                    systemImageName: "gearshape",
                    title: AppLocalization.string("window.settings.title"),
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
                    Label(AppLocalization.string("settings.launch.open_hub"), systemImage: "rectangle.on.rectangle")
                }

                Button(AppLocalization.string("settings.launch.reset_startup")) {
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
                title: AppLocalization.string("settings.onboarding.title"),
                message: onboardingGuideMessage
            )

            HStack(spacing: 8) {
                Label(AppLocalization.format("settings.onboarding.status", onboardingState.status.displayName), systemImage: "flag")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(AppLocalization.format("settings.onboarding.schema", ParrotOnboardingState.currentSchemaVersion))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            onboardingStepRow(
                number: 1,
                title: AppLocalization.string("settings.onboarding.step.welcome.title"),
                detail: AppLocalization.string("settings.onboarding.step.welcome.detail"),
                isPassing: true,
                actionTitle: AppLocalization.string("settings.about.privacy.title"),
                action: { selectedSection = .about }
            )

            onboardingStepRow(
                number: 2,
                title: AppLocalization.string("settings.onboarding.step.provider.title"),
                detail: providerReadyForTranslation
                    ? AppLocalization.string("settings.onboarding.step.provider.ready")
                    : AppLocalization.string("settings.onboarding.step.provider.missing"),
                isPassing: providerReadyForTranslation,
                actionTitle: AppLocalization.string("common.configure"),
                action: { selectedSection = .model }
            )

            onboardingStepRow(
                number: 3,
                title: AppLocalization.string("settings.onboarding.step.test.title"),
                detail: connectionTestSucceeded
                    ? AppLocalization.string("settings.onboarding.step.test.ready")
                    : AppLocalization.string("settings.onboarding.step.test.missing"),
                isPassing: connectionTestSucceeded,
                actionTitle: store.isTesting ? nil : AppLocalization.string("common.test"),
                action: {
                    Task {
                        await store.testConnection()
                    }
                }
            )

            onboardingStepRow(
                number: 4,
                title: AppLocalization.string("settings.onboarding.step.shortcuts.title"),
                detail: AppLocalization.format(
                    "settings.setup.shortcuts.detail",
                    shortcutStore.preferences[.quickTextTranslation].displayString,
                    shortcutStore.preferences[.screenshotTranslation].displayString,
                    shortcutStore.preferences[.openSettings].displayString
                ),
                isPassing: shortcutStore.validationMessages.isEmpty,
                actionTitle: AppLocalization.string("common.review"),
                action: { selectedSection = .shortcuts }
            )

            onboardingStepRow(
                number: 5,
                title: AppLocalization.string("settings.onboarding.step.first.title"),
                detail: AppLocalization.string("settings.onboarding.step.first.detail"),
                isPassing: providerReadyForTranslation,
                actionTitle: AppLocalization.string("launch_hub.quick_text.title"),
                action: onOpenQuickText
            )

            onboardingStepRow(
                number: 6,
                title: AppLocalization.string("settings.onboarding.step.ocr.title"),
                detail: screenRecordingPermissionGranted
                    ? AppLocalization.string("settings.onboarding.step.ocr.ready")
                    : AppLocalization.string("settings.onboarding.step.ocr.missing"),
                isPassing: screenRecordingPermissionGranted,
                isOptional: true,
                actionTitle: AppLocalization.string("settings.setup.open_system_settings"),
                action: openScreenRecordingSettings
            )

            if let onboardingStatusMessage {
                StatusMessageView(message: onboardingStatusMessage, isError: false)
            }

            HStack(spacing: 8) {
                Button(AppLocalization.string("settings.onboarding.mark_complete")) {
                    markOnboardingComplete()
                }
                .disabled(!providerReadyForTranslation)

                Button(AppLocalization.string("settings.onboarding.skip")) {
                    skipOnboarding()
                }

                if onboardingState.status != .notStarted {
                    Button(AppLocalization.string("settings.onboarding.reset")) {
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
                        Text(AppLocalization.string("common.optional"))
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

                SettingsFormRow(AppLocalization.string("settings.model.provider")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Picker(AppLocalization.string("settings.model.provider"), selection: providerSelection) {
                            ForEach(LLMProviderPreset.presets) { preset in
                                Text(preset.displayName).tag(preset.id)
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

                SettingsFormRow(AppLocalization.string("settings.model.base_url")) {
                    TextField(store.selectedPreset.baseURLString, text: $store.baseURLString)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity)
                }

                SettingsFormRow(AppLocalization.string("settings.model.model")) {
                    TextField(store.selectedPreset.modelName, text: $store.modelName)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity)
                }

                SettingsFormRow(AppLocalization.string("settings.model.timeout")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Stepper(
                            AppLocalization.format("settings.model.timeout.seconds", Int(store.requestTimeoutSeconds.rounded())),
                            value: timeoutBinding,
                            in: ProviderTimeoutPreference.minimumRequestTimeoutSeconds...ProviderTimeoutPreference.maximumRequestTimeoutSeconds,
                            step: 5
                        )
                        .controlSize(.small)

                        Text(AppLocalization.string("settings.model.timeout.help"))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                SettingsFormRow(AppLocalization.string("settings.model.api_key"), alignment: .top, labelTopPadding: 7) {
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
                Button(AppLocalization.string("common.save")) {
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
                        Text(AppLocalization.string("settings.model.test_connection"))
                    }
                }
                .disabled(store.isTesting)

                Spacer()

                Button(AppLocalization.string("settings.model.delete_api_key"), role: .destructive) {
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
            title: AppLocalization.string("settings.model.api_key_required.title"),
            message: AppLocalization.string("settings.model.api_key_required.message")
        )
    }

    private var historySettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(AppLocalization.string("settings.privacy.save_history"), isOn: historyEnabledBinding)

            ParrotStatusBanner(
                kind: .info,
                message: historyStore.isHistoryEnabled
                    ? AppLocalization.string("settings.privacy.history_on")
                    : AppLocalization.string("settings.privacy.history_off")
            )
        }
    }

    private var aboutSettings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Parrot")
                        .font(.title3.weight(.semibold))

                    Text(AppLocalization.string("settings.about.subtitle"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 10) {
                    settingsInfoRow(AppLocalization.string("settings.about.version"), value: appVersion)
                    settingsInfoRow(AppLocalization.string("settings.about.build"), value: buildNumber)
                    settingsInfoRow(AppLocalization.string("settings.about.bundle_id"), value: bundleIdentifier)
                    settingsInfoRow(AppLocalization.string("settings.about.requires"), value: ParrotAboutInfo.macOSRequirementDisplayName)
                    settingsInfoRow(AppLocalization.string("settings.about.release_channel"), value: ParrotAboutInfo.releaseChannelDisplayName)
                }
                .padding(12)
                .parrotPanel(fill: Color(nsColor: .controlBackgroundColor).opacity(0.45))

                ParrotStatusBanner(
                    kind: .warning,
                    title: AppLocalization.string("settings.about.unsigned.title"),
                    message: AppLocalization.string("settings.about.unsigned.message")
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
                            Label(AppLocalization.string("settings.about.check_updates"), systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                    .disabled(updateChecker.status == .checking)

                    Button {
                        openReleaseNotes()
                    } label: {
                        Label(AppLocalization.string("settings.about.updates.open_notes"), systemImage: "doc.text")
                    }

                    Button {
                        copyDiagnosticsSummary()
                    } label: {
                        Label(AppLocalization.string("settings.about.copy_diagnostics"), systemImage: "doc.on.doc")
                    }

                    Button {
                        sendFeedback()
                    } label: {
                        Label(AppLocalization.string("settings.about.send_feedback"), systemImage: "bubble.left.and.bubble.right")
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
            Text(AppLocalization.string("settings.about.privacy.title"))
                .font(.headline)

            privacySummaryRow(
                systemImageName: "key.fill",
                title: AppLocalization.string("settings.about.privacy.keychain.title"),
                message: AppLocalization.string("settings.about.privacy.keychain.message")
            )
            privacySummaryRow(
                systemImageName: "text.viewfinder",
                title: AppLocalization.string("settings.about.privacy.ocr.title"),
                message: AppLocalization.string("settings.about.privacy.ocr.message")
            )
            privacySummaryRow(
                systemImageName: "paperplane",
                title: AppLocalization.string("settings.about.privacy.text.title"),
                message: AppLocalization.string("settings.about.privacy.text.message")
            )
            privacySummaryRow(
                systemImageName: "clock.arrow.circlepath",
                title: AppLocalization.string("settings.about.privacy.history.title"),
                message: AppLocalization.string("settings.about.privacy.history.message")
            )
        }
        .padding(12)
        .parrotPanel(fill: Color(nsColor: .controlBackgroundColor).opacity(0.45))
    }

    private var updateCheckSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Text(AppLocalization.string("settings.about.updates.title"))
                    .font(.headline)

                Spacer()

                Button {
                    checkForUpdates()
                } label: {
                    if updateChecker.status == .checking {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label(AppLocalization.string("common.check"), systemImage: "arrow.triangle.2.circlepath")
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
            Text(AppLocalization.string("settings.about.updates.idle"))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        case .checking:
            ParrotStatusBanner(
                kind: .progress,
                title: AppLocalization.string("settings.about.updates.checking.title"),
                message: AppLocalization.string("settings.about.updates.checking.message")
            )
        case .upToDate(let message):
            ParrotStatusBanner(
                kind: .success,
                title: AppLocalization.string("settings.about.updates.up_to_date"),
                message: message
            )
        case .unableToCheck(let message):
            ParrotStatusBanner(
                kind: .error,
                title: AppLocalization.string("settings.about.updates.unable"),
                message: message
            )
        case .updateAvailable(let release, let message):
            VStack(alignment: .leading, spacing: 10) {
                ParrotStatusBanner(
                    kind: .info,
                    title: AppLocalization.string("settings.about.updates.available"),
                    message: message
                )

                HStack(spacing: 8) {
                    Button {
                        NSWorkspace.shared.open(release.releaseNotesURL)
                    } label: {
                        Label(AppLocalization.string("settings.about.updates.open_notes"), systemImage: "doc.text")
                    }

                    Button {
                        downloadAndOpenUpdate(release)
                    } label: {
                        if case .downloading = updateDownloader.status {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label(AppLocalization.string("settings.about.updates.download_open"), systemImage: "arrow.down.circle")
                        }
                    }
                    .disabled(isUpdateDownloading)

                    Button {
                        copyUpdateVersionInfo()
                    } label: {
                        Label(AppLocalization.string("settings.about.updates.copy_version"), systemImage: "doc.on.doc")
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
                title: AppLocalization.string("settings.about.updates.downloading.title"),
                message: AppLocalization.format("settings.about.updates.downloading.message", fileName)
            )
        case .downloaded(let fileName, let fileURL):
            ParrotStatusBanner(
                kind: .success,
                title: AppLocalization.string("settings.about.updates.downloaded.title"),
                message: AppLocalization.format(
                    "settings.about.updates.downloaded.message",
                    fileName,
                    fileURL.deletingLastPathComponent().path
                )
            )
        case .unableToDownload(let message):
            ParrotStatusBanner(
                kind: .error,
                title: AppLocalization.string("settings.about.updates.download_failed"),
                message: message
            )
        }
    }

    private var diagnosticsSummarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppLocalization.string("settings.about.diagnostics.title"))
                .font(.headline)

            Text(AppLocalization.string("settings.about.diagnostics.description"))
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
                LabeledContent(AppLocalization.string("settings.translation.style")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Picker(AppLocalization.string("settings.translation.style_picker"), selection: translationStyleBinding) {
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

                Text(AppLocalization.string("settings.translation.style_help"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()

                floatingWindowPositionSettings

                Divider()

                LabeledContent(AppLocalization.string("settings.translation.default_prompt")) {
                    VStack(alignment: .leading, spacing: 6) {
                        TextEditor(text: .constant(TranslationPromptPreferences.defaultPromptTemplate))
                            .font(.system(.caption, design: .monospaced))
                            .frame(minHeight: 180)
                            .scrollContentBackground(.hidden)
                            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                            .disabled(true)

                        Text(AppLocalization.string("settings.translation.default_prompt_help"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Toggle(AppLocalization.string("settings.translation.enable_custom_prompt"), isOn: $promptPreferences.isCustomPromptEnabled)

                if promptPreferences.isCustomPromptEnabled {
                    LabeledContent(AppLocalization.string("settings.translation.custom_prompt")) {
                        VStack(alignment: .leading, spacing: 6) {
                            TextEditor(text: $promptPreferences.customPromptTemplate)
                                .font(.system(.caption, design: .monospaced))
                                .frame(minHeight: 160)
                                .scrollContentBackground(.hidden)
                                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))

                            Text(AppLocalization.format(
                                "settings.translation.prompt_variables",
                                TranslationPromptPreferences.supportedVariables.joined(separator: ", ")
                            ))
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
                    Button(AppLocalization.string("settings.translation.save_prompt")) {
                        savePromptPreferences()
                    }
                    .disabled(promptValidationMessage != nil)

                    Button(AppLocalization.string("common.restore_default")) {
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
                Text(AppLocalization.string("settings.translation.floating.title"))
                    .font(.headline)

                Text(hasSavedFloatingWindowPositionPreference
                     ? AppLocalization.string("settings.translation.floating.saved")
                     : AppLocalization.string("settings.translation.floating.default"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            LabeledContent(AppLocalization.string("settings.translation.floating.position")) {
                VStack(alignment: .leading, spacing: 6) {
                    Picker(AppLocalization.string("settings.translation.floating.window_position"), selection: floatingWindowPositionBinding) {
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
                Button(AppLocalization.string("settings.translation.floating.save_choice")) {
                    saveFloatingWindowPositionPreference(floatingWindowPositionPreference)
                }

                Button(AppLocalization.string("settings.translation.floating.restore")) {
                    restoreFloatingWindowDefaults()
                }

                Spacer()
            }
        }
    }

    private var glossarySettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(AppLocalization.string("settings.translation.glossary.title"))
                    .font(.headline)

                Text(AppLocalization.string("settings.translation.glossary.description"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            glossaryEditor

            if let statusMessage = glossaryStore.statusMessage {
                StatusMessageView(message: statusMessage, isError: glossaryStore.isStatusError)
            }

            TextField(AppLocalization.string("settings.translation.glossary.search"), text: $glossarySearchText)
                .textFieldStyle(.roundedBorder)

            let visibleEntries = glossaryStore.filteredEntries(searchText: glossarySearchText)
            if visibleEntries.isEmpty {
                ParrotEmptyState(
                    systemImageName: glossarySearchText.isEmpty ? "text.book.closed" : "magnifyingglass",
                    title: glossarySearchText.isEmpty
                        ? AppLocalization.string("settings.translation.glossary.empty.title")
                        : AppLocalization.string("settings.translation.glossary.empty_search.title"),
                    message: glossarySearchText.isEmpty
                        ? AppLocalization.string("settings.translation.glossary.empty.message")
                        : AppLocalization.string("settings.translation.glossary.empty_search.message")
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
                    Text(AppLocalization.string("settings.translation.glossary.source_term"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Parrot", text: $glossaryDraft.sourceTerm)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(AppLocalization.string("settings.translation.glossary.target_term"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Parrot", text: $glossaryDraft.targetTerm)
                        .textFieldStyle(.roundedBorder)
                }
            }

            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppLocalization.string("settings.translation.glossary.target_language"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker(AppLocalization.string("settings.translation.glossary.target_language"), selection: glossaryTargetLanguageBinding) {
                        Text(AppLocalization.string("settings.translation.glossary.any")).tag("")
                        ForEach(TranslationLanguage.allCases) { language in
                            Text(language.displayName).tag(language.rawValue)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 150, alignment: .leading)
                }

                Toggle(AppLocalization.string("common.enabled"), isOn: $glossaryDraft.isEnabled)
                    .padding(.top, 22)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(AppLocalization.string("settings.translation.glossary.context"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField(AppLocalization.string("settings.translation.glossary.context_placeholder"), text: $glossaryDraft.context)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Button(editingGlossaryID == nil
                       ? AppLocalization.string("settings.translation.glossary.add")
                       : AppLocalization.string("settings.translation.glossary.save")) {
                    saveGlossaryDraft()
                }

                if editingGlossaryID != nil {
                    Button(AppLocalization.string("common.cancel")) {
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
                Text(AppLocalization.string("window.settings.title"))
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(AppLocalization.string("settings.header.subtitle"))
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
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? AppLocalization.string("common.unknown")
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? AppLocalization.string("common.unknown")
    }

    private var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? AppLocalization.string("common.unknown")
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
        aboutStatusMessage = AppLocalization.string("settings.about.status.diagnostics_copied")
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
        aboutStatusMessage = AppLocalization.string("settings.about.status.version_copied")
    }

    private func openReleaseNotes() {
        NSWorkspace.shared.open(ParrotAboutInfo.releaseNotesURL)
        aboutStatusMessage = AppLocalization.string("settings.about.status.release_notes_opened")
    }

    private func sendFeedback() {
        NSWorkspace.shared.open(ParrotAboutInfo.feedbackURL)
        aboutStatusMessage = AppLocalization.string("settings.about.status.feedback_opened")
    }

    private func markOnboardingComplete() {
        onboardingState = ParrotOnboardingState.markCompleted()
        onboardingStatusMessage = AppLocalization.string("settings.onboarding.completed_status")
    }

    private func skipOnboarding() {
        onboardingState = ParrotOnboardingState.markSkipped()
        onboardingStatusMessage = AppLocalization.string("settings.onboarding.skipped_status")
    }

    private func resetOnboarding() {
        onboardingState = ParrotOnboardingState.reset()
        onboardingStatusMessage = AppLocalization.string("settings.onboarding.reset_status")
    }

    private func setLaunchHubStartupEnabled(_ isEnabled: Bool) {
        launchHubPreferences = ParrotLaunchHubPreferences.setShowOnStartup(isEnabled)
        launchStatusMessage = isEnabled
            ? AppLocalization.string("settings.launch.status.hub_on")
            : AppLocalization.string("settings.launch.status.hub_off")
    }

    private func setDockIconVisible(_ isVisible: Bool) {
        dockIconPreferences = ParrotDockIconPreferences.setShowDockIcon(isVisible)
        onDockIconVisibilityChanged(isVisible)
        launchStatusMessage = isVisible
            ? AppLocalization.string("settings.launch.status.dock_on")
            : AppLocalization.string("settings.launch.status.dock_off")
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
        store.didTestConnectionSucceed
    }

    private var onboardingGuideMessage: String {
        switch onboardingState.status {
        case .notStarted:
            return AppLocalization.string("settings.onboarding.not_started")
        case .skipped:
            return AppLocalization.string("settings.onboarding.skipped")
        case .completed:
            return AppLocalization.string("settings.onboarding.completed")
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

    private var appLanguageBinding: Binding<AppLanguage> {
        Binding(
            get: { appLanguage },
            set: { newValue in
                appLanguage = newValue
                AppLanguagePreference.save(newValue)
                appLanguageStatusMessage = AppLocalization.string(
                    "settings.language.restart_notice",
                    language: newValue
                )
            }
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
                ? AppLocalization.string("settings.translation.prompt_saved")
                : AppLocalization.string("settings.translation.prompt_disabled")
            isPromptStatusError = false
        } catch {
            promptStatusMessage = error.userFacingMessage
            isPromptStatusError = true
        }
    }

    private func restoreDefaultPrompt() {
        TranslationPromptPreferences.restoreDefault()
        promptPreferences = .defaults
        promptStatusMessage = AppLocalization.string("settings.translation.prompt_restored")
        isPromptStatusError = false
    }

    private func saveFloatingWindowPositionPreference(_ preference: FloatingWindowPositionPreference) {
        preference.save()
        hasSavedFloatingWindowPositionPreference = true
        floatingWindowPositionStatusMessage = AppLocalization.format("settings.translation.floating.saved_status", preference.displayName)
    }

    private func restoreFloatingWindowDefaults() {
        FloatingWindowPositionPreference.clearSavedPreference()
        floatingWindowPositionPreference = FloatingWindowPositionPreference.loadSaved()
        hasSavedFloatingWindowPositionPreference = false
        floatingWindowPositionStatusMessage = AppLocalization.string("settings.translation.floating.restored_status")
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
        store.hasSavedAPIKey
            ? AppLocalization.string("settings.model.api_key.placeholder.saved")
            : AppLocalization.string("settings.model.api_key.placeholder.empty")
    }

    private var apiKeyHelpText: String {
        store.hasSavedAPIKey
            ? AppLocalization.string("settings.model.api_key.help.saved")
            : AppLocalization.string("settings.model.api_key.help.empty")
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

                Toggle(AppLocalization.string("common.enabled"), isOn: enabledBinding)
                    .labelsHidden()
            }

            HStack(spacing: 8) {
                Text(entry.targetLanguage?.displayName ?? AppLocalization.string("settings.translation.glossary.any_target"))
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
                Button(AppLocalization.string("common.edit"), action: onEdit)
                Button(AppLocalization.string("common.delete"), role: .destructive, action: onDelete)
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
