import SwiftUI

/// 起動時のスプラッシュ。
/// 「ピ」だけが中央にポップ表示 → 左右にピッと揺れる →
/// 残り(アイコン・ッと登録・下線)がフェードインしながら「ピ」が定位置へスライドする。
/// レイヤーはロゴ SVG から同一キャンバスで書き出しているため、重ねると完全に一致する。
/// 「視差効果を減らす」設定時はロゴ全体のフェードのみにする。
struct SplashView: View {
    /// アニメーション完了時に呼ばれる(呼び出し側でスプラッシュを閉じる)
    let onFinished: () -> Void

    @State private var isPiVisible = false
    @State private var isRestVisible = false
    /// 「ピ」の揺れ(左右のオフセット)
    @State private var shakeOffset: CGFloat = 0
    /// 構図全体のオフセット。開始時は「ピ」が画面中央に来るよう右へずらしておく
    @State private var compositionOffset: CGFloat = Self.piCenteringOffset

    private let reduceMotion = UIAccessibility.isReduceMotionEnabled

    private static let logoWidth: CGFloat = 280
    /// 「ピ」レイヤーの内容中心はキャンバス幅の約41%位置にあるため、
    /// 画面中央に見せるには (0.5 - 0.41) × 表示幅 ぶん右へずらす
    private static let piCenteringOffset: CGFloat = logoWidth * (0.5 - 0.41)

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            ZStack {
                Image("SplashRest")
                    .resizable()
                    .scaledToFit()
                    .opacity(isRestVisible ? 1 : 0)
                Image("SplashPi")
                    .resizable()
                    .scaledToFit()
                    .opacity(isPiVisible ? 1 : 0)
                    .offset(x: shakeOffset)
            }
            .frame(width: Self.logoWidth)
            .scaleEffect(isPiVisible ? 1.0 : 0.85)
            .offset(x: compositionOffset)
            .allowsHitTesting(false)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("ピッと登録")
        .onAppear(perform: run)
    }

    private func run() {
        guard !reduceMotion else {
            compositionOffset = 0
            withAnimation(.easeOut(duration: 0.4)) {
                isPiVisible = true
                isRestVisible = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: onFinished)
            return
        }
        // 1. 「ピ」が画面中央にポップ表示
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            isPiVisible = true
        }
        // 2. 左右にピッと揺れる
        let shakeSteps: [(delay: TimeInterval, offset: CGFloat)] = [
            (0.55, -12), (0.67, 12), (0.79, 0),
        ]
        for step in shakeSteps {
            DispatchQueue.main.asyncAfter(deadline: .now() + step.delay) {
                withAnimation(.easeInOut(duration: 0.12)) { shakeOffset = step.offset }
            }
        }
        // 3. 残りがフェードインし、「ピ」は定位置へスライド
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.5)) {
                isRestVisible = true
                compositionOffset = 0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: onFinished)
    }
}

#Preview {
    SplashView(onFinished: {})
}
