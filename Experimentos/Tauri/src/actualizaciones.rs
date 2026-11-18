// SPDX-License-Identifier: AGPL-3.0-only
use semver::Version;
use serde_json::{json, Value};
use std::{sync::Mutex, time::Duration};
use tauri::{AppHandle, State};
use tauri_plugin_updater::{Error, Update, UpdaterExt};

const CLAVE: Option<&str> = option_env!("PRACTICASFP_TAURI_PUBLIC_KEY");
const CATALOGO: &str = "https://github.com/JLPalmes/practicas-fp-publico/releases/download/actualizaciones-windows/latest.json";

#[tauri::command]
pub fn actualizaciones_disponibles() -> bool {
    cfg!(feature = "distribucion")
        && !super::automatico()
        && CLAVE.is_some_and(|clave| !clave.trim().is_empty())
}

#[tauri::command]
pub async fn buscar_actualizacion(
    app: AppHandle,
    disponible: State<'_, Mutex<Option<Update>>>,
) -> Result<Option<Value>, String> {
    let clave = CLAVE
        .filter(|_| actualizaciones_disponibles())
        .ok_or("La búsqueda de actualizaciones no está configurada.")?;
    let url = option_env!("PRACTICASFP_TAURI_FEED").unwrap_or(CATALOGO);
    let catalogo = url
        .parse()
        .map_err(|_| "El catálogo de actualizaciones no es válido.")?;
    let actualizacion = app
        .updater_builder()
        .endpoints(vec![catalogo])
        .map_err(|_| "El catálogo debe utilizar HTTPS.")?
        .pubkey(clave)
        .timeout(Duration::from_secs(30))
        .restart_after_install(false)
        .version_comparator(|actual, publicada| version_admitida(&actual, &publicada.version))
        .build()
        .map_err(|_| "No se pudo iniciar el actualizador.")?
        .check()
        .await
        .map_err(|error| {
            eprintln!("{error}");
            match error {
                Error::TargetNotFound(_) | Error::TargetsNotFound(_) => {
                    "El catálogo no ofrece un paquete compatible con Windows x64."
                }
                _ => {
                    "No se pudo consultar el catálogo. Comprueba la conexión y vuelve a intentarlo."
                }
            }
        })?;
    let resumen = actualizacion.as_ref().map(|update| {
        json!({
            "version": update.version,
            "fecha": update.date.map(|date| date.date().to_string()),
            "notas": update.body,
        })
    });
    *disponible
        .lock()
        .map_err(|_| "No se pudo guardar la actualización disponible.")? = actualizacion;
    Ok(resumen)
}

#[tauri::command]
pub async fn instalar_actualizacion(
    disponible: State<'_, Mutex<Option<Update>>>,
) -> Result<(), String> {
    let mut update = disponible
        .lock()
        .map_err(|_| "No se pudo recuperar la actualización.")?
        .take()
        .ok_or("Busca de nuevo la actualización antes de instalarla.")?;
    update.timeout = Some(Duration::from_secs(300));
    let paquete = update.download(|_, _| {}, || {}).await.map_err(|error| {
        eprintln!("{error}");
        match error {
            Error::Minisign(_) | Error::Base64(_) | Error::SignatureUtf8(_)
            | Error::SignedVersionMismatch { .. } | Error::MissingSignedVersion => {
                "La firma o la versión del paquete no es válida. No se ha instalado la actualización."
            }
            _ => "No se pudo completar la descarga. Comprueba la conexión y vuelve a intentarlo.",
        }
    })?;
    if !es_ejecutable_x64(&paquete) {
        return Err("El paquete no es un instalador compatible con Windows x64.".into());
    }
    update.install(paquete).map_err(|error| {
        eprintln!("{error}");
        "Windows no pudo abrir el instalador. Busca de nuevo la actualización para reintentar."
            .into()
    })
}

fn version_admitida(actual: &Version, publicada: &Version) -> bool {
    publicada.pre.is_empty() && publicada.cmp_precedence(actual).is_gt()
}

fn es_ejecutable_x64(paquete: &[u8]) -> bool {
    if !paquete.starts_with(b"MZ") {
        return false;
    }
    let Some(offset) = paquete.get(60..64) else {
        return false;
    };
    let offset = u32::from_le_bytes(offset.try_into().expect("Cuatro bytes")) as usize;
    paquete
        .get(offset..)
        .is_some_and(|pe| pe.starts_with(b"PE\0\0\x64\x86"))
}

#[cfg(test)]
mod tests {
    use super::{es_ejecutable_x64, version_admitida, Version};

    #[test]
    fn solo_admite_versiones_estables_superiores() {
        let actual = Version::parse("2.1.9").unwrap();
        for version in ["2.1.9", "2.1.8", "2.1.9+otra-compilacion", "2.1.10-beta.1"] {
            assert!(!version_admitida(
                &actual,
                &Version::parse(version).unwrap()
            ));
        }
        assert!(version_admitida(
            &actual,
            &Version::parse("2.1.10").unwrap()
        ));
    }

    #[test]
    fn descarta_paquetes_truncados_y_otras_arquitecturas() {
        let mut bytes = [0; 70];
        bytes[..2].copy_from_slice(b"MZ");
        bytes[60] = 64;
        bytes[64..].copy_from_slice(b"PE\0\0\x64\x86");
        assert!(es_ejecutable_x64(&bytes));
        assert!(!es_ejecutable_x64(&bytes[..69]));
        bytes[68..].copy_from_slice(b"\x64\xaa");
        assert!(!es_ejecutable_x64(&bytes));
        bytes[60..64].fill(255);
        assert!(!es_ejecutable_x64(&bytes));
    }
}
