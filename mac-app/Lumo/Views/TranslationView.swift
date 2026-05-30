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
                    sectionLabel("原文")
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
                    sectionLabel(request.mode == .summarize ? "总结" : (request.mode == .polish ? "润色" : "译文"))
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
                Text("等待输入…").foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(minWidth: 360, maxWidth: .infinity, minHeight: 240, maxHeight: .infinity, alignment: .topLeading)
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
            .help("翻译历史")

            Button { model.togglePin() } label: {
                Image(systemName: model.isPinned ? "pin.fill" : "pin")
            }
            .help("置顶窗口")

            Button { model.retranslate() } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("重新翻译")
            .disabled(model.isLoading)

            Button { copyOutput() } label: {
                Image(systemName: "doc.on.doc")
            }
            .help("复制译文")
            .disabled(model.output.isEmpty)

            Button { model.dismiss() } label: {
                Image(systemName: "xmark")
            }
            .help("关闭（Esc）")
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
                    // The error (e.g. "未设置 API Key") names Settings; give the
                    // user a way to reach it from the floating panel itself.
                    Button("打开设置") {
                        SettingsWindowController.shared.present()
                    }
                    .controlSize(.small)
                }
            } else if model.output.isEmpty && model.isLoading {
                Text("翻译中…")
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
        .help("朗读")
        .disabled(disabled)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func copyOutput() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(model.output, forType: .string)
    }
}
