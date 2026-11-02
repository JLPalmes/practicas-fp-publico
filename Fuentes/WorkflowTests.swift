// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Juan Luis (JLPalmes)
import Foundation
@main struct WorkflowTests {
 @MainActor static func main() throws {
  func check(_ value: Bool, _ label: String) { precondition(value, label); print("OK: " + label) }
  var db = Database(); db.exclusions = []; db.version = 1
  var c = Company(); c.name = "Empresa de prueba"; c.capacity = 3
  var s = Student(); s.name = "Alumna de prueba"; s.companyID = c.id; s.assignment = "Definitiva"; s.hasStart = true; s.start = day("2027-01-31"); s.hours = 7
  s.paperwork[2].setDone(true, on: day("2027-01-20")); s.paperwork[3].setDone(true, on: day("2027-01-25"))
  db.companies = [c]; db.students = [s]
  db = try Store.decode(JSONEncoder().encode(db))
  check(db.version == 4, "Migración actualiza la versión")
  check(db.students[0].paperwork[1].title.contains("asignación de tutor"), "Anexo I identificado como asignación de tutor")
  check(db.students[0].paperwork[7].title.contains("calificación final"), "Anexo II identificado como calificación final")
  check(db.students[0].paperwork[2].done && db.students[0].paperwork[3].done, "Devolución antigua confirma remisión")
  check(db.companies[0].response == .accepted, "Asignación existente conserva empresa admitida")
  let again = try Store.decode(JSONEncoder().encode(db)); check(again == db, "Migración idempotente")
  var schedule = db.monthlySchedule(for: c.id)
  check(schedule[0].due == day("2027-02-28") && schedule[1].due == day("2027-03-31"), "Aniversarios desde día 31 sin deriva")
  var second = s; second.id = UUID(); second.name = "Segunda alumna"; second.start = day("2027-02-05")
  db.students.append(second); schedule = db.monthlySchedule(for: c.id)
  check(schedule.first { $0.id == "2027-03" }!.due == day("2027-03-05") && schedule.first { $0.id == "2027-03" }!.studentNames.count == 2, "Agrupar por empresa y mes con primer vencimiento")
  db.students[1].assignment = "Provisional"
  check(db.monthlySchedule(for: c.id).first { $0.id == "2027-03" }!.studentNames.count == 1, "Provisionales no generan contactos")
  db.students[0].manualEnd = true; db.students[0].end = day("2027-03-15")
  check(db.monthlySchedule(for: c.id).count == 1, "Fin manual limita contactos")
  let folder = URL(fileURLWithPath: CommandLine.arguments[1]); let store = Store(folder: folder); store.db = db
  let item = store.db.monthlySchedule(for: c.id)[0]
  store.updateContact(companyID: c.id, item: item) { $0.setCompleted(true, on: day("2027-03-01")); $0.notes = "Evolución favorable" }
  store.db.students[0].paperwork[2].setDone(true, on: day("2027-02-01"))
  let reopened = Store(folder: folder)
  check(reopened.db == store.db && reopened.db.students[0].paperwork[2].done, "Checks, fechas y observaciones persisten al reabrir")
  reopened.db.students[0].hasStart = false
  let historical = reopened.db.monthlySchedule(for: c.id)[0]
  check(historical.historical && historical.saved!.completed && historical.saved!.notes == "Evolución favorable", "Contacto realizado se conserva si cambia calendario")
  reopened.setResponse(.rejected, for: c.id)
  check(reopened.db.companies[0].response == .accepted && reopened.error != nil, "Rechazo bloqueado con alumnas asignadas")
  var step = Step(title: "Prueba"); step.setDone(true, on: day("2027-01-01")); step.setDone(true, on: day("2027-02-01"))
  check(step.date == day("2027-01-01"), "Fecha no cambia al reafirmar realizado")
  step.setDone(false); check(!step.done, "Desmarcar trámite")
  var annexes = Student().paperwork
  annexes.setCompletion(at: 9, to: true)
  check(annexes[8].done && annexes[9].done, "Devolución de Anexo II implica remisión")
  annexes.setCompletion(at: 8, to: false)
  check(!annexes[8].done && !annexes[9].done, "Retirar remisión retira devolución incompatible")
  annexes.setCompletion(at: 3, to: true)
  annexes.setCompletion(at: 3, to: false)
  check(annexes[2].done && !annexes[3].done, "Retirar devolución conserva remisión")
  let export = folder.appendingPathComponent("exportada.json")
  try store.exportBackup(to: export)
  check(try Store.decode(Data(contentsOf: export)) == store.db, "Copia manual contiene todos los datos actuales")
  let empty = Store(folder: folder.appendingPathComponent("vacia"))
  let emptyExport = folder.appendingPathComponent("vacia.json")
  try empty.exportBackup(to: emptyExport)
  check(try Store.decode(Data(contentsOf: emptyExport)) == empty.db, "Copia manual funciona incluso antes del primer guardado")
  var invalidDestinationFailed = false
  do { try store.exportBackup(to: folder.appendingPathComponent("no-existe/copia.json")) } catch { invalidDestinationFailed = true }
  check(invalidDestinationFailed, "Destino inválido devuelve error y no éxito falso")
  let blankPeriod = Shift(from: day("2027-02-01"))
  check(blankPeriod.hours == nil, "Un periodo nuevo comienza con las horas en blanco")
  var incomplete = Student(); incomplete.hasStart = true; incomplete.start = day("2027-01-04"); incomplete.shifts = [blankPeriod]
  check(calculate(incomplete, Database()).error?.contains("Completa las horas") == true, "Las horas en blanco requieren cumplimentación")
  var transfer = Database(); transfer.exclusions = []
  var origin = Company(); origin.name = "Empresa de origen"; origin.capacity = 1; origin.response = .accepted
  var destination = Company(); destination.name = "Empresa nueva"; destination.capacity = 1; destination.response = .accepted
  var transferred = Student(); transferred.name = "Alumna trasladada"; transferred.companyID = origin.id; transferred.assignment = "Definitiva"; transferred.hasStart = true; transferred.start = day("2027-01-04"); transferred.hours = 7
  let transferPeriod = Shift(from: day("2027-02-15"), hours: 7, companyID: destination.id)
  transferred.shifts = [transferPeriod]
  transfer.companies = [origin, destination]; transfer.students = [transferred]
  check(transfer.companyIDs(for: transferred) == Set([origin.id, destination.id]), "El traslado conserva ambas empresas")
  check(transfer.companyID(for: transferred, on: day("2027-02-14")) == origin.id && transfer.companyID(for: transferred, on: day("2027-02-15")) == destination.id, "El cambio de empresa se aplica en la fecha del periodo")
  check(transfer.occupiedPlaces(origin.id) == 1 && transfer.occupiedPlaces(destination.id) == 1, "El traslado reserva plaza en ambas empresas vinculadas")
  check(transfer.monthlySchedule(for: origin.id).count == 1 && transfer.monthlySchedule(for: destination.id).first?.due == day("2027-03-15"), "El seguimiento mensual respeta las fechas de cada empresa")
  check(transfer.assignPeriod(transferred.id, periodID: transferPeriod.id, to: destination.id) && transfer.students[0].shifts[0].paperwork?.count == 10, "La empresa nueva crea sus propios anexos")
  var destinationPaperwork = transfer.paperwork(for: transfer.students[0], at: destination.id); destinationPaperwork.setCompletion(at: 3, to: true)
  check(transfer.setPaperwork(destinationPaperwork, for: transferred.id, at: destination.id) && transfer.paperwork(for: transfer.students[0], at: destination.id)[2].done && !transfer.paperwork(for: transfer.students[0], at: origin.id)[2].done, "Los anexos de cada empresa son independientes")
  var destinationTutor = Tutor(); destinationTutor.name = "Tutor nuevo"; destinationTutor.companyID = destination.id; transfer.tutors = [destinationTutor]
  check(transfer.setTutor(destinationTutor.id, for: transferred.id, at: destination.id) && transfer.tutorID(for: transfer.students[0], at: destination.id) == destinationTutor.id, "Tutor asignado al nuevo periodo")
  var another = Student(); another.name = "Otra alumna"; transfer.students.append(another)
  check(!transfer.canAssign(another.id, to: destination.id), "El cupo bloquea otra asignación a la empresa del nuevo periodo")
  print("31 pruebas de flujo superadas")
 }
}
