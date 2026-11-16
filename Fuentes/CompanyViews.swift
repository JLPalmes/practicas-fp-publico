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
                get: { store.db.companies.first(where: { $0.id == companyID })?.response ?? .uncontacted },
                set: { store.setResponse($0, for: companyID) })) {
                    ForEach(CompanyResponse.allCases) { Text($0.title).tag($0) }
                }
            }
            OptionalDateEditor(title: "Fecha del contacto", date: Binding(get: { store.db.companies.first(where: { $0.id == companyID })?.contactedOn }, set: { value in if let i = store.db.companies.firstIndex(where: { $0.id == companyID }) { store.db.companies[i].contactedOn = value } }))
            if [.accepted, .rejected].contains(store.db.companies[index].response) {
                OptionalDateEditor(title: "Fecha de respuesta", date: Binding(get: { store.db.companies.first(where: { $0.id == companyID })?.respondedOn }, set: { value in if let i = store.db.companies.firstIndex(where: { $0.id == companyID }) { store.db.companies[i].respondedOn = value } }))
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

struct CompaniesDashboard: View {
    @EnvironmentObject var store: Store
    var openCompany: (UUID) -> Void
    var selectedCompany: UUID?
    @Binding var search: String
    @ObservedObject var navigation: WorkspaceNavigation

    func matches(_ company: Company) -> Bool {
        search.isEmpty || company.name.localizedCaseInsensitiveContains(search)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading) {
                    TextField("Buscar empresa", text: $search).textFieldStyle(.roundedBorder)
                }
                if store.db.companies.isEmpty {
                    Text("Todavía no hay empresas. Añade la primera desde la columna de ficha.").foregroundStyle(.secondary)
                } else if !store.db.companies.contains(where: matches) {
                    Text("No hay empresas que coincidan con la búsqueda.").foregroundStyle(.secondary)
                }
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(store.db.companies.filter(matches)) { company in
                        Button { openCompany(company.id) } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(company.name.nonEmpty ?? "Empresa sin nombre").font(.headline)
                                ForEach(store.db.students.filter { store.db.companyIDs(for: $0).contains(company.id) }) { student in
                                    Text(student.name.nonEmpty ?? "Alumna sin nombre")
                                        .font(.callout).foregroundStyle(.secondary)
                                }
                            }.frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10).background(.background, in: RoundedRectangle(cornerRadius: 12))
                                .contentShape(Rectangle())
                        }.buttonStyle(.plain)
                            .accessibilityAddTraits(selectedCompany == company.id ? .isSelected : [])
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(selectedCompany == company.id ? accent : .clear, lineWidth: 2))
                            .id(company.id)
                    }
                }.scrollTargetLayout()
            }.padding(10).background(ScrollMemory(read: { navigation.scrollOffsets["Empresas"] ?? 0 }, write: { navigation.scrollOffsets["Empresas"] = $0 }))
        }
    }
}
