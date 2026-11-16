# The Second Shadow · v0.7.0 Alpha

**The Second Shadow** añade cooperativo local a la edición original de Little Nightmares II en Steam (Helios, Unreal Engine 4.24) mediante UE4SS. El modo local empieza con dos Monos y ofrece la opción de que P2 juegue con la apariencia de Six.

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

## Menú F6

| Opción | Función |
| --- | --- |
| **1** | Elegir modalidad. **1 · Local** invita o retira a P2. **2 · En línea** está en desarrollo. |
| **2** | Elegir el modo de cámara. |
| **3** | Elegir el sombrero de P2 con las flechas y **Enter**. Puede usar un sombrero desbloqueado, ir sin sombrero o seguir la elección de P1. |
| **4** | Abrir Extras para configurar el indicador, el rescate aéreo experimental, la ayuda de salto y la redirección de eventos de P2. **5 · Jugar como Six** cambia la apariencia de P2 desde el menú principal del juego. **6 · Idioma** alterna entre Español y English. |
| **5** | Reasignar el teclado de P2. Selecciona la acción con las flechas, pulsa **Enter** y luego la tecla nueva. **Esc** cancela la captura. |
| **6** | Reasignar las teclas de teletransporte y activar o desactivar el efecto de televisión. |
| **7** | Asignar un mando a P1 o P2. |
| **8** | Activar o desactivar la separación peligrosa. |

**Retroceso** vuelve al menú principal desde un submenú. Las preferencias se guardan en `scripts/preferences.ini`. **F8** escribe un diagnóstico en el registro del mod.

El idioma elegido se aplica al menú F6 y a los avisos del mod. Para volver al español desde inglés, abre **F6 → 4 → 6 · Language**.

**Jugar como Six** conserva los controles de P2. Su apariencia sigue a la Six de la historia. Usa su ropa inicial o su impermeable amarillo cuando ella está presente y se ve como Dark Six cuando está ausente. El selector de sombrero queda reservado para el modo Mono. La elección se guarda y queda bloqueada después de cargar la partida.

### Modos de cámara

- **F6 → 2 → 1 · Compartida estable.** Prioriza a P1. En los planos compatibles, abre el encuadre gradualmente hasta 80° para dar espacio a ambos.
- **F6 → 2 → 2 · Compartida original.** Usa el comportamiento original que toma en cuenta a ambos jugadores.
- **F6 → 2 → 3 · Dividida horizontal.** P1 arriba, P2 abajo, con seguimiento independiente y el audio anclado a la cámara de P1.
- **F6 → 2 → 4 · Dividida vertical.** P1 a la izquierda, P2 a la derecha, con seguimiento independiente y el audio anclado a la cámara de P1.
- **F6 → 2 → 5 · Llenar pantalla.** Quita las barras negras de cada vista en ambas orientaciones. Al desactivarlo se recupera el encuadre original. El modo de cámara y esta opción se guardan.

En cámara compartida, una flecha señala a cualquiera que quede fuera del cuadro. Si la separación peligrosa está activa, una ausencia prolongada causa distorsión, interferencia y latidos, y puede reiniciar el checkpoint. El efecto se pausa en pantalla dividida.

### Un mando y un teclado

Abre **F6 → 7** y pulsa **1** para asignar el mando a P1 o **2** para asignarlo a P2. Suelta los botones para que se aplique el cambio. El otro jugador usa el teclado. Se admite un mando XInput, incluido uno presentado como mando Xbox mediante Steam Input. [Emulación de mandos de Steam Input](https://partner.steamgames.com/doc/features/steam_controller/steam_input_gamepad_emulation_bestpractices).

En P2, el **stick izquierdo** mueve y escala, **A** salta, **RT** agarra, **LT** agacha, **X** corre, **Y** usa o lanza y **B** acciona la linterna o el control remoto. Si se desconecta el mando de P2, vuelve a sus teclas.

### Llamar al compañero

Usa el **grito original** de P1 o pulsa **M** desde P2. Con el mando de P2, pulsa **arriba en la cruceta**. El grito activa la llamada del juego y el aviso cooperativo. En cámara compartida se señala a quien grita, incluso si está fuera de cuadro. En pantalla dividida el aviso aparece en la vista del compañero. La tecla de P2 se puede cambiar en **F6 → 5**.

### Teletransporte y checkpoints

**F9** trae P2 a P1 y **F10** trae P1 a P2. El mod bloquea el teletransporte durante acciones incompatibles, cargas o escenas, y cuando falta espacio para llegar.

Si muere cualquiera de los dos, se reinicia el checkpoint para ambos. P2 vuelve tras la carga y conserva su configuración. Si se encuentra el actor que dirige el despertar, P2 reaparece sentado y se incorpora con sus propios controles.

### Cinemáticas y sigilo en el bosque

**Ofrecer la mano.** Desde suelo firme, mira hacia el compañero y mantén **F1** para P1, **F2** para P2 o **LB** en el mando asignado. Si el otro Mono está colgado, debe mantener su agarre normal. **F6 → 4 → 2** alterna el rescate aéreo experimental, que viene desactivado. **F6 → 4 → 1** alterna el indicador de estado. El mod guarda las dos opciones. Soltar la tecla de ayuda durante el tirón cancela el rescate.

**Ayuda de salto experimental.** Agáchate y pulsa tu botón de ayuda (**F1**, **F2** o **LB**) para preparar la postura. Puedes soltar la tecla. El otro Mono se acerca por delante y pulsa su botón de agarre para recibir el impulso hacia la perilla. Si quieres cancelar la postura, vuelve a pulsar ayuda o usa tu propio botón de agarre. Puedes activarla o desactivarla en **F6 → 4 → 3**. Viene desactivada y tu elección se guarda.

P2 participa en la escena de Six bajo la mesa y en el disparo al Cazador en la caseta. En la caseta, P1 maneja la escopeta y P2 se coloca a su lado y reacciona al disparo.

En el pantano, ambos Monos deben agacharse bajo cobertura para evitar que el Cazador los detecte.


## Configuración inicial de esta distribución

Cámara compartida estable, español, indicador visible y mando asignado a P1. El efecto de teletransporte está activado. Separación peligrosa, llenar pantalla, rescate aéreo, ayuda de salto y redirección de eventos de P2 están desactivados. P2 usa Mono y su sombrero sigue al de P1. Las teclas son las indicadas en esta guía.

Estos valores se aplican al instalar desde cero; después puedes cambiarlos desde F6. Las actualizaciones conservan tu preferences.ini.
