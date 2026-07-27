import Foundation

/// 出力対象の 1 行(取込時の元データ + 割り当てたコード)
public struct ExportSourceRow: Equatable {
    public let values: [String]
    public let barcode: String?

    public init(values: [String], barcode: String?) {
        self.values = values
        self.barcode = barcode
    }
}

/// 出力用に組み立てた表
public struct ExportTable: Equatable {
    public let columnNames: [String]
    public let rows: [[String]]

    public init(columnNames: [String], rows: [[String]]) {
        self.columnNames = columnNames
        self.rows = rows
    }
}

/// プロジェクトの行データから出力用の表を組み立てる。
/// 元データは変更せず、書込列へ `barcode` を合成する(barcode が nil の行は
/// 取込時の既存値を保持)。「書込列のみ」オプションにも対応する。
public enum ExportTableBuilder {

    public static func build(
        columnNames: [String],
        rows: [ExportSourceRow],
        barcodeColumnIndex: Int,
        barcodeOnly: Bool
    ) -> ExportTable {
        let columnCount = columnNames.count
        let merged = rows.map { row in
            TableExporter.merge(
                values: row.values,
                barcode: row.barcode,
                barcodeColumnIndex: barcodeColumnIndex,
                columnCount: columnCount
            )
        }

        guard barcodeOnly else {
            return ExportTable(columnNames: columnNames, rows: merged)
        }

        guard barcodeColumnIndex >= 0, barcodeColumnIndex < columnCount else {
            return ExportTable(columnNames: [], rows: [])
        }
        return ExportTable(
            columnNames: [columnNames[barcodeColumnIndex]],
            rows: merged.map { [$0[barcodeColumnIndex]] }
        )
    }
}
