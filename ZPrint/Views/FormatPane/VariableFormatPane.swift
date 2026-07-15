//
//  VariableFormatPane.swift
//  ZPrint
//

import AppKit
import SwiftUI

struct VariableFormatPane: View {
    @Binding var variable: VariableDefinition
    let variables: [VariableDefinition]
    @Binding var tableSources: [TableDataSource]
    let delete: () -> Void
    @State private var replacingTableSourceID: UUID?
    @State private var importErrorMessage: String?
    @State private var statusMessage: String?
    @State private var isLoadingTableSource = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FormatSection(title: "Variable bearbeiten") {
                PropertyRow(title: "Name") {
                    TextField("Name", text: normalizedNameBinding)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                }

                PropertyRow(title: "Typ") {
                    Picker("Typ", selection: variableTypeBinding) {
                        ForEach(VariableType.allCases, id: \.self) { type in
                            Text(type.displayName)
                                .tag(type)
                        }
                    }
                    .labelsHidden()
                    .controlSize(.small)
                }

                PropertyRow(title: "Format") {
                    TextField("Format", text: $variable.format)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                }
                .disabled(variable.type != .sequence)
                .opacity(variable.type == .sequence ? 1 : 0.45)
            }

            if variable.type == .sequence {
                sequenceSection
            }

            if variable.type == .tableLookup {
                lookupSections
            }

            FormatSection(title: "Platzhalter") {
                Text(variable.placeholder)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            FormatSection(title: "Aktionen") {
                Button(role: .destructive, action: delete) {
                    Label("Variable löschen", systemImage: "trash")
                }
                .controlSize(.small)
            }
        }
        .alert("Tabelle konnte nicht geladen werden", isPresented: importErrorPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importErrorMessage ?? "Unbekannter Fehler")
        }
    }

    private var sequenceSection: some View {
        FormatSection(title: "Sequenz") {
            PropertyRow(title: "Präfix") {
                TextField("Optional", text: $variable.prefix)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
            }

            IntegerPropertyField(title: "Schritt", value: clampedBinding(\.step, minimum: 1))
        }
    }

    private var lookupSections: some View {
        Group {
            FormatSection(title: "Verknüpfung") {
                PropertyRow(title: "Quellvariable") {
                    Picker("Quellvariable", selection: sourceVariableBinding) {
                        Text("Auswählen").tag(nil as UUID?)
                        ForEach(sourceVariables) { sourceVariable in
                            Text(sourceVariable.name).tag(sourceVariable.id as UUID?)
                        }
                    }
                    .labelsHidden()
                    .controlSize(.small)
                }

                PropertyRow(title: "Datei") {
                    Picker("Datei", selection: tableSourceBinding) {
                        Text("Keine Datei").tag(nil as UUID?)
                        ForEach(tableSources) { source in
                            Text(source.displayName).tag(source.id as UUID?)
                        }
                    }
                    .labelsHidden()
                    .controlSize(.small)
                }

                HStack(spacing: 6) {
                    Button {
                        chooseTableFile(replacingID: nil)
                    } label: {
                        Label("Datei auswählen", systemImage: "folder")
                    }

                    Button(action: refreshCurrentSource) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Verknüpfte Datei aktualisieren")
                    .disabled(currentTableSource == nil || isLoadingTableSource)

                    Button {
                        chooseTableFile(replacingID: currentTableSource?.id)
                    } label: {
                        Image(systemName: "link")
                    }
                    .help("Quelldatei neu verknüpfen")
                    .disabled(currentTableSource == nil || isLoadingTableSource)
                }
                .controlSize(.small)
                .disabled(isLoadingTableSource)

                if let currentTableSource {
                    Text("\(currentTableSource.sheets.count) Tabellenblätter · \(currentTableSource.totalRowCount) Datenzeilen")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                    if !currentTableSource.sourcePath.isEmpty {
                        Text(currentTableSource.sourcePath)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                            .help(currentTableSource.sourcePath)
                    }
                }

                if let statusMessage {
                    Text(statusMessage)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            FormatSection(title: "Zuordnung") {
                PropertyRow(title: "Tabellenblatt") {
                    Picker("Tabellenblatt", selection: sheetNameBinding) {
                        ForEach(currentTableSource?.sheets ?? []) { sheet in
                            Text(sheet.name).tag(sheet.name)
                        }
                    }
                    .labelsHidden()
                    .controlSize(.small)
                }
                .disabled(currentTableSource == nil)

                PropertyRow(title: "Schlüsselspalte") {
                    Picker("Schlüsselspalte", selection: keyColumnBinding) {
                        ForEach(currentSheet?.headers ?? [], id: \.self) { header in
                            Text(header).tag(header)
                        }
                    }
                    .labelsHidden()
                    .controlSize(.small)
                }
                .disabled(currentSheet == nil)

                PropertyRow(title: "Wertspalte") {
                    Picker("Wertspalte", selection: valueColumnBinding) {
                        ForEach(currentSheet?.headers ?? [], id: \.self) { header in
                            Text(header).tag(header)
                        }
                    }
                    .labelsHidden()
                    .controlSize(.small)
                }
                .disabled(currentSheet == nil)

                Toggle("Groß-/Kleinschreibung beachten", isOn: caseSensitiveBinding)
                    .controlSize(.small)

                PropertyRow(title: "Falls leer") {
                    TextField("Optional", text: fallbackBinding)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                }

                if let currentSheet {
                    let duplicates = currentSheet.duplicateKeyCount(
                        in: lookupConfiguration.keyColumn,
                        caseSensitive: lookupConfiguration.caseSensitive
                    )
                    if duplicates > 0 {
                        Label("\(duplicates) doppelte Schlüssel; der erste Treffer wird verwendet.", systemImage: "exclamationmark.triangle")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var sourceVariables: [VariableDefinition] {
        variables.filter { $0.id != variable.id && $0.type != .tableLookup }
    }

    private var lookupConfiguration: TableLookupConfiguration {
        variable.tableLookup ?? defaultLookupConfiguration()
    }

    private var currentTableSource: TableDataSource? {
        guard let id = lookupConfiguration.tableSourceID else {
            return nil
        }
        return tableSources.first { $0.id == id }
    }

    private var currentSheet: TableSheetSnapshot? {
        currentTableSource?.sheet(named: lookupConfiguration.sheetName)
    }

    private var variableTypeBinding: Binding<VariableType> {
        Binding(
            get: { variable.type },
            set: { newType in
                variable.type = newType
                if newType == .tableLookup, variable.tableLookup == nil {
                    variable.tableLookup = defaultLookupConfiguration()
                }
            }
        )
    }

    private var sourceVariableBinding: Binding<UUID?> {
        lookupBinding(\.sourceVariableID)
    }

    private var tableSourceBinding: Binding<UUID?> {
        Binding(
            get: { lookupConfiguration.tableSourceID },
            set: { newValue in
                updateLookup { configuration in
                    configuration.tableSourceID = newValue
                    configureColumns(in: &configuration, sourceID: newValue)
                }
            }
        )
    }

    private var sheetNameBinding: Binding<String> {
        Binding(
            get: { lookupConfiguration.sheetName },
            set: { newValue in
                updateLookup { configuration in
                    configuration.sheetName = newValue
                    configureColumns(in: &configuration, sourceID: configuration.tableSourceID, sheetName: newValue)
                }
            }
        )
    }

    private var keyColumnBinding: Binding<String> {
        lookupBinding(\.keyColumn)
    }

    private var valueColumnBinding: Binding<String> {
        lookupBinding(\.valueColumn)
    }

    private var fallbackBinding: Binding<String> {
        lookupBinding(\.fallbackValue)
    }

    private var caseSensitiveBinding: Binding<Bool> {
        lookupBinding(\.caseSensitive)
    }

    private func lookupBinding<Value>(_ keyPath: WritableKeyPath<TableLookupConfiguration, Value>) -> Binding<Value> {
        Binding(
            get: { lookupConfiguration[keyPath: keyPath] },
            set: { newValue in
                updateLookup { $0[keyPath: keyPath] = newValue }
            }
        )
    }

    private func updateLookup(_ update: (inout TableLookupConfiguration) -> Void) {
        var configuration = lookupConfiguration
        update(&configuration)
        variable.tableLookup = configuration
    }

    private func defaultLookupConfiguration() -> TableLookupConfiguration {
        var configuration = TableLookupConfiguration(
            sourceVariableID: sourceVariables.first(where: { $0.type == .sequence })?.id
                ?? sourceVariables.first?.id
        )
        configureColumns(in: &configuration, sourceID: tableSources.first?.id)
        return configuration
    }

    private func configureColumns(
        in configuration: inout TableLookupConfiguration,
        sourceID: UUID?,
        sheetName: String? = nil
    ) {
        configuration.tableSourceID = sourceID
        guard let sourceID,
              let source = tableSources.first(where: { $0.id == sourceID }),
              let sheet = sheetName.flatMap({ source.sheet(named: $0) }) ?? source.sheets.first else {
            configuration.sheetName = ""
            configuration.keyColumn = ""
            configuration.valueColumn = ""
            return
        }

        configuration.sheetName = sheet.name
        configuration.keyColumn = sheet.headers.first ?? ""
        configuration.valueColumn = sheet.headers.dropFirst().first ?? sheet.headers.first ?? ""
    }

    private var normalizedNameBinding: Binding<String> {
        Binding(
            get: { variable.name },
            set: { newValue in
                variable.name = newValue
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: " ", with: "_")
            }
        )
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

    private var importErrorPresented: Binding<Bool> {
        Binding(
            get: { importErrorMessage != nil },
            set: { if !$0 { importErrorMessage = nil } }
        )
    }

    private func chooseTableFile(replacingID: UUID?) {
        let panel = NSOpenPanel()
        panel.title = replacingID == nil ? "Tabelle importieren" : "Tabellendatei neu verknüpfen"
        panel.prompt = replacingID == nil ? "Importieren" : "Verknüpfen"
        panel.allowedContentTypes = TableDataImporter.allowedContentTypes
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK,
              let url = panel.url else {
            return
        }

        replacingTableSourceID = replacingID
        importTable(from: url, preservingID: replacingID ?? UUID())
    }

    private func importTable(from url: URL, preservingID sourceID: UUID) {
        isLoadingTableSource = true
        statusMessage = "Tabelle wird eingelesen ..."

        Task {
            do {
                let importedSource = try await Task.detached(priority: .userInitiated) {
                    try TableDataImporter.load(from: url, preservingID: sourceID)
                }.value

                if let index = tableSources.firstIndex(where: { $0.id == importedSource.id }) {
                    tableSources[index] = importedSource
                } else {
                    tableSources.append(importedSource)
                }

                updateLookup { configuration in
                    configureColumns(in: &configuration, sourceID: importedSource.id)
                }
                statusMessage = "\(importedSource.fileName) wurde mit \(importedSource.totalRowCount) Datenzeilen geladen."
            } catch {
                importErrorMessage = error.localizedDescription
                statusMessage = nil
            }

            replacingTableSourceID = nil
            isLoadingTableSource = false
        }
    }

    private func refreshCurrentSource() {
        guard let source = currentTableSource,
              tableSources.contains(where: { $0.id == source.id }) else {
            return
        }

        isLoadingTableSource = true
        statusMessage = "Tabelle wird aktualisiert ..."
        Task {
            do {
                let refreshedSource = try await Task.detached(priority: .userInitiated) {
                    try TableDataImporter.refresh(source)
                }.value
                guard let index = tableSources.firstIndex(where: { $0.id == source.id }) else {
                    isLoadingTableSource = false
                    return
                }

                tableSources[index] = refreshedSource
                updateLookup { configuration in
                    let previousSheet = configuration.sheetName
                    configureColumns(
                        in: &configuration,
                        sourceID: refreshedSource.id,
                        sheetName: refreshedSource.sheet(named: previousSheet) == nil ? nil : previousSheet
                    )
                }
                statusMessage = "Aktualisiert: \(refreshedSource.totalRowCount) Datenzeilen."
            } catch {
                importErrorMessage = error.localizedDescription
                statusMessage = nil
            }

            isLoadingTableSource = false
        }
    }
}
