local MusicBox={};MusicBox.__index=MusicBox
local longHit='ANIM_Player_HittingMusicBoxVoidLong'
local firstWake='ANIM_Player_HittingMusicBox_SpawnWakeUp'
local hits={
 [longHit]=true,
 ANIM_Player_HittingMusicBoxRecoil=true,
}
local arrivals={
 [firstWake]=true,
 ANIM_Player_WakeUpAfterLastHitMusicBox=true,
 ANIM_Player_StumbleFallLongTransmission=true,
}
local axePickup='ANIM_Player_AxeTransmissionPickup2'
local floorMode=1

local function distanceSquared(a,b)
 return (a.X-b.X)^2+(a.Y-b.Y)^2+(a.Z-b.Z)^2
end

local function atFirstEncounter(at)
 return distanceSquared(at,{X=3253,Y=-15511,Z=4962})<=650^2
end

local voidStumble='ANIM_Player_StumbleFallLong'
local function leavingVoid(name,at)
 return name==voidStumble and distanceSquared(at,{X=-2704,Y=-19502,Z=31119})<=420^2
end

local function enteredMonsterRoom(name,at)
 return name=='ANIM_Player_StumbleFall' and distanceSquared(at,{X=-642,Y=4148,Z=19945})<=420^2
end

function MusicBox.new(api)
 return setmetatable({api=api},MusicBox)
end

function MusicBox:reset()
 self.hit=nil
 self.finished=nil
 self.pose=nil
end

function MusicBox:watchPose(second,name,asset,now)
 if not (hits[name] or arrivals[name] or name==axePickup) then self.pose=nil;return end
 local api=self.api
 local pose=self.pose
 if not pose or not api.same(pose.pawn,second) or not api.same(pose.asset,asset) then
  local length=asset.SequenceLength
  local limit=type(length)=='number' and length>0 and math.max(length+2,10) or 30
  self.pose={pawn=second,asset=asset,startedAt=now,expires=now+limit}
  return
 end
 if now>=pose.expires and not pose.stopped and api.live(second.mAnimationOverrideComponent) then
  pose.stopped=true
  second.mAnimationOverrideComponent:StopAnimationSequenceOverride(true)
  api.log('Caja musical: liberado el clip de P2 que seguia activo despues de su duracion ('..name..')')
  return true
 end
end

function MusicBox:animation(pawn)
 local control=pawn.mAnimationControlComponent
 local asset=self.api.live(control) and control.mCurrentAnimStateAsset or nil
 if self.api.live(asset) and control:IsPlayingOverrideAnimation() then
  return asset:GetFullName():match('%.([^%.]+)$'),asset
 end
end

function MusicBox:protectsSeparation()
 local hit=self.hit
 return hit~=nil and (hit.firstStrike or hit.arrivedAt~=nil or hit.endedAt==nil)
end

function MusicBox:release(hit,asset)
 local pawn=hit.second
 if not hit.released and self.api.same(asset,hit.asset) and self.api.live(pawn.mAnimationOverrideComponent) then
  pawn.mAnimationOverrideComponent:StopAnimationSequenceOverride(true)
  hit.released=true
 end
end

-- Wait for a native arrival before attempting to reunite the pair.
function MusicBox:update(first,second,now,ready,start,paused,redirectSecond)
 local api=self.api
 local hit=self.hit
 if not ready then
  self:reset()
  return false
 end
 if hit and (not api.same(hit.first,first) or not api.same(hit.second,second) or now<hit.lastAt) then
  self:reset()
  return false
 end
 if self.pose and now<self.pose.startedAt then self.pose=nil end
 if paused then return hit~=nil and hit.arrivedAt~=nil end
 if not (hit or start) then return false end

 local firstName,firstAsset=self:animation(first)
 local secondName,secondAsset=self:animation(second)
 -- The first hit visits an intermediate room before the wake at the actual destination.
 local inFirstStrike=hit and hit.firstStrike and not hit.arrivedAt and secondName==longHit
 if not inFirstStrike and (redirectSecond~=false or self.pose) and self:watchPose(second,secondName,secondAsset,now) then
  secondName,secondAsset=self:animation(second)
 end
 if not hit then
  local finished=self.finished
  if finished then
   local current=firstAsset
   if finished.fromSecond then current=secondAsset end
   if api.same(first,finished.first) and api.same(second,finished.second) and api.same(current,finished.asset) then return false end
   self.finished=nil
  end
  if hits[firstName] and hits[secondName] then return false end
  local fromSecond=hits[secondName]==true
  if fromSecond and redirectSecond==false then return false end
  local at=first:K2_GetActorLocation()
  local void=not fromSecond and leavingVoid(firstName,at)
  if not fromSecond and not hits[firstName] and not void then return false end
  local firstStrike=(fromSecond and secondName==longHit and atFirstEncounter(second:K2_GetActorLocation()))
   or (not fromSecond and firstName==longHit and atFirstEncounter(at))
  self.hit={first=first,second=second,fromSecond=fromSecond,asset=fromSecond and secondAsset or firstAsset,
   startedAt=now,lastAt=now,lastPosition=at,firstName=firstName,void=void,firstStrike=firstStrike}
  local source=void and 'salida del vacio' or ('clip de golpe asignado a P'..(fromSecond and '2' or '1'))
  api.log('Caja musical: '..source..'; esperando el cambio de sala')
  return false
 end

 local firstHit=not hit.fromSecond and api.same(firstAsset,hit.asset)
 local secondHit=hit.fromSecond and api.same(secondAsset,hit.asset)
 local secondArrival=hit.fromSecond and arrivals[secondName]
 if hit.fromSecond and secondAsset and not (hit.firstStrike or secondHit or secondArrival or hit.arrivedAt) then
  self.hit=nil
  return false
 end
 if secondHit and not hit.arrivedAt and hit.endedAt then
  self.hit=nil
  return false
 end
 if not (firstHit or secondHit) then hit.endedAt=hit.endedAt or now end

 local at=first:K2_GetActorLocation()
 if not hit.arrivedAt then
  local jumped=(not hit.endedAt or now-hit.endedAt<=2)
   and now-hit.lastAt<=.35 and distanceSquared(at,hit.lastPosition)>=600^2
  local arrived
  if hit.firstStrike then arrived=secondName==firstWake or (firstName==firstWake and firstName~=hit.firstName)
  elseif hit.void then arrived=enteredMonsterRoom(firstName,at)
  else arrived=secondArrival or (arrivals[firstName] and firstName~=hit.firstName) or jumped end
  if arrived then
   hit.arrivedAt=now
   hit.nativeSecond=secondArrival
   api.log('Caja musical: llegada nativa de P'..(hit.nativeSecond and '2' or '1')..'; reuniendo a los dos Monos')
  elseif now-hit.startedAt>30 or (not hit.firstStrike and hit.endedAt and now-hit.endedAt>2) then
   -- A recoil may finish without a room change.
   self.hit=nil
   self.finished=hit
  end
  hit.lastPosition=at
  hit.firstName=firstName
 end
 hit.lastAt=now
 if not hit.arrivedAt then return false end
 if hit.nativeSecond and secondArrival and now-hit.arrivedAt<=20 then return true end
 if hit.firstStrike and secondHit and now-hit.arrivedAt<=20 then return true end
 if hit.retryAt and now<hit.retryAt then return true end
 hit.retryAt=now+.2
 local anchor,partner=first,second
 local partnerAt=second:K2_GetActorLocation()
 local partnerAsset=secondAsset
 if hit.nativeSecond then
  anchor,partner=second,first
  at,partnerAt=partnerAt,at
  partnerAsset=firstAsset
 end
 local movement=anchor.CharacterMovement
 local together=distanceSquared(at,partnerAt)<=240^2 and math.abs(at.Z-partnerAt.Z)<=65
 local movable=(secondHit and not hit.nativeSecond) or (not partnerAsset and (not api.canMove or api.canMove(partner)))
 local destination
 if movable and not together and api.live(movement) and movement.MovementMode==floorMode then
  destination=api.destination(anchor,partner,at)
 end
 if together or destination then
  if secondHit and not hit.nativeSecond then self:release(hit,secondAsset) end
  if together or api.move(partner,destination) then
   self.hit=nil;self.finished=hit
   api.log('Caja musical: los dos Monos estan juntos tras el cambio de sala')
   return false
  end
 end
 if now-hit.arrivedAt>20 then
  if secondHit and not hit.nativeSecond then self:release(hit,secondAsset) end
  self.hit=nil;self.finished=hit
  api.log('Caja musical: no se encontro una llegada segura para reunir a los dos Monos')
  return false
 end
 return true
end

return MusicBox
