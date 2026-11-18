# Prácticas FP

Aplicación de escritorio para gestionar alumnas, empresas, tutores, horarios,
seguimiento mensual y documentación de las prácticas de Formación Profesional.
Los datos se guardan localmente, sin cuentas ni servicios en la nube.

## Descargar e instalar


**Versiones estables disponibles**

Mac 2.1.11 y Windows 2.1.3.

- Windows x64, Windows 10 u 11 con Microsoft Edge WebView2. [Descargar instalador Windows](https://github.com/JLPalmes/practicas-fp-publico/releases/download/tauri-v2.1.3/Instalar-PracticasFP-Tauri-2.1.3-x64.exe)
- Mac con Apple Silicon, macOS 14 o posterior. [Descargar instalador Mac (.dmg)](https://github.com/JLPalmes/practicas-fp-publico/releases/download/mac-v2.1.11/PracticasFP-2.1.11-AppleSilicon.dmg)

[Descargar la edición anterior 2.0.3 (WinForms)](https://github.com/JLPalmes/practicas-fp-publico/releases/tag/v2.0.3)

Para recuperar datos anteriores, exporta una copia desde la versión 1 y restáurala en la 2. La versión 2 usa su propia carpeta de datos. Consulta la [guía de Windows](Windows/LEEME.md).

## Código y compilación

- Windows: ejecuta `powershell -NoProfile -ExecutionPolicy Bypass -File Windows\Compilar.ps1`; compila y ejecuta las pruebas antes de generar el instalador.
- **Prácticas FP Tauri 2.1.3 para Windows x64**: ejecuta `powershell -NoProfile -ExecutionPolicy Bypass -File Windows\Compilar-Tauri.ps1 -Verificar` para generar y verificar el instalador y su archivo de fuentes. Esta edición requiere WebView2 y usa su propia carpeta de datos. Consulta el [registro de desarrollo de Tauri](Experimentos/README.md).
- La publicación automatizada compila Windows, ejecuta las pruebas y adjunta el instalador, la licencia y sus sumas SHA-256 a una versión de GitHub. El código fuente correspondiente se conserva en la etiqueta de esa publicación.

## Licencia

Copyright © 2026 Juan Luis (JLPalmes).
Código, documentación y recursos propios bajo **GNU AGPL versión 3 exclusivamente**
(`AGPL-3.0-only`). Consulta [LICENSE](LICENSE) y [el aviso](AVISO-LICENCIA.txt).
Este programa se distribuye sin garantía.

[Procedimiento de actualización y publicación](ACTUALIZACIONES.md).
