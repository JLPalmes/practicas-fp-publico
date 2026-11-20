# Prácticas FP

Aplicación de escritorio para gestionar alumnas, empresas, tutores, horarios,
seguimiento mensual y documentación de las prácticas de Formación Profesional.
Los datos se guardan localmente, sin cuentas ni servicios en la nube.

## Descargar e instalar


**Versiones estables disponibles**

Mac 2.1.11 y Windows 2.1.10.

- Windows x64, Windows 10 u 11 con Microsoft Edge WebView2. [Descargar instalador Windows](https://github.com/JLPalmes/practicas-fp-publico/releases/download/windows-2.1.10/Instalar-PracticasFP-2.1.10-x64.exe)
- Mac con Apple Silicon, macOS 14 o posterior. [Descargar instalador Mac (.dmg)](https://github.com/JLPalmes/practicas-fp-publico/releases/download/mac-v2.1.11/PracticasFP-2.1.11-AppleSilicon.dmg)

Para recuperar datos anteriores, exporta una copia desde la versión 1 y restáurala en la 2. La versión 2 usa su propia carpeta de datos. Consulta la [guía de Windows](Windows/LEEME.md).

## Código y compilación

- Windows x64: ejecuta `powershell -NoProfile -ExecutionPolicy Bypass -File Windows\Compilar-Tauri.ps1 -Verificar` para generar y verificar el instalador y su archivo de fuentes. Requiere WebView2. Consulta el [registro de desarrollo](Experimentos/README.md).
- La publicación automatizada compila Windows, ejecuta las pruebas y adjunta el instalador, la licencia y sus sumas SHA-256 a una versión de GitHub. El código fuente correspondiente se conserva en la etiqueta de esa publicación.

## Licencia

Copyright © 2026 Juan Luis (JLPalmes).
Código, documentación y recursos propios bajo **GNU AGPL versión 3 exclusivamente**
(`AGPL-3.0-only`). Consulta [LICENSE](LICENSE) y [el aviso](AVISO-LICENCIA.txt).
Este programa se distribuye sin garantía.

[Procedimiento de actualización y publicación](ACTUALIZACIONES.md).
