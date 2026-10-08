import Foundation
import SwiftData

/// 保存済みの場所の読み書き。呼び出し側には `Place` 値型だけを見せる。
@MainActor
public final class PlaceStore {
    public let context: ModelContext
    /// ModelContext はコンテナを強参照せず、コンテナが解放されると操作時にクラッシュする。
    /// `init(container:)` ではここで保持する。
    private let container: ModelContainer?

    /// `context` のコンテナは呼び出し側が保持し続けること。
    public init(context: ModelContext) {
        self.context = context
        container = nil
    }

    public init(container: ModelContainer) {
        self.container = container
        context = container.mainContext
    }

    /// 同じ id があれば更新し、なければ追加して保存する。
    @discardableResult
    public func save(_ place: Place) throws -> Place {
        if let entity = try entity(id: place.id) {
            entity.update(from: place)
        } else {
            context.insert(PlaceEntity(place))
        }
        try context.save()
        return place
    }

    /// 保存日時の新しい順。`status` を渡すとそのステータスだけに絞る。
    public func places(status: PlaceStatus? = nil) throws -> [Place] {
        var descriptor = FetchDescriptor<PlaceEntity>(
            sortBy: [SortDescriptor(\.savedAt, order: .reverse)]
        )
        if let status {
            let rawValue = status.rawValue
            descriptor.predicate = #Predicate { $0.statusRawValue == rawValue }
        }
        return try context.fetch(descriptor).map(\.place)
    }

    public func place(id: UUID) throws -> Place? {
        try entity(id: id)?.place
    }

    /// 該当する場所がなければ何もしない。
    public func setStatus(_ status: PlaceStatus, for id: UUID) throws {
        guard let entity = try entity(id: id) else { return }
        entity.status = status
        try context.save()
    }

    /// 該当する場所がなければ何もしない。
    public func delete(id: UUID) throws {
        guard let entity = try entity(id: id) else { return }
        context.delete(entity)
        try context.save()
    }

    private func entity(id: UUID) throws -> PlaceEntity? {
        var descriptor = FetchDescriptor<PlaceEntity>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
