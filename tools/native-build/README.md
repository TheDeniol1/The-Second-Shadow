# Compilar el adaptador

Código C para Windows x64 y Lua de UE4SS. Se incluyen lua-rvas.h y runtime-identity.h correspondientes a la compilación compatible, sin DLL ni PDB de UE4SS.

Instala Tiny C 0.9.27 para Windows x64 y agrega tcc al PATH. Desde la raíz:

```powershell
tcc -shared -Wall -o mods/LN2LocalCoop/scripts/ln2_native_21.dll tools/native-build/ln2_native.c tools/native-build/heartbeat_wave.c -lkernel32 -luser32
npm run test:native
```

La prueba nativa acepta la ruta del compilador en la variable TCC. El compilador se obtiene por separado; no se redistribuye en el repositorio.

No hace falta regenerar los encabezados para esta versión. resolve-lua.ps1 exige un parámetro explícito -RuntimeDirectory con la DLL y PDB compatibles. No regeneres direcciones para un runtime nuevo sin revisar offsets, desensamblado e identidades. El adaptador rechaza identidades distintas.
