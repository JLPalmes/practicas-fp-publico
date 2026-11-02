// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Juan Luis (JLPalmes)
import Foundation

@main struct ImportTests {
    @MainActor static func main() throws {
        let fixture = URL(fileURLWithPath: CommandLine.arguments[1])
        func check(_ condition: Bool, _ label: String) { if !condition { fatalError(label) }; print("OK: " + label) }
        let book = try TabularReader.read(fixture.appendingPathComponent("lista.csv"))
        let sheet = book.sheets[0]
        let mapping = StudentImporter.guessMapping(sheet.rows[0])
        let rows = StudentImporter.preview(sheet, header: 0, mapping: mapping, existing: [])
        check(rows.count == 1 && rows[0].issue == nil, "CSV con BOM y punto y coma")
        let s = rows[0].student
        check(s.name == "Ana Pérez" && s.dni == "00123456Z" && s.nuss == "001234567890", "Apellidos y ceros iniciales")
        check(s.notes == "Dice \"sí\"; zona norte\nPreferencia de mañana", "Comillas escapadas, separador y salto de línea dentro del campo")
        check(s.email == "ana@example.test" && s.phone == "600123456" && s.group == "2A", "Contacto y grupo")
        check(s.companyID == nil && s.assignment == "Pendiente", "Importación no asigna empresas")
        let comma = try TabularReader.read(fixture.appendingPathComponent("comma.csv")).sheets[0]
        check(comma.rows[1][0].text == "María, López", "CSV separado por comas con coma dentro del nombre")
        let legacy = try TabularReader.read(fixture.appendingPathComponent("legacy.csv")).sheets[0]
        check(legacy.rows[1][0].text == "María" && legacy.rows[1][1].text == "Muñoz", "Codificación Windows-1252")
        let utf = try TabularReader.read(fixture.appendingPathComponent("utf16.csv")).sheets[0]
        check(utf.rows[1][1].text == "00000123X", "UTF-16 y tabulador")
        var caught = false
        do { _ = try TabularReader.csv("Nombre\n\"Sin cierre", separator: ",") } catch { caught = true }
        check(caught, "Comillas sin cerrar se rechazan")
        check(StudentImporter.preview(sheet, header: 0, mapping: mapping, existing: [s])[0].issue != nil, "Duplicado existente se omite")
        var doubled = sheet; doubled.rows.append(sheet.rows[1])
        let duplicates = StudentImporter.preview(doubled, header: 0, mapping: mapping, existing: [])
        check(duplicates[0].issue == nil && duplicates[1].issue != nil, "Duplicados dentro del archivo")
        let excluded = StudentImporter.preview(doubled, header: 0, mapping: mapping, existing: [], excluded: [1])
        check(excluded[0].excluded && excluded[1].issue == nil, "Excluir primera aparición permite seleccionar segunda")
        var named = s; named.dni = ""; named.nuss = ""; named.email = ""; named.name = "Pérez, Ana"
        check(!identityKeys(named).isDisjoint(with: identityKeys(s)), "Detectar mismo nombre en distinto orden")
        let x = try TabularReader.read(fixture.appendingPathComponent("lista.xlsx"))
        check(x.sheets.map(\.name) == ["Instrucciones", "Alumnas"], "Excel con varias hojas y referencias absolutas")
        let excel = x.sheets[1]
        check(excel.rows[1][0].text == "María Muñoz" && excel.rows[1][1].text == "001234567890", "Excel shared strings, texto enriquecido y formato con ceros")
        check(excel.rows[2].isEmpty && excel.rows[3][1].text.isEmpty && excel.rows[3][2].text == "elena@example.test", "Excel filas y celdas dispersas")
        let xp = StudentImporter.preview(excel, header: 0, mapping: StudentImporter.guessMapping(excel.rows[0]), existing: [])
        check(xp.count == 4 && xp.filter { $0.issue == nil }.count == 2, "Fórmulas y números de más de 15 cifras requieren revisión")
        for name in ["bad.xlsx", "broken.xlsx"] {
            var failed = false
            do { _ = try TabularReader.read(fixture.appendingPathComponent(name)) } catch { failed = true }
            check(failed, "Rechazar " + name)
        }
        let store = Store(folder: fixture.appendingPathComponent("store-" + UUID().uuidString))
        var original = Student(); original.name = "Alumna existente"
        store.db.students = [original]
        try store.importStudents([s])
        let reopened = Store(folder: store.folder)
        check(reopened.db.students.count == 2 && reopened.db.students[0] == original && reopened.db.students[1] == s, "Importación persiste y conserva datos previos")
        check(try FileManager.default.contentsOfDirectory(atPath: store.backups.path).count >= 1, "Copia antes de importar")
        let prior = store.db
        var refused = false
        do { try store.importStudents([s]) } catch { refused = true }
        check(refused && store.db == prior, "Confirmación vuelve a comprobar duplicados sin modificar datos")
        print("22 pruebas de importación superadas.")
    }
}
