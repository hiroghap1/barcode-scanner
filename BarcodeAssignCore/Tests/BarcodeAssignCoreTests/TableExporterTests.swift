import XCTest
@testable import BarcodeAssignCore

final class TableExporterTests: XCTestCase {

    // MARK: - merge

    func testMergeWritesBarcodeIntoColumn() {
        let merged = TableExporter.merge(
            values: ["A001", "Tシャツ白", ""],
            barcode: "4901234567890",
            barcodeColumnIndex: 2,
            columnCount: 3
        )
        XCTAssertEqual(merged, ["A001", "Tシャツ白", "4901234567890"])
    }

    func testMergeNilBarcodeKeepsOriginalValue() {
        let merged = TableExporter.merge(
            values: ["A001", "Tシャツ白", "既存値"],
            barcode: nil,
            barcodeColumnIndex: 2,
            columnCount: 3
        )
        XCTAssertEqual(merged, ["A001", "Tシャツ白", "既存値"])
    }

    func testMergePadsShortRows() {
        let merged = TableExporter.merge(
            values: ["A001"],
            barcode: "x",
            barcodeColumnIndex: 2,
            columnCount: 3
        )
        XCTAssertEqual(merged, ["A001", "", "x"])
    }

    // MARK: - TSV(クリップボード)

    func testTSVOutput() {
        let text = TableExporter.text(
            columnNames: ["商品番号", "JAN"],
            rows: [["A001", "4901234567890"]],
            format: .tsv,
            includeHeader: true
        )
        XCTAssertEqual(text, "商品番号\tJAN\nA001\t4901234567890")
    }

    func testTSVWithoutHeader() {
        let text = TableExporter.text(
            columnNames: ["商品番号", "JAN"],
            rows: [["A001", "x"]],
            format: .tsv,
            includeHeader: false
        )
        XCTAssertEqual(text, "A001\tx")
    }

    func testTSVCellContainingTabIsQuoted() {
        let text = TableExporter.text(
            columnNames: ["a"],
            rows: [["x\ty"]],
            format: .tsv,
            includeHeader: false
        )
        XCTAssertEqual(text, "\"x\ty\"")
    }

    // MARK: - CSV

    func testCSVUsesCRLF() {
        let text = TableExporter.text(
            columnNames: ["a", "b"],
            rows: [["1", "2"]],
            format: .csv,
            includeHeader: true
        )
        XCTAssertEqual(text, "a,b\r\n1,2")
    }

    func testCSVEscapesCommaQuoteAndNewline() {
        let text = TableExporter.text(
            columnNames: ["a"],
            rows: [["Tシャツ, 白"], ["サイズ \"L\""], ["1行目\n2行目"]],
            format: .csv,
            includeHeader: false
        )
        XCTAssertEqual(text, "\"Tシャツ, 白\"\r\n\"サイズ \"\"L\"\"\"\r\n\"1行目\n2行目\"")
    }

    func testCSVDataHasUTF8BOM() {
        let data = TableExporter.csvData(columnNames: ["a"], rows: [["1"]], includeHeader: true)
        XCTAssertEqual(Array(data.prefix(3)), [0xEF, 0xBB, 0xBF])
        XCTAssertEqual(String(data: data.dropFirst(3), encoding: .utf8), "a\r\n1")
    }

    // MARK: - パースとの往復

    func testRoundTripThroughParser() {
        let columnNames = ["商品番号", "商品名", "JAN"]
        let rows = [
            ["A001", "Tシャツ, 白", "4901234567890"],
            ["A002", "サイズ \"L\"", ""],
        ]
        let csv = TableExporter.text(columnNames: columnNames, rows: rows, format: .csv, includeHeader: true)
        let parsed = TableParser.parse(text: csv, delimiter: .comma, hasHeader: true)
        XCTAssertEqual(parsed.columnNames, columnNames)
        XCTAssertEqual(parsed.rows, rows)
    }
}
