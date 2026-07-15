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
    @State private var isShowingImageImporter = false
    @State private var imageImportErrorMessage: String?
    @State private var didRefreshLinkedTables = false
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
            refreshLinkedTablesIfNeeded()
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
        .onChange(of: document.tableSources) { _, _ in
            normalizePreviewContext()
        }
        .onChange(of: document.printSettings) { _, _ in
            normalizePreviewContext()
        }
        .task {
            await printController.refreshPrinters()
        }
        .fileImporter(
            isPresented: $isShowingImageImporter,
            allowedContentTypes: LabelImageImporter.allowedContentTypes,
            allowsMultipleSelection: false,
            onCompletion: importImage
        )
        .alert("Bild konnte nicht eingefügt werden", isPresented: imageImportErrorPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(imageImportErrorMessage ?? "Unbekannter Fehler")
        }
    }

    private var actions: RibbonActions {
        RibbonActions(
            clearSelection: clearSelection,
            deleteSelection: deleteSelection,
            addText: addTextElement,
            addBarcode: addBarcodeElement,
            addImage: { isShowingImageImporter = true },
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
            addVariable: addVariable,
            addTableLookupVariable: addTableLookupVariable
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

    private func importImage(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else {
                return
            }

            let importedImage = try LabelImageImporter.load(from: url)
            let frame = initialImageFrame(aspectRatio: importedImage.aspectRatio)
            let imageElement = ImageLabelElement(
                name: importedImage.fileName,
                frame: frame,
                fileName: importedImage.fileName,
                mediaType: importedImage.mediaType,
                imageData: importedImage.data,
                sourceWidth: importedImage.width,
                sourceHeight: importedImage.height
            )

            document.elements.append(.image(imageElement))
            selectNewElement(id: imageElement.id)
        } catch {
            imageImportErrorMessage = error.localizedDescription
        }
    }

    private func initialImageFrame(aspectRatio: Double) -> LabelElementFrame {
        let safeAspectRatio = max(0.01, aspectRatio)
        let maximumWidth = max(12, min(300, document.label.widthDots - 60))
        let maximumHeight = max(12, min(220, document.label.heightDots - 60))
        var width = min(Double(maximumWidth), Double(maximumHeight) * safeAspectRatio)
        var height = width / safeAspectRatio

        if height > Double(maximumHeight) {
            height = Double(maximumHeight)
            width = height * safeAspectRatio
        }

        let widthDots = max(1, Int(round(width)))
        let heightDots = max(1, Int(round(height)))
        return LabelElementFrame(
            xDots: max(0, (document.label.widthDots - widthDots) / 2),
            yDots: max(0, (document.label.heightDots - heightDots) / 2),
            widthDots: widthDots,
            heightDots: heightDots
        )
        .clamped(to: document.label)
    }

    private var imageImportErrorPresented: Binding<Bool> {
        Binding(
            get: { imageImportErrorMessage != nil },
            set: { if !$0 { imageImportErrorMessage = nil } }
        )
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

    private func addTableLookupVariable() {
        let baseName = "tabellenwert"
        var name = baseName
        var suffix = 2

        while document.variables.contains(where: { $0.name == name }) {
            name = "\(baseName)\(suffix)"
            suffix += 1
        }

        let sourceVariableID = document.variables.first(where: { $0.type == .sequence })?.id
            ?? document.variables.first(where: { $0.type != .tableLookup })?.id
        let variable = VariableDefinition(
            name: name,
            type: .tableLookup,
            tableLookup: TableLookupConfiguration(sourceVariableID: sourceVariableID)
        )
        document.variables.append(variable)
        document.printSettings = document.printSettings.normalized(for: document.variables)
        selectedElementID = nil
        selectedGuideID = nil
        selectedVariableID = variable.id
        activeFormatPanePage = .variables
        normalizePreviewContext()
    }

    private func refreshLinkedTablesIfNeeded() {
        guard !didRefreshLinkedTables else {
            return
        }
        didRefreshLinkedTables = true

        let originalSources = document.tableSources
        Task {
            let refreshResults = await Task.detached(priority: .utility) {
                originalSources.map { source in
                    (source, try? TableDataImporter.refresh(source, onlyIfChanged: true))
                }
            }.value

            var refreshedSources = document.tableSources
            var didChange = false
            for (originalSource, refreshedSource) in refreshResults {
                guard let refreshedSource,
                      refreshedSource != originalSource,
                      let index = refreshedSources.firstIndex(where: { $0.id == originalSource.id }),
                      refreshedSources[index] == originalSource else {
                    continue
                }

                refreshedSources[index] = refreshedSource
                didChange = true
            }

            if didChange {
                document.tableSources = refreshedSources
                normalizePreviewContext()
            }
        }
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
    let addImage: () -> Void
    let addRectangle: () -> Void
    let addLine: () -> Void
    let addVerticalGuide: () -> Void
    let addHorizontalGuide: () -> Void
    let addVariable: () -> Void
    let addTableLookupVariable: () -> Void
}
