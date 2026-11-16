-- Regresiones de la redireccion de eventos (coop_events.lua): solo deteccion de agarre.
local Events=require('coop_events')
local anim={valid=true,mCurrentlyActiveGrabInterface=nil}
local calls={}
local api={live=function(o)return o and o.valid end,same=function(a,b)return a==b end,
 p1=function()return {Pawn={valid=true}}end,
 driver={pawn={valid=true,Mesh={valid=true,GetAnimInstance=function()return anim end}}},
 native={routeActive=function(_,on)calls[#calls+1]={active=on};return on end,
  setInteracting=function(_,on)calls[#calls+1]={interacting=on}end},
 log=function()end}
local e=Events.new(api)
-- toggle: activar instala la ruta nativa; desactivar la libera.
e:setEnabled(true)
assert(e.enabled and calls[1].active==true,'enable installs the native route')
calls={}
e:setEnabled(false)
assert(not e.enabled,'disable releases the native route')
-- interact: marca a P2 solo mientras agarra algo.
local grab={valid=true}
anim.mCurrentlyActiveGrabInterface=grab
e:interact()
assert(calls[#calls].interacting==true,'grabbing marks P2 as interacting')
anim.mCurrentlyActiveGrabInterface=nil
e:interact()
assert(calls[#calls].interacting==false,'releasing clears the mark')
print('PASS: generic event routing: interacting flag and toggle.')
