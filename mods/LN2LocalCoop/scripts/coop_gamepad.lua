-- P1 uses Unreal's native controller input. P2 uses the existing Mono driver.
local Pad = {}
Pad.__index = Pad

local function stick(x, y)
 local magnitude = math.sqrt(x*x + y*y)
 local deadzone = 7849
 if magnitude <= deadzone then return 0, 0 end
 local strength = (math.min(magnitude, 32767) - deadzone) / (32767 - deadzone)
 return strength*x/magnitude, strength*y/magnitude
end

function Pad.new(read, mapsSettings, owner, log)
 return setmetatable({read=read, mapsSettings=mapsSettings, owner=owner==2 and 2 or 1,
  log=log, nextScan=0}, Pad)
end

function Pad:restore()
 if self.originalOffset ~= nil then
  self.mapsSettings().bOffsetPlayerGamepadIds = self.originalOffset
  self.originalOffset = nil
 end
 self.routed = nil
 self.neutralSince = nil
end

function Pad:poll(now)
 local x, y, buttons, left, right, cameraX, cameraY
 if self.slot ~= nil then
  x,y,buttons,left,right,cameraX,cameraY = self.read(self.slot)
  if x == nil then
   self.slot = nil
   self.nextScan = now + 0.5
   self.log('Mando XInput desconectado')
  end
 elseif now >= self.nextScan then
  self.nextScan = now + 0.5
  for slot = 0, 3 do
   x,y,buttons,left,right,cameraX,cameraY = self.read(slot)
   if x ~= nil then
    self.slot = slot
    self.log('Mando XInput detectado, canal '..(slot+1))
    break
   end
  end
 end
 if x == nil then
  self.sample = nil
  self.neutral = true
  return
 end
 local moveX, moveY = stick(x, y)
 self.sample = {
  x=moveX, y=moveY, jump=(buttons & 0x1000)~=0,
  sprint=(buttons & 0x4000)~=0, use=(buttons & 0x8000)~=0, gadget=(buttons & 0x2000)~=0,
  sneak=left>30, grab=right>30, assist=(buttons & 0x0100)~=0, call=(buttons & 0x0001)~=0,
 }
 self.neutral = moveX==0 and moveY==0 and buttons==0 and left<=30 and right<=30
  and cameraX*cameraX+cameraY*cameraY<=8689*8689
end

function Pad:update(now, inCoop, hasSecond, foreground)
 if not self.read then return end
 if self.lastTime and now < self.lastTime then
  self.nextScan = 0
  self.neutralSince = nil
 end
 self.lastTime = now
 self.foreground = foreground
 self:poll(now)
 if not inCoop then
  self:restore()
  return
 end

 local routeToP2 = self.owner==2 and hasSecond
 if self.routed == routeToP2 then
  self.neutralSince = nil
  return
 end
 -- Give P1's original input time to receive releases before changing routing.
 if not self.neutral then
  self.neutralSince = nil
  return
 end
 self.neutralSince = self.neutralSince or now
 if self.sample and now-self.neutralSince < 0.1 then return end

 local settings = self.mapsSettings()
 if self.originalOffset == nil then self.originalOffset = settings.bOffsetPlayerGamepadIds end
 settings.bOffsetPlayerGamepadIds = routeToP2
 self.routed = routeToP2
 self.neutralSince = nil
 self.log('Mando asignado a P'..(routeToP2 and '2' or '1'))
end

function Pad:input()
 if not self.routed or not self.sample then return nil end
 if not self.foreground then return {x=0,y=0} end
 return self.sample
end

return Pad
