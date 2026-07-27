import XCTest
@testable import BarcodeAssignCore

final class ExportTableBuilderTests: XCTestCase {

    private let columnNames = ["品番", "商品名", "JAN"]
    private let rows = [
        ExportSourceRow(values: ["A001", "Tシャツ白", "4900000000001"], barcode: "4901111111111"),
        ExportSourceRow(values: ["A002", "Tシャツ黒", ""], barcode: nil),
        ExportSourceRow(values: ["A003", "Tシャツ灰", "4900000000003"], barcode: nil),
    ]

    func testMergesBarcodesIntoColumn() {
        let table = ExportTableBuilder.build(
            columnNames: columnNames, rows: rows, barcodeColumnIndex: 2, barcodeOnly: false
        )

        XCTAssertEqual(table.columnNames, columnNames)
        // スキャンしたコードは書込列を上書き
        XCTAssertEqual(table.rows[0], ["A001", "Tシャツ白", "4901111111111"])
        // 未登録の行は空のまま
        XCTAssertEqual(table.rows[1], ["A002", "Tシャツ黒", ""])
        // barcode が nil でも取込時の既存値は保持
        XCTAssertEqual(table.rows[2], ["A003", "Tシャツ灰", "4900000000003"])
    }

    func testShortRowsArePadded() {
        let table = ExportTableBuilder.build(
            columnNames: columnNames,
            rows: [ExportSourceRow(values: ["A004"], barcode: "4904444444444")],
            barcodeColumnIndex: 2,
            barcodeOnly: false
        )

        XCTAssertEqual(table.rows[0], ["A004", "", "4904444444444"])
    }

    func testBarcodeOnlyExtractsSingleColumn() {
        let table = ExportTableBuilder.build(
            columnNames: columnNames, rows: rows, barcodeColumnIndex: 2, barcodeOnly: true
        )

        XCTAssertEqual(table.columnNames, ["JAN"])
        XCTAssertEqual(table.rows, [["4901111111111"], [""], ["4900000000003"]])
    }

    func testBarcodeOnlyWithInvalidIndexReturnsEmpty() {
        let table = ExportTableBuilder.build(
            columnNames: columnNames, rows: rows, barcodeColumnIndex: 99, barcodeOnly: true
        )

        XCTAssertTrue(table.columnNames.isEmpty)
        XCTAssertTrue(table.rows.isEmpty)
    }
}
