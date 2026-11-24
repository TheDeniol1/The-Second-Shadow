local Door=require('tower_axe_transition')
local axe={GetFullName=function()
 return 'BP_ItemWeapon_C /Game/Levels/Transmission/SubLevels/LVL_6_000_Transmission_CLOs.LVL_6_000_Transmission_CLOs:PersistentLevel.BP_ItemWeapon_Preboss'
end}
local other={GetFullName=function()return axe:GetFullName()..'_2' end}
local first,second={},{}
local tries,moves=0,0
local logs={}
local safe=true
local door=Door.new({same=function(a,b)return a==b end,held=function(p)return p.held end,
 log=function(message)logs[#logs+1]=message end,
 grounded=function(p)return p.grounded end,canMove=function(p)return not p.busy end,
 destination=function(anchor,follower,at)
  assert(anchor~=follower and anchor.at==at)
  tries=tries+1
  if safe then return {X=at.X+100,Y=at.Y,Z=at.Z} end
 end,
 move=function(p,at)moves=moves+1;p.at=at;return true end})

local function setup()
 for i,p in ipairs({first,second}) do
  p.at={X=-326+i*100,Y=-1619,Z=13063}
  p.K2_GetActorLocation=function(self)return self.at end
  p.held,p.grounded,p.busy=nil,true,false
 end
 safe=true
 door:reset()
end
local function step(t,ready,paused)
 door:update(first,second,t,ready~=false,paused)
end

setup()
second.held=other
step(0)
first.at={X=8000,Y=1400,Z=4800}
step(.1)
assert(moves==0 and not door:protectsSeparation(),'other axes cannot arm this door')

setup()
second.held=axe
step(1)
first.at={X=8000,Y=1400,Z=4800}
first.grounded=false
second.held=nil
step(1.1)
assert(door:protectsSeparation() and tries==0 and moves==0,'wait for the native recipient to land')
first.grounded=true
safe=false
step(1.4)
assert(tries==1 and moves==0 and door:protectsSeparation(),'keep waiting if the new room has no free landing')
safe=true
step(1.7,true,true)
assert(tries==1 and moves==0,'pause holds the transfer')
step(1.72)
assert(moves==1 and second.at.X==8100 and not door:protectsSeparation(),'follow P1 into the verified destination')
step(2.05)
assert(moves==1,'complete the passage once')

setup()
second.held=axe
step(3)
second.at={X=-7500,Y=2300,Z=5900}
first.busy=true
step(3.13)
assert(moves==1 and door:protectsSeparation())
first.busy=false
step(3.36)
assert(moves==2 and first.at.X==-7400 and second.at.X==-7500,'follow P2 if the game transfers its attacker')

setup()
first.held=axe
step(4)
first.at={X=447,Y=117,Z=13020}
step(4.8)
assert(moves==2 and not door:protectsSeparation(),'ordinary movement across a longer sample is not a warp')
first.at={X=447,Y=117,Z=12992}
step(4.9)
assert(moves==2,'a falling frame does not count as a warp')
step(5,false)
assert(not door.track,'cancel the door transfer when the checkpoint invalidates the pair')

setup()
first.held=axe
step(6)
first.at={X=8200,Y=1400,Z=4800}
second.at={X=8300,Y=1400,Z=4800}
step(6.11)
assert(moves==2 and not door:protectsSeparation(),'preserve both native arrivals')
print('PASS: the scoped Tower axe follows either native arrival, preserves both arrivals and requires a walkable destination.')
