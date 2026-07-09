//
//  RightFormatPaneView.swift
//  ZPrint
//

import SwiftUI

struct RightFormatPaneView: View {
    @Binding var document: ZPrintDocument
    @Binding var documentTitle: String
    let isFileBackedDocument: Bool
    @Binding var selectedElementID: UUID?
    @Binding var selectedGuideID: UUID?
    @Binding var selectedVariableID: UUID?
    @Binding var activePage: FormatPanePage

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    paneContent
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
            }
            .scrollContentBackground(.hidden)
        }
        .frame(width: ZPrintDesign.Metric.formatPaneWidth)
        .background(ZPrintDesign.ColorToken.subtlePanelBackground)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(ZPrintDesign.ColorToken.softBorder)
                .frame(width: 1)
        }
    }

    private var header: some View {
        HStack {
            Label(headerTitle, systemImage: headerSystemImage)
                .font(.system(size: 14, weight: .semibold))
                .labelStyle(.titleAndIcon)
            Spacer()
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .frame(height: 42)
        .background {
            Rectangle()
                .fill(ZPrintDesign.ColorToken.panelBackground.opacity(0.82))
                .shadow(color: .black.opacity(0.035), radius: 5, x: 0, y: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(ZPrintDesign.ColorToken.softBorder)
                .frame(height: 1)
        }
    }

    private var headerTitle: String {
        if activePage == .preview {
            return "Vorschau"
        }

        if activePage == .print {
            return "Drucken"
        }

        if selectedVariableBinding != nil {
            return "Variable bearbeiten"
        }

        if activePage == .variables {
            return "Variablen"
        }

        if selectedGuideBinding != nil {
            return "Hilfslinie"
        }

        guard let element = selectedElementBinding?.wrappedValue else {
            return "Dokument"
        }

        switch element {
        case .text:
            return "Text formatieren"
        case .barcode:
            return "Barcode formatieren"
        case .shape:
            return "Form formatieren"
        }
    }

    private var headerSystemImage: String {
        if activePage == .preview {
            return "eye"
        }

        if activePage == .print {
            return "printer"
        }

        if selectedVariableBinding != nil || activePage == .variables {
            return "curlybraces"
        }

        if selectedGuideBinding != nil {
            return "ruler"
        }

        guard let element = selectedElementBinding?.wrappedValue else {
            return "doc.text"
        }

        switch element {
        case .text:
            return "textformat"
        case .barcode:
            return "barcode"
        case .shape:
            return "rectangle"
        }
    }

    @ViewBuilder
    private var paneContent: some View {
        if activePage == .preview {
            FormatPaneEmptyState(
                title: "Vorschau aktiv",
                message: "Die Vorschau nutzt die aktuellen Labeldaten und rendert Variablenwerte ohne Bearbeitungsgriffe.",
                systemImage: "eye"
            )
        } else if activePage == .print {
            FormatPaneEmptyState(
                title: "Drucken aktiv",
                message: "Drucker, ZPL-Export und Raw-Druckauftrag werden im Arbeitsbereich links gesteuert.",
                systemImage: "printer"
            )
        } else if let variable = selectedVariableBinding {
            VariableFormatPane(
                variable: variable,
                delete: deleteSelectedVariable
            )
        } else if activePage == .variables {
            VariablesFormatPane(
                document: $document,
                selectedVariableID: $selectedVariableID
            )
        } else if let guide = selectedGuideBinding {
            GuideFormatPane(
                guide: guide,
                labelSize: document.label,
                delete: deleteSelectedGuide
            )
        } else if let element = selectedElementBinding {
            switch element.wrappedValue {
            case .text:
                TextFormatPane(
                    element: textBinding(from: element),
                    labelSize: document.label,
                    variables: document.variables,
                    delete: deleteSelectedElement
                )
            case .barcode:
                BarcodeFormatPane(
                    element: barcodeBinding(from: element),
                    labelSize: document.label,
                    variables: document.variables,
                    delete: deleteSelectedElement
                )
            case .shape:
                ShapeFormatPane(
                    element: shapeBinding(from: element),
                    labelSize: document.label,
                    delete: deleteSelectedElement
                )
            }
        } else {
            DocumentFormatPane(
                document: $document,
                documentTitle: $documentTitle,
                isFileBackedDocument: isFileBackedDocument
            )
        }
    }

    private var selectedElementBinding: Binding<LabelElement>? {
        guard let selectedElementID,
              document.elements.contains(where: { $0.id == selectedElementID }) else {
            return nil
        }

        return Binding(
            get: {
                document.elements.first(where: { $0.id == selectedElementID }) ?? .text(.standardNewElement())
            },
            set: { updatedElement in
                guard let index = document.elements.firstIndex(where: { $0.id == selectedElementID }) else {
                    return
                }
                document.elements[index] = updatedElement
            }
        )
    }

    private var selectedGuideBinding: Binding<GuideElement>? {
        guard let selectedGuideID,
              document.guides.contains(where: { $0.id == selectedGuideID }) else {
            return nil
        }

        return Binding(
            get: {
                document.guides.first(where: { $0.id == selectedGuideID })
                    ?? GuideElement()
            },
            set: { updatedGuide in
                guard let index = document.guides.firstIndex(where: { $0.id == selectedGuideID }) else {
                    return
                }
                document.guides[index] = updatedGuide.clamped(to: document.label)
            }
        )
    }

    private var selectedVariableBinding: Binding<VariableDefinition>? {
        guard let selectedVariableID,
              document.variables.contains(where: { $0.id == selectedVariableID }) else {
            return nil
        }

        return Binding(
            get: {
                document.variables.first(where: { $0.id == selectedVariableID })
                    ?? VariableDefinition(name: "variable")
            },
            set: { updatedVariable in
                guard let index = document.variables.firstIndex(where: { $0.id == selectedVariableID }) else {
                    return
                }
                document.variables[index] = updatedVariable.normalizedForFormatPane
            }
        )
    }

    private func textBinding(from element: Binding<LabelElement>) -> Binding<TextLabelElement> {
        Binding(
            get: {
                if case .text(let textElement) = element.wrappedValue {
                    return textElement
                }
                return .standardNewElement()
            },
            set: { element.wrappedValue = .text($0) }
        )
    }

    private func barcodeBinding(from element: Binding<LabelElement>) -> Binding<BarcodeLabelElement> {
        Binding(
            get: {
                if case .barcode(let barcodeElement) = element.wrappedValue {
                    return barcodeElement
                }
                return .standardNewElement()
            },
            set: { element.wrappedValue = .barcode($0) }
        )
    }

    private func shapeBinding(from element: Binding<LabelElement>) -> Binding<ShapeLabelElement> {
        Binding(
            get: {
                if case .shape(let shapeElement) = element.wrappedValue {
                    return shapeElement
                }
                return ShapeLabelElement()
            },
            set: { element.wrappedValue = .shape($0) }
        )
    }

    private func deleteSelectedElement() {
        guard let selectedElementID else {
            return
        }

        document.elements.removeAll { $0.id == selectedElementID }
        self.selectedElementID = nil
    }

    private func deleteSelectedGuide() {
        guard let selectedGuideID else {
            return
        }

        document.guides.removeAll { $0.id == selectedGuideID }
        self.selectedGuideID = nil
    }

    private func deleteSelectedVariable() {
        guard let selectedVariableID else {
            return
        }

        document.variables.removeAll { $0.id == selectedVariableID }
        self.selectedVariableID = nil
    }
}

private struct FormatPaneEmptyState: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        FormatSection(title: title) {
            VStack(alignment: .leading, spacing: 9) {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(ZPrintDesign.ColorToken.secondaryText)
                    .frame(width: 32, height: 30, alignment: .leading)

                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private extension VariableDefinition {
    var normalizedForFormatPane: VariableDefinition {
        var variable = self
        variable.name = variable.name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "_")
        variable.step = max(1, variable.step)
        return variable
    }
}
