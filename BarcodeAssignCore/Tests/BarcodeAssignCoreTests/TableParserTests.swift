import XCTest
@testable import BarcodeAssignCore

final class TableParserTests: XCTestCase {

    // MARK: - 区切り文字判定

    func testDetectTabDelimiter() {
        let text = "商品番号\t商品名\tJAN\nA001\tTシャツ, 白\t"
        XCTAssertEqual(TableParser.detectDelimiter(in: text), .tab)
    }

    func testDetectCommaDelimiter() {
        let text = "商品番号,商品名,JAN\nA001,Tシャツ白,"
        XCTAssertEqual(TableParser.detectDelimiter(in: text), .comma)
    }

    func testDetectSemicolonDelimiter() {
        let text = "id;name;code\n1;abc;xyz"
        XCTAssertEqual(TableParser.detectDelimiter(in: text), .semicolon)
    }

    func testDetectDelimiterSingleColumnFallsBackToComma() {
        XCTAssertEqual(TableParser.detectDelimiter(in: "A001\nA002"), .comma)
    }

    // MARK: - 基本パース

    func testParseWithHeader() {
        let text = "商品番号,商品名,JAN\nA001,Tシャツ白,4901234567890\nA002,Tシャツ黒,"
        let table = TableParser.parse(text: text, delimiter: .comma, hasHeader: true)
        XCTAssertEqual(table.columnNames, ["商品番号", "商品名", "JAN"])
        XCTAssertEqual(table.rows, [
            ["A001", "Tシャツ白", "4901234567890"],
            ["A002", "Tシャツ黒", ""],
        ])
    }

    func testParseWithoutHeaderGeneratesColumnNames() {
        let text = "A001\tTシャツ白\nA002\tTシャツ黒"
        let table = TableParser.parse(text: text, delimiter: .tab, hasHeader: false)
        XCTAssertEqual(table.columnNames, ["列1", "列2"])
        XCTAssertEqual(table.rows.count, 2)
    }

    func testParseEmptyTextReturnsEmptyTable() {
        let table = TableParser.parse(text: "", delimiter: .comma, hasHeader: true)
        XCTAssertTrue(table.isEmpty)
    }

    func testParseHeaderOnlyReturnsColumnsAndNoRows() {
        let table = TableParser.parse(text: "商品番号,商品名,JAN", delimiter: .comma, hasHeader: true)
        XCTAssertEqual(table.columnNames, ["商品番号", "商品名", "JAN"])
        XCTAssertTrue(table.rows.isEmpty)
    }

    // MARK: - クォート処理(RFC 4180)

    func testQuotedFieldContainingDelimiter() {
        let rows = TableParser.parseFields("A001,\"Tシャツ, 白\",x", delimiter: .comma)
        XCTAssertEqual(rows, [["A001", "Tシャツ, 白", "x"]])
    }

    func testQuotedFieldContainingNewline() {
        let rows = TableParser.parseFields("A001,\"1行目\n2行目\",x", delimiter: .comma)
        XCTAssertEqual(rows, [["A001", "1行目\n2行目", "x"]])
    }

    func testEscapedQuotes() {
        let rows = TableParser.parseFields("A001,\"サイズ \"\"L\"\"\"", delimiter: .comma)
        XCTAssertEqual(rows, [["A001", "サイズ \"L\""]])
    }

    func testQuoteInsideUnquotedFieldIsLiteral() {
        let rows = TableParser.parseFields("5\" inch,x", delimiter: .comma)
        XCTAssertEqual(rows, [["5\" inch", "x"]])
    }

    // MARK: - 改行コード

    func testCRLFAndCRNewlines() {
        let rows = TableParser.parseFields("a,b\r\nc,d\re,f\ng,h", delimiter: .comma)
        XCTAssertEqual(rows, [["a", "b"], ["c", "d"], ["e", "f"], ["g", "h"]])
    }

    func testTrailingNewlineDoesNotProduceEmptyRow() {
        let rows = TableParser.parseFields("a,b\nc,d\n", delimiter: .comma)
        XCTAssertEqual(rows.count, 2)
    }

    // MARK: - 空行・不揃い行

    func testEmptyLinesAreSkipped() {
        let rows = TableParser.parseFields("a,b\n\n\nc,d", delimiter: .comma)
        XCTAssertEqual(rows, [["a", "b"], ["c", "d"]])
    }

    func testRaggedRowsArePaddedToMaxColumnCount() {
        let text = "商品番号,商品名\nA001,Tシャツ白,4901234567890\nA002"
        let table = TableParser.parse(text: text, delimiter: .comma, hasHeader: true)
        XCTAssertEqual(table.columnNames, ["商品番号", "商品名", "列3"])
        XCTAssertEqual(table.rows, [
            ["A001", "Tシャツ白", "4901234567890"],
            ["A002", "", ""],
        ])
    }

    func testEmptyHeaderCellsGetGeneratedNames() {
        let table = TableParser.parse(text: "商品番号,,JAN\nA001,x,y", delimiter: .comma, hasHeader: true)
        XCTAssertEqual(table.columnNames, ["商品番号", "列2", "JAN"])
    }

    // MARK: - BOM・文字コード

    func testBOMIsStripped() {
        let table = TableParser.parse(text: "\u{FEFF}商品番号,JAN\nA001,x", delimiter: .comma, hasHeader: true)
        XCTAssertEqual(table.columnNames.first, "商品番号")
    }

    func testDecodeUTF8WithBOM() {
        let bom = Data([0xEF, 0xBB, 0xBF])
        let data = bom + Data("商品番号,JAN".utf8)
        XCTAssertEqual(TableTextDecoder.decode(data), "商品番号,JAN")
    }

    func testDecodeShiftJIS() {
        let original = "商品番号,商品名\nA001,Tシャツ"
        guard let data = original.data(using: .shiftJIS) else {
            return XCTFail("Shift_JIS エンコード失敗")
        }
        XCTAssertEqual(TableTextDecoder.decode(data), original)
    }
}
