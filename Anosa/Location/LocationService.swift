import AnosaKit
import CoreLocation
import Observation
import OSLog
import WidgetKit

/// 位置情報の権限・significant-location-change・リージョン監視（CLMonitor）をまとめる。
/// 位置が変わるたびに、スナップショットを保存し、監視するリージョンを入れ替え、判断エンジンで通知を決める。
@MainActor
@Observable
final class LocationService: NSObject {
    /// 権限の状態。画面の案内に使う。
    private(set) var authorizationStatus: CLAuthorizationStatus

    /// 「常に許可」をすでに一度求めたか。システムのダイアログは一度しか出ないため、2 回目以降は設定アプリへ案内する。
    private(set) var hasRequestedAlwaysAuthorization = UserDefaults.standard.bool(forKey: alwaysRequestedKey) {
        didSet { UserDefaults.standard.set(hasRequestedAlwaysAuthorization, forKey: Self.alwaysRequestedKey) }
    }

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private let notifier: PlaceNotifier
    @ObservationIgnored private let watchSync: WatchSyncService
    @ObservationIgnored private let store: PlaceStore
    @ObservationIgnored private let evaluator: LocationEvaluator
    @ObservationIgnored private let snapshotStore = LocationSnapshotStore.shared()
    @ObservationIgnored private let settings: AnosaSettings
    @ObservationIgnored private var monitor: CLMonitor?
    @ObservationIgnored private var monitorTask: Task<Void, Never>?
    /// リージョンの入れ替えを 1 本ずつ順に実行するための直前のタスク。
    @ObservationIgnored private var regionTask: Task<Void, Never>?
    /// 判断と通知を 1 本ずつ順に実行するための直前のタスク。
    @ObservationIgnored private var evaluationTask: Task<Void, Never>?
    @ObservationIgnored private var isStarted = false
    @ObservationIgnored private var isMonitoringSignificantChanges = false

    private nonisolated static let logger = Logger(subsystem: "com.example.anosa", category: "location")
    private static let monitorName = "AnosaPlaces"
    private static let alwaysRequestedKey = "location.hasRequestedAlwaysAuthorization"
    /// リージョン侵入時に、この時間より新しい現在地があればそれで判断する。
    private static let freshLocationInterval: TimeInterval = 2 * 60

    init(notifier: PlaceNotifier, watchSync: WatchSyncService, settings: AnosaSettings = .default) {
        self.notifier = notifier
        self.watchSync = watchSync
        self.settings = settings
        let store = PlaceStore(container: AppContainer.shared)
        self.store = store
        evaluator = LocationEvaluator(
            store: store,
            history: NotificationHistoryStore.shared(),
            settings: settings,
            calendar: .autoupdatingCurrent
        )
        authorizationStatus = manager.authorizationStatus
        super.init()
    }

    /// 起動のたびに呼ぶ（バックグラウンドでの再起動を含む）。CLMonitor は同じ名前で作り直して events を待つ。
    func start() {
        guard !isStarted else { return }
        isStarted = true
        manager.delegate = self
        authorizationStatus = manager.authorizationStatus
        startMonitor()
        startUpdatesIfAuthorized()
    }

    /// アプリが前面に来たときに現在地を 1 回取り直す。
    func refresh() {
        guard isAuthorized else { return }
        manager.requestLocation()
    }

    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func requestAlwaysAuthorization() {
        hasRequestedAlwaysAuthorization = true
        manager.requestAlwaysAuthorization()
    }

    private var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    private func startUpdatesIfAuthorized() {
        guard isAuthorized else { return }
        if !isMonitoringSignificantChanges {
            manager.startMonitoringSignificantLocationChanges()
            isMonitoringSignificantChanges = true
        }
        manager.requestLocation()
        Task { await notifier.requestAuthorization() }
    }

    private func startMonitor() {
        monitorTask = Task { [weak self] in
            let monitor = await CLMonitor(Self.monitorName)
            guard let self else { return }
            self.monitor = monitor
            self.updateRegionsFromLastLocation()
            do {
                for try await event in await monitor.events {
                    self.handle(event)
                }
            } catch {
                Self.logger.error("リージョン監視のイベントを受け取れません: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: - 位置更新

    private func handle(_ location: CLLocation) {
        Self.logger.info("現在地が更新されました")
        let coordinate = Coordinate(location.coordinate)
        let now = Date()
        let places: [Place]
        do {
            places = try store.places(status: .wantToGo)
        } catch {
            Self.logger.error("場所を読めません: \(error.localizedDescription, privacy: .public)")
            return
        }
        saveSnapshot(location: coordinate, at: now, places: places)
        updateRegions(around: coordinate, places: places)
        evaluate(at: coordinate, now: now)
    }

    private func saveSnapshot(location: Coordinate, at date: Date, places: [Place]) {
        let snapshot = LocationSnapshot.make(location: location, capturedAt: date, places: places, settings: settings)
        do {
            try snapshotStore.save(snapshot)
        } catch {
            Self.logger.error("スナップショットを保存できません: \(error.localizedDescription, privacy: .public)")
            return
        }
        // ウィジェットの Timeline は .never なので、保存したスナップショットを出すにはここで更新を頼む。
        WidgetCenter.shared.reloadAllTimelines()
        Self.logger.info("ウィジェットの更新を依頼しました")
        watchSync.send(snapshot)
    }

    /// 通知の許可を確かめてから判断する。許可がなければ通知が出ないので、判断も記録もしない
    /// （記録するとクールダウンと 1 日の上限を消費してしまうため）。
    /// 許可の取得は async なので、前の判断の完了を待って位置更新の順に 1 本ずつ実行する。
    private func evaluate(at location: Coordinate, now: Date) {
        let previous = evaluationTask
        evaluationTask = Task { [weak self] in
            await previous?.value
            guard let self else { return }
            await self.evaluateIfNotificationsAllowed(at: location, now: now)
        }
    }

    private func evaluateIfNotificationsAllowed(at location: Coordinate, now: Date) async {
        guard await notifier.canPost() else {
            Self.logger.info("通知が許可されていないため判断しません")
            return
        }
        let candidate: NotificationCandidate?
        do {
            candidate = try evaluator.evaluate(currentLocation: location, now: now)
        } catch {
            Self.logger.error("通知の判断に失敗しました: \(error.localizedDescription, privacy: .public)")
            return
        }
        guard let candidate else {
            Self.logger.info("通知する場所はありません")
            return
        }
        Self.logger.info("近くの場所を通知します")
        await notifier.post(candidate)
    }

    // MARK: - リージョン監視

    /// 監視の入れ替えは前の入れ替えが終わってから行う（CLMonitor への操作が交互に混ざらないように）。
    private func updateRegions(around location: Coordinate, places: [Place]) {
        let previous = regionTask
        regionTask = Task { [weak self] in
            await previous?.value
            guard let self, let monitor = self.monitor else { return }
            await self.applyRegionPlan(monitor: monitor, location: location, places: places)
        }
    }

    /// CLMonitor の用意より先に届いた位置更新の分を、用意ができたところで反映する。
    private func updateRegionsFromLastLocation() {
        guard let location = manager.location else { return }
        do {
            updateRegions(around: Coordinate(location.coordinate), places: try store.places(status: .wantToGo))
        } catch {
            Self.logger.error("場所を読めません: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func applyRegionPlan(monitor: CLMonitor, location: Coordinate, places: [Place]) async {
        let radius = settings.regionRadiusMeters
        var monitored = Set(await monitor.identifiers)
        // 半径が変わったリージョンは外して張り直す（同じ識別子のままだと RegionPlanner は追加しないため）。
        for identifier in monitored {
            guard let condition = await monitor.record(for: identifier)?.condition
                as? CLMonitor.CircularGeographicCondition,
                condition.radius != radius else { continue }
            await monitor.remove(identifier)
            monitored.remove(identifier)
        }

        let plan = RegionPlanner.plan(
            currentLocation: location,
            places: places,
            monitoredIdentifiers: monitored,
            settings: settings
        )
        for identifier in plan.toRemove {
            await monitor.remove(identifier)
        }
        for region in plan.toAdd {
            let condition = CLMonitor.CircularGeographicCondition(
                center: CLLocationCoordinate2D(region.center),
                radius: region.radiusMeters
            )
            await monitor.add(condition, identifier: region.identifier)
        }
        Self.logger.info("リージョンを入れ替えました: 追加 \(plan.toAdd.count) 件・削除 \(plan.toRemove.count) 件・監視 \(plan.desired.count) 件")
    }

    private func handle(_ event: CLMonitor.Event) {
        guard event.state == .satisfied,
              let placeID = RegionIdentifier.placeID(from: event.identifier) else { return }
        Self.logger.info("リージョンに入りました")
        let now = Date()
        let location: Coordinate
        if let current = manager.location,
           current.horizontalAccuracy >= 0,
           now.timeIntervalSince(current.timestamp) <= Self.freshLocationInterval {
            location = Coordinate(current.coordinate)
        } else if let place = try? store.place(id: placeID) {
            // 新しい現在地がなければ、入ったリージョンの中心（場所の座標）にいるとみなす。
            location = place.coordinate
        } else {
            return
        }
        evaluate(at: location, now: now)
    }
}

extension LocationService: CLLocationManagerDelegate {
    // CLLocationManager はメインスレッドで作っているため、delegate もメインスレッドで呼ばれる。
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        MainActor.assumeIsolated {
            authorizationStatus = status
            startUpdatesIfAuthorized()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        MainActor.assumeIsolated {
            handle(location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        Self.logger.error("現在地を取得できません: \(error.localizedDescription, privacy: .public)")
    }
}

private extension Coordinate {
    init(_ coordinate: CLLocationCoordinate2D) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}

private extension CLLocationCoordinate2D {
    init(_ coordinate: Coordinate) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}
