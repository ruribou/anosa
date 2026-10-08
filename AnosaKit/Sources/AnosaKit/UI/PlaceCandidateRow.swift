import SwiftUI

/// 場所の検索候補 1 行。手動追加（iOS アプリ）と Share Extension の候補選択で共通に使う。
public struct PlaceCandidateRow: View {
    private let candidate: PlaceCandidate

    public init(candidate: PlaceCandidate) {
        self.candidate = candidate
    }

    public var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(candidate.name)
                    .foregroundStyle(.primary)
                if let address = candidate.address {
                    Text(address)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        } icon: {
            Image(systemName: "mappin.circle.fill")
                .foregroundStyle(.tint)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    List {
        PlaceCandidateRow(candidate: PlaceCandidate(
            name: "架空の喫茶店",
            coordinate: Coordinate(latitude: 0, longitude: 0),
            address: "架空県架空市 1-2-3"
        ))
        PlaceCandidateRow(candidate: PlaceCandidate(name: "住所のない場所", coordinate: Coordinate(latitude: 0, longitude: 0)))
    }
    .tint(AnosaTheme.accent)
}
