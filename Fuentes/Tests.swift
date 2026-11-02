// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Juan Luis (JLPalmes)
import Foundation
@main struct Tests {
    @MainActor static func main() throws {
        var db = Database(); db.exclusions = []
        var s = Student(); s.hasStart = true; s.start = day("2027-01-04"); s.hours = 8
        func check(_ condition: Bool, _ label: String) { if !condition { fatalError(label) }; print("OK: " + label) }
        var r = calculate(s, db, today: day("2027-01-05"))
        check(r.end == day("2027-03-31") && r.lastHours == 4, "500 h, fines de semana y última jornada parcial")
        check(r.elapsed == 8, "Horas previstas excluyen el día actual")
        s.start = day("2027-01-02")
        check(calculate(s, db).end == r.end, "Inicio en sábado")
        s.start = day("2027-01-04")
        db.exclusions = [Exclusion(title: "Fiesta", from: day("2027-01-05"), to: day("2027-01-05"))]
        check(calculate(s, db).end == day("2027-04-01"), "Festivo aplaza fin")
        db.exclusions.append(db.exclusions[0])
        check(calculate(s, db).end == day("2027-04-01"), "Exclusiones superpuestas no duplican descuento")
        db.exclusions = []
        s.shifts = [Shift(from: day("2027-01-11"), hours: 4)]
        r = calculate(s, db)
        check(r.end == day("2027-06-18") && r.lastHours == 4, "Reducción de jornada conserva 40 horas anteriores")
        s.manualEnd = true; s.end = day("2027-01-15")
        check(calculate(s, db).scheduledToManual == 60, "Horas hasta fecha manual")
        s.shifts.append(Shift(from: day("2027-01-11"), hours: 6))
        check(calculate(s, db).error != nil, "Rechaza cambios duplicados")
        s.shifts = []; s.hours = 0
        check(calculate(s, db).error != nil, "Rechaza cero horas")
        s.hours = 7; s.start = day("2026-12-22")
        check(calculate(s, Database(), today: day("2027-01-11")).elapsed == 7, "Navidad corregida y extremos inclusivos")
        s.start = day("2027-03-19")
        check(calculate(s, Database(), today: day("2027-03-29")).elapsed == 7, "Semana Santa y cambio de hora")
        let folder = URL(fileURLWithPath: CommandLine.arguments[1])
        let store = Store(folder: folder)
        store.db.students.append(s)
        let loaded = Store(folder: folder)
        check(loaded.db.students == [s], "Persistencia local tras reapertura")
        check(try FileManager.default.contentsOfDirectory(atPath: loaded.backups.path).count > 0, "Copia automática al abrir")
        let original = Data("archivo incorrecto".utf8)
        try original.write(to: loaded.file)
        let broken = Store(folder: folder)
        broken.db.students.append(Student())
        check(try Data(contentsOf: broken.file) == original, "Archivo dañado protegido de sobrescritura")

        var places = Database()
        var first = Company(); first.name = "Empresa A"
        var second = Company(); second.name = "Empresa B"; second.capacity = 1
        let one = Student(); let two = Student()
        places.companies = [first, second]; places.students = [one, two]
        check(!places.assign(one.id, to: first.id), "Cupo sin indicar bloquea asignación")
        check(places.setCapacity(1, for: first.id), "Establecer plazas")
        check(places.assign(one.id, to: first.id), "Asignación provisional ocupa plaza")
        let beforeRejection = places
        check(!places.assign(two.id, to: first.id) && places == beforeRejection, "Empresa llena rechaza sin modificar fichas")
        check(places.canAssign(one.id, to: first.id), "Conservar empresa actual aunque esté llena")
        places.students[0].assignment = "Definitiva"
        check(!places.canAssign(two.id, to: first.id), "Asignación definitiva ocupa plaza")
        check(!places.setCapacity(0, for: first.id) && places.companies[0].capacity == 1, "No reducir cupo por debajo de ocupación")
        check(!places.setCapacity(-1, for: second.id), "Rechazar cupo negativo")
        check(places.assign(two.id, to: second.id), "Asignar segunda empresa")
        let tutorID = UUID(); places.students[0].tutorID = tutorID
        check(!places.assign(one.id, to: second.id) && places.students[0].tutorID == tutorID && places.students[0].companyID == first.id, "Cambio rechazado conserva empresa y tutor")
        check(places.assign(two.id, to: nil) && places.occupiedPlaces(second.id) == 0, "Desvincular libera plaza")
        check(places.assign(one.id, to: second.id) && places.occupiedPlaces(first.id) == 0 && places.students[0].tutorID == nil, "Cambio válido libera origen y limpia tutor")
        check(places.setCapacity(0, for: first.id) && !places.canAssign(two.id, to: first.id), "Cero plazas impide asignaciones")
        let encoded = try JSONEncoder().encode(places)
        check(try Store.decode(encoded) == places, "Persistencia de cupos")
        var legacy = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        var legacyCompanies = legacy["companies"] as! [[String: Any]]
        for i in legacyCompanies.indices { legacyCompanies[i].removeValue(forKey: "capacity") }
        legacy["companies"] = legacyCompanies
        let migrated = try Store.decode(JSONSerialization.data(withJSONObject: legacy))
        check(migrated.companies.allSatisfy { $0.capacity == nil } && migrated.students == places.students, "Leer copia anterior conserva asignaciones sin inventar cupos")
        var invalid = places; invalid.companies[1].capacity = 0
        var rejected = false
        do { _ = try Store.decode(JSONEncoder().encode(invalid)) } catch { rejected = true }
        check(rejected, "Restauración rechaza cupos insuficientes")
        print("Todas las pruebas superadas.")
    }
}
