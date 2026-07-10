//
//  StartWindowConfigurator.swift
//  ZPrint
//

import AppKit
import SwiftUI

struct StartWindowConfigurator: NSViewRepresentable {
    final class Coordinator {
        var centeredWindowIdentifiers: Set<ObjectIdentifier> = []
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        configureWhenReady(for: view, context: context)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        configureWhenReady(for: nsView, context: context)
    }

    private func configureWhenReady(for view: NSView, context: Context) {
        let coordinator = context.coordinator

        DispatchQueue.main.async {
            guard let window = view.window else {
                return
            }

            window.title = "ZPrint"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.toolbar = nil
            window.styleMask.insert(.fullSizeContentView)
            window.isMovableByWindowBackground = true
            window.minSize = NSSize(width: 900, height: 560)

            let windowIdentifier = ObjectIdentifier(window)
            if !coordinator.centeredWindowIdentifiers.contains(windowIdentifier) {
                window.center()
                coordinator.centeredWindowIdentifiers.insert(windowIdentifier)
            }
        }
    }
}
