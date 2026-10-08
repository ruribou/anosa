import Foundation

/// 判断エンジン・通知に関わるパラメータを1か所に集約した設定。
public struct AnosaSettings: Hashable, Codable, Sendable {
    /// 通知対象とする距離（メートル、境界を含む）。
    public var notificationRadiusMeters: Double
    /// 1日（カレンダー上の同じ日）の通知上限。
    public var dailyNotificationLimit: Int
    /// 同じ場所を再通知するまでの間隔（秒）。
    public var cooldown: TimeInterval
    /// 「あとで」を選んだときのスヌーズ期間（秒）。
    public var laterSnoozeDuration: TimeInterval
    /// 通知しない時間帯。
    public var quietHours: QuietHours
    /// 保存からの経過1日あたり、距離から差し引く優先度ボーナス（メートル）。
    public var ageBonusMetersPerDay: Double
    /// 経過日数ボーナスの頭打ち（日）。
    public var maxAgeBonusDays: Double
    /// 徒歩速度（メートル/分）。
    public var walkingSpeedMetersPerMinute: Double
    /// 同時に監視するリージョン数の上限（リージョン監視の上限 20 に合わせる）。
    public var monitoredRegionLimit: Int
    /// 監視するリージョンの半径（メートル）。
    public var regionRadiusMeters: Double

    public init(
        notificationRadiusMeters: Double,
        dailyNotificationLimit: Int,
        cooldown: TimeInterval,
        laterSnoozeDuration: TimeInterval,
        quietHours: QuietHours,
        ageBonusMetersPerDay: Double,
        maxAgeBonusDays: Double,
        walkingSpeedMetersPerMinute: Double,
        monitoredRegionLimit: Int = AnosaSettings.defaultMonitoredRegionLimit,
        regionRadiusMeters: Double = AnosaSettings.defaultRegionRadiusMeters
    ) {
        self.notificationRadiusMeters = notificationRadiusMeters
        self.dailyNotificationLimit = dailyNotificationLimit
        self.cooldown = cooldown
        self.laterSnoozeDuration = laterSnoozeDuration
        self.quietHours = quietHours
        self.ageBonusMetersPerDay = ageBonusMetersPerDay
        self.maxAgeBonusDays = maxAgeBonusDays
        self.walkingSpeedMetersPerMinute = walkingSpeedMetersPerMinute
        self.monitoredRegionLimit = monitoredRegionLimit
        self.regionRadiusMeters = regionRadiusMeters
    }

    public static let defaultMonitoredRegionLimit = 20
    public static let defaultRegionRadiusMeters: Double = 500

    private enum CodingKeys: String, CodingKey {
        case notificationRadiusMeters
        case dailyNotificationLimit
        case cooldown
        case laterSnoozeDuration
        case quietHours
        case ageBonusMetersPerDay
        case maxAgeBonusDays
        case walkingSpeedMetersPerMinute
        case monitoredRegionLimit
        case regionRadiusMeters
    }

    /// M3 で足した項目は、それより前に保存された JSON にないため既定値で補う。
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        notificationRadiusMeters = try container.decode(Double.self, forKey: .notificationRadiusMeters)
        dailyNotificationLimit = try container.decode(Int.self, forKey: .dailyNotificationLimit)
        cooldown = try container.decode(TimeInterval.self, forKey: .cooldown)
        laterSnoozeDuration = try container.decode(TimeInterval.self, forKey: .laterSnoozeDuration)
        quietHours = try container.decode(QuietHours.self, forKey: .quietHours)
        ageBonusMetersPerDay = try container.decode(Double.self, forKey: .ageBonusMetersPerDay)
        maxAgeBonusDays = try container.decode(Double.self, forKey: .maxAgeBonusDays)
        walkingSpeedMetersPerMinute = try container.decode(Double.self, forKey: .walkingSpeedMetersPerMinute)
        monitoredRegionLimit = try container.decodeIfPresent(Int.self, forKey: .monitoredRegionLimit)
            ?? Self.defaultMonitoredRegionLimit
        regionRadiusMeters = try container.decodeIfPresent(Double.self, forKey: .regionRadiusMeters)
            ?? Self.defaultRegionRadiusMeters
    }

    public static let `default` = AnosaSettings(
        notificationRadiusMeters: 500,
        dailyNotificationLimit: 2,
        cooldown: 7 * 24 * 60 * 60,
        laterSnoozeDuration: 3 * 60 * 60,
        quietHours: QuietHours(start: TimeOfDay(hour: 22), end: TimeOfDay(hour: 8)),
        ageBonusMetersPerDay: 5,
        maxAgeBonusDays: 30,
        walkingSpeedMetersPerMinute: 80
    )

    /// 徒歩分数。切り上げ、最小1分。
    public func walkingMinutes(forDistance meters: Double) -> Int {
        guard walkingSpeedMetersPerMinute > 0 else { return 1 }
        let minutes = (max(0, meters) / walkingSpeedMetersPerMinute).rounded(.up)
        return max(1, Int(minutes))
    }

    /// スヌーズの終了時刻。
    /// - `.today`（今日はやめる）: `now` より後で最初に静音時間が明ける時刻。静音なしの設定では翌日0時。
    /// - `.later`（あとで）: `now + laterSnoozeDuration`。
    public func snoozeEnd(for kind: SnoozeKind, now: Date, calendar: Calendar) -> Date {
        switch kind {
        case .later:
            return now.addingTimeInterval(laterSnoozeDuration)
        case .today:
            if quietHours.isEnabled {
                let components = DateComponents(hour: quietHours.end.hour, minute: quietHours.end.minute, second: 0)
                if let next = calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTime) {
                    return next
                }
            }
            let startOfToday = calendar.startOfDay(for: now)
            return calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now.addingTimeInterval(24 * 60 * 60)
        }
    }
}

public enum SnoozeKind: String, Hashable, Codable, Sendable {
    /// 「今日はやめる」
    case today
    /// 「あとで」
    case later
}
