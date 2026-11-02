// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Juan Luis (JLPalmes)
import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor final class Store: ObservableObject {
    @Published var db = Database() { didSet {
        if !loading && oldValue != db {
            let path = Self.textEditPath(from: oldValue, to: db)
            let now = Date()
            if path == nil || path != lastEditPath || now.timeIntervalSince(lastEditTime) > 2 {
                undoHistory.append(oldValue)
                if undoHistory.count > 50 { undoHistory.removeFirst() }
            }
            lastEditPath = path; lastEditTime = now
            redoHistory.removeAll()
            updateHistoryStatus()
            save()
        }
    } }
    private var lastEditPath: String?
    private var lastEditTime = Date.distantPast
    func endEditingGroup() { lastEditPath = nil; lastEditTime = .distantPast }
    private static func textEditPath(from old: Database, to new: Database) -> String? {
        guard let before = try? JSONSerialization.jsonObject(with: JSONEncoder().encode(old)),
              let after = try? JSONSerialization.jsonObject(with: JSONEncoder().encode(new)) else { return nil }
        let fields: Set<String> = ["name", "group", "dni", "nuss", "email", "phone", "preferredType", "preferredZone", "preferences", "notes", "cif", "address", "contact", "title", "institute", "course"]
        var paths: [String] = []
        func compare(_ a: Any, _ b: Any, path: String, field: String) {
            if let a = a as? NSDictionary, let b = b as? NSDictionary, a.isEqual(b) { return }
            if let a = a as? [String: Any], let b = b as? [String: Any], Set(a.keys) == Set(b.keys) {
                for key in a.keys { compare(a[key]!, b[key]!, path: path + "/" + key, field: key) }
            } else if let a = a as? [Any], let b = b as? [Any], a.count == b.count {
                for i in a.indices { compare(a[i], b[i], path: path + "/\(i)", field: field) }
            } else if let a = a as? String, let b = b as? String {
                if a != b { paths.append(fields.contains(field) ? path : "") }
            } else if !(a as AnyObject).isEqual(b) { paths.append("") }
        }
        compare(before, after, path: "", field: "")
        return paths.count == 1 && !paths[0].isEmpty ? paths[0] : nil
    }
    private var undoHistory: [Database] = []
    private var redoHistory: [Database] = []
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false
    private func updateHistoryStatus() {
        canUndo = !undoHistory.isEmpty; canRedo = !redoHistory.isEmpty
    }
    func undo() {
        endEditingGroup()
        guard !blocked, let previous = undoHistory.popLast() else { return }
        redoHistory.append(db)
        loading = true; db = previous; loading = false
        updateHistoryStatus(); save()
    }
    func redo() {
        endEditingGroup()
        guard !blocked, let next = redoHistory.popLast() else { return }
        undoHistory.append(db)
        loading = true; db = next; loading = false
        updateHistoryStatus(); save()
    }
    func archiveCourse(named nextCourse: String) throws {
        guard !blocked else { throw CocoaError(.fileReadCorruptFile) }
        let title = nextCourse.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title != db.course else {
            throw ImportFailure(message: "Indica un curso nuevo, distinto del actual.")
        }
        var snapshot = db; snapshot.archivedCourses = nil
        let archive = ArchivedCourse(title: db.course, snapshot: try JSONEncoder().encode(snapshot))
        var updated = db
        updated.archivedCourses = (db.archivedCourses ?? []) + [archive]
        updated.students = []; updated.course = title
        updated.exclusions = []; updated.instituteDaysConfirmed = false
        for i in updated.companies.indices {
            updated.companies[i].monthlyContacts = nil
            updated.companies[i].capacity = nil
            updated.companies[i].response = nil
            updated.companies[i].contactedOn = nil
            updated.companies[i].respondedOn = nil
        }
        try backup()
        db = updated
    }
    @Published var error: String?
    @Published var backupMessage: String?
    @Published var status = "Guardado en este Mac"
    private var loading = true
    private var blocked = false
    let folder: URL
    var file: URL { folder.appendingPathComponent("datos.json") }
    var backups: URL { folder.appendingPathComponent("Copias") }
    init(folder: URL? = nil) {
        let arguments = ProcessInfo.processInfo.arguments
        let testFolder: URL? = arguments.firstIndex(of: "--data-directory").flatMap { index in
            arguments.indices.contains(index + 1) ? URL(fileURLWithPath: arguments[index + 1]) : nil
        }
        self.folder = folder ?? testFolder ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("PracticasFP")
        do {
            try FileManager.default.createDirectory(at: backups, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            if FileManager.default.fileExists(atPath: file.path) {
                db = try Self.decode(Data(contentsOf: file))
                try backup()
            }
        } catch { self.error = "No se han cargado los datos. Se protege el archivo original. \(error.localizedDescription)"; blocked = true }
        loading = false
    }
    static func decode(_ data: Data) throws -> Database {
        var db = try JSONDecoder().decode(Database.self, from: data)
        guard [1, 2, 3, 4].contains(db.version) else { throw CocoaError(.fileReadCorruptFile) }
        guard Set(db.students.map(\.id)).count == db.students.count,
              Set(db.companies.map(\.id)).count == db.companies.count,
              Set(db.tutors.map(\.id)).count == db.tutors.count else { throw CocoaError(.fileReadCorruptFile) }
        guard db.companies.allSatisfy({ company in
            company.capacity.map { $0 >= 0 && $0 >= db.occupiedPlaces(company.id) } ?? true
        }) else { throw CocoaError(.fileReadCorruptFile) }
        guard db.students.allSatisfy({ $0.paperwork.count == 10 && Set($0.paperwork.map(\.id)).count == 10 }),
              db.companies.allSatisfy({ $0.paperwork.count == 4 && Set($0.paperwork.map(\.id)).count == 4 &&
                  Set(($0.monthlyContacts ?? []).map(\.id)).count == ($0.monthlyContacts ?? []).count })
        else { throw CocoaError(.fileReadCorruptFile) }
        guard db.students.allSatisfy({ student in
            student.shifts.allSatisfy { period in
                period.paperwork.map { $0.count == 10 && Set($0.map(\.id)).count == 10 } ?? true
            }
        }) else { throw CocoaError(.fileReadCorruptFile) }
        func validDocuments(_ docs: [DocumentFlow]?, allowed: Set<DocumentKind>) -> Bool {
            guard let docs else { return true }
            return Set(docs.map(\.kind)).count == docs.count && docs.allSatisfy { allowed.contains($0.kind) && $0.valid }
        }
        guard db.students.allSatisfy({ validDocuments($0.documents, allowed: [.annexI,.annexII]) && $0.shifts.allSatisfy { validDocuments($0.documents, allowed: [.annexI,.annexII]) } }),
              db.companies.allSatisfy({ validDocuments($0.documents, allowed: [.agreement]) }) else { throw CocoaError(.fileReadCorruptFile) }
        db.migrateWorkflow()
        db.version = 4
        for i in db.students.indices {
            for j in db.students[i].paperwork.indices { db.students[i].paperwork[j].title = studentPaperworkTitles[j] }
            db.students[i].paperwork.reconcileAnnexes()
            for j in db.students[i].shifts.indices where db.students[i].shifts[j].paperwork != nil {
                for k in db.students[i].shifts[j].paperwork!.indices {
                    db.students[i].shifts[j].paperwork![k].title = studentPaperworkTitles[k]
                }
                db.students[i].shifts[j].paperwork!.reconcileAnnexes()
            }
        }
        return db
    }
    func assign(_ studentID: UUID, to companyID: UUID?) {
        var updated = db
        guard updated.assign(studentID, to: companyID) else {
            error = "No se puede asignar esta empresa: no quedan plazas o aún no se ha indicado el número de plazas."
            return
        }
        db = updated
    }
    func assignPeriod(_ studentID: UUID, periodID: UUID, to companyID: UUID?) {
        var updated = db
        guard updated.assignPeriod(studentID, periodID: periodID, to: companyID) else {
            error = "No se puede usar esta empresa en el periodo: no quedan plazas o todavía no admite alumnas."
            return
        }
        db = updated
    }
    func setTutor(_ tutorID: UUID?, for studentID: UUID, at companyID: UUID) {
        var updated = db
        guard updated.setTutor(tutorID, for: studentID, at: companyID) else {
            error = "El tutor debe pertenecer a la empresa de este periodo."
            return
        }
        db = updated
    }
    func setPaperwork(_ paperwork: [Step], for studentID: UUID, at companyID: UUID) {
        var updated = db
        guard updated.setPaperwork(paperwork, for: studentID, at: companyID) else { return }
        db = updated
    }
    func setDocument(_ flow: DocumentFlow, studentID: UUID, periodID: UUID? = nil) {
        guard let i = db.students.firstIndex(where: { $0.id == studentID }) else { return }
        var updated = db; updated.students[i].setDocument(flow, periodID: periodID); db = updated
    }
    func setCompanyDocument(_ flow: DocumentFlow, companyID: UUID) {
        guard let i = db.companies.firstIndex(where: { $0.id == companyID }) else { return }
        var updated = db; updated.companies[i].setDocument(flow); db = updated
    }
    func setResponse(_ response: CompanyResponse, for companyID: UUID) {
        guard let i = db.companies.firstIndex(where: { $0.id == companyID }) else { return }
        if response == .rejected && db.occupiedPlaces(companyID) > 0 {
            error = "Esta empresa tiene alumnas asignadas. Reasígnalas antes de marcar que rechaza alumnas."
            return
        }
        var updated = db
        updated.companies[i].response = response
        if response == .waiting && updated.companies[i].contactedOn == nil { updated.companies[i].contactedOn = Date() }
        if [.accepted, .rejected].contains(response) && updated.companies[i].respondedOn == nil { updated.companies[i].respondedOn = Date() }
        db = updated
    }
    func updateContact(companyID: UUID, item: ScheduledContact, change: (inout MonthlyContact) -> Void) {
        guard let i = db.companies.firstIndex(where: { $0.id == companyID }) else { return }
        var updated = db
        var contacts = updated.companies[i].monthlyContacts ?? []
        if let j = contacts.firstIndex(where: { $0.id == item.id }) {
            if !contacts[j].completed {
                contacts[j].plannedDate = item.due
                contacts[j].studentNames = item.studentNames
            }
            change(&contacts[j])
        } else {
            var contact = MonthlyContact(id: item.id, plannedDate: item.due, studentNames: item.studentNames)
            change(&contact)
            contacts.append(contact)
        }
        updated.companies[i].monthlyContacts = contacts
        db = updated
    }
    func setCapacity(_ value: Int, for companyID: UUID) {
        var updated = db
        guard updated.setCapacity(value, for: companyID) else {
            error = "Las plazas no pueden ser negativas ni inferiores a las alumnas ya vinculadas a la empresa."
            return
        }
        db = updated
    }
    func importStudents(_ students: [Student]) throws {
        guard !blocked else { throw ImportFailure(message: "Restaura primero los datos: el archivo actual está protegido por un error de lectura.") }
        guard !students.isEmpty else { throw ImportFailure(message: "No hay alumnas válidas para importar.") }
        var seen = db.students.reduce(into: Set<String>()) { $0.formUnion(identityKeys($1)) }
        for s in students {
            guard !s.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  s.companyID == nil, s.tutorID == nil,
                  seen.isDisjoint(with: identityKeys(s)) else {
                throw ImportFailure(message: "La lista contiene una fila vacía, una asignación o un duplicado. Revisa la vista previa.")
            }
            seen.formUnion(identityKeys(s))
        }
        var updated = db
        updated.students.append(contentsOf: students)
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try enc.encode(updated)
        try backup()
        try data.write(to: file, options: .atomic)
        endEditingGroup()
        undoHistory.append(db)
        if undoHistory.count > 50 { undoHistory.removeFirst() }
        redoHistory.removeAll()
        loading = true; db = updated; loading = false
        updateHistoryStatus()
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        status = "\(students.count) alumnas importadas y guardadas"
    }
    func save() {
        guard !blocked else { return }
        do {
            let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            try enc.encode(db).write(to: file, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
            status = "Guardado en este Mac"
        } catch { status = "Error al guardar"; self.error = error.localizedDescription }
    }
    func backup() throws {
        guard FileManager.default.fileExists(atPath: file.path) else { return }
        let name = "Copia-\(Int(Date().timeIntervalSince1970))-\(UUID().uuidString.prefix(6)).json"
        try FileManager.default.copyItem(at: file, to: backups.appendingPathComponent(name))
    }
    func exportBackup(to destination: URL) throws {
        guard !blocked else { throw CocoaError(.fileReadCorruptFile) }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(db)
        _ = try Self.decode(data)
        try data.write(to: destination, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
        guard try Data(contentsOf: destination) == data else { throw CocoaError(.fileWriteUnknown) }
    }
    func manualBackup() {
        let panel = NSSavePanel()
        panel.title = "Guardar copia de seguridad"
        panel.prompt = "Guardar copia"
        panel.allowedContentTypes = [.json]
        panel.directoryURL = backups
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        panel.nameFieldStringValue = "PracticasFP-Copia-" + formatter.string(from: Date()) + ".json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try exportBackup(to: url)
            backupMessage = "Copia guardada y verificada: " + url.path
            status = "Copia de seguridad guardada"
        } catch { self.error = "No se ha guardado la copia. " + error.localizedDescription }
    }
    func restore(from url: URL) throws {
        let recovered = try Self.decode(Data(contentsOf: url))
        let data = try JSONEncoder().encode(recovered)
        try backup()
        try data.write(to: file, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        endEditingGroup(); undoHistory.append(db)
        if undoHistory.count > 50 { undoHistory.removeFirst() }
        redoHistory.removeAll()
        loading = true; blocked = false; db = recovered; loading = false
        updateHistoryStatus(); status = "Copia restaurada y guardada"
    }
}
