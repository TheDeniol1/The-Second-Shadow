-- Explicit hand offer. Only the waiting pose loops; the paired pull plays once.
local Base=require('ledge_rescue_native')
local Rules=require('hand_rescue_rules')
local AirPath=require('air_rescue_path')
local H={};H.__index=H
local paths={
 ready='/Game/Characters/Six/Animations/ANIM_Six_GapHelpReadyLoop.ANIM_Six_GapHelpReadyLoop',
 pull='/Game/Characters/Six/Animations/ANIM_Six_GapHelpPullUp.ANIM_Six_GapHelpPullUp',
 rise='/Game/Characters/Player/Animations/ANIM_Player_GapHelpPulledUp.ANIM_Player_GapHelpPulledUp',
 hoist='/Game/Characters/Six/Animations/ANIM_Six_HoistEnterFwd.ANIM_Six_HoistEnterFwd'}
local hands={'skinned_l_handPlacement_bn','skinned_r_handPlacement_bn'}
local function copy(v)return {X=v.X,Y=v.Y,Z=v.Z}end
function H.new(c)
 return setmetatable({c=c,base=Base.new(c),control={},released={true,true}},H)
end
function H:message(s)self.base:message(s)end
function H:noticeText()return self.base:noticeText()end
function H:select()self:message('Ofrece la mano manteniendo F1 (P1) o F2 (P2)')end
function H:held(role)return self.c.offerHeld(role)==true end
function H:assets()
 local result={}
 for k,path in pairs(paths)do
  local asset=StaticFindObject(path)
  if not self.c.live(asset)then LoadAsset(path);asset=StaticFindObject(path)end
  if not self.c.live(asset)then error('No se pudo cargar '..path)end
  result[k]=asset
 end
 return result
end
function H:own(p,asset)
 return self.c.live(p)and self.c.live(p.mAnimationControlComponent)
  and self.c.same(p.mAnimationControlComponent.mCurrentAnimStateAsset,asset)
end
function H:freezePrimary(a)
 if a.primary then return end
 a.primary=self.c.p1();a.tick=a.primary:IsActorTickEnabled()
 a.primary:SetActorTickEnabled(false)
end
function H:clear(p,pc)
 if self.c.live(p)and self.c.same(p.Controller,pc)then
  pc.mBodyAnimator:ClearMoveInput();pc.mBodyAnimator:SetRawMoveInput({X=0,Y=0,Z=0})
 end
end
function H:finish(reason)
 local a=self.control.active;if not a then return end
 self.control.active=nil;self.released[a.role]=false
 local function clean(fn)local ok,e=pcall(fn);if not ok then self.c.log('Rescate mano: limpieza '..tostring(e))end end
 if a.native then
  clean(function()self.base:finish(a.native,reason=='Rescate terminado'and 'subida terminada'or reason)end)
  self.base.control.active=nil;self.base.selection=nil
 end
 clean(function()self:clear(a.h,a.hc)end)
 if a.captured then clean(function()self:clear(a.v,a.vc)end)end
 for _,entry in ipairs({{a.h,a.hAsset},{a.h,a.assets.ready},{a.captured and a.v or nil,a.vAsset}})do
  clean(function()
   local p,asset=entry[1],entry[2]
   if asset and self:own(p,asset)then p.mAnimationOverrideComponent:StopAnimationSequenceOverride(true)end
  end)
 end
 clean(function()self:releaseAirPhysics(a)end)
 clean(function()
  if a.primary and self.c.live(a.primary)and self.c.same(a.primary,self.c.p1())then a.primary:SetActorTickEnabled(a.tick)end
 end)
 self:message(reason)
end
function H:releaseAirPhysics(a)
 if a.airAnim then
  if self.c.live(a.v)and self.c.live(a.v.Mesh)and self.c.live(a.airAnim)
   and self.c.same(a.v.Mesh:GetAnimInstance(),a.airAnim)and a.airAnim.RootMotionMode==1 then
   a.airAnim:SetRootMotionMode(a.previousRootMode)
  end
  a.airAnim=nil
 end
 if not a.airMovement then return end
 local movement=a.airMovement
 if self.c.live(a.v)and self.c.same(a.v.CharacterMovement,movement)
  and self.c.same(a.v.Controller,a.vc)and movement.MovementMode==5 then
  movement:SetMovementMode(3,0)
 end
 a.airMovement=nil
end
function H:reset()self:finish('Asistencia cancelada');self.base:reset()end
function H:interrupt(blocked)
 if not self.control.active then return end
 local ok,p=pcall(function()if not blocked then return self.base:pair()end end)
 if not ok or not p then self:finish('Asistencia interrumpida')end
end
function H:free(p)
 local ac=p.mAnimationControlComponent
 local grab=p.Mesh:GetAnimInstance().mCurrentlyActiveGrabInterface
 local pickup=p:GetPlayerPickupInterface()
 return not ac:IsPlayingOverrideAnimation()and not self.c.live(grab)
  and not(self.c.live(pickup)and self.c.live(pickup:GetCurrentlyHeldPickup()))
end
local function crouched(p)
 if p.bIsCrouched then return true end
 local amount=p.Mesh:GetAnimInstance().CrouchAmount
 return type(amount)=='number'and amount>=.85
end
local function clearReach(helper,partner,from,to)
 local library=StaticFindObject('/Script/Engine.Default__KismetSystemLibrary')
 local color={R=0,G=0,B=0,A=0}
 -- Hand-sized sweep using the pawn profile. Ignore both participants.
 return not library:CapsuleTraceSingleByProfile(helper,from,to,1,1,
  helper.CapsuleComponent:GetCollisionProfileName(),false,{helper,partner},0,{},true,color,color,0)
end
function H:boost(a)
 local h,v,role=a.h,a.v,a.role
 if v.CharacterMovement.MovementMode~=1 or not self:free(v)or crouched(v)then return false end
 local hc,vc=h.CapsuleComponent,v.CapsuleComponent
 if not self.c.live(hc)or not self.c.live(vc)then return end
 local from,to=h:K2_GetActorLocation(),v:K2_GetActorLocation()
 local dx,dy=to.X-from.X,to.Y-from.Y
 local facing=h:GetActorForwardVector()
 if dx*dx+dy*dy>135^2 or dx*facing.X+dy*facing.Y<0
  or math.abs((to.Z-vc:GetScaledCapsuleHalfHeight())-(from.Z-hc:GetScaledCapsuleHalfHeight()))>28
  or not clearReach(h,v,from,to)then return end
 local gravity=-v.CharacterMovement:GetGravityZ()
 if gravity<=0 then return end
 self:finish('Salto asistido de P'..(3-role))
 -- Target roughly 235 cm of extra reach in the current level's gravity.
 -- The character keeps its horizontal motion and native grab/collision.
 v:LaunchCharacter({X=0,Y=0,Z=math.sqrt(2*gravity*235)},false,true)
 return true
end
function H:begin(h,v,role,now,boostReady)
 if h.CharacterMovement.MovementMode~=1 or not self:free(h)then return end
 local assets=self:assets()
 -- Read the same reflected property used by the cinematic adapter. Cache
 -- the duration before contact so capture never calls GetPlayLength.
 local pullLength,riseLength=assets.pull.SequenceLength,assets.rise.SequenceLength
 local duration=type(pullLength)=='number'and type(riseLength)=='number'and math.max(pullLength,riseLength)
 local a={h=h,v=v,hc=h.Controller,vc=v.Controller,role=role,assets=assets,
  hAsset=boostReady and assets.hoist or assets.ready,airDuration=duration,anchor=copy(h:K2_GetActorLocation()),since=now,last=now,
  phase=boostReady and 'boostReady' or 'ready'}
 -- Own the record before any mutation, so a partial start can be rolled back.
 self.control.active=a
 if boostReady then
  self.released[role]=false
  a.anchorFeet=a.anchor.Z-h.CapsuleComponent:GetScaledCapsuleHalfHeight()
  a.helperGrab=self.base:held(h)~=false
  a.partnerGrab=self.base:held(v)~=false
 end
 if role==1 then self:freezePrimary(a)end
 h.CharacterMovement:StopMovementImmediately()
 self:clear(h,a.hc)
 h.mAnimationOverrideComponent:PlayAnimationSequenceOverride2(a.hAsset,1,true,0,.15,.15)
 self:message(boostReady and 'Salto preparado: el companero debe pulsar agarre'
  or 'Mano extendida: acerca al companero; suelta para cancelar')
end
function H:contact(a)
 local c=self.c;local h,v=a.h,a.v
 local hp,vp=h:K2_GetActorLocation(),v:K2_GetActorLocation()
 local edge,interface=self.base:ledge(v)
 if not edge and not c.state.airRescue then return end
 if not Rules.reachable(hp,vp,h:GetActorForwardVector(),v.CharacterMovement.MovementMode==3,
  edge~=nil,v:GetVelocity().Z)then return end
 if v.mAnimationControlComponent:IsPlayingOverrideAnimation()then return end
 if not edge and not self:free(v)then return end
 if not a.loggedSockets then
  a.loggedSockets=true;self.c.log('Rescate mano: consultando anclajes con FName')
 end
 local nearest
 for _,hname in ipairs(hands)do for _,vname in ipairs(hands)do
  -- Reflected NameProperty parameters require FName userdata, not Lua strings.
  local hb,vb=FName(hname),FName(vname)
  if h.Mesh:DoesSocketExist(hb)and v.Mesh:DoesSocketExist(vb)then
   local x,y=h.Mesh:GetSocketLocation(hb),v.Mesh:GetSocketLocation(vb)
   if Rules.closeHands(x,y,edge~=nil)then nearest={copy(x),copy(y)};break end
  end
 end end
 if not nearest then return end
 if not a.loggedTrace then
  a.loggedTrace=true;self.c.log('Rescate mano: comprobando obstaculos entre manos')
 end
 local capsule=h.CapsuleComponent
 if not c.live(capsule)then return end
 local blocked=not clearReach(h,v,nearest[1],nearest[2])
 if not a.loggedTraceResult then
  a.loggedTraceResult=true;c.log('Rescate mano: barrido entre manos completado; bloqueado='..tostring(blocked))
 end
 if blocked then return end
 return {edge=edge,interface=interface,at=copy(vp)}
end
function H:airClear(a,from,to)
 local capsule=a.v.CapsuleComponent
 local lib=StaticFindObject('/Script/Engine.Default__KismetSystemLibrary')
 local color={R=0,G=0,B=0,A=0}
 return not lib:CapsuleTraceSingleByProfile(a.v,from,to,
  capsule:GetScaledCapsuleRadius(),capsule:GetScaledCapsuleHalfHeight(),capsule:GetCollisionProfileName(),
  false,{a.v},0,{},true,color,color,0)
end
function H:airFloor(a,point)
 local v,h=a.v,a.h
 local z=point.Z-h.CapsuleComponent:GetScaledCapsuleHalfHeight()+v.CapsuleComponent:GetScaledCapsuleHalfHeight()
 -- Sample near the helper's foot height with the falling character's own
 -- walkability rules. The subsequent sweeps validate full capsule clearance.
 for _,offset in ipairs({6,18,-6,-18})do
  local from={X=point.X,Y=point.Y,Z=z+offset}
  local floor={}
  v.CharacterMovement:K2_FindFloor(from,floor)
  local distance=floor.bLineTrace and floor.LineDist or floor.FloorDist
  if floor.bBlockingHit and floor.bWalkableFloor and type(distance)=='number'
   and distance>=0 and distance<=24 then
   return {X=from.X,Y=from.Y,Z=from.Z-distance+3}
  end
 end
 return nil,'sin suelo transitable a la altura del ayudante'
end
function H:planAir(a)
 local h,v=a.h,a.v
 if not self.c.live(v.CapsuleComponent)or not self.c.live(h.CapsuleComponent)then return end
 local r=v.CapsuleComponent:GetScaledCapsuleRadius()
 local separation=r+h.CapsuleComponent:GetScaledCapsuleRadius()+16
 local origin=copy(v:K2_GetActorLocation())
 local reasons={}
 for i,point in ipairs(AirPath.candidates(h:K2_GetActorLocation(),h:GetActorForwardVector(),separation))do
  local target,reason=self:airFloor(a,point)
  local plan=target and AirPath.new(origin,target,r)
  if target and not plan then reason='destino fuera de alcance' end
  if plan then
   if not self:airClear(a,origin,plan.lift)then reason='tramo de elevacion bloqueado'
   elseif not self:airClear(a,plan.lift,plan.cross)then reason='tramo superior bloqueado'
   elseif not self:airClear(a,plan.cross,target)then reason='entrada al suelo bloqueada'
   else
    self.c.log('Rescate mano: destino aceptado '..i);return plan
   end
  end
  reasons[#reasons+1]=i..':'..tostring(reason)
 end
 self.c.log('Rescate mano: destinos rechazados '..table.concat(reasons,'; '))
end
function H:advanceAir(a,progress)
 if AirPath.distance2(a.h:K2_GetActorLocation(),a.anchor)>8^2 then return false,'el ayudante se desplazo' end
 local v=a.v
 if not self.c.same(a.airMovement,v.CharacterMovement)then return false,'cambio el componente de movimiento' end
 if a.airMovement.MovementMode~=5 then return false,'el juego cambio el modo a '..tostring(a.airMovement.MovementMode) end
 if not self.c.same(a.airAnim,v.Mesh:GetAnimInstance())then return false,'cambio la instancia de animacion' end
 -- Starting the override can reset extraction after capture. Reapply it
 -- only while this rescue still owns the victim's animation.
 if a.airAnim.RootMotionMode==0 and self:own(v,a.vAsset)then a.airAnim:SetRootMotionMode(1)end
 if AirPath.distance2(v:K2_GetActorLocation(),AirPath.at(a.airPlan,a.progress))>12^2 then return false,'el rescatado se salio del recorrido' end
 for _,target in ipairs(AirPath.moves(a.airPlan,a.progress,progress))do
  local from=v:K2_GetActorLocation()
  if not self:airClear(a,from,target)then return false,'el nuevo barrido encontro un obstaculo' end
  v:K2_SetActorLocation(target,true,{},false)
  local errorDistance=math.sqrt(AirPath.distance2(v:K2_GetActorLocation(),target))
  if errorDistance>4 then return false,string.format('la capsula se quedo a %.2f unidades del punto previsto',errorDistance) end
 end
 a.progress=progress;return true
end
function H:capture(a,contact,now)
 local h,v=a.h,a.v
 if contact.edge then
  self.base.selection={edge=contact.edge}
  local native=self.base:start({h=h,p=v,interface=contact.interface,helperAsset=a.assets.pull,helperLoop=false,deferPull=true})
  if not native then
   if self.base.pending then self.base:finish(self.base.pending,'inicio fallido');self.base.pending=nil end
   self:finish('No se pudo iniciar la subida del borde');return
  end
  a.native=native;self.base.control.active=native
  a.origin=contact.at;a.captured=true;a.phase='ledge';a.pullAt=now
  self.base:climb(native,{hanging=true,now=now});self.base:maintain()
  self:message('Esperando subida del borde: manten ambas teclas')
  self.c.log('Rescate mano: esperando ascenso en '..contact.edge:GetFullName()..' con ayudante P'..a.role)
  return
 end
 local duration=a.airDuration
 if not duration or not (duration>0 and duration<=8)then
  self:finish('Duracion de rescate aereo no disponible');return
 end
 self.c.log('Rescate mano: comprobando suelo transitable para P'..(3-a.role))
 a.airPlan=self:planAir(a)
 if not a.airPlan then
  self:finish('No hay una llegada despejada sobre la plataforma');return
 end
 a.progress=0
 self:freezePrimary(a)
 -- The clips contain extra time beyond the pull. Land on the beat of the
 -- assist instead of holding the victim aloft for the full clip.
 a.origin=copy(a.airPlan.origin);a.captured=true;a.phase='pull';a.pullAt=now;a.duration=math.min(duration,1.65)
 a.airAnim=v.Mesh:GetAnimInstance()
 a.previousRootMode=a.airAnim.RootMotionMode
 h.CharacterMovement:StopMovementImmediately();v.CharacterMovement:StopMovementImmediately()
 self:clear(h,a.hc);self:clear(v,a.vc)
 local hp=h:K2_GetActorLocation();local vp=v:K2_GetActorLocation()
 v:K2_SetActorRotation({Pitch=0,Yaw=math.deg(math.atan(hp.Y-vp.Y,hp.X-vp.X)),Roll=0},true)
 -- One owner of actor displacement: the checked path, not two independent
 -- animation root tracks. The helper stays at its grounded anchor.
 a.hAsset=a.assets.pull;a.vAsset=a.assets.rise
 h.mAnimationOverrideComponent:PlayAnimationSequenceOverride2(a.hAsset,1,false,0,.08,.15)
 -- NoMovement can replace the flying mode when the animation takes effect
 -- on the next frame. The rescue already gates the controls of both Monos.
 v.mAnimationOverrideComponent:PlayAnimationSequenceOverride2(a.vAsset,0,false,0,.08,.15)
 a.airMovement=v.CharacterMovement
 a.airMovement:SetMovementMode(5,0)
 a.airAnim:SetRootMotionMode(1) -- Extract/ignore root translation; path moves capsule.
 self.c.log(string.format('Rescate mano: recorrido hasta suelo; ayudante=P%d subida=%.2f destino=%.2f,%.2f,%.2f tiron=%.2f clip=%.2f',
  a.role,a.airPlan.target.Z-a.origin.Z,a.airPlan.target.X,a.airPlan.target.Y,a.airPlan.target.Z,a.duration,duration))
 self:message('Companero sujeto: manten la mano hasta terminar')
 self.c.log('Rescate mano: pareja iniciada; '..(contact.edge and 'borde' or 'caida'))
end
function H:step(blocked)
 local p,q=self.base:pair();local a=self.control.active
 for role=1,2 do if not self:held(role)then self.released[role]=true end end
 if blocked or not p then self:finish('Asistencia interrumpida');return false end
 local now=self.c.UE.GetGameplayStatics():GetTimeSeconds(p)
 if not a then
  for role=1,2 do
   if self.released[role]and self:held(role)then
    local h,v=role==1 and p or q,role==1 and q or p
    local boostReady=self.c.state.jumpAssist and h.CharacterMovement.MovementMode==1 and crouched(h)
    self:begin(h,v,role,now,boostReady)
    if self.control.active then break end
   end
  end
  return self.control.active~=nil
 end
 if a.phase~='boostReady' and not self:held(a.role)then
  self:finish('Mano soltada');self.released[a.role]=true;return false
 end
 if not(self.c.same(a.h,p)or self.c.same(a.h,q))or not(self.c.same(a.v,p)or self.c.same(a.v,q))
  or not self.c.same(a.h.Controller,a.hc)or not self.c.same(a.v.Controller,a.vc)then
  self:finish('Cambio de participantes');return false
 end
 if now<a.last or now-a.last>.25 then self:finish('Asistencia interrumpida');return false end
 a.last=now
 if a.phase=='boostReady' then
  local hp=a.h:K2_GetActorLocation()
  local dx,dy=hp.X-a.anchor.X,hp.Y-a.anchor.Y
  local dz=hp.Z-a.h.CapsuleComponent:GetScaledCapsuleHalfHeight()-a.anchorFeet
  local playing=a.h.mAnimationControlComponent:IsPlayingOverrideAnimation()
  local own=self:own(a.h,a.hAsset)
  -- The override and the crouch capsule settle on the following tick.
  -- Judge actual displacement at the feet, not the temporary mode enum.
  local starting=not a.poseSeen and now-a.since<=.2 and not playing
  if not self.c.state.jumpAssist or (not (own and playing) and not starting)
   or dx*dx+dy*dy>16^2 or math.abs(dz)>30 then
   self.c.log(string.format('Salto preparado interrumpido: modo=%s propia=%s activa=%s desplazamiento=%.1f,%.1f,%.1f',
    tostring(a.h.CharacterMovement.MovementMode),tostring(own),tostring(playing),dx,dy,dz))
   self:finish('Postura interrumpida');return false
  end
  a.poseSeen=a.poseSeen or (own and playing)
  local helperGrab,partnerGrab=self.base:held(a.h),self.base:held(a.v)
  if (self.released[a.role]and self:held(a.role))or (helperGrab==true and not a.helperGrab)then
   self:finish('Preparacion de salto cancelada');return false
  end
  self:clear(a.h,a.hc)
  if own and playing and partnerGrab==true and not a.partnerGrab then
   if self:boost(a)then return false end
   self:message('Acercate por delante y vuelve a pulsar agarre')
  end
  a.helperGrab=helperGrab~=false;a.partnerGrab=partnerGrab~=false
 elseif a.phase=='ready' then
  local hp=a.h:K2_GetActorLocation()
  if not self:own(a.h,a.hAsset)or not a.h.mAnimationControlComponent:IsPlayingOverrideAnimation()
   or (hp.X-a.anchor.X)^2+(hp.Y-a.anchor.Y)^2+(hp.Z-a.anchor.Z)^2>16 then
   self:finish('Postura interrumpida');return false
  end
  self:clear(a.h,a.hc)
  local contact=self:contact(a)
  if contact and now-a.since>=.15 then self:capture(a,contact,now)end
 elseif a.phase=='ledge' then
  local edge,interface=self.base:ledge(a.v)
  local hp,vp=a.h:K2_GetActorLocation(),a.v:K2_GetActorLocation()
  if Rules.arrived(a.origin,vp,hp,a.v.CharacterMovement.MovementMode==1)and not edge then
   self:finish('Rescate terminado');return false
  end
  if (edge and (not self.c.same(edge,a.native.nativeEdge)or not self.c.same(interface,a.native.interface)))
   or vp.Z<a.origin.Z-30 or now-a.pullAt>4 then
   self:finish(a.native.observedClimb and 'Subida interrumpida'or 'El juego no inicio la subida de este borde');return false
  end
  if a.h.mAnimationControlComponent:IsPlayingOverrideAnimation()and not self:own(a.h,a.hAsset)then
   self:finish('Animacion interrumpida');return false
  end
  if edge and self.base:held(a.v)==false then self:finish('El Mono colgado solto agarre');return false end
  self.base:climb(a.native,{hanging=edge~=nil,now=now})
  self.base:observeClimb(a.native,{now=now})
  if a.native.observedClimb and not a.native.started then
   self.base:playPull(a.native);a.hAsset=a.assets.pull
   self:message('Ayudando a subir: manten la mano')
  end
  self.base:maintain()
 elseif a.phase=='settle' then
  local done=a.v.CharacterMovement.MovementMode==1
   and AirPath.distance2(a.v:K2_GetActorLocation(),a.airPlan.target)<=12^2
  if done or now-a.settleAt>=.5 then
   self:finish(done and 'Rescate terminado'or 'Tiron terminado; llegada no confirmada');return false
  end
  self:clear(a.h,a.hc);self:clear(a.v,a.vc)
 else
  for _,entry in ipairs({{a.h,a.hAsset},{a.v,a.vAsset}})do
   if entry[1].mAnimationControlComponent:IsPlayingOverrideAnimation()and not self:own(entry[1],entry[2])then
    self:finish('Animacion interrumpida');return false
   end
  end
  self:clear(a.h,a.hc);self:clear(a.v,a.vc)
  local advanced,reason=self:advanceAir(a,math.min(1,(now-a.pullAt)/a.duration))
  if not advanced then
   self.c.log('Rescate mano: recorrido interrumpido: '..reason)
   self:finish('Recorrido de rescate bloqueado');return false
  end
  if not a.motionLogged and now-a.pullAt>=1 then
   a.motionLogged=true
   local vp=a.v:K2_GetActorLocation()
   self.c.log(string.format('Rescate mano: desplazamiento a 1s=%.2f,%.2f,%.2f root=%s modo=%s',
    vp.X-a.origin.X,vp.Y-a.origin.Y,vp.Z-a.origin.Z,
    tostring(a.airAnim and a.airAnim.RootMotionMode),tostring(a.v.CharacterMovement.MovementMode)))
  end
  if now-a.pullAt>=a.duration then
   if self:own(a.v,a.vAsset)then a.v.mAnimationOverrideComponent:StopAnimationSequenceOverride(true)end
   self:releaseAirPhysics(a)
   a.phase='settle';a.settleAt=now
   self.c.log(string.format('Rescate mano: fin aereo; altura ganada=%.2f modo=%s',
    a.v:K2_GetActorLocation().Z-a.origin.Z,tostring(a.v.CharacterMovement.MovementMode)))
  end
 end
 return true
end
function H:update(blocked)
 local ok,result=pcall(function()return self:step(blocked)end)
 if ok then return result end
 if self.base.pending then
  self.base:finish(self.base.pending,'inicio fallido');self.base.pending=nil
  self.base.control.active=nil;self.base.selection=nil
 end
 self:finish('Asistencia cancelada por error')
 self.released={false,false};self.c.log('Rescate mano: '..tostring(result));return false
end
function H:route(direction,input,yaw)
 local a=self.control.active
 if a and a.native then return self.base:route(direction,input,yaw)end
 if not a or not(self.c.same(self.c.driver.pawn,a.h)or a.captured)then return direction,input end
 return {X=0,Y=0,Z=0},{x=0,y=0,grab=false,jump=false,sneak=false,sprint=false,use=false,gadget=false}
end
return H
