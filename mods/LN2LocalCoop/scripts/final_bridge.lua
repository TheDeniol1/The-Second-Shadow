-- The last checkpoint follows the scripted stumble in CollapsingRunHallwayB.
-- The normal camera-relative spawn can place P2 outside supported positions.
local Bridge={};Bridge.__index=Bridge
local transmission='/Game/Levels/Transmission/PLVL_Transmission.'
local offsets={{0,-70},{0,-105},{-36,-70},{36,-70},{0,70}}

function Bridge.new(api)return setmetatable({api=api},Bridge)end
function Bridge:reset()self.attempt=nil end

function Bridge.atCheckpoint(first,position)
 return first:GetFullName():find(transmission,1,true)
  and math.abs(position.X+799)<=135 and position.Y>=11280 and position.Y<=11720
  and position.Z>=28725 and position.Z<=28950
end

function Bridge:watchEnding(first)
 local api=self.api
 if not api.live(first)then return false end
 local world=first:GetWorld()
 if not api.same(world,self.watchWorld)then self.watchWorld=nil end
 if not self.watchWorld and first:GetFullName():find(transmission,1,true)
  and Bridge.atCheckpoint(first,first:K2_GetActorLocation()) then
  self.watchWorld=world
  api.log('Puente final: registrando la secuencia de Six y el epilogo')
 end
 return self.watchWorld~=nil
end

function Bridge:destination(first,pawn,origin,accepts,lanes,movement)
 local api=self.api
 movement=movement or first.CharacterMovement
 for _,offset in ipairs(lanes or offsets)do
  for _,rise in ipairs({8,24,42})do
   local probe={X=origin.X+offset[1],Y=origin.Y+offset[2],Z=origin.Z+rise}
   local floor={}
   movement:K2_FindFloor(probe,floor)
   local distance=floor.bLineTrace and floor.LineDist or floor.FloorDist
   if floor.bBlockingHit and floor.bWalkableFloor and type(distance)=='number'
    and distance>=0 and distance<=60 then
    local at={X=probe.X,Y=probe.Y,Z=probe.Z-distance+4}
    if (not accepts or accepts(at,floor)) and api.clear(pawn,first,at) then return at end
   end
  end
 end
end

-- nil = use the usual join placement. false = wait without converting a
-- failed birth to a gameplay death. true = transfer the live pawn to co-op.
function Bridge:prepare(pc,pawn,firstPC)
 local api=self.api
 local first=firstPC.Pawn
 if self.attempt and not api.same(self.attempt.first,first)then self:reset() end
 if api.playAsSix() or not api.live(first)then return nil end
 local position=first:K2_GetActorLocation()
 if not self.attempt then
  if not Bridge.atCheckpoint(first,position)then return nil end
  self.attempt={first=first}
 end
 local attempt=self.attempt
 local now=api.clock(firstPC)
 if api.same(attempt.placed,pawn)then
  if pawn:IsAlive()then return now>=attempt.readyAt end
  attempt.placed=nil
 end
 if attempt.nextCheck and now<attempt.nextCheck then return false end
 attempt.nextCheck=now+0.25
 if not(first:IsAlive() and api.live(first.CharacterMovement) and first.CharacterMovement.MovementMode==1
  and api.live(pawn.CapsuleComponent))then return false end
 local at=self:destination(first,pawn,position)
 if not at then
  if not attempt.reported then api.log('Puente final: esperando suelo libre para la aparicion de P2');attempt.reported=true end
  return false
 end
 if pawn:IsAlive() then
  if pawn:K2_SetActorLocation(at,false,{},true)==false then return false end
  attempt.placed=pawn;attempt.readyAt=now+0.20;attempt.nextCheck=nil
  api.log(string.format('Puente final: P2 colocado en %.1f %.1f %.1f; comprobando aparicion',at.X,at.Y,at.Z))
  return false
 end
 if not attempt.restarted then
  attempt.restarted=true
  api.log('Puente final: recuperando el peon local de P2 en suelo verificado')
  api.restartLocal(pc,pawn,firstPC,at)
 end
 return false
end
return Bridge
