# Prácticas FP

Aplicación de escritorio para gestionar alumnas, empresas, tutores, horarios,
seguimiento mensual y documentación de las prácticas de Formación Profesional.
Los datos se guardan localmente, sin cuentas ni servicios en la nube.

## Descargar e instalar

Los instaladores están en [Versiones publicadas](https://github.com/JLPalmes/practicas-fp-publico/releases).

| Sistema | Versión | Instalación |
| --- | --- | --- |
| Mac con Apple Silicon, macOS 14 o posterior | 1.8.2 | Abre el `.dmg` y arrastra Prácticas FP a Aplicaciones. |
| Windows 10/11 de 64 bits | 1.8.2-windows.2, edición de pruebas | Ejecuta `Instalar-PracticasFP-…-x64.exe`. Requiere .NET Framework 4.8 recomendado. |

La edición Mac tiene firma local y no está notarizada. La edición Windows no
lleva certificado de firma digital. Conserva una copia de tus datos antes de
actualizar. Los instaladores no incluyen datos de alumnas ni empresas.

Consulta la [guía de Mac](LEEME.md) y la [guía de Windows](Windows/LEEME.md).
Ambas ediciones usan el formato de datos 4. Puedes exportar una copia y
restaurarla en el otro equipo; no hay sincronización ni fusión de cambios.
La verificación completa del intercambio de ida y vuelta sigue pendiente:
conserva el original y comprueba los datos antes de continuar en otro equipo.

## Código y compilación

- Mac: ejecuta `./Validar.command` y `./Compilar.command` con las herramientas de desarrollo de Apple y Python 3.
- Windows: ejecuta `powershell -NoProfile -ExecutionPolicy Bypass -File Windows\Compilar.ps1`; compila y ejecuta las pruebas antes de generar el instalador.
- La publicación automatizada compila ambas ediciones, ejecuta sus pruebas y adjunta los instaladores, la licencia y sus sumas SHA-256 a una versión de GitHub. El código fuente correspondiente se conserva en la etiqueta de esa publicación.

## Licencia

Copyright © 2026 Juan Luis (JLPalmes).
Código, documentación y recursos propios bajo **GNU AGPL versión 3 exclusivamente**
(`AGPL-3.0-only`). Consulta [LICENSE](LICENSE) y [el aviso](AVISO-LICENCIA.txt).
Este programa se distribuye sin garantía.
