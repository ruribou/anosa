import SwiftUI
import UIKit

/// Share Extension の入口。共有された項目を読み取り、SwiftUI の `ShareView` に処理を任せる。
final class ShareViewController: UIViewController {
    private lazy var model = ShareModel { [weak self] outcome in
        self?.finish(outcome)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let host = UIHostingController(rootView: ShareView(model: model))
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        host.didMove(toParent: self)

        let items = extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []
        Task {
            let input = await SharedItemLoader.input(from: items)
            await model.start(with: input)
        }
    }

    private func finish(_ outcome: ShareOutcome) {
        switch outcome {
        case .completed:
            extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        case .cancelled:
            extensionContext?.cancelRequest(withError: CocoaError(.userCancelled))
        }
    }
}
