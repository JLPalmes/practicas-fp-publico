// SPDX-License-Identifier: AGPL-3.0-only
async function iniciarActualizaciones() {
  if (!await invoke("actualizaciones_disponibles").catch(() => false)) return;

  const buscar = byId("buscar-actualizaciones");
  const dialogo = byId("actualizacion");
  const titulo = byId("actualizacion-titulo");
  const fecha = byId("actualizacion-fecha");
  const notas = byId("actualizacion-notas");
  const estado = byId("actualizacion-estado");
  const instalar = byId("actualizacion-instalar");
  const cerrar = byId("actualizacion-cerrar");
  const ultimaBusqueda = "actualizaciones.ultimaBusqueda";
  let ocupado = false;

  async function comprobar(manual) {
    if (ocupado) return;
    ocupado = true;
    buscar.disabled = true;
    titulo.textContent = "Actualizaciones";
    fecha.textContent = notas.textContent = "";
    instalar.hidden = true;
    cerrar.textContent = "Cerrar";
    estado.textContent = "Buscando actualizaciones…";
    if (manual) dialogo.showModal();
    try {
      localStorage.setItem(ultimaBusqueda, String(Date.now()));
      const resultado = await invoke("buscar_actualizacion");
      if (!resultado) {
        estado.textContent = "Ya tienes la última versión.";
        return;
      }
      titulo.textContent = "Prácticas FP " + resultado.version;
      fecha.textContent = resultado.fecha ?? "";
      notas.textContent = resultado.notas ?? "";
      estado.textContent = "Al abrirse el instalador se cerrará Prácticas FP.";
      instalar.hidden = false;
      cerrar.textContent = "Posponer";
      if (!manual) buscar.textContent = "Actualización disponible";
    } catch (error) {
      estado.textContent = String(error);
    } finally {
      ocupado = false;
      buscar.disabled = false;
    }
  }

  buscar.onclick = () => {
    if (!instalar.hidden) dialogo.showModal();
    else return comprobar(true);
  };
  cerrar.onclick = () => dialogo.close();
  instalar.onclick = async () => {
    if (ocupado) return;
    if (saving || reportBusy || backupBusy || !canLeaveFicha() ||
        (!directory.hidden && !canLeaveDirectory()) ||
        (!calendarDialog.hidden && !calendarCanLeave())) {
      estado.textContent = "Guarda o descarta los cambios pendientes antes de instalar.";
      return;
    }
    ocupado = true;
    instalar.disabled = cerrar.disabled = true;
    estado.textContent = "Descargando y verificando el instalador…";
    try {
      await invoke("instalar_actualizacion");
    } catch (error) {
      estado.textContent = String(error);
      instalar.hidden = true;
      buscar.textContent = "Buscar actualizaciones…";
    } finally {
      ocupado = false;
      instalar.disabled = cerrar.disabled = false;
    }
  };
  dialogo.addEventListener("cancel", event => {
    if (instalar.disabled) event.preventDefault();
  });
  buscar.hidden = false;
  if (Date.now() - Number(localStorage.getItem(ultimaBusqueda)) >= 86400000) {
    void comprobar(false);
  }
}
