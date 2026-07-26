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

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: Self.symbologies)],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        context.coordinator.onDetect = onDetect
        guard !scanner.isScanning else { return }
        try? scanner.startScanning()
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
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
