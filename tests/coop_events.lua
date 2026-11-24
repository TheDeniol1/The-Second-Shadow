local Events=require('coop_events')
local oldFind=StaticFindObject
local hangable,drag,pickup,lever={valid=true},{valid=true},{valid=true},{valid=true}
local classes={
 ['/Script/Helios.PlayerHangableInterface']=hangable,
 ['/Script/Helios.PlayerDragInterface']=drag,
 ['/Script/Helios.PlayerPickupInterface']=pickup,
 ['/Script/Helios.PlayerLeverGrabInterface']=lever,
}
StaticFindObject=function(path)return classes[path]end
local function pawn()
 local anim={valid=true}
 return {valid=true,anim=anim,Mesh={valid=true,GetAnimInstance=function()return anim end}}
end
local first,second=pawn(),pawn()
local room={}
first.room=room;second.room=room
local function object(address)
 return {valid=true,room=room,GetAddress=function()return address end,
  GetFullName=function()return 'Test actor' end}
end
local switch,zipline,box=object(12),object(42),object(43)
local active,routes,boxRoute,primaryGrab
local input={}
local writes=0
local api={live=function(o)return o and o.valid end,same=function(a,b)return a~=nil and a==b end,
 world=function(a,b)return a and a.valid and b and b.valid and a.room==b.room end,
 p1=function()return {Pawn=first}end,driver={pawn=second},
 input=function()return input end,primaryGrab=function()return primaryGrab end,
 native={
  routeActive=function(_,on)active=on;routes={};boxRoute=false;return on end,
  routeActor=function(_,address,on)routes[address]=on;writes=writes+1;return true end,
  routeClear=function()routes={}end,
  weaponHitRoutes=function()return 0 end,
  routeMusicBox=function(_,on)boxRoute=on;return 0 end,
 },
 log=function()end}
local function grab(player,kind,actor)
 local component={valid=true,GetOwner=function()return actor end}
 local iface={valid=true,mControlledPawn=player,IsA=function(_,class)return kind==class end,
  mGrabbedHangable=component,mGrabbedGrabHelper=component}
 iface.GetCurrentlyHeldPickup=function()return actor end
 player.anim.mCurrentlyActiveGrabInterface=iface
 return iface
end
local function routed()
 for _,on in pairs(routes) do if on then return true end end
 return false
end
local e=Events.new(api)
grab(second,{},zipline)
e:interact()
assert(writes==0,'the disabled router does not react to a grab')
e:setEnabled(true)
assert(active and e.enabled,'opt-in installs the router')
e:interact()
assert(writes==0,'an unrecognized grab never redirects unrelated scripts')

grab(first,hangable,switch)
grab(second,hangable,zipline)
e:interact()
assert(routes[42] and not routes[12],
 'simultaneous grips keep the P2 route on its source object and leave the P1 switch native')
e:interact()
assert(writes==1,'a continued grab does not register the same route every tick')

grab(first,hangable,zipline)
e:interact()
assert(not routed(),'two grabs on the same prop are ambiguous')
grab(second,drag,box)
e:interact()
assert(routes[43] and not routes[42],'drag redirects the owner of the active grab helper')
local foreign=grab(second,hangable,zipline);foreign.mControlledPawn=first
e:interact()
assert(not routed(),'a foreign interface cannot claim the route')

local holder=first
local pickupComponent=object(903)
pickupComponent.GetHolderIfHeld=function()return holder end
pickupComponent.GetOwner=function()return box end
grab(second,pickup,pickupComponent);e:interact()
assert(not routed(),'a pickup interface alone does not establish ownership')
holder=second;e:interact()
assert(routes[43] and not routes[903],'redirect the owning actor rather than the pickup component')
box.room={}
e:interact()
assert(not routed(),'a streamed object from a different world does not keep the route')
box.room=room;e:interact()
second.anim.mCurrentlyActiveGrabInterface=nil;e:interact()
assert(not routed() and not e.actor,'release removes the route')

local at={X=-493,Y=994,Z=28220}
second.K2_GetActorLocation=function()return at end
second.GetFullName=function()return 'BP_PlayerPawn_C /Game/Levels/Transmission/PLVL_Transmission.Test' end
first.K2_GetActorLocation=second.K2_GetActorLocation
first.GetFullName=second.GetFullName
grab(second,lever,box);e:interact()
assert(routes[43],'a verified P2 lever grip can route its own actor in the final box room')
at={X=-493,Y=0,Z=0};e:interact()
assert(not routed(),'the new lever route is confined to the recorded room')

grab(second,drag,box);e:interact();e:setEnabled(false)
assert(not active and not e.actor and not routed(),'disable clears stored ownership')
e:setEnabled(true)
at={X=-493,Y=994,Z=28220}
local axe=object(873)
axe.GetFullName=function()
 return 'BP_ItemWeapon_C /Game/Levels/Transmission/SubLevels/LVL_6_000_Transmission_CLOs.LVL_6_000_Transmission_CLOs:PersistentLevel.BP_ItemWeapon_2'
end
pickupComponent.GetOwner=function()return axe end
local carried
first.GetPlayerPickupInterface=function()
 return {valid=true,GetCurrentlyHeldPickup=function()return holder==first and carried or nil end}
end
second.GetPlayerPickupInterface=function()
 return {valid=true,GetCurrentlyHeldPickup=function()return holder==second and carried or nil end}
end
first.anim.mCurrentlyActiveGrabInterface=nil
second.anim.mCurrentlyActiveGrabInterface=nil
input.grab=true;primaryGrab=true;e:interact(1)
assert(not boxRoute,'a simultaneous grab near the scripted axe is ambiguous')
primaryGrab=false;e:interact(2)
assert(boxRoute and e.box=='recogida','arm the lookup before P2 dispatches the scripted grab')
input.grab=false
local scripted=grab(second,lever,box)
scripted.mGrabbedGrabHelper=nil
e:interact(3)
assert(boxRoute and not routed(),'the scripted lever is attributed even before the helper is set')
local firstLever=grab(first,lever,box);firstLever.mGrabbedGrabHelper=nil
e:interact(4)
assert(not boxRoute,'preserve P1 when the game identifies a competing lever grab')
first.anim.mCurrentlyActiveGrabInterface=nil
second.anim.mCurrentlyActiveGrabInterface=nil
carried=pickupComponent;e:interact(5)
assert(not boxRoute,'holding the axe alone does not grant the room route')
input.use=true;e:interact(6)
assert(boxRoute and e.box=='golpe','the exact axe and P2 use arm the strike')
input.use=false;carried=nil;e:interact(7)
assert(boxRoute,'keep ownership through the brief release during the animation')
local hit={fromSecond=true,startedAt=7}
e:interact(15,hit)
assert(boxRoute,'keep the continuation attributed while the confirmed P2 hit runs')
hit.arrivedAt=16;e:interact(16,hit)
assert(not boxRoute,'clear the route once the arrival starts')
input.use=true;carried=pickupComponent;e:interact(17)
assert(boxRoute)
holder=first;e:interact(18)
assert(not boxRoute,'a confirmed P1 axe holder cancels a pending P2 route')
holder=second;e:interact(19)
at={X=-5000,Y=994,Z=28220};e:interact(20)
assert(not boxRoute,'another area at the same height cannot redirect the scene')
e:setEnabled(false)
api.native.routeActive=function()return false end
e:setEnabled(true)
assert(not e.enabled,'failure leaves the option inactive')
grab(second,lever,zipline)
assert(e:heldObject(second)==zipline,'diagnostics report any grabbed component owner, lever included')
local empty=grab(first,lever,nil);empty.mGrabbedHangable=nil;empty.mGrabbedGrabHelper=nil
empty.GetCurrentlyHeldPickup=function()error('not a pickup interface')end
assert(e:heldObject(first)==nil,'an empty lever grab or a foreign interface reports nothing')
first.anim.mCurrentlyActiveGrabInterface=nil
assert(e:heldObject(first)==nil,'no grab, no object')
-- Rule 1: the DLL resolves lookups from scripts handling P2; Lua arms and reports it.
local frameOn,frameReads,logs=nil,40,{}
local f=Events.new({live=api.live,same=api.same,world=api.world,p1=api.p1,driver=api.driver,
 input=api.input,primaryGrab=api.primaryGrab,log=function(text)logs[#logs+1]=text end,
 native={routeActive=function(_,on)return on end,routeActor=function()return true end,
  routeClear=function()end,weaponHitRoutes=function()return 0 end,
  routeMusicBox=function()return 0 end,
  routeFrames=function(_,on)frameOn=on;return frameReads end}})
first.anim.mCurrentlyActiveGrabInterface=nil;second.anim.mCurrentlyActiveGrabInterface=nil
f:interact(nil,nil,1)
assert(frameOn==nil,'the frame rule stays off while P2 events are off')
f:setEnabled(true)
assert(frameOn==true and f.frameBase==40,'enabling arms the frame rule and counts from now')
f:interact(nil,nil,2)
assert(#logs==0,'no context lookups yet, nothing to report')
frameReads=43;f:interact(nil,nil,3)
assert(logs[#logs]=='Eventos P2: 3 consultas resueltas por contexto a P2','report new context lookups')
frameReads=50;f:interact(nil,nil,4)
assert(#logs==1,'reports are throttled')
f:interact(nil,nil,9)
assert(#logs==2 and logs[2]:find('10 consultas',1,true),'and resume after five seconds')
f:mark()
assert(logs[#logs]=='Eventos P2: consultas resueltas por contexto a P2: 10','F8 shows the total')
f:setEnabled(false)
assert(frameOn==false and f.frameBase==nil,'disabling turns the frame rule off')
local g=Events.new({live=api.live,same=api.same,world=api.world,p1=api.p1,driver=api.driver,
 input=api.input,primaryGrab=api.primaryGrab,log=function()end,
 native={routeActive=function(_,on)return on end,routeClear=function()end,routeMusicBox=function()return 0 end}})
g:setEnabled(true);g:interact(nil,nil,1);g:setEnabled(false)
-- Key locks: while P2 holds a lever-type grab (and P1 does not), the DLL's
-- short P2 window is renewed every tick, as in the first version of P2 events.
local windowCalls,windowOn,windowReads,lockLogs={}, nil, 10, {}
local h=Events.new({live=api.live,same=api.same,world=api.world,p1=api.p1,driver=api.driver,
 input=api.input,primaryGrab=api.primaryGrab,log=function(text)lockLogs[#lockLogs+1]=text end,
 native={routeActive=function(_,on)return on end,routeActor=function()return true end,
  routeClear=function()end,weaponHitRoutes=function()return 0 end,
  routeMusicBox=function(_,on)windowOn=on;windowCalls[#windowCalls+1]=on;return windowReads end}})
first.anim.mCurrentlyActiveGrabInterface=nil
local function emptyLever(player)
 local iface=grab(player,lever,nil);iface.mGrabbedGrabHelper=nil;iface.mGrabbedHangable=nil
 return iface
end
emptyLever(second)
h:interact(nil,nil,1)
assert(windowOn==nil,'nothing happens while P2 events are off')
h:setEnabled(true)
h:interact(nil,nil,2)
assert(windowOn==true and lockLogs[#lockLogs]:find('candado',1,true),'P2 at a lock opens the P2 window')
windowReads=14;h:interact(nil,nil,3)
assert(windowOn==true and #windowCalls==2,'the window is renewed on every tick')
second.anim.mCurrentlyActiveGrabInterface=nil
h:interact(nil,nil,4)
assert(windowOn==false and lockLogs[#lockLogs]:find('4 consultas',1,true),'releasing closes the window and reports the answers')
local calls=#windowCalls;h:interact(nil,nil,5)
assert(#windowCalls==calls,'no further calls once closed')
emptyLever(second);emptyLever(first)
h:interact(nil,nil,6)
assert(#windowCalls==calls,'when P1 also works a lever or lock, the game decides')
second.anim.mCurrentlyActiveGrabInterface=nil
h:interact(nil,nil,7)
assert(#windowCalls==calls,'a P1 lock grab alone is left to the game')
first.anim.mCurrentlyActiveGrabInterface=nil
emptyLever(second);h:interact(nil,nil,8)
h:setEnabled(false)
assert(h.lockHeld==nil,'disabling forgets the lock')
second.anim.mCurrentlyActiveGrabInterface=nil
StaticFindObject=oldFind
print('PASS: event attribution by real grab ownership, final axe pickup and strike, competing players, held-object diagnostics, context rule reporting, key locks and opt-in lifecycle.')
