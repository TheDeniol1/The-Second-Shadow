-- Read-only Hunter weapon events and an optional F8 snapshot.
local T={};T.__index=T

function T.new(c)
 return setmetatable({c=c,errors={}},T)
end

function T:emit(message)
 self.c.log('[HunterTrace] '..message)
end

function T:guard(label,fn)
 local ok,err=pcall(fn)
 if not ok and not self.errors[label] then
  self.errors[label]=true
  self:emit(label..': '..tostring(err))
 end
end

local function position(at)
 return string.format('(%.1f, %.1f, %.1f)',at.X,at.Y,at.Z)
end

function T:controllerInWilderness()
 local c=self.c
 local pc=c.p1()
 if c.live(pc)and c.live(pc.Pawn)
  and pc.Pawn:GetFullName():find('/Game/Levels/Wilderness/',1,true)then return pc end
end

function T:describe(actor,pc)
 local c=self.c
 if not c.live(actor)then return '-' end
 local role=c.same(actor,pc.Pawn)and 'P1 ' or (c.same(actor,c.driver.pawn)and 'P2 ' or '')
 return role..actor:GetFullName()
end

function T:shot(pc,hit)
 return 'bloqueo='..tostring(hit.bBlockingHit)..' actor='..self:describe(hit.Actor:Get(),pc)
  ..' origen='..position(hit.TraceStart)..' destino='..position(hit.TraceEnd)
  ..' impacto='..position(hit.ImpactPoint)
end

function T:mode()
 local state=self.c.state
 return string.format('P2=%s modo=%d dividida=%s',tostring(state.enabled),state.cameraMode,tostring(state.split))
end

function T:install()
 local c=self.c
 local firearm='/Script/Helios.FirearmComponent:'
 for _,event in ipairs({'Shoot','ShootAutoHit','OnShotReachedAutoHit'})do
  self:guard('registro '..event,function()
   RegisterHook(firearm..event,function(ctx,target)
    self:guard('lectura '..event,function()
     local pc=self:controllerInWilderness()
     if not pc then return end
     local weapon=ctx:get()
     if not c.live(weapon)then return end
     local owner=weapon:GetOwner()
     if not c.live(owner)or not c.world(owner,pc)then return end
     local actor=event~='Shoot'and target:get()or nil
     self:emit(event..' '..self:mode()..' arma='..weapon:GetFullName()..' objetivo='..self:describe(actor,pc))
     if event=='OnShotReachedAutoHit'then return end
     for index,pawn in pairs({[1]=pc.Pawn,[2]=c.driver.pawn})do
      if c.live(pawn)and c.world(pawn,pc)then
       local at=pawn:K2_GetActorLocation()
       self:emit('P'..index..' posicion='..position(at)
        ..' capsula='..tostring(pawn.CapsuleComponent:GetScaledCapsuleHalfHeight())
        ..' lineaDeTiroAlCentro='..tostring(weapon:HasClearLineOfFireTo(at,0)))
      end
     end
    end)
   end)
  end)
 end
 self:guard('registro de impacto',function()
  RegisterHook('/Script/Helios.HunterTerminatorPattern:OnShotReached',function(_,initialHit,currentHit)
   self:guard('lectura de impacto',function()
    local pc=self:controllerInWilderness()
    if pc then
     self:emit('Impacto '..self:mode()..' | inicial '..self:shot(pc,initialHit:get())
      ..' | final '..self:shot(pc,currentHit:get()))
    end
   end)
  end)
 end)
end

function T:mark()
 local c=self.c
 local pc=self:controllerInWilderness()
 if not pc then return end
 self:emit('MARCA F8 '..self:mode())
 for index,pawn in pairs({[1]=pc.Pawn,[2]=c.driver.pawn})do
  if c.live(pawn)then
   self:guard('lectura de P'..index,function()
    self:emit('P'..index..' posicion='..position(pawn:K2_GetActorLocation())
     ..' tipo='..tostring(pawn:GetPawnType())..' capsula='..tostring(pawn.CapsuleComponent:GetScaledCapsuleHalfHeight()))
   end)
  end
 end
 self:guard('lectura de sensores',function()
  for _,component in ipairs(FindAllOf('SensoryComponent')or {})do
   if c.live(component)then
    local owner=component:GetOwner()
    if c.live(owner)and c.world(owner,pc)and owner:GetFullName():lower():find('hunter',1,true)then
     self:emit(owner:GetFullName()..' posicion='..position(owner:K2_GetActorLocation()))
     for i=1,#component.mSensors do
      local sensor=component.mSensors[i]
      if c.live(sensor)then
       self:emit(sensor:GetFullName()..' activo='..tostring(sensor.mEnabled)
        ..' estimulo='..tostring(sensor.mStimulusSource))
      end
     end
    end
   end
  end
 end)
end

return T
