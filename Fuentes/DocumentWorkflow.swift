// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Juan Luis (JLPalmes)
import Foundation

enum DocumentKind: String, Codable, CaseIterable, Identifiable {
    case annexI, annexII, agreement
    var id: String { rawValue }
    var title: String {
        switch self { case .annexI: return "Anexo I · asignación de tutor"; case .annexII: return "Anexo II · calificación final"; case .agreement: return "Concierto de colaboración" }
    }
    var stages: [(String, String)] {
        switch self {
        case .annexI: return [("generated", "Generado"), ("sentTutor", "Enviado al tutor"), ("receivedTutor", "Recibido del tutor"), ("sentStudent", "Enviado a la alumna"), ("receivedStudent", "Recibido de la alumna"), ("signedByMe", "Firmado por mí"), ("archived", "Archivado")]
        case .annexII: return [("generated", "Generado"), ("sentTutor", "Enviado al tutor"), ("receivedTutor", "Recibido del tutor"), ("signedByMe", "Firmado por mí"), ("archived", "Archivado")]
        case .agreement: return [("generated", "Generado"), ("sentDirector", "Enviado al director"), ("receivedDirector", "Recibido del director"), ("sentCompany", "Enviado a la empresa"), ("receivedCompany", "Recibido de la empresa"), ("sentCoordinator", "Enviado al coordinador"), ("uploaded", "Carga confirmada")]
        }
    }
    var receiptPairs: [(String, String)] {
        switch self {
        case .annexI: return [("sentTutor", "receivedTutor"), ("sentStudent", "receivedStudent")]
        case .annexII: return [("sentTutor", "receivedTutor")]
        case .agreement: return [("sentDirector", "receivedDirector"), ("sentCompany", "receivedCompany"), ("sentCoordinator", "uploaded")]
        }
    }
}
struct DocumentMilestone: Codable, Equatable, Identifiable {
    var id: String
    var completed = false
    var date: Date?
}
struct DocumentFlow: Codable, Equatable, Identifiable {
    var kind: DocumentKind
    var milestones: [DocumentMilestone]
    var id: DocumentKind { kind }
    init(_ kind: DocumentKind) { self.kind = kind; milestones = kind.stages.map { DocumentMilestone(id: $0.0) } }
    func done(_ id: String) -> Bool { milestones.first { $0.id == id }?.completed == true }
    var completedCount: Int { milestones.filter(\.completed).count }
    var nextTitle: String { kind.stages.first { !done($0.0) }?.1 ?? "Completado" }
    var valid: Bool { milestones.map(\.id) == kind.stages.map(\.0) }
    mutating func complete(_ id: String, _ value: Bool, on date: Date? = Date()) {
        guard let i = milestones.firstIndex(where: { $0.id == id }) else { return }
        milestones[i].completed = value
        milestones[i].date = value ? date : nil
        for (sent, received) in kind.receiptPairs {
            if id == received && value && !done(sent), let j = milestones.firstIndex(where: { $0.id == sent }) {
                // A returned signature establishes dispatch, but not its date.
                milestones[j].completed = true; milestones[j].date = nil
            }
            if id == sent && !value, let j = milestones.firstIndex(where: { $0.id == received }) {
                milestones[j].completed = false; milestones[j].date = nil
            }
        }
    }
    static func fromLegacy(_ kind: DocumentKind, _ legacy: [Step]) -> DocumentFlow {
        var flow = DocumentFlow(kind)
        let mappings: [(Int, String)]
        switch kind {
        case .annexI: mappings = [(1,"generated"),(2,"sentTutor"),(3,"receivedTutor"),(4,"receivedStudent"),(2,"signedByMe")]
        case .annexII: mappings = [(7,"generated"),(8,"sentTutor"),(9,"receivedTutor"),(8,"signedByMe")]
        case .agreement: mappings = [(0,"generated"),(1,"receivedDirector"),(2,"receivedCompany"),(3,"uploaded")]
        }
        for (index, key) in mappings where legacy.indices.contains(index) && legacy[index].done {
            flow.complete(key, true, on: legacy[index].date)
        }
        return flow
    }
    func applying(to legacy: [Step]) -> [Step] {
        var result = legacy
        let mappings: [(Int,String)]
        switch kind {
        case .annexI: mappings = [(1,"generated"),(2,"sentTutor"),(3,"receivedTutor"),(4,"receivedStudent")]
        case .annexII: mappings = [(7,"generated"),(8,"sentTutor"),(9,"receivedTutor")]
        case .agreement: mappings = [(0,"generated"),(1,"receivedDirector"),(2,"receivedCompany"),(3,"uploaded")]
        }
        for (index,key) in mappings where result.indices.contains(index) {
            result[index].done = done(key)
            if let date = milestones.first(where: { $0.id == key })?.date { result[index].date = date }
        }
        return result
    }
    var reportLines: [String] {
        kind.stages.map { key, title in
            let item = milestones.first { $0.id == key }!
            return "\(kind.title) · \(title): " + (item.completed ? "Hecho" : "Pendiente")
        }
    }
}
extension Student {
    func periodPaperwork(_ periodID: UUID?) -> [Step] {
        guard let periodID else { return paperwork }
        return shifts.first { $0.id == periodID }?.paperwork ?? steps(studentPaperworkTitles)
    }
    var latestPracticePaperwork: [Step] {
        guard let last = shifts.filter({ $0.companyID != nil }).sorted(by: { $0.from < $1.from }).last else { return paperwork }
        return last.paperwork ?? steps(studentPaperworkTitles)
    }
    func document(_ kind: DocumentKind, periodID: UUID? = nil) -> DocumentFlow {
        if let periodID, let period = shifts.first(where: { $0.id == periodID }) {
            return period.documents?.first { $0.kind == kind } ?? .fromLegacy(kind, period.paperwork ?? steps(studentPaperworkTitles))
        }
        return documents?.first { $0.kind == kind } ?? .fromLegacy(kind, paperwork)
    }
    mutating func setDocument(_ flow: DocumentFlow, periodID: UUID? = nil) {
        guard flow.kind != .agreement, flow.valid else { return }
        if let periodID {
            guard let i = shifts.firstIndex(where: { $0.id == periodID }) else { return }
            var values = shifts[i].documents ?? []
            values.removeAll { $0.kind == flow.kind }; values.append(flow)
            shifts[i].documents = values
            shifts[i].paperwork = flow.applying(to: shifts[i].paperwork ?? steps(studentPaperworkTitles))
        } else {
            var values = documents ?? []; values.removeAll { $0.kind == flow.kind }; values.append(flow)
            documents = values; paperwork = flow.applying(to: paperwork)
        }
    }
}
extension Company {
    var document: DocumentFlow { documents?.first { $0.kind == .agreement } ?? .fromLegacy(.agreement, paperwork) }
    mutating func setDocument(_ flow: DocumentFlow) {
        guard flow.kind == .agreement, flow.valid else { return }
        documents = [flow]; paperwork = flow.applying(to: paperwork)
    }
}
struct PracticePeriod: Identifiable {
    var id: UUID
    var companyID: UUID?
    var tutorID: UUID?
    var from: Date?
    var end: Date?
    var hours: Double?
    var shiftID: UUID?
    var changes: [Shift]
}
extension Database {
    func practicePeriods(for s: Student) -> [PracticePeriod] {
        let calculation = calculate(s, self)
        let end = calculation.end.map { s.manualEnd ? s.end : $0 }
        let practices = s.shifts.filter { $0.companyID != nil }.sorted { $0.from < $1.from }
        var result: [PracticePeriod] = []
        for index in 0...practices.count {
            let shift = index == 0 ? nil : practices[index - 1]
            let start = shift?.from ?? s.start
            let next = index < practices.count ? practices[index].from : nil
            let periodEnd = next.map { cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: $0))! }
            let finalEnd = periodEnd.map { boundary in end.map { min($0, boundary) } ?? boundary } ?? end
            let changes = s.shifts.filter { $0.companyID == nil && $0.from >= start && (next == nil || $0.from < next!) }.sorted { $0.from < $1.from }
            result.append(PracticePeriod(id: shift?.id ?? s.id, companyID: shift?.companyID ?? s.companyID, tutorID: shift?.tutorID ?? (shift == nil ? s.tutorID : nil), from: s.hasStart ? start : nil, end: finalEnd, hours: shift == nil ? s.hours : shift?.hours, shiftID: shift?.id, changes: changes))
        }
        return result
    }
    func document(for student: Student, at companyID: UUID, kind: DocumentKind) -> DocumentFlow {
        if student.companyID == companyID { return student.document(kind) }
        return student.document(kind, periodID: student.shifts.last(where: { $0.companyID == companyID })?.id)
    }
}

enum StudentWorkFilter: String, CaseIterable, Identifiable {
    case all = "Todas", noTutor = "Sin tutor", annexI = "Anexo I pendiente", finishMonth = "Finalizan este mes", overdue = "Contacto vencido"
    var id: String { rawValue }
}
extension Database {
    func matches(_ student: Student, workFilter: StudentWorkFilter, today: Date = Date()) -> Bool {
        let periods = practicePeriods(for: student)
        switch workFilter {
        case .all: return true
        case .noTutor: return periods.contains { $0.companyID != nil && $0.tutorID == nil }
        case .annexI: return periods.contains { $0.companyID != nil && !student.document(.annexI, periodID: $0.shiftID).done("archived") }
        case .finishMonth:
            guard student.hasStart, let end = calculate(student, self).end else { return false }
            return cal.isDate(student.manualEnd ? student.end : end, equalTo: today, toGranularity: .month)
        case .overdue:
            return companyIDs(for: student).contains { id in monthlySchedule(for: id).contains { !$0.historical && $0.saved?.completed != true && cal.startOfDay(for: $0.due) < cal.startOfDay(for: today) } }
        }
    }
}
