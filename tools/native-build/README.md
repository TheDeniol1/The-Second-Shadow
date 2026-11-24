# Compilar los adaptadores

Si quieres compilar los adaptadores nativos del mod, aquí tienes los pasos. Están escritos en C para Windows x64. Incluí lua-rvas.h y runtime-identity.h para la versión compatible de UE4SS; la DLL y el PDB de UE4SS se obtienen por separado.

Instala Tiny C 0.9.27 para Windows x64 y agrega tcc al PATH. Desde la raíz:

```powershell
tcc -shared -Wall -o mods/LN2LocalCoop/scripts/ln2_native_29.dll tools/native-build/ln2_native.c tools/native-build/heartbeat_wave.c -lkernel32 -luser32
tcc -shared -Wall -o mods/LN2LocalCoop/scripts/ln2_steam_icons.dll tools/native-build/ln2_steam_icons.c -lkernel32
npm run test:native
npm run test:subject
```

| Archivo | DLL | Para qué sirve |
| --- | --- | --- |
| `ln2_native.c` | `ln2_native_29.dll` | Controles de P2, cámara dividida, mandos, teletransporte, escenas y Eventos de P2. |
| `ln2_steam_icons.c` | `ln2_steam_icons.dll` | Lee de Steam los iconos de tus logros para la pestaña Logros. Solo lectura: no desbloquea nada. |
| `ln2_online.c` | ninguna en esta versión | Adaptador del modo en línea, en desarrollo. No se compila ni se incluye en la v0.8.0 Alpha. |

La prueba nativa acepta la ruta del compilador en la variable TCC. `npm run test:subject` compila las funciones de Eventos de P2 con el compilador de C del sistema y marcos falsos. El compilador se obtiene por separado; no se redistribuye en el repositorio.

No hace falta regenerar los encabezados para esta versión. resolve-lua.ps1 exige un parámetro explícito -RuntimeDirectory con la DLL y PDB compatibles. No regeneres direcciones para un runtime nuevo sin revisar offsets, desensamblado e identidades. El adaptador rechaza identidades distintas.
