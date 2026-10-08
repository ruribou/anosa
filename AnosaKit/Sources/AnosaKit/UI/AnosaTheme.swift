import SwiftUI
#if os(iOS)
import UIKit
#endif

/// アプリ内の色の定義。アクセントカラーはここだけで決め、iOS アプリと Share Extension のルートで `.tint` に渡す。
/// Watch・ウィジェットには使わない（Watch は標準 UI、ウィジェットはシステムの tint に任せる）。
public enum AnosaTheme {
    /// アイコンの背景（コーラル、sRGB 0.95, 0.42, 0.30）に合わせた色。
    /// ライトは白地で文字・ボタンとして読める濃さ（白とのコントラスト約 4.7:1）、ダークは黒地で沈まないよう少し明るくする。
    /// ライト / ダークの切り替え（UIColor の dynamic provider）は iOS だけ。ほか（macOS の swift test・watchOS）はライトの値。
    public static let accent: Color = {
        #if os(iOS)
        Color(uiColor: UIColor { traits in
            let rgb = traits.userInterfaceStyle == .dark ? darkAccent : lightAccent
            return UIColor(red: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1)
        })
        #else
        Color(red: lightAccent.red, green: lightAccent.green, blue: lightAccent.blue)
        #endif
    }()

    private static let lightAccent = (red: 0.78, green: 0.29, blue: 0.17)
    private static let darkAccent = (red: 1.0, green: 0.54, blue: 0.42)
}
