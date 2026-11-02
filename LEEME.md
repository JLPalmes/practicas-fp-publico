# Prácticas FP

Edición de Mac: aplicación nativa para Apple Silicon (arm64), macOS 14 o posterior. Versión 1.8.2.
Abre **PracticasFP.app** con doble clic. Puedes moverla a la carpeta Aplicaciones; los datos se conservan por separado.

Hay una primera adaptación nativa **para Windows 10/11 de 64 bits**, con instalador y formato de datos compatible. Consulta [Windows/LEEME.md](Windows/LEEME.md) para instalarla, trasladar copias y conocer las diferencias de esta edición de pruebas. La aplicación descrita a continuación es la edición de Mac.

## Primeros pasos

1. En **Empresas**, pulsa Añadir y completa los datos. Registra los hitos del concierto y sus fechas.
2. En **Tutores**, añade nombre, empresa, teléfono y email.
3. En **Alumnas**, crea tus siete fichas. No se incluyen personas de ejemplo. DNI y NUSS se guardan como texto, conservando los ceros iniciales.
4. Anota el tipo de empresa y la zona preferidos. Asigna una empresa provisional y cambia a definitiva cuando corresponda. Las preferencias se conservan.
5. Indica la fecha de inicio y las horas diarias de lunes a viernes. El final se calcula para las horas objetivo de la alumna (500 por defecto); se muestra cuánto hace falta en la última jornada.
6. En **Calendario**, añade los días de libre disposición cuando los conozcas y activa la casilla de confirmación.

Todos los cambios se guardan automáticamente. Los estados documentales son independientes y tienen fecha editable.

## Importar alumnas desde CSV o Excel

En **Alumnas**, pulsa **Importar CSV / Excel** y elige un archivo:
- CSV separado por comas, punto y coma o tabuladores; admite UTF-8, UTF-16 y Windows-1252.
- Excel **.xlsx**, sin necesidad de tener Excel instalado. Los archivos antiguos .xls deben guardarse previamente como .xlsx o CSV.

Selecciona la hoja y la fila que contiene los títulos de las columnas. La aplicación reconoce los títulos habituales, pero puedes cambiar la correspondencia de cada columna. Solo el nombre es obligatorio; los apellidos pueden estar en columnas separadas.

Campos admitidos: nombre, apellidos, DNI/NIE, NUSS, email, teléfono, grupo, tipo de empresa preferido, zona, detalle de preferencias y observaciones.

Revisa la vista previa. Puedes desmarcar filas. Se omiten filas vacías, con errores o con posibles duplicados por nombre, DNI, NUSS o email, tanto frente a las fichas existentes como dentro del propio archivo. Esta importación añade fichas nuevas; no actualiza ni sobrescribe las existentes. Si dos personas comparten nombre, revisa ese caso y añade manualmente la ficha que corresponda.

Pulsa **Importar** para incorporar la selección. Las nuevas fichas quedan pendientes de asignación, de modo que la asignación posterior sigue comprobando las plazas de cada empresa. Se guarda una copia local antes de añadir las alumnas.

En Excel, conviene guardar DNI, NUSS y teléfono como **texto**. Se conservan los ceros que estén almacenados como texto o mediante un formato simple de ceros. La aplicación no puede reconstruir cifras que Excel haya eliminado previamente. Las celdas con fórmulas o números de más de 15 cifras se señalan para revisión: pega su resultado como valor o corrige el identificador como texto antes de importar.

Límites para el listado: 20 MB, 10.000 filas y 256 columnas. El procesamiento es local.

## Plazas de empresa

En cada empresa, indica el número de plazas ofrecidas. Se muestran las ocupadas y libres. Las empresas llenas o sin cupo definido no admiten nuevas asignaciones.

Cada alumna vinculada ocupa una plaza, independientemente de si su asignación es provisional o definitiva. Para liberarla, cambia su empresa o selecciona Sin asignar. No se puede reducir el cupo por debajo del número de alumnas vinculadas.

Las fichas y copias de la versión anterior se conservan: las empresas aparecen con plazas sin indicar hasta que establezcas su cupo. No se inventa un número de plazas para las empresas existentes.

## Reducciones de jornada

En la ficha de la alumna, pulsa **Añadir cambio de jornada** e indica la fecha efectiva y las nuevas horas diarias. El cálculo mantiene el horario anterior hasta el día previo. Puedes añadir más de un cambio.

La fecha final también se puede ajustar manualmente. Esa opción muestra las horas que sumaría el horario hasta la fecha elegida; cambiar la fecha por sí solo no cambia las horas de jornada.

Las horas del panel son una previsión hasta el día anterior, no un control de asistencia. Marcar práctica terminada es una decisión manual.

## Calendario

Se excluyen sábados, domingos y los intervalos que aparecen en Calendario, con ambos extremos incluidos. Las exclusiones solapadas no descuentan dos veces el mismo día.

Se incluyen vacaciones y festivos aplicables de septiembre de 2026 a junio de 2027 para Las Palmas de Gran Canaria. Navidad incorpora la corrección oficial: 23 de diciembre a 8 de enero. Falta únicamente introducir los días propios del instituto para ese periodo.

Para otros años o prácticas en verano: introduce sus vacaciones y festivos, actualiza el periodo revisado y el curso de referencia. Las fechas no se repiten automáticamente. El programa advierte cuando una práctica sale del periodo revisado.

Fuentes verificadas:
- [Calendario escolar](https://www.gobiernodecanarias.org/boc/2026/061/1025.html).
- [Corrección de Navidad](https://www.gobiernodecanarias.org/boc/2026/075/1240.html).
- [Festivos locales 2027](https://www.gobiernodecanarias.org/boc/2026/168/3035.html).
- [Calendario laboral 2026](https://www.gobiernodecanarias.org/boc/2025/088/1659.html).
- [Calendario laboral 2027](https://www3.gobiernodecanarias.org/noticias/el-gobierno-aprueba-el-calendario-laboral-de-canarias-para-2027-y-abre-el-plazo-para-fijar-las-fiestas-locales/).

## Datos y copias

Datos: ~/Library/Application Support/PracticasFP/datos.json
Copias: ~/Library/Application Support/PracticasFP/Copias/

En **Ajustes y copias** puedes abrir estas carpetas, crear una copia y restaurarla. Se crea una copia al abrir si existen datos; antes de restaurar se conserva otra. Si un archivo no se puede leer, no se sobrescribe.

No hay cuentas, servicios en la nube, analítica ni adjuntos. Los enlaces a las fuentes solo abren el navegador si los pulsas. Las copias contienen los mismos datos personales y tampoco se suben desde la aplicación.

## Validación y código

Ejecuta **Validar.command** para comprobar cálculo, cupos, almacenamiento, migración, seguimiento mensual, importación CSV/Excel y las nuevas funciones. Utiliza datos ficticios y carpetas temporales, que elimina al terminar. También verifica que compile el código de la interfaz. Requiere las herramientas de desarrollo de Apple y Python 3.

Fuentes/ contiene el código Swift y las pruebas. Compilar.command reconstruye la aplicación con las herramientas de desarrollo de Apple. La aplicación tiene firma local; no se ha distribuido ni notarizado mediante una cuenta de Apple Developer.

## Panel de empresas (1.3)

Filtra por empresas esperando respuesta, que admiten, que rechazan o con asignaciones definitivas. Puedes registrar la respuesta y las plazas. Las asignaciones definitivas muestran el concierto, el tutor y los envíos y devoluciones de los Anexos I y II por alumna.

Los contactos se calculan por meses desde el inicio de la práctica. Si varias alumnas generan vencimientos en el mismo mes, hay un único contacto para la empresa, con la primera fecha prevista. Se puede marcar realizado, editar la fecha y anotar observaciones. Los contactos guardados permanecen en el historial aunque cambien las fechas o asignaciones.

Una devolución registrada confirma automáticamente la remisión del anexo. Si antes constaba pendiente, se usa la fecha de devolución como referencia editable para la remisión.

Para actualizar desde este proyecto, cierra Prácticas FP, ejecuta Compilar.command y copia PracticasFP.app a Aplicaciones, reemplazando la anterior. Los datos se conservan en la carpeta indicada arriba.

## Cambios 1.4

«Guardar copia de seguridad…» abre un diálogo para elegir carpeta y nombre, con botón «Guardar copia». La aplicación escribe los datos actuales, verifica el archivo y muestra su ubicación. «Mostrar copias automáticas» es una acción separada.

Marcar un Anexo I o II como devuelto marca también su remisión. Desmarcar la remisión desmarca la devolución para mantener la coherencia; desmarcar solo la devolución conserva la remisión.

El panel de empresas muestra resúmenes compactos de plazas, tutores y estados de ambos anexos. Los trámites editables, fechas y contactos se despliegan cuando se necesitan. Las casillas de las fichas se distribuyen en columnas adaptadas al ancho disponible.

En el panel de empresas, los botones − y + junto a Plazas concedidas ajustan el cupo directamente. Restar se desactiva cuando las plazas coinciden con las alumnas vinculadas, incluidas las provisionales.

En la versión 1.4.2, el estado de contacto se consulta y cambia desde el desplegable visible bajo el nombre de la empresa. El icono de calendario de esa misma línea permite editar las fechas. El lateral comienza por Panel de alumnos y Panel de empresas.

Versión 1.4.3: el Panel de alumnos usa los tamaños de letra y espaciados compactos del Panel de empresas en contadores y tarjetas.

Versión 1.4.4: se eliminan de la interfaz las fuentes iniciales del calendario y los registros anteriores a la actualización de las fichas de alumnas.

## Periodos y cambios de empresa (1.5)

«Añadir nuevo periodo» crea una fila con las horas en blanco, para evitar confirmar por descuido la jornada anterior. Hay que indicar una jornada válida antes de que pueda calcularse la fecha final.

Cada periodo puede continuar en la empresa anterior o comenzar en otra. Al escoger una empresa nueva, se puede asignar también su tutor y gestionar por separado sus Anexos I y II. La alumna permanece vinculada a las dos empresas, cada una aparece en su panel y ambas reservan una plaza. El seguimiento mensual de cada empresa se calcula únicamente dentro de las fechas en las que la alumna realiza allí sus prácticas.

Versión 1.5.1: se explicita que el Anexo I formaliza la asignación del tutor a la alumna y el Anexo II contiene su calificación final. Cada nueva práctica genera sus propios anexos, sin reutilizar los estados documentales de la anterior.

Versión 1.5.2: los conciertos se muestran exclusivamente en las empresas. No aparecen en las fichas ni se incluyen en el progreso documental de las alumnas.

## Espacio unificado de alumnas y empresas

El lateral reúne cada panel y sus fichas en una sola sección: **Alumnas** y **Empresas**. Pulsa una tarjeta de alumna o el nombre o resumen de una empresa para abrir su ficha junto al panel. La divisoria permite ajustar el espacio; «Cerrar ficha» devuelve todo el ancho al resumen. Los filtros permanecen al abrir y cerrar una ficha. Añadir e importar están disponibles en la cabecera correspondiente.

Las mejoras previstas se recogen en MEJORAS.md.

## Mejoras 1.6

- **Pendientes** reúne asignaciones sin confirmar, tutores sin asignar, anexos remitidos pendientes de devolución y contactos mensuales vencidos. Cada aviso abre la ficha correspondiente. Los trámites completos siguen visibles en cada ficha.
- **Horas objetivo** se configura en Horario y previsión por alumna, entre más de 0 y 10.000 horas. Las fichas anteriores conservan 500 horas. El cálculo, la última jornada, el progreso y el informe usan ese objetivo.
- **Historial** permite archivar el curso actual e iniciar otro tras confirmar. Conserva una instantánea completa para consulta y exportación de su resumen. El curso nuevo mantiene empresas, conciertos y tutores, pero empieza sin alumnas, seguimientos, cupos ni respuestas de contacto. Vacía las exclusiones y desmarca la confirmación de días del instituto; ajusta también las fechas del periodo revisado en Calendario. Se crea una copia antes de archivar.
- **Exportar informe…** guarda texto UTF-8: con ficha abierta, la alumna o empresa seleccionada; sin ficha, el curso completo. Incluye periodos, jornadas, tutores, previsiones y trámites pendientes. Los informes de empresa incluyen contactos y conciertos. No se envían automáticamente.
- **Deshacer y Rehacer** recuperan cambios durante la sesión, incluidas eliminaciones y archivo de curso, con hasta 50 estados. El historial de deshacer no persiste al cerrar; para recuperaciones posteriores utiliza las copias. La escritura consecutiva en un mismo campo se agrupa: cambiar de campo, navegar o una pausa superior a dos segundos inicia otro paso.
- La ficha muestra avisos por nombre vacío, posibles duplicados y formatos de DNI/NIE, NUSS o correo que necesitan revisión. Son avisos orientativos; no certifican la validez del documento ni impiden introducirlo.

El formato de datos pasa a la versión 3 para proteger las horas configurables y el historial de cursos: las aplicaciones anteriores rechazarán este formato. Se siguen leyendo las copias de las versiones 1 y 2. Conserva una copia previa si necesitas volver a una aplicación anterior.

## Ergonomía 1.7

- Las fichas de alumnas y empresas tienen apartados plegables. Se recuerda qué apartados de cada tipo de ficha dejas abiertos, también al reiniciar.
- Los botones de empresa, tutor y alumna permiten navegar entre sus fichas. Cada sección conserva su búsqueda y selección; los filtros del panel se mantienen durante la sesión.
- El listado conserva su desplazamiento al cambiar de sección durante la sesión. Arrastra la divisoria entre panel y ficha para ajustar el ancho; Alumnas y Empresas recuerdan su propia anchura, también al reiniciar.
- Las tarjetas de empresa resaltan la ficha abierta con un borde, como las de alumnas.
- Deshacer agrupa las pulsaciones consecutivas de un campo. Los cambios en campos distintos, casillas, fechas y eliminaciones siguen siendo acciones separadas.
- **Pendientes** separa «Requiere actuación ahora» de «Documentación de cierre · para más adelante». El Anexo II pasa a actuación actual al remitirlo, al superar el fin previsto de su periodo o al marcar la práctica como terminada. La clasificación es orientativa y no introduce plazos oficiales.

## Documentos y periodos 1.8

Cada práctica aparece en un bloque con su empresa, tutor, fechas, jornada, cambios de horas y documentos. Las prácticas posteriores tienen sus propios anexos y estados de inicio y finalización. El resumen del panel usa la última práctica; cerrar la anterior no interrumpe los contactos mensuales de la posterior.

Los documentos se siguen en líneas horizontales de hitos. Pulsa un hito para marcarlo, corregir su fecha o dejarla sin registrar; desplaza la línea horizontalmente para ver todos los pasos.

- **Anexo I:** generado, enviado al tutor, recibido del tutor, enviado a la alumna, recibido de la alumna, firmado por mí y archivado.
- **Anexo II:** generado, enviado al tutor, recibido del tutor, firmado por mí y archivado. No requiere firma de la alumna.
- **Concierto:** generado, enviado al director, recibido del director, enviado al representante de la empresa, recibido de la empresa, enviado al coordinador y carga confirmada en la aplicación.

Cada devolución tiene su recepción y fecha propias. Registrar una recepción confirma el envío correspondiente si faltaba, pero deja su fecha sin registrar. Desmarcar un envío desmarca su recepción asociada. No se marcan automáticamente todos los hitos anteriores ni se inventan fechas. Las fechas de contacto o respuesta desconocidas también aparecen como «Sin registrar», con una acción explícita para añadirlas.

Los estados anteriores se conservan. La antigua casilla de «firmado por mí y remitido» conserva tanto la firma propia como el envío; la firma de la alumna se conserva como recepción firmada. Archivo y otros pasos nuevos no se dan por completados. Revisa la información migrada para completar lo que falte.

La cabecera de la ficha mantiene visibles nombre, empresa y estado al desplazarte. Los filtros «Sin tutor», «Anexo I pendiente», «Finalizan este mes» y «Contacto vencido» muestran su número de coincidencias. «Anexo I pendiente» incluye cualquier hito sin completar hasta el archivo.

El menú **Informe…** ofrece texto, PDF paginado en A4 e impresión. Con una ficha abierta prepara esa alumna o empresa; sin ficha, todo el curso. Incluye fechas y estados de los hitos, periodos y jornadas. Los PDF incorporan español de España (es-ES) en sus metadatos.

**Restaurar una copia…** muestra primero un listado con el curso y las cantidades de fichas. Al seleccionar una copia se muestran fecha del archivo, centro, curso, alumnas, empresas, tutores y cursos archivados, además de la comparación con los datos activos. Puedes elegir una copia de otra carpeta. Nada se sustituye hasta confirmar la restauración.

El formato de datos pasa a la **versión 4**. Se siguen leyendo las versiones 1, 2 y 3; las aplicaciones anteriores no pueden abrir el nuevo formato. Las copias automáticas previas a la actualización conservan el formato anterior.

## Ergonomía 1.8.1

Las empresas abren su ficha pulsando el nombre o el resumen de plazas, sin un botón «Ficha de empresa» separado. Los controles de estado, fechas, plazas y desplegables mantienen sus acciones propias.

## Cierre y versión 1.8.2

La versión de la copia abierta se muestra al pie del lateral. En Ajustes y copias aparecen la versión y su número de compilación. Cerrar la última ventana con el botón rojo termina también la aplicación.
