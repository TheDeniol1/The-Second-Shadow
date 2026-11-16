const fs = require('fs');
const path = require('path');
const {lua,lauxlib,lualib,to_luastring,to_jsstring} = require('fengari');
process.chdir(path.resolve(__dirname,'..'));
const L=lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
function fail(){throw Error(to_jsstring(lua.lua_tostring(L,-1)));}
for(const file of fs.readdirSync('mods/LN2LocalCoop/scripts').filter(x=>x.endsWith('.lua'))){
 if(lauxlib.luaL_loadfile(L,to_luastring('mods/LN2LocalCoop/scripts/'+file))!==lua.LUA_OK) fail();
 lua.lua_pop(L,1);
}
if(lauxlib.luaL_dofile(L,to_luastring('tests/regression.lua'))!==lua.LUA_OK) fail();
