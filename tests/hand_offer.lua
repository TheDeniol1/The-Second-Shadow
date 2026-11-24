local Hand=require('hand_offer')
local function live(o)return type(o)=='table' and not o.invalid end
local function same(a,b)return live(a) and live(b) and a==b end
local W={}
local now=0
local blocked=false
local floorOK=true
local assets={}
for _,name in ipairs({'ANIM_Six_GapHelpReadyLoop','ANIM_Six_GapHelpPullUp','ANIM_Player_GapHelpPulledUp','ANIM_Player_ClimbObjectFromLedgeHang'})do
 assets[name]={name=name,SequenceLength=1.6}
end
local ledgeClass={}
local library={CapsuleTraceSingleByProfile=function()return blocked end}
local oldFind,oldLoad,oldFName=StaticFindObject,LoadAsset,FName
StaticFindObject=function(path)
 if path:find('KismetSystemLibrary',1,true)then return library end
 if path:find('LedgeClimbingInterface',1,true)then return ledgeClass end
 for name,asset in pairs(assets)do if path:find(name,1,true)then return asset end end
end
LoadAsset=function()end
FName=function(s)return s end

local function controller()
 local a={}
 function a:ClearMoveInput()self.move=nil end
 function a:SetMoveInput(d)self.move=d end
 function a:SetRawMoveInput(d)self.raw=d end
 local pc={mBodyAnimator=a,tick=true}
 function pc:IsActorTickEnabled()return self.tick end
 function pc:SetActorTickEnabled(v)self.tick=v end
 function pc:IsMoveInputIgnored()return false end
 return pc
end
local function pawn(x,y,z,yaw)
 local p={pos={X=x,Y=y,Z=z},yaw=yaw or 0,alive=true}
 p.CharacterMovement={MovementMode=1,StopMovementImmediately=function()end,
  SetMovementMode=function(self,m)self.MovementMode=m end,
  K2_FindFloor=function(_,from,floor)
   if floorOK then floor.bBlockingHit=true;floor.bWalkableFloor=true;floor.FloorDist=2 end
  end}
 local ac={playing=false}
 function ac:IsPlayingOverrideAnimation()return self.playing end
 p.mAnimationControlComponent=ac
 p.mAnimationOverrideComponent={
  PlayAnimationSequenceOverride2=function(_,asset,restriction)ac.mCurrentAnimStateAsset=asset;ac.playing=true;p.played=asset
   if restriction==1 and p.CharacterMovement.MovementMode==1 then p.CharacterMovement.MovementMode=6 end end,
  StopAnimationSequenceOverride=function()ac.mCurrentAnimStateAsset=nil;ac.playing=false
   if p.CharacterMovement.MovementMode==6 then p.CharacterMovement.MovementMode=1 end end}
 local anim={mLedgeData={mIsHanging=false},RootMotionMode=0}
 function anim:SetRootMotionMode(m)self.RootMotionMode=m end
 p.anim=anim
 p.Mesh={GetAnimInstance=function()return anim end,DoesSocketExist=function()return true end,
  GetSocketLocation=function()
   local f=p:GetActorForwardVector()
   if anim.mLedgeData.mIsHanging then return {X=p.pos.X,Y=p.pos.Y,Z=p.pos.Z+70}end
   return {X=p.pos.X+f.X*30,Y=p.pos.Y+f.Y*30,Z=p.pos.Z-10}
  end}
 p.CapsuleComponent={GetScaledCapsuleRadius=function()return 20 end,GetScaledCapsuleHalfHeight=function()return 40 end,
  GetCollisionProfileName=function()return 'Pawn' end}
 function p:K2_GetActorLocation()return {X=self.pos.X,Y=self.pos.Y,Z=self.pos.Z}end
 function p:K2_SetActorLocation(at)self.pos={X=at.X,Y=at.Y,Z=at.Z};return true end
 function p:K2_SetActorRotation(r)self.yaw=r.Yaw end
 function p:GetActorForwardVector()return {X=math.cos(math.rad(self.yaw)),Y=math.sin(math.rad(self.yaw)),Z=0}end
 function p:IsAlive()return self.alive end
 function p:GetWorld()return W end
 function p:GetPlayerPickupInterface()return nil end
 function p:GetVelocity()return {X=0,Y=0,Z=-100}end
 return p
end
local function hang(p,climbable)
 local edge={mAllowClimbUpOnTop=climbable~=false,IsLedgeEnabled=function()return true end,GetFullName=function()return 'Ledge test' end}
 local interface={mCurrentLedge=edge,mGrabbingState=1,IsA=function(_,class)return class==ledgeClass end,
  ReleaseGrab=function(self)self.released=true;p.anim.mLedgeData.mIsHanging=false;p.anim.mCurrentlyActiveGrabInterface=nil;p.CharacterMovement.MovementMode=3 end}
 p.anim.mLedgeData.mIsHanging=true
 p.anim.mCurrentlyActiveGrabInterface=interface
 p.CharacterMovement.MovementMode=6
 return edge,interface
end
local function unhang(p)p.anim.mLedgeData.mIsHanging=false;p.anim.mCurrentlyActiveGrabInterface=nil end

local pc,qc=controller(),controller()
local P,Q
local keys={false,false}
local logs={}
local state={enabled=true,airRescue=true}
local c={UE={GetGameplayStatics=function()return {IsGamePaused=function()return false end,GetTimeSeconds=function()return now end}end},
 live=live,same=same,world=function(a,b)return live(a)and live(b)and a:GetWorld()==b:GetWorld()end,
 p1=function()return pc end,driver={},state=state,spawn={phase='active'},death={},
 gamepad={forRole=function()end},log=function(s)logs[#logs+1]=s end,foreground=function()return true end,
 offerHeld=function(role)return keys[role]end,input=function()return {grab=false}end,
 clock=function()return now end,cameraYaw=function()return 0 end}
local function setup(p,q)
 P,Q=p,q
 pc.Pawn,P.Controller=P,pc
 qc.Pawn,Q.Controller=Q,qc
 c.driver.pawn,c.driver.pc=Q,qc
 pc.tick=true
end
local hand=Hand.new(c)
local function tick(dt,blockedTick)now=now+(dt or .05);return hand:update(blockedTick)end
local function press(role)keys[role]=true;local r=tick();keys[role]=false;hand.prev[role]=false;return r end
local function last()
 for i=#logs,math.max(1,#logs-2),-1 do if logs[i]:find('^Mano: [^:]*$') and not logs[i]:find('recorrido',1,true) and not logs[i]:find('subida de borde',1,true) and not logs[i]:find('sin llegada',1,true) and not logs[i]:find('tipo trepar',1,true) then return logs[i] end end
 return logs[#logs]
end

-- Pure rules.
assert(Hand.inReach({X=0,Y=0,Z=100},{X=1,Y=0,Z=0},{X=80,Y=0,Z=20},true))
assert(not Hand.inReach({X=0,Y=0,Z=100},{X=1,Y=0,Z=0},{X=200,Y=0,Z=20},true),'too far while hanging')
assert(Hand.inReach({X=0,Y=0,Z=100},{X=1,Y=0,Z=0},{X=180,Y=0,Z=20},false),'midair reach is wider')
assert(not Hand.inReach({X=0,Y=0,Z=100},{X=1,Y=0,Z=0},{X=-80,Y=0,Z=20},true),'behind the helper')
assert(not Hand.inReach({X=0,Y=0,Z=100},{X=1,Y=0,Z=0},{X=60,Y=0,Z=-200},false),'far above the helper')
do
 local plan={origin={X=100,Y=0,Z=60},hang={X=40,Y=0,Z=20},target={X=0,Y=0,Z=100},split=.15}
 local function near(a,b)return math.abs(a.X-b.X)<1e-6 and math.abs(a.Y-b.Y)<1e-6 and math.abs(a.Z-b.Z)<1e-6 end
 assert(near(Hand.climbAt(plan,0),plan.origin)and near(Hand.climbAt(plan,.15),plan.hang)and near(Hand.climbAt(plan,1),plan.target),'climb goes origin, hang, target')
 local mid=Hand.climbAt(plan,.15+.85*.5)
 assert(mid.X==plan.hang.X and mid.Z>plan.target.Z-15,'rises under the ledge before moving over it')
 local moves=Hand.climbMoves(plan,0,1)
 assert(#moves>=20 and near(moves[#moves],plan.target),'climb is moved in small checked steps')
end

-- 1. P1 offers, P2 is hanging below and gets pulled up natively.
setup(pawn(0,0,100,0),pawn(70,0,30,180))
assert(press(1)==true and hand.control.active.phase=='offer')
assert(P.played==assets.ANIM_Six_GapHelpReadyLoop and not pc.tick,'pose plays and P1 input pauses')
assert(last():find('P1 ofrece la mano',1,true))
tick() -- no partner in reach yet
assert(hand.control.active.phase=='offer')
local edge,interface=hang(Q)
tick()
local a=hand.control.active
assert(a.phase=='ledge' and a.edge==edge,'hanging partner in reach is grabbed')
assert(last():find('P1 agarra a P2 y lo sube',1,true))
local d,routed=hand:route({X=0,Y=1,Z=0},{x=0,y=1,grab=false},0)
assert(math.abs(d.X+1)<1e-6 and routed.grab==true and routed.jump==false,'P2 is pushed towards the ledge and keeps the grab')
interface.mGrabbingState=4
tick()
assert(qc.mBodyAnimator.move and math.abs(qc.mBodyAnimator.move.X+1)<1e-6,'the game climb is driven')
assert(P.played==assets.ANIM_Six_GapHelpPullUp,'helper pulls once the climb starts')
unhang(Q);Q.pos={X=40,Y=0,Z=100};Q.CharacterMovement.MovementMode=1
assert(tick()==false and not hand.control.active,'arrival on top ends the assist')
assert(last():find('Companero a salvo',1,true) and pc.tick,'P1 input is restored')
assert(not P.mAnimationControlComponent.playing,'helper animation is cleared')

-- 2. Pressing again withdraws the hand; walking away or timeout withdraws it too.
setup(pawn(0,0,100,0),pawn(500,0,100,180))
press(1);assert(hand.control.active)
press(1);assert(not hand.control.active and last():find('Mano retirada',1,true) and pc.tick)
press(1);now=now+Hand.limits.offer+.1;a=hand.control.active;a.last=now-.05
assert(tick()==false and last():find('Nadie tomo la mano',1,true))
press(1);P.pos.X=P.pos.X+40
assert(tick()==false and last():find('Mano retirada',1,true),'moving the helper withdraws the hand')

-- 3. P2 offers, P1 falls in midair and is caught along a checked path.
setup(pawn(-90,0,40,0),pawn(0,0,100,180))
P.CharacterMovement.MovementMode=3
press(2);tick()
a=hand.control.active
assert(a and a.role==2)
assert(a.phase=='air','midair partner is caught on the first frame in reach')
assert(P.CharacterMovement.MovementMode==5 and P.anim.RootMotionMode==1 and not pc.tick)
assert(a.plan.kind=='climb' and P.played==assets.ANIM_Player_ClimbObjectFromLedgeHang,'the partner climbs with the game ledge climb animation')
assert(Q.played==assets.ANIM_Six_GapHelpPullUp,'the helper pulls')
assert(last():find('P2 agarra a P1 en el aire',1,true))
local dq,rq=hand:route({X=1,Y=0,Z=0},{x=1,y=0,jump=true},0)
assert(dq.X==0 and rq.x==0 and rq.jump==false,'the helper P2 stays still')
local startZ=P.pos.Z
for _=1,40 do if not hand.control.active or hand.control.active.phase~='air' then break end tick() end
assert(hand.control.active and hand.control.active.phase=='settle' and P.pos.Z>startZ,'path lifts the partner')
assert(P.CharacterMovement.MovementMode==1 and P.anim.RootMotionMode==0,'ends standing on top, no landing')
assert(tick()==false and last():find('Companero a salvo',1,true) and pc.tick)

-- 3c. The partner lands on the side they came from, a step back from the edge,
-- and hangs close to where they were caught.
setup(pawn(-90,20,40,0),pawn(0,0,100,180))
P.CharacterMovement.MovementMode=3
press(2);tick()
a=hand.control.active
assert(a.phase=='air' and a.plan.kind=='climb')
assert(a.plan.target.Y>0 and a.plan.target.X>Q.pos.X,'lands beside the helper on the partner side, inward')
assert(a.plan.hang.X<Q.pos.X and math.abs(a.plan.hang.Y-20)<math.abs(a.plan.target.Y-20),'hangs near the catch point')
hand:reset()

-- 3b. Without the climb animation the older checked path still works.
local climbAsset=assets.ANIM_Player_ClimbObjectFromLedgeHang
assets.ANIM_Player_ClimbObjectFromLedgeHang=nil;hand.assetCache.climb=nil
setup(pawn(-90,0,40,0),pawn(0,0,100,180))
P.CharacterMovement.MovementMode=3
press(2);tick()
a=hand.control.active
assert(a.phase=='air' and a.plan.kind==nil and P.played==assets.ANIM_Player_GapHelpPulledUp,'fallback path')
for _=1,40 do if not hand.control.active or hand.control.active.phase~='air' then break end tick() end
assert(P.CharacterMovement.MovementMode==3,'fallback lands with physics')
hand:reset();assets.ANIM_Player_ClimbObjectFromLedgeHang=climbAsset

-- 4. No room to land: the offer stays out and retries.
setup(pawn(0,0,100,0),pawn(90,0,40,180))
Q.CharacterMovement.MovementMode=3
floorOK=false
press(1);tick()
a=hand.control.active
assert(a and a.phase=='offer' and last():find('No hay sitio',1,true))
tick();assert(hand.control.active.phase=='offer','still offering')
floorOK=true;now=now+Hand.limits.retry
a.last=now-.05
tick();assert(hand.control.active.phase=='air','retry succeeds once there is room')
hand:reset();assert(not hand.control.active and pc.tick and Q.CharacterMovement.MovementMode==3)

-- 5. Partner lets go of the ledge while being pulled: midair catch takes over.
setup(pawn(0,0,100,0),pawn(70,0,30,180))
press(1);hang(Q);tick()
assert(hand.control.active.phase=='ledge')
unhang(Q);Q.CharacterMovement.MovementMode=3;Q.pos.Z=10
tick()
assert(hand.control.active and hand.control.active.phase=='air','a slip becomes a midair catch')
hand:reset()

-- 6. Ledge without climb-up: grab is released and the path lifts them.
setup(pawn(0,0,100,0),pawn(70,0,30,180))
press(1);local _,flat=hang(Q,false);tick()
assert(flat.released and hand.control.active.phase=='air')
hand:reset()

-- 7. Rules that stop an offer from starting.
setup(pawn(0,0,100,0),pawn(70,0,30,180))
P.CharacterMovement.MovementMode=3
press(1);assert(not hand.control.active and last():find('suelo firme',1,true))
P.CharacterMovement.MovementMode=1
P.anim.mCurrentlyActiveGrabInterface={}
press(1);assert(not hand.control.active and last():find('Suelta lo que',1,true))
P.anim.mCurrentlyActiveGrabInterface=nil
-- Holding the key does not re-trigger.
keys[1]=true;tick();assert(hand.control.active);tick();assert(hand.control.active.phase=='offer')
keys[1]=false;tick();assert(hand.control.active,'releasing the key keeps the hand out')

-- 8. A blocked frame (cinematic, menu) cancels and restores.
assert(tick(nil,true)==false and not hand.control.active and pc.tick)
assert(last():find('interrumpida',1,true))

-- 9. Walls between the hands prevent the grab.
setup(pawn(0,0,100,0),pawn(70,0,30,180))
press(1);hang(Q);blocked=true;tick()
assert(hand.control.active.phase=='offer','no grab through walls')
blocked=false;hand:reset()

-- 10. Midair catch can be disabled from the menu; ledges still work.
state.airRescue=false
setup(pawn(0,0,100,0),pawn(90,0,40,180));Q.CharacterMovement.MovementMode=3
press(1);tick();assert(hand.control.active.phase=='offer')
hang(Q);tick();assert(hand.control.active.phase=='ledge')
hand:reset();state.airRescue=true

-- Compatibility surface used by main.lua.
assert(hand.base:ledge(Q)~=nil and hand:noticeText()~=nil)
StaticFindObject,LoadAsset,FName=oldFind,oldLoad,oldFName
print('PASS: hand offer toggles, reaches, grabs from ledges and midair, retries and restores both players.')
