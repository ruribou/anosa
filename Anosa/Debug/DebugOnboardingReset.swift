#if DEBUG
import Foundation
import OSLog

/// スクリーンショット用に、オンボーディングをもう一度出すための DEBUG ビルドだけの導線。
/// 起動引数 `-AnosaResetOnboarding YES` で完了フラグを消す。
@MainActor
enum DebugOnboardingReset {
    static let argumentKey = "AnosaResetOnboarding"

    private static let logger = Logger(subsystem: "com.example.anosa", category: "debug")

    static func resetFromLaunchArguments(defaults: UserDefaults = .standard) {
        guard defaults.bool(forKey: argumentKey) else { return }
        defaults.removeObject(forKey: OnboardingState.hasCompletedKey)
        logger.info("オンボーディングの完了フラグを消しました")
    }
}
#endif
