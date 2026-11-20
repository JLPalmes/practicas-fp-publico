const reportDialog = byId("report-dialog");
const reportStatus = byId("report-status");
let reportBusy = false;
let reportRequest;

async function openReport(kind = "", id = "") {
  if (reportBusy || !await canNavigate()) return;
  reportBusy = true;
  const status = !directory.hidden ? directoryStatus : !calendarDialog.hidden ? calendarStatus : saveStatus;
  try {
    const fields = { id };
    const text = await invoke("ficha_accion", { action: "report", kind, fields });
    reportRequest = { kind, fields };
    byId("report-text").textContent = text;
    reportStatus.textContent = "";
    reportDialog.showModal();
  } catch (error) {
    status.textContent = String(error);
  } finally {
    reportBusy = false;
  }
}

async function runReportOutput(action) {
  if (reportBusy || !reportRequest) return;
  reportBusy = true;
  const buttons = Array.from(reportDialog.querySelectorAll("button"));
  for (const button of buttons) button.disabled = true;
  try {
    const completed = await invoke("ficha_accion", { action, ...reportRequest });
    reportStatus.textContent = completed ? (action === "saveReport" ? "Informe guardado." : "Informe enviado a imprimir.") : "";
  } catch (error) {
    reportStatus.textContent = String(error);
  } finally {
    for (const button of buttons) button.disabled = false;
    reportBusy = false;
  }
}

byId("reports").onclick = () => openReport();
byId("student-report").onclick = () => {
  const id = list.children[currentIndex]?.dataset.id;
  if (id) openReport("students", id);
};
byId("company-report").onclick = () => openReport("companies", directorySelection.value);
byId("report-save").onclick = () => runReportOutput("saveReport");
byId("report-print").onclick = () => runReportOutput("printReport");
byId("report-close").onclick = () => { if (!reportBusy) reportDialog.close(); };
reportDialog.oncancel = event => { if (reportBusy) event.preventDefault(); };
