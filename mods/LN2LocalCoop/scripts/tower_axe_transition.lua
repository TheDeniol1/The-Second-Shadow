-- The preboss axe is unique to the door that advances this part of the Tower.
-- Follow the room change made by the game and place the other player on verified ground.
local Door={};Door.__index=Door
local axePath='/Game/Levels/Transmission/SubLevels/LVL_6_000_Transmission_CLOs.LVL_6_000_Transmission_CLOs:PersistentLevel.BP_ItemWeapon_Preboss'

function Door.isAxe(actor)
 return actor and actor:GetFullName():sub(-#axePath)==axePath
end

local function inApproach(at)
 return at.X>=-2300 and at.X<=2600 and at.Y>=-3200 and at.Y<=2400 and at.Z>=12600 and at.Z<=13760
end

local function apart(a,b,distance,height)
 return (a.X-b.X)^2+(a.Y-b.Y)^2>distance^2 or math.abs(a.Z-b.Z)>height
end

function Door.new(api)return setmetatable({api=api},Door)end

function Door:reset()
 self.track=nil
end

function Door:protectsSeparation()
 return self.track~=nil and self.track.arrivedAt~=nil and not self.track.finished
end

function Door:update(first,second,now,ready,paused)
 local api=self.api
 if not ready then self:reset();return end
 local track=self.track
 if track and (not api.same(track.first,first) or not api.same(track.second,second) or now<track.sampleAt) then
  self:reset();track=nil
 end
 if paused or (track and track.finished) then return end

 local a,b=first:K2_GetActorLocation(),second:K2_GetActorLocation()
 local wasArmed=track and track.armedUntil and now<=track.armedUntil
 if not track then
  if not (inApproach(a) or inApproach(b)) then return end
  track={first=first,second=second,sampleAt=now,a=a,b=b}
  self.track=track
 end
 if not track.arrivedAt then
  -- A hit can release the axe before the level script transfers the attacker.
  if (inApproach(a) and Door.isAxe(api.held(first))) or (inApproach(b) and Door.isAxe(api.held(second))) then
   if not track.armedUntil then api.log('Puerta del hacha: vigilando el traslado con el hacha de este tramo') end
   track.armedUntil=now+10
  end
  if wasArmed and now-track.sampleAt<=.35 then
   local leftFirst=inApproach(track.a) and apart(a,track.a,900,780)
   local leftSecond=inApproach(track.b) and apart(b,track.b,900,780)
   -- A manual reunion ends beside the stationary partner, without changing rooms.
   if (leftFirst and leftSecond) or ((leftFirst or leftSecond) and apart(a,b,240,65)) then
    track.arrivedAt=now
    track.role=leftFirst and 1 or 2
    track.bothArrived=leftFirst and leftSecond
    local at=leftFirst and a or b
    api.log(string.format('Puerta del hacha: traslado del juego detectado en P%d a %.0f %.0f %.0f',
     track.role,at.X,at.Y,at.Z))
   end
  end
 elseif now-track.sampleAt<=.35 then
  local movedOther=track.role==1 and inApproach(track.b) and apart(b,track.b,900,780)
   or track.role==2 and inApproach(track.a) and apart(a,track.a,900,780)
  if movedOther then track.bothArrived=true end
 end
 track.a,track.b,track.sampleAt=a,b,now
 if not track.arrivedAt then return end

 if not apart(a,b,240,65) then
  track.finished=true
  api.log('Puerta del hacha: ambos jugadores llegaron')
  return
 end
 if now-track.arrivedAt>=12 then
  track.finished=true
  api.log('Puerta del hacha: no se pudo confirmar una llegada compartida segura')
  return
 end
 if track.bothArrived or (track.retryAt and now<track.retryAt) then return end
 track.retryAt=now+.2
 local anchor,follower,at=first,second,a
 if track.role==2 then anchor,follower,at=second,first,b end
 if not api.grounded(anchor) or not api.canMove(follower) then return end
 local destination=api.destination(anchor,follower,at)
 if destination and api.move(follower,destination) then
  track.finished=true
  api.log('Puerta del hacha: P'..(3-track.role)..' reunido al otro lado del paso')
 end
end

return Door
