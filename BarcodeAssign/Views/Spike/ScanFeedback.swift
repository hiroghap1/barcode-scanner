import AudioToolbox
import UIKit

/// スキャン成功時のフィードバック(音 + 振動)
enum ScanFeedback {
    static func playSuccess() {
        AudioServicesPlaySystemSound(1057) // Tink
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
