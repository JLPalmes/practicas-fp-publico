// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Juan Luis (JLPalmes)
import Foundation

let cal: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Atlantic/Canary")!
    return c
}()
func day(_ s: String) -> Date {
    let f = DateFormatter(); f.calendar = cal; f.timeZone = cal.timeZone; f.dateFormat = "yyyy-MM-dd"
    return f.date(from: s)!
}
func dateText(_ d: Date) -> String {
    let f = DateFormatter(); f.locale = Locale(identifier: "es_ES"); f.timeZone = cal.timeZone
    f.dateStyle = .medium; return f.string(from: d)
}
struct Step: Codable, Identifiable, Equatable {
    var id = UUID(); var title: String; var done = false; var date = Date()
    mutating func setDone(_ value: Bool, on date: Date = Date()) {
        if value && !done { self.date = date }
        done = value
    }
}
func steps(_ titles: [String]) -> [Step] { titles.map { Step(title: $0) } }
let studentPaperworkTitles = [
    "Certificado de delitos de naturaleza sexual aportado",
    "Anexo I · asignación de tutor a alumna · generado",
    "Anexo I · asignación de tutor a alumna · firmado por mí y remitido a la empresa",
    "Anexo I · asignación de tutor a alumna · devuelto firmado por el tutor",
    "Anexo I · asignación de tutor a alumna · firma de la alumna",
    "Práctica iniciada",
    "Práctica terminada",
    "Anexo II · calificación final de la alumna · generado",
    "Anexo II · calificación final de la alumna · firmado por mí y remitido a la empresa",
    "Anexo II · calificación final de la alumna · devuelto firmado por el tutor"
]
struct Shift: Codable, Identifiable, Equatable {
    var id = UUID(); var from = Date(); var hours: Double?
    // nil means that the company from the preceding period continues.
    var companyID: UUID?
    var tutorID: UUID?
    // Separate annex workflow when this period starts at a different company.
    var documents: [DocumentFlow]?
    var paperwork: [Step]?

    init(id: UUID = UUID(), from: Date = Date(), hours: Double? = nil, companyID: UUID? = nil, tutorID: UUID? = nil, paperwork: [Step]? = nil) {
        self.id = id; self.from = from; self.hours = hours; self.companyID = companyID; self.tutorID = tutorID; self.paperwork = paperwork
    }
}
struct Student: Codable, Identifiable, Equatable {
    var documents: [DocumentFlow]?
    var id = UUID()
    var name = ""; var group = ""; var dni = ""; var nuss = ""; var email = ""; var phone = ""
    var companyID: UUID?; var tutorID: UUID?
    var assignment = "Pendiente"
    var preferredType = ""; var preferredZone = ""; var preferences = ""; var notes = ""
    var hasStart = false; var start = Date(); var hours = 7.0; var shifts: [Shift] = []
    var targetHours: Double?
    var requiredHours: Double { targetHours ?? 500 }
    var manualEnd = false; var end = Date()
    var paperwork = steps(studentPaperworkTitles)
}
struct Company: Codable, Identifiable, Equatable {
    var documents: [DocumentFlow]?
    var response: CompanyResponse?
    var contactedOn: Date?
    var respondedOn: Date?
    var monthlyContacts: [MonthlyContact]?
    var capacity: Int? = nil
    var id = UUID(); var name = ""; var cif = ""; var address = ""; var contact = ""; var phone = ""; var email = ""; var notes = ""
    var paperwork = steps(["Concierto emitido", "Concierto firmado por el director del instituto", "Concierto firmado por la empresa", "Concierto cargado en la aplicación de gestión"])
}
struct Tutor: Codable, Identifiable, Equatable {
    var id = UUID(); var name = ""; var companyID: UUID?; var phone = ""; var email = ""; var notes = ""
}
struct Exclusion: Codable, Identifiable, Equatable {
    var id = UUID(); var title = ""; var from = Date(); var to = Date(); var kind = "Libre disposición"
    init(title: String = "", from: Date = Date(), to: Date = Date(), kind: String = "Libre disposición") {
        self.title = title; self.from = from; self.to = to; self.kind = kind
    }
}
struct ArchivedCourse: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var archivedOn = Date()
    var snapshot: Data
}
struct Database: Codable, Equatable {
    var archivedCourses: [ArchivedCourse]?
    var version = 4
    var students: [Student] = []; var companies: [Company] = []; var tutors: [Tutor] = []
    var course = "2026–2027"; var institute = "IES Pérez Galdós"
    var calendarFrom = day("2026-09-01"); var calendarTo = day("2027-06-30")
    var instituteDaysConfirmed = false
    var exclusions: [Exclusion] = [
        Exclusion(title: "Navidad (BOC, corrección de abril)", from: day("2026-12-23"), to: day("2027-01-08"), kind: "Vacaciones"),
        Exclusion(title: "Semana Santa", from: day("2027-03-22"), to: day("2027-03-26"), kind: "Vacaciones")
    ] + [
        ("2026-09-08", "Nuestra Señora del Pino"),
        ("2026-10-12", "Fiesta Nacional"), ("2026-11-02", "Todos los Santos"),
        ("2026-12-07", "Día del Enseñante y del Estudiante"), ("2026-12-08", "Inmaculada"),
        ("2027-02-09", "Martes de Carnaval · Las Palmas"),
        ("2027-05-01", "Fiesta del Trabajo"), ("2027-05-30", "Día de Canarias"),
        ("2027-06-24", "Fundación de la Ciudad")
    ].map { Exclusion(title: $0.1, from: day($0.0), to: day($0.0), kind: "Festivo") }
}
struct Calculation {
    var end: Date?; var lastHours = 0.0; var elapsed = 0.0; var scheduledToManual = 0.0
    var error: String?
}
func calculate(_ s: Student, _ db: Database, today: Date = Date()) -> Calculation {
    guard s.requiredHours.isFinite && s.requiredHours > 0 && s.requiredHours <= 10000 else {
        return Calculation(error: "Las horas objetivo deben ser mayores de 0 y no superar 10.000.")
    }
    guard s.hasStart else { return Calculation() }
    guard s.hours.isFinite && s.hours > 0 && s.hours <= 24 else {
        return Calculation(error: "La jornada inicial debe tener más de 0 y hasta 24 horas.")
    }
    guard s.shifts.allSatisfy({ shift in
        guard let hours = shift.hours else { return false }
        return hours.isFinite && hours > 0 && hours <= 24
    }) else {
        return Calculation(error: "Completa las horas de todos los periodos (más de 0 y hasta 24).")
    }
    let changes = s.shifts.sorted { $0.from < $1.from }
    guard changes.allSatisfy({ cal.startOfDay(for: $0.from) >= cal.startOfDay(for: s.start) }),
          Set(changes.map { cal.startOfDay(for: $0.from) }).count == changes.count else {
        return Calculation(error: "Los cambios deben ser posteriores o iguales al inicio y tener fechas distintas.")
    }
    guard db.exclusions.allSatisfy({ cal.startOfDay(for: $0.from) <= cal.startOfDay(for: $0.to) }) else {
        return Calculation(error: "Hay un intervalo invertido en el calendario.")
    }
    var result = Calculation(); var total = 0.0; var d = cal.startOfDay(for: s.start)
    let now = cal.startOfDay(for: today); let manual = cal.startOfDay(for: s.end)
    for _ in 0..<3660 {
        let weekday = cal.component(.weekday, from: d)
        let excluded = weekday == 1 || weekday == 7 || db.exclusions.contains {
            d >= cal.startOfDay(for: $0.from) && d <= cal.startOfDay(for: $0.to)
        }
        if !excluded {
            let h = changes.last(where: { cal.startOfDay(for: $0.from) <= d })?.hours ?? s.hours
            if d < now { result.elapsed = min(s.requiredHours, result.elapsed + h) }
            if d <= manual { result.scheduledToManual += h }
            if total < s.requiredHours {
                if total + h >= s.requiredHours - 0.000001 { result.end = d; result.lastHours = s.requiredHours - total }
                total += h
            }
        }
        if result.end != nil && (!s.manualEnd || d >= manual) && d >= now { break }
        d = cal.date(byAdding: .day, value: 1, to: d)!
    }
    if result.end == nil { result.error = "No se alcanzan las horas objetivo en los próximos diez años." }
    return result
}

extension Database {
    func companyIDs(for student: Student) -> Set<UUID> {
        var ids = Set(student.companyID.map { [$0] } ?? [])
        ids.formUnion(student.shifts.compactMap(\.companyID))
        return ids
    }
    func companyID(for student: Student, on date: Date) -> UUID? {
        var companyID = student.companyID
        for period in student.shifts.sorted(by: { $0.from < $1.from })
            where cal.startOfDay(for: period.from) <= cal.startOfDay(for: date) {
            if let changedCompany = period.companyID { companyID = changedCompany }
        }
        return companyID
    }
    func tutorID(for student: Student, at companyID: UUID) -> UUID? {
        if student.companyID == companyID { return student.tutorID }
        return student.shifts.last(where: { $0.companyID == companyID })?.tutorID
    }
    func paperwork(for student: Student, at companyID: UUID) -> [Step] {
        if student.companyID == companyID { return student.paperwork }
        return student.shifts.last(where: { $0.companyID == companyID })?.paperwork ?? Student().paperwork
    }
    func occupiedPlaces(_ companyID: UUID) -> Int {
        students.filter { companyIDs(for: $0).contains(companyID) }.count
    }
    func canAssign(_ studentID: UUID, to companyID: UUID?) -> Bool {
        guard let student = students.first(where: { $0.id == studentID }) else { return false }
        guard let companyID else { return true }
        guard let company = companies.first(where: { $0.id == companyID }) else { return false }
        if student.companyID == companyID { return true }
        guard company.response != .rejected, company.response != .waiting, company.response != .uncontacted, let capacity = company.capacity else { return false }
        return occupiedPlaces(companyID) < capacity
    }
    mutating func assign(_ studentID: UUID, to companyID: UUID?) -> Bool {
        guard canAssign(studentID, to: companyID),
              let index = students.firstIndex(where: { $0.id == studentID }) else { return false }
        guard students[index].companyID != companyID else { return true }
        students[index].companyID = companyID
        students[index].tutorID = nil
        students[index].assignment = companyID == nil ? "Pendiente" : "Provisional"
        return true
    }
    func canAssignPeriod(_ studentID: UUID, periodID: UUID, to companyID: UUID?) -> Bool {
        guard let student = students.first(where: { $0.id == studentID }),
              student.shifts.contains(where: { $0.id == periodID }) else { return false }
        guard let companyID else { return true }
        guard let company = companies.first(where: { $0.id == companyID }) else { return false }
        if companyIDs(for: student).contains(companyID) { return true }
        guard company.response == .accepted, let capacity = company.capacity else { return false }
        return occupiedPlaces(companyID) < capacity
    }
    mutating func assignPeriod(_ studentID: UUID, periodID: UUID, to companyID: UUID?) -> Bool {
        guard canAssignPeriod(studentID, periodID: periodID, to: companyID),
              let studentIndex = students.firstIndex(where: { $0.id == studentID }),
              let periodIndex = students[studentIndex].shifts.firstIndex(where: { $0.id == periodID }) else { return false }
        students[studentIndex].shifts[periodIndex].companyID = companyID
        students[studentIndex].shifts[periodIndex].tutorID = nil
        if companyID != nil && students[studentIndex].shifts[periodIndex].paperwork == nil {
            students[studentIndex].shifts[periodIndex].paperwork = Student().paperwork
        }
        return true
    }
    mutating func setTutor(_ tutorID: UUID?, for studentID: UUID, at companyID: UUID) -> Bool {
        guard tutorID == nil || tutors.contains(where: { $0.id == tutorID && $0.companyID == companyID }),
              let studentIndex = students.firstIndex(where: { $0.id == studentID }) else { return false }
        if students[studentIndex].companyID == companyID {
            students[studentIndex].tutorID = tutorID
            return true
        }
        guard let periodIndex = students[studentIndex].shifts.lastIndex(where: { $0.companyID == companyID }) else { return false }
        students[studentIndex].shifts[periodIndex].tutorID = tutorID
        return true
    }
    mutating func setPaperwork(_ paperwork: [Step], for studentID: UUID, at companyID: UUID) -> Bool {
        guard paperwork.count == 10,
              let studentIndex = students.firstIndex(where: { $0.id == studentID }) else { return false }
        if students[studentIndex].companyID == companyID {
            students[studentIndex].paperwork = paperwork
            return true
        }
        guard let periodIndex = students[studentIndex].shifts.lastIndex(where: { $0.companyID == companyID }) else { return false }
        students[studentIndex].shifts[periodIndex].paperwork = paperwork
        return true
    }
    mutating func setCapacity(_ value: Int, for companyID: UUID) -> Bool {
        guard value >= 0, value >= occupiedPlaces(companyID),
              let index = companies.firstIndex(where: { $0.id == companyID }) else { return false }
        companies[index].capacity = value
        if value > 0 { companies[index].response = .accepted }
        return true
    }
    func placesLabel(_ company: Company) -> String {
        let occupied = occupiedPlaces(company.id)
        guard let capacity = company.capacity else { return "Plazas sin indicar · \(occupied) asignadas" }
        return "\(occupied)/\(capacity) ocupadas · \(max(0, capacity - occupied)) libres"
    }
}
