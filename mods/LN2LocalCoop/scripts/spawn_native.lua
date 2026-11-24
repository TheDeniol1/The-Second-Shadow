-- Native per-pawn animation adapter. Never activates spawners or puzzle events.
local N={};N.__index=N
local checkpointEvent='/Game/GameplayLogic/Spawn/BP_HeliosPlayerStart.BP_HeliosPlayerStart_C:EventPlayerSpawned'
local spawnDirections={{0,1},{0,-1},{-1,0},{1,0},{-.8,.8},{-.8,-.8}}
local sameSpot={{0,0}}
function N.new(context)return setmetatable({c=context},N)end
function N:installCheckpointWatch(now,confirm)
 local c=self.c
 if self.checkpointHook or (self.checkpointScan and now>=self.checkpointScan and now-self.checkpointScan<.5) then return end
 self.checkpointScan=now
 local ok,err=pcall(function()
  if not c.live(StaticFindObject(checkpointEvent)) then return end
  RegisterHook(checkpointEvent,function(ctx,player)
   if not c.session.enabled then return end
   local worked,problem=pcall(function()
    local pc=c.p1()
    local first,point=player:get(),ctx:get()
    if not (pc and c.same(first,pc.Pawn) and c.world(point,first)) then return end
    self.checkpoint={pawn=first,start=point}
    self.searchedAt,self.searchSince,self.cachedPlan=nil,nil,nil
    confirm(first)
   end)
   if not worked and self.checkpointError~=problem then
    self.checkpointError=problem
    c.log('Registro del punto de control: '..tostring(problem))
   end
  end)
  self.checkpointHook=true
 end)
 if not ok and self.checkpointHookError~=err then
  self.checkpointHookError=err
  c.log('Enlace del punto de control: '..tostring(err))
 end
end
function N:gameState(pc)
 local c=self.c
 local lib=StaticFindObject('/Script/Helios.Default__WidgetHelper')
 if c.live(pc) and c.live(lib) then return lib:GetHeliosGameState(pc) end
end
function N:playingGame(pc)
 return self:gameState(pc)==5 -- EHeliosGameState::Playing
end
function N:sixFinale(pc,playing)
 local c=self.c
 if not c.session.playAsSix or self:gameState(pc)==4 then
  self.sixFinaleWorld=nil
  return false
 end
 if not playing or not c.live(pc.Pawn) then return false end
 local p=pc.Pawn
 local owner=p:GetWorld()
 if not c.same(owner,self.sixFinaleWorld) then self.sixFinaleWorld=nil end
 if not p:GetFullName():find('/Game/Levels/Transmission/PLVL_Transmission.',1,true) then return false end
 local control=p.mAnimationControlComponent
 local asset=c.live(control) and control.mCurrentAnimStateAsset or nil
 local lastHit=false
 if c.live(asset) and control:IsPlayingOverrideAnimation() then
  local animation=asset:GetFullName():match('%.([^%.]+)$')
  -- The wake-up follows the last hit. The stumble identifies a direct load
  -- at the last bridge, where the last-hit animation has already passed.
  if animation=='ANIM_Player_WakeUpAfterLastHitMusicBox'
   or animation=='ANIM_Player_StumbleFallLongTransmission'
   or animation=='ANIM_Player_GapHelpSixBetrayal' then
   lastHit=animation=='ANIM_Player_WakeUpAfterLastHitMusicBox' and not c.same(owner,self.sixFinaleWorld)
   self.sixFinaleWorld=owner
  elseif animation=='ANIM_Player_HittingMusicBoxRecoil' then
   self.sixFinaleWorld=nil
  end
 end
 return c.same(owner,self.sixFinaleWorld),lastHit
end
function N:ready(pc)
 local c=self.c
 if not self:playingGame(pc)or not c.live(pc.Pawn)then return false end
 local p=pc.Pawn
 return c.live(p.Controller)and c.same(p.Controller,pc)and c.live(pc.PlayerCameraManager)
  and c.live(p.mAnimationControlComponent)and c.live(p.mAnimationOverrideComponent)
  and c.live(p.Mesh)and c.live(p.Mesh:GetAnimInstance())
end
function N:prepareJoin(pc,pawn,primary)
 local c=self.c
 local first=primary.Pawn
 if not c.world(first,pawn) or not first:IsAlive() then return false end
 local now=c.clock(primary)
 local attempt=self.joinAttempt
 if not attempt or not c.same(first,attempt.first) or not c.same(pc,attempt.controller) then
  attempt={first=first,controller=pc}
  self.joinAttempt=attempt
 end
 if not (c.live(first.CharacterMovement) and c.live(pawn.CharacterMovement) and c.live(first.CapsuleComponent)
  and c.live(pawn.CapsuleComponent) and c.live(primary.PlayerCameraManager)) then return false end

 local origin=first:K2_GetActorLocation()
 local spacing=math.max(100,first.CapsuleComponent:GetScaledCapsuleRadius()+pawn.CapsuleComponent:GetScaledCapsuleRadius()+12)
 local from={X=origin.X,Y=origin.Y,Z=origin.Z+4}
 local function clearPath(at)return c.clear(pawn,first,from,at)end
 local function supportedPosition()
  local current=pawn:K2_GetActorLocation()
  local d=(current.X-origin.X)^2+(current.Y-origin.Y)^2
  if d<(spacing-12)^2 or d>260^2 or math.abs(current.Z-origin.Z)>70 then return end
  return c.landing(first,pawn,current,function(at)
   return math.abs(at.Z-current.Z)<=12 and clearPath(at)
  end,sameSpot,pawn.CharacterMovement)
 end
 if c.same(attempt.placed,pawn) and pawn:IsAlive() and now>=attempt.placedAt then
  if now-attempt.placedAt<.2 then return false end
  if supportedPosition() then return true end
  attempt.placed=nil
 end
 if attempt.nextProbe and now>=attempt.nextProbe-.25 and now<attempt.nextProbe then return false end
 attempt.nextProbe=now+.25
 local yaw=math.rad(primary.PlayerCameraManager:GetCameraRotation().Yaw)
 local x,y=math.cos(yaw)*spacing,math.sin(yaw)*spacing
 local lanes={}
 for _,direction in ipairs(spawnDirections) do
  local forward,right=direction[1],direction[2]
  lanes[#lanes+1]={forward*x-right*y,forward*y+right*x}
 end
 local destination=c.landing(first,pawn,origin,clearPath,lanes)
 local stays=not destination and pawn:IsAlive() and supportedPosition()
 if not (destination or stays) then
  if not attempt.reported then c.log('Aparicion de P2: esperando suelo libre cerca de P1');attempt.reported=true end
  return false
 end
 if not pawn:IsAlive() then
  if not attempt.restarted and c.restartLocal(pc,pawn,primary,destination) then
   attempt.restarted=true
  end
  return false
 end
 if not stays and pawn:K2_SetActorLocation(destination,false,{},true)==false then return false end
 attempt.placed,attempt.placedAt=pawn,now
 c.log('Aparicion de P2: sitio libre junto a P1 verificado')
 return false
end
function N:born(first)
 self.origin=first:K2_GetActorLocation();self.rotation=first:K2_GetActorRotation()
 self.searchedAt=nil;self.searchSince=nil;self.cachedPlan=nil
 local ac=first.mAnimationControlComponent
 self.initialAnimation=self.c.live(ac)and ac.mCurrentAnimStateAsset or nil
end
function N:posePlan(first,early)
 local c=self.c
 local ac=first.mAnimationControlComponent
 local candidates={self.initialAnimation,c.live(ac)and ac.mCurrentAnimStateAsset or nil}
 for i=1,2 do
  local asset=candidates[i]
  if c.live(asset)then
   local name=asset:GetFullName()
   local side=name:find('ANIM_Player_SleepingIdleSideRight',1,true)or name:find('ANIM_Player_SleepingAwakeningIntro',1,true)
   local sit=name:find('ANIM_Player_SleepingIdle',1,true)or name:find('ANIM_Player_SleepingAwakening',1,true)
   if sit then
    local idle=side and 'ANIM_Player_SleepingIdleSideRight'or 'ANIM_Player_SleepingIdle'
    local wake=side and 'ANIM_Player_SleepingAwakeningIntro2'or 'ANIM_Player_SleepingAwakening'
    local function find(n)return StaticFindObject('/Game/Characters/Player/Animations/'..n..'.'..n)end
    local sleepAsset,wakeAsset=find(idle),find(wake)
    if c.live(sleepAsset)and c.live(wakeAsset)then
     c.log('Reaparicion P2 a partir de la pose nativa de P1')
     return {sleep=sleepAsset,wake=wakeAsset,intro=early and not not side,
      immediate=false,location=self.origin,rotation=self.rotation}
    end
   end
  end
 end
end
function N:plan(first,early,now)
 local c=self.c
 if c.storySix and c.storySix(first) then return end
 now=now or 0
 if self.searchedAt and now-self.searchedAt<0.25 then return self.cachedPlan end
 self.searchedAt=now;self.searchSince=self.searchSince or now
 self.cachedPlan=nil
 local selected,nearest,distance
 local origin=self.origin or first:K2_GetActorLocation()
 local checkpoint=self.checkpoint
 if checkpoint and c.same(first,checkpoint.pawn) and c.world(checkpoint.start,first) then
  selected=checkpoint.start
 else
  for _,start in ipairs(FindAllOf('BP_HeliosPlayerStart_C')or{})do
   if c.live(start)and c.world(start,first)then
    if start:IsCurrentCheckpoint()then selected=start;break end
    local at=start:K2_GetActorLocation()
    local d=(at.X-origin.X)^2+(at.Y-origin.Y)^2+(at.Z-origin.Z)^2
    if not distance or d<distance then nearest,distance=start,d end
   end
  end
 end
 -- Soft reload can leave IsCurrentCheckpoint without a matching live actor.
 -- Use only a native start close to the primary's captured spawn origin.
 if not selected and distance and distance<=150^2 then selected=nearest end
 if selected then
   local start=selected;local data=start.SpawnAnimations
   -- The nightmare hallway precedes the outdoor TV introduction. Keep the
   -- pre-game request armed there; do not insert a controllable clone into it.
   if early and start:GetFullName():find('GameIntro',1,true)
    and not(c.live(data)and c.live(data.WakeUpAnimation))then self.cachedPlan={defer=true};return self.cachedPlan end
   if c.live(data)and c.live(data.SleepingAnimation)and c.live(data.WakeUpAnimation)then
    local wake=data.WakeUpAnimation
    local intro=early and wake:GetFullName():find('SleepingAwakeningIntro',1,true)~=nil
    local plan={sleep=data.SleepingAnimation,wake=wake,immediate=start.WakeUpImmediately,
     intro=intro,location=origin,rotation=self.rotation or first:K2_GetActorRotation()}
    c.log('Reaparicion P2: '..data:GetFullName()..(intro and ' | introduccion en orden' or ''))
    self.cachedPlan=plan;return plan
   end
   return nil
 end
 local pose=self:posePlan(first,early)
 if pose then self.cachedPlan=pose;return pose end
 -- An actor whose spawn data is absent may intentionally start standing. If
 -- the checkpoint actor itself is not loaded yet, wait rather than guessing.
 if now-self.searchSince<3 then self.cachedPlan={defer=true};return self.cachedPlan end
 -- A standing spawn may have no matching actor. Never leave controls locked
 -- indefinitely once the native primary and its components are stable.
 c.log('Checkpoint sin actor cercano; P2 conserva la aparicion normal')
 self.cachedPlan=nil;return nil
end
function N:hide(hidden)
 local c=self.c;local p=c.driver.pawn
 if not c.live(p)then return end
 if hidden then
  if not c.same(self.hiddenPawn,p)then
   self.hiddenPawn=p;self.hiddenMode=p.CharacterMovement.MovementMode
   self.hiddenCustom=p.CharacterMovement.CustomMovementMode
  end
  p.CharacterMovement:SetMovementMode(0,0)
  p:SetActorHiddenInGame(true);p:SetActorEnableCollision(false)
 elseif c.same(self.hiddenPawn,p)then
  p:SetActorHiddenInGame(false);p:SetActorEnableCollision(true)
  p.CharacterMovement:SetMovementMode(self.hiddenMode,self.hiddenCustom)
  self.hiddenPawn=nil
 end
end
function N:cancel()
 local c=self.c;local p=c.driver.pawn
 if c.live(p)then
  self:hide(false)
  if self:ownsPose(p) then p.mAnimationOverrideComponent:StopAnimationSequenceOverride(true)end
 end
 self.owned=nil
 self.joinAttempt=nil
end
function N:ownsPose(pawn)
 local c=self.c
 local owned=self.owned
 if not owned or not c.same(owned.pawn,pawn) then return false end
 local control=pawn.mAnimationControlComponent
 return c.live(control) and control:IsPlayingOverrideAnimation() and c.same(control.mCurrentAnimStateAsset,owned.asset)
end
function N:play(asset,loop,restriction)
 local c=self.c;local p=c.driver.pawn
 assert(c.live(p)and c.live(asset),'Secuencia de reaparicion no disponible')
 p.mAnimationOverrideComponent:PlayAnimationSequenceOverride2(asset,restriction,loop,0,0.15,0.15)
 self.owned={pawn=p,asset=asset}
 return asset.SequenceLength
end
function N:api()
 local self,c=self,self.c
 return {live=c.live,same=c.same,alive=function(p)return p:IsAlive()end,
  invalidate=function()self.checkpoint=nil end,
  waitingForRoom=function()
   local attempt=self.joinAttempt
   return attempt and attempt.reported and not attempt.placed
  end,
  cleanup=function()self:cancel();c.driver:stop();c.driver:remove()end,
  ensure=function()local pc=c.p1();return pc and c.driver:ensure(pc)end,
  present=function()return c.live(c.driver.pawn)and c.live(c.driver.pc)
   and c.same(c.driver.pc.Pawn,c.driver.pawn)end,
  born=function(first)self:born(first)end,
  plan=function(first,early,now)return self:plan(first,early,now)end,
  sleep=function(plan)
   local p=c.driver.pawn
   p:K2_SetActorRotation(plan.rotation,true)
   self:play(plan.sleep,true,1)
  end,
  wake=function(plan)return self:play(plan.wake,false,2)end,
  playing=function()
   local p=c.driver.pawn
   return c.live(p)and self:ownsPose(p)
  end,
  primaryFinished=function(first,plan)
   local pc=c.p1();local ac=first.mAnimationControlComponent
   return pc and not pc:IsMoveInputIgnored()and not c.same(ac.mCurrentAnimStateAsset,plan.sleep)
    and not c.same(ac.mCurrentAnimStateAsset,plan.wake)
  end,
  hide=function(hidden)self:hide(hidden)end,
  placeIntro=function(plan)c.driver.pawn:K2_SetActorLocationAndRotation(plan.location,plan.rotation,false,{},true)end,
  complete=function()self.owned=nil end,
  cancel=function()self:cancel()end}
end
return N
