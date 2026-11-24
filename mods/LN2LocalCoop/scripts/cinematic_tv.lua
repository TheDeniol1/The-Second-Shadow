local TV={};TV.__index=TV
local city='/Game/Levels/PaleCity/PLVL_PaleCIty.'
local base='/Script/Helios.PuzzleTVActor:'
local blueprint='/Game/GameplayLogic/AreaSpecific/TVs/PP_TV_Base.PP_TV_Base_C:'
local function distanceSquared(a,b)
 return (a.X-b.X)^2+(a.Y-b.Y)^2+(a.Z-b.Z)^2
end

function TV.new(api) return setmetatable({api=api,hooks={},errors={}},TV) end

function TV:report(where,err)
 local message=tostring(err)
 if self.errors[where]~=message then
  self.errors[where]=message
  self.api.log('Televisores ('..where..'): '..message)
 end
end

function TV:entry(source,actor,confirmed)
 local api=self.api
 local first,second,now=api.pair()
 if not (first and api.world(source,first) and first:GetFullName():find(city,1,true)) then return end
 local follower,role
 if api.same(actor,first) then follower,role=second,1
 elseif api.same(actor,second) then follower,role=first,2
 else return end
 local underway=self.pending or self.trip
 if underway then
  if api.same(actor,underway.follower) then
   if confirmed then self.interrupted=true end
   if api.same(source,underway.source) then underway.followerTouch=true end
   return
  end
  if api.same(source,underway.source) then return end
 end
 local origin=follower:K2_GetActorLocation()
 if distanceSquared(actor:K2_GetActorLocation(),origin)>580^2 then return end
 self.touch={source=source,first=first,second=second,lead=actor,follower=follower,role=role,origin=origin,at=now}
 if not confirmed then return end
 self.pending=self.touch;self.touch=nil
 api.log('Televisores: P'..role..' entro y P'..(3-role)..' acompana el cruce')
end

function TV:arrival(a,b,actor)
 local api=self.api
 local first,second,now=api.pair()
 if not first or not (api.world(a,first) and api.world(b,first))
  or api.same(a,b) then return end
 local trip=self.pending or self.trip
 if trip and trip.followerTouch and api.same(actor,trip.follower)
  and (api.same(a,trip.source) or api.same(b,trip.source)) then
  self.interrupted=true
  return
 end
 local source=trip
 if not source or not (api.same(a,source.source) or api.same(b,source.source)) then source=self.touch end
 if not source or not api.same(source.lead,actor)
  or not api.same(source.first,first) or not api.same(source.second,second) or now<source.at
  or now-source.at>8 then return end
 local target
 if api.same(a,source.source) then target=b
 elseif api.same(b,source.source) then target=a end
 if not target or source.destination then return end
 if source~=trip then
  -- A Blueprint may implement touching the screen and the exit event, but
  -- inherit the empty start event. The native exit proves the link in that case.
  trip=source
  self.pending=trip
 end
 self.touch=nil
 trip.destination=target;trip.arrivedAt=now
 api.log('Televisores: salida nativa de P'..trip.role..' confirmada en '..target:GetFullName())
end

function TV:install(now)
 if self.nextHook and now>=self.nextHook-1 and now<self.nextHook then return end
 self.nextHook=now+1
 local function hook(path,fn)
  if self.hooks[path] then return end
  local ok,err=pcall(function()
   if not self.api.live(StaticFindObject(path)) then return end
   RegisterHook(path,function(...)
    if not self.api.enabled() then return end
    local worked,problem=pcall(fn,...)
    if not worked then self:report(path,problem) end
   end)
   self.hooks[path]=true
  end)
  if not ok then self:report(path,err) end
 end
 for _,prefix in ipairs({base,blueprint}) do
  hook(prefix..'ReceivePawnTouchingScreen',function(_,screen,actor)self:entry(screen:get(),actor:get(),false)end)
  hook(prefix..'ReceivePawnStartTeleporting',function(_,screen,actor)self:entry(screen:get(),actor:get(),true)end)
  hook(prefix..'ReceivePawnEndTeleporting',function(_,a,b,actor)self:arrival(a:get(),b:get(),actor:get())end)
 end
end

function TV:release(trip)
 if trip and trip.clip then self.api.stop(trip.follower,trip.clip);trip.clip=nil end
end

function TV:reset()
 local trip=self.trip
 self.trip=nil;self.touch=nil;self.pending=nil;self.interrupted=nil
 self:release(trip)
end

function TV:protectsSeparation() return self.trip~=nil end

function TV:advance(first,second,now,paused)
 local api=self.api
 if self.interrupted then
  -- The companion's own trip can already be playing the same reach asset.
  if self.trip then self.trip.clip=nil end
  self:reset()
  return false
 end
 if self.pending then
  self:release(self.trip)
  self.trip=self.pending;self.pending=nil
 end
 local trip=self.trip
 if not trip then return false end
 if not api.same(trip.first,first) or not api.same(trip.second,second) or now<trip.at
  or not api.world(trip.source,first) then self:reset();return false end
 local lead,follower=trip.lead,trip.follower
 if trip.finishAt then
  if now<trip.finishAt and api.owns(follower,trip.clip) then return true end
  self:reset();return false
 end
 if paused then return trip.clip~=nil and api.owns(follower,trip.clip) end

 if not trip.arrivedAt then
  if now-trip.at>8 then self:reset();return false end
  if not trip.reached and api.canMove(follower) then
   trip.reached=true
   trip.clip=api.play(follower,'ANIM_Player_TVStandReach',trip.source:K2_GetActorLocation(),false)
  end
  return trip.clip~=nil and api.owns(follower,trip.clip)
 end
 if now-trip.arrivedAt>4 or not api.world(trip.destination,first) then self:reset();return false end
 if trip.nextLanding and now<trip.nextLanding then return false end
 trip.nextLanding=now+.15
 local target=trip.destination:K2_GetActorLocation()
 local origin=lead:K2_GetActorLocation()
 if distanceSquared(origin,target)>490^2 or not api.grounded(lead) then return false end
 local from=follower:K2_GetActorLocation()
 if distanceSquared(from,origin)<=155^2 or distanceSquared(from,trip.origin)>850^2 then self:reset();return false end

 self:release(trip)
 if not api.canMove(follower) then return false end
 local destination=api.landing(lead,follower,origin,function(at)return distanceSquared(at,target)<=530^2 end)
 if not destination or not api.move(follower,destination) then return false end
 local clip,duration=api.play(follower,'ANIM_Player_TVExitGrounded',target,true)
 api.log('Televisores: P'..(3-trip.role)..' salio junto a P'..trip.role)
 if not clip then self:reset();return false end
 trip.clip=clip;trip.finishAt=now+duration
 return true
end

function TV:update(first,second,now,paused)
 local ok,locked=pcall(self.advance,self,first,second,now,paused)
 if ok then return locked,locked and self.trip.follower end
 self:report('cruce',locked)
 pcall(self.reset,self)
 return false
end

return TV
