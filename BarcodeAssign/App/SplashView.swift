import SwiftUI

/// 起動時のスプラッシュ。
/// 「ピ」(三本線なし)が中央に現れ、下端を支点に ±30° 揺れる →
/// 三本線がパッと出現(「ピッ!」の瞬間)→ 残りがフェードインしながら定位置へ合体する。
/// レイヤーはロゴ SVG から同一キャンバスで書き出しているため、重ねると完全に一致する。
/// 「視差効果を減らす」設定時は動きなしの順次フェードにする。
struct SplashView: View {
    /// アニメーション完了時に呼ばれる(呼び出し側でスプラッシュを閉じる)
    let onFinished: () -> Void

    @State private var isPiVisible = false
    @State private var isSparkVisible = false
    @State private var isRestVisible = false
    /// 「ピ」の振り角(下端支点)
    @State private var swingAngle: Double = 0
    /// 構図全体のオフセット。開始時は「ピ」が画面中央に来るよう右へずらしておく
    @State private var compositionOffset: CGFloat = Self.piCenteringOffset

    private let reduceMotion = UIAccessibility.isReduceMotionEnabled

    private static let logoWidth: CGFloat = 280
    /// 「ピ」単体レイヤーの内容中心はキャンバス幅の 39.2% 位置
    private static let piCenteringOffset: CGFloat = logoWidth * (0.5 - 0.3923)
    /// 「ピ」の下端(揺れの支点。キャンバス比)
    private static let piPivot = UnitPoint(x: 0.3923, y: 0.802)
    /// 三本線の付け根(出現時のスケール基準。キャンバス比)
    private static let sparkAnchor = UnitPoint(x: 0.4432, y: 0.1835)

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            ZStack {
                Image("SplashRest")
                    .resizable()
                    .scaledToFit()
                    .opacity(isRestVisible ? 1 : 0)
                Image("SplashSpark")
                    .resizable()
                    .scaledToFit()
                    .opacity(isSparkVisible ? 1 : 0)
                    .scaleEffect(isSparkVisible ? 1.0 : 0.4, anchor: Self.sparkAnchor)
                Image("SplashPiSolo")
                    .resizable()
                    .scaledToFit()
                    .opacity(isPiVisible ? 1 : 0)
                    .rotationEffect(.degrees(swingAngle), anchor: Self.piPivot)
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
            // 動きなしでも出現順(ピ → 三本線 → 残り)は伝える
            compositionOffset = 0
            withAnimation(.easeOut(duration: 0.3)) { isPiVisible = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                withAnimation(.easeOut(duration: 0.2)) { isSparkVisible = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
                withAnimation(.easeOut(duration: 0.35)) { isRestVisible = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.85, execute: onFinished)
            return
        }

        // 1. 「ピ」(三本線なし)が画面中央にポップ表示
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isPiVisible = true
        }
        // 2. 下端を支点にピコピコッと小さく揺れる(±10° で減衰)
        let swings: [(delay: TimeInterval, angle: Double, duration: TimeInterval)] = [
            (0.35, 10, 0.10),
            (0.45, -10, 0.12),
            (0.57, 5, 0.10),
            (0.67, 0, 0.08),
        ]
        for swing in swings {
            DispatchQueue.main.asyncAfter(deadline: .now() + swing.delay) {
                withAnimation(.easeInOut(duration: swing.duration)) {
                    swingAngle = swing.angle
                }
            }
        }
        // 3. 三本線がパッと出現(「ピッ!」の瞬間)→ 余韻をひと呼吸置く
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.78) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                isSparkVisible = true
            }
        }
        // 4. 三本線から 0.4 秒置いて、残りがフェードイン(「ピ」は定位置へスライド)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.35)) {
                isRestVisible = true
                compositionOffset = 0
            }
        }
        // 5. 合体したロゴをひと呼吸見せてから終了(ホームへはゆっくりフェード)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2, execute: onFinished)
    }
}

#Preview {
    SplashView(onFinished: {})
}
