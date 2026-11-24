-- Checkpoint lifecycle. Session settings belong to the caller, never to a Pawn.
local S={};S.__index=S
function S.new(api)return setmetatable({api=api,phase='off'},S)end
function S:enable(early)
 self.enabled=true;self.early=early;self.replay=early
 self.phase='waiting';self.stableAt=nil;self.primary=nil;self.pending=nil
end
function S:disable()
 if self.enabled then self.api.cancel()end
 self.enabled=false;self.phase='off';self.primary=nil;self.pending=nil;self.plan=nil
end
function S:invalidate(first)
 if not self.enabled or self.pending then return end
 self.pending={first=self.primary or first}
 if self.api.invalidate then self.api.invalidate() end
 self.api.cleanup();self.phase='waiting';self.stableAt=nil;self.replay=true;self.plan=nil
end
function S:confirmReload(first)
 if self.pending and not self.pending.confirmed and self.api.same(first,self.pending.first) then
  self.pending.confirmed=true
  return true
 end
end
function S:observe(first)
 if self.pending and self.api.live(first)and not self.api.alive(first)then self.pending.sawDeath=true end
end
function S:wake(now)
 self.wakeLength=self.api.wake(self.plan)or 0
 self.phase='waking';self.since=now
end
function S:update(first,ready,paused,intent,now)
 if not self.enabled then return false end
 local api=self.api
 self:observe(first)
 if not api.live(first)then self.stableAt=nil;return false end
 local resumed
 if self.pending then
  if not api.alive(first)then self.pending.sawDeath=true;return false end
  if self.pending.first and api.same(first,self.pending.first)
   and not (self.pending.confirmed or self.pending.sawDeath) then return false end
  self.pending=nil
  resumed=true
 end
 if not api.same(first,self.primary)then
  if self.primary then api.cleanup();self.replay=true end
  self.primary=first;self.phase='waiting';self.stableAt=nil;self.plan=nil
  if api.born then api.born(first)end
 elseif resumed and api.born then
  api.born(first)
 end
 if not ready or not api.alive(first)then self.stableAt=nil;return false end
 if paused then return false end
 if self.phase=='waiting'then
  self.stableAt=self.stableAt or now
  if now-self.stableAt<0.35 then return false end
  local plan=self.replay and api.plan(first,self.early,now)or nil
  if plan and plan.defer then return false end
  if not api.ensure()then return false end
  self.plan=plan
  self.early=false;self.replay=false
  if self.plan then
   if self.plan.intro then api.hide(true);self.phase='intro_wait'
   else api.sleep(self.plan);self.phase='sleeping';self.since=now end
  else self.phase='active'end
 end
 if not api.present()then
  self.phase='waiting';self.stableAt=nil;self.replay=true;return false
 end
 if self.phase=='intro_wait'then
  if api.primaryFinished(first,self.plan)then
   api.placeIntro(self.plan);api.hide(false);self:wake(now)
  end
 elseif self.phase=='sleeping'then
  if now-self.since>=0.35 and (intent or self.plan.immediate)then self:wake(now)end
 elseif self.phase=='waking'then
  local elapsed=now-self.since
  if elapsed>=0.15 and not api.playing()then
   if api.complete then api.complete()end
   self.phase='active';self.plan=nil
  elseif elapsed>self.wakeLength+1 then
   -- Release only our own sequence if a native completion signal is missed.
   api.cancel();self.phase='active';self.plan=nil
  end
 end
 return self.phase=='active'
end
function S:status()
 if self.phase=='sleeping'then return 'Jugador 2: pulsa una de tus teclas para levantarte'end
 if self.phase=='intro_wait'then return 'El jugador 2 está a punto de aparecer'end
 if self.phase=='waking'then return 'El jugador 2 se está levantando'end
 if self.phase=='waiting' and self.api.waitingForRoom and self.api.waitingForRoom() then
  return 'P1: busca suelo libre para el jugador 2'
 end
 return 'Cargando el punto de control'
end
return S
