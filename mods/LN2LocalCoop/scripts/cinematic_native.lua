-- Match observed story clips explicitly. Each profile owns only P2's response.
local Raft=require('cinematic_raft')
local N={};N.__index=N
local function animationPath(name)
 return '/Game/Characters/Player/Animations/'..name..'.'..name
end
local wilderness='/Game/Levels/Wilderness/PLVL_Wilderness.'
local school='/Game/Levels/School/PLVL_School.'
local hospital='/Game/Levels/Hospital/PLVL_Hospital.'
local transmission='/Game/Levels/Transmission/PLVL_Transmission.'
local paleCity='/Game/Levels/PaleCity/PLVL_PaleCIty.'
local reactionPath=animationPath('ANIM_Player_DragPullStepBack')
local hunterShot='ANIM_Player_HunterShedShoot_SideA'
local hunterPickup='ANIM_Player_HunterShedGrabRifleFall'
local doctorGrab='/Script/Helios.DoctorBedLiftingPattern:OnTargetGrabbed'
local profiles={}
local function profile(source,chapter,scene,response,options)
 local entry=options or {}
 entry.chapter,entry.scene,entry.response=chapter,scene,response
 profiles['AnimSequence '..animationPath(source)]=entry
end
profile('ANIM_Player_CallSixunderBedFullScene',wilderness,'mesa')
profile(hunterShot,wilderness,'cazador')
profile(hunterPickup,wilderness,'cazador',nil,{prepare=true})
profile('ANIM_Player_FallOutOfTrunk',wilderness,'caida del tronco',reactionPath,{followThrough=true})
profile('ANIM_Player_FallDownFoxHole',wilderness,'caida en la madriguera',reactionPath,
 {followThrough=true,bounds={-5400,-4500,20100,20950,-350,220}})
profile('ANIM_Player_Hoist300_FallEnd',school,'caida en la Escuela',reactionPath,
 {followThrough=true,moving=true,bounds={-3200,-2850,-29780,-29450,-2180,-1940}})
profile('ANIM_Player_ReactSixFall',wilderness,'caida de Six',reactionPath)
profile('ANIM_Player_ShedHatch_PushAndFall',wilderness,'escotilla del sotano',reactionPath)
profile('ANIM_Player_BarnFloorBreak',wilderness,'derrumbe del granero')
profile('ANIM_Player_BarnToSwamp',wilderness,'salida del granero')
profile('ANIM_Player_HittingMusicBoxVoidLong',transmission,'caja musical',reactionPath)
profiles[doctorGrab]={chapter=hospital,scene='Doctor'}
local kitchen='/Game/Levels/PaleCity/SubLevels/LVL_4_280_KitchenTVSneak.LVL_4_280_KitchenTVSneak:PersistentLevel.'
local clothesline='/Game/Levels/PaleCity/SubLevels/LVL_4_375_TVClothesline.LVL_4_375_TVClothesline:PersistentLevel.'
local sequenceProfiles={}
local function sequenceProfile(chapter,level,asset,instance,options)
 local sequence='LevelSequence /Game/Levels/'..level..'/LevelSequencers/'..asset..'.'..asset
 local chapterProfiles=sequenceProfiles[chapter] or {}
 options.key=sequence
 chapterProfiles[#chapterProfiles+1]=options
 sequenceProfiles[chapter]=chapterProfiles
 profiles[sequence]=options
 options.actors={}
 for _,path in ipairs(instance) do
  options.actors[#options.actors+1]='BP_HeliosLevelSequence_C '..path
 end
end
sequenceProfile(paleCity,'PaleCity','SEQ_280_WindowCrash',{kitchen..'BP_SEQ_WindowCrash'},
 {scene='ventana de la cocina',response=reactionPath,trigger=kitchen..'Trigger_WindowCrash'})
sequenceProfile(paleCity,'PaleCity','SEQ_4_375_TVClothesline_DoorFalls',{clothesline..'BP_HeliosLevelSequence_2'},
 {scene='puerta del tendedero',response=reactionPath,trigger=clothesline..'PP_DoorHandle_RightOnly2_2'})
sequenceProfile(wilderness,'Wilderness','SEQ_1_580_DoorRide',Raft.sequenceActors,
 {scene='balsa',raft=true})

-- Bounds around the native motion and landings in
-- backups/rescate-extras-20261115-001812/UE4SS.log.
local barnRoutes={
 ['derrumbe del granero']={
  entrance={-5260,-4970,33010,33210,540,780},
  approach={-5550,-4620,32350,33230,505,870},
  arrival={-5500,-4700,33300,33760,620,890},
 },
 ['salida del granero']={
  entrance={-5070,-4730,35362,35702,704,964},
  approach={-5600,-4500,32250,35750,450,1000},
  arrival={-5460,-4260,35720,36900,-455,-195},
 },
}

local function inside(bounds,at)
 return at.X>=bounds[1] and at.X<=bounds[2] and at.Y>=bounds[3] and at.Y<=bounds[4]
  and at.Z>=bounds[5] and at.Z<=bounds[6]
end

local function findAnimation(c,path)
 local asset=StaticFindObject(path)
 if not c.live(asset)then
  pcall(LoadAsset,path)
  asset=StaticFindObject(path)
 end
 return c.live(asset) and asset or nil
end

-- Root-motion copies may play audio on each pawn. Unknown notify objects,
-- notify states and named AnimBP events can advance a single-player script.
local function audioOnly(c,asset)
 local ok,safe=pcall(function()
  local notifies=asset.Notifies
  if not notifies then return false end
  for index=1,#notifies do
   local event=notifies[index]
   local notify=event.Notify
   if c.live(event.NotifyStateClass) or not c.live(notify)
    or not notify:GetFullName():match('^AnimNotify_AkEvent_C ') then return false end
  end
  return true
 end)
 return ok and safe
end

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
 ok,err=pcall(function()
  if not self.c.live(StaticFindObject(doctorGrab)) then return end
  RegisterHook(doctorGrab,function()end,function(_,_,target)
   local worked,problem=pcall(function()self:doctorCaught(target:get())end)
   if not worked and self.doctorError~=problem then
    self.doctorError=problem
    self.c.log('Escena del Doctor: '..tostring(problem))
   end
  end)
 end)
 if not ok then self.c.log('No se pudo enlazar el agarre del Doctor: '..tostring(err))end
end
function N:pair()
 local c=self.c;local pc=c.p1();local p=pc and pc.Pawn;local q=c.driver.pawn
 if not c.state.enabled or not(c.live(p)and c.live(q)and c.live(c.driver.pc))then return end
 if not c.world(p,q)or not c.same(q.Controller,c.driver.pc)or not c.same(c.driver.pc.Pawn,q)
  or not c.same(p.Controller,pc)or c.same(p,q)then return end
 return p,q,pc
end
function N:doctorCaught(caught)
 local c=self.c
 local first,second,pc=self:pair()
 if not first or not first:GetFullName():find(hospital,1,true)
  or c.spawn.phase~='active' or c.spawn.pending or c.death.pending
  or c.state.menu or c.UE.GetGameplayStatics():IsGamePaused(pc) then return end
 local companion
 if c.same(caught,first) then companion=second
 elseif c.same(caught,second) then companion=first
 else return end
 if not companion:IsAlive() then return end
 local at,other=caught:K2_GetActorLocation(),companion:K2_GetActorLocation()
 if (at.X-other.X)^2+(at.Y-other.Y)^2>450^2 or math.abs(at.Z-other.Z)>150 then return end
 local now=c.UE.GetGameplayStatics():GetTimeSeconds(pc)
 local previous=self.lastDoctor
 if previous and c.same(previous.actor,caught) and now>=previous.at and now-previous.at<1 then return end
 self.lastDoctor={actor=caught,at=now}
 self.doctorCue={first=first,second=second,caught=caught,companion=companion,at=at,time=now}
 c.log('Cinematica Doctor: agarre nativo de P'..(c.same(caught,first) and '1' or '2'))
end

function N:snapshot(firstPath)
 local c=self.c
 local p,q,pc=self:pair()
 if not p then return end
 local ac=p.mAnimationControlComponent
 if not c.live(ac)then return end
 local asset=ac.mCurrentAnimStateAsset
 local name=c.live(asset)and asset:GetFullName()
 firstPath=firstPath or p:GetFullName()
 local profile=name and profiles[name]
 if profile and (not ac:IsPlayingOverrideAnimation() or not firstPath:find(profile.chapter,1,true)) then profile=nil end
 if not profile and c.sequence then
  profile,asset=self:activeSequence(firstPath,p)
  if profile then name=profile.key end
 end
 local now=c.UE.GetGameplayStatics():GetTimeSeconds(pc)
 local doctor=self.doctorCue
 self.doctorCue=nil
 if not profile and doctor and firstPath:find(hospital,1,true) and now>=doctor.time and now-doctor.time<=.25
  and c.same(doctor.first,p)and c.same(doctor.second,q) then
  name,profile=doctorGrab,profiles[doctorGrab]
 end
 return {first=p:GetAddress(),second=q:GetAddress(),p=p,q=q,asset=asset,key=profile and name,
  doctor=doctor,allowInput=profile and (profile.trigger~=nil or profile.moving or name==doctorGrab),
  ready=c.spawn.phase=='active'and not c.spawn.pending and not c.death.pending and p:IsAlive()and q:IsAlive(),
  paused=c.state.menu or c.UE.GetGameplayStatics():IsGamePaused(pc),
  now=now}
end
function N:owns(q,asset)
 local c=self.c
 if not (c.live(asset) and c.live(q)) then return false end
 local ac=q.mAnimationControlComponent
 return c.live(ac) and ac:IsPlayingOverrideAnimation() and c.same(ac.mCurrentAnimStateAsset,asset)
end
function N:stopLocalPose(q,asset,allowPrimary)
 local c=self.c
 local pc=allowPrimary and c.p1()
 if (c.same(q,c.driver.pawn) or (pc and c.same(q,pc.Pawn)))
  and self:owns(q,asset) and c.live(q.mAnimationOverrideComponent) then
  q.mAnimationOverrideComponent:StopAnimationSequenceOverride(true)
 end
end
function N:playLocalPose(q,name,target,away)
 local c=self.c
 if not self:available(q) then return end
 local asset=findAnimation(c,animationPath(name))
 local duration=asset and asset.SequenceLength
 if type(duration)~='number' or duration<=0 or not audioOnly(c,asset) then return end
 if c.same(q,c.driver.pawn) then c.driver:stop() end
 q.CharacterMovement:StopMovementImmediately()
 local at=q:K2_GetActorLocation()
 local dx,dy=target.X-at.X,target.Y-at.Y
 if dx^2+dy^2>1 then
  local sign=away and -1 or 1
  q:K2_SetActorRotation({Pitch=0,Yaw=math.deg(math.atan(sign*dy,sign*dx)),Roll=0},true)
 end
 q.mAnimationOverrideComponent:PlayAnimationSequenceOverride2(asset,1,false,0,.1,.15)
 return asset,duration
end
function N:activeSequence(firstPath,pawn)
 local c=self.c
 local chapter=firstPath:match('(/Game/Levels/[^/]+/PLVL_[^.]+%.)')
 local chapterProfiles=chapter and sequenceProfiles[chapter]
 if not chapterProfiles then return end
 for _,profile in ipairs(chapterProfiles) do
  for _,actor in ipairs(profile.actors) do
   local asset=c.sequence(actor,pawn)
   if c.live(asset) and asset:GetFullName()==profile.key then return profile,asset end
  end
 end
end
function N:available(q)
 local c=self.c
 local ac=q.mAnimationControlComponent
 if not c.live(ac)or ac:IsPlayingOverrideAnimation()or not c.live(q.mAnimationOverrideComponent)
  or not c.live(q.CharacterMovement)or q.CharacterMovement.MovementMode~=1 then return end
 local anim=c.live(q.Mesh)and q.Mesh:GetAnimInstance()
 if not c.live(anim)or c.live(anim.mCurrentlyActiveGrabInterface)then return end
 local pickup=q:GetPlayerPickupInterface()
 if c.live(pickup)and c.live(pickup:GetCurrentlyHeldPickup())then return end
 return true
end
function N:start(s)
 local c=self.c;local p,q=s.p,s.q
 local profile=profiles[s.key]
 if not profile then return end
 if s.key==doctorGrab then return self:startDoctorReaction(s)end
 local route=barnRoutes[profile.scene]
 if route then return self:startBarn(s,profile.scene,route) end
 if profile.raft then
  local seat=findAnimation(c,animationPath('ANIM_Player_FloatingDoorSitIdle_A'))
  if not seat or not audioOnly(c,seat) then return end
  local ok,ride=pcall(Raft.start,c,s,seat,function(pawn)return self:available(pawn)end)
  if ok then return ride end
  c.log('Cinematica balsa: '..tostring(ride))
  return
 end
 if not self:available(q) then return end
 if profile.response then return self:startReaction(s,profile)end
 if profile.scene=='cazador' then return self:startHunter(s,profile.prepare)end
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

function N:startDoctorReaction(s)
 local c=self.c
 local event=s.doctor
 if not event then return end
 local pawn=event.companion
 local primary=c.same(pawn,s.p)
 local pc=primary and c.p1()
 if not pawn:IsAlive() or pawn.bIsCrouched or (pc and pc:IsMoveInputIgnored()) or not self:available(pawn) then return end
 local asset=findAnimation(c,animationPath('ANIM_Player_StandToCrouch'))
 local duration=asset and asset.SequenceLength
 if type(duration)~='number' or duration<=0 or not audioOnly(c,asset) then return end
 pawn.mAnimationOverrideComponent:PlayAnimationSequenceOverride2(asset,0,false,0,.08,.1)
 c.log('Cinematica Doctor: P'..(primary and '1' or '2')..' se agacha al ver el agarre')
 return {pawn=pawn,asset=asset,duration=duration,scene='Doctor',reaction=true,passThrough=true,
  followThrough=true,primaryReaction=primary}
end

function N:startBarn(s,scene,route)
 local c=self.c;local p,q=s.p,s.q
 local at,from=p:K2_GetActorLocation(),q:K2_GetActorLocation()
 if not inside(route.entrance,at) or not inside(route.approach,from) then return end
 local length=s.asset.SequenceLength
 if type(length)~='number' or length<=0 or length>12 then return end
 local active={pawn=q,duration=length+5,scene=scene,barnRoute=route,followThrough=true,
  passThrough=true,protectsSeparation=true}
 -- A nearby P2 uses the same authored drop in a separate lane. A player
 -- still crossing the barn retains input until the native drop lands.
 local restriction=p.mAnimationControlComponent.mMovementRestrictionMode
 if math.abs(from.Y-at.Y)>520 or math.abs(from.Z-at.Z)>120 or not self:available(q)
  or (restriction~=2 and restriction~=3) or not audioOnly(c,s.asset) then
  c.log('Cinematica '..scene..': esperando el aterrizaje de P1')
  return active
 end
 local destination
 for _,offset in ipairs({-120,120,-165,165}) do
  local point={X=at.X+offset,Y=at.Y-25,Z=at.Z}
  if c.clear(q,p,point) and c.clear(q,p,from,point) then destination=point;break end
 end
 if not destination then
  c.log('Cinematica '..scene..': sin carril lateral libre, esperando el aterrizaje')
  return active
 end
 c.driver:stop()
 q.CharacterMovement:StopMovementImmediately()
 local rotation=q:K2_GetActorRotation()
 if q:K2_SetActorLocationAndRotation(destination,p:K2_GetActorRotation(),false,{},true)==false then return active end
 local ok,err=pcall(function()
  q.mAnimationOverrideComponent:PlayAnimationSequenceOverride2(s.asset,restriction,false,0,.08,.15)
 end)
 if not ok then
  q:K2_SetActorLocationAndRotation(from,rotation,false,{},true)
  c.log('Granero: error al iniciar la caida de P2: '..tostring(err))
  return active
 end
 active.asset=s.asset
 active.passThrough=false
 c.log('Cinematica '..scene..': P2 acompana la caida en un carril lateral')
 return active
end

function N:tickBarn(active,s)
 local c=self.c;local p,q=s.p,s.q
 local ac=q.mAnimationControlComponent
 local own=active.asset and c.live(ac) and ac:IsPlayingOverrideAnimation()
  and c.same(ac.mCurrentAnimStateAsset,active.asset)
 if active.landed then
  return own and s.now<active.landedUntil
 end
 active.passThrough=not own
 if s.key==active.key or own then return end

 local firstAt=p:K2_GetActorLocation()
 local movement=p.CharacterMovement
 local route=active.barnRoute
 if not inside(route.arrival,firstAt) or not c.live(movement) or movement.MovementMode~=1 then return end
 local secondAt=q:K2_GetActorLocation()
 if inside(route.arrival,secondAt) or not inside(route.approach,secondAt) then return false end
 if active.nextLanding and s.now<active.nextLanding then return end
 active.nextLanding=s.now+.2
 if not self:available(q) then return end
 local destination=c.landing(p,q,firstAt,function(at)return inside(route.arrival,at)end)
 if not destination then return end

 c.driver:stop()
 q.CharacterMovement:StopMovementImmediately()
 if q:K2_SetActorLocation(destination,false,{},true)==false then return end
 c.log('Cinematica '..active.scene..': P2 reunido con P1 en suelo firme')
 local response=findAnimation(c,animationPath('ANIM_Player_LandingConcussive'))
 local duration=response and response.SequenceLength
 if type(duration)~='number' or duration<=0 then return false end
 local ok,err=pcall(function()
  q.mAnimationOverrideComponent:PlayAnimationSequenceOverride2(response,1,false,0,.08,.15)
 end)
 if not ok then
  c.log('Cinematica '..active.scene..': error al reproducir el aterrizaje: '..tostring(err))
  return false
 end
 active.asset=response
 active.landed=true
 active.landedUntil=s.now+duration
 active.passThrough=false
end
function N:startReaction(s,profile)
 local c=self.c;local p,q=s.p,s.q
 local a,b=p:K2_GetActorLocation(),q:K2_GetActorLocation()
 if profile.bounds and not inside(profile.bounds,a) then return end
 if (a.X-b.X)^2+(a.Y-b.Y)^2>450^2 or math.abs(a.Z-b.Z)>100 then
  c.log('Cinematica '..profile.scene..': P2 fuera de la zona de entrada')
  return
 end
 local moving=profile.moving or profile.trigger~=nil
 if profile.trigger then
  local trigger=StaticFindObject(profile.trigger)
  if not c.world(trigger,p) then return end
  local at=trigger:K2_GetActorLocation()
  if (at.X-b.X)^2+(at.Y-b.Y)^2>520^2 or math.abs(at.Z-b.Z)>180 then return end
 end
 local response=findAnimation(c,profile.response)
 local duration=response and response.SequenceLength
 if type(duration)~='number' or duration<=0 then return end
 if not moving then
  c.driver:stop()
  q.CharacterMovement:StopMovementImmediately()
 end
 q.mAnimationOverrideComponent:PlayAnimationSequenceOverride2(response,moving and 0 or 1,false,0,0.08,0.15)
 c.log('Cinematica '..profile.scene..': P2 reacciona en su posicion')
 return {pawn=q,asset=response,duration=duration,scene=profile.scene,reaction=true,
  followThrough=profile.followThrough,passThrough=moving}
end

function N:hunterDestination(p,q,a,b,prepare)
 local c=self.c
 if prepare then
  -- P1 plays the rifle pickup above the floor. Reuse the approach position
  -- reached by P2 in the 10:16 recording.
  if not inside({-4800,-4100,47000,47700,0,300},a) then return end
  local at={X=-4515,Y=47288,Z=b.Z}
  if (at.X-b.X)^2+(at.Y-b.Y)^2<=550^2 and math.abs(b.Z+47)<=80
   and c.clear(q,p,at) and c.clear(q,p,b,at) then return at end
  return
 end
 local yaw=math.rad(p:K2_GetActorRotation().Yaw)
 local forward={X=math.cos(yaw),Y=math.sin(yaw)}
 for _,offset in ipairs({110,-110,155,-155})do
  local at={X=a.X-forward.Y*offset-forward.X*35,
   Y=a.Y+forward.X*offset-forward.Y*35,Z=b.Z}
  local finish={X=at.X-forward.X*65,Y=at.Y-forward.Y*65,Z=at.Z}
  if c.clear(q,p,at)and c.clear(q,p,at,finish)then return at end
 end
end

function N:startHunter(s,prepare)
 local c=self.c;local p,q=s.p,s.q
 local a,b=p:K2_GetActorLocation(),q:K2_GetActorLocation()
 if not prepare and ((a.X-b.X)^2+(a.Y-b.Y)^2>1200^2 or math.abs(a.Z-b.Z)>80) then
  c.log('Cinematica cazador: P2 fuera de la habitacion');return
 end
 local asset=findAnimation(c,reactionPath)
 if not asset then c.log('Cinematica cazador: reaccion no disponible');return end
 local destination=self:hunterDestination(p,q,a,b,prepare)
 if not destination then
  if prepare then return end
  c.log('Cinematica cazador: sin hueco lateral; reaccion desde posicion actual')
  destination=b
 end
 c.driver:stop();q.CharacterMovement:StopMovementImmediately()
 c.log(prepare and 'Cinematica cazador: P2 se coloca mientras P1 recoge la escopeta'
  or 'Cinematica cazador: P2 camina al hueco lateral')
 return {pawn=q,asset=asset,duration=asset.SequenceLength+(prepare and 14 or 6),scene='cazador',
  destination=destination,driving=true,followThrough=true,
  nextKey=prepare and ('AnimSequence '..animationPath(hunterShot)) or nil,
  rotation={Pitch=0,Yaw=-90,Roll=0},phase='approach'}
end
function N:tick(active,s)
 if active.raft then
  local ok,playing=pcall(Raft.tick,self.c,active,s)
  if ok then return playing end
  self.c.log('Cinematica balsa: '..tostring(playing))
  return false
 end
 if active.barnRoute then return self:tickBarn(active,s) end
 if active.reaction then
  local ac=active.pawn.mAnimationControlComponent
  return self.c.live(ac)and ac:IsPlayingOverrideAnimation()
   and self.c.same(ac.mCurrentAnimStateAsset,active.asset)and s.now-active.since<active.duration
 end
 if active.scene~='cazador'then return end
 local q=active.pawn
 if active.phase=='approach' then
  local at=q:K2_GetActorLocation()
  local dx,dy=active.destination.X-at.X,active.destination.Y-at.Y
  local distance=math.sqrt(dx*dx+dy*dy)
  if distance>18 and not active.shotObserved then
   if s.now-active.since>5 then
    self.c.log('Cinematica cazador: recorrido bloqueado; se devuelve control');return false
   end
   self.c.driver.api.move(q,{X=dx/distance,Y=dy/distance,Z=0})
   return
  end
  self.c.driver:stop()
  q:K2_SetActorRotation(active.rotation,true)
  active.phase='waiting';active.driving=false
  self.c.log('Cinematica cazador: P2 espera mirando a la puerta')
 end
 if active.phase=='waiting' then
  if not active.shotObserved then
   if not s.key and not active.nextKey then return false end
   return
  end
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
 if active.raft then Raft.release(c,active) end
 if active.primaryReaction then
  self:stopLocalPose(q,active.asset,true)
 elseif c.live(active.asset)and c.live(q)and c.same(q,c.driver.pawn)and c.live(q.mAnimationControlComponent)
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
