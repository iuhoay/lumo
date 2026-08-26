import KeyboardShortcuts
import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var apiKey: String = ""
    @State private var savedNote: Bool = false

    var body: some View {
        ScrollView {
            Form {
                Section("Provider") {
                Picker("Provider", selection: $settings.provider) {
                    ForEach(Provider.allCases) { provider in
                        Text(provider.title).tag(provider)
                    }
                }
                .onChange(of: settings.provider) { _, newValue in
                    // AppSettings already swapped baseURL to the new provider's
                    // own stored value; just refresh the local API-key field.
                    apiKey = settings.apiKey(for: newValue)
                }

                if settings.provider.isOnDevice {
                    // On-device: no key, base URL, or model to configure — just
                    // surface whether the model is ready to run on this Mac.
                    onDeviceStatusRow()
                } else {
                    SecureField("API Key", text: $apiKey)
                        .onChange(of: apiKey) { _, newValue in
                            settings.setAPIKey(newValue, for: settings.provider)
                        }

                    TextField("Base URL", text: $settings.baseURL,
                              prompt: Text(settings.provider.defaultBaseURL))
                    TextField("Model", text: $settings.model,
                              prompt: Text("deepseek-v4-flash"))

                    if settings.provider.supportsThinkingControl {
                        Picker("Thinking", selection: $settings.thinking) {
                            ForEach(ThinkingMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .help(String(localized: "Off disables thinking for Qwen and Ollama hybrid models. Ignored by models that don't support it."))
                    }
                }
            }

                Section {
                LanguageField(title: "Default target", value: $settings.targetLanguage)
                LanguageField(title: "Flip-back language", value: $settings.nativeLanguage)
            } header: {
                Text("Language (translate mode)")
            } footer: {
                Text("Any language translates to the default target. Input already in the default target flips to the flip-back language. The translation window can change the destination for one request without changing these defaults.")
            }

                Section("Shortcuts") {
                // Recording here updates the global hotkey live (AppDelegate
                // registered the handler at launch against the same name).
                // Recorder's title is a plain String, so localize it explicitly
                // via the xcstrings table rather than a LocalizedStringKey literal.
                KeyboardShortcuts.Recorder(String(localized: "New Translation…"), name: .newTranslation)
                KeyboardShortcuts.Recorder(String(localized: "OCR Screen Text…"), name: .ocrScreenText)
            }
            }
            .formStyle(.grouped)
            .frame(width: 460)
        }
        // Scrollable so the window stays usable when the on-device status row
        // or an open "Custom…" language field pushes the form past the frame.
        .frame(width: 460, height: 420)
        .onAppear {
            apiKey = settings.apiKey(for: settings.provider)
        }
    }

    /// Live readiness of the on-device Apple model (queried each render — cheap).
    @ViewBuilder
    private func onDeviceStatusRow() -> some View {
        let status = AppleFoundationModelService.availabilityStatus()
        Label(status.message, systemImage: status.ok ? "checkmark.circle" : "exclamationmark.triangle")
            .foregroundStyle(status.ok ? Color.green : Color.orange)
            .font(.callout)
    }
}
