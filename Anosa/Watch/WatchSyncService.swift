import AnosaKit
import Foundation
import OSLog
import WatchConnectivity
import WidgetKit

/// iPhone 側の WatchConnectivity。
/// スナップショットを applicationContext（とコンプリケーション用 userInfo）で Watch に送り、
/// Watch から届いた「もう行った」を場所に反映してスナップショットを作り直す。
@MainActor
final class WatchSyncService: NSObject {
    /// コンプリケーション用の転送を重ねないための、前回送った内容（いちばん近い場所と徒歩分）。
    private struct ComplicationKey: Equatable {
        var placeID: UUID?
        var walkingMinutes: Int?

        init(_ snapshot: LocationSnapshot) {
            placeID = snapshot.places.first?.id
            walkingMinutes = snapshot.places.first?.walkingMinutes
        }
    }

    private let session: WCSession?
    private let store: PlaceStore
    private let snapshotStore = LocationSnapshotStore.shared()
    /// 使うたびに読む設定（設定画面での変更を再起動なしで反映するため）。
    private let settings: @MainActor () -> AnosaSettings
    /// activate が終わる前に送ろうとした最後の 1 件。activate 完了時に送る。
    private var pendingSnapshot: LocationSnapshot?
    private var lastComplicationKey: ComplicationKey?
    private var isActivating = false

    private nonisolated static let logger = Logger(subsystem: "com.example.anosa", category: "watch")

    init(settings: @escaping @MainActor () -> AnosaSettings = { UserPreferencesStore.shared().settings() }) {
        session = WCSession.isSupported() ? WCSession.default : nil
        store = PlaceStore(container: AppContainer.shared)
        self.settings = settings
        super.init()
    }

    /// 起動のたびに呼ぶ。保存済みのスナップショットがあれば、activate 完了後に一度送る。
    func activate() {
        guard let session, !isActivating else { return }
        isActivating = true
        if pendingSnapshot == nil {
            pendingSnapshot = snapshotStore.load()
        }
        session.delegate = self
        session.activate()
    }

    /// スナップショットを Watch に送る。activate 前なら最後の 1 件を保持して、activate 完了時に送る。
    func send(_ snapshot: LocationSnapshot) {
        guard let session else { return }
        guard session.activationState == .activated else {
            pendingSnapshot = snapshot
            return
        }
        guard session.isPaired, session.isWatchAppInstalled else { return }

        let context: [String: Any]
        do {
            context = try WatchSyncContext(snapshot: snapshot, generatedAt: Date()).applicationContext()
            try session.updateApplicationContext(context)
            Self.logger.info("Watch にスナップショットを送りました: \(snapshot.places.count) 件")
        } catch {
            Self.logger.error("Watch にスナップショットを送れません: \(error.localizedDescription, privacy: .public)")
            return
        }
        transferComplicationIfNeeded(context, snapshot: snapshot, session: session)
    }

    /// コンプリケーションを早く更新するため、同じ辞書を 1 日の予算の範囲で送る。
    /// 予算を使い切らないよう、いちばん近い場所と徒歩分が前回と同じなら送らない。
    private func transferComplicationIfNeeded(_ context: [String: Any], snapshot: LocationSnapshot, session: WCSession) {
        guard session.isComplicationEnabled, session.remainingComplicationUserInfoTransfers > 0 else { return }
        let key = ComplicationKey(snapshot)
        guard key != lastComplicationKey else { return }
        session.transferCurrentComplicationUserInfo(context)
        lastComplicationKey = key
        Self.logger.info("コンプリケーション用に送りました（残り \(session.remainingComplicationUserInfoTransfers) 回）")
    }

    private func handleActivation(_ state: WCSessionActivationState, errorDescription: String?) {
        isActivating = false
        if let errorDescription {
            Self.logger.error("WatchConnectivity を開始できません: \(errorDescription, privacy: .public)")
        }
        guard state == .activated, let snapshot = pendingSnapshot else { return }
        pendingSnapshot = nil
        send(snapshot)
    }

    private func handleWatchStateChange() {
        guard let session, session.activationState == .activated,
              session.isPaired, session.isWatchAppInstalled,
              let snapshot = snapshotStore.load() else { return }
        send(snapshot)
    }

    /// Watch の「もう行った」を反映し、最後のスナップショットを同じ現在地のまま作り直して保存し、iOS のウィジェットの更新を頼んで Watch に送る。
    /// 該当する場所がなくても作り直して送る（Watch 側の台帳が反映済みとして消せるように）。
    private func applyVisited(_ message: WatchVisitedMessage) {
        let settings = self.settings()
        do {
            try NotificationActionHandler.apply(
                .visited,
                placeID: message.placeID,
                now: Date(),
                store: store,
                settings: settings,
                calendar: .autoupdatingCurrent
            )
            Self.logger.info("Watch の「もう行った」を反映しました")
        } catch {
            Self.logger.error("Watch の「もう行った」を反映できません: \(error.localizedDescription, privacy: .public)")
            return
        }
        guard let snapshot = snapshotStore.load() else { return }
        let refreshed: LocationSnapshot
        do {
            refreshed = snapshot.refreshed(places: try store.places(status: .wantToGo), settings: settings)
            try snapshotStore.save(refreshed)
        } catch {
            Self.logger.error("スナップショットを作り直せません: \(error.localizedDescription, privacy: .public)")
            return
        }
        // ウィジェットの Timeline は .never なので、作り直したスナップショットを出すにはここで更新を頼む。
        WidgetCenter.shared.reloadAllTimelines()
        Self.logger.info("ウィジェットの更新を依頼しました")
        send(refreshed)
    }
}

// WCSession の delegate は内部のキューから呼ばれるため、MainActor へは Task で移る。
extension WatchSyncService: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        let errorDescription = error?.localizedDescription
        Task { @MainActor in
            self.handleActivation(activationState, errorDescription: errorDescription)
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        Self.logger.info("WatchConnectivity が非アクティブになりました")
    }

    /// Watch の切り替え後は、新しい Watch 向けに activate し直す。
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        Self.logger.info("WatchConnectivity を再開します")
        Task { @MainActor in
            self.activate()
        }
    }

    /// Watch アプリが入った・ペアリングが変わったときに、最後のスナップショットを送り直す。
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.handleWatchStateChange()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let message = WatchVisitedMessage(userInfo: userInfo) else {
            Self.logger.error("Watch から読めない userInfo が届きました")
            return
        }
        Task { @MainActor in
            self.applyVisited(message)
        }
    }
}
