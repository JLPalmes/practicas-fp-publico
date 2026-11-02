// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Juan Luis (JLPalmes)
import SwiftUI
import AppKit
import UniformTypeIdentifiers

extension String { var nonEmpty: String? { isEmpty ? nil : self } }

@MainActor final class WorkspaceNavigation: ObservableObject {
    @Published var page = "Alumnas"
    @Published private var selections: [String: UUID] = [:]
    @Published private var searches: [String: String] = [:]
    var scrollOffsets: [String: CGFloat] = [:]
    var selected: UUID? {
        get { selections[page] }
        set { selections[page] = newValue }
    }
    var search: String {
        get { searches[page] ?? "" }
        set { searches[page] = newValue }
    }
    func switchSection(_ section: String) { page = section }
    func open(_ section: String, id: UUID) {
        page = section; selected = id
    }
    func searchBinding(for section: String) -> Binding<String> {
        Binding(get: { self.searches[section] ?? "" }, set: { self.searches[section] = $0 })
    }
}

struct PendingTask: Identifiable {
    var id: String
    var title: String
    var detail: String
    var studentID: UUID?
    var companyID: UUID?
    var forClosing = false
}
extension Database {
    func pendingTasks(today: Date = Date()) -> [PendingTask] {
        var tasks: [PendingTask] = []
        for student in students {
            let name = student.name.isEmpty ? "Alumna sin nombre" : student.name
            func add(_ key: String, _ detail: String) {
                tasks.append(PendingTask(id: "\(student.id)-\(key)", title: name, detail: detail, studentID: student.id))
            }
            if student.assignment != "Definitiva" { add("assignment", "Asignación pendiente de confirmar") }
            if student.companyID != nil && student.tutorID == nil { add("tutor", "Tutor del periodo inicial pendiente") }
            for (key, paperwork) in [("initial", student.paperwork)] + student.shifts.filter({ $0.companyID != nil }).map({ ($0.id.uuidString, $0.paperwork ?? steps(studentPaperworkTitles)) }) {
                let periodID = key == "initial" ? nil : UUID(uuidString: key)
                let annexI = student.document(.annexI, periodID: periodID)
                let annexII = student.document(.annexII, periodID: periodID)
                if !annexI.done("archived") && (key != "initial" || student.companyID != nil) {
                    let detail = annexI.done("sentTutor") && !annexI.done("receivedTutor") ? "Anexo I remitido y pendiente de devolución" : "Anexo I · " + annexI.nextTitle
                    add("\(key)-2", detail + " · " + (key == "initial" ? "periodo inicial" : "periodo posterior"))
                }
                let periodCompany: UUID? = key == "initial" ? student.companyID : student.shifts.first(where: { $0.id.uuidString == key })?.companyID
                let calculation = calculate(student, self, today: today)
                let practiceEnd = calculation.end.map { student.manualEnd ? student.end : $0 }
                let start = key == "initial" ? student.start : student.shifts.first(where: { $0.id.uuidString == key })?.from ?? student.start
                let nextStart = student.shifts.filter { $0.companyID != nil && (key == "initial" ? $0.from >= start : $0.from > start) }.map(\.from).min()
                let intervalEnd = practiceEnd.map { end in nextStart.map { min(end, cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: $0))!) } ?? end }
                let finished = paperwork[6].done || (student.hasStart && intervalEnd.map { cal.startOfDay(for: $0) < cal.startOfDay(for: today) } == true)
                if periodCompany != nil && !annexII.done("archived") {
                    tasks.append(PendingTask(id: "\(student.id)-\(key)-8", title: name,
                        detail: "Anexo II · " + annexII.nextTitle + " · " + (key == "initial" ? "periodo inicial" : "periodo posterior"),
                        studentID: student.id, forClosing: !finished && !annexII.done("sentTutor")))
                }
            }
            for period in student.shifts where period.companyID != nil && period.tutorID == nil {
                add("tutor-\(period.id)", "Tutor pendiente · periodo desde \(dateText(period.from))")
            }
        }
        for company in companies {
            if !company.document.done("uploaded") && (company.response == .accepted || occupiedPlaces(company.id) > 0) {
                tasks.append(PendingTask(id: "\(company.id)-agreement", title: company.name, detail: "Concierto · " + company.document.nextTitle, companyID: company.id))
            }
            for contact in monthlySchedule(for: company.id) where contact.saved?.completed != true && !contact.historical && cal.startOfDay(for: contact.due) < cal.startOfDay(for: today) {
                tasks.append(PendingTask(id: "\(company.id)-\(contact.id)", title: company.name, detail: "Contacto mensual vencido · \(dateText(contact.due))", companyID: company.id))
            }
        }
        return tasks
    }
    func validationMessages(for student: Student) -> [String] {
        var messages: [String] = []
        if student.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { messages.append("Completa el nombre de la alumna.") }
        let duplicates = students.filter { $0.id != student.id && !identityKeys($0).isDisjoint(with: identityKeys(student)) }
        if !duplicates.isEmpty { messages.append("Posible duplicado: " + duplicates.map { $0.name.isEmpty ? "Ficha sin nombre" : $0.name }.joined(separator: ", ") + ". Revisa los datos antes de continuar.") }
        if !student.email.isEmpty && (!student.email.contains("@") || student.email.contains(where: { $0.isWhitespace }) || student.email.hasSuffix("@")) { messages.append("Revisa el formato del correo electrónico.") }
        if !student.nuss.isEmpty && (student.nuss.filter(\.isNumber).count != 12 || student.nuss.contains(where: { !$0.isNumber && !$0.isWhitespace && $0 != "-" })) { messages.append("Revisa el NUSS: se esperan 12 cifras.") }
        let dni = student.dni.uppercased().filter { !$0.isWhitespace && $0 != "-" }
        if !dni.isEmpty && (dni.count != 9 || dni.last?.isLetter != true) { messages.append("Revisa el formato del DNI / NIE.") }
        return messages
    }
    func report(studentID: UUID? = nil, companyID: UUID? = nil, today: Date = Date()) -> String {
        var lines = ["PRÁCTICAS FP · \(course)", institute, "Informe generado: \(dateText(today))", "Horas previstas según horario y calendario; no es un registro de asistencia.", ""]
        let selectedStudents = students.filter { (studentID == nil || $0.id == studentID) && (companyID == nil || self.companyIDs(for: $0).contains(companyID!)) }
        for student in selectedStudents {
            let result = calculate(student, self, today: today)
            lines += ["ALUMNA: \(student.name)", "Grupo: \(student.group) · Asignación: \(student.assignment)", "Objetivo: \(student.requiredHours) h · Previstas hasta ayer: \(result.elapsed) h", "Inicio: \(student.hasStart ? dateText(student.start) : "Sin establecer")", "Fin: \(result.end.map { dateText(student.manualEnd ? student.end : $0) } ?? "Sin calcular")"]
            lines.append("Jornada inicial: \(student.hours) h/día")
            lines += student.shifts.sorted { $0.from < $1.from }.map { "Cambio desde \(dateText($0.from)): \($0.hours.map { String($0) } ?? "Sin jornada") h/día" }
            if let end = result.end, student.start < calendarFrom || end > calendarTo { lines.append("Previsión fuera del periodo de calendario revisado.") }
            if let error = result.error { lines.append("Revisar cálculo: \(error)") }
            for period in practicePeriods(for: student) {
                let name = companies.first { $0.id == period.companyID }?.name ?? "Sin empresa"
                let tutor = tutors.first { $0.id == period.tutorID }?.name ?? "Sin tutor"
                lines += ["Empresa: \(name) · Tutor: \(tutor)", "Periodo: \(period.from.map(dateText) ?? "Sin inicio") – \(period.end.map(dateText) ?? "Sin calcular")"]
                let paperwork = student.periodPaperwork(period.shiftID)
                for i in (period.shiftID == nil ? [0,5,6] : [5,6]) {
                    lines.append(paperwork[i].title + ": " + (paperwork[i].done ? "Hecho · " + dateText(paperwork[i].date) : "Pendiente"))
                }
                for kind in [DocumentKind.annexI,.annexII] { lines += student.document(kind, periodID: period.shiftID).reportLines }
            }
            lines.append("")
        }
        for company in companies where companyID == nil ? studentID == nil : company.id == companyID {
            lines += ["EMPRESA: \(company.name)", placesLabel(company), "Respuesta: \((company.response ?? .uncontacted).title)"]
            lines += company.document.reportLines
            lines += monthlySchedule(for: company.id).map { "Contacto \($0.monthTitle): \($0.saved?.completed == true ? "Realizado" : "Pendiente") · \(dateText($0.due))" }
            lines.append("")
        }
        if !instituteDaysConfirmed { lines.append("Previsión provisional: faltan los días de libre disposición del instituto.") }
        return lines.joined(separator: "\n")
    }
}

@MainActor func exportReport(_ text: String, name: String = "Informe-PracticasFP") {
    let panel = NSSavePanel(); panel.allowedContentTypes = [.plainText]
    panel.nameFieldStringValue = name + ".txt"; panel.title = "Guardar informe"
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
        try text.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    } catch {
        let alert = NSAlert(); alert.messageText = "No se ha guardado el informe"; alert.informativeText = error.localizedDescription; alert.runModal()
    }
}

struct PendingTasksView: View {
    @EnvironmentObject var store: Store
    var openStudent: (UUID) -> Void
    var openCompany: (UUID) -> Void
    var body: some View {
        let tasks = store.db.pendingTasks()
        List {
            Section("Requiere actuación ahora") {
                if !tasks.contains(where: { !$0.forClosing }) { Text("No hay tareas que requieran actuación ahora.").foregroundStyle(.secondary) }
                ForEach(tasks.filter { !$0.forClosing }) { task in taskButton(task) }
            }
            Section("Documentación de cierre · para más adelante") {
                Text("El Anexo II corresponde al cierre de cada práctica. Pasa al grupo anterior cuando lo remites, termina su periodo o marcas la práctica como terminada.").font(.caption).foregroundStyle(.secondary)
                ForEach(tasks.filter(\.forClosing)) { task in taskButton(task) }
            }
        }
    }
    private func taskButton(_ task: PendingTask) -> some View {
        Button {
            if let id = task.studentID { openStudent(id) }
            else if let id = task.companyID { openCompany(id) }
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                Text(task.title).font(.headline)
                Text(task.detail).foregroundStyle(.secondary)
            }.padding(.vertical, 5)
        }.buttonStyle(.plain)
    }
}

struct CourseHistoryView: View {
    @EnvironmentObject var store: Store
    @LocalState private var nextCourse = ""
    @LocalState private var confirm = false
    @LocalState private var selected: UUID?
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField("Nombre del nuevo curso", text: $nextCourse).textFieldStyle(.roundedBorder)
                Button("Archivar curso actual…") { confirm = true }.disabled(nextCourse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Text("Se conserva una copia completa del curso para consulta. El nuevo curso empieza sin alumnas, contactos ni cupos. Se mantienen las empresas, sus conciertos y tutores. Deberás revisar el calendario.").font(.callout).foregroundStyle(.secondary)
            HSplitView {
                List(selection: $selected) {
                    ForEach(store.db.archivedCourses ?? []) { course in
                        VStack(alignment: .leading) { Text(course.title); Text(dateText(course.archivedOn)).font(.caption).foregroundStyle(.secondary) }.tag(course.id)
                    }
                }.frame(minWidth: 180, idealWidth: 230)
                if let archive = store.db.archivedCourses?.first(where: { $0.id == selected }), let snapshot = try? Store.decode(archive.snapshot) {
                    VStack(alignment: .leading) {
                        Button("Exportar informe del curso") { exportReport(snapshot.report()) }
                        ScrollView { Text(snapshot.report()).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding() }
                    }.frame(minWidth: 400)
                } else { ContentUnavailableView("Historial de cursos", systemImage: "archivebox", description: Text("Selecciona un curso archivado para consultar su resumen.")) }
            }
        }.padding()
        .confirmationDialog("¿Archivar \(store.db.course) e iniciar \(nextCourse)?", isPresented: $confirm) {
            Button("Archivar e iniciar curso") {
                do { try store.archiveCourse(named: nextCourse); nextCourse = "" }
                catch { store.error = error.localizedDescription }
            }
            Button("Cancelar", role: .cancel) {}
        } message: { Text("Se crea una copia de seguridad antes del cambio. Puedes deshacer esta operación durante la sesión.") }
    }
}
