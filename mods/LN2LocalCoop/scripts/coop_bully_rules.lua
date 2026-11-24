-- School bullies with P2 events on. Their scripts only ask the game for P1:
-- * a bully's push behaviour answers P2 while P2 is the closer player to that
--   bully, so pushing P2 no longer knocks P1 over;
-- * the narrow gap that breaks the bully head answers P2 while P2, and not
--   P1, squeezes through it, so P2's pass breaks P2's head and not P1's.
local Rules={};Rules.__index=Rules
local school='/Game/Levels/School/PLVL_School.'
local sublevels={'/Game/Levels/School/SubLevels/LVL_2_280_Cafeteria.LVL_2_280_Cafeteria:PersistentLevel.',
 '/Game/Levels/School/SubLevels/LVL_2_285_SchoolHallway.LVL_2_285_SchoolHallway:PersistentLevel.'}
local pushRadius=400
local gapRadius=900
local gapGrace=4
local scanEvery=2

local function paths(names)
 local list={}
 for _,level in ipairs(sublevels) do
  for _,name in ipairs(names) do list[#list+1]=level..name end
 end
 return list
end
local pushNames={'BP_BullyPushBehaviour'}
for i=1,20 do pushNames[#pushNames+1]='BP_BullyPushBehaviour'..i end
local gapNames={'BP_SqueezeGap_PlayerLosesBullyHead'}
for i=1,6 do gapNames[#gapNames+1]='BP_SqueezeGap_PlayerLosesBullyHead_'..i end
local pushPaths,gapPaths=paths(pushNames),paths(gapNames)

function Rules.new(api)
 return setmetatable({api=api,errors={},routed={},gaps={},bullyProperty={}},Rules)
end

function Rules:find(class,known,first)
 local api=self.api
 local found,seen={},{}
 local ok,list=pcall(FindAllOf,class)
 for _,actor in ipairs(ok and list or {}) do
  if api.world(actor,first) or self:inWorld(actor,first) then
   found[#found+1]=actor;seen[actor:GetAddress()]=true
  end
 end
 for _,path in ipairs(known) do
  local actor=StaticFindObject(path)
  if api.live(actor) and not seen[actor:GetAddress()] and (api.world(actor,first) or self:inWorld(actor,first)) then
   found[#found+1]=actor;seen[actor:GetAddress()]=true
  end
 end
 return found
end

-- Sublevel actors report their sublevel's world; their level's OwningWorld is the players'.
function Rules:inWorld(actor,first)
 local ok,owner=pcall(function()return actor:GetOuter().OwningWorld end)
 return ok and self.api.same(owner,first:GetWorld()) or false
end

local function distance(a,b)
 return math.sqrt((a.X-b.X)^2+(a.Y-b.Y)^2+(a.Z-b.Z)^2)
end

function Rules:animation(pawn)
 local ok,name=pcall(function()
  local control=pawn.mAnimationControlComponent
  if not self.api.live(control) or not control:IsPlayingOverrideAnimation() then return '' end
  local asset=control.mCurrentAnimStateAsset
  return self.api.live(asset) and asset:GetFullName() or ''
 end)
 return ok and name or ''
end

-- The behaviour actor keeps its bully in one of its variables. Find which,
-- once per class, and log the variables so a wrong guess can be corrected.
function Rules:bullyOf(behaviour)
 local api=self.api
 local class=behaviour:GetClass()
 local key=class:GetAddress()
 local name=self.bullyProperty[key]
 if name==nil then
  name=false
  local lines={}
  pcall(function()class:ForEachProperty(function(property)
   local prop=property:GetFName():ToString()
   local kind=property:GetClass():GetFName():ToString()
   local value=behaviour[prop]
   local shown=tostring(value)
   if kind=='ObjectProperty' and api.live(value) then
    shown=value:GetFullName()
    if not name and shown:find('Bully',1,true) and shown:find('Pawn',1,true) then name=prop end
   end
   lines[#lines+1]=prop..'='..shown
  end)end)
  self.bullyProperty[key]=name
  api.log('Empujones: variables del comportamiento: '..table.concat(lines,'; '))
  api.log('Empujones: '..(name and ('el abuson esta en '..name) or 'sin referencia al abuson; se usa la posicion del comportamiento'))
 end
 local bully=name and behaviour[name] or nil
 if api.live(bully) then return bully end
 return behaviour
end

function Rules:route(actor,on,label)
 local api=self.api
 local address=actor:GetAddress()
 if on then
  api.native:routeActor(address,true)
  if not self.routed[address] then api.log(label..': '..actor:GetFullName()..' responde a P2') end
  self.routed[address]=true
 elseif self.routed[address] then
  api.native:routeActor(address,false)
  self.routed[address]=nil
  api.log(label..': '..actor:GetFullName()..' vuelve a P1')
 end
end

function Rules:pushes(first,second,now)
 if not self.pushScan or now<self.pushScan or now-self.pushScan>=scanEvery then
  self.pushScan=now
  self.behaviours=self:find('BP_BullyPushBehaviour_C',pushPaths,first)
 end
 local p1,p2=first:K2_GetActorLocation(),second:K2_GetActorLocation()
 for _,behaviour in ipairs(self.behaviours or {}) do
  if self.api.live(behaviour) then
   local at=self:bullyOf(behaviour):K2_GetActorLocation()
   local d1,d2=distance(at,p1),distance(at,p2)
   self:route(behaviour,d2<d1 and d2<=pushRadius,'Empujones')
  end
 end
end

function Rules:gap(first,second,now)
 local api=self.api
 local secondSqueezes=self:animation(second):find('Squeeze',1,true)~=nil
 local firstSqueezes=self:animation(first):find('Squeeze',1,true)~=nil
 if secondSqueezes and not firstSqueezes then
  if not self.gapUntil then
   local p2=second:K2_GetActorLocation()
   self.gapActors={}
   for _,gap in ipairs(self:find('BP_SqueezeGap_PlayerLosesBullyHead_C',gapPaths,first)) do
    if distance(gap:K2_GetActorLocation(),p2)<=gapRadius then self.gapActors[#self.gapActors+1]=gap end
   end
  end
  self.gapUntil=now+gapGrace
 elseif firstSqueezes then
  self.gapUntil=nil
 end
 local active=self.gapUntil and now<=self.gapUntil
 for _,gap in ipairs(self.gapActors or {}) do
  if api.live(gap) then self:route(gap,active,'Pasillo estrecho') end
 end
 if not active then self.gapUntil,self.gapActors=nil,nil end
end

function Rules:clear()
 local api=self.api
 for address in pairs(self.routed) do pcall(api.native.routeActor,api.native,address,false) end
 self.routed={}
 self.gapUntil,self.gapActors,self.behaviours,self.pushScan=nil,nil,nil,nil
end

function Rules:reset()
 local ok,err=pcall(self.clear,self)
 if not ok then self.api.log('Reglas de abusones: '..tostring(err)) end
end

function Rules:step(first,second,path,now,events)
 if not events or not path or not path:find(school,1,true) then
  if next(self.routed) or self.gapActors then self:clear() end
  return
 end
 self:gap(first,second,now)
 self:pushes(first,second,now)
end

function Rules:update(first,second,path,now,events)
 local ok,err=pcall(self.step,self,first,second,path,now,events)
 if not ok and self.errors.update~=err then
  self.errors.update=err
  self.api.log('Reglas de abusones: '..tostring(err))
 end
end

return Rules
