import AnosaKit
import OSLog
import SwiftUI

/// 1日の通知・通知する距離・静かにする時間だけを変える設定画面。
/// 変更のたびに保存し、通知距離が変わったら現在地を取り直してリージョンとスナップショットに反映する。
struct SettingsView: View {
    @Environment(LocationService.self) private var locationService
    @Environment(\.dismiss) private var dismiss
    @State private var preferences: UserPreferences
    private let store: UserPreferencesStore

    private static let logger = Logger(subsystem: "com.example.anosa", category: "settings")

    init(store: UserPreferencesStore = .shared()) {
        self.store = store
        _preferences = State(initialValue: store.load())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("1日の通知", selection: $preferences.dailyNotificationLimit) {
                        ForEach(UserPreferences.dailyNotificationLimitOptions, id: \.self) { limit in
                            Text("\(limit)回まで").tag(limit)
                        }
                    }
                } footer: {
                    Text("通知はひかえめにしてあるよ。")
                }

                Section {
                    Picker("通知する距離", selection: $preferences.notificationRadiusMeters) {
                        ForEach(UserPreferences.notificationRadiusOptions, id: \.self) { radius in
                            Text(DistanceText.format(meters: radius)).tag(radius)
                        }
                    }
                } footer: {
                    Text("このくらい近くに来たら知らせるよ（徒歩\(walkingMinutes)分くらい）。")
                }

                Section {
                    Toggle("静かにする時間", isOn: isQuietHoursEnabled)
                    if preferences.quietHours.isEnabled {
                        Picker("はじまり", selection: hour(\.start)) {
                            hourOptions(excluding: preferences.quietHours.end.hour)
                        }
                        Picker("おわり", selection: hour(\.end)) {
                            hourOptions(excluding: preferences.quietHours.start.hour)
                        }
                    }
                } footer: {
                    Text("この時間は通知しないよ。")
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
            }
            .onChange(of: preferences) { old, new in
                save(new)
                if old.notificationRadiusMeters != new.notificationRadiusMeters {
                    locationService.refresh()
                }
            }
        }
    }

    private var walkingMinutes: Int {
        AnosaSettings.default.walkingMinutes(forDistance: preferences.notificationRadiusMeters)
    }

    /// オフは開始と終了を同じにする（静音なし）。オンに戻したら既定の時間帯にする。
    private var isQuietHoursEnabled: Binding<Bool> {
        Binding {
            preferences.quietHours.isEnabled
        } set: { isEnabled in
            guard isEnabled != preferences.quietHours.isEnabled else { return }
            let start = preferences.quietHours.start
            preferences.quietHours = isEnabled
                ? UserPreferences.default.quietHours
                : QuietHours(start: start, end: start)
        }
    }

    /// 時だけを選ぶ。選んだら分は 0 にする。
    private func hour(_ keyPath: WritableKeyPath<QuietHours, TimeOfDay>) -> Binding<Int> {
        Binding {
            preferences.quietHours[keyPath: keyPath].hour
        } set: { hour in
            preferences.quietHours[keyPath: keyPath] = TimeOfDay(hour: hour)
        }
    }

    /// 開始と終了が同じだと静音なしになるため、もう一方の時は選べないようにする。
    private func hourOptions(excluding excluded: Int) -> some View {
        ForEach(UserPreferences.quietHourOptions.filter { $0 != excluded }, id: \.self) { hour in
            Text("\(hour)時").tag(hour)
        }
    }

    private func save(_ preferences: UserPreferences) {
        do {
            try store.save(preferences)
        } catch {
            Self.logger.error("設定を保存できません: \(error.localizedDescription, privacy: .public)")
        }
    }
}

#Preview {
    SettingsView(store: UserPreferencesStore(defaults: UserDefaults(suiteName: "SettingsPreview") ?? .standard))
        .environment(LocationService(notifier: PlaceNotifier(), watchSync: WatchSyncService()))
}
