-- Read-only scene research. Never replays callbacks, changes bindings or poses.
local T={};T.__index=T
function T.new(c)
 return setmetatable({c=c,hooks={},errors={},scenes={},last={},grabs={},nextScan=0},T)
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
 local function hook(path,callback)
  self:guard(path,function()
   if self.hooks[path] or not self.c.live(StaticFindObject(path))then return end
   RegisterHook(path,function(...)
    if not self.c.state.enabled then return end
    local args=table.pack(...)
    self:guard(path,function()callback(table.unpack(args,1,args.n))end)
   end)
   self.hooks[path]=true
  end)
 end
 for _,event in ipairs({'OnPlay','OnStop'})do
  hook('/Script/Helios.HeliosLevelSequenceActor:'..event,function(ctx)
   local actor=ctx:get();local pc=self.c.p1()
   if pc and self.c.world(actor,pc)then
    self:emit(event..' '..self:name(actor)..' asset='..self:name(actor:GetSequence()))
    self.nextScan=0
   end
  end)
 end
 local control='/Script/Helios.AnimationControlComponent:'
 local override='/Script/Helios.AnimationOverrideComponent:'
 for _,path in ipairs({override..'PlayAnimationSequenceOverride2',control..'PlayAnimationOverrideState'})do
  hook(path,function(ctx,asset)
   local role=self:role(ctx:get())
   if role then self:emit(role..' '..path..' asset='..self:name(asset:get()))end
  end)
 end
 for _,path in ipairs({override..'StopAnimationSequenceOverride',override..'StopComplexOverrideLoop',control..'StopAnimationOverrideState'})do
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
end
local grabTargets={
 {'PlayerDragInterface','mGrabbedGrabHelper'},
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
      or name:match('^CallFunc_GetPlayerPawn_ReturnValue')or name:match('^CallFunc_GetPlayerCharacter_ReturnValue')then
      lookups[#lookups+1]=string.format('%s@0x%X',name,property:GetOffset_Internal())
     end
    end)
    local path=self:name(fn)
    local name=path:match(':([^:]+)$')or ''
    if #lookups>0 or name:lower():find('swing',1,true)or name:find('Overlap',1,true)
     or name:find('Grab',1,true)or name:find('ExecuteUbergraph',1,true)then
     self:emit('Funcion '..path..' busquedas='..table.concat(lookups,','))
    end
   end)
  end
 end
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
   if c.live(class)and interface:IsA(class)then target=interface[entry[2]];break end
  end
  local targetName=self:name(target)
  signature=self:name(interface)..' objetivo='..targetName
  local captureSwing=index==2 and not self.capturedStairwellSwing and targetName:find(stairwellSwing,1,true)
  if (force or captureSwing)and c.live(target)then
   self:scriptCandidates(target:GetOwner())
   if captureSwing then self.capturedStairwellSwing=true end
  end
 end
 if force or (self.grabs[index] and self.grabs[index]~=signature) or (not self.grabs[index] and signature~='-')then
  self:emit('Agarre P'..index..' '..signature)
 end
 self.grabs[index]=signature
end
function T:snapshot(force)
 local c=self.c
 local pc,first,second=self:players()
 if not c.live(pc)then return end
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
    if force or ((sceneActive or playing or ignored or self.active) and self.last[i]~=signature)then
     local at=p:K2_GetActorLocation()
     self:emit(string.format('P%d %s XYZ=%.2f,%.2f,%.2f spawn=%s',i,signature,at.X,at.Y,at.Z,tostring(c.phase())))
    end
    self.last[i]=signature
   end)
   self:guard('agarre P'..i,function()self:grab(i,p,force)end)
  else self.last[i]=nil;self.grabs[i]=nil end
 end
 self.active=sceneActive or pc:IsMoveInputIgnored()
end
function T:scan()
 local c=self.c;local pc,first,second=self:players()
 local current={}
 if c.live(pc)then
  for _,actor in ipairs(FindAllOf('LevelSequenceActor')or{})do
   if c.live(actor)and c.world(actor,pc)then
    self:guard('sequence '..self:name(actor),function()
     local player=actor.SequencePlayer
     if c.live(player)and (player:IsPlaying()or player:IsPaused())then
      local key=self:name(actor);local roles={}
      for i,p in pairs({[1]=first,[2]=second})do
       if c.live(p)then
        roles[#roles+1]='P'..i..' bindings='..#player:GetObjectBindings(p)
       end
      end
      local value=self:name(actor:GetSequence())..' '..table.concat(roles,' ')
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
 self.scenes=current
end
function T:update(now)
 if not self.c.state.enabled then
  self.scenes={};self.last={};self.grabs={};self.active=false;self.nextScan=0;return
 end
 self:guard('update',function()
  if now<self.nextScan and now>=self.nextScan-0.25 then return end
  self.nextScan=now+0.25
  self:scan();self:snapshot(false)
 end)
end
function T:mark()
 self:guard('marca',function()self:emit('MARCA F8');self:scan();self:snapshot(true)end)
end
return T
