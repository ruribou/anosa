import Foundation

public struct NotificationCandidate: Hashable, Sendable {
    public var place: Place
    public var distanceMeters: Double
    public var walkingMinutes: Int

    public init(place: Place, distanceMeters: Double, walkingMinutes: Int) {
        self.place = place
        self.distanceMeters = distanceMeters
        self.walkingMinutes = walkingMinutes
    }
}

public enum DecisionEngine {
    /// 今通知すべき場所を1件返す。なければ nil。
    public static func placeToNotify(
        currentLocation: Coordinate,
        now: Date,
        places: [Place],
        history: [NotificationRecord],
        settings: AnosaSettings = .default,
        openingHours: any OpeningHoursProvider,
        calendar: Calendar
    ) -> NotificationCandidate? {
        if settings.quietHours.contains(now, calendar: calendar) { return nil }

        let todayCount = history.filter { calendar.isDate($0.notifiedAt, inSameDayAs: now) }.count
        if todayCount >= settings.dailyNotificationLimit { return nil }

        var lastNotifiedByPlace: [UUID: Date] = [:]
        for record in history {
            if let existing = lastNotifiedByPlace[record.placeID], existing >= record.notifiedAt { continue }
            lastNotifiedByPlace[record.placeID] = record.notifiedAt
        }

        var best: (candidate: NotificationCandidate, score: Double)?
        for place in places {
            guard place.status == .wantToGo else { continue }
            if let snoozedUntil = place.snoozedUntil, snoozedUntil > now { continue }

            let lastNotified = [place.lastNotifiedAt, lastNotifiedByPlace[place.id]].compactMap { $0 }.max()
            if let lastNotified, now.timeIntervalSince(lastNotified) < settings.cooldown { continue }

            let distance = currentLocation.distance(to: place.coordinate)
            guard distance <= settings.notificationRadiusMeters else { continue }

            guard openingHours.isOpen(place, at: now) else { continue }

            let score = priorityScore(distanceMeters: distance, savedAt: place.savedAt, now: now, settings: settings)
            let candidate = NotificationCandidate(
                place: place,
                distanceMeters: distance,
                walkingMinutes: settings.walkingMinutes(forDistance: distance)
            )
            if let current = best, !isBetter(candidate, score, than: current.candidate, current.score) { continue }
            best = (candidate, score)
        }
        return best?.candidate
    }

    /// 小さいほど優先。距離から、保存からの経過日数（頭打ちあり）に応じたボーナスを差し引く。
    public static func priorityScore(
        distanceMeters: Double,
        savedAt: Date,
        now: Date,
        settings: AnosaSettings
    ) -> Double {
        let ageDays = max(0, now.timeIntervalSince(savedAt)) / (24 * 60 * 60)
        let cappedDays = min(ageDays, max(0, settings.maxAgeBonusDays))
        return distanceMeters - cappedDays * settings.ageBonusMetersPerDay
    }

    private static func isBetter(
        _ lhs: NotificationCandidate, _ lhsScore: Double,
        than rhs: NotificationCandidate, _ rhsScore: Double
    ) -> Bool {
        if lhsScore != rhsScore { return lhsScore < rhsScore }
        if lhs.distanceMeters != rhs.distanceMeters { return lhs.distanceMeters < rhs.distanceMeters }
        return lhs.place.id.uuidString < rhs.place.id.uuidString
    }
}
