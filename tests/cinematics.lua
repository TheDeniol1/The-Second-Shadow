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
local tableClip='ANIM_Player_CallSixunderBedFullScene'
local function animName(name)return 'AnimSequence /Game/Characters/Player/Animations/'..name..'.'..name end
local sample={p=first,q=second,asset=asset,key=animName(tableClip)}
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
n:tick(hunter,{now=10.7,key=sample.key})
assert(hunter.phase=='waiting','do not react immediately on arrival')
n:tick(hunter,{now=10.8,key=sample.key})
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

-- The cinematic owns walking only while still approaching the mark.
timed.active=hunter
hunter.driving=true;assert(timed:driving())
hunter.driving=false;assert(not timed:driving())

-- Story reactions use their own clip and leave the actor at its current location.
local playing=false
second.mAnimationControlComponent.IsPlayingOverrideAnimation=function()return playing end
second.mAnimationOverrideComponent.PlayAnimationSequenceOverride2=function(_,a,restriction,loop)
 assert(a==reaction and restriction==1 and not loop,'reaction uses an in-place movement restriction')
 second.mAnimationControlComponent.mCurrentAnimStateAsset=a
 playing=true
end
sample.asset=asset
for _,name in ipairs({'ANIM_Player_ReactSixFall','ANIM_Player_ShedHatch_PushAndFall','ANIM_Player_HittingMusicBoxVoidLong'})do
 sample.key=animName(name)
 local before=current
 local response=assert(n:start(sample));response.since=15
 assert(response.asset==reaction and response.reaction and current==before,'P2 plays an independent response without relocating')
 assert(n:tick(response,{now=15.2}) and not n:tick(response,{now=17}), 'the reaction has a bounded duration')
 second.mAnimationControlComponent.mCurrentAnimStateAsset=asset
 assert(not n:tick(response,{now=15.4}),'a native clip takes ownership')
 local previousStops=stopped
 n:finish(response)
 assert(stopped==previousStops,'cleanup preserves the new native override')
 playing=false
end
current={X=500,Y=50,Z=30}
assert(not n:start(sample),'a far-away P2 is left with the regular controls')
current={X=10,Y=20,Z=30}
sample.key=animName('ANIM_Player_BarnFloorBreak')
assert(not n:start(sample),'a barn clip at unrelated coordinates cannot take control')

local primaryPC=object()
local secondaryPC=object()
primaryPC.Pawn=first;first.Controller=primaryPC
secondaryPC.Pawn=second;second.Controller=secondaryPC
first.IsAlive=function()return true end
second.IsAlive=first.IsAlive
second.GetAddress=function()return 43 end
first.mAnimationControlComponent.valid=true
first.mAnimationControlComponent.mCurrentAnimStateAsset=asset
first.mAnimationControlComponent.IsPlayingOverrideAnimation=function()return true end
local voidHit=animName('ANIM_Player_HittingMusicBoxVoidLong')
asset.GetFullName=function()return voidHit end
n.c.p1=function()return primaryPC end
n.c.driver.pc=secondaryPC;n.c.spawn={phase='active'};n.c.death={}
n.c.UE={GetGameplayStatics=function()return {IsGamePaused=function()return false end,GetTimeSeconds=function()return 15 end}end}
first.GetFullName=function()return 'BP_PlayerPawn_C /Game/Levels/School/PLVL_School.Test' end
assert(not n:snapshot().key,'an override reused in the wrong chapter does not start a profile')
first.GetFullName=function()return 'BP_PlayerPawn_C /Game/Levels/Transmission/PLVL_Transmission.Test' end
assert(n:snapshot().key==voidHit,'the exact story asset in its intended chapter can start')
StaticFindObject,LoadAsset=oldStatic,oldLoad
print('PASS: Hunter gun stays with P1; P2 reaction asset, swept retreat, pause and independent completion.')
print('PASS: observed wilderness and music-box reactions, in-place playback, range, deadline and ownership.')

local collapseKey=animName('ANIM_Player_BarnFloorBreak')
local exitKey=animName('ANIM_Player_BarnToSwamp')
local landingClip=object();landingClip.SequenceLength=1.2
local anchor=object()
local firstAt,secondAt
local lastClip,restriction,attemptedLanding
local availableGround=true
first.K2_GetActorLocation=function()return firstAt end
first.CharacterMovement=object();first.CharacterMovement.MovementMode=1
second.K2_GetActorLocation=function()return secondAt end
second.K2_SetActorLocationAndRotation=function(_,at) secondAt=at;return true end
second.K2_SetActorLocation=function(_,at) secondAt=at;return true end
second.mAnimationOverrideComponent.PlayAnimationSequenceOverride2=function(_,clip,mode,loop)
 assert(not loop)
 lastClip,restriction=clip,mode
 second.mAnimationControlComponent.mCurrentAnimStateAsset=clip
 playing=true
end
second.mAnimationOverrideComponent.StopAnimationSequenceOverride=function()
 playing=false;stopped=stopped+1
end
asset.SequenceLength=3
asset.Notifies={{Notify=object()}}
asset.Notifies[1].Notify.GetFullName=function()return 'AnimNotify_AkEvent_C marker' end
first.mAnimationControlComponent.mMovementRestrictionMode=3
n.c.landing=function(p,q,at,accepts)
 assert(p==first and q==second and at==firstAt)
 attemptedLanding=(attemptedLanding or 0)+1
 local candidate={X=at.X-110,Y=at.Y,Z=at.Z+4}
 if availableGround and accepts(candidate) then return candidate end
end
StaticFindObject=function(path)
 if path:find('LandingConcussive',1,true) then return landingClip end
 if path:find('Trigger_WindowCrash',1,true) then return anchor end
 if path:find('DragPullStepBack',1,true) then return reaction end
end
local barn=C.new(n:api())
local function frame(now,key,paused)
 return barn:update({now=now,key=key,p=first,q=second,first=42,second=43,
  asset=asset,ready=true,paused=paused})
end

local trunkKey=animName('ANIM_Player_FallOutOfTrunk')
firstAt,secondAt={X=-5603,Y=-10027,Z=518},{X=-5490,Y=-10050,Z=518}
frame(18,nil)
assert(frame(18.016,trunkKey) and lastClip==reaction and restriction==1
 and secondAt.X==-5490,'P2 reacts without taking over P1’s fall or moving to the trunk')
assert(barn:keepsSplit(),'a local reaction can own input while both views remain active')
assert(frame(18.1,nil),'the short P2 reaction can finish after the native fall')
playing=false
assert(not frame(18.2,nil),'the end of the reaction restores input')
local foxHole=animName('ANIM_Player_FallDownFoxHole')
assert(not frame(18.3,foxHole),'the foxhole clip only starts a reaction at the recorded passage')
firstAt,secondAt={X=-4962,Y=20567,Z=-110},{X=-5030,Y=20360,Z=-87}
frame(18.4,nil)
assert(frame(18.416,foxHole) and lastClip==reaction and secondAt.Y==20360,
 'P2 reacts beside the opening while the original fall stays on P1')
barn:reset()
print('PASS: both Wilderness falls cue P2 from its own position and restore play.')

local hunterPickup=animName('ANIM_Player_HunterShedGrabRifleFall')
local huntScene=C.new(n:api())
local function huntFrame(time,key)
 return huntScene:update({first=42,second=43,ready=true,now=time,key=key,p=first,q=second,asset=asset})
end
n.c.active=function()return huntScene.active end
n.c.p1=function()return primaryPC end
n.c.clear=function()return allowed end
local huntAt={X=-4390,Y=47060,Z=-48}
firstAt,secondAt={X=-4412,Y=47414,Z=117},huntAt
huntFrame(18.5,nil)
assert(huntFrame(18.516,hunterPickup) and huntScene:keepsSplit() and secondAt==huntAt,
 'the rifle pickup starts the approach on P2’s floor without snapping either actor')
local preparing=huntScene.active
local previousMoves=approachMoves
huntFrame(18.532,hunterPickup)
assert(approachMoves==previousMoves+1 and preparing.phase=='approach')
firstAt={X=-4466,Y=47192,Z=-51}
local shoot=animName('ANIM_Player_HunterShedShoot_SideA')
huntFrame(18.548,shoot)
assert(huntScene.active==preparing and not huntScene:keepsSplit(),
 'the shot clip keeps the same action and switches to the native cinematic view')
previousMoves=approachMoves
n:shot(emitter,shot)
huntFrame(18.564,shoot)
assert(preparing.phase=='reaction' and approachMoves==previousMoves and secondAt==huntAt and lastClip==reaction,
 'a shot while P2 is still walking cues the reaction from the current position')
assert(huntFrame(18.6,nil),'the reaction can finish after the primary override ends')
huntScene:reset()

allowed=false;firstAt={X=-4412,Y=47414,Z=117}
huntFrame(18.7,nil)
assert(not huntFrame(18.716,hunterPickup),'unsafe approach does not take over P2')
allowed=true;firstAt={X=-4466,Y=47192,Z=-51}
assert(huntFrame(18.732,shoot),'the original shot onset can still start when the early approach was unavailable')
huntScene:reset()
print('PASS: the Hunter pickup stages P2 early, preserves the shot cue and recovers if preparation is unavailable.')

firstAt,secondAt={X=-5115,Y=33152,Z=651},{X=-5070,Y=32995,Z=665}
frame(20,nil)
assert(frame(20.016,collapseKey) and barn:protectsSeparation() and lastClip==asset and restriction==3,
 'the verified collapse uses the primary root-motion mode and takes only P2 input')
assert(not barn:keepsSplit(),'a directed camera can use its existing layout during the shared drop')
assert(secondAt.X~=firstAt.X,'P2 enters a distinct lane')
firstAt,secondAt={X=-5115,Y=33346,Z=705},{X=-5235,Y=33348,Z=706}
assert(frame(20.1,nil),'P2 can finish its own clip after P1 finishes')
playing=false
assert(not frame(20.2,nil) and not barn:protectsSeparation(),'players already together need no automatic move')

firstAt,secondAt={X=-4900,Y=35532,Z=834},{X=-5105,Y=32662,Z=712}
local oldAt=secondAt
assert(not frame(21,nil))
assert(not frame(21.016,exitKey) and barn:protectsSeparation() and secondAt==oldAt,
 'a late player keeps control while the native exit plays')
firstAt={X=-4860,Y=35888,Z=-335}
first.CharacterMovement.MovementMode=3
assert(not frame(21.2,nil) and not attemptedLanding,'wait until P1 reaches the ground')
first.CharacterMovement.MovementMode=1
assert(not frame(21.3,nil,true) and not attemptedLanding,'pause does not relocate the player')
availableGround=false
assert(not frame(21.4,nil) and attemptedLanding==1 and secondAt==oldAt,'unsafe destination cannot move P2')
availableGround=true
assert(frame(21.7,nil) and lastClip==landingClip and restriction==1 and secondAt.Z==-331,
 'a supported destination in the correct zone lets P2 land at the other end')
assert(not frame(23,nil) and not barn:protectsSeparation() and not playing,'landing releases camera and input')

firstAt,secondAt={X=-4900,Y=35532,Z=834},{X=-4880,Y=35390,Z=827}
asset.Notifies={{NotifyName='GameplayEvent'}}
lastClip=nil
assert(not frame(23.03,exitKey) and barn:protectsSeparation() and lastClip==nil,
 'an unclassified notify cannot run again on P2')
barn:reset()
assert(not barn:protectsSeparation(),'checkpoint reset cancels pending recovery')
print('PASS: collapse and swamp drop, distinct lanes, notify guard, late landing, pause, floor and cleanup.')

local window='LevelSequence /Game/Levels/PaleCity/LevelSequencers/SEQ_280_WindowCrash.SEQ_280_WindowCrash'
local windowAsset=object();windowAsset.GetFullName=function()return window end
n.c.sequence=function(actor,p)
 assert(p==first)
 if actor:find('BP_SEQ_WindowCrash',1,true) then return windowAsset end
end
first.GetFullName=function()return 'BP_PlayerPawn_C /Game/Levels/PaleCity/PLVL_PaleCIty.Test' end
local shotFrame=n:snapshot()
assert(shotFrame.key==window and shotFrame.allowInput,'exact sequence actor and asset selects the city scene')
firstAt,secondAt={X=0,Y=0,Z=0},{X=25,Y=20,Z=0}
anchor.K2_GetActorLocation=function()return {X=700,Y=0,Z=0} end
assert(not n:start(shotFrame),'players outside the trigger area cannot react')
anchor.K2_GetActorLocation=function()return {X=0,Y=0,Z=0} end
local canceled=0
n.c.driver.stop=function()canceled=canceled+1 end
local city=assert(n:start(shotFrame))
assert(city.passThrough and canceled==0 and lastClip==reaction and restriction==0,
 'the in-game window crash permits movement while P2 reacts')
n:finish(city)
local clothesline='LevelSequence /Game/Levels/PaleCity/LevelSequencers/SEQ_4_375_TVClothesline_DoorFalls.SEQ_4_375_TVClothesline_DoorFalls'
local doorAsset=object();doorAsset.GetFullName=function()return clothesline end
n.c.sequence=function(actor)
 if actor:find('LVL_4_375_TVClothesline',1,true) then return doorAsset end
end
local doorFrame=n:snapshot()
assert(doorFrame.key==clothesline and doorFrame.allowInput,'the clothesline door has its own trigger and matching active sequence')
StaticFindObject,LoadAsset=oldStatic,oldLoad
print('PASS: active LevelSequence profile with an exact trigger, distance validation and uninterrupted controls.')

local now=30
n.c.UE={GetGameplayStatics=function()return {IsGamePaused=function()return false end,GetTimeSeconds=function()return now end}end}
n.c.sequence=nil
local schoolFall=animName('ANIM_Player_Hoist300_FallEnd')
first.GetFullName=function()return 'BP_PlayerPawn_C /Game/Levels/School/PLVL_School.Test' end
asset.GetFullName=function()return schoolFall end
StaticFindObject=function(path)
 if path:find('DragPullStepBack',1,true) then return reaction end
end
assert(not n:start(n:snapshot()),'a School fall clip played elsewhere does not cue the companion')
firstAt,secondAt={X=-3020,Y=-29605,Z=-2055},{X=-2960,Y=-29690,Z=-2055}
local schoolReaction=assert(n:start(n:snapshot()))
assert(schoolReaction.passThrough and lastClip==reaction and restriction==0 and secondAt.X==-2960,
 'at the observed School fall, P2 reacts while still able to move')
n:finish(schoolReaction)

local duck=object();duck.SequenceLength=.7;duck.Notifies={}
duck.GetFullName=function()return animName('ANIM_Player_StandToCrouch')end
local callback
local oldHook=RegisterHook
local doctorPath='/Script/Helios.DoctorBedLiftingPattern:OnTargetGrabbed'
StaticFindObject=function(path)
 if path==doctorPath then return object() end
 if path:find('ANIM_Player_StandToCrouch',1,true) then return duck end
end
RegisterHook=function(path,_,post)
 if path==doctorPath then callback=post end
end
n:install()
assert(callback,'register the post hook after the native target has been read')
local function caught(pawn)
 callback(nil,nil,{get=function()return pawn end})
end
caught(first)
assert(not n.doctorCue,'a reaction is excluded outside the Hospital')
first.GetFullName=function()return 'BP_PlayerPawn_C /Game/Levels/Hospital/PLVL_Hospital.Test' end
firstAt,secondAt={X=0,Y=0,Z=0},{X=65,Y=0,Z=0}
first.GetPlayerPickupInterface=second.GetPlayerPickupInterface
first.Mesh=second.Mesh
first.CharacterMovement.StopMovementImmediately=function()end
primaryPC.IsMoveInputIgnored=function()return false end
first.mAnimationControlComponent.mCurrentAnimStateAsset=nil
local firstPose
first.mAnimationControlComponent.IsPlayingOverrideAnimation=function()return firstPose~=nil end
first.mAnimationOverrideComponent=object()
first.mAnimationOverrideComponent.PlayAnimationSequenceOverride2=function(_,clip,mode)
 assert(mode==0);firstPose=clip;first.mAnimationControlComponent.mCurrentAnimStateAsset=clip
end
first.mAnimationOverrideComponent.StopAnimationSequenceOverride=function()firstPose=nil end
caught(object())
assert(not n:snapshot().key,'ignore targets that are neither local player')
caught(first)
local hospitalReaction=assert(n:start(n:snapshot()))
assert(hospitalReaction.pawn==second and hospitalReaction.passThrough and lastClip==duck and restriction==0,
 'P2 reacts to the native Doctor grab without gaining control over P1 or moving')
n:finish(hospitalReaction)
caught(first)
assert(not n:snapshot().key,'duplicates cannot replay the reaction')
now=31
caught(second)
local otherReaction=assert(n:start(n:snapshot()))
assert(otherReaction.pawn==first and firstPose==duck and otherReaction.primaryReaction,
 'P1 participates if the Doctor catches P2 first')
n:finish(otherReaction)
assert(not firstPose,'the companion reaction releases the exact primary override')
now=32;second.bIsCrouched=true;caught(first)
assert(not n:start(n:snapshot()),'a companion already crouching keeps the existing pose')
StaticFindObject,LoadAsset,RegisterHook=oldStatic,oldLoad,oldHook
print('PASS: the School fall and native Hospital grab animate the companion on their matching scene and role.')
