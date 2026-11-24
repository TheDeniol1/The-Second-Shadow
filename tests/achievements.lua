-- Logros: registro propio, lectura de Steam solo lectura y botón en el menú del juego.
local Registry=require('coop_achievements')
local tmp='achievements-test.ini'
local files={}
local memio={open=function(path,mode)
 if mode=='r' then
  local data=files[path]
  if not data then return nil end
  return {lines=function() return data:gmatch('[^\n]+') end,close=function() end}
 end
 local buf={}
 return {write=function(_,...) for _,v in ipairs({...})do buf[#buf+1]=v end end,close=function() files[path]=table.concat(buf) end}
end}
local function remove(path) files[path]=nil end
local notified={}
local defs={
 {id='uno',title={es='Uno',en='One'},desc={es='D',en='D'},events={'coop:active'},coop=true},
 {id='kids',title={es='Niños',en='Kids'},desc={es='D',en='D'},events={'game:FindAllPhantomKids'},target=5,coop=true},
 {id='six',title={es='Six',en='Six'},desc={es='S',en='S'},events={'game:CompleteSchool'},coop=true,six=true,hidden=true},
 {id='split',title={es='Div',en='Split'},desc={es='S',en='S'},events={'split:seconds'},target=120,unit='minutes'},
}
local function registry() return Registry.new({defs=defs,path=tmp,io=memio,clock=function()return 42 end,notify=function(d)notified[#notified+1]=d.id end}) end
remove(tmp)
local r=registry()
assert(r:event('coop:active',1,{coop=false})==0 and not r.unlocked.uno,'co-op achievements ignore solo play')
assert(r:event('coop:active',1,{coop=true})==1 and r.unlocked.uno and notified[1]=='uno','co-op activation unlocks and notifies once')
assert(r:event('coop:active',1,{coop=true})==0 and #notified==1,'an unlocked achievement is not repeated')
for _=1,4 do r:event('game:FindAllPhantomKids',1,{coop=true}) end
local rows=r:rows('es')
assert(rows[2].progress=='4/5' and not rows[2].unlocked,'counter shows its progress')
r:event('game:CompleteSchool',1,{coop=true,six=false})
assert(not r.unlocked.six and rows[3].hidden and rows[3].title=='Logro oculto','Six-only achievement stays hidden without Six')
r:event('split:seconds',61,{})
r:flush()
local again=registry()
assert(again.unlocked.uno and again.progress.kids==4 and again.times.uno==42,'progress survives a restart')
assert(again:rows('en')[4].progress=='1/2 min','minutes progress is formatted in English')
again:event('game:FindAllPhantomKids',3,{coop=true})
assert(again.unlocked.kids and again.progress.kids==5,'progress is capped at the target when it unlocks')
again:event('game:CompleteSchool',1,{coop=true,six=true})
local _,done,total=again:rows('en')
assert(again.unlocked.six and again:rows('en')[3].title=='Six' and done==3 and total==4,'Six chapter unlock reveals the hidden entry')
remove(tmp)
local ok=pcall(Registry.new,{defs={{id='a'},{id='a'}}})
assert(not ok,'duplicate ids are rejected')
local real=Registry.new({path=nil})
assert(#real.defs==0 and next(real.byEvent)==nil,'v0.8.0 Alpha ships the mod tab empty while the achievements are in the works')

-- Steam: solo lectura, con textos opcionales y logros ocultos.
local engine={
 list=function() return {{enum=0,id='CompleteWilderness',name='CompleteWilderness',target=0},
  {enum=5,id='FindAllPhantomKids',name='FindAllPhantomKids',target=18},{enum=9,id='ThinmanHat',name='ThinmanHat',target=0}} end,
 unlocked=function(e) return e==0 end,
 progress=function(e) return e==5 and 7 or 0 end,
 describe=function(id) if id=='ThinmanHat' then return 'Secret','x',true end if id=='CompleteWilderness' then return 'Wilderness','Done',false end end,
}
local srows,sdone,stotal=Registry.steamRows(engine,'es')
assert(stotal==3 and sdone==1,'Steam summary counts unlocked entries')
assert(srows[1].title=='Wilderness' and srows[1].unlocked,'Steam texts are used when cached')
assert(srows[2].title=='Find All Phantom Kids' and srows[2].progress=='7/18','missing texts fall back to the readable id')
assert(srows[3].hidden and srows[3].title=='Logro oculto' and srows[3].desc=='','locked hidden Steam achievements stay secret')
local broken={list=engine.list,unlocked=function() error('x') end,progress=engine.progress}
local brows,bdone=Registry.steamRows(broken,'en')
assert(#brows==3 and bdone==0,'a failing Steam query shows entries as locked')

-- Botón en el ButtonPanel: entra antes del ancla y los demás conservan su ranura.
local GameMenu=require('game_menu')
local nextAddress=100
local function widget(name)
 nextAddress=nextAddress+1
 local w={name=name,address=nextAddress}
 function w:GetAddress() return self.address end
 function w:GetParent() return self.parent end
 return w
end
local function panel()
 local p=widget('panel');p.children={}
 function p:GetChildrenCount() return #self.children end
 function p:GetChildAt(i) return self.children[i+1] end
 function p:AddChild(c)
  local slot={Padding={Left=c.pad or 0},Size={SizeRule=0},HorizontalAlignment=0,VerticalAlignment=0}
  function slot:SetPadding(v) self.Padding=v end
  function slot:SetSize(v) self.Size=v end
  function slot:SetHorizontalAlignment(v) self.HorizontalAlignment=v end
  function slot:SetVerticalAlignment(v) self.VerticalAlignment=v end
  c.Slot,c.parent=slot,self;table.insert(self.children,c);return slot
 end
 function p:RemoveChild(c)
  for i,x in ipairs(self.children)do if x==c then table.remove(self.children,i) c.Slot,c.parent=nil,nil return true end end
 end
 return p
end
local live=function(o) return o~=nil end
local p=panel()
local names={'ButtonResumeGame','ButtonNewGame','ButtonSettings','ButtonCredits','ButtonExit'}
local byName={}
for i,n in ipairs(names)do local w=widget(n);w.pad=i;p:AddChild(w);byName[n]=w end
byName.ButtonCredits.Slot.Padding={Left=99}
local mine=widget('Logros')
GameMenu.insertBefore(p,mine,byName.ButtonCredits,live)
local order={}
for _,c in ipairs(p.children)do order[#order+1]=c.name end
assert(table.concat(order,',')=='ButtonResumeGame,ButtonNewGame,ButtonSettings,Logros,ButtonCredits,ButtonExit','Achievements goes right after Settings')
assert(byName.ButtonCredits.Slot.Padding.Left==99 and mine.Slot.Padding.Left==99,'moved buttons keep their slot and ours copies it')
local q=panel()
for _,n in ipairs({'A','B'})do q:AddChild(widget(n)) end
GameMenu.insertBefore(q,widget('Logros'),nil,live)
assert(q.children[3].name=='Logros','without an anchor the button is appended')
local failing=panel()
local a,b=widget('A'),widget('B')
failing:AddChild(a);failing:AddChild(b)
local realAdd=failing.AddChild
local calls=0
function failing:AddChild(c) calls=calls+1 if calls==1 then error('boom') end return realAdd(self,c) end
local okFail=pcall(GameMenu.insertBefore,failing,widget('Logros'),a,live)
assert(not okFail and a.parent==failing and b.parent==failing,'a failed insertion restores the original buttons')

-- Clic del botón del juego abre la pantalla; Esc la cierra. Textos en el idioma del mod.
local state={language='es',enabled=true,playAsSix=false,split=true}
local menu=GameMenu.new({state=state,live=live,log=function()end,registry=registry(),keyDown=function(k) return k==pressed end,
 playing=function() return true end})
assert(menu:t('button')=='Logros','Spanish label')
state.language='en'
assert(menu:t('button')=='Achievements' and menu:t('title')=='ACHIEVEMENTS','English label')
local opened,closed=0,0
menu.openScreen=function(self) self.open=true opened=opened+1 self.openedAt=os.clock() self.checkedPush=true end
menu.closeScreen=function(self) self.open=false closed=closed+1 end
menu.inViewport=function() return true end
menu.refresh=function() end
menu.ensureVisible=function() end
menu.buttons[555]='open'
menu.queued='open'
local pc={IsInputKeyDown=function() return false end}
remove(tmp)
menu.registry=registry()
menu:tick(pc,.05)
assert(opened==1 and menu.open,'a click on the injected button opens the achievements screen')
assert(menu.registry.unlocked.uno and menu.registry.progress.split>0,'state-driven co-op achievements progress while playing')
pressed='Escape'
menu:tick(pc,.05)
pressed=nil
local t0=os.clock() while os.clock()-t0<.25 do end
menu:tick(pc,.05)
assert(closed==1 and not menu.open,'Esc closes the screen after the game had a chance to handle it')
-- Iconos: Steam por nombre de API, logros propios con icono opcional o provisional.
local disk={['R/achievement_icons/CompleteTransmission.png']=true,['R/logro_propio.png']=true,['R/mi_logro.png']=true}
local has=function(path) return disk[path]==true end
assert(GameMenu.iconPath('R/','steam',{id='CompleteTransmission'},has)=='R/achievement_icons/CompleteTransmission.png','Steam rows use the icon exported for their API name')
assert(GameMenu.iconPath('R/','steam',{id='CompleteSchool'},has)==nil,'a Steam row without an exported icon has none')
assert(GameMenu.iconPath('R/','steam',{id='../x'},has)==nil,'Steam ids never escape the icon folder')
assert(GameMenu.iconPath('R/','mod',{unlocked=true,id='a'},has)=='R/logro_propio.png','custom rows fall back to the placeholder')
assert(GameMenu.iconPath('R/','mod',{unlocked=true,id='a',icon='mi_logro.png'},has)=='R/mi_logro.png','custom rows may name their own icon')
assert(GameMenu.iconPath('R/','mod',{unlocked=true,id='a',icon='../evil.png'},has)=='R/logro_propio.png','custom icons stay inside the scripts folder')
assert(GameMenu.iconPath(nil,'mod',{id='a'},has)==nil,'no icon without a mod folder')
disk['R/logro_eco.png']=true
assert(GameMenu.iconPath('R/','mod',{unlocked=true,id='eco'},has)=='R/logro_eco.png','unlocked custom rows pick logro_<id>.png automatically')
assert(GameMenu.iconPath('R/','mod',{unlocked=false,id='eco'},has)=='R/logro_propio.png','locked custom rows always show the shared locked icon')
assert(rows[1].icon==nil or type(rows[1].icon)=='string','registry rows carry the optional icon field')
remove(tmp)
print('PASS: custom achievements, Steam read-only rows, game menu button insertion and screen open/close.')
