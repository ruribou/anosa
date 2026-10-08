import AnosaKit
import AppIntents

/// ショートカット / Siri の「Anosaに保存」。場所名で検索し、先頭の候補をそのまま保存する。
struct SaveToAnosaIntent: AppIntent {
    static let title: LocalizedStringResource = "Anosaに保存"
    static let description = IntentDescription("場所の名前で検索して、行きたい場所に保存します。")

    @Parameter(title: "場所の名前")
    var placeName: String

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$placeName)をAnosaに保存")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let query = PlaceQuery(text: placeName.trimmingCharacters(in: .whitespacesAndNewlines))
        guard let candidate = try await PlaceSearch.candidates(for: query, limit: 1).first else {
            throw SaveToAnosaError.notFound
        }
        try PlaceStore(context: AppContainer.shared.mainContext).save(candidate.makePlace())
        return .result(dialog: IntentDialog(LocalizedStringResource(stringLiteral: SaveCopy.saved)))
    }
}

enum SaveToAnosaError: Error, CustomLocalizedStringResourceConvertible {
    case notFound

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .notFound: LocalizedStringResource(stringLiteral: SaveCopy.notFound)
        }
    }
}
