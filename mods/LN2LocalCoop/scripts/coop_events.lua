-- Redireccion de eventos: cuando P2 esta agarrando algo, GetHeliosPlayerPawn
-- se redirige a P2 para que los scripts de nivel actuen sobre el jugador correcto.
-- El escaneo de "jugador mas cercano" (FindAllOf por clase) se retiro: era costoso
-- y no cubria las trampas. Solo queda la deteccion de agarre, que es barata.
local E={};E.__index=E
function E.new(api)
 return setmetatable({api=api,enabled=false,holding=false},E)
end
function E:interact()
 local holding=false
 local second=self.api.driver and self.api.driver.pawn
 if self.api.live(second) and self.api.live(second.Mesh) then
  local anim=second.Mesh:GetAnimInstance()
  local iface=self.api.live(anim) and anim.mCurrentlyActiveGrabInterface
  holding=self.api.live(iface) and true or false
 end
 if holding~=self.holding then
  self.holding=holding
  self.api.native:setInteracting(holding)
 end
end
function E:setEnabled(on)
 if on==self.enabled then return end
 if on then
  self.enabled=self.api.native:routeActive(true)
  if not self.enabled then return end
 else
  self.enabled=false
  self.holding=false
  self.api.native:setInteracting(false)
  self.api.native:routeActive(false)
 end
end
function E:mark()
 self.api.log('Eventos P2: '..(self.enabled and 'activo (redirige al jugador que agarra)' or 'desactivado'))
end
return E
