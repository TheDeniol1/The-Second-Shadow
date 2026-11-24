-- Ownership follows the LocalPlayer across controller replacement and travel.
local D={}; D.__index=D
function D.new(api) return setmetatable({api=api},D) end
function D:remove()
 if self.api.live(self.pawn) and not self.api.same(self.pawn,self.originalPawn) then self.api.stop(self.pawn) end
 local pc=self.pc
 if not self.api.live(pc) and self.api.live(self.player) and self.api.resolve then pc=self.api.resolve(self.player) end
 if self.api.live(pc) then
  -- Helios pops its global input context when a PlayerPawnController ends play,
  -- even when the extra local controller never registered an input context.
  -- Keep this controller alive; remove only its owned pawn.
  if not self.parked or (self.api.live(pc.Pawn) and not self.api.same(pc.Pawn,self.parkedPawn)) then self.api.park(pc) end
  self.pc=pc; self.pawn=nil; self.parked=true; self.parkedPawn=pc.Pawn; self.restartAt=nil
  return true
 elseif self.api.live(self.player) then
  -- A level transition may temporarily have no controller. Keep the identity
  -- until its replacement exists, so disable can finish cleanup later.
  self.pc,self.pawn=nil,nil
  return false
 end
 self.pc,self.pawn,self.player,self.restartAt,self.parked,self.parkedPawn=nil,nil,nil,nil,nil,nil
 return true
end
function D:ready(p1)
 local pawn=self.pc.Pawn
 if not self.api.live(pawn) then return false end
 assert(not self.api.same(pawn,p1.Pawn),'El motor reutilizo al primer Mono')
 assert(self.api.isMono(pawn),'El personaje creado no es Mono')
 if not self.api.same(self.pawn,pawn) then
  local placed
  if self.api.prepare then
   placed=self.api.prepare(self.pc,pawn,p1)
   if placed==false then return false end
  end
  if self.api.configure and self.api.configure(self.pc,pawn,p1)==false then return false end
  if not placed then self.api.rescue(pawn,p1)end
  self.pawn=pawn; self.originalPawn=p1.Pawn; self.restartAt=nil; self.parked=false; self.parkedPawn=nil
 end
 return true
end
function D:ensure(p1)
 if self.api.live(self.pc) and self.api.sameWorld(self.pc,p1) then
  if self:ready(p1) then return true end
  -- A possessed pawn may still be initializing. RestartPlayer is only for
  -- an actual absence, otherwise it can replace the pawn we are waiting for.
  if self.api.live(self.pc.Pawn) then return false end
  local now=self.api.clock and self.api.clock(p1) or 0
  if self.api.restart and (not self.restartAt or now>=self.restartAt) then
   self.restartAt=now+2
   self.api.restart(self.pc,p1)
   return self:ready(p1)
  end
  return false
 end
 local existing=self.api.existing(p1)
 if existing then
  local identity=self.api.identity and self.api.identity(existing)
  assert(self.api.live(existing) and self.api.live(self.player) and self.api.same(identity,self.player),
   'Ya existe otro jugador local; reinicia la partida')
  self.pc=existing; self.pawn=nil; self.restartAt=nil
  return self:ready(p1)
 end
 -- The owned LocalPlayer can outlive the old world while its new controller
 -- is still being constructed. Do not create a third local player.
 if self.api.live(self.player) then return false end
 self:remove()
 local pc=self.api.create(p1)
 assert(self.api.live(pc),'No se pudo crear el segundo jugador')
 assert(not self.api.same(pc,p1),'El motor devolvio al jugador 1')
 self.pc=pc; self.originalPawn=p1.Pawn
 if self.api.identity then self.player=self.api.identity(pc) end
 return self:ready(p1)
end
function D:stop()
 if self.api.live(self.pawn) then self.api.stop(self.pawn) end
end
function D:update(direction,input)
 if not self.api.live(self.pc) or not self.api.live(self.pawn) then return false end
 self.api.move(self.pawn,direction)
 self.api.actions(self.pawn,input)
 return true
end
return D
