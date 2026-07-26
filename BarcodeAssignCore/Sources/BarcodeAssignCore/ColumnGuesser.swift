import Foundation

/// 識別列・表示列・書込列のインデックス
public struct ColumnMapping: Equatable {
    public var identifierIndex: Int
    public var displayIndex: Int
    public var barcodeIndex: Int

    public init(identifierIndex: Int, displayIndex: Int, barcodeIndex: Int) {
        self.identifierIndex = identifierIndex
        self.displayIndex = displayIndex
        self.barcodeIndex = barcodeIndex
    }
}

/// ヘッダー名から列マッピングの初期値を推定する。
/// 推定できない場合は 1列目=識別、2列目=表示、最終列=書込 にフォールバックする。
public enum ColumnGuesser {

    static let barcodeKeywords = [
        "jan", "barcode", "バーコード", "upc", "ean", "gtin", "isbn", "qr", "コード", "code",
    ]
    static let identifierKeywords = [
        "商品番号", "品番", "番号", "sku", "id", "管理", "no",
    ]
    static let displayKeywords = [
        "商品名", "品名", "名称", "名前", "name", "タイトル", "title", "名",
    ]

    public static func guess(columnNames: [String]) -> ColumnMapping {
        let count = columnNames.count
        guard count > 0 else {
            return ColumnMapping(identifierIndex: 0, displayIndex: 0, barcodeIndex: 0)
        }
        let lowercased = columnNames.map { $0.lowercased() }

        func firstMatch(_ keywords: [String], excluding: Set<Int>) -> Int? {
            for keyword in keywords {
                for (index, name) in lowercased.enumerated()
                where !excluding.contains(index) && name.contains(keyword) {
                    return index
                }
            }
            return nil
        }

        func firstIndex(excluding: Set<Int>) -> Int? {
            (0..<count).first { !excluding.contains($0) }
        }

        let barcode = firstMatch(barcodeKeywords, excluding: []) ?? count - 1
        let identifier = firstMatch(identifierKeywords, excluding: [barcode])
            ?? firstIndex(excluding: [barcode]) ?? barcode
        let display = firstMatch(displayKeywords, excluding: [barcode, identifier])
            ?? firstIndex(excluding: [barcode, identifier]) ?? identifier

        return ColumnMapping(identifierIndex: identifier, displayIndex: display, barcodeIndex: barcode)
    }
}
