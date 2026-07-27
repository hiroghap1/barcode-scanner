import SwiftUI
import AVFoundation

/// AVFoundation ベースのスキャナ(VisionKit 非対応端末向けフォールバック)。
/// EAN-13 の検出は UPC-A も包含する。
struct AVFScannerRepresentable: UIViewControllerRepresentable {
    var onDetect: (_ payload: String, _ symbology: String) -> Void
    /// 読取範囲を中央帯に制限する高さ比率(nil なら全面)。
    /// 書籍の2段 JAN のように複数コードが同時に映る場合の誤読対策。
    var regionHeightRatio: CGFloat?

    func makeUIViewController(context: Context) -> AVFScannerViewController {
        let controller = AVFScannerViewController()
        controller.onDetect = onDetect
        controller.regionHeightRatio = regionHeightRatio
        return controller
    }

    func updateUIViewController(_ controller: AVFScannerViewController, context: Context) {
        controller.onDetect = onDetect
        controller.regionHeightRatio = regionHeightRatio
    }
}

final class AVFScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    static let metadataTypes: [AVMetadataObject.ObjectType] = [
        .ean13, .ean8, .upce, .code128, .code39, .qr,
    ]

    var onDetect: ((_ payload: String, _ symbology: String) -> Void)?

    var regionHeightRatio: CGFloat? {
        didSet {
            guard regionHeightRatio != oldValue else { return }
            updateRectOfInterest()
        }
    }

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "avf-scanner-session")
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var metadataOutput: AVCaptureMetadataOutput?
    private var isConfigured = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        previewLayer = layer
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
        updateRectOfInterest()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard granted else { return }
                self?.startSession()
            }
        default:
            showPermissionDeniedLabel()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sessionQueue.async { [session] in
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    private func startSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.configureIfNeeded()
            if !self.session.isRunning {
                self.session.startRunning()
            }
            // rectOfInterest の座標変換はセッション稼働後でないと正しく計算できない
            DispatchQueue.main.async {
                self.updateRectOfInterest()
            }
        }
    }

    /// 読取範囲を中央帯へ制限する(nil なら全面)。
    /// rectOfInterest はメタデータ出力座標系のため、プレビュー層の変換 API を経由する。
    private func updateRectOfInterest() {
        guard let output = metadataOutput, let layer = previewLayer, session.isRunning else { return }
        guard let ratio = regionHeightRatio else {
            output.rectOfInterest = CGRect(x: 0, y: 0, width: 1, height: 1)
            return
        }
        let bounds = layer.bounds
        guard bounds.height > 0 else { return }
        let bandHeight = bounds.height * ratio
        let bandRect = CGRect(
            x: 0,
            y: (bounds.height - bandHeight) / 2,
            width: bounds.width,
            height: bandHeight
        )
        output.rectOfInterest = layer.metadataOutputRectConverted(fromLayerRect: bandRect)
    }

    private func configureIfNeeded() {
        guard !isConfigured else { return }
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        guard
            let device = AVCaptureDevice.default(for: .video),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else { return }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = Self.metadataTypes.filter {
            output.availableMetadataObjectTypes.contains($0)
        }
        metadataOutput = output
        isConfigured = true
    }

    private func showPermissionDeniedLabel() {
        let label = UILabel()
        label.text = "カメラへのアクセスが許可されていません。\n設定アプリから許可してください。"
        label.textColor = .white
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 16),
        ])
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        for object in metadataObjects {
            guard
                let readable = object as? AVMetadataMachineReadableCodeObject,
                let payload = readable.stringValue
            else { continue }
            onDetect?(payload, readable.type.rawValue)
        }
    }
}
