-- The Second Shadow · modo online, fase 1.
-- El anfitrion juega la partida real; el invitado envia por la red de Steam
-- los controles de P2. Este modulo lleva la sesion, la pagina F6 -> 1 -> 2 y
-- la entrada remota. No toca el juego: main.lua pregunta remoteInput().
local Proto=require('online_protocol')
local M={};M.__index=M
-- v0.8.0 Alpha: el modo en línea sigue en desarrollo y no se incluye su adaptador.
-- Con enabled=false el menú lo muestra como «En desarrollo» y no se carga ninguna DLL.
M.enabled=false

local HELLO_EVERY,PING_EVERY,LOST_AFTER,STALE_INPUT=1.0,1.0,6.0,0.35
local numberKeys={'One','Two','Three','Four','Five','Six','Seven','Eight'}
local english={
 ['Modalidad en línea']='Online mode',
 ['En línea']='Online',
 ['Juega con un amigo de Steam (en pruebas).']='Play with a Steam friend (testing).',
 ['Crear partida']='Host a game',
 ['Tu partida es la real; tu amigo controla a P2.']='Your game is the real one; your friend controls P2.',
 ['Unirse a un amigo']='Join a friend',
 ['Tus controles de P2 manejan a P2 en su partida.']='Your P2 controls drive P2 in their game.',
 ['Elige al amigo que juega contigo']='Choose the friend playing with you',
 ['Amigos de Steam jugando a Little Nightmares II:']='Steam friends playing Little Nightmares II:',
 ['Ningún amigo está jugando ahora.']='No friends are playing right now.',
 ['[8] Actualizar lista']='[8] Refresh list',
 ['Anfitrión']='Host',['Invitado']='Guest',
 ['Esperando a %s…']='Waiting for %s…',
 ['Conectado con %s']='Connected to %s',
 ['Conexión perdida con %s. Reintentando…']='Lost connection to %s. Retrying…',
 ['Ping %d ms']='Ping %d ms',
 ['Tu amigo también debe elegirte en F6 → 1 → 2.']='They must also pick you in F6 → 1 → 2.',
 ['Activa P2 con F7 para que tu amigo lo controle.']='Turn on P2 with F7 so your friend can control it.',
 ['Tu mando o tus teclas de P2 se envían al anfitrión.']='Your controller or P2 keys are sent to the host.',
 ['[8] Desconectar']='[8] Disconnect',
 ['Red de Steam no disponible: %s']='Steam networking unavailable: %s',
 ['Versión del mod distinta a la de %s']='Mod version differs from %s',
 ['%s se ha desconectado']='%s disconnected',
 ['Fase 1: todavía sin imagen; el invitado no ve la partida.']='Phase 1: no video yet; the guest cannot see the game.',
}

local function stick(x,y)
 local magnitude=math.sqrt(x*x+y*y)
 local deadzone=7849
 if magnitude<=deadzone then return 0,0 end
 local strength=(math.min(magnitude,32767)-deadzone)/(32767-deadzone)
 return strength*x/magnitude,strength*y/magnitude
end
-- Misma traduccion de XInput que coop_gamepad.lua para el jugador 2.
function M.padInput(x,y,buttons,left,right)
 if x==nil then return nil end
 local moveX,moveY=stick(x,y)
 return {x=moveX,y=moveY,jump=(buttons&0x1000)~=0,sprint=(buttons&0x4000)~=0,
  use=(buttons&0x8000)~=0,gadget=(buttons&0x2000)~=0,sneak=left>30,grab=right>30,
  assist=(buttons&0x0100)~=0,call=(buttons&0x0001)~=0}
end

local function loadNative(root,log)
 local ok,api=pcall(function()
  local loader,reason=package.loadlib((root or '')..'ln2_online_02.dll','luaopen_ln2_online')
  assert(loader,reason)
  local module=loader()
  assert(type(module)=='table','UE4SS no coincide con el adaptador en línea')
  return module
 end)
 if ok then log('Adaptador en línea cargado: '..tostring(api.version)); return api end
 log('Adaptador en línea no disponible: '..tostring(api))
end

-- opts: root, log, version (texto), sample() -> entrada de teclado de P2,
-- pad(slot) -> lectura cruda de XInput, foreground(), net (transporte de pruebas).
function M.new(opts)
 local self=setmetatable({log=opts.log or function() end,sample=opts.sample,pad=opts.pad,
  foreground=opts.foreground or function() return true end,language=opts.language or function() return 'es' end},M)
 self.net=opts.net or (M.enabled and loadNative(opts.root,self.log)) or nil
 self.versionCode=Proto.versionCode(opts.version or '?')
 self.keysHeld={}
 self:reset()
 return self
end
function M:reset()
 self.role,self.phase,self.peer,self.peerName=nil,'idle',nil,nil
 self.remote,self.remoteAt,self.remoteSeq=nil,nil,nil
 self.seq,self.history=0,0
 self.rtt,self.pingAt,self.helloAt,self.seenAt=nil,nil,nil,nil
end
function M:tr(message,...)
 local text=self.language()=='en' and english[message] or message
 if select('#',...)>0 then return text:format(...) end
 return text
end
function M:now()
 if self.net and self.net.clock_us then return self.net.clock_us()/1e6 end
 return os.clock()
end
function M:active() return self.role~=nil and self.phase~='idle' and self.phase~='pick' end
function M:connected() return self.phase=='connected' end
function M:notice(text) self.message=text; self.log(text) end

function M:startPick(role)
 self.message=nil
 if not self.net then self:notice(self:tr('Red de Steam no disponible: %s','falta ln2_online_02.dll')); return false end
 local ok,id,reason=pcall(self.net.steam_open)
 if not ok or not id then
  self:notice(self:tr('Red de Steam no disponible: %s',tostring(ok and reason or id))); return false
 end
 self.self=id
 self.role=role
 self.phase='pick'
 self:refresh()
 return true
end
function M:refresh()
 self.friends={}
 local ok,count=pcall(self.net.friends_scan)
 if not ok then self:notice(tostring(count)); return end
 for i=1,math.min(count,7) do
  local id,name=self.net.friend(i)
  if id then self.friends[#self.friends+1]={id=id,name=name} end
 end
end
function M:choose(index)
 local friend=self.friends and self.friends[index]
 if not friend then return false end
 self.net.set_peer(friend.id)
 self.peer,self.peerName=friend.id,friend.name
 self.phase='waiting'
 self.helloAt=nil
 self.log((self.role==Proto.HOST and 'Anfitrión' or 'Invitado')..': esperando a '..friend.name)
 return true
end
-- code viaja en el BYE: 0 normal, 1 versiones distintas.
function M:disconnect(reason,code)
 if self.net and self.peer then
  pcall(self.net.send,Proto.BYE,code or 0,0,0,1)
  pcall(self.net.set_peer,0)
 end
 if reason then self:notice(reason) end
 self.log('Sesión en línea cerrada')
 self:reset()
end

function M:send(kind,a,b,c,reliable)
 local ok,err=pcall(self.net.send,kind,a or 0,b or 0,c or 0,reliable and 1 or 0)
 if not ok then self.log('Envío en línea fallido: '..tostring(err)) end
end
function M:handle(kind,a,b,c,now)
 self.seenAt=now
 if self.phase=='lost' and kind~=Proto.HELLO and kind~=Proto.BYE then
  self.phase='connected'
  self:notice(self:tr('Conectado con %s',self.peerName or '?'))
 end
 if kind==Proto.HELLO then
  if a~=Proto.PROTOCOL or b~=self.versionCode then
   self:disconnect(self:tr('Versión del mod distinta a la de %s',self.peerName or '?'),1)
   return
  end
  -- c: papel del otro lado y, en el bit 8, si ya se considera conectado.
  local expected=self.role==Proto.HOST and Proto.GUEST or Proto.HOST
  if c&0xff~=expected then return end
  if self.phase~='connected' then
   self.phase='connected'
   self.remote,self.remoteAt,self.remoteSeq=nil,nil,nil
   self:notice(self:tr('Conectado con %s',self.peerName or '?'))
  end
  if c&0x100==0 then self:send(Proto.HELLO,Proto.PROTOCOL,self.versionCode,self.role|0x100,true) end
  return
 elseif kind==Proto.INPUT and self.role==Proto.HOST and self.phase=='connected' then
  local seq,current=Proto.readInput(a,b,c)
  if not self.remoteSeq or seq>self.remoteSeq or self.remoteSeq-seq>1000000 then
   self.remoteSeq=seq
   self.remote=Proto.decodeState(current)
   self.remoteAt=now
  end
 elseif kind==Proto.PING then
  self:send(Proto.PONG,a,0,0,false)
 elseif kind==Proto.PONG then
  local sent=a/1e6
  if now>=sent then self.rtt=now-sent end
 elseif kind==Proto.BYE then
  self:disconnect(a==1 and self:tr('Versión del mod distinta a la de %s',self.peerName or '?')
   or self:tr('%s se ha desconectado',self.peerName or '?'))
 end
end

function M:guestInput(fg)
 if not fg then return nil end
 if self.pad then
  for slot=0,3 do
   local sample=M.padInput(self.pad(slot))
   if sample then return sample end
  end
 end
 return self.sample and self.sample() or nil
end

-- Una vez por fotograma del bucle principal (hilo del juego).
function M:update()
 if not self.net or not self.peer then return end
 local now=self:now()
 for _=1,64 do
  local ok,kind,a,b,c=pcall(self.net.receive)
  if not ok then self.log('Recepción en línea fallida: '..tostring(kind)); break end
  if not kind then break end
  self:handle(kind,a,b,c,now)
  if not self.peer then return end
 end
 if self.phase=='waiting' or self.phase=='lost' then
  if not self.helloAt or now-self.helloAt>=HELLO_EVERY then
   self.helloAt=now
   self:send(Proto.HELLO,Proto.PROTOCOL,self.versionCode,self.role,true)
  end
  return
 end
 if self.phase~='connected' then return end
 if self.seenAt and now-self.seenAt>LOST_AFTER then
  self.phase='lost'
  self.remote=nil
  self:notice(self:tr('Conexión perdida con %s. Reintentando…',self.peerName or '?'))
  return
 end
 if not self.pingAt or now-self.pingAt>=PING_EVERY then
  self.pingAt=now
  self:send(Proto.PING,math.floor(now*1e6),0,0,false)
 end
 if self.role==Proto.GUEST then
  local state=Proto.encodeState(self:guestInput(self.foreground()))
  self.seq=self.seq+1
  self:send(Proto.inputMessage(self.seq,state,self.history))
  self.history=state
 end
end

-- Anfitrion conectado: entrada del invitado (neutra si se retrasa).
-- En cualquier otro caso nil, y main.lua usa los controles locales de P2.
function M:remoteInput()
 if self.role~=Proto.HOST or (self.phase~='connected' and self.phase~='lost') then return nil end
 if not self.remote or not self.remoteAt or self:now()-self.remoteAt>STALE_INPUT then return Proto.neutral() end
 return self.remote
end
function M:remoteAssist()
 local input=self:remoteInput()
 return input~=nil and input.assist==true
end

-- Teclas de la pagina F6 -> 1 -> 2. Devuelve 'back' para volver.
function M:menuTick(down)
 local pressed={}
 for i,key in ipairs(numberKeys) do
  local now=down(key)
  if now and not self.keysHeld[key] then pressed[i]=true end
  self.keysHeld[key]=now
 end
 local back=down('BackSpace')
 local backPressed=back and not self.keysHeld.BackSpace
 self.keysHeld.BackSpace=back
 if self.phase=='idle' then
  if pressed[1] then self:startPick(Proto.HOST) elseif pressed[2] then self:startPick(Proto.GUEST) end
  if backPressed then return 'back' end
 elseif self.phase=='pick' then
  for i=1,7 do if pressed[i] and self:choose(i) then return end end
  if pressed[8] then self:refresh() end
  if backPressed then self:reset() end
 else
  if pressed[8] then self:disconnect() end
  if backPressed then return 'back' end
 end
end

-- ui: text(t,dx,dy,size,faded), option(key,label,dy,disabled), footer().
function M:draw(ui)
 local t=function(...) return self:tr(...) end
 ui.text(t('Modalidad en línea'),0,74,1.25)
 if self.phase=='idle' then
  ui.option('1',t('Crear partida'),145)
  ui.text(t('Tu partida es la real; tu amigo controla a P2.'),44,184,.78,true)
  ui.option('2',t('Unirse a un amigo'),240)
  ui.text(t('Tus controles de P2 manejan a P2 en su partida.'),44,279,.78,true)
 elseif self.phase=='pick' then
  ui.text(t('Elige al amigo que juega contigo'),0,130,.95)
  ui.text(t('Amigos de Steam jugando a Little Nightmares II:'),0,170,.75,true)
  if #self.friends==0 then ui.text(t('Ningún amigo está jugando ahora.'),0,210,.85,true) end
  for i,friend in ipairs(self.friends) do ui.option(tostring(i),friend.name,200+(i-1)*44) end
  ui.text(t('[8] Actualizar lista'),0,520,.85)
 else
  local role=t(self.role==Proto.HOST and 'Anfitrión' or 'Invitado')
  local line
  if self.phase=='connected' then line=t('Conectado con %s',self.peerName or '?')
  elseif self.phase=='lost' then line=t('Conexión perdida con %s. Reintentando…',self.peerName or '?')
  else line=t('Esperando a %s…',self.peerName or '?') end
  ui.text(role,0,140,.95,true)
  ui.text(line,0,180,1)
  if self.rtt and self.phase=='connected' then ui.text(t('Ping %d ms',math.floor(self.rtt*1000+.5)),0,220,.8,true) end
  if self.phase=='waiting' then ui.text(t('Tu amigo también debe elegirte en F6 → 1 → 2.'),0,260,.75,true) end
  ui.text(t(self.role==Proto.HOST and 'Activa P2 con F7 para que tu amigo lo controle.'
   or 'Tu mando o tus teclas de P2 se envían al anfitrión.'),0,300,.75,true)
  ui.text(t('[8] Desconectar'),0,380,.95)
 end
 if self.message then ui.text(self.message,0,470,.72,true) end
 ui.text(t('Fase 1: todavía sin imagen; el invitado no ve la partida.'),0,560,.66,true)
 ui.footer()
end
return M
