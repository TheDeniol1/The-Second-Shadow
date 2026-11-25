local Path=require('air_rescue_path')
local Lift={};Lift.__index=Lift

function Lift.new(context)return setmetatable({c=context},Lift)end

local function floorAt(movement,point)
 local floor={}
 movement:K2_FindFloor(point,floor)
 local distance=floor.bLineTrace and floor.LineDist or floor.FloorDist
 if floor.bBlockingHit and floor.bWalkableFloor and type(distance)=='number' and distance>=0 and distance<=60 then
  return {X=point.X,Y=point.Y,Z=point.Z-distance+3}
 end
end

function Lift:plan(pawn,movement,radius)
 local origin=pawn:K2_GetActorLocation()
 -- The catch starts beside X=-809 and the far side lies along positive Y.
 for _,forward in ipairs({105,140,175,210})do
  for _,rise in ipairs({92,116,68,140,44,164,188,212})do
   local target=floorAt(movement,{X=origin.X,Y=origin.Y+forward,Z=origin.Z+rise})
   if target and target.Z>origin.Z+10 then
    local plan=Path.new(origin,target,radius)
    local clear=self.c.clear
    if plan and clear(pawn,origin,plan.lift) and clear(pawn,plan.lift,plan.cross)
     and clear(pawn,plan.cross,plan.target)then return plan end
   end
  end
 end
end

function Lift:prepare(pawn,now,duration,rate,fallback)
 local c=self.c
 local movement,capsule,mesh=pawn.CharacterMovement,pawn.CapsuleComponent,pawn.Mesh
 local animation=c.live(mesh)and mesh:GetAnimInstance()or nil
 if not(c.live(movement)and c.live(capsule)and c.live(animation))then return end
 local radius=capsule:GetScaledCapsuleRadius()
 local plan=self:plan(pawn,movement,radius)
 if not plan and fallback then
  -- Suelo conocido del puente, por si la búsqueda falla desde esta postura.
  plan=Path.new(pawn:K2_GetActorLocation(),fallback,radius)
  if plan then c.log('Puente final: se usa el suelo conocido del puente para subir a P2')end
 end
 if not plan then c.log('Puente final: no se encontro suelo libre para subir a P2');return end
 return {pawn=pawn,movement=movement,animation=animation,mesh=mesh,plan=plan,progress=0,
  movementTick=movement:IsComponentTickEnabled(),collision=pawn:GetActorEnableCollision(),
  rootMode=animation.RootMotionMode,startedAt=now,duration=duration,rate=rate or 1}
end

function Lift:begin(lift)
 self.active=lift
 lift.movement:StopMovementImmediately()
 -- The path supplies its own capsule sweeps while this scripted movement
 -- runs. Prevent the regular movement tick and overlap reactions from also
 -- trying to resolve the old handhold inside the ledge.
 lift.movement:SetComponentTickEnabled(false)
 lift.pawn:SetActorEnableCollision(false)
 lift.movement:SetMovementMode(5,0)
 lift.animation:SetRootMotionMode(1)
 if lift.rate~=1 then
  lift.originalRate=tonumber(lift.mesh.GlobalAnimRateScale)
  if lift.originalRate then lift.mesh.GlobalAnimRateScale=lift.originalRate*lift.rate end
 end
 self.c.log(string.format('Puente final: subida de P2 hacia %.1f %.1f %.1f',
  lift.plan.target.X,lift.plan.target.Y,lift.plan.target.Z))
end

function Lift:release()
 local lift=self.active
 self.active=nil
 if not lift then return end
 local c=self.c
 if c.live(lift.mesh)and lift.originalRate then lift.mesh.GlobalAnimRateScale=lift.originalRate end
 if c.live(lift.animation)and lift.animation.RootMotionMode==1 then lift.animation:SetRootMotionMode(lift.rootMode)end
 if c.live(lift.pawn)then lift.pawn:SetActorEnableCollision(lift.collision)end
 if c.live(lift.movement)then
  if lift.movement.MovementMode==5 then lift.movement:SetMovementMode(lift.landed and 1 or 3,0)end
  lift.movement:SetComponentTickEnabled(lift.movementTick)
 end
end

function Lift:update(pawn,now)
 local lift,c=self.active,self.c
 if not lift then return end
 if not(c.same(lift.pawn,pawn)and c.same(lift.movement,pawn.CharacterMovement)
  and c.live(pawn.Mesh)and c.same(lift.animation,pawn.Mesh:GetAnimInstance()))then
  self:release();return
 end
 local expected=Path.at(lift.plan,lift.progress)
 local actual=pawn:K2_GetActorLocation()
 local drift=Path.distance2(actual,expected)
 if drift>5^2 then
  -- The scripted catch keeps applying its placement briefly after the
  -- animation changes. Re-anchor only to the last verified, clear pose.
  local check={X=expected.X,Y=expected.Y,Z=expected.Z+0.2}
  if drift>300^2 or not c.clear(pawn,expected,check)
   or pawn:K2_SetActorLocation(expected,false,{},true)==false then
   c.log(string.format('Puente final: la cinemática desplazo a P2 %.1f unidades fuera de la subida',math.sqrt(drift)))
   self:release();return
  end
  if not lift.corrected then
   lift.corrected=true
   c.log('Puente final: anclaje del tiron restaurado tras el movimiento de la cinemática')
  end
 end
 if lift.landed then return end
 if lift.animation.RootMotionMode~=1 then lift.animation:SetRootMotionMode(1)end
 if lift.movement.MovementMode~=5 then lift.movement:SetMovementMode(5,0)end
 lift.movement:StopMovementImmediately()
 local progress=math.max(lift.progress,math.min(1,(now-lift.startedAt)/lift.duration))
 if progress==lift.progress then return end
 for _,target in ipairs(Path.moves(lift.plan,lift.progress,progress))do
  local at=pawn:K2_GetActorLocation()
  if not c.clear(pawn,at,target)then
   c.log(string.format('Puente final: obstaculo en subida de P2 %.1f %.1f %.1f hacia %.1f %.1f %.1f',
    at.X,at.Y,at.Z,target.X,target.Y,target.Z))
   self:release();return
  end
  pawn:K2_SetActorLocation(target,true,{},false)
  if Path.distance2(pawn:K2_GetActorLocation(),target)>5^2 then
   c.log('Puente final: la capsula de P2 no alcanzo el recorrido de subida');self:release();return
  end
 end
 lift.progress=progress
 if progress==1 then
  local at=pawn:K2_GetActorLocation()
  -- FindFloor requires the character's query collision to be enabled.
  pawn:SetActorEnableCollision(lift.collision)
  local floor=floorAt(lift.movement,at)
  if not floor or math.abs(floor.Z-at.Z)>12 then
   c.log('Puente final: se perdio el suelo bajo P2');self:release();return
  end
  lift.landed=true
  lift.movement:StopMovementImmediately()
  lift.movement:SetMovementMode(1,0)
  c.log('Puente final: P2 subio y apoyo los pies en la plataforma')
 end
end

return Lift
