# Actualizaciones de Prácticas FP

Las ediciones de Mac y Windows consultan catálogos independientes del repositorio
público `JLPalmes/practicas-fp-publico`. Cada plataforma avanza su propia versión.
La primera versión que incorpore el actualizador se instala manualmente desde el
DMG o EXE. A partir de ella, la aplicación comprueba el catálogo estable y permite
buscar actualizaciones desde su menú. La persona usuaria decide cuándo instalar.

## Preparar una versión

1. Incrementa la versión estable `mayor.menor.parche` de la plataforma que cambia.
   En Mac se define en `Compilar.command`. En Windows se registra en
   `Experimentos/Tauri/tauri.conf.json` (versión y título), el bloque `TAURI` de
   `Windows/Instalador.cs` y el bloque `TAURI` de `Windows/Version.cs`.
2. Redacta las notas en español con la fecha, los cambios visibles, la
   compatibilidad y cualquier acción que deba realizar la persona usuaria.
3. Ejecuta manualmente la acción **Preparar paquetes de actualización** en la
   revisión que quieras publicar. Establece las variables públicas del repositorio
   `PRACTICASFP_SPARKLE_PUBLIC_KEY` y `PRACTICASFP_TAURI_PUBLIC_KEY`. La acción
   compila, prueba y adjunta artefactos a la ejecución. La publicación de una
   Release se hace desde GitHub tras revisar y firmar esos artefactos.
4. Para compilar localmente, utiliza Sparkle 2.10.1 y ejecuta
   `./Compilar.command` con las variables `PRACTICASFP_SPARKLE_DIR` y
   `PRACTICASFP_SPARKLE_PUBLIC_KEY`. Empaqueta con
   `ditto -c -k --keepParent PracticasFP.app PracticasFP-VERSION-arm64.zip`.
   Para el primer DMG, pon una copia de la app y un enlace a Aplicaciones en una
   carpeta de preparación y usa `hdiutil create -srcfolder CARPETA -format UDZO PracticasFP-VERSION-arm64.dmg`.
   En Windows x64 ejecuta `Windows/Compilar-Tauri.ps1 -Verificar` con
   `PRACTICASFP_TAURI_PUBLIC_KEY` definido.
5. Conserva los archivos fuente correspondientes a cada paquete publicado,
   incluidas las instrucciones de compilación. El paquete Windows incluye el
   ZIP de fuentes generado por el script. Los catálogos se actualizan solo tras
   publicar y comprobar los paquetes finales.

## Firmar y publicar

Custodia una clave por plataforma, con una copia cifrada fuera del repositorio.
Mantén las claves de pruebas independientes. Las compilaciones necesitan solo la
clave pública. Firma los paquetes finales en un equipo controlado. Mantén las
claves privadas, contraseñas y tokens fuera de Git, de los registros de CI y de los
instaladores.

### Mac

Genera la clave con `bin/generate_keys --account practicas-fp` de Sparkle. La clave
privada se guarda en el Llavero y el comando imprime la pública. Usa la pública
en el build. Genera el catálogo desde una carpeta que contenga solo el ZIP
estable de Mac y su archivo de notas `.md` del mismo nombre base. Pon la fecha
en la primera línea de las notas para que figure en el aviso.

```sh
bin/generate_appcast --account practicas-fp --embed-release-notes --maximum-deltas 0 \
  --download-url-prefix https://github.com/JLPalmes/practicas-fp-publico/releases/download/mac-vVERSION/ carpeta-del-zip
bin/sign_update --account practicas-fp --verify carpeta-del-zip/appcast.xml
```

Sustituye `VERSION` por el número real. Sparkle inspecciona los requisitos de la
app y firma el ZIP y el catálogo. Publica el paquete en la Release estable
`mac-vVERSION`. Tras comprobar la descarga, adjunta el `appcast.xml` firmado a
la Release de catálogo `actualizaciones-mac`. Conserva el mismo nombre del
archivo en futuras promociones. Sirve el catálogo firmado sin volver a editarlo.

### Windows

Crea una clave de Tauri con `npx @tauri-apps/cli@2.12.5 signer generate --write-keys RUTA_PROTEGIDA`.
Usa la clave pública al compilar. Para firmar, facilita la ruta privada con
`TAURI_SIGNING_PRIVATE_KEY_PATH` y, si procede, su contraseña con
`TAURI_SIGNING_PRIVATE_KEY_PASSWORD`, desde el gestor de secretos de tu equipo.

```powershell
npx @tauri-apps/cli@2.12.5 signer sign --app-version VERSION Instalar-PracticasFP-Tauri-VERSION-x64.exe
```

La firma vincula los bytes y la versión. Publica el EXE, su firma y las fuentes
en `tauri-vVERSION`. Luego adjunta `latest.json` a la Release de catálogo
`actualizaciones-windows`. Usa la fecha ISO 8601 y copia íntegro el contenido
del `.sig` en el campo `signature`.

```json
{
  "version": "2.1.4",
  "pub_date": "2026-11-18T12:00:00Z",
  "notes": "Novedades de la versión.",
  "platforms": {
    "windows-x86_64": {
      "url": "https://github.com/JLPalmes/practicas-fp-publico/releases/download/tauri-v2.1.4/Instalar-PracticasFP-Tauri-2.1.4-x64.exe",
      "signature": "CONTENIDO_DEL_ARCHIVO_SIG"
    }
  }
}
```

Tauri verifica la firma y la versión. La aplicación valida que el archivo sea un
ejecutable Windows x64 y abre el instalador C# existente. Este pide confirmación,
sustituye los ejecutables en la misma carpeta y conserva la instalación anterior
para recuperación. El flujo deja que el usuario vuelva a abrir la aplicación
cuando termine.

## Prueba entre dos versiones

- Usa una cuenta de prueba en Mac o una máquina virtual de Windows x64. Incluye
  alumnas, empresas, preferencias, copias e informes ficticios. Exporta una copia
  y anota las rutas, recuentos y contenido de los archivos antes de actualizar.
- En Mac, ejecuta `Pruebas/preparar-actualizacion-mac.command` con
  `PRACTICASFP_SPARKLE_DIR` y `PRACTICASFP_SPARKLE_FEED`. Genera dos
  compilaciones y un catálogo firmado con una clave temporal. La URL de pruebas
  debe apuntar a un HTTPS de confianza con el nombre `appcast.xml`. Aloja los
  archivos de la subcarpeta `update` allí solo con autorización. Abre la versión
  inferior instalada fuera del DMG y busca la actualización. Prueba también el
  recorrido con una descarga real que conserve la cuarentena de macOS.
- En Windows, compila dos versiones con la clave pública de pruebas y
  `PRACTICASFP_TAURI_FEED` apuntando a un catálogo HTTPS de pruebas. Firma la
  superior y genera el manifiesto con la misma clave. Instala la inferior con
  el EXE habitual y comprueba que el instalador lanzado por Tauri mantiene la
  ruta, los accesos directos y una sola entrada de desinstalación.
- En cada plataforma comprueba ausencia de actualización, detección de la
  superior, aplazamiento, conexión fallida, descarga interrumpida y paquete
  manipulado. Repite con un catálogo estable que excluya la preliminar. Prueba
  un paquete incompatible y comprueba que se rechaza antes de reemplazar la app.
  Tras instalar, abre las fichas y compara los datos, preferencias, copias e
  informes con los de partida. Repite con acceso de un usuario sin privilegios.

Los datos de Mac permanecen en `~/Library/Application Support/PracticasFP/` y
sus preferencias en el dominio `es.practicasfp.mac`. Los datos de Windows
permanecen en `%LOCALAPPDATA%\PracticasFP-Tauri-Piloto\`. El actualizador no
cambia el formato de datos. Para una futura migración destructiva, prueba la
restauración de una copia válida antes de publicar y bloquéala si falla la copia.

## Retirada y recuperación

Retira la versión defectuosa del catálogo estable antes de retirar su paquete.
En Mac sustituye el catálogo por uno firmado con la versión segura anterior o
sin elementos. En Windows vuelve a apuntar a un manifiesto válido de la última
versión segura. Los clientes con una versión posterior no instalarán una inferior
automáticamente. Para quienes ya actualizaron, conserva una copia de sus datos,
instala manualmente la edición segura si puede leerlos o publica una corrección
con un número superior. Si cambió el formato, verifica la copia anterior antes
de restaurarla y conserva también la copia de los datos recientes.

Las preliminares se publican como tales y se prueban con otro catálogo o con una
instalación manual. GitHub no decide por sí solo qué versión notifica la app. Esa
decisión la toma el responsable al modificar el catálogo estable.
