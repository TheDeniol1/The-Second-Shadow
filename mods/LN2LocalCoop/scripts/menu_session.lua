local Session={}
Session.__index=Session

function Session.new(statics,input,live,same)
 return setmetatable({statics=statics,input=input,live=live,same=same},Session)
end

function Session:close()
 local validController=self.live(self.pc)
 local sameWorld=validController and self.same(self.pc:GetWorld(),self.world)
 if self.paused and self.live(self.world) then self.statics():SetGamePaused(sameWorld and self.pc or self.world,false) end
 if validController then
  if self.changedInput and sameWorld then
   local input=self.input()
   input:SetInputMode_GameOnly(self.pc)
   input:SetFocusToGameViewport()
  end
  self.pc.bShowMouseCursor=self.cursor
 end
 self.pc,self.world,self.cursor,self.paused,self.changedInput=nil,nil,nil,nil,nil
end

function Session:update(pc,open,playing)
 if not open or not self.live(pc) then
  if self.pc then self:close() end
  return
 end
 local world=pc:GetWorld()
 if not self.live(world) then
  if self.pc then self:close() end
  return
 end
 if not (self.same(pc,self.pc) and self.same(world,self.world)) then
  if self.pc then self:close() end
  self.pc,self.world,self.cursor=pc,world,pc.bShowMouseCursor==true
 end
 if not pc.bShowMouseCursor then pc.bShowMouseCursor=true end
 if playing then
  local statics=self.statics()
  if not statics:IsGamePaused(pc) then
   self.paused=statics:SetGamePaused(pc,true) or self.paused
   if not self.changedInput then
    self.changedInput=true
    self.input():SetInputMode_GameAndUIEx(pc,nil,0,false)
   end
  end
 end
end

return Session
