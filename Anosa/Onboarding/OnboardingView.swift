import SwiftUI

/// 初回起動時だけ出すオンボーディングの完了フラグ（UserDefaults.standard）。
enum OnboardingState {
    static let hasCompletedKey = "onboarding.hasCompleted"
}

/// 「保存したら、忘れていい。」を伝える 3 画面のオンボーディング。
/// どの画面からでも終えられる（最終画面は「はじめる」、それより前は「スキップ」）。
struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var selection = 0

    private let pages = OnboardingPage.all

    var body: some View {
        TabView(selection: $selection) {
            ForEach(pages.indices, id: \.self) { index in
                OnboardingPageView(page: pages[index])
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                Button {
                    if isLastPage {
                        onFinish()
                    } else {
                        withAnimation { selection += 1 }
                    }
                } label: {
                    Text(isLastPage ? "はじめる" : "つぎへ")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)

                Button("スキップ") { onFinish() }
                    .controlSize(.large)
                    .opacity(isLastPage ? 0 : 1)
                    .disabled(isLastPage)
                    .accessibilityHidden(isLastPage)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
    }

    private var isLastPage: Bool { selection == pages.count - 1 }
}

private struct OnboardingPage {
    var symbolName: String
    var title: String
    var message: String

    static let all: [OnboardingPage] = [
        OnboardingPage(
            symbolName: "square.and.arrow.down",
            title: "保存したら、忘れていい。",
            message: "行きたい場所を見つけたら、共有ボタンから Anosa に送るだけ。あとは覚えておくね。"
        ),
        OnboardingPage(
            symbolName: "figure.walk",
            title: "近くに来たら、話しかけるね",
            message: "近くを通ったとき、通知やウィジェット、Apple Watch でそっと知らせるよ。アプリを開かなくていい。"
        ),
        OnboardingPage(
            symbolName: "bell.badge",
            title: "通知は、ひかえめに",
            message: "1日の回数と夜の時間は控えめにしてあるよ。設定でいつでも変えられる。位置情報は端末の外に出さないよ。"
        ),
    ]
}

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: page.symbolName)
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text(page.title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text(page.message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    OnboardingView {}
}
