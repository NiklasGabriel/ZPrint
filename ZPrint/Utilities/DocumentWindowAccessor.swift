//
//  DocumentWindowAccessor.swift
//  ZPrint
//

import AppKit
import SwiftUI

struct DocumentWindowAccessor: NSViewRepresentable {
    let resolve: (NSDocument?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        resolveDocument(from: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        resolveDocument(from: nsView)
    }

    private func resolveDocument(from view: NSView) {
        DispatchQueue.main.async {
            resolve(view.window?.windowController?.document as? NSDocument)
        }
    }
}
