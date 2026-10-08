import SwiftUI

/// 保存直後に一言だけ出す確認チップ。コンテンツの上に浮かせて使う。
/// ガラス表現（glassEffect）を使うのはこのチップだけにし、ガラスの上には置かない。
public struct SavedConfirmationView: View {
    private let message: String

    public init(message: String = SaveCopy.saved) {
        self.message = message
    }

    public var body: some View {
        Label {
            Text(message)
        } icon: {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.tint)
        }
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect()
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    SavedConfirmationView()
        .tint(AnosaTheme.accent)
}
