const calendarDialog = byId("calendar-dialog");
const calendarForm = byId("calendar-form");
const exclusionForm = byId("exclusion-form");
const exclusionPicker = byId("exclusion-picker");
const calendarStatus = byId("calendar-status");
const calendarDiscard = byId("calendar-discard");
let calendarData;
let exclusionId = "";
let calendarBusy = false;
let visibleMonth;
let selectedDay;
const calendarEdits = new Set();
const calendarRequest = (action, fields) => invoke("ficha_accion", { action, fields });
const monthTitle = new Intl.DateTimeFormat("es-ES", { month: "long", year: "numeric", timeZone: "UTC" });
const fullDay = new Intl.DateTimeFormat("es-ES", { dateStyle: "full", timeZone: "UTC" });
const courseToday = new Intl.DateTimeFormat("sv-SE", { timeZone: "Atlantic/Canary" }).format(new Date());
const dateKey = date => date.toISOString().slice(0, 10);
const firstOfMonth = date => new Date(date.slice(0, 7) + "-01T00:00:00Z");

function dayExclusions(day) {
  return calendarData.exclusions.filter(item => item.from <= day && item.to >= day);
}

function showDayDetail(day) {
  const detail = byId("calendar-day-detail");
  detail.hidden = !day;
  detail.replaceChildren();
  if (!day) return;
  const date = new Date(day + "T00:00:00Z");
  const exclusions = dayExclusions(day);
  const weekend = date.getUTCDay() === 0 || date.getUTCDay() === 6;
  const label = document.createElement("strong");
  label.textContent = fullDay.format(date);
  detail.append(label);
  if (weekend || exclusions.length) {
    if (weekend) detail.append(" · Fin de semana");
    for (const item of exclusions) {
      const button = document.createElement("button");
      button.type = "button";
      button.textContent = item.title || "Día excluido";
      button.onclick = () => { if (chooseExclusion(item.id)) exclusionForm.scrollIntoView({ block: "nearest" }); };
      detail.append(button);
    }
  } else detail.append(" · Sin exclusiones");
}

function drawMonth() {
  const days = byId("calendar-days");
  const year = visibleMonth.getUTCFullYear();
  const month = visibleMonth.getUTCMonth();
  byId("calendar-month-title").textContent = monthTitle.format(visibleMonth);
  days.replaceChildren();
  for (let i = 0; i < (visibleMonth.getUTCDay() + 6) % 7; i++) {
    const space = document.createElement("span");
    space.setAttribute("aria-hidden", "true");
    days.append(space);
  }
  const count = new Date(Date.UTC(year, month + 1, 0)).getUTCDate();
  for (let day = 1; day <= count; day++) {
    const date = new Date(Date.UTC(year, month, day));
    const key = dateKey(date);
    const exclusions = dayExclusions(key);
    const weekend = date.getUTCDay() === 0 || date.getUTCDay() === 6;
    const notes = exclusions.map(item => item.title || "Día excluido");
    if (weekend) notes.push("Fin de semana");
    const button = document.createElement("button");
    button.type = "button";
    button.className = "month-day";
    button.dataset.date = key;
    button.classList.toggle("excluded", exclusions.length > 0);
    button.classList.toggle("weekend", weekend);
    button.setAttribute("aria-label", [fullDay.format(date), ...notes].join(" · "));
    button.setAttribute("aria-pressed", String(key === selectedDay));
    if (key === courseToday) button.setAttribute("aria-current", "date");
    const number = document.createElement("strong");
    number.textContent = day;
    button.append(number);
    if (exclusions.length) {
      const name = document.createElement("span");
      name.textContent = exclusions[0].title || "Día excluido";
      button.append(name);
    }
    if (notes.length) button.title = notes.join(" · ");
    button.onclick = () => {
      for (const active of days.querySelectorAll('[aria-pressed="true"]')) active.setAttribute("aria-pressed", "false");
      button.setAttribute("aria-pressed", "true");
      selectedDay = key;
      showDayDetail(key);
    };
    days.append(button);
  }
  showDayDetail(selectedDay?.startsWith(dateKey(visibleMonth).slice(0, 7)) ? selectedDay : null);
}

function changeMonth(delta) {
  visibleMonth.setUTCMonth(visibleMonth.getUTCMonth() + delta);
  drawMonth();
}
byId("calendar-previous-month").onclick = () => changeMonth(-1);
byId("calendar-next-month").onclick = () => changeMonth(1);

function calendarCanLeave() {
  if (calendarBusy) return false;
  if (!calendarEdits.size) return true;
  calendarStatus.textContent = "Guarda o descarta los cambios pendientes.";
  calendarDiscard.hidden = false;
  return false;
}

function showExclusion(id) {
  const item = calendarData.exclusions.find(record => record.id === id);
  exclusionId = item?.id ?? "";
  exclusionPicker.value = exclusionId;
  for (const key of ["title", "kind", "from", "to"]) exclusionForm.elements[key].value = item?.[key] ?? "";
  byId("exclusion-delete").hidden = !item;
  byId("exclusion-save").textContent = item ? "Guardar día o intervalo" : "Añadir día o intervalo";
  byId("exclusion-heading").textContent = item?.title || (item ? "Día o intervalo" : "Nuevo día o intervalo");
  byId("calendar-list").replaceChildren(...calendarData.exclusions.map(record => {
    const button = document.createElement("button");
    button.type = "button";
    const title = document.createElement("strong");
    title.textContent = record.title || "Día o intervalo";
    const dates = document.createElement("span");
    const format = date => date.split("-").reverse().join("/");
    dates.textContent = format(record.from) + (record.from === record.to ? "" : " – " + format(record.to));
    button.append(title, dates);
    if (record.id === exclusionId) button.setAttribute("aria-current", "true");
    button.onclick = () => {
      if (!chooseExclusion(record.id)) return;
      visibleMonth = firstOfMonth(record.from);
      selectedDay = record.from;
      drawMonth();
    };
    return button;
  }));
}

function showCalendar(data, id = "") {
  calendarData = data;
  if (!visibleMonth) visibleMonth = firstOfMonth(courseToday < data.from ? data.from : courseToday > data.to ? data.to : courseToday);
  calendarEdits.clear();
  calendarDiscard.hidden = true;
  calendarForm.elements.from.value = data.from;
  calendarForm.elements.to.value = data.to;
  calendarForm.elements.confirmed.checked = data.confirmed;
  exclusionPicker.replaceChildren(new Option("Nuevo día o intervalo", ""));
  for (const item of data.exclusions) {
    exclusionPicker.add(new Option(item.from + " · " + (item.title || "Día o intervalo"), item.id));
  }
  showExclusion(id);
  drawMonth();
}

async function updateCalendar(action, fields) {
  if (calendarBusy) return;
  calendarBusy = true;
  const controls = Array.from(calendarDialog.querySelectorAll("input, select, button"));
  for (const control of controls) control.disabled = true;
  try {
    const previous = new Set(calendarData.exclusions.map(item => item.id));
    const data = await calendarRequest(action, fields);
    const created = action === "saveExclusion" && !fields.id ? data.exclusions.find(item => !previous.has(item.id)) : null;
    showCalendar(data, action === "deleteExclusion" ? "" : created?.id ?? exclusionId);
    if (action === "saveExclusion") {
      visibleMonth = firstOfMonth(fields.from);
      selectedDay = fields.from;
      drawMonth();
    }
    if (currentIndex !== undefined) await show(currentIndex);
    calendarStatus.textContent = action === "deleteExclusion" ? "Intervalo eliminado." : "Guardado.";
  } catch (error) {
    calendarStatus.textContent = String(error);
  } finally {
    for (const control of controls) control.disabled = false;
    calendarBusy = false;
  }
}

for (const editor of [calendarForm, exclusionForm]) {
  editor.addEventListener("input", () => calendarEdits.add(editor));
}
function chooseExclusion(id) {
  if (calendarBusy) return false;
  if (calendarEdits.has(exclusionForm) && !calendarCanLeave()) {
    exclusionPicker.value = exclusionId;
    return false;
  }
  showExclusion(id);
  return true;
}
exclusionPicker.onchange = () => chooseExclusion(exclusionPicker.value);
byId("calendar-create").onclick = () => chooseExclusion("");
calendarForm.onsubmit = event => {
  event.preventDefault();
  if (calendarEdits.has(exclusionForm)) { calendarCanLeave(); return; }
  updateCalendar("saveCalendar", {
    ...Object.fromEntries(new FormData(calendarForm)),
    confirmed: calendarForm.elements.confirmed.checked
  });
};
exclusionForm.onsubmit = event => {
  event.preventDefault();
  if (calendarEdits.has(calendarForm)) { calendarCanLeave(); return; }
  updateCalendar("saveExclusion", { ...Object.fromEntries(new FormData(exclusionForm)), id: exclusionId });
};
byId("exclusion-delete").onclick = async () => {
  if (!calendarCanLeave() || !exclusionId || !await confirmDelete()) return;
  await updateCalendar("deleteExclusion", { id: exclusionId });
};
calendarDiscard.onclick = () => { if (!calendarBusy) showCalendar(calendarData, exclusionId); };
byId("calendar").onclick = async () => {
  if (!await canNavigate() || calendarBusy || !calendarDialog.hidden) return;
  calendarBusy = true;
  try {
    showCalendar(await calendarRequest("calendar"));
    calendarStatus.textContent = "";
    navigateWorkspace("calendar");
  } catch (error) {
    saveStatus.textContent = String(error);
  } finally {
    calendarBusy = false;
  }
};
