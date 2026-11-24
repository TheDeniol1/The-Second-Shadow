-- Logros propios de The Second Shadow.
-- Para añadir uno, copia una entrada y cambia id, textos y eventos.
--  id      : nombre único, solo letras, números y _ (se usa en achievements.ini).
--  title   : nombre visible {es=..., en=...}.
--  desc    : descripción visible {es=..., en=...}.
--  events  : eventos que suman progreso. Los del juego son 'game:<EAchievement>'
--            (por ejemplo 'game:CompleteSchool'). Los del mod: 'coop:active',
--            'split:seconds' (suma segundos en pantalla dividida).
--  target  : progreso necesario (1 si se omite).
--  coop    : true si solo cuenta con el cooperativo activo.
--  six     : true si solo cuenta jugando como Six.
--  hidden  : true para ocultar nombre y descripción hasta desbloquearlo.
--  unit    : 'minutes' muestra el progreso en minutos (target en segundos).
--  icon    : PNG opcional en la carpeta scripts (por ejemplo 'mi_logro.png').
--            Sin él se busca logro_<id>.png (por ejemplo logro_eco.png). Mientras
--            el logro está bloqueado se muestra logro_propio.png (icono de bloqueado),
--            que también se usa si falta el icono propio.
--            Medida recomendada: 256x256 (o 128x128), fondo oscuro opaco.
-- v0.8.0 Alpha: la lista se publica vacía mientras se terminan los logros
-- propios. La pestaña del menú muestra «Próximamente». Los borradores siguen
-- abajo, comentados, para retomarlos.
return {}

--[==[ Borradores para una versión futura:
return {
 {id='dos_sombras',title={es='Dos sombras',en='Two Shadows'},
  desc={es='Juega una partida con el cooperativo local activo.',en='Play a game with local co-op enabled.'},
  events={'coop:active'},coop=true},
 {id='bosque_a_dos',title={es='El Bosque, a dos',en='Two in the Wilderness'},
  desc={es='Completa el Bosque en cooperativo.',en='Complete the Wilderness in co-op.'},
  events={'game:CompleteWilderness'},coop=true},
 {id='recreo_compartido',title={es='Recreo compartido',en='Shared Recess'},
  desc={es='Completa la Escuela en cooperativo.',en='Complete the School in co-op.'},
  events={'game:CompleteSchool'},coop=true},
 {id='turno_doble',title={es='Turno doble',en='Double Shift'},
  desc={es='Completa el Hospital en cooperativo.',en='Complete the Hospital in co-op.'},
  events={'game:CompleteHospital'},coop=true},
 {id='senal_compartida',title={es='Señal compartida',en='Shared Signal'},
  desc={es='Completa la Ciudad Pálida en cooperativo.',en='Complete the Pale City in co-op.'},
  events={'game:CompletePaleCity'},coop=true},
 {id='hasta_el_final',title={es='Hasta el final',en='To the End, Together'},
  desc={es='Termina el juego en cooperativo.',en='Finish the game in co-op.'},
  events={'game:GameComplete'},coop=true},
 {id='la_otra_six',title={es='Yo ya estuve en tus zapatos',en='I Have Been in Your Shoes'},
  desc={es='Completa un capítulo con P2 jugando como Six.',en='Complete a chapter with Player 2 playing as Six.'},
  events={'game:CompleteWilderness','game:CompleteSchool','game:CompleteHospital','game:CompletePaleCity','game:GameComplete'},
  coop=true,six=true,hidden=true},
 {id='ojos_de_mas',title={es='Ojos de más',en='Extra Eyes'},
  desc={es='Atrapa 5 niños fantasma en cooperativo.',en='Catch 5 Glitching Remains in co-op.'},
  events={'game:FindAllPhantomKids'},target=5,coop=true},
 {id='eco',title={es='Eco',en='Echo'},
  desc={es='Llama 10 veces en cooperativo.',en='Call out 10 times in co-op.'},
  events={'game:CallSix'},target=10,coop=true},
 {id='cada_uno_lo_suyo',title={es='Cada uno a lo suyo',en='Split Up'},
  desc={es='Juega 30 minutos en pantalla dividida.',en='Play for 30 minutes in split-screen.'},
  events={'split:seconds'},target=1800,unit='minutes',coop=true},
}
]==]
