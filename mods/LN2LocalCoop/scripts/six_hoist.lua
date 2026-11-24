local Hoist={};Hoist.__index=Hoist
local boostHeight=350 -- World units above the takeoff point.
local animations={
 ready='/Game/Characters/Six/Animations/ANIM_Six_HoistEnterFwdNoRM.ANIM_Six_HoistEnterFwdNoRM',
 six='/Game/Characters/Six/Animations/ANIM_Six_HoistPlayerJumpFast.ANIM_Six_HoistPlayerJumpFast',
 mono='/Game/Characters/Player/Animations/ANIM_Player_HoistPlayerJumpFast.ANIM_Player_HoistPlayerJumpFast',
}

function Hoist.new(c)
 return setmetatable({c=c,assets={},held={false,false}},Hoist)
end

function Hoist:asset(role)
 local asset=self.assets[role]
 if not self.c.live(asset) then
  local path=animations[role]
  asset=StaticFindObject(path)
  if not self.c.live(asset) then LoadAsset(path);asset=StaticFindObject(path) end
  self.assets[role]=asset
 end
 if self.c.live(asset) then return asset end
end

function Hoist:owns(pawn,asset)
 return self.c.live(pawn) and self.c.live(pawn.mAnimationControlComponent)
  and self.c.same(pawn.mAnimationControlComponent.mCurrentAnimStateAsset,asset)
end

function Hoist:ownsPawn(pawn)
 local active=self.active
 return active and ((self.c.same(pawn,active.helper) and self:owns(pawn,active.helperAsset))
  or (self.c.same(pawn,active.partner) and self:owns(pawn,active.partnerAsset)))
end

function Hoist:blocks(pawn)
 local active=self.active
 return active and (self.c.same(pawn,active.helper)
  or (active.liftedAt and not active.partnerReleased and self.c.same(pawn,active.partner)))
end

function Hoist:unfreezePose(active)
 local mesh=active.mesh
 if active.posePaused and self.c.live(mesh) then
  mesh.bPauseAnims=false
 end
 active.posePaused=nil
end

function Hoist:releasePartner(active,skipBlend)
 local c=self.c
 if c.live(active.anim) and active.anim.RootMotionMode==1 then active.anim:SetRootMotionMode(active.rootMode) end
 if c.live(active.movement) and active.movement.MovementMode==5 then active.movement:SetMovementMode(3,0) end
 if self:owns(active.partner,active.partnerAsset) then
  active.partner.mAnimationOverrideComponent:StopAnimationSequenceOverride(skipBlend)
 end
 active.partnerReleased=true
end

function Hoist:reset()
 local active=self.active
 self.active=nil
 if not active then return end
 local c=self.c
 local function release(fn)
  local ok,err=pcall(fn)
  if not ok then c.log('Impulso de Six: '..tostring(err)) end
 end
 release(function()self:unfreezePose(active)end)
 release(function()
  if self:owns(active.helper,active.helperAsset) then
   active.helper.mAnimationOverrideComponent:StopAnimationSequenceOverride(true)
  end
 end)
 if not active.partnerReleased then release(function()self:releasePartner(active,true)end) end
end

function Hoist:free(pawn,allowHands)
 local live=self.c.live
 if not (live(pawn) and pawn:IsAlive() and live(pawn.CharacterMovement) and pawn.CharacterMovement.MovementMode==1
  and live(pawn.Mesh) and live(pawn.CapsuleComponent) and live(pawn.mAnimationOverrideComponent)
  and live(pawn.mAnimationControlComponent) and not pawn.mAnimationControlComponent:IsPlayingOverrideAnimation()) then return false end
 local anim=pawn.Mesh:GetAnimInstance()
 if not live(anim) then return false end
 local grab=anim.mCurrentlyActiveGrabInterface
 if live(grab) and not (allowHands and grab:GetFullName():match('^PlayerHandholdingInterface ')) then return false end
 local pickup=pawn:GetPlayerPickupInterface()
 return not live(pickup) or not live(pickup:GetCurrentlyHeldPickup())
end

function Hoist:canReach(six,mono)
 local origin,destination=six:K2_GetActorLocation(),mono:K2_GetActorLocation()
 local dx,dy=destination.X-origin.X,destination.Y-origin.Y
 local facing=six:GetActorForwardVector()
 if dx*dx+dy*dy>135^2 or dx*facing.X+dy*facing.Y<0 then return false end
 local feet=origin.Z-six.CapsuleComponent:GetScaledCapsuleHalfHeight()
 if math.abs(destination.Z-mono.CapsuleComponent:GetScaledCapsuleHalfHeight()-feet)>32 then return false end
 local system=StaticFindObject('/Script/Engine.Default__KismetSystemLibrary')
 local color={R=0,G=0,B=0,A=0}
 return not system:CapsuleTraceSingleByProfile(six,origin,destination,1,1,
  six.CapsuleComponent:GetCollisionProfileName(),false,{six,mono},0,{},true,color,color,0)
end

function Hoist:prepare(six,mono,role,now,grab)
 if not self:free(six,false) then return end
 local asset=self:asset('ready')
 if not asset then return end
 self.active={helper=six,partner=mono,helperAsset=asset,role=role,mesh=six.Mesh,since=now,grab=grab==true}
 six.CharacterMovement:StopMovementImmediately()
 six.mAnimationOverrideComponent:PlayAnimationSequenceOverride2(asset,1,true,0,.08,.1)
end

function Hoist:displacement(asset,seconds)
 local library=StaticFindObject('/Script/Helios.Default__HeliosAnimationBlueprintLibrary')
 if not self.c.live(library) then return end
 return library:ExtractRootMotion(asset,0,seconds,false).Translation
end

function Hoist:overridden(pawn,asset)
 local control=pawn.mAnimationControlComponent
 return self.c.live(control) and control:IsPlayingOverrideAnimation() and not self:owns(pawn,asset)
end

function Hoist:apex(asset,duration)
 local samples,peak={},0
 local count=math.max(1,math.ceil(duration*30))
 for i=1,count do
  local relative=self:displacement(asset,duration*i/count)
  samples[i]=relative and relative.Z or 0
  peak=math.max(peak,samples[i])
 end
 if peak>=85 then
  -- End the guided ascent at the start of the peak, including flat tails.
  for i,z in ipairs(samples) do
   if z>=peak-1 then return duration*i/count,peak end
  end
 end
 return nil,peak
end

function Hoist:lift(active,now)
 local six,mono=active.helper,active.partner
 if not self:free(mono,true) or not self:canReach(six,mono) then return end
 local helper,partner=self:asset('six'),self:asset('mono')
 if not helper or not partner then return end
 local duration=partner.SequenceLength
 if type(duration)~='number' or duration<=0 then return end
 local grasp=mono.Mesh:GetAnimInstance().mCurrentlyActiveGrabInterface
 if self.c.live(grasp) then
  local target=grasp:GetHeldPartner()
  if self.c.live(target) and not self.c.same(target,six) then return end
  grasp:StopHoldingHands()
 end
 local releaseAt,nativeHeight=self:apex(partner,duration)
 local movement=mono.CharacterMovement
 local gravity=-movement:GetGravityZ()
 if not releaseAt and gravity<=0 then return end
 self:unfreezePose(active)
 if self:owns(six,active.helperAsset) then six.mAnimationOverrideComponent:StopAnimationSequenceOverride(true) end
 active.helperAsset,active.partnerAsset,active.liftedAt=helper,partner,now
 active.duration=math.max(helper.SequenceLength,duration)
 active.anim=mono.Mesh:GetAnimInstance()
 active.rootMode=active.anim.RootMotionMode
 active.anim:SetRootMotionMode(1)
 movement:StopMovementImmediately()
 six.mAnimationOverrideComponent:PlayAnimationSequenceOverride2(helper,1,false,0,.05,.1)
 mono.mAnimationOverrideComponent:PlayAnimationSequenceOverride2(partner,4,false,0,.05,.1)
 if releaseAt then
  active.releaseAt=releaseAt
  active.verticalScale=math.max(1,boostHeight/nativeHeight)
  active.movement=movement
  active.basis=mono.Mesh:K2_GetComponentToWorld()
  active.lastMotion={X=0,Y=0,Z=0}
  movement:SetMovementMode(5,0)
 else
  -- Some paired sequences animate in place. Use gravity and collision for the lift.
  mono:LaunchCharacter({X=0,Y=0,Z=math.sqrt(2*gravity*boostHeight)},false,true)
 end
 self.c.log(string.format('Impulso manual: P%d impulsa a P%d | altura prevista %.1f',active.role,3-active.role,math.max(boostHeight,nativeHeight)))
end

function Hoist:followMotion(active,elapsed)
 if not active.movement then return end
 local delta=self:displacement(active.partnerAsset,math.min(elapsed,active.partnerAsset.SequenceLength))
 if not delta or active.movement.MovementMode~=5 then return end
 local before=active.lastMotion
 local offset={X=delta.X-before.X,Y=delta.Y-before.Y,Z=delta.Z-before.Z}
 local shift=self.c.math():TransformDirection(active.basis,offset)
 local mono=active.partner
 local here=mono:K2_GetActorLocation()
 mono:K2_SetActorLocation({X=here.X,Y=here.Y,Z=here.Z+shift.Z*active.verticalScale},true,{},false)
 here=mono:K2_GetActorLocation()
 mono:K2_SetActorLocation({X=here.X+shift.X,Y=here.Y+shift.Y,Z=here.Z},true,{},false)
 active.lastMotion={X=delta.X,Y=delta.Y,Z=delta.Z}
end

function Hoist:step(first,second,controls,now,paused,blocked)
 local active=self.active
 local press={}
 for role=1,2 do
  local held=controls and controls.held[role] or false
  press[role]=held and not self.held[role]
  self.held[role]=held
 end
 if not controls or blocked or not (self.c.live(first) and self.c.live(second)) then
  self:reset()
  return false
 end
 local helper,partner=first,second
 if active and active.role==2 then helper,partner=second,first end
 if active and (not self.c.same(helper,active.helper) or not self.c.same(partner,active.partner)
  or not helper:IsAlive() or not partner:IsAlive()) then self:reset();return false end
 if paused then return active~=nil end
 if active and active.liftedAt then
  local elapsed=now-active.liftedAt
  if elapsed<0 or (elapsed>.2 and ((not active.partnerReleased and self:overridden(partner,active.partnerAsset))
   or self:overridden(helper,active.helperAsset))) then
   self:reset()
   return false
  end
  if not active.partnerReleased then
   if active.releaseAt then
    self:followMotion(active,math.min(elapsed,active.releaseAt))
    if elapsed>=active.releaseAt or active.movement.MovementMode~=5 then self:releasePartner(active,false) end
   else
    local speed=partner:GetVelocity().Z
    if speed>0 then active.rising=true
    elseif active.rising or partner.CharacterMovement.MovementMode==3 then self:releasePartner(active,false) end
   end
  end
  if elapsed>=active.duration then self:reset();return false end
  return true
 end
 if not active then
  if press[1] then self:prepare(first,second,1,now,controls.grab(2))
  elseif press[2] then self:prepare(second,first,2,now,controls.grab(1)) end
  return self.active~=nil
 end
 local own=self:owns(helper,active.helperAsset)
 if press[active.role] or (active.role==2 and controls.moving) or (not own and now-active.since>.22) then
  self:reset()
  return false
 end
 if own and not active.posePaused and not active.mesh.bPauseAnims
  and now-active.since>=active.helperAsset.SequenceLength*.85 then
  -- Pause the evaluated mesh pose before the entry sequence loops.
  active.mesh.bPauseAnims=true
  active.posePaused=true
 end
 local grab=controls.grab(3-active.role)==true
 if own and grab and not active.grab then self:lift(active,now) end
 active.grab=grab
 return true
end

function Hoist:update(...)
 local ok,result=pcall(self.step,self,...)
 if ok then return result end
 self:reset()
 self.c.log('Impulso manual: '..tostring(result))
 return false
end

return Hoist
