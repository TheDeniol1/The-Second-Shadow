-- One checkpoint reload per death, retaining local-player/controller ownership.
local D={};D.__index=D
function D.new(api)return setmetatable({api=api},D)end
function D:reset()self.pending=nil end
function D:confirmReload(first)
 if self.pending and not self.pending.confirmed and self.api.same(first,self.pending.first) then
  self.pending.confirmed=true
  return true
 end
end
function D:begin(pc,first,who,restart,lost)
 -- Latch before invoking engine callbacks: never reload once per polling frame.
 self.pending={first=first,sawDeath=not restart}
 self.api.begin(who,pc,lost)
 if restart then self.api.restart(pc,who) end
end
function D:lose(pc,first,who)
 if self.pending or not self.api.live(first) or not self.api.alive(first) then return false end
 self:begin(pc,first,who,true,true)
 return true
end
function D:update(pc,first,second)
 local api=self.api
 if self.pending then
  if not api.live(first) then return false end
  if not api.alive(first) then self.pending.sawDeath=true;return false end
  if not api.same(first,self.pending.first) or self.pending.sawDeath or self.pending.confirmed then
   self.pending=nil
   return true
  end
  return false
 end
 if not api.live(first) then return false end
 local who
 if not api.alive(first) then who='P1'
 elseif api.live(second) and api.sameWorld(first,second) and not api.alive(second) then who='P2' end
 if not who then return true end
 -- P1 already uses the game's normal death sequence. Only P2 needs a request.
 self:begin(pc,first,who,who=='P2')
 return false
end
return D
