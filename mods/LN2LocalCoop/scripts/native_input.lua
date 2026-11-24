-- Small C extension for Helios inputs not exposed as reflected UFunctions.
local M={};M.__index=M
function M.new(root,live,log)
 local self=setmetatable({live=live,log=log},M)
 for _,filename in ipairs({'ln2_native_29.dll'}) do
  local ok,api=pcall(function()
   local loader,err=package.loadlib(root..filename,'luaopen_ln2_native')
   assert(loader,err)
   local module=loader()
   assert(type(module)=='table','Adaptador nativo incompatible')
   return module
  end)
  if ok then
   self.api=api
   log('Adaptador nativo cargado: '..api.version)
   break
  end
  log('Adaptador '..filename..' no disponible: '..tostring(api))
 end
 return self
end
function M:bind(second,first)
 if not self.api then return false end
 self:vent(false)
 self:cage()
 local ok,err=pcall(self.api.bind,second:GetAddress(),second.Player:GetAddress(),second.Pawn:GetAddress(),first:GetAddress(),first.Pawn:GetAddress())
 if not ok then
  if tostring(err):find('P2 native input is not linked to its own chalkboard',1,true)then return false end
  error(err)
 end
 self.pc,self.pawn=second,second.Pawn
 self.ventDrag=nil
 return true
end
function M:ready()
 return self.api and self.live(self.pc) and self.live(self.pawn)
  and self.live(self.pc.Pawn) and self.pc.Pawn:GetAddress()==self.pawn:GetAddress()
  and self.live(self.pawn.Controller) and self.pawn.Controller:GetAddress()==self.pc:GetAddress()
end
function M:crouch(held)
 if self:ready() then self.api.crouch(held and 1 or 0) end
end
function M:sixCrouch(animator,held)
 if not (self.api and self.api.six_crouch and self.live(animator)) then return end
 local pawn=animator.mPawnSelf
 if self.live(pawn) then self.api.six_crouch(pawn:GetAddress(),animator:GetAddress(),held and 1 or 0) end
end
function M:jump(held,wasHeld)
 if not self:ready() or not self.api.jump then return false end
 if held~=(wasHeld or false) then self.api.jump(held and 1 or 0) end
 return true
end
local ventClass='/Game/GameplayLogic/Draggable/PP_PullOpenVent.PP_PullOpenVent_C'
local cageGraph='/Game/Levels/Wilderness/SubLevels/LVL_1_061_TutorialPullPush.LVL_1_061_TutorialPullPush_C:ExecuteUbergraph_LVL_1_061_TutorialPullPush'
local playerLookup='/Script/Helios.OverseerBlueprintLibrary:GetHeliosPlayerPawn'
function M:vent(held)
 if not self.api or not self.api.vent or self.ventFailed then return end
 local ok,err=pcall(function()
  local target
  if held and self:ready() then
   if not self.live(self.ventDrag) then
    local class=StaticFindObject('/Script/Helios.PlayerDragInterface')
    if self.live(class) then self.ventDrag=self.pawn:GetComponentByClass(class) end
   end
   local helper=self.live(self.ventDrag) and self.ventDrag.mGrabbedGrabHelper or nil
   if self.live(helper) then
    local actor=helper:GetOwner()
    if self.live(actor) and actor:GetClass():GetFullName()=='BlueprintGeneratedClass '..ventClass then
     target=actor:GetAddress()
    end
   end
  end
  if target==self.ventTarget then return end
  if target then
   local lookup=StaticFindObject(playerLookup)
   local graph=StaticFindObject(ventClass..':ExecuteUbergraph_PP_PullOpenVent')
   assert(self.live(lookup) and self.live(graph),'Script de la rejilla no disponible')
   self.api.vent(lookup:GetAddress(),graph:GetAddress(),target)
   self.log('P2 sujeto a la rejilla del tunel')
  else
   local reads=self.api.vent(0,0,0)
   self.log('La rejilla leyo a P2 '..tostring(reads)..' veces')
  end
  self.ventTarget=target
 end)
 if not ok then
  pcall(self.api.vent,0,0,0)
  self.ventTarget=nil;self.ventFailed=true
  self.log('Interaccion de la rejilla: '..tostring(err))
 end
end
function M:cage(now)
 if not self.api or not self.api.cage then return end
 if now and self.live(self.cageGraph) then return end
 if self.cageGraph then
  local reads=self.api.cage(0,0)
  self.cageGraph=nil
  if reads>0 then self.log('La trampa de jaula eligio a P2 '..reads..' veces') end
 end
 if not now then self.cageScanAt=nil;return end
 if not self:ready() then return end
 if self.cageScanAt and now>=self.cageScanAt and now-self.cageScanAt<0.25 then return end
 self.cageScanAt=now
 local graph=StaticFindObject(cageGraph)
 if not self.live(graph) then return end
 local lookup=StaticFindObject(playerLookup)
 if not self.live(lookup) then return end
 local ok,err=pcall(self.api.cage,lookup:GetAddress(),graph:GetAddress())
 if ok then
  self.cageGraph=graph
  self.cageError=nil
  self.log('Trampa de jaula preparada para P2')
 elseif self.cageError~=err then
  -- Streaming can expose the UFunction before its bytecode is ready.
  self.cageError=err
  self.log('Enlace de la jaula pendiente: '..tostring(err))
 end
end
function M:move(x,y)
 if self:ready() then
  local length=math.sqrt(x*x+y*y)
  if length>1 then x,y=x/length,y/length end
  local direction=self.direction or {X=0,Y=0}
  self.api.raw_move(x,y,direction.X,direction.Y)
 end
end
function M:foreground()
 return not self.api or not self.api.foreground or self.api.foreground()
end
function M:use(held)
 if not self:ready() then return end
 if held then
  local pickupInterface=self.pawn:GetPlayerPickupInterface()
  if self.live(pickupInterface) then
   local pickup=pickupInterface:GetCurrentlyHeldPickup()
   if self.live(pickup) and pickup.mCanThrow then
    local holder=pickup:GetHolderIfHeld()
    if self.live(holder) and holder:GetAddress()==self.pawn:GetAddress() and pickup:TryThrow() then return end
   end
  end
 end
 self.api.use_item(held and 1 or 0)
end
function M:gadget(held)
 if not self:ready() or not self.api.gadget then return end
 if not held then self.api.gadget(0);return end
 local inventory=self.pawn:GetInventoryComponent()
 if not self.live(inventory)then return end
 -- The second native equipment input also sends the remote-control signal.
 if inventory:HasInventoryItem(3) or inventory:HasInventoryItem(2) then self.api.gadget(2)
 elseif inventory:HasInventoryItem(1) then self.api.gadget(1) end
end
function M:routeActor(address,target)
 if self.api and self.api.route_actor then
  local ok,err=pcall(self.api.route_actor,address,target and 1 or 0)
  if not ok then self.log('Redireccion de evento (actor): '..tostring(err)) end
  return ok
 end
 return false
end
function M:routeClear()
 if self.api and self.api.route_clear then pcall(self.api.route_clear) end
end
function M:routeActive(on)
 if not self.api or not self.api.route_active then return false end
 if on then
  local lookup=StaticFindObject(playerLookup)
  if not self.live(lookup) then self.log('Redireccion de eventos: no se encontro el getter del jugador');return false end
  local ok,err=pcall(self.api.route_active,1,lookup:GetAddress())
  if not ok then
   if err~=self.routeError then self.log('Redireccion de eventos: '..tostring(err)) end
   self.routeError=err
   return false
  end
  self.routeError=nil
  return true
 end
 pcall(self.api.route_active,0)
 self.routeEnabled=false
 return false
end
-- Rule 1: lookups from a script whose frame names only P2 return P2.
-- Returns the number of lookups resolved this way, or nil without support.
function M:routeFrames(on)
 if not self.api or not self.api.route_frames then return nil end
 local ok,reads=pcall(self.api.route_frames,on and 1 or 0)
 if ok then return reads end
 if reads~=self.frameError then self.log('Eventos por contexto: '..tostring(reads)) end
 self.frameError=reads
end
function M:weaponHitRoutes()
 if self.api and self.api.route_hit_reads then return self.api.route_hit_reads() end
end
function M:routeMusicBox(on)
 if self.api and self.api.route_music_box then
  local ok,reads=pcall(self.api.route_music_box,on and 1 or 0)
  if ok then return reads end
  if reads~=self.boxRouteError then self.log('Redireccion de la caja musical: '..tostring(reads)) end
  self.boxRouteError=reads
 end
end
function M:subjectObserve(on)
 if not self.api or not self.api.subject_observe then return false end
 local ok,err
 if on then
  local lookup=StaticFindObject(playerLookup)
  if not self.live(lookup) then return false end
  ok,err=pcall(self.api.subject_observe,1,lookup:GetAddress())
 else
  ok,err=pcall(self.api.subject_observe,0)
 end
 if not ok and err~=self.subjectError then self.log('Sujeto de eventos: '..tostring(err)) end
 self.subjectError=not ok and err or nil
 return ok and on
end
function M:subjectGrabs(first,second)
 if self.api and self.api.subject_grabs then pcall(self.api.subject_grabs,first,second) end
end
function M:subjectNext()
 if not self.api or not self.api.subject_next then return end
 local ok,entry=pcall(self.api.subject_next)
 if ok then return entry end
end
function M:subjectStats()
 if not self.api or not self.api.subject_stats then return 0,0 end
 local ok,count,dropped=pcall(self.api.subject_stats)
 if ok then return count,dropped end
 return 0,0
end
function M:schoolEscort(pawn,observers)
 if not self.api or not self.api.school_escort then return false end
 local ok,err
 if pawn then ok,err=pcall(self.api.school_escort,pawn,table.unpack(observers,1,math.min(#observers,48)))
 else ok,err=pcall(self.api.school_escort,0) end
 if not ok and self.escortError~=err then self.log('Cafeteria: '..tostring(err)) end
 self.escortError=not ok and err or nil
 return ok
end
function M:schoolEscortReads()
 if self.api and self.api.school_escort_reads then return self.api.school_escort_reads() end
end
return M
