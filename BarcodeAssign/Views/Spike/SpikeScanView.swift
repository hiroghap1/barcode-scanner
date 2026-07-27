import SwiftUI
import VisionKit
import BarcodeAssignCore

/// P0 スキャン技術スパイク画面。
///
/// 検証項目(結果は docs/notes/scanner-spike.md に記録):
/// - 対応 7 シンボロジーが読み取れるか(UPC-A は EAN-13 として検出される)
/// - 読取速度・精度(小さいバーコード、かすれ)
/// - VisionKit 非対応端末での AVFoundation フォールバック
/// - 同一コード連続検出のクールダウン挙動
struct SpikeScanView: View {

    enum Engine: String, CaseIterable, Identifiable {
        case visionKit = "VisionKit"
        case avFoundation = "AVFoundation"
        var id: String { rawValue }
    }

    struct SpikeScan: Identifiable, Equatable {
        let id = UUID()
        let payload: String
        let symbology: String
        let date: Date
    }

    @State private var engine: Engine = DataScannerViewController.isSupported ? .visionKit : .avFoundation
    @State private var scans: [SpikeScan] = []
    @State private var lastAccepted: SpikeScan?
    /// 読取範囲を中央帯に制限する(書籍の2段 JAN が交互に読まれる問題の対策検証)
    @State private var restrictToCenterBand = true
    /// 受理判定(再アーム + グローバルクールダウン)。詳細は ScanArbiter を参照
    @State private var arbiter = ScanArbiter()

    /// 中央帯の高さ比率
    private let bandRatio: CGFloat = 0.35

    var body: some View {
        VStack(spacing: 0) {
            Picker("エンジン", selection: $engine) {
                ForEach(Engine.allCases) { engine in
                    Text(engine.rawValue).tag(engine)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            Toggle("読取範囲を中央に制限(2段バーコード対策)", isOn: $restrictToCenterBand)
                .font(.footnote)
                .padding(.horizontal)
                .padding(.bottom, 8)

            scannerView
                .frame(maxWidth: .infinity)
                .frame(height: 320)
                .background(Color.black)
                .overlay {
                    if restrictToCenterBand {
                        GuideBandOverlay(bandRatio: bandRatio)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

            resultPanel

            List(scans.reversed()) { scan in
                VStack(alignment: .leading, spacing: 2) {
                    Text(scan.payload).font(.body.monospaced())
                    Text(scan.symbology)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .listStyle(.plain)
        }
        .navigationTitle("スキャンスパイク")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: engine) {
            arbiter.reset()
        }
    }

    @ViewBuilder
    private var scannerView: some View {
        let ratio: CGFloat? = restrictToCenterBand ? bandRatio : nil
        switch engine {
        case .visionKit:
            if DataScannerViewController.isSupported {
                DataScannerRepresentable(
                    onDetect: { payload, symbology in
                        accept(payload: payload, symbology: symbology)
                    },
                    regionHeightRatio: ratio
                )
            } else {
                ContentUnavailableView(
                    "VisionKit 非対応端末",
                    systemImage: "camera.badge.ellipsis",
                    description: Text("A12 Bionic 以降が必要です。AVFoundation を選択してください。")
                )
                .foregroundStyle(.white)
            }
        case .avFoundation:
            AVFScannerRepresentable(
                onDetect: { payload, symbology in
                    accept(payload: payload, symbology: symbology)
                },
                regionHeightRatio: ratio
            )
        }
    }

    private var resultPanel: some View {
        VStack(spacing: 4) {
            Text(lastAccepted?.payload ?? "バーコードをかざしてください")
                .font(.title3.monospaced().bold())
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(lastAccepted.map { "\($0.symbology) ・ 計\(scans.count)件" } ?? " ")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    /// 検出を ScanArbiter で判定し、受理時のみ記録して音と振動を鳴らす
    /// (P3 の成功フローの先行検証)。
    /// - 視界に入り続けている同一コードは 1 回だけ受理(再登録は枠外に出してかざし直す)
    /// - 受理直後 1 秒間は別のコードも受理しない(2段バーコードの交互受理防止)
    private func accept(payload: String, symbology: String) {
        let now = Date()
        guard arbiter.register(payload: payload, at: now) else { return }
        let scan = SpikeScan(payload: payload, symbology: symbology, date: now)
        lastAccepted = scan
        scans.append(scan)
        ScanFeedback.playSuccess()
    }
}

#Preview {
    NavigationStack {
        SpikeScanView()
    }
}
