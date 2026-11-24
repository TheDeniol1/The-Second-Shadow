local Raft={}
local lake='/Game/Levels/Wilderness/SubLevels/LVL_1_580_DesolateLake02.LVL_1_580_DesolateLake02:PersistentLevel.'
local doorPath=lake..'BP_FloatingDoor02_2'
local collisionPath=lake..'RaftCollision'
Raft.sequenceActors={lake..'BP_HeliosLevelSequence_2',lake..'BP_HeliosLevelSequence3_2'}

local function distanceSquared(a,b)
 return (a.X-b.X)^2+(a.Y-b.Y)^2+(a.Z-b.Z)^2
end

local function floorOwner(c,floor)
 local component=floor.HitResult and floor.HitResult.Component
 if not component then return end
 local ok,owner=pcall(function()
  local object=component:Get()
  if c.live(object) then return object:GetOwner() end
 end)
 if ok then return owner end
end

local function onRaft(c,ride,owner)
 return c.same(owner,ride.door) or c.same(owner,ride.collision)
end

local function board(c,ride,s)
 local p,q=s.p,s.q
 local deck,root,seat=ride.deck,ride.root,ride.seat
 if c.live(root:GetAttachParent()) or not ride.available(q) then return end
 local first,second=p:K2_GetActorLocation(),q:K2_GetActorLocation()
 if distanceSquared(first,deck:K2_GetComponentLocation())>350^2 then return end
 if ride.nextProbe and s.now<ride.nextProbe then return end
 ride.nextProbe=s.now+.15

 local destination=c.landing(p,q,first,function(at,floor)
  return distanceSquared(second,at)<=145^2 and onRaft(c,ride,floorOwner(c,floor)) and c.clear(q,p,second,at)
 end)
 if not destination then return end

 c.driver:stop()
 ride.movement:StopMovementImmediately()
 local rotation=q:K2_GetActorRotation()
 if not q:K2_SetActorLocationAndRotation(destination,p:K2_GetActorRotation(),false,{},true) then return end
 local ok,err=pcall(function()
  local attached=root:K2_AttachToComponent(deck,FName('None'),1,1,1,false)
  ride.ownsAttachment=c.same(root:GetAttachParent(),deck)
  assert(attached and ride.ownsAttachment,'no se pudo fijar el asiento al movimiento de la puerta')
  ride.movement:SetMovementMode(0,0)
  q.mAnimationOverrideComponent:PlayAnimationSequenceOverride2(seat,1,true,0,.12,.15)
 end)
 if not ok then
  local ac=q.mAnimationControlComponent
  if c.live(ac) and c.same(ac.mCurrentAnimStateAsset,seat) then
   q.mAnimationOverrideComponent:StopAnimationSequenceOverride(true)
  end
  Raft.release(c,ride)
  if q:K2_SetActorLocationAndRotation(second,rotation,false,{},true) and ride.movement.MovementMode==3 then
   ride.movement:SetMovementMode(1,0)
  end
  c.log('Cinematica balsa: '..tostring(err))
  ride.nextProbe=s.now+.7
  return
 end
 ride.asset=seat
 ride.nextProbe=nil
 ride.passThrough=false
 ride.protectsSeparation=true
 c.log('Cinematica balsa: P2 viaja sentado en la puerta')
end

function Raft.start(c,s,seat,available)
 local p,q=s.p,s.q
 local first,second=p:K2_GetActorLocation(),q:K2_GetActorLocation()
 if distanceSquared(first,second)>900^2 then return end
 local door,collision=StaticFindObject(doorPath),StaticFindObject(collisionPath)
 if not (c.world(door,p) and c.world(collision,p) and c.live(p.CharacterMovement)) then return end
 local deck,root=door.SKM_FloatingDoor02,q.RootComponent
 if not (c.live(deck) and c.live(root) and c.live(q.CharacterMovement)) then return end
 if distanceSquared(first,deck:K2_GetComponentLocation())>350^2 then return end

 local ride={raft=true,pawn=q,seat=seat,door=door,collision=collision,deck=deck,root=root,
  movement=q.CharacterMovement,duration=100,scene='balsa',followThrough=true,passThrough=true,available=available}
 board(c,ride,s)
 if not ride.asset then c.log('Cinematica balsa: P2 conserva el control para acercarse a la puerta') end
 return ride
end

function Raft.tick(c,ride,s)
 local p,q=s.p,s.q
 if not (c.live(ride.root) and c.live(ride.deck) and c.same(q.RootComponent,ride.root)
  and c.same(q.CharacterMovement,ride.movement) and c.world(ride.door,p)) then return false end
 if not ride.asset then
  if s.key~=ride.key then return false end
  ride.protectsSeparation=distanceSquared(q:K2_GetActorLocation(),ride.deck:K2_GetComponentLocation())<=650^2
  board(c,ride,s)
  return true
 end
 if not c.same(ride.root:GetAttachParent(),ride.deck) then return false end
 local ac=q.mAnimationControlComponent
 if not (c.live(ac) and ac:IsPlayingOverrideAnimation() and c.same(ac.mCurrentAnimStateAsset,ride.asset)) then
  return false
 end
 if s.key==ride.key then return true end

 ride.disembarkAt=ride.disembarkAt or s.now
 if s.now-ride.disembarkAt>4 then return false end
 local movement=p.CharacterMovement
 if not c.live(movement) or movement.MovementMode~=1 then return true end
 if ride.nextProbe and s.now<ride.nextProbe then return true end
 ride.nextProbe=s.now+.2
 local origin=p:K2_GetActorLocation()
 if distanceSquared(origin,ride.deck:K2_GetComponentLocation())>1800^2 then return false end
 local destination=c.landing(p,q,origin,function(_,floor)
  local owner=floorOwner(c,floor)
  return c.live(owner) and not onRaft(c,ride,owner)
 end)
 if not destination then return true end
 if q:K2_SetActorLocation(destination,false,{},true)==false then return true end
 Raft.release(c,ride)
 c.log('Cinematica balsa: P2 desembarco en suelo firme')
 return false
end

function Raft.release(c,ride)
 local q=ride.pawn
 if not (ride.ownsAttachment and c.same(q,c.driver.pawn) and c.live(ride.root) and c.same(q.RootComponent,ride.root)) then return end
 local parent=ride.root:GetAttachParent()
 if c.same(parent,ride.deck) then
  q:K2_DetachFromActor(1,1,1)
 elseif c.live(parent) then
  return
 end
 ride.ownsAttachment=false
 if c.live(ride.movement) and c.same(q.CharacterMovement,ride.movement) and ride.movement.MovementMode==0 then
  ride.movement:SetMovementMode(3,0)
 end
end

return Raft
