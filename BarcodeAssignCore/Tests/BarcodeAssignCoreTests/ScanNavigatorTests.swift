import XCTest
@testable import BarcodeAssignCore

final class ScanNavigatorTests: XCTestCase {

    // MARK: nextPendingIndex

    func testNextPendingAfterCurrent() {
        // [済, 未, 未] で current=1 → 2
        XCTAssertEqual(ScanNavigator.nextPendingIndex(isPending: [false, true, true], after: 1), 2)
    }

    func testWrapsAroundToBeginning() {
        // 末尾以降に未登録がなければ先頭へ巻き戻る
        XCTAssertEqual(ScanNavigator.nextPendingIndex(isPending: [true, false, false], after: 1), 0)
    }

    func testSkipsRegisteredRows() {
        XCTAssertEqual(ScanNavigator.nextPendingIndex(isPending: [false, false, false, true], after: 0), 3)
    }

    func testExcludesCurrentItself() {
        // current だけが未登録でも current 自身は返さない(登録直後の移動用のため)
        XCTAssertNil(ScanNavigator.nextPendingIndex(isPending: [false, true, false], after: 1))
    }

    func testAllDoneReturnsNil() {
        XCTAssertNil(ScanNavigator.nextPendingIndex(isPending: [false, false], after: 0))
    }

    func testEmptyReturnsNil() {
        XCTAssertNil(ScanNavigator.nextPendingIndex(isPending: [], after: 0))
    }

    func testOutOfRangeCurrentIsClamped() {
        // 範囲超過は最終行扱い → 次は巻き戻って先頭
        XCTAssertEqual(ScanNavigator.nextPendingIndex(isPending: [true, true], after: 99), 0)
        // 負は先頭からの探索
        XCTAssertEqual(ScanNavigator.nextPendingIndex(isPending: [false, true], after: -5), 1)
    }

    func testSingleRowNeverReturnsCurrent() {
        XCTAssertNil(ScanNavigator.nextPendingIndex(isPending: [true], after: 0))
    }

    // MARK: startIndex

    func testStartKeepsCurrentWhenPending() {
        XCTAssertEqual(ScanNavigator.startIndex(isPending: [true, true], preferring: 1), 1)
    }

    func testStartFallsBackToFirstPending() {
        XCTAssertEqual(ScanNavigator.startIndex(isPending: [false, true, true], preferring: 0), 1)
    }

    func testStartReturnsNilWhenAllDone() {
        XCTAssertNil(ScanNavigator.startIndex(isPending: [false, false], preferring: 0))
    }
}
