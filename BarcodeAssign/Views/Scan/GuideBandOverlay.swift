import SwiftUI

/// カメラプレビューの読取帯ガイド。
/// 読取範囲(中央帯)の外側を暗くし、帯の境界を線で示す。
/// regionOfInterest / rectOfInterest の帯と同じ比率で使うこと。
struct GuideBandOverlay: View {
    /// 中央帯の高さ比率
    let bandRatio: CGFloat

    var body: some View {
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
}
