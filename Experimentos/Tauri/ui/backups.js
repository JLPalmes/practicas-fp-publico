const backupDialog = byId("backup-dialog");
const courseForm = byId("course-form");
const backupStatus = byId("backup-status");
const backupPreview = byId("backup-preview");
let backupBusy = false;
let courseInfo;
const backupRequest = (action, fields) => invoke("ficha_accion", { action, fields });

function showCourse(info) {
  courseInfo = info;
  courseForm.elements.institute.value = info.institute;
  courseForm.elements.course.value = info.course;
  byId("backup-discard").hidden = true;
}

function backupCanLeave() {
  if (backupBusy) return false;
  if (courseInfo && (courseForm.elements.institute.value !== courseInfo.institute ||
      courseForm.elements.course.value !== courseInfo.course)) {
    backupStatus.textContent = "Guarda o descarta los cambios del curso.";
    byId("backup-discard").hidden = false;
    return false;
  }
  return true;
}

async function runBackup(action) {
  if (backupBusy) return;
  backupBusy = true;
  const fields = action === "saveCourse" ? Object.fromEntries(new FormData(courseForm)) : undefined;
  const controls = Array.from(backupDialog.querySelectorAll("input, button"));
  for (const control of controls) control.disabled = true;
  try {
    const data = await backupRequest(action, fields);
    backupStatus.textContent = "";
    if (action === "saveCourse") {
      showCourse(data);
      backupStatus.textContent = "Datos del curso guardados.";
    } else if (action === "exportCourse" && data) {
      backupStatus.textContent = "Copia guardada y verificada.";
    } else if (action === "selectRestore") {
      backupPreview.hidden = !data;
      if (data) byId("backup-summary").textContent =
        data.institute + " · " + data.course + " · " + data.students + " alumnas, " +
        data.companies + " empresas y " + data.tutors + " tutores";
    } else if (action === "applyRestore") {
      backupPreview.hidden = true;
      currentIndex = undefined;
      await useDirectory("restore", data);
      showCourse(await backupRequest("backupInfo"));
      backupStatus.textContent = "Copia restaurada.";
    } else if (action === "cancelRestore") backupPreview.hidden = true;
  } catch (error) {
    backupStatus.textContent = String(error);
  } finally {
    for (const control of controls) control.disabled = false;
    backupBusy = false;
  }
}

byId("backups").onclick = async () => {
  if (backupBusy || !await canNavigate()) return;
  backupBusy = true;
  try {
    showCourse(await backupRequest("backupInfo"));
    await backupRequest("cancelRestore");
    backupPreview.hidden = true;
    backupStatus.textContent = "";
    backupDialog.showModal();
  } catch (error) { saveStatus.textContent = String(error); }
  finally { backupBusy = false; }
};
courseForm.onsubmit = event => { event.preventDefault(); runBackup("saveCourse"); };
byId("backup-export").onclick = () => { if (backupCanLeave()) runBackup("exportCourse"); };
byId("backup-select").onclick = () => { if (backupCanLeave()) runBackup("selectRestore"); };
byId("backup-apply").onclick = () => { if (backupCanLeave()) runBackup("applyRestore"); };
byId("backup-cancel").onclick = () => runBackup("cancelRestore");
byId("backup-discard").onclick = () => { if (!backupBusy) showCourse(courseInfo); };
byId("backup-close").onclick = () => { if (backupCanLeave()) backupDialog.close(); };
backupDialog.oncancel = event => { if (!backupCanLeave()) event.preventDefault(); };
