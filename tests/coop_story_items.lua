local Story=require('coop_story_items')
local oldFind,oldList,oldName=StaticFindObject,FindAllOf,FName
local room={}
local function object(address)
 return {room=room,GetAddress=function()return address end}
end
local first,second=object(1),object(2)
local function pawn(p,at)
 p.at={X=at,Y=0,Z=0}
 function p:K2_GetActorLocation()return self.at end
end
pawn(first,0);pawn(second,1500)
local cityPath='/Game/Levels/PaleCity/PLVL_PaleCIty.PLVL_PaleCIty:PersistentLevel.BP_PlayerPawn_C'
local schoolPath='/Game/Levels/School/PLVL_School.PLVL_School:PersistentLevel.BP_PlayerPawn_C'
local cafePath='/Game/Levels/School/SubLevels/LVL_2_280_Cafeteria.LVL_2_280_Cafeteria:PersistentLevel.'
local zip=object(3)
zip.bReturnToStart=false;zip.progress=0;zip.resets=0
zip.hangable=object(30);zip.ZipStart={K2_GetComponentLocation=function()return {X=0,Y=0,Z=0}end}
function zip:IsThisPieceBeingUsed()return self.inUse end
function zip:GetPieceProgress()return self.progress end
function zip:CE_Reset()self.resets=self.resets+1 end
local schoolClass={}
StaticFindObject=function(path)
 if path:match('BP_Zipline2$') then return zip end
 if path=='/Script/Helios.ControlledPawn' then return schoolClass end
end
FName=function(name)return name end
local function enemy(address,kind,path)
 local e=object(address)
 e.GetFullName=function()return path end
 e.GetPawnType=function()return kind end
 e.IsA=function(_,class)return class==schoolClass end
 return e
end
local bully=enemy(6,6,'BP_Bully_C PersistentLevel.DynamicBully')
local teacher=enemy(5,5,cafePath..'Teacher')
local otherBully=enemy(7,6,'/Game/Levels/School/SubLevels/OtherRoom:PersistentLevel.Bully')
local placedBully=enemy(8,6,cafePath..'Bully')
local function observer(address,p)
 local sensor=object(address+20);sensor.GetOwner=function()return p end
 local a=object(address);a.mSensors=sensor;return a
end
local spawner=object(10)
spawner.GetFullName=function()return cafePath..'AISpawner' end
spawner.GetSpawnedAI=function()return bully end
local found={
 AISpawner={spawner},
 PerceptionAnalyzer={observer(106,bully),observer(105,teacher),observer(107,otherBully),observer(108,placedBully)},
}
FindAllOf=function(class)return found[class]end
local visible=true
local config,available
local story=Story.new({
 live=function(o)return o~=nil end,same=function(a,b)return a~=nil and a==b end,
 world=function(a,b)return a and b and a.room==b.room end,log=function()end,
 canEquip=function(p)assert(p==second);return available end,
 gameplay=function()return {GetStreamingLevel=function(_,p,name)
   assert(p==first and name:find('Cafeteria',1,true))
   return {IsLevelVisible=function()return visible end}
  end}end,
 native={schoolEscort=function(_,address,observers)
   config=address and {address,observers} or nil
   return true
  end},
})
local function city(now,paused)story:update(first,second,cityPath,now,paused)end
city(0)
assert(zip.bReturnToStart and zip.resets==0,'return uses the native flag from the start')
zip.progress=1;second.PlayerHangableInterface={mGrabbedHangable=zip.hangable}
city(1);city(3)
assert(zip.resets==0,'never reset a hook while occupied')
second.PlayerHangableInterface=nil
city(3.1);city(4.7)
assert(zip.resets==1,'an empty hook at the far end can be restored for the waiting player')
city(8);assert(zip.resets==1,'the fallback runs once per stuck crossing')
zip.progress=.4;city(8.1);zip.progress=1;city(8.2);city(10,true)
assert(zip.resets==1,'paused frames never reset the piece')
story:reset()
assert(not zip.bReturnToStart,'return setting restores when leaving coop')

local function schoolTick(now,paused)story:update(first,second,schoolPath,now,paused)end
local a,b={},{}
first.PlayerHandholdingInterface=a;second.PlayerHandholdingInterface=b
a.IsHoldingHands=function()return true end;b.IsHoldingHands=a.IsHoldingHands
a.GetHeldPartner=function()return b end;b.GetHeldPartner=function()return {} end
schoolTick(11)
assert(not config,'handhold must reciprocally belong to the two players')
b.GetHeldPartner=function()return a end
schoolTick(11.1)
assert(config[1]==2 and #config[2]==2 and config[2][1]==106 and config[2][2]==108,
 'only P2 and actual cafeteria Bullies are passed to the native filter')
b.IsHoldingHands=function()return false end
schoolTick(11.2)
assert(not config,'release clears protection immediately before the next poll')
b.IsHoldingHands=a.IsHoldingHands
schoolTick(12)
schoolTick(12.1,true)
assert(not config,'pausing clears the perception routing')
visible=false
schoolTick(13)
assert(not config,'unloaded cafeteria cannot protect against other rooms')

local hospitalPath='/Game/Levels/Hospital/PLVL_Hospital.PLVL_Hospital:PersistentLevel.BP_PlayerPawn_C'
local source,borrowed,existing=object(41),object(42),object(43)
local sourceInventory,localInventory=object(44),object(45)
local sourceItem,secondItem
local grants,removals,destroyed=0,0,0
local expectedSlot=1
local createdActor,p1Light=object(46),object(47)
function borrowed:GetOwner()return createdActor end
function source:GetOwner()return p1Light end
function createdActor:K2_DestroyActor()destroyed=destroyed+1 end
function sourceInventory:GetInventoryItem(slot)assert(slot==expectedSlot);return sourceItem end
function localInventory:HasInventoryItem(slot)assert(slot==expectedSlot);return secondItem~=nil end
function localInventory:GetInventoryItem(slot)assert(slot==expectedSlot);return secondItem end
function localInventory:SpawnEquipItem(slot,save)
 assert(slot==expectedSlot and save==false and secondItem==nil,'equip P2 without writing progression')
 grants=grants+1;secondItem=borrowed
end
function localInventory:RemoveItemFromInventory(slot,save)
 assert(slot==expectedSlot and save==false and secondItem==borrowed,'cleanup only the temporary item')
 removals=removals+1;secondItem=nil
end
first.GetInventoryComponent=function()return sourceInventory end
second.GetInventoryComponent=function()return localInventory end
local override
first.mAnimationControlComponent={IsPlayingOverrideAnimation=function()return override end}
local function hospitalTick(now,paused,mono)story:update(first,second,hospitalPath,now,paused,mono)end
available=true;hospitalTick(14,false,true)
assert(grants==0,'P2 only obtains the flashlight after P1')
sourceItem=source;override=true;hospitalTick(15,false,true)
assert(grants==0,'the scripted pickup can finish before spawning P2 equipment')
override=false;hospitalTick(16,true,true)
hospitalTick(17,false,false)
assert(grants==0,'skip paused frames and the Six story pawn')
available=false;hospitalTick(18,false,true)
assert(grants==0,'do not equip while P2 is in a conflicting action')
available=true;hospitalTick(19,false,true);hospitalTick(20,false,true)
assert(grants==1 and secondItem==borrowed,'the flashlight is equipped once per missing inventory')
sourceItem=nil;hospitalTick(21,false,true)
assert(removals==1 and destroyed==1 and not secondItem,'a checkpoint before the pickup removes the owned flashlight')
sourceItem=source;hospitalTick(22,false,true)
assert(grants==2 and secondItem==borrowed,'the original unlock can grant the flashlight after reloading')
story:reset()
assert(removals==2 and destroyed==2 and not secondItem,'leaving the mode removes the owned item')
secondItem=existing;hospitalTick(23,false,true)
story:reset()
assert(grants==2 and removals==2 and secondItem==existing,'preserve an existing native item')
secondItem=nil;hospitalTick(24,false,true)
secondItem=existing;story:reset()
assert(grants==3 and removals==2 and secondItem==existing,'do not remove an item replacing the tracked one')

expectedSlot=3
sourceItem=nil;secondItem=nil
story:update(first,second,cityPath,25,false,true)
assert(zip.bReturnToStart and grants==3,'the zipline works independently before the remote unlocks')
sourceItem=source
story:update(first,second,cityPath,26,false,true)
assert(grants==4 and secondItem==borrowed and zip.bReturnToStart,'P2 can use its own remote after the story pickup')
story:update(first,second,cityPath,27,false,false)
assert(removals==3 and destroyed==3 and not secondItem and zip.bReturnToStart,
 'the temporary remote disappears in Six mode while the zipline stays available')
story:reset()
StaticFindObject,FindAllOf,FName=oldFind,oldList,oldName
print('PASS: native zipline return, occupied/repeated reset guards, reciprocal cafeteria escort and cleanup.')
print('PASS: independent flashlight and remote, story unlock, pause, checkpoint and exact equipment ownership.')
