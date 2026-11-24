local Call=require('coop_call')
local function pawn()
 local gesture={mFlowControlComponent={},mGestureData={mIsGesturing=false},starts=0,stops=0}
 function gesture:TryStartGesturing()
  self.starts=self.starts+1
  self.mGestureData.mIsGesturing=not self.blocked
 end
 function gesture:StopGesturing()
  self.stops=self.stops+1
  self.mGestureData.mIsGesturing=false
 end
 return {GestureInterface=gesture}
end
local first,second=pawn(),pawn()
local p1,p2=first.GestureInterface,second.GestureInterface
local call=Call.new(function(value)return value~=nil end,function(a,b)return a~=nil and a==b end,function()end)
p1.mGestureData.mIsGesturing=true
assert(call:observe(first,second)==1 and p1.starts==0,'P1 native gesture signals without a duplicate input')
assert(not call:observe(first,second),'held gesture is signaled once')
call:input(second,true)
call:input(second,true)
assert(p2.starts==1 and call:observe(first,second)==2,'P2 starts its own native call once')
call:input(second,false)
assert(p2.stops==1 and not p2.mGestureData.mIsGesturing,'releasing the button ends the owned action')
call:observe(first,second)
p2.blocked=true
call:input(second,true)
assert(not call:observe(first,second),'an ignored start produces no indicator')
call:input(second,false)
p2.blocked=false
call:input(second,true)
call:observe(nil,nil)
assert(not p2.mGestureData.mIsGesturing,'pause or pawn loss releases a call')
call:input(second,true)
assert(not p2.mGestureData.mIsGesturing,'holding the button through a pause does not start a new call')
local rescue=Call.new(call.live,call.same,call.log,function(p)return p==second end)
local count=p2.starts
rescue:input(second,true)
local role,wantsHelp=rescue:observe(first,second)
assert(role==2 and wantsHelp and p2.starts==count,'hanging P2 requests help without playing a gesture')
rescue:input(second,true)
assert(not rescue:observe(first,second),'hold does not repeat the request')
rescue:input(second,false);rescue:input(second,true)
assert(not rescue:observe(first,pawn()),'a respawn cannot inherit the old request')
print('PASS: native gesture signaling for both players, press/release and pause cleanup.')
