import XCTest
@testable import BarcodeAssignCore

final class ImportPlannerTests: XCTestCase {

    private let table = ParsedTable(
        columnNames: ["品番", "商品名", "JAN"],
        rows: [
            ["A001", "Tシャツ白", "4901234567890"],
            ["A002", "Tシャツ黒", ""],
            ["A003", "Tシャツ灰", "   "],
        ]
    )

    private let mapping = ColumnMapping(identifierIndex: 0, displayIndex: 1, barcodeIndex: 2)

    // MARK: 既存列を書込列にする場合

    func testExistingColumnPicksUpExistingCodes() {
        let plan = ImportPlanner.makePlan(table: table, mapping: mapping, newBarcodeColumnName: nil)

        XCTAssertEqual(plan.columnNames, ["品番", "商品名", "JAN"])
        XCTAssertEqual(plan.mapping, mapping)
        XCTAssertEqual(plan.rows[0].existingBarcode, "4901234567890")
        XCTAssertNil(plan.rows[1].existingBarcode)
    }

    func testWhitespaceOnlyCellIsNotExistingCode() {
        let plan = ImportPlanner.makePlan(table: table, mapping: mapping, newBarcodeColumnName: nil)

        XCTAssertNil(plan.rows[2].existingBarcode)
    }

    func testExistingBarcodeCount() {
        let plan = ImportPlanner.makePlan(table: table, mapping: mapping, newBarcodeColumnName: nil)

        XCTAssertEqual(plan.existingBarcodeCount, 1)
    }

    func testValuesAreKeptUnchanged() {
        let plan = ImportPlanner.makePlan(table: table, mapping: mapping, newBarcodeColumnName: nil)

        XCTAssertEqual(plan.rows.map(\.values), table.rows)
    }

    // MARK: 新しい列を追加する場合

    func testNewColumnAppendsNameAndMovesBarcodeIndex() {
        let plan = ImportPlanner.makePlan(table: table, mapping: mapping, newBarcodeColumnName: "コード")

        XCTAssertEqual(plan.columnNames, ["品番", "商品名", "JAN", "コード"])
        XCTAssertEqual(plan.mapping.barcodeIndex, 3)
        XCTAssertEqual(plan.mapping.identifierIndex, 0)
        XCTAssertEqual(plan.mapping.displayIndex, 1)
    }

    func testNewColumnHasNoExistingCodes() {
        let plan = ImportPlanner.makePlan(table: table, mapping: mapping, newBarcodeColumnName: "コード")

        XCTAssertTrue(plan.rows.allSatisfy { $0.existingBarcode == nil })
        XCTAssertEqual(plan.existingBarcodeCount, 0)
    }

    func testNewColumnDoesNotTouchRowValues() {
        let plan = ImportPlanner.makePlan(table: table, mapping: mapping, newBarcodeColumnName: "コード")

        XCTAssertEqual(plan.rows.map(\.values), table.rows)
    }

    func testEmptyNewColumnNameFallsBackToDefault() {
        let plan = ImportPlanner.makePlan(table: table, mapping: mapping, newBarcodeColumnName: "  ")

        XCTAssertEqual(plan.columnNames.last, ImportPlanner.defaultNewColumnName)
    }
}
