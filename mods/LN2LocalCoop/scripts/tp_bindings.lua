local Bindings=require('coop_bindings')
local M={}
M.actions={{id='toP1',label='Jugador 2 hacia jugador 1'},{id='toP2',label='Jugador 1 hacia jugador 2'}}
local candidates={'F9','F10','F11','F12','Home','End','Insert','Delete','PageUp','PageDown'}
local listed={};for _,key in ipairs(candidates)do listed[key]=true end
for _,key in ipairs(Bindings.keys)do if not listed[key]and not Bindings.reserved[key]then candidates[#candidates+1]=key end end
function M.new(controls,data,primary)
 local function blocked(key)
  if primary and primary(key)then return 'Ya usada por el jugador 1'end
  for _,action in ipairs(controls.actions)do
   if controls.bindings[action.id]==key then return 'Ya usada para '..action.label..' del jugador 2'end
  end
 end
 local function defaults()
  local result={name='Teletransporte'};local index=1
  for _,action in ipairs(M.actions)do
   while candidates[index]and blocked(candidates[index])do index=index+1 end
   result[action.id]=assert(candidates[index],'No hay teclas libres para TP');index=index+1
  end
  return result
 end
 local self=Bindings.new(defaults(),data,{actions=M.actions,prefix='tp',blocked=blocked})
 function self:reconcile()
  local changed=false;local used={};local fallback=defaults()
  for _,action in ipairs(self.actions)do
   local key=self.bindings[action.id]
   if blocked(key)or used[key]then
    key=fallback[action.id]
    if used[key]then for _,candidate in ipairs(candidates)do if not blocked(candidate)and not used[candidate]then key=candidate;break end end end
    self.bindings[action.id]=key;changed=true
   end
   used[key]=true
  end
  if changed then self.capture=nil;self.revision=self.revision+1 end
  return changed
 end
 controls.blocked=function(key)
  for _,action in ipairs(self.actions)do if self.bindings[action.id]==key then return 'Ya usada para '..action.label end end
 end
 return self
end
return M
