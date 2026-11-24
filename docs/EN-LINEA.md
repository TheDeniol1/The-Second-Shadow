# Modo en línea (en desarrollo)

En la v0.8.0 Alpha la opción **F6 → 1 → 2 · En línea** aparece como «En desarrollo» y todavía no hace nada. El ZIP no incluye el adaptador de red. Te cuento cómo lo estoy preparando para que sepas qué viene.

## Cómo va a funcionar

- **Una sola partida real.** Quien crea la partida (el anfitrión) juega normalmente en su PC. Su amigo (el invitado) controla a P2 en esa partida.
- **Con tus amigos de Steam.** Desde **F6 → 1 → 2**, el anfitrión elige **Crear partida** y el invitado **Unirse a un amigo**. Cada uno elige al otro de la lista de amigos que están jugando a Little Nightmares II. No hace falta abrir puertos: la conexión va por la red de Steam.
- **Controles del invitado.** El mando o las teclas de P2 del invitado se envían al anfitrión y mueven a P2 allí, igual que en el cooperativo local.
- **Imagen.** El anfitrión enviará la imagen del juego al invitado como un vídeo en directo, para que el invitado vea la partida desde su PC.

## En qué punto está

| Fase | Qué incluye | Estado |
| --- | --- | --- |
| 0 · Diagnóstico | Comprobar captura de pantalla, codificación de vídeo y red de Steam en el PC del jugador. | Hecha, solo para pruebas internas |
| 1 · Controles | Sesión entre amigos de Steam y controles del invitado manejando a P2. Ping y reconexión. | En pruebas; el invitado aún no ve la partida |
| 2 · Imagen | Enviar la imagen del anfitrión al invitado. | Pendiente |

Los dos jugadores tendrán que usar la misma versión del mod. Cuando esté listo para jugar lo anunciaré en una nueva versión.
