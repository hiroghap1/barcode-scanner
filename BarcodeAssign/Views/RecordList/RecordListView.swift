import SwiftUI
import SwiftData
import BarcodeAssignCore

/// S4 レコード一覧。プロジェクトのハブ画面。
/// 行タップ・スキャン開始でスキャン(S5)へ。出力(S6)へは P4 で結線する。
struct RecordListView: View {
    @Bindable var project: Project

    @State private var filter: RowFilter = .all
    @State private var searchText = ""
    @State private var isScanPresented = false

    /// 行の状態フィルタ
    enum RowFilter: String, CaseIterable, Identifiable {
        case all = "すべて"
        case pending = "未登録"
        case registered = "登録済み"
        case skipped = "スキップ"

        var id: String { rawValue }

        func matches(_ row: Row) -> Bool {
            switch self {
            case .all: return true
            case .pending: return row.status == .pending
            case .registered: return row.status == .registered
            case .skipped: return row.status == .skipped
            }
        }
    }

    var body: some View {
        List {
            Section {
                progressHeader
            }
            Section {
                ForEach(filteredRows) { row in
                    Button {
                        startScan(at: row)
                    } label: {
                        RecordRowView(row: row, project: project)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        skipToggleButton(for: row)
                        if row.barcode != nil {
                            Button("コードを消去", systemImage: "xmark.circle") {
                                clearBarcode(of: row)
                            }
                            .tint(.red)
                        }
                    }
                }
            } footer: {
                if filteredRows.isEmpty {
                    Text(searchText.isEmpty ? "該当する行がありません" : "「\(searchText)」に一致する行がありません")
                }
            }
        }
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "識別・表示・コードで検索")
        .safeAreaInset(edge: .bottom) {
            Button {
                startScan()
            } label: {
                Label("スキャン開始", systemImage: "camera")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(project.totalCount == 0)
            .padding()
            .background(.bar)
        }
        .fullScreenCover(isPresented: $isScanPresented) {
            ScanView(project: project)
        }
    }

    // MARK: - スキャン開始

    /// 現在位置(未登録でなければ最初の未登録行)からスキャンを開始する
    private func startScan() {
        let pending = project.sortedRows.map { $0.status == .pending }
        if let start = ScanNavigator.startIndex(isPending: pending, preferring: project.currentPosition) {
            project.currentPosition = start
        } else {
            // 未登録行なし → 完了画面が表示される
            project.currentPosition = pending.count
        }
        isScanPresented = true
    }

    /// 指定行を開始位置にしてスキャンを開始する(登録済み行の上書きにも使う)
    private func startScan(at row: Row) {
        if let index = project.sortedRows.firstIndex(where: { $0 === row }) {
            project.currentPosition = index
        }
        isScanPresented = true
    }

    // MARK: - 進捗・フィルタ

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProgressView(value: progress)
                .tint(project.pendingCount == 0 && project.totalCount > 0 ? .green : .accentColor)
            Text("登録 \(project.registeredCount) ・ スキップ \(project.skippedCount) ・ 残り \(project.pendingCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("フィルタ", selection: $filter) {
                ForEach(RowFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.vertical, 4)
    }

    private var progress: Double {
        project.totalCount == 0 ? 0 : Double(project.registeredCount) / Double(project.totalCount)
    }

    private var filteredRows: [Row] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        return project.sortedRows.filter { row in
            guard filter.matches(row) else { return false }
            guard !query.isEmpty else { return true }
            let identifier = row.value(at: project.identifierColumnIndex)
            let display = row.value(at: project.displayColumnIndex)
            let barcode = row.barcode ?? ""
            return identifier.localizedCaseInsensitiveContains(query)
                || display.localizedCaseInsensitiveContains(query)
                || barcode.localizedCaseInsensitiveContains(query)
        }
    }

    // MARK: - 行操作

    @ViewBuilder
    private func skipToggleButton(for row: Row) -> some View {
        if row.status == .skipped {
            Button("戻す", systemImage: "arrow.uturn.backward") {
                row.status = .pending
                project.updatedAt = .now
            }
            .tint(.blue)
        } else if row.status == .pending {
            Button("スキップ", systemImage: "forward.end") {
                row.status = .skipped
                project.updatedAt = .now
            }
            .tint(.orange)
        }
    }

    private func clearBarcode(of row: Row) {
        row.barcode = nil
        row.scannedAt = nil
        row.status = .pending
        project.updatedAt = .now
    }
}

/// レコード 1 行(状態アイコン・識別列・表示列・コード)
struct RecordRowView: View {
    let row: Row
    let project: Project

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            statusIcon
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(row.value(at: project.identifierColumnIndex))
                        .font(.body.monospaced().weight(.medium))
                    Text(row.value(at: project.displayColumnIndex))
                        .font(.body)
                        .lineLimit(1)
                }
                if let barcode = row.barcode {
                    Text(barcode)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                } else {
                    Text(row.status.label)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch row.status {
        case .registered:
            Image(systemName: "circle.fill").foregroundStyle(.green)
        case .pending:
            Image(systemName: "circle").foregroundStyle(.secondary)
        case .skipped:
            Image(systemName: "minus").foregroundStyle(.orange)
        }
    }
}
