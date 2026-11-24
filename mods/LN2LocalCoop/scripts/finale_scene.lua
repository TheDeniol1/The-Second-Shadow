local Finale={};Finale.__index=Finale
local Bridge=require('final_bridge')
local tower='/Game/Levels/Transmission/PLVL_Transmission.'
local betrayal='ANIM_Player_GapHelpSixBetrayal'
local departureDuration=.65

function Finale.new(api)return setmetatable({api=api},Finale)end
function Finale:stopReaction(route)
 if not route or not route.reaction then return end
 local clip=route.reaction
 route.reaction=nil
 self.api.stopReaction(route.reacting,clip)
end
function Finale:reset()
 if self.route and self.route.phase=='rescue' then self.api.releaseCamera()end
 self:stopReaction(self.route)
 self.api.clearShadow()
 self.route=nil
 self.grace=nil
end

local function atGap(position)
 return math.abs(position.X+809)<180 and position.Y>=13750 and position.Y<=14300
  and position.Z>=28150 and position.Z<=29275
end

function Finale:update(first,second,now,enabled,playing,paused)
 local api=self.api
 if not enabled then self:reset();return end
 if not playing or not api.live(first)or paused then return self.route and 'hold' end
 local route=self.route
 if not route and (not api.live(second)or not first:GetFullName():find(tower,1,true))then return end
 local at=first:K2_GetActorLocation()
 if route and Bridge.atCheckpoint(first,at)
  and (not api.same(first,route.first)or route.phase=='shadow' or route.phase=='departing' or route.phase=='done')then
  -- A manual reload or an ordinary death in the gap can return to the bridge.
  self:reset()
  return
 end
 if not route then
  if atGap(at) and api.animation(first)==betrayal then
   self.route={phase='primary',first=first,second=second,at=at,reacting=second}
   api.stopSecond()
   self.route.reaction=api.reactPartner(first,second,2)
   api.log('Puente final: Six atrapo a P1 primero')
   return 'hold'
  end
  local other=second:K2_GetActorLocation()
  if atGap(other) and api.animation(second)==betrayal then
   local ok,length=pcall(api.pull,second)
   if not ok then api.log('Puente final: no se pudo reproducir el rescate: '..tostring(length));length=nil end
   self.route={phase='rescue',first=first,second=second,reacting=first,
    finishAt=now+math.min(4.25,math.max(1.1,length or 0)+1.25)}
   self.route.reaction=api.reactPartner(second,first,1)
   api.frameRescue(second)
   api.log('Puente final: Six atrapo a P2 primero')
   return 'hold'
  end
  -- A follower can die just before the catch override is visible on P1.
  if atGap(at) and first:IsAlive() and not second:IsAlive() then
   self.grace=self.grace or now
   if now-self.grace<1.15 then return 'grace' end
  else self.grace=nil end
  return
 end
 if route.phase=='rescue' then
  if not api.same(first,route.first)then self:reset();return end
  if now<route.finishAt then
   api.frameRescue(route.second)
   return 'hold'
  end
  self:reset()
  return 'restart'
 end
 if route.phase=='primary' then
  if api.live(second) and (not second:IsAlive() or api.animation(second)==betrayal)then
   self:stopReaction(route)
   api.parkSecond()
  end
  -- Wait for the native scene to release P1 in the epilogue. The scripted
  -- fall may report P1 dead, or transport the same pawn far from the ledge.
  local moved=(at.X-route.at.X)^2+(at.Y-route.at.Y)^2+(at.Z-route.at.Z)^2>1800^2
  if not first:IsAlive() or atGap(at) or (not moved and api.same(first,route.first)) then return 'hold' end
  self:stopReaction(route)
  api.parkSecond()
  route.phase='shadow'
  api.log('Final: epilogo de P1; aparece la sombra de P2')
 end
 if route.phase=='shadow'then
  local cue=api.chair(first)
  if cue then
   route.phase='departing'
   route.departureAt=now
   api.beginDissolve(first)
   api.log('Final: Mono se sento; la sombra de P2 empieza a desvanecerse')
  else api.shadow(first,now)end
 end
 if route.phase=='departing' then
  if now<route.departureAt then self:reset();return end
  local progress=math.min(1,(now-route.departureAt)/departureDuration)
  api.dissolve(progress)
  if progress>=1 then
   route.phase='done'
   api.log('Final: la sombra de P2 se disipo')
  end
 end
 return 'hold'
end
return Finale
