# Prácticas FP para Windows · edición de pruebas

Adaptación nativa de la versión de Mac 1.8.4. Identificador: **1.8.4-windows.8**.

## Instalar y probar

1. Ejecuta `dist\Windows\Instalar-PracticasFP-1.8.4-windows.8-x64.exe`.
2. Pulsa **Instalar**. No requiere permisos de administrador y no abre la aplicación automáticamente.
3. Abre **Prácticas FP** desde el escritorio o el menú Inicio.
4. Prueba primero con fichas ficticias. Para usar una copia de Mac, ve a **Ajustes y copias → Restaurar copia de Windows o Mac…**. Antes de sustituir datos se muestra un resumen y se conserva una copia previa.

Destinada a Windows 10/11 de **64 bits**, con .NET Framework (4.8 recomendado). No necesita Excel, Node ni el SDK de .NET. Esta edición no lleva certificado de firma digital.

## Funciones

- Alumnas, empresas y tutores; búsquedas y filtros; navegación entre fichas.
- Cupos, asignación provisional/definitiva y comprobación de plazas.
- Objetivo de horas, jornadas y cambios por fecha; prácticas en varias empresas, cada una con sus documentos.
- Calendario local del curso, exclusiones inclusivas y días del instituto.
- Casillas de completado en anexos y conciertos, con coherencia entre envíos y recepciones.
- Seguimiento mensual agrupado por empresa.
- Importación CSV y Excel .xlsx con elección de hoja y fila de cabecera, correspondencia de columnas y selección previa. Protege los ceros iniciales; omite duplicados y señala fórmulas y números largos para revisión. Límite: 20 MB, 10.000 filas y 256 columnas.
- Guardado automático **al salir de cada campo**; Deshacer/Rehacer de hasta 50 cambios en la sesión. El historial almacena las diferencias de cada operación, sin duplicar los cursos archivados en cada edición. Se limita a unos 16 MB, conservando al menos la última operación aunque por sí sola supere ese tamaño.
- Copias automáticas al abrir datos existentes, antes de importar y restaurar, con exportación manual verificada.
- Informes de alumna, empresa o curso en texto y mediante impresión paginada A4. En el diálogo de impresión selecciona **Microsoft Print to PDF** para guardar un PDF.

## Datos y compatibilidad

- Datos: `%LOCALAPPDATA%\PracticasFP\Datos\datos.json`.
- Copias: `%LOCALAPPDATA%\PracticasFP\Datos\Copias`.
- Aplicación: `%LOCALAPPDATA%\Programs\PracticasFP`.

Lee formatos 1, 2, 3 y 4 y escribe el formato 4 de Mac. Conserva los campos desconocidos, los identificadores como texto, las fechas numéricas de Swift y las instantáneas de cursos en base64. Las fechas se interpretan en la zona de Canarias, independientemente de la zona del ordenador.

Los datos y copias no se suben a servicios externos. Para trasladarlos entre equipos, exporta una copia y restáurala en el otro. No hay sincronización simultánea ni fusión de cambios. Una segunda instancia no puede abrir la misma carpeta de datos. Un archivo ilegible bloquea las modificaciones para proteger el original.

Desinstala desde **Configuración → Aplicaciones**. Se conservan datos y copias. Por ser un instalador mínimo, queda el archivo `Desinstalar.exe` en la carpeta de la aplicación; puedes eliminarlo después de cerrar la desinstalación.

## Mejoras de la segunda edición de Windows

- Fichas con apartados plegables y una cabecera que mantiene visible el nombre y el estado de asignación.
- Al marcar hitos se actualiza el apartado documental afectado. Las otras actualizaciones de ficha conservan el desplazamiento y recuperan el foco cuando sigue disponible el mismo control.
- Cada ficha conserva su posición durante la sesión. Las búsquedas, filtros y selecciones se mantienen al cambiar de sección. Las anchuras por sección y el estado de los apartados plegables se recuerdan también al reiniciar, en `vista-windows.json`, separado del archivo de datos.
- Los campos se adaptan al ancho disponible. Las consultas de documentos, periodos e informes ya no crean datos al mostrarlos.
- Se reutilizan cálculos de previsión, periodos, contactos y ocupación mientras no cambien los datos ni el día de Canarias. Las fechas de cambios y exclusiones se preparan una sola vez por cálculo.
- El código separa almacenamiento, historial, pantallas, controles documentales e informes. Se conserva el formato de datos 4 y las tecnologías C# / Windows Forms / .NET Framework.

Los filtros todavía no muestran contadores. Deshacer registra cada campo al abandonarlo, en lugar de agrupar pulsaciones por tiempo. El PDF se produce mediante el controlador de impresión de Windows, sin los metadatos lingüísticos del exportador de Mac.

## Actualizar y recuperar una versión

Cierra Prácticas FP antes de ejecutar el instalador nuevo. Se verifican los dos ejecutables antes de sustituirlos. Si falla la actualización, se intenta recuperar ambos archivos y deshacer los cambios en accesos directos y registro de la aplicación. Si la recuperación tampoco puede completarse, el mensaje indica dónde se conservan los respaldos; no los elimines.

Una actualización completada conserva los ejecutables anteriores en `%LOCALAPPDATA%\Programs\PracticasFP\VersionAnterior`. Para volver manualmente a la aplicación anterior, ciérrala y copia `VersionAnterior\PracticasFP.exe` sobre el de la carpeta principal. Esta versión mantiene el formato de datos, por lo que no requiere una migración para volver a windows.1. Antes de otra actualización conserva aparte esa copia si quieres retener más de una versión anterior.

Si se interrumpe el reemplazo de archivos, el siguiente intento de instalación recupera esos archivos antes de volver a actualizar. Los datos de alumnas, empresas y copias quedan fuera de la carpeta de instalación y no se modifican. La recuperación se ha probado con archivos ficticios y fallos simulados; el instalador real no se ha ejecutado en esta revisión.

El intercambio completo de copias con Mac queda fuera del alcance de esta mejora. Se conserva la lectura de los formatos anteriores, sin prometer una verificación de ida y vuelta con Mac.

## Compilar y validar

Desde PowerShell en la raíz del repositorio:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File Windows\Compilar.ps1
```

Usa el compilador de .NET Framework incluido en Windows. Compila la aplicación, ejecuta las pruebas con datos ficticios temporales y, solo si pasan, genera el instalador con la aplicación recién compilada como recurso. No ejecuta el instalador ni instala la aplicación.

Los instaladores se nombran `Instalar-PracticasFP-<versión>-x64.exe`. La versión se obtiene automáticamente de la aplicación recién compilada y se comprueba que coincida con la del instalador. Así, cada versión conserva un nombre distinto al descargarla o compartirla.

Resultados en `dist\Windows\`. `Pruebas.exe` ejecuta 73 comprobaciones del cálculo, datos, migraciones, documentos, copias, importación, contactos, consultas sin efectos secundarios, historial incremental, reutilización de cálculos y recuperación de actualizaciones. La interfaz se comprobó abriendo la aplicación compilada con una carpeta de datos ficticios independiente mediante `--data-directory`.

## Mejoras 1.8.4-windows.5

Las fichas reutilizan los campos de texto que comparten. Los anexos, el concierto y varios apartados de datos se cargan al abrirlos si estaban plegados.

## Mejoras 1.8.4-windows.4

Se agrupan los ajustes de diseño al abrir una ficha y al marcar hitos para reducir el trabajo de redibujado.

## Mejoras 1.8.4-windows.3

Alumnas, Empresas y Tutores mantienen siempre el listado y la ficha. Al entrar
se recupera la selección de esa sección durante la sesión o se abre la primera
ficha disponible. Al borrar la seleccionada se abre otra; si no quedan fichas,
la columna derecha permite añadir. La búsqueda conserva la ficha abierta.

La lista de tutores muestra el nombre, debajo su empresa y después las alumnas
asignadas, incluidas las de periodos posteriores, sin repeticiones. Permite
buscar por tutor, empresa o alumna. Su ficha incluye enlaces a esas alumnas.

Se reducen los márgenes y anchos mínimos. Las columnas del listado se ajustan
al espacio disponible y los hitos documentales se distribuyen en filas
numeradas sin desplazamiento horizontal. Toda la cabecera de los apartados es
pulsable, con un mínimo de 32 puntos y altura adaptable a títulos largos.
Informe permite elegir la ficha seleccionada o el curso completo.

Además de las 73 comprobaciones funcionales, la compilación ejecuta pruebas
sobre formularios reales con datos ficticios: selección inicial y conservada,
listados vacíos, borrado, alta, búsqueda de tutores, plegado, hitos y ausencia
de barra horizontal en fichas estrechas. Genera vistas previas de Windows para
revisión. Sigue pendiente la comprobación manual en el equipo del usuario.

La publicación de una actualización exclusiva de Windows reutiliza el instalador
Mac existente únicamente si las fuentes de Mac y su procedimiento de compilación
permanecen idénticos a los de aquella versión y se verifica su suma SHA-256.
