-- Keyboard configuration and capture state, independent of Unreal objects.
local M={};M.__index=M
M.actions={
 {id='up',label='Avanzar / subir'}, {id='down',label='Retroceder / bajar'},
 {id='left',label='Izquierda'}, {id='right',label='Derecha'},
 {id='jump',label='Saltar'}, {id='grab',label='Agarrar'},
 {id='sneak',label='Agacharse'}, {id='sprint',label='Correr'},
 {id='use',label='Usar / lanzar'}, {id='gadget',label='Linterna / control remoto'},
 {id='call',label='Gritar / llamar'},
}
M.keys={}
local valid={}
local function key(name) M.keys[#M.keys+1]=name;valid[name]=true end
for c=65,90 do key(string.char(c))end
for _,name in ipairs({'Zero','One','Two','Three','Four','Five','Six','Seven','Eight','Nine',
 'NumPadZero','NumPadOne','NumPadTwo','NumPadThree','NumPadFour','NumPadFive','NumPadSix','NumPadSeven','NumPadEight','NumPadNine',
 'Up','Down','Left','Right','SpaceBar','Enter','Tab','BackSpace','Delete','Insert','Home','End','PageUp','PageDown',
 'LeftShift','RightShift','LeftControl','RightControl','LeftAlt','RightAlt','CapsLock','NumLock','ScrollLock','Pause',
 'Comma','Period','Semicolon','Apostrophe','Slash','Backslash','LeftBracket','RightBracket','Hyphen','Equals','Tilde',
 'Decimal','Add','Subtract','Multiply','Divide','LeftMouseButton','RightMouseButton','MiddleMouseButton','ThumbMouseButton','ThumbMouseButton2',
 'Escape'}) do key(name)end
for i=1,12 do key('F'..i)end
M.reserved={F6=true,F7=true,F8=true,Escape=true}
local extraDefaults={'M','N','B','T','G','V','C','NumPadTwo','NumPadThree','NumPadSeven','NumPadEight','NumPadNine'}
local names={SpaceBar='Espacio',Enter='Enter',BackSpace='Retroceso',Escape='Esc',
 LeftShift='Shift izq.',RightShift='Shift der.',LeftControl='Ctrl izq.',RightControl='Ctrl der.',
 LeftAlt='Alt izq.',RightAlt='Alt der.',Up='Flecha arriba',Down='Flecha abajo',Left='Flecha izq.',Right='Flecha der.',
 LeftMouseButton='Raton izquierdo',RightMouseButton='Raton derecho',MiddleMouseButton='Raton central',
 ThumbMouseButton='Raton lateral 1',ThumbMouseButton2='Raton lateral 2',Decimal='Num .',Add='Num +',Subtract='Num -',Multiply='Num *',Divide='Num /',
 Zero='0',One='1',Two='2',Three='3',Four='4',Five='5',Six='6',Seven='7',Eight='8',Nine='9'}
for i,name in ipairs({'Zero','One','Two','Three','Four','Five','Six','Seven','Eight','Nine'})do names['NumPad'..name]='Num '..(i-1)end
function M.pretty(name)return names[name] or name end
function M.new(defaults,data,options)
 options=options or {}
 local self=setmetatable({bindings={},selected=1,previous={},revision=0,
  actions=options.actions or M.actions,prefix=options.prefix or 'bind',blocked=options.blocked},M)
 assert(self.prefix:match('^[%w_]+$'),'Invalid binding namespace')
 self.actionIds={};for _,action in ipairs(self.actions)do self.actionIds[action.id]=true end
 self:reset(defaults)
 local saved={}
 for id,value in (data or ''):gmatch(self.prefix..'%.([%w_]+)=([%w]+)') do
  if self.actionIds[id] and valid[value] and not M.reserved[value]and not(self.blocked and self.blocked(value))then
   self.bindings[id]=value
   saved[id]=true
  end
 end
 -- Older preferences can already use the defaults for newer actions.
 local occupied={}
 for _,action in ipairs(self.actions)do
  local id=action.id
  if saved[id] or (id~='gadget' and id~='call') then occupied[self.bindings[id]]=true end
 end
 for value in (data or ''):gmatch('tp%.toP[12]=([%w]+)')do occupied[value]=true end
 local function available(value)
  return not occupied[value] and not M.reserved[value] and not(self.blocked and self.blocked(value))
 end
 for _,id in ipairs({'gadget','call'})do
  if self.actionIds[id] and not saved[id] then
   local current=self.bindings[id]
   if not available(current) then
    for _,candidates in ipairs({extraDefaults,M.keys}) do
     for _,value in ipairs(candidates) do
      if available(value) then self.bindings[id]=value;break end
     end
     if available(self.bindings[id]) then break end
    end
   end
   occupied[self.bindings[id]]=true
  end
 end
 -- Reject malformed duplicate saved bindings as a group, preserving defaults.
 local used={}
 for _,action in ipairs(self.actions)do
  local value=self.bindings[action.id]
  if used[value] then self:reset(defaults);break end
  used[value]=true
 end
 for _,action in ipairs(self.actions)do
  if self.bindings[action.id]~=defaults[action.id] then self.custom=true;self.bindings.name='Personalizado';break end
 end
 return self
end
function M:reset(defaults)
 for _,action in ipairs(self.actions)do self.bindings[action.id]=assert(defaults[action.id]) end
 self.bindings.name=defaults.name;self.custom=false;self.capture=nil;self.armed=false
 self.hint='Selecciona una acción y pulsa Enter';self.revision=self.revision+1
end
function M:serialize()
 local lines={}
 for _,action in ipairs(self.actions)do lines[#lines+1]=self.prefix..'.'..action.id..'='..self.bindings[action.id] end
 return table.concat(lines,'\n')..'\n'
end
function M:assign(id,name)
 if not self.actionIds[id] or not valid[name] then return false,'Tecla no reconocida' end
 if M.reserved[name] then return false,'Esa tecla se usa en el menú. Elige otra.' end
 local blocked=self.blocked and self.blocked(name)
 if blocked then return false,blocked end
 for _,action in ipairs(self.actions)do
  if action.id~=id and self.bindings[action.id]==name then return false,'Ya usada para '..action.label end
 end
 self.bindings[id]=name;self.bindings.name='Personalizado';self.custom=true
 self.hint='Guardado: '..M.pretty(name);self.revision=self.revision+1
 return true
end
function M:open(down)
 self.capture=nil;self.armed=false;self.previous={}
 for _,name in ipairs(M.keys)do self.previous[name]=down(name) or false end
 self.hint='Selecciona una acción y pulsa Enter';self.revision=self.revision+1
end
function M:beginCapture(index)
 self.selected=index
 self.capture=self.actions[index].id;self.armed=false
 self.hint='Pulsa la nueva tecla; Esc cancela';self.revision=self.revision+1
end
function M:tick(down)
 local current,any={},false
 for _,name in ipairs(M.keys)do current[name]=down(name) or false;any=any or current[name] end
 local function edge(name)return current[name] and not self.previous[name] end
 local result
 if self.capture then
  if not self.armed then
   if not any then self.armed=true end
  else
   for _,name in ipairs(M.keys)do
    if edge(name) then
     if name=='Escape' then self.capture=nil;self.hint='Cambio cancelado';self.revision=self.revision+1
     else
      local ok,hint=self:assign(self.capture,name)
      if ok then self.capture=nil;result='saved'
      else self.hint=hint;self.revision=self.revision+1 end
     end
     break
    end
   end
  end
 elseif edge('Escape') or edge('BackSpace') then result='back'
 elseif edge('Up') then self.selected=(self.selected-2)%#self.actions+1;self.revision=self.revision+1
 elseif edge('Down') then self.selected=self.selected%#self.actions+1;self.revision=self.revision+1
 elseif edge('Enter') then
  self:beginCapture(self.selected)
 end
 self.previous=current
 return result
end
return M
