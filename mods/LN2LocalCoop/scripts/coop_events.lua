-- A grab applies only to the object owned by its active grab interface.
-- Weapon hits use the instigator supplied by Helios during dispatch.
local E={};E.__index=E
local grabTypes={
 {'/Script/Helios.PlayerHangableInterface','mGrabbedHangable'},
 {'/Script/Helios.PlayerDragInterface','mGrabbedGrabHelper'},
 {'/Script/Helios.PlayerLeverGrabInterface','mGrabbedGrabHelper',true},
 {'/Script/Helios.PlayerPickupInterface'},
}
local tower='/Game/Levels/Transmission/PLVL_Transmission.'
local lastAxe='/Game/Levels/Transmission/SubLevels/LVL_6_000_Transmission_CLOs.LVL_6_000_Transmission_CLOs:PersistentLevel.BP_ItemWeapon_2'
local function atFinalBox(pawn)
 if not pawn:GetFullName():find(tower,1,true) then return end
 local at=pawn:K2_GetActorLocation()
 if at.Z>=27900 and at.Z<=28500 and at.Y>=-400 and at.Y<=1800 and at.X>=-1250 and at.X<=900 then
  return at
 end
end
local function isLastAxe(actor)
 return actor and actor:GetFullName():sub(-#lastAxe)==lastAxe
end
function E.new(api)
 return setmetatable({api=api,enabled=false,classes={}},E)
end
function E:activeGrab(pawn)
 local api=self.api
 if not api.live(pawn) or not api.live(pawn.Mesh) then return end
 local anim=pawn.Mesh:GetAnimInstance()
 local iface=api.live(anim) and anim.mCurrentlyActiveGrabInterface or nil
 if api.live(iface) and api.same(iface.mControlledPawn,pawn) then return iface end
end
function E:matches(iface,index)
 local class=self.classes[index]
 if not self.api.live(class) then
  class=StaticFindObject(grabTypes[index][1])
  self.classes[index]=class
 end
 return iface and self.api.live(class) and iface:IsA(class)
end
function E:heldActor(pawn,iface)
 local api=self.api
 if not api.live(iface) then return end
 local item=iface:GetCurrentlyHeldPickup()
 if api.live(item) and api.same(item:GetHolderIfHeld(),pawn) then
  local actor=item:GetOwner()
  if api.world(actor,pawn) then return actor end
 end
end
function E:grabTarget(pawn,iface)
 if not iface then return end
 local api=self.api
 for index,kind in ipairs(grabTypes) do
  if self:matches(iface,index) then
   if kind[3] and not atFinalBox(pawn) then return end
   if not kind[2] then return self:heldActor(pawn,iface) end
   local component=iface[kind[2]]
   if api.live(component) then
    local actor=component:GetOwner()
    if api.world(actor,pawn) then return actor end
   end
   return
  end
 end
end
-- Any object a pawn holds through its active grab interface, for diagnostics.
function E:heldObject(pawn)
 local api=self.api
 local iface=self:activeGrab(pawn)
 if not iface then return end
 for _,field in ipairs({'mGrabbedHangable','mGrabbedGrabHelper'}) do
  local ok,component=pcall(function()return iface[field]end)
  if ok and api.live(component) then
   local actor=component:GetOwner()
   if api.world(actor,pawn) then return actor end
  end
 end
 local ok,actor=pcall(self.heldActor,self,pawn,iface)
 if ok then return actor end
end
-- A key lock is used through a lever grab with no grabbed component, and the
-- lock's Blueprint then asks for the player. As in the first version of P2
-- events, every lookup answers P2 while that grab lasts, through the short
-- window the DLL renews each tick (shared with the final music box). Only a
-- lever-type grab by P2 (locks and levers) opens it, never while P1 works one too.
function E:lockGrab(pawn,iface,primaryIface)
 return iface and self:matches(iface,3) and not atFinalBox(pawn)
  and not self:grabTarget(pawn,iface)
  and not (primaryIface and self:matches(primaryIface,3))
end
function E:lockRoute(pawn,iface,primaryIface)
 local api=self.api
 if not self:lockGrab(pawn,iface,primaryIface) then
  if self.lockHeld and not self.box then api.native:routeMusicBox(false) end
  if self.lockHeld then
   api.log('Eventos P2: candado soltado; '..math.max(0,(self.lockReads or 0)-(self.lockBase or 0))..' consultas respondidas con P2')
  end
  self.lockHeld,self.lockBase,self.lockReads=nil,nil,nil
  return
 end
 local reads=api.native:routeMusicBox(true)
 if not self.lockHeld then
  self.lockHeld,self.lockBase=true,reads
  api.log('Eventos P2: P2 usa un candado; el juego le responde a P2')
 end
 self.lockReads=reads
end
function E:boxInteraction(pc,second,firstGrab,secondGrab,target,now,hit)
 local api=self.api
 local first=pc and pc.Pawn
 local at=now and api.world(first,second) and atFinalBox(second)
 if not at or (hit and hit.arrivedAt) then self.swingUntil=nil;return end
 if isLastAxe(self:heldActor(first,first:GetPlayerPickupInterface())) or self:matches(firstGrab,3) then
  self.swingUntil=nil
  return
 end
 local input=api.input(pc)
 local axe=isLastAxe(target) or isLastAxe(self:heldActor(second,second:GetPlayerPickupInterface()))
 if axe and input.use then self.swingUntil=now+3 end
 if self.swingUntil and (now<=self.swingUntil or (hit and hit.fromSecond
   and not hit.arrivedAt and now-hit.startedAt<25 and (not hit.endedAt or now-hit.endedAt<=2))) then
  return 'golpe'
 end
 self.swingUntil=nil
 local near=(at.X+493)^2+(at.Y-994)^2+(at.Z-28215)^2<=280^2
 if not axe and ((self:matches(secondGrab,3) and not target)
   or (near and input.grab and not secondGrab and not api.primaryGrab(first))) then
  return 'recogida'
 end
end
-- Lookups the DLL resolved to P2 because the asking script was handling P2.
function E:frameRule(clock)
 local reads=self.api.native.routeFrames and self.api.native:routeFrames(true)
 if not reads then return end
 local base=self.frameBase or reads
 self.frameBase=base
 local total=reads-base
 if total>(self.frameLogged or 0) and (not self.frameAt or clock-self.frameAt>=5) then
  self.api.log('Eventos P2: '..total..' consultas resueltas por contexto a P2')
  self.frameLogged,self.frameAt=total,clock
 end
 self.frameTotal=total
end
function E:interact(now,hit,clock)
 if not self.enabled then return end
 local api=self.api
 self:frameRule(clock or now or 0)
 local second=api.driver.pawn
 local pc=api.p1()
 local first=pc and pc.Pawn
 local firstGrab,secondGrab=self:activeGrab(first),self:activeGrab(second)
 local target=self:grabTarget(second,secondGrab)
 self:lockRoute(second,secondGrab,firstGrab)
 local primary=self:grabTarget(first,firstGrab)
 local box=self:boxInteraction(pc,second,firstGrab,secondGrab,target,now,hit)
 if box or self.box then
  local reads=api.native:routeMusicBox(box~=nil)
  if reads and self.boxReads and reads>self.boxReads and not self.boxLogged then
   api.log('Caja musical: script redirigido a P2 durante '..self.box)
   self.boxLogged=true
  end
  if self.box~=box then self.boxLogged=false end
  self.box,self.boxReads=box,reads
 end
 local address=target and not api.same(target,primary) and target:GetAddress() or nil
 if self.actor==address then return end
 -- Only this object's route: lock routes stay in place.
 if self.actor then api.native:routeActor(self.actor,false) end
 self.actor=nil
 if address and api.native:routeActor(address,true) then
  self.actor=address
  api.log('Eventos P2: consultas de '..target:GetFullName()..' dirigidas a P2')
 end
end
function E:setEnabled(on)
 if on==self.enabled then return end
 if on then
  self.enabled=self.api.native:routeActive(true)
  if self.enabled and self.api.native.routeFrames then self.frameBase=self.api.native:routeFrames(true) end
 else
  self.enabled=false
  self.actor=nil
  self.lockHeld,self.lockBase,self.lockReads=nil,nil,nil
  if self.api.native.routeFrames then self.api.native:routeFrames(false) end
  self.frameBase,self.frameLogged,self.frameAt=nil,nil,nil
  self.box,self.swingUntil,self.boxReads,self.boxLogged=nil,nil,nil,nil
  self.api.native:routeActive(false)
 end
end
function E:mark()
 local mode=self.actor and 'objeto sujetado por P2' or 'esperando interaccion'
 self.api.log('Eventos P2: '..(self.enabled and mode or 'desactivado'))
 local hits=self.api.native:weaponHitRoutes()
 if hits then self.api.log('Eventos P2: consultas de golpe atribuidas al atacante P2: '..hits) end
 if self.box then self.api.log('Eventos P2: caja musical ('..self.box..')') end
 if self.enabled then self.api.log('Eventos P2: consultas resueltas por contexto a P2: '..(self.frameTotal or 0)) end
end
return E
