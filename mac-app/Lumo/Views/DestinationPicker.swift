import SwiftUI

/// Compact destination control for the translation result row. A quiet chip
/// matching the neighbouring 18pt icon buttons; Custom… uses a popover so the
/// row height doesn't jump.
struct DestinationPicker: View {
    let destination: String
    let onSelect: (String) -> Void

    @State private var showingCustom = false
    @State private var customText = ""

    private var selectedPreset: String? {
        LanguagePresets.canonicalPreset(matching: destination)
    }

    var body: some View {
        Menu {
            Picker("Destination", selection: Binding<String?>(
                get: { selectedPreset },
                set: { if let newValue = $0 { onSelect(newValue) } }
            )) {
                ForEach(LanguagePresets.list, id: \.self) { language in
                    Text(language).tag(Optional(language))
                }
            }
            .labelsHidden()
            .pickerStyle(.inline)
            Divider()
            Button("Custom…") {
                let resolved = LanguagePresets.selection(for: destination)
                customText = resolved.selection == LanguagePresets.customTag ? resolved.custom : ""
                showingCustom = true
            }
        } label: {
            DestinationChip(title: destination)
        }
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .fixedSize()
        .help("Change destination")
        .popover(isPresented: $showingCustom, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Custom language")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("e.g. Dutch", text: $customText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { commitCustom() }
            }
            .padding(12)
            .frame(width: 220)
        }
    }

    private func commitCustom() {
        let trimmed = customText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSelect(LanguagePresets.canonicalPreset(matching: trimmed) ?? trimmed)
        showingCustom = false
    }
}

/// Quiet language chip: same 18pt row and hover wash as `IconButtonStyle`.
private struct DestinationChip: View {
    let title: String
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(.tertiary)
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, 6)
        .frame(height: 18)
        .frame(maxWidth: 168)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(hovering ? 0.10 : 0))
        )
        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }
}
