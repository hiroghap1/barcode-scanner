import SwiftUI

/// 起動時のスプラッシュ。
/// ロゴをスプリングで表示 → スキャンビームが横切る → 「ピッ」と小さく弾んで終了。
/// 「視差効果を減らす」設定時はフェードのみのシンプル表示にする。
struct SplashView: View {
    /// アニメーション完了時に呼ばれる(呼び出し側でスプラッシュを閉じる)
    let onFinished: () -> Void

    @State private var isLogoVisible = false
    /// ビームの相対位置(ロゴ幅に対する割合。-0.3 で左外、1.3 で右外)
    @State private var beamProgress: CGFloat = -0.3
    @State private var isPopping = false

    private let reduceMotion = UIAccessibility.isReduceMotionEnabled

    /// ビームの色(両モードで発光して見える明るいミント)
    private let beamColor = Color(red: 0x53 / 255.0, green: 0xDF / 255.0, blue: 0xA0 / 255.0)

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            logo
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("ピッと登録")
        .onAppear(perform: run)
    }

    private var logo: some View {
        Image("LogoHeader")
            .resizable()
            .scaledToFit()
            .frame(width: 280)
            .overlay {
                if !reduceMotion {
                    GeometryReader { geometry in
                        beam
                            .frame(height: geometry.size.height * 1.2)
                            .offset(
                                x: geometry.size.width * beamProgress,
                                y: -geometry.size.height * 0.1
                            )
                    }
                }
            }
            .clipped()
            .scaleEffect(isLogoVisible ? (isPopping ? 1.06 : 1.0) : 0.85)
            .opacity(isLogoVisible ? 1 : 0)
            .allowsHitTesting(false)
    }

    private var beam: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        beamColor.opacity(0),
                        beamColor.opacity(0.65),
                        beamColor.opacity(0),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: 70)
            .blur(radius: 2)
    }

    private func run() {
        guard !reduceMotion else {
            withAnimation(.easeOut(duration: 0.4)) { isLogoVisible = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: onFinished)
            return
        }
        // 1. ロゴをスプリングでポップ表示
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            isLogoVisible = true
        }
        // 2. スキャンビームが左から右へ横切る
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.55)) { beamProgress = 1.3 }
        }
        // 3. 読取成功の「ピッ」を思わせる小さな弾み
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.05) {
            withAnimation(.spring(response: 0.18, dampingFraction: 0.5)) { isPopping = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { isPopping = false }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.55, execute: onFinished)
    }
}

#Preview {
    SplashView(onFinished: {})
}
