import SwiftUI
import SwiftData
import BarcodeAssignCore

/// S3 プレビュー & 列マッピング画面
struct ColumnMappingView: View {
    @Bindable var draft: ImportDraft
    /// 取込確定後に呼ばれる(作成されたプロジェクトを渡す)
    let onComplete: (Project) -> Void

    @Environment(\.modelContext) private var modelContext

    private static let previewRowLimit = 5

    var body: some View {
        Form {
            parseOptionsSection
            mappingSection
            previewSection
            summarySection
        }
        .navigationTitle("列の設定")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("取込") { confirmImport() }
                    .disabled(!draft.hasData)
            }
        }
    }

    // MARK: - パース設定

    private var parseOptionsSection: some View {
        Section {
            Toggle("1行目はヘッダー", isOn: $draft.hasHeader)
            Picker("区切り文字", selection: $draft.delimiter) {
                ForEach(Delimiter.allCases, id: \.self) { delimiter in
                    Text(delimiter.displayName).tag(delimiter)
                }
            }
        }
    }

    // MARK: - 列の割当

    private var mappingSection: some View {
        Section("列の割当") {
            Picker("識別列", selection: $draft.identifierIndex) {
                columnOptions
            }
            Picker("表示列", selection: $draft.displayIndex) {
                columnOptions
            }
            Picker("書込列", selection: $draft.barcodeChoice) {
                ForEach(Array(draft.table.columnNames.enumerated()), id: \.offset) { index, name in
                    Text(name).tag(BarcodeColumnChoice.existing(index))
                }
                Label("新しい列を追加", systemImage: "plus")
                    .tag(BarcodeColumnChoice.new)
            }
            if draft.barcodeChoice == .new {
                TextField("新しい列名", text: $draft.newColumnName)
            }
            if draft.identifierEqualsBarcode {
                Label(
                    "識別列と書込列が同じです。スキャンすると識別列の値が上書きされます。",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.footnote)
                .foregroundStyle(.orange)
            }
        }
    }

    private var columnOptions: some View {
        ForEach(Array(draft.table.columnNames.enumerated()), id: \.offset) { index, name in
            Text(name).tag(index)
        }
    }

    // MARK: - プレビュー

    private var previewSection: some View {
        Section("プレビュー(先頭\(Self.previewRowLimit)行)") {
            let plan = draft.plan
            ScrollView(.horizontal) {
                Grid(alignment: .leading, horizontalSpacing: 1, verticalSpacing: 1) {
                    GridRow {
                        ForEach(Array(plan.columnNames.enumerated()), id: \.offset) { index, name in
                            previewCell(name, role: role(of: index, in: plan), isHeader: true)
                        }
                    }
                    ForEach(Array(plan.rows.prefix(Self.previewRowLimit).enumerated()), id: \.offset) { _, row in
                        GridRow {
                            ForEach(0..<plan.columnNames.count, id: \.self) { index in
                                let value = index < row.values.count ? row.values[index] : ""
                                previewCell(value, role: role(of: index, in: plan), isHeader: false)
                            }
                        }
                    }
                }
            }
            legend
        }
    }

    /// 列の役割(ハイライト色の判定)
    private enum ColumnRole {
        case identifier, display, barcode, none

        var color: Color {
            switch self {
            case .identifier: return .blue
            case .display: return .green
            case .barcode: return .orange
            case .none: return .clear
            }
        }
    }

    private func role(of index: Int, in plan: ImportPlan) -> ColumnRole {
        // 書込列を優先(識別列と重なった場合は警告表示で気づける)
        if index == plan.mapping.barcodeIndex { return .barcode }
        if index == plan.mapping.identifierIndex { return .identifier }
        if index == plan.mapping.displayIndex { return .display }
        return .none
    }

    private func previewCell(_ text: String, role: ColumnRole, isHeader: Bool) -> some View {
        Text(text.isEmpty ? " " : text)
            .font(.caption.weight(isHeader ? .semibold : .regular))
            .lineLimit(1)
            .frame(minWidth: 44, maxWidth: 140, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(role.color.opacity(isHeader ? 0.3 : 0.12))
    }

    private var legend: some View {
        HStack(spacing: 12) {
            legendItem("識別", color: .blue)
            legendItem("表示", color: .green)
            legendItem("書込", color: .orange)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private func legendItem(_ label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color.opacity(0.5)).frame(width: 8, height: 8)
            Text(label)
        }
    }

    // MARK: - 集計・確定

    private var summarySection: some View {
        Section {
            LabeledContent("行数", value: "\(draft.table.rows.count)行")
            LabeledContent("既存コード", value: "\(draft.plan.existingBarcodeCount)件")
        } footer: {
            Text("書込列に既にコードが入っている行は「登録済み」として取り込みます。")
        }
    }

    private func confirmImport() {
        let project = draft.saveProject(in: modelContext)
        try? modelContext.save()
        onComplete(project)
    }
}

#Preview {
    let draft = ImportDraft()
    draft.setSourceText("品番,商品名,JAN\nA001,Tシャツ白,4901234567890\nA002,Tシャツ黒,\nA003,Tシャツ灰,")
    return NavigationStack {
        ColumnMappingView(draft: draft, onComplete: { _ in })
    }
    .modelContainer(for: [Project.self, Row.self], inMemory: true)
}
