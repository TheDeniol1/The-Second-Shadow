# The Second Shadow

**Dos jugadores. Una misma pesadilla.**

Soy **TheDalex** y este es **The Second Shadow**, mi mod de cooperativo local para **Little Nightmares II**.

Con este mod puedes jugar con otra persona en el mismo PC y acompañar a Mono como un segundo jugador. Puedes compartir cámara o dividir la pantalla, jugar con dos Monos y elegir la apariencia de Six para P2.

**v0.7.0 Alpha · Windows x64 · Edición original de Steam · MIT**

> Esta es una alpha. Probé el capítulo uno hasta la muerte del Cazador, el uso de teclado y mando y que los ajustes se guarden al reiniciar. También confirmé en partida que P1 recupera el teclado después de cargar y que las apariencias de Six y Dark Six cambian según la historia. Todavía me falta probar el resto de la campaña.

## Qué incluye

- Cooperativo local para dos jugadores con teclado compartido o un mando y un teclado.
- Cámara compartida y pantalla dividida horizontal o vertical.
- Menú en español e inglés, controles de teclado de P2 reasignables y preferencias guardadas.
- Sombreros para P2 Mono y apariencia opcional de Six. P2 alterna entre Dark Six, la ropa inicial de Six y el impermeable amarillo según la historia.
- Muerte compartida, reaparición de P2 tras los checkpoints, grito para llamar al compañero y teletransporte.
- Rescate de cornisa y ayudas experimentales de rescate aéreo y salto.

## Antes de jugar

Necesitas la **edición original de Little Nightmares II en Steam** y la compilación compatible de **UE4SS**. El juego y UE4SS se obtienen por separado. Esta versión no ofrece juego en línea ni dos mandos simultáneos; otras ediciones del juego no están verificadas.

Antes de empezar, revisa las [limitaciones de esta alpha](docs/LIMITACIONES.md). Puedes encontrar fallos en capítulos, puzles o cinemáticas que todavía no he probado.

## Descargar

[Descargar v0.7.0 Alpha](https://github.com/TheDeniol1/The-Second-Shadow/releases/tag/v0.7.0-alpha). Descarga el ZIP The-Second-Shadow-v0.7.0-alpha.zip de los archivos adjuntos de la release. El archivo automático Source code contiene las fuentes.

## Instalación y controles

1. Sigue la [guía de instalación](docs/INSTALACION.md) y comprueba la [compatibilidad exacta](docs/compatibilidad.json).
2. Pulsa **F7** para activar a P2 y **F6** para abrir el menú.
3. Si quieres que ambos aparezcan en la introducción, activa P2 antes de comenzar una partida nueva.

Encontrarás todas las teclas, opciones y ayudas en la [guía de controles](docs/CONTROLES.md).

## Reportar un problema

Si encuentras un fallo, [abre un issue](https://github.com/TheDeniol1/The-Second-Shadow/issues) y cuéntame en qué capítulo o checkpoint ocurrió, qué hacía cada jugador y qué cámara y controles usabas. Si puedes explicar cómo repetirlo, me ayudas a localizarlo. También puedes adjuntar el fragmento relevante de UE4SS.log, quitando antes las rutas personales.

## Si quieres revisar o modificar el código

Con Node.js y npm instalados, ejecuta desde la raíz:

```sh
npm install --ignore-scripts
npm test
```

Para comprobar la sintaxis Lua y las regresiones simuladas uso Fengari 0.1.4. Las pruebas pasaron con la instalación local de desarrollo; todavía queda comprobar la instalación de esas dependencias desde cero. Si quieres compilar la DLL, tienes los pasos en la [guía del adaptador nativo](tools/native-build/README.md).

## Créditos y licencia

**TheDalex** — autor de The Second Shadow.

Usé herramientas de inteligencia artificial como apoyo durante la elaboración de este mod.

Gracias a los autores de **SplitScreenMod** y al equipo de **UE4SS** por la base con la que empecé a trabajar en la pantalla dividida. [Créditos completos y avisos de terceros](CREDITOS.md).

Código propio y documentación bajo [MIT](LICENSE). Little Nightmares II y sus recursos pertenecen a sus respectivos titulares. Este es un mod de fans no oficial, sin afiliación con Tarsier Studios ni Bandai Namco Entertainment.
