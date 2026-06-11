import SwiftUI

/// The app's Settings window (⌘,). Configures the AI command bar's backend.
///
/// Endpoint config is saved to `UserDefaults`; the API key goes to the Keychain.
/// Privacy note: nothing is sent anywhere until you configure an endpoint and
/// submit a query the local handlers don't resolve.
struct SettingsView: View {
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
        .frame(width: 440, height: 320)
        .onChange(of: settings.endpoint) { didSave = false }
        .onChange(of: settings.apiKey) { didSave = false }
    }

    private func applyPreset(_ preset: AIEndpoint) {
        settings.endpoint = preset
    }
}
