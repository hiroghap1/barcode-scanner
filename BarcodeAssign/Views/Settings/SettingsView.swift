import SwiftUI

/// 設定画面(ホームの歯車から開くシート)
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(AppSettings.soundEnabledKey) private var isSoundEnabled = true
    @AppStorage(AppSettings.hapticsEnabledKey) private var isHapticsEnabled = true
    @AppStorage(AppSettings.cooldownKey) private var cooldown = 1.0

    private static let cooldownOptions: [Double] = [0.5, 1.0, 1.5, 2.0]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("読み取り成功音", isOn: $isSoundEnabled)
                    Toggle("振動", isOn: $isHapticsEnabled)
                } header: {
                    Text("スキャンのフィードバック")
                } footer: {
                    Text("静かな売り場では音をオフに、騒がしい場所では振動のみ、などの使い分けができます。")
                }

                Section {
                    Picker("読み取り間隔", selection: $cooldown) {
                        ForEach(Self.cooldownOptions, id: \.self) { value in
                            Text(value == 1.0 ? "1秒(標準)" : String(format: "%g秒", value))
                                .tag(value)
                        }
                    }
                } header: {
                    Text("連続読み取り")
                } footer: {
                    Text("読み取り成功後、次の読み取りを受け付けるまでの間隔です。誤って同じ商品を連続登録してしまう場合は長めにしてください。")
                }

                Section("情報") {
                    LabeledContent(
                        "バージョン",
                        value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
                    )
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
