import AnosaKit
import Foundation
import Observation
import OSLog
import WatchConnectivity
import WatchKit
import WidgetKit

/// Watch 側の WatchConnectivity と表示の状態。
/// iPhone から届いたスナップショットを App Group に保存して台帳を照合し、コンプリケーションを更新する。
/// 「もう行った」は台帳に記録して transferUserInfo で iPhone に送る。
@MainActor
@Observable
final class WatchSyncModel: NSObject {
    private(set) var snapshot: LocationSnapshot?
    private(set) var ledger: WatchVisitedLedger

    @ObservationIgnored private let session: WCSession?
    @ObservationIgnored private let snapshotStore = LocationSnapshotStore.shared()
    @ObservationIgnored private let ledgerStore = WatchVisitedLedgerStore.shared()
    /// 最後に取り込んだ辞書の generatedAt。applicationContext とコンプリケーション用 userInfo の到着順は保証されないため、古いものを捨てる。
    @ObservationIgnored private let lastGeneratedAtKey = "watchSyncLastGeneratedAt"
    /// activate 前に押された「もう行った」。activate 完了時に送る。
    @ObservationIgnored private var pendingVisits: [WatchVisitedMessage] = []
    /// hasContentPending が false になるまで完了を待つバックグラウンドタスク。
    @ObservationIgnored private var pendingRefreshTasks: [WKWatchConnectivityRefreshBackgroundTask] = []
    @ObservationIgnored private var contentPendingObservation: NSKeyValueObservation?
    @ObservationIgnored private var isActivating = false

    private nonisolated static let logger = Logger(subsystem: "com.example.anosa", category: "watch")

    override init() {
        session = WCSession.isSupported() ? WCSession.default : nil
        snapshot = LocationSnapshotStore.shared().load()
        ledger = WatchVisitedLedgerStore.shared().load()
        super.init()
    }

    /// 一覧に出す場所（台帳にある場所を除いて近い順に 3 件）。
    var visiblePlaces: [NearbyPlace] {
        guard let snapshot else { return [] }
        return ledger.visiblePlaces(in: snapshot, limit: 3)
    }

    /// 起動時・バックグラウンドタスクを受けたときに呼ぶ。activate 済みなら何もしない。
    func activate() {
        guard let session, !isActivating, session.activationState != .activated else { return }
        isActivating = true
        session.delegate = self
        contentPendingObservation = session.observe(\.hasContentPending) { @Sendable _, _ in
            Task { @MainActor in
                self.completeRefreshTasksIfIdle()
            }
        }
        session.activate()
    }

    /// 「もう行った」。台帳に記録して一覧・コンプリケーションから除き、iPhone に送る。
    func markVisited(_ place: NearbyPlace) {
        let now = Date()
        ledger.markVisited(place.id, at: now)
        do {
            try ledgerStore.save(ledger)
        } catch {
            Self.logger.error("台帳を保存できません: \(error.localizedDescription, privacy: .public)")
        }
        WidgetCenter.shared.reloadAllTimelines()
        send(WatchVisitedMessage(placeID: place.id, visitedAt: now))
    }

    /// WatchConnectivity のバックグラウンドタスク。届いている内容を受け取り終えてから完了する。
    func handle(_ task: WKWatchConnectivityRefreshBackgroundTask) {
        pendingRefreshTasks.append(task)
        activate()
        completeRefreshTasksIfIdle()
    }

    private func send(_ message: WatchVisitedMessage) {
        guard let session else { return }
        guard session.activationState == .activated else {
            pendingVisits.append(message)
            activate()
            return
        }
        session.transferUserInfo(message.userInfo())
        Self.logger.info("iPhone に「もう行った」を送りました")
    }

    private func apply(_ context: WatchSyncContext) {
        let defaults = UserDefaults.standard
        if let last = defaults.object(forKey: lastGeneratedAtKey) as? Date, context.generatedAt <= last {
            return
        }
        do {
            try snapshotStore.save(context.snapshot)
        } catch {
            Self.logger.error("スナップショットを保存できません: \(error.localizedDescription, privacy: .public)")
            return
        }
        defaults.set(context.generatedAt, forKey: lastGeneratedAtKey)
        snapshot = context.snapshot
        ledger = ledgerStore.load().reconciled(with: context, now: Date())
        do {
            try ledgerStore.save(ledger)
        } catch {
            Self.logger.error("台帳を保存できません: \(error.localizedDescription, privacy: .public)")
        }
        WidgetCenter.shared.reloadAllTimelines()
        Self.logger.info("iPhone からスナップショットを受け取りました: \(context.snapshot.places.count) 件")
    }

    private func handleActivation(_ state: WCSessionActivationState, context: WatchSyncContext?, errorDescription: String?) {
        isActivating = false
        if let errorDescription {
            Self.logger.error("WatchConnectivity を開始できません: \(errorDescription, privacy: .public)")
        }
        if state == .activated {
            if let context {
                apply(context)
            }
            let visits = pendingVisits
            pendingVisits = []
            visits.forEach(send)
        }
        completeRefreshTasksIfIdle()
    }

    /// activate が終わり、受け取る内容が残っていなければ、待っているバックグラウンドタスクを完了する。
    /// activate できなかったときも、タスクを残し続けないよう完了する。
    private func completeRefreshTasksIfIdle() {
        guard !pendingRefreshTasks.isEmpty else { return }
        if let session, isActivating || (session.activationState == .activated && session.hasContentPending) {
            return
        }
        let tasks = pendingRefreshTasks
        pendingRefreshTasks = []
        tasks.forEach { $0.setTaskCompletedWithSnapshot(false) }
    }
}

// WCSession の delegate は内部のキューから呼ばれるため、Sendable な値に読み替えてから MainActor へ Task で移る。
extension WatchSyncModel: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        let errorDescription = error?.localizedDescription
        let context = activationState == .activated
            ? WatchSyncContext(applicationContext: session.receivedApplicationContext)
            : nil
        Task { @MainActor in
            self.handleActivation(activationState, context: context, errorDescription: errorDescription)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        receive(applicationContext)
    }

    /// コンプリケーション用の転送（transferCurrentComplicationUserInfo）もここに届く。
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        receive(userInfo)
    }

    private nonisolated func receive(_ dictionary: [String: Any]) {
        guard let context = WatchSyncContext(applicationContext: dictionary) else {
            Self.logger.error("iPhone から読めない辞書が届きました")
            return
        }
        Task { @MainActor in
            self.apply(context)
        }
    }
}
