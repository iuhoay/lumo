import AppKit
import SwiftUI

/// The contents of the floating translation window.
struct TranslationView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject private var speaker = Speaker.shared
    @FocusState private var inputFocused: Bool
    @State private var didCopy = false
    /// Bumped on every copy so the checkmark-reset task restarts even when
    /// `didCopy` is already true (rapid re-copies keep the confirmation fresh).
    @State private var copyToken = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            HStack {
                sectionLabel("Original")
                speakButton(model.inputText)
                Spacer()
            }
            inputField

            HStack {
                Spacer()
                Button("Translate") { model.translate() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(translateDisabled)
                    .help("Translate (⌘↵)")
            }

            Divider()

            HStack {
                sectionLabel(resultLabel)
                if !model.resolvedTarget.isEmpty, model.mode != .polish {
                    Text("· \(model.resolvedTarget)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                speakButton(model.output)
                copyButton
                Spacer()
                if model.isLoading { ProgressView().controlSize(.small) }
            }

            resultArea
        }
        .padding(16)
        // minWidth must fit the header toolbar (fixed-size segmented picker +
        // history/pin/close icons, ~416pt). NSHostingController sizes the window
        // to this minWidth, so anything narrower clips the trailing buttons past
        // the rounded-glass mask, making them unclickable.
        .frame(minWidth: 440, maxWidth: .infinity, minHeight: 300, maxHeight: .infinity, alignment: .topLeading)
        // Liquid Glass: the whole popup is a single floating glass slab over the
        // desktop. Controls inside stay flat (borderless) to avoid glass-on-glass.
        .glassEffect(in: RoundedRectangle(cornerRadius: GlassPanelMetrics.cornerRadius, style: .continuous))
        // Focus the input when the panel first appears and whenever it's reopened
        // (the hosting view is reused, so onAppear alone fires only once). Defer
        // to the next runloop tick: setting @FocusState synchronously during
        // window presentation races AppKit's initial first-responder assignment
        // and loses, leaving the focus ring on a toolbar button instead.
        .onAppear { focusInputSoon() }
        .onChange(of: model.focusInputToken) { _, _ in focusInputSoon() }
    }

    private func focusInputSoon() {
        DispatchQueue.main.async { inputFocused = true }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Picker("", selection: Binding(
                get: { model.mode },
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

            Button { model.dismiss() } label: {
                Image(systemName: "xmark")
            }
            .help("Close (Esc)")
        }
        .buttonStyle(IconButtonStyle())
    }

    /// Editable "Original" field — bare text on the glass (no fill or border), so
    /// it reads as one slab with the result area below rather than a box sitting
    /// on top. TextEditor carries a small built-in text inset; the negative
    /// leading padding pulls it back in line with the surrounding content, and
    /// the placeholder mirrors that inset so it sits exactly where typing begins.
    private var inputField: some View {
        TextEditor(text: $model.inputText)
            .font(.body)
            .scrollContentBackground(.hidden)
            .frame(height: 64)
            .overlay(alignment: .topLeading) {
                if model.inputText.isEmpty {
                    Text("Type or paste text here…")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        // Match TextEditor's text origin: ~5pt leading inset and
                        // a near-zero top inset, so the placeholder sits exactly
                        // where the caret/first line begins (no top padding).
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
            }
            .focused($inputFocused)
            .padding(.leading, -5)
    }

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

    private var translateDisabled: Bool {
        model.isLoading || model.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var resultLabel: LocalizedStringKey {
        switch model.mode {
        case .summarize: return "Summary"
        case .polish: return "Polished"
        case .translate: return "Translation"
        }
    }

    /// Inline result-row glyph at a fixed size. SF Symbols differ in intrinsic
    /// height/width, so without a fixed frame a state swap (copy↔check,
    /// speaker↔stop) changes the row height and nudges its neighbours.
    private func toolbarIcon(_ systemName: String, tint: AnyShapeStyle = AnyShapeStyle(.primary)) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 13))
            .foregroundStyle(tint)
            .frame(width: 18, height: 18)
    }

    private func speakButton(_ text: String) -> some View {
        let isActive = speaker.isSpeaking && speaker.currentText == text
        return Button {
            if isActive { speaker.stop() } else { speaker.speak(text) }
        } label: {
            toolbarIcon(
                isActive ? "stop.fill" : "speaker.wave.2",
                tint: isActive ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary)
            )
        }
        .buttonStyle(IconButtonStyle())
        .help(isActive ? "Stop" : "Read aloud")
        // Disable on whitespace-only too: Speaker.speak trims and no-ops, so an
        // enabled button there would feel broken. Matches translateDisabled.
        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private var copyButton: some View {
        Button { copyOutput() } label: {
            toolbarIcon(
                didCopy ? "checkmark" : "doc.on.doc",
                tint: didCopy ? AnyShapeStyle(.green) : AnyShapeStyle(.primary)
            )
        }
        .buttonStyle(IconButtonStyle())
        .help(didCopy ? "Copied" : "Copy result")
        .disabled(model.output.isEmpty)
        // Revert the checkmark a beat after copying. Keyed on copyToken (not
        // didCopy) so back-to-back copies restart the timer instead of letting
        // the first one's reset fire early.
        .task(id: copyToken) {
            guard didCopy else { return }
            try? await Task.sleep(for: .seconds(1.2))
            didCopy = false
        }
    }

    private func sectionLabel(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func copyOutput() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(model.output, forType: .string)
        didCopy = true
        copyToken &+= 1
    }
}

/// Flat icon button that actually reacts to the pointer: a rounded highlight on
/// hover, a stronger fill plus a slight shrink on press. Replaces bare
/// `.borderless` on the panel's toolbar/inline icons, which gave almost no
/// feedback over the glass.
private struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        IconButtonStyleBody(configuration: configuration)
    }
}

/// Backing view for `IconButtonStyle` — a separate type so it can hold the
/// `@State` hover flag that a `ButtonStyle` struct can't.
private struct IconButtonStyleBody: View {
    let configuration: ButtonStyleConfiguration
    @State private var hovering = false

    var body: some View {
        let fill = configuration.isPressed ? 0.18 : (hovering ? 0.10 : 0)
        configuration.label
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(fill))
            )
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.12), value: hovering)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
