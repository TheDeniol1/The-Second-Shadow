-- The Second Shadow · modo online. Protocolo puro, sin dependencias del juego,
-- para que las pruebas lo ejecuten tal cual. Cada mensaje es un tipo y tres
-- enteros (el transporte nativo no pasa cadenas binarias).
-- Todos los valores caben en 24 bits: las pruebas usan fengari, cuyos enteros
-- son de 32 bits, y el juego usa Lua 5.4 con enteros de 64.
local M={}
M.PROTOCOL=1
M.HELLO,M.INPUT,M.PING,M.PONG,M.BYE=1,2,3,4,5
M.HOST,M.GUEST=1,2
local order={'jump','grab','sneak','sprint','use','gadget','call','assist'}
M.buttons=order

-- Huella de la version: anfitrion e invitado deben llevar la misma.
function M.versionCode(text)
 local hash=7
 for i=1,#text do hash=(hash*31+text:byte(i))%16777213 end
 return hash
end

local function axis(value)
 value=tonumber(value) or 0
 if value~=value then value=0 end
 value=math.max(-1,math.min(1,value))
 return math.floor(value*127+(value>=0 and .5 or -.5)) & 0xff
end
local function unaxis(byte)
 if byte>=128 then byte=byte-256 end
 return math.max(-1,byte/127)
end

-- Un estado de mando en 24 bits: 8 botones, luego x e y con signo.
function M.encodeState(input)
 local bits=0
 if input then
  for i,name in ipairs(order) do if input[name] then bits=bits|(1<<(i-1)) end end
 end
 return bits|(axis(input and input.x)<<8)|(axis(input and input.y)<<16)
end
function M.decodeState(word)
 word=word & 0xffffff
 local input={x=unaxis((word>>8)&0xff),y=unaxis((word>>16)&0xff)}
 for i,name in ipairs(order) do input[name]=(word>>(i-1))&1==1 end
 return input
end
M.neutral=function() return M.decodeState(0) end

-- Mensaje de entrada: secuencia, estado actual y el anterior (sin fiabilidad,
-- para no acumular retraso; el anterior cubre un paquete perdido).
function M.inputMessage(seq,current,previous)
 return M.INPUT,seq,current&0xffffff,previous&0xffffff
end
function M.readInput(a,b,c)
 return a,b&0xffffff,c&0xffffff
end
return M
