# Animación propia del abrazo (final oculto)

El final oculto usa dos animaciones propias si están instaladas:

- `/Game/Mods/TheSecondShadow/ANIM_SecretHug_Mono` (esqueleto de Mono)
- `/Game/Mods/TheSecondShadow/ANIM_SecretHug_Six` (esqueleto de Six)

Si no las encuentra, el mod compone el abrazo con poses del juego. Cuando las encuentra, en `UE4SS.log` aparece `Final oculto: usando la animacion propia del abrazo`.

El juego usa **Unreal Engine 4.24** (lo indica UE4SS al arrancar).

## 1. Sacar los modelos con FModel

1. Instala [FModel](https://fmodel.app) y en *Settings* elige la carpeta `Little Nightmares II\Helios\Content\Paks` y la versión **UE4.24**.
2. En *Settings → Models*, elige el formato de exportación **ActorX (psk/psa)**.
3. Exporta `Helios/Content/Characters/Player/SKM_Player02` (Mono) y `Helios/Content/Characters/Six/SKM_Six` (Six).
4. Abre cada malla en FModel y apunta qué **Skeleton** usa. Mono usa `/Game/Characters/Player/SKEL_Player`. Para Six, apunta la ruta que salga, porque la necesitas en el paso 3.

## 2. Animar en Blender

1. Instala el addon de importación PSK/PSA (por ejemplo, *io_import_scene_unreal_psa_psk*) e importa los dos `.psk`.
2. Comprueba que los armatures se llamen `SKM_Player02` y `SKM_Six`. Si no, cambia `MONO` y `SIX` al principio de `abrazo_blender.py`.
3. Guarda el `.blend`, abre `abrazo_blender.py` en el editor de texto de Blender y pulsa **Run Script**.
4. Revisa la consola (*Window → Toggle System Console*). El script dice qué huesos no encontró y lista los nombres reales. Si alguno no aparece, añade su nombre en `PARTS`.
5. Reproduce la animación. Si un brazo gira al revés, cambia el signo de ese valor en `POSES` y vuelve a ejecutar el script. A partir de aquí puedes retocar las claves a mano.
6. El script exporta `ANIM_SecretHug_Mono.fbx` y `ANIM_SecretHug_Six.fbx` junto al `.blend`.

Six se coloca enfrente de Mono, a `DISTANCE` cm. Si cambias esa distancia, cambia también `N.customHug.distance` en `finale_native.lua`. La escena juntos dura 8 s (`Secret.timing.together` en `secret_ending.lua`), y el script anima 7,6 s.

## 3. Cocinar con Unreal 4.24

1. Crea un proyecto vacío de UE 4.24 llamado **Helios**. El nombre importa, porque así las rutas cocinadas coinciden con las del juego.
2. Importa `SKM_Player02.psk` (o un FBX de la malla) en `Content/Characters/Player/`, para que el esqueleto quede en `/Game/Characters/Player/SKEL_Player`. Haz lo mismo con Six en la ruta del esqueleto que apuntaste en el paso 1.
3. Importa los dos FBX de animación en `Content/Mods/TheSecondShadow/`, cada uno con su esqueleto, y deja los nombres `ANIM_SecretHug_Mono` y `ANIM_SecretHug_Six`.
4. Ejecuta *File → Cook Content for Windows*.
5. De `Saved/Cooked/WindowsNoEditor/Helios/Content/Mods/TheSecondShadow/` copia solo los `.uasset`/`.uexp` de las dos animaciones. No incluyas los esqueletos ni las mallas falsas, porque el juego ya tiene los suyos.

## 4. Empaquetar e instalar

1. Arma esta estructura de carpetas: `Helios/Content/Mods/TheSecondShadow/` con los archivos cocinados.
2. Crea el pak con UnrealPak de UE 4.24, por ejemplo: `UnrealPak.exe TheSecondShadow_P.pak -create=lista.txt`, donde `lista.txt` asocia cada archivo con `../../../Helios/Content/Mods/TheSecondShadow/<archivo>`.
3. Copia `TheSecondShadow_P.pak` a `Little Nightmares II\Helios\Content\Paks\~mods\` (crea la carpeta si no existe).
4. Juega el final oculto y busca en el log `usando la animacion propia del abrazo`.
