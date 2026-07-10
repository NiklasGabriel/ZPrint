//
//  AppShellView.swift
//  ZPrint
//

import SwiftUI

struct AppShellView: View {
    @Binding var document: ZPrintDocument
    @Binding var documentTitle: String
    let isFileBackedDocument: Bool
    @Binding var selectedElementID: UUID?
    @Binding var selectedGuideID: UUID?
    @State private var selectedVariableID: UUID?
    @State private var selectedRibbonTab: RibbonTab = .home
    @State private var previewContext: VariableEngine.Context = [:]
    @State private var activeFormatPanePage: FormatPanePage = .document
    @StateObject private var printController = PrintJobController()

    var body: some View {
        VStack(spacing: 0) {
            OfficeTitleBarView(
                document: $document
            )

            RibbonView(
                document: $document,
                selectedElementID: $selectedElementID,
                selectedGuideID: $selectedGuideID,
                selectedTab: $selectedRibbonTab,
                previewContext: $previewContext,
                printController: printController,
                actions: actions
            )

            HStack(spacing: 0) {
                ZPrintWorkspaceView(
                    document: $document,
                    selectedElementID: $selectedElementID,
                    selectedGuideID: $selectedGuideID,
                    selectedVariableID: $selectedVariableID,
                    previewContext: $previewContext,
                    activeFormatPanePage: $activeFormatPanePage,
                    printController: printController
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                RightFormatPaneView(
                    document: $document,
                    documentTitle: $documentTitle,
                    isFileBackedDocument: isFileBackedDocument,
                    selectedElementID: $selectedElementID,
                    selectedGuideID: $selectedGuideID,
                    selectedVariableID: $selectedVariableID,
                    activePage: $activeFormatPanePage,
                    printController: printController
                )
            }

            BottomOfficeStatusBar(document: $document)
        }
        .background(ZPrintDesign.ColorToken.appBackground)
        .onAppear {
            normalizeDocumentDerivedState()
        }
        .onChange(of: selectedRibbonTab) { _, newTab in
            updateFormatPanePage(for: newTab)

            if newTab == .preview {
                document.viewSettings.mode = .preview
            } else if newTab == .print {
                document.viewSettings.mode = .print
            } else if document.viewSettings.mode != .edit {
                document.viewSettings.mode = .edit
            }
        }
        .onChange(of: document.viewSettings.mode) { _, newMode in
            switch newMode {
            case .edit:
                if selectedRibbonTab == .preview || selectedRibbonTab == .print {
                    selectedRibbonTab = .home
                }
            case .preview:
                selectedRibbonTab = .preview
            case .print:
                selectedRibbonTab = .print
            }
        }
        .onChange(of: selectedElementID) { _, newValue in
            if newValue != nil {
                selectedVariableID = nil
                activeFormatPanePage = .document
            }
        }
        .onChange(of: selectedGuideID) { _, newValue in
            if newValue != nil {
                selectedVariableID = nil
                activeFormatPanePage = .document
            }
        }
        .onChange(of: selectedVariableID) { _, newValue in
            if newValue != nil {
                activeFormatPanePage = .variables
            }
        }
        .onChange(of: document.variables) { _, _ in
            normalizeDocumentDerivedState()
        }
        .onChange(of: document.printSettings) { _, _ in
            normalizePreviewContext()
        }
        .task {
            await printController.refreshPrinters()
        }
    }

    private var actions: RibbonActions {
        RibbonActions(
            clearSelection: clearSelection,
            deleteSelection: deleteSelection,
            addText: addTextElement,
            addBarcode: addBarcodeElement,
            addRectangle: addRectangleElement,
            addLine: addLineElement,
            addVerticalGuide: {
                addGuide(
                    orientation: .vertical,
                    positionDots: document.label.widthDots / 2,
                    name: "Vertikale Hilfslinie"
                )
            },
            addHorizontalGuide: {
                addGuide(
                    orientation: .horizontal,
                    positionDots: document.label.heightDots / 2,
                    name: "Horizontale Hilfslinie"
                )
            },
            addVariable: addVariable
        )
    }

    private func clearSelection() {
        selectedElementID = nil
        selectedGuideID = nil
        selectedVariableID = nil
        activeFormatPanePage = .document
    }

    private func deleteSelection() {
        if let selectedElementID {
            document.elements.removeAll { $0.id == selectedElementID }
            self.selectedElementID = nil
        }

        if let selectedGuideID {
            document.guides.removeAll { $0.id == selectedGuideID }
            self.selectedGuideID = nil
        }

        if let selectedVariableID {
            document.variables.removeAll { $0.id == selectedVariableID }
            document.printSettings = document.printSettings.normalized(for: document.variables)
            self.selectedVariableID = nil
        }
    }

    private func addTextElement() {
        let textElement = TextLabelElement.standardNewElement()
        let clampedElement = TextLabelElement(
            id: textElement.id,
            name: textElement.name,
            frame: textElement.frame.clamped(to: document.label),
            text: textElement.text,
            fontFamilyName: textElement.fontFamilyName,
            fontSizeDots: textElement.fontSizeDots,
            isBold: textElement.isBold,
            isItalic: textElement.isItalic,
            isUnderlined: textElement.isUnderlined,
            alignment: textElement.alignment,
            rotation: textElement.rotation,
            variableKey: textElement.variableKey
        )

        document.elements.append(.text(clampedElement))
        selectNewElement(id: clampedElement.id)
    }

    private func addBarcodeElement() {
        let barcodeElement = BarcodeLabelElement.standardNewElement()
        let clampedElement = BarcodeLabelElement(
            id: barcodeElement.id,
            name: barcodeElement.name,
            frame: barcodeElement.frame.clamped(to: document.label),
            symbology: barcodeElement.symbology,
            value: barcodeElement.value,
            moduleWidth: barcodeElement.moduleWidth,
            showsHumanReadableText: barcodeElement.showsHumanReadableText,
            rotation: barcodeElement.rotation,
            variableKey: barcodeElement.variableKey
        )

        document.elements.append(.barcode(clampedElement))
        selectNewElement(id: clampedElement.id)
    }

    private func addRectangleElement() {
        let shape = ShapeLabelElement(
            name: "Rechteck",
            frame: LabelElementFrame(
                xDots: 80,
                yDots: 70,
                widthDots: min(240, document.label.widthDots - 80),
                heightDots: min(120, document.label.heightDots - 70)
            )
            .clamped(to: document.label),
            shape: .rectangle,
            strokeWidthDots: 2,
            isFilled: false
        )

        document.elements.append(.shape(shape))
        selectNewElement(id: shape.id)
    }

    private func addLineElement() {
        let shape = ShapeLabelElement(
            name: "Linie",
            frame: LabelElementFrame(
                xDots: 80,
                yDots: document.label.heightDots / 2,
                widthDots: min(260, document.label.widthDots - 80),
                heightDots: 12
            )
            .clamped(to: document.label),
            shape: .line,
            strokeWidthDots: 3,
            isFilled: false
        )

        document.elements.append(.shape(shape))
        selectNewElement(id: shape.id)
    }

    private func addGuide(
        orientation: GuideOrientation,
        positionDots: Int,
        name: String
    ) {
        let maxPosition = orientation == .vertical
            ? document.label.widthDots
            : document.label.heightDots
        let guide = GuideElement(
            orientation: orientation,
            positionDots: min(max(positionDots, 0), maxPosition),
            name: name
        )

        document.guides.append(guide)
        document.viewSettings.mode = .edit
        selectedElementID = nil
        selectedGuideID = guide.id
        selectedVariableID = nil
        activeFormatPanePage = .document
    }

    private func addVariable() {
        let baseName = "variable"
        var name = baseName
        var suffix = 2

        while document.variables.contains(where: { $0.name == name }) {
            name = "\(baseName)\(suffix)"
            suffix += 1
        }

        let variable = VariableDefinition(name: name)
        document.variables.append(variable)
        document.printSettings = document.printSettings.normalized(for: document.variables)
        selectedElementID = nil
        selectedGuideID = nil
        selectedVariableID = variable.id
        activeFormatPanePage = .variables
        normalizePreviewContext()
    }

    private func selectNewElement(id: UUID) {
        document.viewSettings.mode = .edit
        selectedElementID = id
        selectedGuideID = nil
        selectedVariableID = nil
        activeFormatPanePage = .document
        selectedRibbonTab = .home
    }

    private func normalizePreviewContext() {
        previewContext = VariableEngine.normalizedPreviewContext(previewContext, for: document)
    }

    private func normalizeDocumentDerivedState() {
        let normalizedPrintSettings = document.printSettings.normalized(for: document.variables)

        if normalizedPrintSettings != document.printSettings {
            document.printSettings = normalizedPrintSettings
        }

        normalizePreviewContext()
    }

    private func updateFormatPanePage(for tab: RibbonTab) {
        switch tab {
        case .variables:
            activeFormatPanePage = .variables
        case .preview:
            selectedVariableID = nil
            activeFormatPanePage = .preview
        case .print:
            selectedVariableID = nil
            activeFormatPanePage = .print
        case .home, .insert, .layout:
            selectedVariableID = nil
            activeFormatPanePage = .document
        }
    }
}

struct RibbonActions {
    let clearSelection: () -> Void
    let deleteSelection: () -> Void
    let addText: () -> Void
    let addBarcode: () -> Void
    let addRectangle: () -> Void
    let addLine: () -> Void
    let addVerticalGuide: () -> Void
    let addHorizontalGuide: () -> Void
    let addVariable: () -> Void
}
