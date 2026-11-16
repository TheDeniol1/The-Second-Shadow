-- A private post-process volume and playing IDs for the separation warning.
local FX={};FX.__index=FX
local effect='/Game/Characters/Thinman/PostEffects/MAT_PP_Thinman.MAT_PP_Thinman'
local shake='/Game/Environment/Effects/CameraShakes/CameraShake_Cinematic_Side.CameraShake_Cinematic_Side_C'
local thinman='/Game/Audio/Events/Characters/Enemies/Thinman/'
local electric=thinman..'Gameplay/Play_Thinman_Proximity_Electric_LP'
local buildup=thinman..'Scenes/EnterViaTV/Play_Thinman_EnterViaTV_GrabSix_Buildup'
local heartbeat='/Game/Audio/Events/Characters/Friendly/Player/Gameplay/Play_Player_Heartbeat_LP'
local static='/Game/Audio/Events/Objects/Electric/TVs/ChapterSelect/Play_TV_ChapterSelect_Static_Level_LP'
local rotation={Pitch=0,Yaw=0,Roll=0}

function FX.new(live,same,log,native)
 return setmetatable({live=live,same=same,log=log,native=native,sounds={}},FX)
end

function FX:asset(path)
 local asset=StaticFindObject(path)
 if not self.live(asset) then LoadAsset(path);asset=StaticFindObject(path) end
 assert(self.live(asset),'Recurso no disponible: '..path)
 return asset
end

function FX:attempt(label,fn)
 local ok,value=pcall(fn)
 if not ok then self.log(label..': '..tostring(value));return end
 return value
end

function FX:removeVolume()
 local volume=self.volume
 self.volume,self.material,self.visible=nil,nil,nil
 if self.live(volume) then volume.bEnabled=false;volume:K2_DestroyActor() end
end

function FX:createVolume(pc,world)
 local parent=self:asset(effect)
 local lib=StaticFindObject('/Script/Engine.Default__KismetMaterialLibrary')
 local class=StaticFindObject('/Script/Engine.PostProcessVolume')
 local volume=world:SpawnActor(class,pc.Pawn:K2_GetActorLocation(),rotation)
 assert(self.live(volume),'No se pudo crear el volumen de distorsion')
 self.volume=volume
 volume.bEnabled=false
 volume.bUnbound=true
 volume.Priority=100
 volume.BlendWeight=1
 local material=lib:CreateDynamicMaterialInstance(volume,parent,FName('None'))
 assert(self.live(material),'No se pudo crear el material de Thin Man')
 local blendables=volume.Settings.WeightedBlendables
 blendables.Array={{Weight=1,Object=material}}
 assert(#blendables.Array==1 and self.same(blendables.Array[1].Object,material),'No se pudo enlazar el material de Thin Man')
 self.material=material
 self.log('Distorsion de Thin Man enlazada')
end

function FX:visual(pc,amount,now)
 if amount<=0 then
  if self.visible and self.live(self.volume) then self.volume.bEnabled=false end
  self.visible=nil
  return false
 end
 local world=pc:GetWorld()
 if self.same(world,self.failedWorld) then return false end
 local rendered=self:attempt('Distorsion de separacion',function()
  if not self.live(self.volume) or not self.same(world,self.volume:GetWorld())then
   self:removeVolume();self:createVolume(pc,world)
  end
  local phase=(now*1.25)%1
  local pulse=math.exp(-((phase-.20)/.11)^2)+.55*math.exp(-((phase-.42)/.10)^2)
  self.material:SetScalarParameterValue(FName('Alpha'),amount*(.45+.18*pulse))
  self.material:SetScalarParameterValue(FName('GlitchAlpha'),amount*.24*pulse)
  if not self.visible then self.volume.bEnabled=true;self.visible=true end
  return true
 end)
 if not rendered then self.failedWorld=world;self:removeVolume() end
 return rendered
end

function FX:play(pc,path)
 return self:attempt('Audio de separacion',function()
  local event=self:asset(path..'.'..path:match('[^/]+$'))
  local audio=StaticFindObject('/Script/AkAudio.Default__AkGameplayStatics')
  local id=audio:PostEventAtLocation(event,pc.Pawn:K2_GetActorLocation(),rotation,'',pc)
  assert(type(id)=='number' and id~=0,'Wwise no inicio '..path)
  self.sounds[#self.sounds+1]=id
  self.log('Audio de separacion iniciado: '..path:match('[^/]+$'))
  return id
 end)
end

function FX:playHeartbeat(pc)
 if self.native and self.native.heartbeat then
  local started=self:attempt('Latidos de separacion',function()
   local lib=StaticFindObject('/Script/Engine.Default__GameUserSettings')
   local settings=lib:GetGameUserSettings()
   local volume=math.max(0,math.min(1,settings:GetMasterAudioVolume()))
   return self.native.heartbeat(volume)
  end)
  if started then self.waveHeartbeat=true;return true end
 end
 local id=self:play(pc,heartbeat)
 if not id then return end
 return self:attempt('Latidos de separacion',function()
  local class=StaticFindObject('/Script/TarsierWwiseRuntimeExtension.PhysicsAudioComponent')
  local emitter=pc.Pawn:GetComponentByClass(class)
  assert(self.live(emitter),'No se encontro el emisor de Mono')
  -- Scope the native heartbeat settings to the warning's Wwise playing ID.
  emitter:SetRTPCValue('Heartbeat_Rate',1,200,id,4,false)
  emitter:SetRTPCValue('Heartbeat_Suspense',.5,200,id,4,false)
  return true
 end)
end

function FX:stopWarning()
 if not self.warning then return end
 self.warning,self.buildup,self.electricAt=nil,nil,nil
 if self.waveHeartbeat then
  self:attempt('Fin de los latidos de separacion',function()
   assert(self.native.stop_heartbeat(),'No se pudo cerrar la salida de audio')
  end)
  self.waveHeartbeat=nil
 end
 local audio=StaticFindObject('/Script/AkAudio.Default__AkGameplayStatics')
 for _,id in ipairs(self.sounds)do
  self:attempt('Fin del audio de separacion',function()audio:ExecuteActionOnPlayingID(0,id,350,4)end)
 end
 self.sounds={}
 if self.live(self.shake) and self.live(self.camera) then
  self:attempt('Fin del movimiento de camara',function()self.camera:StopCameraShake(self.shake,true)end)
 end
 self.shake,self.camera=nil,nil
end

function FX:warningFor(pc,elapsed)
 if not elapsed then self:stopWarning();return end
 if not self.warning then
  self.warning=true
  self.electricAt=self:playHeartbeat(pc) and elapsed+1 or elapsed
  self:attempt('Movimiento de camara de separacion',function()
   self.camera=pc.PlayerCameraManager
   self.shake=self.camera:PlayCameraShake(self:asset(shake),.18,0,rotation)
  end)
 end
 if self.electricAt and elapsed>=self.electricAt then
  self.electricAt=nil
  if not self:play(pc,electric)then self:play(pc,static)end
 end
 if elapsed>=10.5 and not self.buildup then
  self.buildup=true
  self:play(pc,buildup)
 end
end

function FX:clear()
 self:stopWarning()
 self:attempt('Fin de la distorsion',function()self:removeVolume()end)
end

return FX
