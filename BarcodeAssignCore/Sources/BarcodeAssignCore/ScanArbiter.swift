import Foundation

/// 連続スキャンの受理判定。
///
/// スキャナは同じコードを毎フレーム検出し続けるため、そのまま登録すると
/// 連続誤登録になる。本クラスは検出(sighting)を毎回受け取り、
/// 「登録すべき 1 回」だけを受理する:
///
/// 1. **再アーム**: 視界に入り続けているコードは最初の 1 回だけ受理する。
///    同じコードを再登録したいときは、いったん読取範囲から外して
///    `rearmInterval` 秒経過後にかざし直す
/// 2. **グローバルクールダウン**: 受理直後の `cooldown` 秒間は別のコードも
///    受理しない(書籍の2段 JAN など複数コード同時映り込みの誤登録防止)
///
/// 検出のたびに `register` を呼ぶこと(受理可否によらず「見えている」記録を更新する)。
public final class ScanArbiter {

    private let cooldown: TimeInterval
    private let rearmInterval: TimeInterval

    private var lastSeenAt: [String: Date] = [:]
    private var lastAcceptedAt: Date?

    public init(cooldown: TimeInterval = 1.0, rearmInterval: TimeInterval = 1.0) {
        self.cooldown = cooldown
        self.rearmInterval = rearmInterval
    }

    /// コードの検出を記録し、登録として受理すべきときだけ true を返す。
    @discardableResult
    public func register(payload: String, at now: Date = Date()) -> Bool {
        let seenRecently = lastSeenAt[payload].map {
            now.timeIntervalSince($0) < rearmInterval
        } ?? false
        lastSeenAt[payload] = now

        if seenRecently {
            return false
        }
        if let accepted = lastAcceptedAt, now.timeIntervalSince(accepted) < cooldown {
            return false
        }
        lastAcceptedAt = now
        return true
    }

    /// 判定状態を初期化する(エンジン切替やスキャン画面の開き直し用)
    public func reset() {
        lastSeenAt = [:]
        lastAcceptedAt = nil
    }
}
