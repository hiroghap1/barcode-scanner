import XCTest
@testable import BarcodeAssignCore

final class ColumnGuesserTests: XCTestCase {

    func testTypicalJapaneseHeaders() {
        let mapping = ColumnGuesser.guess(columnNames: ["商品番号", "商品名", "JAN"])
        XCTAssertEqual(mapping, ColumnMapping(identifierIndex: 0, displayIndex: 1, barcodeIndex: 2))
    }

    func testEnglishHeaders() {
        let mapping = ColumnGuesser.guess(columnNames: ["SKU", "Name", "Barcode"])
        XCTAssertEqual(mapping, ColumnMapping(identifierIndex: 0, displayIndex: 1, barcodeIndex: 2))
    }

    func testBarcodeColumnNotLast() {
        let mapping = ColumnGuesser.guess(columnNames: ["JANコード", "品番", "品名"])
        XCTAssertEqual(mapping, ColumnMapping(identifierIndex: 1, displayIndex: 2, barcodeIndex: 0))
    }

    func testNoKeywordsFallsBackToPositions() {
        let mapping = ColumnGuesser.guess(columnNames: ["A", "B", "C"])
        XCTAssertEqual(mapping, ColumnMapping(identifierIndex: 0, displayIndex: 1, barcodeIndex: 2))
    }

    func testSingleColumn() {
        let mapping = ColumnGuesser.guess(columnNames: ["データ"])
        XCTAssertEqual(mapping, ColumnMapping(identifierIndex: 0, displayIndex: 0, barcodeIndex: 0))
    }

    func testTwoColumns() {
        let mapping = ColumnGuesser.guess(columnNames: ["商品名", "JAN"])
        XCTAssertEqual(mapping.barcodeIndex, 1)
        XCTAssertEqual(mapping.displayIndex, 0)
    }

    func testEmptyColumnsDoNotCrash() {
        let mapping = ColumnGuesser.guess(columnNames: [])
        XCTAssertEqual(mapping, ColumnMapping(identifierIndex: 0, displayIndex: 0, barcodeIndex: 0))
    }
}
