# The Second Shadow - cocina las animaciones del final oculto y crea el pak.
# Uso (PowerShell):
#   .\cocinar.ps1 -Fbx "C:\ruta\a\los\fbx" [-Engine "C:\Program Files\Epic Games\UE_4.24"]
#                 [-Juego "D:\SteamLibrary\steamapps\common\Little Nightmares II"]
param(
  [Parameter(Mandatory=$true)][string]$Fbx,
  [string]$Engine = "C:\Program Files\Epic Games\UE_4.24",
  [string]$Juego = "D:\SteamLibrary\steamapps\common\Little Nightmares II",
  [string]$Trabajo = "$env:LOCALAPPDATA\TheSecondShadow\cocina"
)
$ErrorActionPreference = 'Stop'
$editor = Join-Path $Engine 'Engine\Binaries\Win64\UE4Editor-Cmd.exe'
$pakTool = Join-Path $Engine 'Engine\Binaries\Win64\UnrealPak.exe'
foreach ($tool in @($editor, $pakTool)) { if (-not (Test-Path $tool)) { throw "No encuentro $tool. ¿Está instalado Unreal 4.24?" } }

# Proyecto limpio llamado Helios, para que las rutas cocinadas sean las del juego.
$proyecto = Join-Path $Trabajo 'Helios'
if (Test-Path $proyecto) { Remove-Item $proyecto -Recurse -Force }
New-Item -ItemType Directory -Force -Path $proyecto | Out-Null
Copy-Item (Join-Path $PSScriptRoot 'unreal\*') $proyecto -Recurse -Force
New-Item -ItemType Directory -Force -Path (Join-Path $proyecto 'fbx') | Out-Null
Copy-Item (Join-Path $Fbx '*.fbx') (Join-Path $proyecto 'fbx') -Force
$uproject = Join-Path $proyecto 'Helios.uproject'

Write-Host '1/3 Importando los FBX...'
& $editor $uproject -run=pythonscript -script="$(Join-Path $proyecto 'importar.py')" -unattended -nop4 -nosplash -stdout | Tee-Object -FilePath (Join-Path $Trabajo 'importar.log')
if (-not (Select-String -Path (Join-Path $Trabajo 'importar.log') -Pattern '\[SecondShadow\] listo' -Quiet)) { throw 'La importacion fallo; revisa importar.log' }

Write-Host '2/3 Cocinando para Windows...'
& $editor $uproject -run=cook -targetplatform=WindowsNoEditor -unversioned -unattended -nop4 -nosplash -stdout | Tee-Object -FilePath (Join-Path $Trabajo 'cocinar.log')
$cocinado = Join-Path $proyecto 'Saved\Cooked\WindowsNoEditor\Helios\Content\Mods\TheSecondShadow'
$archivos = Get-ChildItem $cocinado -File -Include *.uasset,*.uexp,*.ubulk -Recurse
if (-not $archivos) { throw "No hay archivos cocinados en $cocinado; revisa cocinar.log" }

Write-Host '3/3 Creando el pak...'
$lista = Join-Path $Trabajo 'lista.txt'
$archivos | ForEach-Object { '"{0}" "../../../Helios/Content/Mods/TheSecondShadow/{1}"' -f $_.FullName, $_.Name } | Set-Content -Encoding ASCII $lista
$pak = Join-Path $Trabajo 'TheSecondShadow_P.pak'
& $pakTool $pak -create="$lista"
if (-not (Test-Path $pak)) { throw 'UnrealPak no creo el pak' }
$mods = Join-Path $Juego 'Helios\Content\Paks\~mods'
New-Item -ItemType Directory -Force -Path $mods | Out-Null
Copy-Item $pak $mods -Force
Write-Host "Listo: $pak copiado a $mods"
