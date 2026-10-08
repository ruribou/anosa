import Foundation

/// 位置が変わったときに判断エンジンを実行し、通知する場所があれば記録する。
@MainActor
public final class LocationEvaluator {
    public let store: PlaceStore
    public let history: NotificationHistoryStore
    public var settings: AnosaSettings
    public let calendar: Calendar
    public let openingHours: any OpeningHoursProvider

    public init(
        store: PlaceStore,
        history: NotificationHistoryStore,
        settings: AnosaSettings = .default,
        calendar: Calendar,
        openingHours: (any OpeningHoursProvider)? = nil
    ) {
        self.store = store
        self.history = history
        self.settings = settings
        self.calendar = calendar
        self.openingHours = openingHours ?? UserInputOpeningHoursProvider(calendar: calendar)
    }

    /// 通知すべき場所があれば記録して返す（記録後の `Place` を入れる）。なければ何もせず nil。
    public func evaluate(currentLocation: Coordinate, now: Date) throws -> NotificationCandidate? {
        let candidate = DecisionEngine.placeToNotify(
            currentLocation: currentLocation,
            now: now,
            places: try store.places(status: .wantToGo),
            history: history.records(),
            settings: settings,
            openingHours: openingHours,
            calendar: calendar
        )
        guard let candidate else { return nil }
        return try record(candidate, now: now)
    }

    /// 通知したことを記録する: `lastNotifiedAt = now`・`notifiedCount + 1` を保存し、履歴に追記する。
    /// 場所がストアにない（削除済み）ときは何もせず nil。
    @discardableResult
    public func record(_ candidate: NotificationCandidate, now: Date) throws -> NotificationCandidate? {
        guard var place = try store.place(id: candidate.place.id) else { return nil }
        place.lastNotifiedAt = now
        place.notifiedCount += 1
        try store.save(place)
        try history.append(NotificationRecord(placeID: place.id, notifiedAt: now), now: now, settings: settings)

        var recorded = candidate
        recorded.place = place
        return recorded
    }
}
