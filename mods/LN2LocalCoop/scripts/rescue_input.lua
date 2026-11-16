-- UE key names -> physical Windows VK codes. Read only; never synthesizes keys.
local M={}
local codes={LeftMouseButton=1,RightMouseButton=2,MiddleMouseButton=4,ThumbMouseButton=5,ThumbMouseButton2=6,
 BackSpace=8,Tab=9,Enter=13,Pause=19,CapsLock=20,Escape=27,SpaceBar=32,
 PageUp=33,PageDown=34,End=35,Home=36,Left=37,Up=38,Right=39,Down=40,Insert=45,Delete=46,
 LeftShift=160,RightShift=161,LeftControl=162,RightControl=163,LeftAlt=164,RightAlt=165,
 NumLock=144,ScrollLock=145,Multiply=106,Add=107,Subtract=109,Decimal=110,Divide=111,
 Semicolon=186,Equals=187,Comma=188,Hyphen=189,Period=190,Slash=191,Tilde=192,
 LeftBracket=219,Backslash=220,RightBracket=221,Apostrophe=222}
for i=65,90 do codes[string.char(i)]=i end
for i,name in ipairs({'Zero','One','Two','Three','Four','Five','Six','Seven','Eight','Nine'})do
 codes[name]=47+i;codes['NumPad'..name]=95+i
end
for i=1,24 do codes['F'..i]=111+i end
function M.code(name)return codes[name]end
function M.held(mappings,read)
 if not read then return nil end
 local supported=false
 for _,m in ipairs(mappings)do
  local key=codes[m.key]
  if key then
   supported=true
   if read(key) and (not m.shift or read(160)or read(161))
    and (not m.ctrl or read(162)or read(163))and (not m.alt or read(164)or read(165))then return true end
  end
 end
 if supported then return false end
 return nil
end
return M
