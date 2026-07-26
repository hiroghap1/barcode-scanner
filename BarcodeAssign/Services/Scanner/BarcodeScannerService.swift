import Foundation

/// スキャン結果
struct ScanResult: Equatable {
    /// 読み取った値
    let payload: String
    /// シンボロジー(例: "VNBarcodeSymbologyEAN13")
    let symbology: String
}

/// バーコード読取の抽象化。
/// UI 層はこのプロトコルのみに依存し、VisionKit / AVFoundation /
/// 将来の Bluetooth リーダー等は実装の追加で対応する。
/// 本実装は P3。P0 ではスパイク画面(Views/Spike/)で技術検証を行う。
protocol BarcodeScannerService {
    var isAvailable: Bool { get }
    func start(onDetect: @escaping (ScanResult) -> Void)
    func stop()
}
