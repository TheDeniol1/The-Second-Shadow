-- Native per-pawn animation adapter. Never activates spawners or puzzle events.
local N={};N.__index=N
function N.new(context)return setmetatable({c=context},N)end
function N:gameState(pc)
 local c=self.c
 local lib=StaticFindObject('/Script/Helios.Default__WidgetHelper')
 if c.live(pc) and c.live(lib) then return lib:GetHeliosGameState(pc) end
end
function N:playingGame(pc)
 return self:gameState(pc)==5 -- EHeliosGameState::Playing
end
function N:ready(pc)
 local c=self.c
 if not self:playingGame(pc)or not c.live(pc.Pawn)then return false end
 local p=pc.Pawn
 return c.live(p.Controller)and c.same(p.Controller,pc)and c.live(pc.PlayerCameraManager)
  and c.live(p.mAnimationControlComponent)and c.live(p.mAnimationOverrideComponent)
  and c.live(p.Mesh)and c.live(p.Mesh:GetAnimInstance())
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
 now=now or 0
 if self.searchedAt and now-self.searchedAt<0.25 then return self.cachedPlan end
 self.searchedAt=now;self.searchSince=self.searchSince or now
 self.cachedPlan=nil
 local selected,nearest,distance
 local origin=self.origin or first:K2_GetActorLocation()
 for _,start in ipairs(FindAllOf('BP_HeliosPlayerStart_C')or{})do
  if c.live(start)and c.world(start,first)then
   if start:IsCurrentCheckpoint()then selected=start;break end
   local at=start:K2_GetActorLocation()
   local d=(at.X-origin.X)^2+(at.Y-origin.Y)^2+(at.Z-origin.Z)^2
   if not distance or d<distance then nearest,distance=start,d end
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
  if self.owned and c.same(self.owned,p)then p.mAnimationOverrideComponent:StopAnimationSequenceOverride(true)end
 end
 self.owned=nil
end
function N:play(asset,loop,restriction)
 local c=self.c;local p=c.driver.pawn
 assert(c.live(p)and c.live(asset),'Secuencia de reaparicion no disponible')
 p.mAnimationOverrideComponent:PlayAnimationSequenceOverride2(asset,restriction,loop,0,0.15,0.15)
 self.owned=p
 return asset.SequenceLength
end
function N:api()
 local self,c=self,self.c
 return {live=c.live,same=c.same,alive=function(p)return p:IsAlive()end,
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
   return c.live(p)and p.mAnimationControlComponent:IsPlayingOverrideAnimation()
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
