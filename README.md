# The Second Shadow

**Dos jugadores. Una misma pesadilla.**

Soy **TheDalex** y este es **The Second Shadow**, mi mod de cooperativo local para **Little Nightmares II**.

Con este mod puedes recorrer la pesadilla con otra persona en el mismo PC. P2 puede ser una segunda sombra de Mono o, lo que más te recomiendo, **jugar como Six** a su lado. Podéis compartir cámara o dividir la pantalla, daros la mano para subir a un borde, impulsaros para llegar más alto y usar llaves, palancas y objetos cada uno por su cuenta.

**v0.8.0 Alpha · Windows x64 · Edición original de Steam · MIT**

> Esta es una alpha. En partida he jugado con **Jugar como Six** desde que Mono rescata a Six del sótano en el Bosque hasta que la secuestran en la Escuela, incluida la cabeza de abusón de cada jugador. También he comprobado teclado y mando y que los ajustes se guardan. El resto de la campaña sigue en pruebas y te dejo los fallos que conozco en [pendientes](docs/PENDIENTES.md).

## Jugar como Six: la forma más fiel de jugar

Si vas a probar el mod, empieza por aquí. Con **Jugar como Six**, P2 no es un personaje añadido: controla a la propia Six de la historia mientras acompaña a Mono. Usa su ropa, sus animaciones y sus escenas originales, así que la aventura se vive como la pensó el juego, pero con una persona de verdad al otro lado de la mano.

Cuando la historia separa a Six de Mono, P2 pasa a ser **Dark Six**, su sombra, y sigue jugando hasta que Six vuelve. Su aspecto cambia solo entre la ropa del principio, el impermeable amarillo y Dark Six según el momento de la historia.

Hoy es también **el modo más estable**. Como el juego ya cuenta con Six en sus puzles y cinemáticas, hay menos escenas que adaptar que con dos Monos. Actívalo desde el menú principal del juego con **F6 → 4 → 5** y después carga o empieza la partida.

## Lo que podéis hacer juntos

**Acciones en pareja.** No juegues como si fuerais dos personas por separado. Estas dos ayudas son las que más cambian la partida:

- **Ofrecer la mano.** Pulsa una vez **F1** (P1), **F2** (P2) o **LB** en el mando. Si tu compañero está colgado de un borde, o cae en el aire delante de ti, lo agarras y lo subes solo. Vuelve a pulsar para retirar la mano.
- **Impulso de compañero.** Pulsa **F3** (P1) o **F4** (P2) para agacharte en postura. Tu compañero se acerca por delante, pulsa agarrar y lo lanzas hacia arriba. Viene activado; puedes quitarlo en **F6 → 4 → 3**.

**Cooperativo local completo.**

- Dos jugadores en el mismo PC: teclado compartido, un mando y un teclado, o dos mandos.
- Cámara compartida estable o original, o pantalla dividida horizontal o vertical, con opción para llenar la pantalla.
- Grito para llamar al compañero, con aviso en pantalla y flecha cuando alguien queda fuera de cuadro.
- Teletransporte entre jugadores con **F9** y **F10**, con efecto de televisión.
- Muerte compartida: si cae uno, ambos vuelven al último punto de control y P2 reaparece con su configuración.
- Separación peligrosa opcional: si os alejáis demasiado, la pantalla se distorsiona y podéis perder la partida.

**Eventos de P2.** Activado de serie. P2 puede abrir candados con llaves, mover palancas, recoger y ponerse su propia cabeza de abusón en la Escuela y cruzar pasillos estrechos sin que el juego se lo atribuya a P1.

**P2 en la historia.** P2 aparece por la televisión del Bosque en la introducción, se sienta y despierta en los puntos de control, y participa en escenas como la mesa de Six, el disparo al Cazador, la balsa, los televisores de la Ciudad Pálida, la caja de música y el puente final. Tiene su propia linterna en el Hospital y su propio mando a distancia en la Ciudad Pálida.

**Personalización.** Menú en español e inglés, teclas de P2 reasignables, sombreros para P2 en el modo de dos Monos y preferencias que se guardan entre partidas.

## Lo que viene

- **Logros propios.** El menú del juego ya tiene la pestaña **Logros**: la de Steam muestra tus logros y la de The Second Shadow está vacía por ahora. Estoy preparando los logros del mod, y conseguir uno en específico desbloqueará **un final adicional**.
- **Modo en línea.** Aparece en **F6 → 1 → 2** como «En desarrollo» y todavía no hace nada en esta versión. [Cómo va a funcionar](docs/EN-LINEA.md).
- **Correcciones.** Fallos y bloqueos de progreso que conozco y quiero resolver. Los apunto en [pendientes](docs/PENDIENTES.md).

## Antes de jugar

Necesitas la **edición original de Little Nightmares II en Steam** y la compilación compatible de **UE4SS**. El juego y UE4SS se obtienen por separado. Otras ediciones del juego, como Enhanced Edition, no están verificadas.

Antes de empezar, revisa las [limitaciones de esta alpha](docs/LIMITACIONES.md) y los [fallos pendientes](docs/PENDIENTES.md).

## Descargar

[Descargar v0.8.0 Alpha](https://github.com/TheDeniol1/The-Second-Shadow/releases/tag/v0.8.0-alpha). Descarga el ZIP `The-Second-Shadow-v0.8.0-alpha.zip` de los archivos adjuntos de la release. El archivo automático Source code contiene solo las fuentes.

## Instalación y controles

1. Sigue la [guía de instalación](docs/INSTALACION.md) y comprueba la [compatibilidad exacta](docs/compatibilidad.json).
2. Pulsa **F7** para activar a P2 y **F6** para abrir el menú.
3. Si quieres que ambos aparezcan en la introducción, activa P2 antes de comenzar una partida nueva.

Todas las teclas, opciones y ayudas están en la [guía de controles](docs/CONTROLES.md).

## Reportar un problema

Si encuentras un fallo, [abre un issue](https://github.com/TheDeniol1/The-Second-Shadow/issues). Cuéntame en qué capítulo o punto de control ocurrió, qué hacía cada jugador, si jugabais como Six o con dos Monos y qué cámara y controles usabais. Si puedes explicar cómo repetirlo, me ayudas a localizarlo. También puedes adjuntar el fragmento de `UE4SS.log`, quitando antes las rutas personales. **F8** deja una marca en ese registro.

## Si quieres revisar o modificar el código

Con Node.js y npm instalados, ejecuta desde la raíz:

```sh
npm install --ignore-scripts
npm test
npm run test:subject
```

`npm test` comprueba la sintaxis Lua y las regresiones simuladas con Fengari 0.1.4. `npm run test:subject` compila parte del adaptador nativo con el compilador de C del sistema. Las dos pruebas se ejecutan en cada cambio con GitHub Actions. Para compilar las DLL, sigue la [guía del adaptador nativo](tools/native-build/README.md).

## Créditos y licencia

**TheDalex** — autor de The Second Shadow.

Usé herramientas de inteligencia artificial como apoyo durante la elaboración de este mod.

Gracias a los autores de **SplitScreenMod** y al equipo de **UE4SS** por la base con la que empecé a trabajar en la pantalla dividida. [Créditos completos y avisos de terceros](CREDITOS.md).

Código propio y documentación bajo [MIT](LICENSE). Little Nightmares II y sus recursos pertenecen a sus respectivos titulares. Este es un mod de fans no oficial, sin afiliación con Tarsier Studios ni Bandai Namco Entertainment.
