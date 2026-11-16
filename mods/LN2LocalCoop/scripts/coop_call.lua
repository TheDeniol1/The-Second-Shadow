local Call={}
Call.__index=Call

function Call.new(live,same,log)
 return setmetatable({live=live,same=same,log=log,seen={}},Call)
end

function Call:gesture(pawn)
 if self.live(pawn) and self.live(pawn.GestureInterface) then return pawn.GestureInterface end
end

function Call:invoke(gesture,start)
 if not self.live(gesture) or not self.live(gesture.mFlowControlComponent) then return false end
 local ok,err=pcall(function()
  if start then gesture:TryStartGesturing() else gesture:StopGesturing() end
 end)
 if not ok and err~=self.lastError then self.log('Grito P2: '..tostring(err)) end
 self.lastError=not ok and err or nil
 return ok
end

function Call:release()
 if self.owned then self:invoke(self.owned,false);self.owned=nil end
end

function Call:input(pawn,pressed)
 local gesture=self:gesture(pawn)
 if self.owned and (not pressed or not self.same(self.owned,gesture)) then self:release() end
 if pressed and not self.pressed and self.live(gesture)
  and not gesture.mGestureData.mIsGesturing and self:invoke(gesture,true) then
  self.owned=gesture
 end
 self.pressed=not not pressed
end

function Call:observe(first,second)
 if not first or not second then self:release();self.seen[1],self.seen[2]=nil,nil;return end
 local role
 for index,pawn in ipairs({first,second}) do
  local gesture=self:gesture(pawn)
  local active=gesture and gesture.mGestureData.mIsGesturing
  if active then
   if not self.same(self.seen[index],gesture) then role=index end
   self.seen[index]=gesture
  else
   self.seen[index]=nil
  end
 end
 return role
end

return Call
