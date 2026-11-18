// SPDX-License-Identifier: AGPL-3.0-only
const { test } = require("node:test");
const assert = require("node:assert/strict");
const { readFileSync } = require("node:fs");
const { runInNewContext } = require("node:vm");

const script = readFileSync(new URL("../Experimentos/Tauri/ui/actualizaciones.js", `file://${__filename}`), "utf8");
const dia = 86400000;
const version = { version: "2.1.5", fecha: "2026-11-18", notas: "Novedades de prueba" };

async function escenario({ hace = dia, resultado = version, problema, falloInstalacion, pendiente } = {}) {
  const elementos = new Map();
  const elemento = id => {
    if (!elementos.has(id)) {
      elementos.set(id, {
        hidden: true, textContent: "Buscar actualizaciones…", open: false,
        showModal() { this.open = true; },
        close() { this.open = false; },
        addEventListener() {}
      });
    }
    return elementos.get(id);
  };
  const llamadas = [];
  const contexto = {
    byId: elemento,
    invoke: async accion => {
      llamadas.push(accion);
      if (accion === "actualizaciones_disponibles") return true;
      if (accion === "buscar_actualizacion") {
        if (problema) throw problema;
        return resultado;
      }
      if (falloInstalacion) throw falloInstalacion;
    },
    localStorage: { getItem: () => String(Date.now() - hace), setItem() {} },
    saving: false, reportBusy: false, backupBusy: false,
    canLeaveFicha: () => !pendiente,
    directory: { hidden: true }, calendarDialog: { hidden: true }
  };
  await runInNewContext(script + "\niniciarActualizaciones()", contexto);
  return { elemento, llamadas };
}

test("respeta 24 horas y permite una consulta manual", async () => {
  const { elemento, llamadas } = await escenario({ hace: 1000, resultado: null });
  assert.deepEqual(llamadas, ["actualizaciones_disponibles"]);
  await elemento("buscar-actualizaciones").onclick();
  assert.equal(elemento("actualizacion-estado").textContent, "Ya tienes la última versión.");
});

test("avisa sin bloquear y permite posponer la versión", async () => {
  const { elemento, llamadas } = await escenario();
  assert.equal(elemento("buscar-actualizaciones").textContent, "Actualización disponible");
  assert.equal(elemento("actualizacion").open, false);
  await elemento("buscar-actualizaciones").onclick();
  assert.equal(elemento("actualizacion-titulo").textContent, "Prácticas FP 2.1.5");
  assert.equal(elemento("actualizacion-fecha").textContent, version.fecha);
  assert.equal(elemento("actualizacion-notas").textContent, version.notas);
  elemento("actualizacion-cerrar").onclick();
  assert.equal(elemento("actualizacion").open, false);
  assert.ok(!llamadas.includes("instalar_actualizacion"));
});

test("muestra el fallo de conexión tras una consulta manual", async () => {
  const { elemento } = await escenario({ hace: 1000, problema: "Sin conexión" });
  await elemento("buscar-actualizaciones").onclick();
  assert.equal(elemento("actualizacion-estado").textContent, "Sin conexión");
});

test("protege cambios pendientes y muestra errores de descarga o firma", async () => {
  const pendiente = await escenario({ pendiente: true });
  await pendiente.elemento("actualizacion-instalar").onclick();
  assert.ok(!pendiente.llamadas.includes("instalar_actualizacion"));
  for (const error of ["Descarga interrumpida", "Firma inválida"]) {
    const fallo = await escenario({ falloInstalacion: error });
    await fallo.elemento("actualizacion-instalar").onclick();
    assert.equal(fallo.elemento("actualizacion-estado").textContent, error);
    assert.ok(fallo.elemento("actualizacion-instalar").hidden);
  }
});
