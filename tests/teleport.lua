local T=require('coop_teleport')
local Bindings=require('coop_bindings')
local TPBindings=require('tp_bindings')
local Input=require('coop_input')
local function check(v,message)assert(v,message)end
local now,allowed,blocked,space,moves,fx=0,true,nil,true,{},0
local first,second={at={X=10,Y=20,Z=30}},{at={X=-10,Y=-20,Z=0}}
local api={clock=function()return now end,log=function()end,
 players=function()if allowed then return first,second else return nil,nil,'not ready'end end,
 blocked=function(p)if p==blocked then return 'busy'end end,location=function(p)return p.at end,
 clear=function(p,target,dest)check(p~=target,'distinct mover and target');return space end,
 move=function(p,at)moves[#moves+1]={pawn=p,at=at};p.at=at;return true end,
 effects=function()fx=fx+1 end}
local tp=T.new(api)
check(tp:request('toP1')and moves[1].pawn==second,'P2 goes to P1')
check(second.at.X==10 and second.at.Y==20 and second.at.Z==55 and first.at.Z==30,'destination is target position plus 25 Z; target stays untouched')
check(not tp:request('toP2')and #moves==1,'cooldown prevents rapid bounce in the other direction')
now=2
check(tp:request('toP2')and moves[2].pawn==first and first.at.Z==80,'P1 can go to P2 independently')
now=4;blocked=first
check(not tp:request('toP1')and #moves==2,'busy target cannot be teleported to')
blocked=second;check(not tp:request('toP2')and #moves==2,'busy source or target always blocks')
blocked=nil;space=false
check(not tp:request('toP1')and #moves==2 and fx==2,'wall or ceiling rejection has no side effects')
space=true;allowed=false
check(not tp:request('toP1')and #moves==2,'pause, disabled P2 and reload gates never move a pawn')
allowed=true
api.clear=function()error('native trace unavailable')end
check(not tp:request('toP1')and #moves==2,'native errors are contained without disabling co-op')
api.clear=function()return true end;api.effects=function()error('missing cosmetic asset')end
check(tp:request('toP1')and #moves==3,'cosmetic failure cannot undo a valid teleport')
api.effects=function()end;now=6
local pressed={F9=true,F10=false};local keys={toP1='F9',toP2='F10'}
tp:poll(function(key)return pressed[key]end,keys,false)
tp:poll(function(key)return pressed[key]end,keys,true)
check(#moves==3,'key held while closing the menu does not fire a delayed teleport')
pressed.F9=false;tp:poll(function(key)return pressed[key]end,keys,true)
pressed.F9=true;tp:poll(function(key)return pressed[key]end,keys,true)
check(#moves==4,'fresh key edge teleports once')
now=10;tp:poll(function(key)return pressed[key]end,keys,true)
check(#moves==4,'holding the teleport key does not repeatedly teleport')
pressed.F10=true;tp:poll(function(key)return pressed[key]end,keys,true)
check(#moves==4,'opposite simultaneous requests are rejected')
local controls=Bindings.new(Input.presets[1])
local config=TPBindings.new(controls,'tp.toP1=F11\ntp.toP2=F12\n',function(key)return key=='W'end)
check(config.bindings.toP1=='F11'and config.bindings.toP2=='F12','TP bindings have independent persistent namespace')
check(not config:assign('toP1','W')and not config:assign('toP1','I'),'TP capture rejects primary and secondary gameplay keys')
check(not config:assign('toP1','F12')and not config:assign('toP1','F6'),'TP directions and menu keys cannot overlap')
check(not controls:assign('jump','F11'),'P2 controls cannot overwrite teleport keys')
check(config:assign('toP1','NumPadOne'),'free key can be assigned to TP')
controls:reset(Input.presets[2]);check(config:reconcile(),'changing P2 preset reconciles teleport conflicts')
check(config.bindings.toP1~='NumPadOne'and config.bindings.toP2=='F12','reconciliation preserves the other valid TP key')
local restored=TPBindings.new(controls,config:serialize())
check(restored.bindings.toP2=='F12','new TP mapping survives serialization')
config:open(function()return false end)
config:tick(function(k)return k=='Down'end);config:tick(function()return false end)
config:tick(function(k)return k=='Enter'end);config:tick(function()return false end)
check(config.capture=='toP2','two-row capture selects the correct TP direction')
config:tick(function(k)return k=='G'end)
check(config.bindings.toP2=='G','shared capture state handles TP keyboard assignment')
now=0
check(tp:request('toP1'),'new-world clock cannot inherit an old cooldown')
print('PASS: teleport identity, elevation, action and geometry gates, cooldown, edges, errors and binding conflicts.')
local Native=require('tp_native')
local previousFName=FName;FName=function(name)return name end
local function live(o)return o and o.valid end
local function mono()
 local p={valid=true,alive=true,CharacterMovement={valid=true,MovementMode=1}}
 p.GetFullName=function()return 'BP_PlayerPawn_C test'end
 p.IsAlive=function(self)return self.alive end
 p.mAnimationControlComponent={valid=true,IsPlayingOverrideAnimation=function(self)return self.playing end}
 p.anim={valid=true};p.Mesh={GetAnimInstance=function()return p.anim end}
 p.GetPlayerPickupInterface=function(self)return self.pickup end
 return p
end
local a,b=mono(),mono()
local pc,pc2={valid=true,Pawn=a},{valid=true,Pawn=b,Player={valid=true,ControllerId=1}}
a.Controller=pc;b.Controller=pc2
pc.IsMoveInputIgnored=function(self)return self.ignored end
pc.IsInputKeyDown=function()return false end
local pause,sameWorld,raw=false,true,{}
local context={live=live,same=function(x,y)return x==y end,world=function()return sameWorld end,
 state={enabled=true,menu=false,tp={effects=true}},spawn={phase='active'},death={},
 p1=function()return pc end,driver={pc=pc2,pawn=b},input=function()return raw end,
 UE={GetGameplayStatics=function()return {IsGamePaused=function()return pause end}end},log=function()end}
local n=Native.new(context)
check(n:players()==a and not n:blocked(a)and not n:blocked(b),'native adapter accepts two owned, idle Monos')
pause=true;check(not n:players(),'native pause blocks teleport');pause=false
context.spawn.phase='intro_wait';check(not n:players(),'introduction blocks teleport');context.spawn.phase='active'
pc2.Pawn=a;check(not n:players(),'controller ownership guard rejects a primary pawn reused by P2');pc2.Pawn=b
sameWorld=false;check(not n:players(),'different worlds cannot be joined');sameWorld=true
b.CharacterMovement.MovementMode=6;check(n:blocked(b),'ladder/custom locomotion blocks teleport');b.CharacterMovement.MovementMode=1
b.alive=false;check(n:blocked(b),'dead pawn blocks teleport');b.alive=true
b.mAnimationControlComponent.playing=true;check(n:blocked(b),'native cutscene or action override blocks teleport');b.mAnimationControlComponent.playing=false
b.anim.mCurrentlyActiveGrabInterface={valid=true};check(n:blocked(b),'active grab, drag or handhold interface blocks teleport');b.anim.mCurrentlyActiveGrabInterface=nil
raw.grab=true;check(n:blocked(b),'same-frame raw action blocks teleport before animation catches up');raw.grab=false
local holder=b
b.pickup={valid=true,GetCurrentlyHeldPickup=function()return {valid=true,GetHolderIfHeld=function()return holder end}end}
check(n:blocked(b),'held item blocks teleport')
holder=a;check(not n:blocked(b),'stale item reference does not count as an object held by P2')
local originalStatic=StaticFindObject;local obstructed=false;local arguments
StaticFindObject=function()return {CapsuleTraceSingleByProfile=function(_,...)arguments={...};return obstructed end}end
b.CapsuleComponent={valid=true,GetScaledCapsuleRadius=function()return 30 end,
 GetScaledCapsuleHalfHeight=function()return 62.5 end,GetCollisionProfileName=function()return 'PlayerProfile'end}
check(n:clear(b,a,{X=1,Y=2,Z=3}),'unobstructed native capsule test accepts destination')
check(arguments[8][1]==b and arguments[8][2]==a and #arguments[8]==2,'destination trace ignores exactly the two players, not puzzle actors or Six')
check(arguments[4]==30 and arguments[5]==62.5 and arguments[6]=='PlayerProfile','trace uses actual scaled capsule and its collision profile')
obstructed=true;check(not n:clear(b,a,{X=1,Y=2,Z=3}),'native wall/ceiling hit refuses destination')
StaticFindObject=originalStatic
local stopped=0
n.emitters={{object={valid=true,DeactivateSystem=function()stopped=stopped+1 end},untilTime=1}}
context.state.tp.flashUntil=100
n:update(.5);check(stopped==0,'effect is not deactivated early')
n:update(2);check(stopped==1 and #n.emitters==0,'native particles are explicitly deactivated after the burst')
n:update(0);check(not context.state.tp.flashFrame,'new world cannot retain a permanent static overlay')
FName=previousFName
print('PASS: native ownership, scene/ladder/grab/item guards, capsule trace contract and effect cleanup.')
