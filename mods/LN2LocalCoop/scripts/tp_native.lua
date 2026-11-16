-- Teleport only the two owned Monos. Puzzle state and Six are never modified.
local N={};N.__index=N
function N.new(c)return setmetatable({c=c,emitters={}},N)end
function N:primaryKeys()
 if self.primary then return self.primary end
 local used,actions={},{ }
 for _,key in ipairs({'W','A','S','D','SpaceBar','LeftShift','LeftControl','LeftMouseButton','RightMouseButton'})do used[key]=true end
 local ok=pcall(function()
  local settings=StaticFindObject('/Script/Engine.Default__InputSettings')
  for _,group in ipairs({'ActionMappings','AxisMappings'})do
   local mappings=settings[group]
   for i=1,#mappings do
    local key=mappings[i].Key.KeyName:ToString();used[key]=true
    if group=='ActionMappings'then actions[key]=true end
   end
  end
 end)
 if not ok then for _,key in ipairs({'SpaceBar','LeftShift','LeftControl','LeftMouseButton','RightMouseButton'})do actions[key]=true end end
 self.primary,self.primaryActions=used,actions
 return used
end
function N:players()
 local c=self.c;local pc=c.p1()
 if not c.state.enabled or c.spawn.phase~='active'or c.spawn.pending or c.death.pending then return nil,nil,'Espera a que ambos jugadores estén listos'end
 if not pc or c.state.menu or c.UE.GetGameplayStatics():IsGamePaused(pc)or pc:IsMoveInputIgnored()then return nil,nil,'No pueden reunirse durante una pausa o escena'end
 local a,b=pc.Pawn,c.driver.pawn;local second=c.driver.pc
 if not(c.live(a)and c.live(b)and c.live(second)and c.live(second.Player))then return nil,nil,'Activa primero al jugador 2'end
 if not a:GetFullName():find('BP_PlayerPawn_C',1,true)or not b:GetFullName():find('BP_PlayerPawn_C',1,true)then return nil,nil,'Esperando a los dos Monos'end
 if c.same(a,b)or second.Player.ControllerId~=1 or not c.same(second.Pawn,b)or not c.same(b.Controller,second)
  or not c.same(a.Controller,pc)or not c.world(a,b)then return nil,nil,'Esperando a los personajes de esta zona'end
 return a,b
end
function N:blocked(p)
 local c=self.c
 if not p:IsAlive()then return 'Espera a que ambos jugadores vuelvan a la partida'end
 if not c.live(p.CharacterMovement)or p.CharacterMovement.MovementMode~=1 then return 'Ambos deben estar sobre suelo firme'end
 local ac=p.mAnimationControlComponent
 if not c.live(ac)or ac:IsPlayingOverrideAnimation()then return 'Espera a que termine la acción'end
 local anim=p.Mesh:GetAnimInstance()
 if not c.live(anim)or c.live(anim.mCurrentlyActiveGrabInterface)then return 'Suelta lo que estés agarrando antes de reunirte'end
 local pickup=p:GetPlayerPickupInterface()
 if c.live(pickup)then
  local item=pickup:GetCurrentlyHeldPickup()
  if c.live(item)and c.same(item:GetHolderIfHeld(),p)then return 'Deja el objeto antes de reunirte'end
 end
 local pc=c.p1()
 if c.same(p,c.driver.pawn)then
  local input=c.input()
  if input.jump or input.grab or input.use or input.sneak or input.sprint then return 'Jugador 2: suelta los controles antes de reunirte'end
 else
  self:primaryKeys()
  for key in pairs(self.primaryActions)do
   if pc:IsInputKeyDown({KeyName=FName(key)})then return 'Jugador 1: suelta los controles antes de reunirte'end
  end
 end
end
function N:clear(mover,target,destination,endLocation)
 local c=self.c;local capsule=mover.CapsuleComponent
 if not c.live(capsule)then return false end
 local lib=StaticFindObject('/Script/Engine.Default__KismetSystemLibrary')
 local finish=endLocation or {X=destination.X,Y=destination.Y,Z=destination.Z+0.1}
 local hit={};local color={R=0,G=0,B=0,A=0}
 return not lib:CapsuleTraceSingleByProfile(mover,destination,finish,
  capsule:GetScaledCapsuleRadius(),capsule:GetScaledCapsuleHalfHeight(),capsule:GetCollisionProfileName(),
  false,{mover,target},0,hit,true,color,color,0)
end
function N:prepareEffects()
 if self.prepared then return end;self.prepared=true
 local function asset(path)
  local value=StaticFindObject(path)
  if not self.c.live(value)then
   local ok=pcall(LoadAsset,path)
   if ok then value=StaticFindObject(path)end
  end
  if self.c.live(value)then return value end
 end
 self.particles=asset('/Game/Environment/Effects/Particles/ThinmanEffects/P_Thinman_TeleportIn01.P_Thinman_TeleportIn01')
 self.sound=asset('/Game/Audio/Events/Objects/Electric/TVs/ChapterSelect/Play_TV_ChapterSelect_ChangeChannel.Play_TV_ChapterSelect_ChangeChannel')
end
function N:effects(p,origin,destination,now)
 local c=self.c
 if not c.state.tp.effects then return end
 c.state.tp.flashUntil=now+0.2
 self:prepareEffects()
 local rotation={Pitch=0,Yaw=0,Roll=0}
 if c.live(self.particles)then
  for _,at in ipairs({origin,destination})do
   local fx=c.UE.GetGameplayStatics():SpawnEmitterAtLocation(p,self.particles,at,rotation,{X=.35,Y=.35,Z=.35},true,0,true)
   if c.live(fx)then self.emitters[#self.emitters+1]={object=fx,untilTime=now+.7}end
  end
 end
 if c.live(self.sound)then
  StaticFindObject('/Script/AkAudio.Default__AkGameplayStatics'):PostEventAtLocation(self.sound,destination,rotation,'',p)
 end
end
function N:update(now)
 if self.lastNow and now<self.lastNow then self.c.state.tp.flashUntil=0;self.prepared=nil end
 self.lastNow=now
 for i=#self.emitters,1,-1 do
  local entry=self.emitters[i]
  if not self.c.live(entry.object)then table.remove(self.emitters,i)
  elseif now>=entry.untilTime then pcall(function()entry.object:DeactivateSystem()end);table.remove(self.emitters,i)end
 end
 local tp=self.c.state.tp
 tp.flashFrame=tp.effects and now<(tp.flashUntil or 0)and math.floor(now*24)or nil
end
function N:api()
 local self,c=self,self.c
 return {clock=function()local pc=c.p1();return pc and c.UE.GetGameplayStatics():GetRealTimeSeconds(pc)or os.clock()end,
  log=c.log,players=function()return self:players()end,
  blocked=function(p)return self:blocked(p)end,location=function(p)return p:K2_GetActorLocation()end,
  clear=function(a,b,at)return self:clear(a,b,at)end,
  move=function(p,at)
   if c.same(p,c.driver.pawn)then c.driver:stop()end
   p.CharacterMovement:StopMovementImmediately()
   return p:K2_SetActorLocation(at,false,{},true)
  end,
  effects=function(...)return self:effects(...)end}
end
return N
