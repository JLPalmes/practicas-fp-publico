// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Juan Luis (JLPalmes)
import Foundation
import PDFKit

@main struct FeatureTests {
    @MainActor static func main() throws {
        func check(_ value: Bool, _ label: String) { precondition(value, label); print("OK: " + label) }
        var db = Database(); db.exclusions = []
        var s = Student(); s.name = "Alumna de prueba"; s.hasStart = true; s.start = day("2027-01-04"); s.hours = 8
        check(s.requiredHours == 500, "Objetivo anterior sigue siendo 500 horas")
        s.targetHours = 12
        let result = calculate(s, db, today: day("2027-01-08"))
        check(result.end == day("2027-01-05") && result.lastHours == 4 && result.elapsed == 12, "Objetivo configurable respeta última jornada y límite de progreso")
        s.targetHours = 0
        check(calculate(s, db).error != nil, "Objetivo cero se rechaza")
        s.targetHours = 10001
        check(calculate(s, db).error != nil, "Objetivo excesivo se rechaza")
        s.targetHours = 500
        var c = Company(); c.name = "Empresa de prueba"; c.capacity = 2; c.response = .accepted
        s.companyID = c.id; s.assignment = "Definitiva"; s.paperwork[2].done = true
        db.companies = [c]; db.students = [s]
        let tasks = db.pendingTasks(today: day("2027-02-10"))
        check(tasks.contains { $0.studentID == s.id && $0.detail.hasPrefix("Anexo I remitido") }, "Anexo remitido genera tarea con acceso a alumna")
        check(tasks.contains { $0.studentID == s.id && $0.detail.contains("Tutor") }, "Tutor pendiente genera aviso")
        check(tasks.contains { $0.companyID == c.id && $0.detail.contains("vencido") }, "Contacto vencido genera tarea con acceso a empresa")
        db.students[0].paperwork[3].done = true
        check(!db.pendingTasks().contains { $0.detail.hasPrefix("Anexo I remitido") }, "Devolución elimina la tarea")
        var duplicate = s; duplicate.id = UUID(); db.students.append(duplicate)
        check(db.validationMessages(for: s).contains { $0.contains("duplicado") }, "Edición manual detecta duplicados")
        db.students.removeLast()
        check(!db.validationMessages(for: s).contains { $0.contains("duplicado") }, "La ficha no se duplica consigo misma")
        let report = db.report(studentID: s.id, today: day("2027-02-10"))
        check(report.contains(s.name) && report.contains(c.name) && report.contains("500.0") && report.contains("Periodo:"), "Informe incluye alumna, empresa, objetivo y periodos")
        check(db.report(companyID: UUID()).contains(s.name) == false, "Informe de empresa respeta el filtro")
        let folder = URL(fileURLWithPath: CommandLine.arguments[1])
        let store = Store(folder: folder); store.db = db
        store.db.students[0].shifts.append(Shift(from: day("2027-02-01"), hours: 4))
        let withPeriod = store.db
        store.db.students[0].shifts.removeAll()
        store.undo()
        check(store.db == withPeriod && store.canRedo, "Deshacer recupera periodo eliminado")
        store.redo()
        check(store.db.students[0].shifts.isEmpty, "Rehacer vuelve a eliminar el periodo")
        store.undo(); store.db.students[0].notes = "Cambio nuevo"
        check(!store.canRedo, "Nuevo cambio invalida rehacer")
        let previous = store.db
        try store.archiveCourse(named: "2027–2028")
        check(store.db.students.isEmpty && store.db.course == "2027–2028" && store.db.occupiedPlaces(c.id) == 0, "Curso nuevo libera plazas y separa alumnas")
        check(store.db.companies[0].capacity == nil && store.db.companies[0].response == nil && !store.db.instituteDaysConfirmed && store.db.exclusions.isEmpty, "Nuevo curso obliga a revisar cupos y calendario")
        let archived = try Store.decode(store.db.archivedCourses![0].snapshot)
        check(archived == previous && archived.archivedCourses == nil, "Archivo conserva curso completo sin duplicar archivos anteriores")
        check(try Store.decode(Data(contentsOf: store.file)) == store.db, "Archivo persiste en disco")
        store.undo()
        check(store.db == previous, "Deshacer archivo restaura el curso activo")
        var legacy = try JSONSerialization.jsonObject(with: JSONEncoder().encode(db)) as! [String: Any]
        var students = legacy["students"] as! [[String: Any]]; students[0].removeValue(forKey: "targetHours"); legacy["students"] = students
        let migrated = try Store.decode(JSONSerialization.data(withJSONObject: legacy))
        check(migrated.students[0].requiredHours == 500 && migrated.archivedCourses == nil, "Copias antiguas abren sin nuevos campos")
        let nav = WorkspaceNavigation()
        nav.selected = s.id; nav.search = "prueba"; nav.scrollOffsets["Alumnas"] = 250
        nav.open("Empresas", id: c.id); nav.search = "empresa"
        nav.open("Tutores", id: UUID())
        nav.switchSection("Empresas")
        check(nav.page == "Empresas" && nav.selected == c.id && nav.search == "empresa", "Abrir otra sección conserva empresa y búsqueda")
        nav.switchSection("Alumnas")
        check(nav.page == "Alumnas" && nav.selected == s.id && nav.search == "prueba" && nav.scrollOffsets["Alumnas"] == 250, "Cambiar sección conserva selección, filtro y posición de alumnas")
        nav.switchSection("Empresas")
        check(nav.selected == c.id && nav.search == "empresa", "Cambiar sección conserva su selección y búsqueda")
        let automatic = WorkspaceNavigation()
        let nextID = UUID()
        automatic.ensureSelection(in: [s.id, nextID])
        check(automatic.selected == s.id, "El espacio de trabajo selecciona la primera ficha al entrar")
        automatic.selected = nextID
        automatic.ensureSelection(in: [s.id, nextID])
        check(automatic.selected == nextID, "La selección automática conserva una ficha válida")
        automatic.switchSection("Empresas")
        automatic.ensureSelection(in: [c.id])
        automatic.switchSection("Alumnas")
        automatic.ensureSelection(in: [s.id, nextID])
        check(automatic.selected == nextID, "Volver a la sección recupera su última ficha")
        automatic.ensureSelection(in: [s.id])
        check(automatic.selected == s.id, "Eliminar la ficha seleccionada abre otra disponible")
        automatic.ensureSelection(in: [])
        check(automatic.selected == nil, "Un listado vacío elimina la selección obsoleta")
        automatic.ensureSelection(in: [nextID])
        check(automatic.selected == nextID, "Añadir o restaurar datos vuelve a abrir una ficha")
        var tutorData = Database()
        let tutorID = UUID()
        var initialStudent = Student(); initialStudent.tutorID = tutorID
        var laterStudent = Student(); laterStudent.shifts = [Shift(tutorID: tutorID), Shift(tutorID: tutorID)]
        tutorData.students = [initialStudent, laterStudent, Student()]
        check(tutorData.students(tutoredBy: tutorID).map(\.id) == [initialStudent.id, laterStudent.id], "Tutores incluyen asignaciones iniciales y posteriores sin duplicar alumnas")
        check(tutorData.students(tutoredBy: UUID()).isEmpty, "Un tutor sin asignaciones no muestra alumnas de otros tutores")
        automatic.switchSection("Tutores")
        automatic.ensureSelection(in: [tutorID])
        check(automatic.selected == tutorID, "Tutores abre automáticamente su primera ficha")
        automatic.switchSection("Alumnas")
        automatic.ensureSelection(in: [nextID])
        automatic.switchSection("Tutores")
        check(automatic.selected == tutorID, "Tutores conserva su ficha al volver de otra sección")
        let grouped = Store(folder: folder.appendingPathComponent("grouped"))
        grouped.db = db; grouped.endEditingGroup()
        let originalName = grouped.db.students[0].name
        grouped.db.students[0].name = "A"; grouped.db.students[0].name = "Ana"
        grouped.undo()
        check(grouped.db.students[0].name == originalName, "Deshacer agrupa escritura consecutiva en un campo")
        grouped.redo()
        check(grouped.db.students[0].name == "Ana", "Rehacer recupera la edición completa")
        grouped.endEditingGroup(); grouped.db.students[0].name = "Ana María"
        grouped.undo()
        check(grouped.db.students[0].name == "Ana", "Finalizar edición separa dos acciones en el mismo campo")
        grouped.db.students[0].notes = "nota"; grouped.db.students[0].name = "Otro nombre"
        grouped.undo()
        check(grouped.db.students[0].notes == "nota" && grouped.db.students[0].name == "Ana", "Deshacer no mezcla campos distintos")
        var closing = db
        closing.students[0].paperwork[8].done = false
        let beforeEnd = closing.pendingTasks(today: day("2027-01-05"))
        check(beforeEnd.contains { $0.forClosing && $0.detail.contains("Anexo II") }, "Anexo II sin remitir queda para el cierre")
        closing.students[0].paperwork[8].done = true
        check(closing.pendingTasks(today: day("2027-01-05")).contains { !$0.forClosing && $0.detail.contains("Anexo II") }, "Anexo II remitido requiere seguimiento actual")
        closing.students[0].paperwork[8].done = false
        closing.students[0].paperwork[6].done = true
        check(closing.pendingTasks(today: day("2027-01-05")).contains { !$0.forClosing && $0.detail.contains("Anexo II") }, "Práctica terminada activa documentación de cierre")
        closing.students[0].paperwork[6].done = false
        check(closing.pendingTasks(today: day("2028-01-05")).contains { !$0.forClosing && $0.detail.contains("Anexo II") }, "Fin previsto pasado activa documentación de cierre")
        var nextCompany = Company(); nextCompany.name = "Empresa posterior"; nextCompany.capacity = 1
        closing.companies.append(nextCompany)
        closing.students[0].paperwork[6].done = true
        let later = Shift(from: day("2027-02-01"), hours: 8, companyID: nextCompany.id)
        closing.students[0].shifts = [later]
        check(closing.pendingTasks(today: day("2027-01-05")).contains { $0.id.contains(later.id.uuidString) && $0.forClosing }, "Terminar el periodo inicial no adelanta el cierre del posterior")
        var flow = DocumentFlow(.annexI)
        flow.complete("receivedTutor", true, on: day("2027-01-08"))
        check(flow.done("sentTutor") && flow.milestones.first { $0.id == "sentTutor" }?.date == nil, "Recepción confirma envío sin inventar su fecha")
        check(flow.milestones.first { $0.id == "receivedTutor" }?.date == day("2027-01-08"), "Recepción conserva su fecha propia")
        flow.complete("sentTutor", false)
        check(!flow.done("receivedTutor"), "Retirar envío retira su recepción asociada")
        check(!DocumentKind.annexII.stages.contains { $0.0.contains("Student") }, "Anexo II no pide firma de la alumna")
        let legacyFlow = DocumentFlow.fromLegacy(.annexI, s.paperwork)
        check(legacyFlow.done("signedByMe") && !legacyFlow.done("archived"), "Migración conserva firma propia anterior sin inventar archivo")
        var signedAgreement = c.paperwork
        for i in signedAgreement.indices { signedAgreement[i].done = true }
        let agreement = DocumentFlow.fromLegacy(.agreement, signedAgreement)
        check(agreement.completedCount == agreement.milestones.count && agreement.milestones.first { $0.id == "sentDirector" }?.date == nil, "Concierto migrado conserva firmas y carga sin inventar fechas de envío")
        var documentStudent = s
        let period = Shift(from: day("2027-02-01"), hours: 6, companyID: nextCompany.id)
        documentStudent.shifts = [period]
        var nextDocument = DocumentFlow(.annexI); nextDocument.complete("generated", true, on: day("2027-01-20"))
        documentStudent.setDocument(nextDocument, periodID: period.id)
        check(documentStudent.document(.annexI, periodID: period.id).done("generated") && documentStudent.documents == nil, "Documentos del periodo posterior son independientes")
        var periodDB = db; periodDB.companies.append(nextCompany); periodDB.students = [documentStudent]
        documentStudent.shifts.insert(Shift(from: day("2027-01-11"), hours: 4), at: 0)
        periodDB.students = [documentStudent]
        let blocks = periodDB.practicePeriods(for: documentStudent)
        check(blocks.count == 2 && blocks[0].changes.count == 1 && blocks[0].end == day("2027-01-31"), "Prácticas agrupan cambios de jornada y delimitan fechas")
        check(periodDB.matches(documentStudent, workFilter: .noTutor) && periodDB.matches(documentStudent, workFilter: .annexI), "Filtros detectan tutor y documentación pendiente")
        var completedInitial = periodDB
        completedInitial.students[0].paperwork[6].done = true
        completedInitial.students[0].paperwork[6].date = day("2027-01-25")
        check(!completedInitial.monthlySchedule(for: nextCompany.id).isEmpty, "Cerrar la primera práctica no corta los contactos de la posterior")
        check(!completedInitial.students[0].latestPracticePaperwork[6].done, "Estado global refleja la última práctica, no la anterior cerrada")
        if let index = completedInitial.students[0].shifts.firstIndex(where: { $0.id == period.id }) {
            completedInitial.students[0].shifts[index].paperwork = nil
        }
        check(!completedInitial.monthlySchedule(for: nextCompany.id).isEmpty, "Periodo sin trámites previos no hereda el cierre del inicial")
        let documentStore = Store(folder: folder.appendingPathComponent("documents")); documentStore.db = periodDB
        documentStore.setDocument(nextDocument, studentID: documentStudent.id, periodID: period.id)
        check(try Store.decode(Data(contentsOf: documentStore.file)) == documentStore.db, "Hitos y sus fechas persisten al reabrir")
        var invalidDocuments = documentStore.db
        invalidDocuments.students[0].documents = [DocumentFlow(.agreement)]
        var badDocumentRejected = false
        do { _ = try Store.decode(JSONEncoder().encode(invalidDocuments)) } catch { badDocumentRejected = true }
        check(badDocumentRejected, "Restauración rechaza hitos de tipo incorrecto")
        let backupURL = folder.appendingPathComponent("restore-preview.json")
        try documentStore.exportBackup(to: backupURL)
        let savedCourse = documentStore.db.course
        documentStore.db.course = "Curso cambiado"
        try documentStore.restore(from: backupURL)
        check(documentStore.db.course == savedCourse && documentStore.canUndo, "Restaurar copia conserva datos y permite deshacer")
        let corruptURL = folder.appendingPathComponent("corrupt.json"); try Data("incorrecto".utf8).write(to: corruptURL)
        let beforeCorrupt = documentStore.db
        do { try documentStore.restore(from: corruptURL) } catch {}
        check(documentStore.db == beforeCorrupt, "Copia inválida no sustituye los datos activos")
        let pdfText = periodDB.report() + String(repeating: "\nObservación de prueba: seguimiento, firmas y recepción de documentos.", count: 130) + "\nFIN DEL INFORME"
        let pdfData = try ReportPDF.data(for: pdfText)
        let pdf = PDFDocument(data: pdfData)
        check((pdf?.pageCount ?? 0) > 1 && pdf?.string?.contains("FIN DEL INFORME") == true, "Informe PDF pagina y conserva el texto hasta el final")
        if CommandLine.arguments.count > 2 {
            let qa = URL(fileURLWithPath: CommandLine.arguments[2]); try FileManager.default.createDirectory(at: qa, withIntermediateDirectories: true)
            try pdfData.write(to: qa.appendingPathComponent("informe-prueba.pdf"))
            try JSONEncoder().encode(periodDB).write(to: qa.appendingPathComponent("datos.json"))
        }
        print("Pruebas de mejoras superadas")
    }
}
