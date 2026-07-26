import Foundation

/// 表データの区切り文字
public enum Delimiter: String, CaseIterable, Equatable {
    case tab = "\t"
    case comma = ","
    case semicolon = ";"

    public var character: Character {
        Character(rawValue)
    }

    public var displayName: String {
        switch self {
        case .tab: return "タブ"
        case .comma: return "カンマ"
        case .semicolon: return "セミコロン"
        }
    }
}

/// パース済みの表データ。全行が同じ列数に正規化されている。
public struct ParsedTable: Equatable {
    public let columnNames: [String]
    public let rows: [[String]]

    public var columnCount: Int { columnNames.count }
    public var isEmpty: Bool { rows.isEmpty && columnNames.isEmpty }

    public init(columnNames: [String], rows: [[String]]) {
        self.columnNames = columnNames
        self.rows = rows
    }
}

/// CSV/TSV パーサ(RFC 4180 準拠)
public enum TableParser {

    /// 先頭数行から区切り文字を自動判定する。
    /// スプレッドシート/Excel からのコピーはタブ区切りのため、タブを最優先とする。
    public static func detectDelimiter(in text: String) -> Delimiter {
        let lines = text.split(whereSeparator: \.isNewline)
            .filter { !$0.isEmpty }
            .prefix(10)
        var counts: [Delimiter: Int] = [:]
        for line in lines {
            for delimiter in Delimiter.allCases {
                counts[delimiter, default: 0] += line.filter { $0 == delimiter.character }.count
            }
        }
        for delimiter in [Delimiter.tab, .comma, .semicolon] where counts[delimiter, default: 0] > 0 {
            return delimiter
        }
        return .comma
    }

    /// テキストを表として解釈する。
    /// - ヘッダーありの場合は 1 行目を列名に使う(空の列名は「列n」で補完)
    /// - ヘッダーなしの場合は「列1」「列2」…を生成する
    /// - 列数はすべての行の最大値に合わせ、足りないセルは空文字で埋める
    public static func parse(text: String, delimiter: Delimiter, hasHeader: Bool) -> ParsedTable {
        let rawRows = parseFields(stripBOM(text), delimiter: delimiter)
        guard !rawRows.isEmpty else {
            return ParsedTable(columnNames: [], rows: [])
        }

        let header: [String]? = hasHeader ? rawRows[0] : nil
        let body = hasHeader ? Array(rawRows.dropFirst()) : rawRows
        let columnCount = max(header?.count ?? 0, body.map(\.count).max() ?? 0)
        guard columnCount > 0 else {
            return ParsedTable(columnNames: [], rows: [])
        }

        func padded(_ row: [String]) -> [String] {
            row.count >= columnCount ? row : row + Array(repeating: "", count: columnCount - row.count)
        }

        let columnNames: [String]
        if let header {
            columnNames = padded(header).enumerated().map { index, name in
                let trimmed = name.trimmingCharacters(in: .whitespaces)
                return trimmed.isEmpty ? "列\(index + 1)" : trimmed
            }
        } else {
            columnNames = (1...columnCount).map { "列\($0)" }
        }

        return ParsedTable(columnNames: columnNames, rows: body.map(padded))
    }

    /// RFC 4180 準拠のフィールド分割。
    /// - ダブルクォート囲みフィールド内の区切り文字・改行・エスケープ("")に対応
    /// - 改行コードは CRLF / LF / CR いずれも 1 改行として扱う
    /// - すべてのセルが空の行は取り除く
    public static func parseFields(_ text: String, delimiter: Delimiter) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var field = ""
        var inQuotes = false
        let delimiterChar = delimiter.character

        func endField() {
            currentRow.append(field)
            field = ""
        }

        func endRow() {
            endField()
            rows.append(currentRow)
            currentRow = []
        }

        var index = text.startIndex
        while index < text.endIndex {
            let char = text[index]
            if inQuotes {
                if char == "\"" {
                    let next = text.index(after: index)
                    if next < text.endIndex, text[next] == "\"" {
                        field.append("\"")
                        index = next
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(char)
                }
            } else {
                switch char {
                case "\"" where field.isEmpty:
                    inQuotes = true
                case delimiterChar:
                    endField()
                // Swift では CRLF が 1 つの Character になるため "\r\n" も明示する
                case "\n", "\r", "\r\n":
                    endRow()
                default:
                    field.append(char)
                }
            }
            index = text.index(after: index)
        }
        if !field.isEmpty || !currentRow.isEmpty {
            endRow()
        }

        return rows.filter { row in !row.allSatisfy(\.isEmpty) }
    }

    static func stripBOM(_ text: String) -> String {
        text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text
    }
}
