$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$output = Join-Path $projectRoot 'dist\Windows'
New-Item -ItemType Directory -Force -Path $output | Out-Null
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (!(Test-Path $compiler)) { throw 'Se necesita .NET Framework 4 de Windows.' }
$references = @('/r:System.Windows.Forms.dll', '/r:System.Drawing.dll', '/r:System.Web.Extensions.dll', '/r:System.Xml.Linq.dll', '/r:System.IO.Compression.dll', '/r:System.IO.Compression.FileSystem.dll')
$sourceNames = @('Datos.cs','Presentacion.cs','Store.cs','Historial.cs','Importacion.cs','App.cs','VistaEstado.cs','Fichas.cs','InformesVista.cs','ImportacionVista.cs','Version.cs')
$sources = @($sourceNames | ForEach-Object { Join-Path $PSScriptRoot $_ })
$license = Join-Path $projectRoot 'LICENSE'
$notice = Join-Path $projectRoot 'AVISO-LICENCIA.txt'
$manifest = Join-Path $PSScriptRoot 'App.manifest'
& $compiler /nologo /target:winexe /platform:x64 /optimize+ /utf8output "/win32manifest:$manifest" "/out:$output\PracticasFP.exe" $references "/resource:$license,LICENSE" "/resource:$notice,AVISO-LICENCIA.txt" $sources
if ($LASTEXITCODE -ne 0) { throw 'No se ha compilado la aplicación.' }
$version = [System.Diagnostics.FileVersionInfo]::GetVersionInfo((Join-Path $output 'PracticasFP.exe')).ProductVersion
if ($version -notmatch '^[0-9A-Za-z][0-9A-Za-z._-]*$') { throw 'La aplicación no tiene una versión válida para nombrar el instalador.' }
$installer = Join-Path $output "Instalar-PracticasFP-$version-x64.exe"
$testSources = @('Datos.cs','Presentacion.cs','Store.cs','Historial.cs','Importacion.cs','Actualizacion.cs','Pruebas.cs') | ForEach-Object { Join-Path $PSScriptRoot $_ }
& $compiler /nologo /target:exe /platform:x64 /utf8output "/out:$output\Pruebas.exe" $references $testSources
if ($LASTEXITCODE -ne 0) { throw 'No se han compilado las pruebas.' }
& "$output\Pruebas.exe"
if ($LASTEXITCODE -ne 0) { throw 'Han fallado las pruebas.' }
& $compiler /nologo /target:exe /platform:x64 /main:UiTests /utf8output "/out:$output\PruebasInterfaz.exe" $references $sources (Join-Path $PSScriptRoot 'PruebasInterfaz.cs')
if ($LASTEXITCODE -ne 0) { throw 'No se han compilado las pruebas de interfaz.' }
& "$output\PruebasInterfaz.exe" $output
if ($LASTEXITCODE -ne 0) { throw 'Han fallado las pruebas de interfaz.' }
& $compiler /nologo /target:winexe /platform:x64 /optimize+ /utf8output "/win32manifest:$manifest" "/out:$installer" /r:System.Windows.Forms.dll /r:System.Drawing.dll /r:Microsoft.CSharp.dll "/resource:$output\PracticasFP.exe,PracticasFP.exe" "/resource:$license,LICENSE" "/resource:$notice,AVISO-LICENCIA.txt" (Join-Path $PSScriptRoot 'Instalador.cs') (Join-Path $PSScriptRoot 'Actualizacion.cs') (Join-Path $PSScriptRoot 'Version.cs')
if ($LASTEXITCODE -ne 0) { throw 'No se ha compilado el instalador.' }
$installerVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($installer).ProductVersion
if ($installerVersion -ne $version) { throw 'La versión del instalador no coincide con la aplicación.' }
Get-FileHash $installer -Algorithm SHA256 | Format-List
Write-Host "Instalador preparado: $installer"
