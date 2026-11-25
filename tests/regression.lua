package.path='mods/LN2LocalCoop/scripts/?.lua;'..package.path
local Input=require('coop_input')
local Driver=require('mono_driver')
local n=0
local function check(v,s) assert(v,s); n=n+1 end
local held={I=true,L=true}
local p=Input.sample(Input.presets[1],function(k) return held[k] or false end)
local d=Input.direction(p.x,p.y,0)
check(math.abs(d.X*d.X+d.Y*d.Y-1)<.0001,'diagonal normalized')
held={}; p=Input.sample(Input.presets[1],function(k) return held[k] or false end)
check(p.x==0 and p.y==0 and not p.jump,'keys release')
local p1={valid=true,Pawn={valid=true,name='P1'}}
local created,removed,stopped=0,0,0
local api={live=function(o) return o and o.valid end,same=function(a,b) return a==b end,
 sameWorld=function(a,b) return a.world==b.world end,
 existing=function() return false end,
 create=function() created=created+1; return {valid=true,Pawn={valid=true,name='P2'}} end,
 park=function(pc) check(pc~=p1 and pc.Pawn~=p1.Pawn,'never remove P1'); removed=removed+1; pc.Pawn=nil end,
 isMono=function(o) return o.name=='P2' end,rescue=function(o) check(o~=p1.Pawn,'rescue only P2') end,
 stop=function() stopped=stopped+1 end,move=function(o,v) o.direction=v end,
 actions=function(o,v) o.input=v end}
local driver=Driver.new(api)
check(driver:ensure(p1),'create P2')
check(driver:ensure(p1) and created==1,'activation idempotent')
driver:update(Input.direction(1,0,0),{jump=true,sneak=false})
check(driver.pawn.direction.Y==1 and driver.pawn.input.jump,'P2 input independent')
driver:stop(); check(stopped==1,'pause releases P2 input')
driver:remove(); driver:remove(); check(removed==1,'removal idempotent')
check(driver.pc.valid and driver.parked,'disable retains the controller to preserve primary input')
driver=Driver.new(api)
api.existing=function() return {valid=true} end
check(not pcall(function() driver:ensure(p1) end) and created==1,'refuse foreign local player')
api.existing=function() return false end
api.create=function() return p1 end
check(not pcall(function() driver:ensure(p1) end) and driver.pc==nil,'reject P1 before claiming ownership')
api.create=function() return {valid=true,Pawn={valid=false}} end
check(driver:ensure(p1)==false,'wait for a missing pawn without duplicating the controller')
driver:remove(); check(removed==2,'failed activation cleans owned controller')
print('PASS: '..n..' checks (keyboard, independent input, creation ownership, cleanup).')
local Actions=require('mono_actions')
local events={}
local act=Actions.new({key=function(k) return k end,
 start=function(_,k) events[#events+1]='start '..k end,
 hold=function(_,k) events[#events+1]='hold '..k end,
 stop=function(_,k) events[#events+1]='stop '..k end})
act:update({}, {jump=true,grab=true})
check(#events==4 and events[1]=='start Jump' and events[3]=='start Grab','simultaneous jump and grab stay independent')
events={}; act:update({}, {jump=true,grab=true})
check(#events==2 and events[1]=='hold Jump','holding does not repeat press edge')
events={}; act:update({}, {grab=true})
check(events[1]=='stop Jump' and events[2]=='hold Grab','releasing one action preserves another')
events={}; act:release({}); act:release({})
check(#events==1 and events[1]=='stop Grab','pause/disable releases each action exactly once')
act:update({}, {jump=true}); events={}; act:release(nil)
check(#events==0,'destroyed animator clears ownership without native calls')
events={}; act:update({}, {jump=true})
check(events[1]=='start Jump','respawn can start a fresh action')
print('PASS: action lifecycle and simultaneous-button regressions.')
act:release(nil); events={}; act:update({}, {sprint=true,grab=true})
check(#events==4 and events[3]=='start Sprint','sprint and grab can start together')
events={}; act:update({}, {grab=true})
check(events[1]=='hold Grab' and events[2]=='stop Sprint','sprint release preserves grab')
act:release(nil)
local sprintInput=Input.sample(Input.presets[1],function(key)return key=='RightShift' end)
check(sprintInput.sprint and not sprintInput.jump,'right shift maps independently to P2 sprint')
local Link=require('primary_link')
local live=function(o) return o and o.valid end
local primary={valid=true};local pawn={valid=true,Controller=primary};primary.Pawn=pawn
local linkApi={live=live,same=function(a,b)return a==b end,isMono=function()return true end}
check(Link.ensure(primary,linkApi) and primary.mPlayerPawn==pawn,'repair absent native reference to own pawn')
check(not Link.ensure(primary,linkApi),'primary repair idempotent')
local scripted={valid=true};primary.mPlayerPawn=scripted
check(not Link.ensure(primary,linkApi) and primary.mPlayerPawn==scripted,'preserve an existing scripted reference')
linkApi.stale=function(old)return old==scripted end
check(Link.ensure(primary,linkApi) and primary.mPlayerPawn==pawn,'replace a reference confirmed to be from an older world')
linkApi.stale=nil
primary.mPlayerPawn=nil;pawn.Controller={valid=true}
check(not Link.ensure(primary,linkApi) and not primary.mPlayerPawn,'never link a pawn controlled by someone else')
print('PASS: primary controller reference regressions.')
local owner={valid=true}; local current; local now=0
local spawns,restarts,configures,deletes=0,0,0,0
local inputsReady=true
local first={valid=true,world=1,Pawn={valid=true,name='P1'}}
local function controller(world,pawn)
 return {valid=true,world=world,Player=owner,Pawn=pawn}
end
local lifecycle=Driver.new({live=live,same=function(a,b)return a==b end,
 sameWorld=function(a,b)return a.world==b.world end,
 existing=function()return current end,identity=function(pc)return pc.Player end,
 resolve=function()return current end,clock=function()return now end,
 create=function()spawns=spawns+1;current=controller(first.world,{valid=true,name='P2'});return current end,
 restart=function()restarts=restarts+1 end,
 configure=function()if not inputsReady then return false end; configures=configures+1 end,
 isMono=function(p)return p.name=='P2' end,rescue=function()end,stop=function()end,
 park=function(pc)assert(pc.Player==owner);deletes=deletes+1;pc.Pawn=nil end})
check(lifecycle:ensure(first),'lifecycle initial creation')
current.valid=false; current=nil; first.world=2
check(not lifecycle:ensure(first) and spawns==1,'transition waits without creating another player')
current=controller(2,{valid=true,name='P2'})
inputsReady=false
check(not lifecycle:ensure(first) and not lifecycle.pawn,'do not publish a pawn until its input is initialized')
check(not lifecycle:ensure(first) and restarts==0,'do not restart a possessed pawn still initializing')
inputsReady=true
check(lifecycle:ensure(first) and configures==2 and spawns==1,'adopt replacement controller belonging to same local player')
current.Pawn=nil
check(not lifecycle:ensure(first) and restarts==1,'missing pawn requests restart')
now=1; lifecycle:ensure(first)
check(restarts==1,'restart retries are throttled')
now=2; lifecycle:ensure(first)
check(restarts==2,'restart retries after cooldown')
current.Pawn={valid=true,name='P2'}
check(lifecycle:ensure(first) and configures==3,'configure replacement pawn')
current.valid=false;current=nil
check(not lifecycle:remove() and lifecycle.player==owner,'disable preserves identity until controller returns')
current=controller(2,{valid=true,name='P2'})
check(lifecycle:remove() and deletes==1 and lifecycle.player==owner and current.valid,'deferred disable parks pawn and preserves controller identity')
now=5
check(not lifecycle:ensure(first) and spawns==1,'reactivation reuses parked controller')
current.Pawn={valid=true,name='P2'}
check(lifecycle:ensure(first) and spawns==1,'reappearing P2 does not recreate its controller')
print('PASS: controller replacement, delayed spawn, retry throttling and deferred cleanup.')
local Recovery=require('primary_recovery')
local recoveryTime,recoveries,intent=0,0,false
local recovery=Recovery.new({live=live,same=function(a,b)return a==b end,
 clock=function()return recoveryTime end,intent=function()return intent end,
 restore=function(pc)assert(pc==first);recoveries=recoveries+1 end})
check(not recovery:update(first,true) and recoveries==0,'initial spawn does not steal viewport focus')
first.Pawn={valid=true,name='P1 replacement'}
recovery:update(first,true);recoveryTime=2
check(not recovery:update(first,true),'replacement waits for gameplay keyboard intent')
intent=true
check(not recovery:update(first,false) and recoveries==0,'paused menus and cutscenes prevent recovery')
check(recovery:update(first,true) and recoveries==1,'recover viewport when movement arrives after respawn')
check(not recovery:update(first,true) and recoveries==1,'recovery is once per replacement pawn')
first.Pawn={valid=true,name='another P1'}
check(not recovery:update(first,true),'new pawn waits for spawn to settle')
recoveryTime=4
check(recovery:update(first,true) and recoveries==2,'subsequent checkpoints can recover independently')
print('PASS: checkpoint viewport recovery, keyboard intent and menu protection.')
local chapterWorld,chapterTime,attempts,focusChanges=1,10,0,0
local chapter=Recovery.new({live=live,same=function(a,b)return a==b end,
 world=function()return chapterWorld end,clock=function()return chapterTime end,intent=function()return true end,
 restore=function(_,focus)
  attempts=attempts+1
  if focus then focusChanges=focusChanges+1 end
  return attempts~=1
 end})
chapter:update(first,true)
chapterWorld,chapterTime=2,0
check(not chapter:update(first,true),'same controller and pawn with another world waits for readiness')
chapterTime=1.1
check(not chapter:update(first,false) and attempts==0,'do not repair while a menu or cinematic owns input')
check(not chapter:update(first,true) and attempts==1,'defer when the native input context is still occupied')
chapterTime=1.3
check(not chapter:update(first,true) and attempts==1,'deferred repair is throttled')
chapterTime=1.6
check(chapter:update(first,true) and attempts==2 and focusChanges==1,'retry without overriding viewport focus again')
chapter:update(nil,false)
chapterTime=2
chapter:update(first,true)
chapterTime=3.1
check(chapter:update(first,true) and attempts==3,'returning from save selection rearms recovery with a reused pawn')
chapter:invalidate()
chapter:update(first,true)
chapterTime=4.2
check(chapter:update(first,true) and attempts==4,'late P2 controller initialization rechecks P1')
print('PASS: chapter travel, save reload and deferred native primary recovery.')
local Bindings=require('coop_bindings')
local bindings=Bindings.new(Input.presets[1])
local function keys(values)return function(key)return values[key] or false end end
bindings:open(keys({}))
bindings:tick(keys({Enter=true}))
check(bindings.capture=='up','Enter selects the highlighted action')
bindings:tick(keys({Enter=true}))
check(bindings.bindings.up=='I','selection key is not captured while still held')
bindings:tick(keys({}))
check(bindings:tick(keys({G=true}))=='saved' and bindings.bindings.up=='G','capture assigns a fresh keyboard edge')
local persisted=Bindings.new(Input.presets[1],bindings:serialize())
check(persisted.bindings.up=='G' and persisted.bindings.name=='Personalizado','custom keyboard bindings persist')
local assigned,hint=bindings:assign('down','G')
check(not assigned and bindings.bindings.down=='K' and hint:find('Avanzar',1,true),'duplicate assignment preserves other actions')
check(not bindings:assign('up','F6') and not bindings:assign('up','Escape'),'menu and cancel keys cannot be rebound')
check(not bindings:assign('up','UnknownKey'),'unknown input key rejected')
bindings:open(keys({}));bindings:tick(keys({Down=true}));bindings:tick(keys({}))
bindings:tick(keys({Enter=true}));bindings:tick(keys({}));bindings:tick(keys({Escape=true}))
check(bindings.capture==nil and bindings.bindings.down=='K','cancel leaves the old binding intact')
bindings:reset(Input.presets[2])
check(bindings.bindings.up=='NumPadEight' and bindings.bindings.use=='NumPadOne','preset restores every action including use')
local invalid=Bindings.new(Input.presets[1],'bind.up=F6\nbind.down=I\n')
check(invalid.bindings.up=='I' and invalid.bindings.down=='K','invalid duplicate persisted mapping falls back to complete defaults')
local legacy=Bindings.new(Input.presets[1],'bind.use=Y\nbind.up=G\n')
check(legacy.bindings.use=='Y' and legacy.bindings.up=='G' and legacy.bindings.gadget~='Y',
 'adding the gadget binding preserves existing custom controls')
local legacyTP=Bindings.new(Input.presets[1],'tp.toP1=Y\ntp.toP2=M\n')
check(legacyTP.bindings.gadget~='Y' and legacyTP.bindings.gadget~='M','adding the gadget binding preserves teleport keys')
local legacyCall=Bindings.new(Input.presets[1],'bind.gadget=M\ntp.toP1=N\n')
check(legacyCall.bindings.gadget=='M' and legacyCall.bindings.call~='M' and legacyCall.bindings.call~='N',
 'adding the call binding preserves existing gadget and teleport keys')
local nativeEvents={}
local nativeAct=Actions.new({key=function(k)return k end,start=function()end,hold=function()end,stop=function()end,
 crouch=function(_,v)nativeEvents[#nativeEvents+1]='crouch '..tostring(v)end,
 use=function(_,v)nativeEvents[#nativeEvents+1]='use '..tostring(v)end,
 gadget=function(v)nativeEvents[#nativeEvents+1]='gadget '..tostring(v)end})
nativeAct:update({}, {sneak=true,use=true,grab=true,gadget=true});nativeAct:update({}, {sneak=true,use=true,grab=true,gadget=true})
local uses=0;for _,event in ipairs(nativeEvents)do if event=='use true'then uses=uses+1 end end
check(uses==1,'holding use does not repeatedly throw objects')
nativeEvents={};nativeAct:release({})
local released={};for _,event in ipairs(nativeEvents)do released[event]=true end
check(released['use false'] and released['crouch false'] and released['gadget false'],'menu/disable releases equipment input and other native actions')
print('PASS: control capture, persistence, conflicts, cancellation and native action release.')
local Native=require('native_input')
local function object(address)return {valid=true,GetAddress=function()return address end}end
local primaryPc,primaryPawn=object(11),object(12);primaryPc.Pawn=primaryPawn
local secondPc,secondPawn,secondPlayer=object(21),object(22),object(23)
secondPc.Pawn=secondPawn;secondPc.Player=secondPlayer;secondPawn.Controller=secondPc
local bound,throws,uses=nil,0,0
local gadgets,inventorySlot={},nil
local jumps={}
local pickup=object(24);pickup.mCanThrow=true
pickup.GetHolderIfHeld=function()return secondPawn end
pickup.TryThrow=function()throws=throws+1;return true end
local pickupInterface=object(25);pickupInterface.GetCurrentlyHeldPickup=function()return pickup end
secondPawn.GetPlayerPickupInterface=function()return pickupInterface end
local inventory=object(27);inventory.HasInventoryItem=function(_,slot)return slot==inventorySlot end
secondPawn.GetInventoryComponent=function()return inventory end
local native=setmetatable({live=live,api={bind=function(...)bound={...}end,
 use_item=function()uses=uses+1 end,gadget=function(command)gadgets[#gadgets+1]=command end,
 jump=function(command)jumps[#jumps+1]=command end}},Native)
local bindReady=native.api.bind
native.api.bind=function()error('P2 native input is not linked to its own chalkboard')end
check(not native:bind(secondPc,primaryPc) and not native:ready(),'native link delay defers activation')
native.api.bind=function()error('P2 native input ownership changed')end
check(not pcall(native.bind,native,secondPc,primaryPc),'unexpected ownership errors remain visible')
native.api.bind=bindReady
native:bind(secondPc,primaryPc)
check(bound[1]==21 and bound[3]==22 and bound[4]==11 and bound[5]==12,'native binding identifies primary and secondary objects separately')
local jumpActions=Actions.new({key=function(k)return k end,start=function()error('unexpected legacy jump')end,
 hold=function()end,stop=function()end,jump=function(held,wasHeld)return native:jump(held,wasHeld)end})
jumpActions:update({}, {jump=true});jumpActions:update({}, {jump=true});jumpActions:release({})
check(table.concat(jumps,',')=='1,0','native jump uses one press and releases when the mod stops input')
native:use(true)
check(throws==1 and uses==0,'throw targets the object held by P2')
pickup.GetHolderIfHeld=function()return primaryPawn end
native:use(true)
check(throws==1 and uses==1,'stale item reference never throws an object held by P1')
native:gadget(true)
inventorySlot=1;native:gadget(true);native:gadget(false)
inventorySlot=3;native:gadget(true);native:gadget(false)
check(table.concat(gadgets,',')=='1,0,2,0','only P2 inventory selects flashlight or remote, with a native release')
local vent,other,handle,drag=object(31),object(32),object(33),object(34)
local grabbed=other
local ventClass='BlueprintGeneratedClass /Game/GameplayLogic/Draggable/PP_PullOpenVent.PP_PullOpenVent_C'
vent.GetClass=function()return {GetFullName=function()return ventClass end}end
other.GetClass=function()return {GetFullName=function()return 'Other grabbable' end}end
handle.GetOwner=function()return grabbed end
drag.mGrabbedGrabHelper=handle
secondPawn.GetComponentByClass=function()return drag end
local originalFind=StaticFindObject
StaticFindObject=function()return object(35)end
local routes={}
native.log=function()end
native.api.vent=function(_,_,target)routes[#routes+1]=target;return 0 end
native:vent(true)
grabbed=vent;native:vent(true);native:vent(true);native:vent(false)
check(table.concat(routes,',')=='31,0','only the held tunnel grate is routed and releasing restores the lookup')
local cageRoutes={}
local cage=object(36)
local cageLoaded=false
StaticFindObject=function(path)
 if path:find('ExecuteUbergraph_LVL_1_061_TutorialPullPush',1,true) then return cage end
 if path:find('GetHeliosPlayerPawn',1,true) then return object(35) end
end
native.api.cage=function(lookup,graph)
 cageRoutes[#cageRoutes+1]=lookup..':'..graph
 if lookup~=0 and not cageLoaded then error('The cage animation bytecode does not match',0) end
 return 0
end
native:cage(1)
check(not native.cageGraph,'a streamed graph is not armed before its bytecode is ready')
cageLoaded=true
native:cage(1.1);native:cage(1.25);native:cage(2);native:cage()
native:cage(0)
native:bind(secondPc,primaryPc)
StaticFindObject=originalFind
check(table.concat(cageRoutes,',')=='35:36,35:36,0:0,35:36,0:0',
 'cage setup retries after streaming and clears before replacing P2')
secondPc.Pawn=object(26)
native:use(true);native:gadget(true);native:jump(true)
check(throws==1 and uses==1 and #gadgets==4 and #jumps==2,'replacement pawn blocks stale native adapter calls until rebound')
print('PASS: native adapter ownership, held-item ownership and stale-pawn guards.')
local Camera=require('coop_camera')
local cameraModes,lastZoom={},0
local track,blend=41,nil
local camera=Camera.new({
 shared_camera=function(enabled)cameraModes[#cameraModes+1]=enabled end,
 camera_tracks=function()return track,math.floor(lastZoom*10000+.5),blend end,
 camera_zoom=function(amount,address,otherAddress)
  check(address==track or (address==0 and amount==0),'zoom never spills onto an unrelated camera track')
  check(otherAddress==0 or otherAddress==blend,'zoom receives the current blend scope')
  lastZoom=amount
 end,
},live,function(err)error(err)end)
local volume=object(44)
function volume:GetUnscaledBoxExtent() return {X=100,Y=100,Z=100} end
function volume:K2_GetComponentToWorld() return self.offset or 0 end
local follow=object(41)
follow.mEditablePlayerVolume=volume
local nextFollow=object(42)
nextFollow.mEditablePlayerVolume=setmetatable({offset=150},{__index=volume})
local oldFindAll=FindAllOf
FindAllOf=function()return {follow,nextFollow}end
StaticFindObject=function(path)
 if path:find('DollhouseCameraActor',1,true) then return object(45) end
 if path:find('CameraBlendVolume',1,true) then return object(48) end
 return {valid=true,InverseTransformLocation=function(_,offset,p)return {X=p.X-offset,Y=p.Y,Z=p.Z}end}
end
local view={edge=1.04,firstLocation={X=0,Y=0,Z=0},secondLocation={X=80,Y=0,Z=10}}
camera:start()
for i=0,20 do camera:update(i*.05,view) end
check(math.abs(math.deg(2*math.atan(math.tan(math.rad(30))*(1+lastZoom)))-80)<.001,
 'near the edge, zoom opens gradually to 80 degrees from the normal 60')
view.edge=.8
camera:update(1.05,view)
check(lastZoom>0,'the measured lens expansion cannot immediately close the frame')
view.edge=.65
for i=22,49 do camera:update(i*.05,view) end
check(lastZoom==0,'zoom returns smoothly after both players move inward')
view.edge=1.05
camera:update(2.5,view);camera:update(2.55,view)
check(lastZoom>0,'zoom reopens after the players approach the edge')
blend=42
view.secondLocation.X=110
camera:update(2.6,view)
check(lastZoom>0,'adding a follow camera retains zoom for players in adjacent volumes')
track,blend=42,nil
view.firstLocation.X=80
camera:update(2.65,view)
check(lastZoom>0,'zoom continues when the adjacent follow camera takes over')
view.secondLocation.X=280
camera:update(2.7,view)
check(lastZoom==0,'zoom clears when P2 enters another zone')
track=nil
camera:update(2.75,view);camera:update(2.80,view)
check(lastZoom==0,'a fixed shot uses the original lens')
camera:stop()
check(table.concat(cameraModes,',')=='1,0','shared camera is enabled and restored with the mod lifecycle')
local splitWorld=object(46)
follow.GetWorld=function()return splitWorld end
local scans=0
camera.api.split_camera_scan=function(world,blendClass)
 check(world==46 and blendClass==48,'split scans the loaded levels of its own world')
 scans=scans+1
end
local fillCalls={}
camera.api.camera_fill=function(value)fillCalls[#fillCalls+1]=value end
camera:syncSplit(3,follow,true)
camera:syncSplit(3.1,follow,false)
check(scans==1,'split refreshes the camera scan at most twice per second')
camera:stop()
check(table.concat(fillCalls,',')=='1,0,0','fill screen updates immediately despite scan throttling and restores on stop')
check(table.concat(cameraModes,',')=='1,0,2,0','split camera state is scoped to split mode')
FindAllOf=oldFindAll
StaticFindObject=originalFind
print('PASS: shared camera gates, opening cap, edge hysteresis and cleanup.')
local Death=require('coop_death')
local reloads,events=0,{}
local function pawn(alive,world)return {valid=true,alive=alive,world=world or 1}end
local death=Death.new({live=live,same=function(a,b)return a==b end,
 sameWorld=function(a,b)return a.world==b.world end,alive=function(p)return p.alive end,
 begin=function(who)events[#events+1]=who end,
 restart=function()check(#events>0,'cleanup precedes checkpoint request');reloads=reloads+1 end})
local d1,d2=pawn(true),pawn(false)
check(not death:update({},d1,d2) and reloads==1 and events[1]=='P2','P2 death restarts the shared checkpoint')
for i=1,100 do check(not death:update({},d1,nil),'wait for native reload, even while P1 still alive') end
check(reloads==1,'pending death never repeatedly requests checkpoint')
check(not death:update({},nil,nil),'missing pawn while loading keeps the latch')
d1.alive=false;check(not death:update({},d1,nil),'wait while native primary death runs')
d1.alive=true;check(death:update({},d1,nil),'same primary pawn may revive after death')
d2=pawn(false);check(not death:update({},d1,d2) and reloads==2,'a later death can reload again')
d1=pawn(true);check(death:update({},d1,nil),'replacement primary pawn completes reload')
d1.alive=false;d2.alive=false
check(not death:update({},d1,d2) and events[#events]=='P1' and reloads==2,'simultaneous deaths use only native P1 restart')
death:reset();d1=pawn(true)
check(death:update({},d1,nil),'missing P2 is not a death')
check(death:update({},d1,pawn(false,2)) and reloads==2,'old-world P2 never restarts a new world')
d1.alive=false;check(not death:update({},d1,nil) and reloads==2,'P1 death does not duplicate native restart')
death:reset();d1.alive=true
check(death:update({},d1,pawn(true)),'disable clears pending death state')
check(death:lose({},d1,'P1') and events[#events]=='P1' and reloads==3,'offscreen P1 uses the shared checkpoint')
check(not death:lose({},d1,'P2') and not death:update({},d1,nil) and reloads==3,'offscreen loss latches a single reload')
print('PASS: shared death, single restart, simultaneous death, loading and subsequent respawn.')

local separation=require('coop_separation').new(false)
local now=0
local function offscreen(seconds,player,observed,second)
 for _=1,seconds*4 do
  now=now+.25
  local lost=separation:update(now,player,'right',observed,1,second or 2)
  if lost then return lost end
 end
end
check(not offscreen(20,2,true) and separation.elapsed==0,'separation is opt-in')
separation.enabled=true
offscreen(8,2,true)
check(not separation.warning,'the first observation does not count as time away')
offscreen(.25,2,true)
check(separation.warning and separation.amount>0,'warning begins at eight seconds')
check(not offscreen(20,2,false) and not separation.warning and separation.elapsed==8,'pause freezes time and mutes warning')
offscreen(.25,nil,true)
offscreen(.5,nil,true)
check(separation.elapsed==0 and separation.amount==0,'return to frame clears danger and fades static')
check(not offscreen(13,1,true) and offscreen(.25,1,true)==1,'P1 can be lost after thirteen seconds')
check(not offscreen(3,1,true),'a loss only fires once')
check(not offscreen(1,2,true,3) and separation.elapsed<1,'replacement pawn starts a new timer')
print('PASS: opt-in offscreen loss, pause, rescue fade, either player and one restart per encounter.')
local Spawn=require('coop_spawn')
local spawned,slept,woke,cleaned,hidden,placed,completed,cancelled=0,0,0,0,false,0,0,0
local present,animating,primaryFinished=true,true,false
local plan={sleep='sit',wake='stand',immediate=false}
local sApi={live=live,same=function(a,b)return a==b end,alive=function(p)return p.alive end,
 cleanup=function()cleaned=cleaned+1 end,ensure=function()spawned=spawned+1;return true end,
 present=function()return present end,plan=function()return plan end,
 sleep=function()slept=slept+1 end,wake=function()woke=woke+1;return 2.8 end,
 playing=function()return animating end,primaryFinished=function()return primaryFinished end,
 hide=function(v)hidden=v end,placeIntro=function()placed=placed+1 end,
 cancel=function()hidden=false;cancelled=cancelled+1 end,complete=function()completed=completed+1 end}
local spawn=Spawn.new(sApi);local original=pawn(true)
spawn:enable(false)
check(not spawn:update(original,false,false,false,0) and spawned==0,'no P2 before native readiness')
check(not spawn:update(original,true,false,false,1),'wait for stable primary pawn')
check(not spawn:update(original,false,false,false,1.2),'loading resets stability interval')
spawn:update(original,true,false,false,2)
check(spawn:update(original,true,false,false,2.4) and spawned==1 and slept==0,'mid-game activation joins without replaying introduction')
for i=1,10 do spawn:update(original,true,false,false,3+i)end
check(spawned==1,'stable gameplay never spawns duplicate pawns')
spawn:invalidate();spawn:invalidate()
local cleanupAt=cleaned
check(not spawn:update(original,true,false,false,20) and spawned==1,'manual reload waits beyond the old still-alive pawn')
original.alive=false;spawn:update(original,false,false,false,21)
original.alive=true;spawn:update(original,true,false,false,22)
check(not spawn:update(original,true,false,false,22.4) and spawn.phase=='sleeping' and slept==1,'same-pawn checkpoint restoration sits P2 once')
check(cleaned==cleanupAt,'repeated invalidation never repeatedly cleans the world')
check(not spawn:update(original,true,false,true,22.5) and woke==0,'sit animation has a minimum settling interval')
check(not spawn:update(original,true,true,true,23) and woke==0,'paused inputs cannot wake P2')
check(not spawn:update(original,true,false,true,23.1) and woke==1,'own P2 input starts native awakening')
check(not spawn:update(original,true,false,true,24) and woke==1,'held inputs never restart awakening')
animating=false
check(spawn:update(original,true,false,false,26) and completed==1,'native animation completion releases P2 controls')
local replacement=pawn(true)
spawn:update(replacement,true,false,false,30)
spawn:update(replacement,true,false,false,30.4)
check(slept==2 and cleaned>cleanupAt,'new primary pawn restarts the checkpoint lifecycle')
spawn:disable();check(not spawn.enabled and not hidden,'disable cancels a pending sequence')
spawn:enable(true);plan={sleep='introIdle',wake='introWake',intro=true}
spawn:update(replacement,true,false,false,40);spawn:update(replacement,true,false,false,40.4)
check(hidden and spawn.phase=='intro_wait','pre-game F7 queues P2 after the primary introduction')
spawn:update(replacement,true,false,true,41)
check(placed==0,'P2 input never cuts ahead of P1 introduction')
primaryFinished=true;animating=true
spawn:update(replacement,true,false,false,42)
check(not hidden and placed==1 and woke==2,'intro plays once at its original location after P1 finishes')
animating=false;spawn:update(replacement,true,false,false,46)
spawn:invalidate();replacement=pawn(true)
plan={sleep='sit',wake='stand'}
spawn:update(replacement,true,false,false,50);spawn:update(replacement,true,false,false,50.4)
check(spawn.phase=='sleeping' and placed==1,'later checkpoints never repeat the special introduction')
spawn:disable();spawn:enable(false);plan=nil
spawn:update(replacement,true,false,false,60);check(spawn:update(replacement,true,false,false,60.4),'standing checkpoints do not invent sleep animations')
present=false;check(not spawn:update(replacement,true,false,false,61),'lost P2 is recovered through readiness gate')
spawn:update(replacement,true,false,false,62);present=true
check(spawn:update(replacement,true,false,false,62.4),'recovery can continue on the retained controller')
print('PASS: stable checkpoint readiness, sit/wake lifecycle, input gating and introduction ordering.')
spawn:disable();spawn:enable(true);present=true;plan={defer=true}
local beforeSpawn=spawned
spawn:update(replacement,true,false,false,70);spawn:update(replacement,true,false,false,71)
check(spawned==beforeSpawn and spawn.early,'nightmare/loading keeps pre-game introduction armed without spawning')
plan={sleep='introIdle',wake='introWake',intro=true};primaryFinished=false
spawn:update(replacement,true,false,false,72)
check(spawn.phase=='intro_wait' and hidden,'outdoor introduction can follow a deferred nightmare scene')
spawn:disable();spawn:enable(false);spawn:invalidate(replacement)
check(not spawn:update(replacement,true,false,false,80),'reload before the first poll still remembers the old pawn')
replacement.alive=false;spawn:observe(replacement);replacement.alive=true
spawn:update(replacement,true,false,false,81);plan=nil
check(spawn:update(replacement,true,false,false,81.4),'death observed by the outer loop releases a reused primary pawn')
local SpawnNative=require('spawn_native')
local nativeMode=5
StaticFindObject=function()return {valid=true,GetHeliosGameState=function()return nativeMode end}end
local p2={valid=true,CharacterMovement={MovementMode=1,CustomMovementMode=0}}
p2.CharacterMovement.SetMovementMode=function(self,mode,custom)self.MovementMode=mode;self.CustomMovementMode=custom end
p2.SetActorHiddenInGame=function(self,v)self.hidden=v end
p2.SetActorEnableCollision=function(self,v)self.collision=v end
local pc={valid=true,Pawn=p2};p2.Controller=pc
local settings={enabled=true,bindings={up='G'},appearance={hat='future-hat'}}
local adapter=SpawnNative.new({live=live,same=function(a,b)return a==b and live(a)end,
 driver={pawn=p2},session=settings})
adapter:hide(true)
check(p2.hidden and not p2.collision and p2.CharacterMovement.MovementMode==0,'hidden intro pawn cannot fall through the ground')
adapter:hide(false)
check(not p2.hidden and p2.collision and p2.CharacterMovement.MovementMode==1,'intro restores the previous movement mode')
check(settings.enabled and settings.bindings.up=='G' and settings.appearance.hat=='future-hat','spawn adapter preserves session controls and future appearance')
check(not adapter:ready(pc),'missing animation components prevent premature recovery')
pc.PlayerCameraManager={valid=true};p2.mAnimationControlComponent={valid=true};p2.mAnimationOverrideComponent={valid=true}
p2.Mesh={valid=true,GetAnimInstance=function()return {valid=true}end}
check(adapter:ready(pc),'initialized native pawn can pass readiness gate')
nativeMode=4;check(not adapter:ready(pc),'menu/loading state cannot spawn P2')
print('PASS: deferred introduction, reused-pawn reload, hidden-pawn physics and session preservation.')
local tower={valid=true}
local bridgePawn={valid=true,GetWorld=function()return tower end,
 GetFullName=function()return 'BP_PlayerPawn_C /Game/Levels/Transmission/PLVL_Transmission.PLVL_Transmission:PersistentLevel.Pawn'end}
local signal,overriding='ANIM_Player_StumbleFallLongTransmission',true
bridgePawn.mAnimationControlComponent={valid=true,IsPlayingOverrideAnimation=function()return overriding end,
 mCurrentAnimStateAsset={valid=true,GetFullName=function()return 'AnimSequence /Game/Characters/Player/Animations/'..signal..'.'..signal end}}
local bridgePC={valid=true,Pawn=bridgePawn}
nativeMode=5
check(not adapter:sixFinale(bridgePC,true),'loading the bridge in two-Mono mode does not end co-op')
settings.playAsSix=true
local solo,finalHit=adapter:sixFinale(bridgePC,true)
check(solo and not finalHit,'loading the final bridge ends the Dark Six session without playing a disappearance')
overriding=false
check(adapter:sixFinale(bridgePC,true),'the bridge remains solo after the override, including a manual activation')
nativeMode=4
check(not adapter:sixFinale(bridgePC,false),'the main menu clears the ending for another save')
nativeMode=5
check(not adapter:sixFinale(bridgePC,true),'an inactive override does not identify the ending')
signal,overriding='ANIM_Player_WakeUpAfterLastHitMusicBox',true
solo,finalHit=adapter:sixFinale(bridgePC,true)
check(solo and finalHit,'the last hit produces the disappearance cue')
solo,finalHit=adapter:sixFinale(bridgePC,true)
check(solo and not finalHit,'the last-hit effect plays once across repeated game polls')
signal='ANIM_Player_HittingMusicBoxRecoil'
check(not adapter:sixFinale(bridgePC,true),'an earlier music box checkpoint in the same world can restore co-op')
print('PASS: Dark Six finale, direct bridge loads, and re-entry before the last hit.')
local Bridge=require('final_bridge')
local bridgeTime,restarts,placements=0,0,0
local ground,room,playingSix=true,true,false
local bridgePosition={X=-799.15,Y=11409.17,Z=28792.25}
bridgePawn.GetActorLocation=function()return bridgePosition end
bridgePawn.K2_GetActorLocation=bridgePawn.GetActorLocation
bridgePawn.IsAlive=function()return true end
bridgePawn.CharacterMovement={valid=true,MovementMode=1,
 K2_FindFloor=function(_,_,floor)floor.bBlockingHit=ground;floor.bWalkableFloor=ground;floor.FloorDist=8 end}
local newMono={valid=true,alive=true,CapsuleComponent={valid=true},
 IsAlive=function(self)return self.alive end,
 K2_SetActorLocation=function(_,at)placements=placements+1;check(at.Y==bridgePosition.Y-70,'placement follows the verified bridge lane');return true end}
local localPlayer={valid=true}
local bridge=Bridge.new({live=live,same=function(a,b)return a==b and live(a)end,
 log=function()end,playAsSix=function()return playingSix end,clock=function()return bridgeTime end,
 clear=function()return room end,restartLocal=function()restarts=restarts+1 end})
playingSix=true
check(bridge:prepare(localPlayer,newMono,bridgePC)==nil,'Dark Six uses the separate finale path')
playingSix=false;ground=false
check(bridge:prepare(localPlayer,newMono,bridgePC)==false and placements==0,'missing floor delays P2 birth')
bridgeTime=.3;ground=true;room=false
check(bridge:prepare(localPlayer,newMono,bridgePC)==false and placements==0,'occupied capsule delays P2 birth')
bridgeTime=.6;room=true
check(bridge:prepare(localPlayer,newMono,bridgePC)==false and placements==1,'verified placement waits for the pawn to survive initialization')
newMono.alive=false;bridgeTime=.7
check(bridge:prepare(localPlayer,newMono,bridgePC)==false and restarts==1,'a failed birth restarts just the local pawn')
bridgeTime=1
check(bridge:prepare(localPlayer,newMono,bridgePC)==false and restarts==1,'failed births cannot loop through checkpoint reloads')
newMono.alive=true;bridgeTime=1.3
check(bridge:prepare(localPlayer,newMono,bridgePC)==false and placements==2,'a recovered pawn is checked again')
bridgeTime=1.6
check(bridge:prepare(localPlayer,newMono,bridgePC)==true,'a stable pawn joins with no default offset')
bridge:reset();bridgePosition={X=-799,Y=8280,Z=28200}
check(bridge:prepare(localPlayer,newMono,bridgePC)==nil,'the earlier collapse retains normal joining')
print('PASS: final bridge floor and capsule checks, stable handoff and bounded local recovery.')
do
 local now,moves,restarts=0,0,0
 local clear=true
 local canMove=true
 local support='none'
 local function findFloor(_,point,floor)
  floor.bBlockingHit=(support=='left' and point.Y<-75) or (support=='native' and point.X>200)
  floor.bWalkableFloor=floor.bBlockingHit
  floor.FloorDist=point.Z-100
 end
 local function mono(x,y,z)
  local p={valid=true,alive=true,at={X=x,Y=y,Z=z}}
  p.K2_GetActorLocation=function(self)return self.at end
  p.K2_SetActorLocation=function(self,at)
   if not canMove then return false end
   self.at=at;moves=moves+1;return true
  end
  p.IsAlive=function(self)return self.alive end
  p.CapsuleComponent={valid=true,GetScaledCapsuleRadius=function()return 32 end}
  p.CharacterMovement={valid=true,K2_FindFloor=findFloor}
  return p
 end
 local first,second=mono(0,0,100),mono(0,100,100)
 local firstPC={Pawn=first,PlayerCameraManager={valid=true,GetCameraRotation=function()return {Yaw=0}end}}
 local secondPC={valid=true}
 local bridge=Bridge.new({clear=function()return clear end})
 local function instance()
  return SpawnNative.new({live=live,same=function(a,b)return a~=nil and a==b end,
   world=function(a,b)return a==first and live(b)end,clock=function()return now end,log=function()end,
   clear=function()return clear end,landing=function(...)return bridge:destination(...)end,
   restartLocal=function(pc,q,p,at)
    check(pc==secondPC and not q.alive and p==firstPC and at.Y<0,'only the dead local pawn restarts at verified ground')
    restarts=restarts+1;return true
   end})
 end
 local join=instance()
 check(not join:prepareJoin(secondPC,second,firstPC) and moves==0,'an open offset without floor is rejected')
 support='left';clear=false;now=.3
 check(not join:prepareJoin(secondPC,second,firstPC) and moves==0,'a wall between players is also rejected')
 clear=true;canMove=false;now=.6
 check(not join:prepareJoin(secondPC,second,firstPC) and moves==0,'a native placement failure is retried without taking control')
 canMove=true;now=.9
 check(not join:prepareJoin(secondPC,second,firstPC) and moves==1 and second.at.Y==-100,
  'search the other side of P1 when the preferred side has no floor')
 now=1.05;check(not join:prepareJoin(secondPC,second,firstPC),'check the placed pawn before enabling input')
 now=1.2;check(join:prepareJoin(secondPC,second,firstPC) and moves==1,'a stable landing keeps its placement')

 support='native';second=mono(225,0,104);join=instance()
 check(not join:prepareJoin(secondPC,second,firstPC) and moves==1,'a supported native spawn can stay in place')
 now=1.5;check(join:prepareJoin(secondPC,second,firstPC) and moves==1,'the native slot becomes playable without a move')

 support='left';second.alive=false;join=instance()
 check(not join:prepareJoin(secondPC,second,firstPC) and restarts==1,'a failed birth restarts only P2')
 now=2
 check(not join:prepareJoin(secondPC,second,firstPC) and restarts==1,'the same failed birth cannot repeat the restart')
 second=mono(0,0,100)
 check(not join:prepareJoin(secondPC,second,firstPC),'a replacement pawn gets its own landing verification')
 now=2.3;check(not join:prepareJoin(secondPC,second,firstPC) and second.at.Y==-100,'place the replacement on support')
 now=2.6;check(join:prepareJoin(secondPC,second,firstPC),'the replacement returns to play')
end
print('PASS: P2 placement finds a supported side, preserves safe engine starts and recovers only the local pawn.')
local Finale=require('finale_scene')
local betrayal='ANIM_Player_GapHelpSixBetrayal'
local parked,stopped,pulled,shown,dissolved=0,0,0,0,0
local reactions,releasedReaction,rescueReactions=0,0,0
local dissolveProgress
local reaction={valid=true}
local rescueFrames,releasedCameras=0,0
local main=bridgePawn
local partner={valid=true,alive=true,position={X=-809,Y=14026,Z=29050},
 K2_GetActorLocation=function(self)return self.position end,IsAlive=function(self)return self.alive end}
main.IsAlive=partner.IsAlive
main.alive=true
local scene=Finale.new({live=live,same=function(a,b)return a==b and live(a)end,log=function()end,
 animation=function(p)return p.animation end,pull=function(p)check(p==partner,'rescue belongs to P2');pulled=pulled+1;return 1.3 end,
 frameRescue=function(p)check(p==partner,'rescue camera belongs to P2');rescueFrames=rescueFrames+1 end,
 releaseCamera=function()releasedCameras=releasedCameras+1 end,
 reactPartner=function(caught,companion,role)
  if role==1 then
   check(caught==partner and companion==main,'P1 reaches toward P2 when Six catches P2 first')
   rescueReactions=rescueReactions+1
  else
   check(caught==main and companion==partner,'P2 reaches toward P1 when Six catches P1 first')
   reactions=reactions+1
  end
  return reaction
 end,
 stopReaction=function(q,clip)
  check(q==(releasedReaction==0 and main or partner) and clip==reaction,'only release the route-owned pose')
  releasedReaction=releasedReaction+1
 end,
 parkSecond=function()parked=parked+1 end,stopSecond=function()stopped=stopped+1 end,
 chair=function(p)return p.seated end,shadow=function(p)check(p==main,'shadow follows the primary Mono');shown=shown+1 end,
 beginDissolve=function()dissolved=dissolved+1 end,
 dissolve=function(progress)dissolveProgress=progress end,clearShadow=function()end})
local function finaleTick(now,paused)
 return scene:update(main,partner,now,true,true,paused)
end
partner.animation=betrayal
bridgePosition={X=-821,Y=13500,Z=28900}
check(finaleTick(1)=='hold'and pulled==1 and rescueReactions==1,'P2 reaching Six first starts one rescue and P1 reacts')
main.alive=false;main.animation=betrayal
check(finaleTick(2)=='hold'and pulled==1,'P1 death and subsequent catch cannot interrupt the P2 rescue')
check(finaleTick(5,true)=='hold','a paused finale cannot advance')
check(finaleTick(4)=='restart'and not scene.route,'P2 route requests a shared restart after the rescue')
check(rescueFrames==2 and releasedCameras==1 and releasedReaction==1,'the P2 shot and P1 pose release before restart')
bridgePosition={X=-809,Y=14026,Z=29050}
main.alive=true;main.animation=nil;partner.alive=false;partner.animation=nil
check(finaleTick(6)=='grace','P2 falling just before the native catch gets a short grace period')
main.animation=betrayal
check(finaleTick(6.25)=='hold'and stopped==1 and reactions==1,'P1 reaching Six starts the P2 reaction once')
main.alive=false
check(finaleTick(8)=='hold'and parked==1 and shown==0 and releasedReaction==2,'clear the reaction before parking, then wait for the native fall')
partner.valid=false;main.animation=nil;main.alive=true
bridgePosition={X=500,Y=2000,Z=1000}
check(finaleTick(15)=='hold'and shown==1,'the native transition replaces playable P2 with a shadow')
main.seated=true
check(finaleTick(16)=='hold'and dissolved==1 and dissolveProgress==0,'the chair cue starts the effect once')
check(finaleTick(16.8,true)=='hold'and dissolveProgress==0,'pause retains the dissolving shadow')
check(finaleTick(16.3)=='hold'and dissolveProgress>0 and dissolveProgress<1,'the shadow dissolves over the last moment')
check(finaleTick(17)=='hold'and dissolved==1 and shown==1 and dissolveProgress==1,
 'the shadow is never recreated after the chair cue')
bridgePosition={X=-799,Y=11330,Z=28813}
check(not finaleTick(18)and not scene.route,'reloading the bridge clears the finale')
print('PASS: native catch ordering, P2 rescue and reaction, P1 fall, epilogue shadow and one-time dissipation.')
do
 local Native=require('finale_native')
 local position={X=20,Y=50,Z=5}
 local rotation={Pitch=0,Yaw=25,Roll=0}
 local visual={valid=true,K2_GetActorLocation=function()return position end,K2_GetActorRotation=function()return rotation end}
 local emitter={valid=true}
 local count=0
 local instance=Native.new({live=live,UE={GetGameplayStatics=function()return {SpawnEmitterAtLocation=function(_,context,asset,at,facing)
  check(context==visual and asset==emitter and at==position and facing==rotation,'disappearance uses the existing Dark Six appearance')
  count=count+1
 end}end}})
 instance.asset=function()return emitter end
 instance:dissolveAt(visual)
 check(count==1 and visual.valid,'emitter leaves retirement to the normal co-op lifecycle')
 local scale,soundStarts,soundStops=nil,0,0
 local beforeFind=StaticFindObject
 StaticFindObject=function(path)
  check(path=='/Script/AkAudio.Default__AkGameplayStatics','the cue uses the existing positional audio API')
  return {valid=true,
   PostEventAtLocation=function(_,sound,at,_,_,context)
    check(sound==emitter and at==position and context.valid,'the static starts at the shadow position')
    soundStarts=soundStarts+1;return 27
   end,
   ExecuteActionOnPlayingID=function(_,action,id)
    check(action==0 and id==27,'cleanup stops only the finale sound');soundStops=soundStops+1
   end}
 end
 visual.GetActorScale3D=function()return {X=2,Y=2,Z=2}end
 visual.SetActorScale3D=function(_,value)scale=value end
 visual.K2_DestroyActor=function(self)self.valid=false end
 local seated={valid=true}
 instance.c.world=function(a,b)return a==visual and b==seated end
 instance.shadowActor=visual
 instance:beginDissolve(seated)
 instance:dissolve(.5)
 check(soundStarts==1 and scale.X>0 and scale.X<2 and visual.valid,'sound and the still-visible silhouette overlap')
 instance:dissolve(1)
 check(soundStops==1 and not visual.valid and not instance.shadowActor,'the finished effect cleans up its own resources')
 visual.valid=true
 instance.shadowActor=visual
 instance:beginDissolve(seated)
 instance:clearShadow()
 check(soundStops==2 and not visual.valid and not instance.departureScale,'interrupted departure also clears the silhouette and sound')
 StaticFindObject=beforeFind
 local calls={}
 local first={K2_GetActorLocation=function()return position end}
 local secondAt={X=150,Y=0,Z=50}
 local second={IsAlive=function()return true end,K2_GetActorLocation=function()return secondAt end}
 instance.c.world=function(q,p)return q==second and p==first end
 instance.c.playPose=function(q,name,at)
  check(q==second and at==position,'the reaction faces the caught partner')
  calls[#calls+1]=name
  if name=='ANIM_Player_HandHoldOpenHandIdle' then return name end
 end
 check(instance:reactToBetrayal(first,second)=='ANIM_Player_HandHoldOpenHandIdle' and #calls==2,
  'a non-replayable primary gesture falls back to an independent reaching pose')
 secondAt.X=1200
 check(not instance:reactToBetrayal(first,second) and #calls==2,'P2 outside the bridge shot keeps its own pose')
end
do
 local Native=require('finale_native')
 local cameraWorld,cameraClass={valid=true},{valid=true}
 local original,other={valid=true},{valid=true}
 local camera,viewpoint,fieldOfView
 local player={valid=true,PlayerCameraManager={valid=true,GetCameraLocation=function()return {X=-1400}end}}
 player.GetWorld=function()return cameraWorld end
 player.GetViewTarget=function()return viewpoint end
 player.SetViewTargetWithBlend=function(_,target)viewpoint=target end
 function cameraWorld:SpawnActor(class,position,rotation)
  check(class==cameraClass and position.X<partner.position.X,'shot uses the native camera side')
  camera={valid=true,CameraComponent={SetFieldOfView=function(_,value)fieldOfView=value end},
   K2_DestroyActor=function(self)self.valid=false end}
  return camera
 end
 local previousFind=StaticFindObject
 StaticFindObject=function(path)
  check(path=='/Script/Engine.CameraActor','rescue spawns only a camera actor')
  return cameraClass
 end
 partner.valid=true
 local adapter=Native.new({live=live,same=function(a,b)return a==b and live(a)end,
  world=function(_,b)return live(b)end,log=function()end,p1=function()return player end,driver={},
  UE={GetKismetMathLibrary=function()return {FindLookAtRotation=function()return {}end}end}})
 viewpoint=original
 adapter:frameRescue(partner)
 check(viewpoint==camera and fieldOfView==49,'P1 sees the P2 rescue shot at full width')
 viewpoint=other
 adapter:frameRescue(partner)
 check(viewpoint==camera,'native fall camera cannot take the shot before the rescue ends')
 adapter:releaseCamera()
 check(viewpoint==original and not camera.valid,'cleanup restores the original target and destroys the temporary camera')
 StaticFindObject=previousFind
end
do
 local Native=require('finale_native')
 local at={X=-809,Y=14010,Z=29065}
 local pawn={valid=true,CharacterMovement={MovementMode=1},K2_GetActorLocation=function()return at end}
 local adapter=Native.new({same=function(a,b)return a==b end,log=function()end})
 local fallback=0
 adapter.lift.begin=function(_,lift)check(lift.startedAt==1,'fallback starts at the current clip time');fallback=fallback+1 end
 local function attempt()
  return {pawn=pawn,origin={X=-809,Y=14010,Z=29065},startedAt=0,deadline=.85,latest=1.6,lift={}}
 end
 adapter.monoClimb=attempt()
 at={X=-809,Y=14065,Z=29115}
 adapter:updateMonoClimb(pawn,1)
 check(fallback==0 and not adapter.monoClimb,'native locomotion reaching the platform needs no fallback')
 adapter.monoClimb=attempt()
 at={X=-809,Y=14010,Z=29065}
 adapter:updateMonoClimb(pawn,1)
 check(fallback==1 and not adapter.monoClimb,'root motion blocked by the scene releases to the checked path once')
end
do
 local Native=require('finale_native')
 local previousFind,previousAll=StaticFindObject,FindAllOf
 local clock,loads=0,0
 local at={X=-809,Y=14075,Z=29110}
 local six={valid=true,GetFullName=function()return 'BridgeScene Six' end,K2_GetActorLocation=function()return at end}
 function six:SetActorHiddenInGame(hidden)self.bHidden=hidden end
 local duplicate={valid=true,SetActorHiddenInGame=six.SetActorHiddenInGame,GetFullName=function()
  return 'SkeletalMeshActor /Game/Levels/Transmission/SubLevels/LVL_6_140_CollapsingRunExit_02.LVL_6_140_CollapsingRunExit_02:PersistentLevel.SKM_Six3'
 end}
 local otherSix={valid=true,SetActorHiddenInGame=six.SetActorHiddenInGame,GetFullName=function()
  return 'SkeletalMeshActor /Game/OtherRoom.OtherRoom:PersistentLevel.SKM_Six3'
 end}
 local mesh={valid=true,bVisible=false,bRenderInMainPass=true,
  SkeletalMesh={valid=true,GetFullName=function()return 'SkeletalMesh /Game/Scene/Variants.SKM_SixBridge' end}}
 local function engineParam(object)return {get=function()return object end}end
 function six:K2_GetComponentsByClass()return {engineParam(mesh)}end
 function mesh:GetOwner()return six end
 function mesh:IsVisible()return self.bVisible end
 function mesh:SetVisibility(visible)self.bVisible=visible end
 function mesh:SetHiddenInGame(hidden)self.bHiddenInGame=hidden end
 function mesh:SetRenderInMainPass(rendered)self.bRenderInMainPass=rendered end
 function mesh:K2_GetComponentLocation()return at end
 function mesh:K2_GetComponentRotation()return {Pitch=2,Yaw=95,Roll=3}end
 function mesh:GetNumMaterials()return 0 end
 local pose={valid=true,SequenceLength=2}
 local activePose,seek,rate
 local visual={SetMobility=function()end,SetCollisionEnabled=function()end,SetSkeletalMesh=function()end,
  PlayAnimation=function(_,value)activePose=value end,SetPosition=function(_,value)seek=value end,
  SetPlayRate=function(_,value)rate=value end}
 local actor={valid=true,SkeletalMeshComponent=visual,SetActorEnableCollision=function()end,
  K2_DestroyActor=function(self)self.valid=false end}
 partner.GetWorld=function()return {SpawnActor=function(_,_,_,rotation)
  check(rotation.Yaw==275 and rotation.Pitch==2 and rotation.Roll==3,'Six faces the rescued Mono with a half turn')
  loads=loads+1;return actor
 end}end
 StaticFindObject=function(path)
  if path:find('PersistentLevel.SKM_Six2',1,true)then return nil end
  return {valid=true}
 end
 FindAllOf=function(class)return class=='SkeletalMeshActor' and {duplicate,otherSix} or {}end
 local adapter=Native.new({live=function(object)
   if object==nil then return false end
   check(not object.get,'reflected array entries must be unwrapped before UObject access')
   return live(object)
  end,same=function(a,b)return a==b and live(a)end,
  world=function(a,b)return live(a) and live(b) and a~=six and a~=duplicate end,log=function()end,
  UE={GetGameplayStatics=function()return {
   GetTimeSeconds=function()return clock end,
   GetAllActorsOfClass=function(_,_,_,out)out[1]=engineParam(six)end}
  end}})
 adapter.sixPull={asset=pose,startedAt=0,nextSearch=0,rate=1.25}
 adapter:updateSix(partner)
 check(loads==0,'hidden Six is not substituted before the cutscene reveals her')
 mesh.bVisible=true;clock=.25
 adapter:updateSix(partner)
 check(loads==1 and activePose==pose and rate==1.25 and seek==clock*rate and not mesh.bVisible,
  'late-bound Six starts on the same normalized animation frame as P2')
 check(six.bHidden and mesh.bHiddenInGame and not mesh.bRenderInMainPass and duplicate.bHidden and not otherSix.bHidden,'streamed Six actors are hidden even when their world lookup disagrees')
 mesh.bVisible=true;mesh.bHiddenInGame=false;mesh.bRenderInMainPass=true;six.bHidden=false;duplicate.bHidden=false;clock=.5;adapter:updateSix(partner)
 check(loads==1 and not mesh.bVisible and mesh.bHiddenInGame and not mesh.bRenderInMainPass and six.bHidden and duplicate.bHidden,'native visibility changes cannot overlap the rescue visual')
 adapter:clearSixPull()
 check(mesh.bVisible and not mesh.bHiddenInGame and mesh.bRenderInMainPass and not six.bHidden and not duplicate.bHidden and not actor.valid,'cleanup restores Six and removes the temporary visual')
 StaticFindObject,FindAllOf=previousFind,previousAll
end
do
 local Lift=require('finale_lift')
 local blocked,moves=false,{}
 local corrections=0
 local anim={valid=true,RootMotionMode=3,SetRootMotionMode=function(self,mode)self.RootMotionMode=mode end}
 local movement={valid=true,MovementMode=3,tick=true,StopMovementImmediately=function()end,
  SetMovementMode=function(self,mode)self.MovementMode=mode end,
  IsComponentTickEnabled=function(self)return self.tick end,
  SetComponentTickEnabled=function(self,enable)self.tick=enable end}
 local victim
 function movement:K2_FindFloor(point,result)
  if victim.collision and point.Y>=14105 and point.Z>=29128 and point.Z<=29188 then
   result.bBlockingHit,result.bWalkableFloor,result.FloorDist=true,true,point.Z-29128
  end
 end
 local function atEdge()return {X=-809,Y=14010,Z=29065}end
 victim={valid=true,CharacterMovement=movement,position=atEdge(),collision=true,
  GetActorEnableCollision=function(self)return self.collision end,
  SetActorEnableCollision=function(self,enable)self.collision=enable end,
  Mesh={valid=true,GlobalAnimRateScale=1,GetAnimInstance=function()return anim end},
  CapsuleComponent={valid=true,GetScaledCapsuleRadius=function()return 26 end}}
 function victim:K2_GetActorLocation()return self.position end
 function victim:K2_SetActorLocation(target,sweep)
  if not sweep then corrections=corrections+1 end
  moves[#moves+1]=target;self.position=target
 end
 local adapter=Lift.new({live=live,same=function(a,b)return a==b and live(a)end,log=function()end,
  clear=function()return not blocked end})
 local plan=adapter:prepare(victim,0,2,1.5)
 check(plan and plan.plan.target.Z==29131,'the landing uses an actual walkable floor')
 adapter:begin(plan)
 check(not movement.tick and not victim.collision and victim.Mesh.GlobalAnimRateScale==1.5,
  'native movement and overlap reactions are suspended and the Mono clip takes the shared rate')
 victim.position={X=-809,Y=14044,Z=28974}
 adapter:update(victim,.8)
 check(corrections==1 and victim.position.Y==14010 and victim.position.Z>29065 and anim.RootMotionMode==1,
  'the scripted handhold is corrected to the verified path before rising')
 adapter:update(victim,2.1)
 check(plan.landed and victim.position.Y>14105 and movement.MovementMode==1 and victim.collision,'P2 reaches the platform with ground collision restored')
 adapter:release()
 check(anim.RootMotionMode==3 and movement.MovementMode==1 and movement.tick and victim.Mesh.GlobalAnimRateScale==1,
  'a successful pull restores animation and movement without dropping P2')
 victim.position=atEdge();movement.MovementMode=3
 adapter:begin(adapter:prepare(victim,3,2))
 blocked=true
 local count=#moves
 adapter:update(victim,4)
 check(not adapter.active and #moves==count and anim.RootMotionMode==3 and movement.MovementMode==3
  and movement.tick and victim.collision,'a new collision cancels cleanly without moving through it')
end
local sleepAsset={valid=true}
local wakeAsset={valid=true,GetFullName=function()return 'ANIM_Player_SleepingAwakeningIntro2'end}
local data={valid=true,SleepingAnimation=sleepAsset,WakeUpAnimation=wakeAsset,GetFullName=function()return 'native spawn data'end}
local cp={valid=true,IsCurrentCheckpoint=function()return false end,SpawnAnimations=data,
 K2_GetActorLocation=function()return {X=100,Y=0,Z=0}end,GetFullName=function()return 'native outdoor start'end}
FindAllOf=function()return {cp}end
p2.K2_GetActorLocation=function()return {X=0,Y=0,Z=0}end
p2.K2_GetActorRotation=function()return {Pitch=0,Yaw=0,Roll=0}end
adapter.c.world=function()return true end;adapter.c.log=function()end
adapter:born(p2)
local fallbackPlan=adapter:plan(p2,true,1)
check(fallbackPlan.intro and fallbackPlan.sleep==sleepAsset,'reload can use a native start near the captured primary origin')
cp.K2_GetActorLocation=function()return {X=500,Y=0,Z=0}end
adapter:born(p2)
check(adapter:plan(p2,true,2).defer,'far-away checkpoint cannot supply a false introduction')
check(adapter:plan(p2,true,5.1)==nil,'missing checkpoint actor has a bounded wait after primary readiness')
print('PASS: native spawn-origin fallback, distance limit and bounded actor lookup.')
local oldStatic=StaticFindObject
StaticFindObject=function(path)
 if path:find('SleepingIdleSideRight',1,true)then return sleepAsset end
 if path:find('SleepingAwakeningIntro2',1,true)then return wakeAsset end
 return oldStatic(path)
end
FindAllOf=function()return {}end
p2.mAnimationControlComponent.mCurrentAnimStateAsset={valid=true,GetFullName=function()return 'ANIM_Player_SleepingIdleSideRight'end}
adapter:born(p2)
p2.mAnimationControlComponent.mCurrentAnimStateAsset=nil
local nativePose=adapter:plan(p2,true,10)
check(nativePose.intro and nativePose.sleep==sleepAsset and nativePose.wake==wakeAsset,'captured native intro pose survives delayed checkpoint-actor lookup')
adapter:born(p2)
check(adapter:plan(p2,true,20).defer,'a primary with no sleep pose cannot invent an intro')
StaticFindObject=oldStatic
print('PASS: native initial-pose fallback uses existing assets without replaying unrelated animations.')
do
 local center={X=300,Y=400,Z=500}
 local first=pawn(true)
 first.K2_GetActorLocation=function()return center end
 first.K2_GetActorRotation=p2.K2_GetActorRotation
 local primary={Pawn=first}
 local checkpoint={valid=true,SpawnAnimations=cp.SpawnAnimations,WakeUpImmediately=true,
  GetFullName=function()return 'BP_HeliosPlayerStart_C ActualCheckpoint'end}
 local wrongWorld={valid=true}
 local enabled=true
 local native=SpawnNative.new({live=live,same=function(a,b)return a==b end,
  world=function(a,b)return a==checkpoint and b==first end,p1=function()return primary end,
  driver={pawn=p2},session={enabled=enabled},log=function()end})
 local observed,callback,registrations,loaded=0,nil,0,false
 local savedStatic,savedRegister=StaticFindObject,RegisterHook
 StaticFindObject=function()return loaded and checkpoint or nil end
 RegisterHook=function(path,fn)
  check(path:find(':EventPlayerSpawned',1,true),'read the authored checkpoint event')
  callback=fn;registrations=registrations+1
 end
 local born=0
 local localSpawn=Spawn.new(setmetatable({born=function(p)
  check(p==first,'only capture the live primary')
  born=born+1;native:born(p)
 end},{__index=sApi}))
 localSpawn:enable(false);plan=nil
 localSpawn:update(first,true,false,false,1)
 check(localSpawn:update(first,true,false,false,1.4) and born==1,'capture the first native spawn')
 localSpawn:invalidate(first)
 death:reset();death:begin({},first,'P2',true)
 local function confirm(confirmed)
  observed=observed+1
  localSpawn:confirmReload(confirmed)
  death:confirmReload(confirmed)
 end
 native:installCheckpointWatch(1.5,confirm)
 loaded=true;native:installCheckpointWatch(1.7,confirm)
 check(registrations==0,'avoid repeated lookup during streaming')
 native:installCheckpointWatch(2.1,confirm);native:installCheckpointWatch(3,confirm)
 check(registrations==1,'install the observer once the checkpoint Blueprint is available')
 local function handle(point,actor)
  callback({get=function()return point end},{get=function()return actor end})
 end
 handle(checkpoint,p2);handle(wrongWorld,first)
 check(observed==0 and not death:update({},first,nil)
  and not localSpawn:update(first,true,false,false,3),'foreign notifications cannot resume either coordinator')
 center={X=700,Y=800,Z=900}
 handle(checkpoint,first)
 check(observed==1 and death:update({},first,nil),'native spawn completes the shared death state with the same living pawn')
 check(not localSpawn:update(first,true,false,false,3.2) and born==2,
  'native confirmation refreshes the reused pawn’s origin before the stability interval')
 check(localSpawn:update(first,true,false,false,3.6) and native.origin==center,
  'same-pawn checkpoint resumes controls only after native readiness')
 check(native:plan(first,true,4).immediate,'the checkpoint that actually spawned P1 supplies its wake animation')
 StaticFindObject,RegisterHook=savedStatic,savedRegister

 local otherPose={valid=true}
 local stops=0
 p2.mAnimationControlComponent.IsPlayingOverrideAnimation=function()return true end
 p2.mAnimationOverrideComponent={
  PlayAnimationSequenceOverride2=function(_,asset)p2.mAnimationControlComponent.mCurrentAnimStateAsset=asset end,
  StopAnimationSequenceOverride=function()stops=stops+1 end,
 }
 native:play(wakeAsset,false,2)
 check(native:api().playing(),'the adapter owns its own wake clip')
 p2.mAnimationControlComponent.mCurrentAnimStateAsset=otherPose
 check(not native:api().playing(),'a following story animation is outside the respawn lock')
 native:cancel()
 check(stops==0,'checkpoint cleanup preserves a different active pose')
 native:play(wakeAsset,false,2);native:cancel()
 check(stops==1,'checkpoint cleanup releases its unfinished wake clip')
end
print('PASS: native checkpoint events unblock both lifecycle gates and preserve later animation ownership.')
dofile('tests/coop_ui.lua')
dofile('tests/coop_call.lua')
dofile('tests/six_appearance.lua')
dofile('tests/six_control.lua')
dofile('tests/six_hoist.lua')
dofile('tests/main_hooks.lua')
dofile('tests/teleport.lua')
dofile('tests/gamepad.lua')
dofile('tests/online.lua')
dofile('tests/cinematic_trace.lua')
dofile('tests/cinematics.lua')
dofile('tests/cinematic_raft.lua')
dofile('tests/cinematic_tv.lua')
dofile('tests/ledge_rescue.lua')
dofile('tests/hand_rescue.lua')
dofile('tests/hand_offer.lua')
dofile('tests/coop_events.lua')
dofile('tests/subject_trace.lua')
dofile('tests/coop_story_items.lua')
dofile('tests/coop_bully_head.lua')
dofile('tests/coop_bully_rules.lua')
dofile('tests/music_box_transition.lua')
dofile('tests/tower_axe_transition.lua')
dofile('tests/achievements.lua')
dofile('tests/secret_ending.lua')
local marker=require('camera_marker')
local frame={left=100,top=0,right=1266,bottom=768}
assert(not marker.place(frame,683,384,nil,nil,1),'visible player has no arrow')
local left=marker.place(frame,80,384,nil,nil,1)
local right=marker.place(frame,1320,384,nil,nil,1)
assert(left.x==130 and left.dx==-1 and right.x==1236 and right.dx==1,'arrows use the actual camera bounds')
local above=marker.place(frame,nil,nil,0,-2,1)
assert(above.y==30 and above.angle==-90,'behind-camera direction can point upward')
local nextLeft=marker.place(frame,80,384,nil,nil,1)
marker.separate(left,nextLeft,frame,1)
assert(left.y~=nextLeft.y,'same-edge players retain separate labels')
print('PASS: offscreen camera direction, constrained frame and shared-edge marker spacing.')
