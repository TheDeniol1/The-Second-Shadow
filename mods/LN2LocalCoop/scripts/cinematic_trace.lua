-- Read-only scene research. Never replays callbacks, changes bindings or poses.
local T={};T.__index=T
local TowerAxe=require('tower_axe_transition')
local tower='/Game/Levels/Transmission/PLVL_Transmission.'
local storyChapters={School='Escuela',Hospital='Hospital',PaleCity='Ciudad Palida'}
function T.new(c)
 return setmetatable({c=c,hooks={},errors={},scenes={},sequences={},last={},grabs={},nextScan=0},T)
end
function T:name(o)return self.c.live(o) and o:GetFullName() or '-' end
function T:emit(s)self.c.log('[CinematicTrace] '..s)end
function T:guard(key,fn)
 local ok,err=pcall(fn)
 if not ok and self.errors[key]~=tostring(err) then
  self.errors[key]=tostring(err);self:emit('diagnostico '..key..': '..tostring(err))
 end
end
function T:players()
 local pc=self.c.p1()
 return pc,pc and pc.Pawn,self.c.driver.pawn
end
function T:role(component)
 local _,first,second=self:players()
 for i,p in pairs({[1]=first,[2]=second})do
  if self.c.live(p) and (self.c.same(component,p.mAnimationControlComponent)
   or self.c.same(component,p.mAnimationOverrideComponent))then return 'P'..i end
 end
end
function T:install()
 local function hook(path,callback,post)
  self:guard(path,function()
   if self.hooks[path] or not self.c.live(StaticFindObject(path))then return end
   local function dispatch(...)
    if not (self.c.state.enabled or self.watchingEnding) then return end
    local args=table.pack(...)
    self:guard(path,function()callback(table.unpack(args,1,args.n))end)
   end
   if post then RegisterHook(path,function()end,dispatch) else RegisterHook(path,dispatch) end
   self.hooks[path]=true
  end)
 end
 for _,event in ipairs({'OnPlay','OnStop'})do
  hook('/Script/Helios.HeliosLevelSequenceActor:'..event,function(ctx)
   local actor=ctx:get();local pc=self.c.p1()
   if pc and self.c.world(actor,pc)then
    local key,asset=self:name(actor),actor:GetSequence()
    self.sequences[key]=event=='OnPlay' and {actor=actor,asset=asset} or nil
    self:emit(event..' '..key..' asset='..self:name(asset))
    self.nextScan=0
   end
  end)
 end
 local control='/Script/Helios.AnimationControlComponent:'
 local override='/Script/Helios.AnimationOverrideComponent:'
 for _,path in ipairs({
  override..'PlayAnimationSequenceOverride2',control..'PlayAnimationOverrideState',
  override..'StopAnimationSequenceOverride',override..'StopComplexOverrideLoop',control..'StopAnimationOverrideState',
 })do
  -- A native pre-hook may run before the animation argument is initialized.
  -- snapshot reads the committed asset from the owning component on tick.
  hook(path,function(ctx)
   local role=self:role(ctx:get())
   if role then self:emit(role..' '..path)end
  end)
 end
 for _,class in ipairs({'PuzzleWallSwitchActor','PuzzleSwingActor'})do
  for _,event in ipairs({'StartGrab','EndGrab'})do
   hook('/Script/Helios.'..class..':OnHangableComponent'..event,function(ctx,_,grabber)
    local c=self.c
    local pc,first,second=self:players()
    local actor,interface=ctx:get(),grabber:get()
    if not c.live(interface)or not c.world(actor,pc)then return end
    local pawn=interface.mControlledPawn
    if not c.live(pawn)then return end
    local role=c.same(pawn,first)and 'P1' or (c.same(pawn,second)and 'P2')
    if role then self:emit('Interaccion '..event..' '..role..' objeto='..self:name(actor))end
   end)
  end
 end
 hook('/Script/Helios.DamageReciever:OnWeaponHit',function(receiver,instigator,_,weapon)
  self:weaponHit(receiver:get(),instigator:get(),weapon:get())
 end,true)
end
local grabTargets={
 {'PlayerDragInterface','mGrabbedGrabHelper'},
 {'PlayerLeverGrabInterface','mGrabbedGrabHelper'},
 {'PlayerPickupInterface'},
 {'PlayerHangableInterface','mGrabbedHangable'},
 {'LedgeClimbingInterface','mCurrentLedge'},
}
local stairwellSwing='/Game/Levels/School/SubLevels/LVL_2_040_AbandonedStairwell.LVL_2_040_AbandonedStairwell:PersistentLevel.PP_SwingableTemplate_BoxPushSwing.'
function T:scriptCandidates(actor)
 local c=self.c
 if not c.live(actor)then return end
 local level=actor:GetOuter()
 local levelScript=c.live(level)and self:name(level):match('^Level ') and level.LevelScriptActor
 for _,candidate in pairs({actor,levelScript})do
  if c.live(candidate)then
   local class=candidate:GetClass()
   self:emit('Blueprint '..self:name(class)..' instancia='..self:name(candidate))
   class:ForEachFunction(function(fn)
    local lookups={}
    fn:ForEachProperty(function(property)
     local name=property:GetFName():ToString()
     if name:match('^CallFunc_GetHeliosPlayerPawn_ReturnValue')
      or name:match('^CallFunc_GetPlayerPawn_ReturnValue')or name:match('^CallFunc_GetPlayerCharacter_ReturnValue')
      or name:match('^CallFunc_GetPlayerController_ReturnValue')then
      lookups[#lookups+1]=string.format('%s@0x%X',name,property:GetOffset_Internal())
     end
    end)
    local path=self:name(fn)
    local name=path:match(':([^:]+)$')or ''
    if #lookups>0 or name:lower():find('swing',1,true)or name:find('Overlap',1,true) or name:find('WeaponHit',1,true)
     or name:find('Grab',1,true)or name:find('ExecuteUbergraph',1,true)then
     self:emit('Funcion '..path..' busquedas='..table.concat(lookups,','))
    end
   end)
  end
 end
end
function T:musicBoxReceiver(owner,foundBy)
 self.musicBoxReceivers=self.musicBoxReceivers or {}
 local name=self:name(owner)
 if self.musicBoxReceivers[name] then return end
 self.musicBoxReceivers[name]=true
 self:emit('Caja musical: receptor '..foundBy..' '..name)
 self:guard('script caja musical '..name,function()self:scriptCandidates(owner)end)
end

function T:weaponHit(receiver,instigator,weapon)
 local c=self.c
 local _,first,second=self:players()
 if not (c.live(first) and c.live(second) and self:name(first):find(tower,1,true) and c.world(receiver,first)) then return end
 local owner=receiver:GetOwner()
 if not c.world(owner,first) then return end
 local role=c.same(instigator,first) and 'P1' or (c.same(instigator,second) and 'P2' or self:name(instigator))
 if c.live(weapon) and TowerAxe.isAxe(weapon) then
  self:emit('Puerta del hacha: golpe nativo atacante='..role..' objeto='..self:name(owner))
  return
 end
 self:emit('Caja musical: golpe nativo atacante='..role..' objeto='..self:name(owner)..' arma='..self:name(weapon))
 self:musicBoxReceiver(owner,'del golpe')
end

function T:musicBoxNearby(first,force)
 local c=self.c
 if not c.live(first) or not self:name(first):find(tower,1,true) then return end
 if not force and (c.phase()~='active' or c.same(self.scannedMusicBox,first)) then return end
 local at=first:K2_GetActorLocation()
 -- Bounds around the last encounter in the 19:40 trace. Keep the scan local.
 if at.Z<27900 or at.Z>28500 or at.Y<-400 or at.Y>1800 then return end
 local _,_,second=self:players()
 self.scannedMusicBox=first
 local nearest,seen={},{}
 for _,receiver in ipairs(FindAllOf('DamageReciever') or {}) do
  if c.world(receiver,first) then
   local owner=receiver:GetOwner()
   if c.world(owner,first) and not (c.same(owner,first) or c.same(owner,second)) then
    local name=self:name(owner)
    if not seen[name] then
     seen[name]=true
     local here=owner:K2_GetActorLocation()
     local distance=(here.X-at.X)^2+(here.Y-at.Y)^2+(here.Z-at.Z)^2
     if distance<=850^2 then nearest[#nearest+1]={owner=owner,distance=distance} end
    end
   end
  end
 end
 table.sort(nearest,function(a,b)return a.distance<b.distance end)
 for i=1,math.min(4,#nearest) do self:musicBoxReceiver(nearest[i].owner,'cercano') end
end
function T:grab(index,pawn,force)
 local c=self.c
 local mesh=pawn.Mesh
 local anim=c.live(mesh)and mesh:GetAnimInstance()
 local interface=c.live(anim)and anim.mCurrentlyActiveGrabInterface
 local signature='-'
 if c.live(interface)then
  local target
  for _,entry in ipairs(grabTargets)do
   local class=StaticFindObject('/Script/Helios.'..entry[1])
   if c.live(class)and interface:IsA(class)then
    if entry[2] then target=interface[entry[2]]
    else
     local pickup=interface:GetCurrentlyHeldPickup()
     if c.live(pickup) and c.same(pickup:GetHolderIfHeld(),pawn) then target=pickup end
    end
    break
   end
  end
  local targetName=self:name(target)
  signature=self:name(interface)..' objetivo='..targetName
  local captureSwing=index==2 and not self.capturedStairwellSwing and targetName:find(stairwellSwing,1,true)
  local captureAxe=index==2 and self:name(pawn):find(tower,1,true)
   and (targetName:find('Axe',1,true) or self:name(interface):find('PlayerLeverGrabInterface ',1,true))
  if captureAxe and c.live(target) then
   local owner=target:GetOwner()
   if c.world(owner,pawn) then self:musicBoxReceiver(owner,'del agarre de P2') end
  elseif (force or captureSwing)and c.live(target)then
   self:scriptCandidates(target:GetOwner())
   if captureSwing then self.capturedStairwellSwing=true end
  end
 end
 if force or (self.grabs[index] and self.grabs[index]~=signature) or (not self.grabs[index] and signature~='-')then
  self:emit('Agarre P'..index..' '..signature)
 end
 self.grabs[index]=signature
end
function T:snapshotSix(pc,label,force,watchEnding)
 local c=self.c
 if not label then self.storySix=nil;return end
 if not c.live(self.overseer) then
  self.overseer=StaticFindObject('/Script/Helios.Default__OverseerBlueprintLibrary')
 end
 local six=c.live(self.overseer) and self.overseer:GetHeliosPlaypalPawn() or nil
 if not c.world(pc,six) then six=nil end
 local control=six and six.mAnimationControlComponent
 local asset=c.live(control) and control.mCurrentAnimStateAsset or nil
 local playing=c.live(control) and control:IsPlayingOverrideAnimation() or false
 local name=self:name(six)
 local signature=name..' asset='..self:name(asset)..' override='..tostring(playing)
 local previous=self.storySix
 if force or not previous or previous.label~=label or previous.name~=name
  or ((watchEnding or playing or previous.playing or self.active) and previous.signature~=signature) then
  local at=six and six:K2_GetActorLocation()
  self:emit(label..' '..signature..(at and string.format(' XYZ=%.2f,%.2f,%.2f',at.X,at.Y,at.Z) or ''))
 end
 self.storySix={label=label,name=name,signature=signature,playing=playing,actor=six}
end

function T:snapshot(force,watchEnding)
 local c=self.c
 local pc,first,second=self:players()
 if not c.live(pc)then return end
 self:guard('receptores caja musical',function()self:musicBoxNearby(first,force)end)
 local sceneActive=next(self.scenes)~=nil
 for i,p in pairs({[1]=first,[2]=second})do
  if c.live(p)then
   self:guard('snapshot P'..i,function()
    local ac=p.mAnimationControlComponent
    local asset=c.live(ac)and ac.mCurrentAnimStateAsset or nil
    local controller=p.Controller
    local ignored=c.live(controller)and controller:IsMoveInputIgnored() or false
    local playing=c.live(ac)and ac:IsPlayingOverrideAnimation()or false
    local signature=self:name(p)..' asset='..self:name(asset)..' override='..tostring(playing)..' inputBlocked='..tostring(ignored)
    local scripted=playing or ignored
    local previous=self.last[i]
    if force or ((sceneActive or scripted or (previous and previous.scripted) or self.active or watchEnding)
      and (not previous or previous.signature~=signature))then
     local at=p:K2_GetActorLocation()
     self:emit(string.format('P%d %s XYZ=%.2f,%.2f,%.2f spawn=%s',i,signature,at.X,at.Y,at.Z,tostring(c.phase())))
    end
    self.last[i]={signature=signature,scripted=scripted}
   end)
   self:guard('agarre P'..i,function()self:grab(i,p,force)end)
  else self.last[i]=nil;self.grabs[i]=nil end
 end
 self.active=sceneActive or pc:IsMoveInputIgnored()
 local chapter=storyChapters[self:name(first):match('/Game/Levels/([^/]+)/PLVL_')]
 local label=watchEnding and 'Six en el final' or (chapter and 'Six en '..chapter)
 self:guard('Six en cinemáticas',function()self:snapshotSix(pc,label,force,watchEnding)end)
end
function T:scan()
 local c=self.c;local pc,first,second=self:players()
 local current,sequences={},{}
 if c.live(pc)then
  for _,actor in ipairs(FindAllOf('LevelSequenceActor')or{})do
   if c.live(actor)and c.world(actor,pc)then
    self:guard('sequence '..self:name(actor),function()
     local player=actor.SequencePlayer
     if c.live(player)and (player:IsPlaying()or player:IsPaused())then
      local key=self:name(actor);local roles={}
      local sequence=actor:GetSequence()
      sequences[key]={actor=actor,asset=sequence}
      for i,p in pairs({[1]=first,[2]=second})do
       if c.live(p)then
        roles[#roles+1]='P'..i..' bindings='..#player:GetObjectBindings(p)
       end
      end
      local six=self.storySix and self.storySix.actor
      if c.live(six) and c.world(actor,six) then roles[#roles+1]='Six bindings='..#player:GetObjectBindings(six) end
      local value=self:name(sequence)..' '..table.concat(roles,' ')
      current[key]=value
      if self.scenes[key]~=value then self:emit('sequence '..key..' asset='..value)end
     end
    end)
   end
  end
 end
 for key in pairs(self.scenes)do
  if not current[key]then self:emit('sequence ended/unloaded '..key)end
 end
 self.scenes,self.sequences=current,sequences
end
function T:sequence(actorName,pawn)
 local entry=self.sequences[actorName]
 local c=self.c
 if not entry or not c.world(entry.actor,pawn) then return end
 local player=entry.actor.SequencePlayer
 if c.live(player) and (player:IsPlaying()or player:IsPaused()) then return entry.asset end
end
function T:update(now,watchEnding)
 self.watchingEnding=watchEnding
 if not (self.c.state.enabled or watchEnding) then
  self.scenes={};self.sequences={};self.last={};self.grabs={};self.active=false;self.nextScan=0;self.storySix=nil;return
 end
 self:guard('update',function()
  if now<self.nextScan and now>=self.nextScan-0.25 then return end
  self.nextScan=now+0.25
  self:scan();self:snapshot(false,watchEnding)
 end)
end
function T:mark()
 self:guard('marca',function()self:emit('MARCA F8');self:scan();self:snapshot(true)end)
end
return T
