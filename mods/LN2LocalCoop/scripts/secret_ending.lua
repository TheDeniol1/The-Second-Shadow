-- Final oculto «Tú y yo».
-- Condiciones: logro oculto «Ojos de más» desbloqueado, Jugar como Six activo
-- y el último golpe a la caja de música lo da P2 como Dark Six. Dark Six
-- desaparece como siempre y, en el puente final, Six sube a Mono en vez de
-- soltarlo: plano cercano de los dos, fundido a negro, el texto del final y
-- los créditos del juego.
local Secret={};Secret.__index=Secret
local tower='/Game/Levels/Transmission/PLVL_Transmission.'
local betrayal='ANIM_Player_GapHelpSixBetrayal'
local lastWake='ANIM_Player_WakeUpAfterLastHitMusicBox'
Secret.achievement='ojos_de_mas'

-- Duraciones de cada plano, en segundos.
Secret.timing={together=4.5,fade=3,card=5.5}

local function atGap(position)
 return math.abs(position.X+809)<180 and position.Y>=13750 and position.Y<=14300
  and position.Z>=28150 and position.Z<=29275
end
Secret.atGap=atGap

local function strike(name)
 return type(name)=='string' and name:find('HittingMusicBox',1,true)~=nil
end

function Secret.new(api)return setmetatable({api=api},Secret)end

-- Olvida el final en curso; armed se conserva salvo que se pida lo contrario.
function Secret:reset(disarm)
 if self.phase and self.phase~='done' then pcall(self.api.release) end
 self.phase,self.until_=nil,nil
 if disarm then self.armed=nil;self.lastHitter=nil end
end

-- Cada tick con el cooperativo activo: recuerda quién golpeó la caja de música.
-- El juego reproduce a veces el golpe en P1 aunque el hacha la lleve P2, así que
-- al empezar cada golpe cuenta quién sujeta el arma.
function Secret:observe(first,second,coop,six)
 local api=self.api
 if not (coop and six) then return end
 if api.live(first) and not first:GetFullName():find(tower,1,true) then return end
 local mine=api.live(second) and api.animation(second) or nil
 local theirs=api.live(first) and api.animation(first) or nil
 local swing=(strike(mine) or mine==lastWake) and 'P2:'..mine or (strike(theirs) and 'P1:'..theirs) or nil
 if not swing then self.swing=nil;return end
 if swing==self.swing then return end
 self.swing=swing
 local hitter=swing:sub(1,2)=='P2' and 2 or 1
 if hitter==1 and api.holdsWeapon then
  local okSecond,second_=pcall(api.holdsWeapon,second)
  local okFirst,first_=pcall(api.holdsWeapon,first)
  if okSecond and second_ and not (okFirst and first_) then hitter=2 end
 end
 if hitter==2 and self.lastHitter~=2 then api.log('Final oculto: P2 golpeo la caja de musica') end
 if hitter==1 and self.lastHitter~=1 then api.log('Final oculto: P1 golpeo la caja de musica') end
 self.lastHitter=hitter
end

-- Dark Six acaba de desaparecer tras el último golpe.
function Secret:darkSixRetired(six)
 local api=self.api
 if self.armed then return true end
 if not six then return false end
 local unlocked=api.unlocked()
 if self.lastHitter==2 and unlocked then
  self.armed=true
  api.log('Final oculto: condiciones cumplidas; Six no soltara a Mono en el puente')
 else
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
  -- Volver al menú cancela el final de esta partida.
  if self.phase then self:reset(true) end
  return
 end
 if not api.live(first) then return self.phase and 'hold' or nil end
 if paused then return self.phase and 'hold' or nil end
 local phase=self.phase
 if not phase then
  if not first:GetFullName():find(tower,1,true) then return end
  if not (atGap(first:K2_GetActorLocation()) and api.animation(first)==betrayal) then return end
  local ok,length=pcall(api.pull,first)
  if not ok or not length then
   api.log('Final oculto: no se pudo reproducir el rescate de Six: '..tostring(length))
   self:reset(true)
   return
  end
  self.first=first
  self.phase='pull'
  self.until_=now+math.max(1.65,length)+.4
  api.log('Final oculto: Six sujeta a Mono y lo sube')
  api.frame(first,0)
  return 'hold'
 end
 if not api.same(first,self.first) then
  api.log('Final oculto: el jugador cambio durante la escena; se cancela')
  self:reset(true)
  return
 end
 local timing=Secret.timing
 if phase=='pull' then
  api.frame(first,0)
  if now>=self.until_ then
   self.phase='together'
   self.startedAt=now
   self.until_=now+timing.together
   api.log('Final oculto: Six y Mono juntos en el puente')
  end
 elseif phase=='together' then
  api.frame(first,math.min(1,(now-self.startedAt)/timing.together))
  if now>=self.until_ then
   self.phase='fade'
   self.until_=now+timing.fade
   api.fade(timing.fade)
  end
 elseif phase=='fade' then
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
   self.armed=nil
   local ok,shown=pcall(api.credits)
   if ok and shown then
    api.log('Final oculto: creditos del juego')
   else
    api.log('Final oculto: no se pudieron abrir los creditos ('..tostring(shown)..'); vuelve el juego')
    pcall(api.release)
   end
  end
 end
 return 'hold'
end

return Secret
