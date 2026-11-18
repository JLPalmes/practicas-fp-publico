// SPDX-License-Identifier: AGPL-3.0-only
import Foundation

struct Format5Period: Decodable, Identifiable {
    let id: UUID
    let active: Bool
    let hasStart: Bool
    let start: Date
    let end: Date
    let manualEnd: Bool
    let hours: Double
    let targetHours: Double
    let companyID: UUID?
    let tutorID: UUID?
    let assignment: String?
    let shifts: [Shift]
    let paperwork: [Step]
    let documents: [DocumentFlow]?

    func forecast(in calendar: Database, today: Date) -> Calculation {
        guard active else { return Calculation() }
        guard calendar.companies.contains(where: { $0.id == companyID }) else {
            return Calculation(error: "Asigna una empresa al periodo.")
        }
        guard hasStart else { return Calculation() }
        let startDay = cal.startOfDay(for: start)
        let completion = paperwork.dropFirst(6).first.flatMap { $0.done ? $0.date : nil }
        let endDay = cal.startOfDay(for: completion ?? end)
        let fixedEnd = completion != nil || manualEnd
        guard !fixedEnd || endDay >= startDay else {
            return Calculation(error: "El fin manual debe ser igual o posterior al inicio.")
        }
        var schedule = Student()
        schedule.hasStart = true
        schedule.start = start
        schedule.end = endDay
        schedule.manualEnd = fixedEnd
        schedule.hours = hours
        schedule.targetHours = fixedEnd && targetHours == 0 ? 0.01 : targetHours
        schedule.shifts = shifts
        var result = calculate(schedule, calendar, today: today)
        if fixedEnd && result.error == nil {
            let yesterday = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: today))!
            schedule.end = min(yesterday, endDay)
            result.elapsed = calculate(schedule, calendar, today: today).scheduledToManual
            result.end = endDay
        }
        return result
    }
}

struct Format5Student: Decodable {
    let id: UUID
    let targetHours: Double?
    let previousCourseHours: Double?
    let nextCourseHours: Double?
    let practicePeriods: [Format5Period]?

    func forecasts(in calendar: Database, today: Date) -> [Calculation] {
        let active = (practicePeriods ?? []).filter(\.active)
        var results = active.map { $0.forecast(in: calendar, today: today) }
        if active.count == 2, active[1].hasStart, let firstEnd = results[0].end,
           cal.startOfDay(for: active[1].start) <= firstEnd {
            results[1] = Calculation(error: "El segundo periodo debe comenzar después de finalizar el primero.")
        }
        return results
    }

    func remainingHours(elapsed: Double) -> Double {
        max(0, (targetHours ?? 500) - (previousCourseHours ?? 0) - elapsed)
    }
}

// Preview only. Keep the original bytes because the Mac editor does not yet
// represent every field used by Windows and Tauri.
struct Format5Preview {
    let original: Data
    let calendar: Database
    let students: [Format5Student]

    private struct Payload: Decodable {
        let version: Int
        let students: [Format5Student]
    }

    init(data: Data) throws {
        let decoder = JSONDecoder()
        let payload = try decoder.decode(Payload.self, from: data)
        guard payload.version == 5,
              Set(payload.students.map(\.id)).count == payload.students.count,
              payload.students.allSatisfy(Self.valid) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        original = data
        calendar = try decoder.decode(Database.self, from: data)
        students = payload.students
    }

    private static func valid(_ student: Format5Student) -> Bool {
        // Converted and legacy students may coexist in a format-5 course.
        guard let periods = student.practicePeriods else { return true }
        guard periods.count == 2, periods[0].active,
              Set(periods.map(\.id)).count == 2,
              student.previousCourseHours != nil, student.nextCourseHours != nil else { return false }
        return periods.allSatisfy { period in
            period.shifts.allSatisfy { $0.companyID == nil } &&
            Set(period.shifts.map(\.id)).count == period.shifts.count &&
            period.paperwork.count == 10 && Set(period.paperwork.map(\.id)).count == 10 &&
            (period.assignment.map { ["Pendiente", "Provisional", "Definitiva"].contains($0) } ?? true) &&
            Set((period.documents ?? []).map(\.kind)).count == (period.documents ?? []).count &&
            (period.documents ?? []).allSatisfy { $0.kind != .agreement && $0.valid }
        }
    }
}

struct Format5ScheduleEdit {
    var hasStart: Bool
    var start: Date
    var manualEnd: Bool
    var end: Date
    var hours: Double
    var targetHours: Double

    init(_ period: Format5Period) {
        hasStart = period.hasStart
        start = period.start
        manualEnd = period.manualEnd
        end = period.end
        hours = period.hours
        targetHours = period.targetHours
    }
}

extension Format5Preview {
    func editingSchedule(studentID: UUID, periodID: UUID, edit: Format5ScheduleEdit) throws -> Format5Preview {
        guard edit.hours.isFinite, (0...24).contains(edit.hours), edit.hours > 0,
              edit.targetHours.isFinite, (0...10000).contains(edit.targetHours),
              edit.targetHours > 0 || edit.manualEnd,
              !edit.hasStart || !edit.manualEnd || cal.startOfDay(for: edit.end) >= cal.startOfDay(for: edit.start),
              var root = try JSONSerialization.jsonObject(with: original) as? [String: Any],
              var records = root["students"] as? [[String: Any]],
              let index = records.firstIndex(where: { Self.identifier($0) == studentID }),
              var periods = records[index]["practicePeriods"] as? [[String: Any]],
              let periodIndex = periods.firstIndex(where: { Self.identifier($0) == periodID }),
              let student = students.first(where: { $0.id == studentID }),
              let period = student.practicePeriods?.first(where: { $0.id == periodID }), period.active else {
            throw CocoaError(.fileWriteUnknown)
        }
        periods[periodIndex]["hasStart"] = edit.hasStart
        periods[periodIndex]["start"] = edit.start.timeIntervalSinceReferenceDate
        periods[periodIndex]["manualEnd"] = edit.manualEnd
        periods[periodIndex]["end"] = edit.end.timeIntervalSinceReferenceDate
        periods[periodIndex]["hours"] = edit.hours
        periods[periodIndex]["targetHours"] = edit.targetHours
        records[index]["practicePeriods"] = periods
        root["students"] = records
        return try Format5Preview(data: JSONSerialization.data(withJSONObject: root, options: [.sortedKeys]))
    }

    private static func identifier(_ record: [String: Any]) -> UUID? {
        (record["id"] as? String).flatMap(UUID.init(uuidString:))
    }
}
