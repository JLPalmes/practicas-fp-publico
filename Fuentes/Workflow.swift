// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Juan Luis (JLPalmes)
import Foundation

enum CompanyResponse: String, Codable, CaseIterable, Identifiable {
    case uncontacted, waiting, accepted, rejected
    var id: String { rawValue }
    var title: String {
        switch self {
        case .uncontacted: return "Contacto sin registrar"
        case .waiting: return "Contactada · esperando respuesta"
        case .accepted: return "Admite alumnas"
        case .rejected: return "Rechaza alumnas"
        }
    }
}
struct MonthlyContact: Codable, Identifiable, Equatable {
    var id: String // year-month, unique within this company
    var plannedDate: Date
    var studentNames: [String]
    var completed = false
    var completedOn = Date()
    var notes = ""
    mutating func setCompleted(_ value: Bool, on date: Date = Date()) {
        if value && !completed { completedOn = date }
        completed = value
    }
}
struct ScheduledContact: Identifiable {
    var id: String
    var due: Date
    var studentNames: [String]
    var saved: MonthlyContact?
    var historical = false
    var monthTitle: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "es_ES"); f.timeZone = cal.timeZone
        f.dateFormat = "MMMM yyyy"; return f.string(from: due).capitalized
    }
}
func monthKey(_ date: Date) -> String {
    let c = cal.dateComponents([.year, .month], from: date)
    return String(format: "%04d-%02d", c.year!, c.month!)
}
extension Database {
    mutating func migrateWorkflow() {
        guard version == 1 else { return }
        for i in students.indices {
            let titles = Student().paperwork.map { $0.title }
            for j in students[i].paperwork.indices {
                // A recorded signature does not establish that the document was sent.
                if j == 2 || j == 8 { students[i].paperwork[j].done = false }
                students[i].paperwork[j].title = titles[j]
            }
        }
        let companyTitles = Company().paperwork.map { $0.title }
        for i in companies.indices {
            for j in companies[i].paperwork.indices { companies[i].paperwork[j].title = companyTitles[j] }
            if companies[i].response == nil && (occupiedPlaces(companies[i].id) > 0 || (companies[i].capacity ?? 0) > 0) {
                companies[i].response = .accepted
            }
        }
        version = 2
    }
    func definitiveStudents(_ companyID: UUID) -> [Student] {
        students.filter { companyIDs(for: $0).contains(companyID) && $0.assignment == "Definitiva" }
    }
    func intervals(for student: Student, at companyID: UUID, until end: Date) -> [(start: Date, end: Date)] {
        guard student.hasStart else { return [] }
        return practicePeriods(for: student).compactMap { period in
            guard period.companyID == companyID, let start = period.from else { return nil }
            var final = min(end, period.end ?? end)
            let paperwork = student.periodPaperwork(period.shiftID)
            if paperwork[6].done { final = min(final, cal.startOfDay(for: paperwork[6].date)) }
            return start <= final ? (start, final) : nil
        }
    }

    func monthlySchedule(for companyID: UUID) -> [ScheduledContact] {
        guard let company = companies.first(where: { $0.id == companyID }) else { return [] }
        var result: [String: ScheduledContact] = [:]
        for student in definitiveStudents(companyID) where student.hasStart {
            let calc = calculate(student, self)
            guard calc.error == nil, let calculatedEnd = calc.end else { continue }
            let end = cal.startOfDay(for: student.manualEnd ? student.end : calculatedEnd)
            for interval in intervals(for: student, at: companyID, until: end) {
                for n in 1...120 {
                    guard let due = cal.date(byAdding: .month, value: n, to: interval.start), due <= interval.end else { break }
                    let key = monthKey(due)
                    if var existing = result[key] {
                        existing.due = min(existing.due, due)
                        if !existing.studentNames.contains(student.name) { existing.studentNames.append(student.name) }
                        result[key] = existing
                    } else { result[key] = ScheduledContact(id: key, due: due, studentNames: [student.name]) }
                }
            }
        }
        for saved in company.monthlyContacts ?? [] {
            if var item = result[saved.id] {
                item.saved = saved
                if saved.completed { item.due = saved.plannedDate; item.studentNames = saved.studentNames }
                result[saved.id] = item
            } else {
                result[saved.id] = ScheduledContact(id: saved.id, due: saved.plannedDate, studentNames: saved.studentNames, saved: saved, historical: true)
            }
        }
        return result.values.sorted { $0.due < $1.due }
    }
}

// The return establishes that an annex was sent, even when its send date is unknown.
extension Array where Element == Step {
    mutating func reconcileAnnexes() {
        guard count == 10 else { return }
        for (sent, returned) in [(2, 3), (8, 9)] where self[returned].done && !self[sent].done {
            self[sent].done = true
            self[sent].date = self[returned].date
        }
    }
    mutating func setCompletion(at index: Int, to value: Bool) {
        self[index].setDone(value)
        if count == 10 {
            for (sent, returned) in [(2, 3), (8, 9)] where index == sent && !value {
                self[returned].done = false
            }
            reconcileAnnexes()
        }
    }
}
