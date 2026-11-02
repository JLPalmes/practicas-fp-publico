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
    @LocalState private var selected: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Text(flow.kind.title).font(.headline); Spacer(); Text("\(flow.completedCount)/\(flow.milestones.count)").foregroundStyle(.secondary) }
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(flow.kind.stages.enumerated()), id: \.element.0) { index, stage in
                        milestoneButton(stage.0, title: stage.1)
                        if index < flow.kind.stages.count - 1 { Rectangle().fill(accent.opacity(0.3)).frame(width: 24, height: 2).padding(.top, 18) }
                    }
                }.padding(.horizontal, 4)
            }
            Text("Siguiente hito pendiente: " + flow.nextTitle).font(.caption).foregroundStyle(.secondary)
        }.padding(10).background(accent.opacity(0.035)).clipShape(RoundedRectangle(cornerRadius: 10))
    }
    private func milestonePresentation(_ id: String) -> Binding<Bool> {
        Binding<Bool>(get: { selected == id }, set: { isPresented in
            if !isPresented { selected = nil }
        })
    }
    private func milestoneButton(_ id: String, title: String) -> some View {
        let item = flow.milestones.first { $0.id == id }!
        return Button { selected = id } label: {
            VStack(spacing: 6) {
                Image(systemName: item.completed ? "checkmark.circle.fill" : "circle").font(.title2).foregroundStyle(item.completed ? accent : Color.secondary)
                Text(title).font(.caption).multilineTextAlignment(.center).frame(width: 108).frame(minHeight: 30)
                Text(item.completed ? item.date.map(dateText) ?? "Fecha sin registrar" : "Pendiente").font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(width: 108)
            }.padding(.vertical, 6)
        }.buttonStyle(.plain).accessibilityLabel(flow.kind.title + " · " + title)
            .accessibilityValue(item.completed ? "Hecho" : "Pendiente")
            .popover(isPresented: milestonePresentation(id)) {
                milestoneEditor(id, title: title)
            }
    }
    private func milestoneEditor(_ id: String, title: String) -> some View {
        let done = flow.done(id)
        return VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            Toggle("Hito realizado", isOn: Binding(get: { flow.done(id) }, set: { value in
                var updated = flow; updated.complete(id, value); flow = updated
            }))
            if done {
                OptionalDateEditor(title: "Fecha", date: Binding(get: { flow.milestones.first { $0.id == id }?.date }, set: { date in
                    var updated = flow
                    if let i = updated.milestones.firstIndex(where: { $0.id == id }) { updated.milestones[i].date = date }
                    flow = updated
                }))
            }
            Text("Marca cada envío y cada recepción por separado. Los hitos sin fecha no se interpretan como realizados hoy.").font(.caption).foregroundStyle(.secondary)
        }.padding().frame(width: 360)
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
    var body: some View {
        let periods = store.db.practicePeriods(for: s)
        ForEach(Array(periods.enumerated()), id: \.element.id) { offset, period in
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
                    Picker("Estado de asignación", selection: $s.assignment) {
                        Text("Pendiente").tag("Pendiente")
                        if s.companyID != nil { Text("Provisional").tag("Provisional"); Text("Definitiva").tag("Definitiva") }
                    }
                    Picker("Tutor", selection: $s.tutorID) {
                        Text("Sin asignar").tag(nil as UUID?)
                        ForEach(store.db.tutors.filter { s.companyID != nil && $0.companyID == s.companyID }) { Text($0.name).tag(Optional($0.id)) }
                    }
                    TextField("Horas diarias iniciales", value: $s.hours, format: .number)
                    Checklist(items: $s.paperwork, only: [0,5,6])
                }
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
            }.padding(12).background(accent.opacity(0.04)).clipShape(RoundedRectangle(cornerRadius: 12))
        }
        Menu("Añadir periodo o cambio de jornada") {
            Button("Cambio de jornada en la misma empresa") { appendShift(companyID: nil) }
            ForEach(store.db.companies) { company in
                Button("Nueva práctica en " + company.name) { appendShift(companyID: company.id) }
                    .disabled(!store.db.companyIDs(for: s).contains(company.id) && !store.db.canAssign(s.id, to: company.id))
            }
        }
    }
    private func appendShift(companyID: UUID?) {
        var date = max(cal.startOfDay(for: Date()), cal.startOfDay(for: s.start))
        while s.shifts.contains(where: { cal.isDate($0.from, inSameDayAs: date) }) { date = cal.date(byAdding: .day, value: 1, to: date)! }
        let period = Shift(from: date)
        var updated = store.db
        guard let i = updated.students.firstIndex(where: { $0.id == s.id }) else { return }
        updated.students[i].shifts.append(period)
        if companyID != nil && !updated.assignPeriod(s.id, periodID: period.id, to: companyID) { store.error = "No hay plazas disponibles para este periodo."; return }
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
