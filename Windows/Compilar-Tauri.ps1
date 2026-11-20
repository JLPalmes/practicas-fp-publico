param([switch]$Verificar)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$tauri = Join-Path $root 'Experimentos\Tauri'
$output = Join-Path $root 'dist\Windows-Tauri'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$version = (Get-Content -Raw -LiteralPath (Join-Path $tauri 'tauri.conf.json') | ConvertFrom-Json).version
if ($version -notmatch '^\d+\.\d+\.\d+$') { throw 'La version debe contener tres numeros.' }
New-Item -ItemType Directory -Force -Path $output | Out-Null
$motor = Join-Path $output ("motor-" + [guid]::NewGuid() + ".exe")
$icon = Join-Path $tauri 'icon.ico'
& (Join-Path $PSScriptRoot 'Medir-Rendimiento.ps1') -SoloMotor $motor
& (Join-Path $PSScriptRoot 'CrearIcono.ps1') -OutputPath $icon
$target = 'x86_64-pc-windows-msvc'
$cargoOutput = Join-Path $tauri 'target'
cargo build --release --locked --features distribucion --target $target --target-dir $cargoOutput --manifest-path (Join-Path $tauri 'Cargo.toml')
if ($LASTEXITCODE -ne 0) { throw 'No se pudo compilar Tauri.' }
$app = Join-Path $cargoOutput "$target\release\practicas-fp-prototipo.exe"
$installer = Join-Path $output "Instalar-PracticasFP-$version-x64.exe"
$license = Join-Path $root 'LICENSE'
$notice = Join-Path $output 'AVISO-LICENCIA.txt'
$sourceName = "Fuentes-PracticasFP-$version.zip"
$noticeText = [IO.File]::ReadAllText((Join-Path $root 'AVISO-LICENCIA.txt')).Replace(
    'https://github.com/JLPalmes/practicas-fp-publico','Fuentes adjuntas: ' + $sourceName)
[IO.File]::WriteAllText($notice,$noticeText)
$manifest = Join-Path $PSScriptRoot 'App.manifest'
$sources = @('Instalador.cs','Actualizacion.cs','Version.cs') | ForEach-Object { Join-Path $PSScriptRoot $_ }
try {
    & $compiler /nologo /target:winexe /platform:x64 /optimize+ /define:TAURI /utf8output "/win32icon:$icon" "/win32manifest:$manifest" "/out:$installer" /r:System.Windows.Forms.dll /r:System.Drawing.dll /r:Microsoft.CSharp.dll "/resource:$app,PracticasFP.exe" "/resource:$motor,motor.exe" "/resource:$license,LICENSE" "/resource:$notice,AVISO-LICENCIA.txt" $sources
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo compilar el instalador.' }
} finally { if (Test-Path -LiteralPath $motor) { Remove-Item -LiteralPath $motor } }
if ([Diagnostics.FileVersionInfo]::GetVersionInfo($installer).ProductVersion -ne $version) { throw 'La version del instalador no coincide.' }
$sourceFiles = @('LICENSE','AVISO-LICENCIA.txt','Experimentos/README.md','ACTUALIZACIONES.md','Experimentos/Tauri/updater-public-key.txt',
    'Experimentos/Tauri/Cargo.toml','Experimentos/Tauri/Cargo.lock','Experimentos/Tauri/build.rs','Experimentos/Tauri/tauri.conf.json')
foreach ($folder in @('Windows','Experimentos/Tauri/src','Experimentos/Tauri/ui','Experimentos/Tauri/capabilities')) {
    $sourceFiles += Get-ChildItem -File -LiteralPath (Join-Path $root $folder) |
        Where-Object Extension -in '.cs','.ps1','.md','.manifest','.rs','.js','.html','.css','.json' |
        ForEach-Object { "$folder/$($_.Name)" }
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.IO.Compression
$sourceZip = Join-Path $output $sourceName
if (Test-Path -LiteralPath $sourceZip) { Remove-Item -LiteralPath $sourceZip }
$archive = [IO.Compression.ZipFile]::Open($sourceZip,[IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($path in ($sourceFiles | Sort-Object -Unique)) {
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive,(Join-Path $root $path),$path) | Out-Null
    }
} finally { $archive.Dispose() }
if ($Verificar) {
    $test = Join-Path ([IO.Path]::GetTempPath()) ("PracticasFP-Paquete-" + [guid]::NewGuid() + ".exe")
    try {
        & $compiler /nologo /target:exe /platform:x64 /utf8output "/out:$test" (Join-Path $PSScriptRoot 'Pruebas-PaqueteTauri.cs') (Join-Path $PSScriptRoot 'Actualizacion.cs')
        if ($LASTEXITCODE -ne 0) { throw 'No se pudo compilar la prueba del paquete.' }
        & $test $installer
        if ($LASTEXITCODE -ne 0) { throw 'Fallo la prueba aislada del paquete.' }
    } finally { if (Test-Path -LiteralPath $test) { Remove-Item -LiteralPath $test } }
}
Get-FileHash -LiteralPath $installer
