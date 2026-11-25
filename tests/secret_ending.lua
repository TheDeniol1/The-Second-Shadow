-- Final oculto: condición de Dark Six en la caja de música y escena del puente.
local Secret=require('secret_ending')
local function pawn(path,at)
 local p={path=path,at=at,anim=nil}
 function p:GetFullName() return self.path end
 function p:K2_GetActorLocation() return self.at end
 return p
end
local tower='/Game/Levels/Transmission/PLVL_Transmission.PersistentLevel.BP_PlayerPawn_C'
local gap={X=-809,Y=14000,Z=28700}
local function setup(unlocked)
 local calls={pull=0,frame={},fade=0,card=0,credits=0,release=0,logs={}}
 local api={live=function(v) return v~=nil end,same=function(a,b) return a==b end,
  log=function(s) calls.logs[#calls.logs+1]=s end,
  animation=function(p) return p.anim end,unlocked=function() return unlocked end,
  pull=function() calls.pull=calls.pull+1 return 2 end,
  frame=function(_,progress) calls.frame[#calls.frame+1]=progress end,
  fade=function() calls.fade=calls.fade+1 end,card=function() calls.card=calls.card+1 end,
  credits=function() calls.credits=calls.credits+1 return calls.creditsWork~=false end,
  release=function() calls.release=calls.release+1 end}
 return Secret.new(api),calls
end
local first,second=pawn(tower,{X=0,Y=0,Z=0}),pawn(tower,{X=0,Y=0,Z=0})

local s=setup(true)
second.anim='ANIM_Player_HittingMusicBoxVoidLong';s:observe(first,second,true,true)
second.anim=nil;first.anim='ANIM_Player_WakeUpAfterLastHitMusicBox';s:observe(first,second,true,true)
assert(s:darkSixRetired(true) and s.armed,'the last hit by Dark Six with the achievement arms the hidden ending')

local p1=setup(true)
second.anim='ANIM_Player_HittingMusicBoxVoidLong';p1:observe(first,second,true,true)
second.anim=nil;first.anim='ANIM_Player_HittingMusicBoxRecoil';p1:observe(first,second,true,true)
assert(not p1:darkSixRetired(true),'a final hit by P1 keeps the normal ending')

local locked=setup(false)
first.anim=nil;second.anim='ANIM_Player_HittingMusicBoxVoidLong';locked:observe(first,second,true,true)
assert(not locked:darkSixRetired(true),'without the hidden achievement the ending stays normal')

local mono=setup(true)
mono:observe(first,second,true,false)
assert(not mono:darkSixRetired(false),'two-Mono mode never opens the hidden ending')

-- Escena del puente.
local hero=pawn(tower,gap)
local scene,calls=setup(true)
scene.armed=true
assert(scene:update(hero,10,true,false)==nil,'the scene waits for Six to catch Mono')
hero.anim='ANIM_Player_GapHelpSixBetrayal'
assert(scene:update(hero,11,true,false)=='hold' and calls.pull==1 and scene.phase=='pull','Six pulls Mono up instead of dropping him')
assert(scene:update(hero,12,true,true)=='hold' and scene.phase=='pull','pausing holds the scene')
scene:update(hero,13.5,true,false)
assert(scene.phase=='together','after the pull both stay together on the bridge')
scene:update(hero,13.5+Secret.timing.together,true,false)
assert(scene.phase=='fade' and calls.fade==1,'the shot fades to black')
scene:update(hero,13.5+Secret.timing.together+Secret.timing.fade,true,false)
assert(scene.phase=='card' and calls.card==1,'the ending text appears in the dark')
scene:update(hero,30,true,false)
assert(scene.phase=='done' and calls.credits==1 and not scene.armed and calls.release==0,'the game credits close the hidden ending')
assert(calls.frame[#calls.frame]==1,'the camera finishes the push-in before the fade')

local failing,fcalls=setup(true)
fcalls.creditsWork=false
failing.armed=true;hero.anim='ANIM_Player_GapHelpSixBetrayal'
for t=1,40 do failing:update(hero,t,true,false) end
assert(failing.phase=='done' and fcalls.release==1,'if the credits cannot open the game gets its camera back')

local menu,mcalls=setup(true)
menu.armed=true;menu:update(hero,1,true,false)
menu:update(hero,2,false,false)
assert(not menu.armed and not menu.phase and mcalls.release==1,'returning to the menu cancels the scene and disarms it')

local away=setup(true)
away.armed=true
local elsewhere=pawn('/Game/Levels/School/PLVL_School.X',gap);elsewhere.anim='ANIM_Player_GapHelpSixBetrayal'
assert(away:update(elsewhere,1,true,false)==nil and away.armed,'the scene only starts on the Tower bridge')
print('PASS: hidden ending needs the hidden achievement, Six mode and the last hit by Dark Six, then plays the bridge scene and credits.')
