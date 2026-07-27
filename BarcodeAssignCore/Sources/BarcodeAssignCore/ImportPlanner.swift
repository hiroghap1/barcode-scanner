import Foundation

/// 取込確定時の計画。S3 での選択(列マッピング・新規列追加)を保存可能な形へ正規化する。
public struct ImportPlan: Equatable {
    /// 新規列の追加を反映した列名
    public let columnNames: [String]
    /// 新規列の追加を反映した列マッピング
    public let mapping: ColumnMapping
    public let rows: [ImportPlanRow]

    /// 書込列に既にコードが入っている行数
    public var existingBarcodeCount: Int {
        rows.filter { $0.existingBarcode != nil }.count
    }

    public init(columnNames: [String], mapping: ColumnMapping, rows: [ImportPlanRow]) {
        self.columnNames = columnNames
        self.mapping = mapping
        self.rows = rows
    }
}

/// 取込計画の 1 行
public struct ImportPlanRow: Equatable {
    /// 元の行データ(新規列を追加しても変更しない。出力時に合成する)
    public let values: [String]
    /// 書込列の既存コード(空白のみのセルは nil)
    public let existingBarcode: String?

    public init(values: [String], existingBarcode: String?) {
        self.values = values
        self.existingBarcode = existingBarcode
    }
}

/// パース済みの表と列マッピングから取込計画を作る
public enum ImportPlanner {

    /// 新規列名が空の場合に使う既定値
    public static let defaultNewColumnName = "バーコード"

    /// - Parameter newBarcodeColumnName: nil なら既存の書込列(`mapping.barcodeIndex`)を使う。
    ///   非 nil なら新しい列を末尾に追加し、書込列をそこへ付け替える(名前が空白のみなら既定値)。
    public static func makePlan(
        table: ParsedTable,
        mapping: ColumnMapping,
        newBarcodeColumnName: String?
    ) -> ImportPlan {
        var columnNames = table.columnNames
        var mapping = mapping
        let usesNewColumn = newBarcodeColumnName != nil

        if let newName = newBarcodeColumnName {
            let trimmed = newName.trimmingCharacters(in: .whitespaces)
            columnNames.append(trimmed.isEmpty ? defaultNewColumnName : trimmed)
            mapping.barcodeIndex = columnNames.count - 1
        }

        let rows = table.rows.map { values -> ImportPlanRow in
            var existing: String?
            if !usesNewColumn, mapping.barcodeIndex >= 0, mapping.barcodeIndex < values.count {
                let value = values[mapping.barcodeIndex].trimmingCharacters(in: .whitespaces)
                existing = value.isEmpty ? nil : value
            }
            return ImportPlanRow(values: values, existingBarcode: existing)
        }

        return ImportPlan(columnNames: columnNames, mapping: mapping, rows: rows)
    }
}
