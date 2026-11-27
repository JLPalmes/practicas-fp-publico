# Prácticas FP para Windows

Versión **2.1.11**, para Windows 10 u 11 de 64 bits, con Microsoft Edge WebView2 y
.NET Framework 4.8 recomendado.

## Instalar

Ejecuta Instalar-PracticasFP-2.1.11-x64.exe y pulsa Instalar. La aplicación se abre
desde Prácticas FP en el escritorio o el menú Inicio. Se instala para tu usuario
y conserva los datos al actualizar.

## Fichas y periodos

La navegación abre los paneles Alumnas, Empresas, Tutores y Calendario.
Alumnas guarda automáticamente tras una pausa de edición y al navegar.
Los errores conservan el borrador y aparecen en el aviso superior. Deshacer
y Rehacer actúan durante la sesión.

Cada periodo tiene su empresa, tutor, jornada, cambios de jornada, documentación
y fecha de cierre. Al cerrar un periodo se cuentan las horas cumplidas hasta
ese día incluido. El siguiente recibe el saldo del objetivo general,
descontando las horas de cursos anteriores y de los periodos ya cerrados.

Calendario muestra los festivos e intervalos excluidos en una cuadrícula
mensual. Informes ofrece la alumna, la empresa o el curso completo, con
exportación de texto e impresión. El diálogo de impresión permite elegir
Microsoft Print to PDF.

## Datos y copias

Datos y copias permite exportar y restaurar copias JSON de Mac o Windows,
con una copia previa al reemplazo. La importación CSV, TSV o Excel permite
revisar la hoja y las columnas antes de añadir alumnas.

Los datos permanecen en %LOCALAPPDATA%\PracticasFP-Tauri-Piloto\datos.json
y las copias en la subcarpeta Copias. Esta ruta heredada permite recuperar
las instalaciones anteriores. Se admite una sola instancia por almacén.
Para cambiar de equipo, exporta una copia y restáurala en el otro.

## Compilar y actualizar

Windows/Compilar-Tauri.ps1 -Verificar genera el instalador y sus fuentes en
dist/Windows-Tauri y comprueba el paquete en una carpeta temporal.

El actualizador utiliza la clave pública de Windows del proyecto. Para activar
una actualización hay que firmar el paquete y publicar el catálogo según
ACTUALIZACIONES.md.