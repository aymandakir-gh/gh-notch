import ServiceManagement
import SwiftUI

/// The app's Settings window (⌘,), tabbed since v0.4:
/// General (launch/displays/behavior) · AI (the command bar's backend — the
/// differentiator, form unchanged) · Features (section toggles).
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
            AISettingsView()
                .tabItem { Label("AI", systemImage: "sparkles") }
            FeaturesSettingsView()
                .tabItem { Label("Features", systemImage: "switch.2") }
        }
        .frame(width: 460, height: 400)
    }
}

// MARK: - General

struct GeneralSettingsView: View {
    @Bindable private var settings = AppSettingsStore.shared
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var launchAtLoginError: String?
    @State private var widthOverrideEnabled = AppSettingsStore.shared.notchWidthOverride != nil

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        applyLaunchAtLogin(enabled)
                    }
                if let launchAtLoginError {
                    Text(launchAtLoginError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section("Displays") {
                Picker("Show the notch on", selection: $settings.showOnDisplays) {
                    ForEach(ShowOnDisplays.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
            }

            Section("Behavior") {
                Toggle("Blend collapsed bar with the menu bar", isOn: $settings.blendCollapsed)
                Text("Off draws the island even when collapsed.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                LabeledContent("Hover delay") {
                    Slider(value: $settings.hoverDwell, in: 0.0...0.5, step: 0.05) {
                        Text("Hover delay")
                    } minimumValueLabel: {
                        Text("0s")
                    } maximumValueLabel: {
                        Text("0.5s")
                    }
                    .frame(width: 200)
                }
                Text(String(format: "Expands after %.2fs of hovering the notch.", settings.hoverDwell))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Notch width") {
                Toggle("Override automatic width", isOn: $widthOverrideEnabled)
                    .onChange(of: widthOverrideEnabled) { _, enabled in
                        settings.notchWidthOverride = enabled ? (settings.notchWidthOverride ?? 200) : nil
                    }
                if widthOverrideEnabled {
                    LabeledContent("Width") {
                        Slider(
                            value: Binding(
                                get: { settings.notchWidthOverride ?? 200 },
                                set: { settings.notchWidthOverride = $0 }
                            ),
                            in: 150...400,
                            step: 5
                        )
                        .frame(width: 200)
                    }
                    Text(String(format: "%.0f points", settings.notchWidthOverride ?? 200))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = "Could not update login item: \(error.localizedDescription)"
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

// MARK: - AI (the v0.3 form, unchanged behavior)

struct AISettingsView: View {
    @Bindable private var settings = SettingsStore.shared
    @State private var didSave = false

    var body: some View {
        Form {
            Section("AI Endpoint") {
                TextField("Base URL", text: $settings.endpoint.baseURL)
                    .textContentType(.URL)
                TextField("Model", text: $settings.endpoint.model)
                SecureField("API Key (stored in Keychain)", text: $settings.apiKey)

                HStack {
                    Button("OpenAI preset") { applyPreset(.openAI) }
                    Button("Ollama (local) preset") { applyPreset(.ollama) }
                }
                .buttonStyle(.link)
            }

            Section {
                Text("Local commands (math, counts, date) always run on-device. Free-form queries are sent to the endpoint above only when configured.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Button("Save") {
                        settings.save()
                        didSave = true
                    }
                    .keyboardShortcut(.defaultAction)

                    if didSave {
                        Label("Saved", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.footnote)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: settings.endpoint) { didSave = false }
        .onChange(of: settings.apiKey) { didSave = false }
    }

    private func applyPreset(_ preset: AIEndpoint) {
        settings.endpoint = preset
    }
}

// MARK: - Features

struct FeaturesSettingsView: View {
    private var settings = AppSettingsStore.shared

    var body: some View {
        Form {
            Section("Expanded panel sections") {
                ForEach(ExpandedSection.allCases) { section in
                    Toggle(
                        section.displayName,
                        isOn: Binding(
                            get: { !settings.disabledSections.contains(section) },
                            set: { settings.setSection(section, enabled: $0) }
                        )
                    )
                    .disabled(section.isAlwaysOn)
                }
                Text("Clock & Battery stays on — it hosts the Settings gear.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
