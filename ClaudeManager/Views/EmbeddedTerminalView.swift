import AppKit
import SwiftUI
import SwiftTerm

struct EmbeddedTerminalView: NSViewRepresentable {
    @ObservedObject var controller: TerminalSessionController

    func makeNSView(context: Context) -> TerminalHostView {
        let hostView = TerminalHostView()
        hostView.attachTerminalView(controller.terminalView)
        return hostView
    }

    func updateNSView(_ nsView: TerminalHostView, context: Context) {
        nsView.attachTerminalView(controller.terminalView)
    }
}

final class TerminalHostView: NSView {
    private weak var attachedTerminalView: NSView?

    func attachTerminalView(_ terminalView: NSView) {
        guard attachedTerminalView !== terminalView else { return }

        attachedTerminalView?.removeFromSuperview()

        if terminalView.superview !== self {
            terminalView.removeFromSuperview()
            addSubview(terminalView)
            terminalView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                terminalView.leadingAnchor.constraint(equalTo: leadingAnchor),
                terminalView.trailingAnchor.constraint(equalTo: trailingAnchor),
                terminalView.topAnchor.constraint(equalTo: topAnchor),
                terminalView.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        }

        attachedTerminalView = terminalView
    }
}
