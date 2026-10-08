import AnosaKit
import OSLog
import SwiftData

/// アプリ本体と App Intent で共有する SwiftData のコンテナ。
/// PlaceStore(context:) はコンテナを保持しないため、ここでプロセスの間保持する。
@MainActor
enum AppContainer {
    static let shared: ModelContainer = make()

    private static let logger = Logger(subsystem: "com.example.anosa", category: "store")

    /// 永続ストアを開けなければインメモリで起動する（保存内容は終了時に消えるが、クラッシュはさせない）。
    private static func make() -> ModelContainer {
        do {
            return try AnosaStore.makeContainer()
        } catch {
            logger.error("永続ストアを開けないためインメモリで起動します: \(error.localizedDescription, privacy: .public)")
        }
        do {
            return try AnosaStore.makeContainer(inMemory: true)
        } catch {
            fatalError("インメモリの ModelContainer も作成できません: \(error)")
        }
    }
}
