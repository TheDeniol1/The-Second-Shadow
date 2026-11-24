-- Registro de logros: los propios del mod y la lectura de los de Steam.
-- Steam es solo lectura: este módulo nunca desbloquea logros de la plataforma.
local M={}
M.__index=M

local function pick(text,language)
 if type(text)~='table' then return tostring(text or '') end
 return text[language] or text.es or text.en or ''
end
M.pick=pick

function M.humanize(id)
 return (tostring(id):gsub('(%l)(%u)','%1 %2'):gsub('_',' '))
end

function M.new(opts)
 opts=opts or {}
 local self=setmetatable({log=opts.log or function()end,path=opts.path,io=opts.io or io,clock=opts.clock or os.time,
  notify=opts.notify or function()end,defs=opts.defs or require('achievements_defs'),
  progress={},unlocked={},times={},byId={},byEvent={},revision=0,dirty=false},M)
 for _,d in ipairs(self.defs)do
  assert(type(d.id)=='string' and d.id:match('^[%w_]+$'),'id de logro no válido')
  assert(not self.byId[d.id],'id de logro repetido: '..d.id)
  self.byId[d.id]=d
  for _,e in ipairs(d.events or {})do
   self.byEvent[e]=self.byEvent[e] or {}
   table.insert(self.byEvent[e],d)
  end
 end
 self:load()
 return self
end

function M:target(d) return math.max(1,math.floor(tonumber(d.target) or 1)) end

function M:load()
 if not (self.path and self.io and self.io.open) then return end
 local f=self.io.open(self.path,'r')
 if not f then return end
 for line in f:lines()do
  local id,u,p,t=line:match('^([%w_]+)=([01])|([%d%.]+)|(%d*)')
  if id then
   self.unlocked[id]=u=='1'
   self.progress[id]=tonumber(p) or 0
   self.times[id]=tonumber(t)
  end
 end
 f:close()
end

function M:save()
 if not (self.path and self.io and self.io.open) then self.dirty=false return end
 local f=self.io.open(self.path,'w')
 if not f then return end
 f:write('# The Second Shadow - progreso de logros propios. Borra una linea para reiniciar ese logro.\n')
 for _,d in ipairs(self.defs)do
  local p=self.progress[d.id]
  if p or self.unlocked[d.id] then
   f:write(string.format('%s=%s|%s|%s\n',d.id,self.unlocked[d.id] and '1' or '0',
    tostring(math.floor((p or 0)*10+.5)/10),tostring(self.times[d.id] or '')))
  end
 end
 f:close()
 self.dirty=false
end

function M:unlock(d)
 if self.unlocked[d.id] then return false end
 self.unlocked[d.id]=true
 self.times[d.id]=self.clock()
 self.progress[d.id]=math.max(self.progress[d.id] or 0,self:target(d))
 self.revision=self.revision+1
 self:save()
 self.log('Logro desbloqueado: '..d.id)
 pcall(self.notify,d)
 return true
end

-- name: evento; amount: cuánto suma (1 por defecto); ctx: {coop=bool,six=bool}.
function M:event(name,amount,ctx)
 local list=self.byEvent[name]
 if not list then return 0 end
 ctx=ctx or {}
 amount=tonumber(amount) or 1
 if amount<=0 then return 0 end
 local unlockedNow=0
 for _,d in ipairs(list)do
  if not self.unlocked[d.id] and (not d.coop or ctx.coop) and (not d.six or ctx.six) then
   local before=self.progress[d.id] or 0
   local value=math.min(before+amount,self:target(d))
   self.progress[d.id]=value
   if value>=self:target(d) then
    if self:unlock(d) then unlockedNow=unlockedNow+1 end
   else
    self.dirty=true
    if math.floor(value)~=math.floor(before) then self.revision=self.revision+1 end
   end
  end
 end
 return unlockedNow
end

function M:flush() if self.dirty then self:save() end end

-- Filas listas para mostrar, en el idioma pedido.
function M:rows(language)
 local rows,done={},0
 for _,d in ipairs(self.defs)do
  local unlocked=self.unlocked[d.id]==true
  if unlocked then done=done+1 end
  local target=self:target(d)
  local p=math.min(self.progress[d.id] or 0,target)
  local progress
  if target>1 and not unlocked then
   if d.unit=='minutes' then progress=string.format('%d/%d min',math.floor(p/60),math.floor(target/60))
   else progress=string.format('%d/%d',math.floor(p),target) end
  end
  local secret=d.hidden and not unlocked
  rows[#rows+1]={id=d.id,icon=d.icon,unlocked=unlocked,progress=progress,hidden=secret,
   title=secret and (language=='en' and 'Hidden achievement' or 'Logro oculto') or pick(d.title,language),
   desc=secret and (language=='en' and 'Keep playing to discover it.' or 'Sigue jugando para descubrirlo.') or pick(d.desc,language)}
 end
 return rows,done,#self.defs
end

-- Lectura de Steam a través de un adaptador del motor:
-- engine.list() -> {{enum=,id=,name=,target=}}; engine.unlocked(enum) -> bool;
-- engine.progress(enum) -> count; engine.describe(id) -> title,desc,hidden (opcional).
function M.steamRows(engine,language)
 local rows,done={},0
 for _,a in ipairs(engine.list() or {})do
  local okU,unlocked=pcall(engine.unlocked,a.enum)
  unlocked=okU and unlocked==true
  if unlocked then done=done+1 end
  local title,desc,hidden
  if engine.describe then
   local ok,t,ds,h=pcall(engine.describe,a.id)
   if ok then title,desc,hidden=t,ds,h end
  end
  if not title or title=='' then title=M.humanize(a.name or a.id) end
  local progress
  local target=tonumber(a.target) or 0
  if target>1 and not unlocked then
   local ok,count=pcall(engine.progress,a.enum)
   if ok and tonumber(count) then progress=string.format('%d/%d',math.min(math.floor(count),target),target) end
  end
  local secret=hidden and not unlocked
  rows[#rows+1]={id=a.id,unlocked=unlocked,progress=progress,hidden=secret,
   title=secret and (language=='en' and 'Hidden achievement' or 'Logro oculto') or title,
   desc=secret and '' or (desc or '')}
 end
 return rows,done,#rows
end

return M
