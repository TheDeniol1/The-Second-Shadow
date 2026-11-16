local C=require('coop_cinematics')
local starts,finishes=0,0
local c=C.new({start=function()starts=starts+1;return {duration=20}end,
 finish=function()finishes=finishes+1 end})
local function s(t,key,paused,first,ready)
 return {first=first or 1,second=2,key=key,now=t,paused=paused,ready=ready~=false}
end
assert(not c:update(s(0,'scene'))and starts==0,'never join an already-running animation at activation')
c:update(s(1,nil));assert(c:update(s(1.016,'scene'))and starts==1,'enter on observed onset')
c:update(s(2,'scene'));assert(starts==1,'animation plays only once')
assert(c:update(s(2,'scene',true)),'paused scene retains ownership')
assert(not c:update(s(3,nil))and finishes==1,'native completion restores input')
c:update(s(4,nil));assert(not c:update(s(5,'scene')),'long observation gap cannot restart a scene late')
c:update(s(6,nil));assert(c:update(s(6.016,'scene')))
assert(not c:update(s(6.032,'scene',false,3))and finishes==2,'pawn replacement releases old scene')
c:update(s(7,nil));assert(c:update(s(7.016,'scene')))
assert(not c:update(s(7.032,'scene',false,1,false))and finishes==3,'death or checkpoint cancels scene')
c:update(s(8,nil));assert(c:update(s(8.016,'scene')))
assert(not c:update(s(31,'scene'))and finishes==4,'missing native completion has a bounded exit')
c:update(s(32,nil));assert(c:update(s(32.016,'scene')))
c:reset();c:reset();assert(finishes==5,'cleanup is idempotent')
local rejected=0
local reject=C.new({start=function()rejected=rejected+1 end,finish=function()error('no ownership')end})
reject:update(s(0,nil));reject:update(s(.016,'scene'));reject:update(s(.032,'scene'))
assert(rejected==1,'unsafe placement is not retried halfway through an animation')

local N=require('cinematic_native')
local function object()return {valid=true}end
local asset=object();asset.SequenceLength=15
local first,second=object(),object()
first.mAnimationControlComponent={mMovementRestrictionMode=2}
local original={X=10,Y=20,Z=30};local moved,played,stopped=0,0,0
local lastPosition,lastRestriction
first.K2_GetActorLocation=function()return {X=0,Y=0,Z=30}end
first.K2_GetActorRotation=function()return {Yaw=-90,Pitch=0,Roll=0}end
second.K2_GetActorLocation=function()return original end
second.K2_GetActorRotation=first.K2_GetActorRotation
second.K2_SetActorRotation=function()end
second.K2_SetActorLocationAndRotation=function(_,at) lastPosition=at;moved=moved+1;return true end
second.mAnimationControlComponent=object()
second.mAnimationControlComponent.IsPlayingOverrideAnimation=function()return false end
second.mAnimationOverrideComponent=object()
second.mAnimationOverrideComponent.PlayAnimationSequenceOverride2=function(_,a,restriction,loop)
 assert(a==asset and not loop);lastRestriction=restriction;played=played+1
 second.mAnimationControlComponent.mCurrentAnimStateAsset=asset
end
second.mAnimationOverrideComponent.StopAnimationSequenceOverride=function()stopped=stopped+1 end
second.CharacterMovement=object();second.CharacterMovement.MovementMode=1
second.CharacterMovement.StopMovementImmediately=function()end
second.Mesh=object();second.Mesh.GetAnimInstance=function()return object()end
second.GetPlayerPickupInterface=function()return nil end
local allowed=true
local n=N.new({live=function(o)return o and o.valid end,same=function(a,b)return a==b end,
 driver={pawn=second,stop=function()end},clear=function()return allowed end,log=function()end})
local sample={p=first,q=second,asset=asset,key='scene'}
allowed=false;local fallback=assert(n:start(sample))
assert(lastPosition==original and lastRestriction==2 and played==1,
 'blocked lane still participates from existing position with physical root motion')
n:finish(fallback)
first.mAnimationControlComponent.mMovementRestrictionMode=3
allowed=true;local active=assert(n:start(sample))
assert(moved==2 and played==2 and lastRestriction==3,'safe placement plays the original asset with its native restriction')
n:finish(active);assert(stopped==2,'owned animation can be released')
second.mAnimationControlComponent.mCurrentAnimStateAsset=object()
n:finish(active);assert(stopped==2,'cleanup must not interrupt an unrelated native animation')
second.CharacterMovement.MovementMode=3
assert(not n:start(sample)and played==2,'do not take control of airborne P2')
print('PASS: cinematic onset, pause, completion, death, replacement, timeout, placement and animation ownership.')

-- Hunter reaction is a separate asset and can finish before the gun scene.
local oldStatic,oldLoad=StaticFindObject,LoadAsset
local reaction=object();reaction.SequenceLength=1.5
StaticFindObject=function(path)
 assert(path:find('ANIM_Player_DragPullStepBack',1,true));return reaction
end
LoadAsset=function()error('already loaded')end
second.CharacterMovement.MovementMode=1
local current={X=10,Y=20,Z=30};local sweepCalls=0
second.K2_GetActorLocation=function()return {X=current.X,Y=current.Y,Z=current.Z}end
second.K2_SetActorLocationAndRotation=function(_,at)current=at;return true end
second.K2_SetActorLocation=function(_,at,sweep)
 assert(sweep,'retreat must sweep against furniture');sweepCalls=sweepCalls+1;current=at;return true
end
second.mAnimationOverrideComponent.PlayAnimationSequenceOverride2=function(_,a,restriction,loop)
 assert(a==reaction and restriction==2 and not loop,'P2 uses a separate backward-step animation with physical root motion')
 second.mAnimationControlComponent.mCurrentAnimStateAsset=a
end
sample.key='AnimSequence /Game/Characters/Player/Animations/ANIM_Player_HunterShedShoot_SideA.ANIM_Player_HunterShedShoot_SideA'
local approachMoves=0
n.c.driver.api={move=function(_,direction)
 assert(math.abs(direction.X^2+direction.Y^2-1)<.001);approachMoves=approachMoves+1
end}
local beforeApproach=current
local hunter=assert(n:start(sample));hunter.since=9
assert(current==beforeApproach,'entry must never teleport P2')
n:tick(hunter,{now=9.1})
assert(approachMoves==1 and hunter.phase=='approach','approach uses animated native locomotion')
current=hunter.destination
n:tick(hunter,{now=10})
assert(hunter.phase=='waiting'and hunter.rotation.Yaw==-90,'arrival faces the door on the left and waits')
n:tick(hunter,{now=10.7})
assert(hunter.phase=='waiting','do not react immediately on arrival')
n:tick(hunter,{now=10.8})
assert(hunter.phase=='waiting','elapsed time alone cannot trigger the reaction')
local shot=object()
shot.GetFullName=function()return 'AkAudioEvent /Game/Audio/Events/Characters/Enemies/Hunter/Foley/Scenes/ShootingHunter/Play_ShotGunFire.Play_ShotGunFire'end
local emitter=object();local weapon=object()
weapon.GetFullName=function()return 'BP_RifleToolShed_C room:PersistentLevel.BP_RifleToolShed'end
emitter.GetOwner=function()return weapon end
first.GetAddress=function()return 42 end;hunter.first=42
n.c.active=function()return hunter end;n.c.state={enabled=true}
n.c.p1=function()return {Pawn=first}end;n.c.world=function()return true end
local other=object();other.GetFullName=function()return 'another gun sound'end
n:shot(emitter,other);assert(not hunter.shotObserved,'unrelated sounds cannot trigger fear')
n.c.world=function()return false end
n:shot(emitter,shot);assert(not hunter.shotObserved,'ignore sounds from another world')
n.c.world=function()return true end
n:shot(emitter,shot);assert(hunter.shotObserved,'exact native rifle event releases waiting P2')
n:tick(hunter,{now=10.8})
assert(hunter.phase=='reaction','reaction requires an explicit shot signal')
assert(hunter.scene=='cazador'and hunter.asset==reaction,'gun trigger selects a distinct P2 response')
local start=current
n:tick(hunter,{now=11});n:tick(hunter,{now=11.2})
assert(current==start and sweepCalls==0,'Lua must not relocate P2 during native root motion')
assert(n:tick(hunter,{now=12.4})==false,'reaction releases on its own duration')
local ticks=0
local timed=C.new({start=function()return {duration=2}end,finish=function()end,
 tick=function()ticks=ticks+1;return false end})
timed:update(s(0,nil));assert(timed:update(s(.016,'scene')))
assert(timed:update(s(.016,'scene',true))and ticks==0,'pause does not advance the retreat')
assert(not timed:update(s(.032,'scene'))and ticks==1,'coordinator accepts reaction completion')
assert(not timed:update(s(.048,'scene')),'finished reaction does not replay while P1 continues shooting')
StaticFindObject,LoadAsset=oldStatic,oldLoad
print('PASS: Hunter gun stays with P1; P2 reaction asset, swept retreat, pause and independent completion.')
