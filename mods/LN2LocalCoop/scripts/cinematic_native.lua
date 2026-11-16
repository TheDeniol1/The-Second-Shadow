-- First observed scene profile. No story callbacks or Six bindings are copied.
local N={};N.__index=N
local assetPath='AnimSequence /Game/Characters/Player/Animations/ANIM_Player_CallSixunderBedFullScene.ANIM_Player_CallSixunderBedFullScene'
local hunterPath='AnimSequence /Game/Characters/Player/Animations/ANIM_Player_HunterShedShoot_SideA.ANIM_Player_HunterShedShoot_SideA'
local reactionPath='/Game/Characters/Player/Animations/ANIM_Player_DragPullStepBack.ANIM_Player_DragPullStepBack'
function N.new(c)return setmetatable({c=c},N)end
function N:shot(emitter,event)
 local c=self.c;local active=c.active and c.active()
 if not active or active.scene~='cazador' or active.shotObserved or not c.state.enabled then return end
 if not c.live(event)or event:GetFullName()~='AkAudioEvent /Game/Audio/Events/Characters/Enemies/Hunter/Foley/Scenes/ShootingHunter/Play_ShotGunFire.Play_ShotGunFire' then return end
 local pc=c.p1()
 if not pc or not c.live(emitter)or not c.world(emitter,pc)then return end
 local owner=emitter:GetOwner()
 if not c.live(owner)or not owner:GetFullName():find('PersistentLevel.BP_RifleToolShed',1,true)then return end
 if not c.live(pc.Pawn)or pc.Pawn:GetAddress()~=active.first
  or not c.same(active.pawn,c.driver.pawn)then return end
 active.shotObserved=true
 c.log('Cinematica cazador: disparo nativo recibido de la escopeta')
end
function N:install()
 local ok,err=pcall(RegisterHook,'/Script/AkAudio.AkComponent:PostAkEvent',function(ctx,event)
  local worked,problem=pcall(function()self:shot(ctx:get(),event:get())end)
  if not worked then self.c.log('Evento de disparo: '..tostring(problem))end
 end)
 if not ok then self.c.log('No se pudo enlazar el disparo: '..tostring(err))end
end
function N:snapshot()
 local c=self.c;local pc=c.p1();local p=pc and pc.Pawn;local q=c.driver.pawn
 if not c.state.enabled or not(c.live(p)and c.live(q)and c.live(c.driver.pc))then return end
 if not c.world(p,q)or not c.same(q.Controller,c.driver.pc)or not c.same(c.driver.pc.Pawn,q)
  or not c.same(p.Controller,pc)or c.same(p,q)then return end
 local ac=p.mAnimationControlComponent
 if not c.live(ac)then return end
 local asset=ac.mCurrentAnimStateAsset
 local name=c.live(asset)and asset:GetFullName()
 local key=(name==assetPath or name==hunterPath)and ac:IsPlayingOverrideAnimation()and name or nil
 return {first=p:GetAddress(),second=q:GetAddress(),p=p,q=q,asset=asset,key=key,
  ready=c.spawn.phase=='active'and not c.spawn.pending and not c.death.pending and p:IsAlive()and q:IsAlive(),
  paused=c.state.menu or c.UE.GetGameplayStatics():IsGamePaused(pc),
  now=c.UE.GetGameplayStatics():GetTimeSeconds(pc)}
end
function N:start(s)
 local c=self.c;local p,q=s.p,s.q
 local ac=q.mAnimationControlComponent
 if not c.live(ac)or ac:IsPlayingOverrideAnimation()or not c.live(q.mAnimationOverrideComponent)
  or not c.live(q.CharacterMovement)or q.CharacterMovement.MovementMode~=1 then return end
 local anim=c.live(q.Mesh)and q.Mesh:GetAnimInstance()
 if not c.live(anim)or c.live(anim.mCurrentlyActiveGrabInterface)then return end
 local pickup=q:GetPlayerPickupInterface()
 if c.live(pickup)and c.live(pickup:GetCurrentlyHeldPickup())then return end
 if s.key==hunterPath then return self:startHunter(s)end
 local a,b=p:K2_GetActorLocation(),q:K2_GetActorLocation()
 if (a.X-b.X)^2+(a.Y-b.Y)^2>800^2 or math.abs(a.Z-b.Z)>80 then
  c.log('Cinematica mesa: P2 fuera de la zona de entrada');return
 end
 -- This scene travels along Y in the recorded Wilderness room. Keep a
 -- separate lane along X and sweep the capsule through its recorded travel.
 local destination
 for _,offset in ipairs({-110,110})do
  local at={X=a.X+offset,Y=a.Y,Z=a.Z}
  local finish={X=at.X,Y=a.Y-515,Z=a.Z}
  if c.clear(q,p,at)and c.clear(q,p,at,finish)then destination=at;break end
 end
 -- A standing capsule cannot preflight every part of this crouched scene.
 -- Failure to find a lane must not discard participation: retain P2's
 -- grounded location and let native root motion resolve collisions instead.
 local restriction=p.mAnimationControlComponent.mMovementRestrictionMode
 if not destination then
  destination=b
  restriction=2 -- EMovementRestriction::RootMotionWithPhysics (local SDK).
  c.log('Cinematica mesa: P2 participa desde su posicion, con colisiones')
 end
 c.driver:stop()
 q.CharacterMovement:StopMovementImmediately()
 local original=q:K2_GetActorLocation();local rotation=q:K2_GetActorRotation()
 local moved=q:K2_SetActorLocationAndRotation(destination,p:K2_GetActorRotation(),false,{},true)
 if moved==false then return end
 local active={pawn=q,asset=s.asset,duration=s.asset.SequenceLength}
 local ok,err=pcall(function()
  q.mAnimationOverrideComponent:PlayAnimationSequenceOverride2(s.asset,
   restriction,false,0,0.15,0.15)
 end)
 if not ok then
  q:K2_SetActorLocationAndRotation(original,rotation,false,{},true)
  error(err)
 end
 c.log('Cinematica mesa: P2 inicia '..s.key)
 return active
end
function N:startHunter(s)
 local c=self.c;local p,q=s.p,s.q
 local a,b=p:K2_GetActorLocation(),q:K2_GetActorLocation()
 if (a.X-b.X)^2+(a.Y-b.Y)^2>1200^2 or math.abs(a.Z-b.Z)>80 then
  c.log('Cinematica cazador: P2 fuera de la habitacion');return
 end
 local asset=StaticFindObject(reactionPath)
 if not c.live(asset)then
  pcall(LoadAsset,reactionPath);asset=StaticFindObject(reactionPath)
 end
 if not c.live(asset)then c.log('Cinematica cazador: reaccion no disponible');return end
 local rotation=p:K2_GetActorRotation();local yaw=math.rad(rotation.Yaw)
 local forward={X=math.cos(yaw),Y=math.sin(yaw)}
 local destination
 for _,offset in ipairs({110,-110,155,-155})do
  local at={X=a.X-forward.Y*offset-forward.X*35,
   Y=a.Y+forward.X*offset-forward.Y*35,Z=b.Z}
  local finish={X=at.X-forward.X*65,Y=at.Y-forward.Y*65,Z=at.Z}
  if c.clear(q,p,at)and c.clear(q,p,at,finish)then destination=at;break end
 end
 if not destination then
  c.log('Cinematica cazador: sin hueco lateral; reaccion desde posicion actual')
  destination=b
 end
 c.driver:stop();q.CharacterMovement:StopMovementImmediately()
 c.log('Cinematica cazador: P2 camina al hueco lateral')
 return {pawn=q,asset=asset,duration=asset.SequenceLength+6,scene='cazador',
  forward=forward,retreated=0,destination=destination,
  rotation={Pitch=0,Yaw=-90,Roll=0},phase='approach'}
end
function N:tick(active,s)
 if active.scene~='cazador'then return end
 local q=active.pawn
 if active.phase=='approach' then
  local at=q:K2_GetActorLocation()
  local dx,dy=active.destination.X-at.X,active.destination.Y-at.Y
  local distance=math.sqrt(dx*dx+dy*dy)
  if distance>18 then
   if s.now-active.since>5 then
    self.c.log('Cinematica cazador: recorrido bloqueado; se devuelve control');return false
   end
   self.c.driver.api.move(q,{X=dx/distance,Y=dy/distance,Z=0})
   return
  end
  self.c.driver:stop()
  q:K2_SetActorRotation(active.rotation,true)
  active.phase='waiting'
  self.c.log('Cinematica cazador: P2 espera mirando a la puerta')
 end
 if active.phase=='waiting' then
  if not active.shotObserved then return end
  q:K2_SetActorRotation(active.rotation,true)
  q.mAnimationOverrideComponent:PlayAnimationSequenceOverride2(active.asset,2,false,0,0.08,0.15)
  active.phase='reaction';active.reactionAt=s.now
  self.c.log('Cinematica cazador: P2 llega y reacciona')
 end
 local elapsed=s.now-active.reactionAt
 if elapsed>=active.asset.SequenceLength then return false end
 if not active.diagnosed then
  active.diagnosed=true
  local ok,detail=pcall(function()
   local at=q:K2_GetActorLocation();local mesh=q.Mesh:K2_GetComponentLocation()
   return string.format('actor=%.1f,%.1f,%.1f mesh=%.1f,%.1f,%.1f hidden=%s meshHidden=%s',
    at.X,at.Y,at.Z,mesh.X,mesh.Y,mesh.Z,tostring(q.bHidden),tostring(q.Mesh.bHiddenInGame))
  end)
  self.c.log('Cinematica cazador: '..(ok and detail or tostring(detail)))
 end
 -- Native physical root motion owns the backward step; no actor translation.

end
function N:finish(active)
 local c=self.c;local q=active.pawn
 if active.scene=='cazador' and c.same(q,c.driver.pawn)then c.driver:stop()end
 if c.live(q)and c.same(q,c.driver.pawn)and c.live(q.mAnimationControlComponent)
  and c.same(q.mAnimationControlComponent.mCurrentAnimStateAsset,active.asset)
  and c.live(q.mAnimationOverrideComponent)then
  q.mAnimationOverrideComponent:StopAnimationSequenceOverride(true)
 end
 c.log('Cinematica '..(active.scene or 'mesa')..': fin del control de P2')
end
function N:api()
 return {start=function(s)return self:start(s)end,finish=function(a)self:finish(a)end,
  tick=function(a,s)return self:tick(a,s)end}
end
return N
