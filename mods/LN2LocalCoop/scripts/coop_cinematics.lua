-- Enter only on an observed animation edge; never restart a scene halfway.
local M={};M.__index=M
function M.new(api)return setmetatable({api=api},M)end
function M:reset()
 local active=self.active
 self.active=nil;self.previous=nil
 if active then self.api.finish(active)end
end
function M:update(s)
 local api=self.api
 if not s then self:reset();return false end
 if self.active then
  local a=self.active
  if s.first~=a.first or s.second~=a.second or not s.ready or s.key~=a.key
   or s.now<a.since or s.now-a.since>a.duration+2 then
   self.active=nil;api.finish(a)
  end
 end
 if s.paused then return self.active~=nil end
 local old=self.previous
 self.previous={first=s.first,second=s.second,key=s.key,now=s.now,ready=s.ready}
 if self.active then
  if api.tick and api.tick(self.active,s)==false then
   local a=self.active;self.active=nil;api.finish(a);return false
  end
  return true
 end
 -- A fresh player, resumed load, or long frame gap cannot establish onset.
 if not s.ready or not s.key or not old or not old.ready
  or old.first~=s.first or old.second~=s.second or old.key==s.key
  or s.now<old.now or s.now-old.now>0.25 then return false end
 local active=api.start(s)
 if active then
  active.first=s.first;active.second=s.second;active.key=s.key
  active.since=s.now;self.active=active
 end
 return active~=nil
end
return M
