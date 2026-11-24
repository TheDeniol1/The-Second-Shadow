local MusicBox=require('music_box_transition')
local long='ANIM_Player_HittingMusicBoxVoidLong'
local recoil='ANIM_Player_HittingMusicBoxRecoil'
local wake='ANIM_Player_HittingMusicBox_SpawnWakeUp'
local finalWake='ANIM_Player_WakeUpAfterLastHitMusicBox'
local pickup='ANIM_Player_AxeTransmissionPickup2'
local other='ANIM_Player_Climb'
local assets={}
local function clip(name)
 if not name then return nil end
 if not assets[name] then
  assets[name]={GetFullName=function()return 'AnimSequence /Game/Characters/Player/Animations/'..name..'.'..name end}
 end
 return assets[name]
end
local function pawn(x)
 local p={at={X=x,Y=0,Z=0},stops=0,CharacterMovement={MovementMode=1}}
 p.K2_GetActorLocation=function(self)return self.at end
 p.mAnimationControlComponent={IsPlayingOverrideAnimation=function(self)return self.mCurrentAnimStateAsset~=nil end}
 p.mAnimationOverrideComponent={StopAnimationSequenceOverride=function(_,skipExit)
  assert(skipExit,'do not replay the old room exit animation in the new room')
  p.stops=p.stops+1
  p:setClip(nil)
 end}
 function p:setClip(name) self.mAnimationControlComponent.mCurrentAnimStateAsset=clip(name) end
 return p
end
local first,second=pawn(0),pawn(25)
local nativeArrival
local safe,acceptMove,canMove,moved=true,true,true,0
local logs={}
local box=MusicBox.new({
 live=function(o)return o~=nil end,same=function(a,b)return a~=nil and a==b end,
 log=function(msg)logs[#logs+1]=msg end,
 canMove=function(p)assert(p==(nativeArrival and first or second));return canMove end,
 destination=function(p,q,at)
  assert(p==(nativeArrival and second or first) and q==(nativeArrival and first or second) and at==p.at,
   'do not probe around a stale pawn or previous room')
  if safe then return {X=at.X+70,Y=at.Y,Z=at.Z+4} end
 end,
 move=function(p,at)
  assert(p==(nativeArrival and first or second),'the native character responsible for the chapter stays in its own scene')
  if not acceptMove then return false end
  moved=moved+1;p.at=at;return true
 end,
})
local function tick(now,start,paused)
 return box:update(first,second,now,true,start~=false,paused)
end

second:setClip(long)
assert(not tick(0,false) and not box.hit,'opt-in controls new transitions')
assert(not tick(0) and box.hit and second.stops==0)
assert(not tick(10) and moved==0 and second.stops==0,'the observed ten-second original sequence runs in full')
first.at={X=6500,Y=8300,Z=9000};first:setClip(wake)
first.CharacterMovement.MovementMode=3
assert(not tick(10.2,true,true) and not box.hit.arrivedAt,'paused game makes no edits')
assert(tick(10.2) and moved==0 and second.stops==0,'wait for P1 to land in the new room')
first.CharacterMovement.MovementMode=1
safe=false
assert(tick(10.5) and moved==0 and second.stops==0,'loaded transition without a safe landing cannot move P2')
safe=true
assert(not tick(10.8,false) and moved==1 and second.stops==1 and first.stops==0,
 'an in-flight recovery can finish after the preference is toggled')
assert(second.at.X==6570 and first.mAnimationControlComponent.mCurrentAnimStateAsset==clip(wake))
assert(not tick(11) and moved==1,'the same transition cannot repeat')

box:reset()
first:setClip(nil);second:setClip(recoil)
assert(not tick(20) and box.hit)
second:setClip(nil)
assert(not tick(20.3) and second.stops==1)
assert(not tick(51) and not box.hit and moved==1,'an ordinary recoil can finish without a room change')

box:reset()
second:setClip(long)
assert(not tick(60))
first.at={X=15000,Y=0,Z=15300}
assert(not tick(60.25) and moved==2 and second.stops==2,'abrupt native transport is also recognized')

second:setClip(long);assert(not tick(70))
second:setClip(other);first:setClip(wake)
assert(not tick(70.1) and moved==2 and second.stops==2,'a different override takes ownership and is preserved')
first:setClip(nil);second:setClip(long)
assert(not tick(71))
assert(not box:update(first,second,71.1,false,true,false) and not box.hit,'checkpoint invalidation drops pending recovery')
assert(not tick(72))
second=pawn(30)
assert(not tick(72.1) and not box.hit and moved==2,'a replacement pawn does not inherit the old hit')

second:setClip(long);first:setClip(nil)
assert(not tick(80))
first:setClip(wake);acceptMove=false
assert(tick(80.2) and second.stops==1)
assert(not tick(101) and moved==2 and second.stops==1,'failed placement has a bounded wait and releases the clip once')
assert(logs[#logs]:find('no se encontro una llegada segura',1,true))

box:reset()
local function update(now,redirectSecond,paused)
 return box:update(first,second,now,true,true,paused,redirectSecond)
end
first:setClip(nil);second:setClip(long)
assert(not update(105,false) and not box.hit,'P2 strikes require opt-in')
second:setClip(nil);first:setClip(long)
assert(not update(106,false) and box.hit and not box.hit.fromSecond and box:protectsSeparation(),
 'a confirmed P1 hit suspends separation even with event redirection disabled')
local origin=second.at
first.at={X=22000,Y=0,Z=18000};first:setClip(wake)
second:setClip(other);acceptMove=true
assert(update(106.15,false) and box:protectsSeparation() and second.at==origin,'a foreign animation is preserved during arrival')
assert(update(106.2,false,true) and second.at==origin,'pause preserves the in-flight handoff')
second:setClip(nil);canMove=false
assert(update(106.4,false) and second.at==origin,'wait for P2 to release the unsafe state')
canMove=true
assert(not update(106.7,false) and not box:protectsSeparation() and second.at.X==22070 and moved==3)
assert(first.stops==0 and second.stops==1,'a primary hit never stops either native animation')

box:reset()
first:setClip(wake);second:setClip(long)
assert(not update(110,true) and box.hit)
assert(not update(110.2,true) and not box.hit.arrivedAt,'an arrival animation already in progress is not a new arrival')
box:reset()
first:setClip(recoil);second:setClip(nil)
assert(not update(112,false) and box:protectsSeparation())
first:setClip(nil)
assert(not update(112.2,false) and not box:protectsSeparation(),'an ordinary recoil restores the separation rule immediately')

box:reset()
first:setClip('ANIM_Player_StumbleFallLong')
assert(not update(115,false) and not box.hit,'a generic stumble elsewhere is outside the route')
first.at={X=-2704,Y=-19502,Z=31119}
assert(not update(115.1,false) and box.hit.void,'recognize the recorded intermediate room')
first.at={X=-2704,Y=-17502,Z=31119}
assert(not update(115.2,false) and not box.hit.arrivedAt,'the void route requires the observed destination, even after a large movement')
first.at={X=-642,Y=4148,Z=19945};first:setClip('ANIM_Player_StumbleFall')
assert(not update(115.3,false) and moved==4 and second.at.X==-572,'the recorded return to Monster Six reunites P2')

box:reset()
nativeArrival=true
first:setClip(nil);second:setClip(recoil)
local stops=second.stops
assert(not update(125,true) and box.hit.fromSecond)
second:setClip(finalWake)
assert(update(126,true) and box.hit.nativeSecond and moved==4 and second.stops==stops,
 'if the game advances the scene on P2, let P2 finish its native wake')
second.at={X=15000,Y=1000,Z=1500};second:setClip(nil)
assert(not update(130,true) and moved==5 and first.at.X==15070 and second.stops==stops,
 'reunite P1 using the destination chosen by the game for P2')

box:reset()
second:setClip(pickup);clip(pickup).SequenceLength=6
assert(not update(140,true) and box.pose and second.stops==stops)
assert(not update(149.9,true) and second.stops==stops,'give the native scene time to finish')
assert(not update(150.1,true,true) and second.stops==stops,'do not edit the clip while paused')
assert(not update(150.1,true) and second.stops==stops+1 and not box.hit,
 'release a final pickup clip that remains active beyond its duration')
assert(not update(150.2,true) and second.stops==stops+1,'stale clip recovery runs once')
second:setClip(finalWake);clip(finalWake).SequenceLength=6
assert(not update(155,true))
second:setClip(other)
assert(not update(166,true) and second.stops==stops+1,'preserve an animation that has replaced the wake')

second:setClip(recoil);clip(recoil).SequenceLength=2
assert(not update(170,true) and box.hit.fromSecond)
assert(not update(180.1,true) and box.hit.endedAt and second.stops==stops+2,
 'release a stuck P2 recoil even if the scene does not move rooms')
print('PASS: P2 music-box handoff, native arrival, safe placement, ordinary recoil, replacement and bounded recovery.')
print('PASS: P1 music-box handoff, separation, pause, stale signals, foreign overrides and the observed void return.')
print('PASS: the final wake stays on its native P2 owner and only lingering encounter clips are released.')

box:reset()
nativeArrival=false
first.at={X=3409,Y=-15130,Z=4962};first:setClip(nil)
second.at={X=3253,Y=-15511,Z=4962};second:setClip(long)
clip(long).SequenceLength=3
local before=second.stops
assert(not update(200,true) and box.hit.firstStrike)
first.at={X=596,Y=-19801,Z=12264}
assert(not update(200.2,true) and not box.hit.arrivedAt and second.stops==before,
 'the intermediate teleport from the recorded first strike must not cut the clip')
assert(not update(210.1,true) and second.stops==before and box:protectsSeparation(),
 'do not interrupt the first strike before its native wake even past the ordinary watchdog')
second:setClip(nil)
assert(not update(210.2,true) and box:protectsSeparation())
first.at={X=1834,Y=-9551,Z=13219};first:setClip(wake)
assert(not update(210.4,true) and not box.hit and second.at.X==1904 and moved==6)
assert(second.stops==before,'the first strike may finish naturally before the actual reunion')

box:reset()
first.at={X=3253,Y=-15511,Z=4962};first:setClip(long)
second.at={X=3409,Y=-15130,Z=4962};second:setClip(nil)
assert(not update(220,false) and box.hit.firstStrike)
first.at={X=596,Y=-19801,Z=12264};first:setClip(nil)
assert(not update(220.2,false) and not box.hit.arrivedAt)
assert(not update(226,false) and box:protectsSeparation(),'keep waiting after the first clip ends')
first.at={X=1834,Y=-9551,Z=13219};first:setClip(wake)
assert(not update(230.4,false) and not box.hit and moved==7 and second.at.X==1904)
print('PASS: the first Tower strike waits for the recorded wake after the intermediate teleport with either attacker.')
