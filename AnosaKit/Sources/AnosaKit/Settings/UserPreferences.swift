import Foundation

/// 利用者が設定画面で変えられる項目。`applied(to:)` で `AnosaSettings` に反映する。
public struct UserPreferences: Hashable, Codable, Sendable {
    /// 1日の通知上限。
    public var dailyNotificationLimit: Int
    /// 通知しない時間帯。開始と終了が同じなら静音なし。
    public var quietHours: QuietHours
    /// 通知する距離（メートル）。
    public var notificationRadiusMeters: Double

    public init(dailyNotificationLimit: Int, quietHours: QuietHours, notificationRadiusMeters: Double) {
        self.dailyNotificationLimit = dailyNotificationLimit
        self.quietHours = quietHours
        self.notificationRadiusMeters = notificationRadiusMeters
    }

    public static let `default` = UserPreferences(
        dailyNotificationLimit: AnosaSettings.default.dailyNotificationLimit,
        quietHours: AnosaSettings.default.quietHours,
        notificationRadiusMeters: AnosaSettings.default.notificationRadiusMeters
    )

    /// 通知上限の選択肢（昇順）。
    public static let dailyNotificationLimitOptions: [Int] = [1, 2, 3]
    /// 通知距離の選択肢（メートル、昇順）。
    public static let notificationRadiusOptions: [Double] = [300, 500, 1000]
    /// 静音時間帯の開始・終了に選べる時（分は 0）。
    public static let quietHourOptions: [Int] = Array(0..<24)

    /// 選択肢にない上限・距離は最も近い選択肢に寄せる（同じ近さなら小さい方）。
    /// 静音の時・分が範囲外なら既定値の同じ項目に戻す。
    public func normalized() -> UserPreferences {
        let fallback = Self.default
        let limit = Self.nearest(
            to: Double(dailyNotificationLimit),
            in: Self.dailyNotificationLimitOptions.map(Double.init)
        ).map { Int($0) } ?? fallback.dailyNotificationLimit
        let radius = notificationRadiusMeters.isFinite
            ? Self.nearest(to: notificationRadiusMeters, in: Self.notificationRadiusOptions) ?? fallback.notificationRadiusMeters
            : fallback.notificationRadiusMeters
        return UserPreferences(
            dailyNotificationLimit: limit,
            quietHours: QuietHours(
                start: Self.normalized(quietHours.start, fallback: fallback.quietHours.start),
                end: Self.normalized(quietHours.end, fallback: fallback.quietHours.end)
            ),
            notificationRadiusMeters: radius
        )
    }

    /// 3 項目を上書きし、リージョンの半径も通知距離に合わせる。他の項目はそのまま。
    public func applied(to settings: AnosaSettings) -> AnosaSettings {
        var result = settings
        result.dailyNotificationLimit = dailyNotificationLimit
        result.quietHours = quietHours
        result.notificationRadiusMeters = notificationRadiusMeters
        result.regionRadiusMeters = notificationRadiusMeters
        return result
    }

    /// `options` は昇順。先に見つかった方を残すため、同じ近さなら小さい方になる。
    private static func nearest(to value: Double, in options: [Double]) -> Double? {
        options.min { abs($0 - value) < abs($1 - value) }
    }

    private static func normalized(_ time: TimeOfDay, fallback: TimeOfDay) -> TimeOfDay {
        TimeOfDay(
            hour: (0..<24).contains(time.hour) ? time.hour : fallback.hour,
            minute: (0..<60).contains(time.minute) ? time.minute : fallback.minute
        )
    }
}

/// 利用者の設定を App Group の UserDefaults に JSON で保存する。
public struct UserPreferencesStore {
    public static let defaultKey = "userPreferences"

    public let defaults: UserDefaults
    public let key: String

    public init(defaults: UserDefaults, key: String = defaultKey) {
        self.defaults = defaults
        self.key = key
    }

    /// App Group の suite。取れなければ `.standard`（この場合アプリと拡張で共有されない）。
    public static func shared() -> UserPreferencesStore {
        UserPreferencesStore(defaults: SharedDefaults.make())
    }

    /// 保存がない・読めないときは既定値。読めたら正規化して返す。
    public func load() -> UserPreferences {
        guard let data = defaults.data(forKey: key),
              let preferences = try? JSONDecoder().decode(UserPreferences.self, from: data)
        else { return .default }
        return preferences.normalized()
    }

    /// 正規化してから保存する。
    public func save(_ preferences: UserPreferences) throws {
        defaults.set(try JSONEncoder().encode(preferences.normalized()), forKey: key)
    }

    /// 保存済みの設定を `base` に反映した設定。
    public func settings(base: AnosaSettings = .default) -> AnosaSettings {
        load().applied(to: base)
    }
}
