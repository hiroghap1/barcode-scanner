import Foundation

/// 出力形式
public enum ExportFormat {
    /// RFC 4180 準拠 CSV(ファイル保存用)
    case csv
    /// タブ区切り(クリップボード経由でスプレッドシートへ貼り付ける用)
    case tsv

    var delimiter: Character {
        switch self {
        case .csv: return ","
        case .tsv: return "\t"
        }
    }

    /// CSV ファイルは RFC 4180 の CRLF、クリップボード用 TSV は LF
    var lineSeparator: String {
        switch self {
        case .csv: return "\r\n"
        case .tsv: return "\n"
        }
    }
}

/// 表データの書き出し
public enum TableExporter {

    /// 元の行データの書込列へ割り当てたコードを合成する。
    /// - barcode が nil の場合は元の値を保持する(取込時の既存コードなど)
    /// - 行が列数に満たない場合は空文字で埋める
    public static func merge(
        values: [String],
        barcode: String?,
        barcodeColumnIndex: Int,
        columnCount: Int
    ) -> [String] {
        var row = values
        if row.count < columnCount {
            row += Array(repeating: "", count: columnCount - row.count)
        }
        if let barcode, barcodeColumnIndex >= 0, barcodeColumnIndex < row.count {
            row[barcodeColumnIndex] = barcode
        }
        return row
    }

    /// 表全体をテキストへ変換する。
    public static func text(
        columnNames: [String],
        rows: [[String]],
        format: ExportFormat,
        includeHeader: Bool
    ) -> String {
        var lines: [String] = []
        if includeHeader {
            lines.append(line(columnNames, format: format))
        }
        lines += rows.map { line($0, format: format) }
        return lines.joined(separator: format.lineSeparator)
    }

    /// CSV ファイル用データ。Excel での文字化けを防ぐため UTF-8 BOM を付与する。
    public static func csvData(columnNames: [String], rows: [[String]], includeHeader: Bool) -> Data {
        let bom = Data([0xEF, 0xBB, 0xBF])
        let body = text(columnNames: columnNames, rows: rows, format: .csv, includeHeader: includeHeader)
        return bom + Data(body.utf8)
    }

    static func line(_ fields: [String], format: ExportFormat) -> String {
        fields.map { escape($0, format: format) }.joined(separator: String(format.delimiter))
    }

    /// 区切り文字・ダブルクォート・改行を含むセルをクォートで囲む(Excel 互換)
    static func escape(_ field: String, format: ExportFormat) -> String {
        let needsQuoting = field.contains(format.delimiter)
            || field.contains("\"")
            || field.contains("\n")
            || field.contains("\r")
        guard needsQuoting else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
