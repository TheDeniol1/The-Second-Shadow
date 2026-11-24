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
 return setmetatable({read=read, mapsSettings=mapsSettings, owner=(owner==2 or owner==3) and owner or 1,
  log=log, nextScan=0, devices={}}, Pad)
end

function Pad:restore()
 if self.originalOffset ~= nil then
  self.mapsSettings().bOffsetPlayerGamepadIds = self.originalOffset
  self.originalOffset = nil
 end
 self.routed,self.primarySlot,self.secondSlot=nil,nil,nil
 self.pendingRoute,self.neutralSince=nil,nil
end

local function readDevice(read,slot)
 local x,y,buttons,left,right,cameraX,cameraY=read(slot)
 if x==nil then return end
 local moveX, moveY = stick(x, y)
 return {
  x=moveX, y=moveY, jump=(buttons & 0x1000)~=0,
  sprint=(buttons & 0x4000)~=0, use=(buttons & 0x8000)~=0, gadget=(buttons & 0x2000)~=0,
  sneak=left>30, grab=right>30, assist=(buttons & 0x0100)~=0, call=(buttons & 0x0001)~=0,
  neutral=moveX==0 and moveY==0 and buttons==0 and left<=30 and right<=30
   and cameraX*cameraX+cameraY*cameraY<=8689*8689,
 }
end

local function firstConnected(devices,from)
 for slot=from,3 do if devices[slot] then return slot end end
end

function Pad:poll(now)
 local discover=now>=self.nextScan
 if discover then self.nextScan=now+.5 end
 local devices=self.devices
 for slot=0,3 do
  local old=devices[slot]
  if discover or old then
   local sample=readDevice(self.read,slot)
   devices[slot]=sample
   if (sample~=nil)~=(old~=nil) then
    self.log((sample and 'Mando XInput detectado, canal ' or 'Mando XInput desconectado, canal ')..(slot+1))
   end
  end
 end
 if not devices[self.slot] then self.slot=firstConnected(devices,0) end
 if not devices[self.primarySlot] then self.primarySlot=nil end
 if not devices[self.secondSlot] then self.secondSlot=nil end
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

 local primary,secondary,offset
 local devices=self.devices
 if self.owner==3 then
  primary=devices[0] and 0 or nil
  if hasSecond then
   secondary=(self.secondSlot and self.secondSlot>0 and self.secondSlot) or firstConnected(devices,1)
  end
  offset=false
 else
  offset=self.owner==2 and not not hasSecond
  if offset then secondary=self.slot else primary=self.slot end
 end
 if not hasSecond then self.secondSlot=nil end
 if self.routed==offset and self.primarySlot==primary and self.secondSlot==secondary then
  self.pendingRoute,self.neutralSince=nil,nil
  return
 end
 local pending=self.pendingRoute
 if not pending or pending.primary~=primary or pending.second~=secondary or pending.offset~=offset then
  self.pendingRoute={primary=primary,second=secondary,offset=offset}
  self.neutralSince=nil
 end
 local oldFirst,oldSecond=devices[self.primarySlot],devices[self.secondSlot]
 local newFirst,newSecond=devices[primary],devices[secondary]
 local primaryChanges=self.routed~=offset or self.primarySlot~=primary
 local secondChanges=self.routed~=offset or self.secondSlot~=secondary
 -- Wait only for the affected pads, so reconnecting P2 does not interrupt P1.
 if (primaryChanges and ((oldFirst and not oldFirst.neutral) or (newFirst and not newFirst.neutral)))
  or (secondChanges and ((oldSecond and not oldSecond.neutral) or (newSecond and not newSecond.neutral))) then
  self.neutralSince = nil
  return
 end
 self.neutralSince = self.neutralSince or now
 if (oldFirst or oldSecond or newFirst or newSecond) and now-self.neutralSince<.1 then return end

 local settings = self.mapsSettings()
 if self.originalOffset == nil then self.originalOffset = settings.bOffsetPlayerGamepadIds end
 settings.bOffsetPlayerGamepadIds=offset
 self.routed,self.primarySlot,self.secondSlot=offset,primary,secondary
 self.pendingRoute,self.neutralSince=nil,nil
 if primary or secondary then
  self.log('Mandos: P1='..(primary and (primary+1) or 'teclado')..' P2='..(secondary and (secondary+1) or 'teclado'))
 end
end

function Pad:forRole(role)
 if role==1 then return self.devices[self.primarySlot] end
 return self.devices[self.secondSlot]
end

function Pad:input()
 local sample=self:forRole(2)
 if not sample then return nil end
 if not self.foreground then return {x=0,y=0} end
 return sample
end

return Pad
