local Rules=require('coop_bully_rules')
local oldFind,oldAll=StaticFindObject,FindAllOf
local n=0
local function check(v,s) assert(v,s); n=n+1 end
local room={}
local function actor(address,x,name)
 local o={valid=true,room=room,at={X=x,Y=0,Z=0}}
 function o:GetAddress()return address end
 function o:GetFullName()return name or ('Actor '..address) end
 function o:K2_GetActorLocation()return self.at end
 return o
end
local function pawn(address,x)
 local p=actor(address,x)
 p.anim=''
 p.mAnimationControlComponent={valid=true,
  IsPlayingOverrideAnimation=function()return p.anim~='' end,
  mCurrentAnimStateAsset={valid=true,GetFullName=function()return p.anim end}}
 return p
end
local first,second=pawn(1,0),pawn(2,1000)
local bully=actor(60,900,'BP_BullyPawn_C /Game/Levels/School/PLVL_School.PLVL_School:PersistentLevel.BP_BullyPawn_C_1')
local pushClass={props={{'Speed','FloatProperty'},{'BullyPawn','ObjectProperty'}}}
function pushClass:GetAddress()return 500 end
function pushClass:ForEachProperty(fn)
 for _,p in ipairs(self.props) do
  fn({GetFName=function()return {ToString=function()return p[1] end}end,
   GetClass=function()return {GetFName=function()return {ToString=function()return p[2] end}end}end})
 end
end
local behaviour=actor(50,0,'BP_BullyPushBehaviour5')
behaviour.Speed=3;behaviour.BullyPawn=bully
function behaviour:GetClass()return pushClass end
local gap=actor(70,1100,'BP_SqueezeGap_PlayerLosesBullyHead_2')
local farGap=actor(71,5000,'BP_SqueezeGap_PlayerLosesBullyHead_3')
local listed={BP_BullyPushBehaviour_C={behaviour},BP_SqueezeGap_PlayerLosesBullyHead_C={gap,farGap}}
FindAllOf=function(class)return listed[class] end
StaticFindObject=function()return nil end
local routes,logs={},{}
-- Like main.lua's live: a boolean here is a bug and must fail the test.
local api={live=function(o)return o~=nil and o.valid==true end,
 same=function(a,b)return a~=nil and b~=nil and a.valid and b.valid and a:GetAddress()==b:GetAddress() end,
 world=function(a,b)return a and a.valid and b and b.valid and a.room==b.room end,
 native={routeActor=function(_,address,on)routes[address]=on;return true end},
 log=function(s)logs[#logs+1]=s end}
local function logged(text)
 for _,line in ipairs(logs) do if line:find(text,1,true) then return true end end
 return false
end
local school='BP_PlayerPawn_C /Game/Levels/School/PLVL_School.PLVL_School:PersistentLevel.BP_PlayerPawn_C_1'
local city='BP_PlayerPawn_C /Game/Levels/PaleCity/PLVL_PaleCIty.PLVL_PaleCIty:PersistentLevel.BP_PlayerPawn_C_1'

local rules=Rules.new(api)
rules:update(first,second,school,0,true)
check(routes[50]==true and logged('Empujones: BP_BullyPushBehaviour5 responde a P2'),'bully rules: the bully pushing P2 answers P2')
check(logged('el abuson esta en BullyPawn'),'bully rules: the bully reference is found and logged')
check(routes[70]==nil,'bully rules: gaps untouched while nobody squeezes')

second.at={X=300,Y=0,Z=0};first.at={X=850,Y=0,Z=0}
rules:update(first,second,school,0.5,true)
check(routes[50]==false and logged('vuelve a P1'),'bully rules: the bully near P1 answers P1 again')
second.at={X=1000,Y=0,Z=0};first.at={X=0,Y=0,Z=0}
bully.at={X=2000,Y=0,Z=0}
rules:update(first,second,school,1,true)
check(routes[50]~=true,'bully rules: a bully far from both players stays with P1')
bully.at={X=900,Y=0,Z=0}

second.anim='AnimSequence /Game/Characters/Six/Animations/ANIM_Six_SqueezeThroughBarsRun'
rules:update(first,second,school,2,true)
check(routes[70]==true and routes[71]==nil,'bully rules: the gap P2 squeezes through answers P2')
second.anim=''
rules:update(first,second,school,4,true)
check(routes[70]==true,'bully rules: the gap keeps answering P2 while P2 exits')
rules:update(first,second,school,6.5,true)
check(routes[70]==false,'bully rules: the gap returns to P1 after the exit')

second.anim='ANIM_Six_SqueezeThroughBarsRun';first.anim='ANIM_Player_SqueezeThroughBars'
rules:update(first,second,school,7,true)
check(routes[70]~=true,'bully rules: P1 squeezing keeps the gap with P1')
first.anim='';second.anim=''

rules:update(first,second,school,8,true)
check(routes[50]==true,'bully rules: push route restored')
rules:update(first,second,school,8.1,false)
check(routes[50]==false,'bully rules: events off clears the routes')
rules:update(first,second,school,8.2,true)
rules:update(first,second,city,8.3,true)
check(routes[50]==false,'bully rules: leaving the School clears the routes')
rules:update(first,second,school,8.4,true)
rules:reset()
check(routes[50]==false and next(rules.routed)==nil,'bully rules: reset clears the routes')

-- A behaviour without a bully variable uses its own position (once crashed on false).
local plainClass={props={{'Speed','FloatProperty'}}}
function plainClass:GetAddress()return 501 end
plainClass.ForEachProperty=pushClass.ForEachProperty
local plain=actor(52,950,'BP_BullyPushBehaviour6')
plain.Speed=1
function plain:GetClass()return plainClass end
listed.BP_BullyPushBehaviour_C={plain}
logs={}
rules=Rules.new(api)
local strict=api.live
api.live=function(o)assert(type(o)~='boolean','live() got a boolean');return strict(o)end
rules:update(first,second,school,0,true)
api.live=strict
check(routes[52]==true and logged('se usa la posicion del comportamiento') and not logged('Reglas de abusones'),'bully rules: behaviour without a bully reference uses its own position')
rules:reset()

FindAllOf=function()error('broken')end
logs={}
rules=Rules.new(api)
rules:update(first,second,school,0,true)
check(routes[50]==false,'bully rules: a failing search leaves no route')

StaticFindObject,FindAllOf=oldFind,oldAll
print('PASS: '..n..' checks (bully pushes and the narrow gap answer the player involved).')
