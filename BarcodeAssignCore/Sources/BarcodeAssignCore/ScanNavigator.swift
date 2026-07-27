import Foundation

/// スキャン画面の行送りロジック。
/// 「登録のたびに次の未登録行へ自動移動する」際の移動先を決める。
public enum ScanNavigator {

    /// current の次から末尾へ、見つからなければ先頭から current の直前まで
    /// 巻き戻って、最初の未登録行のインデックスを返す(current 自身は除く)。
    /// 未登録行がなければ nil(全行完了)。
    /// current が負なら先頭から、範囲超過なら最終行扱いで探す。
    public static func nextPendingIndex(isPending: [Bool], after current: Int) -> Int? {
        guard !isPending.isEmpty else { return nil }
        guard current >= 0 else { return isPending.firstIndex(of: true) }
        let count = isPending.count
        let start = min(current, count - 1)
        for offset in 1..<count {
            let index = (start + offset) % count
            if isPending[index] { return index }
        }
        return nil
    }

    /// 先頭から最初の未登録行(スキャン開始位置の補正用)。
    /// current が未登録ならそのまま current を返す。
    public static func startIndex(isPending: [Bool], preferring current: Int) -> Int? {
        guard !isPending.isEmpty else { return nil }
        if current >= 0, current < isPending.count, isPending[current] {
            return current
        }
        return isPending.firstIndex(of: true)
    }
}
