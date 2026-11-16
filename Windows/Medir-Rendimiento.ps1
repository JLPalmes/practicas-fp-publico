param([ValidateSet('Windows','SQLite','Tauri')][string]$Modo='Windows',[switch]$Interactivo,[string]$Copia,[switch]$Piloto,[switch]$VerificarPiloto,[string]$SoloMotor)
$ErrorActionPreference = 'Stop'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$sources = @('Datos.cs','Periodos.cs','Presentacion.cs','Store.cs','Historial.cs','Importacion.cs','App.cs','Controles.cs','VistaEstado.cs','Fichas.cs','InformesVista.cs','ImportacionVista.cs','Rendimiento.cs','RendimientoSqlite.cs') |
    ForEach-Object { Join-Path $PSScriptRoot $_ }
$references = @('System.Windows.Forms','System.Drawing','System.Web.Extensions','System.Xml.Linq','System.IO.Compression','System.IO.Compression.FileSystem') |
    ForEach-Object { "/r:$_.dll" }
$output = Join-Path ([IO.Path]::GetTempPath()) ("PracticasFP-Rendimiento-" + [guid]::NewGuid() + ".exe")
$previousCopy = $env:PRACTICAS_FP_BENCHMARK_COPY
if ($Copia -and ($Interactivo -or $Modo -eq 'SQLite')) { throw 'Usa -Copia con Windows o Tauri en modo automatico.' }
if ($Piloto -and ($Modo -ne 'Tauri' -or $Copia -or $Interactivo)) { throw 'Usa -Piloto con -Modo Tauri.' }
if ($VerificarPiloto -and ($Modo -ne 'Tauri' -or $Copia -or $Interactivo -or $Piloto)) { throw 'Usa -VerificarPiloto con -Modo Tauri.' }
try {
    $env:PRACTICAS_FP_BENCHMARK_COPY = if ($Copia) { (Get-Item -LiteralPath $Copia -ErrorAction Stop).FullName }
    & $compiler /nologo /target:exe /platform:x64 /optimize+ /main:Rendimiento /utf8output "/out:$output" $references $sources
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo compilar la prueba de rendimiento.' }
    if ($SoloMotor) {
        Copy-Item -LiteralPath $output -Destination $SoloMotor
        return
    }
    if ($Modo -eq 'Tauri') {
        $prototype = Join-Path (Split-Path $PSScriptRoot -Parent) 'Experimentos\Tauri'
        Copy-Item -LiteralPath $output -Destination (Join-Path $prototype 'motor.exe')
        & (Join-Path $PSScriptRoot 'CrearIcono.ps1') -OutputPath (Join-Path $prototype 'icon.ico')
        $arguments = @('run','--release','--locked','--manifest-path',(Join-Path $prototype 'Cargo.toml'))
        if ($Piloto) { cargo @arguments -- --piloto }
        elseif ($Copia) { cargo @arguments -- --medir-copia }
        elseif ($Interactivo) { cargo @arguments }
        else {
            $session = [guid]::NewGuid().ToString('N')
            $previousSession = $env:PRACTICAS_FP_TEST_SESSION
            $env:PRACTICAS_FP_TEST_SESSION = $session
            $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
            $sessionFolder = Join-Path $tempRoot "PracticasFP-Rendimiento-$session"
            try {
                $firstRun = if ($VerificarPiloto) { '--verificar-piloto' } else { '--medir' }
                $nextRun = if ($VerificarPiloto) { '--verificar-reapertura-piloto' } else { '--verificar-reapertura' }
                cargo @arguments -- $firstRun
                if ($LASTEXITCODE -ne 0) { throw 'La primera ejecucion de Tauri ha fallado.' }
                cargo @arguments -- $nextRun
            }
            finally {
                $env:PRACTICAS_FP_TEST_SESSION = $previousSession
                if (Test-Path -LiteralPath $sessionFolder) {
                    $resolved = (Resolve-Path -LiteralPath $sessionFolder).Path
                    if ($resolved -eq $sessionFolder -and (Split-Path $resolved -Parent).TrimEnd('\') -eq $tempRoot.TrimEnd('\')) {
                        Remove-Item -LiteralPath $resolved -Recurse
                    }
                }
            }
        }
    }
    elseif ($Modo -eq 'SQLite') { & $output --sqlite }
    else { & $output }
    if ($LASTEXITCODE -ne 0) { throw 'La prueba de rendimiento ha fallado.' }
}
finally {
    $env:PRACTICAS_FP_BENCHMARK_COPY = $previousCopy
    if (Test-Path -LiteralPath $output) { Remove-Item -LiteralPath $output }
}
