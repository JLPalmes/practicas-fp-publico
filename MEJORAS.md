# Mejoras implementadas · 1.8

- Paneles y fichas unificados en Alumnas y Empresas, con divisoria ajustable y cierre de ficha.
- Sección Pendientes con acceso a fichas: asignaciones, tutores, devoluciones de anexos y contactos vencidos.
- Horas objetivo configurables por alumna, con 500 por defecto para datos anteriores.
- Archivo de curso con instantánea completa, consulta del resumen y comienzo de un curso nuevo.
- Informes de texto exportables por alumna, empresa y curso.
- Deshacer y rehacer cambios durante la sesión, hasta 50 estados.
- Avisos de datos incompletos, formatos y posibles duplicados en edición manual.
- Validar.command para pruebas reproducibles y documentación de instalación actualizada.

## Posibles ampliaciones

- Navegación detallada por fichas históricas; ahora el historial ofrece un resumen consultable y exportable, conservando la instantánea completa.


## Plataforma

La aplicación se desarrolla y compila exclusivamente para Apple Silicon (arm64). No se mantiene compatibilidad con Intel ni se generan binarios universales.

## Ergonomía 1.7

- Apartados plegables con preferencias de apertura por tipo de ficha.
- Navegación mediante enlaces directos entre empresas, tutores y alumnas, con destinos explícitos.
- Conservación de búsqueda, filtros, selección y desplazamiento durante la sesión; ancho independiente y persistente para cada panel.
- Resaltado de la empresa seleccionada.
- Escritura consecutiva del mismo campo agrupada para deshacer.
- Separación de tareas actuales y documentación de cierre; Anexo II vinculado al periodo correspondiente.

## Documentos y periodos 1.8

- Líneas de hitos específicas para Anexo I, Anexo II y concierto, con envío y recepción separados, firma propia y archivo cuando corresponde.
- Conservación de estados anteriores sin inventar fechas para hitos nuevos o envíos inferidos por una recepción.
- Prácticas en bloques con su empresa, tutor, jornada, fechas y anexos; cambios de jornada agrupados dentro de cada práctica.
- Resumen fijo de identidad y estado de la ficha.
- Filtros prácticos con contadores.
- Fechas desconocidas explícitas y editables.
- Informes PDF A4 paginados, con idioma es-ES, e impresión.
- Vista previa de copias antes de restaurar.
- Seguimiento y contadores adaptados a prácticas sucesivas.

## Cierre y versión 1.8.2

- Versión visible en el pie del lateral y versión y compilación en Ajustes y copias, leídas de los metadatos de la aplicación abierta.
- Cerrar la última ventana con el botón rojo termina también la aplicación.
- Instalador 1.8.2 preparado como candidato final, a petición del usuario.

## Interfaz compacta de Mac · 1.8.3

- La ficha admite un ancho mínimo de 360 puntos, frente a 450; el panel admite 300, frente a 340. La divisoria conserva el ajuste independiente por sección.
- El lateral, la cabecera, los contadores y los formularios tienen márgenes más contenidos. La ventana admite 900 × 620 puntos.
- Los filtros de alumnas y empresas se adaptan al ancho disponible.
- Los desplegables permiten pulsar toda la cabecera, incluido el título y el espacio lateral. La zona activa tiene al menos 32 puntos de alto y la flecha dispone de un área de 24 × 24 puntos, sin ampliar los campos del contenido.
- Los hitos se distribuyen en filas numeradas, de izquierda a derecha y de arriba abajo, para consultar la secuencia sin desplazamiento horizontal. Mantienen la edición individual y las fechas.
- Validación: 133 comprobaciones, comprobación de tipos de la interfaz y compilación arm64 superadas. Revisión visual mediante renderizado de las vistas SwiftUI reales con datos ficticios: alumnas y empresas a 900 × 620 y 1250 × 850 puntos, concierto en ficha estrecha y Anexo I a 360 puntos; sin solapamientos ni desplazamiento horizontal en los hitos. Los contadores se distribuyen en dos columnas para evitar filas con un único contador. La prueba directa con ratón sigue pendiente porque el control de aplicaciones no está disponible.
- Instalador 1.8.3 preparado a petición del usuario. Windows no cambia.

## Panel y ficha permanentes en Mac · 1.8.4

- Alumnas y Empresas mantienen siempre la columna de ficha; se elimina «Cerrar ficha».
- Al entrar se conserva la última selección válida de esa sección durante la sesión, o se abre la primera ficha disponible. Al eliminarla se selecciona otra; al vaciar el listado se ofrece añadir en la columna derecha.
- El ancho de ambas columnas y los filtros conservan su comportamiento. La búsqueda no cierra la ficha ni interrumpe una edición si deja de coincidir con el filtro.
- Informe incluye una opción explícita para el curso completo, además del informe de la ficha seleccionada.
- Validación: 139 comprobaciones superadas y compilación arm64 correcta. Renderizadas las dos secciones con datos y vacías a 900 y 1250 puntos; comprobado también el borrado de la ficha abierta y de la última alumna mientras la vista permanece activa.
- Incluido en el instalador Mac 1.8.4 solicitado por el usuario. Windows no cambia.

## Lista y ficha de tutores · 1.8.4

- Cada fila muestra tutor, empresa y alumnas tutorizadas, incluidas las asignaciones en periodos posteriores sin duplicar alumnas.
- La búsqueda admite tutor, empresa y alumna. Los tutores sin vínculos muestran «Sin empresa» o «Sin alumnas asignadas».
- Tutores utiliza el mismo espacio permanente de listado y ficha, con divisoria y ancho propios, selección automática y opción de añadir cuando está vacío.
- Validación: 143 comprobaciones y compilación arm64 superadas. Vistas reales renderizadas con datos ficticios a 900 y 1250 puntos, y estado vacío comprobado.
- Incluido en el instalador Mac 1.8.4 solicitado por el usuario. Windows no cambia.

## Windows 1.8.4-windows.3

- Fichas permanentes, selección inicial automática, recuperación por sección y alta desde la columna vacía.
- Tutores en filas con empresa y alumnas de todos sus periodos, sin duplicados; búsqueda por cualquiera de esos datos y enlaces en la ficha.
- Márgenes y anchos mínimos menores, columnas de listado ajustables al espacio y hitos en filas numeradas. Cabeceras completas pulsables y adaptadas al título.
- Informe de ficha o curso completo explícitos.
- Pruebas funcionales y pruebas de formularios reales en Windows mediante GitHub, con datos ficticios y vistas previas. La comprobación manual en el equipo del usuario queda pendiente.
