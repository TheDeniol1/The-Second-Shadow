local Six={}
Six.__index=Six
local meshes={
 jumper='/Game/Characters/Six/SKM_Six_Jumper.SKM_Six_Jumper',
 raincoat='/Game/Characters/Six/SKM_Six.SKM_Six',
}
local chaptersAfterRaincoat={Hospital=true,PaleCity=true,Transmission=true}
local shadow='/Game/Environment/DefaultMaterials/Effect/Hologram/MAT_HologramGlitch_PhantomKids_Inst01.MAT_HologramGlitch_PhantomKids_Inst01'

function Six.new(live,same,log)
 return setmetatable({live=live,same=same,log=log,assets={}},Six)
end

function Six:restore()
 local original=self.original
 self.original=nil
 if not original then return end
 if self.live(original.actor) then original.actor:K2_DestroyActor() end
 if self.live(original.component) then
  original.component.VisibilityBasedAnimTickOption=original.tick
  original.component:SetVisibility(original.visible,false)
 end
end

function Six:syncVisibility()
 local original=self.original
 if not original or not (self.live(original.actor) and self.live(original.pawn) and self.live(original.component)) then return end
 local hidden=not not (original.pawn.bHidden or original.component.bHiddenInGame)
 if original.actor.bHidden~=hidden then original.actor:SetActorHiddenInGame(hidden) end
end

function Six:storyPawn(pawn)
 if not self.live(self.overseer) then self.overseer=StaticFindObject('/Script/Helios.Default__OverseerBlueprintLibrary') end
 local companion=self.live(self.overseer) and self.overseer:GetHeliosPlaypalPawn() or nil
 if not (self.live(companion) and self.same(companion:GetWorld(),pawn:GetWorld())) then return end
 if companion:GetClass():GetFullName():find('BP_SixPawn',1,true) then return companion end
end

function Six:wornOutfit(companion)
 local mesh=companion.Mesh
 if self.live(mesh) and self.live(mesh.SkeletalMesh) then
  local name=mesh.SkeletalMesh:GetFullName()
  if name:find(meshes.jumper,1,true) then return 'jumper' end
  if name:find(meshes.raincoat,1,true) then return 'raincoat' end
 end
 return companion:GetClass():GetFullName():find('BP_SixPawn_WithCoat_C',1,true) and 'raincoat' or 'jumper'
end

function Six:resetWardrobe()
 self.wardrobe=nil
end

function Six:observeOutfit(pawn,companion)
 local world=pawn:GetWorld()
 local wardrobe=self.wardrobe
 if not wardrobe or not self.same(wardrobe.world,world) then
  local chapter=pawn:GetFullName():match('/Game/Levels/([^/]+)/PLVL_')
  -- Direct chapter loads can start without a live Six to copy.
  wardrobe={world=world,outfit=chaptersAfterRaincoat[chapter] and 'raincoat' or 'jumper'}
  self.wardrobe=wardrobe
 end
 if self.live(companion) then
  local present=not companion.bHidden and companion:IsAlive()
  if present then
   wardrobe.outfit=self:wornOutfit(companion)
   wardrobe.observed=true
   return wardrobe.outfit,true
  elseif not wardrobe.observed and self:wornOutfit(companion)=='raincoat' then
   -- The current playpal can be hidden during checkpoint streaming.
   wardrobe.outfit='raincoat'
  end
 end
 return wardrobe.outfit,false
end

function Six:asset(path)
 local asset=self.assets[path]
 if not self.live(asset) then
  asset=StaticFindObject(path)
  if not self.live(asset) then LoadAsset(path);asset=StaticFindObject(path) end
  self.assets[path]=asset
 end
 return asset
end

function Six:setLook(visual,component,mesh,material,previousDark)
 if previousDark then
  for i=0,visual:GetNumMaterials()-1 do visual:SetMaterial(i,nil) end
 end
 if not self.same(visual.SkeletalMesh,mesh) then
  visual:SetSkeletalMesh(mesh,false)
  assert(self.same(visual.SkeletalMesh,mesh),'el motor rechazó la malla de Six')
  visual:SetMasterPoseComponent(component,true)
 end
 if material then
  for i=0,visual:GetNumMaterials()-1 do visual:SetMaterial(i,material) end
 end
end

function Six:apply(pawn,shadowOnly)
 local component=pawn.Mesh
 if not self.live(component) or not self.live(component.SkeletalMesh) then return false end
 local original=self.original
 if original and not (self.same(original.component,component) and self.live(original.actor)) then
  self:restore()
  original=nil
 end
 local outfit,present=self:observeOutfit(pawn,self:storyPawn(pawn))
 local look=(shadowOnly or not present) and 'dark' or outfit
 -- Give a temporarily hidden or unloaded companion one polling interval to reappear.
 if original and look=='dark' and original.look~='dark' and not original.missing then
  original.missing=true
  return true
 end
 if original then
  original.missing=nil
  if original.look==look and original.outfit==outfit then
   if component.bVisible then component:SetVisibility(false,false) end
   self:syncVisibility()
   return true
  end
 end
 local mesh=self:asset(meshes[outfit])
 if not self.live(mesh) then return false,'malla de Six no disponible' end
 if not self.same(component.SkeletalMesh.Skeleton,mesh.Skeleton) then
  return false,'Six y Mono usan esqueletos distintos'
 end
 local material
 if look=='dark' then
  material=self:asset(shadow)
  if not self.live(material) then return false,'material de Dark Six no disponible' end
 end
 if original then
  self:setLook(original.actor.SkeletalMeshComponent,component,mesh,material,original.look=='dark')
  original.look,original.outfit=look,outfit
  self:syncVisibility()
  self.log('Apariencia P2: '..(look=='dark' and 'dark/'..outfit or look))
  return true
 end
 local class=StaticFindObject('/Script/Engine.SkeletalMeshActor')
 assert(self.live(class),'no se encontró el actor visual de Six')
 local actor=pawn:GetWorld():SpawnActor(class,component:K2_GetComponentLocation(),component:K2_GetComponentRotation())
 assert(self.live(actor),'no se pudo crear la apariencia de Six')
 self.original={actor=actor,pawn=pawn,component=component,tick=component.VisibilityBasedAnimTickOption,
  visible=component.bVisible,look=look,outfit=outfit}
 actor:SetOwner(pawn)
 actor:SetActorEnableCollision(false)
 local visual=actor.SkeletalMeshComponent
 assert(self.live(visual),'el actor visual de Six no tiene malla')
 if visual.Mobility~=2 then visual:SetMobility(2) end -- Movable
 visual:SetCollisionEnabled(0)
 local attached=visual:K2_AttachToComponent(component,FName('None'),2,2,2,false)
 assert(attached and self.same(visual:GetAttachParent(),component),'no se pudo unir la apariencia de Six a P2')
 self:setLook(visual,component,mesh,material)
 component.VisibilityBasedAnimTickOption=0 -- AlwaysTickPoseAndRefreshBones, even while the Mono mesh is hidden.
 component:SetVisibility(false,false)
 self:syncVisibility()
 self.log('Apariencia P2: '..(look=='dark' and 'dark/'..outfit or look))
 return true
end

function Six:sync(second,pawn,first,shadowOnly)
 if not (self.live(second) and self.live(second.Player) and second.Player.ControllerId==1
  and self.live(pawn) and self.live(first) and not self.same(first.Pawn,pawn)
  and self.same(second.Pawn,pawn) and self.same(pawn.Controller,second)) then return end
 if self.same(self.failedPawn,pawn) then return false,self.lastError end
 local ok,applied,reason=pcall(self.apply,self,pawn,shadowOnly)
 if not ok then
  reason=applied
  pcall(self.restore,self)
  self.failedPawn=pawn
 end
 if reason and self.lastError~=reason then self.log('Apariencia de Six: '..tostring(reason)) end
 self.lastError=reason
 return ok and applied,reason
end

function Six:darkVisual(pawn)
 local appearance=self.original
 if appearance and appearance.look=='dark' and self.same(appearance.pawn,pawn)
  and self.live(appearance.actor) and not appearance.actor.bHidden then
  return appearance.actor
 end
end

return Six
