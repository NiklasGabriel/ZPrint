//
//  WindowChromeConfigurator.swift
//  ZPrint
//

import AppKit
import SwiftUI

struct WindowChromeConfigurator: NSViewRepresentable {
    var title: String
    var representedURL: URL?

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

            window.title = title
            window.representedURL = representedURL
            window.titleVisibility = .visible
            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.fullSizeContentView)
            window.toolbar = nil
            window.toolbarStyle = .unifiedCompact
            window.isMovableByWindowBackground = false
            centerTrafficLightButtons(in: window)
        }
    }

    private func centerTrafficLightButtons(in window: NSWindow) {
        let buttons = [
            window.standardWindowButton(.closeButton),
            window.standardWindowButton(.miniaturizeButton),
            window.standardWindowButton(.zoomButton)
        ].compactMap { $0 }

        guard !buttons.isEmpty else {
            return
        }

        let targetY = max(0, (ZPrintDesign.Metric.titleBarHeight - buttons[0].frame.height) / 2)
        for button in buttons {
            button.setFrameOrigin(NSPoint(x: button.frame.origin.x, y: targetY))
        }
    }
}
