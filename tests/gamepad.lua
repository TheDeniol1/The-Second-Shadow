local Pad = require('coop_gamepad')
local settings = {bOffsetPlayerGamepadIds=false}
local connected = true
local x,y,buttons,left,right = 0,0,0,0,0
local pad = Pad.new(function(slot)
 if connected and slot==0 then return x,y,buttons,left,right,0,0 end
end,function() return settings end,1,function() end)

pad:update(1,true,true,true)
pad:update(1.2,true,true,true)
assert(pad.slot==0 and not settings.bOffsetPlayerGamepadIds and not pad:input(),
 'P1 assignment keeps native input and leaves the keyboard to P2')

pad.owner=2
buttons=0x1000
pad:update(2,true,true,true)
assert(not settings.bOffsetPlayerGamepadIds and not pad:input(),
 'a held P1 button must release before P2 takes the pad')
buttons=0
pad:update(2.2,true,true,true)
pad:update(2.4,true,true,true)
assert(settings.bOffsetPlayerGamepadIds and pad:input(), 'only P2 consumes the routed pad')
x,y,buttons,left,right=32767,32767,0xf000,255,255
pad:update(2.5,true,true,true)
local input=pad:input()
assert(input.x>0 and input.y>0 and input.x^2+input.y^2<=1.000001, 'diagonal analog movement is bounded')
assert(input.jump and input.sprint and input.use and input.gadget and input.sneak and input.grab, 'P2 gets independent buttons and triggers')
buttons=0x0100;right=0;pad:update(2.55,true,true,true)
assert(pad:input().assist and not pad:input().grab,'LB offers the hand independently of RT grab')
pad:update(2.6,true,true,false)
assert(pad:input().x==0 and not pad:input().grab, 'pad input stops outside the game window')

connected=false
pad:update(3,true,true,true)
assert(not pad:input() and pad.owner==2, 'disconnect returns P2 to keyboard and retains assignment')
pad:update(4,false,true,true)
assert(not settings.bOffsetPlayerGamepadIds, 'leaving co-op restores original engine routing')
connected=true
x,y,buttons,left,right=500,-500,0,0,0
pad:update(0,true,false,true)
pad:update(.2,true,false,true)
assert(pad.slot==0 and not settings.bOffsetPlayerGamepadIds and not pad:input(),
 'a new level scans again and cannot route until a local P2 exists')
pad:update(.3,true,true,true)
pad:update(.5,true,true,true)
assert(pad:input().x==0 and pad:input().y==0, 'deadzone removes stick drift')
pad.owner=1
pad:update(.6,true,true,true)
pad:update(.8,true,true,true)
assert(not settings.bOffsetPlayerGamepadIds and not pad:input(), 'switching back restores P1 native input')
print('PASS: gamepad ownership, neutral switch, analog inputs, reconnect and keyboard fallback.')
