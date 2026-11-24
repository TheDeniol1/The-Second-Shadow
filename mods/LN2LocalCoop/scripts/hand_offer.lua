-- Ofrecer la mano. Una pulsacion de F1 (P1), F2 (P2) o LB extiende la mano
-- del ayudante. Si el companero entra al alcance colgado de un borde o en el
-- aire, el ayudante lo agarra y lo sube. Otra pulsacion retira la mano.
--
-- Fases: offer -> ledge (subida nativa del borde) | air (recorrido comprobado)
-- -> settle. Solo hay una ayuda a la vez.
local AirPath=require('air_rescue_path')
local PhysicalInput=require('rescue_input')
local H={};H.__index=H

local paths={
 ready='/Game/Characters/Six/Animations/ANIM_Six_GapHelpReadyLoop.ANIM_Six_GapHelpReadyLoop',
 pull='/Game/Characters/Six/Animations/ANIM_Six_GapHelpPullUp.ANIM_Six_GapHelpPullUp',
 rise='/Game/Characters/Player/Animations/ANIM_Player_GapHelpPulledUp.ANIM_Player_GapHelpPulledUp'}
-- Subida desde colgado del propio juego: la misma que se ve al subir un borde.
local climbPath='/Game/Characters/Player/Animations/ANIM_Player_ClimbObjectFromLedgeHang.ANIM_Player_ClimbObjectFromLedgeHang'
local hands={'skinned_l_handPlacement_bn','skinned_r_handPlacement_bn'}

H.limits={
 offer=10,        -- s con la mano extendida antes de retirarla sola
 grace=.25,       -- s para que la postura llegue al grafo de animacion
 anchor=25,       -- unidades que puede moverse el ayudante mientras ofrece
 reach={hang=155,air=190},  -- alcance horizontal entre actores
 hands={hang=115,air=150},  -- distancia maxima entre manos
 below={min=-40,max=230},   -- ayudante.Z - companero.Z
 front=-.2,       -- coseno minimo respecto al frente del ayudante
 ledge=4,         -- s para que el juego complete la subida del borde
 pullDelay=.35,   -- s sin subida observada antes de animar el tiron igualmente
 air=1.2,         -- s del recorrido aereo de respaldo
 grab=.25,        -- s para llevar al companero bajo las manos al agarrarlo
 climb={min=.9,max=2.2},    -- s de la subida tipo trepar (duracion del clip)
 settle=.6,       -- s para confirmar suelo al terminar
 retry=.75,       -- s entre intentos cuando no hay llegada libre
}
local L=H.limits

local function copy(v)return {X=v.X,Y=v.Y,Z=v.Z}end
local function flat(v)
 local len=math.sqrt(v.X*v.X+v.Y*v.Y)
 if len<.5 then return end
 return {X=v.X/len,Y=v.Y/len,Z=0}
end
H.copy,H.flat=copy,flat

local function smooth(t)t=math.max(0,math.min(1,t));return t*t*(3-2*t)end
local function mix(a,b,t)return {X=a.X+(b.X-a.X)*t,Y=a.Y+(b.Y-a.Y)*t,Z=a.Z+(b.Z-a.Z)*t}end

-- Reglas puras: se prueban sin motor.
function H.inReach(hp,forward,vp,hanging)
 local x,y=vp.X-hp.X,vp.Y-hp.Y
 local d2=x*x+y*y
 local r=hanging and L.reach.hang or L.reach.air
 if d2>r*r then return false end
 local dz=hp.Z-vp.Z
 if dz<L.below.min or dz>L.below.max then return false end
 if d2<1 then return true end
 local f=flat(forward)
 if not f then return false end
 return (x*f.X+y*f.Y)/math.sqrt(d2)>=L.front
end
function H.handsClose(a,b,hanging)
 local limit=hanging and L.hands.hang or L.hands.air
 return AirPath.distance2(a,b)<=limit*limit
end
function H.arrived(origin,vp,hp,grounded)
 return grounded and vp.Z>=origin.Z+20 and math.abs(vp.Z-hp.Z)<=45
  and (vp.X-hp.X)^2+(vp.Y-hp.Y)^2<=200^2
end

function H.new(c)
 local self=setmetatable({c=c,control={},prev={false,false},assetCache={}},H)
 -- Compatibilidad con main.lua: ledgeRescue.base:held(pawn) y base:ledge(pawn).
 self.base={held=function(_,pawn)return self:held(pawn)end,ledge=function(_,pawn)return self:ledge(pawn)end}
 return self
end

function H:message(text)
 self.notice=text;self.noticeUntil=self:clock()+4
 self.c.log('Mano: '..text)
end
function H:clock()return self.c.clock and self.c.clock()or os.clock()end
function H:noticeText()
 if self.notice and self:clock()<self.noticeUntil then return self.notice end
 self.notice=nil
end
function H:select()self:message('Pulsa F1 (P1), F2 (P2) o LB para ofrecer la mano')end

function H:offerHeld(role)return self.c.offerHeld and self.c.offerHeld(role)==true end

function H:secondPawn()
 local c=self.c
 if c.playpal then
  local six,controlled=c.playpal()
  if c.live(six) then return six,controlled end
 end
 return c.driver.pawn,true
end

function H:pair()
 local c=self.c;local pc=c.p1();local q=c.driver.pawn
 if not c.state.enabled or c.state.menu or c.spawn.phase~='active' or c.spawn.pending or c.death.pending
  or not pc or not c.foreground() or c.UE.GetGameplayStatics():IsGamePaused(pc)
  or not c.live(pc.Pawn) or not c.live(q) or not c.live(c.driver.pc) then return end
 local p=pc.Pawn
 if not c.world(p,q) or c.same(p,q) or not c.same(p.Controller,pc)
  or not c.same(q.Controller,c.driver.pc) or not c.same(c.driver.pc.Pawn,q)
  or not p:IsAlive() or not q:IsAlive()
  or (pc:IsMoveInputIgnored() and not self:ownsAnimation(p)) then return end
 local partner,controlled=self:secondPawn()
 if not controlled or not c.world(p,partner) or c.same(p,partner) or not partner:IsAlive() then return end
 if not c.same(partner,q) then
  local ai=partner.Controller
  if not c.live(ai) or not c.same(ai.Pawn,partner) or not c.live(ai.mBodyAnimator)
   or not c.same(ai.mBodyAnimator.mPawnSelf,partner) then return end
 end
 return p,partner
end

-- Agarre fisico de un jugador (lo usa tambien el impulso manual).
function H:held(pawn)
 local c=self.c
 if c.same(pawn,self:secondPawn())then return c.input().grab end
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

-- Borde del que cuelga el jugador: edge, interfaz y si el juego permite subir.
function H:ledge(pawn)
 local c=self.c
 if not c.live(pawn) or not c.live(pawn.Mesh)then return end
 local anim=pawn.Mesh:GetAnimInstance()
 if not c.live(anim)or not anim.mLedgeData or not anim.mLedgeData.mIsHanging then return end
 local interface=anim.mCurrentlyActiveGrabInterface
 local class=StaticFindObject('/Script/Helios.LedgeClimbingInterface')
 if not c.live(interface)or not c.live(class)or not interface:IsA(class)then return end
 local edge=interface.mCurrentLedge
 if not c.live(edge)then return end
 return edge,interface,edge:IsLedgeEnabled()and edge.mAllowClimbUpOnTop==true
end

function H:assets()
 local out={}
 for k,path in pairs(paths)do
  local asset=self.assetCache[k]
  if not self.c.live(asset)then
   asset=StaticFindObject(path)
   if not self.c.live(asset)then LoadAsset(path);asset=StaticFindObject(path)end
   if not self.c.live(asset)then error('No se pudo cargar '..path)end
   self.assetCache[k]=asset
  end
  out[k]=asset
 end
 return out
end

function H:own(pawn,asset)
 return asset~=nil and self.c.live(pawn)and self.c.live(pawn.mAnimationControlComponent)
  and self.c.same(pawn.mAnimationControlComponent.mCurrentAnimStateAsset,asset)
end

function H:ownsAnimation(pawn)
 local a=self.control.active
 if not a then return false end
 if self.c.same(pawn,a.h)then return self:own(pawn,a.hAsset)end
 return self.c.same(pawn,a.v)and a.phase~='offer'
end

function H:free(pawn)
 local c=self.c
 local ac=pawn.mAnimationControlComponent
 local anim=pawn.Mesh:GetAnimInstance()
 local pickup=pawn:GetPlayerPickupInterface()
 if ac:IsPlayingOverrideAnimation()then return false,'Espera a que termine la animacion' end
 if c.live(anim)and c.live(anim.mCurrentlyActiveGrabInterface)then return false,'Suelta lo que estas agarrando' end
 if c.live(pickup)and c.live(pickup:GetCurrentlyHeldPickup())then return false,'Deja el objeto para ofrecer la mano' end
 return true
end

function H:clear(pawn,controller)
 if self.c.live(pawn)and self.c.same(pawn.Controller,controller)and self.c.live(controller.mBodyAnimator)then
  controller.mBodyAnimator:ClearMoveInput();controller.mBodyAnimator:SetRawMoveInput({X=0,Y=0,Z=0})
 end
end

-- P1 recibe su entrada del motor. Se congela mientras participa para que su
-- mando no deshaga la postura o la subida.
function H:freezePrimary(a)
 if a.primary then return end
 local pc=self.c.p1()
 a.primary=pc;a.primaryTick=pc:IsActorTickEnabled()
 pc:SetActorTickEnabled(false)
end
function H:thawPrimary(a)
 if a.primary and self.c.live(a.primary)and self.c.same(a.primary,self.c.p1())and a.primaryTick~=nil then
  a.primary:SetActorTickEnabled(a.primaryTick)
 end
 a.primary=nil
end

function H:face(pawn,target)
 local at=pawn:K2_GetActorLocation()
 pawn:K2_SetActorRotation({Pitch=0,Yaw=math.deg(math.atan(target.Y-at.Y,target.X-at.X)),Roll=0},true)
end

function H:play(pawn,asset,loop,restriction)
 pawn.mAnimationOverrideComponent:PlayAnimationSequenceOverride2(asset,restriction or 1,loop,0,.12,.15)
end
function H:stopOwned(pawn,asset)
 if self:own(pawn,asset)then pawn.mAnimationOverrideComponent:StopAnimationSequenceOverride(true)end
end

-- Empezar a ofrecer la mano.
function H:begin(h,v,role,now)
 local c=self.c
 if h.CharacterMovement.MovementMode~=1 then
  self:message('Ponte en suelo firme para ofrecer la mano');return
 end
 local ok,reason=self:free(h)
 if not ok then self:message(reason);return end
 local loaded,assets=pcall(self.assets,self)
 if not loaded then self:message('Animaciones de la mano no disponibles');c.log('Mano: '..tostring(assets));return end
 local pull,rise=assets.pull.SequenceLength,assets.rise.SequenceLength
 local a={h=h,v=v,hc=h.Controller,vc=v.Controller,role=role,assets=assets,hAsset=assets.ready,
  anchor=copy(h:K2_GetActorLocation()),since=now,last=now,phase='offer',
  clip=type(pull)=='number'and type(rise)=='number'and math.max(pull,rise)or nil}
 self.control.active=a
 if role==1 then self:freezePrimary(a)end
 h.CharacterMovement:StopMovementImmediately()
 self:clear(h,a.hc)
 self:play(h,a.hAsset,true)
 self:message('P'..role..' ofrece la mano')
 return true
end

-- El companero esta al alcance: colgado o en el aire, delante y con las manos cerca.
function H:contact(a)
 local c=self.c;local h,v=a.h,a.v
 local edge,interface,climbable=self:ledge(v)
 local falling=v.CharacterMovement.MovementMode==3
 if not edge and not (falling and c.state.airRescue~=false)then return end
 local hp,vp=h:K2_GetActorLocation(),v:K2_GetActorLocation()
 if not H.inReach(hp,h:GetActorForwardVector(),vp,edge~=nil)then return end
 if v.mAnimationControlComponent:IsPlayingOverrideAnimation()and not edge then return end
 local best,bestDistance
 for _,hn in ipairs(hands)do for _,vn in ipairs(hands)do
  local hb,vb=FName(hn),FName(vn)
  if h.Mesh:DoesSocketExist(hb)and v.Mesh:DoesSocketExist(vb)then
   local x,y=h.Mesh:GetSocketLocation(hb),v.Mesh:GetSocketLocation(vb)
   local d=AirPath.distance2(x,y)
   if H.handsClose(x,y,edge~=nil)and (not bestDistance or d<bestDistance)then best,bestDistance={copy(x),copy(y)},d end
  end
 end end
 if not best then return end
 -- Sin paredes entre las manos. Barrido fino con el perfil del ayudante.
 local lib=StaticFindObject('/Script/Engine.Default__KismetSystemLibrary')
 local color={R=0,G=0,B=0,A=0}
 if lib:CapsuleTraceSingleByProfile(h,best[1],best[2],1,1,h.CapsuleComponent:GetCollisionProfileName(),
  false,{h,v},0,{},true,color,color,0)then return end
 return {edge=edge,interface=interface,climbable=climbable,at=copy(vp)}
end

-- Llegada aerea: suelo transitable junto al ayudante y recorrido libre.
function H:sweepClear(a,from,to)
 local capsule=a.v.CapsuleComponent
 local lib=StaticFindObject('/Script/Engine.Default__KismetSystemLibrary')
 local color={R=0,G=0,B=0,A=0}
 return not lib:CapsuleTraceSingleByProfile(a.v,from,to,capsule:GetScaledCapsuleRadius(),
  capsule:GetScaledCapsuleHalfHeight(),capsule:GetCollisionProfileName(),false,{a.v},0,{},true,color,color,0)
end
function H:floorAt(a,point)
 local v,h=a.v,a.h
 local z=point.Z-h.CapsuleComponent:GetScaledCapsuleHalfHeight()+v.CapsuleComponent:GetScaledCapsuleHalfHeight()
 for _,offset in ipairs({6,18,30,-6,-18,-30})do
  local from={X=point.X,Y=point.Y,Z=z+offset}
  local floor={}
  v.CharacterMovement:K2_FindFloor(from,floor)
  local distance=floor.bLineTrace and floor.LineDist or floor.FloorDist
  if floor.bBlockingHit and floor.bWalkableFloor and type(distance)=='number'and distance>=0 and distance<=40 then
   return {X=from.X,Y=from.Y,Z=from.Z-distance+3}
  end
 end
end
function H:planAir(a)
 local h,v=a.h,a.v
 local r=v.CapsuleComponent:GetScaledCapsuleRadius()
 local separation=r+h.CapsuleComponent:GetScaledCapsuleRadius()+16
 local origin=copy(v:K2_GetActorLocation())
 local hp=h:K2_GetActorLocation()
 local points=AirPath.candidates(hp,h:GetActorForwardVector(),separation)
 -- El sitio del propio ayudante, un paso por detras, siempre tiene suelo.
 local f=flat(h:GetActorForwardVector())
 if f then points[#points+1]={X=hp.X-f.X*separation*1.8,Y=hp.Y-f.Y*separation*1.8,Z=hp.Z}end
 local reasons={}
 for i,point in ipairs(points)do
  local target=self:floorAt(a,point)
  local plan=target and AirPath.new(origin,target,r)
  local reason=not target and 'sin suelo' or (not plan and 'fuera de alcance')
  if plan then
   if not self:sweepClear(a,origin,plan.lift)then reason='elevacion bloqueada'
   elseif not self:sweepClear(a,plan.lift,plan.cross)then reason='paso superior bloqueado'
   elseif not self:sweepClear(a,plan.cross,target)then reason='llegada bloqueada'
   else return plan end
  end
  reasons[#reasons+1]=i..':'..reason
 end
 self.c.log('Mano: sin llegada libre ('..table.concat(reasons,'; ')..')')
end

-- Subida tipo trepar: un agarre corto deja al companero colgando bajo el
-- borde; despues sube casi en vertical y entra encima al final, como la
-- subida nativa desde colgado.
function H.climbAt(p,t)
 if t<=p.split then return mix(p.origin,p.hang,smooth(t/p.split))end
 local u=(t-p.split)/(1-p.split)
 local up=smooth(u/.6)
 local over=smooth((u-.5)/.5)
 local z=p.hang.Z+(p.target.Z+6-p.hang.Z)*up-6*smooth((u-.85)/.15)
 return {X=p.hang.X+(p.target.X-p.hang.X)*over,Y=p.hang.Y+(p.target.Y-p.hang.Y)*over,Z=z}
end
function H.climbMoves(p,from,to)
 local out={}
 local steps=math.max(1,math.ceil((to-from)/.05))
 for i=1,steps do out[i]=H.climbAt(p,from+(to-from)*i/steps)end
 return out
end

function H:climbAsset(v)
 local c=self.c
 local asset
 pcall(function()
  local class=StaticFindObject('/Script/Helios.LedgeClimbingInterface')
  local interface=c.live(class)and v:GetComponentByClass(class)
  local params=c.live(interface)and interface.mClimbFromHangParams
  if params and c.live(params.mAnimation)then asset=params.mAnimation end
 end)
 if c.live(asset)then return asset end
 asset=self.assetCache.climb
 if not c.live(asset)then
  asset=StaticFindObject(climbPath)
  if not c.live(asset)then pcall(LoadAsset,climbPath);asset=StaticFindObject(climbPath)end
  if not c.live(asset)then return end
  self.assetCache.climb=asset
 end
 return asset
end

-- Llegada: al lado del ayudante por donde viene el companero y un paso hacia
-- dentro, para no acabar haciendo equilibrio en el filo. Al colgar se queda
-- lo mas cerca posible de donde se le agarro; el resto del paso lateral se
-- hace al pasar por encima del borde.
function H:planClimb(a)
 local h,v=a.h,a.v
 local r=v.CapsuleComponent:GetScaledCapsuleRadius()
 local hh=v.CapsuleComponent:GetScaledCapsuleHalfHeight()
 local separation=r+h.CapsuleComponent:GetScaledCapsuleRadius()+10
 local origin=copy(v:K2_GetActorLocation())
 local hp=h:K2_GetActorLocation()
 -- El frente del ayudante marca hacia donde da el borde.
 local out=flat(h:GetActorForwardVector())or flat({X=origin.X-hp.X,Y=origin.Y-hp.Y})
 if not out then return end
 local side={X=-out.Y,Y=out.X,Z=0}
 local function along(p,d)return (p.X-hp.X)*d.X+(p.Y-hp.Y)*d.Y end
 local lateral,ahead=along(origin,side),along(origin,out)
 local first=lateral<0 and -1 or 1
 for _,sign in ipairs({first,-first})do
  for _,back in ipairs({.6,.3,0})do
   local point={X=hp.X-out.X*back*separation+side.X*sign*separation,
    Y=hp.Y-out.Y*back*separation+side.Y*sign*separation,Z=hp.Z}
   local target=self:floorAt(a,point)
   if target then
    local drop=math.max(hh*1.2,math.min(hh*2.6,target.Z-origin.Z))
    local tl,ta=along(target,side),along(target,out)
    for _,k in ipairs({.6,.3,0})do
     for _,gap in ipairs({r+8,r+24,r+44,ahead})do
      local l=tl+(lateral-tl)*k
      local hang={X=hp.X+out.X*gap+side.X*l,Y=hp.Y+out.Y*gap+side.Y*l,Z=target.Z-drop}
      if gap>=r+8 and gap>ta and AirPath.distance2(origin,hang)<=120^2 then
       local plan={kind='climb',origin=origin,hang=hang,target=target,split=.15,out=out}
       local from,clear=origin,true
       for i=1,16 do
        local to=H.climbAt(plan,i/16)
        if not self:sweepClear(a,from,to)then clear=false;break end
        from=to
       end
       if clear then return plan end
      end
     end
    end
   end
  end
 end
end

-- Agarrar.
function H:catch(a,contact,now)
 local c=self.c;local h,v=a.h,a.v
 self:freezePrimary(a)
 if contact.edge and contact.climbable then
  local direction=flat(v:GetActorForwardVector())
  if not direction then return end
  self:face(h,contact.at)
  a.phase='ledge';a.since=now;a.edge=contact.edge;a.interface=contact.interface
  a.origin=contact.at;a.direction=direction
  self:stopOwned(h,a.hAsset)
  a.hAsset=nil
  self:message('P'..a.role..' agarra a P'..(3-a.role)..' y lo sube')
  c.log('Mano: subida de borde en '..contact.edge:GetFullName())
  return true
 end
 if now<(a.retryAt or 0)then return end
 local climb=self:climbAsset(v)
 local plan=climb and self:planClimb(a)
 local duration
 if plan then
  local len=climb.SequenceLength
  duration=math.max(L.climb.min,math.min(L.climb.max,type(len)=='number'and len or 1.4))
  plan.split=math.min(.3,L.grab/duration)
 else
  local clip=a.clip
  if clip and clip>0 and clip<=8 then plan=self:planAir(a);duration=math.min(clip,L.air)end
 end
 if not plan then
  a.retryAt=now+L.retry
  if not a.warned then a.warned=true;self:message('No hay sitio para subir al companero aqui')end
  return
 end
 if contact.edge then
  -- Borde sin subida propia: se suelta el agarre y lo sube el recorrido.
  contact.interface:ReleaseGrab(0)
 end
 a.phase='air';a.since=now;a.plan=plan;a.progress=0;a.origin=copy(plan.origin)
 a.duration=duration
 h.CharacterMovement:StopMovementImmediately();v.CharacterMovement:StopMovementImmediately()
 self:clear(h,a.hc);self:clear(v,a.vc)
 self:face(h,contact.at)
 if plan.kind=='climb' then self:face(v,plan.target)else self:face(v,h:K2_GetActorLocation())end
 a.hAsset,a.vAsset=a.assets.pull,plan.kind=='climb'and climb or a.assets.rise
 self:play(h,a.hAsset,false)
 self:play(v,a.vAsset,false,0)
 a.movement=v.CharacterMovement;a.movement:SetMovementMode(5,0) -- Flying: el recorrido mueve la capsula.
 a.anim=v.Mesh:GetAnimInstance();a.rootMode=a.anim.RootMotionMode
 a.anim:SetRootMotionMode(1) -- Ignorar la traslacion de la animacion.
 self:message('P'..a.role..' agarra a P'..(3-a.role)..' en el aire')
 if plan.kind=='climb' then
  local rm;pcall(function()rm=climb.bEnableRootMotion end)
  c.log(string.format('Mano: subida tipo trepar a %.0f,%.0f,%.0f en %.2fs (%s, root motion %s)',plan.target.X,plan.target.Y,plan.target.Z,
   a.duration,tostring(climb.GetFullName and climb:GetFullName()or climb.name),tostring(rm)))
 else
  c.log(string.format('Mano: recorrido aereo a %.0f,%.0f,%.0f en %.2fs',plan.target.X,plan.target.Y,plan.target.Z,a.duration))
 end
 return true
end

function H:releaseAir(a,landed)
 local c=self.c
 if a.anim then
  if c.live(a.v)and c.live(a.anim)and c.same(a.v.Mesh:GetAnimInstance(),a.anim)and a.anim.RootMotionMode==1 then
   a.anim:SetRootMotionMode(a.rootMode)
  end
  a.anim=nil
 end
 if a.movement then
  if c.live(a.v)and c.same(a.v.CharacterMovement,a.movement)and a.movement.MovementMode==5 then
   a.movement:SetMovementMode(landed and 1 or 3,0)
  end
  a.movement=nil
 end
end

function H:finish(reason)
 local a=self.control.active
 if not a then return end
 self.control.active=nil
 local function clean(label,fn)
  local ok,err=pcall(fn)
  if not ok then self.c.log('Mano: limpieza '..label..': '..tostring(err))end
 end
 clean('ayudante',function()self:clear(a.h,a.hc)end)
 clean('companero',function()if a.phase~='offer' then self:clear(a.v,a.vc)end end)
 clean('animacion',function()
  for _,asset in ipairs({a.assets.ready,a.assets.pull})do self:stopOwned(a.h,asset)end
  if a.vAsset then self:stopOwned(a.v,a.vAsset)end
 end)
 clean('fisica',function()self:releaseAir(a)end)
 clean('P1',function()self:thawPrimary(a)end)
 if reason then self:message(reason)end
end
function H:reset()self:finish(nil);self.prev={false,false}end
function H:interrupt(blocked)
 if not self.control.active then return end
 local ok,p=pcall(function()if not blocked then return self:pair()end end)
 if not ok or not p then self:finish('Ayuda de la mano interrumpida')end
end

-- Un tick de la fase activa. Devuelve false al terminar.
function H:advance(a,now)
 local c=self.c;local h,v=a.h,a.v
 if a.phase=='offer' then
  local posed=self:own(h,a.hAsset)and h.mAnimationControlComponent:IsPlayingOverrideAnimation()
  -- Durante la postura el juego pone al ayudante en None (0) o Custom (6).
  -- Solo cuenta caer (Falling, 3) o desplazarse de verdad.
  local mode=h.CharacterMovement.MovementMode
  local moved=math.sqrt(AirPath.distance2(h:K2_GetActorLocation(),a.anchor))
  if moved>L.anchor or mode==3 then
   c.log(string.format('Mano: ayudante desplazado %.1f, modo %s',moved,tostring(mode)))
   self:finish('Mano retirada');return false
  end
  if posed then a.posed=true
  elseif a.posed or now-a.since>L.grace then
   c.log('Mano: la postura fue reemplazada por '..tostring(h.mAnimationControlComponent.mCurrentAnimStateAsset and h.mAnimationControlComponent.mCurrentAnimStateAsset:GetFullName()))
   self:finish('Mano retirada');return false
  end
  if now-a.since>L.offer then self:finish('Nadie tomo la mano');return false end
  self:clear(h,a.hc)
  if posed then
   local contact=self:contact(a)
   if contact then self:catch(a,contact,now)end
  end
  return true
 end
 if a.phase=='ledge' then
  local edge,interface=self:ledge(v)
  local hp,vp=h:K2_GetActorLocation(),v:K2_GetActorLocation()
  if not edge and H.arrived(a.origin,vp,hp,v.CharacterMovement.MovementMode==1)then
   self:finish('Companero a salvo');return false
  end
  if not edge and v.CharacterMovement.MovementMode==3 then
   -- Se solto durante la subida: si sigue al alcance, se agarra en el aire.
   a.phase='offer';a.hAsset=a.assets.ready;a.posed=true
   local contact=self:contact(a)
   if contact and self:catch(a,contact,now)then return true end
   self:finish('El companero se solto');return false
  end
  if (edge and not c.same(edge,a.edge))or vp.Z<a.origin.Z-40 then self:finish('Subida interrumpida');return false end
  if now-a.since>L.ledge then self:finish('El juego no permitio subir por este borde');return false end
  if not a.hAsset and ((c.live(interface)and interface.mGrabbingState==4)or now-a.since>=L.pullDelay)then
   a.hAsset=a.assets.pull;self:play(h,a.hAsset,false)
  end
  self:clear(h,a.hc)
  self:drive(a)
  return true
 end
 if a.phase=='air' then
  if AirPath.distance2(h:K2_GetActorLocation(),a.anchor)>L.anchor^2 then self:finish('El ayudante se movio');return false end
  if not c.same(a.movement,v.CharacterMovement)or a.movement.MovementMode~=5 then self:finish('Subida interrumpida');return false end
  if a.anim and a.anim.RootMotionMode==0 and self:own(v,a.vAsset)then a.anim:SetRootMotionMode(1)end
  self:clear(h,a.hc);self:clear(v,a.vc)
  local progress=math.min(1,(now-a.since)/a.duration)
  local moves=a.plan.kind=='climb'and H.climbMoves(a.plan,a.progress,progress)or AirPath.moves(a.plan,a.progress,progress)
  for _,target in ipairs(moves)do
   if not self:sweepClear(a,v:K2_GetActorLocation(),target)then self:finish('Algo bloqueo la subida');return false end
   v:K2_SetActorLocation(target,true,{},false)
   if AirPath.distance2(v:K2_GetActorLocation(),target)>6^2 then self:finish('Algo bloqueo la subida');return false end
  end
  a.progress=progress
  if progress>=1 then
   self:stopOwned(v,a.vAsset)
   -- La subida termina de pie sobre el borde: se camina, sin caida ni aterrizaje.
   self:releaseAir(a,a.plan.kind=='climb')
   a.phase='settle';a.since=now
  end
  return true
 end
 -- settle
 local done=v.CharacterMovement.MovementMode==1 and AirPath.distance2(v:K2_GetActorLocation(),a.plan.target)<=16^2
 if done or now-a.since>=L.settle then self:finish(done and 'Companero a salvo'or 'Subida terminada');return false end
 self:clear(h,a.hc);self:clear(v,a.vc)
 return true
end

-- La subida del borde la hace el juego: basta con empujar hacia el borde.
function H:drive(a)
 local c=self.c;local v,vc=a.v,a.vc
 if not (c.live(v)and c.same(v.Controller,vc)and c.live(vc.mBodyAnimator))then return end
 local d=a.direction
 vc.mBodyAnimator:SetMoveInput(d)
 local yaw=math.rad(c.cameraYaw and c.cameraYaw(v)or 0)
 vc.mBodyAnimator:SetRawMoveInput({X=math.cos(yaw)*d.X+math.sin(yaw)*d.Y,Y=-math.sin(yaw)*d.X+math.cos(yaw)*d.Y,Z=0})
end

function H:step(blocked)
 local c=self.c
 local pressed={}
 for role=1,2 do
  local held=self:offerHeld(role)
  pressed[role]=held and not self.prev[role]
  self.prev[role]=held
 end
 local a=self.control.active
 local p,q=self:pair()
 if blocked or not p then
  if a then self:finish('Ayuda de la mano interrumpida')end
  return false
 end
 local now=c.UE.GetGameplayStatics():GetTimeSeconds(p)
 if a then
  if not ((c.same(a.h,p)and c.same(a.v,q))or(c.same(a.h,q)and c.same(a.v,p)))
   or not c.same(a.h.Controller,a.hc)or not c.same(a.v.Controller,a.vc)then
   self:finish('Cambio de participantes');return false
  end
  if now<a.last or now-a.last>.25 then self:finish('Ayuda de la mano interrumpida');return false end
  a.last=now
  if pressed[a.role]and a.phase=='offer' then c.log('Mano: tecla pulsada de nuevo');self:finish('Mano retirada');return false end
  return self:advance(a,now)
 end
 for role=1,2 do
  if pressed[role]then
   local h,v=role==1 and p or q,role==1 and q or p
   if self:begin(h,v,role,now)then return true end
  end
 end
 return false
end

function H:update(blocked)
 local ok,result=pcall(self.step,self,blocked)
 if ok then return result end
 self:finish('Ayuda de la mano cancelada por un error')
 self.c.log('Mano: '..tostring(result))
 return false
end

-- P2 no se mueve mientras ofrece ni mientras lo suben. En la subida del borde
-- se le empuja hacia el borde y se mantiene su agarre.
function H:route(direction,input,yaw)
 local a=self.control.active
 if not a then return direction,input end
 local c=self.c;local partner=self:secondPawn()
 local helper=c.same(partner,a.h)
 local victim=c.same(partner,a.v)and a.phase~='offer'
 if not helper and not victim then return direction,input end
 local d={X=0,Y=0,Z=0}
 if victim and a.phase=='ledge' then d=a.direction end
 local angle=math.rad(yaw)
 return d,{x=-math.sin(angle)*d.X+math.cos(angle)*d.Y,y=math.cos(angle)*d.X+math.sin(angle)*d.Y,
  grab=victim and a.phase=='ledge' or false,jump=false,sneak=false,sprint=false,use=false,gadget=false,call=false}
end

return H
