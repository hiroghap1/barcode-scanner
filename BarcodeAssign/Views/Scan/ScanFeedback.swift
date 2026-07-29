import AudioToolbox
import UIKit

/// スキャン成功時のフィードバック(音 + 振動)。設定でそれぞれオフにできる
enum ScanFeedback {
    static func playSuccess() {
        if AppSettings.isSoundEnabled {
            AudioServicesPlaySystemSound(1057) // Tink
        }
        if AppSettings.isHapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}
