local S={};S.__index=S
local warningTime,limit=8,13

function S.new(enabled)
 return setmetatable({enabled=enabled,elapsed=0,amount=0},S)
end

function S:reset()
 self.elapsed,self.amount=0,0
 self.player,self.side,self.last,self.first,self.second,self.fired=nil,nil,nil,nil,nil,nil
 self.warning=false
end

function S:update(now,player,side,observed,first,second)
 self.warning=false
 if not self.enabled then self:reset();return end
 if not observed then self.last=nil;return end
 if self.first~=first or self.second~=second then self:reset();self.first,self.second=first,second end
 -- Skip time spent in pauses, scene transitions or long gaps between frames.
 local dt=self.last and math.max(0,math.min(.25,now-self.last)) or 0
 self.last=now
 if not player then
  self.elapsed,self.player,self.fired=0,nil,nil
  self.amount=math.max(0,self.amount-dt*2.5)
  return
 end
 if self.player~=player then
  self.player,self.elapsed,self.amount,self.fired=player,0,0,nil
 else
  self.elapsed=self.elapsed+dt
 end
 self.side=side
 if self.elapsed>=limit and not self.fired then self.fired=true;return player end
 self.warning=self.elapsed>=warningTime
 self.amount=self.warning and math.min(1,.12+.88*(self.elapsed-warningTime)/(limit-warningTime)) or 0
end

return S
