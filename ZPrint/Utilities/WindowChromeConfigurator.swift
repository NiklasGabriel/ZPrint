//
//  WindowChromeConfigurator.swift
//  ZPrint
//

import AppKit
import SwiftUI

struct WindowChromeConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        configureWhenReady(for: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        configureWhenReady(for: nsView)
    }

    private func configureWhenReady(for view: NSView) {
        DispatchQueue.main.async {
            guard let window = view.window else {
                return
            }

            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.fullSizeContentView)
            window.toolbar = nil
            window.toolbarStyle = .unifiedCompact
            window.isMovableByWindowBackground = true
        }
    }
}
