import SwiftUI
import VisionKit

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

    /// 直前の受理から一定時間は「別のコードでも」無視する秒数。
    /// 同一コードのみの抑止だと、書籍の2段 JAN(ISBN + 価格コード)が
    /// 交互に受理され続けるため、グローバルに適用する(P3 も同方式にする)
    private let cooldown: TimeInterval = 1.0
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
                        guideBandOverlay
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

    /// 読取帯の外側を暗くし、帯の境界を線で示すガイド
    private var guideBandOverlay: some View {
        GeometryReader { geometry in
            let bandHeight = geometry.size.height * bandRatio
            let inset = (geometry.size.height - bandHeight) / 2
            VStack(spacing: 0) {
                Color.black.opacity(0.45)
                    .frame(height: inset)
                Rectangle()
                    .strokeBorder(.yellow, lineWidth: 2)
                    .frame(height: bandHeight)
                Color.black.opacity(0.45)
                    .frame(height: inset)
            }
        }
        .allowsHitTesting(false)
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

    /// クールダウン付きで読取を受理し、音と振動を鳴らす(P3 の成功フローの先行検証)。
    /// クールダウンはコードの異同を問わずグローバルに効かせる(2段バーコードの交互受理防止)
    private func accept(payload: String, symbology: String) {
        let now = Date()
        if let last = lastAccepted,
           now.timeIntervalSince(last.date) < cooldown {
            return
        }
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
