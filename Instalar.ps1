param(
    [Parameter(Mandatory=$true)][string]$GameDirectory,
    [Parameter(Mandatory=$true)][string]$RuntimeZip
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $GameDirectory).Path
$archivePath = (Resolve-Path -LiteralPath $RuntimeZip).Path
$win64 = Join-Path $root 'Helios\Binaries\Win64'
$exe = Join-Path $win64 'Little Nightmares II.exe'
if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) { throw 'Selecciona la raiz de la edicion original del juego.' }
if ((Get-FileHash -LiteralPath $exe).Hash -ne '2920C17031003A713EB1B6FC4057C28AE98FDE5900EBC6FF93E488DBF11BD1C9') { throw 'Ejecutable incompatible con esta alpha.' }
if ((Get-FileHash -LiteralPath $archivePath).Hash -ne '580A244BC30352CFD0D0019C4C63726C2BDDD5BB04EF91F985DF237AA81B06E9') { throw 'ZIP de UE4SS incompatible. Consulta INSTALACION.md.' }
foreach ($name in @('ue4ss','dwmapi.dll','UE4SS.dll','Mods','xinput1_3.dll')) {
    if (Test-Path -LiteralPath (Join-Path $win64 $name)) { throw "Ya existe $name. Este instalador solo acepta una instalacion limpia y no reemplaza mods ni preferencias." }
}
if (Get-Process -Name 'Little Nightmares II' -ErrorAction SilentlyContinue) { throw 'Cierra el juego antes de instalar.' }
$source = Join-Path $PSScriptRoot 'Helios\Binaries\Win64\ue4ss\Mods\LN2LocalCoop'
if (-not (Test-Path -LiteralPath $source)) { $source = Join-Path $PSScriptRoot 'mods\LN2LocalCoop' }
$defaults = Join-Path $PSScriptRoot 'configuracion\preferences-default.ini'
if (-not (Test-Path -LiteralPath $defaults -PathType Leaf)) { throw 'Falta configuracion/preferences-default.ini.' }
foreach ($required in @((Join-Path $source 'scripts\main.lua'),(Join-Path $source 'scripts\ln2_native_21.dll'),(Join-Path $PSScriptRoot 'configuracion\UE4SS-settings.ini'),(Join-Path $PSScriptRoot 'configuracion\mods.txt'))) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Paquete incompleto: $required" }
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($archivePath)
try {
    foreach ($entry in $zip.Entries) {
        $relative = $entry.FullName.Replace('\','/')
        if (-not $entry.Name) { continue }
        # Runtime and shared Lua helpers only: no debug mods, PDBs or examples.
        if ($relative -notmatch '^(dwmapi\.dll|ue4ss/UE4SS\.dll)$' -and $relative -notmatch '^ue4ss/(Mods/shared|UE4SS_Signatures|MemberVarLayoutTemplates|VTableLayoutTemplates)/') { continue }
        $destination = [IO.Path]::GetFullPath((Join-Path $win64 $relative))
        if (-not $destination.StartsWith($win64 + '\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Ruta inesperada en ZIP.' }
        New-Item -ItemType Directory -Path (Split-Path $destination) -Force | Out-Null
        [IO.Compression.ZipFileExtensions]::ExtractToFile($entry,$destination,$false)
    }
} finally { $zip.Dispose() }
$runtime = Join-Path $win64 'ue4ss'
if ((Get-FileHash -LiteralPath (Join-Path $runtime 'UE4SS.dll')).Hash -ne 'F176DC36FD2BC7B8211DDE6BA54ADE6F66DA5C8F3A79E3017A85B45C215E8242') { throw 'La DLL extraida no coincide.' }
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'configuracion\UE4SS-settings.ini') -Destination $runtime
New-Item -ItemType Directory -Path (Join-Path $runtime 'Mods') -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'configuracion\mods.txt') -Destination (Join-Path $runtime 'Mods')
Copy-Item -LiteralPath $source -Destination (Join-Path $runtime 'Mods') -Recurse
Copy-Item -LiteralPath $defaults -Destination (Join-Path $runtime 'Mods\LN2LocalCoop\scripts\preferences.ini')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'licenses\UE4SS-MIT.txt') -Destination (Join-Path $runtime 'LICENSE')
Write-Output 'Instalacion completada con ajustes predeterminados. F7 activa P2; F6 abre el menu. No se incluyeron partidas.'
