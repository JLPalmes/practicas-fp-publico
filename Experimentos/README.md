# Rendimiento de Prácticas FP 2.0.3 en Windows

## Fin previsto y autoguardado de Windows 2.1.9

El autoguardado actualiza la fecha prevista y los errores del cálculo en la ficha
abierta, además de las horas. Se elimina el botón Guardar ficha de Alumnas.
Si falta una empresa o una fecha de inicio, el resultado explica qué falta.
La prueba del paquete reabre un periodo cerrado, espera el autoguardado y compara
la fecha visible con la respuesta del motor. Después vuelve a cerrarlo y verifica
la persistencia tras reiniciar.

La edición mantenida para Windows se denomina Prácticas FP. Desde 2.1.8 se
elimina el distintivo Tauri de la ventana, el instalador, los accesos y los
nombres de las descargas. Las rutas internas heredadas permiten actualizar las
instalaciones existentes. La publicación automatizada compila la edición actual.
Se superaron 84 comprobaciones de datos, 38 de WinForms, el recorrido completo
de Alumnas y la verificación aislada del paquete y su actualización.

## Autoguardado y objetivos de Windows 2.1.8

Alumnas guarda tras una pausa de edición de 700 ms y al navegar. El guardado de
fondo conserva los campos editables y evita mensajes rutinarios. Las ediciones
incompletas conservan el borrador y muestran el error hasta que se corrige.

El periodo tiene una sola fecha de cierre. Para copias anteriores con dos
fechas, se muestra la de práctica terminada si estaba marcada y, en otro caso,
el fin manual guardado. Las horas del periodo cerrado se cuentan hasta ese día,
incluyéndolo, con las jornadas, fines de semana y exclusiones correspondientes.
El siguiente periodo recibe el objetivo general menos las horas del curso
anterior y las cumplidas en los periodos anteriores. El campo se calcula
automáticamente, por lo que no se edita de forma independiente.

Las pruebas de cálculo verificaron el reparto de 500 horas, con 10 horas previas
y 7 cumplidas en el primer periodo, que deja 483 para el segundo. La prueba del
paquete verificó que el autoguardado actualiza el motor sin un cambio de ficha,
sin bloquear la entrada y sin avisos de guardado.

## Navegación y guardado de Windows 2.1.7

La inspección de una sesión instalada en 2.1.6 encontró la ventana y el motor
activos con el aviso de cambios pendientes al pie de la ficha. Esta protección
impedía cambiar de alumna y podía confundirse con un bloqueo.

Alumnas guarda ahora sus cambios al abrir otra alumna o un panel, crear una
ficha, importar o usar el historial. Las operaciones inválidas conservan el
borrador y muestran el error en un aviso situado bajo la navegación principal.
Los estados de guardado y los avisos de Empresas, Calendario y copias también
aparecen allí.

La prueba de 2.1.7 editó el objetivo y el estado de finalización, cambió de alumna
por la lista y comprobó la persistencia de ambos. También intentó navegar con el
objetivo vacío, verificó el error visible y pudo navegar tras corregirlo. Pasaron
la reapertura del paquete, la reversión y la actualización aisladas. Estas
pruebas cubren el impedimento de navegación observado en la sesión inspeccionada.

## Correcciones de Windows 2.1.6

Se incorporaron los avances de la rama principal hechos en Mac antes de corregir
Windows. Las lecturas de ficha pasan al ejecutor de tareas de fondo, igual que los
guardados y diálogos, para evitar esperar al motor desde el hilo de la ventana.
Si el motor deja de responder durante 60 segundos se cierra el canal y se informa
del error. El cierre de la aplicación tiene un límite de espera para el proceso C#.

Las fechas visibles de fin previsto se presentan como día/mes/año. El primer
periodo oculta esa previsión cuando está activo el segundo. El objetivo general
recupera las 500 horas predeterminadas si la copia anterior omite el campo, y las
horas restantes se actualizan mientras se edita el objetivo o las horas previas.
El objetivo de cada periodo conserva su cálculo independiente.

El actualizador incluye la clave pública configurada desde Mac. La firma del
paquete y el catálogo de Windows están pendientes de la clave privada custodiada
allí. El instalador inicial de 2.1.6 se entrega para instalación manual.

Verificación de 2.1.6: pasaron las 82 comprobaciones de datos, las 38 de interfaz
WinForms, las cuatro pruebas de la interfaz del actualizador y las dos pruebas
Rust de versiones y arquitectura. La prueba del instalador ejercitó 12 lecturas
simultáneas, la visualización de 500 horas en fichas sin el campo, el cambio y
guardado del objetivo a 650, la actualización inmediata de horas restantes, las
fechas en español y la visibilidad de la previsión según el segundo periodo.
También verificó reapertura, reversión y actualización aisladas. El bloqueo
intermitente comunicado no se reprodujo durante estas pruebas.

Pruebas locales en Roquetes con 300 alumnas ficticias, dos periodos activos por alumna y una empresa. Cada operación se calentó cuatro veces y se midió 30 veces. Los resultados están en milisegundos.

| Operación | WinForms con JSON, mediana / p95 | Variante, mediana / p95 |
|---|---:|---:|
| Cambiar entre dos fichas | 496,92 / 550,58 | Tauri con C# · 13,90 / 15,00 |
| Desplegar y plegar Anexo I | 64,94 / 71,08 | Tauri con C# · 27,80 / 27,90 |
| Guardar un cambio de teléfono | 364,68 / 384,63 | SQLite · 5,46 / 8,65 |
| Consultar alumnas de una empresa | 0,26 / 1,65 (en memoria) | SQLite · 0,41 / 0,49 |

La apertura completa del JSON tardó 149,15 ms de mediana. La lectura de una ficha individual en SQLite tardó 0,53 ms con la conexión abierta. Son operaciones de alcance distinto.

WinForms ejecuta la ficha completa y procesa sus eventos de dibujo. El prototipo Tauri muestra una ficha reducida y de solo lectura, con datos de contacto, dos periodos, el registro global de horas y los pasos del Anexo I. Mantiene un proceso local de C# que reutiliza el modelo y el cálculo, y espera dos llamadas de animación por actualización de pantalla. La cifra de Tauri mide esta ficha reducida. Para decidir un porte, la siguiente comparación tendría que igualar las funciones de edición y validación.

SQLite conserva cada ficha como un registro y mantiene un índice de las asignaciones por empresa. La prueba verifica la reconstrucción de la copia con dos periodos y la importación de una copia ficticia de la versión 1. La escritura de una ficha usa una transacción de SQLite. El guardado actual además valida el conjunto, calcula el historial de deshacer y escribe el archivo completo. La cifra de SQLite mide la actualización aislada. Queda por integrar la validación, el historial y la recuperación antes de valorar el guardado completo.

## Repetir las pruebas

Desde la raíz del proyecto, en Windows:

```powershell
powershell -ExecutionPolicy Bypass -File Windows/Medir-Rendimiento.ps1
powershell -ExecutionPolicy Bypass -File Windows/Medir-Rendimiento.ps1 -Modo SQLite
powershell -ExecutionPolicy Bypass -File Windows/Medir-Rendimiento.ps1 -Modo Tauri
```

La prueba de Tauri requiere Rust, las herramientas de compilación de Visual C++ y WebView2. Con `-Interactivo` deja abierta la ficha de prueba y permite editar el contacto o medir desde el botón. El modo SQLite usa la biblioteca incluida en Windows. Los datos de prueba se generan en memoria o en una carpeta temporal propia.

## Segunda prueba con validación y edición

La ficha de Tauri permite editar el teléfono y el correo. C# comprueba el correo y guarda los dos campos con el mismo `Store.Change` que usa WinForms. La prueba comprueba el rechazo de un correo inválido y que el teléfono guardado se conserva al pasar a otra alumna y volver. El resto de la ficha sigue siendo de consulta.

| Operación en Tauri con edición de contacto | Mediana | p95 |
|---|---:|---:|
| Cambiar de alumna | 13,90 ms | 15,50 ms |
| Desplegar y plegar el anexo | 27,80 ms | 28,00 ms |
| Guardar contacto y mostrar el resultado | 375,35 ms | 397,90 ms |

En SQLite se probó el mismo flujo de validación e historial de `Store.Change`, escribiendo en una sola fila de la base. El guardado completo tardó **361,13 ms de mediana y 377,80 ms de p95**. En la misma ejecución, la escritura aislada del teléfono tardó **5,49 ms de mediana**. El guardado completo con JSON había tardado **364,68 ms**. Se verificaron la consistencia con la copia JSON, el rechazo de datos inválidos y la escritura en SQLite al deshacer y rehacer. En este flujo el coste está principalmente en el trabajo que se hace sobre el conjunto de datos antes de escribir.

## Tercera prueba con edición de horas

La ficha de Tauri añade la edición del objetivo general, las horas del curso anterior y del siguiente, y la jornada inicial y el objetivo de cada periodo. Se aceptan decimales con coma o punto. El motor C# comprueba todos los valores antes de guardar el contacto y las horas en una sola operación. Después actualiza el registro global con el cálculo existente.

La prueba comprueba que una jornada de 25 horas rechace toda la edición, que los dos periodos mantengan valores independientes y que los cambios válidos se conserven al volver a la ficha. Las empresas, las fechas, los cambios de jornada, la documentación y los demás campos aún quedan fuera de esta edición.

| Operación en Tauri con edición de horas | Mediana | p95 |
|---|---:|---:|
| Cambiar de alumna | 13,90 ms | 14,60 ms |
| Desplegar y plegar el anexo | 27,80 ms | 27,90 ms |
| Guardar ficha y recalcular horas | 388,75 ms | 418,70 ms |

WebView2 emitió un aviso al cerrar la ventana de prueba después de imprimir los resultados. La ejecución terminó con código 0.

## Cuarta prueba con empresas y fechas

Cada periodo permite elegir empresa y editar el inicio y el fin manual. Las fechas vacías dejan el inicio o fin sin fijar. La ficha muestra el fin previsto y los avisos del cálculo de C#. Al cambiar de empresa se aplica `Model.Assign`, que comprueba el cupo y deja la asignación en provisional.

La prueba utiliza 300 alumnas y tres empresas ficticias. Comprueba que el sistema rechaza un fin anterior al inicio y revierte los cambios de ambos periodos si una empresa no admite nuevas alumnas. También verifica que, al volver a la ficha, siguen guardadas las empresas y fechas de cada periodo.

| Operación | Mediana | p95 |
|---|---:|---:|
| Cambiar de alumna | 13,90 ms | 15,60 ms |
| Desplegar y plegar el anexo | 27,80 ms | 28,00 ms |
| Guardar ficha y recalcular horas | 388,20 ms | 417,80 ms |

## Quinta prueba con cambios de jornada

Cada periodo permite añadir, editar y quitar cambios de jornada dentro de su empresa. Cada cambio tiene una fecha efectiva y sus nuevas horas diarias. El motor C# rechaza fechas duplicadas dentro del periodo o anteriores al inicio. La prueba guarda un cambio distinto en cada periodo, vuelve a abrir la ficha y comprueba que quitar el cambio del primer periodo altera las horas calculadas y conserva el cambio del segundo.

| Operación | Mediana | p95 |
|---|---:|---:|
| Cambiar de alumna | 13,85 ms | 15,10 ms |
| Desplegar y plegar el anexo | 27,80 ms | 28,00 ms |
| Guardar ficha y recalcular horas | 390,10 ms | 418,00 ms |

## Sexta prueba con anexos por periodo

Cada periodo contiene sus propios anexos I y II. Los hitos se muestran en columnas y se guardan con el resto de la ficha. Se aplica el flujo de C# que vincula envío y recepción. Los cambios nuevos se guardan sin fecha y las fechas históricas de los hitos que no se modifican se conservan.

La comprobación marca la recepción del Anexo I del primer periodo y la generación del Anexo II del segundo, cambia de alumna y verifica que se mantengan en sus anexos y periodos. También comprueba que retirar el envío retire su recepción y conserve el otro anexo.

| Operación | Mediana | p95 |
|---|---:|---:|
| Cambiar de alumna | 13,90 ms | 16,40 ms |
| Desplegar y plegar el Anexo I | 27,80 ms | 28,00 ms |
| Guardar ficha y recalcular horas | 388,85 ms | 407,00 ms |

## Séptima prueba con tutores y estados de asignación

Cada periodo permite elegir el tutor de su empresa y el estado pendiente, provisional o definitivo. Al cambiar de empresa, la interfaz borra la selección del tutor, vuelve a cargar los de la nueva empresa y propone el estado provisional. C# comprueba que el tutor pertenezca a la empresa antes de guardar.

La prueba asigna empresas, tutores y estados distintos a los dos periodos, vuelve a abrir la ficha y verifica los valores. También prueba que C# rechace un tutor de otra empresa y que la lista del segundo periodo solo muestre sus tutores.

| Operación | Mediana | p95 |
|---|---:|---:|
| Cambiar de alumna | 13,90 ms | 15,60 ms |
| Desplegar y plegar el Anexo I | 27,80 ms | 27,90 ms |
| Guardar ficha y recalcular horas | 382,70 ms | 403,30 ms |

## Octava prueba con datos personales y preferencias

El prototipo permite editar el nombre, grupo, DNI o NIE, NUSS, contacto, tipo de empresa, zona, preferencias y observaciones. La prueba cambia esos datos, abre otra ficha y verifica que se conservan al volver. También comprueba que la lista muestre el nombre editado, que se conserven los ceros iniciales del NUSS y que las observaciones admitan varias líneas.

La mediana fue de **13,80 ms** para cambiar de alumna y **400,45 ms** para guardar y recalcular. Los p95 fueron **16,70 ms** y **441,20 ms**, respectivamente.

## Activación del segundo periodo

La ficha permite desactivar o volver a activar el segundo periodo. Sus datos quedan guardados al desactivarlo, y el cálculo global lo excluye hasta que se reactive.

## Creación, estado de las prácticas y deshacer

La ficha incorpora las casillas de práctica iniciada y terminada de cada periodo, y los botones Añadir alumna, Deshacer y Rehacer. El flujo usa el historial del almacén de C# y vuelve a leer la lista al cambiar el número de fichas. La prueba crea una alumna, guarda su nombre y el estado de sus prácticas, deshace y rehace y carga el archivo experimental de nuevo desde disco.

El modo automático cierra Tauri y su proceso C#, vuelve a arrancar ambos con el mismo archivo temporal y verifica la ficha creada y sus casillas. La prueba completa pasó con medianas de **13,90 ms** para cambiar de alumna y **383,15 ms** para guardar y recalcular.

## Comparativa con fichas de mayor carga

Se repitieron las pruebas en Roquetes con 300 fichas ficticias, diez grupos, dos periodos fechados por ficha, un cambio por periodo y parte de la documentación marcada. Los ejecutables se midieron por separado. Cada operación tiene 30 muestras después de cuatro ejecuciones de calentamiento.

| Operación | WinForms, mediana / p95 | Tauri con C#, mediana / p95 |
|---|---:|---:|
| Cambiar de alumna | 561,25 / 597,08 ms | 13,90 / 17,00 ms |
| Desplegar y plegar Anexo I | 62,80 / 66,14 ms | 27,80 / 28,00 ms |
| Guardar | 405,65 / 420,29 ms | 436,30 / 466,40 ms |

La medición de guardado en WinForms abarca `Store.Change` para un teléfono. En Tauri abarca la edición de la ficha, el recálculo y la actualización visible. Los dos tiempos corresponden a flujos diferentes. La ventaja más clara de Tauri está en la navegación en esta carga. El guardado sigue dominado por la validación y el historial de C#, como mostró la prueba con SQLite.

## Medir una copia de un curso

El modo `-Copia` se usa con una exportación JSON local que contenga al menos dos fichas. Ambos programas convierten en memoria las fichas del formato anterior con la rutina de Prácticas FP y usan las dos primeras para medir. Las pantallas muestran el contenido de la copia durante la prueba. La salida solo incluye el número de fichas y los tiempos. En este modo se mide navegación y apertura del anexo, sin guardar cambios.

Con la copia real de siete fichas del formato 4, se obtuvieron estos tiempos en 30 mediciones por operación después del calentamiento:

| Operación | WinForms, mediana / p95 | Tauri con C#, mediana / p95 |
|---|---:|---:|
| Cambiar de alumna | 481,37 / 597,74 ms | 13,90 / 14,10 ms |
| Desplegar y plegar el Anexo I | 49,12 / 52,87 ms | 27,80 / 28,00 ms |

La huella SHA-256 de la copia real coincidió antes y después. La prueba usa dos fichas de un solo curso y mide el prototipo de Alumnas, con cobertura parcial de la aplicación. La mejora de navegación se repitió con la copia real y con 300 fichas ficticias. Para el uso ocasional previsto, la recomendación es conservar WinForms como versión distribuida y mantener Tauri con C# como base si más adelante se decide priorizar la fluidez. Un traslado completo requeriría portar las demás pantallas y verificar el instalador y la restauración. Las pruebas de guardado ofrecen poco fundamento para migrar a SQLite o reescribir la lógica en Rust por rendimiento.

```powershell
powershell -ExecutionPolicy Bypass -File Windows/Medir-Rendimiento.ps1 -Copia "C:\ruta\copia-del-curso.json"
powershell -ExecutionPolicy Bypass -File Windows/Medir-Rendimiento.ps1 -Modo Tauri -Copia "C:\ruta\copia-del-curso.json"
```

Verificación del modo con una exportación ficticia de 300 fichas. WinForms midió **574,26 ms** para el cambio de alumna y **63,11 ms** para desplegar y plegar. Tauri midió **13,95 ms** y **27,80 ms**, respectivamente. La huella SHA-256 de la entrada coincidía antes y después de ejecutar ambos programas.

## Certificado y avisos en Datos personales

La casilla del certificado pertenece a la ficha de la alumna y se guarda con los datos personales, sin añadir una fecha. Tauri y WinForms comparten los avisos de nombre, posibles duplicados, DNI o NIE, NUSS y correo. La prueba automática marca el certificado, cambia de ficha, verifica su persistencia y comprueba los avisos con datos de identificación incompletos.

Pasaron la prueba de Tauri con reapertura y las 81 comprobaciones de Windows y 38 de interfaz. Tauri midió **13,90 ms** de mediana al cambiar de alumna con los avisos activos.

## Búsqueda y lista de alumnas

La lista de Tauri muestra el nombre en negrita y las empresas debajo. C# usa las mismas líneas de presentación y los mismos campos de búsqueda que WinForms. El filtro de la interfaz encuentra coincidencias por nombre, empresa, DNI o grupo, sin distinguir mayúsculas ni tildes.

La prueba verifica los resultados con el nombre editado, el DNI, el grupo y una empresa asignada exclusivamente a la primera ficha. También comprueba que la selección siga correspondiendo a la ficha abierta.

La mediana de cambio de ficha fue de **16,35 ms** con 300 alumnas ficticias. Pasó también la reapertura tras reiniciar los dos procesos.

## Ediciones pendientes

Con cambios pendientes, la ficha pide guardar o descartar al intentar abrir otra alumna, crear una ficha, usar el historial, lanzar la medición interactiva o cerrar la ventana. Descartar restaura los últimos valores guardados. Si hay un guardado en marcha, la ventana espera a que termine.

La prueba solicita el cierre de la ventana después de editar las observaciones, comprueba que la ventana y el borrador siguen abiertos y restaura los valores guardados. En el arranque de verificación se comprueba la reapertura y que la ventana sin cambios pendientes cierre normalmente.

## Preparación de una versión para compañeros

El modo de desarrollo `-Modo Tauri -Piloto` inicia Alumnas con un almacén persistente propio en `%LOCALAPPDATA%\PracticasFP-Tauri-Piloto`. La primera sesión comienza sin fichas y solo una instancia a la vez puede abrir el almacén. Los modos de medición siguen usando datos temporales.

Verificación superada con `powershell -ExecutionPolicy Bypass -File Windows/Medir-Rendimiento.ps1 -Modo Tauri -VerificarPiloto`. El primer arranque usó un almacén temporal aislado y vacío, creó una alumna y guardó su estado de prácticas. El segundo arranque recuperó los datos después de cerrar Tauri y C#. La prueba no escribe en el almacén del usuario.

La versión distribuible requiere trasladar Empresas y Tutores para que los usuarios puedan configurar las asignaciones, Calendario e Informes para mantener el flujo de trabajo, y añadir la importación y restauración de copias. Antes de ofrecerla a los compañeros hay que empaquetar el proceso C# junto a Tauri, probar la instalación y la actualización en Windows, y verificar la recuperación de una copia con los datos del usuario.

### Alta de empresas y tutores

El piloto incorpora formularios de alta y edición para empresas y tutores. Empresas incluye contacto, fechas y cupo, con el cálculo visible de plazas ocupadas y libres. Al guardar se actualizan las opciones de la ficha de Alumnas y se impide cambiar de empresa a un tutor ya asignado.

La prueba del piloto creó una empresa con dos plazas y una tutora, las asignó a la primera alumna desde sus selectores y comprobó la ocupación y el rechazo de un cambio de empresa para la tutora. Tras reiniciar recuperó la asignación y la ocupación.

Empresas incluye el concierto de colaboración y el seguimiento mensual, con los contactos desplegables dentro de su bloque. La prueba confirmó que, al registrar la recepción del concierto, se marca el envío sin añadir fechas. También registró un contacto mensual con fecha y observaciones y recuperó ambos cambios tras reiniciar.

La navegación enlaza a las alumnas y tutores desde la empresa, y permite abrir la empresa y las alumnas desde el tutor. Los dos periodos también enlazan a la empresa y el tutor guardados. Empresas, Tutores y Alumnas piden confirmación al eliminar. WinForms y Tauri comparten las reglas que impiden eliminar empresas y tutores vinculados. La prueba del piloto verifica ambos rechazos y el ciclo de eliminar, deshacer y rehacer con un tutor sin vínculos.

### Calendario

El piloto permite editar el intervalo revisado y confirmar los días de libre disposición. También permite añadir, editar y eliminar días e intervalos excluidos. Los cambios se guardan en el historial de C# y se vuelve a cargar la ficha abierta para reflejar la previsión actualizada.

La prueba aislada rechazó un intervalo invertido, descontó siete horas al excluir un día laborable, las recuperó al borrar ese día y volvió a descontarlas al deshacer. El calendario y la exclusión se recuperaron tras reiniciar Tauri y C#.

### Informes

Tauri muestra el informe del curso, el de la alumna abierta y el de la empresa seleccionada. Utiliza el mismo generador de C# que WinForms y comparte sus diálogos de guardar texto UTF-8 e imprimir o guardar como PDF. La comprobación automatizada compara la vista previa con la respuesta de C# y verifica el alcance de cada informe.

### Datos y copias

El piloto permite guardar el centro y el curso, exportar una copia JSON verificada y restaurar una copia de Windows o Mac. La selección muestra un resumen antes de sustituir el curso. El motor valida y convierte los registros anteriores al formato de dos periodos en memoria. Al confirmar, el almacén conserva una copia de los datos previos y permite deshacer el cambio durante la sesión.

La prueba aislada exportó una copia, verificó su contenido, restauró una copia del formato 4 y confirmó la conversión y la creación de la copia previa. Deshizo la restauración y volvió a leer los datos originales desde disco. El arranque posterior recuperó la ficha del piloto.

### Importación de alumnas

Tauri abre el selector de CSV, TSV o Excel y reutiliza la revisión de WinForms para elegir hoja, fila de títulos, correspondencia de columnas y fichas que se añadirán. Ambos guardan una copia previa y convierten las fichas importadas al formato de dos periodos. La prueba aislada importó una fila CSV, verificó sus ceros iniciales y periodos al cargar desde disco y deshizo la importación. Las pruebas de Windows cubren la lectura de Excel y el aviso de fórmulas.

### Instalador Windows x64

`Windows/Compilar-Tauri.ps1` compila Prácticas FP Tauri y el motor C# y prepara un instalador con la versión en el nombre. Tauri arranca el motor junto a su ejecutable. La edición Tauri se instala para el usuario con accesos y carpeta propios. Requiere WebView2 y .NET Framework como parte del entorno Windows. La instalación y la desinstalación conservan los datos personales fuera de la carpeta de programas.

Con `-Verificar`, la prueba inspecciona los ejecutables y las licencias dentro del instalador, aplica su contenido en una carpeta temporal, simula un fallo de actualización y comprueba que la aplicación empaquetada conserva el curso al reiniciar. El instalador gráfico queda para el usuario. El recorrido interactivo de los diálogos nativos se comprobará aparte.

El paquete **2.1.0 x64** superó la extracción de sus recursos, el primer arranque desde una carpeta temporal, la reversión de un fallo después de sustituir el motor, la actualización y la reapertura con el curso intacto. También pasaron las 81 comprobaciones y las 38 de interfaz de WinForms.

Con la copia real de siete fichas, las medianas de la edición empaquetada fueron **32,05 ms** para cambiar de alumna y **27,80 ms** para desplegar y plegar el anexo. WinForms midió **481,90 ms** y **49,29 ms**, respectivamente. La copia de entrada mantuvo la misma huella SHA-256.

Se abrieron y cancelaron manualmente los cuadros nativos para importar, guardar y restaurar copias, exportar texto e imprimir. Microsoft Print to PDF aparecía disponible. La prueba no envió un trabajo de impresión. Las pruebas automatizadas ejercitan la importación y la restauración con archivos temporales.

Para compartir la edición, el instalador y `Fuentes-PracticasFP-Tauri-2.1.0.zip` se generan juntos en `dist/Windows-Tauri`. El ZIP contiene las fuentes y los procedimientos de compilación de la edición, sin archivos de curso ni ejecutables generados.

### Navegación y diseño de Tauri 2.1.1

Alumnas, Empresas, Tutores y Calendario tienen una entrada en la barra superior y su propio panel de lista y detalle. Calendario presenta los días e intervalos excluidos al abrirlo. La ficha de alumna separa Datos personales, Preferencias, Horas y los dos periodos en pestañas con navegación por teclado. El cambio de pestaña conserva las ediciones y el cambio de panel pide resolver los borradores pendientes.

La prueba del paquete comprueba el cambio de panel, la visibilidad del calendario y la separación de periodos en pestañas. La revisión visual se hizo en Windows con una ventana de 1000 × 700 y un almacén de prueba.

### Cuadrícula mensual de Tauri 2.1.2

Calendario abre el mes actual, o el mes del límite del curso si hoy cae fuera de él. La cuadrícula muestra los festivos e intervalos excluidos en naranja, y los sábados y domingos en gris. Al pulsar un día se muestra su fecha y el nombre completo de las exclusiones, con acceso a su ficha de edición. La lista lateral lleva al mes correspondiente. Las pruebas abarcan un día añadido, un sábado, un día ordinario y el intervalo de Navidad entre diciembre y enero.

### Autoguardado de Empresas y Tutores 2.1.10

Las fichas de empresas y tutores se guardan al editar y antes de cambiar de ficha o panel. Se retira Guardar y el aviso de éxito persistente; los errores siguen visibles. El guardado en segundo plano conserva el campo y el foco de escritura. La prueba del paquete verifica ambas fichas y el guardado al navegar.
