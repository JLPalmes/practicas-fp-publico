# Prácticas FP

Aplicación de escritorio para gestionar alumnas, empresas, tutores, horarios,
seguimiento mensual y documentación de las prácticas de Formación Profesional.
Los datos se guardan localmente, sin cuentas ni servicios en la nube.

## Descargar e instalar


La versión vigente es **Prácticas FP 2.0.0 para Windows x64**. Requiere Windows 10 u 11 y se recomienda .NET Framework 4.8.

[Descargar Prácticas FP 2](https://github.com/JLPalmes/practicas-fp-publico/releases/latest)

Para recuperar datos anteriores, exporta una copia desde la versión 1 y restáurala en la 2. La versión 2 usa su propia carpeta de datos. Consulta la [guía de Windows](Windows/LEEME.md).

## Código y compilación

- Windows: ejecuta `powershell -NoProfile -ExecutionPolicy Bypass -File Windows\Compilar.ps1`; compila y ejecuta las pruebas antes de generar el instalador.
- La publicación automatizada compila Windows, ejecuta las pruebas y adjunta el instalador, la licencia y sus sumas SHA-256 a una versión de GitHub. El código fuente correspondiente se conserva en la etiqueta de esa publicación.

## Licencia

Copyright © 2026 Juan Luis (JLPalmes).
Código, documentación y recursos propios bajo **GNU AGPL versión 3 exclusivamente**
(`AGPL-3.0-only`). Consulta [LICENSE](LICENSE) y [el aviso](AVISO-LICENCIA.txt).
Este programa se distribuye sin garantía.
