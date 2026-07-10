//
//  DocumentSidebarView.swift
//  ZPrint
//

import SwiftUI

struct DocumentSidebarView: View {
    @Binding var document: ZPrintDocument
    @Binding var selection: SidebarSection
    @Binding var selectedElementID: UUID?
    let toggleSidebar: () -> Void
    @State private var selectedVariableID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            SidebarChromeHeader(toggleSidebar: toggleSidebar)

            List(selection: $selection) {
                inspectorContent
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
        .background(.bar, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.50), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var inspectorContent: some View {
        if let selectedElementID,
           let index = document.elements.firstIndex(where: { $0.id == selectedElementID }) {
            selectedElementInspector(element: $document.elements[index])
        } else {
            switch selection {
            case .document:
                documentInspector
            case .variables:
                variablesInspector
            case .elements:
                elementsInspector
            }
        }
    }

    private var documentInspector: some View {
        Group {
            Section("Label") {
                Picker("Größe", selection: labelSizeSelection) {
                    ForEach(LabelSize.standardSizes) { labelSize in
                        Text(labelSize.name)
                            .tag(labelSize.id)
                    }
                }

                InspectorValueRow(label: "DPI", value: "\(document.label.dotsPerInch)")
                InspectorValueRow(
                    label: "mm",
                    value: "\(formatMillimeters(document.label.widthMillimeters)) x \(formatMillimeters(document.label.heightMillimeters))"
                )
                InspectorValueRow(
                    label: "Dots",
                    value: "\(document.label.widthDots) x \(document.label.heightDots)"
                )
                InspectorValueRow(label: "Elemente", value: "\(document.elements.count)")
            }

            guidesInspector
        }
    }

    private var guidesInspector: some View {
        Section("Hilfslinien") {
            if document.guides.isEmpty {
                InspectorPlaceholderRow(systemImageName: "ruler", title: "Keine Hilfslinien")
            } else {
                ForEach($document.guides) { $guide in
                    GuideEditorRow(
                        guide: $guide,
                        labelSize: document.label,
                        delete: {
                            deleteGuide(id: guide.id)
                        }
                    )
                }
            }
        }
    }

    private var variablesInspector: some View {
        Group {
            Section("Variablen") {
                if document.variables.isEmpty {
                    InspectorPlaceholderRow(systemImageName: "tag", title: "Keine Variablen")
                } else {
                    VariableChipCloud(
                        variables: document.variables,
                        selectedVariableID: selectedVariableID ?? document.variables.first?.id,
                        select: { variable in
                            selectedVariableID = variable.id
                        }
                    )
                }

                Button {
                    addVariable()
                } label: {
                    Label("Variable anlegen", systemImage: "plus")
                }
            }

            if let selectedVariableBinding {
                VariableEditorSection(
                    variable: selectedVariableBinding,
                    canDelete: true,
                    delete: {
                        deleteVariable(id: selectedVariableBinding.wrappedValue.id)
                    }
                )
            } else if !document.variables.isEmpty {
                Section("Bearbeiten") {
                    InspectorPlaceholderRow(systemImageName: "tag", title: "Variable auswählen")
                }
            }
        }
    }

    private var elementsInspector: some View {
        Section("Elemente") {
            if document.elements.isEmpty {
                InspectorPlaceholderRow(systemImageName: "square.dashed", title: "Keine Elemente")
            } else {
                ForEach(document.elements) { element in
                    ElementListRow(
                        element: element,
                        isSelected: selectedElementID == element.id,
                        select: {
                            selectedElementID = element.id
                        },
                        delete: {
                            deleteElement(id: element.id)
                        }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func selectedElementInspector(element: Binding<LabelElement>) -> some View {
        switch element.wrappedValue {
        case .text:
            TextElementInspector(
                element: Binding(
                    get: {
                        if case .text(let textElement) = element.wrappedValue {
                            return textElement
                        }

                        return TextLabelElement.standardNewElement()
                    },
                    set: { updatedElement in
                        element.wrappedValue = .text(updatedElement)
                    }
                ),
                labelSize: document.label,
                variables: document.variables
            )
            selectedElementActions
        case .barcode:
            BarcodeElementInspector(
                element: Binding(
                    get: {
                        if case .barcode(let barcodeElement) = element.wrappedValue {
                            return barcodeElement
                        }

                        return BarcodeLabelElement.standardNewElement()
                    },
                    set: { updatedElement in
                        element.wrappedValue = .barcode(updatedElement)
                    }
                ),
                labelSize: document.label,
                variables: document.variables
            )
            selectedElementActions
        case .shape:
            Section("Form") {
                InspectorPlaceholderRow(systemImageName: "rectangle", title: "Form-Inspector folgt später")
            }
            selectedElementActions
        }
    }

    private var selectedElementActions: some View {
        Section("Aktionen") {
            Button(role: .destructive) {
                if let selectedElementID {
                    deleteElement(id: selectedElementID)
                }
            } label: {
                Label("Element löschen", systemImage: "trash")
            }
        }
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
                document.elements = document.elements.map { element in
                    element.replacingFrame(element.frame.clamped(to: labelSize))
                }
                document.guides = document.guides.map { guide in
                    guide.clamped(to: labelSize)
                }
            }
        )
    }

    private var selectedVariableBinding: Binding<VariableDefinition>? {
        guard let selectedVariableID,
              document.variables.contains(where: { $0.id == selectedVariableID }) else {
            return document.variables.first.map { variable in
                Binding(
                    get: {
                        document.variables.first(where: { $0.id == variable.id }) ?? variable
                    },
                    set: { updatedVariable in
                        guard let index = document.variables.firstIndex(where: { $0.id == variable.id }) else {
                            return
                        }

                        document.variables[index] = updatedVariable.normalized
                    }
                )
            }
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

                document.variables[index] = updatedVariable.normalized
                document.printSettings = document.printSettings.normalized(for: document.variables)
            }
        )
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
        selectedVariableID = variable.id
    }

    private func deleteVariable(id: UUID) {
        document.variables.removeAll { $0.id == id }
        document.printSettings = document.printSettings.normalized(for: document.variables)

        if selectedVariableID == id {
            selectedVariableID = document.variables.first?.id
        }
    }

    private func deleteGuide(id: UUID) {
        document.guides.removeAll { $0.id == id }
    }

    private func deleteElement(id: UUID) {
        document.elements.removeAll { $0.id == id }

        if selectedElementID == id {
            selectedElementID = nil
        }
    }

    private func formatMillimeters(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }
}

private struct SidebarChromeHeader: View {
    let toggleSidebar: () -> Void

    var body: some View {
        HStack {
            Spacer()

            Button(action: toggleSidebar) {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 18, weight: .regular))
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 30, height: 28)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .help("Sidebar ausblenden")
        }
        .padding(.leading, 96)
        .padding(.trailing, 20)
        .padding(.top, 18)
        .frame(height: 78)
        .background(.bar)
    }
}

private struct TextElementInspector: View {
    @Binding var element: TextLabelElement
    let labelSize: LabelSize
    let variables: [VariableDefinition]

    var body: some View {
        Section("Inhalt") {
            TextEditor(text: $element.text)
                .font(TextLabelFontCatalog.swiftUIFont(
                    familyName: element.fontFamilyName,
                    size: 12,
                    isBold: element.isBold
                ))
                .frame(minHeight: 74)
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1)
                }

            VariableInsertMenu(variables: variables) { variable in
                element.text.append(variable.placeholder)
            }
        }

        Section("Typografie") {
            Picker("Schrift", selection: $element.fontFamilyName) {
                ForEach(TextLabelFontCatalog.fontFamilyNames, id: \.self) { familyName in
                    Text(TextLabelFontCatalog.displayName(for: familyName))
                        .tag(familyName)
                }
            }

            IntegerInspectorField(title: "Größe", value: clampedBinding(\.fontSizeDots, 6...200))

            Picker("Ausrichtung", selection: $element.alignment) {
                ForEach(TextElementAlignment.allCases, id: \.self) { alignment in
                    Text(alignment.displayName)
                        .tag(alignment)
                }
            }

            HStack {
                Toggle("B", isOn: $element.isBold)
                    .toggleStyle(.button)
                    .fontWeight(.bold)
                    .help("Fett")

                Toggle("I", isOn: $element.isItalic)
                    .toggleStyle(.button)
                    .italic()
                    .help("Kursiv")

                Toggle("U", isOn: $element.isUnderlined)
                    .toggleStyle(.button)
                    .underline()
                    .help("Unterstrichen")
            }
            .controlSize(.small)
        }

        frameSection
    }

    private var frameSection: some View {
        Section("Position") {
            IntegerInspectorField(title: "X", value: frameBinding(\.xDots))
            IntegerInspectorField(title: "Y", value: frameBinding(\.yDots))
            IntegerInspectorField(title: "W", value: frameBinding(\.widthDots, minimum: 1))
            IntegerInspectorField(title: "H", value: frameBinding(\.heightDots, minimum: 1))
        }
    }

    private func frameBinding(
        _ keyPath: WritableKeyPath<LabelElementFrame, Int>,
        minimum: Int = 0
    ) -> Binding<Int> {
        Binding(
            get: { element.frame[keyPath: keyPath] },
            set: { newValue in
                var frame = element.frame
                frame[keyPath: keyPath] = max(minimum, newValue)
                element.frame = frame.clamped(to: labelSize)
            }
        )
    }

    private func clampedBinding(
        _ keyPath: WritableKeyPath<TextLabelElement, Int>,
        _ range: ClosedRange<Int>
    ) -> Binding<Int> {
        Binding(
            get: { element[keyPath: keyPath] },
            set: { element[keyPath: keyPath] = min(max($0, range.lowerBound), range.upperBound) }
        )
    }
}

private struct BarcodeElementInspector: View {
    @Binding var element: BarcodeLabelElement
    let labelSize: LabelSize
    let variables: [VariableDefinition]

    var body: some View {
        Section("Barcode") {
            TextField("Wert", text: $element.value)
                .textFieldStyle(.roundedBorder)

            VariableInsertMenu(variables: variables) { variable in
                element.value.append(variable.placeholder)
            }

            Picker("Typ", selection: $element.symbology) {
                Text(BarcodeSymbology.code128.displayName)
                    .tag(BarcodeSymbology.code128)
            }

            IntegerInspectorField(title: "Modulbreite", value: clampedBinding(\.moduleWidth, 1...12))
            IntegerInspectorField(title: "Höhe", value: frameBinding(\.heightDots, minimum: 1))
            Toggle("Klarschrift", isOn: $element.showsHumanReadableText)
        }

        Section("Position") {
            IntegerInspectorField(title: "X", value: frameBinding(\.xDots))
            IntegerInspectorField(title: "Y", value: frameBinding(\.yDots))
            IntegerInspectorField(title: "W", value: frameBinding(\.widthDots, minimum: 1))
            IntegerInspectorField(title: "H", value: frameBinding(\.heightDots, minimum: 1))
        }
    }

    private func frameBinding(
        _ keyPath: WritableKeyPath<LabelElementFrame, Int>,
        minimum: Int = 0
    ) -> Binding<Int> {
        Binding(
            get: { element.frame[keyPath: keyPath] },
            set: { newValue in
                var frame = element.frame
                frame[keyPath: keyPath] = max(minimum, newValue)
                element.frame = frame.clamped(to: labelSize)
            }
        )
    }

    private func clampedBinding(
        _ keyPath: WritableKeyPath<BarcodeLabelElement, Int>,
        _ range: ClosedRange<Int>
    ) -> Binding<Int> {
        Binding(
            get: { element[keyPath: keyPath] },
            set: { element[keyPath: keyPath] = min(max($0, range.lowerBound), range.upperBound) }
        )
    }
}

private struct GuideEditorRow: View {
    @Binding var guide: GuideElement
    let labelSize: LabelSize
    let delete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: guide.orientation == .vertical ? "line.diagonal" : "minus")
                    .foregroundStyle(.secondary)
                    .frame(width: 18)

                TextField("Name", text: $guide.name)
                    .textFieldStyle(.roundedBorder)

                Button(role: .destructive, action: delete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Hilfslinie löschen")
            }

            Picker("Richtung", selection: $guide.orientation) {
                ForEach(GuideOrientation.allCases, id: \.self) { orientation in
                    Text(orientation.displayName)
                        .tag(orientation)
                }
            }
            .onChange(of: guide.orientation) { _, _ in
                guide.positionDots = min(guide.positionDots, maximumPosition)
            }

            IntegerInspectorField(title: "Position", value: positionBinding)
                .disabled(guide.locked)

            HStack {
                Toggle("Sichtbar", isOn: $guide.visible)
                Toggle("Gesperrt", isOn: $guide.locked)
            }
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }

    private var maximumPosition: Int {
        guide.orientation == .vertical
            ? labelSize.widthDots
            : labelSize.heightDots
    }

    private var positionBinding: Binding<Int> {
        Binding(
            get: { guide.positionDots },
            set: { guide.positionDots = min(max($0, 0), maximumPosition) }
        )
    }
}

private struct ElementListRow: View {
    let element: LabelElement
    let isSelected: Bool
    let select: () -> Void
    let delete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: select) {
                HStack(spacing: 8) {
                    Image(systemName: iconName)
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                        Text("\(element.frame.xDots), \(element.frame.yDots)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: delete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("Element löschen")
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            select()
        }
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.accentColor.opacity(0.16))
            }
        }
    }

    private var iconName: String {
        switch element {
        case .text:
            return "textformat"
        case .barcode:
            return "barcode"
        case .shape:
            return "rectangle"
        }
    }

    private var title: String {
        switch element {
        case .text(let textElement):
            return textElement.text.isEmpty ? "Text" : textElement.text
        case .barcode(let barcodeElement):
            return barcodeElement.value.isEmpty ? "Barcode" : barcodeElement.value
        case .shape(let shapeElement):
            return shapeElement.name
        }
    }
}

private struct VariableEditorSection: View {
    @Binding var variable: VariableDefinition
    let canDelete: Bool
    let delete: () -> Void

    var body: some View {
        Section("Variable") {
            TextField("Name", text: $variable.name)
                .textFieldStyle(.roundedBorder)

            Picker("Typ", selection: $variable.type) {
                ForEach(VariableType.allCases, id: \.self) { type in
                    Text(type.displayName)
                        .tag(type)
                }
            }

            TextField("Format", text: $variable.format)
                .textFieldStyle(.roundedBorder)

            TextField("Präfix", text: $variable.prefix)
                .textFieldStyle(.roundedBorder)

            IntegerInspectorField(title: "Schritt", value: clampedBinding(\.step, minimum: 1))

            InspectorValueRow(label: "Platzhalter", value: variable.placeholder)
        }

        Section("Aktionen") {
            Button(role: .destructive, action: delete) {
                Label("Variable löschen", systemImage: "trash")
            }
            .disabled(!canDelete)
            .help("Variable löschen")
        }
    }

    private func clampedBinding(
        _ keyPath: WritableKeyPath<VariableDefinition, Int>,
        minimum: Int
    ) -> Binding<Int> {
        Binding(
            get: { variable[keyPath: keyPath] },
            set: { variable[keyPath: keyPath] = max(minimum, $0) }
        )
    }
}

private struct VariableInsertMenu: View {
    let variables: [VariableDefinition]
    let insert: (VariableDefinition) -> Void

    var body: some View {
        Menu {
            if variables.isEmpty {
                Text("Keine Variablen")
            } else {
                ForEach(variables) { variable in
                    Button(variable.chipTitle) {
                        insert(variable)
                    }
                }
            }
        } label: {
            HStack {
                Image(systemName: "curlybraces")
                Text("Variable einfügen")
                Spacer(minLength: 8)
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 8)
            .frame(minHeight: 26)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.78))
            }
        }
        .menuStyle(.borderlessButton)
        .controlSize(.small)
    }
}

private struct VariableChipCloud: View {
    let variables: [VariableDefinition]
    let selectedVariableID: UUID?
    let select: (VariableDefinition) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 82), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(variables) { variable in
                Button {
                    select(variable)
                } label: {
                    VariableChipView(
                        variable: variable,
                        isSelected: selectedVariableID == variable.id
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct VariableChipView: View {
    let variable: VariableDefinition
    var isSelected = false
    var isCompact = false
    var isRunning = false

    var body: some View {
        HStack(spacing: 4) {
            if isRunning {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: isCompact ? 8 : 9, weight: .bold))
            }

            Text(variable.name.isEmpty ? "variable" : variable.name)
                .font(.system(size: isCompact ? 10 : 11, weight: .medium))
                .lineLimit(1)

            if variable.type == .sequence, !variable.format.isEmpty {
                Text("· \(variable.format)")
                    .font(.system(size: isCompact ? 9 : 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, isCompact ? 7 : 8)
        .padding(.vertical, isCompact ? 4 : 5)
        .background {
            Capsule()
                .fill(chipFill)
        }
        .overlay {
            Capsule()
                .stroke(chipStroke, lineWidth: 1)
        }
        .foregroundStyle(isRunning ? Color.orange.opacity(0.92) : (isSelected ? Color.accentColor : Color.primary))
    }

    private var chipFill: Color {
        if isRunning {
            return Color.orange.opacity(isSelected ? 0.22 : 0.16)
        }

        return isSelected ? ZPrintDesign.ColorToken.selectedFill : Color(nsColor: .controlBackgroundColor).opacity(0.78)
    }

    private var chipStroke: Color {
        if isRunning {
            return Color.orange.opacity(0.46)
        }

        return isSelected ? ZPrintDesign.ColorToken.accent.opacity(0.38) : ZPrintDesign.ColorToken.softBorder
    }
}

private struct SidebarNavigationRow: View {
    let title: String
    let systemImageName: String
    var count: Int?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImageName)
                .font(.system(size: 16, weight: .regular))
                .frame(width: 22)

            Text(title)
                .font(.system(size: 15, weight: .medium))

            Spacer()

            if let count {
                Text("\(count)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .frame(minHeight: 26)
    }
}

private struct InspectorValueRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
        }
        .font(.system(size: 13))
        .frame(minHeight: 22)
    }
}

private struct IntegerInspectorField: View {
    let title: String
    @Binding var value: Int

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 58, alignment: .leading)

            Spacer()

            ZPrintNumberStepperField(
                title: title,
                value: $value,
                width: 116
            )
        }
        .controlSize(.small)
    }
}

private struct InspectorPlaceholderRow: View {
    let systemImageName: String
    let title: String

    var body: some View {
        Label(title, systemImage: systemImageName)
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .frame(minHeight: 22)
    }
}

private extension VariableDefinition {
    var normalized: VariableDefinition {
        var variable = self
        variable.name = variable.name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "_")
        variable.step = max(1, variable.step)
        return variable
    }
}
