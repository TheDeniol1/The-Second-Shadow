-- Phase 0 of native P2 events: report which player each Blueprint lookup of
-- GetHeliosPlayerPawn refers to. Read only; the lookup result is unchanged.
local T={};T.__index=T
local order={'p2','self2','both','p1','self1','none'}
local labels={p2='P2',self2='P2 propio',both='ambos',p1='P1',self1='P1 propio',none='ninguno'}
local interesting={p2=true,self2=true,both=true}
local function hex(n)return string.format('0x%x',n)end
local drainEvery,repeatEvery,maxLines=1,5,25

function T.new(api)
 return setmetatable({api=api,enabled=false,seen={},lines=0},T)
end

-- Names arrive innermost first: g1 function, g2 class, g3 package.
-- Each level has its FName ComparisonIndex (g1) and Number (g1n).
function T:path(entry,prefix,levels)
 local parts={}
 for i=levels,1,-1 do
  local index,number=entry[prefix..i],entry[prefix..i..'n'] or 0
  if index then
   local text=self.api.name(index) or ('#'..index)
   if number>0 then text=text..'_'..(number-1) end
   parts[#parts+1]=text
  end
 end
 if #parts==0 then return '?' end
 local path=parts[1]
 for i=2,#parts do path=path..(i==3 and ':' or '.')..parts[i] end
 return path
end

local function dominant(entry)
 local best,count='none',-1
 for _,kind in ipairs(order) do
  if (entry[kind] or 0)>count then best,count=kind,entry[kind] or 0 end
 end
 return best
end

function T:describe(entry)
 local graph=self:path(entry,'g',4)
 local actor=self:path(entry,'a',5)
 local class=self:path(entry,'c',1)
 local counts={}
 for _,kind in ipairs(order) do
  if (entry[kind] or 0)>0 then counts[#counts+1]=labels[kind]..'='..entry[kind] end
 end
 local line='Sujeto: '..labels[dominant(entry)]..' | '..graph
 if entry.code and entry.code>=0 then line=line..' @'..string.format('0x%x',entry.code) end
 line=line..' | actor '..actor..' ('..class..') | '..table.concat(counts,' ')
 if (entry.grab1 or 0)+(entry.grab2 or 0)>0 then
  line=line..' | sujeta P1='..(entry.grab1 or 0)..' P2='..(entry.grab2 or 0)
 end
 if (entry.slot1 or -1)>=0 or (entry.slot2 or -1)>=0 then
  line=line..' | ranura'..((entry.slot1 or -1)>=0 and ' P1='..hex(entry.slot1) or '')
   ..((entry.slot2 or -1)>=0 and ' P2='..hex(entry.slot2) or '')
 end
 if (entry.routed or 0)>0 then line=line..' | redirigido='..entry.routed end
 if entry.depth and entry.depth>=0 then line=line..' | frame='..entry.depth end
 local first,second
 if self.api.distances then first,second=self.api.distances(actor) end
 if first and second then line=line..string.format(' | dist P1=%d P2=%d',math.floor(first),math.floor(second)) end
 return line
end

function T:drain(now)
 local api=self.api
 local budget=maxLines
 while true do
  local entry=api.native:subjectNext()
  if not entry then break end
  local key=tostring(entry.graph)..'|'..tostring(entry.actor)
  local mark=self.seen[key]
  local score=(entry.p2 or 0)+(entry.self2 or 0)+(entry.both or 0)+(entry.grab2 or 0)+(entry.grab1 or 0)
  local report=false
  if not mark then
   mark={score=score,at=now}
   self.seen[key]=mark
   report=true
  elseif score>mark.score then
   report=now-mark.at>=repeatEvery or mark.score==0
  end
  if report and budget>0 then
   mark.score,mark.at=score,now
   budget=budget-1
   self.lines=self.lines+1
   local ok,line=pcall(self.describe,self,entry)
   api.log(ok and line or ('Sujeto: no se pudo describir una consulta: '..tostring(line)))
  elseif report then
   self.skipped=(self.skipped or 0)+1
  end
 end
end

function T:setEnabled(on,now)
 on=not not on
 if on==self.enabled then return end
 if on then
  self.enabled=self.api.native:subjectObserve(true)==true
  if self.enabled then
   self.seen,self.next,self.held1,self.held2={},nil,nil,nil
   self.api.log('Sujeto: observando consultas del jugador (solo registro)')
  end
 else
  pcall(self.drain,self,now or 0)
  self.api.native:subjectObserve(false)
  self.enabled=false
  self.api.log('Sujeto: observacion detenida')
 end
end

-- Addresses of the objects each player is holding; 0 when nothing is held.
function T:holding(first,second)
 if not self.enabled then return end
 first,second=first or 0,second or 0
 if first==self.held1 and second==self.held2 then return end
 self.held1,self.held2=first,second
 self.api.native:subjectGrabs(first,second)
end

function T:update(now)
 if not self.enabled then return end
 if self.next and now<self.next and now>=self.next-drainEvery then return end
 self.next=now+drainEvery
 self:drain(now)
end

function T:mark()
 if not self.enabled then self.api.log('Sujeto: observacion inactiva');return end
 local entries,dropped=self.api.native:subjectStats()
 self.api.log('Sujeto: '..tostring(entries)..' consultas distintas, '..tostring(dropped or 0)
  ..' descartadas, '..self.lines..' lineas, '..(self.skipped or 0)..' omitidas por limite')
end

return T
