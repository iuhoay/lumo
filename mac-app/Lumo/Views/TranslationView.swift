import AppKit
import SwiftUI

/// The contents of the floating translation window.
struct TranslationView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject private var sizing: TranslationSizing
    @ObservedObject private var speaker = Speaker.shared
    @FocusState private var inputFocused: Bool
    /// Whether the clipboard currently holds text — gates the empty window's
    /// "press ⇥ to paste" hint. Refreshed on present and on app re-activation
    /// (not per-render) so we don't read the pasteboard during `body`.
    @State private var clipboardHasText = false
    @State private var didCopy = false
    /// Bumped on every copy so the checkmark-reset task restarts even when
    /// `didCopy` is already true (rapid re-copies keep the confirmation fresh).
    @State private var copyToken = 0
    /// Natural (unclamped) height of the result content, measured inside the
    /// scroll view. Drives the self-sizing result box and, through it, the
    /// window's grow-to-fit height.
    @State private var resultContentHeight: CGFloat = 0

    init(sizing: TranslationSizing) {
        self.sizing = sizing
    }

    var body: some View {
        content
            .padding(16)
            // Measure the content's NATURAL height here, before the fill frame
            // below stretches it to the window, and report it up so the controller
            // can size the window to fit. `onGeometryChange` reads this view's own
            // laid-out height directly; the older `.background(GeometryReader →
            // preference)` trick collapsed to 0 inside the result ScrollView and
            // never updated as tokens streamed.
            .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { sizing.onHeight?($0) }
            // minWidth must fit the header toolbar (fixed-size segmented picker +
            // history/pin/close icons). The segments carry " ⌘1/⌘2/⌘3" hints, so the
            // picker is wider than its bare titles — at 440 the toolbar still leaves a
            // small trailing margin (this is why "Summarize" was shortened to
            // "Summary"). NSHostingController sizes the window to this minWidth, so
            // anything narrower clips the trailing buttons past the rounded-glass mask,
            // making them unclickable. Keep window.minSize in TranslationWindowController
            // in sync with this value.
            .frame(minWidth: 440, maxWidth: .infinity, minHeight: 300, maxHeight: .infinity, alignment: .topLeading)
            // Liquid Glass: the whole popup is a single floating glass slab over the
            // desktop. Controls inside stay flat (borderless) to avoid glass-on-glass.
            .glassEffect(in: RoundedRectangle(cornerRadius: GlassPanelMetrics.cornerRadius, style: .continuous))
            // Command-key shortcuts that the visible controls can't carry: ⌘1/⌘2/⌘3
            // (the segmented Picker has no per-segment shortcut hook) and ⌘R (kept
            // chromeless by choice). Hidden buttons stay in the hierarchy, so the
            // shortcuts fire even while the TextEditor holds focus.
            .background(keyboardShortcuts)
            // Streaming edge: let the controller settle to an exact fit once a
            // grow-only stream finishes.
            .onChange(of: model.isLoading) { _, loading in sizing.onStreaming?(loading) }
            // Focus the input when the panel first appears and whenever it's reopened
            // (the hosting view is reused, so onAppear alone fires only once). Defer
            // to the next runloop tick: setting @FocusState synchronously during
            // window presentation races AppKit's initial first-responder assignment
            // and loses, leaving the focus ring on a toolbar button instead.
            .onAppear { onPresent() }
            .onChange(of: model.focusInputToken) { _, _ in onPresent() }
            // Catch a clipboard change made while the empty window stayed open: the
            // panel re-activates when the user comes back to it, so refresh the hint.
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                refreshClipboardHint()
            }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            HStack {
                sectionLabel("Original")
                speakButton(ResultSegment.spokenText(model.inputText), source: .input)
                Spacer()
            }
            inputField

            HStack {
                Spacer()
                // Mode-agnostic label: ⌘↵ runs the selected action (translate /
                // polish / summarize), so a fixed "Run" stays correct in every
                // mode. The current mode is shown by the picker and result label.
                Button("Run") { model.translate() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(translateDisabled)
                    .help("Run (⌘↵)")
            }

            Divider()

            HStack {
                sectionLabel(resultLabel)
                if !model.resolvedTarget.isEmpty, model.mode != .polish {
                    Text("· \(model.resolvedTarget)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                speakButton(ResultSegment.spokenText(model.output), source: .result)
                copyButton
                Spacer()
                if model.isLoading { ProgressView().controlSize(.small) }
            }

            resultArea
        }
    }

    /// Runs each time the panel is shown (first appear + every reopen): focus the
    /// input and refresh the clipboard hint for the freshly opened, empty window.
    private func onPresent() {
        focusInputSoon()
        refreshClipboardHint()
    }

    private func focusInputSoon() {
        DispatchQueue.main.async { inputFocused = true }
    }

    private func refreshClipboardHint() {
        clipboardHasText = model.clipboardText != nil
    }

    private var header: some View {
        HStack(spacing: 8) {
            Picker("", selection: Binding(
                get: { model.mode },
                set: { model.setMode($0) }
            )) {
                // Append the ⌘-number hint to each segment so the shortcut is
                // self-documenting — a segmented Picker can't host a per-segment
                // .help(...). The number is the 1-based position in allCases,
                // which is exactly what `keyboardShortcuts` binds ⌘1/⌘2/⌘3 to.
                ForEach(Array(TranslationMode.allCases.enumerated()), id: \.element.id) { index, mode in
                    Label("\(mode.title) ⌘\(index + 1)", systemImage: mode.symbol).tag(mode)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .fixedSize()

            Spacer()

            Button { HistoryWindowController.shared.toggle() } label: {
                Image(systemName: "clock.arrow.circlepath")
            }
            // ⌘Y is the de-facto macOS history shortcut (Safari, Finder). Like
            // the Run button, this visible control carries its shortcut directly
            // and still fires while the TextEditor holds focus.
            .keyboardShortcut("y", modifiers: .command)
            .help("Translation History (⌘Y)")

            Button { model.togglePin() } label: {
                Image(systemName: model.isPinned ? "pin.fill" : "pin")
            }
            .keyboardShortcut("p", modifiers: .command)
            .help(model.isPinned ? "Unpin window (⌘P)" : "Pin window (⌘P)")

            Button { model.dismiss() } label: {
                Image(systemName: "xmark")
            }
            .help("Close (Esc)")
        }
        .buttonStyle(IconButtonStyle())
    }

    /// Off-screen buttons that own the window's command-key shortcuts. ⌘1/⌘2/⌘3
    /// switch mode by position in `allCases` (matching the hints in the picker
    /// segments); ⌘R re-runs the current mode. `.hidden()` keeps them in the
    /// view tree — required for the shortcuts to register — without drawing.
    /// ⌘R reuses `translateDisabled`, so it's inert on empty input or mid-stream.
    private var keyboardShortcuts: some View {
        Group {
            ForEach(Array(TranslationMode.allCases.enumerated()), id: \.element.id) { index, mode in
                Button("") { model.setMode(mode) }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
            }
            Button("") { model.translate() }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(translateDisabled)
        }
        .hidden()
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
                    Text(clipboardHasText
                        ? "Type, or press ⇥ to paste clipboard"
                        : "Type or paste text here…")
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

    /// The result box self-sizes to its content (`resultContentHeight`, measured
    /// inside the scroll view) up to the per-screen cap, then scrolls past it.
    /// The window follows this height, so short results don't leave dead space and
    /// long ones grow the window instead of scrolling inside a small box.
    private var resultArea: some View {
        ScrollView {
            resultBody
                .frame(maxWidth: .infinity, alignment: .leading)
                // Measure the result's natural height directly. Feeds `resultBoxHeight`,
                // which sizes this box to fit until the per-screen cap, then scrolls.
                .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { resultContentHeight = $0 }
        }
        .frame(height: resultBoxHeight)
    }

    /// Clamp the measured content height to the per-screen cap. The small floor
    /// keeps an empty/just-opened window from collapsing the box to nothing before
    /// the first measurement arrives.
    private var resultBoxHeight: CGFloat {
        let floorHeight: CGFloat = 56
        let natural = max(resultContentHeight, floorHeight)
        return min(natural, sizing.maxResultHeight)
    }

    @ViewBuilder
    private var resultBody: some View {
        if let errorText = model.errorText {
            VStack(alignment: .leading, spacing: 8) {
                Text(errorText)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let destination = model.errorSettingsDestination {
                    Button(settingsButtonTitle(for: destination)) {
                        openSettings(destination)
                    }
                    .controlSize(.small)
                }
            }
        } else if model.output.isEmpty && model.isLoading {
            Text("Translating…")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            MarkdownResultText(text: model.output)
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

    private func settingsButtonTitle(for destination: ErrorSettingsDestination) -> LocalizedStringKey {
        switch destination {
        case .appSettings: return "Open Settings"
        case .screenRecording: return "Open System Settings"
        }
    }

    private func openSettings(_ destination: ErrorSettingsDestination) {
        switch destination {
        case .appSettings:
            SettingsWindowController.shared.present()
        case .screenRecording:
            ScreenCaptureService.openScreenRecordingSettings()
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

    private func speakButton(_ text: String, source: Speaker.Source) -> some View {
        let isActive = speaker.isSpeaking && speaker.currentSource == source
        return Button {
            if isActive { speaker.stop() } else { speaker.speak(text, source: source) }
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
