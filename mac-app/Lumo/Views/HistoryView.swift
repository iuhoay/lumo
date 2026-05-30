import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \HistoryItem.createdAt, order: .reverse) private var items: [HistoryItem]
    @State private var search = ""
    @State private var selectedID: HistoryItem.ID?

    private var filtered: [HistoryItem] {
        guard !search.isEmpty else { return items }
        return items.filter {
            $0.sourceText.localizedCaseInsensitiveContains(search) ||
            $0.outputText.localizedCaseInsensitiveContains(search)
        }
    }

    private var selected: HistoryItem? {
        guard let selectedID else { return nil }
        return items.first { $0.id == selectedID }
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 360)
        } detail: {
            if let selected {
                detail(selected)
            } else {
                ContentUnavailableView("Select a record", systemImage: "sidebar.left")
            }
        }
        .navigationTitle("Translation History")
        .frame(minWidth: 720, minHeight: 460)
    }

    private var sidebar: some View {
        Group {
            if filtered.isEmpty {
                ContentUnavailableView("No history yet", systemImage: "clock")
            } else {
                List(selection: $selectedID) {
                    ForEach(filtered) { item in
                        sidebarRow(item).tag(item.id)
                    }
                }
            }
        }
        .searchable(text: $search, prompt: "Search source or result")
    }

    private func sidebarRow(_ item: HistoryItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Label(item.mode.title, systemImage: item.mode.symbol)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(item.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Text(item.sourceText)
                .lineLimit(2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button("Delete", role: .destructive) {
                if selectedID == item.id { selectedID = nil }
                HistoryStore.shared.delete(item)
            }
        }
    }

    private func detail(_ item: HistoryItem) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label(item.mode.title, systemImage: item.mode.symbol)
                        .font(.headline)
                    Spacer()
                    Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                actions(item)

                field("Original", item.sourceText)
                field("Translation", item.outputText)

                metadata(item)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func actions(_ item: HistoryItem) -> some View {
        HStack(spacing: 12) {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.outputText, forType: .string)
            } label: {
                Label("Copy result", systemImage: "doc.on.doc")
            }
            Button {
                AppModel.shared.handle(TranslationRequest(text: item.sourceText, mode: item.mode))
            } label: {
                Label("Retranslate", systemImage: "arrow.clockwise")
            }
            Spacer()
            Button(role: .destructive) {
                selectedID = nil
                HistoryStore.shared.delete(item)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func field(_ title: LocalizedStringKey, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(text)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
        }
    }

    private func metadata(_ item: HistoryItem) -> some View {
        HStack(spacing: 16) {
            meta("Provider", item.provider.title)
            meta("Model", item.model)
            meta("Target language", item.target)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private func meta(_ label: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
            Text(value)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
    }
}
