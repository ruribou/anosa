import Foundation
import SwiftData

/// SwiftData のコンテナ生成。iOS アプリ・Share Extension・App Intent で同じストアを共有する。
public enum AnosaStore {
    /// プレースホルダー。実際の App Group ID は署名とあわせて手動で設定する。
    public static let appGroupIdentifier = "group.com.example.anosa"
    public static let storeFileName = "Anosa.store"

    public static let schema = Schema([PlaceEntity.self])

    /// `inMemory` が false のときは App Group コンテナ内の `Anosa.store` を使う。
    /// App Group が使えない環境（署名なしのシミュレータなど）では ModelConfiguration の既定の場所に保存する。
    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else if let url = sharedStoreURL() {
            configuration = ModelConfiguration(schema: schema, url: url)
        } else {
            configuration = ModelConfiguration(schema: schema)
        }
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// App Group コンテナ内のストアの場所。取得できなければ nil。
    public static func sharedStoreURL() -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appending(path: storeFileName)
    }
}
