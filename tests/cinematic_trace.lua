local Trace=require('cinematic_trace')
local oldFind,oldStatic,oldHook=FindAllOf,StaticFindObject,RegisterHook
local hooks,posts,logs={},{},{ }
local function object(name)return {valid=true,GetFullName=function()return name end}end
local ac=object('animation control');local ao=object('override')
local asset=object('intro animation');ac.mCurrentAnimStateAsset=asset
ac.IsPlayingOverrideAnimation=function()return true end
local pc=object('controller');pc.IsMoveInputIgnored=function()return true end
local pawn=object('Mono');pc.Pawn=pawn;pawn.Controller=pc
pawn.mAnimationControlComponent=ac;pawn.mAnimationOverrideComponent=ao
pawn.K2_GetActorLocation=function()return {X=1,Y=2,Z=3}end
local sequence=object('sequence');local playing=true
local player=object('sequence player')
player.IsPlaying=function()return playing end;player.IsPaused=function()return false end
player.GetObjectBindings=function(_,p)assert(p==pawn);return {1}end
local actor=object('intro scene');actor.SequencePlayer=player
actor.GetSequence=function()return sequence end
FindAllOf=function()return {actor}end
StaticFindObject=function()return object('function')end
RegisterHook=function(path,fn,post)hooks[path]=fn;posts[path]=post end
local state={enabled=true}
local trace=Trace.new({live=function(o)return o and o.valid end,same=function(a,b)return a==b end,
 world=function()return true end,p1=function()return pc end,driver={},state=state,
 log=function(s)logs[#logs+1]=s end,phase=function()return 'active'end})
trace:install();trace:update(1)
assert(table.concat(logs,'\n'):find('P1 bindings=1',1,true),'report the original player binding')
assert(trace:sequence('intro scene',pawn)==sequence,'an active actor can feed a scene profile')
trace.c.world=function()return false end
assert(not trace:sequence('intro scene',pawn),'a sequence from another world cannot feed a profile')
trace.c.world=function()return true end
local count=#logs;trace:update(1.1);trace:update(1.3)
assert(#logs==count,'unchanged scene snapshots must not flood the log')
local ctx={get=function()return ao end}
local arg={get=function()error('native pre-hook animation argument is not safe to resolve')end}
local callback=hooks['/Script/Helios.AnimationOverrideComponent:PlayAnimationSequenceOverride2']
callback(ctx,arg)
assert(logs[#logs]:find('P1 /Script/Helios.AnimationOverrideComponent:PlayAnimationSequenceOverride2',1,true),
 'attribute the request without accessing its native argument')
local stateCallback=hooks['/Script/Helios.AnimationControlComponent:PlayAnimationOverrideState']
stateCallback({get=function()return ac end},arg)
assert(logs[#logs]:find('P1 /Script/Helios.AnimationControlComponent:PlayAnimationOverrideState',1,true),
 'a nested request must not resolve its native animation argument either')
ac.mCurrentAnimStateAsset=object('active rescue animation')
trace:snapshot(false,false)
assert(logs[#logs]:find('asset=active rescue animation',1,true),'the active animation is still reported from its component')
count=#logs;callback({get=function()return object('Six component')end},arg)
assert(#logs==count,'ignore unrelated animation owners')
local partner=object('second Mono');trace.c.driver.pawn=partner
local pole=object('wall switch');local hang=object('hangable component')
local grabber=object('hanging interface');grabber.mControlledPawn=partner;grabber.mGrabbedHangable=hang
grabber.IsA=function(_,class)return class:GetFullName()=='/Script/Helios.PlayerHangableInterface'end
local anim=object('anim instance');anim.mCurrentlyActiveGrabInterface=grabber
partner.Mesh=object('mesh');partner.Mesh.GetAnimInstance=function()return anim end
StaticFindObject=function(path)return object(path)end
trace:grab(2,partner,false)
assert(logs[#logs]:find('Agarre P2 hanging interface objetivo=hangable component',1,true))
local class=object('BlueprintGeneratedClass Box_C')
local fn=object('Function Box_C:ExecuteUbergraph_Box')
function fn:ForEachProperty(cb)
 cb({GetFName=function()return {ToString=function()return 'CallFunc_GetHeliosPlayerPawn_ReturnValue' end}end,
  GetOffset_Internal=function()return 16 end})
end
function class:ForEachFunction(cb)cb(fn)end
function pole:GetClass()return class end
function pole:GetOuter()return object('Level Stairwell')end
function hang:GetOwner()return pole end
trace:grab(2,partner,true)
assert(logs[#logs-1]:find('GetHeliosPlayerPawn_ReturnValue@0x10',1,true),'F8 reports the targeted Blueprint lookup')
function hang:GetFullName()
 return 'HangableComponent /Game/Levels/School/SubLevels/LVL_2_040_AbandonedStairwell.LVL_2_040_AbandonedStairwell:PersistentLevel.PP_SwingableTemplate_BoxPushSwing.HangableComponent'
end
trace:grab(2,partner,false)
assert(trace.capturedStairwellSwing and logs[#logs-1]:find('GetHeliosPlayerPawn_ReturnValue@0x10',1,true),
 'the reported School prop captures its scripts on the first P2 grab without an F8 mark')
count=#logs;trace:grab(2,partner,false)
assert(#logs==count,'unchanged grab target does not flood the log')
local switch=assert(hooks['/Script/Helios.PuzzleWallSwitchActor:OnHangableComponentStartGrab'])
switch({get=function()return pole end},nil,{get=function()return grabber end})
assert(logs[#logs]:find('Interaccion StartGrab P2 objeto=wall switch',1,true),'attribute the native switch event to the actual grabber')
anim.mCurrentlyActiveGrabInterface=nil;trace:grab(2,partner,false)
assert(logs[#logs]:find('Agarre P2 -',1,true),'trace release of a known target')
trace.c.driver.pawn=nil
playing=false;trace:update(2)
assert(table.concat(logs,'\n'):find('ended/unloaded',1,true),'record scene completion')
assert(not trace:sequence('intro scene',pawn),'an unloaded scene no longer feeds a profile')
pc.IsMoveInputIgnored=function()return false end
trace:update(2.3)
ac.IsPlayingOverrideAnimation=function()return false end
trace:update(2.6)
assert(logs[#logs]:find('override=false inputBlocked=false',1,true),'return to playable state is logged even without a sequence player')
count=#logs;trace:update(2.9)
assert(#logs==count,'playable frames do not flood the log')
state.enabled=false;count=#logs;callback(ctx,arg);trace:update(3)
assert(#logs==count and next(trace.scenes)==nil,'disabled coop does not record scene events')
state.enabled=true;FindAllOf=function()error('streaming boundary')end
trace:update(4);trace:update(5)
assert(state.enabled and #logs==count+1,'diagnostic errors are isolated and deduplicated')

local position={X=-492,Y=994,Z=28220}
pawn.GetFullName=function()return 'BP_PlayerPawn_C /Game/Levels/Transmission/PLVL_Transmission.Test' end
pawn.K2_GetActorLocation=function()return position end
trace.c.driver.pawn=partner
pole.K2_GetActorLocation=function()return position end
local receiver=object('receiver');receiver.GetOwner=function()return pole end
local axe=object('axe')
local hitPath='/Script/Helios.DamageReciever:OnWeaponHit'
local function ref(value)return {get=function()return value end}end
count=#logs;hooks[hitPath](arg,arg,arg,arg)
assert(#logs==count,'the weapon pre-hook does not read possibly uninitialized arguments')
posts[hitPath](ref(receiver),ref(partner),nil,ref(axe))
assert(logs[count+1]:find('atacante=P2 objeto=wall switch arma=axe',1,true),'native attacker is independent of the animation owner')
local observed=#logs
posts[hitPath](ref(receiver),ref(pawn),nil,ref(axe))
assert(#logs==observed+1 and logs[#logs]:find('atacante=P1',1,true),'each native hit is logged and its Blueprint is inspected once')

local nearby=object('nearby box')
nearby.GetClass=pole.GetClass;nearby.GetOuter=pole.GetOuter;nearby.K2_GetActorLocation=pole.K2_GetActorLocation
local candidate=object('nearby component');candidate.GetOwner=function()return nearby end
FindAllOf=function(kind)if kind=='DamageReciever' then return {candidate} end end
count=#logs;trace:musicBoxNearby(pawn,false)
assert(logs[count+1]:find('receptor cercano nearby box',1,true),'nearby Blueprint metadata is recorded before a native hit')
count=#logs;trace:musicBoxNearby(pawn,false)
assert(#logs==count,'the nearby scan only runs once per pawn')

local six=object('BP_SixPawn_C')
local sixControl=object('Six animation control')
local sixPlaying=true
local sixInWorld=true
sixControl.IsPlayingOverrideAnimation=function()return sixPlaying end
sixControl.mCurrentAnimStateAsset=object('Six cutscene animation')
six.mAnimationControlComponent=sixControl
six.K2_GetActorLocation=function()return {X=40,Y=50,Z=60} end
local observedSix=six
local library=object('overseer')
library.GetHeliosPlaypalPawn=function()return observedSix end
StaticFindObject=function()return library end
pawn.GetFullName=function()return 'BP_PlayerPawn_C /Game/Levels/School/PLVL_School.Test' end
trace.c.world=function(a,b) return a and b and (sixInWorld or b~=six) end
trace.c.driver.pawn=nil
trace:snapshot(false,false)
assert(logs[#logs]:find('Six en Escuela BP_SixPawn_C asset=Six cutscene animation override=true',1,true),
 'capture a story animation even when no Mono starts an override')
count=#logs;trace:snapshot(false,false)
assert(#logs==count,'repeat snapshots do not spam the active story pose')

FindAllOf=function(kind)if kind=='LevelSequenceActor' then return {actor} end end
player.GetObjectBindings=function(_,p)
 if p==six then return {1,2} end
 assert(p==pawn);return {1}
end
playing=true;trace:scan()
assert(logs[#logs]:find('Six bindings=2',1,true),'report the story actor’s existing sequence bindings')
playing=false;trace:scan()

sixPlaying=false;sixControl.mCurrentAnimStateAsset=nil
trace:snapshot(false,false)
assert(logs[#logs]:find('Six en Escuela BP_SixPawn_C asset=- override=false',1,true),'record the end of the override')
count=#logs;sixControl.mCurrentAnimStateAsset=object('ordinary movement')
trace:snapshot(false,false)
assert(#logs==count,'ordinary locomotion does not spam the log')
sixInWorld=false;trace:snapshot(false,false)
assert(logs[#logs]:find('Six en Escuela - asset=-',1,true),'an actor in another world is treated as absent')
sixInWorld=true
pawn.GetFullName=function()return 'BP_PlayerPawn_C /Game/Levels/Hospital/PLVL_Hospital.Test' end
trace:mark()
assert(logs[#logs]:find('Six en Hospital BP_SixPawn_C',1,true),'F8 traces Six in the next watched chapter')
observedSix=nil
trace:snapshot(false,false)
assert(logs[#logs]:find('Six en Hospital - asset=-',1,true),'story disappearance is recorded without modifying the actor')
FindAllOf,StaticFindObject,RegisterHook=oldFind,oldStatic,oldHook
print('PASS: cinematic trace ownership, event attribution, throttling, scene exit and error isolation.')
