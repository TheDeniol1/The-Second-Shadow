local Rules=require('hand_rescue_rules')
local h={X=0,Y=0,Z=100};local v={X=60,Y=0,Z=30};local f={X=1,Y=0,Z=0}
assert(Rules.reachable(h,v,f,true,false,-100))
assert(Rules.reachable(h,v,f,false,true,0))
assert(not Rules.reachable(h,v,f,true,false,100),'ascending jump is not a falling capture')
assert(not Rules.reachable(h,v,{X=-1,Y=0},true,false,-100),'cannot catch behind the offered hand')
assert(not Rules.reachable(h,{X=60,Y=0,Z=-110},f,true,false,-100),'no rescue after falling out of reach')
assert(not Rules.reachable(h,{X=190,Y=0,Z=30},f,true,false,-100))
assert(Rules.reachable(h,{X=140,Y=0,Z=30},f,false,true,0),'wider ledge reach')
assert(Rules.reachable(h,{X=175,Y=0,Z=30},f,true,false,-100),'air capture tolerates an incomplete jump')
assert(Rules.closeHands(h,{X=85,Y=0,Z=100},true))
assert(Rules.closeHands(h,{X=135,Y=0,Z=100},false))
assert(not Rules.closeHands(h,{X=145,Y=0,Z=100},false))
local AirPath=require('air_rescue_path')
local plan=AirPath.new(v,{X=0,Y=56,Z=103},20)
assert(plan and AirPath.at(plan,0).Z==v.Z and AirPath.at(plan,.55).Z>103)
assert(AirPath.at(plan,.2).X==v.X,'lift before crossing the edge')
assert(AirPath.at(plan,.9).Z==plan.lift.Z,'cross above the landing surface')
assert(AirPath.distance2(AirPath.at(plan,1),plan.target)==0)
assert(#AirPath.moves(plan,.5,.95)==3,'a frame crossing both corners cannot cut through the platform')
assert(not AirPath.new(v,{X=1000,Y=0,Z=103},20),'bound the rescue path')
assert(not Rules.arrived(v,{X=60,Y=0,Z=0},h,true),'landing below is not success')
assert(not Rules.arrived(v,h,h,false),'airborne animation completion is not success')
assert(Rules.arrived(v,h,h,true))
local Hand=require('hand_rescue_native')
local oldFind=StaticFindObject
local oldFName=FName
FName=function(name)return {fname=name}end
local function sequence()
 return {SequenceLength=1,GetPlayLength=function()error('capture must not invoke GetPlayLength')end}
end
local ready={};local pull=sequence();local rise=sequence();local hoist=sequence()
local blocked=false;local noFloor=false;local steepFloor=false;local partialMove=false
StaticFindObject=function(path)
 if path:find('ReadyLoop',1,true)then return ready end
 if path:find('PullUp',1,true)then return pull end
 if path:find('PulledUp',1,true)then return rise end
 if path:find('HoistEnterFwd',1,true)then return hoist end
 if path:find('KismetSystemLibrary',1,true)then return {
  LineTraceSingle=function()error('hand contact must use the proven capsule trace binding')end,
  CapsuleTraceSingleByProfile=function(_,context,from,to,radius,half,profile,complex,ignore,draw,hit)
   if radius==1 then
    assert(half==1 and profile=='Pawn' and not complex and #ignore==2 and ignore[1]==context,
     'hand contact checks level geometry with the pawn profile and ignores both Monos')
    return blocked
   end
   return blocked
  end}end
end
local now=0;local held={false,false};local logs={};local p,q
local function pawn(at)
 local o={at=at,Controller={mBodyAnimator={ClearMoveInput=function()end,SetRawMoveInput=function()end}},plays={}}
 o.Controller.tick=true
 function o.Controller:IsActorTickEnabled()return self.tick end
 function o.Controller:SetActorTickEnabled(x)self.tick=x end
 function o:K2_GetActorLocation()return self.at end
 function o:GetActorForwardVector()return f end
 function o:GetVelocity()return {Z=-100}end
 function o:K2_SetActorRotation()end
 function o:K2_SetActorLocation(at,sweep,hit,teleport)
  assert(sweep and not teleport,'alignment must sweep with collision')
  if not partialMove then self.at={X=at.X,Y=at.Y,Z=at.Z}end
 end
 o.CapsuleComponent={GetScaledCapsuleRadius=function()return 20 end,
  GetScaledCapsuleHalfHeight=function()return 40 end,GetCollisionProfileName=function()return 'Pawn'end}
 function o:GetPlayerPickupInterface()end
 o.CharacterMovement={MovementMode=1,StopMovementImmediately=function()end}
 function o.CharacterMovement:GetGravityZ()return -980 end
 function o:LaunchCharacter(velocity,xy,z)
  assert(not xy and z and velocity.Z>600 and velocity.Z<700,'native launch preserves horizontal velocity')
  self.launches=(self.launches or 0)+1
 end
 function o.CharacterMovement:SetMovementMode(mode)self.MovementMode=mode end
 function o.CharacterMovement:K2_FindFloor(from,floor)
  floor.bBlockingHit=not noFloor
  floor.bWalkableFloor=not steepFloor
  floor.bLineTrace=false
  floor.FloorDist=from.Z-100
 end
 o.anim={RootMotionMode=3}
 function o.anim:SetRootMotionMode(mode)self.RootMotionMode=mode end
 o.Mesh={GetAnimInstance=function()return o.anim end,DoesSocketExist=function(_,name)
  assert(type(name)=='table'and name.fname,'socket query requires an FName');return true end,
  GetSocketLocation=function(_,name)
   assert(type(name)=='table'and name.fname,'socket position requires an FName');return {X=40,Y=0,Z=80}end}
 local ac={};o.mAnimationControlComponent=ac
 function ac:IsPlayingOverrideAnimation()return self.mCurrentAnimStateAsset~=nil end
 o.mAnimationOverrideComponent={}
 function o.mAnimationOverrideComponent:PlayAnimationSequenceOverride2(asset,mode,loop)
  o.plays[#o.plays+1]={asset=asset,mode=mode,loop=loop};ac.mCurrentAnimStateAsset=asset
 end
 function o.mAnimationOverrideComponent:StopAnimationSequenceOverride()ac.mCurrentAnimStateAsset=nil end
 return o
end
p=pawn(h);q=pawn(v);p.Controller.Pawn=p;q.Controller.Pawn=q
local c={state={airRescue=true},live=function(o)return type(o)=='table'end,same=function(a,b)return a~=nil and a==b end,
 p1=function()return p.Controller end,driver={pawn=q},offerHeld=function(role)return held[role]end,
 clock=function()return now end,log=function(s)logs[#logs+1]=s end,
 UE={GetGameplayStatics=function()return {GetTimeSeconds=function()return now end}end}}
local n=Hand.new(c)
n.base.pair=function()return p,q end
n.base.ledge=function()return nil end
held[1]=true;assert(n:update(false));assert(n.control.active.phase=='ready' and not p.Controller.tick)
q.CharacterMovement.MovementMode=3
c.state.airRescue=false
assert(not n:contact(n.control.active),'disabled air rescue does not capture a falling pawn')
c.state.airRescue=true
local originalVelocity=q.GetVelocity
q.GetVelocity=function()return {Z=100}end
now=.1;assert(n:update(false)and not n.control.active.captured,'a rising Mono stays in normal play')
q.GetVelocity=originalVelocity
blocked=true;now=.2;assert(n:update(false)and n.control.active.phase=='ready','wall prevents capture')
local originalPosition=q.at
assert(not n:planAir(n.control.active)and q.at==originalPosition,'blocked route never relocates the victim')
blocked=false;noFloor=true
assert(not n:planAir(n.control.active),'no floor means no rescue path')
noFloor=false;steepFloor=true
assert(not n:planAir(n.control.active),'steep surface is not a landing')
steepFloor=false
blocked=false;now=.3;assert(n:update(false)and n.control.active.captured)
assert(q.at==originalPosition,'capture starts at the actual position; never snaps down')
assert(q.CharacterMovement.MovementMode==5,'air pull permits vertical root motion')
assert(q.anim.RootMotionMode==1,'the path owns displacement, without a second root-motion trajectory')
assert(#p.plays==2 and #q.plays==1 and not p.plays[2].loop and not q.plays[1].loop,'paired pull starts once without looping')
assert(p.plays[2].mode==1 and q.plays[1].mode==0,'victim override must leave its guided movement mode alone')
q.anim.RootMotionMode=0 -- The engine may reset extraction when it starts the override.
for i=1,4 do now=.3+i*.2;assert(n:update(false))end
assert(q.anim.RootMotionMode==1,'the owned rise pose cannot add translation to the guided pull')
assert(#p.plays==2 and #q.plays==1,'updates never restart either animation')
local original={x=1,jump=true,grab=true};local d,i=n:route({X=1,Y=0,Z=0},original)
assert(d.X==0 and not i.jump and original.jump,'both participants lose competing input without mutating the physical sample')
local landing=n.control.active.airPlan.target
now=1.3;assert(n:update(false)and n.control.active.phase=='settle'and q.CharacterMovement.MovementMode==3,
 'animation completion restores falling before testing ground contact')
assert(AirPath.distance2(q.at,landing)==0,'swept progression reaches the validated destination')
assert(q.anim.RootMotionMode==3,'completion restores the original animation root motion mode')
q.CharacterMovement.MovementMode=1
now=1.35;assert(not n:update(false)and p.Controller.tick and n:noticeText()=='Rescate terminado')
now=1.4;assert(not n:update(false),'holding through completion cannot repeat the pull')
held[1]=false;n:update(false);held[1]=true;now=1.5;assert(n:update(false))
held[1]=false;now=1.6;assert(not n:update(false)and p.Controller.tick,'release cancels the waiting pose')
-- Reverse roles and verify primary controller is untouched until capture.
q.at=h;p.at=v;p.CharacterMovement.MovementMode=3;q.CharacterMovement.MovementMode=1
rise.SequenceLength=6
held[2]=true;now=2;assert(n:update(false));assert(p.Controller.tick,'P1 remains playable while P2 offers a hand')
now=2.2;assert(n:update(false)and n.control.active.captured and not p.Controller.tick)
assert(n.control.active.duration==1.65,'a long source clip does not extend the guided pull')
rise.SequenceLength=1
held[2]=false;now=2.3;assert(not n:update(false)and p.Controller.tick,'release aborts the paired pull')
assert(p.CharacterMovement.MovementMode==3,'release restores gravity for the captured player')
assert(p.anim.RootMotionMode==3,'release restores animation root motion mode too')
-- A new movement mode from the engine ends the scripted pull without
-- replacing that mode or moving the victim again.
held[2]=true;now=2.31;assert(n:update(false));now=2.51;assert(n:update(false)and n.control.active.captured)
local interruptedAt=p.at
p.CharacterMovement.MovementMode=4
now=2.55;assert(not n:update(false)and p.Controller.tick)
assert(p.at==interruptedAt and p.CharacterMovement.MovementMode==4 and p.anim.RootMotionMode==3)
assert(logs[#logs-1]:find('el juego cambio el modo a 4',1,true),'report a movement mode interruption separately from geometry')
held[2]=false;now=2.56;n:update(false)
-- Moving obstacles or a collision during the actual sweep cancel safely.
held[2]=true;p.CharacterMovement.MovementMode=3;now=2.6;assert(n:update(false))
now=2.8;assert(n:update(false)and n.control.active.captured)
partialMove=true;now=2.9;assert(not n:update(false)and p.Controller.tick)
assert(p.CharacterMovement.MovementMode==3 and p.anim.RootMotionMode==3,'blocked sweep restores physics')
partialMove=false;held[2]=false;now=2.95;n:update(false)
-- Unrelated animation is never stopped during interruption.
held[2]=true;now=3;assert(n:update(false));local foreign={};q.mAnimationControlComponent.mCurrentAnimStateAsset=foreign
now=3.1;assert(not n:update(false)and q.mAnimationControlComponent.mCurrentAnimStateAsset==foreign)
q.mAnimationControlComponent.mCurrentAnimStateAsset=nil
held[2]=false;n:update(false);held[2]=true;now=4;assert(n:update(false))
now=4.5;assert(not n:update(false),'long frame interruption cancels rather than capturing late')
held[2]=false;n:update(false);held[2]=true;now=5;assert(n:update(false))
assert(not n:update(true),'cinematic gate cancels waiting')
-- Startup failure restores a suspended P1, even before the pose exists.
held[2]=false;held[1]=false;n:update(false);p.at=h;p.CharacterMovement.MovementMode=1
local play=p.mAnimationOverrideComponent.PlayAnimationSequenceOverride2
p.mAnimationOverrideComponent.PlayAnimationSequenceOverride2=function()error('test animation failure')end
held[1]=true;now=6;assert(not n:update(false)and p.Controller.tick and not n.control.active)
p.mAnimationOverrideComponent.PlayAnimationSequenceOverride2=play
-- Ledge capture must retain the native grab and never play the airborne rise.
local nativeFinished,climbRequests=0,0
local savedRisePlays=#q.plays
local edge={GetFullName=function()return 'test ledge'end}
local interface={ReleaseGrab=function()error('must not release the ledge to start')end}
local native={}
n.base.start=function(_,s)
 assert(s.interface==interface and s.helperAsset==pull and s.helperLoop==false and s.deferPull)
 native.nativeEdge=edge;native.interface=interface;native.h=s.h;return native
end
n.base.climb=function()climbRequests=climbRequests+1 end
n.base.maintain=function()end
local accepted=false
n.base.observeClimb=function()native.observedClimb=accepted end
n.base.playPull=function(_,a)
 assert(accepted and not a.started)
 a.h.mAnimationOverrideComponent:PlayAnimationSequenceOverride2(pull,1,false)
 a.started=true
end
n.base.held=function()return true end
n.base.finish=function(_,_,reason)nativeFinished=nativeFinished+1;assert(reason=='subida terminada')end
n.base.ledge=function()return edge,interface end
c.state.airRescue=false
held[1]=false;now=7;n:update(false);held[1]=true;now=7.1
q.at=v;assert(n:update(false));now=7.3;assert(n:update(false)and n.control.active.phase=='ledge')
assert(#q.plays==savedRisePlays and climbRequests==1,'native ledge ascent does not start the airborne animation')
assert(p.mAnimationControlComponent.mCurrentAnimStateAsset==ready,'offer pose stays active until the engine accepts the climb')
accepted=true
now=7.4;assert(n:update(false)and climbRequests==2)
assert(p.mAnimationControlComponent.mCurrentAnimStateAsset==pull,'start the pull once on native climb acceptance')
n.base.ledge=function()return nil end;q.at=h;q.CharacterMovement.MovementMode=1
now=7.5;assert(not n:update(false)and nativeFinished==1 and n.base.control.active==nil)
-- A crouched helper arms the pose; a fresh grab from the other Mono launches.
local base={X=0,Y=0,Z=100};local partner={X=65,Y=0,Z=100}
p.at=base;q.at=partner;p.CharacterMovement.MovementMode=1;q.CharacterMovement.MovementMode=1
local grabs={[p]=false,[q]=true}
n.base.held=function(_,pawn)return grabs[pawn]end
held[1]=false;held[2]=false;now=8;n:update(false)
c.state.jumpAssist=true;p.anim.CrouchAmount=1
held[1]=true;now=8.1;assert(n:update(false)and n.control.active.phase=='boostReady' and not q.launches)
assert(n.control.active.hAsset==hoist,'the jump boost uses the Six hoist pose')
p.CharacterMovement.MovementMode=6
held[1]=false;now=8.2;assert(n:update(false)and not q.launches,'a locally stationary override can use a different movement mode')
p.CharacterMovement.MovementMode=1
grabs[q]=false;now=8.25;assert(n:update(false))
grabs[q]=true;blocked=true;now=8.3;assert(n:update(false)and not q.launches)
grabs[q]=false;blocked=false;now=8.35;assert(n:update(false))
grabs[q]=true;now=8.4;assert(not n:update(false)and q.launches==1 and p.Controller.tick)
now=8.45;assert(not n:update(false)and q.launches==1)
p.anim.CrouchAmount=0;q.anim.CrouchAmount=1;q.at=base;p.at=partner
grabs[q]=false;held[2]=true;now=8.5;assert(n:update(false)and p.Controller.tick)
held[2]=false;now=8.55;assert(n:update(false))
grabs[q]=true;now=8.6;assert(not n:update(false)and not p.launches,'helper grab cancels without launching')
grabs[q]=false;now=8.65;n:update(false)
held[2]=true;now=8.7;assert(n:update(false))
grabs[p]=true;now=8.75;assert(not n:update(false)and p.launches==1,'either Mono can receive the jump')
held[2]=false;grabs[p]=false;now=8.8;n:update(false)
c.state.jumpAssist=false;held[2]=true;now=8.9
assert(n:update(false)and n.control.active.phase=='ready' and p.launches==1,'disabling jump assist keeps the hand offer')
held[2]=false;now=8.95;n:update(false)
StaticFindObject=oldFind
FName=oldFName
print('PASS: hand offer, reach, occlusion, both roles, single paired pull, release, ownership and rollback.')
