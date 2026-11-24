-- Pure keyboard logic, also used by the regression tests.
local M = {}
M.presets = {
 {name="I J K L",left="J",right="L",up="I",down="K",jump="U",grab="O",sneak="P",sprint="RightShift",use="H",gadget="Y",call="M",boost="F4"},
 {name="Teclado numerico",left="NumPadFour",right="NumPadSix",up="NumPadEight",down="NumPadFive",jump="NumPadSeven",grab="NumPadNine",sneak="NumPadZero",sprint="Decimal",use="NumPadOne",gadget="NumPadTwo",call="NumPadThree",boost="F4"},
}
function M.sample(preset,down)
 return {x=(down(preset.right) and 1 or 0)-(down(preset.left) and 1 or 0),
 y=(down(preset.up) and 1 or 0)-(down(preset.down) and 1 or 0),
 jump=down(preset.jump),grab=down(preset.grab),sneak=down(preset.sneak),sprint=down(preset.sprint),use=down(preset.use),gadget=down(preset.gadget),
 call=preset.call and down(preset.call) or false}
end
function M.direction(x,y,yaw)
 local length=math.sqrt(x*x+y*y)
 if length>1 then x,y=x/length,y/length end
 local a=math.rad(yaw)
 return {X=-math.sin(a)*x+math.cos(a)*y,Y=math.cos(a)*x+math.sin(a)*y,Z=0}
end
-- Native control orders expose ONE command, not a button bitmask.
function M.command(input)
 if input.jump then return 1 end
 if input.grab then return 2 end
 if input.sneak then return 4 end
 return 0
end
return M
