import AnosaKit

extension PlaceStatus {
    /// 一覧の絞り込みに出す名前。
    var title: String {
        switch self {
        case .wantToGo: "行きたい"
        case .visited: "行った"
        case .archived: "アーカイブ"
        }
    }

    /// スワイプでこのステータスへ移すときのボタン名。
    var moveActionTitle: String {
        switch self {
        case .wantToGo: "行きたいに戻す"
        case .visited: "行った"
        case .archived: "アーカイブ"
        }
    }

    var systemImage: String {
        switch self {
        case .wantToGo: "mappin"
        case .visited: "checkmark"
        case .archived: "archivebox"
        }
    }
}
