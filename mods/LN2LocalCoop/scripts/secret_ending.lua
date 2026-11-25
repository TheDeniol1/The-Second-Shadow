-- Final oculto «Tú y yo».
-- Condiciones: logro oculto «Ojos de más» desbloqueado, Jugar como Six activo
-- y el último golpe a la caja de música lo da P2 como Dark Six. Dark Six
-- desaparece como siempre y, en el puente final, Six no suelta a Mono: lo
-- sostiene colgando unos segundos, tira de golpe y cae hacia atrás, queda de
-- rodillas y Mono la abraza. Fundido a negro, el texto del final y los créditos.
local Secret={};Secret.__index=Secret
local tower='/Game/Levels/Transmission/PLVL_Transmission.'
local betrayal='ANIM_Player_GapHelpSixBetrayal'
local lastWake='ANIM_Player_WakeUpAfterLastHitMusicBox'
Secret.achievement='ojos_de_mas'

-- Duraciones de cada plano, en segundos: agarre en suspenso, caída de Six
-- hacia atrás tras el tirón, Six de rodillas, abrazo, fundido y texto.
Secret.timing={grab=2.5,fall=1.6,kneel=1.2,together=7,fade=3.5,card=5.5}

local function atGap(position)
 return math.abs(position.X+809)<180 and position.Y>=13750 and position.Y<=14300
  and position.Z>=28150 and position.Z<=29275
end
Secret.atGap=atGap

local function strike(name)
 return type(name)=='string' and name:find('HittingMusicBox',1,true)~=nil
end

function Secret.new(api)
 local self=setmetatable({api=api},Secret)
 -- El final queda guardado: se puede cerrar el juego y volver al puente.
 local ok,saved=pcall(function() return api.restore and api.restore() end)
 self.armed=ok and saved==true or nil
 return self
end
function Secret:setArmed(on)
 self.armed=on and true or nil
 if self.api.store then pcall(self.api.store,on==true) end
end

-- Olvida el final en curso; armed se conserva salvo que se pida lo contrario.
function Secret:reset(disarm)
 if self.phase and self.phase~='done' then
  if self.api.secretRelease then pcall(self.api.secretRelease,self.first) end
  pcall(self.api.release)
 end
 self.phase,self.until_=nil,nil
 if disarm then self:setArmed(false);self.lastHitter=nil end
end

-- Cada tick con el cooperativo activo: recuerda quién golpeó la caja de música.
-- El juego reproduce a veces el golpe en P1 aunque el hacha la lleve P2, así que
-- al empezar cada golpe cuenta quién sujeta el arma.
function Secret:observe(first,second,coop,six)
 local api=self.api
 if not (coop and six) then return end
 if api.live(first) and not first:GetFullName():find(tower,1,true) then return end
 local function holds(pawn)
  if not api.holdsWeapon then return false end
  local ok,value=pcall(api.holdsWeapon,pawn)
  return ok and value==true
 end
 local firstHolds,secondHolds=holds(first),holds(second)
 -- Último que llevaba el hacha él solo (el juego puede pasarla a P1 al golpear).
 -- Misma señal que usan los eventos de P2: P2 golpea la caja con el hacha.
 local okSwing,p2Swing=pcall(function() return api.p2Swing and api.p2Swing() end)
 if okSwing and p2Swing then self.carrier=2;secondHolds=true end
 if secondHolds and not firstHolds then self.carrier=2
 elseif firstHolds and not secondHolds then self.carrier=1 end
 local mine=api.live(second) and api.animation(second) or nil
 local theirs=api.live(first) and api.animation(first) or nil
 local swing=(strike(mine) or mine==lastWake) and 'P2:'..mine or (strike(theirs) and 'P1:'..theirs) or nil
 if not swing then self.swing=nil;return end
 if swing==self.swing then return end
 self.swing=swing
 local hitter=swing:sub(1,2)=='P2' and 2 or 1
 if hitter==1 and self.carrier==2 then hitter=2 end
 api.log('Final oculto: golpe '..swing..' (hacha: P1='..tostring(firstHolds)..' P2='..tostring(secondHolds)
  ..', ultimo portador P'..tostring(self.carrier or '?')..') -> P'..hitter)
 self.lastHitter=hitter
end

-- Dark Six acaba de desaparecer tras el último golpe.
function Secret:darkSixRetired(six)
 local api=self.api
 if not six then return self.armed==true end
 local unlocked=api.unlocked()
 if self.lastHitter==2 and unlocked then
  self:setArmed(true)
  api.log('Final oculto: condiciones cumplidas; Six no soltara a Mono en el puente')
 else
  if self.lastHitter then self:setArmed(false) end
  api.log('Final oculto: no se activa (ultimo golpe de P'..tostring(self.lastHitter or '?')
   ..', logro '..(unlocked and 'conseguido' or 'pendiente')..')')
 end
 self.lastHitter=nil
 return self.armed==true
end

-- Cada tick: devuelve 'hold' mientras la escena está en marcha.
function Secret:update(first,now,playing,paused)
 local api=self.api
 if not self.armed then return end
 if not playing then
  -- Volver al menú corta la escena; el final sigue guardado para reintentar.
  if self.phase then self:reset(false) end
  return
 end
 if not api.live(first) then return self.phase and 'hold' or nil end
 if paused then return self.phase and 'hold' or nil end
 local phase=self.phase
 local timing=Secret.timing
 if not phase then
  if not first:GetFullName():find(tower,1,true) then return end
  if not (atGap(first:K2_GetActorLocation()) and api.animation(first)==betrayal) then return end
  -- Six agarra a Mono y lo deja colgando unos segundos antes de tirar.
  self.first=first
  self.phase='grab'
  self.until_=now+timing.grab
  if api.secretGrab then pcall(api.secretGrab,first) end
  api.log('Final oculto: Six agarra a Mono y lo sostiene')
  api.frame(first,0)
  return 'hold'
 end
 if not api.same(first,self.first) then
  api.log('Final oculto: el jugador cambio durante la escena; se cancela')
  self:reset(true)
  return
 end
 if phase=='grab' then
  api.frame(first,0)
  if now>=self.until_ then
   local pull=api.secretPull or api.pull
   local ok,length=pcall(pull,first)
   if not ok or not length then
    api.log('Final oculto: no se pudo reproducir el rescate de Six: '..tostring(length))
    self:reset(true)
    return
   end
   self.phase='pull'
   self.until_=now+math.max(1,length)+.1
   api.log('Final oculto: Six tira de Mono con fuerza')
  end
 elseif phase=='pull' then
  api.frame(first,0)
  if now>=self.until_ then
   local length=api.secretSixPose and api.secretSixPose('fall') or nil
   self.phase='fall'
   self.until_=now+(tonumber(length) and math.min(2.2,math.max(1,length/1.25)) or timing.fall)
   if api.secretHug then pcall(api.secretHug,first) end
   api.log('Final oculto: Six cae hacia atras con Mono en el puente')
  end
 elseif phase=='fall' then
  api.frame(first,.1)
  if now>=self.until_ then
   if api.secretSixPose then api.secretSixPose('kneel') end
   self.phase='kneel'
   self.until_=now+timing.kneel
  end
 elseif phase=='kneel' then
  api.frame(first,.15)
  if now>=self.until_ then
   self.phase='together'
   self.startedAt=now
   self.until_=now+timing.together
   api.log('Final oculto: Mono abraza a Six')
  end
 elseif phase=='together' then
  if api.hug and not api.secretHug then pcall(api.hug,first,now) end
  api.frame(first,.15+.85*math.min(1,(now-self.startedAt)/timing.together))
  if now>=self.until_ then
   self.phase='fade'
   self.until_=now+timing.fade
   api.fade(timing.fade)
  end
 elseif phase=='fade' then
  if api.hug and not api.secretHug then pcall(api.hug,first,now) end
  api.frame(first,1)
  if now>=self.until_ then
   self.phase='card'
   self.until_=now+timing.card
   api.card()
   api.log('Final oculto: Tu y yo')
  end
 elseif phase=='card' then
  if now>=self.until_ then
   self.phase='done'
   self:setArmed(false)
   local ok,shown=pcall(api.credits)
   if ok and shown then
    api.log('Final oculto: creditos del juego')
   else
    api.log('Final oculto: no se pudieron abrir los creditos ('..tostring(shown)..'); vuelve el juego')
    if api.secretRelease then pcall(api.secretRelease,first) end
    pcall(api.release)
   end
  end
 end
 return 'hold'
end

return Secret
