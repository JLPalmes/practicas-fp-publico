// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Juan Luis (JLPalmes)
import SwiftUI

struct CompanyResponseEditor: View {
    @EnvironmentObject var store: Store
    var companyID: UUID
    var showState = true
    var body: some View {
        if let index = store.db.companies.firstIndex(where: { $0.id == companyID }) {
            if showState {
            Picker("Estado", selection: Binding(
                get: { store.db.companies[index].response ?? .uncontacted },
                set: { store.setResponse($0, for: companyID) })) {
                    ForEach(CompanyResponse.allCases) { Text($0.title).tag($0) }
                }
            }
            OptionalDateEditor(title: "Fecha del contacto", date: Binding(get: { store.db.companies[index].contactedOn }, set: { store.db.companies[index].contactedOn = $0 }))
            if [.accepted, .rejected].contains(store.db.companies[index].response) {
                OptionalDateEditor(title: "Fecha de respuesta", date: Binding(get: { store.db.companies[index].respondedOn }, set: { store.db.companies[index].respondedOn = $0 }))
            }
        }
    }
}

struct CompanyFollowUps: View {
    @EnvironmentObject var store: Store
    var companyID: UUID
    var body: some View {
        let contacts = store.db.monthlySchedule(for: companyID)
        VStack(alignment: .leading, spacing: 12) {
            Text("Un contacto por empresa y mes. Los vencimientos parten del inicio de cada alumna; si coinciden en un mes, se usa la primera fecha.").font(.caption).foregroundStyle(.secondary)
            if store.db.definitiveStudents(companyID).contains(where: { !$0.hasStart }) {
                Text("Hay alumnas sin fecha de inicio; sus seguimientos se calcularán al indicarla.").font(.caption).foregroundStyle(.orange)
            }
            if store.db.definitiveStudents(companyID).contains(where: { $0.hasStart && calculate($0, store.db).error != nil }) {
                Text("Revisa las jornadas o el calendario: no se puede calcular el seguimiento de alguna alumna.").foregroundStyle(.orange)
            }
            if contacts.isEmpty {
                Text("Sin contactos mensuales previstos. Se generan para asignaciones definitivas con inicio y fin calculables.").foregroundStyle(.secondary)
            }
            ForEach(contacts) { item in
                FollowUpRow(companyID: companyID, item: item)
            }
        }
    }
}

struct FollowUpRow: View {
    @EnvironmentObject var store: Store
    var companyID: UUID
    var item: ScheduledContact
    var record: MonthlyContact? { store.db.companies.first(where: { $0.id == companyID })?.monthlyContacts?.first(where: { $0.id == item.id }) }
    var done: Bool { record?.completed ?? false }
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top) {
                CompletionButton(title: item.monthTitle + " · contacto realizado", done: done) {
                    store.updateContact(companyID: companyID, item: item) { $0.setCompleted(!done) }
                }
                if done {
                    DatePicker("Realizado el", selection: Binding(
                        get: { record?.completedOn ?? Date() },
                        set: { date in store.updateContact(companyID: companyID, item: item) { $0.completedOn = date } }
                    ), displayedComponents: .date).frame(width: 230)
                }
            }
            HStack {
                Text("Previsto: " + dateText(item.due))
                if item.historical { Text("· Conservado del historial").foregroundStyle(.secondary) }
                else if !done && cal.startOfDay(for: item.due) < cal.startOfDay(for: Date()) {
                    Text("· Pendiente vencido").foregroundStyle(.orange)
                } else if !done { Text("· Pendiente").foregroundStyle(.secondary) }
            }.font(.caption)
            Text("Alumnas: " + item.studentNames.joined(separator: ", ")).font(.caption).foregroundStyle(.secondary)
            TextField("Observaciones del contacto", text: Binding(
                get: { record?.notes ?? "" },
                set: { text in store.updateContact(companyID: companyID, item: item) { $0.notes = text } }
            ), axis: .vertical).lineLimit(2...6).textFieldStyle(.roundedBorder)
        }.padding(12).background(accent.opacity(done ? 0.08 : 0.025)).clipShape(RoundedRectangle(cornerRadius: 9))
    }
}

enum CompanyPanelFilter: String, CaseIterable, Identifiable {
    case all = "Todas"
    case waiting = "Esperando respuesta"
    case accepted = "Admiten"
    case rejected = "Rechazan"
    case assigned = "Asignación definitiva"
    case uncontacted = "Sin registrar"
    var id: String { rawValue }
}
struct CompaniesDashboard: View {
    @EnvironmentObject var store: Store
    var openCompany: (UUID) -> Void
    var openStudent: (UUID) -> Void
    var selectedCompany: UUID?
    @Binding var search: String
    @Binding var filter: CompanyPanelFilter
    @ObservedObject var navigation: WorkspaceNavigation
    func matches(_ c: Company) -> Bool {
        guard search.isEmpty || c.name.localizedCaseInsensitiveContains(search) else { return false }
        switch filter {
        case .all: return true
        case .waiting: return c.response == .waiting
        case .accepted: return c.response == .accepted
        case .rejected: return c.response == .rejected
        case .assigned: return !store.db.definitiveStudents(c.id).isEmpty
        case .uncontacted: return c.response == nil || c.response == .uncontacted
        }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130))], alignment: .leading, spacing: 10) {
                    stat("Esperando respuesta", count: store.db.companies.filter { $0.response == .waiting }.count)
                    stat("Admiten", count: store.db.companies.filter { $0.response == .accepted }.count)
                    stat("Rechazan", count: store.db.companies.filter { $0.response == .rejected }.count)
                    stat("Con definitivas", count: store.db.companies.filter { !store.db.definitiveStudents($0.id).isEmpty }.count)
                }
                VStack(alignment: .leading) {
                    TextField("Buscar empresa", text: $search).textFieldStyle(.roundedBorder)
                    Picker("Mostrar", selection: $filter) { ForEach(CompanyPanelFilter.allCases) { Text($0.rawValue).tag($0) } }.frame(width: 300)
                }
                if store.db.companies.isEmpty {
                    ContentUnavailableView("Añade tus empresas", systemImage: "building.2", description: Text("Pulsa Añadir. Aquí podrás consultar sus respuestas, plazas y contactos y editar su ficha."))
                } else if !store.db.companies.contains(where: matches) {
                    Text("No hay empresas que coincidan con el filtro.").foregroundStyle(.secondary)
                }
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(store.db.companies.filter(matches)) { company in
                        CompanyPanelCard(companyID: company.id, openCompany: openCompany, openStudent: openStudent)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(selectedCompany == company.id ? accent : .clear, lineWidth: 2))
                            .id(company.id)
                    }
                }.scrollTargetLayout()
            }.padding(14).background(ScrollMemory(read: { navigation.scrollOffsets["Empresas"] ?? 0 }, write: { navigation.scrollOffsets["Empresas"] = $0 }))
        }
    }
    func stat(_ title: String, count: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) { Text(title).font(.caption).foregroundStyle(.secondary); Text("\(count)").font(.title.bold()) }
            .frame(maxWidth: .infinity, alignment: .leading).padding(14).background(.background).clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct CompanyPanelCard: View {
    @LocalState private var showDates = false
    @EnvironmentObject var store: Store
    var companyID: UUID
    var openCompany: (UUID) -> Void
    var openStudent: (UUID) -> Void
    var body: some View {
        if let i = store.db.companies.firstIndex(where: { $0.id == companyID }) {
            let company = store.db.companies[i]
            let students = store.db.definitiveStudents(companyID)
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 5) {
                        Button { openCompany(companyID) } label: {
                            HStack {
                                Text(company.name.isEmpty ? "Empresa sin nombre" : company.name).font(.headline)
                                Spacer(minLength: 0)
                            }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                            .accessibilityLabel("Abrir ficha de " + (company.name.isEmpty ? "empresa sin nombre" : company.name))
                        HStack(spacing: 8) {
                            Picker("Estado de contacto", selection: Binding(
                                get: { store.db.companies[i].response ?? .uncontacted },
                                set: { store.setResponse($0, for: companyID) })) {
                                ForEach(CompanyResponse.allCases) { Text($0.title).tag($0) }
                            }.labelsHidden().frame(width: 220)
                            Button { showDates.toggle() } label: { Image(systemName: "calendar") }
                                .buttonStyle(.borderless).help("Consultar o editar fechas de contacto y respuesta")
                                .accessibilityLabel("Fechas de contacto y respuesta")
                                .popover(isPresented: $showDates) {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Fechas de contacto y respuesta").font(.headline)
                                        CompanyResponseEditor(companyID: companyID, showState: false)
                                        if company.contactedOn == nil && company.respondedOn == nil && ![CompanyResponse.accepted, .rejected].contains(company.response) {
                                            Text("Se registran al indicar el contacto o la respuesta.").font(.caption)
                                        }
                                    }.padding().frame(width: 340)
                                }
                        }
                    }
                }
                if company.response == .accepted || !students.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Button { openCompany(companyID) } label: {
                                Text("Plazas concedidas: \(company.capacity.map(String.init) ?? "sin indicar")").bold()
                            }.buttonStyle(.plain)
                            Button {
                                store.setCapacity((company.capacity ?? store.db.occupiedPlaces(companyID)) - 1, for: companyID)
                            } label: { Image(systemName: "minus") }
                            .disabled((company.capacity ?? store.db.occupiedPlaces(companyID)) <= store.db.occupiedPlaces(companyID))
                            .accessibilityLabel("Restar plaza")
                            .help("Restar una plaza. Las alumnas provisionales también reservan plaza.")
                            Button {
                                store.setCapacity((company.capacity ?? store.db.occupiedPlaces(companyID)) + 1, for: companyID)
                            } label: { Image(systemName: "plus") }
                            .disabled(company.capacity == Int.max)
                            .accessibilityLabel("Añadir plaza")
                            .help("Añadir una plaza")
                        }.controlSize(.small)
                        Button { openCompany(companyID) } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Definitivas: \(students.count)")
                                Text("Provisionales / otras: \(store.db.occupiedPlaces(companyID) - students.count)")
                                Text("Restantes: \(company.capacity.map { String(max(0, $0 - store.db.occupiedPlaces(companyID))) } ?? "—")").bold().foregroundStyle(accent)
                            }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }.font(.callout)

                }
                if !students.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(students) { student in
                            VStack(alignment: .leading, spacing: 5) {
                                Button(student.name) { openStudent(student.id) }.buttonStyle(.plain).fontWeight(.semibold)
                                Text(store.db.tutors.first { $0.id == store.db.tutorID(for: student, at: companyID) }?.name ?? "Tutor pendiente").foregroundStyle(.secondary)
                                Spacer()
                                Text("I: " + store.db.document(for: student, at: companyID, kind: .annexI).nextTitle).foregroundStyle(.secondary)
                                Text("II: " + store.db.document(for: student, at: companyID, kind: .annexII).nextTitle).foregroundStyle(.secondary)
                            }.font(.callout)
                        }
                    }
                    DisclosureGroup("Trámites · concierto \(company.document.completedCount)/\(company.document.milestones.count) · tutores y anexos") {
                    Text("Concierto de colaboración · \(company.document.completedCount)/\(company.document.milestones.count)").font(.headline)
                    DocumentTimeline(flow: Binding(get: { store.db.companies[i].document }, set: { store.setCompanyDocument($0, companyID: companyID) }))
                    Divider()
                    Text("Alumnas con asignación definitiva").font(.headline)
                    ForEach(students) { student in
                        DefinitiveStudentRow(studentID: student.id, companyID: companyID, openStudent: openStudent)
                    }
                    Divider()
                    }
                    let contacts = store.db.monthlySchedule(for: companyID)
                    let pending = contacts.filter { $0.saved?.completed != true && !$0.historical }
                    DisclosureGroup("Seguimiento · \(contacts.filter { $0.saved?.completed == true }.count) realizados · \(pending.count) pendientes" + (pending.first.map { " · próximo: " + dateText($0.due) } ?? "")) {
                        CompanyFollowUps(companyID: companyID)
                    }
                } else if !(company.monthlyContacts ?? []).isEmpty {
                    DisclosureGroup("Historial de contactos") { CompanyFollowUps(companyID: companyID) }
                }
                if !company.notes.isEmpty { Text(company.notes).font(.callout).foregroundStyle(.secondary) }
            }.padding(12).background(.background).clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}
struct DefinitiveStudentRow: View {
    @EnvironmentObject var store: Store
    var studentID: UUID
    var companyID: UUID
    var openStudent: (UUID) -> Void
    var body: some View {
        if let i = store.db.students.firstIndex(where: { $0.id == studentID }) {
            let student = store.db.students[i]
            VStack(alignment: .leading, spacing: 6) {
                HStack { Text(student.name).font(.headline); Spacer(); Button("Ficha de alumna") { openStudent(studentID) } }
                Picker("Tutor de empresa", selection: Binding(
                    get: { store.db.tutorID(for: student, at: companyID) },
                    set: { store.setTutor($0, for: studentID, at: companyID) })) {
                    Text("Pendiente de asignar").tag(nil as UUID?)
                    ForEach(store.db.tutors.filter { $0.companyID == companyID }) { Text($0.name).tag(Optional($0.id)) }
                }
                if let tutorID = store.db.tutorID(for: student, at: companyID),
                   let tutor = store.db.tutors.first(where: { $0.id == tutorID }) {
                    Text("\(tutor.phone) · \(tutor.email)").font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                }
                ForEach([DocumentKind.annexI,.annexII]) { kind in
                    DocumentTimeline(flow: Binding(get: { store.db.document(for: student, at: companyID, kind: kind) }, set: { flow in
                        let periodID = student.companyID == companyID ? nil : student.shifts.last(where: { $0.companyID == companyID })?.id
                        store.setDocument(flow, studentID: studentID, periodID: periodID)
                    }))
                }
            }.padding(8).background(accent.opacity(0.045)).clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}
