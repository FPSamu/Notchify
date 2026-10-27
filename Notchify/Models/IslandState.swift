import Combine
import CoreGraphics
import Foundation

/// Shared UI state between the SwiftUI island and the AppKit window that hosts it.
final class IslandState: ObservableObject {
    @Published var isExpanded = false

    /// Called before the expand animation starts so the hosting window can grow first.
    var onWillExpand: (() -> Void)?

    func expand() {
        guard !isExpanded else { return }
        onWillExpand?()
        // Next run-loop turn: the window is already big, so the animation starts from the pill.
        DispatchQueue.main.async { [weak self] in
            self?.isExpanded = true
        }
    }
}

enum IslandLayout {
    static let compactSize = CGSize(width: 242, height: 32)
    static let expandedSize = CGSize(width: 295, height: 145)
}
