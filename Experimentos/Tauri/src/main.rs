#![cfg_attr(all(windows, feature = "distribucion"), windows_subsystem = "windows")]

use serde_json::{json, Value};
use std::io::{BufRead, BufReader, Write};
use std::process::{Child, ChildStdin, ChildStdout, Command, Stdio};
use std::sync::{Arc, Mutex};
use tauri::Manager;

struct Motor {
    child: Child,
    input: Option<ChildStdin>,
    output: BufReader<ChildStdout>,
    names: Value,
}

impl Motor {
    fn start() -> Result<Self, Box<dyn std::error::Error>> {
        #[cfg(feature = "distribucion")]
        let executable = std::env::current_exe()?.with_file_name("motor.exe");
        #[cfg(not(feature = "distribucion"))]
        let executable = concat!(env!("CARGO_MANIFEST_DIR"), "/motor.exe");
        let mut command = Command::new(executable);
        #[cfg(all(windows, feature = "distribucion"))]
        {
            use std::os::windows::process::CommandExt;
            command.creation_flags(0x08000000); // CREATE_NO_WINDOW
        }
        command.arg("--motor");
        if cfg!(feature = "distribucion") && !automatico()
            || std::env::args().any(|arg| {
                matches!(
                    arg.as_str(),
                    "--piloto" | "--verificar-piloto" | "--verificar-reapertura-piloto"
                )
            })
        {
            command.arg("--piloto");
        }
        if let Ok(session) = std::env::var("PRACTICAS_FP_TEST_SESSION") {
            command.arg(session);
        }
        let mut child = command
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .spawn()?;
        let input = child.stdin.take().expect("stdin");
        let output = BufReader::new(child.stdout.take().expect("stdout"));
        let mut motor = Self {
            child,
            input: Some(input),
            output,
            names: Value::Null,
        };
        motor.names = motor.read()?;
        Ok(motor)
    }

    fn read(&mut self) -> Result<Value, Box<dyn std::error::Error>> {
        let mut line = String::new();
        self.output.read_line(&mut line)?;
        Ok(serde_json::from_str(&line)?)
    }

    fn request(&mut self, command: Value) -> Result<Value, String> {
        let input = self.input.as_mut().ok_or("El motor está cerrado")?;
        writeln!(input, "{command}").map_err(|e| e.to_string())?;
        input.flush().map_err(|e| e.to_string())?;
        let response = self.read().map_err(|e| e.to_string())?;
        if let Some(error) = response["error"].as_str() {
            return Err(error.to_owned());
        }
        Ok(response["data"].clone())
    }

    fn stop(&mut self) {
        drop(self.input.take());
        let _ = self.child.wait();
    }
}

impl Drop for Motor {
    fn drop(&mut self) {
        self.stop();
    }
}

#[tauri::command]
fn alumnas(motor: tauri::State<Arc<Mutex<Motor>>>) -> Result<Value, String> {
    Ok(motor.lock().map_err(|e| e.to_string())?.names.clone())
}

#[tauri::command]
fn ficha(index: usize, motor: tauri::State<Arc<Mutex<Motor>>>) -> Result<Value, String> {
    motor
        .lock()
        .map_err(|e| e.to_string())?
        .request(json!({"index":index}))
}

#[tauri::command]
async fn guardar(
    index: usize,
    fields: Value,
    motor: tauri::State<'_, Arc<Mutex<Motor>>>,
) -> Result<Value, String> {
    let worker = Arc::clone(motor.inner());
    tauri::async_runtime::spawn_blocking(move || {
        worker.lock().map_err(|e| e.to_string())?.request(json!({
            "action":"save","index":index,"fields":fields
        }))
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
async fn ficha_accion(
    window: tauri::WebviewWindow,
    action: String,
    kind: Option<String>,
    fields: Option<Value>,
    motor: tauri::State<'_, Arc<Mutex<Motor>>>,
) -> Result<Value, String> {
    #[cfg(windows)]
    let owner = window.hwnd().map_err(|error| error.to_string())?.0 as usize;
    #[cfg(not(windows))]
    let owner = 0usize;
    let worker = Arc::clone(motor.inner());
    tauri::async_runtime::spawn_blocking(move || {
        worker
            .lock()
            .map_err(|e| e.to_string())?
            .request(json!({"action":action,"kind":kind,"fields":fields,"owner":owner.to_string()}))
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
fn automatico() -> bool {
    if verificar_piloto() || verificar_reapertura() {
        return true;
    }
    std::env::args()
        .any(|arg| arg == "--medir" || arg == "--verificar-reapertura" || arg == "--medir-copia")
}

#[tauri::command]
fn edicion_distribuida() -> bool {
    cfg!(feature = "distribucion")
}

#[tauri::command]
fn medir_copia() -> bool {
    std::env::args().any(|arg| arg == "--medir-copia")
}
#[tauri::command]
fn verificar_reapertura() -> bool {
    std::env::args().any(|arg| {
        matches!(
            arg.as_str(),
            "--verificar-reapertura" | "--verificar-reapertura-piloto"
        )
    })
}

#[tauri::command]
fn verificar_piloto() -> bool {
    std::env::args().any(|arg| arg == "--verificar-piloto")
}

#[tauri::command]
fn probar_cierre(window: tauri::WebviewWindow) -> Result<(), String> {
    if !automatico() {
        return Err("La solicitud está reservada a la prueba automática.".into());
    }
    window.close().map_err(|error| error.to_string())
}
#[tauri::command]
fn resultado(app: tauri::AppHandle, window: tauri::WebviewWindow, report: String, success: bool) {
    if automatico() {
        println!("{report}");
        if success && verificar_reapertura() {
            if let Err(error) = window.close() {
                eprintln!("No se pudo cerrar la ventana: {error}");
                app.exit(1);
            }
        } else {
            app.exit(if success { 0 } else { 1 });
        }
    }
}

fn main() {
    tauri::Builder::default()
        .manage(Arc::new(Mutex::new(
            Motor::start().expect("Inicia el motor C# del prototipo"),
        )))
        .invoke_handler(tauri::generate_handler![
            alumnas,
            ficha,
            guardar,
            ficha_accion,
            automatico,
            edicion_distribuida,
            medir_copia,
            verificar_reapertura,
            verificar_piloto,
            probar_cierre,
            resultado
        ])
        .build(tauri::generate_context!())
        .expect("Inicia el prototipo Tauri")
        .run(|app, event| {
            if matches!(event, tauri::RunEvent::Exit) {
                if let Ok(mut motor) = app.state::<Arc<Mutex<Motor>>>().lock() {
                    motor.stop();
                }
            }
        });
}
