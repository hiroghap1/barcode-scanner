import SwiftUI
import AVFoundation

/// AVFoundation ベースのスキャナ(VisionKit 非対応端末向けフォールバック)。
/// EAN-13 の検出は UPC-A も包含する。
struct AVFScannerRepresentable: UIViewControllerRepresentable {
    var onDetect: (_ payload: String, _ symbology: String) -> Void

    func makeUIViewController(context: Context) -> AVFScannerViewController {
        let controller = AVFScannerViewController()
        controller.onDetect = onDetect
        return controller
    }

    func updateUIViewController(_ controller: AVFScannerViewController, context: Context) {
        controller.onDetect = onDetect
    }
}

final class AVFScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    static let metadataTypes: [AVMetadataObject.ObjectType] = [
        .ean13, .ean8, .upce, .code128, .code39, .qr,
    ]

    var onDetect: ((_ payload: String, _ symbology: String) -> Void)?

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "avf-scanner-session")
    private var previewLayer: AVCaptureVideoPreviewLayer?
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
        }
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
