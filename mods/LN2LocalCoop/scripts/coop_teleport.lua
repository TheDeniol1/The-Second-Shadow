-- Instant relocation after all checks; invalid requests never queue for later.
local T={};T.__index=T
function T.new(api)return setmetatable({api=api,held={},notice='',noticeUntil=0,nextAt=0},T)end
function T:now()
 local now=self.api.clock()
 if self.lastNow and now<self.lastNow then self.nextAt=0;self.noticeUntil=0;self.notice=''end
 self.lastNow=now;return now
end
function T:message(text,now)
 self.notice=text;self.noticeUntil=now+3
 self.api.log(text)
end
function T:request(direction)
 local api=self.api;local now=self:now()
 if direction~='toP1'and direction~='toP2'then return false end
 if now<self.nextAt then return false end
 local ok,result,reason=pcall(function()
  local first,second,why=api.players()
  if not first then return false,why end
  for _,pawn in ipairs({first,second})do
   local blocked=api.blocked(pawn)
   if blocked then return false,blocked end
  end
  local mover,target=second,first
  if direction=='toP2'then mover,target=first,second end
  local at=api.location(target)
  local destination={X=at.X,Y=at.Y,Z=at.Z+25}
  if not api.clear(mover,target,destination)then return false,'No hay espacio libre en el destino'end
  local origin=api.location(mover)
  if not api.move(mover,destination)then return false,'No se pudo reunir a los jugadores. Inténtalo de nuevo.'end
  -- Cosmetic failures do not undo a successful move or disable co-op.
  local fxOk,fxError=pcall(api.effects,mover,origin,destination,now)
  if not fxOk then api.log('Efecto No pueden reunirse en este momento: '..tostring(fxError))end
  return true
 end)
 if not ok then
  api.log('TP cancelado: '..tostring(result));self:message('No pueden reunirse en este momento',now);return false
 end
 if not result then self:message(reason or 'No pueden reunirse en este momento',now);return false end
 self.nextAt=now+1
 self:message(direction=='toP1'and 'El jugador 2 se reunió con el jugador 1'or 'El jugador 1 se reunió con el jugador 2',now)
 return true
end
function T:poll(down,bindings,allowed)
 local a,b=down(bindings.toP1),down(bindings.toP2)
 local ea,eb=a and not self.held.a,b and not self.held.b
 self.held.a,self.held.b=a,b
 if allowed and not(a and b)then
  if ea then self:request('toP1')elseif eb then self:request('toP2')end
 end
 if self:now()>=self.noticeUntil then self.notice=''end
end
return T
