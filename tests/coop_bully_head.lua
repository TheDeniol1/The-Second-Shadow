local Head=require('coop_bully_head')
local oldFind=StaticFindObject
local n=0
local function check(v,s) assert(v,s); n=n+1 end
local room={}
local nextAddress=100
local spawned={}
local function object(address)
 local o={valid=true,room=room}
 function o:GetAddress()return address end
 function o:GetFullName()return 'Objeto '..address end
 function o:GetOuter()return self.outer end
 function o:GetAttachParentActor()return self.parent end
 return o
end
local function at(o,x,y,z)
 o.at={X=x,Y=y,Z=z}
 function o:K2_GetActorLocation()return self.at end
 function o:K2_GetActorRotation()return {Pitch=0,Yaw=90,Roll=0} end
end
local first,second=object(1),object(2)
at(first,-500,0,0);at(second,300,0,0)
local bully=object(50)
local headClass={props={{'bUsable','BoolProperty'},{'Radius','FloatProperty'},{'TargetBully','ObjectProperty'},
 {'HeadMesh','ObjectProperty'},{'Bullies','ArrayProperty'}}}
function headClass:ForEachProperty(fn)
 for _,p in ipairs(self.props) do
  fn({GetFName=function()return {ToString=function()return p[1] end}end,
   GetClass=function()return {GetFName=function()return {ToString=function()return p[2] end}end}end})
 end
end
local source=object(10)
at(source,0,0,0)
source.bHidden=false;source.bUsable=true;source.Radius=250;source.TargetBully=bully
source.HeadMesh=object(11);source.HeadMesh.outer=source;source.Bullies={bully}
function source:GetClass()return headClass end
local refuse=false
local world={valid=true,GetAddress=function()return 900 end}
function world:SpawnActor(class,location,rotation)
 assert(class==headClass and rotation.Yaw==90)
 if refuse then return nil end
 nextAddress=nextAddress+1
 local copy=object(nextAddress)
 copy.location=location
 function copy:K2_DestroyActor()self.valid=false;self.destroyed=true end
 spawned[#spawned+1]=copy
 return copy
end
function first:GetWorld()return world end
local present=true
StaticFindObject=function(path)
 if present and path:find('BP_BullyHead_Pickup',1,true) then return source end
end
local routes,logs={},{}
local api={live=function(o)return o~=nil and o.valid==true end,
 same=function(a,b)return a~=nil and b~=nil and a.valid and b.valid and a:GetAddress()==b:GetAddress() end,
 world=function(a,b)return a and a.valid and b and b.valid and a.room==b.room end,
 native={routeActor=function(_,address,on)routes[address]=on;return true end},
 log=function(s)logs[#logs+1]=s end}
local function logged(text)
 for _,line in ipairs(logs) do if line:find(text,1,true) then return true end end
 return false
end
local schoolPath='/Game/Levels/School/PLVL_School.PLVL_School:PersistentLevel.BP_PlayerPawn_C'
local cityPath='/Game/Levels/PaleCity/PLVL_PaleCIty.PLVL_PaleCIty:PersistentLevel.BP_PlayerPawn_C'

local head=Head.new(api)
head:update(first,second,schoolPath,0,false)
check(#spawned==0,'bully head: no copy while P2 events are off')
check(logged('esperando Eventos de P2'),'bully head: waiting reason logged')
head:update(first,second,cityPath,1,true)
check(#spawned==0,'bully head: no copy outside the School')
-- The level's head reports its sublevel world; its level's OwningWorld is the players' world.
source.room={};source.outer={valid=true,OwningWorld={valid=true,GetAddress=function()return 901 end}}
head:update(first,second,schoolPath,2,true)
check(#spawned==0 and logged('otro mundo'),'bully head: a head from another world gets no copy')
source.outer.OwningWorld=world
head:update(first,second,schoolPath,2,true)
local copy=spawned[1]
check(copy and math.abs(copy.location.X-70)<.01 and copy.location.Y==0,'bully head: copy spawns beside the level head toward P2')
check(routes[copy:GetAddress()]==true,'bully head: the copy answers P2')
check(routes[source:GetAddress()]==nil,'bully head: the level head stays with P1')
check(copy.bUsable==true and copy.Radius==250 and copy.TargetBully==bully,'bully head: level settings copied')
check(copy.HeadMesh==nil and copy.Bullies==nil,'bully head: own components and arrays are not copied')
check(logged('variables de la cabeza original') and logged('sin copiar: HeadMesh, Bullies'),'bully head: original variables logged once')
head:update(first,second,schoolPath,3,true)
check(#spawned==1,'bully head: a single copy')

source.CurrentMaskState=2;copy.CurrentMaskState=0
head:update(first,second,schoolPath,3.5,true)
check(copy.CurrentMaskState==2 and logged('sigue el estado 2'),'bully head: free copy follows the level head state')
copy.bPickedUp=true;source.CurrentMaskState=3
head:update(first,second,schoolPath,3.6,true)
check(copy.CurrentMaskState==2,'bully head: a picked copy keeps its own state')
check(logged('cabeza del nivel estado=2') and logged('copia estado=2'),'bully head: state changes reported')
copy.bPickedUp=false;source.parent=first
head:update(first,second,schoolPath,3.7,true)
check(copy.CurrentMaskState==2,'bully head: P1 wearing the level head does not change the copy')
source.parent=nil;source.CurrentMaskState=2
routes={}
head:update(first,second,schoolPath,4,true)
check(routes[copy:GetAddress()]==true,'bully head: route restored after events cleared it')
routes={}
head:update(first,second,schoolPath,4.5,false)
check(routes[copy:GetAddress()]==nil and #spawned==1,'bully head: paused events keep the copy without routing')

copy.parent=second
head:update(first,second,schoolPath,5,true)
check(logged('la copia la tiene P2'),'bully head: P2 wearing the copy is reported')
source.parent=first
head:update(first,second,schoolPath,6,true)
check(logged('la cabeza del nivel la tiene P1') and #spawned==1,'bully head: P1 takes the level head')

present=false
head:update(first,second,schoolPath,7,true)
check(copy.valid and routes[copy:GetAddress()]==true,'bully head: a worn copy stays when the level head unloads')

-- A copy P2 left on the floor goes away with the level head.
present=true;source.parent=nil;copy.parent=nil
head:update(first,second,schoolPath,20,true)
check(#spawned==1,'bully head: no second copy while the first is alive')
present=false
head:update(first,second,schoolPath,21,true)
check(copy.destroyed and head.copy==nil,'bully head: free copy removed with the level head')

-- Deaths reset even a worn copy: after the checkpoint its reload event would put it on P1.
present=true
head=Head.new(api);spawned={}
head:update(first,second,schoolPath,30,true)
local worn=spawned[1];worn.parent=second
head:update(first,second,schoolPath,30.1,true)
head:reset()
check(worn.destroyed,'bully head: reset removes the copy P2 was wearing')
head:update(first,second,schoolPath,31,true)
local moved=spawned[2];moved.parent=first
head:update(first,second,schoolPath,31.1,true)
check(moved.destroyed and logged('la copia la tiene P1'),'bully head: a copy that lands on P1 is removed')

-- After a checkpoint P1 already wears the level's head: P2 gets a worn copy.
source.parent=first;source.bPickedUp=true;source.CurrentMaskState=1
head=Head.new(api);spawned={};routes={};logs={}
head:update(first,second,schoolPath,50,false)
check(#spawned==0,'bully head: no worn copy while events are off')
local reloads=0
local oldSpawn=world.SpawnActor
function world:SpawnActor(...)
 local copy=oldSpawn(self,...)
 function copy:WorldReloaded()reloads=reloads+1;assert(routes[self:GetAddress()]==true,'routed before reload');self.parent=second end
 return copy
end
head:update(first,second,schoolPath,51,true)
local given=spawned[1]
check(given and given.location.X==second.at.X and reloads==1,'bully head: worn copy spawned at P2 and reloaded onto it')
check(logged('copia creada para ponersela a P2'),'bully head: worn copy reported')
head:update(first,second,schoolPath,51.1,true)
check(logged('la copia la tiene P2') and #spawned==1,'bully head: P2 wears its copy after the checkpoint')
-- If the game still puts it on P1, it is removed and not recreated in a loop.
head:reset();spawned={};reloads=0
function world:SpawnActor(...)
 local copy=oldSpawn(self,...)
 function copy:WorldReloaded()reloads=reloads+1;self.parent=first end
 return copy
end
head:update(first,second,schoolPath,60,true)
head:update(first,second,schoolPath,60.1,true)
head:update(first,second,schoolPath,70,true)
check(#spawned==1 and spawned[1].destroyed,'bully head: a worn copy that lands on P1 is removed once')
world.SpawnActor=oldSpawn
source.parent=nil;source.bPickedUp=nil;source.CurrentMaskState=2

-- Playing as Six, the masks of the pickup animation stay hidden.
local hiddenMasks=0
api.six=function()return true end
api.hideMask=function()hiddenMasks=hiddenMasks+1 end
head=Head.new(api);spawned={}
head:update(first,second,schoolPath,40,true)
local sixCopy=spawned[1]
sixCopy.SpawnedMask=object(77);sixCopy.SpawnedMask.bHidden=false
function sixCopy.SpawnedMask:SetActorHiddenInGame(on)self.bHidden=on end
head:update(first,second,schoolPath,40.1,true)
check(sixCopy.SpawnedMask.bHidden and hiddenMasks==0,'bully head: the animation mask is hidden for Six')
sixCopy.bPickedUp=true
head:update(first,second,schoolPath,40.2,true)
check(hiddenMasks==1,'bully head: P2 mask kept hidden once Six wears the head')
api.six=function()return false end
sixCopy.bPickedUp=false
head:update(first,second,schoolPath,40.3,true)
check(hiddenMasks==1,'bully head: Mono keeps its mask')
api.six,api.hideMask=nil,nil
head:reset()

-- The game removing the copy: retry slowly and give up after three copies.
present=true
head=Head.new(api);spawned={}
for t=0,40,1 do
 head:update(first,second,schoolPath,t,true)
 local last=spawned[#spawned]
 if last and last.valid then last.valid=false end
end
check(#spawned==3 and logged('no se vuelve a crear'),'bully head: copies the game removes are retried at most three times')

head=Head.new(api);spawned={}
source.bHidden=true
head:update(first,second,schoolPath,0,true)
check(#spawned==0,'bully head: hidden level head gets no copy')
check(logged('la cabeza del nivel esta oculta'),'bully head: hidden reason logged')
source.bHidden=false
refuse=true
head:update(first,second,schoolPath,1,true)
check(#spawned==0 and logged('el juego no creo la copia'),'bully head: failed spawn reported')
refuse=false

head=Head.new(api);spawned={}
head:update(first,second,schoolPath,0,true)
local free=spawned[1]
head:update(first,second,cityPath,1,true)
check(free.destroyed and head.source==nil,'bully head: leaving the School removes a free copy')
head:update(first,second,schoolPath,2,true)
head:reset()
check(spawned[2].destroyed,'bully head: reset removes a free copy')

-- The copy's grab axis answers P2's grab; other actors keep their own input.
local oldHook=RegisterHook
local hooked,post={},nil
RegisterHook=function(path,pre,after)hooked[#hooked+1]=path;post=after end
local grab=false
api.input=function()return {grab=grab} end
logs={}
head=Head.new(api);spawned={}
source.parent=nil;source.bHidden=false;present=true
at(first,-60,0,0)
head:update(first,second,schoolPath,0,true)
local mine=spawned[1]
check(#hooked==1 and hooked[1]=='/Script/Engine.Actor:GetInputAxisValue','bully head: grab axis hooked once the copy exists')
check(logged('P1 junto a la cabeza del nivel (60)'),'bully head: P1 at the level head is reported')
local function param(v)return {get=function()return v end} end
local axisName={ToString=function()return 'Grab' end}
check(post(param(mine),param(axisName))==0.0,'bully head: P1 grab does not reach the copy')
grab=true
head:update(first,second,schoolPath,0.1,true)
check(post(param(mine),param(axisName))==1.0 and logged('el eje Grab de la copia'),'bully head: P2 grab picks up the copy')
check(post(param(source),param(axisName))==nil,'bully head: the level head keeps P1 input')
head:update(first,second,schoolPath,0.2,false)
check(post(param(mine),param(axisName))==0.0,'bully head: no P2 grab while events are off')
head:update(first,second,schoolPath,0.3,true)
head:reset()
check(post(param(mine),param(axisName))==nil,'bully head: removed copy releases the axis')
head:update(first,second,schoolPath,10,true)
check(#hooked==1,'bully head: the hook is installed only once')
RegisterHook=oldHook;api.input=nil
at(first,-500,0,0)

StaticFindObject=oldFind
print('PASS: '..n..' checks (bully head copy for P2).')
