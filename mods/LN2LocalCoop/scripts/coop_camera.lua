local C={};C.__index=C
local maxZoom=math.tan(math.rad(40))/math.tan(math.rad(30))-1
local openAt,closeAt=.83,.73

function C.new(api,live,log)
 return setmetatable({api=api,live=live,log=log,amount=0},C)
end

function C:start(split)
 self.split=split
 if not self.api or not self.api.camera_tracks then return end
 if split and not self.api.split_camera_scan then return end
 local class=StaticFindObject('/Script/CameraSystemRuntime.DollhouseCameraActor')
 if not self.live(class) then return end
 local ok,err=pcall(self.api.shared_camera,split and 2 or 1,class:GetAddress())
 self.active=ok
 if not ok then self.log('Camara compartida: '..tostring(err)) end
end

function C:clear()
 if self.amount>0 then self.api.camera_zoom(0,0,0) end
 self.amount,self.open,self.last=0,false,nil
end

function C:stop()
 if self.api and self.api.camera_fill then self.api.camera_fill(0) end
 if self.active then self.api.shared_camera(0) end
 self.active,self.actor,self.otherActor,self.track,self.blend,self.scanAt=nil,nil,nil,nil,nil,nil
 self.amount,self.open,self.last=0,false,nil
 self.split,self.splitScanAt,self.splitReady=nil,nil,nil
end

function C:syncSplit(now,pc,fill)
 if not self.split then self:start(true) end
 if not self.active then return end
 if self.api.camera_fill then self.api.camera_fill(fill and 1 or 0) end
 if self.splitScanAt and now>=self.splitScanAt and now-self.splitScanAt<.5 then return end
 self.splitScanAt=now
 self.blendClass=self.blendClass or StaticFindObject('/Script/CameraSystemRuntime.CameraBlendVolume')
 if not self.live(self.blendClass) then self.blendClass=nil;return end
 local count=self.api.split_camera_scan(pc:GetWorld():GetAddress(),self.blendClass:GetAddress())
 if count and count>0 and not self.splitReady then
  self.splitReady=true
  self.log('Transiciones de pantalla dividida: '..count..' camaras registradas')
 end
end

function C:cameraActors(track,blend,now)
 if track~=self.track or blend~=self.blend then
  local function wasTracked(address)
   return address and (address==self.track or address==self.blend)
  end
  if not (wasTracked(track) or wasTracked(blend)) then self:clear() end
  local cached={}
  if self.track then cached[self.track]=self.actor end
  if self.blend then cached[self.blend]=self.otherActor end
  self.track,self.blend,self.scanAt=track,blend,nil
  self.actor,self.otherActor=cached[track],blend and cached[blend]
 end
 if not (self.live(self.actor) and (not blend or self.live(self.otherActor))) and
    (not self.scanAt or now<self.scanAt or now-self.scanAt>=.5) then
  self.scanAt=now
  for _,actor in pairs(FindAllOf('DollhouseCameraActor') or {}) do
   if self.live(actor) then
    local address=actor:GetAddress()
    if address==track then self.actor=actor end
    if address==blend then self.otherActor=actor end
   end
  end
 end
 return self.live(self.actor) and (not blend or self.live(self.otherActor))
end

function C:playersInVolume(actor,first,second)
 local playerVolume=actor.mEditablePlayerVolume
 if not self.live(playerVolume) then playerVolume=actor.mPlayerVolume end
 if not self.live(playerVolume) then return false,false end
 self.mathLib=self.mathLib or StaticFindObject('/Script/Engine.Default__KismetMathLibrary')
 if not self.live(self.mathLib) then self.mathLib=nil;return false,false end
 local bounds=playerVolume:GetUnscaledBoxExtent()
 local transform=playerVolume:K2_GetComponentToWorld()
 local function inside(point)
  local p=self.mathLib:InverseTransformLocation(transform,point)
  return math.abs(p.X)<bounds.X and math.abs(p.Y)<bounds.Y and math.abs(p.Z)<bounds.Z
 end
 return inside(first),inside(second)
end

function C:frame(now,view)
 if not view or not view.edge then self:clear();return end
 local track,applied,blend=self.api.camera_tracks()
 if not track then self:clear();return end
 -- Measure against the original lens so opening it cannot undo its own trigger.
 local edge=view.edge*(1+applied/10000)
 if self.amount==0 and edge<openAt then self.open=false;return end
 if not self:cameraActors(track,blend,now) then self:clear();return end
 local first,second=self:playersInVolume(self.actor,view.firstLocation,view.secondLocation)
 if blend and not (first and second) then
  local otherFirst,otherSecond=self:playersInVolume(self.otherActor,view.firstLocation,view.secondLocation)
  first,second=first or otherFirst,second or otherSecond
 end
 if not (first and second) then self:clear();return end
 self.open=edge>=(self.open and closeAt or openAt)
 local target=self.open and maxZoom*math.min(1,math.max(0,(edge-.75)/.24)) or 0
 local dt=self.last and math.max(0,math.min(.05,now-self.last)) or 0
 self.last=now
 local amount=math.max(self.amount-dt*.36,math.min(self.amount+dt*.48,target))
 if amount>0 or self.amount>0 then self.api.camera_zoom(amount,track,blend or 0);self.amount=amount end
end

function C:update(now,view)
 if not self.active or self.split or self.failed then return end
 local ok,err=pcall(self.frame,self,now,view)
 if not ok then
  self:clear()
  self.failed=true
  self.log('Zoom cooperativo: '..tostring(err))
 end
end

return C
