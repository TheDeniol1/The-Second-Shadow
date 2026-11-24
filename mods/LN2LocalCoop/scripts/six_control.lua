local Actions=require('mono_actions')
local Six={};Six.__index=Six

function Six.new(c)
 return setmetatable({c=c,actions=Actions.new({
  key=c.key,
  start=function(a,key)a:BlueprintStartAction(key)end,
  hold=function(a,key)a:BlueprintHoldAction(key)end,
  stop=function(a,key)a:BlueprintStopAction(key)end,
  crouch=c.crouch,
  use=function(a,held)
   if held then
    local pawn=a.mPawnSelf
    local interface=pawn:GetPlayerPickupInterface()
    local pickup=c.live(interface) and interface:GetCurrentlyHeldPickup() or nil
    if c.live(pickup) and pickup.mCanThrow and c.same(pickup:GetHolderIfHeld(),pawn) then pickup:TryThrow() end
   end
  end,
 })},Six)
end

function Six:actor()
 local pair=self.pair
 if pair and self.c.live(pair.actor) then return pair.actor end
end

function Six:stop()
 local ai=self.ai
 if not ai or not self.c.live(ai.animator) or not self.c.same(ai.animator.mPawnSelf,ai.actor) then
  self.actions:release(nil);return
 end
 self.actions:release(ai.animator)
 ai.animator:ClearMoveInput()
 ai.animator:SetRawMoveInput({X=0,Y=0,Z=0})
end

function Six:restoreAI()
 local ai=self.ai
 if not ai then return end
 local c=self.c
 local function restore(fn,...)
  local ok,err=pcall(fn,...)
  if not ok then c.log('Jugar como Six: error al restaurar la IA: '..tostring(err)) end
 end
 restore(self.stop,self)
 self.ai=nil
 self.actions:release(nil)
 if c.live(ai.brain) then restore(function()ai.brain.mAllowEventDriven=ai.events end) end
 for _,component in ipairs(ai.components) do
  local object=component.object
  if c.live(object) then restore(object.SetComponentTickEnabled,object,component.tick) end
 end
 if c.live(ai.animator) and c.same(ai.animator.mPawnSelf,ai.actor) then
  restore(ai.animator.SetMoveSpeedRate,ai.animator,ai.speed)
 end
end

function Six:restore()
 self:restoreAI()
 local pair=self.pair
 self.pair=nil
 if not pair or not self.c.live(pair.proxy) then return end
 local proxy=pair.proxy
 if self.c.live(pair.movement) and self.c.same(proxy.CharacterMovement,pair.movement) then
  local mode=pair.mode
  -- A grip or a custom climb belongs to the space Mono was in before the handover.
  if mode~=0 then pair.movement:SetMovementMode(3,0) end -- Falling, recheck the floor at Six's position.
 end
 proxy:SetActorEnableCollision(pair.collision)
 proxy:SetActorHiddenInGame(pair.hidden)
end

function Six:mirror()
 local pair=self.pair
 local at=pair.actor:K2_GetActorLocation()
 local from=pair.proxy:K2_GetActorLocation()
 if math.abs(at.X-from.X)+math.abs(at.Y-from.Y)+math.abs(at.Z-from.Z)>0.1 then
  pair.proxy:K2_SetActorLocation(at,false,{},true)
 end
 if not pair.proxy.bHidden then pair.proxy:SetActorHiddenInGame(true) end
end

function Six:orders(brain)
 local c=self.c
 local loadouts=brain.mPatternLoadouts
 for i=1,#loadouts do
  local loadout=loadouts[i]
  if c.live(loadout) then
   local analyzers=loadout.mAnalyzers
   for j=1,#analyzers do
    local analyzer=analyzers[j]
    if c.live(analyzer) and analyzer:GetFullName():match('^OrdersAnalyzer ') then
     local patterns=loadout.mPatterns
     for k=1,#patterns do
      local pattern=patterns[k]
      if c.live(pattern) and pattern:GetFullName():match('^ProcessScriptedOrdersPattern ') then
       return analyzer,pattern
      end
     end
     return analyzer
    end
   end
  end
 end
end

function Six:takeInput(controller,actor)
 local c=self.c
 local ai={actor=actor,animator=controller.mBodyAnimator,brain=controller.mBrain,
  components={},events=controller.mBrain.mAllowEventDriven,speed=controller.mBodyAnimator:GetMoveSpeedRate()}
 self.ai=ai
 controller.mNavigator:Stop(true)
 for _,object in ipairs({controller.mBrain,controller.mNavigator,actor.PlaypalOutOfBoundsManager}) do
  if c.live(object) then
   ai.components[#ai.components+1]={object=object,tick=object:IsComponentTickEnabled()}
   object:SetComponentTickEnabled(false)
  end
 end
 ai.brain.mAllowEventDriven=false
 ai.animator:SetMoveSpeedRate(1)
 c.log('Jugar como Six: entrada de P2 en '..actor:GetFullName())
end

function Six:sync(second,proxy,first,paused,scene,ready)
 local c=self.c
 if not (c.live(proxy) and c.live(first) and c.live(second) and c.live(second.Player)
  and second.Player.ControllerId==1 and c.same(second.Pawn,proxy) and c.same(proxy.Controller,second)
  and c.world(first,proxy) and not c.same(first.Pawn,proxy)) then self:restore();return end

 local story=c.storyPawn(proxy)
 local pair=self.pair
 if pair and (not c.same(proxy,pair.proxy) or not c.same(story,pair.actor)) then
  self:restore();pair=nil
 end
 if not c.live(story) or ((story.bHidden or not story:IsAlive()) and not (pair and scene)) then
  self:restore();return
 end
 if not pair then
  local movement=proxy.CharacterMovement
  if not c.live(movement) then return end
  c.park()
  pair={actor=story,proxy=proxy,movement=movement,mode=movement.MovementMode,
   hidden=proxy.bHidden,collision=proxy:GetActorEnableCollision()}
  self.pair=pair
  proxy:SetActorHiddenInGame(true)
  proxy:SetActorEnableCollision(false)
  movement:StopMovementImmediately()
  movement:SetMovementMode(0,0)
 end
 self:mirror()

 local controller,control=story.Controller,story.mAnimationControlComponent
 local prepared=c.live(controller) and c.same(controller.Pawn,story)
  and c.live(controller.mBodyAnimator) and c.same(controller.mBodyAnimator.mPawnSelf,story)
  and c.live(controller.mBodyAnimator.mFlowControl)
  and c.live(controller.mBrain) and c.live(controller.mNavigator)
 if not prepared then self:restoreAI();return story end
 if not c.same(pair.controller,controller) or not c.same(pair.brain,controller.mBrain)
  or (self.ai and not c.same(self.ai.animator,controller.mBodyAnimator)) then
  self:restoreAI()
  pair.controller=controller
  pair.brain=controller.mBrain
  pair.orders,pair.orderPattern=self:orders(controller.mBrain)
 end
 local orders=pair.orders
 local scripted=(c.live(orders) and (c.live(orders.mNextScriptedOrder) or #orders.mQueuedScriptedOrders>0))
  or (c.live(pair.orderPattern) and c.live(pair.orderPattern.mOrderBeingProcessed))
 local primaryControl=first.Pawn.mAnimationControlComponent
 local primaryAsset=c.live(primaryControl) and primaryControl.mCurrentAnimStateAsset or nil
 local cooperativeScene=c.live(primaryAsset) and primaryControl:IsPlayingOverrideAnimation()
  and primaryAsset:GetFullName():find('_CoOp_',1,true)
 local blocked=scene or cooperativeScene or controller:IsMoveInputIgnored()
  or (c.live(control) and control:IsPlayingOverrideAnimation() and not (c.ownsAssist and c.ownsAssist(story)))
 if not ready or scripted or blocked then
  self:restoreAI()
 elseif paused then
  if not pair.paused then self:stop() end
 elseif not self.ai then
  self:takeInput(controller,story)
 end
 pair.paused=paused
 return story
end

function Six:update(direction,input)
 local ai=self.ai
 if not ai then return end
 local a=ai.animator
 local x,y=input.x,input.y
 local length=math.sqrt(x*x+y*y)
 if length>1 then x,y=x/length,y/length end
 if x==0 and y==0 then a:ClearMoveInput() else a:SetMoveInput(direction) end
 a:SetRawMoveInput({X=y,Y=x,Z=0})
 self.actions:update(a,input)
end

return Six
