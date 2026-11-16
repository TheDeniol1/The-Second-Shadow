local Rescue=require('coop_ledge_rescue')
local starts,climbs,finishes=0,0,0
local r=Rescue.new({start=function()starts=starts+1;return {}end,
 climb=function()climbs=climbs+1 end,finish=function()finishes=finishes+1 end})
local function sample(now,changes)
 local s={helper=1,victim=2,edge=3,now=now,ready=true,held=true,hanging=true,valid=true}
 for k,v in pairs(changes or {})do s[k]=v end
 return s
end
assert(not r:update(sample(0,{held=false})))
assert(not r:update(sample(0,{valid=false})))
assert(r:update(sample(0)))
for i=1,4 do assert(r:update(sample(i*.2)))end
assert(climbs==0,'short hold must not initiate the climb')
assert(not r:update(sample(.9,{held=false}))and finishes==1,'release cancels preparation')
assert(r:update(sample(1)))
for i=1,6 do assert(r:update(sample(1+i*.2)))end
assert(climbs>0,'sustained hold requests native climbing')
assert(not r:update(sample(2.3,{held=false})),'release also stops further climb requests')
for _,changes in ipairs({{helper=9},{victim=9},{edge=9},{ready=false},{valid=false}})do
 r:update(sample(3,{held=false}));assert(r:update(sample(3)))
 assert(not r:update(sample(3.1,changes))and not r.active,'identity or readiness loss cancels')
end
r:update(sample(4,{held=false}));assert(r:update(sample(4)))
assert(not r:update(sample(5)),'long frame gap must cancel instead of finishing the hold')
assert(not r:update(sample(5.1)),'held key must not restart a timed-out attempt')
r:update(sample(6,{held=false}));assert(r:update(sample(6)))
assert(not r:update(sample(5.9)),'clock rollback cancels')
r:update(sample(7,{held=false}));assert(r:update(sample(7)))
assert(not r:update(sample(7.1,{done=true})))
assert(not r:update(sample(7.2)),'completed attempt needs a new press')
local before=finishes;r:cancel();r:cancel();assert(finishes==before,'cleanup is idempotent')
r:update(sample(8,{held=false}));assert(r:update(sample(8)))
assert(r:update(sample(8.2)))
assert(not r:update(sample(8.1)),'clock rollback within an attempt is not elapsed progress')
r:update(sample(9,{held=false}));assert(r:update(sample(9)))
r:update(nil);assert(not r:update(sample(9.1)),'pause cannot restart while grab is still held')
r:update(sample(9.2,{held=false}));assert(r:update(sample(9.3)))
assert(not r:update(sample(9.4,{done=true,valid=false})),'invalid arrival never wins over cancellation')
local failed=0;local unavailable=Rescue.new({start=function()failed=failed+1 end})
unavailable:update(sample(0));unavailable:update(sample(.1));assert(failed==1,'missing asset does not retry every frame')
print('PASS: ledge rescue hold, release, ownership, readiness, completion and frame-gap cancellation.')

-- Adapter boundary: F5 selects an actual hanging interface, either player can help,
-- and cleanup must not stop another system\'s animation.
local Native=require('ledge_rescue_native')
local objects={};local function obj(id)
 local o={id=id};objects[id]=o
 function o:GetAddress()return self.id end
 return o
end
local w=obj(1);local p=obj(2);local q=obj(3);local pc=obj(4);local qc=obj(5)
local edge=obj(6);local interface=obj(7);local asset=obj(8);local class=obj(9)
local climbAsset=obj(10)
local moved,stopped,plays=0,0,0;local time=0;local down=true
local rescueLogs={}
local c={state={enabled=true},spawn={phase='active'},death={},gamepad={owner=1},
 driver={pawn=q,pc=qc},p1=function()return pc end,foreground=function()return true end,
 input=function()return {grab=down}end,physicalKey=function()return down end,
 log=function(message)rescueLogs[#rescueLogs+1]=message end,
 live=function(o)return type(o)=='table'and o.id~=nil end,
 same=function(a,b)return a~=nil and a==b end,world=function()return true end,
 UE={GetGameplayStatics=function()return {IsGamePaused=function()return false end,GetTimeSeconds=function()return time end}end}}
pc.Pawn=p;qc.Pawn=q;p.Controller=pc;q.Controller=qc
pc.IsMoveInputIgnored=function()return false end
pc.IsInputKeyDown=function()return down end
local ticking=true
pc.IsActorTickEnabled=function()return ticking end
pc.SetActorTickEnabled=function(_,value)ticking=value end
local function pawn(o,z)
 o.GetWorld=function()return w end;o.IsAlive=function()return true end
 o.K2_GetActorLocation=function()return {X=0,Y=0,Z=z}end
 o.GetActorForwardVector=function()return {X=1,Y=0,Z=0}end
 o.rotation={Pitch=0,Yaw=45,Roll=0}
 o.K2_GetActorRotation=function()return o.rotation end
 o.K2_SetActorRotation=function(_,value)o.rotation=value;return true end
 o.CharacterMovement={MovementMode=1,StopMovementImmediately=function()end}
 o.GetPlayerPickupInterface=function()end
 o.Controller.mBodyAnimator=obj(o.id+20)
 local lastMove={X=0,Y=0,Z=0}
 o.Controller.mBodyAnimator.SetMoveInput=function(_,d)lastMove=d;if d.X~=0 or d.Y~=0 then moved=moved+1 end end
 o.Controller.mBodyAnimator.GetMoveInput=function()return lastMove end
 o.Controller.mBodyAnimator.ClearMoveInput=function()end
 o.Controller.mBodyAnimator.SetRawMoveInput=function()end
 o.Controller.PlayerCameraManager={GetCameraRotation=function()return {Yaw=0}end}
 o.anim=obj(o.id+30);o.anim.mLedgeData={mIsHanging=false}
 o.Mesh=obj(o.id+40);o.Mesh.GetAnimInstance=function()return o.anim end
 o.mAnimationControlComponent=obj(o.id+50)
 local ac=o.mAnimationControlComponent
 ac.IsPlayingOverrideAnimation=function()return ac.mCurrentAnimStateAsset~=nil end
 o.mAnimationOverrideComponent={PlayAnimationSequenceOverride2=function(_,a,restriction)
  plays=plays+1;ac.mCurrentAnimStateAsset=a;ac.mMovementRestrictionMode=restriction
  o.CharacterMovement.MovementMode=0 end,
  StopAnimationSequenceOverride=function()
   stopped=stopped+1;ac.mCurrentAnimStateAsset=nil;ac.mMovementRestrictionMode=0
   o.CharacterMovement.MovementMode=1 end}
end
pawn(p,0);pawn(q,70)
edge.IsLedgeEnabled=function()return true end;edge.mAllowClimbUpOnTop=true;edge.GetFullName=function()return 'test ledge'end
interface.IsA=function(_,x)return x==class end;interface.mCurrentLedge=edge
interface.InitialGrabDirection={X=-1,Y=0,Z=0}
interface.mClimbFromHangParams={mAnimation=climbAsset}
interface.mClimbFromFreeHangParams={mAnimation=climbAsset}
p.anim.mLedgeData.mIsHanging=true;p.anim.mCurrentlyActiveGrabInterface=interface
local oldStatic=StaticFindObject
StaticFindObject=function(path)
 if path=='/Script/Helios.LedgeClimbingInterface'then return class end
 if path:find('DragPullStepBack',1,true)then return asset end
 return {ActionMappings={{ActionName={ToString=function()return 'Grab'end},Key={KeyName={ToString=function()return 'LeftMouseButton'end}}}}}
end
local n=Native.new(c);n:select();assert(n.selection.edge==edge)
local observation={driven=true,requestAt=0,p=p,pc=pc,interface={mGrabbingState=3},
 climbAsset=climbAsset,origin={Z=0}}
n:observeClimb(observation,{now=.5})
assert(observation.diagnosed and not observation.observedClimb,'sending a request is not proof of native ascent')
assert(rescueLogs[#rescueLogs]:find('entrada=',1,true),'diagnostic includes the actual animator input')
observation.interface.mGrabbingState=4;p.anim.mLedgeData.mClimbAnimation=climbAsset
n:observeClimb(observation,{now=.6})
assert(observation.observedClimb and n:noticeText():find('iniciada',1,true),'native traversal must be observed before announcing ascent')
assert(n:update(false)and plays==1)
assert(n.control.active.direction.X==1,'climb direction follows current pawn facing, not a stale initial grab vector')
assert(not ticking,'P1 tick is suspended while the rescue owns its input')
down=false;time=.1;assert(not n:update(false)and stopped==1 and moved==0)
assert(ticking,'cancel restores the previous P1 tick state')
down=true;time=.2;assert(n:update(false))
for i=1,6 do time=.2+i*.2;assert(n:update(false))end
assert(moved>0,'owned NoMovement animation must survive until native climb is requested')
local position=q.K2_GetActorLocation
q.K2_GetActorLocation=function()return {X=0,Y=0,Z=60}end
local drift=n:snapshot(false)
assert(not drift.valid and drift.reason:find('sin apoyo',1,true),'immobilized helper cannot drift off its grounded anchor')
q.K2_GetActorLocation=position
q.mAnimationControlComponent.mCurrentAnimStateAsset=obj(99)
time=1.5;assert(not n:update(false)and stopped==1,'foreign override is preserved')
n:select();assert(not n.selection,'F5 toggles the selection off')
q.mAnimationControlComponent.mCurrentAnimStateAsset=nil
q.CharacterMovement.MovementMode=1
p.anim.mLedgeData.mIsHanging=false;q.anim.mLedgeData.mIsHanging=true
p.anim.mCurrentlyActiveGrabInterface=nil;q.anim.mCurrentlyActiveGrabInterface=interface
p.K2_GetActorLocation=function()return {X=0,Y=0,Z=140}end
n:select();assert(n.selection);assert(n:update(false),'P1 can rescue P2 with configured grab')
c.state.menu=true;assert(not n:update(false)and not n.control.active,'menu releases animation ownership')
assert(ticking,'menu cancellation restores P1 tick')
c.state.menu=false;time=2
assert(not n:update(false),'closing the menu while holding does not restart')
down=false;n:update(false);down=true;time=2.1;assert(n:update(false))
local physical={x=1,y=-1,grab=true,jump=true,use=true,sprint=true,gadget=true,sneak=true}
local dir={X=1,Y=0,Z=0};local Input=require('coop_input')
local rd,ri=n:route(dir,physical,90)
assert(rd.X==0 and rd.Y==0 and ri.grab and not ri.jump and not ri.use,
 'P2 victim holds its own grab while preparation suppresses competing inputs')
assert(physical.jump and physical.use and physical.x==1,'routing never mutates the physical input sample')
n.control.active.driven=true
for _,yaw in ipairs({0,90,-90,180})do
 rd,ri=n:route(dir,physical,yaw)
 local decoded=Input.direction(ri.x,ri.y,yaw)
 assert(math.abs(decoded.X-rd.X)<.00001 and math.abs(decoded.Y-rd.Y)<.00001,
  'camera-relative raw movement and world movement request the same climb')
end
local active=n.control.active
q.anim.mLedgeData.mIsHanging=false
q.K2_GetActorLocation=function()return {X=0,Y=0,Z=0}end
assert(not n:snapshot(false).done,'landing below the ledge must not report successful rescue')
q.K2_GetActorLocation=function()return {X=0,Y=0,Z=140}end
assert(n:snapshot(false).done,'arrival on the upper platform can finish the rescue')
local fresh=obj(100);fresh.mBodyAnimator=obj(101)
fresh.mBodyAnimator.ClearMoveInput=function()error('replacement controller touched')end
q.Controller=fresh
assert(not n:update(false),'replacement controller cancels without writing to its input')
assert(ticking,'replacement of the other controller still restores P1 tick')
q.Controller=qc
assert(n:noticeText(),'cancellation reason is available to the HUD')
-- Helper role must suppress native grab as well, otherwise it can start a
-- hand-holding interaction in the middle of the rescue override.
n.control.active={p=p,h=q,driven=true,direction=dir}
rd,ri=n:route(dir,physical,0)
assert(rd.X==0 and rd.Y==0 and not ri.grab and not ri.jump and not ri.use,'P2 helper is isolated from normal actions')
n.control.active=nil
rd,ri=n:route(dir,physical,0);assert(rd==dir and ri==physical,'ordinary input is untouched outside a rescue')
local releases=0
interface.ReleaseGrab=function(_,option)
 assert(option==0);releases=releases+1;interface.mGrabbingState=0;interface.mCurrentLedge=nil
end
local function prepare()
 n=Native.new(c);time=time+1;down=true;c.state.menu=false
 p.anim.mLedgeData.mIsHanging=false;q.anim.mLedgeData.mIsHanging=true
 p.anim.mCurrentlyActiveGrabInterface=nil;q.anim.mCurrentlyActiveGrabInterface=interface
 p.mAnimationControlComponent.mCurrentAnimStateAsset=nil;q.mAnimationControlComponent.mCurrentAnimStateAsset=nil
 p.CharacterMovement.MovementMode=1;q.CharacterMovement.MovementMode=1
 p.K2_GetActorLocation=function()return {X=20,Y=0,Z=140}end
 q.K2_GetActorLocation=function()return {X=0,Y=0,Z=70}end
 interface.mControlledPawn=q;interface.mCurrentLedge=edge;interface.mGrabbingState=3
 n:select();assert(n:update(false));return n.control.active
end
local a=prepare()
assert(p.rotation.Yaw==180,'helper faces the hanging Mono')
n.control:cancel('agarre soltado')
assert(releases==0 and ticking and p.rotation.Yaw==45,'early cancel preserves hang and restores helper facing')
a=prepare();a.driven=true;interface.mGrabbingState=4
q.anim.mLedgeData.mClimbAnimation=climbAsset
n.control:cancel('agarre soltado')
assert(releases==1 and a.aborted and ticking,'native AnimBP climb can be aborted without a scripted animation override')
a=prepare();a.driven=true;interface.mGrabbingState=4
q.anim.mLedgeData.mClimbAnimation=climbAsset;q.mAnimationControlComponent.mCurrentAnimStateAsset=climbAsset
n.control:cancel('agarre soltado')
assert(releases==2 and a.aborted and ticking,'cancel tears down only the owned native climb and restores P1')
a=prepare();a.driven=true;interface.mGrabbingState=4
q.mAnimationControlComponent.mCurrentAnimStateAsset=obj(102)
n.control:cancel('interrumpido')
assert(releases==2 and ticking,'foreign victim animation is not aborted')
a=prepare();a.driven=true;interface.mGrabbingState=4
q.mAnimationControlComponent.mCurrentAnimStateAsset=climbAsset
interface.ReleaseGrab=function()error('simulated native release failure')end
n.control:cancel('agarre soltado')
assert(ticking and not p.mAnimationControlComponent.mCurrentAnimStateAsset,
 'failure in native teardown cannot skip restoration of controller or helper animation')
-- Startup failure after acquiring P1 must restore both tick and rotation.
local play=p.mAnimationOverrideComponent.PlayAnimationSequenceOverride2
n=Native.new(c);time=time+1;down=true;p.CharacterMovement.MovementMode=1
q.mAnimationControlComponent.mCurrentAnimStateAsset=nil;interface.mGrabbingState=3
p.mAnimationOverrideComponent.PlayAnimationSequenceOverride2=function()error('simulated animation failure')end
n:select();assert(not n:update(false))
assert(ticking and p.rotation.Yaw==45 and not n.pending,'partial startup rolls back controller and facing')
p.mAnimationOverrideComponent.PlayAnimationSequenceOverride2=play
StaticFindObject=oldStatic
print('PASS: native ledge selection, both roles, mapped grab, helper animation cleanup and menu cancellation.')
local Physical=require('rescue_input')
local pressed={}
local function read(key)return pressed[key]or false end
assert(Physical.code('F5')==116 and Physical.code('LeftMouseButton')==1 and Physical.code('O')==79)
local map={{key='LeftMouseButton',shift=true}}
pressed[1]=true
assert(Physical.held(map,read)==false,'required mapping modifier must also be held')
pressed[161]=true;assert(Physical.held(map,read))
pressed[1]=false;assert(Physical.held(map,read)==false,'release remains observable independently of controller tick')
assert(Physical.held({{key='unsupported'}},read)==nil,'unknown physical mapping fails closed')
print('PASS: physical grab input, modifiers, release and unsupported bindings.')
