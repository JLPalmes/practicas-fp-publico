const invoke = window.__TAURI__.core.invoke;
const byId = id => document.getElementById(id);
const list = byId("list");
const tabs = Array.from(byId("student-tabs").querySelectorAll("[role=tab]"));

function selectStudentTab(tab) {
  for (const button of tabs) {
    button.setAttribute("aria-selected", String(button === tab));
    button.tabIndex = button === tab ? 0 : -1;
  }
  for (const id of ["personal", "preferences-panel", "global-hours", "periods"]) {
    byId(id).hidden = tab.getAttribute("aria-controls") !== id;
  }
  const second = tab.id === "tab-second";
  byId("periods").dataset.period = second ? "second" : "first";
  byId("periods").setAttribute("aria-labelledby", second ? "tab-second" : "tab-first");
  byId("second-toggle").hidden = !second;
}
for (const [index, tab] of tabs.entries()) {
  tab.onclick = () => selectStudentTab(tab);
  tab.onkeydown = event => {
    const next = event.key === "ArrowRight" ? (index + 1) % tabs.length :
      event.key === "ArrowLeft" ? (index + tabs.length - 1) % tabs.length :
      event.key === "Home" ? 0 : event.key === "End" ? tabs.length - 1 : -1;
    if (next < 0) return;
    event.preventDefault();
    selectStudentTab(tabs[next]);
    tabs[next].focus();
  };
}
selectStudentTab(tabs[0]);

function navigateWorkspace(section) {
  for (const id of ["save-status", "directory-status", "calendar-status"]) byId(id).textContent = "";
  globalStatus.textContent = "";
  globalStatus.hidden = true;
  byId("students-panel").hidden = section !== "students";
  byId("directory-dialog").hidden = section !== "companies" && section !== "tutors";
  byId("calendar-dialog").hidden = section !== "calendar";
  for (const id of ["students", "companies", "tutors", "calendar"]) {
    if (id === section) byId(id).setAttribute("aria-current", "page");
    else byId(id).removeAttribute("aria-current");
  }
}

async function canNavigate() {
  return !saving && !measuring && (directory.hidden || await savePendingDirectory()) &&
    (calendarDialog.hidden || calendarCanLeave()) && await savePendingFicha();
}
byId("students").onclick = async () => { if (await canNavigate()) navigateWorkspace("students"); };
const search = byId("student-search");
const measure = byId("measure");
const result = byId("result");
const save = { disabled: true };
const saveStatus = byId("save-status");
const globalStatus = byId("global-status");
const statusObserver = new MutationObserver(records => {
  const target = records.at(-1).target;
  const message = (target.nodeType === Node.ELEMENT_NODE ? target : target.parentElement)?.closest("output");
  if (!message) return;
  globalStatus.textContent = message.textContent;
  globalStatus.hidden = !message.textContent;
});
for (const id of ["save-status", "directory-status", "calendar-status", "backup-status", "import-status"]) {
  statusObserver.observe(byId(id), { childList: true, characterData: true, subtree: true });
}
const discard = byId("discard");
const personalFields = ["name", "group", "dni", "nuss", "phone", "email", "preferredType", "preferredZone",
  "preferences", "notes"];
const personalInput = key => byId(key === "name" ? "student-name" : key);
const form = byId("ficha");
const lifecycleButtons = ["create", "undo", "redo"].map(byId);
const globalFields = ["target", "previous", "next"];
const spanishDate = date => /^\d{4}-\d{2}-\d{2}$/.test(date) ? date.split("-").reverse().join("/") : date;
const periodFields = ["company", "tutor", "assignment", "start", "end", "hours", "target"];
let companies;
let tutors;
function showTutors(node, selectedTutor = "") {
  const company = node.querySelector(".company").value;
  const select = node.querySelector(".tutor");
  select.replaceChildren(new Option("Sin tutor", ""));
  for (const tutor of tutors.filter(tutor => tutor.company === company)) {
    select.add(new Option(tutor.name, tutor.id));
  }
  select.value = Array.from(select.options).some(option => option.value === selectedTutor) ? selectedTutor : "";
}
function addShift(container, shift = {}) {
  const node = byId("shift").content.firstElementChild.cloneNode(true);
  node.dataset.id = shift.id ?? "";
  node.querySelector(".from").value = shift.from ?? "";
  node.querySelector(".hours").value = shift.hours ?? "";
  node.querySelector(".remove-shift").onclick = () => node.remove();
  container.append(node);
}
const sections = ["Primer periodo", "Segundo periodo"].map((title, index) => {
  const node = byId("period").content.firstElementChild.cloneNode(true);
  node.querySelector("h2").textContent = title;
  periodFields.forEach((key, field) => {
    const id = "period-" + index + "-" + key;
    node.querySelector("." + key).id = id;
    node.querySelectorAll("label")[field].htmlFor = id;
  });
  node.querySelector(".add-shift").onclick = () => {
    addShift(node.querySelector(".shifts"), { hours: node.querySelector(".hours").value });
  };
  node.querySelector(".company").onchange = () => {
    showTutors(node);
    node.querySelector(".assignment").value = "Provisional";
  };
  byId("periods").append(node);
  return node;
});
let selected;
let request = 0;
let measuring = false;
let saving = false;
let currentIndex;
let annexEdits = [];
let savedFields;
let savedRecord;
const secondActive = byId("second-active");

secondActive.onchange = () => {
  sections[1].hidden = !secondActive.checked;
  updateForecastVisibility();
};

function updateForecastVisibility() {
  const forecast = sections[0].querySelector(".forecastEnd");
  forecast.hidden = secondActive.checked;
  forecast.previousElementSibling.hidden = secondActive.checked;
}

function showForecast(node, period) {
  node.querySelector(".forecastEnd").textContent = period.forecastEnd ? spanishDate(period.forecastEnd) :
    !period.company ? "Asigna una empresa" : !period.start ? "Indica la fecha de inicio" :
      period.error ? "Revisa los datos del periodo" : period.target === 0 ? "Objetivo cumplido" : "Sin calcular";
  node.querySelector(".error").textContent = period.error;
}

function previewGlobalHours() {
  if (!savedRecord) return;
  const number = key => Number(byId(key).value.trim().replace(",", "."));
  if (byId("target").value.trim() && byId("previous").value.trim() &&
      Number.isFinite(number("target")) && Number.isFinite(number("previous"))) {
    byId("remaining").textContent = Math.max(0, number("target") - number("previous") - savedRecord.elapsed);
  }
}
byId("target").addEventListener("input", previewGlobalHours);
byId("previous").addEventListener("input", previewGlobalHours);

function render(index, data) {
  currentIndex = index;
  secondActive.checked = data.secondActive;
  annexEdits = sections.map(() => []);
  byId("name").textContent = data.name || "Alumna sin nombre";
  for (const key of ["elapsed", "remaining"]) byId(key).textContent = data[key];
  for (const key of personalFields) personalInput(key).value = data[key];
  byId("certificate").checked = data.certificate;
  const warnings = byId("student-warnings");
  warnings.replaceChildren(...data.warnings.map(message => {
    const item = document.createElement("li");
    item.textContent = message;
    return item;
  }));
  warnings.hidden = data.warnings.length === 0;
  for (const key of globalFields) byId(key).value = data[key];
  sections.forEach((node, i) => {
    const period = data.periods[i];
    node.hidden = i === 1 && !data.secondActive;
    if (!period) {
      node.querySelector(".company").value = "";
      showTutors(node);
      node.querySelector(".assignment").value = "Pendiente";
      node.querySelector(".start").value = node.querySelector(".end").value = "";
      node.querySelector(".hours").value = "7";
      node.querySelector(".target").value = "0";
      node.querySelector(".forecastEnd").textContent = node.querySelector(".error").textContent = "";
      node.querySelector(".shifts").replaceChildren();
      for (const grid of node.querySelectorAll(".milestones")) grid.replaceChildren();
    }
    if (period) {
      node.querySelector(".company").value = period.company;
      showTutors(node, period.tutor);
      for (const [control, kind, id] of [[".open-company", "companies", period.company], [".open-tutor", "tutors", period.tutor]]) {
        const button = node.querySelector(control);
        button.hidden = !id;
        button.onclick = () => openDirectory(kind, id);
      }
      for (const key of periodFields.filter(key => key !== "tutor")) node.querySelector("." + key).value = period[key];
      node.querySelector(".practice-start").checked = period.practice[0];
      const completion = node.querySelector(".practice-end");
      completion.checked = period.practice[1];
      completion.onchange = () => {
        if (completion.checked && !node.querySelector(".end").value) node.querySelector(".end").value = courseToday;
      };
      showForecast(node, period);
      const shifts = node.querySelector(".shifts");
      shifts.replaceChildren();
      for (const shift of period.shifts) addShift(shifts, shift);
      for (const annex of period.annexes) {
        const grid = node.querySelector("." + annex.kind + " .milestones");
        grid.replaceChildren(...annex.steps.map(step => {
          const label = document.createElement("label");
          const check = document.createElement("input");
          check.type = "checkbox";
          check.dataset.stage = step.id;
          check.checked = step.checked;
          check.disabled = measuring || saving;
          check.onchange = () => annexEdits[i].push({ kind: annex.kind, id: step.id, checked: check.checked });
          label.append(check, " " + step.label);
          return label;
        }));
      }
    }
  });
  updateForecastVisibility();
  selected?.removeAttribute("aria-current");
  selected = list.children[index];
  updateCard(selected, data.card);
  filterCard(selected, searchKey());
  selected.setAttribute("aria-current", "true");
  savedRecord = data;
  savedFields = JSON.stringify(readFields());
  discard.hidden = true;
}

async function show(index) {
  const sequence = ++request;
  save.disabled = true;
  const data = await invoke("ficha", { index });
  if (sequence !== request) return;
  render(index, data);
  saveStatus.textContent = "";
  save.disabled = measuring || saving;
  return data;
}

function readFields() {
  return {
    certificate: byId("certificate").checked,
    secondActive: secondActive.checked,
    ...Object.fromEntries(personalFields.map(key => [key, personalInput(key).value])),
    ...Object.fromEntries(globalFields.map(key => [key, byId(key).value])),
    periods: sections.filter(node => !node.hidden).map((node, index) => ({
      ...Object.fromEntries(periodFields.map(key => [key, node.querySelector("." + key).value])),
      annexEdits: annexEdits[index],
      practice: [node.querySelector(".practice-start").checked, node.querySelector(".practice-end").checked],
      practiceEndDate: node.querySelector(".practice-end-date").value,
      shifts: Array.from(node.querySelectorAll(".shift"), row => ({
        id: row.dataset.id,
        from: row.querySelector(".from").value,
        hours: row.querySelector(".hours").value
      }))
    }))
  };
}

function hasPendingChanges() {
  return savedFields !== undefined && savedFields !== JSON.stringify(readFields());
}

function canLeaveFicha() {
  if (!hasPendingChanges()) return true;
  saveStatus.textContent = "Guarda o descarta los cambios antes de continuar.";
  discard.hidden = false;
  return false;
}

discard.onclick = () => {
  if (saving || measuring || save.disabled || !savedRecord) return;
  render(currentIndex, savedRecord);
  saveStatus.textContent = "Cambios descartados.";
};

function lockFields(locked) {
  for (const input of form.querySelectorAll("input")) {
    if (input.type === "checkbox") input.disabled = locked;
    else input.readOnly = locked || input.classList.contains("target");
  }
  for (const select of form.querySelectorAll("select")) select.disabled = locked;
  for (const textarea of form.querySelectorAll("textarea")) textarea.readOnly = locked;
  for (const button of form.querySelectorAll(".add-shift, .remove-shift")) button.disabled = locked;
}

async function saveFicha(index, fields) {
  const data = await invoke("guardar", { index, fields });
  render(index, data);
  return data;
}

let pendingSave;
let autoSaveEnabled = false;
let autoSaveTimer;
function scheduleAutoSave() {
  if (!autoSaveEnabled) return;
  clearTimeout(autoSaveTimer);
  autoSaveTimer = setTimeout(async () => {
    if (saving || measuring || directoryBusy || calendarBusy || backupBusy || reportBusy) return;
    await savePendingFicha(true);
  }, 700);
}
form.addEventListener("input", scheduleAutoSave);
form.addEventListener("focusout", scheduleAutoSave);
form.addEventListener("change", scheduleAutoSave);
form.addEventListener("click", event => {
  if (event.target.closest(".add-shift, .remove-shift")) scheduleAutoSave();
});

async function savePendingFicha(background = false) {
  if (pendingSave) return pendingSave;
  if (saving || measuring) return false;
  if (!hasPendingChanges() || currentIndex === undefined) return true;
  pendingSave = (async () => {
    saving = true;
    save.disabled = true;
    if (!background) lockFields(true);
    const fields = JSON.parse(JSON.stringify(readFields()));
    const snapshot = JSON.stringify(fields);
    saveStatus.textContent = "";
    try {
      if (background) {
        const data = await invoke("guardar", { index: currentIndex, fields });
        savedRecord = data;
        savedFields = snapshot;
        byId("elapsed").textContent = data.elapsed;
        byId("remaining").textContent = data.remaining;
        for (const [index, period] of data.periods.entries()) {
          sections[index].querySelector(".target").value = period.target;
          showForecast(sections[index], period);
        }
        // Derived targets are display-only and do not create a new user edit.
        const accepted = { ...fields, periods: fields.periods.map((period, index) =>
          ({ ...period, target: String(data.periods[index].target) })) };
        savedFields = JSON.stringify(accepted);
        updateCard(list.children[currentIndex], data.card);
        if (hasPendingChanges()) scheduleAutoSave();
      } else await saveFicha(currentIndex, fields);
      saveStatus.textContent = "";
      return true;
    } catch (error) {
      saveStatus.textContent = String(error);
      discard.hidden = false;
      return false;
    } finally {
      saving = false;
      save.disabled = false;
      if (!background) lockFields(false);
    }
  })();
  try { return await pendingSave; }
  finally { pendingSave = undefined; }
}

function searchKey() {
  return search.value.toLowerCase().normalize("NFD").replace(/\p{Mn}/gu, "")
    .replace(/[^\p{L}\p{N}]+/gu, " ").trim();
}

function filterCard(button, query) {
  button.hidden = !button.dataset.search.includes(query);
}

function applySearch() {
  const query = searchKey();
  for (const button of list.children) filterCard(button, query);
  const empty = byId("empty-search");
  empty.textContent = list.children.length ? "No hay alumnas que coincidan." : "Todavía no hay alumnas.";
  empty.hidden = Array.from(list.children).some(button => !button.hidden);
}
search.oninput = applySearch;

function updateCard(button, card) {
  button.dataset.id = card.id;
  button.dataset.search = card.search;
  const lines = JSON.stringify(card.lines);
  if (button.dataset.lines === lines) return;
  button.dataset.lines = lines;
  button.replaceChildren(...card.lines.map((text, index) => {
    const line = document.createElement(index === 0 ? "strong" : "span");
    line.textContent = text;
    if (index === 0) line.title = text;
    return line;
  }));
}

function showCards(cards) {
  selected = undefined;
  list.replaceChildren(...cards.map((card, index) => {
    const button = document.createElement("button");
    updateCard(button, card);
    button.onclick = async () => {
      if (index === currentIndex || !await canNavigate()) return;
      try { await show(index); }
      catch (error) { saveStatus.textContent = String(error); }
    };
    return button;
  }));
  applySearch();
}

async function changeRecords(action) {
  const data = await invoke("ficha_accion", { action });
  return useDirectory(action, data);
}

byId("import-students").onclick = async () => {
  if (!await canNavigate()) return;
  saving = true;
  save.disabled = true;
  lockFields(true);
  const status = byId("import-status");
  status.textContent = "";
  try {
    const data = await invoke("ficha_accion", { action: "importStudents" });
    if (data) {
      await useDirectory("import", data);
      status.textContent = "Importación guardada.";
    }
  } catch (error) {
    status.textContent = String(error);
  } finally {
    saving = false;
    save.disabled = currentIndex === undefined;
    lockFields(false);
  }
};

async function useDirectory(action, data) {
  const cards = data.cards;
  const index = action === "create" ? cards.length - 1 : Math.min(currentIndex ?? 0, cards.length - 1);
  loadDirectory(data);
  if (!cards.length) {
    currentIndex = undefined;
    savedFields = savedRecord = undefined;
    form.hidden = true;
    byId("name").textContent = "Alumnas";
    return;
  }
  form.hidden = false;
  return show(index);
}

function loadDirectory(data) {
  companies = data.companies;
  tutors = data.tutors;
  for (const node of sections) {
    const select = node.querySelector(".company");
    select.replaceChildren(new Option("Selecciona una empresa", ""));
    for (const company of companies) select.add(new Option(company.name || "Empresa sin nombre", company.id));
  }
  showCards(data.cards);
}

const directory = byId("directory-dialog");
const directoryForm = byId("directory-form");
const directorySelection = byId("directory-record");
const directoryStatus = byId("directory-status");
let directoryKind;
let directoryBusy = false;
let directoryDirty = false;
let directoryVersion = 0;
let directoryRevision = 0;
let directorySaveTimer;
let pendingDirectorySave;
let pendingDirectoryData;
let agreementEdits = [];
let contactsToSave = [];
const companyResponses = [
  ["uncontacted", "Contacto sin registrar"], ["waiting", "Esperando respuesta"],
  ["accepted", "Admite alumnas"], ["rejected", "Rechaza alumnas"]
];
const directoryRecords = () => directoryKind === "companies" ? companies : tutors;

function directoryFields() {
  const company = directoryKind === "companies";
  const record = directoryRecords().find(item => item.id === directorySelection.value) ?? {};
  byId("directory-heading").textContent = record.name || (company ? "Nueva empresa" : "Nuevo tutor");
  renderDirectoryCards();
  const fields = byId("directory-fields");
  fields.replaceChildren();
  directoryDirty = false;
  byId("directory-discard").hidden = true;
  byId("directory-delete").hidden = !record.id;
  byId("company-report").hidden = !company || !record.id;
  loadDirectoryDetails(record.id);
  function add(key, label, type = "text", options) {
    const input = document.createElement(options ? "select" : type === "textarea" ? "textarea" : "input");
    input.name = key;
    input.id = "directory-" + key;
    if (options) for (const [value, text] of options) input.add(new Option(text, value));
    else if (input instanceof HTMLInputElement) input.type = type;
    input.value = record[key] ?? (key === "response" ? "uncontacted" : "");
    const caption = document.createElement("label");
    caption.htmlFor = input.id;
    caption.textContent = label;
    const term = document.createElement("dt");
    const definition = document.createElement("dd");
    term.append(caption);
    definition.append(input);
    fields.append(term, definition);
    return { input, term, definition };
  }
  add("name", company ? "Empresa" : "Nombre");
  if (company) {
    add("cif", "CIF");
    add("address", "Dirección");
    add("contact", "Persona de contacto");
  } else add("company", "Empresa", "text", [["", "Sin empresa"], ...companies.map(item => [item.id, item.name])]);
  add("phone", "Teléfono", "tel");
  add("email", "Correo");
  add("notes", "Observaciones", "textarea");
  if (company) {
    const response = add("response", "Estado de contacto", "text", companyResponses).input;
    add("contactedOn", "Fecha de contacto", "date");
    add("respondedOn", "Fecha de respuesta", "date");
    const { input, term, definition } = add("capacity", "Plazas concedidas");
    input.inputMode = "numeric";
    const count = document.createElement("output");
    definition.append(count);
    function refreshCapacity() {
      const occupied = record.occupied ?? 0;
      term.hidden = definition.hidden = response.value !== "accepted";
      const capacity = Number(input.value);
      count.textContent = input.value.trim() && Number.isInteger(capacity) && capacity >= Math.max(1, occupied)
        ? " · " + occupied + " ocupadas, " + (capacity - occupied) + " libres"
        : " · " + occupied + " ocupadas";
    }
    response.onchange = input.oninput = refreshCapacity;
    refreshCapacity();
  }
}

async function loadDirectoryDetails(id) {
  const container = byId("directory-details");
  const version = ++directoryVersion;
  container.replaceChildren();
  agreementEdits = [];
  contactsToSave = [];
  if (!id) return;
  try {
    const company = directoryKind === "companies";
    const data = await invoke("ficha_accion", { action: company ? "companyDetails" : "tutorLinks", fields: { id } });
    if (version !== directoryVersion) return;
    const links = company ? data.links : data;
    for (const link of links) {
      const button = document.createElement("button");
      button.type = "button";
      button.textContent = link.label || "Sin nombre";
      button.onclick = async () => {
        if (!await savePendingDirectory()) return;
        if (link.kind === "students") {
          const index = Array.from(list.children).findIndex(card => card.dataset.id === link.id);
          if (index < 0) return;
          navigateWorkspace("students");
          show(index).catch(error => { result.textContent = String(error); });
        } else openDirectory(link.kind, link.id);
      };
      container.append(button);
    }
    if (!company) return;
    const fold = (parent, title) => {
      const details = document.createElement("details");
      const summary = document.createElement("summary");
      summary.textContent = title;
      details.append(summary);
      parent.append(details);
      return details;
    };
    const agreement = fold(container, "Concierto de colaboración");
    const grid = document.createElement("div");
    grid.className = "milestones";
    for (const step of data.agreement) {
      const label = document.createElement("label");
      const check = document.createElement("input");
      check.type = "checkbox";
      check.checked = step.checked;
      check.onchange = () => agreementEdits.push({ kind: "agreement", id: step.id, checked: check.checked });
      label.append(check, " " + step.label);
      grid.append(label);
    }
    agreement.append(grid);
    const monthly = fold(container, "Seguimiento mensual");
    if (!data.contacts.length) monthly.append("Sin seguimientos mensuales.");
    for (const contact of data.contacts) {
      const month = new Intl.DateTimeFormat("es-ES", { month: "long", year: "numeric", timeZone: "UTC" })
        .format(new Date(contact.planned + "T00:00:00Z"));
      const item = fold(monthly, month + (contact.historical ? " · histórico" : ""));
      const context = document.createElement("p");
      context.textContent = "Previsto: " + contact.planned + " · " + contact.students.join(", ");
      item.append(context);
      const register = document.createElement("button");
      register.type = "button";
      register.textContent = "Registrar este contacto";
      register.hidden = contact.saved;
      const editor = document.createElement("div");
      editor.hidden = !contact.saved;
      function field(caption, type, value) {
        const label = document.createElement("label");
        const input = document.createElement(type === "textarea" ? "textarea" : "input");
        if (type !== "textarea") input.type = type;
        if (type === "checkbox") input.checked = value;
        else input.value = value;
        label.append(caption, " ", input);
        editor.append(label);
        return input;
      }
      const planned = field("Fecha prevista", "date", contact.planned);
      const completed = field("Contacto realizado", "checkbox", contact.completed);
      const doneOn = field("Realizado el", "date", contact.doneOn);
      const notes = field("Observaciones del contacto", "textarea", contact.notes);
      const updateDate = () => { doneOn.parentElement.hidden = !completed.checked; };
      completed.onchange = updateDate;
      updateDate();
      register.onclick = () => { register.hidden = true; editor.hidden = false; markDirectoryChanged(); };
      item.append(register, editor);
      contactsToSave.push(() => {
        if (editor.hidden || (contact.saved && planned.value === contact.planned && completed.checked === contact.completed &&
            doneOn.value === contact.doneOn && notes.value === contact.notes)) return null;
        return { id: contact.id, planned: planned.value, completed: completed.checked, doneOn: doneOn.value, notes: notes.value };
      });
    }
  } catch (error) {
    if (version === directoryVersion) directoryStatus.textContent = String(error);
  }
}

function refreshDirectoryPicker(id = "") {
  directorySelection.replaceChildren(new Option("Nueva ficha", ""));
  for (const record of directoryRecords()) directorySelection.add(new Option(record.name || "Sin nombre", record.id));
  directorySelection.value = id;
  directorySelection.dataset.saved = id;
  directoryFields();
}

function renderDirectoryCards() {
  const cards = directoryRecords().map(record => {
    const button = document.createElement("button");
    button.type = "button";
    const title = document.createElement("strong");
    title.textContent = record.name || "Sin nombre";
    title.title = title.textContent;
    button.append(title);
    if (directoryKind === "tutors" && record.company) {
      const line = document.createElement("span");
      line.className = "muted";
      line.textContent = companies.find(company => company.id === record.company)?.name || "Empresa sin nombre";
      button.append(line);
    }
    for (const label of record.students ?? []) {
      const line = document.createElement("span");
      line.textContent = label;
      button.append(line);
    }
    if (record.id === directorySelection.value) button.setAttribute("aria-current", "true");
    button.onclick = () => selectDirectoryRecord(record.id);
    return button;
  });
  byId("directory-list").replaceChildren(...cards);
}

async function selectDirectoryRecord(id) {
  if (!await savePendingDirectory()) return;
  directorySelection.value = id;
  directorySelection.dataset.saved = id;
  directoryStatus.textContent = "";
  directoryFields();
}
byId("directory-create").onclick = () => selectDirectoryRecord("");
function canLeaveDirectory() {
  if (directoryBusy) return false;
  if (!directoryDirty) return true;
  directoryStatus.textContent = "Guarda o descarta los cambios de esta ficha antes de continuar.";
  byId("directory-discard").hidden = false;
  return false;
}
function markDirectoryChanged() {
  directoryDirty = true;
  directoryRevision++;
  clearTimeout(directorySaveTimer);
  if (autoSaveEnabled) directorySaveTimer = setTimeout(() => savePendingDirectory(true), 700);
}
directoryForm.addEventListener("input", markDirectoryChanged);
directoryForm.addEventListener("change", markDirectoryChanged);
directorySelection.onchange = async () => {
  const id = directorySelection.value;
  directorySelection.value = directorySelection.dataset.saved;
  await selectDirectoryRecord(id);
};
async function openDirectory(kind, id) {
  if (!await canNavigate()) return;
  directoryKind = kind;
  byId("directory-title").textContent = kind === "companies" ? "Empresas" : "Tutores";
  refreshDirectoryPicker(id ?? directoryRecords()[0]?.id);
  directoryStatus.textContent = "";
  byId("directory-create").textContent = kind === "companies" ? "Añadir empresa" : "Añadir tutor";
  navigateWorkspace(kind);
}
for (const kind of ["companies", "tutors"]) {
  byId(kind).onclick = () => openDirectory(kind);
}
byId("directory-discard").onclick = () => {
  if (directoryBusy) return;
  directoryFields();
  directoryStatus.textContent = "Cambios descartados.";
};
directory.oncancel = event => { if (!canLeaveDirectory()) event.preventDefault(); };

const deleteDialog = byId("confirm-delete");
function confirmDelete() {
  return new Promise(resolve => {
    deleteDialog.returnValue = "";
    deleteDialog.addEventListener("close", () => resolve(deleteDialog.returnValue === "delete"), { once: true });
    deleteDialog.showModal();
  });
}
async function deleteRecord(kind, id) {
  const data = await invoke("ficha_accion", { action: "deleteRecord", kind, fields: { id } });
  await useDirectory("delete", data);
}
byId("delete-student").onclick = async () => {
  if (saving || measuring || currentIndex === undefined || !canLeaveFicha()) return;
  const id = list.children[currentIndex].dataset.id;
  if (!await confirmDelete()) return;
  saving = true;
  lockFields(true);
  try { await deleteRecord("students", id); }
  catch (error) { saveStatus.textContent = String(error); }
  finally { saving = false; lockFields(false); save.disabled = currentIndex === undefined; }
};
byId("directory-delete").onclick = async () => {
  if (!await savePendingDirectory() || !directorySelection.value || !await confirmDelete()) return;
  directoryBusy = true;
  try {
    await deleteRecord(directoryKind, directorySelection.value);
    refreshDirectoryPicker(directoryRecords()[0]?.id);
    directoryStatus.textContent = "Ficha eliminada.";
  } catch (error) { directoryStatus.textContent = String(error); }
  finally { directoryBusy = false; if (currentIndex !== undefined) save.disabled = false; }
};
async function savePendingDirectory(background = false) {
  clearTimeout(directorySaveTimer);
  if (pendingDirectorySave) {
    if (!await pendingDirectorySave) return false;
    return savePendingDirectory(background);
  }
  if (directoryBusy) return false;
  if (directoryDirty) {
    const revision = directoryRevision;
    const kind = directoryKind;
    const fields = { ...Object.fromEntries(new FormData(directoryForm)), id: directorySelection.value,
      annexEdits: agreementEdits.slice(), contacts: contactsToSave.map(read => read()).filter(Boolean) };
    directoryBusy = true;
    directoryStatus.textContent = "";
    pendingDirectorySave = (async () => {
      try {
        const data = await invoke("ficha_accion", { action: "saveDirectory", kind, fields });
        pendingDirectoryData = data;
        companies = data.companies;
        tutors = data.tutors;
        const id = fields.id || directoryRecords().at(-1)?.id;
        directorySelection.replaceChildren(new Option("Nueva ficha", ""),
          ...directoryRecords().map(record => new Option(record.name || "Sin nombre", record.id)));
        directorySelection.value = directorySelection.dataset.saved = id;
        agreementEdits.splice(0, fields.annexEdits.length);
        directoryDirty = directoryRevision !== revision;
        byId("directory-heading").textContent = directoryRecords().find(record => record.id === id)?.name || "Sin nombre";
        byId("directory-delete").hidden = false;
        byId("company-report").hidden = kind !== "companies";
        renderDirectoryCards();
        directoryStatus.textContent = "";
        return true;
      } catch (error) {
        directoryStatus.textContent = String(error);
        byId("directory-discard").hidden = false;
        return false;
      } finally { directoryBusy = false; }
    })();
    let success;
    try { success = await pendingDirectorySave; }
    finally { pendingDirectorySave = undefined; }
    if (!success) return false;
    if (directoryDirty) {
      if (!background) return savePendingDirectory();
      if (autoSaveEnabled) directorySaveTimer = setTimeout(() => savePendingDirectory(true), 700);
    }
  }
  if (!background && pendingDirectoryData) {
    const data = pendingDirectoryData;
    pendingDirectoryData = undefined;
    await useDirectory("refresh", data);
  }
  return true;
}
directoryForm.onsubmit = async event => {
  event.preventDefault();
  await savePendingDirectory();
};

for (const button of lifecycleButtons) {
  button.onclick = async () => {
    if (!await canNavigate()) return;
    saving = true;
    save.disabled = measure.disabled = true;
    lockFields(true);
    try { await changeRecords(button.id); }
    catch (error) { saveStatus.textContent = String(error); }
    finally {
      saving = false;
      save.disabled = measure.disabled = false;
      lockFields(false);
    }
  };
}

form.onsubmit = async event => {
  event.preventDefault();
  if (save.disabled || currentIndex === undefined) return;
  saving = true;
  save.disabled = measure.disabled = true;
  lockFields(true);
  saveStatus.textContent = "";
  try {
    await saveFicha(currentIndex, readFields());
    saveStatus.textContent = "";
  } catch (error) {
    saveStatus.textContent = String(error);
  } finally {
    saving = false;
    save.disabled = measure.disabled = false;
    lockFields(false);
  }
};

const paint = () => new Promise(done => requestAnimationFrame(() => requestAnimationFrame(done)));
async function timings(label, action) {
  const samples = [];
  for (let i = 0; i < 34; i++) {
    const start = performance.now();
    await action(i < 4 ? i : i - 4);
    if (i >= 4) samples.push(performance.now() - start);
  }
  samples.sort((a, b) => a - b);
  return label + " · mediana " + ((samples[14] + samples[15]) / 2).toFixed(2) +
    " ms · p95 " + samples[28].toFixed(2) + " ms";
}

async function benchmark() {
  measuring = true;
  measure.disabled = save.disabled = true;
  lockFields(true);
  try {
    result.textContent = "Midiendo 30 muestras por operación…";
    const change = await timings("Cambiar de ficha", async i => {
      const index = (i + 1) % 2;
      const data = await show(index);
      if (byId("name").textContent !== list.children[index].firstElementChild.textContent || data.periods.length !== 2) {
        throw Error("La ficha mostrada no coincide con la solicitud.");
      }
      await paint();
    });
    selectStudentTab(byId("tab-first"));
    const annex = sections[0].querySelector(".annexI");
    const disclosure = await timings("Desplegar y plegar el anexo", async () => {
      annex.open = true;
      await paint();
      annex.open = false;
      await paint();
    });
    await show(0);
    const initial = readFields();
    let validation;
    try { await saveFicha(0, { ...initial, phone: "600000000", email: "correo inválido" }); }
    catch (error) { validation = String(error); }
    if (validation !== "Revisa el correo." || (await show(0)).phone !== initial.phone) {
      throw Error("El correo inválido debe rechazarse sin cambiar el contacto.");
    }
    const alternate = companies.find(company => company.name === "Segunda empresa de prueba").id;
    const unavailable = companies.find(company => company.name === "Empresa sin plazas").id;
    const firstTutor = tutors.find(tutor => tutor.company === initial.periods[0].company).id;
    const secondTutor = tutors.find(tutor => tutor.company === alternate).id;
    const periods = [
      { ...initial.periods[0], tutor: firstTutor, assignment: "Definitiva",
        hours: "6,5", target: "300", start: "2026-09-07", end: "2026-09-18",
        shifts: [{ from: "2026-09-10", hours: "4" }] },
      { company: alternate, tutor: secondTutor, assignment: "Provisional",
        hours: "7,25", target: "200", start: "2026-09-21", end: "2026-10-02",
        shifts: [{ from: "2026-09-23", hours: "5,5" }] }
    ];
    validation = "";
    try {
      await saveFicha(0, { ...initial, target: "750", periods: [periods[0], { ...periods[1], hours: "25" }] });
    } catch (error) { validation = String(error); }
    const unedited = await show(0);
    if (validation !== "Revisa la jornada del periodo 2." || unedited.target !== Number(initial.target)) {
      throw Error("Una jornada inválida debe rechazar toda la edición.");
    }
    try {
      await saveFicha(0, { ...initial, target: "751", periods: [
        { ...periods[0], company: alternate, tutor: secondTutor }, { ...periods[1], company: unavailable }
      ] });
      throw Error("Se aceptó una empresa sin plazas.");
    } catch (error) {
      if (!String(error).includes("no dispone de plazas libres")) throw error;
    }
    const unchanged = await show(0);
    if (unchanged.target !== Number(initial.target) || unchanged.periods[0].company !== initial.periods[0].company) {
      throw Error("La asignación rechazada modificó la ficha.");
    }
    try {
      await saveFicha(0, { ...initial, periods: [periods[0], { ...periods[1], tutor: firstTutor }] });
      throw Error("Se aceptó un tutor de otra empresa.");
    } catch (error) {
      if (!String(error).includes("El tutor debe pertenecer")) throw error;
    }
    try {
      await saveFicha(0, { ...initial, periods: [periods[0], { ...periods[1], end: "2026-09-20" }] });
      throw Error("Se aceptó un fin anterior al inicio.");
    } catch (error) {
      if (!String(error).includes("El fin manual requiere un inicio")) throw error;
    }
    try {
      await saveFicha(0, { ...initial, periods: [periods[0], {
        ...periods[1], shifts: [...periods[1].shifts, ...periods[1].shifts]
      }] });
      throw Error("Se aceptó una fecha de cambio duplicada.");
    } catch (error) {
      if (!String(error).includes("requiere una fecha distinta")) throw error;
    }
    const edit = await timings("Guardar ficha y recalcular horas", async i => {
      const phone = String(600000100 + i);
      const target = 600 + i;
      const data = await saveFicha(0, {
        ...initial, phone, email: "alumna@example.test", target: String(target), previous: "25,5", next: "10", periods
      });
      if (data.phone !== phone || data.target !== target || data.next !== 10 ||
          data.periods[0].hours !== 6.5 || data.periods[1].hours !== 7.25 ||
          data.periods[0].target !== 41 || data.periods[1].target !== 58.5 ||
          data.periods[1].company !== alternate || data.periods[0].start !== "2026-09-07" ||
          data.periods[1].forecastEnd !== "2026-10-02" ||
          data.periods[0].shifts[0].hours !== 4 || data.periods[1].shifts[0].hours !== 5.5 ||
          data.remaining !== Math.max(0, target - 25.5 - data.elapsed) ||
          byId("remaining").textContent !== String(data.remaining)) {
        throw Error("La ficha guardada o el cálculo de horas no coinciden.");
      }
      data.periods.forEach((period, index) => {
        periods[index].shifts[0].id = period.shifts[0].id;
      });
      await paint();
    });
    if ((await show(1)).phone === "600000129") throw Error("Se modificó otra ficha.");
    const reopened = await show(0);
    if (reopened.periods[0].tutor !== firstTutor || reopened.periods[0].assignment !== "Definitiva" ||
        reopened.periods[1].tutor !== secondTutor || reopened.periods[1].assignment !== "Provisional" ||
        sections[1].querySelector(".tutor").value !== secondTutor ||
        Array.from(sections[1].querySelector(".tutor").options).some(option => option.value === firstTutor)) {
      throw Error("El tutor y el estado deben conservarse y filtrarse por periodo.");
    }
    if (reopened.phone !== "600000129" || reopened.target !== 629 || reopened.previous !== 25.5 ||
        reopened.periods[1].company !== alternate || reopened.periods[1].hours !== 7.25 ||
        reopened.periods[1].end !== "2026-10-02" || reopened.periods[1].shifts[0].hours !== 5.5) {
      throw Error("Los cambios no se conservaron al volver a la ficha.");
    }
    const afterRemoval = readFields();
    afterRemoval.periods[0].shifts = [];
    const removed = await saveFicha(0, afterRemoval);
    if (removed.periods[0].shifts.length || removed.periods[1].shifts.length !== 1 ||
        removed.elapsed <= reopened.elapsed) {
      throw Error("Quitar un cambio debe recalcular las horas de su periodo.");
    }
    const mark = (period, kind, stage, checked) => {
      const check = sections[period].querySelector("." + kind + ' [data-stage="' + stage + '"]');
      check.checked = checked;
      check.dispatchEvent(new Event("change"));
    };
    const step = (data, period, kind, stage) =>
      data.periods[period].annexes.find(annex => annex.kind === kind).steps.find(item => item.id === stage);
    mark(0, "annexI", "receivedTutor", true);
    mark(1, "annexII", "generated", true);
    await saveFicha(0, readFields());
    await show(1);
    const documents = await show(0);
    const sent = step(documents, 0, "annexI", "sentTutor");
    const received = step(documents, 0, "annexI", "receivedTutor");
    const generated = step(documents, 1, "annexII", "generated");
    if (![sent, received, generated].every(item => item.checked && !item.dated) ||
        step(documents, 1, "annexI", "receivedTutor").checked) {
      throw Error("Los hitos deben persistir en su periodo y anexo sin registrar fechas.");
    }
    mark(0, "annexI", "sentTutor", false);
    const cleared = await saveFicha(0, readFields());
    if (step(cleared, 0, "annexI", "receivedTutor").checked ||
        !step(cleared, 1, "annexII", "generated").checked) {
      throw Error("Retirar un envío debe retirar su recepción en el mismo anexo.");
    }
    const personal = {
      name: "Alumna de prueba editada", group: "2.º A", dni: "00000000T", nuss: "001234567890",
      preferredType: "Administración", preferredZone: "Centro", preferences: "Horario de mañana",
      notes: "Primera línea\nSegunda línea"
    };
    for (const [key, value] of Object.entries(personal)) personalInput(key).value = value;
    byId("certificate").checked = true;
    await saveFicha(0, readFields());
    await show(1);
    const updated = await show(0);
    if (!Object.entries(personal).every(([key, value]) => updated[key] === value && personalInput(key).value === value) ||
        list.children[0].firstElementChild.textContent !== personal.name || !updated.certificate || !byId("certificate").checked ||
        updated.warnings.length) {
      throw Error("Los datos personales o las preferencias no se conservaron.");
    }
    personalInput("notes").value = "Borrador pendiente";
    await invoke("probar_cierre");
    for (let frame = 0; discard.hidden && frame < 30; frame++) await paint();
    if (discard.hidden || currentIndex !== 0 || personalInput("notes").value !== "Borrador pendiente") {
      throw Error("Cerrar la ventana debe conservar los cambios pendientes.");
    }
    render(currentIndex, savedRecord);
    if (hasPendingChanges() || !discard.hidden || personalInput("notes").value !== personal.notes) {
      throw Error("Descartar debe restaurar la última ficha guardada.");
    }
    for (const query of ["ALÚMNA DE PRUEBA EDITADA", "00000000T", "2.º A"]) {
      search.value = query;
      applySearch();
      if (Array.from(list.children).filter(button => !button.hidden).length !== 1 ||
          list.children[0].hidden || currentIndex !== 0) throw Error("La búsqueda no conservó la ficha correcta.");
    }
    search.value = "Segunda empresa de prueba";
    applySearch();
    if (list.children[0].hidden || !list.children[1].hidden) throw Error("La búsqueda debe incluir la empresa.");
    search.value = "";
    applySearch();
    const incomplete = await saveFicha(0, { ...readFields(), dni: "00", nuss: "01" });
    if (!incomplete.warnings.some(message => message.includes("DNI")) ||
        !incomplete.warnings.some(message => message.includes("NUSS"))) {
      throw Error("Faltan los avisos de identificación.");
    }
    await saveFicha(0, { ...readFields(), dni: personal.dni, nuss: personal.nuss });
    secondActive.checked = false;
    secondActive.dispatchEvent(new Event("change"));
    const disabled = await saveFicha(0, readFields());
    if (disabled.secondActive || !sections[1].hidden || disabled.elapsed >= updated.elapsed) {
      throw Error("El segundo periodo desactivado no debe sumar horas.");
    }
    await show(1);
    await show(0);
    secondActive.checked = true;
    secondActive.dispatchEvent(new Event("change"));
    const enabled = await saveFicha(0, readFields());
    if (!enabled.secondActive || enabled.elapsed !== updated.elapsed ||
        enabled.periods[1].company !== updated.periods[1].company ||
        enabled.periods[1].shifts[0].id !== updated.periods[1].shifts[0].id) {
      throw Error("El segundo periodo debe recuperar su asignación y jornada.");
    }
    const count = list.children.length;
    const created = await changeRecords("create");
    const newIndex = list.children.length - 1;
    if (list.children.length !== count + 1 || created.secondActive || created.name) {
      throw Error("La ficha nueva debe tener un solo periodo activo.");
    }
    personalInput("name").value = "Alumna creada en la prueba";
    sections[0].querySelector(".practice-start").checked = true;
    sections[0].querySelector(".practice-end").checked = true;
    await saveFicha(newIndex, readFields());
    const undone = await changeRecords("undo");
    if (undone.name || undone.periods[0].practice.some(Boolean)) throw Error("Deshacer no restauró la ficha nueva.");
    const redone = await changeRecords("redo");
    if (redone.name !== "Alumna creada en la prueba" || !redone.periods[0].practice.every(Boolean)) {
      throw Error("Rehacer no restauró los datos guardados.");
    }
    const reloaded = await changeRecords("reopen");
    if (reloaded.name !== redone.name || !reloaded.periods[0].practice.every(Boolean)) {
      throw Error("Los cambios no se conservaron al reabrir el archivo.");
    }
    result.textContent = [change, disclosure, edit, "Validación, recálculo e hitos de ambos periodos verificados."].join("\n");
    await invoke("resultado", { report: result.textContent, success: true });
  } catch (error) {
    result.textContent = String(error);
    await invoke("resultado", { report: result.textContent, success: false });
  }
  finally {
    measuring = false;
    measure.disabled = save.disabled = false;
    lockFields(false);
  }
}
measure.onclick = () => { if (canLeaveFicha()) benchmark(); };

async function benchmarkCopy(count) {
  measuring = true;
  lockFields(true);
  const change = await timings("Cambiar de ficha", async i => {
    const index = (i + 1) % 2;
    await show(index);
    if (currentIndex !== index) throw Error("La ficha mostrada no coincide con la solicitud.");
    await paint();
  });
  selectStudentTab(byId("tab-first"));
  const annex = sections[0].querySelector(".annexI");
  const disclosure = await timings("Desplegar y plegar el Anexo I", async () => {
    annex.open = true;
    await paint();
    annex.open = false;
    await paint();
  });
  await invoke("resultado", {
    report: ["Tauri / " + count + " fichas / 30 mediciones por operación", change, disclosure].join("\n"),
    success: true
  });
}

async function start() {
  autoSaveEnabled = !await invoke("automatico");
  measure.hidden = await invoke("edicion_distribuida");
  await window.__TAURI__.window.getCurrentWindow().onCloseRequested(event => {
    if (saving || reportBusy || backupBusy) {
      event.preventDefault();
      saveStatus.textContent = "Espera a que termine el guardado antes de cerrar.";
    } else if ((!directory.hidden && !canLeaveDirectory()) || (!calendarDialog.hidden && !calendarCanLeave()) ||
        (backupDialog.open && !backupCanLeave()) || !canLeaveFicha()) {
      event.preventDefault();
    }
  });
  const data = await invoke("alumnas");
  loadDirectory(data);
  for (const kind of ["companies", "tutors"]) byId(kind).disabled = false;
  byId("calendar").disabled = false;
  byId("reports").disabled = false;
  byId("backups").disabled = false;
  byId("import-students").disabled = false;
  for (const button of lifecycleButtons) button.disabled = false;
  void iniciarActualizaciones();
  if (await invoke("verificar_piloto")) {
    if (data.cards.length) throw Error("El primer arranque del piloto debe comenzar vacío.");
    const companyData = await invoke("ficha_accion", { action: "saveDirectory", kind: "companies", fields: {
      name: "Empresa del piloto", response: "accepted", capacity: "2", contactedOn: "2026-09-01"
    } });
    const company = companyData.companies[0];
    const tutorData = await invoke("ficha_accion", { action: "saveDirectory", kind: "tutors", fields: {
      name: "Tutora del piloto", company: company.id
    } });
    const tutor = tutorData.tutors[0];
    if (company.capacity !== 2 || company.contactedOn !== "2026-09-01" || tutor.company !== company.id) {
      throw Error("El piloto no guardó la empresa o su tutora.");
    }
    await changeRecords("create");
    personalInput("name").value = "Alumna creada en la prueba";
    const companyInput = sections[0].querySelector(".company");
    companyInput.value = company.id;
    companyInput.dispatchEvent(new Event("change"));
    sections[0].querySelector(".tutor").value = tutor.id;
    sections[0].querySelector(".assignment").value = "Definitiva";
    sections[0].querySelector(".start").value = "2026-09-01";
    sections[0].querySelector(".end").value = "2026-10-31";
    sections[0].querySelector(".practice-start").checked = true;
    sections[0].querySelector(".practice-end").checked = true;
    const assigned = await saveFicha(0, readFields());
    if (byId("target").value !== "500" || assigned.target !== 500) throw Error("Falta el objetivo general inicial.");
    byId("target").value = "650";
    byId("target").dispatchEvent(new Event("input"));
    if (Number(byId("remaining").textContent) !== Math.max(0, 650 - assigned.previous - assigned.elapsed)) {
      throw Error("El objetivo general debe recalcular las horas restantes mientras se edita.");
    }
    const objectiveSaved = await saveFicha(0, readFields());
    if (objectiveSaved.target !== 650) throw Error("El objetivo general no se guardó.");
    const reads = await Promise.all(Array.from({ length: 12 }, () => invoke("ficha", { index: 0 })));
    if (reads.some(record => record.target !== 650)) throw Error("Las lecturas simultáneas devolvieron otra ficha.");
    await show(0);
    if (byId("target").value !== "650") throw Error("El objetivo no se recuperó al cambiar de ficha.");
    const displayed = sections[0].querySelector(".forecastEnd");
    if (displayed.textContent !== spanishDate(objectiveSaved.periods[0].forecastEnd)) throw Error("La fecha debe usar formato español.");
    secondActive.checked = true;
    secondActive.dispatchEvent(new Event("change"));
    if (!displayed.hidden || !displayed.previousElementSibling.hidden) throw Error("El primer periodo no debe mostrar una previsión final con segundo periodo.");
    secondActive.checked = false;
    secondActive.dispatchEvent(new Event("change"));
    if (displayed.hidden) throw Error("Debe mostrarse la previsión del periodo único.");
    selectStudentTab(byId("tab-first"));
    if (sections[0].getClientRects().length === 0 || sections[1].getClientRects().length ||
        !byId("personal").hidden || readFields().periods[0].company !== company.id) {
      throw Error("Las pestañas deben separar secciones sin cambiar los datos de la ficha.");
    }
    selectStudentTab(byId("tab-second"));
    if (sections[0].getClientRects().length || byId("second-toggle").hidden) {
      throw Error("La pestaña del segundo periodo debe mostrar su control de activación.");
    }
    selectStudentTab(byId("tab-personal"));
    await openDirectory("companies", company.id);
    if (directory.hidden || !byId("students-panel").hidden || !byId("directory-list").children.length) {
      throw Error("Empresas debe ocupar un panel con su propia lista.");
    }
    await openDirectory("tutors", tutor.id);
    if (byId("tutors").getAttribute("aria-current") !== "page") throw Error("Tutores debe tener navegación propia.");
    await byId("calendar").onclick();
    if (calendarDialog.hidden || !directory.hidden || !byId("calendar-list").children.length) {
      throw Error("El calendario debe mostrar los días excluidos en su propio panel.");
    }
    await byId("students").onclick();
    if (byId("students-panel").hidden || !calendarDialog.hidden) throw Error("No se pudo volver al panel de Alumnas.");
    const temporaryStudent = await changeRecords("create");
    const temporaryIndex = list.children.length - 1;
    await list.children[0].onclick();
    byId("target").value = "675";
    sections[0].querySelector(".practice-end").checked = false;
    sections[0].querySelector(".practice-end").onchange();
    sections[0].querySelector(".practice-end").checked = true;
    sections[0].querySelector(".practice-end").onchange();
    sections[0].querySelector(".practice-end-date").value = "2026-10-31";
    await list.children[temporaryIndex].onclick();
    if (currentIndex !== temporaryIndex || saving) throw Error("Cambiar de alumna debe guardar y abrir la ficha solicitada.");
    await list.children[0].onclick();
    if (byId("target").value !== "675" || !sections[0].querySelector(".practice-end").checked) {
      throw Error("Se perdieron el objetivo o la finalización al navegar.");
    }
    byId("target").value = "";
    await list.children[temporaryIndex].onclick();
    await paint();
    if (currentIndex !== 0 || globalStatus.hidden || !globalStatus.textContent.includes("objetivo general")) {
      throw Error("Una edición inválida debe mantener la ficha y mostrar su error arriba.");
    }
    byId("target").value = "675";
    await list.children[temporaryIndex].onclick();
    if (currentIndex !== temporaryIndex) throw Error("Corregir el dato debe permitir navegar.");
    await deleteRecord("students", temporaryStudent.card.id);
    const initialCalendar = await calendarRequest("calendar");
    await calendarRequest("saveCalendar", { ...initialCalendar, confirmed: true });
    try {
      await calendarRequest("saveExclusion", { title: "Intervalo incorrecto", from: "2026-09-16", to: "2026-09-15" });
      throw Error("Se aceptó un intervalo invertido.");
    } catch (error) {
      if (!String(error).includes("fin igual o posterior")) throw error;
    }
    const cal = await calendarRequest("saveExclusion", {
      title: "Día del piloto", kind: "Centro", from: "2026-09-15", to: "2026-09-15"
    });
    const exclusion = cal.exclusions.find(item => item.title === "Día del piloto");
    showCalendar(cal);
    visibleMonth = firstOfMonth("2026-09-01");
    drawMonth();
    const grid = byId("calendar-days");
    const excludedCell = grid.querySelector('[data-date="2026-09-15"]');
    if (!excludedCell.classList.contains("excluded") || !excludedCell.textContent.includes("Día del piloto") ||
        !grid.querySelector('[data-date="2026-09-19"]').classList.contains("weekend") ||
        grid.querySelector('[data-date="2026-09-16"]').classList.contains("excluded")) {
      throw Error("La cuadrícula debe distinguir los días excluidos, el fin de semana y los días ordinarios.");
    }
    excludedCell.click();
    if (!byId("calendar-day-detail").textContent.includes("Día del piloto")) throw Error("Falta el detalle del día excluido.");
    visibleMonth = firstOfMonth("2026-12-01");
    drawMonth();
    if (!grid.querySelector('[data-date="2026-12-30"].excluded')) throw Error("Falta el tramo de diciembre de Navidad.");
    byId("calendar-next-month").click();
    if (!grid.querySelector('[data-date="2027-01-08"].excluded') ||
        grid.querySelector('[data-date="2027-01-09"].excluded')) throw Error("El intervalo debe continuar en enero hasta su último día incluido.");
    const recalculated = await show(0);
    if (!cal.confirmed || !exclusion || recalculated.elapsed !== assigned.elapsed - 7) {
      throw Error("El nuevo día excluido debe descontarse del cálculo.");
    }
    await calendarRequest("deleteExclusion", { id: exclusion.id });
    if ((await show(0)).elapsed !== assigned.elapsed) throw Error("Eliminar el día debe recuperar sus horas.");
    await changeRecords("undo");
    if ((await show(0)).elapsed !== recalculated.elapsed) throw Error("Deshacer debe recuperar el día excluido.");
    const occupied = await invoke("ficha_accion", { action: "directory" });
    if (assigned.periods[0].tutor !== tutor.id || occupied.companies[0].occupied !== 1) {
      throw Error("La asignación no se reflejó en el cupo de la empresa.");
    }
    const details = await invoke("ficha_accion", { action: "companyDetails", fields: { id: company.id } });
    if (!details.contacts.length || details.contacts[0].saved) throw Error("Falta el seguimiento previsto.");
    const tutorLinks = await invoke("ficha_accion", { action: "tutorLinks", fields: { id: tutor.id } });
    const studentId = assigned.card.id;
    if (!details.links.some(link => link.kind === "students" && link.id === studentId) ||
        !details.links.some(link => link.kind === "tutors" && link.id === tutor.id) ||
        !tutorLinks.some(link => link.kind === "companies" && link.id === company.id) ||
        !tutorLinks.some(link => link.kind === "students" && link.id === studentId)) {
      throw Error("Faltan los enlaces entre alumna, empresa y tutora.");
    }
    for (const [kind, id] of [["companies", company.id], ["tutors", tutor.id]]) {
      try {
        await invoke("ficha_accion", { action: "deleteRecord", kind, fields: { id } });
        throw Error("Se permitió eliminar una ficha vinculada.");
      } catch (error) {
        if (!String(error).includes("Retira primero")) throw error;
      }
    }
    const temporary = await invoke("ficha_accion", { action: "saveDirectory", kind: "tutors", fields: { name: "Tutor temporal" } });
    const temporaryId = temporary.tutors.at(-1).id;
    await deleteRecord("tutors", temporaryId);
    if (tutors.some(item => item.id === temporaryId)) throw Error("La ficha sin vínculos no se eliminó.");
    await changeRecords("undo");
    if (!tutors.some(item => item.id === temporaryId)) throw Error("Deshacer no recuperó la ficha eliminada.");
    await changeRecords("redo");
    await invoke("ficha_accion", { action: "saveDirectory", kind: "companies", fields: {
      ...occupied.companies[0],
      annexEdits: [{ kind: "agreement", id: "receivedCompany", checked: true }],
      contacts: [{ ...details.contacts[0], completed: true, doneOn: "2026-10-02", notes: "Seguimiento de prueba" }]
    } });
    try {
      await invoke("ficha_accion", { action: "saveDirectory", kind: "tutors", fields: { id: tutor.id, company: "" } });
      throw Error("Se permitió cambiar de empresa a una tutora asignada.");
    } catch (error) {
      if (!String(error).includes("Retira las asignaciones")) throw error;
    }
    autoSaveEnabled = true;
    byId("target").value = "700";
    byId("target").dispatchEvent(new Event("input", { bubbles: true }));
    for (let frame = 0; (savedRecord.target !== 700 || saving) && frame < 240; frame++) await paint();
    autoSaveEnabled = false;
    if (savedRecord.target !== 700 || hasPendingChanges() || byId("target").readOnly || saveStatus.textContent) {
      throw Error("El autoguardado debe conservar la edición sin bloquear el campo ni mostrar avisos de guardado.");
    }
    if ((await invoke("ficha", { index: currentIndex })).target !== 700) throw Error("Falta el objetivo autoguardado en el motor.");
    autoSaveEnabled = true;
    const closureDate = sections[0].querySelector(".end").value;
    sections[0].querySelector(".end").value = "";
    sections[0].querySelector(".practice-end").checked = false;
    sections[0].querySelector(".practice-end").dispatchEvent(new Event("change", { bubbles: true }));
    for (let frame = 0; (savedRecord.periods[0].practice[1] || saving) && frame < 240; frame++) await paint();
    if (!savedRecord.periods[0].forecastEnd ||
        sections[0].querySelector(".forecastEnd").textContent !== spanishDate(savedRecord.periods[0].forecastEnd)) {
      throw Error("El autoguardado debe actualizar el fin previsto en la ficha abierta.");
    }
    sections[0].querySelector(".end").value = closureDate;
    sections[0].querySelector(".practice-end").checked = true;
    sections[0].querySelector(".practice-end").dispatchEvent(new Event("change", { bubbles: true }));
    for (let frame = 0; (!savedRecord.periods[0].practice[1] || saving) && frame < 240; frame++) await paint();
    autoSaveEnabled = false;
    if (!savedRecord.periods[0].practice[1] || document.getElementById("save")) {
      throw Error("La ficha debe cerrar el periodo con autoguardado y carecer de botón Guardar ficha.");
    }
    await openDirectory("companies", company.id);
    autoSaveEnabled = true;
    const companyNotes = byId("directory-notes");
    companyNotes.value = "Autoguardado de empresa";
    companyNotes.dispatchEvent(new Event("input", { bubbles: true }));
    for (let frame = 0; (directoryDirty || directoryBusy) && frame < 240; frame++) await paint();
    if (directoryDirty || byId("directory-notes") !== companyNotes || companyNotes.disabled || directoryStatus.textContent ||
        directoryForm.querySelector('button.primary')) throw Error("La empresa debe autoguardarse sin reconstruir el editor ni mostrar Guardar o Guardado.");
    companyNotes.value = "Empresa guardada al navegar";
    companyNotes.dispatchEvent(new Event("input", { bubbles: true }));
    await openDirectory("tutors", tutor.id);
    if (companies.find(item => item.id === company.id).notes !== "Empresa guardada al navegar") throw Error("Navegar debe completar el guardado de empresa.");
    byId("directory-phone").value = "123456789";
    byId("directory-phone").dispatchEvent(new Event("input", { bubbles: true }));
    await byId("students").onclick();
    autoSaveEnabled = false;
    const persistedDirectory = await invoke("ficha_accion", { action: "directory" });
    if (persistedDirectory.tutors.find(item => item.id === tutor.id).phone !== "123456789" ||
        !directory.hidden || globalStatus.textContent || directoryStatus.textContent) throw Error("El tutor debe guardarse al navegar sin dejar mensajes persistentes.");
    if (!await backupRequest("verifyCopies") || !await invoke("ficha_accion", { action: "verifyImport" })) {
      throw Error("No se verificaron las copias y la importación.");
    }
    await invoke("resultado", { report: "Arranque vacío, primera ficha y copias verificadas en el piloto aislado.", success: true });
    return;
  }
  if (!data.cards.length) {
    form.hidden = true;
    measure.hidden = true;
    return;
  }
  if (await invoke("verificar_reapertura")) {
    const index = data.cards.map(card => card.name).lastIndexOf("Alumna creada en la prueba");
    if (index < 0) throw Error("El nuevo arranque no encontró la ficha guardada.");
    const reopened = await show(index);
    if (reopened.secondActive || !reopened.periods[0].practice.every(Boolean)) {
      throw Error("Faltan datos de la ficha tras reiniciar Tauri y C#.");
    }
    if (data.companies.length === 1 && data.companies[0].name === "Empresa del piloto" &&
        (reopened.periods[0].company !== data.companies[0].id ||
         reopened.periods[0].tutor !== data.tutors[0].id || data.companies[0].occupied !== 1)) {
      throw Error("Falta la asignación guardada tras reiniciar el piloto.");
    }
    if (data.companies.length === 1 && data.companies[0].name === "Empresa del piloto") {
      const calendar = await calendarRequest("calendar");
      if (!calendar.confirmed || !calendar.exclusions.some(item => item.title === "Día del piloto")) {
        throw Error("Falta el calendario guardado tras reiniciar.");
      }
      const details = await invoke("ficha_accion", { action: "companyDetails", fields: { id: data.companies[0].id } });
      const steps = details.agreement.filter(step => ["sentCompany", "receivedCompany"].includes(step.id));
      if (!steps.every(step => step.checked && !step.dated) || !details.contacts.some(contact =>
        contact.saved && contact.completed && contact.doneOn === "2026-10-02" && contact.notes === "Seguimiento de prueba")) {
        throw Error("Falta el concierto o el seguimiento tras reiniciar el piloto.");
      }
      const all = await invoke("ficha_accion", { action: "report" });
      const studentReport = await invoke("ficha_accion", { action: "report", kind: "students", fields: { id: reopened.card.id } });
      const companyReport = await invoke("ficha_accion", { action: "report", kind: "companies", fields: { id: data.companies[0].id } });
      if (!all.includes("EMPRESA: Empresa del piloto") || !all.includes("Seguimiento de prueba") ||
          !studentReport.includes("ALUMNA: Alumna creada en la prueba") ||
          !studentReport.includes("Tutor: Tutora del piloto") || studentReport.includes("EMPRESA:") ||
          !companyReport.includes("EMPRESA: Empresa del piloto") || !companyReport.includes("Plazas: 1 / 2")) {
        throw Error("El informe no refleja las fichas recuperadas.");
      }
      await openReport("students", reopened.card.id);
      if (!reportDialog.open || byId("report-text").textContent !== studentReport) {
        throw Error("La vista del informe no coincide con C#.");
      }
      reportDialog.close();
    }
    await invoke("resultado", { report: "Ficha y estado de prácticas verificados tras reiniciar Tauri y C#.", success: true });
    return;
  }
  await show(0);
  if (await invoke("medir_copia")) {
    await benchmarkCopy(data.cards.length);
    return;
  }
  measure.disabled = false;
  for (const button of lifecycleButtons) button.disabled = false;
  if (await invoke("automatico")) await benchmark();
}
start().catch(async error => {
  result.textContent = String(error);
  await invoke("resultado", { report: result.textContent, success: false });
});
