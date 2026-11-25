local N={};N.__index=N
local Lift=require('finale_lift')
local pullPath='/Game/Characters/Six/Animations/ANIM_Six_GapHelpPullUp.ANIM_Six_GapHelpPullUp'
local risePath='/Game/Characters/Player/Animations/ANIM_Player_GapHelpPulledUp.ANIM_Player_GapHelpPulledUp'
local bridgeLevel='/Game/Levels/Transmission/SubLevels/LVL_6_140_'
local bridgeSix=bridgeLevel..'CollapsingRunExit_02.LVL_6_140_CollapsingRunExit_02:PersistentLevel.SKM_Six2'
local shadowPath='/Game/Environment/DefaultMaterials/Effect/Hologram/MAT_HologramGlitch_PhantomKids_Inst01.MAT_HologramGlitch_PhantomKids_Inst01'
local dissolvePath='/Game/Environment/Effects/Particles/ThinmanEffects/P_Thinman_TeleportIn01.P_Thinman_TeleportIn01'
local staticPath='/Game/Audio/Events/Objects/Electric/TVs/TV_Shows/Play_TV_Static_GlitchBurst.Play_TV_Static_GlitchBurst'
local function unwrapObjects(objects)
 -- Reflected arrays in this UE4SS build copy each entry as RemoteUnrealParam.
 -- Resolve the entries before invoking another reflected function.
 for i=1,#objects do
  local entry=objects[i]
  if entry and type(entry.get)=='function'then objects[i]=entry:get()end
 end
 return objects
end

function N.new(c)return setmetatable({c=c,assets={},lift=Lift.new(c)},N)end
function N:asset(path)
 local value=self.assets[path]
 if not self.c.live(value) then
  value=StaticFindObject(path)
  if not self.c.live(value)then pcall(LoadAsset,path);value=StaticFindObject(path)end
  self.assets[path]=value
 end
 if self.c.live(value)then return value end
end
function N:animation(pawn)
 local c=self.c
 local control=c.live(pawn) and pawn.mAnimationControlComponent or nil
 local asset=c.live(control) and control.mCurrentAnimStateAsset or nil
 if c.live(asset) and control:IsPlayingOverrideAnimation()then
  return asset:GetFullName():match('%.([^%.]+)$')
 end
end
-- ¿Sujeta este pawn un arma (el hacha de la Torre)?
function N:holdsWeapon(pawn)
 local c=self.c
 if not c.live(pawn) then return false end
 local interface=pawn:GetPlayerPickupInterface()
 local pickup=c.live(interface) and interface:GetCurrentlyHeldPickup() or nil
 if not (c.live(pickup) and c.same(pickup:GetHolderIfHeld(),pawn)) then return false end
 return pickup:GetFullName():find('ItemWeapon',1,true)~=nil
end
function N:findSix(second,pull)
 local c=self.c
 local at=second:K2_GetActorLocation()
 local mesh,distance
 local function consider(component,candidate)
  local visual=c.live(component) and component.SkeletalMesh or nil
  if not c.live(visual) or not component:IsVisible() or component.bHiddenInGame then return end
  local asset=visual:GetFullName():lower()
  local owner=candidate:GetFullName():lower()
  local leaf=asset:match('%.([^%.]+)$')or ''
  if not (asset:find('/six/',1,true)or asset:find('skm_six',1,true)
   or ((owner:find('six',1,true)or leaf:find('six',1,true))
    and c.same(visual.Skeleton,pull.Skeleton)))then return end
  if asset:find('monster',1,true)then return end
  local pos=component:K2_GetComponentLocation()
  local d=(pos.X-at.X)^2+(pos.Y-at.Y)^2+(pos.Z-at.Z)^2
  if d>=600^2 then
   local root=FName('root')
   if component:DoesSocketExist(root)then
    pos=component:GetSocketLocation(root)
    d=(pos.X-at.X)^2+(pos.Y-at.Y)^2+(pos.Z-at.Z)^2
   end
  end
  if d<600^2 and (not distance or d<distance)then mesh,distance=component,d end
 end
 local placed=StaticFindObject(bridgeSix)
 if c.world(placed,second)and not placed.bHidden then
  consider(placed.SkeletalMeshComponent,placed)
  if mesh then return mesh end
 end
 for _,component in ipairs(FindAllOf('SkeletalMeshComponent')or{})do
  if c.live(component)then
   local owner=component:GetOwner()
   if c.world(owner,second)and not owner.bHidden then consider(component,owner)end
  end
 end
 if mesh then return mesh end
 -- Sequencer can attach Six to a level Blueprint or a derived mesh
 -- component. Enumerating nearby world actors also covers these bindings.
 local actorClass=StaticFindObject('/Script/Engine.Actor')
 local meshClass=StaticFindObject('/Script/Engine.SkeletalMeshComponent')
 if not(c.live(actorClass)and c.live(meshClass))then return end
 local actors={}
 c.UE.GetGameplayStatics():GetAllActorsOfClass(second,actorClass,actors)
 for _,actor in ipairs(unwrapObjects(actors))do
  if c.live(actor)and not actor.bHidden then
   local pos=actor:K2_GetActorLocation()
   if (pos.X-at.X)^2+(pos.Y-at.Y)^2+(pos.Z-at.Z)^2<1200^2 then
    local components=unwrapObjects(actor:K2_GetComponentsByClass(meshClass))
    for _,component in ipairs(components)do consider(component,actor)end
   end
  end
 end
 return mesh
end
function N:hideBridgeSix(scene,now)
 local c=self.c
 local function hide(actor,mesh)
  for _,entry in ipairs(scene.hiddenActors)do
   if c.same(entry.actor,actor)then return end
  end
  scene.hiddenActors[#scene.hiddenActors+1]={actor=actor,wasHidden=actor.bHidden,
   mesh=mesh,wasRendered=c.live(mesh)and mesh.bRenderInMainPass}
  c.log('Puente final: ocultando el modelo original '..actor:GetFullName())
 end
 if now>=scene.nextHideScan then
  scene.nextHideScan=now+.2
  local source=scene.original
  if c.live(source)then
   local owner=source:GetOwner()
   -- Source was resolved against the active catch. A streamed level's actor
   -- may not return the playable pawn's world through UE4SS's GetWorld().
   if c.live(owner)then hide(owner,source)end
  end
  for _,actor in ipairs(FindAllOf('SkeletalMeshActor')or{})do
   if c.live(actor)and not c.same(actor,scene.actor)then
    local name=actor:GetFullName()
    if name:find(bridgeLevel,1,true)then
     local mesh=actor.SkeletalMeshComponent
     local visual=c.live(mesh)and mesh.SkeletalMesh or nil
     if name:match(':PersistentLevel%.SKM_Six[%w_]*$')
      or (c.live(source)and c.same(visual,source.SkeletalMesh))then hide(actor,mesh)end
    end
   end
  end
 end
 for _,entry in ipairs(scene.hiddenActors)do
  if c.live(entry.actor)and not entry.actor.bHidden then entry.actor:SetActorHiddenInGame(true)end
  if c.live(entry.mesh)and entry.mesh.bRenderInMainPass then entry.mesh:SetRenderInMainPass(false)end
 end
 local original=scene.original
 if c.live(original)then
  if original.bVisible then original:SetVisibility(false,false)end
  if not original.bHiddenInGame then original:SetHiddenInGame(true,false)end
 end
end
function N:updateSix(second)
 local c=self.c
 local scene=self.sixPull
 if not(scene and c.live(second))then return end
 local now=c.UE.GetGameplayStatics():GetTimeSeconds(second)
 if c.live(scene.actor)then
  self:hideBridgeSix(scene,now)
  return
 end
 local elapsed=now-scene.startedAt
 if elapsed<scene.nextSearch or scene.missing then return end
 if elapsed>.90 then
  scene.missing=true
  c.log('Puente final: no se encontro la malla visible de Six para el tiron')
  return
 end
 scene.nextSearch=elapsed+.22
 local mesh=self:findSix(second,scene.asset)
 if not mesh then return end
 local class=StaticFindObject('/Script/Engine.SkeletalMeshActor')
 if not c.live(class)then return end
 local rotation=mesh:K2_GetComponentRotation()
 -- The pull-up asset faces the opposite way from the bridge betrayal pose.
 local facing={Pitch=rotation.Pitch,Yaw=(rotation.Yaw+180)%360,Roll=rotation.Roll}
 local actor=second:GetWorld():SpawnActor(class,mesh:K2_GetComponentLocation(),facing)
 if not c.live(actor)then return end
 scene.actor=actor
 local visual=actor.SkeletalMeshComponent
 actor:SetActorEnableCollision(false)
 visual:SetMobility(2)
 visual:SetCollisionEnabled(0)
 visual:SetSkeletalMesh(mesh.SkeletalMesh,false)
 for i=0,mesh:GetNumMaterials()-1 do visual:SetMaterial(i,mesh:GetMaterial(i))end
 visual:PlayAnimation(scene.asset,false)
 visual:SetPlayRate(scene.rate or 1)
 if elapsed>0 then
  local position=elapsed*(scene.rate or 1)
  visual:SetPosition(math.min(position,scene.asset.SequenceLength or position),false)
 end
 scene.original,scene.visible,scene.hiddenInGame=mesh,mesh.bVisible,mesh.bHiddenInGame
 scene.hiddenActors,scene.nextHideScan={},now
 self:hideBridgeSix(scene,now)
 c.log('Puente final: tiron de Six aplicado a la malla de '..mesh:GetOwner():GetFullName())
end
function N:clearSixPull()
 local scene=self.sixPull
 self.sixPull=nil
 if not scene then return end
 if self.c.live(scene.original)then
  scene.original:SetVisibility(scene.visible,false)
  scene.original:SetHiddenInGame(not not scene.hiddenInGame,false)
 end
 for _,entry in ipairs(scene.hiddenActors or {})do
  if self.c.live(entry.mesh)then entry.mesh:SetRenderInMainPass(not not entry.wasRendered)end
  if self.c.live(entry.actor)then entry.actor:SetActorHiddenInGame(not not entry.wasHidden)end
 end
 if self.c.live(scene.actor)then scene.actor:K2_DestroyActor()end
end
function N:frameRescue(second)
 local c=self.c
 local pc=c.p1()
 if not(c.live(second)and c.world(pc,second))then return end
 local shot=self.rescueCamera
 if not shot then
  local manager=pc.PlayerCameraManager
  local playerTwo=c.driver.pc
  if c.live(playerTwo) and c.live(playerTwo.PlayerCameraManager)then manager=playerTwo.PlayerCameraManager end
  if not c.live(manager)then return end
  local at=second:K2_GetActorLocation()
  local side=manager:GetCameraLocation().X<at.X and -1 or 1
  -- Frame the handhold and the landing side from the native camera's side.
  local focus={X=at.X,Y=at.Y+85,Z=at.Z+34}
  local position={X=focus.X+side*555,Y=focus.Y-165,Z=focus.Z+114}
  local rotation=c.UE.GetKismetMathLibrary():FindLookAtRotation(position,focus)
  local class=StaticFindObject('/Script/Engine.CameraActor')
  if not c.live(class)then return end
  local actor=pc:GetWorld():SpawnActor(class,position,rotation)
  if not c.live(actor)then return end
  shot={actor=actor,pc=pc,original=pc:GetViewTarget(),position=position,focus=focus}
  self.rescueCamera=shot
  actor.CameraComponent.bConstrainAspectRatio=false
  actor.CameraComponent:SetFieldOfView(49)
  c.log('Puente final: plano del rescate enfocado en P2')
 end
 if c.same(pc,shot.pc) and not c.same(pc:GetViewTarget(),shot.actor)then
  pc:SetViewTargetWithBlend(shot.actor,0,0,0,false)
 end
end
-- Final oculto, por fases: Six agarra a Mono y lo sostiene unos segundos,
-- tira de golpe, cae hacia atrás, queda de rodillas y Mono la abraza.
local sixFall='/Game/Characters/Six/Animations/ANIM_Six_DragImpactBack.ANIM_Six_DragImpactBack'
-- No hay pose de rodillas: Six se sienta en cuclillas y Mono, agachado, la
-- rodea con los brazos (la pose de cargar un objeto grande agachado).
local sixKneel='/Game/Characters/Six/Animations/ANIM_Six_SitDownSquatStart.ANIM_Six_SitDownSquatStart'
local sixKneelLoop='/Game/Characters/Six/Animations/ANIM_Six_SitDownSquatLoop.ANIM_Six_SitDownSquatLoop'
local monoHug='/Game/Characters/Player/Animations/ANIM_Player_CarryMediumCylinderCrouchIdle.ANIM_Player_CarryMediumCylinderCrouchIdle'
N.secretPose={hugDistance=30,pullRate=1.6,
 -- Suelo del puente medido en partidas anteriores (centro de la cápsula de Mono).
 floor={X=-809.3,Y=14103,Z=29186},
 -- Las animaciones normales de Six miran hacia +Y de la malla.
 sixYaw=-90,
 -- Plano cercano del abrazo, en unidades del juego.
 shot={side=300,back=60,up=85,lookUp=34}}
local function now(c,pawn)return c.UE.GetGameplayStatics():GetTimeSeconds(pawn)end
local function yawTo(from,to)return math.deg(math.atan(to.Y-from.Y,to.X-from.X))end
function N:setAnimRate(pawn,rate)
 local mesh=self.c.live(pawn) and pawn.Mesh or nil
 if self.c.live(mesh) then mesh.GlobalAnimRateScale=rate end
end
-- Congela la secuencia del juego (Six sujetando a Mono) mientras dura el agarre.
function N:holdSequences(first,on)
 local c=self.c
 if on then
  self.heldSequences=self.heldSequences or {}
  for _,actor in ipairs(FindAllOf('LevelSequenceActor')or{})do
   local player=c.live(actor) and actor.SequencePlayer or nil
   if c.live(player) and c.world(actor,first) and player:IsPlaying() then
    player:Pause()
    self.heldSequences[#self.heldSequences+1]=player
    c.log('Final oculto: secuencia en pausa '..actor:GetFullName())
   end
  end
 else
  for _,player in ipairs(self.heldSequences or {})do
   if c.live(player) then pcall(function() player:Play() end) end
  end
  self.heldSequences=nil
 end
end
-- El juego puede tener a Mono enganchado a Six o a la cornisa; se suelta
-- antes de moverlo para que la subida y el abrazo no lo devuelvan a la mano.
function N:detach(pawn)
 local c=self.c
 local ok,parent=pcall(function() return pawn:GetAttachParentActor() end)
 if ok and c.live(parent) then
  c.log('Final oculto: Mono estaba unido a '..parent:GetFullName()..'; se suelta')
  pcall(function() pawn:K2_DetachFromActor(1,1,1) end)
 end
end
local function where(p)return string.format('%.0f %.0f %.0f',p.X,p.Y,p.Z)end
-- Agarre: Mono queda sujeto en el punto donde Six lo atrapó. La subida se
-- calcula ya desde ahí y espera, congelada, hasta el tirón.
function N:secretGrab(first)
 local c=self.c
 self.monoClimb=nil
 pcall(self.lift.release,self.lift)
 self:detach(first)
 self:holdSequences(first,true)
 self:setAnimRate(first,0)
 local time=now(c,first)
 local lift=self.lift:prepare(first,time,1.65/N.secretPose.pullRate,nil,N.secretPose.floor)
 if lift then self.liftTarget=lift.plan.target end
 local measured,anchor=pcall(self.secretMeasure,self,first)
 if not measured then c.log('Final oculto: error al medir el puente: '..tostring(anchor));anchor=nil end
 if anchor then
  local started,length=pcall(self.sceneStart,self,first,anchor)
  if not started then
   c.log('Final oculto: error de la escena propia: '..tostring(length))
   pcall(self.sceneClear,self)
  elseif length then
   -- Con la escena propia Mono queda oculto y sujeto en su sitio, sin subir.
   if lift then
    lift.startedAt,lift.collision=time+3600,true
    self.lift:begin(lift)
   end
   return length
  end
 end
 if not lift then c.log('Final oculto: no hay camino para subir a Mono');return end
 lift.startedAt=time+3600
 -- Al terminar la subida Mono necesita colisión para pisar el puente.
 lift.collision=true
 self.lift:begin(lift)
 self.liftTarget=lift.plan.target
 c.log('Final oculto: Mono sujeto en '..where(lift.plan.origin)..'; subira a '..where(lift.plan.target))
end
-- Tirón: Mono sube de golpe por el camino ya calculado y Six tira de él.
function N:secretPull(first)
 local c=self.c
 local rate=N.secretPose.pullRate
 local pull,rise=self:asset(pullPath),self:asset(risePath)
 local override=first.mAnimationOverrideComponent
 if not (pull and rise and c.live(override)) then c.log('Final oculto: faltan las animaciones del tiron');return end
 local time=now(c,first)
 local lift=self.lift.active
 if not lift then
  lift=self.lift:prepare(first,time,1.65/rate,nil,N.secretPose.floor)
  if lift then lift.collision=true;self.lift:begin(lift) end
 end
 if lift then
  lift.startedAt,lift.duration=time,1.65/rate
  self.liftTarget=lift.plan.target
 else
  c.log('Final oculto: Mono no tiene camino de subida')
 end
 self:setAnimRate(first,rate)
 override:PlayAnimationSequenceOverride2(rise,0,false,0,.05,.1)
 self.sixPull={asset=pull,startedAt=time,nextSearch=0,rate=rate}
 return 1.65/rate+.1
end
function N:sixClone()
 local scene=self.sixPull
 local actor=scene and scene.actor
 if self.c.live(actor) then return actor,scene end
end
-- Punto donde se ve a Six ahora (la pelvis), por si la animación la desplazó.
function N:sixBody(actor)
 local visual=actor.SkeletalMeshComponent
 local problem
 for _,bone in ipairs({'pelvis','Pelvis','Hips','hips','root','Root'})do
  local ok,at=pcall(function()
   local name=FName(bone)
   if visual:GetBoneIndex(name)<0 then return end
   return visual:GetSocketLocation(name)
  end)
  if ok and at and at.X then return at,bone end
  if not ok then problem=at end
 end
 if problem and not self.boneWarned then
  self.boneWarned=true
  self.c.log('Final oculto: no se pudo leer la pelvis de Six: '..tostring(problem))
 end
 return actor:K2_GetActorLocation(),'actor'
end
-- Altura de los pies sobre el puente (la cápsula de Mono apoyada en el suelo).
function N:floorFeet(first)
 local floor=self.liftTarget or N.secretPose.floor
 local half=44
 pcall(function() half=first.CapsuleComponent:GetScaledCapsuleHalfHeight() end)
 return floor.Z-half
end
-- Six sale despedida hacia atrás por el tirón y luego queda de rodillas,
-- siempre de cara a Mono y desde donde se la ve, sin saltos.
function N:secretSixPose(kind,first)
 local c=self.c
 local actor,scene=self:sixClone()
 if not actor then c.log('Final oculto: no hay copia de Six para '..kind);return end
 local asset=self:asset(kind=='fall' and sixFall or sixKneel)
 if not asset then c.log('Final oculto: falta la pose de Six '..kind);return end
 local body,bone=self:sixBody(actor)
 -- La copia nace donde estaba la malla de la secuencia, que va por debajo del
 -- suelo; las poses normales necesitan los pies sobre el puente.
 local at={X=body.X,Y=body.Y,Z=c.live(first) and self:floorFeet(first) or actor:K2_GetActorLocation().Z}
 local mono=c.live(first) and first:K2_GetActorLocation() or self.liftTarget or N.secretPose.floor
 local yaw=yawTo(at,mono)+N.secretPose.sixYaw
 actor:K2_SetActorLocationAndRotation(at,{Pitch=0,Yaw=yaw,Roll=0},false,{},true)
 scene.facingFixed=true
 local visual=actor.SkeletalMeshComponent
 visual:PlayAnimation(asset,false)
 visual:SetPlayRate(kind=='fall' and 1.25 or 1)
 c.log(string.format('Final oculto: Six %s en %s (%s), mirando a Mono en %s',
  kind=='fall' and 'cae hacia atras' or 'queda de rodillas',where(at),bone,where(mono)))
 return tonumber(asset.SequenceLength) or 1.2
end
function N:place(pawn,at)
 local c=self.c
 self:detach(pawn)
 pawn:K2_SetActorLocation(at,false,{},true)
 local got=pawn:K2_GetActorLocation()
 if (got.X-at.X)^2+(got.Y-at.Y)^2+(got.Z-at.Z)^2>25 then
  c.log('Final oculto: Mono no se movio a '..where(at)..' (sigue en '..where(got)..')')
 end
end
-- Plano cercano de los dos, desde el mismo lado que la cámara del rescate.
function N:secretShot(six,mono)
 local shot=self.rescueCamera
 if not (shot and self.c.live(shot.actor)) then return end
 local cfg=N.secretPose.shot
 local focus={X=(six.X+mono.X)/2,Y=(six.Y+mono.Y)/2,Z=math.max(six.Z,mono.Z)+cfg.lookUp-40}
 local side=(shot.position.X<focus.X) and -1 or 1
 shot.focus=focus
 shot.position={X=focus.X+side*cfg.side,Y=focus.Y-cfg.back,Z=focus.Z+cfg.up}
 shot.actor:K2_SetActorLocationAndRotation(shot.position,
  self.c.UE.GetKismetMathLibrary():FindLookAtRotation(shot.position,focus),false,{},true)
end
-- Abrazo: Mono, ya en el puente, se pone frente a Six y la abraza.
function N:secretHug(first)
 local c=self.c
 local actor=self:sixClone()
 if not (actor and c.live(first)) then return end
 self.monoClimb=nil
 pcall(self.lift.release,self.lift)
 self:setAnimRate(first,1)
 local six=actor:K2_GetActorLocation()
 local mono=first:K2_GetActorLocation()
 local dx,dy=mono.X-six.X,mono.Y-six.Y
 local length=math.sqrt(dx*dx+dy*dy)
 if length<1 then dx,dy,length=0,1,1 end
 local d=N.secretPose.hugDistance
 local floorZ=(self.liftTarget or N.secretPose.floor).Z
 local at={X=six.X+dx/length*d,Y=six.Y+dy/length*d,Z=floorZ+2}
 pcall(function() first.CharacterMovement:SetMovementMode(1,0) end)
 self:place(first,at)
 first:K2_SetActorRotation({Pitch=0,Yaw=yawTo(at,six),Roll=0},true)
 actor:K2_SetActorRotation({Pitch=0,Yaw=yawTo(six,at)+N.secretPose.sixYaw,Roll=0},true)
 local loop=self:asset(sixKneelLoop)
 if loop then
  actor.SkeletalMeshComponent:PlayAnimation(loop,true)
  actor.SkeletalMeshComponent:SetPlayRate(1)
 end
 local pose=self:asset(monoHug)
 if pose and c.live(first.mAnimationOverrideComponent) then
  first.mAnimationOverrideComponent:PlayAnimationSequenceOverride2(pose,1,true,0,.35,.35)
 end
 self:secretShot(six,at)
 c.log('Final oculto: Mono abraza a Six; Mono en '..where(at)..', Six en '..where(six))
end
function N:secretRelease(first)
 pcall(self.sceneClear,self)
 pcall(self.lift.release,self.lift)
 self:holdSequences(first,false)
 if self.c.live(first) then self:setAnimRate(first,1) end
end
-- Escena propia completa (pak de The Second Shadow): un clip para Mono y otro
-- para Six, animados juntos en Blender sobre el mismo origen. El origen es el
-- punto del suelo del puente justo encima de donde Mono cuelga; las dos copias
-- se colocan ahí con el mismo giro, así que encajan sin colocar nada a mano.
N.customScene={
 mono='/Game/Mods/TheSecondShadow/ANIM_SecretScene_Mono.ANIM_SecretScene_Mono',
 six='/Game/Mods/TheSecondShadow/ANIM_SecretScene_Six.ANIM_SecretScene_Six',
 yaw=0, -- igual que SCENE_YAW en tools/hug-animation
}
-- Medidas del puente para el script de Blender: se escriben en el log.
function N:secretMeasure(first)
 local c=self.c
 local hang=first:K2_GetActorLocation()
 local half,radius=0,0
 pcall(function()
  half=first.CapsuleComponent:GetScaledCapsuleHalfHeight()
  radius=first.CapsuleComponent:GetScaledCapsuleRadius()
 end)
 local floor=self.liftTarget or N.secretPose.floor
 local edge
 pcall(function()
  local movement=first.CharacterMovement
  for step=0,40 do
   local point={X=hang.X,Y=hang.Y+step*5,Z=floor.Z+4}
   local hit={}
   movement:K2_FindFloor(point,hit)
   local distance=hit.bLineTrace and hit.LineDist or hit.FloorDist
   if hit.bBlockingHit and hit.bWalkableFloor and type(distance)=='number' and distance<=60 then
    edge=point.Y;break
   end
  end
 end)
 c.log(string.format('Final oculto: medidas cuelga=%s capsula=%.1f/%.1f suelo=%.1f borde=%s',
  where(hang),half,radius,floor.Z-half,edge and string.format('%.1f',edge) or '?'))
 local mesh=first.Mesh
 pcall(function()
  local r,l=mesh.RelativeRotation,mesh.RelativeLocation
  c.log(string.format('Final oculto: malla de Mono relativa %.1f %.1f %.1f giro %.1f',l.X,l.Y,l.Z,r.Yaw))
 end)
 -- Esqueletos del juego: el proyecto de Unreal debe crearlos en estas rutas.
 pcall(function()
  local pull,rise=self:asset(pullPath),self:asset(risePath)
  c.log('Final oculto: esqueleto de Six '..(pull and pull.Skeleton:GetFullName() or '?')
   ..'; esqueleto de Mono '..(rise and rise.Skeleton:GetFullName() or '?'))
 end)
 pcall(function()
  local six=self:findSix(first,self:asset(pullPath))
  if six then
   local r=six:K2_GetComponentRotation()
   c.log('Final oculto: Six de la secuencia en '..where(six:K2_GetComponentLocation())
    ..string.format(' giro %.1f',r.Yaw))
  end
 end)
 return {X=hang.X,Y=hang.Y,Z=floor.Z-half}
end
local function copyMesh(world,class,source,at,rotation,c)
 local actor=world:SpawnActor(class,at,rotation)
 if not c.live(actor) then return end
 local visual=actor.SkeletalMeshComponent
 actor:SetActorEnableCollision(false)
 visual:SetMobility(2)
 visual:SetCollisionEnabled(0)
 visual:SetSkeletalMesh(source.SkeletalMesh,false)
 for i=0,source:GetNumMaterials()-1 do visual:SetMaterial(i,source:GetMaterial(i))end
 return actor
end
-- Devuelve la duración de la escena, o nil si el pak no está instalado.
function N:sceneStart(first,anchor)
 local c=self.c
 local monoClip,sixClip=self:asset(N.customScene.mono),self:asset(N.customScene.six)
 if not (monoClip and sixClip) then return end
 local class=StaticFindObject('/Script/Engine.SkeletalMeshActor')
 local six=self:findSix(first,self:asset(pullPath))
 if not (c.live(class) and six and c.live(first.Mesh)) then
  c.log('Final oculto: no se pudo preparar la escena propia');return
 end
 local world=first:GetWorld()
 local rotation={Pitch=0,Yaw=N.customScene.yaw,Roll=0}
 local scene={actors={}}
 self.secretScene=scene
 local main=copyMesh(world,class,first.Mesh,anchor,rotation,c)
 if not main then self:sceneClear();return end
 scene.actors[#scene.actors+1]=main
 -- Partes extra de Mono (si las tiene) siguen la pose de la malla principal.
 local meshClass=StaticFindObject('/Script/Engine.SkeletalMeshComponent')
 if c.live(meshClass) then
  for _,part in ipairs(unwrapObjects(first:K2_GetComponentsByClass(meshClass)))do
   if c.live(part) and not c.same(part,first.Mesh) and c.live(part.SkeletalMesh) and part:IsVisible() then
    local extra=copyMesh(world,class,part,anchor,rotation,c)
    if extra then
     scene.actors[#scene.actors+1]=extra
     extra:K2_AttachToActor(main,FName('None'),1,1,1,false)
     extra.SkeletalMeshComponent:SetMasterPoseComponent(main.SkeletalMeshComponent,false)
    end
   end
  end
 end
 local sixActor=copyMesh(world,class,six,anchor,rotation,c)
 if not sixActor then self:sceneClear();return end
 local time=now(c,first)
 -- Reutiliza el ocultado de la Six del juego del rescate normal.
 self.sixPull={asset=sixClip,startedAt=time,nextSearch=0,actor=sixActor,original=six,
  visible=six.bVisible,hiddenInGame=six.bHiddenInGame,hiddenActors={},nextHideScan=time}
 self:hideBridgeSix(self.sixPull,time)
 scene.pawn=first
 first:SetActorHiddenInGame(true)
 main.SkeletalMeshComponent:PlayAnimation(monoClip,false)
 sixActor.SkeletalMeshComponent:PlayAnimation(sixClip,false)
 local length=math.max(tonumber(monoClip.SequenceLength) or 0,tonumber(sixClip.SequenceLength) or 0)
 local shot=self.rescueCamera
 if shot then shot.focus={X=anchor.X,Y=anchor.Y+25,Z=anchor.Z+35} end
 c.log(string.format('Final oculto: escena propia de %.1f s en %s',length,where(anchor)))
 return length
end
function N:sceneClear()
 local scene=self.secretScene
 self.secretScene=nil
 if not scene then return end
 for _,actor in ipairs(scene.actors)do
  if self.c.live(actor) then pcall(function() actor:K2_DestroyActor() end) end
 end
 if self.c.live(scene.pawn) then pcall(function() scene.pawn:SetActorHiddenInGame(false) end) end
end
-- Lista de animaciones de Six y Mono del juego, para elegir mejores poses.
function N:animationNames()
 local c=self.c
 local names,seen={},{}
 local function add(text)
  if type(text)=='string' and text~='' and not seen[text] then seen[text]=true;names[#names+1]=text end
 end
 local registry=FindFirstOf('AssetRegistryImpl')
 if c.live(registry) then
  for _,path in ipairs({'/Game/Characters/Six','/Game/Characters/Player','/Game/Characters/Mono'})do
   local found={}
   if pcall(function() registry:GetAssetsByPath(FName(path),found,true,false) end) then
    for i=1,#found do
     local entry=found[i]
     if entry and type(entry.get)=='function' then entry=entry:get() end
     pcall(function() add(entry.AssetClass:ToString()..' '..entry.ObjectPath:ToString()) end)
    end
   end
  end
 end
 for _,asset in ipairs(FindAllOf('AnimSequence')or{})do
  pcall(function()
   local name=asset:GetFullName()
   if name:find('/Characters/',1,true) then add(name) end
  end)
 end
 table.sort(names)
 return names
end
-- Final oculto: abrazo compuesto con poses del juego (hasta tener la animación
-- propia). Mono queda agotado de rodillas y Six se agacha pegada a él, de frente.
local hugMono='/Game/Characters/Player/Animations/ANIM_Player_ExhaustedCrouchIdle.ANIM_Player_ExhaustedCrouchIdle'
local hugSix='/Game/Characters/Six/Animations/ANIM_Six_CrouchIdleShift.ANIM_Six_CrouchIdleShift'
N.hugOffset={side=48,forward=34,meshYaw=-90}
N.customHug={
 mono='/Game/Mods/TheSecondShadow/ANIM_SecretHug_Mono.ANIM_SecretHug_Mono',
 six='/Game/Mods/TheSecondShadow/ANIM_SecretHug_Six.ANIM_SecretHug_Six',
 distance=30, -- igual que DISTANCE en tools/hug-animation/abrazo_blender.py
}
function N:composeHug(first,now)
 local c=self.c
 local scene=self.sixPull
 local actor=scene and scene.actor
 if not (c.live(first) and c.live(actor)) then return end
 local hug=self.hug
 if not hug or not c.same(hug.first,first) then
  -- La subida terminó: nada más debe mover a Mono durante el abrazo. Si la
  -- secuencia del juego lo dejó colgando o a medio subir, se le pone de pie sobre el puente.
  self.monoClimb=nil
  pcall(self.lift.release,self.lift)
  local floor=self.liftTarget
  local standing=first:K2_GetActorLocation()
  if floor and (math.abs(standing.Z-floor.Z)>15 or (standing.X-floor.X)^2+(standing.Y-floor.Y)^2>60^2) then
   first.mAnimationOverrideComponent:StopAnimationSequenceOverride(true)
   first:K2_SetActorLocation({X=floor.X,Y=floor.Y,Z=floor.Z+2},false,{},true)
   pcall(function() first.CharacterMovement:SetMovementMode(1,0) end)
   c.log(string.format('Final oculto: Mono colocado sobre el puente (estaba en %.0f %.0f %.0f)',standing.X,standing.Y,standing.Z))
  end
  -- Animación propia (pak del mod) si está instalada; si no, poses del juego.
  local customMono,customSix=self:asset(N.customHug.mono),self:asset(N.customHug.six)
  local custom=customMono and customSix
  local monoPose,sixPose=customMono or self:asset(hugMono),customSix or self:asset(hugSix)
  if custom then c.log('Final oculto: usando la animacion propia del abrazo') end
  if not (monoPose and sixPose) then c.log('Final oculto: faltan las poses del abrazo');self.hug={first=first};return end
  local visual=actor.SkeletalMeshComponent
  if custom then
   -- Las dos animaciones propias se hacen en Blender con Six enfrente de Mono,
   -- a N.customHug.distance; aquí se repite esa colocación.
   local mesh=first.Mesh
   local at=mesh:K2_GetComponentLocation()
   local rotation=mesh:K2_GetComponentRotation()
   local forward=first:GetActorForwardVector()
   local d=N.customHug.distance
   actor:K2_SetActorLocationAndRotation({X=at.X+forward.X*d,Y=at.Y+forward.Y*d,Z=at.Z},
    {Pitch=rotation.Pitch,Yaw=(rotation.Yaw+180)%360,Roll=rotation.Roll},false,{},true)
   visual:PlayAnimation(sixPose,false)
   visual:SetPlayRate(1)
   self.hug={first=first,pose=monoPose,length=tonumber(monoPose.SequenceLength) or 8,once=true}
   hug=self.hug
  else
  local at=first:K2_GetActorLocation()
  local forward=first:GetActorForwardVector()
  local right={X=-forward.Y,Y=forward.X}
  local o=N.hugOffset
  local sixAt={X=at.X+right.X*o.side+forward.X*o.forward,Y=at.Y+right.Y*o.side+forward.Y*o.forward,
   Z=first.Mesh:K2_GetComponentLocation().Z}
  local toMono=math.deg(math.atan(at.Y-sixAt.Y,at.X-sixAt.X))
  actor:K2_SetActorLocationAndRotation(sixAt,{Pitch=0,Yaw=toMono+o.meshYaw,Roll=0},false,{},true)
  visual:PlayAnimation(sixPose,true)
  visual:SetPlayRate(.8)
  first:K2_SetActorRotation({Pitch=0,Yaw=(toMono+180)%360,Roll=0},true)
  hug={first=first,pose=monoPose,length=tonumber(monoPose.SequenceLength) or 3}
  self.hug=hug
  c.log(string.format('Final oculto: abrazo compuesto; Six en %.0f %.0f %.0f mirando a %.0f',sixAt.X,sixAt.Y,sixAt.Z,toMono))
 end
 end
 if hug.pose and (not hug.nextAt or now>=hug.nextAt) and c.live(first.mAnimationOverrideComponent) then
  first.mAnimationOverrideComponent:PlayAnimationSequenceOverride2(hug.pose,1,false,0,hug.nextAt and 0 or .25,.25)
  hug.nextAt=hug.once and math.huge or now+math.max(.5,hug.length-.05)
 end
end
function N:clearHug()
 local hug=self.hug
 self.hug=nil
 if hug and hug.pose and self.c.live(hug.first) and self.c.live(hug.first.mAnimationOverrideComponent) then
  pcall(function() hug.first.mAnimationOverrideComponent:StopAnimationSequenceOverride(true) end)
 end
end
-- Final oculto: acerca poco a poco el plano del rescate a los dos personajes.
function N:pushIn(progress)
 local shot=self.rescueCamera
 if not (shot and self.c.live(shot.actor) and shot.position) then return end
 local eased=progress*progress*(3-2*progress)
 local from,to=shot.position,shot.focus
 local amount=.38*eased
 local at={X=from.X+(to.X-from.X)*amount,Y=from.Y+(to.Y-from.Y)*amount,Z=from.Z+(to.Z-from.Z)*amount-30*eased}
 local rotation=self.c.UE.GetKismetMathLibrary():FindLookAtRotation(at,to)
 shot.actor:K2_SetActorLocationAndRotation(at,rotation,false,{},true)
end
function N:fade(duration)
 local pc=self.c.p1()
 local manager=self.c.live(pc) and pc.PlayerCameraManager or nil
 if not self.c.live(manager) then return end
 manager:StartCameraFade(0,1,duration,{R=0,G=0,B=0,A=1},true,true)
 self.faded=manager
end
function N:clearFade()
 local manager=self.faded
 self.faded=nil
 if self.c.live(manager) then pcall(function() manager:StopCameraFade() end) end
end
function N:card(text)
 local manager=FindFirstOf('WidgetManager')
 local pc=self.c.p1()
 local world=self.c.live(pc) and pc:GetWorld() or nil
 if not (self.c.live(manager) and self.c.live(world)) then self.c.log(text);return end
 manager:ShowHintWidget(world,FText(text),5)
end
local creditsPath='/Game/Blueprints/Widgets/Menues/WDG_CreditsScreen.WDG_CreditsScreen_C'
function N:credits()
 local c=self.c
 local pc=c.p1()
 if not c.live(pc) then return false end
 local class=StaticFindObject(creditsPath)
 if not c.live(class) then pcall(LoadAsset,creditsPath);class=StaticFindObject(creditsPath)end
 local library=StaticFindObject('/Script/UMG.Default__WidgetBlueprintLibrary')
 if not (c.live(class) and c.live(library)) then return false end
 local widget=library:Create(pc,class,pc)
 if not c.live(widget) then return false end
 pcall(function() widget.AccessedFromMenu=false end)
 widget:AddToViewport(100)
 pcall(function() widget:SetKeyboardFocus() end)
 self.creditsWidget=widget
 return true
end
function N:releaseCamera()
 local shot=self.rescueCamera
 self.rescueCamera=nil
 if not shot then return end
 local c=self.c
 if c.same(shot.pc,c.p1())and c.same(shot.pc:GetViewTarget(),shot.actor)then
  local target=c.live(shot.original) and shot.original or shot.pc.Pawn
  if c.world(shot.pc,target)then shot.pc:SetViewTargetWithBlend(target,0,0,0,false)end
 end
 if c.live(shot.actor)then shot.actor:K2_DestroyActor()end
end
function N:pull(second,rate)
 local c=self.c
 local pull=self:asset(pullPath)
 local ledgeClass=StaticFindObject('/Script/Helios.LedgeClimbingInterface')
 local ledge=c.live(ledgeClass)and second:GetComponentByClass(ledgeClass)or nil
 local climb=c.live(ledge)and ledge.mClimbFromHangParams.mAnimation or nil
 local nativeClimb=c.live(climb)
 local rise=nativeClimb and climb or self:asset(risePath)
 local override=second.mAnimationOverrideComponent
 if not (rise and pull and c.live(override))then c.log('Puente final: faltan las animaciones del rescate');return end
 c.driver:stop()
 local now=c.UE.GetGameplayStatics():GetTimeSeconds(second)
 local origin=second:K2_GetActorLocation()
 local monoLength=tonumber(rise.SequenceLength)or 1.65
 local checked,lift=pcall(self.lift.prepare,self.lift,second,now,1.65/(rate or 1))
 if not checked then
  c.log('Puente final: error al comprobar el suelo de P2: '..tostring(lift))
  lift=nil
 end
 -- El final oculto necesita saber dónde queda el suelo del puente.
 self.liftTarget=lift and lift.plan and lift.plan.target or nil
 override:PlayAnimationSequenceOverride2(rise,nativeClimb and 2 or (lift and 0 or 2),false,0,.05,.1)
 self.sixPull={asset=pull,startedAt=now,nextSearch=0,rate=rate}
 if nativeClimb then
  self.monoClimb={pawn=second,origin=origin,startedAt=now,lift=lift,
   deadline=math.min(1.2,math.max(.6,monoLength*.6)),latest=math.min(2,monoLength+.15)}
  c.log('Puente final: subida nativa de cornisa '..climb:GetFullName())
 elseif lift then
  local begun,problem=pcall(self.lift.begin,self.lift,lift)
  if not begun then
   pcall(self.lift.release,self.lift)
   c.log('Puente final: error al iniciar la subida de P2: '..tostring(problem))
  end
 end
 return (nativeClimb and math.max(monoLength,2.15)or 1.65)/(rate or 1)
end
function N:updateMonoClimb(pawn,now)
 local attempt=self.monoClimb
 if not attempt then return end
 local c=self.c
 if not c.same(attempt.pawn,pawn)then self.monoClimb=nil;return end
 local at=pawn:K2_GetActorLocation()
 local vertical,forward=at.Z-attempt.origin.Z,at.Y-attempt.origin.Y
 if vertical>=30 and forward>=45 and pawn.CharacterMovement.MovementMode==1 then
  self.monoClimb=nil
  c.log('Puente final: la subida nativa dejo a P2 sobre la plataforma')
 elseif now-attempt.startedAt>=(vertical>=15 and forward>=10 and attempt.latest or attempt.deadline) then
  self.monoClimb=nil
  if attempt.lift then
   attempt.lift.startedAt=now
   self.lift:begin(attempt.lift)
   c.log('Puente final: la subida nativa necesita completar la llegada al suelo')
  end
 end
end
function N:chair(first)
 local name=(self:animation(first)or ''):lower()
 if name:find('chair',1,true)or name:find('throne',1,true)
  or name:find('_sit',1,true)or name:find('sitdown',1,true)or name:find('sitting',1,true)then return true end
 local c=self.c
 local now=c.UE.GetGameplayStatics():GetTimeSeconds(first)
 if self.nextChairScan and now>=self.nextChairScan-.3 and now<self.nextChairScan then return false end
 self.nextChairScan=now+.3
 for _,actor in ipairs(FindAllOf('LevelSequenceActor')or{})do
  if c.world(actor,first) and c.live(actor.SequencePlayer) and actor.SequencePlayer:IsPlaying()then
   local sequence=actor:GetSequence()
   local path=(actor:GetFullName()..' '..(c.live(sequence)and sequence:GetFullName()or '')):lower()
   if path:find('chair',1,true)or path:find('throne',1,true)then return true end
  end
 end
 return false
end
function N:clearShadow()
 local actor=self.shadowActor
 local audio,id=self.shadowAudio,self.shadowSound
 self.shadowActor,self.shadowPawn,self.shadowPosition,self.shadowTime=nil,nil,nil,nil
 self.shadowAudio,self.shadowSound,self.departureScale=nil,nil,nil
 self.nextChairScan=nil
 if id and self.c.live(audio) then
  pcall(audio.ExecuteActionOnPlayingID,audio,0,id,100,4)
 end
 if self.c.live(actor)then actor:K2_DestroyActor()end
end
function N:shadow(first,now)
 local c=self.c
 local mesh=first.Mesh
 if not(c.live(mesh)and c.live(mesh.SkeletalMesh))then return end
 if not c.same(self.shadowPawn,first)then self:clearShadow()end
 local at=mesh:K2_GetComponentLocation()
 local facing=first:GetActorForwardVector()
 local rotation=mesh:K2_GetComponentRotation()
 local desired={X=at.X-facing.X*78,Y=at.Y-facing.Y*78,Z=at.Z}
 if not c.live(self.shadowActor)then
  local material=self:asset(shadowPath)
  local class=StaticFindObject('/Script/Engine.SkeletalMeshActor')
  if not(material and c.live(class))then return end
  local actor=first:GetWorld():SpawnActor(class,desired,rotation)
  if not c.live(actor)then return end
  self.shadowActor,self.shadowPawn,self.shadowPosition=actor,first,desired
  actor:SetActorEnableCollision(false)
  local visual=actor.SkeletalMeshComponent
  visual:SetMobility(2)
  visual:SetCollisionEnabled(0)
  visual:SetSkeletalMesh(mesh.SkeletalMesh,false)
  visual:SetMasterPoseComponent(mesh,true)
  for i=0,visual:GetNumMaterials()-1 do visual:SetMaterial(i,material)end
 end
 local current=self.shadowPosition
 local dt=self.shadowTime and now-self.shadowTime or 0
 self.shadowTime=now
 if dt<0 or (current.X-desired.X)^2+(current.Y-desired.Y)^2+(current.Z-desired.Z)^2>520^2 then
  current=desired
  self.shadowPosition=current
 else
  local blend=1-math.exp(-7.7*dt)
  for _,axis in ipairs({'X','Y','Z'})do current[axis]=current[axis]+(desired[axis]-current[axis])*blend end
 end
 self.shadowActor:K2_SetActorLocationAndRotation(current,rotation,false,{},true)
end
function N:dissolveAt(actor)
 if self.c.live(actor)then
  local effect=self:asset(dissolvePath)
  if effect then
   return self.c.UE.GetGameplayStatics():SpawnEmitterAtLocation(actor,effect,actor:K2_GetActorLocation(),
    actor:K2_GetActorRotation(),{X=.25,Y=.25,Z=.25},true,0,true)
  end
 end
end
function N:beginDissolve(first)
 local c=self.c
 local actor=self.shadowActor
 if not c.world(actor,first) then return end
 local scale=actor:GetActorScale3D()
 self.departureScale={X=scale.X,Y=scale.Y,Z=scale.Z}
 self:dissolveAt(actor)
 local ok,err=pcall(function()
  local audio=StaticFindObject('/Script/AkAudio.Default__AkGameplayStatics')
  local sound=self:asset(staticPath)
  if not (c.live(audio) and sound) then return end
  local id=audio:PostEventAtLocation(sound,actor:K2_GetActorLocation(),actor:K2_GetActorRotation(),'',first)
  if type(id)=='number' and id~=0 then self.shadowAudio,self.shadowSound=audio,id end
 end)
 if not ok then c.log('Final: error de la estatica de P2: '..tostring(err))end
end

function N:dissolve(progress)
 if progress>=1 then self:clearShadow();return end
 local scale=self.departureScale
 if not scale or not self.c.live(self.shadowActor) then return end
 local size=1-.92*progress^2
 self.shadowActor:SetActorScale3D({X=scale.X*size,Y=scale.Y*size,Z=scale.Z*size})
end

function N:reactToBetrayal(first,second)
 local c=self.c
 if not (c.world(second,first) and second:IsAlive()) then return end
 local at,other=first:K2_GetActorLocation(),second:K2_GetActorLocation()
 if (at.X-other.X)^2+(at.Y-other.Y)^2>460^2 or math.abs(at.Z-other.Z)>240 then return end
 return c.playPose(second,'ANIM_Player_ReactSixFall',at)
  or c.playPose(second,'ANIM_Player_HandHoldOpenHandIdle',at)
end
function N:api()
 local c=self.c
 local function visual(action,...)
  if self.visualFailed then return end
  local ok,err=pcall(action,self,...)
  if not ok then
   self.visualFailed=true
   pcall(self.clearShadow,self)
   c.log('Final: error de la sombra: '..tostring(err))
  end
 end
 return {live=c.live,same=c.same,log=c.log,
  animation=function(p)return self:animation(p)end,pull=function(p)return self:pull(p)end,
  chair=function(p)return self:chair(p)end,shadow=function(p,now)visual(self.shadow,p,now)end,
  beginDissolve=function(p)visual(self.beginDissolve,p)end,dissolve=function(progress)visual(self.dissolve,progress)end,
  clearShadow=function()self:clearShadow();self.visualFailed=nil end,
  frameRescue=function(p)
   if (self.monoClimb or self.lift.active)and c.live(p)then
    local now=c.UE.GetGameplayStatics():GetTimeSeconds(p)
    local worked,problem=pcall(function()
     self:updateMonoClimb(p,now)
     self.lift:update(p,now)
    end)
    if not worked then
     self.monoClimb=nil
     pcall(self.lift.release,self.lift)
     c.log('Puente final: error al subir a P2: '..tostring(problem))
    end
   end
   local ok,err=xpcall(self.updateSix,debug and debug.traceback or tostring,self,p)
   if not ok then
    pcall(self.clearSixPull,self)
    c.log('Puente final: error al animar a Six: '..tostring(err))
   end
   if self.cameraFailed then return end
   ok,err=pcall(self.frameRescue,self,p)
   if not ok then
    self.cameraFailed=true
    pcall(self.releaseCamera,self)
    c.log('Puente final: error al enfocar a P2: '..tostring(err))
   end
  end,
  releaseCamera=function()
   self.monoClimb=nil
   local released,liftError=pcall(self.lift.release,self.lift)
   if not released then c.log('Puente final: error al liberar a P2: '..tostring(liftError))end
   local cleared,problem=pcall(self.clearSixPull,self)
   if not cleared then c.log('Puente final: error al restaurar a Six: '..tostring(problem))end
   local ok,err=pcall(self.releaseCamera,self)
   self.cameraFailed=nil
   if not ok then c.log('Puente final: error al restaurar la camara: '..tostring(err))end
  end,
  secretGrab=function(p)
   local ok,result=pcall(self.secretGrab,self,p)
   if not ok then c.log('Final oculto: error al sostener el agarre: '..tostring(result));return end
   return result
  end,
  secretPull=function(p)
   local ok,length=pcall(self.secretPull,self,p)
   if not ok then c.log('Final oculto: error del tiron: '..tostring(length));return end
   return length
  end,
  secretSixPose=function(kind,p)
   local ok,length=pcall(self.secretSixPose,self,kind,p)
   if not ok then c.log('Final oculto: error en la pose de Six: '..tostring(length));return end
   return length
  end,
  secretHug=function(p)
   local ok,err=pcall(self.secretHug,self,p)
   if not ok then c.log('Final oculto: error del abrazo: '..tostring(err)) end
  end,
  secretRelease=function(p)pcall(self.secretRelease,self,p)end,
  hug=function(p,now)
   if self.hugFailed then return end
   local ok,err=pcall(self.composeHug,self,p,now)
   if not ok then self.hugFailed=true;c.log('Final oculto: error del abrazo: '..tostring(err)) end
  end,
  clearHug=function()pcall(self.clearHug,self);self.hugFailed=nil end,
  pushIn=function(progress)
   if self.cameraFailed then return end
   local ok,err=pcall(self.pushIn,self,progress)
   if not ok then c.log('Final oculto: error al acercar la camara: '..tostring(err)) end
  end,
  fade=function(duration)
   local ok,err=pcall(self.fade,self,duration)
   if not ok then c.log('Final oculto: error del fundido: '..tostring(err)) end
  end,
  clearFade=function()self:clearFade()end,
  card=function(text)
   local ok,err=pcall(self.card,self,text)
   if not ok then c.log('Final oculto: error del texto: '..tostring(err)) end
  end,
  credits=function()return self:credits()end,
  stopSecond=function()c.driver:stop()end,parkSecond=function()c.driver:remove()end,
  reactPartner=function(caught,companion,role)
   local ok,clip=pcall(self.reactToBetrayal,self,caught,companion)
   if ok then
    if clip then c.log('Puente final: P'..role..' intenta alcanzar a P'..(3-role)) end
    return clip
   end
   c.log('Puente final: error en la reaccion de P2: '..tostring(clip))
  end,
  stopReaction=function(pawn,clip)
   local ok,err=pcall(c.stopPose,pawn,clip)
   if not ok then c.log('Puente final: error al liberar la reaccion: '..tostring(err)) end
  end}
end
return N
