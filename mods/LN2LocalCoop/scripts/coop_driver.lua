-- Keep Six's original controller; only own our scripted control order.
local D = {}; D.__index=D
function D.new(api) return setmetatable({api=api,uuid=18000},D) end
function D:release()
 if self.handle then self.api.stop(self.handle) end
 self.handle,self.order,self.pawn,self.command=nil,nil,nil,nil
end
function D:attach(pawn,context,direction,command)
 self:release(); self.uuid=self.uuid+1
 local handle,order=self.api.start(pawn,context,self.uuid,direction,command)
 if not self.api.live(order) then
  if handle then self.api.stop(handle) end
  error("El juego no devolvio una orden de control valida")
 end
 self.pawn,self.handle,self.order,self.command=pawn,handle,order,command
end
function D:update(direction,command)
 if not self.api.live(self.pawn) or not self.api.live(self.order) then return false end
 self.order.moveInput=direction; self.order.heldCommand=command
 return true
end
return D
