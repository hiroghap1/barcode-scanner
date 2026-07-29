import Foundation

/// アプリ設定(UserDefaults のキーと既定値)。
/// SettingsView の @AppStorage と同じキーを共有する。
enum AppSettings {
    static let soundEnabledKey = "scanSoundEnabled"
    static let hapticsEnabledKey = "scanHapticsEnabled"
    static let cooldownKey = "scanCooldown"

    /// 読み取り成功音を鳴らすか(既定: オン)
    static var isSoundEnabled: Bool {
        UserDefaults.standard.object(forKey: soundEnabledKey) as? Bool ?? true
    }

    /// 読み取り成功時に振動するか(既定: オン)
    static var isHapticsEnabled: Bool {
        UserDefaults.standard.object(forKey: hapticsEnabledKey) as? Bool ?? true
    }

    /// 連続読み取りの間隔(秒)。ScanArbiter の cooldown / rearmInterval に使う(既定: 1.0)
    static var cooldown: Double {
        UserDefaults.standard.object(forKey: cooldownKey) as? Double ?? 1.0
    }
}
