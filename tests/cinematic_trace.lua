local Trace=require('cinematic_trace')
local oldFind,oldStatic,oldHook=FindAllOf,StaticFindObject,RegisterHook
local hooks,logs={},{ }
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
RegisterHook=function(path,fn)hooks[path]=fn end
local state={enabled=true}
local trace=Trace.new({live=function(o)return o and o.valid end,same=function(a,b)return a==b end,
 world=function()return true end,p1=function()return pc end,driver={},state=state,
 log=function(s)logs[#logs+1]=s end,phase=function()return 'active'end})
trace:install();trace:update(1)
assert(table.concat(logs,'\n'):find('P1 bindings=1',1,true),'report the original player binding')
local count=#logs;trace:update(1.1);trace:update(1.3)
assert(#logs==count,'unchanged scene snapshots must not flood the log')
local ctx={get=function()return ao end};local arg={get=function()return asset end}
local callback=hooks['/Script/Helios.AnimationOverrideComponent:PlayAnimationSequenceOverride2']
callback(ctx,arg)
assert(logs[#logs]:find('P1',1,true)and logs[#logs]:find('intro animation',1,true),'attribute animation to its owner')
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
state.enabled=false;count=#logs;callback(ctx,arg);trace:update(3)
assert(#logs==count and next(trace.scenes)==nil,'disabled coop does not record scene events')
state.enabled=true;FindAllOf=function()error('streaming boundary')end
trace:update(4);trace:update(5)
assert(state.enabled and #logs==count+1,'diagnostic errors are isolated and deduplicated')
FindAllOf,StaticFindObject,RegisterHook=oldFind,oldStatic,oldHook
print('PASS: cinematic trace ownership, event attribution, throttling, scene exit and error isolation.')
