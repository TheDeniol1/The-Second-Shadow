# The Second Shadow · v0.8.0 Alpha

Aquí tienes las teclas y opciones que puedes usar en **The Second Shadow**. Al activar el cooperativo empiezas con dos Monos. Te recomiendo cambiar a **Jugar como Six** desde el menú principal del juego: es la forma más fiel y, por ahora, la más estable de jugar el mod.

## Empezar a jugar

Pulsa **F7** para activar o retirar a P2 y **F6** para abrir o cerrar el menú. En partida, abrir F6 pausa el juego. Puedes elegir con el mouse o con el teclado. El cooperativo empieza desactivado. Para que P2 también salga de la televisión en la introducción, actívalo con **F7** antes de empezar una partida nueva.

P1 usa los controles habituales del juego. P2 tiene estas asignaciones de teclado por defecto.

| Acción de P2 | Tecla |
| --- | --- |
| Moverse y escalar | **I J K L** |
| Saltar | **U** |
| Agarrar | **O** |
| Agacharse | **P** |
| Correr | **Shift derecho** |
| Usar o lanzar un objeto | **H** |
| Usar la linterna o el control remoto | **Y** |
| Gritar y llamar al compañero | **M** |
| Impulsar al compañero | **F4** |
| Ofrecer la mano | **F2** |

P1 ofrece la mano con **F1** e impulsa con **F3**.

## Menú F6

| Opción | Función |
| --- | --- |
| **1** | Elegir modalidad. **1 · Local** invita o retira a P2. **2 · En línea** aparece como «En desarrollo» y todavía no se puede usar. [Cómo va a funcionar](EN-LINEA.md). |
| **2** | Elegir el modo de cámara. |
| **3** | Elegir el sombrero de P2 con las flechas y **Enter**. Puede usar un sombrero desbloqueado, ir sin sombrero o seguir la elección de P1. |
| **4** | Abrir Extras. **1** indicador de estado, **2** agarre en el aire al ofrecer la mano, **3** impulso de compañero, **4** Eventos de P2, **5 · Jugar como Six** (solo desde el menú principal del juego) y **6 · Idioma**. |
| **5** | Reasignar el teclado de P2. Selecciona la acción con las flechas, pulsa **Enter** y luego la tecla nueva. **Esc** cancela la captura. |
| **6** | Reasignar las teclas de teletransporte y activar o desactivar el efecto de televisión. |
| **7** | Asignar un mando a P1, a P2 o uno a cada jugador. |
| **8** | Activar o desactivar la separación peligrosa. |

**Retroceso** vuelve al menú principal desde un submenú. Las preferencias se guardan en `scripts/preferences.ini`. **F8** escribe un diagnóstico en el registro del mod.

El idioma elegido se aplica al menú F6 y a los avisos del mod. Para volver al español desde inglés, abre **F6 → 4 → 6 · Language**.

### Jugar como Six

Actívalo en **F6 → 4 → 5** desde el menú principal del juego, antes de cargar o empezar la partida. P2 conserva sus controles y toma el control de la Six de la historia cuando acompaña a Mono. Cuando ella se va, P2 se convierte en Dark Six y vuelve a ser Six cuando regresa. Su ropa cambia sola entre la del principio, el impermeable amarillo y Dark Six.

En algunas escenas el juego mueve a Six por su cuenta; P2 recupera el control al terminar. Los sombreros quedan reservados para el modo de dos Monos. La elección se guarda y queda bloqueada mientras dura la partida.

### Modos de cámara

- **F6 → 2 → 1 · Compartida estable.** Prioriza a P1. En los planos compatibles, abre el encuadre gradualmente hasta 80° para dar espacio a ambos.
- **F6 → 2 → 2 · Compartida original.** Usa el comportamiento original que toma en cuenta a ambos jugadores.
- **F6 → 2 → 3 · Dividida horizontal.** P1 arriba, P2 abajo, con seguimiento independiente y el audio anclado a la cámara de P1.
- **F6 → 2 → 4 · Dividida vertical.** P1 a la izquierda, P2 a la derecha, con seguimiento independiente y el audio anclado a la cámara de P1.
- **F6 → 2 → 5 · Llenar pantalla.** Quita las barras negras de cada vista en ambas orientaciones. Al desactivarlo se recupera el encuadre original. El modo de cámara y esta opción se guardan.

En cámara compartida, una flecha señala a cualquiera que quede fuera del cuadro. Si la separación peligrosa está activa, una ausencia prolongada causa distorsión, interferencia y latidos, y puede reiniciar el checkpoint. El efecto se pausa en pantalla dividida.

### Mandos

Abre **F6 → 7** y pulsa **1** para dejar el mando a P1, **2** para dárselo a P2 o **3** para usar dos mandos. Suelta los botones para que se aplique el cambio. Con un solo mando, el otro jugador usa el teclado. Con dos, P1 usa el primer mando XInput y P2 otro conectado; si se desconecta uno, su jugador puede seguir con el teclado. Se admiten mandos presentados como mando Xbox mediante Steam Input. [Emulación de mandos de Steam Input](https://partner.steamgames.com/doc/features/steam_controller/steam_input_gamepad_emulation_bestpractices).

En P2, el **stick izquierdo** mueve y escala, **A** salta, **RT** agarra, **LT** agacha, **X** corre, **Y** usa o lanza y **B** acciona la linterna o el control remoto. **LB** ofrece la mano. Si se desconecta el mando de P2, vuelve a sus teclas.

### Llamar al compañero

Usa el **grito original** de P1 o pulsa **M** desde P2. Con el mando de P2, pulsa **arriba en la cruceta**. El grito activa la llamada del juego y el aviso cooperativo. En cámara compartida se señala a quien grita, incluso si está fuera de cuadro. En pantalla dividida el aviso aparece en la vista del compañero. La tecla de P2 se puede cambiar en **F6 → 5**.

### Teletransporte y checkpoints

**F9** trae P2 a P1 y **F10** trae P1 a P2. El mod bloquea el teletransporte durante acciones incompatibles, cargas o escenas, y cuando falta espacio para llegar.

Si muere cualquiera de los dos, se reinicia el checkpoint para ambos. P2 vuelve tras la carga y conserva su configuración. Si se encuentra el actor que dirige el despertar, P2 reaparece sentado y se incorpora con sus propios controles.

### Acciones en pareja

**Ofrecer la mano.** Desde suelo firme y con las manos libres, pulsa una vez **F1** para P1, **F2** para P2 o **LB** en el mando asignado. Si tu compañero entra al alcance de la mano, colgado de un borde o en el aire delante de ti, lo agarras y lo subes. Él no tiene que pulsar nada. Vuelve a pulsar la tecla para retirar la mano; también se retira sola a los 10 segundos o si te mueves. Si no hay sitio para subirlo, la mano sigue extendida y lo vuelve a intentar.

Si P2 está colgado de una cornisa, su tecla de grito (**M**) muestra **P2 pide ayuda** para que P1 le ofrezca la mano. **F6 → 4 → 2** activa o desactiva el agarre en el aire; los bordes funcionan siempre. Vale con dos Monos y jugando como Six, con cualquiera de los dos como ayudante.

**Impulso de compañero.** Viene activado; lo puedes quitar en **F6 → 4 → 3**. Pulsa **F3** con P1 o **F4** con P2 para agacharte en postura. Tu compañero se acerca por delante y pulsa agarrar para que lo lances hacia arriba. Para cancelar, vuelve a pulsar la misma tecla. Puedes reasignar la tecla de P2 en **F6 → 5 → Impulsar al compañero**.

### Eventos de P2

Con **F6 → 4 → 4** activado, que es el valor de serie, el juego responde a P2 cuando es él quien actúa:

- Abrir candados con una llave y mover palancas.
- Recoger su propia cabeza de abusón en la Escuela, ponérsela y conservarla al volver a un punto de control.
- Cruzar los pasillos estrechos que rompen la cabeza sin que se rompa la de P1.
- Iniciar eventos de zona cuando entra él primero.

Si un evento se comporta de forma extraña, puedes desactivarlo ahí mismo y contármelo en un issue.

### Escenas con P2

P2 aparece por la televisión del Bosque si lo activas antes de empezar una partida nueva. Participa en la escena de Six bajo la mesa, en el disparo al Cazador desde la caseta, en la balsa, en los cruces por televisores de la Ciudad Pálida (cualquiera de los dos puede entrar primero), en la caja de música de la Torre y en el puente final. Recibe su propia linterna en el Hospital y su propio mando a distancia en la Ciudad Pálida.

En el pantano, ambos deben agacharse bajo cobertura para que el Cazador no los detecte.

### Logros

El menú principal y el de pausa del juego tienen un botón **Logros**. La pestaña de Steam muestra tus logros del juego, sin desbloquear ninguno. La pestaña de The Second Shadow está vacía en esta versión: estoy preparando los logros propios del mod, y conseguir uno en específico desbloqueará un final adicional.


## Los ajustes que dejé por defecto

| Opción | Valor inicial |
| --- | --- |
| Cámara | Compartida estable, sin llenar pantalla |
| Idioma | Español |
| Indicador de estado | Visible |
| Mando | Asignado a P1 |
| Teletransporte | F9 y F10, con efecto de televisión |
| Separación peligrosa | Desactivada |
| Agarre en el aire al ofrecer la mano | Activado |
| Impulso de compañero | Activado |
| Eventos de P2 | Activados |
| P2 | Dos Monos, con el sombrero que siga al de P1 |

Las teclas son las de esta guía.

Estos valores se aplican al instalar desde cero; después puedes cambiarlos desde F6. Las actualizaciones conservan tu preferences.ini.
