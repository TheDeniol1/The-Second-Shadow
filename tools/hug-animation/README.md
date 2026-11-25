# Escena propia del puente (final oculto)

El final oculto reproduce una escena propia si encuentra estos dos clips en un pak:

- `/Game/Mods/TheSecondShadow/ANIM_SecretScene_Mono` (esqueleto de Mono)
- `/Game/Mods/TheSecondShadow/ANIM_SecretScene_Six` (esqueleto de Six)

Los dos clips se animan juntos en Blender, sobre el mismo origen, y cubren toda la
escena: el agarre, el tirón, la caída de Six, Six de rodillas y el abrazo. El mod
oculta a Mono y a la Six del juego, crea dos copias con sus mallas en el origen
y reproduce los clips a la vez. Si el pak no está, usa el reemplazo con poses del juego.

## Origen de la escena

El origen es el punto del suelo del puente justo encima de donde Mono cuelga.
Las dos copias se colocan con el giro `N.customScene.yaw` de `finale_native.lua`.
Al empezar la escena, el mod escribe en `UE4SS.log` las medidas que necesita el
script de Blender:

- `Final oculto: medidas cuelga=X Y Z capsula=media/radio suelo=Z borde=Y`
- `Final oculto: esqueleto de Six ...; esqueleto de Mono ...`
- `Final oculto: Six de la secuencia en X Y Z giro G`

## 1. Exportar del juego con FModel

1. En FModel elige `Little Nightmares II\Helios\Content\Paks` y la versión **UE4.24**.
2. En *Settings → Models*, mallas en **ActorX (psk)** y animaciones en **psa**.
3. Clic derecho en `Helios/Content/Characters/Six/Animations` y en
   `Helios/Content/Characters/Player/Animations` → *Save Folder's Packages Animations*.
4. Guarda las mallas de Mono y Six (`SKM_…`) con *Save Model*.

## 2. Animar en Blender

La escena se arma con clips del juego como base (por ejemplo `ANIM_Six_GapHelpPullUp`
con `ANIM_Player_GapHelpPulledUp` para el tirón) y se retoca a mano donde no hay
animación del juego, como el abrazo. Se exportan:

- `SKM_Mono.fbx` y `SKM_Six.fbx`: las mallas, para crear los esqueletos en Unreal.
- `ANIM_SecretScene_Mono.fbx` y `ANIM_SecretScene_Six.fbx`: los clips.

`abrazo_blender.py` es el primer borrador, solo del abrazo.

## 3. Cocinar e instalar (Unreal 4.24)

Con Unreal 4.24.3 instalado, en PowerShell:

```powershell
.\cocinar.ps1 -Fbx "C:\ruta\a\los\fbx"
```

El script crea un proyecto vacío llamado **Helios** (así las rutas cocinadas
coinciden con las del juego) y luego hace tres pasos:

1. Importa las mallas y mueve sus esqueletos a las rutas del juego.
2. Importa los clips, cocina para Windows y crea `TheSecondShadow_P.pak`.
3. Copia el pak en `Little Nightmares II\Helios\Content\Paks\~mods\`.

Las rutas de los esqueletos se cambian en `unreal/importar.json`.

Para comprobarlo, juega el final oculto y busca `escena propia` en `UE4SS.log`.
