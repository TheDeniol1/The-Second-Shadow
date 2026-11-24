-- Pestaña "Logros" dentro del menú del propio juego (menú principal y pausa).
-- Añade un botón al ButtonPanel de WDG_MainMenu y WDG_PauseMenu y abre una pantalla
-- con dos pestañas: logros de Steam (solo lectura) y logros de The Second Shadow.
local Registry=require('coop_achievements')
local M={}
M.__index=M

local HOSTS={WDG_MainMenu_C='ButtonCredits',WDG_PauseMenu_C='ButtonExit'} -- botón Logros va antes de este
local FONT='/Game/Localization/Fonts/WesternAlphabet/Amorie-Modella-Bold_Font.Amorie-Modella-Bold_Font'
-- Solo blanco, como el menú del juego; el estado se marca con opacidad y texto.
local WHITE={R=1,G=1,B=1,A=1}
local BASE_SIZE=36
local ICON_DIR='achievement_icons/'        -- la DLL ln2_steam_icons escribe aquí los iconos de Steam
local PLACEHOLDER='logro_propio.png'       -- icono provisional de los logros del mod

local TEXT={
 button={es='Logros',en='Achievements'},
 title={es='LOGROS',en='ACHIEVEMENTS'},
 steam={es='Steam',en='Steam'},
 mod={es='The Second Shadow',en='The Second Shadow'},
 overlay={es='Ver en Steam',en='Open in Steam'},
 back={es='Volver',en='Back'},
 unlocked={es='Desbloqueado',en='Unlocked'},
 locked={es='Bloqueado',en='Locked'},
 summary={es='%d de %d desbloqueados',en='%d of %d unlocked'},
 steamNote={es='Leídos de Steam. El mod no los desbloquea.',en='Read from Steam. The mod never unlocks them.'},
 modNote={es='Logros propios del mod. Se guardan en achievements.ini.',en="The mod's own achievements, saved in achievements.ini."},
 hint={es='Q / E o LB / RB  cambiar pestaña     Flechas  desplazar     Esc  volver',
  en='Q / E or LB / RB  switch tab     Arrows  scroll     Esc  back'},
 toast={es='Logro desbloqueado: %s',en='Achievement unlocked: %s'},
 empty={es='No se pudieron leer los logros de Steam.',en='Could not read the Steam achievements.'},
 soon={es='Próximamente',en='Coming soon'},
 soonNote={es='Estamos preparando los logros propios del mod. Desbloquear uno en específico abrirá un final adicional.',
  en="The mod's own achievements are in the works. Unlocking a specific one will open an additional ending."},
}
M.TEXT=TEXT

local function short(name) return (tostring(name):gsub('^.*::','')) end
local function str(v)
 if v==nil then return nil end
 if type(v)~='userdata' then return tostring(v) end
 local ok,r=pcall(function() return v:ToString() end)
 if ok and type(r)=='string' then return r end
 ok,r=pcall(function() return v:get() end)
 if ok then if type(r)=='userdata' then return str(r) end return r~=nil and tostring(r) or nil end
 return nil
end
-- UE4SS escribe cada parámetro de salida en una tabla pasada en su posición.
-- Se busca por nombre en todas las tablas y, si no, por posición.
local function out(tables,name,index)
 for _,t in ipairs(tables)do
  if type(t)=='table' and t[name]~=nil then return t[name] end
 end
 local t=index and tables[index]
 if type(t)=='table' then return t[1] end
 return nil
end
local function keys(tables)
 local parts={}
 for i,t in ipairs(tables)do
  local names={}
  if type(t)=='table' then for k,v in pairs(t)do names[#names+1]=tostring(k)..'='..tostring(v) end end
  parts[#parts+1]=i..':{'..table.concat(names,',')..'}'
 end
 return table.concat(parts,' ')
end

function M.new(o)
 local self=setmetatable({o=o,state=o.state,live=o.live,log=o.log or function()end,
  injected={},buttons={},hooked={},tab='steam',open=false,keys={},enumNames={}},M)
 self.registry=o.registry or Registry.new({path=o.root and (o.root..'achievements.ini'),log=self.log,
  notify=function(d) self:toast(d) end})
 return self
end

function M:lang() return self.state.language=='en' and 'en' or 'es' end
function M:t(key) return Registry.pick(TEXT[key],self:lang()) end
function M:ctx() return {coop=self.state.enabled==true,six=self.state.playAsSix==true} end

-------------------------------------------------------------------- Steam (solo lectura)
function M:steamSystem()
 if not self.live(self.system) then self.system=FindFirstOf('AchievementSystem') end
 return self.live(self.system) and self.system or nil
end

function M:loadEnum()
 if next(self.enumNames) then return end
 local e=StaticFindObject('/Script/Helios.EAchievement')
 if not self.live(e) then return end
 pcall(function() e:ForEachName(function(n,v) self.enumNames[v]=short(str(n) or '') end) end)
end

function M:steamList()
 if self.steamCache then return self.steamCache end
 self:loadEnum()
 local set=StaticFindObject('/Script/Helios.Default__AchievementsProjectSettings')
 if not self.live(set) then return {} end
 local list={}
 local ok,err=pcall(function()
  set.AchievementList:ForEach(function(_,el)
   local d=el:get()
   local e=d.AchievementEnum
   list[#list+1]={enum=e,id=str(d.AchievementID) or tostring(e),name=self.enumNames[e],target=tonumber(d.TargetCount) or 0}
  end)
 end)
 if not ok then self.log('Logros: no se pudo leer AchievementList: '..tostring(err)) end
 if #list>0 then self.steamCache=list end
 return list
end

function M:cacheSteamTexts(pc)
 if self.textsRequested or not self.live(pc) then return end
 self.textsRequested=true
 local proxy=StaticFindObject('/Script/OnlineSubsystemUtils.Default__AchievementQueryCallbackProxy')
 if not self.live(proxy) then return end
 for _,fn in ipairs({'CacheAchievements','CacheAchievementDescriptions'})do
  local ok,err=pcall(function()
   local p=proxy[fn](proxy,pc,pc)
   if self.live(p) then p:Activate() end
  end)
  if not ok then self.log('Logros: '..fn..' '..tostring(err)) end
 end
end

function M:steamEngine(pc)
 local sys=self:steamSystem()
 local lib=StaticFindObject('/Script/OnlineSubsystemUtils.Default__AchievementBlueprintLibrary')
 local engine={}
 function engine.list() return self:steamList() end
 function engine.unlocked(e)
  if not sys then return false end
  local ok,v=pcall(function() return sys:IsAchievementUnlockedPlatform(e) end)
  if ok and v then return true end
  return false
 end
 function engine.progress(e)
  if not sys then return nil end
  local t={{},{}}
  sys:GetAchievementProgress(e,t[1],t[2])
  return tonumber(str(out(t,'Count',1)))
 end
 if self.live(lib) and self.live(pc) then
  function engine.describe(id)
   local t={{},{},{},{},{}}
   lib:GetCachedAchievementDescription(pc,pc,FName(id),t[1],t[2],t[3],t[4],t[5])
   local found=out(t,'bFoundID',1)
   if found==false then return nil end
   local title=str(out(t,'Title',2))
   local desc=str(out(t,'UnlockedDescription',4)) or str(out(t,'LockedDescription',3))
   local hidden=out(t,'bHidden',5)
   if not self.describedOnce then
    self.describedOnce=true
    self.log('Logros: texto de Steam para '..id..' -> '..tostring(title)..' | '..tostring(desc)..' | '..keys(t))
   end
   return title,desc,hidden==true
  end
 end
 return engine
end

function M:hookGameAchievements()
 if self.gameHooks then return end
 self.gameHooks=true
 local function nameOf(param)
  local ok,v=pcall(function() return param:get() end)
  if not ok then return nil end
  self:loadEnum()
  return self.enumNames[v]
 end
 local function hook(path,amountOf)
  local ok,err=pcall(RegisterHook,path,function(_,a,b)
   local name=nameOf(a)
   if not name then return end
   local amount=amountOf and amountOf(b) or 1
   local okE,errE=pcall(self.registry.event,self.registry,'game:'..name,amount,self:ctx())
   if not okE then self.log('Logros: evento '..name..' '..tostring(errE)) end
   self.dirtyScreen=true
  end)
  if not ok then self.log('Logros: no se pudo enganchar '..path..' '..tostring(err)) end
 end
 hook('/Script/Helios.AchievementSystem:RequestUnlockAchievement')
 hook('/Script/Helios.AchievementSystem:IncrementAchievementCount',function(b)
  local ok,v=pcall(function() return b:get() end)
  return ok and tonumber(v) or 1
 end)
 hook('/Script/Helios.AchievementSystem:IncrementAchievementReference')
end

-------------------------------------------------------------------- Botón en el menú del juego
-- Los menús del juego viven dentro de un HeliosLayerWidget, no directamente en el
-- viewport, así que IsInViewport() es falso para ellos: se usa la visibilidad de Slate.
local function shown(w)
 local ok,v=pcall(function() return w:IsInViewport() end)
 if ok and v then return true end
 ok,v=pcall(function() return w:IsVisible() end)
 return ok and v==true
end
M.shown=shown

local function className(w)
 local ok,n=pcall(function() return w:GetClass():GetFName():ToString() end)
 return ok and n or nil
end

function M:font()
 if not self.live(self.fontObject) then
  self.fontObject=StaticFindObject(FONT)
  if not self.live(self.fontObject) then pcall(LoadAsset,FONT); self.fontObject=StaticFindObject(FONT) end
 end
 return self.live(self.fontObject) and self.fontObject or nil
end

-- Aplica la fuente del menú del juego (si ya se copió) a escala de su tamaño,
-- en blanco con la opacidad indicada.
function M:style(text,scale,alpha)
 local g=self.gameFont
 local base=(g and tonumber(g.size)) or BASE_SIZE
 local size=math.max(14,math.floor(base*scale+.5))
 local object=g and self.live(g.object) and g.object or self:font()
 if object then pcall(function() text:SetFont({FontObject=object,Size=size,TypefaceFontName=FName('None')}) end) end
 local c=g and g.color or WHITE
 pcall(function() text:SetColorAndOpacity({SpecifiedColor={R=c.R,G=c.G,B=c.B,A=alpha or 1},ColorUseRule=0}) end)
 return text
end

function M:makeText(tree,source,label,size,color)
 local cls=StaticFindObject(source and '/Script/Helios.HeliosTextBlock' or '/Script/UMG.TextBlock')
 local text=StaticConstructObject(cls,tree)
 if source then
  pcall(function() text.mUseCultureFont=source.mUseCultureFont end)
  pcall(function() text:SetFont(source.Font) end)
  pcall(function() text:SetColorAndOpacity(source.ColorAndOpacity) end)
  pcall(function() text:SetShadowOffset(source.ShadowOffset) end)
  pcall(function() text:SetShadowColorAndOpacity(source.ShadowColorAndOpacity) end)
  pcall(function() text:SetJustification(source.Justification) end)
 else
  local font=self:font()
  if font then text:SetFont({FontObject=font,Size=size or 22,TypefaceFontName=FName('None')}) end
  text:SetColorAndOpacity({SpecifiedColor=color or WHITE,ColorUseRule=0})
  text:SetShadowColorAndOpacity({R=0,G=0,B=0,A=.9})
  text:SetShadowOffset({X=1,Y=1})
 end
 if size and source then pcall(function() text:SetFontSize(size) end) end
 text:SetText(FText(label))
 return text
end

function M:makeButton(tree,template,label,size)
 local btn=StaticConstructObject(StaticFindObject('/Script/Helios.HeliosButton'),tree)
 local srcText
 if self.live(template) then
  pcall(function() btn:SetStyle(template.WidgetStyle) end)
  for _,p in ipairs({'mFadeTime','mMinScale','mMaxScale','mPressedScale','mPressedFadeTime','mMinOpacity','mMaxOpacity',
   'mShouldPlayClickSound','IsFocusable','ClickMethod','TouchMethod','PressMethod'})do
   pcall(function() btn[p]=template[p] end)
  end
  pcall(function() btn:SetRenderOpacity(template:GetRenderOpacity()) end)
  pcall(function() srcText=template:GetContent() end)
  if not self.live(srcText) then srcText=nil end
 end
 local text=self:makeText(tree,srcText,label,size)
 btn:SetContent(text)
 if srcText then
  pcall(function()
   local from,to=srcText.Slot,text.Slot
   to:SetPadding(from.Padding)
   to:SetHorizontalAlignment(from.HorizontalAlignment)
   to:SetVerticalAlignment(from.VerticalAlignment)
  end)
 end
 return btn,text
end

local function copySlot(from,to)
 if not (from and to) then return end
 pcall(function() to:SetPadding(from.Padding) end)
 pcall(function() to:SetSize(from.Size) end)
 pcall(function() to:SetHorizontalAlignment(from.HorizontalAlignment) end)
 pcall(function() to:SetVerticalAlignment(from.VerticalAlignment) end)
end

-- Inserta child antes de anchor en un VerticalBox moviendo al final los que van detrás.
function M.insertBefore(panel,child,anchor,live)
 local count=panel:GetChildrenCount()
 local index
 for i=0,count-1 do
  local c=panel:GetChildAt(i)
  if anchor and live(c) and c:GetAddress()==anchor:GetAddress() then index=i break end
 end
 if not index then
  local slot=panel:AddChild(child)
  return slot,count
 end
 local tail={}
 for i=index,count-1 do
  local c=panel:GetChildAt(i)
  local s=c.Slot
  tail[#tail+1]={widget=c,slot={Padding=s.Padding,Size=s.Size,HorizontalAlignment=s.HorizontalAlignment,VerticalAlignment=s.VerticalAlignment}}
 end
 local mine
 local ok,err=pcall(function()
  for _,item in ipairs(tail)do panel:RemoveChild(item.widget) end
  mine=panel:AddChild(child)
  copySlot(tail[1].slot,mine)
  for _,item in ipairs(tail)do copySlot(item.slot,panel:AddChild(item.widget)) end
 end)
 if not ok then
  -- Recupera cualquier botón original que haya quedado fuera del panel.
  for _,item in ipairs(tail)do
   local parent
   pcall(function() parent=item.widget:GetParent() end)
   if not live(parent) then pcall(function() copySlot(item.slot,panel:AddChild(item.widget)) end) end
  end
  error(err)
 end
 return mine,index
end

-- Copia tamaño, tipografía y color del texto de un botón original (Settings) leyendo
-- sus campos y construyendo estructuras nuevas, sin pasar estructuras del juego.
function M:matchGameText(menu,text)
 local ok,err=pcall(function()
  local src=menu.ButtonSettings:GetContent()
  local font=src.Font
  local size=tonumber(font.Size)
  local object=font.FontObject
  if size and size>0 and self.live(object) then
   text:SetFont({FontObject=object,Size=size,TypefaceFontName=font.TypefaceFontName})
  end
  local c=src.ColorAndOpacity.SpecifiedColor
  text:SetColorAndOpacity({SpecifiedColor={R=c.R,G=c.G,B=c.B,A=c.A},ColorUseRule=0})
  self.gameFont={object=object,size=size,color={R=c.R,G=c.G,B=c.B}}
 end)
 if not ok then self.log('Logros: no se copió el estilo del texto: '..tostring(err)) end
end

-- Versión prudente: botón con estilo propio, añadido al final del panel y con un
-- registro por paso para localizar cualquier fallo del motor.
function M:inject(menu)
 if not self.live(menu) then return end
 local key=menu:GetAddress()
 if self.injected[key] then return end
 local cls=className(menu)
 if not (cls and HOSTS[cls]) then return end
 self.injected[key]={menu=menu,failed=true}
 local function step(n) self.log('Logros: paso '..n..' ('..cls..')') end
 local ok,err=pcall(function()
  step('1 panel')
  local panel=menu.ButtonPanel
  assert(self.live(panel),'sin ButtonPanel')
  local tree=menu.WidgetTree
  assert(self.live(tree),'sin WidgetTree')
  step('2 boton')
  local btn=StaticConstructObject(StaticFindObject('/Script/Helios.HeliosButton'),tree)
  assert(self.live(btn),'no se creó el botón')
  step('3 texto')
  local text=self:makeText(tree,nil,self:t('button'),30,WHITE)
  self:matchGameText(menu,text)
  step('4 contenido')
  btn:SetContent(text)
  step('5 panel')
  local anchor
  pcall(function() anchor=menu[HOSTS[cls]] end)
  local okInsert,errInsert=pcall(M.insertBefore,panel,btn,self.live(anchor) and anchor or nil,self.live)
  if not okInsert then
   self.log('Logros: inserción ordenada falló ('..tostring(errInsert)..'), se añade al final')
   local parent
   pcall(function() parent=btn:GetParent() end)
   if not self.live(parent) then panel:AddChild(btn) end
  end
  step('6 listo')
  self.injected[key]={menu=menu,button=btn,text=text,language=self:lang()}
  self.buttons[btn:GetAddress()]='open'
  self.hostOf=self.hostOf or {}
  self.hostOf[btn:GetAddress()]=menu
  self.log('Logros: botón añadido a '..cls)
 end)
 if not ok then self.log('Logros: no se pudo añadir el botón a '..tostring(cls)..': '..tostring(err)) end
end

function M:hookHost(cls)
 if self.hooked[cls] then return end
 local path='/Game/Blueprints/Widgets/Menues/'..cls:gsub('_C$','')..'.'..cls..':OnSetupMenu'
 local ok=pcall(RegisterHook,path,function(ctx)
  local menu=ctx:get()
  pcall(self.inject,self,menu)
 end)
 self.hooked[cls]=ok and 'hook' or 'poll'
end

function M:watchMenus()
 pcall(NotifyOnNewObject,'/Script/Helios.HeliosMenuWidget',function(o)
  local cls=className(o)
  if not (cls and HOSTS[cls]) then return end
  local name=''
  pcall(function() name=o:GetFullName() end)
  if name:find('WidgetArchetype',1,true) or name:find('Default__',1,true) then return end
  self.pending=self.pending or {}
  self.pending[#self.pending+1]=o
  self.log('Logros: menú detectado '..cls)
 end)
 pcall(RegisterHook,'/Script/Helios.HeliosButton:Clicked',function(ctx)
  local ok,btn=pcall(function() return ctx:get() end)
  if not (ok and self.live(btn)) then return end
  local action=self.buttons[btn:GetAddress()]
  if action then
   self.queued=action
   if self.hostOf and self.hostOf[btn:GetAddress()] then self.lastHost=self.hostOf[btn:GetAddress()] end
  end
 end)
end

-------------------------------------------------------------------- Pantalla de logros
local function full(slot)
 slot:SetAnchors({Minimum={X=0,Y=0},Maximum={X=1,Y=1}})
 slot:SetOffsets({Left=0,Top=0,Right=0,Bottom=0})
end

function M:buildScreen(pc)
 local lib=StaticFindObject('/Script/UMG.Default__WidgetBlueprintLibrary')
 local cls=StaticFindObject('/Script/Helios.HeliosMenuWidget')
 self.log('Logros: pantalla paso 1 crear')
 local w=lib:Create(pc,cls,pc)
 assert(self.live(w),'no se pudo crear la pantalla de logros')
 self.log('Logros: pantalla paso 2 arbol')
 local tree=w.WidgetTree
 if not self.live(tree) then
  tree=StaticConstructObject(StaticFindObject('/Script/UMG.WidgetTree'),w)
  w.WidgetTree=tree
 end
 local function new(class) return StaticConstructObject(StaticFindObject('/Script/UMG.'..class),tree) end
 local root=new('CanvasPanel')
 tree.RootWidget=root
 local bg=new('Image')
 bg:SetColorAndOpacity({R=0,G=0,B=0,A=.93})
 full(root:AddChildToCanvas(bg))
 local column=new('VerticalBox')
 local cs=root:AddChildToCanvas(column)
 cs:SetAnchors({Minimum={X=.16,Y=.07},Maximum={X=.84,Y=.93}})
 cs:SetOffsets({Left=0,Top=0,Right=0,Bottom=0})
 local function add(widget,pad,fill,center)
  local s=column:AddChildToVerticalBox(widget)
  if pad then s:SetPadding({Left=0,Top=pad,Right=0,Bottom=0}) end
  if fill then s:SetSize({SizeRule=1,Value=1}) end
  if center then s:SetHorizontalAlignment(2) end
  return s
 end
 self.log('Logros: pantalla paso 3 contenido')
 local title=self:style(self:makeText(tree,nil,self:t('title'),44),1.25)
 add(title,0,false,true)
 local tabs=new('HorizontalBox')
 add(tabs,18,false,true)
 local function tab(action,key)
  local b=StaticConstructObject(StaticFindObject('/Script/Helios.HeliosButton'),tree)
  local t=self:style(self:makeText(tree,nil,self:t(key),26),.8)
  b:SetContent(t)
  local s=tabs:AddChildToHorizontalBox(b)
  s:SetPadding({Left=18,Top=0,Right=18,Bottom=0})
  self.buttons[b:GetAddress()]=action
  return b,t
 end
 local screen={widget=w,tree=tree,tabs={}}
 screen.tabs.steam={tab('tab:steam','steam')}
 screen.tabs.mod={tab('tab:mod','mod')}
 screen.overlayButton={tab('overlay','overlay')}
 screen.backButton={tab('back','back')}
 pcall(function() w.ButtonPanel=tabs end)
 screen.summary=self:style(self:makeText(tree,nil,'',20),.72)
 add(screen.summary,14,false,true)
 screen.note=self:style(self:makeText(tree,nil,'',16),.55,.85)
 add(screen.note,4,false,true)
 local scroll=new('ScrollBox')
 add(scroll,18,true,false)
 local list=new('VerticalBox')
 scroll:AddChild(list)
 screen.scroll,screen.list,screen.rows=scroll,list,{}
 screen.hint=self:style(self:makeText(tree,nil,self:t('hint'),15),.5,.85)
 add(screen.hint,10,false,true)
 self.screen=screen
 self.log('Logros: pantalla paso 4 lista')
 return screen
end

-------------------------------------------------------------------- Iconos
-- Ruta del icono de una fila. Steam: el PNG que escribió ln2_steam_icons.dll con el
-- nombre de API del logro. Mod: el campo icon de la definición o el provisional.
function M.iconPath(root,tab,data,exists)
 if not root or not data then return nil end
 if tab=='steam' then
  local id=tostring(data.id or '')
  if not id:match('^[%w_%-]+$') then return nil end
  local path=root..ICON_DIR..id..'.png'
  return exists(path) and path or nil
 end
 -- Bloqueado: siempre el icono común de logro bloqueado (logro_propio.png).
 if data.unlocked then
  local custom=data.icon and tostring(data.icon)
  if custom and custom:match('^[%w_%-%.]+%.png$') and not custom:find('..',1,true) and exists(root..custom) then return root..custom end
  local id=tostring(data.id or '')
  if id:match('^[%w_]+$') and exists(root..'logro_'..id..'.png') then return root..'logro_'..id..'.png' end
 end
 local path=root..PLACEHOLDER
 return exists(path) and path or nil
end

local function fileExists(path)
 if not (io and io.open) then return false end
 local f=io.open(path,'rb')
 if f then f:close() return true end
 return false
end

function M:exists(path)
 self.seen=self.seen or {}
 if self.seen[path] then return true end
 local ok=fileExists(path)
 if ok then self.seen[path]=true end
 return ok
end

function M:texture(path,pc)
 self.textures=self.textures or {}
 local tex=self.textures[path]
 if self.live(tex) then return tex end
 self.textures[path]=nil
 local ok,result=pcall(function()
  local lib=StaticFindObject('/Script/Engine.Default__KismetRenderingLibrary')
  return lib:ImportFileAsTexture2D(pc,path)
 end)
 if ok and self.live(result) then self.textures[path]=result return result end
 if not (self.iconErrors and self.iconErrors[path]) then
  self.iconErrors=self.iconErrors or {}
  self.iconErrors[path]=true
  self.log('Logros: no se pudo cargar el icono '..path..': '..tostring(result))
 end
 return nil
end

function M:setIcon(r,data,pc)
 if not r.icon then return end
 local path=M.iconPath(self.o.root,self.tab,data,function(p) return self:exists(p) end)
 local tex=path and pc and self:texture(path,pc)
 if not tex then r.icon:SetVisibility(2) r.iconPath=nil return end
 if r.iconPath~=path then
  local side=r.iconSide
  pcall(function() r.icon:SetBrushFromTexture(tex,false) end)
  pcall(function() r.icon:SetBrushSize({X=side,Y=side}) end)
  r.iconPath=path
 end
 -- Steam ya entrega el icono gris si está bloqueado; los del mod usan su icono de bloqueado.
 local alpha=1
 pcall(function() r.icon:SetColorAndOpacity({R=1,G=1,B=1,A=alpha}) end)
 r.icon:SetVisibility(0)
end

-- Carga la DLL que pide a Steam los iconos. Solo lectura: no desbloquea nada.
function M:loadIconHelper()
 local root=self.o.root
 if not root or not fileExists(root..'ln2_steam_icons.dll') then self.log('Logros: sin ln2_steam_icons.dll, filas sin icono de Steam') return end
 local ok,a,b=pcall(package.loadlib,root..'ln2_steam_icons.dll','*')
 if ok and a then self.log('Logros: lector de iconos de Steam cargado')
 else self.log('Logros: no se cargó ln2_steam_icons.dll: '..tostring(ok and b or a)) end
end

function M:row(i)
 local s=self.screen
 local r=s.rows[i]
 if r then return r end
 local box=StaticConstructObject(StaticFindObject('/Script/UMG.HorizontalBox'),s.tree)
 local slot=s.list:AddChildToVerticalBox(box)
 slot:SetPadding({Left=8,Top=i==1 and 0 or 20,Right=8,Bottom=0})
 local base=(self.gameFont and tonumber(self.gameFont.size)) or BASE_SIZE
 local side=math.max(48,math.floor(base*1.9+.5))
 local icon
 pcall(function()
  icon=StaticConstructObject(StaticFindObject('/Script/UMG.Image'),s.tree)
  icon:SetBrushSize({X=side,Y=side})
  local is=box:AddChildToHorizontalBox(icon)
  is:SetPadding({Left=0,Top=0,Right=18,Bottom=0})
  is:SetVerticalAlignment(1)
  icon:SetVisibility(2)
 end)
 local textBox=StaticConstructObject(StaticFindObject('/Script/UMG.VerticalBox'),s.tree)
 local ts=box:AddChildToHorizontalBox(textBox)
 pcall(function() ts:SetSize({SizeRule=1,Value=1}) ts:SetVerticalAlignment(2) end)
 local head=self:style(self:makeText(s.tree,nil,'',23),.72)
 local desc=self:style(self:makeText(s.tree,nil,'',17),.56,.9)
 pcall(function() desc:SetAutoWrapText(true) end)
 textBox:AddChildToVerticalBox(head)
 textBox:AddChildToVerticalBox(desc)
 r={box=box,head=head,desc=desc,icon=icon,iconSide=side}
 s.rows[i]=r
 return r
end

function M:refresh(pc)
 local s=self.screen
 if not s then return end
 local language=self:lang()
 local rows,done,total
 if self.tab=='steam' then
  local ok,a,b,c=pcall(Registry.steamRows,self:steamEngine(pc),language)
  if ok then rows,done,total=a,b,c else self.log('Logros: lectura de Steam falló: '..tostring(a)) rows,done,total={},0,0 end
 else
  rows,done,total=self.registry:rows(language)
 end
 for key,pair in pairs(s.tabs)do
  local active=self.tab==key
  self:style(pair[2],.8,active and 1 or .45)
 end
 if total==0 and self.tab=='steam' then
  s.summary:SetText(FText(self:t('empty')))
 elseif total==0 then
  s.summary:SetText(FText(self:t('soon')))
 else
  s.summary:SetText(FText(string.format(self:t('summary'),done,total)))
 end
 s.note:SetText(FText(self:t(self.tab=='steam' and 'steamNote' or (total==0 and 'soonNote' or 'modNote'))))
 for i,data in ipairs(rows)do
  local r=self:row(i)
  local status=data.unlocked and self:t('unlocked') or (data.progress or self:t('locked'))
  r.head:SetText(FText(data.title..'   ·   '..status))
  self:style(r.head,.72,data.unlocked and 1 or .8)
  r.desc:SetText(FText(data.desc or ''))
  self:setIcon(r,data,pc)
  r.box:SetVisibility(0)
 end
 for i=#rows+1,#s.rows do s.rows[i].box:SetVisibility(2) end
 self.shownRevision=self.registry.revision
 self.dirtyScreen=false
end

function M:focusTabs()
 local s=self.screen
 if not s then return end
 local b=s.tabs[self.tab] and s.tabs[self.tab][1]
 if self.live(b) then pcall(function() b:SetKeyboardFocus() end) end
end

function M:widgetManager()
 if not self.live(self.manager) then self.manager=FindFirstOf('WidgetManager') end
 return self.live(self.manager) and self.manager or nil
end

function M:openScreen(pc)
 if self.open then return end
 self:cacheSteamTexts(pc)
 local ok,err=pcall(function()
  if not (self.screen and self.live(self.screen.widget)) then self:buildScreen(pc) end
  self:refresh(pc)
  local w=self.screen.widget
  local manager=self:widgetManager()
  self.pushed=false
  self.log('Logros: pantalla paso 5 apilar')
  if manager then
   local okPush,errPush=pcall(function() manager:PushMenuWidget(w) end)
   self.pushed=okPush
   if not okPush then self.log('Logros: PushMenuWidget falló: '..tostring(errPush)) end
  end
  self.log('Logros: pantalla abierta (apilada='..tostring(self.pushed)..')')
  self.open=true
  self.openedAt=os.clock()
  self.checkedPush=false
  self:focusTabs()
  self.world=pc:GetWorld()
  pcall(function() self.screen.scroll:SetScrollOffset(0) end)
 end)
 if not ok then self.log('Logros: no se pudo abrir la pantalla: '..tostring(err)) self.open=false end
end

function M:inViewport()
 local s=self.screen
 if not (s and self.live(s.widget)) then return false end
 return shown(s.widget)
end

function M:closeScreen()
 if not self.open then return end
 self.open=false
 local s=self.screen
 if not (s and self.live(s.widget)) then return end
 if self.overlay then
  pcall(function() s.widget:RemoveFromParent() end)
  if self.hiddenHost and self.live(self.hiddenHost) then pcall(function() self.hiddenHost:SetVisibility(4) end) end
  self.overlay,self.hiddenHost=false,nil
 elseif self:inViewport() then
  local manager=self:widgetManager()
  local ok=manager and self.live(self.world) and pcall(function() manager:PopMenuWidget(self.world) end)
  if not ok then pcall(function() s.widget:RemoveFromParent() end) end
 end
end

-- Si el juego no mostró la pantalla al apilarla, se muestra encima del menú.
function M:ensureVisible(host)
 if not self.open or self.overlay or self.checkedPush or os.clock()-self.openedAt<.35 then return end
 self.checkedPush=true
 if self:inViewport() then return end
 pcall(function() self.screen.widget:AddToViewport(9500) end)
 self.overlay=true
 if self.live(host) then self.hiddenHost=host pcall(function() host:SetVisibility(2) end) end
 self:focusTabs()
 self.log('Logros: la pantalla se muestra como capa propia')
end

function M:toast(d)
 local text=string.format(self:t('toast'),Registry.pick(d.title,self:lang()))
 local ok=false
 local manager=self:widgetManager()
 local viewport=FindFirstOf('GameViewportClient')
 local world=self.live(viewport) and viewport.World or nil
 if manager and self.live(world) then
  ok=pcall(function() manager:ShowHintWidget(world,FText(text),4.0) end)
 end
 if not ok then self.log(text) end
 self.dirtyScreen=true
end

-------------------------------------------------------------------- Bucle
function M:edge(name,down)
 local was=self.keys[name]
 self.keys[name]=down
 return down and not was
end

function M:input(pc)
 local o=self.o
 local function key(k) return o.keyDown and o.keyDown(k) or false end
 local function pad(k)
  local ok,v=pcall(function() return pc:IsInputKeyDown({KeyName=FName(k)}) end)
  return ok and v
 end
 local focused=not o.focused or o.focused()
 if not focused then return end
 if self:edge('back',key('Escape') or key('BackSpace') or pad('Gamepad_FaceButton_Right')) then
  self.backAt=os.clock()
 end
 if self.backAt and os.clock()-self.backAt>.2 then
  self.backAt=nil
  if self.open and (self:inViewport() or self.overlay) then self:closeScreen() else self.open=false end
 end
 local nextTab=self:edge('next',key('E') or pad('Gamepad_RightShoulder'))
 local prevTab=self:edge('prev',key('Q') or pad('Gamepad_LeftShoulder'))
 if nextTab or prevTab then self.tab=self.tab=='steam' and 'mod' or 'steam' self:refresh(pc) end
 local delta=0
 if key('Down') or key('S') or pad('Gamepad_DPad_Down') or pad('Gamepad_RightStick_Down') then delta=delta+22 end
 if key('Up') or key('W') or pad('Gamepad_DPad_Up') or pad('Gamepad_RightStick_Up') then delta=delta-22 end
 if self:edge('pgdn',key('PageDown')) then delta=delta+400 end
 if self:edge('pgup',key('PageUp')) then delta=delta-400 end
 if delta~=0 then
  pcall(function()
   local s=self.screen.scroll
   local offset=math.max(0,math.min(s:GetScrollOffset()+delta,s:GetScrollOffsetOfEnd()))
   s:SetScrollOffset(offset)
  end)
 end
end

function M:act(action,pc)
 if action=='open' then self:openScreen(pc)
 elseif action=='back' then self:closeScreen()
 elseif action=='tab:steam' then self.tab='steam' self:refresh(pc)
 elseif action=='tab:mod' then self.tab='mod' self:refresh(pc)
 elseif action=='overlay' then
  pcall(function() StaticFindObject('/Script/Engine.Default__KismetSystemLibrary'):ShowPlatformSpecificAchievementsScreen(pc) end)
 end
end

function M:tick(pc,dt)
 local state=self.state
 -- Menús nuevos pendientes de recibir el botón (respaldo si el hook OnSetupMenu no llega).
 if self.pending then
  local keep={}
  for _,menu in ipairs(self.pending)do
   if self.live(menu) then
    local key=menu:GetAddress()
    self.seen=self.seen or {}
    self.seen[key]=self.seen[key] or os.clock()
    if shown(menu) and os.clock()-self.seen[key]>1.5 then self:inject(menu) else
     keep[#keep+1]=menu
     self.waitLogged=self.waitLogged or {}
     if os.clock()-self.seen[key]>5 and not self.waitLogged[key] then
      self.waitLogged[key]=true
      local okP,panel=pcall(function() return menu.ButtonPanel end)
      self.log('Logros: el menú sigue sin mostrarse ('..tostring(className(menu))..', panel='..tostring(okP and self.live(panel))..')')
     end
    end
   end
  end
  self.pending=#keep>0 and keep or nil
 end
 -- Idioma del botón.
 for key,entry in pairs(self.injected)do
  if entry.failed then
  elseif not self.live(entry.button) then self.injected[key]=nil
  elseif entry.language~=self:lang() then entry.text:SetText(FText(self:t('button'))) entry.language=self:lang() end
 end
 -- Respaldo para clics: IsPressed del botón inyectado.
 for _,entry in pairs(self.injected)do
  if entry.button then
  local ok,pressed=pcall(function() return entry.button:IsPressed() end)
  local id='press'..entry.button:GetAddress()
  if ok and self:edge(id,pressed) then self.queued=self.queued or 'open' self.lastHost=entry.menu end
  end
 end
 if self.queued then local a=self.queued self.queued=nil self:act(a,pc) end
 if self.open then
  self:ensureVisible(self.lastHost)
  if not self.overlay and self.checkedPush and os.clock()-self.openedAt>.6 and not self:inViewport() then self.open=false end
  self:input(pc)
  -- Los iconos de Steam llegan en segundo plano: se reintenta hasta que la DLL termina.
  if self.tab=='steam' and not self.iconsDone and os.clock()-(self.iconCheck or 0)>2 then
   self.iconCheck=os.clock()
   self.iconsDone=self.o.root~=nil and fileExists(self.o.root..ICON_DIR..'index.txt')
   self.dirtyScreen=true
  end
  if self.dirtyScreen or self.shownRevision~=self.registry.revision then self:refresh(pc) end
 end
 -- Logros propios basados en el estado del mod.
 local playing=self.o.playing and self.o.playing()
 if playing and state.enabled then
  self.registry:event('coop:active',1,self:ctx())
  if state.split and dt and dt>0 and dt<5 then self.registry:event('split:seconds',dt,self:ctx()) end
 end
 self.flushTimer=(self.flushTimer or 0)+(dt or 0)
 if self.flushTimer>30 then self.flushTimer=0 self.registry:flush() end
end

function M.install(o)
 local self=M.new(o)
 self:hookGameAchievements()
 self:watchMenus()
 pcall(function() self:loadIconHelper() end)
 local last=os.clock()
 -- Mismo hilo que el bucle principal del mod: LoopAsync ejecuta Lua en otro hilo
-- a la vez que el juego y corrompía el estado de Lua (cierres del juego).
 LoopInGameThreadWithDelay(50,function()
  local ok,err=pcall(function()
   local now=os.clock()
   local dt=now-last
   last=now
   local pc=o.p1 and o.p1()
   if pc then self:tick(pc,dt) end
  end)
  if not ok and err~=self.lastError then self.lastError=err self.log('Logros: '..tostring(err)) end
 end)
 self.log('Logros: pestaña del menú del juego lista')
 return self
end

return M
