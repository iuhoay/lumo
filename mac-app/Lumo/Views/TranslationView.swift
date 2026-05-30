import SwiftUI
import AppKit

/// The contents of the floating translation window.
struct TranslationView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let request = model.request {
                header(for: request)

                HStack {
                    sectionLabel("Original")
                    speakButton(request.text)
                    Spacer()
                }
                ScrollView {
                    Text(request.text)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 110)

                Divider()

                HStack {
                    sectionLabel(request.mode == .summarize ? "Summary" : (request.mode == .polish ? "Polished" : "Translation"))
                    if !model.resolvedTarget.isEmpty, request.mode != .polish {
                        Text("· \(model.resolvedTarget)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    speakButton(model.output, disabled: model.output.isEmpty)
                    Spacer()
                    if model.isLoading { ProgressView().controlSize(.small) }
                }

                resultArea
            } else {
                Text("Waiting for input…").foregroundStyle(.secondary)
            }
        }
        .padding(16)
        // minWidth must fit the header toolbar (fixed-size segmented picker +
        // 5 icon buttons, ~416pt). NSHostingController sizes the window to this
        // minWidth, so anything narrower clips the trailing buttons (retranslate,
        // copy, close) past the rounded-glass mask, making them unclickable.
        .frame(minWidth: 440, maxWidth: .infinity, minHeight: 240, maxHeight: .infinity, alignment: .topLeading)
        // Liquid Glass: the whole popup is a single floating glass slab over the
        // desktop. Controls inside stay flat (borderless) to avoid glass-on-glass.
        .glassEffect(in: RoundedRectangle(cornerRadius: GlassPanelMetrics.cornerRadius, style: .continuous))
    }

    private func header(for request: TranslationRequest) -> some View {
        HStack(spacing: 8) {
            Picker("", selection: Binding(
                get: { request.mode },
                set: { model.setMode($0) }
            )) {
                ForEach(TranslationMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.symbol).tag(mode)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .fixedSize()

            Spacer()

            Button { HistoryWindowController.shared.toggle() } label: {
                Image(systemName: "clock.arrow.circlepath")
            }
            .help("Translation History")

            Button { model.togglePin() } label: {
                Image(systemName: model.isPinned ? "pin.fill" : "pin")
            }
            .help("Pin window")

            Button { model.retranslate() } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Retranslate")
            .disabled(model.isLoading)

            Button { copyOutput() } label: {
                Image(systemName: "doc.on.doc")
            }
            .help("Copy result")
            .disabled(model.output.isEmpty)

            Button { model.dismiss() } label: {
                Image(systemName: "xmark")
            }
            .help("Close (Esc)")
        }
        .buttonStyle(.borderless)
    }

    @ViewBuilder
    private var resultArea: some View {
        ScrollView {
            if let errorText = model.errorText {
                VStack(alignment: .leading, spacing: 8) {
                    Text(errorText)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    // The error (e.g. "No API key set") names Settings; give the
                    // user a way to reach it from the floating panel itself.
                    Button("Open Settings") {
                        SettingsWindowController.shared.present()
                    }
                    .controlSize(.small)
                }
            } else if model.output.isEmpty && model.isLoading {
                Text("Translating…")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(model.output)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func speakButton(_ text: String, disabled: Bool = false) -> some View {
        Button { Speaker.shared.speak(text) } label: {
            Image(systemName: "speaker.wave.2")
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .help("Read aloud")
        .disabled(disabled)
    }

    private func sectionLabel(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func copyOutput() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(model.output, forType: .string)
    }
}
