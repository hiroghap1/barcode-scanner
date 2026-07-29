import SwiftUI
import SwiftData
import AVFoundation
import VisionKit
import BarcodeAssignCore

/// S5 スキャン画面(フルスクリーン)。
/// 「表示 → スキャン → 自動保存 → 次の未登録行へ」の連続フローを提供する。
/// 受理判定は ScanArbiter(再アーム + グローバルクールダウン)、
/// 読取範囲は中央帯(ガイド枠)に制限する — 方式は docs/notes/scanner-spike.md 参照。
struct ScanView: View {
    @Bindable var project: Project
    /// 完了画面の「出力へ」で呼ばれる(呼び出し側でスキャンを閉じた後に出力シートを開く)
    var onExport: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var arbiter = ScanArbiter()
    @State private var cameraStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    /// 確認ダイアログ表示中はスキャンを受理しない(誤読防止)
    @State private var pendingConfirmation: PendingConfirmation?
    @State private var isManualEntryPresented = false
    @State private var manualCode = ""
    /// 読取成功時にカードを一瞬緑にフラッシュ
    @State private var isFlashingSuccess = false
    /// 行送りアニメーションの方向(進む: 下から / 戻る: 上から)
    @State private var advanceEdge: Edge = .bottom

    /// 中央帯の高さ比率(スパイクで検証済みの値)
    private let bandRatio: CGFloat = 0.35

    /// スキャン受理後にユーザーの確認を要するケース
    private enum PendingConfirmation: Identifiable {
        /// 他の行に登録済みのコード(重複)
        case duplicate(payload: String, existingRow: Row)
        /// 現在行が登録済みで、別のコードに上書きしようとしている
        case overwrite(payload: String)

        var id: String {
            switch self {
            case .duplicate(let payload, _): return "duplicate-\(payload)"
            case .overwrite(let payload): return "overwrite-\(payload)"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let row = currentRow {
                    scannerArea
                    // 前後の行を小さく見せ、リストを進んでいる感覚を出す
                    VStack(spacing: 0) {
                        adjacentRowView(previousRow)
                        productCard(for: row)
                        adjacentRowView(nextRow)
                    }
                    .id(project.currentPosition)
                    .transition(.push(from: advanceEdge))
                    controlBar
                } else {
                    completedView
                }
            }
            .clipped()
            .navigationTitle("\(project.registeredCount) / \(project.totalCount)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    ProgressView(value: progress)
                        .frame(width: 140)
                }
            }
        }
        .interactiveDismissDisabled()
        .onAppear(perform: requestCameraIfNeeded)
        .alert(
            confirmationTitle,
            isPresented: Binding(
                get: { pendingConfirmation != nil },
                set: { if !$0 { pendingConfirmation = nil } }
            )
        ) {
            Button("このまま登録") {
                if let confirmation = pendingConfirmation {
                    switch confirmation {
                    case .duplicate(let payload, _), .overwrite(let payload):
                        commit(payload)
                    }
                }
                pendingConfirmation = nil
            }
            Button("キャンセル", role: .cancel) { pendingConfirmation = nil }
        } message: {
            Text(confirmationMessage)
        }
        .alert("コードを手動入力", isPresented: $isManualEntryPresented) {
            TextField("バーコードの値", text: $manualCode)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("登録") {
                let code = manualCode.trimmingCharacters(in: .whitespaces)
                manualCode = ""
                if !code.isEmpty {
                    handleDetection(of: code, bypassArbiter: true)
                }
            }
            Button("キャンセル", role: .cancel) { manualCode = "" }
        } message: {
            Text("カメラで読めないコードを直接入力できます。")
        }
    }

    // MARK: - 現在行

    private var sortedRows: [Row] { project.sortedRows }

    private var currentRow: Row? {
        let rows = sortedRows
        guard project.currentPosition >= 0, project.currentPosition < rows.count else { return nil }
        let row = rows[project.currentPosition]
        // 全行完了(未登録なし)なら完了画面を出す。登録済み行を意図的に開いている場合は表示する
        if row.status != .pending {
            return project.pendingCount > 0 || row.status == .registered ? row : nil
        }
        return row
    }

    private var progress: Double {
        project.totalCount == 0 ? 0 : Double(project.registeredCount) / Double(project.totalCount)
    }

    /// リスト順での前後の行(状態は問わない。「一覧を進んでいる」感覚を優先)
    private var previousRow: Row? {
        let rows = sortedRows
        let index = project.currentPosition - 1
        return index >= 0 && index < rows.count ? rows[index] : nil
    }

    private var nextRow: Row? {
        let rows = sortedRows
        let index = project.currentPosition + 1
        return index >= 0 && index < rows.count ? rows[index] : nil
    }

    // MARK: - カメラ

    @ViewBuilder
    private var scannerArea: some View {
        Group {
            switch cameraStatus {
            case .authorized:
                scannerView
                    .overlay { GuideBandOverlay(bandRatio: bandRatio) }
            case .denied, .restricted:
                cameraDeniedView
            default:
                ProgressView("カメラを準備中…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }

    @ViewBuilder
    private var scannerView: some View {
        if DataScannerViewController.isSupported {
            DataScannerRepresentable(
                onDetect: { payload, _ in handleDetection(of: payload) },
                regionHeightRatio: bandRatio
            )
        } else {
            AVFScannerRepresentable(
                onDetect: { payload, _ in handleDetection(of: payload) },
                regionHeightRatio: bandRatio
            )
        }
    }

    private var cameraDeniedView: some View {
        ContentUnavailableView {
            Label("カメラを使用できません", systemImage: "camera.fill")
                .foregroundStyle(.white)
        } description: {
            Text("バーコードを読み取るには設定アプリでカメラへのアクセスを許可してください。手動入力(⌨)は引き続き使えます。")
                .foregroundStyle(.gray)
        } actions: {
            Button("設定を開く") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .fontWeight(.bold)
            .buttonStyle(.borderedProminent)
            .tint(Color("BrandGreen"))
        }
    }

    private func requestCameraIfNeeded() {
        guard cameraStatus == .notDetermined else { return }
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                cameraStatus = granted ? .authorized : .denied
            }
        }
    }

    // MARK: - 商品情報カード・操作

    /// 前後の行のミニ表示(現在行の上下に小さく置き、リストの流れを見せる)
    @ViewBuilder
    private func adjacentRowView(_ row: Row?) -> some View {
        HStack(spacing: 6) {
            if let row {
                Text(row.value(at: project.identifierColumnIndex))
                    .font(.caption.monospaced())
                Text(row.value(at: project.displayColumnIndex))
                    .font(.caption)
                    .lineLimit(1)
                Spacer()
                if row.barcode != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
            } else {
                Text(" ").font(.caption) // 端でも高さを揃えるためのプレースホルダ
            }
        }
        .foregroundStyle(.secondary)
        .opacity(0.6)
        .padding(.horizontal)
        .padding(.vertical, 3)
        .background(Color(.secondarySystemBackground))
        .accessibilityHidden(true)
    }

    private func productCard(for row: Row) -> some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(row.value(at: project.identifierColumnIndex))
                    .font(.headline.monospaced())
                    .foregroundStyle(.secondary)
                Text(row.value(at: project.displayColumnIndex))
                    .font(.title2.bold())
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                if let barcode = row.barcode {
                    Label(barcode, systemImage: "barcode")
                        .font(.body.monospaced())
                    Text("登録済み(再スキャンで上書き)")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else {
                    Text("コード: \(row.status == .skipped ? "スキップ中" : "未登録")")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding()
        .background(isFlashingSuccess ? Color.green.opacity(0.35) : Color(.systemBackground))
        .animation(.easeOut(duration: 0.3), value: isFlashingSuccess)
    }

    private var controlBar: some View {
        HStack(spacing: 8) {
            controlButton("戻る", systemImage: "chevron.backward", identifier: "scan.previous") {
                moveToPrevious()
            }
            controlButton("スキップ", systemImage: "forward.end", identifier: "scan.skip") {
                skipCurrent()
            }
            controlButton("一覧", systemImage: "list.bullet", identifier: "scan.list") {
                dismiss()
            }
            controlButton("手動入力", systemImage: "keyboard", identifier: "scan.manual") {
                isManualEntryPresented = true
            }
        }
        .padding(.horizontal)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .background(Color(.systemBackground))
    }

    /// 下部メニューのボタン(アイコン上・文字下の均等幅。文字は折り返さない)
    private func controlButton(
        _ title: String,
        systemImage: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.title3)
                Text(title)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(title)
    }

    // MARK: - 完了画面

    private var completedView: some View {
        ContentUnavailableView {
            Label("すべて完了しました 🎉", systemImage: "checkmark.seal.fill")
                .foregroundStyle(.green)
        } description: {
            Text("登録 \(project.registeredCount) 件・スキップ \(project.skippedCount) 件")
        } actions: {
            if onExport != nil {
                Button("出力へ") {
                    onExport?()
                    dismiss()
                }
                .fontWeight(.bold)
                .buttonStyle(.borderedProminent)
                .tint(Color("BrandGreen"))
            }
            Button("一覧へ戻る") { dismiss() }
                .buttonStyle(.bordered)
        }
    }

    // MARK: - 読取フロー

    /// カメラ検出・手動入力の共通入口。
    /// - Parameter bypassArbiter: 手動入力は連続検出ではないため再アーム判定を通さない
    private func handleDetection(of payload: String, bypassArbiter: Bool = false) {
        // ダイアログ表示中は受理しない(arbiter には「見えている」ことだけ記録される)
        if !bypassArbiter {
            let accepted = arbiter.register(payload: payload)
            guard accepted, pendingConfirmation == nil, !isManualEntryPresented else { return }
        } else if pendingConfirmation != nil {
            return
        }
        guard let row = currentRow else { return }

        // 重複チェック: 同一プロジェクト内の他の行に登録済みか
        if let existing = sortedRows.first(where: { $0 !== row && $0.barcode == payload }) {
            pendingConfirmation = .duplicate(payload: payload, existingRow: existing)
            return
        }
        // 現在行が登録済み(意図的に開き直した行)なら上書き確認
        if row.barcode != nil, row.barcode != payload {
            pendingConfirmation = .overwrite(payload: payload)
            return
        }
        commit(payload)
    }

    /// 保存 → フィードバック → 次の未登録行へ(currentPosition も逐次保存)
    private func commit(_ payload: String) {
        guard let row = currentRow else { return }
        row.barcode = payload
        row.status = .registered
        row.scannedAt = .now
        project.updatedAt = .now

        let rows = sortedRows
        advanceEdge = .bottom
        withAnimation(.easeInOut(duration: 0.3)) {
            if let next = ScanNavigator.nextPendingIndex(
                isPending: rows.map { $0.status == .pending },
                after: project.currentPosition
            ) {
                project.currentPosition = next
            } else {
                // 全行完了。currentPosition は範囲外にして完了画面を表示する
                project.currentPosition = rows.count
            }
        }
        try? modelContext.save()

        ScanFeedback.playSuccess()
        // VoiceOver 利用時はスキャン成功と登録先を読み上げる
        UIAccessibility.post(
            notification: .announcement,
            argument: "登録しました。次は \(nextRowSummary)"
        )
        isFlashingSuccess = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            isFlashingSuccess = false
        }
    }

    /// 読み上げ用: 移動先の行の概要(完了時は完了の旨)
    private var nextRowSummary: String {
        guard let row = currentRow else { return "すべて完了しました" }
        let identifier = row.value(at: project.identifierColumnIndex)
        let display = row.value(at: project.displayColumnIndex)
        return "\(identifier) \(display)"
    }

    private func skipCurrent() {
        guard let row = currentRow else { return }
        if row.status == .pending {
            row.status = .skipped
            project.updatedAt = .now
        }
        let rows = sortedRows
        advanceEdge = .bottom
        withAnimation(.easeInOut(duration: 0.3)) {
            if let next = ScanNavigator.nextPendingIndex(
                isPending: rows.map { $0.status == .pending },
                after: project.currentPosition
            ) {
                project.currentPosition = next
            } else {
                project.currentPosition = rows.count
            }
        }
        try? modelContext.save()
    }

    private func moveToPrevious() {
        guard project.currentPosition > 0 else { return }
        advanceEdge = .top
        withAnimation(.easeInOut(duration: 0.3)) {
            project.currentPosition = min(project.currentPosition, sortedRows.count) - 1
        }
        try? modelContext.save()
    }

    // MARK: - 確認ダイアログ文言

    private var confirmationTitle: String {
        switch pendingConfirmation {
        case .duplicate: return "このバーコードは既に登録されています"
        case .overwrite: return "登録済みのコードを上書きしますか?"
        case nil: return ""
        }
    }

    private var confirmationMessage: String {
        switch pendingConfirmation {
        case .duplicate(let payload, let existing):
            let identifier = existing.value(at: project.identifierColumnIndex)
            let display = existing.value(at: project.displayColumnIndex)
            return "\(payload) は「\(identifier) \(display)」に登録済みです。"
        case .overwrite(let payload):
            return "現在のコードを \(payload) で上書きします。"
        case nil:
            return ""
        }
    }
}
