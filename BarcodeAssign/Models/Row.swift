import Foundation
import SwiftData

/// 行の状態
enum RowStatus: Int, Codable {
    case pending = 0
    case registered = 1
    case skipped = 2

    var label: String {
        switch self {
        case .pending: return "未登録"
        case .registered: return "登録済み"
        case .skipped: return "スキップ"
        }
    }
}

/// 取り込んだ表の 1 行
@Model
final class Row {
    /// 元データでの行順
    var sortIndex: Int
    /// 取込時の元データ(不変。コードは barcode に持ち、出力時に合成する)
    var values: [String]
    /// 割り当てたコード
    var barcode: String?
    var statusRaw: Int
    var scannedAt: Date?
    var project: Project?

    var status: RowStatus {
        get { RowStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    init(sortIndex: Int, values: [String]) {
        self.sortIndex = sortIndex
        self.values = values
        self.barcode = nil
        self.statusRaw = RowStatus.pending.rawValue
        self.scannedAt = nil
    }
}

extension Row {
    /// 指定列の値(範囲外は空文字)
    func value(at index: Int) -> String {
        guard index >= 0, index < values.count else { return "" }
        return values[index]
    }
}
