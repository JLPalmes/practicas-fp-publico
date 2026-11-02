// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Juan Luis (JLPalmes)
import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ImportView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @LocalState<ImportBook?> private var book: ImportBook?
    @LocalState<URL?> private var source: URL?
    @LocalState<Int> private var sheetIndex = 0
    @LocalState<Int> private var header = 0
    @LocalState<[StudentField: Int]> private var mapping = [:]
    @LocalState<Set<Int>> private var excluded = []
    @LocalState<String?> private var error: String?
    @LocalState<Bool> private var loading = false
    @LocalState<String> private var delimiter = "Automático"
    var sheet: ImportSheet? {
        guard let book, book.sheets.indices.contains(sheetIndex) else { return nil }
        return book.sheets[sheetIndex]
    }
    var headers: [ImportCell] {
        guard let sheet, sheet.rows.indices.contains(header) else { return [] }
        return sheet.rows[header]
    }
    var mappingOK: Bool { mapping[.name] != nil && Set(mapping.values).count == mapping.values.count }
    var rows: [ImportPreviewRow] {
        guard let sheet, mappingOK else { return [] }
        return StudentImporter.preview(sheet, header: header, mapping: mapping, existing: store.db.students, excluded: excluded)
    }
    var accepted: [Student] { rows.filter { $0.issue == nil && !$0.excluded }.map(\.student) }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Importar alumnas").font(.title.bold())
                    Text("CSV o Excel (.xlsx) · todo se procesa en este Mac").foregroundStyle(.secondary)
                }
                Spacer()
                Button("Elegir archivo…", action: choose).disabled(loading)
            }
            if let source { Text(source.lastPathComponent).font(.headline).textSelection(.enabled) }
            if loading { ProgressView("Leyendo archivo…") }
            if let error { Text(error).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true) }
            if let book, let sheet {
                HStack {
                    Picker("Hoja", selection: $sheetIndex) { ForEach(book.sheets.indices, id: \.self) { Text(book.sheets[$0].name).tag($0) } }
                        .onChange(of: sheetIndex) { _, _ in header = 0; resetMapping() }
                    Stepper("Cabecera en fila \(header + 1)", value: $header, in: 0...max(0, min(99, sheet.rows.count - 1)))
                        .onChange(of: header) { _, _ in resetMapping() }
                    if source?.pathExtension.lowercased() != "xlsx" {
                        Picker("Separador", selection: $delimiter) { ForEach(["Automático","Punto y coma","Coma","Tabulador"], id: \.self) { Text($0) } }
                            .onChange(of: delimiter) { _, _ in if let source { read(source) } }
                    }
                }.disabled(loading)
                Divider()
                HStack(alignment: .top, spacing: 20) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Relaciona las columnas").font(.headline)
                            ForEach(StudentField.allCases) { field in
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(field.title).font(.caption).foregroundStyle(.secondary)
                                    Picker(field.title, selection: Binding(get: { mapping[field] ?? -1 }, set: { value in
                                        if value < 0 { mapping.removeValue(forKey: field) } else { mapping[field] = value }
                                        excluded = []
                                    })) {
                                        Text("No importar").tag(-1)
                                        ForEach(headers.indices, id: \.self) { i in
                                            Text("\(i + 1) · \(headers[i].text.isEmpty ? "Columna sin título" : headers[i].text)").tag(i)
                                        }
                                    }.labelsHidden()
                                }
                            }
                            Text("Solo el nombre es obligatorio. Si los apellidos están en otras columnas, selecciónalas también.").font(.caption).foregroundStyle(.secondary)
                        }.padding(.trailing, 6)
                    }.frame(width: 280)
                    Divider()
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Vista previa").font(.headline)
                        if !mappingOK { Text("Selecciona la columna del nombre y usa cada columna una sola vez.").foregroundStyle(.orange) }
                        else if rows.isEmpty { Text("No hay filas de datos después de la cabecera.").foregroundStyle(.secondary) }
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 12) {
                                ForEach(rows) { row in
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Toggle("", isOn: Binding(get: { !excluded.contains(row.id) }, set: { value in
                                                if value { excluded.remove(row.id) } else { excluded.insert(row.id) }
                                            })).labelsHidden()
                                            Text("Fila \(row.id + 1) · \(row.student.name.isEmpty ? "Sin nombre" : row.student.name)").bold()
                                            Spacer()
                                        }
                                        if row.excluded { Text("Excluida").foregroundStyle(.secondary) }
                                        else if let issue = row.issue { Text(issue).foregroundStyle(.orange) }
                                        else { Text("Se añadirá").foregroundStyle(accent) }
                                        Text("DNI: \(row.student.dni) · NUSS: \(row.student.nuss)").textSelection(.enabled)
                                        Text("Email: \(row.student.email) · Teléfono: \(row.student.phone)").textSelection(.enabled)
                                        DisclosureGroup("Grupo, preferencias y observaciones") {
                                            VStack(alignment: .leading) {
                                                Text("Grupo: \(row.student.group)")
                                                Text("Tipo de empresa: \(row.student.preferredType)")
                                                Text("Zona: \(row.student.preferredZone)")
                                                Text("Preferencias: \(row.student.preferences)")
                                                Text("Observaciones: \(row.student.notes)")
                                            }.frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }.font(.callout).padding(12).background(.quaternary.opacity(0.35)).clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.disabled(loading)
            } else if !loading {
                ContentUnavailableView("Elige una lista de alumnas", systemImage: "tablecells", description: Text("El archivo debe tener una fila con los nombres de las columnas. Puedes escoger la hoja y la fila de cabecera."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Divider()
            Text("Se crearán fichas pendientes de asignación. Los posibles duplicados y las filas con errores se omiten. Se guarda una copia local antes de importar.").font(.caption).foregroundStyle(.secondary)
            HStack {
                Text("\(accepted.count) para añadir · \(rows.count - accepted.count) omitidas").font(.callout)
                Spacer()
                Button("Cancelar") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Importar \(accepted.count) alumnas") {
                    do {
                        try store.importStudents(accepted)
                        dismiss()
                    } catch { self.error = error.localizedDescription }
                }.buttonStyle(.borderedProminent).disabled(loading || accepted.isEmpty || !mappingOK)
            }
        }.padding(24).frame(width: 1020, height: 760)
    }
    func resetMapping() { mapping = StudentImporter.guessMapping(headers); excluded = []; error = nil }
    func choose() {
        let panel = NSOpenPanel(); panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType.commaSeparatedText, UTType.tabSeparatedText, UTType(filenameExtension: "xlsx")!]
        panel.message = "Selecciona CSV o Excel .xlsx con los datos de las alumnas."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        read(url)
    }
    func read(_ url: URL) {
        loading = true; error = nil; book = nil; source = url
        let separator: Character? = ["Punto y coma": ";", "Coma": ",", "Tabulador": "\t"][delimiter]
        Task {
            do {
                let loaded = try await Task.detached(priority: .userInitiated) { try TabularReader.read(url, delimiter: separator) }.value
                book = loaded; sheetIndex = 0; header = 0; resetMapping()
            } catch { self.error = error.localizedDescription }
            loading = false
        }
    }
}
