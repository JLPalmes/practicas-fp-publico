// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Juan Luis (JLPalmes)
import SwiftUI
import AppKit

struct OptionalDateEditor: View {
    var title: String
    @Binding var date: Date?
    var body: some View {
        if let value = date {
            HStack {
                DatePicker(title, selection: Binding(get: { date ?? value }, set: { date = $0 }), displayedComponents: .date)
                Button("Quitar fecha") { date = nil }.buttonStyle(.borderless)
            }
        } else {
            HStack { Text(title + " · Sin registrar").foregroundStyle(.secondary); Spacer(); Button("Registrar fecha…") { date = Date() } }
        }
    }
}
struct DocumentTimeline: View {
    @Binding var flow: DocumentFlow
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(flow.kind.title).font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), alignment: .topLeading)], alignment: .leading, spacing: 8) {
                ForEach(flow.kind.stages, id: \.0) { stage in
                    Toggle(isOn: Binding(get: { flow.done(stage.0) }, set: { value in
                        var updated = flow
                        let date = flow.milestones.first { $0.id == stage.0 }?.date
                        updated.complete(stage.0, value, on: date)
                        flow = updated
                    })) {
                        Text(stage.1).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }.padding(10).background(accent.opacity(0.035)).clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
struct StudentDocuments: View {
    @EnvironmentObject var store: Store
    var studentID: UUID
    var periodID: UUID?
    var body: some View {
        if let student = store.db.students.first(where: { $0.id == studentID }) {
            ForEach([DocumentKind.annexI, .annexII]) { kind in
                DocumentTimeline(flow: Binding(get: { store.db.students.first(where: { $0.id == studentID })?.document(kind, periodID: periodID) ?? DocumentFlow(kind) }, set: { store.setDocument($0, studentID: studentID, periodID: periodID) }))
            }
            if student.documents == nil && periodID == nil {
                Text("Se conservan los estados del registro anterior. Envíos a la alumna, archivo y otros hitos nuevos deben revisarse; no se dan por realizados automáticamente.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
struct PracticePeriodsEditor: View {
    @EnvironmentObject var store: Store
    @Binding var s: Student
    var openCompany: (UUID) -> Void
    var openTutor: (UUID) -> Void
    var displayedPeriodID: UUID
    var body: some View {
        let periods = store.db.practicePeriods(for: s)
        ForEach(Array(periods.enumerated()).filter { $0.element.id == displayedPeriodID }, id: \.element.id) { offset, period in
            VStack(alignment: .leading, spacing: 12) {
                Text("Práctica \(offset + 1) · " + (store.db.companies.first { $0.id == period.companyID }?.name ?? "Sin empresa")).font(.headline)
                Text("\(period.from.map(dateText) ?? "Inicio sin establecer") → \(period.end.map(dateText) ?? "Fin sin calcular")").font(.callout).foregroundStyle(.secondary)
                if let shiftID = period.shiftID, let i = s.shifts.firstIndex(where: { $0.id == shiftID }) {
                    DatePicker("Inicio del periodo", selection: $s.shifts[i].from, displayedComponents: .date)
                    TextField("Horas diarias iniciales del periodo", value: $s.shifts[i].hours, format: .number)
                    Picker("Empresa", selection: Binding(get: { s.shifts.first { $0.id == shiftID }?.companyID }, set: { store.assignPeriod(s.id, periodID: shiftID, to: $0) })) {
                        ForEach(store.db.companies) { company in Text(company.name).tag(Optional(company.id)).disabled(!store.db.canAssignPeriod(s.id, periodID: shiftID, to: company.id)) }
                    }
                    Picker("Tutor", selection: $s.shifts[i].tutorID) {
                        Text("Sin asignar").tag(nil as UUID?)
                        ForEach(store.db.tutors.filter { $0.companyID == period.companyID }) { Text($0.name).tag(Optional($0.id)) }
                    }
                    Checklist(items: Binding(get: { s.shifts.first { $0.id == shiftID }?.paperwork ?? steps(studentPaperworkTitles) }, set: { value in if let i = s.shifts.firstIndex(where: { $0.id == shiftID }) { s.shifts[i].paperwork = value } }), only: [5,6])
                    DeleteButton(title: "Eliminar este periodo") { s.shifts.removeAll { $0.id == shiftID } }
                } else {
                    Picker("Empresa", selection: Binding(get: { s.companyID }, set: { store.assign(s.id, to: $0) })) {
                        Text("Sin asignar").tag(nil as UUID?)
                        ForEach(store.db.companies) { company in Text(company.name).tag(Optional(company.id)).disabled(!store.db.canAssign(s.id, to: company.id)) }
                    }
                    Picker("Tutor", selection: $s.tutorID) {
                        Text("Sin asignar").tag(nil as UUID?)
                        ForEach(store.db.tutors.filter { s.companyID != nil && $0.companyID == s.companyID }) { Text($0.name).tag(Optional($0.id)) }
                    }
                    Checklist(items: $s.paperwork, only: [0,5,6])
                }
                assignmentControl(for: period)
                if let id = period.companyID { Button("Abrir ficha de empresa") { openCompany(id) } }
                if let id = period.tutorID { Button("Abrir ficha del tutor") { openTutor(id) } }
                ForEach(period.changes) { change in
                    if let i = s.shifts.firstIndex(where: { $0.id == change.id }) {
                        VStack(alignment: .leading) {
                            Text("Cambio de jornada · misma empresa").font(.subheadline)
                            DatePicker("Desde", selection: $s.shifts[i].from, displayedComponents: .date)
                            TextField("Horas/día", value: $s.shifts[i].hours, format: .number)
                            DeleteButton(title: "Eliminar cambio de jornada") { s.shifts.removeAll { $0.id == change.id } }
                        }.padding(8).background(.background).clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                StudentDocuments(studentID: s.id, periodID: period.shiftID)
            }.padding(8).background(accent.opacity(0.04)).clipShape(RoundedRectangle(cornerRadius: 12))
        }
        if periods.last?.id == displayedPeriodID {
            Button("Añadir cambio de jornada") { appendShift(companyID: nil) }
            Menu("Añadir periodo · nueva práctica") {
                ForEach(store.db.companies) { company in
                    Button(company.name.nonEmpty ?? "Empresa sin nombre") { appendShift(companyID: company.id) }
                }
            }.disabled(store.db.companies.isEmpty)
        }
    }
    @ViewBuilder private func assignmentControl(for period: PracticePeriod) -> some View {
        if s.isPreviousPeriod(period.shiftID) || s.requiresDefinitiveAssignment(period.shiftID) {
            LabeledContent("Estado de asignación", value: s.periodAssignment(period.shiftID))
        } else {
            Picker("Estado de asignación", selection: Binding(
                get: { s.periodAssignment(period.shiftID) },
                set: { value in
                    guard !s.isPreviousPeriod(period.shiftID), !s.requiresDefinitiveAssignment(period.shiftID) else { return }
                    if let shiftID = period.shiftID {
                        if let index = s.shifts.firstIndex(where: { $0.id == shiftID }) {
                            s.shifts[index].assignment = value
                        }
                    } else {
                        s.assignment = value
                    }
                }
            )) {
                Text("Pendiente").tag("Pendiente")
                if period.companyID != nil {
                    Text("Provisional").tag("Provisional")
                    Text("Definitiva").tag("Definitiva")
                }
            }
        }
    }

    private func appendShift(companyID: UUID?) {
        guard store.db.practicePeriods(for: s).last?.id == displayedPeriodID else { return }
        let latest = ([s.start] + s.shifts.map(\.from)).max() ?? s.start
        let nextDay = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: latest))!
        let date = max(cal.startOfDay(for: Date()), nextDay)
        let period = Shift(from: date)
        var updated = store.db
        guard let i = updated.students.firstIndex(where: { $0.id == s.id }) else { return }
        updated.students[i].shifts.append(period)
        if companyID != nil && !updated.assignPeriod(s.id, periodID: period.id, to: companyID) { store.error = "Para asignar esta empresa, debe figurar como admitida y tener plazas libres. Revisa su ficha en Empresas."; return }
        updated.students[i].confirmStartedAndPreviousPeriods()
        store.db = updated
    }
}

struct BackupCandidate: Identifiable {
    var url: URL
    var database: Database?
    var date: Date?
    var problem: String?
    var id: URL { url }
    @MainActor static func read(_ url: URL) -> BackupCandidate {
        let date = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        do { return BackupCandidate(url: url, database: try Store.decode(Data(contentsOf: url)), date: date) }
        catch { return BackupCandidate(url: url, date: date, problem: error.localizedDescription) }
    }
}
struct BackupRestoreView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @LocalState private var candidates: [BackupCandidate] = []
    @LocalState private var selected: URL?
    @LocalState private var confirm = false
    var candidate: BackupCandidate? { candidates.first { $0.url == selected } }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Restaurar una copia · vista previa").font(.title2.bold())
            HStack {
                Button("Elegir otra copia…") {
                    let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]
                    guard panel.runModal() == .OK, let url = panel.url else { return }
                    if !candidates.contains(where: { $0.url == url }) { candidates.append(BackupCandidate.read(url)) }
                    selected = url
                }
                Spacer(); Button("Cancelar") { dismiss() }
            }
            HSplitView {
                List(selection: $selected) {
                    ForEach(candidates) { item in
                        VStack(alignment: .leading) {
                            Text(item.database?.course ?? "Copia no válida").font(.headline)
                            Text(item.url.lastPathComponent).font(.caption)
                            if let db = item.database { Text("\(db.students.count) alumnas · \(db.companies.count) empresas").font(.caption).foregroundStyle(.secondary) }
                        }.tag(item.url)
                    }
                }.frame(minWidth: 260)
                VStack(alignment: .leading, spacing: 12) {
                    if let item = candidate, let db = item.database {
                        Text("Curso: " + db.course).font(.headline)
                        Text(db.institute)
                        Text("Fecha del archivo: " + (item.date.map(dateText) ?? "Sin registrar"))
                        Text("\(db.students.count) alumnas · \(db.companies.count) empresas · \(db.tutors.count) tutores")
                        Text("\((db.archivedCourses ?? []).count) cursos archivados")
                        Text("Actualmente: \(store.db.course), \(store.db.students.count) alumnas y \(store.db.companies.count) empresas.").foregroundStyle(.secondary)
                        Text("La restauración sustituye los datos actuales. Antes se guardará una copia de seguridad.")
                        Button("Restaurar esta copia…") { confirm = true }.buttonStyle(.borderedProminent)
                    } else if let problem = candidate?.problem {
                        Text("No se puede restaurar este archivo.").foregroundStyle(.red)
                        Text(problem).font(.caption)
                    } else { Text("Selecciona una copia para ver su contenido antes de restaurarla.").foregroundStyle(.secondary) }
                    Spacer()
                }.padding().frame(minWidth: 340)
            }
        }.padding(20).frame(width: 780, height: 480)
        .onAppear {
            let files = (try? FileManager.default.contentsOfDirectory(at: store.backups, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
            candidates = files.filter { $0.pathExtension == "json" }.map(BackupCandidate.read).sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        }
        .confirmationDialog("¿Sustituir los datos actuales por esta copia?", isPresented: $confirm) {
            Button("Restaurar copia") {
                guard let url = selected else { return }
                do { try store.restore(from: url); dismiss() }
                catch { store.error = "No se ha restaurado la copia. " + error.localizedDescription }
            }
            Button("Cancelar", role: .cancel) {}
        }
    }
}

struct Format5ReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @LocalState private var copy: Format5Preview?
    @LocalState private var selected: UUID?
    @LocalState private var error: String?
    @LocalState private var dirty = false
    @LocalState private var discard = false
    @LocalState private var editing: Format5Period?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Consultar copia de la serie 2").font(.title2.bold())
            Text("Edita el horario y guarda los cambios en un archivo nuevo.")
                .foregroundStyle(.secondary)
            HStack {
                Button("Elegir copia JSON…", action: chooseCopy).disabled(dirty)
                Button("Guardar copia nueva…", action: saveCopy).disabled(!dirty)
                Spacer()
                Button("Cerrar") { if dirty { discard = true } else { dismiss() } }
            }
            if let error {
                Text(error).foregroundStyle(.red)
            }
            if let copy {
                Text(copy.calendar.course + " · " + copy.calendar.institute).font(.headline)
                if copy.students.isEmpty {
                    ContentUnavailableView("La copia no contiene alumnas", systemImage: "person.2")
                } else {
                    HSplitView {
                        List(selection: $selected) {
                            ForEach(copy.calendar.students) { student in
                                Text(student.name.nonEmpty ?? "Alumna sin nombre").tag(student.id)
                            }
                        }.frame(minWidth: 220)
                        if let student = copy.students.first(where: { $0.id == selected }) {
                            detail(student, in: copy.calendar).frame(minWidth: 360)
                        }
                    }
                }
            } else {
                ContentUnavailableView("Elige una copia de Windows de la serie 2", systemImage: "doc")
            }
            Spacer(minLength: 0)
        }.padding(20).frame(width: 780, height: 540)
        .interactiveDismissDisabled(dirty)
        .confirmationDialog("¿Descartar los cambios de la copia?", isPresented: $discard) {
            Button("Descartar cambios", role: .destructive) { dismiss() }
            Button("Cancelar", role: .cancel) {}
        }
        .sheet(item: $editing) { period in
            if let id = selected {
                Format5ScheduleEditor(period: period) { edit in
                    guard let copy else { throw CocoaError(.fileReadUnknown) }
                    self.copy = try copy.editingSchedule(studentID: id, periodID: period.id, edit: edit)
                    dirty = true
                    error = nil
                }
            }
        }
    }

    private func chooseCopy() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let loaded = try Format5Preview(data: Data(contentsOf: url))
            copy = loaded
            selected = loaded.students.first?.id
            error = nil
            dirty = false
        } catch {
            copy = nil
            selected = nil
            self.error = "No se ha podido leer la copia. Elige un archivo JSON válido en formato 5."
        }
    }

    private func saveCopy() {
        guard let copy else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "PracticasFP-serie-2.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try copy.original.write(to: url, options: .withoutOverwriting)
            dirty = false
            error = nil
        } catch {
            self.error = "No se ha guardado la copia. Comprueba que el nombre sea nuevo y que la carpeta permita escribir."
        }
    }

    private func detail(_ student: Format5Student, in db: Database) -> some View {
        Form {
            if let periods = student.practicePeriods {
                let forecasts = student.forecasts(in: db, today: Date())
                let elapsed = forecasts.reduce(0) { $0 + $1.elapsed }
                Section("Horas del curso") {
                    hours("Objetivo general", student.targetHours ?? 500)
                    hours("Curso anterior", student.previousCourseHours ?? 0)
                    hours("Previstas hasta ayer", elapsed)
                    hours("Restantes del objetivo", student.remainingHours(elapsed: elapsed))
                    hours("Anotadas para el siguiente curso", student.nextCourseHours ?? 0)
                }
                ForEach(Array(periods.enumerated()), id: \.element.id) { index, period in
                    Section(index == 0 ? "Primer periodo" : "Segundo periodo") {
                        if period.active {
                            let result = forecasts[index]
                            LabeledContent("Empresa", value: db.companies.first { $0.id == period.companyID }?.name ?? "Sin empresa")
                            LabeledContent("Tutor", value: db.tutors.first { $0.id == period.tutorID }?.name ?? "Sin tutor")
                            LabeledContent("Inicio", value: period.hasStart ? dateText(period.start) : "Sin registrar")
                            LabeledContent("Fin", value: result.end.map(dateText) ?? "Sin calcular")
                            hours("Objetivo del periodo", period.targetHours)
                            hours("Jornada inicial", period.hours)
                            hours("Previstas hasta ayer", result.elapsed)
                            if let problem = result.error { Text(problem).foregroundStyle(.orange) }
                            Button("Editar horario y fechas…") { editing = period }
                        } else {
                            Text("Periodo inactivo").foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                Text("Esta ficha conserva la estructura anterior. Aún no se ha convertido a dos periodos.")
                    .foregroundStyle(.secondary)
            }
        }.formStyle(.grouped)
    }

    private func hours(_ label: String, _ value: Double) -> some View {
        LabeledContent(label, value: value.formatted(.number.precision(.fractionLength(0...2))) + " h")
    }
}

private struct Format5ScheduleEditor: View {
    @Environment(\.dismiss) private var dismiss
    @LocalState private var edit: Format5ScheduleEdit
    @LocalState private var invalid = false
    let apply: (Format5ScheduleEdit) throws -> Void

    init(period: Format5Period, apply: @escaping (Format5ScheduleEdit) throws -> Void) {
        _edit = State(initialValue: Format5ScheduleEdit(period))
        self.apply = apply
    }

    var body: some View {
        Form {
            Section("Horario y fechas del periodo") {
                Toggle("Inicio establecido", isOn: $edit.hasStart)
                if edit.hasStart {
                    DatePicker("Inicio", selection: $edit.start, displayedComponents: .date)
                }
                Toggle("Ajustar fin manualmente", isOn: $edit.manualEnd)
                if edit.manualEnd {
                    DatePicker("Fin", selection: $edit.end, displayedComponents: .date)
                }
                TextField("Horas diarias iniciales", value: $edit.hours, format: .number)
                TextField("Horas objetivo", value: $edit.targetHours, format: .number)
                if invalid {
                    Text("Revisa las fechas y las horas. La jornada debe ser mayor que cero y como máximo de 24 h. El objetivo debe estar entre 0 y 10.000 h y solo puede ser cero con un fin manual.")
                        .foregroundStyle(.red)
                }
            }
            HStack {
                Button("Cancelar") { dismiss() }
                Spacer()
                Button("Aplicar") {
                    do {
                        try apply(edit)
                        dismiss()
                    } catch {
                        invalid = true
                    }
                }.buttonStyle(.borderedProminent)
            }
        }.formStyle(.grouped).toggleStyle(.checkbox).frame(width: 480, height: 360)
    }
}
