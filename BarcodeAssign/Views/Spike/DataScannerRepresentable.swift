import SwiftUI
import VisionKit
import Vision

/// VisionKit DataScannerViewController の SwiftUI ラッパー。
/// UPC-A は EAN-13(先頭 0)として検出されるため symbologies に含めない。
struct DataScannerRepresentable: UIViewControllerRepresentable {

    static let symbologies: [VNBarcodeSymbology] = [
        .ean13, .ean8, .upce, .code128, .code39, .qr,
    ]

    var onDetect: (_ payload: String, _ symbology: String) -> Void
    /// 読取範囲を中央帯に制限する高さ比率(nil なら全面)。
    /// 書籍の2段 JAN のように複数コードが同時に映る場合の誤読対策。
    var regionHeightRatio: CGFloat?

    func makeUIViewController(context: Context) -> DataScannerContainerController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: Self.symbologies)],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return DataScannerContainerController(scanner: scanner)
    }

    func updateUIViewController(_ container: DataScannerContainerController, context: Context) {
        context.coordinator.onDetect = onDetect
        container.regionHeightRatio = regionHeightRatio
        guard !container.scanner.isScanning else { return }
        try? container.scanner.startScanning()
    }

    static func dismantleUIViewController(_ container: DataScannerContainerController, coordinator: Coordinator) {
        container.scanner.stopScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onDetect: onDetect)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onDetect: (_ payload: String, _ symbology: String) -> Void

        init(onDetect: @escaping (_ payload: String, _ symbology: String) -> Void) {
            self.onDetect = onDetect
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            for item in addedItems {
                if case .barcode(let barcode) = item, let payload = barcode.payloadStringValue {
                    onDetect(payload, barcode.observation.symbology.rawValue)
                }
            }
        }
    }
}

/// DataScannerViewController を子 VC として保持し、レイアウト確定後に
/// regionOfInterest(ビュー座標系)を適用するためのコンテナ。
final class DataScannerContainerController: UIViewController {
    let scanner: DataScannerViewController

    var regionHeightRatio: CGFloat? {
        didSet {
            guard regionHeightRatio != oldValue else { return }
            view.setNeedsLayout()
        }
    }

    init(scanner: DataScannerViewController) {
        self.scanner = scanner
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(scanner)
        view.addSubview(scanner.view)
        scanner.didMove(toParent: self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scanner.view.frame = view.bounds
        if let ratio = regionHeightRatio {
            let height = view.bounds.height * ratio
            scanner.regionOfInterest = CGRect(
                x: 0,
                y: (view.bounds.height - height) / 2,
                width: view.bounds.width,
                height: height
            )
        } else {
            scanner.regionOfInterest = nil
        }
    }
}
