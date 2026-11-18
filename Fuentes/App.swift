// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Juan Luis (JLPalmes)
import SwiftUI
#if ACTUALIZACIONES
import Sparkle
#endif
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
                if step.done && step.title != studentPaperworkTitles[0] {
                    DatePicker("Fecha de cumplimiento", selection: Binding(
                        get: { items.first(where: { $0.id == step.id })?.date ?? step.date },
                        set: { date in
                            guard let i = items.firstIndex(where: { $0.id == step.id }) else { return }
                            var updated = items; updated[i].date = date; items = updated
                        }), displayedComponents: .date).labelsHidden().frame(width: 135)
                }
            }.padding(8).frame(maxWidth: .infinity, alignment: .leading).background(accent.opacity(step.done ? 0.08 : 0.025)).clipShape(RoundedRectangle(cornerRadius: 7))
        }
        }
    }
}
struct WideTextField: View {
    let title: String
    @Binding var text: String
    var wraps = false

    init(_ title: String, text: Binding<String>, wraps: Bool = false) {
        self.title = title
        _text = text
        self.wraps = wraps
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary).fixedSize().accessibilityHidden(true)
            if wraps {
                TextField(title, text: Binding(
                    get: { text },
                    set: { text = $0.replacingOccurrences(of: "[\\r\\n]+", with: "", options: .regularExpression) }
                ), axis: .vertical).lineLimit(1...)
            } else {
                TextField(title, text: $text)
            }
        }
        .labelsHidden()
        .multilineTextAlignment(.leading)
        .textFieldStyle(.roundedBorder)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CompactFields<First: View, Second: View>: View {
    let firstWidth: CGFloat?
    let secondWidth: CGFloat?
    let first: First
    let second: Second

    init(firstWidth: CGFloat? = nil, secondWidth: CGFloat? = nil,
         @ViewBuilder first: () -> First, @ViewBuilder second: () -> Second) {
        self.firstWidth = firstWidth
        self.secondWidth = secondWidth
        self.first = first()
        self.second = second()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            first.frame(width: firstWidth)
            second.frame(width: secondWidth)
        }
    }
}

struct ContactFields: View {
    @Binding var phone: String
    @Binding var email: String

    var body: some View {
        CompactFields(firstWidth: 172) {
            WideTextField("Teléfono", text: $phone)
        } second: {
            WideTextField("Correo", text: $email, wraps: true)
        }
    }
}
struct Notes: View {
    var title = "Observaciones"; @Binding var text: String
    var body: some View { VStack(alignment: .leading) { Text(title).font(.caption).foregroundStyle(.secondary); TextEditor(text: $text).frame(minHeight: 65).padding(5).background(.background).clipShape(RoundedRectangle(cornerRadius: 6)) } }
}
struct WideDisclosureStyle: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                configuration.isExpanded.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: configuration.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold))
                        .frame(width: 24, height: 24)
                        .accessibilityHidden(true)
                    configuration.label
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(configuration.isExpanded ? "Desplegada" : "Plegada")
            .accessibilityHint("Pulsa para abrir o cerrar la sección")
            if configuration.isExpanded {
                configuration.content
            }
        }
    }
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
                width = min(maximum, max(300, (initial ?? width) + value.translation.width))
            }.onEnded { _ in initial = nil })
            .help("Arrastra para ajustar el ancho del panel")
            .accessibilityLabel("Ancho del panel")
            .accessibilityAdjustableAction { direction in
                width = min(maximum, max(300, width + (direction == .increment ? 20 : -20)))
            }
    }
}
struct RootView: View {
    @EnvironmentObject var store: Store
    @StateObject private var navigation = WorkspaceNavigation()
    @AppStorage("PracticasFP.Width.Alumnas") private var studentPanelWidth = 380.0
    @AppStorage("PracticasFP.Width.Empresas") private var companyPanelWidth = 380.0
    @AppStorage("PracticasFP.Width.Tutores") private var tutorPanelWidth = 300.0
    var page: String {
        get { navigation.page }
        nonmutating set { navigation.switchSection(newValue) }
    }
    var selected: UUID? {
        get {
            guard ["Alumnas", "Empresas", "Tutores"].contains(page) else { return navigation.selected }
            return recordIDs.contains(where: { $0 == navigation.selected }) ? navigation.selected : recordIDs.first
        }
        nonmutating set { navigation.selected = newValue }
    }
    var recordIDs: [UUID] {
        page == "Alumnas" ? store.db.students.map(\.id) : page == "Empresas" ? store.db.companies.map(\.id) : store.db.tutors.map(\.id)
    }
    func ensureWorkspaceSelection() {
        if ["Alumnas", "Empresas", "Tutores"].contains(page) { navigation.ensureSelection(in: recordIDs) }
    }
    var search: String {
        get { navigation.search }
        nonmutating set { navigation.search = newValue }
    }
    @LocalState<Bool> private var importing = false
    @LocalState private var restoring = false
    @LocalState private var reviewingFormat5 = false
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ForEach(["Alumnas", "Empresas", "Tutores", "Calendario"], id: \.self) { section in
                    Button {
                        page = section
                        store.endEditingGroup()
                    } label: {
                        Text(section).padding(.horizontal, 10).padding(.vertical, 7)
                            .background(page == section ? accent.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 7))
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain)
                        .accessibilityAddTraits(page == section ? .isSelected : [])
                }
                Spacer()
                Menu("Informes") {
                    if ["Alumnas", "Empresas"].contains(page) {
                        Menu("Ficha seleccionada") { reportActions(currentReport) }
                    }
                    Menu("Curso completo") { reportActions(store.db.report()) }
                }
                Button("Datos y copias") { page = "Ajustes y copias"; store.endEditingGroup() }
                    .accessibilityAddTraits(page == "Ajustes y copias" ? .isSelected : [])
                Text(AppIdentity.versionLabel).font(.caption).foregroundStyle(.secondary)
            }.padding(10)
            Divider()
            switch page {
            case "Alumnas", "Empresas", "Tutores": unifiedWorkspace
            case "Calendario": CalendarView()
            default: settings
            }
        }.background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $importing) { ImportView().environmentObject(store) }
        .sheet(isPresented: $reviewingFormat5) { Format5ReviewView() }
        .sheet(isPresented: $restoring) { BackupRestoreView().environmentObject(store) }
        .onAppear { ensureWorkspaceSelection() }
        .onChange(of: page) { _, _ in ensureWorkspaceSelection() }
        .onChange(of: store.db.students.map(\.id)) { _, _ in ensureWorkspaceSelection() }
        .onChange(of: store.db.companies.map(\.id)) { _, _ in ensureWorkspaceSelection() }
        .onChange(of: store.db.tutors.map(\.id)) { _, _ in ensureWorkspaceSelection() }
        .onReceive(NotificationCenter.default.publisher(for: NSControl.textDidEndEditingNotification)) { _ in store.endEditingGroup() }
        .onReceive(NotificationCenter.default.publisher(for: NSText.didEndEditingNotification)) { _ in store.endEditingGroup() }
        .tint(accent)
        .toggleStyle(.checkbox)
        .disclosureGroupStyle(WideDisclosureStyle())
        .frame(minWidth: 900, minHeight: 620)
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
    @ViewBuilder private func reportActions(_ report: @autoclosure @escaping () -> String) -> some View {
        Button("Guardar como texto…") { exportReport(report()) }
        Button("Guardar como PDF…") { savePDFReport(report()) }
        Button("Imprimir…") { printReport(report()) }
    }

    var dashboard: some View {
        let students = store.db.students.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }
        return ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Buscar alumna", text: Binding(get: { search }, set: { search = $0 })).textFieldStyle(.roundedBorder)
                Button("Importar alumnas…") { importing = true }
                if students.isEmpty && !search.isEmpty {
                    Text("No hay alumnas que coincidan.").foregroundStyle(.secondary)
                }
                ForEach(students) { student in
                    Button { open("Alumnas", student.id) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(student.name.nonEmpty ?? "Alumna sin nombre").font(.headline)
                            Text(companies(student)).font(.callout).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(selected == student.id ? accent.opacity(0.15) : Color(nsColor: .controlBackgroundColor),
                                    in: RoundedRectangle(cornerRadius: 7))
                        .contentShape(Rectangle())
                    }.buttonStyle(.plain)
                        .accessibilityAddTraits(selected == student.id ? .isSelected : [])
                }
            }.padding(10).background(ScrollMemory(read: { navigation.scrollOffsets["Alumnas"] ?? 0 }, write: { navigation.scrollOffsets["Alumnas"] = $0 }))
        }
    }
    var selectedTitle: String {
        if page == "Alumnas" { return store.db.students.first { $0.id == selected }?.name.nonEmpty ?? "Alumna sin nombre" }
        if page == "Tutores" { return store.db.tutors.first { $0.id == selected }?.name.nonEmpty ?? "Tutor sin nombre" }
        return store.db.companies.first { $0.id == selected }?.name.nonEmpty ?? "Empresa sin nombre"
    }
    var selectedSubtitle: String {
        if let student = store.db.students.first(where: { page == "Alumnas" && $0.id == selected }) { return companies(student) }
        if let company = store.db.companies.first(where: { $0.id == selected }) { return (company.response ?? .uncontacted).title + " · " + store.db.placesLabel(company) }
        if page == "Tutores", let tutor = store.db.tutors.first(where: { $0.id == selected }) {
            return company(tutor.companyID) + " · \(store.db.students(tutoredBy: tutor.id).count) alumnas"
        }
        return ""
    }
    var hasSelectedRecord: Bool {
        if page == "Alumnas" { return store.db.students.contains { $0.id == selected } }
        if page == "Tutores" { return store.db.tutors.contains { $0.id == selected } }
        return store.db.companies.contains { $0.id == selected }
    }
    var unifiedWorkspace: some View {
        GeometryReader { geometry in
        let maximum = max(300, geometry.size.width - 366)
        let width = Binding<Double>(get: { page == "Alumnas" ? studentPanelWidth : page == "Empresas" ? companyPanelWidth : tutorPanelWidth }, set: { value in
            if page == "Alumnas" { studentPanelWidth = value } else if page == "Empresas" { companyPanelWidth = value } else { tutorPanelWidth = value }
        })
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(page).font(.headline)
                    HStack(spacing: 6) {
                        Button("Añadir", action: add).buttonStyle(.borderedProminent)
                        Button("Deshacer") { store.undo() }.disabled(!store.canUndo)
                        Button("Rehacer") { store.redo() }.disabled(!store.canRedo)
                    }
                }.padding(10)
                if page == "Alumnas" { dashboard }
                else if page == "Tutores" { tutorsList }
                else {
                    CompaniesDashboard(
                        openCompany: { open("Empresas", $0) },
                        selectedCompany: selected,
                        search: navigation.searchBinding(for: "Empresas"),
                        navigation: navigation)
                }
            }.frame(width: min(maximum, max(300, width.wrappedValue)))
                .frame(maxHeight: .infinity)
                PanelDivider(width: width, maximum: maximum)
                VStack(spacing: 0) {
                    if hasSelectedRecord {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(selectedTitle).font(.headline)
                            Text(selectedSubtitle).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }.padding(8)
                    Divider()
                    if page == "Alumnas", let student = store.db.students.first(where: { $0.id == selected }) {
                        StudentEditor(s: Binding(get: { store.db.students.first(where: { $0.id == student.id }) ?? student }, set: { value in
                            if let i = store.db.students.firstIndex(where: { $0.id == student.id }) { store.db.students[i] = value }
                        }), openCompany: { open("Empresas", $0) }, openTutor: { open("Tutores", $0) }).id(selected)
                    } else if page == "Empresas", let company = store.db.companies.first(where: { $0.id == selected }) {
                        CompanyEditor(c: Binding(get: { store.db.companies.first(where: { $0.id == company.id }) ?? company }, set: { value in
                            if let i = store.db.companies.firstIndex(where: { $0.id == company.id }) { store.db.companies[i] = value }
                        }), openStudent: { open("Alumnas", $0) }, openTutor: { open("Tutores", $0) }).id(selected)
                    } else if page == "Tutores", let tutor = store.db.tutors.first(where: { $0.id == selected }) {
                        TutorEditor(t: Binding(get: { store.db.tutors.first(where: { $0.id == tutor.id }) ?? tutor }, set: { value in
                            if let i = store.db.tutors.firstIndex(where: { $0.id == tutor.id }) { store.db.tutors[i] = value }
                        }), openCompany: { open("Empresas", $0) }, openStudent: { open("Alumnas", $0) }).id(selected)
                    }
                    } else {
                        ContentUnavailableView {
                            Label(page == "Alumnas" ? "Añade una alumna" : page == "Empresas" ? "Añade una empresa" : "Añade un tutor", systemImage: page == "Empresas" ? "building.2" : "person.badge.plus")
                        } description: {
                            Text("La ficha aparecerá aquí, junto al listado.")
                        } actions: {
                            Button(action: add) { Label(page == "Alumnas" ? "Añadir alumna" : page == "Empresas" ? "Añadir empresa" : "Añadir tutor", systemImage: "plus") }.buttonStyle(.borderedProminent)
                        }
                    }
                }.frame(minWidth: 360, idealWidth: 420, maxHeight: .infinity)
        }
        }
    }
    var tutorsList: some View {
        VStack(spacing: 0) {
            TextField("Buscar tutor, empresa o alumna", text: Binding(get: { search }, set: { search = $0 }))
                .textFieldStyle(.roundedBorder).padding(10)
            List(selection: Binding(get: { selected }, set: { selected = $0 })) {
                ForEach(store.db.tutors.filter { tutor in
                    search.isEmpty || tutor.name.localizedCaseInsensitiveContains(search) || company(tutor.companyID).localizedCaseInsensitiveContains(search) || store.db.students(tutoredBy: tutor.id).contains { $0.name.localizedCaseInsensitiveContains(search) }
                }) { tutor in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tutor.name.nonEmpty ?? "Tutor sin nombre").font(.headline)
                        Text(company(tutor.companyID)).foregroundStyle(.secondary)
                        let students = store.db.students(tutoredBy: tutor.id)
                        if students.isEmpty {
                            Text("Sin alumnas asignadas").font(.caption).foregroundStyle(.secondary)
                        } else {
                            ForEach(students) { student in
                                Text(student.name.nonEmpty ?? "Alumna sin nombre").font(.caption)
                            }
                        }
                    }.padding(.vertical, 4).tag(tutor.id)
                }
            }.listStyle(.plain)
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
                Button("Consultar copia de la serie 2…") { reviewingFormat5 = true }
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
    @LocalState private var tab = "personal"
    var body: some View {
        let periods = store.db.practicePeriods(for: s)
        let tabs = [("personal", "Datos personales"), ("preferences", "Preferencias"), ("hours", "Horas")]
            + periods.enumerated().map { ($0.element.id.uuidString, periodTabTitle($0.offset)) }
        VStack(spacing: 0) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { tabButtons(tabs) }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), alignment: .leading)], alignment: .leading) {
                    tabButtons(tabs)
                }
            }.padding(.horizontal, 12).padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            Divider()
            switch tab {
            case "preferences":
                Form {
                    Section("Preferencias para la asignación") {
                        TextField("Tipo de empresa", text: $s.preferredType)
                        TextField("Zona de la ciudad", text: $s.preferredZone)
                        Notes(title: "Detalle de preferencias", text: $s.preferences)
                        Notes(text: $s.notes)
                    }
                }.formStyle(.grouped)
            case "hours":
                Form {
                    Section("Registro global de horas") {
                        TextField("Objetivo general", value: Binding(get: { s.requiredHours }, set: { s.targetHours = $0 }), format: .number)
                        TextField("Cumplidas el curso anterior", value: courseHours(\.previousCourseHours), format: .number)
                        TextField("Para el curso siguiente", value: courseHours(\.nextCourseHours), format: .number)
                        LabeledContent("Previstas hasta ayer", value: formattedHours(result.elapsed))
                        LabeledContent("Restantes del objetivo", value: formattedHours(s.remainingHours(after: result.elapsed)))
                    }
                    if s.hasStart {
                        Section("Horario y previsión") { calculation }
                    }
                }.formStyle(.grouped)
            default:
                if let period = periods.first(where: { $0.id.uuidString == tab }) {
                    Form {
                        PracticePeriodsEditor(s: $s, openCompany: openCompany, openTutor: openTutor, displayedPeriodID: period.id)
                    }.formStyle(.grouped).id(period.id)
                } else {
                    personal
                }
            }
        }
        .onChange(of: periods.map(\.id)) { _, ids in
            if let selected = UUID(uuidString: tab), !ids.contains(selected) { tab = ids.first?.uuidString ?? "personal" }
        }
        .onChange(of: s.hasStart) { _, _ in confirmAssignments() }
        .onChange(of: s.start) { _, _ in confirmAssignments() }
        .onChange(of: s.shifts.map(\.from)) { _, _ in confirmAssignments() }
        .onChange(of: tab) { _, _ in store.endEditingGroup() }
    }

    private func confirmAssignments() {
        var updated = s
        updated.confirmStartedAndPreviousPeriods()
        if updated != s { s = updated }
    }

    private func courseHours(_ key: WritableKeyPath<Student, Double?>) -> Binding<Double> {
        Binding(get: { s[keyPath: key] ?? 0 }, set: { value in
            if value.isFinite && value >= 0 { s[keyPath: key] = value }
        })
    }

    private func formattedHours(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2))) + " h"
    }

    private func tabButtons(_ tabs: [(String, String)]) -> some View {
        ForEach(tabs, id: \.0) { id, title in
            Button { tab = id } label: {
                Text(title).font(.callout)
                    .padding(.horizontal, 5).padding(.vertical, 7)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(tab == id ? accent : .clear).frame(height: 2)
                    }
                    .contentShape(Rectangle())
            }.buttonStyle(.plain)
                .accessibilityAddTraits(tab == id ? .isSelected : [])
        }
    }

    private func periodTabTitle(_ index: Int) -> String {
        switch index {
        case 0: "Primer periodo"
        case 1: "Segundo periodo"
        default: "Periodo \(index + 1)"
        }
    }

    private var personal: some View {
        Form {
            let messages = store.db.validationMessages(for: s)
            if !messages.isEmpty {
                Section("Revisar datos") {
                    ForEach(messages, id: \.self) { message in
                        Label(message, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                    }
                }
            }
            Section("Datos de la alumna") {
                CompactFields {
                    WideTextField("Nombre y apellidos", text: $s.name, wraps: true)
                } second: {
                    WideTextField("Grupo", text: $s.group, wraps: true)
                }
                CompactFields {
                    WideTextField("DNI / NIE", text: $s.dni)
                } second: {
                    WideTextField("NUSS", text: $s.nuss)
                }
                ContactFields(phone: $s.phone, email: $s.email)
            }
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
            FoldableSection("company.data", "Datos de la empresa", initiallyExpanded: true) {
                CompactFields(secondWidth: 132) {
                    WideTextField("Empresa", text: $c.name, wraps: true)
                } second: {
                    WideTextField("CIF", text: $c.cif)
                }
                WideTextField("Dirección", text: $c.address, wraps: true)
                WideTextField("Persona de contacto", text: $c.contact, wraps: true)
                ContactFields(phone: $c.phone, email: $c.email)
            }
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
            FoldableSection("company.tutors", "Tutores", initiallyExpanded: false) {
                LinkRows {
                    ForEach(store.db.tutors.filter { $0.companyID == c.id }) { tutor in
                        Button(tutor.name.nonEmpty ?? "Tutor sin nombre") { openTutor(tutor.id) }
                    }
                }
            }
            FoldableSection("company.students", "Alumnas vinculadas", initiallyExpanded: true) {
                LinkRows {
                    ForEach(store.db.students.filter { store.db.companyIDs(for: $0).contains(c.id) }) { student in
                        let statuses = store.db.practicePeriods(for: student).filter { $0.companyID == c.id }
                            .map { student.periodAssignment($0.shiftID) }.joined(separator: " · ")
                        Button(student.name + " · " + statuses) { openStudent(student.id) }
                    }
                }
            }
            FoldableSection("company.notes", "Observaciones") { Notes(text: $c.notes) }
            Section {
                if store.db.students.contains(where: { store.db.companyIDs(for: $0).contains(c.id) }) || store.db.tutors.contains(where: { $0.companyID == c.id }) { Text("Para eliminar esta empresa, desvincula primero sus alumnas y tutores.").font(.caption) }
                else { DeleteButton(title: "Eliminar empresa") { store.db.companies.removeAll { $0.id == c.id } } }
            }
        }.formStyle(.grouped).contentMargins(.horizontal, 8, for: .scrollContent).contentMargins(.vertical, 8, for: .scrollContent)
    }
}
struct LinkRows: Layout {
    private let gap: CGFloat = 8

    private func arrange(width: CGFloat, subviews: Subviews) -> (frames: [CGRect], size: CGSize) {
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var usedWidth: CGFloat = 0
        for view in subviews {
            let ideal = view.sizeThatFits(.unspecified)
            let itemWidth = min(ideal.width, width)
            let size = view.sizeThatFits(ProposedViewSize(width: itemWidth, height: nil))
            if x > 0 && x + itemWidth > width {
                x = 0
                y += rowHeight + gap
                rowHeight = 0
            }
            frames.append(CGRect(x: x, y: y, width: itemWidth, height: size.height))
            usedWidth = max(usedWidth, x + itemWidth)
            x += itemWidth + gap
            rowHeight = max(rowHeight, size.height)
        }
        return (frames, CGSize(width: usedWidth, height: y + rowHeight))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let row = arrange(width: proposal.width ?? bounds.width, subviews: subviews)
        for (view, frame) in zip(subviews, row.frames) {
            view.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                       anchor: .topLeading, proposal: ProposedViewSize(frame.size))
        }
    }
}

struct RecordLink: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.up.right.square")
        }
        .help(title)
        .accessibilityLabel(title)
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
                CompactFields {
                    WideTextField("Nombre y apellidos", text: $t.name, wraps: true)
                } second: {
                    if store.db.students(tutoredBy: t.id).isEmpty {
                        HStack(spacing: 8) {
                            Picker("Empresa", selection: $t.companyID) {
                                Text("Sin asignar").tag(nil as UUID?)
                                ForEach(store.db.companies) { Text($0.name).tag(Optional($0.id)) }
                            }
                            if let id = t.companyID {
                                RecordLink(title: "Abrir ficha de empresa") { openCompany(id) }
                            }
                        }
                    } else if let company = store.db.companies.first(where: { $0.id == t.companyID }) {
                        HStack(spacing: 6) {
                            Text("Empresa").font(.caption).foregroundStyle(.secondary)
                            Button(company.name.nonEmpty ?? "Empresa sin nombre") { openCompany(company.id) }
                                .help("Abrir ficha de empresa")
                        }
                    } else {
                        Text("Sin empresa").foregroundStyle(.secondary)
                    }
                }
                ContactFields(phone: $t.phone, email: $t.email)
            }
            Section("Alumnas tutorizadas") {
                LinkRows {
                    ForEach(store.db.students(tutoredBy: t.id)) { student in
                        Button(student.name.nonEmpty ?? "Alumna sin nombre") { openStudent(student.id) }
                    }
                }
            }
            Section { Notes(text: $t.notes) }
            Section {
                if store.db.students.contains(where: { $0.tutorID == t.id || $0.shifts.contains(where: { $0.tutorID == t.id }) }) { Text("Desvincula sus alumnas antes de cambiar su empresa o eliminarlo.").font(.caption) }
                else { DeleteButton(title: "Eliminar tutor") { store.db.tutors.removeAll { $0.id == t.id } } }
            }
        }.formStyle(.grouped).contentMargins(.horizontal, 8, for: .scrollContent).contentMargins(.vertical, 8, for: .scrollContent)
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
    @LocalState private var month = Date()
    @LocalState private var selectedDay: Date?
    @LocalState private var selectedExclusion: UUID?
    @LocalState private var addingExclusion = false

    private var grid: CourseMonth { CourseMonth(containing: month) }
    private var exclusions: [Exclusion] { store.db.exclusions.sorted { $0.from < $1.from } }

    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Días excluidos").font(.headline)
                Button("Añadir día o intervalo") { addingExclusion = true }.buttonStyle(.borderedProminent)
                List(selection: $selectedExclusion) {
                    ForEach(exclusions) { item in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.title.nonEmpty ?? item.kind)
                            Text(dateText(item.from) + " – " + dateText(item.to))
                                .font(.caption).foregroundStyle(.secondary)
                        }.tag(item.id)
                    }
                }.listStyle(.plain)
            }.padding(10).frame(minWidth: 220, idealWidth: 270, maxWidth: 320)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Calendario del curso").font(.title2.bold())
                    monthView
                    settings
                    if let id = selectedExclusion, let item = exclusions.first(where: { $0.id == id }) {
                        editor(for: item)
                    }
                }.padding(16).frame(maxWidth: 800)
            }.frame(minWidth: 440)
        }
        .sheet(isPresented: $addingExclusion) {
            NewExclusionView { item in
                store.db.exclusions.append(item)
                month = item.from
                selectedDay = item.from
                selectedExclusion = item.id
            }
        }
        .onAppear {
            let today = Date()
            month = min(max(today, store.db.calendarFrom), max(store.db.calendarFrom, store.db.calendarTo))
        }
        .onChange(of: selectedExclusion) { _, id in
            guard let item = exclusions.first(where: { $0.id == id }) else { return }
            if let selectedDay, CourseMonth.includes(selectedDay, in: item) { return }
            month = item.from
            selectedDay = item.from
        }
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.timeZone = cal.timeZone
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter.string(from: grid.start)
    }

    private var monthView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                monthButton("Mes anterior", icon: "chevron.left", offset: -1)
                Spacer()
                Text(monthTitle)
                    .font(.headline)
                Spacer()
                monthButton("Mes siguiente", icon: "chevron.right", offset: 1)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 7), spacing: 5) {
                ForEach(["Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom"], id: \.self) {
                    Text($0).font(.caption).foregroundStyle(.secondary)
                }
                ForEach(0..<grid.leadingBlanks, id: \.self) { _ in Color.clear.frame(height: 34) }
                ForEach(grid.days, id: \.self, content: dayCell)
            }
            HStack(spacing: 16) {
                Label("Día excluido", systemImage: "square.fill").foregroundStyle(.orange)
                Label("Fin de semana", systemImage: "square.fill").foregroundStyle(.secondary)
            }.font(.caption)
            if let selectedDay {
                Text(dateText(selectedDay)).font(.headline)
                let items = exclusions.filter { CourseMonth.includes(selectedDay, in: $0) }
                if items.isEmpty {
                    Text(CourseMonth.isWeekend(selectedDay) ? "Fin de semana" : "Día lectivo")
                        .foregroundStyle(.secondary)
                }
                ForEach(items) { item in
                    Button(item.title.nonEmpty ?? item.kind) { selectedExclusion = item.id }
                }
            }
        }.padding(12).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }

    private func monthButton(_ label: String, icon: String, offset: Int) -> some View {
        Button {
            if let next = cal.date(byAdding: .month, value: offset, to: grid.start) { month = next }
            selectedDay = nil
            selectedExclusion = nil
        } label: { Image(systemName: icon).frame(width: 24, height: 24) }
            .accessibilityLabel(label)
    }

    private func dayCell(_ date: Date) -> some View {
        let excluded = exclusions.contains { CourseMonth.includes(date, in: $0) }
        let weekend = CourseMonth.isWeekend(date)
        let selected = selectedDay.map { cal.isDate($0, inSameDayAs: date) } ?? false
        let fill = excluded ? Color.orange.opacity(0.28) : weekend ? Color.gray.opacity(0.19) : Color.gray.opacity(0.06)
        return Button {
            selectedDay = date
            selectedExclusion = nil
        } label: {
            Text(String(cal.component(.day, from: date)))
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(fill, in: RoundedRectangle(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(selected ? accent : .clear, lineWidth: 2))
                .contentShape(Rectangle())
        }.buttonStyle(.plain)
            .accessibilityLabel(dateText(date) + (excluded ? ", excluido" : weekend ? ", fin de semana" : ""))
            .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 8) {
            DatePicker("Periodo revisado desde", selection: $store.db.calendarFrom, displayedComponents: .date)
            DatePicker("Hasta", selection: $store.db.calendarTo, displayedComponents: .date)
            Toggle("Días de libre disposición del instituto confirmados", isOn: $store.db.instituteDaysConfirmed)
        }
    }

    private func editor(for item: Exclusion) -> some View {
        let entry = Binding(get: { store.db.exclusions.first { $0.id == item.id } ?? item }, set: { value in
            if let index = store.db.exclusions.firstIndex(where: { $0.id == item.id }) {
                store.db.exclusions[index] = value
            }
        })
        return VStack(alignment: .leading, spacing: 8) {
            Text("Editar día o intervalo").font(.headline)
            TextField("Descripción", text: entry.title)
            Picker("Tipo", selection: entry.kind) {
                ForEach(["Festivo", "Vacaciones", "Libre disposición"], id: \.self) { Text($0) }
            }
            DatePicker("Desde", selection: entry.from, displayedComponents: .date)
            DatePicker("Hasta", selection: entry.to, displayedComponents: .date)
            if cal.startOfDay(for: entry.wrappedValue.to) < cal.startOfDay(for: entry.wrappedValue.from) {
                Text("La fecha final debe ser igual o posterior al inicio.").foregroundStyle(.red)
            }
            DeleteButton(title: "Eliminar día o intervalo") {
                store.db.exclusions.removeAll { $0.id == item.id }
                selectedExclusion = nil
            }
        }.padding(12).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }

}
private struct NewExclusionView: View {
    @Environment(\.dismiss) private var dismiss
    @LocalState private var title = ""
    @LocalState private var kind: String?
    @LocalState private var from = ""
    @LocalState private var to = ""
    let save: (Exclusion) -> Void

    private var entry: Exclusion? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.timeZone = cal.timeZone
        formatter.dateFormat = "dd/MM/yyyy"
        formatter.isLenient = false
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let first = from.trimmingCharacters(in: .whitespacesAndNewlines)
        let last = to.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let kind, let start = formatter.date(from: first),
              formatter.string(from: start) == first else { return nil }
        if last.isEmpty { return Exclusion(title: name, from: start, to: start, kind: kind) }
        guard let end = formatter.date(from: last), formatter.string(from: end) == last,
              end >= start else { return nil }
        return Exclusion(title: name, from: start, to: end, kind: kind)
    }

    var body: some View {
        Form {
            Section("Añadir día o intervalo") {
                TextField("Descripción", text: $title)
                Picker("Tipo", selection: $kind) {
                    Text("Selecciona un tipo").tag(nil as String?)
                    ForEach(["Festivo", "Vacaciones", "Libre disposición"], id: \.self) { Text($0).tag(Optional($0)) }
                }
                TextField("Desde (dd/mm/aaaa)", text: $from)
                TextField("Hasta (opcional, dd/mm/aaaa)", text: $to)
                Text("Deja Hasta en blanco para un solo día.").font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Button("Cancelar") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Guardar") {
                    guard let entry else { return }
                    save(entry)
                    dismiss()
                }.keyboardShortcut(.defaultAction).disabled(entry == nil)
            }
        }.formStyle(.grouped).frame(width: 480, height: 320)
    }
}
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
@main struct PracticasApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = Store()
#if ACTUALIZACIONES
    private let updater = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil
    )
#endif
    var body: some Scene {
        WindowGroup("Prácticas FP") { RootView().environmentObject(store).environment(\.locale, Locale(identifier: "es_ES")) }
            .defaultSize(width: 1250, height: 850)
            .commands {
                CommandGroup(replacing: .newItem) {}
#if ACTUALIZACIONES
                CommandGroup(after: .appInfo) {
                    Button("Buscar actualizaciones…") { updater.checkForUpdates(nil) }
                }
#endif
            }
    }
}
