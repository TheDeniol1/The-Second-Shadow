-- Translate held buttons into the game's chalkboard actions. Keep each button
-- independent so jump + grab can be held together.
local M={}; M.__index=M
function M.new(api) return setmetatable({api=api,keys={},held={}},M) end
function M:update(animator,input)
 for _,name in ipairs({'Jump','Grab','Sprint'}) do
  local pressed=input[({Jump='jump',Grab='grab',Sprint='sprint'})[name]] or false
  if not self.keys[name] then self.keys[name]=self.api.key(name) end
  local nativeJump=name=='Jump' and self.api.jump and self.api.jump(pressed,self.held[name])
  if not nativeJump then
   if pressed then
    if not self.held[name] then self.api.start(animator,self.keys[name]) end
    self.api.hold(animator,self.keys[name])
   elseif self.held[name] then self.api.stop(animator,self.keys[name]) end
  end
  self.held[name]=pressed
 end
 local crouch=input.sneak or false
 if self.api.crouch then self.api.crouch(animator,crouch)
 elseif self.api.locomotion and self.held.crouch~=crouch then self.api.locomotion(animator,crouch) end
 self.held.crouch=crouch
 local use=input.use or false
 if self.api.use and self.held.use~=use then self.api.use(animator,use) end
 self.held.use=use
 local gadget=input.gadget or false
 if self.api.gadget and self.held.gadget~=gadget then self.api.gadget(gadget) end
 self.held.gadget=gadget
end
function M:release(animator)
 for name,pressed in pairs(self.held) do
  if pressed and animator then
   if name=='crouch' then
    if self.api.crouch then self.api.crouch(animator,false)
    elseif self.api.locomotion then self.api.locomotion(animator,false) end
   elseif name=='use' then
    if self.api.use then self.api.use(animator,false) end
   elseif name=='gadget' then
    if self.api.gadget then self.api.gadget(false) end
   elseif name~='Jump' or not self.api.jump or not self.api.jump(false,true) then
    self.api.stop(animator,self.keys[name])
   end
  end
 end
 self.held={}
end
return M
