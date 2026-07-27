import SwiftUI
import UniformTypeIdentifiers
import BarcodeAssignCore

/// 取込フロー(S2 → S3)のルート。シートとして表示する。
struct ImportFlowView: View {
    /// 取込確定後に呼ばれる(呼び出し側でシートを閉じ、作成されたプロジェクトへ遷移する)
    let onComplete: (Project) -> Void

    @State private var draft = ImportDraft()

    var body: some View {
        NavigationStack {
            ImportView(draft: draft, onComplete: onComplete)
        }
    }
}

/// S2 データ取込画面
struct ImportView: View {
    @Bindable var draft: ImportDraft
    let onComplete: (Project) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var method: ImportMethod = .paste
    @State private var isFilePickerPresented = false
    @State private var loadedFileName: String?
    @State private var errorMessage: String?

    private enum ImportMethod: Hashable {
        case paste
        case file
    }

    var body: some View {
        VStack(spacing: 16) {
            Picker("入力方法", selection: $method) {
                Text("貼り付け").tag(ImportMethod.paste)
                Text("CSV ファイル").tag(ImportMethod.file)
            }
            .pickerStyle(.segmented)

            switch method {
            case .paste: pasteSection
            case .file: fileSection
            }

            detectionSummary

            NavigationLink {
                ColumnMappingView(draft: draft, onComplete: onComplete)
            } label: {
                Text("次へ")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!draft.hasData)
        }
        .padding()
        .navigationTitle("データ取込")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") { dismiss() }
            }
        }
        .fileImporter(
            isPresented: $isFilePickerPresented,
            allowedContentTypes: [.commaSeparatedText, .tabSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { loadFile(from: url) }
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
        .alert("読み込みエラー", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - 貼り付け

    private var pasteSection: some View {
        VStack(spacing: 12) {
            TextEditor(text: Binding(
                get: { draft.sourceText },
                set: { draft.setSourceText($0) }
            ))
            .font(.footnote.monospaced())
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .frame(maxHeight: .infinity)
            .overlay(alignment: .topLeading) {
                if draft.sourceText.isEmpty {
                    Text("スプレッドシートからコピーした表を貼り付け")
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color(.separator))
            )

            Button {
                if let text = UIPasteboard.general.string, !text.isEmpty {
                    draft.setSourceText(text)
                } else {
                    errorMessage = "クリップボードにテキストがありません"
                }
            } label: {
                Label("クリップボードから貼り付け", systemImage: "doc.on.clipboard")
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - CSV ファイル

    private var fileSection: some View {
        VStack(spacing: 12) {
            ContentUnavailableView {
                Label(loadedFileName ?? "ファイル未選択", systemImage: "doc.text")
            } description: {
                Text("CSV / TSV / テキストファイルを選択してください(UTF-8 / Shift_JIS 対応)")
            } actions: {
                Button("ファイルを選択") { isFilePickerPresented = true }
                    .buttonStyle(.borderedProminent)
            }
            .frame(maxHeight: .infinity)
        }
    }

    private func loadFile(from url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }
        do {
            let data = try Data(contentsOf: url)
            guard let text = TableTextDecoder.decode(data) else {
                errorMessage = "文字コードを判別できませんでした(UTF-8 / Shift_JIS のみ対応)"
                return
            }
            draft.setSourceText(text)
            loadedFileName = url.lastPathComponent
        } catch {
            errorMessage = "ファイルを読み込めませんでした: \(error.localizedDescription)"
        }
    }

    // MARK: - 検出結果

    @ViewBuilder
    private var detectionSummary: some View {
        if draft.hasData {
            Label(
                "\(draft.table.rows.count)行 × \(draft.table.columnCount)列を検出(区切り: \(draft.delimiter.displayName))",
                systemImage: "checkmark.circle.fill"
            )
            .font(.callout)
            .foregroundStyle(.green)
        } else if !draft.sourceText.isEmpty {
            Label("表データを検出できませんでした", systemImage: "exclamationmark.triangle.fill")
                .font(.callout)
                .foregroundStyle(.orange)
        }
    }
}

#Preview {
    ImportFlowView(onComplete: { _ in })
}
