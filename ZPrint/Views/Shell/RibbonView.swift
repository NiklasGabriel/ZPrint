//
//  RibbonView.swift
//  ZPrint
//

import SwiftUI

struct RibbonView: View {
    @Binding var document: ZPrintDocument
    @Binding var selectedElementID: UUID?
    @Binding var selectedGuideID: UUID?
    @Binding var selectedTab: RibbonTab
    @Binding var previewContext: VariableEngine.Context
    let actions: RibbonActions

    var body: some View {
        VStack(spacing: 0) {
            RibbonTabBar(selectedTab: $selectedTab)

            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    tabContent
                }
                .frame(minWidth: 780, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            .frame(height: ZPrintDesign.Metric.ribbonContentHeight)
        }
        .background(ZPrintDesign.ColorToken.ribbonBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(ZPrintDesign.ColorToken.border)
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .home:
            homeTab
        case .insert:
            insertTab
        case .layout:
            layoutTab
        case .variables:
            variablesTab
        case .preview:
            previewTab
        case .print:
            printTab
        }
    }

    private var homeTab: some View {
        Group {
            RibbonGroupView(title: "Auswahl") {
                VStack(alignment: .leading, spacing: 5) {
                    RibbonButton(title: "Abwählen", systemImage: "cursorarrow.rays", action: actions.clearSelection)
                    RibbonButton(
                        title: "Löschen",
                        systemImage: "trash",
                        isDisabled: selectedElementID == nil && selectedGuideID == nil,
                        action: actions.deleteSelection
                    )
                }
            }

            RibbonGroupView(title: "Text") {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 4) {
                        RibbonTextToggleButton(
                            title: "B",
                            style: .bold,
                            isSelected: selectedText?.isBold ?? false,
                            isDisabled: selectedTextBinding == nil
                        ) {
                            selectedTextBinding?.wrappedValue.isBold.toggle()
                        }
                        RibbonTextToggleButton(
                            title: "I",
                            style: .italic,
                            isSelected: selectedText?.isItalic ?? false,
                            isDisabled: selectedTextBinding == nil
                        ) {
                            selectedTextBinding?.wrappedValue.isItalic.toggle()
                        }
                        RibbonTextToggleButton(
                            title: "U",
                            style: .underline,
                            isSelected: selectedText?.isUnderlined ?? false,
                            isDisabled: selectedTextBinding == nil
                        ) {
                            selectedTextBinding?.wrappedValue.isUnderlined.toggle()
                        }
                    }

                    RibbonFontSizeControl(
                        value: fontSizeBinding,
                        displayedValue: selectedText?.fontSizeDots ?? 0,
                        isDisabled: selectedTextBinding == nil
                    )
                }
            }

            RibbonGroupView(title: "Ausrichten") {
                VStack(spacing: 5) {
                    HStack(spacing: 4) {
                        alignmentButton(.left, image: "text.alignleft")
                        alignmentButton(.center, image: "text.aligncenter")
                        alignmentButton(.right, image: "text.alignright")
                    }
                    RibbonButton(title: "Mitte", systemImage: "align.horizontal.center", isDisabled: selectedElementID == nil) {
                        centerSelectedElementHorizontally()
                    }
                }
            }

            RibbonGroupView(title: "Anordnen") {
                VStack(alignment: .leading, spacing: 5) {
                    RibbonButton(title: "Nach vorne", systemImage: "square.2.layers.3d.top.filled", isDisabled: true) {}
                    RibbonButton(title: "Nach hinten", systemImage: "square.2.layers.3d.bottom.filled", isDisabled: true) {}
                }
            }

            RibbonGroupView(title: "Dokument") {
                VStack(alignment: .leading, spacing: 5) {
                    Text(document.label.name)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text("\(document.label.widthDots) x \(document.label.heightDots) dots")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private var insertTab: some View {
        Group {
            RibbonGroupView(title: "Elemente") {
                RibbonLargeButton(title: "Text", systemImage: "textformat", action: actions.addText)
                RibbonLargeButton(title: "Barcode", systemImage: "barcode", action: actions.addBarcode)
                RibbonLargeButton(title: "Form", systemImage: "rectangle", action: actions.addRectangle)
                RibbonLargeButton(title: "Linie", systemImage: "line.diagonal", action: actions.addLine)
            }

            RibbonGroupView(title: "Hilfslinien") {
                RibbonLargeButton(title: "Vertikal", systemImage: "ruler", action: actions.addVerticalGuide)
                RibbonLargeButton(title: "Horizontal", systemImage: "ruler.fill", action: actions.addHorizontalGuide)
            }

            RibbonGroupView(title: "Vorbereitet") {
                RibbonLargeButton(title: "QR-Code", systemImage: "qrcode", isDisabled: true) {}
                RibbonLargeButton(title: "DataMatrix", systemImage: "square.grid.3x3", isDisabled: true) {}
                RibbonLargeButton(title: "Bild", systemImage: "photo", isDisabled: true) {}
            }
        }
    }

    private var layoutTab: some View {
        Group {
            RibbonGroupView(title: "Label") {
                VStack(alignment: .leading, spacing: 7) {
                    Picker("Größe", selection: labelSizeSelection) {
                        ForEach(LabelSize.standardSizes) { labelSize in
                            Text(labelSize.name).tag(labelSize.id)
                        }
                    }
                    .frame(width: 210)

                    Text("\(document.label.dotsPerInch) dpi · \(document.label.widthDots) x \(document.label.heightDots) dots")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            RibbonGroupView(title: "Hilfslinien") {
                VStack(alignment: .leading, spacing: 5) {
                    RibbonButton(title: "Mitte vertikal", systemImage: "ruler", action: actions.addVerticalGuide)
                    RibbonButton(title: "Mitte horizontal", systemImage: "ruler.fill", action: actions.addHorizontalGuide)
                }
            }

            RibbonGroupView(title: "Snapping") {
                VStack(alignment: .leading, spacing: 5) {
                    RibbonButton(title: "Aktiv", systemImage: "point.topleft.down.curvedto.point.bottomright.up", isSelected: true, isDisabled: true) {}
                    Text("Dots-basiert")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var variablesTab: some View {
        Group {
            RibbonGroupView(title: "Variablen") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 5) {
                        ForEach(document.variables.prefix(5)) { variable in
                            VariableRibbonChip(variable: variable)
                        }

                        if document.variables.isEmpty {
                            Text("Keine Variablen")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack(spacing: 6) {
                        RibbonButton(title: "Neu", systemImage: "plus", action: actions.addVariable)
                        RibbonButton(title: "Standards", systemImage: "sparkles", action: actions.addStandardVariables)
                    }
                }
            }

            RibbonGroupView(title: "Einfügen") {
                VStack(alignment: .leading, spacing: 5) {
                    Menu {
                        if document.variables.isEmpty {
                            Text("Keine Variablen")
                        } else {
                            ForEach(document.variables) { variable in
                                Button(variable.chipTitle) {
                                    insertVariable(variable)
                                }
                            }
                        }
                    } label: {
                        Label("Variable einfügen", systemImage: "curlybraces")
                            .frame(width: 150, height: 28)
                    }
                    .disabled(!canInsertVariable)

                    Text(canInsertVariable ? "In ausgewählten Inhalt" : "Text oder Barcode auswählen")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var previewTab: some View {
        Group {
            RibbonGroupView(title: "Vorschauwerte") {
                PreviewRibbonContextView(
                    variables: document.variables,
                    context: $previewContext,
                    reset: resetPreviewContext
                )
            }
        }
    }

    private var printTab: some View {
        Group {
            RibbonGroupView(title: "Druckbereich") {
                VStack(alignment: .leading, spacing: 5) {
                    printField("Start", value: $document.printSettings.counterStart)
                    printField("Ende", value: $document.printSettings.counterEnd)
                }
            }

            RibbonGroupView(title: "Ausgabe") {
                RibbonLargeButton(title: "Drucken", systemImage: "printer", isDisabled: true) {}
                RibbonLargeButton(title: "ZPL", systemImage: "doc.on.doc", isDisabled: true) {}
                RibbonLargeButton(title: "Export", systemImage: "square.and.arrow.up", isDisabled: true) {}
            }
        }
    }

    private func alignmentButton(_ alignment: TextElementAlignment, image: String) -> some View {
        RibbonButton(
            title: "",
            systemImage: image,
            isSelected: selectedText?.alignment == alignment,
            isDisabled: selectedTextBinding == nil
        ) {
            selectedTextBinding?.wrappedValue.alignment = alignment
        }
    }

    private func printField(_ title: String, value: Binding<Int>) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .leading)
            TextField(title, value: value, format: .number)
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
                .frame(width: 72)
        }
    }

    private var selectedText: TextLabelElement? {
        selectedTextBinding?.wrappedValue
    }

    private var selectedTextBinding: Binding<TextLabelElement>? {
        guard let selectedElementID,
              let index = document.elements.firstIndex(where: { $0.id == selectedElementID }),
              case .text = document.elements[index] else {
            return nil
        }

        return Binding(
            get: {
                if case .text(let textElement) = document.elements[index] {
                    return textElement
                }
                return .standardNewElement()
            },
            set: { document.elements[index] = .text($0) }
        )
    }

    private var selectedBarcodeBinding: Binding<BarcodeLabelElement>? {
        guard let selectedElementID,
              let index = document.elements.firstIndex(where: { $0.id == selectedElementID }),
              case .barcode = document.elements[index] else {
            return nil
        }

        return Binding(
            get: {
                if case .barcode(let barcodeElement) = document.elements[index] {
                    return barcodeElement
                }
                return .standardNewElement()
            },
            set: { document.elements[index] = .barcode($0) }
        )
    }

    private var fontSizeBinding: Binding<Int> {
        Binding(
            get: { selectedTextBinding?.wrappedValue.fontSizeDots ?? 0 },
            set: { selectedTextBinding?.wrappedValue.fontSizeDots = min(max($0, 6), 200) }
        )
    }

    private var canInsertVariable: Bool {
        selectedTextBinding != nil || selectedBarcodeBinding != nil
    }

    private func insertVariable(_ variable: VariableDefinition) {
        if selectedTextBinding != nil {
            selectedTextBinding?.wrappedValue.text.append(variable.placeholder)
        } else if selectedBarcodeBinding != nil {
            selectedBarcodeBinding?.wrappedValue.value.append(variable.placeholder)
        }
    }

    private func resetPreviewContext() {
        previewContext = VariableEngine.previewContext(for: document)
    }

    private func centerSelectedElementHorizontally() {
        guard let selectedElementID,
              let index = document.elements.firstIndex(where: { $0.id == selectedElementID }) else {
            return
        }

        var frame = document.elements[index].frame
        frame.xDots = max(0, (document.label.widthDots - frame.widthDots) / 2)
        document.elements[index] = document.elements[index].replacingFrame(frame.clamped(to: document.label))
    }

    private var labelSizeSelection: Binding<String> {
        Binding(
            get: { document.labelSizeId },
            set: { newID in
                guard let labelSize = LabelSize.standardSizes.first(where: { $0.id == newID }) else {
                    return
                }

                document.labelSizeId = labelSize.id
                document.label = labelSize
                document.elements = document.elements.map { $0.replacingFrame($0.frame.clamped(to: labelSize)) }
                document.guides = document.guides.map { $0.clamped(to: labelSize) }
            }
        )
    }

}

private struct VariableRibbonChip: View {
    let variable: VariableDefinition

    var body: some View {
        Text(variable.chipTitle)
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background {
                Capsule()
                    .fill(ZPrintDesign.ColorToken.accent.opacity(0.10))
            }
            .overlay {
                Capsule()
                    .stroke(ZPrintDesign.ColorToken.accent.opacity(0.24), lineWidth: 1)
            }
    }
}

private enum RibbonTextToggleStyle {
    case bold
    case italic
    case underline
}

private struct RibbonTextToggleButton: View {
    let title: String
    let style: RibbonTextToggleStyle
    var isSelected = false
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: style == .bold ? .bold : .medium))
                .italic(style == .italic)
                .underline(style == .underline)
                .frame(width: 28, height: ZPrintDesign.Metric.buttonHeight)
                .background {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isSelected ? ZPrintDesign.ColorToken.accent.opacity(0.14) : Color.clear)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(isSelected ? ZPrintDesign.ColorToken.accent.opacity(0.34) : Color.clear, lineWidth: 1)
                }
                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1)
        .help(helpTitle)
    }

    private var helpTitle: String {
        switch style {
        case .bold:
            return "Fett"
        case .italic:
            return "Kursiv"
        case .underline:
            return "Unterstrichen"
        }
    }
}

private struct RibbonFontSizeControl: View {
    @Binding var value: Int
    let displayedValue: Int
    var isDisabled = false

    var body: some View {
        HStack(spacing: 2) {
            Button {
                value -= 1
            } label: {
                Image(systemName: "minus")
                    .frame(width: 22, height: 24)
            }
            .buttonStyle(.plain)

            Text("\(displayedValue)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .frame(width: 34)

            Button {
                value += 1
            } label: {
                Image(systemName: "plus")
                    .frame(width: 22, height: 24)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 3)
        .frame(height: ZPrintDesign.Metric.buttonHeight)
        .background {
            Capsule()
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.72))
        }
        .overlay {
            Capsule()
                .stroke(ZPrintDesign.ColorToken.softBorder, lineWidth: 1)
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1)
        .help("Schriftgröße")
    }
}

private struct PreviewRibbonContextView: View {
    let variables: [VariableDefinition]
    @Binding var context: VariableEngine.Context
    let reset: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Label("Werte", systemImage: "eye")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)

            if variables.isEmpty {
                Text("Keine Variablen")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 124, alignment: .leading)
            } else {
                HStack(spacing: 8) {
                    ForEach(variables) { variable in
                        PreviewRibbonContextField(
                            variable: variable,
                            value: binding(for: variable.name)
                        )
                    }
                }
            }

            Button(action: reset) {
                Label("Zurücksetzen", systemImage: "arrow.counterclockwise")
                    .font(.system(size: 12, weight: .medium))
                    .frame(height: ZPrintDesign.Metric.buttonHeight)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(ZPrintDesign.ColorToken.softBorder, lineWidth: 1)
            }
            .disabled(variables.isEmpty)
            .opacity(variables.isEmpty ? 0.45 : 1)
        }
    }

    private func binding(for key: String) -> Binding<String> {
        Binding(
            get: { context[key, default: ""] },
            set: { context[key] = $0 }
        )
    }
}

private struct PreviewRibbonContextField: View {
    let variable: VariableDefinition
    @Binding var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(variable.chipTitle)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            TextField(variable.name, text: $value)
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
                .frame(width: 104)
        }
    }
}
