-- Modo online, fase 1: protocolo y sesion con un transporte falso de dos extremos.
package.path='mods/LN2LocalCoop/scripts/?.lua;'..package.path
local Proto=require('online_protocol')
local Online=require('coop_online')
local function check(cond,message) if not cond then error(message,2) end end

-- Codificacion de estados.
local input={x=1,y=-1,jump=true,grab=false,sneak=true,sprint=false,use=true,gadget=false,call=true,assist=true}
local decoded=Proto.decodeState(Proto.encodeState(input))
check(decoded.x==1 and decoded.y==-1,'ejes extremos')
for _,name in ipairs(Proto.buttons) do check(decoded[name]==(input[name]==true),'boton '..name) end
local half=Proto.decodeState(Proto.encodeState({x=.5,y=-.25}))
check(math.abs(half.x-.5)<.01 and math.abs(half.y+.25)<.01,'ejes intermedios')
local wild=Proto.decodeState(Proto.encodeState({x=0/0,y=7}))
check(wild.x==0 and wild.y==1,'ejes no validos se limitan')
local neutral=Proto.decodeState(Proto.encodeState(nil))
check(neutral.x==0 and not neutral.jump,'entrada vacia es neutra')
local kind,a,b,c=Proto.inputMessage(9,0xffffff,0x800001)
local seq,current,previous=Proto.readInput(a,b,c)
check(kind==Proto.INPUT and seq==9 and current==0xffffff and previous==0x800001,'historial de entrada')
check(Proto.versionCode('v0.8.0-dev.22')<16777216,'huella de version en 24 bits')
check(Proto.versionCode('v0.8.0-dev.22')~=Proto.versionCode('v0.8.0-dev.23'),'versiones distintas')

-- Red falsa: dos extremos con colas y reloj compartido.
local clock=0
local function network()
 local ends={}
 for i,id in ipairs({1001,2002}) do
  ends[i]={id=id,queue={},peer=0,open=true,lost=false}
 end
 local function api(me,other,friends)
  return {
   steam_open=function() if not me.open then return false,'sin Steam' end return me.id end,
   friends_scan=function() return #friends end,
   friend=function(i) local f=friends[i]; if f then return f.id,f.name end end,
   set_peer=function(id) me.peer=id; return true end,
   send=function(kind,a,b,c,reliable)
    if me.peer==0 then return false end
    if me.peer==other.id and other.peer==me.id and not me.lost then
     table.insert(other.queue,{kind,a,b,c})
    end
    return true,1
   end,
   receive=function()
    local m=table.remove(me.queue,1)
    if m then return m[1],m[2],m[3],m[4] end
   end,
   clock_us=function() return math.floor(clock*1e6) end,
  }
 end
 local hostNet=api(ends[1],ends[2],{{id=2002,name='Invitado'}})
 local guestNet=api(ends[2],ends[1],{{id=3003,name='Otro'},{id=1001,name='Anfitrion'}})
 return ends,hostNet,guestNet
end
local ends,hostNet,guestNet=network()
local logs={}
local keyboard={x=0,y=1,jump=true}
local fg=true
local host=Online.new({net=hostNet,version='v1',log=function(s) logs[#logs+1]=s end})
local guest=Online.new({net=guestNet,version='v1',log=function() end,sample=function() return keyboard end,
 foreground=function() return fg end})
local function step(n) for _=1,n or 1 do clock=clock+.016; host:update(); guest:update() end end

check(host:remoteInput()==nil,'sin sesion se usan los controles locales')
-- Navegacion por teclas: 1 crear, luego 1 elegir amigo.
local held={}
local function press(session,key) held[key]=true; session:menuTick(function(k) return held[k] end); held[key]=false; session:menuTick(function(k) return held[k] end) end
press(host,'One'); check(host.phase=='pick' and #host.friends==1,'lista de amigos del anfitrion')
press(host,'One'); check(host.phase=='waiting' and host.peer==2002,'anfitrion espera al invitado')
step(5); check(host.phase=='waiting','sin respuesta sigue esperando')
press(guest,'Two'); press(guest,'Two'); check(guest.phase=='waiting' and guest.peer==1001,'el invitado elige al anfitrion')
step(80)
check(host:connected() and guest:connected(),'ambos conectados')
check(host.rtt~=nil and guest.rtt~=nil,'ping medido')
local remote=host:remoteInput()
check(remote and remote.y==1 and remote.jump and remote.x==0,'el anfitrion recibe la entrada del invitado')
-- Mando del invitado con prioridad sobre el teclado.
guest.pad=function(slot) if slot==1 then return 32767,0,0x0100,0,255 end end
step(2)
remote=host:remoteInput()
check(remote.x>.99 and remote.grab and remote.assist and not remote.jump,'mando del invitado')
check(host:remoteAssist(),'la mano del invitado llega al anfitrion')
guest.pad=nil
-- Sin foco, el invitado envia una entrada neutra.
fg=false; step(2); remote=host:remoteInput()
check(remote.x==0 and remote.y==0 and not remote.jump,'invitado sin foco')
fg=true
-- Paquetes perdidos: entrada neutra tras el limite y conexion perdida mas tarde.
ends[2].lost=true
step(30); remote=host:remoteInput()
check(remote and remote.y==0 and not remote.jump,'entrada antigua pasa a neutra')
step(400); check(host.phase=='lost','conexion perdida')
check(host:remoteInput()~=nil,'en conexion perdida P2 queda quieto, no pasa al teclado local')
ends[2].lost=false
step(120); check(host:connected(),'reconexion')
check(host:remoteInput().jump,'entrada de nuevo tras reconectar')
-- Desconexion del invitado.
press(guest,'Eight'); step(3)
check(guest.phase=='idle' and host.phase=='idle' and host:remoteInput()==nil,'despedida cierra ambos lados')
-- Versiones distintas.
ends,hostNet,guestNet=network()
host=Online.new({net=hostNet,version='v1',log=function() end})
guest=Online.new({net=guestNet,version='v2',log=function() end,sample=function() return keyboard end})
host:startPick(Proto.HOST); host:choose(1); guest:startPick(Proto.GUEST); guest:choose(2)
step(80)
check(not host:connected() and host.phase=='idle' and host.message and host.message:find('distinta'),'version distinta rechazada')
-- Steam no disponible.
ends[1].open=false
host=Online.new({net=hostNet,version='v1',log=function() end})
check(not host:startPick(Proto.HOST) and host.message:find('Steam'),'sin red de Steam')
-- Sin adaptador.
local missing=Online.new({root='/no/existe/',version='v1',log=function() end})
check(not missing:startPick(Proto.HOST),'sin DLL en linea')
-- Dibujo en ingles y espanol sin errores.
local drawn={}
local ui={text=function(t) drawn[#drawn+1]=t end,option=function(_,label) drawn[#drawn+1]=label end,footer=function() end}
for _,lang in ipairs({'es','en'}) do
 local s=Online.new({net=hostNet,version='v1',log=function() end,language=function() return lang end})
 s:draw(ui); s.phase,s.friends='pick',{{id=1,name='A'}}; s:draw(ui)
 s.phase,s.role,s.peerName,s.rtt='connected',Proto.HOST,'A',.042; s:draw(ui)
end
local joined=table.concat(drawn,'\n')
check(joined:find('Ping 42 ms',1,true) and joined:find('Host a game',1,true),'pagina en linea dibujada')
print('PASS: modo online (protocolo, sesion, mando, foco, perdida, reconexion, versiones, menu).')
