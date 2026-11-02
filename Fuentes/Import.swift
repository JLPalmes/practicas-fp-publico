// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Juan Luis (JLPalmes)
import Foundation

struct ImportFailure: LocalizedError {
    var message: String
    var errorDescription: String? { message }
}
struct ImportCell {
    var text = ""
    var issue: String?
}
struct ImportSheet {
    var name: String
    var rows: [[ImportCell]]
}
struct ImportBook {
    var sheets: [ImportSheet]
}
enum StudentField: String, CaseIterable, Identifiable {
    case name, surnames, surname2, dni, nuss, email, phone, group, preferredType, preferredZone, preferences, notes
    var id: String { rawValue }
    var title: String {
        switch self {
        case .name: return "Nombre o nombre completo"
        case .surnames: return "Apellidos / primer apellido"
        case .surname2: return "Segundo apellido"
        case .dni: return "DNI / NIE"
        case .nuss: return "NUSS"
        case .email: return "Email"
        case .phone: return "Teléfono"
        case .group: return "Grupo"
        case .preferredType: return "Tipo de empresa preferido"
        case .preferredZone: return "Zona preferida"
        case .preferences: return "Detalle de preferencias"
        case .notes: return "Observaciones"
        }
    }
    var aliases: [String] {
        switch self {
        case .name: return ["nombre", "nombre completo", "nombre y apellidos", "alumna", "alumno", "alumnado"]
        case .surnames: return ["apellidos", "primer apellido", "apellido1", "apellido 1"]
        case .surname2: return ["segundo apellido", "apellido2", "apellido 2"]
        case .dni: return ["dni", "nie", "dni nie", "documento", "nif"]
        case .nuss: return ["nuss", "naf", "numero seguridad social", "seguridad social", "n ss"]
        case .email: return ["email", "e mail", "correo", "correo electronico"]
        case .phone: return ["telefono", "movil", "telefono movil"]
        case .group: return ["grupo", "curso"]
        case .preferredType: return ["tipo de empresa", "tipo de empresa preferido", "empresa preferida"]
        case .preferredZone: return ["zona", "zona preferida"]
        case .preferences: return ["preferencias", "detalle de preferencias"]
        case .notes: return ["observaciones", "notas"]
        }
    }
}
func importKey(_ value: String) -> String {
    value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es_ES"))
        .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: " ")
}
func identityKeys(_ s: Student) -> Set<String> {
    var keys = Set<String>()
    for (prefix, value) in [("dni", s.dni), ("nuss", s.nuss), ("email", s.email)] {
        let key = value.folding(options: [.caseInsensitive], locale: Locale(identifier: "es_ES")).filter { !$0.isWhitespace && $0 != "-" }
        if !key.isEmpty { keys.insert(prefix + ":" + key) }
    }
    let name = importKey(s.name).split(separator: " ").sorted().joined(separator: " ")
    if !name.isEmpty { keys.insert("nombre:" + name) }
    return keys
}
struct ImportPreviewRow: Identifiable {
    var id: Int
    var student: Student
    var issue: String?
    var excluded: Bool
}
enum StudentImporter {
    static func guessMapping(_ headers: [ImportCell]) -> [StudentField: Int] {
        var result: [StudentField: Int] = [:]
        var used = Set<Int>()
        for field in StudentField.allCases {
            if let i = headers.indices.first(where: { !used.contains($0) && field.aliases.contains(importKey(headers[$0].text)) }) {
                result[field] = i; used.insert(i)
            }
        }
        return result
    }
    static func preview(_ sheet: ImportSheet, header: Int, mapping: [StudentField: Int], existing: [Student], excluded: Set<Int> = []) -> [ImportPreviewRow] {
        guard sheet.rows.indices.contains(header) else { return [] }
        var seen = existing.reduce(into: Set<String>()) { $0.formUnion(identityKeys($1)) }
        var output: [ImportPreviewRow] = []
        for index in sheet.rows.indices where index > header {
            let row = sheet.rows[index]
            if row.allSatisfy({ $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.issue == nil }) { continue }
            func cell(_ field: StudentField) -> ImportCell {
                guard let c = mapping[field], row.indices.contains(c) else { return ImportCell() }
                return row[c]
            }
            func value(_ field: StudentField) -> String { cell(field).text.trimmingCharacters(in: .whitespacesAndNewlines) }
            var s = Student()
            s.name = [value(.name), value(.surnames), value(.surname2)].filter { !$0.isEmpty }.joined(separator: " ")
            s.dni = value(.dni); s.nuss = value(.nuss); s.email = value(.email); s.phone = value(.phone)
            s.group = value(.group); s.preferredType = value(.preferredType); s.preferredZone = value(.preferredZone)
            s.preferences = value(.preferences); s.notes = value(.notes)
            var issue: String?
            if value(.name).isEmpty { issue = "Falta el nombre." }
            if let bad = StudentField.allCases.first(where: { cell($0).issue != nil }) {
                issue = bad.title + ": " + (cell(bad).issue ?? "")
            }
            if !seen.isDisjoint(with: identityKeys(s)) { issue = "Posible duplicado por nombre, DNI, NUSS o email." }
            let skipped = excluded.contains(index)
            if issue == nil && !skipped { seen.formUnion(identityKeys(s)) }
            output.append(ImportPreviewRow(id: index, student: s, issue: issue, excluded: skipped))
        }
        return output
    }
}
enum TabularReader {
    static func read(_ url: URL, delimiter: Character? = nil) throws -> ImportBook {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= 20_000_000 else { throw ImportFailure(message: "El archivo supera 20 MB. Guarda una copia con solo la lista de alumnas.") }
        switch url.pathExtension.lowercased() {
        case "csv", "tsv":
            let data = try Data(contentsOf: url)
            let text: String?
            if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]) { text = String(data: data, encoding: .utf16) }
            else { text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .windowsCP1252) }
            guard let text else { throw ImportFailure(message: "No se puede leer la codificación del CSV. Guárdalo como CSV UTF-8.") }
            let clean = text.replacingOccurrences(of: "\u{FEFF}", with: "").replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
            let rows = try csv(clean, separator: delimiter ?? (url.pathExtension.lowercased() == "tsv" ? "\t" : detectDelimiter(clean)))
            return ImportBook(sheets: [ImportSheet(name: url.deletingPathExtension().lastPathComponent, rows: rows.map { $0.map { ImportCell(text: $0) } })])
        case "xlsx": return try xlsx(url)
        default: throw ImportFailure(message: "Selecciona CSV o Excel .xlsx. Si tienes un .xls antiguo, guárdalo como .xlsx o CSV.")
        }
    }
    static func detectDelimiter(_ text: String) -> Character {
        var counts: [Character: Int] = [",": 0, ";": 0, "\t": 0]
        var quoted = false
        for c in text {
            if c == "\"" { quoted.toggle() }
            if c == "\n" && !quoted { break }
            if !quoted && counts[c] != nil { counts[c, default: 0] += 1 }
        }
        return [";", ",", "\t"].max(by: { counts[$0, default: 0] < counts[$1, default: 0] }) ?? ","
    }
    static func csv(_ text: String, separator: Character) throws -> [[String]] {
        var rows: [[String]] = []; var row: [String] = []; var field = ""
        var quoted = false; var afterQuote = false; var atStart = true
        let chars = Array(text); var i = 0
        func endField() throws {
            row.append(field); field = ""; atStart = true; afterQuote = false
            guard row.count <= 256 else { throw ImportFailure(message: "La lista supera 256 columnas.") }
        }
        func endRow() throws {
            try endField(); rows.append(row); row = []
            guard rows.count <= 10000 else { throw ImportFailure(message: "La lista supera 10.000 filas.") }
        }
        while i < chars.count {
            let c = chars[i]
            if quoted {
                if c == "\"" {
                    if i + 1 < chars.count && chars[i + 1] == "\"" { field.append("\""); i += 1 }
                    else { quoted = false; afterQuote = true }
                } else { field.append(c) }
            } else if c == separator { try endField() }
            else if c == "\n" { try endRow() }
            else if c == "\"" && atStart { quoted = true; atStart = false }
            else if afterQuote {
                if c != " " { throw ImportFailure(message: "CSV mal formado: contenido después de una comilla de cierre.") }
            } else { field.append(c); atStart = false }
            i += 1
        }
        guard !quoted else { throw ImportFailure(message: "CSV mal formado: hay comillas sin cerrar.") }
        if !field.isEmpty || !row.isEmpty || afterQuote { try endRow() }
        guard !rows.isEmpty else { throw ImportFailure(message: "El archivo no contiene filas.") }
        return rows
    }
    static func zipPart(_ url: URL, _ path: String) throws -> Data {
        guard !path.contains(".."), !path.hasPrefix("/"), !path.contains("*"), !path.contains("?"), !path.contains("[") else {
            throw ImportFailure(message: "El Excel contiene una referencia de hoja no válida.")
        }
        let task = Process(); task.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        task.arguments = ["-p", url.path, path]
        let pipe = Pipe(); task.standardOutput = pipe; task.standardError = FileHandle.nullDevice
        try task.run()
        var data = Data()
        while true {
            let chunk = pipe.fileHandleForReading.readData(ofLength: 65536)
            if chunk.isEmpty { break }
            data.append(chunk)
            if data.count > 40_000_000 {
                task.terminate(); try? pipe.fileHandleForReading.close()
                task.waitUntilExit()
                throw ImportFailure(message: "El Excel es demasiado grande al descomprimirlo.")
            }
        }
        task.waitUntilExit()
        guard task.terminationStatus == 0 else { throw ImportFailure(message: "No se puede leer el Excel. Comprueba que sea .xlsx y que no esté protegido por contraseña.") }
        return data
    }
    static func xml(_ data: Data) throws -> XMLNode {
        let delegate = XMLTree()
        let parser = XMLParser(data: data); parser.delegate = delegate; parser.shouldResolveExternalEntities = false
        guard parser.parse(), let root = delegate.root else { throw ImportFailure(message: "El Excel contiene datos XML no válidos.") }
        return root
    }
    static func xlsx(_ url: URL) throws -> ImportBook {
        let workbook = try xml(zipPart(url, "xl/workbook.xml"))
        let rels = try xml(zipPart(url, "xl/_rels/workbook.xml.rels"))
        var targets: [String: String] = [:]
        for rel in rels.children where rel.name == "Relationship" && rel.attributes["TargetMode"] != "External" {
            if let id = rel.attributes["Id"], let target = rel.attributes["Target"] {
                targets[id] = target.hasPrefix("/xl/") ? String(target.dropFirst()) : "xl/" + target
            }
        }
        // Optional parts need not exist in Excel workbooks using inline strings.
        let sharedRoot = try? xml(zipPart(url, "xl/sharedStrings.xml"))
        let shared = sharedRoot?.children.filter { $0.name == "si" }.map { $0.richText } ?? []
        let styles = try? xml(zipPart(url, "xl/styles.xml"))
        var formats: [String: String] = [:]
        for format in styles?.child("numFmts")?.children ?? [] {
            if let id = format.attributes["numFmtId"], let code = format.attributes["formatCode"] { formats[id] = code }
        }
        let xfs = styles?.child("cellXfs")?.children ?? []
        var sheets: [ImportSheet] = []
        for sheet in workbook.child("sheets")?.children ?? [] {
            guard let id = sheet.attributes["r:id"], let target = targets[id] else { continue }
            let root = try xml(zipPart(url, target))
            var rows: [[ImportCell]] = []
            for sourceRow in root.child("sheetData")?.children ?? [] {
                let r = (Int(sourceRow.attributes["r"] ?? "") ?? (rows.count + 1)) - 1
                guard r >= 0 && r < 10000 else { throw ImportFailure(message: "La hoja supera 10.000 filas. Guarda una copia con solo el listado.") }
                while rows.count <= r { rows.append([]) }
                for c in sourceRow.children where c.name == "c" {
                    let letters = (c.attributes["r"] ?? "").prefix { $0.isLetter }
                    var col = 0
                    for scalar in letters.uppercased().unicodeScalars { col = col * 26 + Int(scalar.value) - 64 }
                    col = letters.isEmpty ? rows[r].count : col - 1
                    guard col >= 0 && col < 256 else { throw ImportFailure(message: "La hoja supera 256 columnas.") }
                    while rows[r].count <= col { rows[r].append(ImportCell()) }
                    let type = c.attributes["t"] ?? "n"
                    let raw = c.child("v")?.text ?? ""
                    var cell = ImportCell(text: raw)
                    if type == "s" {
                        guard let i = Int(raw), shared.indices.contains(i) else { throw ImportFailure(message: "No se puede leer una celda de texto del Excel.") }
                        cell.text = shared[i]
                    } else if type == "inlineStr" { cell.text = c.child("is")?.richText ?? "" }
                    else if type == "n", !raw.isEmpty {
                        if let decimal = Decimal(string: raw, locale: Locale(identifier: "en_US_POSIX")) { cell.text = NSDecimalNumber(decimal: decimal).stringValue }
                        if let index = Int(c.attributes["s"] ?? ""), xfs.indices.contains(index),
                           let fmt = formats[xfs[index].attributes["numFmtId"] ?? ""],
                           !fmt.isEmpty, fmt.count <= 30, fmt.allSatisfy({ $0 == "0" }),
                           cell.text.allSatisfy({ $0.isNumber }) {
                            cell.text = String(repeating: "0", count: max(0, fmt.count - cell.text.count)) + cell.text
                        }
                        if cell.text.filter({ $0.isNumber }).count > 15 { cell.issue = "Número de más de 15 cifras: guarda esta celda como texto y comprueba su valor." }
                    }
                    if type == "e" { cell.issue = "La celda contiene un error de Excel." }
                    if c.child("f") != nil { cell.issue = "La celda contiene una fórmula. Copia y pega su resultado como valor antes de importar." }
                    rows[r][col] = cell
                }
            }
            sheets.append(ImportSheet(name: sheet.attributes["name"] ?? "Hoja", rows: rows))
        }
        guard !sheets.isEmpty else { throw ImportFailure(message: "El Excel no contiene hojas legibles.") }
        return ImportBook(sheets: sheets)
    }
}
final class XMLNode {
    var name: String; var attributes: [String: String]; var text = ""; var children: [XMLNode] = []
    init(_ name: String, _ attributes: [String: String]) { self.name = name; self.attributes = attributes }
    func child(_ name: String) -> XMLNode? { children.first { $0.name == name } }
    var richText: String { name == "t" ? text : children.filter { $0.name != "rPh" }.map(\.richText).joined() }
}
final class XMLTree: NSObject, XMLParserDelegate {
    var root: XMLNode?; var stack: [XMLNode] = []
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String]) {
        let node = XMLNode(elementName.components(separatedBy: ":").last ?? elementName, attributeDict)
        if let parent = stack.last { parent.children.append(node) } else { root = node }
        stack.append(node)
        if stack.count > 100 { parser.abortParsing() }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) { stack.last?.text += string }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) { _ = stack.popLast() }
}
