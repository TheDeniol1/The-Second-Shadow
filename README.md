# The Second Shadow

Soy **TheDalex** y este es mi mod para jugar **Little Nightmares II en cooperativo local**. La idea es que puedas sentarte con alguien en el mismo PC y jugar juntos. Pueden ir con dos Monos o hacer que el segundo jugador controle a Six, que es como yo te recomiendo probarlo.

**v0.8.0 Alpha · Windows x64 · Edición original de Steam · MIT**

Sigue siendo una alpha. Ya probé Jugar como Six desde que Mono rescata a Six del sótano en el Bosque hasta que la secuestran en la Escuela, con una cabeza de abusón para cada jugador. También probé los controles con teclado y mando y que los ajustes se guardan. El resto de la campaña sigue en pruebas. [Fallos que tengo anotados](docs/PENDIENTES.md).

## Jugar como Six

Si es tu primera vez con el mod, yo empezaría por aquí. Un jugador lleva a Mono y el otro controla a la Six que ya sale en la historia, con su ropa, sus animaciones y sus escenas. Cuando la historia los separa, el segundo jugador sigue jugando como **Dark Six** hasta que ella regresa. El cambio entre su ropa del principio, el impermeable amarillo y Dark Six se hace solo.

También es el modo que mejor funciona ahorita. El juego ya tiene en cuenta a Six en sus puzles y cinemáticas, así que hay menos cosas que adaptar que cuando vas con dos Monos.

Para activarlo, entra a **F6 → 4 → 5** desde el menú principal y luego carga o empieza una partida.

## Qué pueden hacer juntos

Hay dos cosas que vale la pena probar en cuanto entren a jugar.

- **Ofrecer la mano.** Pulsa una vez **F1** si eres P1, **F2** si eres P2 o **LB** si juegas con mando. Si tu compañero está colgado de un borde o cae por delante de ti y está a tu alcance, lo agarras y lo subes en automático. Si vuelves a pulsar, bajas la mano.
- **Dar un impulso.** Actívalo primero en **F6 → 4 → 3**. Pulsa **F3** si eres P1 o **F4** si eres P2 para agacharte. Tu compañero se acerca por delante, pulsa agarrar y sale disparado hacia arriba.

Pueden jugar con un teclado compartido, con teclado y mando o con dos mandos. En el menú pueden elegir entre la cámara compartida original o la estable, o dividir la pantalla en horizontal o vertical. También hay una opción para llenar la pantalla.

Si pierdes de vista al otro, puedes gritar para llamarlo. Sale un aviso en pantalla y, si está fuera de cuadro, una flecha te indica dónde está. También están **F9** y **F10** para teletransportarse entre jugadores con efecto de tele.

Si uno muere, los dos regresan al último punto de control y P2 reaparece con sus ajustes. También puedes activar la separación peligrosa. Si se alejan demasiado, la pantalla empieza a distorsionarse y pueden perder la partida.

### Qué puede hacer P2 por su cuenta

Los **Eventos de P2** vienen activados de entrada. El segundo jugador puede usar llaves para abrir candados, mover palancas, recoger y ponerse su propia cabeza de abusón en la Escuela y pasar por pasillos estrechos. El juego toma en cuenta quién hizo cada cosa.

También hay cambios en varias partes de la historia para que P2 participe. Puede aparecer por la tele del Bosque en la intro, sentarse y despertar en los puntos de control y participar en escenas como la mesa de Six, el disparo al Cazador, la balsa, los televisores de la Ciudad Pálida, la caja de música y el puente final. En el Hospital tiene su propia linterna y en la Ciudad Pálida tiene su propio control remoto.

El menú está en español e inglés. Puedes cambiar las teclas de P2, ponerle sombreros cuando jueguen con dos Monos y guardar tus ajustes entre partidas.

## Lo que sigue

- **Logros del mod.** Ya hay una pestaña de **Logros** en el menú del juego. Ahí puedes ver los de Steam y, por ahora, la pestaña de The Second Shadow está vacía. Estoy preparando los del mod y uno en específico va a desbloquear un final adicional.
- **Modo en línea.** Por ahora solo aparece como «En desarrollo» en **F6 → 1 → 2**. [Cómo va a funcionar](docs/EN-LINEA.md).
- **Correcciones.** Tengo anotados los fallos que conozco, incluidos los que pueden frenar el progreso. [Lista de pendientes](docs/PENDIENTES.md).

## Descargar e instalar

Necesitas la **edición original de Little Nightmares II en Steam** y la versión compatible de **UE4SS**. El juego y UE4SS se consiguen por separado. Por ahora he verificado la edición original de Steam. La Enhanced Edition y las demás siguen pendientes de pruebas. [Compatibilidad exacta](docs/compatibilidad.json).

En los archivos adjuntos de la release, baja **`The-Second-Shadow-v0.8.0-alpha.zip`**. GitHub también pone un ZIP automático llamado **Source code**, que trae los archivos fuente. [Descargar v0.8.0 Alpha](https://github.com/TheDeniol1/The-Second-Shadow/releases/tag/v0.8.0-alpha).

1. Sigue la [guía de instalación](docs/INSTALACION.md).
2. Ya en el juego, pulsa **F7** para activar a P2 y **F6** para abrir el menú.
3. Si quieres que los dos salgan desde la intro, activa a P2 antes de empezar una partida nueva.

Antes de jugar, échale un ojo a las [limitaciones de la alpha](docs/LIMITACIONES.md) y a los [fallos pendientes](docs/PENDIENTES.md). Si quieres ver todas las teclas y opciones, están en la [guía de controles](docs/CONTROLES.md).

## Si algo falla

Cuéntame en qué capítulo o punto de control pasó, qué estaba haciendo cada jugador, si iban con Six o con dos Monos y qué cámara y controles usaban. Si sabes cómo hacer que vuelva a pasar, eso me ayuda un buen a encontrarlo. [Abrir un issue](https://github.com/TheDeniol1/The-Second-Shadow/issues).

También puedes adjuntar la parte del `UE4SS.log` donde pasó, quitando primero las rutas personales. **F8** deja una marca en el registro para que puedas ubicar ese momento más fácil.

## Si quieres revisar o modificar el código

Con Node.js y npm instalados, corre estos comandos desde la raíz del repo.

```sh
npm install --ignore-scripts
npm test
npm run test:subject
```

`npm test` revisa la sintaxis de Lua y corre las pruebas de regresión simuladas con Fengari 0.1.4. `npm run test:subject` compila parte del adaptador nativo con el compilador de C de tu sistema. Las dos pruebas corren en GitHub Actions con cada cambio. Si quieres compilar las DLL, aquí está la [guía del adaptador nativo](tools/native-build/README.md).

## Créditos y licencia

Soy **TheDalex**, autor de The Second Shadow. Usé herramientas de IA como apoyo para hacer el mod.

Gracias a los autores de **SplitScreenMod** y al equipo de **UE4SS**. Su trabajo fue la base con la que empecé a hacer la pantalla dividida. [Créditos completos y avisos de terceros](CREDITOS.md).

El código propio y la documentación están bajo licencia [MIT](LICENSE). Little Nightmares II y sus recursos pertenecen a sus respectivos titulares. Este es un mod de fans no oficial, sin afiliación con Tarsier Studios ni Bandai Namco Entertainment.
