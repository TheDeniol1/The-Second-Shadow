local Story={};Story.__index=Story
local paleCity='/Game/Levels/PaleCity/PLVL_PaleCIty.'
local school='/Game/Levels/School/PLVL_School.'
local hospital='/Game/Levels/Hospital/PLVL_Hospital.'
local flashlight={slot=1,label='linterna',chapter='Hospital'}
local remote={slot=3,label='mando del televisor',chapter='Ciudad Palida'}
local rooftop='/Game/Levels/PaleCity/SubLevels/LVL_4_490_RooftopTVPeople.LVL_4_490_RooftopTVPeople'
local ziplinePath=rooftop..':PersistentLevel.BP_Zipline2'
local cafeteria='/Game/Levels/School/SubLevels/LVL_2_280_Cafeteria'
local cafeteriaActors=cafeteria..'.LVL_2_280_Cafeteria:PersistentLevel.'

function Story.new(api)
 return setmetatable({api=api,errors={}},Story)
end

function Story:restoreZipline()
 local ride=self.zipline
 self.zipline=nil
 if ride and self.api.live(ride.actor) and ride.actor.bReturnToStart==true then
  ride.actor.bReturnToStart=ride.original
 end
end

local function nearStart(pawn,origin)
 local at=pawn:K2_GetActorLocation()
 return (at.X-origin.X)^2+(at.Y-origin.Y)^2<=600^2 and math.abs(at.Z-origin.Z)<=450
end

function Story:ziplineUpdate(first,second,now,paused)
 local api=self.api
 local ride=self.zipline
 if ride and not api.world(ride.actor,first) then self:restoreZipline();ride=nil end
 if not ride then
  if self.ziplineScan and now>=self.ziplineScan and now-self.ziplineScan<.3 then return end
  self.ziplineScan=now
  local actor=StaticFindObject(ziplinePath)
  if not api.world(actor,first) or type(actor.bReturnToStart)~='boolean' then return end
  ride={actor=actor,original=actor.bReturnToStart}
  self.zipline=ride
  actor.bReturnToStart=true
  api.log('Tirolina del tendedero: regreso habilitado para el cooperativo')
 end
 if paused then ride.stuckSince=nil;return end
 local actor=ride.actor
 local hangable=actor.hangable
 local p1Grip,p2Grip=first.PlayerHangableInterface,second.PlayerHangableInterface
 if actor.bGrabbed or actor:IsThisPieceBeingUsed()
  or (api.live(hangable) and ((api.live(p1Grip) and api.same(p1Grip.mGrabbedHangable,hangable))
   or (api.live(p2Grip) and api.same(p2Grip.mGrabbedHangable,hangable)))) then
  ride.stuckSince=nil
  return
 end
 local progress=actor:GetPieceProgress()
 if progress<.97 then ride.stuckSince=nil;ride.reset=nil;return end
 if ride.reset or not api.live(actor.ZipStart) then return end
 local start=actor.ZipStart:K2_GetComponentLocation()
 if not (nearStart(first,start) or nearStart(second,start)) then ride.stuckSince=nil;return end
 -- Save loads can restore an already-used hook. Let its native return
 -- run first, and only reset the unoccupied piece if it remains at the end.
 if not ride.stuckSince or now<ride.stuckSince then ride.stuckSince=now end
 if now-ride.stuckSince>=1.5 then
  ride.reset=true
  actor:CE_Reset()
  api.log('Tirolina del tendedero: gancho libre devuelto para el jugador que espera')
 end
end

function Story:clearEscort()
 self.escortScan=nil
 if self.escort then self.api.native:schoolEscort();self.escort=nil end
end

function Story:holdingHands(first,second)
 local api=self.api
 local a,b=first.PlayerHandholdingInterface,second.PlayerHandholdingInterface
 return api.live(a) and api.live(b) and a:IsHoldingHands() and b:IsHoldingHands()
  and api.same(a:GetHeldPartner(),b) and api.same(b:GetHeldPartner(),a)
end

function Story:cafeteriaObservers(first)
 local api=self.api
 local spawns,observers={},{}
 for _,spawner in ipairs(FindAllOf('AISpawner') or {}) do
  if api.world(spawner,first) and spawner:GetFullName():find(cafeteriaActors,1,true) then
   local bully=spawner:GetSpawnedAI()
   if not api.live(bully) then bully=spawner.mPawnReference end
   if api.live(bully) then spawns[bully:GetAddress()]=true end
  end
 end
 local pawnClass=StaticFindObject('/Script/Helios.ControlledPawn')
 if not api.live(pawnClass) then return observers end
 local controllerClass=StaticFindObject('/Script/Engine.Controller')
 for _,analyzer in ipairs(FindAllOf('PerceptionAnalyzer') or {}) do
  local sensors=api.live(analyzer) and analyzer.mSensors or nil
  local bully=api.live(sensors) and sensors:GetOwner() or nil
  if api.live(bully) and api.live(controllerClass) and bully:IsA(controllerClass) then bully=bully.Pawn end
  if api.world(bully,first) and bully:IsA(pawnClass) and bully:GetPawnType()==6
   and (spawns[bully:GetAddress()] or bully:GetFullName():find(cafeteriaActors,1,true)) then
   observers[#observers+1]=analyzer:GetAddress()
  end
 end
 return observers
end

function Story:escortUpdate(first,second,now,paused)
 local api=self.api
 if paused or not self:holdingHands(first,second) then self:clearEscort();return end
 if self.escort and not api.same(second,self.escort) then self:clearEscort() end
 if self.escortScan and now>=self.escortScan and now-self.escortScan<.6 then return end
 self.escortScan=now
 local level=api.gameplay():GetStreamingLevel(first,FName(cafeteria))
 if not api.live(level) or not level:IsLevelVisible() then self:clearEscort();self.escortScan=now;return end
 local observers=self:cafeteriaObservers(first)
 if #observers==0 or not api.native:schoolEscort(second:GetAddress(),observers) then
  self:clearEscort();self.escortScan=now;return
 end
 if not self.escort then api.log('Cafeteria: proteccion de P2 mientras camina de la mano de P1') end
 self.escort=second
end

function Story:clearEquipment()
 local grant=self.equipmentGrant
 self.equipmentGrant=nil
 if not grant then return end
 local api=self.api
 local ok,err=pcall(function()
  if not api.live(grant.pawn) or not api.same(grant.inventory,grant.pawn:GetInventoryComponent())
   or not api.same(grant.item,grant.inventory:GetInventoryItem(grant.slot)) then return end
  grant.inventory:RemoveItemFromInventory(grant.slot,false)
  if api.world(grant.actor,grant.pawn) and not grant.inventory:HasInventoryItem(grant.slot) then
   grant.actor:K2_DestroyActor()
  end
 end)
 if not ok and self.errors.equipmentCleanup~=err then
  self.errors.equipmentCleanup=err
  api.log('Retirada del equipo de P2: '..tostring(err))
 end
end

function Story:setEquipmentMode(mode)
 if mode==self.equipmentMode then return end
 self:clearEquipment()
 self.equipmentMode=mode
 self.equipmentPoll=nil
 self.equipmentAttempt=nil
end

function Story:equipmentUpdate(first,second,now,paused)
 local api=self.api
 local mode=self.equipmentMode
 local slot=mode.slot
 if self.equipmentGrant and not api.same(self.equipmentGrant.pawn,second) then self:clearEquipment() end
 if paused or (self.equipmentPoll and now>=self.equipmentPoll and now-self.equipmentPoll<.5) then return end
 self.equipmentPoll=now
 local source=first:GetInventoryComponent()
 local inventory=second:GetInventoryComponent()
 if not (api.live(source) and api.live(inventory)) or api.same(source,inventory) then return end
 local original=source:GetInventoryItem(slot)
 if not api.live(original) then
  self:clearEquipment()
  self.equipmentAttempt=nil
  return
 end
 if inventory:HasInventoryItem(slot) or not api.canEquip(second) then return end
 local control=first.mAnimationControlComponent
 if not api.live(control) or control:IsPlayingOverrideAnimation() then return end
 local attempt=self.equipmentAttempt
 if attempt and api.same(attempt.inventory,inventory) and now>=attempt.at and now-attempt.at<5 then return end
 self.equipmentAttempt={inventory=inventory,at=now}

 -- Use P2's own inventory after the story unlocks the item.
 -- The save flag is false for both creation and cleanup.
 inventory:SpawnEquipItem(slot,false)
 local item=inventory:GetInventoryItem(slot)
 if not api.live(item) or api.same(item,original) then return end
 local actor=item:GetOwner()
 if not api.world(actor,second) or api.same(actor,original:GetOwner()) then return end
 self.equipmentGrant={pawn=second,inventory=inventory,item=item,actor=actor,slot=slot}
 self.equipmentAttempt=nil
 api.log(mode.chapter..': P2 recibio '..mode.label)
end

function Story:reset()
 self:restoreZipline()
 self:clearEscort()
 self:setEquipmentMode(nil)
 self.ziplineScan=nil
end

function Story:guard(feature,update,reset,...)
 local ok,err=pcall(update,self,...)
 if not ok then
  pcall(reset,self)
  if self.errors[feature]~=err then self.errors[feature]=err;self.api.log(feature..': '..tostring(err)) end
 end
end

function Story:update(first,second,path,now,paused,secondIsMono)
 local api=self.api
 if not path or not api.world(first,second) then self:reset();return end
 local inCity=path:find(paleCity,1,true)
 local mode=secondIsMono and (inCity and remote or (path:find(hospital,1,true) and flashlight)) or nil
 self:setEquipmentMode(mode)
 if mode then
  self:guard('Equipo de P2',self.equipmentUpdate,self.clearEquipment,first,second,now,paused)
 end
 if inCity then
  self:clearEscort()
  self:guard('Tirolina',self.ziplineUpdate,self.restoreZipline,first,second,now,paused)
 elseif path:find(school,1,true) then
  self:restoreZipline()
  self.ziplineScan=nil
  self:guard('Cafeteria',self.escortUpdate,self.clearEscort,first,second,now,paused)
 else
  self:restoreZipline()
  self:clearEscort()
  self.ziplineScan=nil
 end
end

function Story:mark()
 local count=self.api.native:schoolEscortReads()
 if count then self.api.log('Cafeteria: detecciones de P2 evitadas='..count) end
end

return Story
