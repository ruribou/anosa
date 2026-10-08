import CoreLocation
import SwiftUI

/// 位置情報の権限について、いま出す案内。
enum LocationGuidance: Equatable {
    /// まだ決めていない → 「使用中のみ」を求める
    case askWhenInUse
    /// 「使用中のみ」で、まだ「常に許可」を求めていない → 価値を説明して求める
    case askAlways
    /// 「常に許可」を断られた（使用中のみのまま）→ 設定アプリへのリンクだけ
    case alwaysDeclined
    /// 許可されていない → 設定アプリへのリンクだけ
    case denied
    /// 「常に許可」済み → 案内しない
    case none

    init(status: CLAuthorizationStatus, hasRequestedAlways: Bool) {
        switch status {
        case .notDetermined: self = .askWhenInUse
        case .authorizedWhenInUse: self = hasRequestedAlways ? .alwaysDeclined : .askAlways
        case .authorizedAlways: self = .none
        case .denied, .restricted: self = .denied
        @unknown default: self = .none
        }
    }
}

extension LocationService {
    var guidance: LocationGuidance {
        LocationGuidance(status: authorizationStatus, hasRequestedAlways: hasRequestedAlwaysAuthorization)
    }
}

/// 権限の 2 段階（使用中のみ → 説明のうえ常に許可）を案内するシート。
struct LocationPermissionView: View {
    @Environment(LocationService.self) private var locationService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: symbolName)
                .font(.largeTitle)
                .foregroundStyle(.tint)
            Text(title)
                .font(.title3.bold())
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
            actions
        }
        .padding(24)
        .presentationDetents([.medium])
    }

    private var guidance: LocationGuidance { locationService.guidance }

    private var symbolName: String {
        switch guidance {
        case .askWhenInUse, .none: "location"
        case .askAlways: "location.fill"
        case .alwaysDeclined, .denied: "location.slash"
        }
    }

    private var title: String {
        switch guidance {
        case .askWhenInUse: "近くに来たら、教えるね"
        case .askAlways: "アプリを閉じていても、教えたい"
        case .alwaysDeclined, .denied: "設定アプリで変えられるよ"
        case .none: "準備できたよ"
        }
    }

    private var message: String {
        switch guidance {
        case .askWhenInUse:
            "保存した場所の近くにいるかを知るために、現在地を使うよ。位置情報は端末の外に出さないよ。"
        case .askAlways:
            "「常に許可」にすると、アプリを開いていないときも、行きたい場所の近くでお知らせできるよ。"
        case .alwaysDeclined:
            "いまはアプリを開いているときだけ教えるね。閉じていても知りたくなったら、設定アプリで「常に」を選んでね。"
        case .denied:
            "位置情報がオフだと、近くに来ても教えられないんだ。使いたくなったら、設定アプリからどうぞ。"
        case .none:
            "行きたい場所の近くに来たら、お知らせするね。"
        }
    }

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: 12) {
            switch guidance {
            case .askWhenInUse:
                primaryButton("位置情報を使う") { locationService.requestWhenInUseAuthorization() }
                laterButton
            case .askAlways:
                primaryButton("常に許可にする") {
                    // 答えを待たずに閉じる（ダイアログの間に「断られた」案内へ切り替わって見えないように）。
                    locationService.requestAlwaysAuthorization()
                    dismiss()
                }
                laterButton
            case .alwaysDeclined, .denied:
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    Link(destination: url) {
                        Text("設定をひらく")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                }
                laterButton
            case .none:
                primaryButton("閉じる") { dismiss() }
            }
        }
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
    }

    private var laterButton: some View {
        Button("いまはいい") { dismiss() }
            .controlSize(.large)
    }
}
