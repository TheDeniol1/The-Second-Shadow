-- Cosmetic selection for the owned P2 pawn. Never writes the shared MaskSystem.
local Hats = {}
Hats.__index = Hats

local labels = {
 MASK_PAPERBAG='Bolsa de papel', MASK_FOOTBALL='Balón', MASK_RAINCAP='Gorro de lluvia',
 MASK_MAILMAN='Gorra de cartero', MASK_MOKUJIN='Mokujin', MASK_NEWSBOY='Gorra de periódico',
 MASK_NOME='Nome', MASK_SCOUT='Sombrero de explorador', MASK_STUFFEDTOY='Peluche',
 MASK_THINMAN='Sombrero del Hombre Delgado', MASK_TINCAN='Lata', MASK_WRAPPEDGAUZE='Vendas',
}

function Hats.new(live, same, preferences, log)
 return setmetatable({live=live, same=same, preferences=preferences, log=log,
  revision=0, cursor=1, options={}, hint=''}, Hats)
end

function Hats:system()
 if not self.live(self.maskSystem) then self.maskSystem=FindFirstOf('MaskSystem') end
 return self.maskSystem
end

function Hats:selected()
 return self.preferences.hat or 'follow'
end

function Hats:open(down)
 self.options={{id='follow', label='Usar el mismo sombrero que el jugador 1'}, {id='bare', label='Sin sombrero'}}
 local ok, err=pcall(function()
  local system=self:system()
  if not self.live(system) then return end
  local available={}
  local settings=StaticFindObject('/Script/Helios.Default__MaskProjectSettings')
  if not self.live(settings) then return end
  local catalog=settings.Masks
  for i=1,#catalog do
   local data=catalog[i]
   local name=data.UniqueId:ToString()
   if name~='None' and self.live(data.MaskAsset) and system:IsMaskUnlocked(data.UniqueId) then
    available[#available+1]={id='hat.'..name,label=labels[name:upper()] or name}
   end
  end
  table.sort(available,function(a,b) return a.label<b.label end)
  for _,option in ipairs(available) do self.options[#self.options+1]=option end
 end)
 if not ok then self.log('Catalogo de sombreros: '..tostring(err)) end
 self.cursor=1
 for i,option in ipairs(self.options) do
  if option.id==self:selected() then self.cursor=i; break end
 end
 self.previous={}
 for _,key in ipairs({'Up','Down','Enter','BackSpace'}) do self.previous[key]=down(key) end
 self.hint='Arriba / abajo para elegir. Enter para aplicar.'
 self.revision=self.revision+1
end

function Hats:tick(down)
 local current={}
 for _,key in ipairs({'Up','Down','Enter','BackSpace'}) do current[key]=down(key) end
 local function edge(key) return current[key] and not self.previous[key] end
 local action
 if edge('BackSpace') then action='back'
 elseif edge('Enter') then action='apply'
 elseif edge('Up') then self.cursor=(self.cursor-2)%#self.options+1; self.revision=self.revision+1
 elseif edge('Down') then self.cursor=self.cursor%#self.options+1; self.revision=self.revision+1 end
 self.previous=current
 return action
end

function Hats:component(second,pawn,first)
 if not (self.live(first) and self.live(second) and self.live(pawn) and self.live(second.Player)) then return end
 if second.Player.ControllerId~=1 or self.same(first.Pawn,pawn)
  or not self.same(second.Pawn,pawn) or not self.same(pawn.Controller,second) then return end
 local mask=pawn.MaskComponent
 if self.live(mask) and self.same(mask:GetOwner(),pawn) then return mask end
end

function Hats:child(mask,pawn)
 local child=mask.CurrentMask:Get()
 if self.live(child) then
  assert(self.same(child:GetOwner(),pawn),'El sombrero no pertenece a P2')
  return child
 end
end

function Hats:cleanup()
 if self.live(self.actor) then self.actor:K2_DestroyActor() end
 self.actor=nil
end

function Hats:hideForSix(second,pawn,first)
 self:cleanup()
 local mask=self:component(second,pawn,first)
 if not mask then return end
 local child=self:child(mask,pawn)
 if child and self.live(child.ChildActor) and not child.ChildActor.bHidden then
  child.ChildActor:SetActorHiddenInGame(true)
  self.sixHidden=child.ChildActor
 end
end

function Hats:attach(pawn,mask,class)
 local mesh=pawn.Mesh
 local socket=mask.HeadSocketName
 assert(self.live(mesh) and mesh:DoesSocketExist(socket),'No se encontro el anclaje del sombrero')
 local actor=pawn:GetWorld():SpawnActor(class,pawn:K2_GetActorLocation(),pawn:K2_GetActorRotation())
 assert(self.live(actor),'No se pudo crear el sombrero de P2')
 self.actor=actor
 local ok,err=pcall(function()
  actor:SetOwner(pawn)
  actor:SetActorEnableCollision(false)
  actor:SetActorHiddenInGame(pawn.bHidden)
  local root=actor.RootComponent
  assert(self.live(root) and root:K2_AttachToComponent(mesh,socket,2,2,2,false),'No se pudo fijar el sombrero')
 end)
 if not ok then self:cleanup();error(err) end
end

function Hats:apply(second,pawn,first,id)
 local mask=self:component(second,pawn,first)
 if not mask then return false end
 if not self.same(self.pawn,pawn) then
  self:cleanup()
  self.pawn=pawn
  self.applied=nil
 end
 if id=='follow' and not self.applied then return true end
 if id=='follow' and self.applied=='follow' then return true end

 local child=self:child(mask,pawn)
 if id=='follow' then
  self:cleanup()
  if child then mask:TakeOffMask() end
  pawn:OnMaskOff()
  mask:ChangeMask()
 elseif id=='bare' then
  self:cleanup()
  if child then mask:TakeOffMask() end
  if child or self.applied~=id then pawn:OnMaskOff() end
 else
  local name=id:match('^hat%.(.+)$')
  if not name then return false end
  local system=self:system()
  if not self.live(system) then return false end
  local key=FName(name)
  if not system:IsMaskUnlocked(key) then return false end
  local data=system:GetMaskData(key)
  local class=data.MaskAsset
  if not self.live(class) then return false end

  if child then
   self:cleanup()
   if not self.same(child.ChildActorClass,class) or not self.live(child.ChildActor) then
    child:SetChildActorClass(class)
    assert(self.live(child.ChildActor),'El motor no creo el sombrero de P2')
    pawn:UpdateHairVisibility(data)
   elseif self.applied~=id then
    pawn:UpdateHairVisibility(data)
   end
  else
   if not self.live(self.actor) or not self.same(self.actor:GetClass(),class) then
    self:cleanup()
    self:attach(pawn,mask,class)
    pawn:UpdateHairVisibility(data)
   end
   if self.actor.bHidden~=pawn.bHidden then self.actor:SetActorHiddenInGame(pawn.bHidden) end
  end
 end
 self.applied=id
 return true
end

function Hats:sync(second,pawn,first)
 if self.live(self.sixHidden) then self.sixHidden:SetActorHiddenInGame(false) end
 self.sixHidden=nil
 if self.actor and not self.same(self.pawn,pawn) then self:cleanup() end
 local ok,result=pcall(self.apply,self,second,pawn,first,self:selected())
 if not ok and self.lastError~=result then self.log('Sombrero P2: '..tostring(result)) end
 self.lastError=not ok and result or nil
end

function Hats:choose(second,pawn,first)
 local option=self.options[self.cursor]
 if not option then return false end
 local ok,result=true,true
 if self.live(pawn) then ok,result=pcall(self.apply,self,second,pawn,first,option.id) end
 if ok and result then
  self.preferences.hat=option.id
  self.hint='Guardado: '..option.label
  self.log('Sombrero P2 guardado: '..option.id)
 else
  self.hint='No se pudo aplicar ese sombrero.'
  if not ok then self.log('Sombrero P2: '..tostring(result)) end
 end
 self.revision=self.revision+1
 return ok and result
end

return Hats
