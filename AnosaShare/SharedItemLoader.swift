import AnosaKit
import Foundation
import UniformTypeIdentifiers

/// `NSExtensionItem` から共有入力（Web URL とテキスト）を取り出す。
@MainActor
enum SharedItemLoader {
    static func input(from items: [NSExtensionItem]) async -> SharedInput {
        var url: URL?
        var attachmentText: String?
        for provider in items.flatMap({ $0.attachments ?? [] }) {
            if url == nil, provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
               let loaded = await load(URL.self, from: provider), ShareFlow.isWebURL(loaded) {
                url = loaded
            } else if attachmentText == nil, provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                attachmentText = ShareFlow.nonEmpty(await load(String.self, from: provider))
            }
        }
        let text = ShareFlow.sharedText(
            attachmentText: attachmentText,
            contentText: items.lazy.compactMap { ShareFlow.nonEmpty($0.attributedContentText?.string) }.first,
            title: items.lazy.compactMap { ShareFlow.nonEmpty($0.attributedTitle?.string) }.first
        )
        return SharedInput(url: url, text: text)
    }

    /// 読み込めなければ nil（失敗した項目は無視して、ほかの項目で続ける）。
    private static func load<T: _ObjectiveCBridgeable & Sendable>(_ type: T.Type, from provider: NSItemProvider) async -> T?
    where T._ObjectiveCType: NSItemProviderReading {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: type) { object, _ in
                continuation.resume(returning: object)
            }
        }
    }
}
