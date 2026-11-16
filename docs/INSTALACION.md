# Instalación — v0.7.0 Alpha

Para Little Nightmares II **original de Steam, Windows x64**. Enhanced Edition y otras ediciones no están verificadas. Necesitas el juego instalado y Steam abierto. El ZIP del mod no incluye el juego ni UE4SS.

## 1. Descargar UE4SS compatible

Descarga [zDEV-UE4SS_v3.0.1-1161-g6eb3d9bc.zip](https://github.com/UE4SS-RE/RE-UE4SS/releases/download/experimental/zDEV-UE4SS_v3.0.1-1161-g6eb3d9bc.zip) desde el proyecto oficial. Usa exactamente ese archivo, no la última versión ni el ZIP sin el prefijo zDEV.

SHA-256 del ZIP: `580a244bc30352cfd0d0019c4c63726c2bddd5bb04ef91f985df237aa81b06e9`.

La descarga se verificó el 16 de noviembre de 2026. Su DLL coincide con la instalación de desarrollo. Aunque la etiqueta del ZIP indica 1161/g6eb3d9bc, el runtime anuncia v3.0.1 Beta #0 / Git SHA 5418fa4e; la compatibilidad se comprueba por huellas, no solo por ese texto.

## 2. Instalar en una copia sin mods

1. Cierra Little Nightmares II.
2. Extrae el ZIP de The Second Shadow en una carpeta aparte. Conserva juntos Instalar.ps1, configuracion, licenses y Helios.
3. Abre PowerShell en esa carpeta y ejecuta el comando siguiente, sustituyendo las dos rutas por las tuyas. GameDirectory es la raíz que contiene Helios y Engine. RuntimeZip es el ZIP de UE4SS descargado, sin extraer.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Instalar.ps1 -GameDirectory "D:\Juegos\Little Nightmares II" -RuntimeZip "D:\Descargas\zDEV-UE4SS_v3.0.1-1161-g6eb3d9bc.zip"
```

El instalador comprueba el ejecutable y el ZIP antes de copiar. Rechaza instalaciones con UE4SS, un cargador o una carpeta Mods previa: no actualiza ni reemplaza configuraciones existentes. Extrae el runtime y los helpers compartidos, instala LN2LocalCoop y activa únicamente ese mod.

El instalador crea preferences.ini a partir de configuracion/preferences-default.ini, con los valores de lanzamiento elegidos por TheDalex. Los eventos de P2, el rescate aéreo y la ayuda de salto empiezan desactivados. No se incluyen partidas. La configuración base desactiva la recarga en caliente y las cachés de UE4SS utilizadas en la configuración compatible; mantiene la consola gráfica oculta. Solo aplica la plantilla de valores predeterminados publicada con el mod.

## 3. Empezar

Abre la edición original. **F7** invita o retira a P2; **F6** abre el menú. Para la introducción conjunta, activa P2 antes de comenzar una partida nueva. Consulta CONTROLES.md en el ZIP o la guía de controles del repositorio.

El usuario confirmó teclado y mando, persistencia de ajustes y el capítulo uno hasta la muerte del Cazador. El paquete incluye además el parche nativo 21 posterior a ese recorrido. La campaña completa no está validada.

## Instalaciones existentes y actualizaciones

Con el juego cerrado, conserva una copia de LN2LocalCoop y su preferences.ini. Confirma que UE4SS.dll tenga SHA-256 `f176dc36fd2bc7b8211dde6ba54ade6f66da5c8f3a79e3017a85b45c215e8242`. Copia solo el contenido de Helios del ZIP sobre la raíz del juego; no copies configuracion sobre tus ajustes sin revisarlos. Activa LN2LocalCoop : 1 y desactiva SplitScreenMod : 0 en ue4ss/Mods/mods.txt. Reinicia el juego para cargar cambios.

La configuración de referencia se encuentra en configuracion/UE4SS-settings.ini. Para el mismo comportamiento, revisa EnableHotReloadSystem=0, EnableAutoReloadingLuaMods=0, UseCache=0 y bUseUObjectArrayCache=false. Los valores de consola solo controlan su presentación.

## Diagnóstico

Revisa Helios/Binaries/Win64/ue4ss/UE4SS.log buscando LN2LocalCoop y Adaptador nativo cargado. Al reportar un fallo, indica capítulo, checkpoint, controles, cámara y pasos para reproducirlo. Elimina rutas personales del registro antes de compartirlo.

## Desinstalar

Con el juego cerrado, cambia LN2LocalCoop : 1 a LN2LocalCoop : 0 en mods.txt. Si añadiste un enabled.txt dentro de LN2LocalCoop, retíralo también. Puedes guardar preferences.ini y retirar únicamente la carpeta LN2LocalCoop. No elimines un runtime compartido con otros mods.
