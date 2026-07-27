import Foundation
import SwiftData
import BarcodeAssignCore

/// 書込列の選択肢
enum BarcodeColumnChoice: Hashable {
    /// 既存の列へ書き込む
    case existing(Int)
    /// 新しい列を末尾に追加する
    case new
}

/// 取込フロー(S2 → S3)で編集中のデータ。
/// テキスト・区切り文字・ヘッダー有無が変わるたびに再パースし、列マッピングを推定し直す。
@Observable
final class ImportDraft {
    private(set) var sourceText = ""
    var delimiter: Delimiter = .comma { didSet { reparse() } }
    var hasHeader = true { didSet { reparse() } }

    private(set) var table = ParsedTable(columnNames: [], rows: [])
    var identifierIndex = 0
    var displayIndex = 0
    var barcodeChoice: BarcodeColumnChoice = .existing(0)
    var newColumnName = ImportPlanner.defaultNewColumnName

    var hasData: Bool { !table.rows.isEmpty }

    /// 貼り付け・ファイル読込でテキストを差し替える(区切り文字は自動判定)
    func setSourceText(_ text: String) {
        sourceText = text
        // delimiter の didSet が reparse を呼ぶ(同値代入でも didSet は発火する)
        delimiter = TableParser.detectDelimiter(in: text)
    }

    private func reparse() {
        table = TableParser.parse(text: sourceText, delimiter: delimiter, hasHeader: hasHeader)
        guard table.columnCount > 0 else {
            identifierIndex = 0
            displayIndex = 0
            barcodeChoice = .existing(0)
            return
        }
        let guessed = ColumnGuesser.guess(columnNames: table.columnNames)
        identifierIndex = guessed.identifierIndex
        displayIndex = guessed.displayIndex
        barcodeChoice = .existing(guessed.barcodeIndex)
    }

    // MARK: - 取込計画

    var mapping: ColumnMapping {
        let barcodeIndex: Int
        switch barcodeChoice {
        case .existing(let index): barcodeIndex = index
        case .new: barcodeIndex = table.columnCount // makePlan が新規列の位置へ付け替える
        }
        return ColumnMapping(
            identifierIndex: identifierIndex,
            displayIndex: displayIndex,
            barcodeIndex: barcodeIndex
        )
    }

    var plan: ImportPlan {
        ImportPlanner.makePlan(
            table: table,
            mapping: mapping,
            newBarcodeColumnName: barcodeChoice == .new ? newColumnName : nil
        )
    }

    /// 識別列と書込列が同一(既存値がスキャンで上書きされるため警告する)
    var identifierEqualsBarcode: Bool {
        barcodeChoice == .existing(identifierIndex)
    }

    // MARK: - 保存

    /// 取込を確定してプロジェクトを保存する
    @discardableResult
    func saveProject(in context: ModelContext) -> Project {
        let plan = plan
        let project = Project(
            name: Self.defaultName(for: .now),
            columnNames: plan.columnNames,
            identifierColumnIndex: plan.mapping.identifierIndex,
            displayColumnIndex: plan.mapping.displayIndex,
            barcodeColumnIndex: plan.mapping.barcodeIndex
        )
        context.insert(project)
        for (index, planRow) in plan.rows.enumerated() {
            let row = Row(sortIndex: index, values: planRow.values)
            if let code = planRow.existingBarcode {
                row.barcode = code
                row.status = .registered
            }
            project.rows.append(row)
        }
        project.currentPosition = plan.rows.firstIndex { $0.existingBarcode == nil } ?? 0
        return project
    }

    static func defaultName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}
