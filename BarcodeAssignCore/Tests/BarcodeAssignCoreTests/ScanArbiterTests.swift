import XCTest
@testable import BarcodeAssignCore

final class ScanArbiterTests: XCTestCase {

    private let base = Date(timeIntervalSince1970: 1_000_000)

    private func at(_ seconds: TimeInterval) -> Date {
        base.addingTimeInterval(seconds)
    }

    func testFirstSightingIsAccepted() {
        let arbiter = ScanArbiter()

        XCTAssertTrue(arbiter.register(payload: "A", at: at(0)))
    }

    func testContinuousSightingIsAcceptedOnlyOnce() {
        let arbiter = ScanArbiter()

        XCTAssertTrue(arbiter.register(payload: "A", at: at(0)))
        // 毎フレーム(0.2秒間隔)見え続けている間は再受理しない
        for i in 1...30 {
            XCTAssertFalse(arbiter.register(payload: "A", at: at(Double(i) * 0.2)))
        }
    }

    func testRearmsAfterLeavingViewForInterval() {
        let arbiter = ScanArbiter()

        XCTAssertTrue(arbiter.register(payload: "A", at: at(0)))
        XCTAssertFalse(arbiter.register(payload: "A", at: at(0.5)))
        // 0.5 秒時点から 1.0 秒以上視界から外れた → 再受理できる
        XCTAssertTrue(arbiter.register(payload: "A", at: at(1.6)))
    }

    func testShortDropoutDoesNotRearm() {
        let arbiter = ScanArbiter()

        XCTAssertTrue(arbiter.register(payload: "A", at: at(0)))
        // トラッキングが 0.4 秒だけ途切れて再検出(チャタリング)→ 再受理しない
        XCTAssertFalse(arbiter.register(payload: "A", at: at(0.4)))
        XCTAssertFalse(arbiter.register(payload: "A", at: at(0.8)))
    }

    func testDifferentCodeDuringCooldownIsRejected() {
        let arbiter = ScanArbiter()

        XCTAssertTrue(arbiter.register(payload: "A", at: at(0)))
        // 別コードでもクールダウン中は受理しない(2段 JAN の交互受理防止)
        XCTAssertFalse(arbiter.register(payload: "B", at: at(0.5)))
    }

    func testCooldownRejectedCodeStaysBlockedWhileVisible() {
        let arbiter = ScanArbiter()

        XCTAssertTrue(arbiter.register(payload: "A", at: at(0)))
        XCTAssertFalse(arbiter.register(payload: "B", at: at(0.5)))
        // B は見え続けている限り、クールダウン明けでも受理しない(視界から外す操作が必要)
        XCTAssertFalse(arbiter.register(payload: "B", at: at(1.2)))
        XCTAssertFalse(arbiter.register(payload: "B", at: at(1.9)))
        // 視界から 1 秒以上外れてから戻すと受理される
        XCTAssertTrue(arbiter.register(payload: "B", at: at(3.5)))
    }

    func testDifferentCodeAfterCooldownIsAccepted() {
        let arbiter = ScanArbiter()

        XCTAssertTrue(arbiter.register(payload: "A", at: at(0)))
        XCTAssertTrue(arbiter.register(payload: "B", at: at(1.5)))
    }

    func testResetClearsState() {
        let arbiter = ScanArbiter()

        XCTAssertTrue(arbiter.register(payload: "A", at: at(0)))
        arbiter.reset()
        XCTAssertTrue(arbiter.register(payload: "A", at: at(0.1)))
    }
}
