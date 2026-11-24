-- Opt-in, one observed ledge per world. No teleports or synthetic story notifies.
local Controller=require('coop_ledge_rescue')
local PhysicalInput=require('rescue_input')
local N={};N.__index=N
local pullPath='/Game/Characters/Player/Animations/ANIM_Player_DragPullStepBack.ANIM_Player_DragPullStepBack'
function N.new(c)
 local self=setmetatable({c=c},N)
 self.control=Controller.new({start=function(s)return self:start(s)end,
  climb=function(a,s)self:climb(a,s)end,finish=function(a,r)self:finish(a,r)end})
 return self
end
function N:reset()
 self.control:cancel('reinicio');self.control.waitRelease=nil;self.selection=nil
end
function N:message(text)
 self.notice=text;self.noticeUntil=(self.c.clock and self.c.clock()or os.clock())+4
 self.c.log('Rescate: '..text)
end
function N:noticeText()
 if self.notice and (self.c.clock and self.c.clock()or os.clock())<self.noticeUntil then return self.notice end
 self.notice=nil
end
function N:secondPawn()
 local c=self.c
 if c.playpal then
  local six,controlled=c.playpal()
  if c.live(six) then return six,controlled end
 end
 return c.driver.pawn,true
end
function N:pair()
 local c=self.c;local pc=c.p1();local q=c.driver.pawn
 if not c.state.enabled or c.state.menu or c.spawn.phase~='active' or c.spawn.pending or c.death.pending
  or not pc or not c.foreground() or c.UE.GetGameplayStatics():IsGamePaused(pc)
  or not c.live(pc.Pawn) or not c.live(q) or not c.live(c.driver.pc) then return end
 local p=pc.Pawn
 if not c.world(p,q) or c.same(p,q) or not c.same(p.Controller,pc)
  or not c.same(q.Controller,c.driver.pc) or not c.same(c.driver.pc.Pawn,q)
  or not p:IsAlive() or not q:IsAlive()
  or (pc:IsMoveInputIgnored() and not (c.ownsPrimary and c.ownsPrimary(p))) then return end
 local partner,controlled=self:secondPawn()
 if not controlled or not c.world(p,partner) or c.same(p,partner) or not partner:IsAlive() then return end
 if not c.same(partner,q) then
  local ai=partner.Controller
  if not c.live(ai) or not c.same(ai.Pawn,partner) or not c.live(ai.mBodyAnimator)
   or not c.same(ai.mBodyAnimator.mPawnSelf,partner) then return end
 end
 return p,partner
end
function N:ledge(p)
 local c=self.c
 if not c.live(p.Mesh)then return end
 local anim=p.Mesh:GetAnimInstance()
 if not c.live(anim)or not anim.mLedgeData or not anim.mLedgeData.mIsHanging then return end
 local interface=anim.mCurrentlyActiveGrabInterface
 local class=StaticFindObject('/Script/Helios.LedgeClimbingInterface')
 if not c.live(interface)or not c.live(class)or not interface:IsA(class)then return end
 local edge=interface.mCurrentLedge
 if c.live(edge)and edge:IsLedgeEnabled()and edge.mAllowClimbUpOnTop then return edge,interface end
end
function N:select()
 if self.selection then self:reset();self:message('Prueba desactivada');return end
 local p,q=self:pair();if not p then self:message('Activa ambos Monos y cierra el menu');return end
 local ep,ip=self:ledge(p);local eq,iq=self:ledge(q)
 if (ep and eq)or not(ep or eq)then self:message('Deja un solo Mono colgado de un borde escalable');return end
 local victim,edge,interface=ep and p or q,ep or eq,ip or iq
 local at=victim:K2_GetActorLocation()
 self.selection={edge=edge,world=p:GetWorld(),at={X=at.X,Y=at.Y,Z=at.Z}}
 self.c.log('Rescate: borde seleccionado '..edge:GetFullName()..'; acercate arriba y manten agarre')
 self:message('Borde seleccionado: acercate arriba y manten agarre')
end
function N:held(p)
 local c=self.c
 if c.same(p,self:secondPawn())then return c.input().grab end
 -- Read configured keyboard mappings; the assigned XInput pad uses the same RT as normal play.
 local pad=c.gamepad:forRole(1)
 if pad and pad.grab then return true end
 local settings=StaticFindObject('/Script/Engine.Default__InputSettings')
 local mappings={}
 for i=1,#settings.ActionMappings do
  local m=settings.ActionMappings[i]
  if not m.Key.KeyName:ToString():find('Gamepad',1,true)
   and m.ActionName:ToString():lower():find('grab',1,true)then
   mappings[#mappings+1]={key=m.Key.KeyName:ToString(),shift=m.bShift,ctrl=m.bCtrl,alt=m.bAlt}
  end
 end
 local held=PhysicalInput.held(mappings,c.physicalKey)
 if held~=nil then return held end
 if pad then return false end
 return nil
end
function N:snapshot(blocked)
 local c=self.c;local selection=self.selection
 if not selection then return end
 local p,q=self:pair()
 if not p or blocked then return end
 if not c.live(selection.edge)or not c.same(selection.world,p:GetWorld())then self.selection=nil;return end
 local a=self.control.active;local victim,helper,edge,interface
 if a then
  if not(c.same(a.p,p)or c.same(a.p,q))or not(c.same(a.h,p)or c.same(a.h,q))then return end
  victim,helper=a.p,a.h;edge,interface=self:ledge(victim)
 else
  edge,interface=self:ledge(p);victim,helper=p,q
  if not edge then edge,interface=self:ledge(q);victim,helper=q,p end
 end
 if not a and not c.same(edge,selection.edge)then return end
 if a and (not c.same(a.pc,victim.Controller)or not c.same(a.hc,helper.Controller))then return end
 local v,h=victim:K2_GetActorLocation(),helper:K2_GetActorLocation()
 -- A fall onto the floor below is not a successful rescue. Require an actual
 -- height gain and arrival at the helper's platform, with no active climb.
 local done=a and a.driven and not edge and victim.CharacterMovement.MovementMode==1
  and v.Z>=a.origin.Z+25 and math.abs(v.Z-a.anchor.Z)<=35
 local nearby=(v.X-h.X)^2+(v.Y-h.Y)^2<=160^2 and h.Z-v.Z>=-20 and h.Z-v.Z<=180
 local at=selection.at
 local inZone=(v.X-at.X)^2+(v.Y-at.Y)^2<=180^2 and math.abs(v.Z-at.Z)<=200
 local ac=helper.mAnimationControlComponent
 local owned=a and c.same(ac.mCurrentAnimStateAsset,a.asset)
 local playing=ac:IsPlayingOverrideAnimation()
 -- NoMovement can disable walking while our own override is active. Require
 -- the owned animation, its restriction, and the original grounded position.
 local anchored=a and (h.X-a.anchor.X)^2+(h.Y-a.anchor.Y)^2+(h.Z-a.anchor.Z)^2<=4^2
 local immobilized=owned and playing and ac.mMovementRestrictionMode==1 and anchored
 local support=helper.CharacterMovement.MovementMode==1 or immobilized
 local animationOK=(a and owned and playing)or (not a and not playing)
 local reason
 if not nearby then reason='distancia entre Monos'
 elseif not inZone then reason='fuera de la zona seleccionada'
 elseif not support then reason='ayudante sin apoyo; movement='..tostring(helper.CharacterMovement.MovementMode)..' restriction='..tostring(ac.mMovementRestrictionMode)
 elseif not animationOK then reason='animacion del ayudante interrumpida'
 elseif edge and not c.same(edge,selection.edge)then reason='cambio de borde'
 elseif a and not a.driven and not edge then reason='el Mono dejo de estar colgado' end
 if edge and self:held(victim)==false then reason=reason or 'El Mono colgado solto agarre' end
 local valid=reason==nil
 if not a then
  local anim=helper.Mesh:GetAnimInstance();local pickup=helper:GetPlayerPickupInterface()
  if h.Z-v.Z<25 then reason=reason or 'Acercate desde arriba'
  elseif c.live(anim.mCurrentlyActiveGrabInterface)then reason=reason or 'El ayudante ya esta agarrando algo'
  elseif c.live(pickup)and c.live(pickup:GetCurrentlyHeldPickup())then reason=reason or 'Deja el objeto antes de ayudar' end
  valid=reason==nil
 end
 -- A release must be observed even when the attempt is no longer in range.
 local held=not not self:held(helper)
 if not a and held and reason and self.lastReason~=reason then self:message(reason)end
 self.lastReason=reason
 return {helper=helper:GetAddress(),victim=victim:GetAddress(),edge=selection.edge:GetAddress(),
  h=helper,p=victim,interface=interface,held=held,hanging=edge~=nil,
  now=c.UE.GetGameplayStatics():GetTimeSeconds(p),ready=true,valid=valid,done=done,reason=reason}
end
function N:start(s)
 local c=self.c;local asset=s.helperAsset or StaticFindObject(pullPath)
 if not c.physicalKey or self:held(c.p1().Pawn)==nil then
  self:message('No se puede leer el agarre fisico de P1; se necesita el adaptador 18 y una tecla compatible');return
 end
 if not c.live(asset)then pcall(LoadAsset,pullPath);asset=StaticFindObject(pullPath)end
 if not c.live(asset)then c.log('Rescate: animacion de tiron no disponible');return end
 -- Helios' climb eligibility compares movement with the pawn's current
 -- forward vector (A6AA40), not with the approach vector cached on first grab.
 local direction=s.p:GetActorForwardVector()
 local length=math.sqrt(direction.X^2+direction.Y^2)
 if length<0.5 then return end
 -- Do not replace the hanging player's grab or override its native climb.
 local at=s.h:K2_GetActorLocation()
 local origin=s.p:K2_GetActorLocation()
 local rotation=s.h:K2_GetActorRotation()
 local a={p=s.p,h=s.h,pc=s.p.Controller,hc=s.h.Controller,asset=asset,interface=s.interface,
  nativeEdge=self.selection.edge,rotation={Pitch=rotation.Pitch,Yaw=rotation.Yaw,Roll=rotation.Roll},
  origin={X=origin.X,Y=origin.Y,Z=origin.Z},anchor={X=at.X,Y=at.Y,Z=at.Z},
  direction={X=direction.X/length,Y=direction.Y/length,Z=0}}
 local data=s.p.Mesh:GetAnimInstance().mLedgeData
 local params=data.mIsFreeHang and s.interface.mClimbFromFreeHangParams or s.interface.mClimbFromHangParams
 a.climbAsset=params.mAnimation
 if not c.live(a.climbAsset)then self:message('El borde no tiene animacion de subida disponible');return end
 a.beforeAsset=s.h.mAnimationControlComponent.mCurrentAnimStateAsset
 self.pending=a
 -- Capture the exact controller and its previous tick state. Both physical
 -- input streams remain live via the native reader while P1 is suspended.
 a.primary=c.p1();a.primaryPawn=a.primary.Pawn
 a.primaryTick=a.primary:IsActorTickEnabled()
 a.primary:SetActorTickEnabled(false)
 s.h.CharacterMovement:StopMovementImmediately()
 local facing=math.deg(math.atan(origin.Y-at.Y,origin.X-at.X))
 s.h:K2_SetActorRotation({Pitch=0,Yaw=facing,Roll=0},true)
 a.rotated=true
 a.helperLoop=s.helperLoop~=false
 if not s.deferPull then self:playPull(a)end
 self.pending=nil
 c.log('Rescate: preparando tiron; suelta agarre para cancelar')
 return a
end
function N:playPull(a)
 a.h.mAnimationOverrideComponent:PlayAnimationSequenceOverride2(a.asset,1,a.helperLoop,0,0.1,0.15)
 a.started=true
end
function N:climb(a,s)
 if not s.hanging then return end
 if not a.driven then
  a.requestAt=s.now
  self.c.log(string.format('Rescate: orden de subida enviada; direccion=%.3f,%.3f',a.direction.X,a.direction.Y))
 end
 a.driven=true
 a.p.Controller.mBodyAnimator:SetMoveInput(a.direction)
end
function N:observeClimb(a,s)
 if not a.driven then return end
 local c=self.c;local data=a.p.Mesh:GetAnimInstance().mLedgeData
 if not a.observedClimb and a.interface.mGrabbingState==4
  and c.same(data.mClimbAnimation,a.climbAsset)then
  a.observedClimb=true;self:message('Subida nativa iniciada; manten agarre')
 end
 if not a.diagnosed and s.now-a.requestAt>=.35 then
  a.diagnosed=true
  local ok,detail=pcall(function()
   local move=a.pc.mBodyAnimator:GetMoveInput()
   local forward=a.p:GetActorForwardVector()
   local at=a.p:K2_GetActorLocation()
   return string.format('estado=%s colgado=%s bloqueo=%s entrada=%.3f,%.3f,%.3f frente=%.3f,%.3f alturaGanada=%.2f demoraMinima=%s entradaMinima=%s',
    tostring(a.interface.mGrabbingState),tostring(data.mIsHanging),tostring(data.mDesiredClimbBlocked),
    move.X,move.Y,move.Z,forward.X,forward.Y,at.Z-a.origin.Z,
    tostring(a.interface.mTimeBeforeClimbAllowed),tostring(a.interface.mMinInputSizeToClimbUp))
  end)
  c.log('Rescate: respuesta del motor '..(ok and detail or tostring(detail)))
  if not a.observedClimb and data.mDesiredClimbBlocked then
   self:message('El juego esta bloqueando la subida de este borde')
  end
 end
end
function N:finish(a,reason)
 local c=self.c
 local function cleanup(label,fn)
  local ok,err=pcall(fn)
  if not ok then c.log('Rescate: limpieza '..label..': '..tostring(err))end
 end
 -- ReleaseGrab is the native interface teardown, not a fabricated animation
 -- notify. Only abort our observed ledge traversal; never release a different
 -- interaction or an idle hanging player on an early cancellation.
 cleanup('subida',function()
 if reason~='subida terminada' and a.driven and c.live(a.p)and a.p:IsAlive()
  and c.same(a.p.Controller,a.pc)and c.live(a.interface)
  and c.same(a.interface.mControlledPawn,a.p)and c.same(a.interface.mCurrentLedge,a.nativeEdge)
  and a.interface.mGrabbingState==4 then -- EGrabbingStates::ExitGrabbing
   local anim=a.p.Mesh:GetAnimInstance()
   local ac=a.p.mAnimationControlComponent
   if c.same(anim.mCurrentlyActiveGrabInterface,a.interface)
    and c.same(anim.mLedgeData.mClimbAnimation,a.climbAsset)
    and c.live(ac)and (not ac:IsPlayingOverrideAnimation()or c.same(ac.mCurrentAnimStateAsset,a.climbAsset))then
    a.interface:ReleaseGrab(0) -- AllowRegrab. Normal physics may drop the player.
    a.aborted=true
   end
 end
 end)
 -- Release only writes belonging to this attempt, including on partial startup failure.
 cleanup('entrada',function()
 if c.live(a.p)and c.same(a.p.Controller,a.pc)and c.live(a.pc.mBodyAnimator)then
  a.pc.mBodyAnimator:ClearMoveInput();a.pc.mBodyAnimator:SetRawMoveInput({X=0,Y=0,Z=0})
 end end)
 cleanup('controlador',function()
 if c.live(a.primary)and c.same(a.primary,c.p1())and a.primaryTick~=nil then
  a.primary:SetActorTickEnabled(a.primaryTick)
 end end)
 cleanup('animacion',function()
 if c.live(a.h)and c.live(a.h.mAnimationControlComponent)then
  local current=a.h.mAnimationControlComponent.mCurrentAnimStateAsset
  local own=c.same(current,a.asset)
  local pending=not a.started and (c.same(current,a.beforeAsset)or (not c.live(current)and not c.live(a.beforeAsset)))
  if own then a.h.mAnimationOverrideComponent:StopAnimationSequenceOverride(true)end
  if not own and not pending then return end
  if a.rotated and reason~='subida terminada' and c.same(a.h.Controller,a.hc)then
   a.h:K2_SetActorRotation(a.rotation,true)
  end
 end end)
 self:message(reason)
end
-- Arbitration happens before the ordinary P2 driver writes raw and world axes.
-- Copy the sampled input: cancellation always reads the real physical buttons.
function N:route(direction,input,yaw)
 local a=self.control.active;local c=self.c
 if not a then return direction,input end
 local partner=self:secondPawn()
 local victim=c.same(partner,a.p)
 local helper=c.same(partner,a.h)
 if not victim and not helper then return direction,input end
 local d=victim and a.driven and a.direction or {X=0,Y=0,Z=0}
 local angle=math.rad(yaw)
 local routed={x=-math.sin(angle)*d.X+math.cos(angle)*d.Y,
  y=math.cos(angle)*d.X+math.sin(angle)*d.Y,
  grab=victim and input.grab or false,jump=false,sneak=false,sprint=false,use=false,gadget=false}
 return d,routed
end
function N:maintain()
 local a=self.control.active;if not a then return end
 local c=self.c
 if c.live(a.h)and c.same(a.h.Controller,a.hc)then
  a.hc.mBodyAnimator:ClearMoveInput();a.hc.mBodyAnimator:SetRawMoveInput({X=0,Y=0,Z=0})
 end
 if c.live(a.p)and c.same(a.p.Controller,a.pc)then
  local d=a.driven and a.direction or {X=0,Y=0,Z=0}
  a.pc.mBodyAnimator:SetMoveInput(d)
  local yaw=math.rad(c.cameraYaw and c.cameraYaw(a.p) or a.pc.PlayerCameraManager:GetCameraRotation().Yaw)
  a.pc.mBodyAnimator:SetRawMoveInput({X=math.cos(yaw)*d.X+math.sin(yaw)*d.Y,
   Y=-math.sin(yaw)*d.X+math.cos(yaw)*d.Y,Z=0})
 end
end
function N:interrupt(blocked)
 if not self.control.active then return end
 local ok,ready=pcall(function()return not blocked and self:pair()end)
 if not ok or not ready then self.control:cancel('interrumpido')end
end
function N:update(blocked)
 if not self.selection and not self.control.active then return false end
 local ok,result=pcall(function()
  local snapshot=self:snapshot(blocked)
  local active=self.control:update(snapshot)
  if active then
   self:observeClimb(self.control.active,snapshot)
   self:maintain()
  end
  return active
 end)
 if ok then return result end
 if self.pending then self:finish(self.pending,'inicio fallido');self.pending=nil end
 self:reset();self.c.log('Rescate desactivado: '..tostring(result));return false
end
return N
