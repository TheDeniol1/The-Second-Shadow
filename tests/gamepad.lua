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

local physical={[0]={x=0,buttons=0},[1]={x=0,buttons=0}}
local dual=Pad.new(function(slot)
 local device=physical[slot]
 if device then return device.x,0,device.buttons,0,device.grab and 255 or 0,0,0 end
end,function()return settings end,3,function()end)
dual:update(10,true,false,true)
dual:update(10.15,true,false,true)
assert(dual.primarySlot==0 and not dual:input(),'a second device waits until the owned local controller is ready')
dual:update(10.2,true,true,true)
dual:update(10.35,true,true,true)
assert(dual.primarySlot==0 and dual.secondSlot==1 and not settings.bOffsetPlayerGamepadIds)
physical[0]={x=14000,buttons=0x1000,grab=true}
physical[1]={x=-14000,buttons=0x2001}
dual:update(10.45,true,true,true)
assert(dual:forRole(1).x>0 and dual:forRole(1).jump and dual:forRole(1).grab)
assert(dual:input().x<0 and not dual:input().jump and not dual:input().grab
 and dual:input().gadget and dual:input().call,'both controllers keep their own movement and buttons')
physical[1]=nil
dual:update(10.6,true,true,true)
assert(not dual:input() and dual.primarySlot==0 and dual:forRole(1).grab,
 'P2 can fall back to keyboard while P1 keeps holding the original input')

physical[2]={x=0,buttons=0x1000}
dual:update(11.2,true,true,true)
assert(not dual:input() and dual.pendingRoute,'a reconnected pad cannot inject a held jump')
physical[2].buttons=0
dual:update(11.3,true,true,true)
assert(not dual:input(),'wait for a neutral sample after reconnection')
dual:update(11.5,true,true,true)
assert(dual.secondSlot==2 and dual:input() and dual:forRole(1).grab,
 'a replacement P2 controller can connect while P1 remains in action')
physical[1]={x=0,buttons=0}
dual:update(11.8,true,true,true)
assert(dual.secondSlot==2,'do not swap a working P2 pad when another one connects')
physical[0]=nil
dual:update(12,true,true,true)
assert(not dual:forRole(1) and dual.secondSlot==2 and dual:input(),
 'when the P1 controller disconnects its partner keeps the same device')
dual:update(12.1,true,false,true)
assert(not dual:input(),'controller replacement drops raw P2 input immediately')
dual:update(12.2,false,false,true)
assert(not settings.bOffsetPlayerGamepadIds and not dual:input(),'leaving co-op restores the engine setting')
print('PASS: single and dual gamepad ownership, independent inputs, neutral reassignment and keyboard fallback.')
