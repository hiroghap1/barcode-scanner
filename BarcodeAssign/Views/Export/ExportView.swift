import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import BarcodeAssignCore

/// S6 出力シート。
/// クリップボード(TSV)/ CSV ファイル保存 / Share Sheet の3方式で出力する。
struct ExportView: View {
    let project: Project

    @Environment(\.dismiss) private var dismiss
    @State private var includeHeader = true
    @State private var barcodeOnly = false
    @State private var didCopy = false
    @State private var isFileExporterPresented = false
    @State private var exportError: String?

    private static let previewRowLimit = 5

    var body: some View {
        NavigationStack {
            Form {
                previewSection
                optionsSection
                actionsSection
            }
            .navigationTitle("出力")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .fileExporter(
            isPresented: $isFileExporterPresented,
            document: CSVDocument(data: csvData),
            contentType: .commaSeparatedText,
            defaultFilename: suggestedFileName
        ) { result in
            if case .failure(let error) = result {
                exportError = error.localizedDescription
            }
        }
        .alert("出力エラー", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
    }

    // MARK: - 出力データ

    private var exportTable: ExportTable {
        ExportTableBuilder.build(
            columnNames: project.columnNames,
            rows: project.sortedRows.map { ExportSourceRow(values: $0.values, barcode: $0.barcode) },
            barcodeColumnIndex: project.barcodeColumnIndex,
            barcodeOnly: barcodeOnly
        )
    }

    private var tsvText: String {
        let table = exportTable
        return TableExporter.text(
            columnNames: table.columnNames,
            rows: table.rows,
            format: .tsv,
            includeHeader: includeHeader
        )
    }

    private var csvData: Data {
        let table = exportTable
        return TableExporter.csvData(
            columnNames: table.columnNames,
            rows: table.rows,
            includeHeader: includeHeader
        )
    }

    /// ファイル名に使えない文字を避ける(プロジェクト名の "12:00" 等)
    private var suggestedFileName: String {
        project.name
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "/", with: "-")
    }

    // MARK: - プレビュー

    private var previewSection: some View {
        Section("プレビュー(先頭\(Self.previewRowLimit)行)") {
            let table = exportTable
            ScrollView(.horizontal) {
                Grid(alignment: .leading, horizontalSpacing: 1, verticalSpacing: 1) {
                    if includeHeader {
                        GridRow {
                            ForEach(Array(table.columnNames.enumerated()), id: \.offset) { _, name in
                                previewCell(name, isHeader: true)
                            }
                        }
                    }
                    ForEach(Array(table.rows.prefix(Self.previewRowLimit).enumerated()), id: \.offset) { _, row in
                        GridRow {
                            ForEach(Array(row.enumerated()), id: \.offset) { _, value in
                                previewCell(value, isHeader: false)
                            }
                        }
                    }
                }
            }
        }
    }

    private func previewCell(_ text: String, isHeader: Bool) -> some View {
        Text(text.isEmpty ? " " : text)
            .font(.caption.weight(isHeader ? .semibold : .regular))
            .lineLimit(1)
            .frame(minWidth: 44, maxWidth: 140, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isHeader ? Color(.secondarySystemFill) : .clear)
    }

    // MARK: - オプション・注意

    private var optionsSection: some View {
        Section {
            Toggle("ヘッダー行を含める", isOn: $includeHeader)
            Toggle("書込列のみ", isOn: $barcodeOnly)
        } footer: {
            if project.pendingCount > 0 || project.skippedCount > 0 {
                Text("未登録 \(project.pendingCount) 件・スキップ \(project.skippedCount) 件が残っています(出力は可能です)。")
                    .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - 出力アクション

    private var actionsSection: some View {
        Section {
            Button {
                UIPasteboard.general.string = tsvText
                didCopy = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { didCopy = false }
            } label: {
                Label(
                    didCopy ? "コピーしました" : "クリップボードにコピー",
                    systemImage: didCopy ? "checkmark.circle.fill" : "doc.on.doc"
                )
            }
            Button {
                isFileExporterPresented = true
            } label: {
                Label("CSV ファイルとして保存", systemImage: "square.and.arrow.down")
            }
            ShareLink(
                item: CSVTransferable(data: csvData, fileName: suggestedFileName + ".csv"),
                preview: SharePreview(suggestedFileName + ".csv", image: Image(systemName: "tablecells"))
            ) {
                Label("共有", systemImage: "square.and.arrow.up")
            }
        } footer: {
            Text("コピー(タブ区切り)は Google スプレッドシートや Excel にそのまま貼り付けできます。CSV は Excel 互換の UTF-8(BOM 付き)です。")
        }
    }
}

/// fileExporter 用の CSV ドキュメント
struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

/// Share Sheet 用の CSV(共有実行時に一時ファイルへ書き出す)
struct CSVTransferable: Transferable {
    let data: Data
    let fileName: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { item in
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(item.fileName)
            try item.data.write(to: url)
            return SentTransferredFile(url)
        }
    }
}
