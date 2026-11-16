-- Hold-to-assist controller. Native climbing retains collision and animation ownership.
local M={};M.__index=M
function M.new(api)return setmetatable({api=api},M)end
function M:cancel(reason)
 local a=self.active;self.active=nil
 if a then self.waitRelease=true;self.api.finish(a,reason)end
end
function M:update(s)
 local a=self.active
 if not s or not s.ready then self:cancel('interrumpido');return false end
 if s.held==false then self.waitRelease=nil end
 if a then
  local reason
  if s.helper~=a.helper or s.victim~=a.victim or s.edge~=a.edge then reason='cambio de participantes o borde'
  elseif not s.held then reason='agarre soltado'
  elseif s.now<a.last or s.now-a.last>0.25 then reason='salto del reloj o interrupcion prolongada'
  elseif s.now-a.since>4 then reason='la subida no se completo a tiempo' end
  if reason then
   self:cancel(reason);if s.held==false then self.waitRelease=nil end;return false
  end
  a.last=s.now
  if not s.valid then self.waitRelease=true;self:cancel(s.reason or 'fuera de alcance');return false end
  if s.done then self.waitRelease=true;self:cancel('subida terminada');return false end
  if s.now-a.since>=1 then self.api.climb(a,s)end
  return true
 end
 if self.waitRelease or not s.valid or not s.held or not s.hanging then return false end
 a=self.api.start(s)
 if not a then self.waitRelease=true;return false end
 a.helper,a.victim,a.edge,a.since,a.last=s.helper,s.victim,s.edge,s.now,s.now
 self.active=a
 return true
end
return M
