-- Restore viewport gameplay input once after a stable replacement pawn appears.
-- Never keep forcing focus while the player is using a menu or a cutscene.
local M={};M.__index=M
function M.new(api)return setmetatable({api=api},M)end
function M:invalidate()
 if self.seen then self.interrupted=true end
end
function M:update(pc,allowed)
 local api=self.api
 if not api.live(pc) or not api.live(pc.Pawn) then self:invalidate();return false end
 local now=api.clock(pc)
 local world=api.world and api.world(pc)
 if self.interrupted or world~=self.world or not api.same(pc,self.pc) or not api.same(pc.Pawn,self.pawn) then
  self.pending=self.seen or false
  self.seen=true;self.pc=pc;self.pawn=pc.Pawn;self.world=world;self.readyAt=now+1
  self.interrupted,self.focused=nil,nil
 end
 if self.pending and allowed and now>=self.readyAt and api.intent(pc) then
  local restored=api.restore(pc,not self.focused)
  self.focused=true
  if restored==false then self.readyAt=now+.4;return false end
  self.pending=false
  return true
 end
 return false
end
return M
