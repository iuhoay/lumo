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
                ContentUnavailableView("选择一条记录", systemImage: "sidebar.left")
            }
        }
        .navigationTitle("翻译历史")
        .frame(minWidth: 720, minHeight: 460)
    }

    private var sidebar: some View {
        Group {
            if filtered.isEmpty {
                ContentUnavailableView("暂无历史", systemImage: "clock")
            } else {
                List(selection: $selectedID) {
                    ForEach(filtered) { item in
                        sidebarRow(item).tag(item.id)
                    }
                }
            }
        }
        .searchable(text: $search, prompt: "搜索原文或译文")
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
            Button("删除", role: .destructive) {
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

                field("原文", item.sourceText)
                field("译文", item.outputText)

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
                Label("复制译文", systemImage: "doc.on.doc")
            }
            Button {
                AppModel.shared.handle(TranslationRequest(text: item.sourceText, mode: item.mode))
            } label: {
                Label("重新翻译", systemImage: "arrow.clockwise")
            }
            Spacer()
            Button(role: .destructive) {
                selectedID = nil
                HistoryStore.shared.delete(item)
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    private func field(_ title: String, _ text: String) -> some View {
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
            meta("服务", item.provider.title)
            meta("模型", item.model)
            meta("目标语言", item.target)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private func meta(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
            Text(value)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
    }
}
