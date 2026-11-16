local M={name='The Second Shadow',version='v0.7.0 Alpha'}
local Bindings=require('coop_bindings')
local Locale=require('coop_locale')
local white={R=1,G=1,B=1,A=1}
local faded={R=.68,G=.68,B=.68,A=1}
local line={R=1,G=1,B=1,A=.64}
local panel={R=0,G=0,B=0,A=.86}
local selection={R=1,G=1,B=1,A=.10}
local hover={R=1,G=1,B=1,A=.16}
local cameraModes={'Compartida estable','Compartida original','Dividida horizontal','Dividida vertical'}
local numberKeys={'One','Two','Three','Four','Five','Six','Seven','Eight'}
function M.draw(hud,w,h,state,preset,font)
 local s=math.min(w/760,h/768)
 local left,top=(w-660*s)/2,(h-716*s)/2
 local x,y=left+38*s,top+18*s
 local function tr(message,...) return Locale.text(state.language,message,...) end
 local function notice(message) return Locale.notice(state.language,message) end
 local function yes(value) return tr(value and 'Sí' or 'No') end
 local function pretty(key) return tr(Bindings.pretty(key)) end
 local function text(t,dx,dy,size,color) hud:DrawText(tr(t),color or white,x+dx*s,y+dy*s,font,size*s,false) end
 local function rect(color,dx,dy,width,height) hud:DrawRect(color,x+dx*s,y+dy*s,width*s,height*s) end
 local function highlight(dy,height)
  rect(selection,-12,dy,598,height)
  rect(white,-12,dy,2,height)
 end
 local function target(action,dy,height,dx,width)
  dx,width=dx or -12,width or 598
  if hud.MenuTarget then hud:MenuTarget(action,x+dx*s,y+dy*s,width*s,height*s) end
  if state.menuHover==action then rect(hover,dx,dy,width,height) end
 end
 local function option(key,label,dy,disabled)
  if not disabled then target(numberKeys[tonumber(key)],dy-3,39) end
  rect(selection,0,dy+2,30,28)
  local color=disabled and faded or white
  text(key,10,dy+3,.66,color)
  text(label,44,dy,.95,color)
 end
 local function footer(hint)
  rect(line,0,608,584,1)
  if hint then text(hint,0,622,.73,faded)
  else
   target('back',616,34,-8,220)
   text('Retroceso  volver',0,622,.73,faded)
  end
  target('close',616,34,470,116)
  text('F6  cerrar',482,622,.73,faded)
  text(M.version,482,655,.58,faded)
 end
 hud:DrawRect({R=0,G=0,B=0,A=.46},0,0,w,h)
 hud:DrawRect({R=0,G=0,B=0,A=.38},left+7*s,top+8*s,660*s,716*s)
 hud:DrawRect(panel,left,top,660*s,716*s)
 hud:DrawRect(line,left,top,660*s,s)
 hud:DrawRect(line,left,top+715*s,660*s,s)
 text('Little Nightmares II: '..M.name,0,0,1.42)
 rect(line,0,59,584,1)
 if state.menuPage=='play' then
  text('Modalidad de juego',0,74,1.25)
  option('1','Local',145)
  text(state.enabled and 'Cooperativo activo. Pulsa 1 para retirar al jugador 2.' or
   'Pulsa 1 para invitar al jugador 2.',44,184,.78,faded)
  text('[2] En línea',0,260,.95,faded)
  text('En desarrollo',44,298,.78,faded)
  footer()
  return
 end
 if state.menuPage=='camera' then
  text('Modos de cámara',0,74,1.25)
  local details={
   'Sigue al jugador 1 y amplía la vista para incluir a ambos.',
   'La cámara tiene en cuenta a los dos jugadores.',
   'Jugador 1 arriba y jugador 2 abajo.',
   'Jugador 1 a la izquierda y jugador 2 a la derecha.',
  }
  for i,name in ipairs(cameraModes) do
   local selected=i==state.cameraMode
   if selected then highlight(136+(i-1)*78,67) end
   target(numberKeys[i],136+(i-1)*78,67)
   text('['..i..'] '..tr(name),0,140+(i-1)*78,1)
   text(details[i],24,176+(i-1)*78,.75,faded)
  end
  target('Five',448,66)
  text(tr('[5] Llenar pantalla: %s',yes(state.fillScreen)),0,450,.95)
  text('Quita las barras negras de las dos vistas divididas.',24,486,.72,faded)
  text('La separación peligrosa se pausa en pantalla dividida.',0,520,.68,faded)
  footer()
  return
 end
 if state.menuPage=='extras' then
  text('Extras',0,74,1.25)
  target('One',150,41)
  target('Two',220,70)
  target('Three',320,70)
  target('Four',420,70)
  text(tr('[1] Indicador de estado: %s',tr(state.showStatus and 'Visible' or 'Oculto')),0,155,1)
  text(tr('[2] Rescate aéreo (experimental): %s',yes(state.airRescue)),0,225,1)
  text('Permite atrapar al compañero mientras cae.',24,262,.76,faded)
  text(tr('[3] Ayuda de salto de compañero (experimental): %s',yes(state.jumpAssist)),0,325,.95)
  text('Agáchate y pulsa ayuda. Tu compañero pulsa agarre.',24,362,.76,faded)
  text(tr('[4] Eventos de P2 (experimental): %s',yes(state.eventRedirect)),0,425,.95)
  text('Enruta los eventos y la IA al jugador más cercano.',24,462,.76,faded)
  if not state.sixLocked then target('Five',500,63) end
  text(tr('[5] Jugar como Six: %s',yes(state.playAsSix)),0,505,.95,state.sixLocked and faded or white)
  local detail='Acompaña a Mono como Six.'
  if state.sixAppearanceFailed then detail='Bloqueado en partida. Apariencia de Six no disponible.'
  elseif state.sixLocked then detail='Bloqueado durante la partida.' end
  text(detail,24,537,.76,faded)
  target('Six',567,36)
  text(tr('[6] Idioma: %s',state.language=='en' and 'English' or 'Español'),0,570,.95)
  footer()
  return
 end
 if state.menuPage=='hats' then
  local hats=state.hats
  text('Sombrero del jugador 2',0,74,1.25)
  local start=math.max(1,math.min(hats.cursor-3,#hats.options-6))
  for i=start,math.min(start+6,#hats.options) do
   local option=hats.options[i]
   local selected=i==hats.cursor
   local marker=option.id==hats:selected() and tr('  [elegido]') or ''
   if selected then highlight(142+(i-start)*43,40) end
   target(i,142+(i-start)*43,40)
   text(tr(option.label)..marker,0,145+(i-start)*43,.9)
  end
  text(hats.cursor..' / '..#hats.options,0,465,.72,faded)
  if #hats.options>7 then
   target('hatUp',456,35,308,128)
   text('Anterior',320,465,.72,faded)
   target('hatDown',456,35,444,140)
   text('Siguiente',456,465,.72,faded)
  end
  text(notice(hats.hint),0,503,.76)
  footer()
  return
 end
 if state.menuPage=='gamepad' then
  local pad=state.gamepad
  text('Asignar mando',0,74,1.25)
  highlight(pad.owner==1 and 146 or 201,42)
  target('One',146,42)
  target('Two',201,42)
  text('[1] Jugador 1',0,150,1)
  text('[2] Jugador 2',0,205,1)
  if not pad.read then
   text('No se puede usar el mando en este momento.',0,285,.8,faded)
  elseif pad.slot==nil then
   text('No se detecta ningún mando. Comprueba la conexión.',0,285,.8,faded)
  elseif pad.owner==2 and not state.enabled then
   text('Mando conectado. Activa al jugador 2 con F7.',0,285,.8,faded)
  elseif state.enabled and pad.routed~=(pad.owner==2) then
   text('Suelta los botones del mando para aplicar el cambio.',0,285,.8,faded)
  else
   text('Mando conectado.',0,285,.8,faded)
  end
  text('Jugador 2: palanca izquierda para moverse y escalar.',0,350,.78)
  text('A  saltar     RT  agarrar     LT  agacharse',0,388,.76,faded)
  text('X  correr    Y  usar o lanzar    B  linterna / control remoto',0,420,.76,faded)
  text('Cruceta arriba  gritar / llamar al compañero',0,456,.76,faded)
  text('Botones indicados como en un mando Xbox.',0,496,.68,faded)
  footer()
  return
 end
 if state.menuPage=='teleport'then
  local tp=state.tp;local controls=tp.controls
  text('Teletransporte',0,74,1.25)
  for i,action in ipairs(controls.actions)do
   local selected=i==controls.selected
   local dy=150+(i-1)*55
   if selected then highlight(dy-4,40) end
   target(i,dy-4,40)
   text(action.label,0,dy,.95)
   text(controls.capture==action.id and '[ ... ]'or('[ '..pretty(controls.bindings[action.id])..' ]'),425,dy,.95,selected and white or faded)
  end
  text(notice(controls.hint),0,285,.78)
  target('Three',344,39)
  text(tr('[3] Efectos de interferencia: %s',yes(tp.effects)),0,350,.87)
  text('Para reunirse, ambos deben estar libres y en suelo firme.',0,405,.68,faded)
  text(tp.notice~=''and notice(tp.notice) or 'Acerca a un jugador al lugar donde está su compañero.',0,440,.68,faded)
  text('Arriba / abajo  seleccionar     Enter  cambiar',0,505,.70,faded)
  footer()
  return
 end
 if state.menuPage=='controls' then
  local controls=state.controls
  text('Controles del jugador 2',0,74,1.25)
  for i,action in ipairs(Bindings.actions)do
   local selected=i==controls.selected
   local dy=145+(i-1)*35
   local value=controls.capture==action.id and '[ ... ]' or ('[ '..pretty(controls.bindings[action.id])..' ]')
   if selected then highlight(dy-1,33) end
   target(i,dy-1,33)
   text(action.label,0,dy,.85)
   text(value,425,dy,.85,selected and white or faded)
  end
  text(notice(controls.hint),0,535,.78,white)
  text('Arriba / abajo  seleccionar     Enter  cambiar',0,570,.70,faded)
  footer()
  return
 end
 text('Coop Mod',0,74,1.35)
 option('1','Modalidad de juego',145)
 option('2',tr('Cámara: %s',tr(cameraModes[state.cameraMode or 1])),190)
 option('3',state.playAsSix and 'Sombrero del jugador 2 (solo Mono)' or 'Sombrero del jugador 2',235,state.playAsSix)
 option('4','Extras',280)
 option('5','Teclado del jugador 2',325)
 option('6','Opciones de teletransporte',370)
 option('7',tr('Mando para el jugador %d',state.gamepad and state.gamepad.owner or 1),415)
 option('8',tr('Separación peligrosa: %s',yes(state.separation.enabled)),460)
 rect(line,0,508,584,1)
 text(state.status,0,520,.8,state.enabled and white or faded)
 text(tr('%s  mover / escaleras    %s  saltar    %s  agarrar',
  table.concat({pretty(preset.up),pretty(preset.left),pretty(preset.down),pretty(preset.right)},' '),pretty(preset.jump),pretty(preset.grab)),0,555,.68,faded)
 text(tr('%s  agacharse    %s  correr    %s  usar / lanzar    %s  linterna / control',
  pretty(preset.sneak),pretty(preset.sprint),pretty(preset.use),pretty(preset.gadget)),0,582,.68,faded)
 footer('F7  activar o retirar jugador 2')
 text(tr('%s  gritar / llamar al compañero',pretty(preset.call)),0,655,.75,faded)
end
function M.badge(hud,state,font)
 local message=state.rescueNotice or (state.tp and state.tp.notice~=''and state.tp.notice or state.status)
 hud:DrawRect(state.enabled and white or faded,22,26,2,22)
 hud:DrawText(Locale.notice(state.language,message)..'   [F6]',white,32,23,font,.68,false)
end
function M.static(hud,w,h,frame)
 for i=1,16 do
  local seed=(frame*7919+i*104729)%65521
  local shade=(seed%100)/100
  local x=(seed%1000)/1000*w
  local y=((seed*37)%1000)/1000*h
  hud:DrawRect({R=shade,G=shade,B=shade,A=.12},x,y,w*(.03+(seed%180)/1000),1+seed%3)
 end
 hud:DrawRect({R=.8,G=.85,B=.9,A=.035},0,(frame*47)%h,w,3)
end
function M.separationStatic(hud,view,side,amount,frame)
 local w,h=view.right-view.left,view.bottom-view.top
 local reach=.16+.84*amount
 local left,top=view.left,view.top
 if side=='left' or side=='right' then
  if side=='right' then left=left+w*(1-reach) end
  w=w*reach
 else
  if side=='bottom' then top=top+h*(1-reach) end
  h=h*reach
 end
 for i=1,64 do
  local seed=(frame*7919+i*104729)%65521
  local width=w*(.03+(seed%360)/1000)
  local height=1+seed%5
  local x=left+((seed*19)%1000)/1000*(w-width)
  local y=top+((seed*37)%1000)/1000*math.max(0,h-height)
  local shade=.12+(seed%100)*.007
  hud:DrawRect({R=shade,G=shade,B=shade,A=.1+.32*amount},x,y,width,math.min(h,height))
 end
end
return M
