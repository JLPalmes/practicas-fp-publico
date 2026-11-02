// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Juan Luis (JLPalmes)
import SwiftUI
import AppKit
typealias LocalState<Value> = SwiftUI.State<Value>

enum AppIdentity {
    static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Sin especificar"
    static let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Sin especificar"
    static var versionLabel: String { "Versión " + version }
}

let accent = Color(red: 0.10, green: 0.42, blue: 0.40)
struct CompletionButton: View {
    var title: String
    var done: Bool
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: done ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(done ? accent : Color.secondary)
                Text(title).foregroundStyle(.primary).multilineTextAlignment(.leading)
            }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
        }.buttonStyle(.plain)
        .accessibilityLabel(title).accessibilityValue(done ? "Cumplimentado" : "Pendiente")
    }
}
struct Checklist: View {
    @Binding var items: [Step]
    var only: [Int]? = nil
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), alignment: .topLeading)], alignment: .leading, spacing: 8) {
        ForEach(items.filter { item in
            guard let only, let index = items.firstIndex(where: { $0.id == item.id }) else { return true }
            return only.contains(index)
        }) { step in
            VStack(alignment: .leading, spacing: 4) {
                CompletionButton(title: step.title, done: step.done) {
                    guard let i = items.firstIndex(where: { $0.id == step.id }) else { return }
                    var updated = items
                    updated.setCompletion(at: i, to: !updated[i].done)
                    items = updated
                }
                if step.done {
                    DatePicker("Fecha de cumplimiento", selection: Binding(
                        get: { items.first(where: { $0.id == step.id })?.date ?? step.date },
                        set: { date in
                            guard let i = items.firstIndex(where: { $0.id == step.id }) else { return }
                            var updated = items; updated[i].date = date; items = updated
                        }), displayedComponents: .date).labelsHidden().frame(width: 135)
                } else { Text("Pendiente").foregroundStyle(.secondary).font(.caption).frame(width: 85, alignment: .trailing) }
            }.padding(8).frame(maxWidth: .infinity, alignment: .leading).background(accent.opacity(step.done ? 0.08 : 0.025)).clipShape(RoundedRectangle(cornerRadius: 7))
        }
        }
    }
}
struct Notes: View {
    var title = "Observaciones"; @Binding var text: String
    var body: some View { VStack(alignment: .leading) { Text(title).font(.caption).foregroundStyle(.secondary); TextEditor(text: $text).frame(minHeight: 65).padding(5).background(.background).clipShape(RoundedRectangle(cornerRadius: 6)) } }
}
struct FoldableSection<Content: View>: View {
    var title: String
    @AppStorage private var expanded: Bool
    var content: Content
    init(_ key: String, _ title: String, initiallyExpanded: Bool = false, @ViewBuilder content: () -> Content) {
        self.title = title
        self._expanded = AppStorage(wrappedValue: initiallyExpanded, "PracticasFP.Section." + key)
        self.content = content()
    }
    var body: some View {
        Section {
            DisclosureGroup(title, isExpanded: $expanded) { content }
        }
    }
}
struct ScrollMemory: NSViewRepresentable {
    var read: () -> CGFloat
    var write: (CGFloat) -> Void
    func makeNSView(context: Context) -> Marker { Marker() }
    func updateNSView(_ view: Marker, context: Context) { view.read = read; view.write = write }
    final class Marker: NSView {
        var read: () -> CGFloat = { 0 }
        var write: (CGFloat) -> Void = { _ in }
        private weak var tracked: NSScrollView?
        private var restoring = true
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard window != nil else { return }
            DispatchQueue.main.async {
                guard let scroll = self.enclosingScrollView, self.tracked !== scroll else { return }
                self.tracked = scroll
                let clip = scroll.contentView
                clip.postsBoundsChangedNotifications = true
                let maxY = max(0, (scroll.documentView?.frame.height ?? 0) - clip.bounds.height)
                clip.scroll(to: NSPoint(x: 0, y: min(maxY, self.read())))
                scroll.reflectScrolledClipView(clip)
                self.restoring = false
                NotificationCenter.default.addObserver(self, selector: #selector(self.changed), name: NSView.boundsDidChangeNotification, object: clip)
            }
        }
        @objc private func changed() {
            guard !restoring, window != nil, let scroll = tracked else { return }
            write(max(0, scroll.contentView.bounds.origin.y))
        }
        deinit { NotificationCenter.default.removeObserver(self) }
    }
}
struct PanelDivider: View {
    @Binding var width: Double
    var maximum: Double
    @LocalState private var initial: Double?
    var body: some View {
        Rectangle().fill(Color.secondary.opacity(0.18)).frame(width: 6).contentShape(Rectangle())
            .gesture(DragGesture(coordinateSpace: .global).onChanged { value in
                if initial == nil { initial = width }
                width = min(maximum, max(340, (initial ?? width) + value.translation.width))
            }.onEnded { _ in initial = nil })
            .help("Arrastra para ajustar el ancho del panel")
            .accessibilityLabel("Ancho del panel")
            .accessibilityAdjustableAction { direction in
                width = min(maximum, max(340, width + (direction == .increment ? 20 : -20)))
            }
    }
}
struct RootView: View {
    @EnvironmentObject var store: Store
    @StateObject private var navigation = WorkspaceNavigation()
    @AppStorage("PracticasFP.Width.Alumnas") private var studentPanelWidth = 380.0
    @AppStorage("PracticasFP.Width.Empresas") private var companyPanelWidth = 380.0
    var page: String {
        get { navigation.page }
        nonmutating set { navigation.switchSection(newValue) }
    }
    var selected: UUID? {
        get { navigation.selected }
        nonmutating set { navigation.selected = newValue }
    }
    var search: String {
        get { navigation.search }
        nonmutating set { navigation.search = newValue }
    }
    @LocalState private var companyPanelFilter: CompanyPanelFilter = .all
    @LocalState<String> private var assignment = "Todas"
    @LocalState<UUID?> private var companyFilter: UUID?
    @LocalState<String> private var groupFilter = ""
    @LocalState<Bool> private var pendingOnly = false
    @LocalState<Bool> private var importing = false
    @LocalState private var restoring = false
    @LocalState private var workFilter: StudentWorkFilter = .all
    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 20) {
                Label("Prácticas FP", systemImage: "leaf.fill").font(.title2.bold()).foregroundStyle(accent).padding(.top, 15)
                Text(store.db.institute).font(.caption).foregroundStyle(.secondary)
                ForEach([("Alumnas","person.2"),("Empresas","building.2"),("Pendientes","checklist"),("Historial","archivebox"),("Tutores","person.crop.rectangle"),("Calendario","calendar"),("Ajustes y copias","gearshape")], id: \.0) { item in
                    Button { page = item.0; store.endEditingGroup() } label: {
                        Label(item.0, systemImage: item.1).frame(maxWidth: .infinity, alignment: .leading).padding(10)
                            .background(page == item.0 ? accent.opacity(0.14) : .clear).clipShape(RoundedRectangle(cornerRadius: 9))
                    }.buttonStyle(.plain)
                }
                Spacer()
                Label("Solo en este Mac", systemImage: "internaldrive").font(.caption).foregroundStyle(.secondary)
                Text(store.status).font(.caption2).foregroundStyle(.secondary)
                Text(AppIdentity.versionLabel).font(.caption2).foregroundStyle(.secondary)
                    .help("Versión de la copia de Prácticas FP que está abierta")
            }.padding(16).navigationSplitViewColumnWidth(220)
        } detail: {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(page).font(.largeTitle.bold())
                        Text("Seguimiento en empresa · \(store.db.course)").foregroundStyle(.secondary)
                    }
                    HStack {
                    Button { store.undo() } label: { Label("Deshacer", systemImage: "arrow.uturn.backward") }.disabled(!store.canUndo)
                    Button { store.redo() } label: { Label("Rehacer", systemImage: "arrow.uturn.forward") }.disabled(!store.canRedo)
                    if ["Alumnas", "Empresas"].contains(page) {
                        Menu("Informe…") {
                            Button("Guardar como texto…") { exportReport(currentReport) }
                            Button("Guardar como PDF…") { savePDFReport(currentReport) }
                            Button("Imprimir…") { printReport(currentReport) }
                        }
                    }
                    if page == "Alumnas" {
                        Button { importing = true } label: { Label("Importar CSV / Excel", systemImage: "square.and.arrow.down") }
                    }
                    if ["Alumnas","Empresas","Tutores"].contains(page) {
                        Button(action: add) { Label("Añadir", systemImage: "plus") }.buttonStyle(.borderedProminent)
                    }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(20)
                Divider()
                switch page {
                case "Alumnas", "Empresas": unifiedWorkspace
                case "Tutores": records
                case "Pendientes": PendingTasksView(openStudent: { open("Alumnas", $0) }, openCompany: { open("Empresas", $0) })
                case "Historial": CourseHistoryView()
                case "Calendario": CalendarView()
                default: settings
                }
            }.background(Color(nsColor: .windowBackgroundColor))
        }
        .sheet(isPresented: $importing) { ImportView().environmentObject(store) }
        .sheet(isPresented: $restoring) { BackupRestoreView().environmentObject(store) }
        .onReceive(NotificationCenter.default.publisher(for: NSControl.textDidEndEditingNotification)) { _ in store.endEditingGroup() }
        .onReceive(NotificationCenter.default.publisher(for: NSText.didEndEditingNotification)) { _ in store.endEditingGroup() }
        .tint(accent)
        .frame(minWidth: 1050, minHeight: 720)
        .alert("Aviso", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) { Button("Aceptar") { store.error = nil } } message: { Text(store.error ?? "") }
    }
    var currentReport: String { store.db.report(studentID: page == "Alumnas" && hasSelectedRecord ? selected : nil, companyID: page == "Empresas" && hasSelectedRecord ? selected : nil) }
    func open(_ section: String, _ id: UUID) {
        store.endEditingGroup()
        navigation.open(section, id: id)
    }
    func add() {
        if page == "Alumnas" { let x = Student(); store.db.students.append(x); selected = x.id }
        if page == "Empresas" { let x = Company(); store.db.companies.append(x); selected = x.id }
        if page == "Tutores" { let x = Tutor(); store.db.tutors.append(x); selected = x.id }
    }
    func company(_ id: UUID?) -> String { store.db.companies.first { $0.id == id }?.name ?? "Sin empresa" }
    func companies(_ student: Student) -> String {
        var ids: [UUID] = []
        if let initial = student.companyID { ids.append(initial) }
        for period in student.shifts.sorted(by: { $0.from < $1.from }) {
            if let id = period.companyID, ids.last != id { ids.append(id) }
        }
        return ids.isEmpty ? "Sin empresa" : ids.map { company($0) }.joined(separator: " → ")
    }
    func progress(_ student: Student) -> (done: Int, total: Int) {
        var done = [0,5,6].filter { student.paperwork[$0].done }.count + (student.tutorID == nil ? 0 : 1)
        var total = 4
        for kind in [DocumentKind.annexI, .annexII] { let flow = student.document(kind); done += flow.completedCount; total += flow.milestones.count }
        for period in student.shifts where period.companyID != nil {
            for kind in [DocumentKind.annexI, .annexII] { let flow = student.document(kind, periodID: period.id); done += flow.completedCount; total += flow.milestones.count }
            done += period.tutorID == nil ? 0 : 1; total += 3
            let paperwork = period.paperwork ?? steps(studentPaperworkTitles)
            done += [5,6].filter { paperwork[$0].done }.count
        }
        return (done, total)
    }
    var filtered: [Student] {
        store.db.students.filter { student in
            (search.isEmpty || student.name.localizedCaseInsensitiveContains(search)) &&
            (assignment == "Todas" || student.assignment == assignment) &&
            (companyFilter == nil || companyFilter.map { store.db.companyIDs(for: student).contains($0) } == true) &&
            (groupFilter.isEmpty || student.group.localizedCaseInsensitiveContains(groupFilter)) &&
            (!pendingOnly || progress(student).done < progress(student).total) && store.db.matches(student, workFilter: workFilter)
        }
    }
    var dashboard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130))], alignment: .leading, spacing: 10) {
                    metric("Alumnas", "\(store.db.students.count)", "person.2")
                    metric("Asignación definitiva", "\(store.db.students.filter { $0.assignment == "Definitiva" }.count)", "building.2")
                    metric("Práctica iniciada", "\(store.db.students.filter { $0.latestPracticePaperwork[5].done && !$0.latestPracticePaperwork[6].done }.count)", "clock")
                    metric("Terminadas", "\(store.db.students.filter { $0.latestPracticePaperwork[6].done }.count)", "checkmark.circle")
                }
                if !store.db.instituteDaysConfirmed {
                    Label("Pendiente: añadir los días de libre disposición del instituto. Las fechas de fin son provisionales.", systemImage: "calendar.badge.exclamationmark").font(.callout).foregroundStyle(.orange)
                }
                VStack(alignment: .leading) {
                    TextField("Buscar alumna", text: Binding(get: { search }, set: { search = $0 })).textFieldStyle(.roundedBorder)
                    Picker("Asignación", selection: $assignment) { ForEach(["Todas","Pendiente","Provisional","Definitiva"], id: \.self) { Text($0) } }.frame(width: 230)
                    Picker("Empresa", selection: $companyFilter) { Text("Todas").tag(nil as UUID?); ForEach(store.db.companies) { Text($0.name).tag(Optional($0.id)) } }.frame(width: 220)
                }
                Picker("Necesita atención", selection: $workFilter) {
                    ForEach(StudentWorkFilter.allCases) { filter in
                        Text("\(filter.rawValue) (\(store.db.students.filter { store.db.matches($0, workFilter: filter) }.count))").tag(filter)
                    }
                }
                VStack(alignment: .leading, spacing: 8) { TextField("Filtrar por grupo", text: $groupFilter).textFieldStyle(.roundedBorder).frame(width: 220); Toggle("Solo con trámites pendientes", isOn: $pendingOnly) }
                if store.db.students.isEmpty {
                    ContentUnavailableView { Label("Tu seguimiento empieza aquí", systemImage: "person.2.badge.plus") } description: { Text("Añade las empresas, sus tutores y tus alumnas. Cada ficha se guarda automáticamente.") } actions: { Button("Añadir primera alumna") { page = "Alumnas"; add() }.buttonStyle(.borderedProminent) }
                } else if filtered.isEmpty { Text("No hay alumnas que coincidan con los filtros.").foregroundStyle(.secondary) }
                LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(filtered) { s in
                    let c = calculate(s, store.db)
                    let documentProgress = progress(s)
                    Button { open("Alumnas", s.id) } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack { Text(s.name.isEmpty ? "Alumna sin nombre" : s.name).font(.headline); Spacer(); Text(s.assignment).font(.caption.bold()).padding(.horizontal, 6).padding(.vertical, 3).background(accent.opacity(0.1)).clipShape(Capsule()) }
                            Text("\(companies(s)) · \(s.group)").foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 10) {
                                VStack(alignment: .leading) { Text("Trámites · \(documentProgress.done)/\(documentProgress.total)"); ProgressView(value: Double(documentProgress.done), total: Double(documentProgress.total)) }
                                VStack(alignment: .leading) { Text("Horas previstas hasta ayer · \(c.elapsed, specifier: "%.1f")/\(s.requiredHours, specifier: "%.0f")"); ProgressView(value: c.elapsed, total: max(1, s.requiredHours)) }
                                VStack(alignment: .leading) { Text("Fin \(s.manualEnd ? "ajustado" : "previsto")").font(.caption).foregroundStyle(.secondary); Text(s.hasStart ? (c.end.map { dateText(s.manualEnd ? s.end : $0) } ?? "Revisar jornada") : "Sin fecha de inicio").bold() }.frame(width: 170, alignment: .leading)
                            }.font(.callout)
                            if s.assignment != "Definitiva" { Text("Preferencias: \(s.preferredType.isEmpty ? "tipo pendiente" : s.preferredType) · \(s.preferredZone.isEmpty ? "zona pendiente" : s.preferredZone)").font(.caption).foregroundStyle(.secondary) }
                        }.padding(12).background(.background).clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected == s.id ? accent : .clear, lineWidth: 2))
                    }.buttonStyle(.plain).id(s.id)
                }
                }.scrollTargetLayout()
            }.padding(14).background(ScrollMemory(read: { navigation.scrollOffsets["Alumnas"] ?? 0 }, write: { navigation.scrollOffsets["Alumnas"] = $0 }))
        }
    }
    func metric(_ title: String, _ value: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) { Label(title, systemImage: icon).font(.caption).foregroundStyle(.secondary); Text(value).font(.title.bold()) }.frame(maxWidth: .infinity, alignment: .leading).padding(14).background(.background).clipShape(RoundedRectangle(cornerRadius: 10))
    }
    var selectedTitle: String {
        if page == "Alumnas" { return store.db.students.first { $0.id == selected }?.name.nonEmpty ?? "Alumna sin nombre" }
        return store.db.companies.first { $0.id == selected }?.name.nonEmpty ?? "Empresa sin nombre"
    }
    var selectedSubtitle: String {
        if let student = store.db.students.first(where: { page == "Alumnas" && $0.id == selected }) { return companies(student) + " · " + student.assignment }
        if let company = store.db.companies.first(where: { $0.id == selected }) { return (company.response ?? .uncontacted).title + " · " + store.db.placesLabel(company) }
        return ""
    }
    var hasSelectedRecord: Bool {
        if page == "Alumnas" { return store.db.students.contains { $0.id == selected } }
        return store.db.companies.contains { $0.id == selected }
    }
    var unifiedWorkspace: some View {
        GeometryReader { geometry in
        let maximum = max(340, geometry.size.width - 456)
        let width = Binding<Double>(get: { page == "Alumnas" ? studentPanelWidth : companyPanelWidth }, set: { value in
            if page == "Alumnas" { studentPanelWidth = value } else { companyPanelWidth = value }
        })
        HStack(spacing: 0) {
            Group {
                if page == "Alumnas" { dashboard }
                else {
                    CompaniesDashboard(
                        openCompany: { open("Empresas", $0) },
                        openStudent: { open("Alumnas", $0) },
                        selectedCompany: selected,
                        search: navigation.searchBinding(for: "Empresas"),
                        filter: $companyPanelFilter,
                        navigation: navigation)
                }
            }.frame(width: hasSelectedRecord ? min(maximum, max(340, width.wrappedValue)) : nil)
                .frame(maxWidth: hasSelectedRecord ? nil : .infinity, maxHeight: .infinity)
            if hasSelectedRecord {
                PanelDivider(width: width, maximum: maximum)
                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(selectedTitle).font(.headline)
                            Text(selectedSubtitle).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { selected = nil } label: { Label("Cerrar ficha", systemImage: "xmark") }
                            .help("Cerrar la ficha y ampliar el panel")
                    }.padding(12)
                    Divider()
                    if page == "Alumnas", let i = store.db.students.firstIndex(where: { $0.id == selected }) {
                        StudentEditor(s: $store.db.students[i], openCompany: { open("Empresas", $0) }, openTutor: { open("Tutores", $0) }).id(selected)
                    } else if page == "Empresas", let i = store.db.companies.firstIndex(where: { $0.id == selected }) {
                        CompanyEditor(c: $store.db.companies[i], openStudent: { open("Alumnas", $0) }, openTutor: { open("Tutores", $0) }).id(selected)
                    }
                }.frame(minWidth: 450, idealWidth: 500, maxHeight: .infinity)
            }
        }
        }
    }
    var records: some View {
        HStack(spacing: 0) {
            VStack {
                TextField("Buscar", text: Binding(get: { search }, set: { search = $0 })).textFieldStyle(.roundedBorder).padding(12)
                List(selection: Binding(get: { selected }, set: { selected = $0 })) {
                    if page == "Alumnas" { ForEach(store.db.students.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }) { s in VStack(alignment: .leading) { Text(s.name.isEmpty ? "Alumna sin nombre" : s.name); Text(s.assignment).font(.caption).foregroundStyle(.secondary) }.tag(s.id) } }
                    if page == "Empresas" { ForEach(store.db.companies.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }) { s in Text(s.name.isEmpty ? "Empresa sin nombre" : s.name).tag(s.id) } }
                    if page == "Tutores" { ForEach(store.db.tutors.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }) { s in Text(s.name.isEmpty ? "Tutor sin nombre" : s.name).tag(s.id) } }
                }
            }.frame(width: 230)
            Divider()
            Group {
                if page == "Alumnas", let i = store.db.students.firstIndex(where: { $0.id == selected }) { StudentEditor(s: $store.db.students[i], openCompany: { open("Empresas", $0) }, openTutor: { open("Tutores", $0) }).id(selected) }
                else if page == "Empresas", let i = store.db.companies.firstIndex(where: { $0.id == selected }) { CompanyEditor(c: $store.db.companies[i], openStudent: { open("Alumnas", $0) }, openTutor: { open("Tutores", $0) }).id(selected) }
                else if page == "Tutores", let i = store.db.tutors.firstIndex(where: { $0.id == selected }) { TutorEditor(t: $store.db.tutors[i], openCompany: { open("Empresas", $0) }, openStudent: { open("Alumnas", $0) }).id(selected) }
                else { ContentUnavailableView("Selecciona una ficha", systemImage: "rectangle.and.pencil.and.ellipsis", description: Text("O pulsa Añadir para crear una nueva.")) }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    var settings: some View {
        Form {
            Section("Acerca de Prácticas FP") {
                LabeledContent("Versión", value: AppIdentity.version).textSelection(.enabled)
                LabeledContent("Compilación", value: AppIdentity.build).textSelection(.enabled)
            }
            Section("Tu centro") { TextField("Instituto", text: $store.db.institute); TextField("Curso de referencia", text: $store.db.course) }
            Section("Almacenamiento local") {
                Text("Los cambios se guardan automáticamente. Se crea una copia al abrir la aplicación si ya existen datos.")
                Text(store.folder.path).font(.caption).textSelection(.enabled)
                Button("Guardar copia de seguridad…") { store.manualBackup() }
                if let message = store.backupMessage { Label(message, systemImage: "checkmark.circle.fill").foregroundStyle(accent).textSelection(.enabled) }
                Button("Mostrar copias automáticas") { NSWorkspace.shared.open(store.backups) }
                Button("Restaurar una copia…") { restoring = true }
                Button("Mostrar carpeta de datos") { NSWorkspace.shared.open(store.folder) }
            }
            Section("Cómo empezar") { Text("1. Añade empresas y tutores.\n2. Crea las fichas de las alumnas y recoge sus preferencias.\n3. Asigna empresa y tutor, y marca los trámites.\n4. Indica inicio y jornada para calcular el final.\n5. Completa el calendario del instituto.") }
            Section("Privacidad") { Text("Sin cuentas, sincronización, analítica ni envío de información. Los documentos se registran mediante hitos y fechas; no se adjuntan archivos. Las copias contienen los mismos datos personales que las fichas y se guardan en este Mac.") }
        }.formStyle(.grouped)
    }
}
struct StudentEditor: View {
    @EnvironmentObject var store: Store
    @Binding var s: Student
    var openCompany: (UUID) -> Void
    var openTutor: (UUID) -> Void
    var result: Calculation { calculate(s, store.db) }
    var body: some View {
        Form {
            if !store.db.validationMessages(for: s).isEmpty {
                Section("Revisar datos") {
                    ForEach(store.db.validationMessages(for: s), id: \.self) { message in
                        Label(message, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                    }
                }
            }
            FoldableSection("student.data", "Datos de la alumna", initiallyExpanded: true) {
                TextField("Nombre y apellidos", text: $s.name); TextField("Grupo", text: $s.group)
                TextField("DNI / NIE", text: $s.dni); TextField("NUSS", text: $s.nuss)
                TextField("Email", text: $s.email); TextField("Teléfono", text: $s.phone)
            }
            FoldableSection("student.preferences", s.assignment == "Definitiva" ? "Preferencias conservadas · referencia ante quejas" : "Preferencias para la asignación") {
                TextField("Tipo de empresa", text: $s.preferredType); TextField("Zona de la ciudad", text: $s.preferredZone)
                Notes(title: "Detalle de preferencias", text: $s.preferences)
            }
            FoldableSection("student.schedule", "Horario y previsión", initiallyExpanded: false) {
                TextField("Horas objetivo", value: Binding(get: { s.requiredHours }, set: { s.targetHours = $0 }), format: .number)
                Text("Por defecto, 500 horas. Puedes ajustarlas para esta alumna.").font(.caption).foregroundStyle(.secondary)
                Toggle("Fecha de inicio establecida", isOn: $s.hasStart)
                if s.hasStart {
                    DatePicker("Inicio", selection: $s.start, displayedComponents: .date)
                    calculation
                }
            }
            FoldableSection("student.periods", "Periodos de práctica · empresas, jornadas y documentos", initiallyExpanded: true) {
                PracticePeriodsEditor(s: $s, openCompany: openCompany, openTutor: openTutor)
            }
            FoldableSection("student.notes", "Observaciones") { Notes(text: $s.notes) }
            Section { DeleteButton(title: "Eliminar alumna") { store.db.students.removeAll { $0.id == s.id } } }
        }.formStyle(.grouped)
    }
    @ViewBuilder var calculation: some View {
        if let error = result.error { Text(error).foregroundStyle(.red) }
        if let end = result.end {
            LabeledContent("Fin calculado", value: dateText(end))
            LabeledContent("Horas necesarias en la última jornada", value: String(format: "%.2f h", result.lastHours))
            LabeledContent("Horas previstas hasta ayer", value: String(format: "%.1f / %.1f", result.elapsed, s.requiredHours))
            Text("Previsión según horario y calendario; no es un registro de asistencia.").font(.caption).foregroundStyle(.secondary)
            if s.start < store.db.calendarFrom || end > store.db.calendarTo { Label("El cálculo sale del periodo de calendario revisado. Amplía y revisa el calendario.", systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
            if !store.db.instituteDaysConfirmed { Text("Fin provisional: faltan los días de libre disposición.").foregroundStyle(.orange) }
            Toggle("Ajustar fecha final manualmente", isOn: $s.manualEnd).onChange(of: s.manualEnd) { _, value in if value { s.end = end } }
            if s.manualEnd {
                DatePicker("Fin ajustado", selection: $s.end, in: s.start..., displayedComponents: .date)
                Text(String(format: "Hasta esa fecha, el horario suma %.1f h (%+.1f h respecto a %.1f).", result.scheduledToManual, result.scheduledToManual - s.requiredHours, s.requiredHours)).foregroundStyle(.orange)
                Text("Si se ha reducido la jornada, añade el cambio de horas para que el cálculo refleje la nueva situación.").font(.caption)
            }
        }
    }
}
struct CompanyEditor: View {
    @EnvironmentObject var store: Store
    @Binding var c: Company
    var openStudent: (UUID) -> Void
    var openTutor: (UUID) -> Void
    var body: some View {
        Form {
            FoldableSection("company.data", "Datos de la empresa", initiallyExpanded: true) { TextField("Nombre", text: $c.name); TextField("CIF", text: $c.cif); TextField("Dirección", text: $c.address); TextField("Persona de contacto", text: $c.contact); TextField("Teléfono", text: $c.phone); TextField("Email", text: $c.email) }
            FoldableSection("company.response", "Contacto y respuesta", initiallyExpanded: true) { CompanyResponseEditor(companyID: c.id) }
            FoldableSection("company.capacity", "Plazas ofrecidas", initiallyExpanded: true) {
                Text(store.db.placesLabel(c)).font(.headline)
                HStack {
                    TextField("Número de plazas", value: Binding(
                        get: { c.capacity ?? store.db.occupiedPlaces(c.id) },
                        set: { store.setCapacity($0, for: c.id) }
                    ), format: .number)
                    Stepper("Ajustar plazas", value: Binding(
                        get: { c.capacity ?? store.db.occupiedPlaces(c.id) },
                        set: { store.setCapacity($0, for: c.id) }
                    ), in: store.db.occupiedPlaces(c.id)...Int.max).labelsHidden()
                }
                if c.capacity == nil {
                    Text("Indica el cupo para permitir nuevas asignaciones. Las alumnas ya vinculadas se conservan.").foregroundStyle(.orange)
                    Button("Confirmar \(store.db.occupiedPlaces(c.id)) plazas") { store.setCapacity(store.db.occupiedPlaces(c.id), for: c.id) }
                }
                Text("El cupo incluye todas las alumnas vinculadas. No se puede reducir por debajo de la ocupación actual.").font(.caption).foregroundStyle(.secondary)
            }
            FoldableSection("company.paperwork", "Concierto de colaboración", initiallyExpanded: false) {
                DocumentTimeline(flow: Binding(get: { c.document }, set: { c.setDocument($0) }))
            }
            FoldableSection("company.followups", "Seguimiento mensual por empresa", initiallyExpanded: false) { CompanyFollowUps(companyID: c.id) }
            FoldableSection("company.tutors", "Tutores", initiallyExpanded: false) { ForEach(store.db.tutors.filter { $0.companyID == c.id }) { tutorLink($0) } }
            FoldableSection("company.students", "Alumnas vinculadas", initiallyExpanded: true) { ForEach(store.db.students.filter { store.db.companyIDs(for: $0).contains(c.id) }) { student in Button("\(student.name) · \(student.assignment)") { openStudent(student.id) } } }
            FoldableSection("company.notes", "Observaciones") { Notes(text: $c.notes) }
            Section {
                if store.db.students.contains(where: { store.db.companyIDs(for: $0).contains(c.id) }) || store.db.tutors.contains(where: { $0.companyID == c.id }) { Text("Para eliminar esta empresa, desvincula primero sus alumnas y tutores.").font(.caption) }
                else { DeleteButton(title: "Eliminar empresa") { store.db.companies.removeAll { $0.id == c.id } } }
            }
        }.formStyle(.grouped)
    }
    private func tutorLink(_ tutor: Tutor) -> some View {
        VStack(alignment: .leading) {
            Button(tutor.name.isEmpty ? "Tutor sin nombre" : tutor.name) { openTutor(tutor.id) }
            Text("\(tutor.phone) · \(tutor.email)").foregroundStyle(.secondary).textSelection(.enabled)
        }
    }
}
struct TutorEditor: View {
    @EnvironmentObject var store: Store
    @Binding var t: Tutor
    var openCompany: (UUID) -> Void
    var openStudent: (UUID) -> Void
    var body: some View {
        Form {
            Section("Tutor de empresa") {
                TextField("Nombre y apellidos", text: $t.name)
                Picker("Empresa", selection: $t.companyID) { Text("Sin asignar").tag(nil as UUID?); ForEach(store.db.companies) { Text($0.name).tag(Optional($0.id)) } }
                    .disabled(store.db.students.contains { $0.tutorID == t.id || $0.shifts.contains(where: { $0.tutorID == t.id }) })
                if let id = t.companyID { Button("Abrir ficha de empresa") { openCompany(id) } }
                TextField("Teléfono", text: $t.phone); TextField("Email", text: $t.email)
            }
            Section("Alumnas tutorizadas") { ForEach(store.db.students.filter { $0.tutorID == t.id || $0.shifts.contains(where: { $0.tutorID == t.id }) }) { student in Button(student.name) { openStudent(student.id) } } }
            Section { Notes(text: $t.notes) }
            Section {
                if store.db.students.contains(where: { $0.tutorID == t.id || $0.shifts.contains(where: { $0.tutorID == t.id }) }) { Text("Desvincula sus alumnas antes de cambiar su empresa o eliminarlo.").font(.caption) }
                else { DeleteButton(title: "Eliminar tutor") { store.db.tutors.removeAll { $0.id == t.id } } }
            }
        }.formStyle(.grouped)
    }
}
struct DeleteButton: View {
    var title: String; var action: () -> Void
    @LocalState<Bool> private var confirm = false
    var body: some View {
        Button(title, role: .destructive) { confirm = true }
            .confirmationDialog("¿\(title)?", isPresented: $confirm) { Button(title, role: .destructive, action: action); Button("Cancelar", role: .cancel) {} } message: { Text("Se eliminará la ficha y su información.") }
    }
}
struct CalendarView: View {
    @EnvironmentObject var store: Store
    var body: some View {
        Form {
            Section("Calendario compartido · Las Palmas de Gran Canaria") {
                Text("Sábados y domingos excluidos automáticamente. Los intervalos incluyen las fechas de inicio y final. Las exclusiones coincidentes se cuentan una sola vez.")
                DatePicker("Periodo revisado desde", selection: $store.db.calendarFrom, displayedComponents: .date)
                DatePicker("Hasta", selection: $store.db.calendarTo, displayedComponents: .date)
                Toggle("Días de libre disposición del instituto ya incorporados", isOn: $store.db.instituteDaysConfirmed)
                Text("Para otro año, incorpora sus festivos y vacaciones y actualiza el periodo revisado. No se repiten automáticamente las fechas.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Días e intervalos excluidos") {
                ForEach($store.db.exclusions) { $e in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { TextField("Motivo", text: $e.title); Picker("Tipo", selection: $e.kind) { ForEach(["Festivo","Vacaciones","Libre disposición"], id: \.self) { Text($0) } }.frame(width: 230) }
                        HStack {
                            DatePicker("Desde", selection: $e.from, displayedComponents: .date)
                            DatePicker("Hasta", selection: $e.to, displayedComponents: .date)
                            Button(role: .destructive) { store.db.exclusions.removeAll { $0.id == e.id } } label: { Image(systemName: "trash") }.buttonStyle(.borderless)
                        }
                        if cal.startOfDay(for: e.to) < cal.startOfDay(for: e.from) { Text("La fecha final debe ser igual o posterior al inicio.").foregroundStyle(.red) }
                    }.padding(.vertical, 4)
                }
                Button("Añadir día o intervalo") { store.db.exclusions.append(Exclusion(title: "Día del instituto")) }
            }
        }.formStyle(.grouped)
    }
}
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
@main struct PracticasApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = Store()
    var body: some Scene {
        WindowGroup("Prácticas FP") { RootView().environmentObject(store).environment(\.locale, Locale(identifier: "es_ES")) }
            .defaultSize(width: 1250, height: 850)
            .commands { CommandGroup(replacing: .newItem) {} }
    }
}
