# The Second Shadow

**Dos jugadores. Una misma pesadilla.**

Mod de cooperativo local para **Little Nightmares II**, creado por **TheDalex**.

The Second Shadow permite que un segundo jugador acompañe a Mono en el mismo PC. Puedes compartir cámara o dividir la pantalla, jugar con dos Monos y elegir la apariencia de Six para P2.

**v0.7.0 Alpha · Windows x64 · Edición original de Steam · MIT**

> Versión alpha. La campaña completa aún no está validada. La descarga compatible de UE4SS está verificada. Se confirmó el recorrido del capítulo uno hasta la muerte del Cazador, teclado y mando, y persistencia de ajustes. El parche nativo 21 se incorporó después de ese recorrido.

## Qué incluye

- Cooperativo local para dos jugadores con teclado compartido o un mando y un teclado.
- Cámara compartida y pantalla dividida horizontal o vertical.
- Menú en español e inglés, controles de teclado de P2 reasignables y preferencias guardadas.
- Sombreros para P2 Mono y apariencia opcional de Six, con cambios visuales todavía pendientes de verificación.
- Muerte compartida, reaparición de P2 tras los checkpoints, llamadas y teletransporte entre compañeros.
- Rescate de cornisa y ayudas experimentales de rescate aéreo y salto.

## Antes de jugar

Necesitas la **edición original de Little Nightmares II en Steam** y la compilación compatible de **UE4SS**. El juego y UE4SS se obtienen por separado. Esta versión no ofrece juego en línea ni dos mandos simultáneos; otras ediciones del juego no están verificadas.

El capítulo uno se ha probado hasta la muerte del Cazador. Eso no garantiza que todos los capítulos, puzles o cinemáticas funcionen en cooperativo. Consulta las [limitaciones de esta alpha](docs/LIMITACIONES.md).

## Descargar

[Descargar v0.7.0 Alpha](https://github.com/TheDeniol1/The-Second-Shadow/releases/tag/v0.7.0-alpha). Descarga el ZIP The-Second-Shadow-v0.7.0-alpha.zip de los archivos adjuntos de la release. El archivo automático Source code contiene las fuentes.

## Instalación y controles

1. Sigue la [guía de instalación](docs/INSTALACION.md) y comprueba la [compatibilidad exacta](docs/compatibilidad.json).
2. Pulsa **F7** para activar a P2 y **F6** para abrir el menú.
3. Si quieres que ambos aparezcan en la introducción, activa P2 antes de comenzar una partida nueva.

Encontrarás todas las teclas, opciones y ayudas en la [guía de controles](docs/CONTROLES.md).

## Reportar un problema

Indica el capítulo o checkpoint, qué hacía cada jugador, el tipo de cámara y los controles utilizados. Añade los pasos para repetir el fallo y, si hace falta, el fragmento relevante de UE4SS.log con las rutas personales eliminadas.

## Desarrollo

Con Node.js y npm instalados, ejecuta desde la raíz:

```sh
npm install --ignore-scripts
npm test
```

La suite usa Fengari 0.1.4 para comprobar sintaxis y regresiones simuladas. La instalación de dependencias desde cero sigue pendiente de comprobación; las pruebas de esta preparación usaron Fengari local. Consulta también la [compilación del adaptador nativo](tools/native-build/README.md).

## Créditos y licencia

**TheDalex** — autor de The Second Shadow.

Gracias a los autores de **SplitScreenMod** y al equipo de **UE4SS** por la base utilizada para iniciar el trabajo de pantalla dividida. [Créditos completos y avisos de terceros](CREDITOS.md).

Código propio y documentación bajo [MIT](LICENSE). Little Nightmares II y sus recursos pertenecen a sus respectivos titulares. Este es un mod de fans no oficial, sin afiliación con Tarsier Studios ni Bandai Namco Entertainment.
