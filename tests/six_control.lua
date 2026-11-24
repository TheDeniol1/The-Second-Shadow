local Six=require('six_control')
local function live(o)return type(o)=='table' and not o.invalid end
local function same(a,b)return live(a) and a==b end
local world={}
local function component(enabled)
 return {tick=enabled,IsComponentTickEnabled=function(self)return self.tick end,
  SetComponentTickEnabled=function(self,value)self.tick=value end}
end
local function pawn(x)
 local p={world=world,position={X=x,Y=0,Z=10},bHidden=false,collision=true,alive=true}
 function p:IsAlive()return self.alive end
 function p:K2_GetActorLocation()return self.position end
 function p:K2_SetActorLocation(at)self.position=at end
 function p:SetActorHiddenInGame(value)self.bHidden=value end
 function p:SetActorEnableCollision(value)self.collision=value end
 function p:GetActorEnableCollision()return self.collision end
 function p:GetPlayerPickupInterface()return self.pickup end
 function p:GetFullName()return 'Pawn test' end
 p.CharacterMovement={MovementMode=1,StopMovementImmediately=function()end,
  SetMovementMode=function(self,value)self.MovementMode=value end}
 return p
end
local function connect(actor)
 local orders={GetFullName=function()return 'OrdersAnalyzer test'end,mQueuedScriptedOrders={}}
 local pattern={GetFullName=function()return 'ProcessScriptedOrdersPattern test'end}
 local brain=component(true)
 brain.mAllowEventDriven=true
 brain.mPatternLoadouts={{mPatterns={pattern},mAnalyzers={orders},
  GetFullName=function()return 'OrdersAILoadout_C test'end}}
 local navigator=component(false)
 function navigator:Stop()self.stops=(self.stops or 0)+1 end
 local a={mPawnSelf=actor,mFlowControl={},held={},speed=.5}
 function a:BlueprintStartAction(name)self.held[name]=true end
 function a:BlueprintHoldAction(name)assert(self.held[name])end
 function a:BlueprintStopAction(name)self.held[name]=nil end
 function a:ClearMoveInput()self.move=nil end
 function a:SetMoveInput(direction)self.move=direction end
 function a:SetRawMoveInput(direction)self.raw=direction end
 function a:GetMoveSpeedRate()return self.speed end
 function a:SetMoveSpeedRate(speed)self.speed=speed end
 actor.PlaypalOutOfBoundsManager=component(true)
 actor.mAnimationControlComponent={IsPlayingOverrideAnimation=function()return false end}
 actor.Controller={Pawn=actor,mBrain=brain,mNavigator=navigator,mBodyAnimator=a,
  IsMoveInputIgnored=function()return false end}
 return brain,navigator,a,orders,pattern
end
local proxy,story=pawn(1),pawn(12)
local second={Pawn=proxy,world=world,Player={ControllerId=1}}
local pc={Pawn=pawn(0),world=world}
proxy.Controller=second
local brain,navigator,animator,orders,pattern=connect(story)
local canon=story
local parkCount=0
local crouchAmount
local rescueOwnsAnimation=false
local six=Six.new({live=live,same=same,world=function(a,b)return a.world==b.world end,
 key=function(name)return name end,log=function()end,storyPawn=function()return canon end,
 ownsAssist=function(actor)return actor==canon and rescueOwnsAnimation end,
 crouch=function(a,held)
  assert(a.mPawnSelf==canon,'crouch belongs to the story pawn')
  crouchAmount=held and 1 or 0
 end,
 park=function()parkCount=parkCount+1 end})
assert(six:sync(second,proxy,pc,false,false,true)==story)
assert(story.Controller.mBrain==brain and not story.bHidden and story.collision and story:IsAlive())
assert(proxy.bHidden and not proxy.collision and proxy.CharacterMovement.MovementMode==0 and parkCount==1)
assert(proxy.position==story.position and animator.speed==1 and not brain.tick and not brain.mAllowEventDriven and not story.PlaypalOutOfBoundsManager.tick)
local direction={X=0,Y=1,Z=0}
six:update(direction,{x=1,y=0,jump=true,grab=true,sneak=true,sprint=true,use=true})
assert(animator.move==direction and animator.raw.X==0 and animator.raw.Y==1)
assert(animator.held.Jump and animator.held.Grab and animator.held.Sprint and crouchAmount==1)
assert(not animator.held.Sneak,'Six crouches through the float input')
six:update(direction,{x=1,y=0,sneak=false})
assert(crouchAmount==0,'releasing the button clears the input')
six:update(direction,{x=1,y=0,sneak=true})
six:sync(second,proxy,pc,true,false,true)
assert(not next(animator.held) and crouchAmount==0 and not animator.move and not brain.tick,
 'pause clears player input and keeps AI parked')
orders.mQueuedScriptedOrders={{}}
six:sync(second,proxy,pc,false,false,true)
assert(animator.speed==.5 and brain.tick and brain.mAllowEventDriven and not navigator.tick and story.PlaypalOutOfBoundsManager.tick)
assert(proxy.bHidden and not six.ai,'a story order must not reveal the spare pawn')
orders.mQueuedScriptedOrders={}
pattern.mOrderBeingProcessed={}
six:sync(second,proxy,pc,false,false,true)
assert(not six.ai,'an order already dequeued continues to own movement')
pattern.mOrderBeingProcessed=nil
story.bHidden=true
six:sync(second,proxy,pc,false,true,true)
assert(proxy.bHidden and not six.ai,'hidden cinematic Six must not cause Dark Six to pop in')
story.bHidden=false
six:sync(second,proxy,pc,false,false,true)
assert(six.ai and not brain.tick and navigator.stops==2 and parkCount==1)
local playingOverride=story.mAnimationControlComponent.IsPlayingOverrideAnimation
story.mAnimationControlComponent.IsPlayingOverrideAnimation=function()return true end
rescueOwnsAnimation=true
six:sync(second,proxy,pc,false,false,true)
assert(six.ai and not brain.tick,'Six keeps local control through a rescue pose or native climb')
rescueOwnsAnimation=false
six:sync(second,proxy,pc,false,false,true)
assert(not six.ai and brain.tick,'an unrelated animation still belongs to the game')
story.mAnimationControlComponent.IsPlayingOverrideAnimation=playingOverride
six:sync(second,proxy,pc,false,false,true)
local lift={GetFullName=function()return 'AnimSequence /Game/ANIM_Player_CoOp_WindowLong' end}
pc.Pawn.mAnimationControlComponent={mCurrentAnimStateAsset=lift,IsPlayingOverrideAnimation=function()return true end}
six:sync(second,proxy,pc,false,false,true)
assert(not six.ai and brain.tick and proxy.bHidden,'give the native partner control during a paired scene')
pc.Pawn.mAnimationControlComponent=nil
six:sync(second,proxy,pc,false,false,true)
canon=nil
assert(not six:sync(second,proxy,pc,false,false,true))
assert(not proxy.bHidden and proxy.collision and proxy.CharacterMovement.MovementMode==3)
assert(brain.tick and brain.mAllowEventDriven and not navigator.tick and story.PlaypalOutOfBoundsManager.tick)

canon=pawn(27)
local nextBrain=connect(canon)
assert(six:sync(second,proxy,pc,false,false,true)==canon and proxy.position==canon.position)
canon.world={}
local lookup=six.c.storyPawn
six.c.storyPawn=function()return nil end -- Canonical lookup excludes the previous world.
assert(not six:sync(second,proxy,pc,false,false,true))
assert(nextBrain.tick and not proxy.bHidden,'world travel releases the old actor and restores the proxy')
six.c.storyPawn=lookup
canon=story
second.Player.ControllerId=0
assert(not six:sync(second,proxy,pc,false,false,true))
assert(brain.tick and not proxy.bHidden,'a reused P1 controller cannot become an input owner')
print('PASS: story Six is the only active body, with reversible controls, story orders, pause, and Dark Six handoff.')

