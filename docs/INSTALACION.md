# Instalación — v0.8.0 Alpha

Aquí te explico cómo instalar el mod en Little Nightmares II **original de Steam, para Windows x64**. Necesitas tener el juego instalado y Steam abierto. Descarga el mod y UE4SS por separado; el juego no viene incluido.

Esta versión está preparada para la edición original. Todavía no he comprobado Enhanced Edition ni otras ediciones.

## 1. Descargar UE4SS compatible

Descarga [zDEV-UE4SS_v3.0.1-1161-g6eb3d9bc.zip](https://github.com/UE4SS-RE/RE-UE4SS/releases/download/experimental/zDEV-UE4SS_v3.0.1-1161-g6eb3d9bc.zip) desde el proyecto oficial. Usa exactamente ese archivo, no la última versión ni el ZIP sin el prefijo zDEV.

SHA-256 del ZIP: `580a244bc30352cfd0d0019c4c63726c2bddd5bb04ef91f985df237aa81b06e9`.

El enlace corresponde a la versión con la que preparé el mod. Si quieres comprobar la descarga, compara su SHA-256 con el valor de arriba; el instalador también lo revisa automáticamente. El registro de UE4SS puede mostrar v3.0.1 Beta #0 / Git SHA 5418fa4e aunque el ZIP se llame 1161/g6eb3d9bc. Esa diferencia de nombre es normal en este paquete.

## 2. Instalar si todavía no tienes mods

1. Cierra Little Nightmares II.
2. Extrae el ZIP de The Second Shadow en una carpeta aparte. Conserva juntos Instalar.ps1, configuracion, licenses y Helios.
3. Abre PowerShell en esa carpeta y ejecuta el comando siguiente, sustituyendo las dos rutas por las tuyas. GameDirectory es la raíz que contiene Helios y Engine. RuntimeZip es el ZIP de UE4SS descargado, sin extraer.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Instalar.ps1 -GameDirectory "D:\Juegos\Little Nightmares II" -RuntimeZip "D:\Descargas\zDEV-UE4SS_v3.0.1-1161-g6eb3d9bc.zip"
```

El instalador comprueba la versión del juego y el ZIP de UE4SS antes de copiar los archivos. Si detecta UE4SS, un cargador o una carpeta Mods anterior, se detiene para evitar reemplazar tu instalación. En ese caso, consulta el apartado de instalaciones existentes más abajo.

Al instalar desde cero empiezas con los Eventos de P2 y el agarre en el aire activados, y con el impulso de compañero desactivado. Puedes cambiarlos en F6 → 4. Tus cambios se guardan en preferences.ini. El paquete no incluye partidas guardadas.

## 3. Empezar

Abre la edición original. **F7** invita o retira a P2; **F6** abre el menú. Para la introducción conjunta, activa P2 antes de comenzar una partida nueva. Si quieres jugar como Six, que es lo que te recomiendo, actívalo en **F6 → 4 → 5** desde el menú principal, antes de cargar la partida. Consulta CONTROLES.md en el ZIP o la guía de controles del repositorio.

En partida confirmé el Bosque completo en cooperativo, el comienzo de la Escuela, el uso de teclado y mando y que los ajustes se conservan al reiniciar. El resto de la campaña sigue en pruebas; los fallos conocidos están en PENDIENTES.md.

## Instalaciones existentes y actualizaciones

Si vienes de la v0.7.0 Alpha: con el juego cerrado, guarda una copia de LN2LocalCoop y de su preferences.ini, borra la carpeta scripts antigua, copia la nueva y vuelve a poner tu preferences.ini dentro. La DLL ln2_native_21.dll ya no se usa; ahora es ln2_native_29.dll. Tu preferences.ini sirve tal cual; para activar los Eventos de P2 usa F6 → 4 → 4. Confirma que UE4SS.dll tenga SHA-256 `f176dc36fd2bc7b8211dde6ba54ade6f66da5c8f3a79e3017a85b45c215e8242`. Copia solo el contenido de Helios del ZIP sobre la raíz del juego; no copies configuracion sobre tus ajustes sin revisarlos. Activa LN2LocalCoop : 1 y desactiva SplitScreenMod : 0 en ue4ss/Mods/mods.txt. Reinicia el juego para cargar cambios.

La configuración de referencia se encuentra en configuracion/UE4SS-settings.ini. Para el mismo comportamiento, revisa EnableHotReloadSystem=0, EnableAutoReloadingLuaMods=0, UseCache=0 y bUseUObjectArrayCache=false. Los valores de consola solo controlan su presentación.

## Diagnóstico

Revisa Helios/Binaries/Win64/ue4ss/UE4SS.log buscando LN2LocalCoop y Adaptador nativo cargado. Si me reportas un fallo, dime el capítulo, checkpoint, controles y cámara que usabas, junto con los pasos para repetirlo. Elimina rutas personales del registro antes de compartirlo.

## Desinstalar

Con el juego cerrado, cambia LN2LocalCoop : 1 a LN2LocalCoop : 0 en mods.txt. Si añadiste un enabled.txt dentro de LN2LocalCoop, retíralo también. Puedes guardar preferences.ini y retirar únicamente la carpeta LN2LocalCoop. No elimines un runtime compartido con otros mods.
