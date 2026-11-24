-- School bully head: the level places one head (BP_BullyHead_Pickup) and its
-- script only asks the game for P1. With P2 events on, a second head is
-- spawned beside it and every player lookup of that copy answers P2, so P2
-- picks it up and wears it on its own. The level's head stays P1's.
local Head={};Head.__index=Head
local school='/Game/Levels/School/PLVL_School.'
local headPath='/Game/Levels/School/SubLevels/LVL_2_000_BullyMaskPlace.LVL_2_000_BullyMaskPlace:PersistentLevel.BP_BullyHead_Pickup'
local spacing=70
local maxSpawns=3
local retry=5
local axisHook='/Script/Engine.Actor:GetInputAxisValue'

function Head.new(api)
 return setmetatable({api=api,errors={},spawns=0,axes={}},Head)
end

function Head:parent(actor)
 local ok,parent=pcall(function()return actor:GetAttachParentActor()end)
 if ok and self.api.live(parent) then return parent end
end

-- An actor of a streamed sublevel can report the sublevel's own world through
-- its outers. Its level's OwningWorld is the world the players are in.
function Head:inWorld(actor,first)
 local api=self.api
 if api.world(actor,first) then return true end
 local ok,owner=pcall(function()return actor:GetOuter().OwningWorld end)
 return ok and api.same(owner,first:GetWorld()) or false
end

function Head:worldName(actor)
 local ok,name=pcall(function()return actor:GetWorld():GetFullName()end)
 return ok and tostring(name) or '?'
end

function Head:propertyName(property)
 local ok,name=pcall(function()return property:GetFName():ToString()end)
 return ok and name or nil
end

function Head:propertyType(property)
 local ok,kind=pcall(function()return property:GetClass():GetFName():ToString()end)
 return ok and kind or '?'
end

local scalar={BoolProperty=true,FloatProperty=true,DoubleProperty=true,IntProperty=true,
 ByteProperty=true,EnumProperty=true,NameProperty=true,Int64Property=true}
local reference={ObjectProperty=true,WeakObjectProperty=true}

-- Placed actors carry level settings in their Blueprint variables. Copy the
-- simple ones and references to other actors; never the original's own
-- components, which would make the copy drive the level's head.
function Head:copyState(source,copy)
 local api=self.api
 local copied,skipped,lines={},{},{}
 local ok,err=pcall(function()
  source:GetClass():ForEachProperty(function(property)
   local name=self:propertyName(property)
   if not name then return end
   local kind=self:propertyType(property)
   local value=source[name]
   local shown=tostring(value)
   if reference[kind] then
    local live=api.live(value)
    shown=live and value:GetFullName() or 'nada'
    local owned=live and (api.same(value,source) or api.same(value:GetOuter(),source))
    if live and not owned and pcall(function()copy[name]=value end) then copied[#copied+1]=name
    else skipped[#skipped+1]=name end
   elseif scalar[kind] then
    if pcall(function()copy[name]=value end) then copied[#copied+1]=name
    else skipped[#skipped+1]=name end
   else
    skipped[#skipped+1]=name
   end
   lines[#lines+1]=name..' ('..kind..')='..shown
  end)
 end)
 if not ok then api.log('Cabeza de P2: no se pudo leer la cabeza original: '..tostring(err)) end
 if not self.described then
  self.described=true
  api.log('Cabeza de P2: variables de la cabeza original: '..(#lines>0 and table.concat(lines,'; ') or 'ninguna'))
 end
 api.log('Cabeza de P2: copiadas '..#copied..' variables'..(#skipped>0 and ('; sin copiar: '..table.concat(skipped,', ')) or ''))
end

function Head:place(source,second)
 local at=source:K2_GetActorLocation()
 local to=second:K2_GetActorLocation()
 local dx,dy=to.X-at.X,to.Y-at.Y
 local length=math.sqrt(dx*dx+dy*dy)
 if length<1 then dx,dy,length=1,0,1 end
 return {X=at.X+dx/length*spacing,Y=at.Y+dy/length*spacing,Z=at.Z}
end

function Head:spawn(source,first,second,now,worn)
 local api=self.api
 if self.spawnedAt and now>=self.spawnedAt and now-self.spawnedAt<retry then return end
 if self.spawns>=maxSpawns then
  if not self.exhausted then
   self.exhausted=true
   api.log('Cabeza de P2: el juego quito la copia '..maxSpawns..' veces; no se vuelve a crear')
  end
  return
 end
 self.spawnedAt=now
 self.spawns=self.spawns+1
 local at=worn and second:K2_GetActorLocation() or self:place(source,second)
 local copy=first:GetWorld():SpawnActor(source:GetClass(),at,source:K2_GetActorRotation())
 if not api.world(copy,first) then
  api.log('Cabeza de P2: el juego no creo la copia')
  return
 end
 self.copy=copy
 self.copyAddress=copy:GetAddress()
 self:installAxis()
 self:copyState(source,copy)
 if not worn then
  api.log(string.format('Cabeza de P2: copia creada junto a la del nivel (%.0f, %.0f, %.0f)',at.X,at.Y,at.Z))
  return
 end
 -- After a checkpoint P1 already wears the level's head. The head's reload
 -- event puts a worn head back on its player; with the copy answering P2,
 -- that player is P2.
 api.native:routeActor(self.copyAddress,true)
 local ok,err=pcall(function()copy:WorldReloaded()end)
 api.log('Cabeza de P2: P1 ya lleva la cabeza; copia creada para ponersela a P2'..(ok and '' or (' (fallo: '..tostring(err)..')')))
end

-- The level's head is on P1 after a checkpoint: P2 gets its head back too.
function Head:wornByFirst(source,first)
 return self.api.same(self:parent(source),first) and source.bPickedUp==true and source.CurrentMaskState==1
end

-- The head asks its own input component for the grab axis, and that component
-- listens to P1's controller. For the copy, the axis reports P2's grab instead,
-- so P1's grab no longer picks up P2's head and P2's grab does.
function Head:axis(context,name)
 local address=self.copyAddress
 if not address then return end
 local actor=context:get()
 if not actor or actor:GetAddress()~=address then return end
 local ok,axis=pcall(function()return name:get():ToString()end)
 axis=ok and axis or '?'
 if not self.axes[axis] then
  self.axes[axis]=true
  self.api.log('Cabeza de P2: el eje '..axis..' de la copia responde al agarre de P2')
 end
 return self.grabbing and 1.0 or 0.0
end

function Head:installAxis()
 if self.axisInstalled~=nil then return self.axisInstalled end
 local ok,err=pcall(RegisterHook,axisHook,function()end,function(context,name)
  local worked,value=pcall(self.axis,self,context,name)
  if worked then return value end
  if self.errors.axis~=value then
   self.errors.axis=value
   self.api.log('Cabeza de P2: eje de agarre: '..tostring(value))
  end
 end)
 self.axisInstalled=ok
 if not ok then self.api.log('Cabeza de P2: no se pudo enlazar el eje de agarre: '..tostring(err)) end
 return ok
end

function Head:worn(second)
 local copy=self.copy
 return self.api.live(copy) and self.api.same(self:parent(copy),second)
end

-- A worn copy stays unless forced. Deaths force it: after the checkpoint the
-- copy's reload event would otherwise put it on P1.
function Head:release(force)
 local api=self.api
 local copy=self.copy
 local keep=not force and self:worn(self.second)
 if api.live(copy) and not keep then
  pcall(function()copy:K2_DestroyActor()end)
  api.log('Cabeza de P2: copia retirada')
 end
 if not keep then self.copy,self.copyAddress=nil,nil end
 self.holder=nil
end

function Head:reset()
 self.wornGiven=nil
 local ok,err=pcall(self.release,self,true)
 if not ok then self.api.log('Cabeza de P2: '..tostring(err)) end
 self.source,self.spawns,self.spawnedAt,self.exhausted=nil,0,nil,nil
 self.firstHolder=nil
end

function Head:track(first,second)
 local api=self.api
 local parent=self:parent(self.copy)
 local holder=parent and (api.same(parent,second) and 'P2' or api.same(parent,first) and 'P1' or 'otro') or nil
 if holder~=self.holder then
  self.holder=holder
  api.log('Cabeza de P2: '..(holder and ('la copia la tiene '..holder) or 'la copia esta libre'))
 end
 if holder=='P1' then
  -- P1 already wears the level's head; a second one on P1 is never right.
  self:release(true)
 end
end

-- Playing as Six, the pickup animation shows Mono's own mask coming off.
-- Keep that mask, and the one the head spawns for the animation, hidden.
function Head:hideMasks(second)
 local api=self.api
 if not (api.six and api.six()) then return end
 local copy=self.copy
 if not api.live(copy) then return end
 local spawned=copy.SpawnedMask
 if api.live(spawned) and not spawned.bHidden then
  spawned:SetActorHiddenInGame(true)
  if not self.maskHidden then api.log('Cabeza de P2: mascara de Mono oculta en modo Six') end
  self.maskHidden=true
 end
 if copy.bPickedUp==true and api.hideMask then api.hideMask() end
end

-- One-off map of the head's script: each function and the calls it makes.
function Head:describeFunctions(source)
 if self.functionsDescribed then return end
 self.functionsDescribed=true
 local entries={}
 local ok,err=pcall(function()
  source:GetClass():ForEachFunction(function(fn)
   local name=self:propertyName(fn) or '?'
   local calls={}
   pcall(function()fn:ForEachProperty(function(property)
    local local_=self:propertyName(property)
    local call=local_ and local_:match('^CallFunc_(.-)_ReturnValue')
    if call then calls[#calls+1]=call end
   end)end)
   entries[#entries+1]=name..(#calls>0 and ('['..table.concat(calls,',')..']') or '')
  end)
 end)
 if not ok then entries[#entries+1]='error: '..tostring(err) end
 self.api.log('Cabeza de P2: funciones de la cabeza: '..table.concat(entries,'; '))
end

function Head:stateOf(actor)
 local ok,text=pcall(function()
  return 'estado='..tostring(actor.CurrentMaskState)..' recogida='..tostring(actor.bPickedUp)
 end)
 return ok and text or '?'
end

-- Report state changes of both heads, so P2's pickup can be compared with P1's.
function Head:watchState(source)
 local api=self.api
 local original=self:stateOf(source)
 if original~=self.originalState then
  self.originalState=original
  api.log('Cabeza de P2: cabeza del nivel '..original)
 end
 if api.live(self.copy) then
  local copied=self:stateOf(self.copy)
  if copied~=self.copyLabel then
   self.copyLabel=copied
   api.log('Cabeza de P2: copia '..copied)
  end
 end
end

-- The level moves its head through states with world events the copy never
-- receives. While neither head is in a player's hands, the copy follows the
-- state of the level's head.
function Head:followState(source,first,second)
 local api=self.api
 local copy=self.copy
 if not api.live(copy) or copy.bPickedUp==true or self:parent(copy) then return end
 local parent=self:parent(source)
 if source.bPickedUp==true or (parent and (api.same(parent,first) or api.same(parent,second))) then return end
 local state=source.CurrentMaskState
 if type(state)=='number' and copy.CurrentMaskState~=state then
  copy.CurrentMaskState=state
  api.log('Cabeza de P2: la copia sigue el estado '..state..' de la cabeza del nivel')
 end
end

-- Logs why no copy exists yet, once per change, so a missing head can be traced.
function Head:wait(reason)
 if reason==self.reason then return end
 self.reason=reason
 if reason then self.api.log('Cabeza de P2: '..reason) end
end

-- P1 standing at the level's head: logged once per approach, with its state,
-- to tell a missed grab from a head that refuses P1.
function Head:watchFirst(source,first)
 local at,to=source:K2_GetActorLocation(),first:K2_GetActorLocation()
 local distance=math.sqrt((at.X-to.X)^2+(at.Y-to.Y)^2+(at.Z-to.Z)^2)
 local near=distance<=150
 if near and not self.firstNear then
  self.api.log(string.format('Cabeza de P2: P1 junto a la cabeza del nivel (%.0f) %s',distance,self:stateOf(source)))
 end
 self.firstNear=near
end

function Head:step(first,second,path,now,events)
 local api=self.api
 self.second=second
 local input=api.input and api.input()
 self.grabbing=events and input and input.grab==true or false
 self.copyAddress=api.live(self.copy) and self.copy:GetAddress() or nil
 if not path or not path:find(school,1,true) then
  if self.copy or self.source then self:reset() end
  self.reason,self.watching=nil,nil
  return
 end
 if not self.watching then
  self.watching=true
  api.log('Cabeza de P2: vigilando la Escuela')
 end
 local source=StaticFindObject(headPath)
 if not api.live(source) then self:wait('esperando la cabeza del nivel (no cargada)')
 elseif not self:inWorld(source,first) then
  self:wait('la cabeza del nivel esta en otro mundo ('..self:worldName(source)..' frente a '..self:worldName(first)..')')
 end
 if self:inWorld(source,first) then
  local address=source:GetAddress()
  if self.source~=address then
   self.source,self.spawns,self.spawnedAt,self.exhausted=address,0,nil,nil
  end
  local holder=self:parent(source)
  local firstHolder=holder and (api.same(holder,first) and 'P1' or api.same(holder,second) and 'P2' or holder:GetFullName()) or nil
  if firstHolder~=self.firstHolder then
   self.firstHolder=firstHolder
   if firstHolder then api.log('Cabeza de P2: la cabeza del nivel la tiene '..firstHolder) end
  end
  self:describeFunctions(source)
  self:watchState(source)
  self:watchFirst(source,first)
  if not api.live(self.copy) then
   self.copy,self.copyAddress=nil,nil
   local parent=self:parent(source)
   if not events then self:wait('esperando Eventos de P2')
   elseif self:wornByFirst(source,first) and not self.wornGiven then
    self:wait(nil)
    self.wornGiven=true
    self:spawn(source,first,second,now,true)
   elseif source.bHidden then self:wait('la cabeza del nivel esta oculta')
   elseif parent then self:wait('la cabeza del nivel esta sujeta a '..parent:GetFullName())
   else
    self:wait(nil)
    self:spawn(source,first,second,now)
   end
  end
  self:followState(source,first,second)
 elseif self.copy and not self:worn(second) then
  -- The level's head unloaded: a copy P2 left behind goes with it.
  self:release()
 end
 if not api.live(self.copy) then return end
 -- Turning events off clears every native route, so this is set again each tick.
 if events then api.native:routeActor(self.copy:GetAddress(),true) end
 self:track(first,second)
 if api.live(self.copy) then self:hideMasks(second) end
end

function Head:update(first,second,path,now,events)
 local ok,err=pcall(self.step,self,first,second,path,now,events)
 if not ok and self.errors.update~=err then
  self.errors.update=err
  self.api.log('Cabeza de P2: '..tostring(err))
 end
end

function Head:mark()
 local api=self.api
 if not self.source then return end
 local state=api.live(self.copy) and (self.holder and ('la tiene '..self.holder) or 'libre') or 'sin copia'
 api.log('Cabeza de P2: '..state..' (copias creadas '..self.spawns..')')
end

return Head
