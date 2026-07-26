import Foundation

/// CSV ファイル読込時の文字コード解決。
/// UTF-8(BOM 付き含む)→ Shift_JIS の順で試行する。
public enum TableTextDecoder {

    public static func decode(_ data: Data) -> String? {
        if let text = String(data: data, encoding: .utf8) {
            return TableParser.stripBOM(text)
        }
        if let text = String(data: data, encoding: .shiftJIS) {
            return text
        }
        return nil
    }
}
